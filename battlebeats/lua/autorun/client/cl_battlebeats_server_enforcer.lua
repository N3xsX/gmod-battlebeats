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
    if BATTLEBEATS.currentPreviewStation and IsValid(BATTLEBEATS.currentPreviewStation) then
        BATTLEBEATS.FadeMusic(BATTLEBEATS.currentPreviewStation, nil, 0.5)
    end
    print("[BattleBeats Client] Enforcing sound: " .. tostring(sound))
    BATTLEBEATS.PlayNextTrack(sound)
end)