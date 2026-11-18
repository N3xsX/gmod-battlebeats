BATTLEBEATS_server = BATTLEBEATS_server or {}

util.AddNetworkString("BTB_Change_ConVar")
util.AddNetworkString("BTB_ThreatDebug")
util.AddNetworkString("BTB_ExplosionFade")
util.AddNetworkString("BTB_CombatState")

local playerCombatTargets = {}
local incomingShots = {}
local npcDamage = {}
local lastSent = {}
local enemyMemory = {}
local enemySpotted = {}
local memoryTime = 60

--local combatCooldown = GetConVar("battlebeats_server_combat_cooldown")
local maxDistance = GetConVar("battlebeats_server_max_distance")
local pvpEnabled = GetConVar("battlebeats_pvp_enable")
local pvpMode = GetConVar("battlebeats_pvp_mode")
local pvpCombatTime = GetConVar("battlebeats_pvp_combat_time")
local pvpTeam = GetConVar("battlebeats_pvp_allow_team_combat")
local pvpRequireLOS = GetConVar("battlebeats_pvp_lineofsight")
local maxDistancePVP = GetConVar("battlebeats_pvp_max_distance")
local shotsNearTrigger = GetConVar("battlebeats_pvp_near_shots_trigger_combat")

local povAngle = GetConVar("battlebeats_server_pov_angle")
local povNearDistance = GetConVar("battlebeats_server_pov_near_distance")
local povGrace = 2

local c2555050220 = Color(255, 50, 50, 220)
local function debugPVETrigger(ply, ent)
    if GetConVar("developer"):GetInt() < 1 then return end
    local plyEye = ply:EyePos()
    local entHead = ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z + 10)
    debugoverlay.Line(plyEye, entHead, 1, c2555050220, false)
    debugoverlay.Box(ent:GetPos(), ent:OBBMins(), ent:OBBMaxs(), 1, c2555050220)
    local entClass = ent.GetClass and ent:GetClass() or "n/a"
    local dist = math.Round(ply:GetPos():Distance(ent:GetPos()), 1)
    debugoverlay.Text(entHead + Vector(0, 0, 30), "[BATTLEBEATS]" .. " " .. entClass .. " -> is triggering PVE | Distance: " .. dist .. " units", 1)
end

BATTLEBEATS_server.ignoredNPCs = {
    ["npc_crow"] = true,
    ["npc_pigeon"] = true,
    ["npc_seagull"] = true,
    ["npc_cscanner"] = true,
    ["npc_clawscanner"] = true,
    ["npc_combine_camera"] = true
}

local isSinglePlayer = game.SinglePlayer()
local dmgWindow = 5
local closeRadiusSqr = 600 * 600
local function sendState(ply, enemy, score, close, curTime)
    local l = lastSent[ply]
    if l and l.e == enemy and l.s == score and l.c == close and curTime - l.t < 5 then return end
    if not l then
        l = {}
        lastSent[ply] = l
    end
    l.e, l.s, l.c, l.t = enemy, score, close, curTime

    net.Start("BTB_CombatState")
    net.WriteBool(enemy)
    net.WriteUInt(score, 6)
    net.WriteUInt(close, 8)
    net.Send(ply)
end

local function canNoticeNPC(ply, ent, ctx, curTime, spotted)
    if not ply:IsLineOfSightClear(ent) then return false end
    if ctx.povOff then return true end

    if ctx.plyPos:DistToSqr(ent:GetPos()) <= ctx.nearSqr then
        spotted[ent] = curTime
        return true
    end

    local last = spotted[ent]
    if last and curTime - last <= povGrace then
        spotted[ent] = curTime
        return true
    end

    local dir = ent:WorldSpaceCenter() - ctx.eyePos
    dir:Normalize()
    if dir:Dot(ctx.fwd) >= ctx.cosHalf then
        spotted[ent] = curTime
        return true
    end
    return false
end

local weak = { __mode = "k" }
local firedRecently = setmetatable({}, weak)
local firearmCache = setmetatable({}, weak)

