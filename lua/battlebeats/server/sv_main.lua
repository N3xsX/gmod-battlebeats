BATTLEBEATS_server = BATTLEBEATS_server or {}

util.AddNetworkString("BTB_Change_ConVar")
util.AddNetworkString("BTB_ThreatDebug")
util.AddNetworkString("BTB_ExplosionFade")

local lastCombatTime = {}
local playerCombatTargets = {}
local incomingShots = {}
local npcDamage = {}
local combatThreat = {}
local threatChange = {}

--local combatCooldown = GetConVar("battlebeats_server_combat_cooldown")
local maxDistance = GetConVar("battlebeats_server_max_distance")
local pvpEnabled = GetConVar("battlebeats_pvp_enable")
local pvpMode = GetConVar("battlebeats_pvp_mode")
local pvpCombatTime = GetConVar("battlebeats_pvp_combat_time")
local pvpTeam = GetConVar("battlebeats_pvp_allow_team_combat")
local pvpRequireLOS = GetConVar("battlebeats_pvp_lineofsight")
local maxDistancePVP = GetConVar("battlebeats_pvp_max_distance")
local shotsNearTrigger = GetConVar("battlebeats_pvp_near_shots_trigger_combat")

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

local tc = { [1] = 12, [2] = 15, [3] = 20 }
local isSinglePlayer = game.SinglePlayer()
local dmgWindow = 5
local function CheckCombatState(ply)
    if not IsValid(ply) then return end

    local combatEnabled = ply:GetInfoNum("battlebeats_enable_combat", 1)
    if combatEnabled == 0 then
        ply:SetNWBool("BattleBeats_InCombat", false)
        ply:SetNWBool("BattleBeats_HasCombatEnemy", false)
        ply:SetNWInt("BattleBeats_ThreatLevel", 1)
        return
    end

    local curTime = CurTime()
    local isInCombat = false
    local threat = 1
    /*local shotTime = incomingShots[ply]
    if shotTime then
        if (curTime - shotTime) <= 10 then
            isInCombat = true
            lastCombatTime[ply] = curTime
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
                            lastCombatTime[ply] = curTime
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
                            lastCombatTime[ply] = curTime
                            break
                        end
                    end
                end
            end
        elseif mode == 2 then -- visible/near
            for _, other in ipairs(player.GetAll()) do
                if other ~= ply and IsValid(other) and other:IsPlayer() then
                    if ply:Team() ~= other:Team() then
                        local dist = ply:GetPos():DistToSqr(other:GetPos())
                        if dist <= (maxDistancePVP:GetInt() ^ 2) then
                            if not pvpRequireLOS:GetBool() or ply:IsLineOfSightClear(other) then
                                isInCombat = true
                                lastCombatTime[ply] = curTime
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
        local ec = 0
        for _, ent in ipairs(nearbyEnts) do
            if (ent:IsNPC() or ent:IsNextBot()) and ent.GetEnemy then
                local enemy = ent:GetEnemy()
                if IsValid(enemy) and (enemy == ply or (NPCfightTriggersCombat and (enemy:IsNPC() or enemy:IsNextBot() or enemy:IsPlayer()))) then
                    local class = ent:GetClass()
                    if not BATTLEBEATS_server.ignoredNPCs[class] then
                        local los = not reqiresLos or ply:IsLineOfSightClear(ent)
                        if los then
                            ec = ec + 1
                            debugPVETrigger(ply, ent)
                            isInCombat = true
                            lastCombatTime[ply] = curTime
                        end
                    end
                end
            end
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

            local s = (hpPct <= 0.25 and 5 or hpPct <= 0.5 and 3 or hpPct <= 0.75 and 1 or 0)
            s = s + (ec >= 11 and 10 or ec >= 7 and 5 or ec >= 4 and 3 or ec >= 1 and 1 or 0)
            s = s + (dmgPct >= 0.25 and 4 or dmgPct >= 0.1 and 3 or dmgPct > 0 and 2 or 0)

            local want = s >= 10 and 3 or s >= 5 and 2 or 1
            local cur = ply:GetNWInt("BattleBeats_ThreatLevel", 1)
            local ct = threatChange[ply] or 0

            if want > cur then
                threat = want
                threatChange[ply] = curTime
            elseif want < cur and curTime - ct >= 5 then
                threat = want
                threatChange[ply] = curTime
            else
                threat = cur
            end

            combatThreat[ply] = ply:Alive() and math.max(combatThreat[ply] or 1, threat) or -1

            /*net.Start("BTB_ThreatDebug")
            net.WriteUInt(ec or 0, 8)
            net.WriteUInt(math.Clamp(math.Round(hpPct * 100), 0, 100), 7)
            net.WriteUInt(math.Clamp(dmg, 0, 65535), 16)
            net.WriteUInt(math.Clamp(s, 0, 31), 5)
            net.WriteUInt(combatThreat[ply] or 1, 2)
            net.WriteBool(isInCombat)
            net.Send(ply)*/
        end
    end

    ply:SetNWBool("BattleBeats_HasCombatEnemy", isInCombat)
    ply:SetNWInt("BattleBeats_ThreatLevel", threat)

    if isInCombat then
        ply:SetNWBool("BattleBeats_InCombat", true)
    else
        local ct = combatThreat[ply] or -1
        local cd = tc[ct] or 1
        if lastCombatTime[ply] and (curTime - lastCombatTime[ply]) >= cd then
            ply:SetNWBool("BattleBeats_InCombat", false)
            ply:SetNWInt("BattleBeats_ThreatLevel", 1)
            combatThreat[ply] = nil
            threatChange[ply] = nil
            if not isSinglePlayer and pvpMode:GetInt() == 1 then
                for enemy, lastHit in pairs(playerCombatTargets[ply] or {}) do
                    if (curTime - lastHit) > pvpCombatTime:GetInt() then
                        playerCombatTargets[ply][enemy] = nil
                    end
                end
                if table.IsEmpty(playerCombatTargets[ply] or {}) then
                    playerCombatTargets[ply] = nil
                end
            end
        end
    end
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

    lastCombatTime[victim] = curTime
    lastCombatTime[attacker] = curTime
end)

hook.Add("PlayerHurt", "BattleBeats_NPCDamage", function(victim, attacker, health, damage)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if not IsValid(attacker) or (not attacker:IsNPC() and not attacker:IsNextBot()) then return end
    local t = CurTime()
    local w = math.floor(t / dmgWindow) * dmgWindow
    npcDamage[victim] = npcDamage[victim] or {}
    npcDamage[victim][w] = (npcDamage[victim][w] or 0) + damage
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

    for _, ply in ipairs(player.GetAll()) do
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
    combatThreat[victim] = nil
    threatChange[victim] = nil
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
    combatThreat[ply] = nil
    threatChange[ply] = nil
    incomingShots[ply] = nil
    lastCombatTime[ply] = nil
end)

timer.Create("BattleBeats_CombatCheck", 0.5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
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