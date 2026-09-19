local btb = BATTLEBEATS
local allowEnforce = GetConVar("battlebeats_allow_server")

net.Receive("BTB_Send_Sound", function()
    local sound = net.ReadString()
    if not allowEnforce:GetBool() then
        print("[BattleBeats Client] Server tried to enforce sound: " .. tostring(sound))
        return
    end
    if not file.Exists(sound, "GAME") then
        print("[BattleBeats Client] Server tried to enforce sound but it doesnt exist! | " .. tostring(sound))
        return
    end
    if btb.currentPreviewStation and IsValid(btb.currentPreviewStation) then
        btb.FadeMusic(btb.currentPreviewStation, nil, 0.5)
    end
    print("[BattleBeats Client] Enforcing sound: " .. tostring(sound))
    btb.PlayNextTrack(sound, nil, 1, 1)
end)

/*net.Receive("BTB_Server_Radio", function()
    local sound = net.ReadString()
    if not allowEnforce:GetBool() then
        print("[BattleBeats Client] Server tried to enforce sound: " .. tostring(sound))
        return
    end
    if not file.Exists(sound, "GAME") then
        print("[BattleBeats Client] Server tried to enforce sound but it doesnt exist! | " .. tostring(sound))
        return
    end
    btb.serverTrack = sound
    local pp = {isServer = true}
    btb.PlayNextTrack(sound, nil, nil, nil, nil, pp)
end)*/