local nonFirearm = {
    ["weapon_crowbar"] = true,
    ["weapon_stunstick"] = true,
    ["weapon_frag"] = true,
    ["weapon_slam"] = true,
}

local rangedCaps = bit.bor(CAP_INNATE_RANGE_ATTACK1, CAP_WEAPON_RANGE_ATTACK1)

local function weaponIsFirearm(wep)
    if not IsValid(wep) then return false end
    if nonFirearm[wep:GetClass()] then return false end
    return wep:GetMaxClip1() > 0 or wep:GetPrimaryAmmoType() >= 0
end

local function hasFirearm(ent, curTime)
    local fired = firedRecently[ent]
    if fired and curTime - fired <= 10 then return true end

    local c = firearmCache[ent]
    if c and curTime - c.t < 2 then return c.v end

    local result = false
    if ent.GetActiveWeapon then
        result = weaponIsFirearm(ent:GetActiveWeapon())
    end
    if not result and ent.CapabilitiesGet then
        result = bit.band(ent:CapabilitiesGet(), rangedCaps) ~= 0
    end

    firearmCache[ent] = { t = curTime, v = result }
    return result
end

hook.Add("EntityFireBullets", "BattleBeats_TrackShooters", function(attacker)
    if IsValid(attacker) and (attacker:IsNPC() or attacker:IsNextBot()) then
        firedRecently[attacker] = CurTime()
    end
end)

