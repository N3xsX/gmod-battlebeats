local lastCombatTime = {}
local playerCombatTargets = {}

local combatCooldown = CreateConVar("battlebeats_server_combat_cooldown", "5", { FCVAR_ARCHIVE }, "", 3, 30)
local maxDistance = CreateConVar("battlebeats_server_max_distance", "5000", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "", 100, 10000)
local pvpEnabled = CreateConVar("battlebeats_pvp_enable", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "", 0, 1)
local pvpMode = CreateConVar("battlebeats_pvp_mode", "1", { FCVAR_ARCHIVE }, "", 0, 2)
local pvpCombatTime = CreateConVar("battlebeats_pvp_combat_time", "30", { FCVAR_ARCHIVE }, "", 5, 120)
local pvpTeam = CreateConVar("battlebeats_pvp_allow_team_combat", "1", { FCVAR_ARCHIVE }, "", 0, 1)
local pvpRequireLOS = CreateConVar("battlebeats_pvp_lineofsight", "0", { FCVAR_ARCHIVE }, "", 0, 1)
local maxDistancePVP = CreateConVar("battlebeats_pvp_max_distance", "5000", { FCVAR_ARCHIVE }, "", 100, 10000)

resource.AddFile("materials/btb.png")
resource.AddFile("materials/btbdmc.jpg")
resource.AddFile("materials/btbzzz.jpg")
resource.AddFile("materials/btbtw3.jpg")
resource.AddFile("sound/btb_button_enable.mp3")
resource.AddFile("sound/btb_button_disable.mp3")
resource.AddFile("sound/btb_ui_exit.mp3")

local function CheckCombatState(ply)
    if not IsValid(ply) then return end

    local combatEnabled = ply:GetInfoNum("battlebeats_enable_combat", 1)
    if combatEnabled == 0 then
        ply:SetNWBool("BattleBeats_InCombat", false)
        return
    end

    local curTime = CurTime()
    local isInCombat = false
    local isSinglePlayer = game.SinglePlayer()

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
        for _, ent in ipairs(nearbyEnts) do
            if (ent:IsNPC() or ent:IsNextBot()) and ent.GetEnemy then
                local enemy = ent:GetEnemy()
                if IsValid(enemy) and (enemy == ply or (NPCfightTriggersCombat and (enemy:IsNPC() or enemy:IsNextBot() or enemy:IsPlayer()))) then
                    if not reqiresLos or ply:IsLineOfSightClear(ent) then
                        isInCombat = true
                        lastCombatTime[ply] = curTime
                        break
                    end
                end
            end
        end
    end

    if isInCombat then
        ply:SetNWBool("BattleBeats_InCombat", true)
    else
        if lastCombatTime[ply] and (curTime - lastCombatTime[ply]) >= combatCooldown:GetInt() then
            ply:SetNWBool("BattleBeats_InCombat", false)
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

    lastCombatTime[ply] = nil
end)

timer.Create("BattleBeats_CombatCheck", 1, 0, function()
    for _, ply in pairs(player.GetAll()) do
        local success, err = pcall(function() CheckCombatState(ply) end)
        if not success then
            print("[BattleBeats] BattleBeats_CombatCheck error: " .. tostring(err))
        end
    end
end)