local function CheckCombatState(ply)
    if not IsValid(ply) then return end

    local curTime = CurTime()

    local combatEnabled = ply:GetInfoNum("battlebeats_enable_combat", 1)
    if combatEnabled == 0 then
        sendState(ply, false, 0, 0, curTime)
        return
    end

    if not ply:Alive() then
        enemyMemory[ply] = nil
        enemySpotted[ply] = nil
        sendState(ply, false, 0, 0, curTime)
        return
    end

    local isInCombat = false
    local score = 0
    local close = 0
    /*local shotTime = incomingShots[ply]
    if shotTime then
        if (curTime - shotTime) <= 10 then
            isInCombat = true
        else
            incomingShots[ply] = nil
        end
    end*/

    if not isSinglePlayer and pvpEnabled:GetBool() then
        local mode = pvpMode:GetInt()
        if mode == 0 then -- until death
            if playerCombatTargets[ply] then
                for enemy, _ in pairs(playerCombatTargets[ply]) do
                    if IsValid(enemy) and enemy:IsPlayer() then
                        if not pvpRequireLOS:GetBool() or ply:IsLineOfSightClear(enemy) then
                            isInCombat = true
                            break
                        end
                    end
                end
            end
        elseif mode == 1 then -- timeout
            if playerCombatTargets[ply] then
                for enemy, lastHit in pairs(playerCombatTargets[ply]) do
                    if IsValid(enemy) and enemy:IsPlayer() and (curTime - lastHit) <= pvpCombatTime:GetInt() then
                        if not pvpRequireLOS:GetBool() or ply:IsLineOfSightClear(enemy) then
                            isInCombat = true
                            break
                        end
                    end
                end
            end
        elseif mode == 2 then -- visible/near
            for _, other in player.Iterator() do
                if other ~= ply and IsValid(other) and other:IsPlayer() then
                    if ply:Team() ~= other:Team() then
                        local dist = ply:GetPos():DistToSqr(other:GetPos())
                        if dist <= (maxDistancePVP:GetInt() ^ 2) then
                            if not pvpRequireLOS:GetBool() or ply:IsLineOfSightClear(other) then
                                isInCombat = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if not isInCombat then
        local reqiresLos = tobool(ply:GetInfoNum("battlebeats_detection_mode", 1))
        local NPCfightTriggersCombat = tobool(ply:GetInfoNum("battlebeats_npc_combat", 0))
        local plyPos = ply:GetPos()
        local nearbyEnts = ents.FindInSphere(plyPos, maxDistance:GetInt())
        local mem = enemyMemory[ply]
        if not mem then
            mem = {}
            enemyMemory[ply] = mem
        end
        local spot = enemySpotted[ply]
        if not spot then
            spot = {}
            enemySpotted[ply] = spot
        end
        local fov = povAngle:GetFloat()
        local ctx = {
            povOff = fov >= 360,
            plyPos = plyPos,
            eyePos = ply:EyePos(),
            fwd = ply:EyeAngles():Forward(),
            cosHalf = math.cos(math.rad(fov * 0.5)),
            nearSqr = povNearDistance:GetFloat() ^ 2
        }
        local ec = 0
        for _, ent in ipairs(nearbyEnts) do
            if (ent:IsNPC() or ent:IsNextBot()) and ent.GetEnemy then
                local enemy = ent:GetEnemy()
                if IsValid(enemy) and (enemy == ply or (NPCfightTriggersCombat and (enemy:IsNPC() or enemy:IsNextBot() or enemy:IsPlayer()))) then
                    local class = ent:GetClass()
                    if not BATTLEBEATS_server.ignoredNPCs[class] then
                        local weight = 1
                        if reqiresLos then
                            if canNoticeNPC(ply, ent, ctx, curTime, spot) then
                                mem[ent] = curTime
                            else
                                local seen = mem[ent]
                                local age = seen and (curTime - seen)
                                weight = (age and age <= memoryTime) and 1 * (1 - age / memoryTime) or 0
                            end
                        end
                        if weight > 0 then
                            if hasFirearm(ent, curTime) then
                                weight = weight * 2
                            end
                            ec = ec + weight
                            debugPVETrigger(ply, ent)
                            isInCombat = true
                            if plyPos:DistToSqr(ent:GetPos()) <= closeRadiusSqr then
                                close = close + 1
                            end
                        end
                    end
                end
            end
        end
        for e, t in pairs(mem) do
            if not IsValid(e) or curTime - t > memoryTime then mem[e] = nil end
        end
        for e, t in pairs(spot) do
            if not IsValid(e) or curTime - t > povGrace then spot[e] = nil end
        end
        if isInCombat and tobool(ply:GetInfoNum("battlebeats_dynamic_volume", 1)) then
            local hp, mx = math.max(ply:Health(), 0), math.max(ply:GetMaxHealth(), 1)
            local hpPct = hp / mx
            local dmg = 0
            local d = npcDamage[ply]
            if d then
                local minT = math.floor((curTime - 30) / dmgWindow) * dmgWindow
                for t, v in pairs(d) do
                    if t >= minT then
                        dmg = dmg + v
                    else
                        d[t] = nil
                    end
                end
            end
            local dmgPct = dmg / mx

            score = (hpPct <= 0.25 and 5 or hpPct <= 0.5 and 3 or hpPct <= 0.75 and 1 or 0)
            score = score + (ec >= 11 and 10 or ec >= 7 and 5 or ec >= 4 and 3 or ec >= 1 and 1 or 0)
            score = score + (dmgPct >= 0.25 and 4 or dmgPct >= 0.1 and 3 or dmgPct > 0 and 2 or 0)
        end
    end

    if not isInCombat and not isSinglePlayer and pvpMode:GetInt() == 1 and playerCombatTargets[ply] then
        for enemy, lastHit in pairs(playerCombatTargets[ply]) do
            if (curTime - lastHit) > pvpCombatTime:GetInt() then
                playerCombatTargets[ply][enemy] = nil
            end
        end
        if table.IsEmpty(playerCombatTargets[ply]) then
            playerCombatTargets[ply] = nil
        end
    end

    sendState(ply, isInCombat, math.Clamp(score, 0, 63), math.Clamp(close, 0, 255), curTime)
end

hook.Add("PlayerHurt", "BattleBeats_PVPCombat", function(victim, attacker)
    if not pvpEnabled:GetBool() or game.SinglePlayer() then return end
    if not IsValid(victim) or not IsValid(attacker) then return end
    if not victim:IsPlayer() or not attacker:IsPlayer() then return end
    if victim == attacker then return end
    if victim:Team() == attacker:Team() and not pvpTeam:GetBool() then return end

    local curTime = CurTime()

    playerCombatTargets[victim] = playerCombatTargets[victim] or {}
    playerCombatTargets[attacker] = playerCombatTargets[attacker] or {}

    playerCombatTargets[victim][attacker] = curTime
    playerCombatTargets[attacker][victim] = curTime
end)

hook.Add("PlayerHurt", "BattleBeats_NPCDamage", function(victim, attacker, health, damage)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if not IsValid(attacker) or (not attacker:IsNPC() and not attacker:IsNextBot()) then return end
    local t = CurTime()
    local w = math.floor(t / dmgWindow) * dmgWindow
    npcDamage[victim] = npcDamage[victim] or {}
    npcDamage[victim][w] = (npcDamage[victim][w] or 0) + damage
    local sp = enemySpotted[victim]
    if not sp then
        sp = {}
        enemySpotted[victim] = sp
    end
    sp[attacker] = t
end)

/*local rad = math.rad
local cos = math.cos
hook.Add("EntityFireBullets", "BattleBeats_NearbyBullets", function(attacker, bullet)
    if not shotsNearTrigger:GetBool() then return end
    if not bullet or not bullet.Src or not bullet.Dir then return end

    local start = bullet.Src
    local dir = bullet.Dir:GetNormalized()
    local maxDist = maxDistance:GetInt()
    local maxDistSqr = maxDist * maxDist

    for _, ply in player.Iterator() do
        if ply == attacker then continue end
        if not IsValid(ply) or not ply:Alive() then continue end
        if IsValid(attacker) and attacker:IsPlayer() then
            if ply:Team() == attacker:Team() and not pvpTeam:GetBool() then
                continue
            end
        end

        local toPly = ply:GetPos() - start
        if toPly:LengthSqr() > maxDistSqr then continue end

        local dirToPly = toPly:GetNormalized()
        local dot = dir:Dot(dirToPly)

        if dot > cos(rad(45)) then
            incomingShots[ply] = CurTime()
        end
    end
end)*/

hook.Add("PlayerDeath", "BattleBeats_EndCombatOnDeath", function(victim)
    if game.SinglePlayer() then return end
    if not IsValid(victim) or not victim:IsPlayer() then return end

    if playerCombatTargets[victim] then
        for enemy in pairs(playerCombatTargets[victim]) do
            if playerCombatTargets[enemy] then
                playerCombatTargets[enemy][victim] = nil
            end
        end
        playerCombatTargets[victim] = nil
    end

    npcDamage[victim] = nil
    enemySpotted[victim] = nil
    incomingShots[victim] = nil
end)

hook.Add("PlayerDisconnected", "BattleBeats_CleanCombatState", function(ply)
    if playerCombatTargets[ply] then
        for enemy in pairs(playerCombatTargets[ply]) do
            if playerCombatTargets[enemy] then
                playerCombatTargets[enemy][ply] = nil
            end
        end
        playerCombatTargets[ply] = nil
    end

    npcDamage[ply] = nil
    enemyMemory[ply] = nil
    enemySpotted[ply] = nil
    incomingShots[ply] = nil
    lastSent[ply] = nil
end)

timer.Create("BattleBeats_CombatCheck", 0.5, 0, function()
    for _, ply in player.Iterator() do
        local success, err = pcall(function() CheckCombatState(ply) end)
        if not success then
            print("[BattleBeats] BattleBeats_CombatCheck error: " .. tostring(err))
        end
    end
end)

hook.Add("OnDamagedByExplosion", "BattleBeats_ExplosionFade", function(ply, dmg)
    if dmg:GetDamage() > 35 then
        net.Start("BTB_ExplosionFade")
        net.Send(ply)
    end
end)

net.Receive("BTB_Change_ConVar", function(len, ply)
    if not ply:IsSuperAdmin() then return end
    local conVar = net.ReadString()
    local value = net.ReadFloat()
    if conVar == "" then return end
    if not string.StartWith(conVar, "battlebeats_") then return end
    if not GetConVar(conVar) then return end
    RunConsoleCommand(conVar, tostring(value))
end)
