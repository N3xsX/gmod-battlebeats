BATTLEBEATS = BATTLEBEATS or {}

local targetVolume = 1
local currentStation = nil
local currentPreviewStation = nil

local isInCombat = false
local lastCombatState = false

local lastAmbienceLength = 0
local lastAmbienceTotalLength = nil
local lastAmbienceTrack = nil
local lastAmbiencePosition = nil
local combatStartTime = nil

local lastCombatLength = 0
local lastCombatTotalLength = nil
local lastCombatTrack = nil
local lastCombatPosition = nil
local ambienceStartTime = nil

local isAlive = true
local lastMuteState = false
local lastAliveState = true
local fadeStartTime = nil
local isPreviewing = false

BATTLEBEATS.currentStation = nil
BATTLEBEATS.currentPreviewStation = nil
BATTLEBEATS.currentPreviewPosition = nil
BATTLEBEATS.currentPreviewTrack = nil
BATTLEBEATS.frame = nil
BATTLEBEATS.currentPacks = {}
BATTLEBEATS.musicPacks = {}
BATTLEBEATS.excludedTracks = {}
BATTLEBEATS.favoriteTracks = {}
BATTLEBEATS.isInCombat = false

CreateClientConVar("battlebeats_detection_mode", "1", true, true, "", 0, 1)
CreateClientConVar("battlebeats_npc_combat", "0", true, true, "", 0, 1)

local volumeSet = CreateClientConVar("battlebeats_volume", "100", true, false, "", 0, 1000)
local debugMode = CreateClientConVar("battlebeats_debug_mode", "0", true, false, "", 0, 1)
local ambientWaitTime = CreateClientConVar("battlebeats_ambient_wait_time", "40", true, false)
local combatWaitTime = CreateClientConVar("battlebeats_combat_wait_time", "40", true, false)
local enableAmbient = CreateClientConVar("battlebeats_enable_ambient", "1", true, false, "", 0, 1)
local enableCombat = CreateClientConVar("battlebeats_enable_combat", "1", true, true, "", 0, 1)
local disableMode = CreateClientConVar("battlebeats_disable_mode", "0", true, false, "", 0, 2)
local persistentNotification = CreateClientConVar("battlebeats_persistent_notification", "0", true, false, "", 0, 1)
local showNotification = CreateClientConVar("battlebeats_show_notification", "1", true, false, "", 0, 1)
local replayNotification = CreateClientConVar("battlebeats_show_notification_after_continue", "0", true, false, "", 0, 1)
local exclusivePlay = CreateClientConVar("battlebeats_exclusive_play", "0", true, false, "", 0, 1)
local alwaysContinue = CreateClientConVar("battlebeats_always_continue", "0", true, false, "", 0, 1)
local continueMode = CreateClientConVar("battlebeats_continue_mode", "0", true, false, "", 0, 1)
local showPreviewNotification = CreateClientConVar("battlebeats_show_preview_notification", "1", true, false, "", 0, 1)
local lowerInMenu = CreateClientConVar("battlebeats_lower_volume_in_menu", "0", true, false, "", 0, 1)

local ambientVolume = CreateClientConVar("battlebeats_volume_ambient", "100", true, false, "", 0, 100)
local combatVolume = CreateClientConVar("battlebeats_volume_combat", "100", true, false, "", 0, 100)

local muteVolume = nil

local function debugPrint(...)
    if debugMode:GetBool() then print("[BattleBeats Debug] " .. ...) end
end

function BATTLEBEATS.ValidatePacks()
    local hasAmbient, hasCombat = false, false

    for packName in pairs(BATTLEBEATS.currentPacks) do
        local pack = BATTLEBEATS.musicPacks[packName]
        if pack then
            if pack.ambient and #pack.ambient > 0 then hasAmbient = true end
            if pack.combat and #pack.combat > 0 then hasCombat = true end
        end
    end

    local wasAmbientAutoDisabled = cookie.GetNumber("battlebeats_auto_disabled_ambient", 0) == 1
    local wasCombatAutoDisabled  = cookie.GetNumber("battlebeats_auto_disabled_combat", 0) == 1

    if not hasAmbient and enableAmbient:GetBool() then
        RunConsoleCommand("battlebeats_enable_ambient", "0")
        cookie.Set("battlebeats_auto_disabled_ambient", "1")
    elseif hasAmbient and wasAmbientAutoDisabled then
        RunConsoleCommand("battlebeats_enable_ambient", "1")
        cookie.Set("battlebeats_auto_disabled_ambient", "0")
    end

    if not hasCombat and enableCombat:GetBool() then
        RunConsoleCommand("battlebeats_enable_combat", "0")
        cookie.Set("battlebeats_auto_disabled_combat", "1")
    elseif hasCombat and wasCombatAutoDisabled then
        RunConsoleCommand("battlebeats_enable_combat", "1")
        cookie.Set("battlebeats_auto_disabled_combat", "0")
    end
end

--MARK:Music Fade
--------------------------------------------------------------------------------------

local function RemoveSoundTimers()
    if timer.Exists("BattleBeats_NextTrack") then timer.Remove("BattleBeats_NextTrack") end
    if timer.Exists("BattleBeats_CheckSound") then timer.Remove("BattleBeats_CheckSound") end
end

local function FadeMusic(station, fadeIn, fadeTime, isPreview)
    if not IsValid(station) then return end
    fadeTime = fadeTime or 2
    local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
    local masterVolume = volumeSet:GetInt() / 100
    local targetVolume = muteVolume or ((volumeType / 100) * masterVolume)
    if isPreview then targetVolume = muteVolume or masterVolume end

    local startVolume = fadeIn and 0 or station:GetVolume()
    local endVolume = fadeIn and targetVolume or 0
    local startTime = CurTime()
    local timerName = "BattleBeats_Fade_" .. tostring(station)

    debugPrint("[FadeMusic] Start " .. (fadeIn and "IN " or "OUT ") .. tostring(station) .. " targetVolume: " .. tostring(targetVolume))

    timer.Simple(fadeTime + 0.1, function() -- plz god no more ghost tracks
        if not fadeIn and IsValid(station) then
            debugPrint("[FadeMusic][Failsafe] Stopping station " .. tostring(station))
            station:SetVolume(0)
            station:Stop()
        end
    end)
    
    timer.Create(timerName, 0.03, fadeTime / 0.03, function()
        if not IsValid(station) then
            debugPrint("[FadeMusic] Station invalid, removing timer " .. tostring(station))
            timer.Remove(timerName)
            return
        end
        local progress = math.min((CurTime() - startTime) / fadeTime, 1)
        local vol = Lerp(progress, startVolume, endVolume)
        station:SetVolume(vol)
        if progress >= 0.95 and not fadeIn then
            debugPrint("[FadeMusic] Fade out complete, stopping station " .. tostring(station))
            station:SetVolume(0)
            station:Stop()
            timer.Remove(timerName)
        elseif progress >= 0.95 and fadeIn then -- this is redundant but well it looks nice :)
            debugPrint("[FadeMusic] Fade in complete, removing timer " .. tostring(station))
            timer.Remove(timerName)
        end
    end)
end

function BATTLEBEATS.FadeMusic(station, fadeIn, fadeTime, isPreview)
    FadeMusic(station, fadeIn, fadeTime, isPreview)
end

--MARK:Random track
--------------------------------------------------------------------------------------

local function AreTracksFromSamePack(trackA, trackB)
    local packA, packB = nil, nil

    for packName in pairs(BATTLEBEATS.currentPacks) do
        local pack = BATTLEBEATS.musicPacks[packName]
        if not pack then continue end

        for _, category in ipairs({ pack.combat or {}, pack.ambient or {} }) do
            for _, track in ipairs(category) do
                if track == trackA then
                    packA = packName
                    debugPrint("[AreTracksFromSamePack] Found trackA in pack: " .. packA)
                end
                if track == trackB then
                    packB = packName
                    debugPrint("[AreTracksFromSamePack] Found trackB in pack: " .. packB)
                end
                if packA and packB then
                    local same = packA == packB
                    debugPrint("[AreTracksFromSamePack] Same pack: " .. tostring(same))
                    return same, packA, packB
                end
            end
        end
    end
    debugPrint("[AreTracksFromSamePack] One or both tracks not found. packA: ", packA, "packB:", packB)
    return false, packA, packB
end

local function GetRandomTrack(packs, isCombat, excluded, lastTrack2, exclusivePlayOnly)
    if not packs or table.IsEmpty(packs) then
        debugPrint("[GetRandomTrack] No packs provided")
        return nil
    end
    if (isCombat and not enableCombat:GetBool()) or
        (not isCombat and not enableAmbient:GetBool()) then
        return nil
    end
    local allTracks = {}
    if exclusivePlay:GetBool() and lastTrack2 and exclusivePlayOnly then
        local samePack, packName = AreTracksFromSamePack(lastTrack2, lastTrack2) -- restrict to same pack if exclusive play is enabled
        debugPrint("[GetRandomTrack] Exclusive play enabled. Using pack: " .. packName)
        if samePack and packName and BATTLEBEATS.musicPacks[packName] then
            local selectedTracks = isCombat and BATTLEBEATS.musicPacks[packName].combat or BATTLEBEATS.musicPacks[packName].ambient
            if selectedTracks and #selectedTracks > 0 then
                for _, t in ipairs(selectedTracks) do
                    table.insert(allTracks, t)
                end
            else
                debugPrint("[GetRandomTrack] Selected pack is empty. Falling back to all")
                for packName, _ in pairs(packs) do -- fallback: use all tracks from allowed packs
                    if BATTLEBEATS.musicPacks[packName] then
                        local tracks = isCombat and BATTLEBEATS.musicPacks[packName].combat or BATTLEBEATS.musicPacks[packName].ambient
                        for _, track in ipairs(tracks or {}) do
                            table.insert(allTracks, track)
                        end
                    end
                end
            end
        end
    else
        for packName, _ in pairs(packs) do --not in exclusive mode: use all tracks from all selected pack
            if BATTLEBEATS.musicPacks[packName] then
                local tracks = isCombat and BATTLEBEATS.musicPacks[packName].combat or BATTLEBEATS.musicPacks[packName].ambient
                for _, track in ipairs(tracks) do
                    table.insert(allTracks, track)
                end
            end
        end
    end
    debugPrint("[GetRandomTrack] Found " .. #allTracks .. " tracks before exclusion")
    excluded = excluded or BATTLEBEATS.excludedTracks
    if #allTracks > 0 then
        local availableTracks = {}
        for _, track in ipairs(allTracks) do -- filter out excluded tracks
            if not excluded[track] then table.insert(availableTracks, track) end
        end
        debugPrint("[GetRandomTrack] Available after exclusion: " .. #availableTracks)
        if #availableTracks > 1 then
            local lastTrack = isCombat and lastCombatTrack or lastAmbienceTrack -- get last played track
            if lastTrack then
                local filteredTracks = {}
                for _, track in ipairs(availableTracks) do
                    if track ~= lastTrack then
                        table.insert(filteredTracks, track) -- avoid repeating the last track
                    end
                end
                availableTracks = filteredTracks
            end
        end
        if #availableTracks > 0 then
            return availableTracks[math.random(#availableTracks)]
        else
            notification.AddLegacy("All tracks are excluded! Playing random one!", NOTIFY_ERROR, 4)
            return allTracks[math.random(#allTracks)] -- fallback: return random track even if excluded
        end
    end
    return nil
end

function BATTLEBEATS.GetRandomTrack(packs, isCombat, excluded, lastTrack2, exclusivePlayOnly)
    return GetRandomTrack(packs, isCombat, excluded, lastTrack2, exclusivePlayOnly)
end

local function printStationError(track, errCode, errStr)
    notification.AddLegacy("Failed to play sound! Check the console for details", NOTIFY_ERROR, 4)
    MsgC(
        Color(255, 255, 0), "[BattleBeats Client] ",
        Color(255, 255, 255), "Error playing sound: ",
        Color(255, 255, 0), track .. " ",
        Color(255, 255, 255), "Code: ",
        Color(0, 255, 255), tostring(errCode) .. " ",
        Color(255, 255, 255), "Error: ",
        Color(255, 0, 255), errStr .. "\n"
    )
end

--MARK:Music Player
--------------------------------------------------------------------------------------

local function PlayNextTrackPreview(track, time, isLooped, errCallback)
    RemoveSoundTimers()
    if currentStation and IsValid(currentStation) then
        FadeMusic(currentStation, false)
    end
    if currentPreviewStation and IsValid(currentPreviewStation) then
        FadeMusic(currentPreviewStation, false)
    end
    if showPreviewNotification:GetBool() and not isLooped then BATTLEBEATS.ShowTrackNotification(track, false, true) end
    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if IsValid(station) then
            isPreviewing = true
            currentPreviewStation = station
            BATTLEBEATS.currentPreviewStation = station
            station:SetVolume(0)
            station:Play()
            station:SetTime(time or 0, true)
            FadeMusic(station, true, 2, true)
        else
            timer.Simple(2, function ()
                BATTLEBEATS.HideNotification()
            end)
            printStationError(track, errCode, errStr)
            if errCallback then
                errCallback(track, errCode, errStr)
            end
        end
    end)
end

function BATTLEBEATS.PlayNextTrackPreview(track, time, isLooped, errCallback)
    PlayNextTrackPreview(track, time, isLooped, errCallback)
end

local function PlayNextTrack(track, time, noFade)
    if not track or track == "" then
        debugPrint("[PlayNextTrack] Attempted to play nil/empty track! Aborting...")
        return
    end
    debugPrint("[PlayNextTrack] Starting playback for track: " .. tostring(track))
    debugPrint("[PlayNextTrack] Start time: " .. tostring(math.Truncate(time or 0, 1)) .. " (s) | No fade: " .. tostring(tobool(noFade)))
    if currentStation and IsValid(currentStation) then
        FadeMusic(currentStation, false)
    end

    -- store last track info based on combat state
    if not isInCombat then
        lastAmbienceTrack = track
        lastAmbienceLength = 0
    else
        lastCombatTrack = track
        lastCombatLength = 0
    end

    if (not time or replayNotification:GetBool() or persistentNotification:GetBool())
        and showNotification:GetBool()
        and volumeSet:GetInt() > 0 then
        BATTLEBEATS.ShowTrackNotification(track, isInCombat)
    end

    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if IsValid(station) then
            isPreviewing = false
            currentStation = station
            BATTLEBEATS.currentStation = station
            station:SetVolume(0)
            station:Play()
            station:SetTime(time or 0, true)
            local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
            local masterVolume = volumeSet:GetInt() / 100
            if not noFade then
                FadeMusic(station, true)
            else
                station:SetVolume((volumeType / 100) * masterVolume)
                --station:SetVolume(volumeSet:GetInt() / 100)
            end

            RemoveSoundTimers()

            --instantly store the current music position to prevent rare issue
            --where a newly switched track would incorrectly use the position of the previous one
            --(only saw this twice in 40+ hours of gameplay but hey might as well fix it)
            if not isInCombat then
                lastAmbiencePosition = station:GetTime()
                lastAmbienceTotalLength = station:GetLength()
            else
                lastCombatPosition = station:GetTime()
                lastCombatTotalLength = station:GetLength()
            end

            local startTime = time or 0
            local trackLength = station:GetLength()
            local playDuration = math.max(trackLength - startTime - 1, 1)

            debugPrint("[PlayNextTrack] Track length: " .. math.Truncate(trackLength or 0, 1) .. " (s) | Will play for: " .. math.Truncate(playDuration or 0, 1) .. " (s)")

            timer.Create("BattleBeats_NextTrack", playDuration, 1, function() -- timer to play next track when current finishes
                debugPrint("[PlayNextTrack] Timer reached end. Selecting next track")
                if timer.Exists("BattleBeats_CheckSound") then timer.Remove("BattleBeats_CheckSound") end
                if not table.IsEmpty(BATTLEBEATS.currentPacks) then
                    local nextTrack = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks)
                    if nextTrack then PlayNextTrack(nextTrack) end
                end
            end)

            timer.Create("BattleBeats_CheckSound", 1, 0, function() -- timer to check if track stops playing unexpectedly
                if not IsValid(station) or station:GetState() ~= GMOD_CHANNEL_PLAYING then
                    debugPrint("[PlayNextTrack] Track stopped unexpectedly. Selecting next track")
                    timer.Remove("BattleBeats_CheckSound")
                    if timer.Exists("BattleBeats_NextTrack") then timer.Remove("BattleBeats_NextTrack") end
                    if not table.IsEmpty(BATTLEBEATS.currentPacks) then
                        local nextTrack = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks)
                        if nextTrack then PlayNextTrack(nextTrack) end
                    end
                end
                -- update playback length and position
                if IsValid(station) then
                    if not isInCombat then
                        lastAmbiencePosition = station:GetTime()
                        lastAmbienceLength = lastAmbienceLength + 1
                    else
                        lastCombatPosition = station:GetTime()
                        lastCombatLength = lastCombatLength + 1
                    end
                end
            end)
        else
            printStationError(track, errCode, errStr)
            if not table.IsEmpty(BATTLEBEATS.currentPacks) then
                local nextTrack = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks)
                if nextTrack then PlayNextTrack(nextTrack) end
            end
        end
    end)
end

function BATTLEBEATS.PlayNextTrack(track, time, noFade)
    PlayNextTrack(track, time, noFade)
end

hook.Add("PostCleanupMap", "BattleBeats_ResumeMusic", function()
    if not isPreviewing then
        if (isInCombat and not lastCombatTrack) or (not isInCombat and not lastAmbienceTrack) then return end
        PlayNextTrack(isInCombat and lastCombatTrack or lastAmbienceTrack, isInCombat and (lastCombatPosition + 1) or (lastAmbiencePosition + 1))
    else
        if not BATTLEBEATS.currentPreviewTrack then return end
        PlayNextTrackPreview(BATTLEBEATS.currentPreviewTrack, BATTLEBEATS.currentPreviewPosition)
    end
end)

--MARK:Client Timers
--------------------------------------------------------------------------------------

timer.Create("BattleBeats_ClientAliveCheck", 1, 0, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    isAlive = ply:Alive()
    if isAlive ~= lastAliveState then
        lastAliveState = isAlive
        local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
        local masterVolume = volumeSet:GetInt() / 100
        if disableMode:GetInt() == 1 then -- fade volume to 0 when dead, restore when alive
            --targetVolume = isAlive and volumeSet:GetInt() / 100 or 0
            targetVolume = isAlive and (volumeType / 100) * masterVolume or 0
            fadeStartTime = CurTime()
            if muteVolume == nil then
                muteVolume = IsValid(currentStation) and currentStation:GetVolume() or
                IsValid(currentPreviewStation) and currentPreviewStation:GetVolume()
                or targetVolume
            end
        elseif disableMode:GetInt() == 2 then -- fade volume to 30% when dead, restore when alive
            targetVolume = isAlive and (volumeType / 100) * masterVolume or 0.3
            --targetVolume = isAlive and volumeSet:GetInt() / 100 or 0.3
            fadeStartTime = CurTime()
            if muteVolume == nil then
                muteVolume = IsValid(currentStation) and currentStation:GetVolume() or
                IsValid(currentPreviewStation) and currentPreviewStation:GetVolume()
                or targetVolume
            end
        end
    end

    if isAlive and lowerInMenu:GetBool() then
        local inGameMenu = gui.IsGameUIVisible()
        local inSpawnMenu = g_SpawnMenu and g_SpawnMenu:IsVisible()
        local isMenuOpen = inGameMenu or inSpawnMenu

        local shouldMute = isMenuOpen
        if shouldMute ~= lastMuteState then
            lastMuteState = shouldMute

            local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
            local masterVolume = volumeSet:GetInt() / 100

            targetVolume = not shouldMute and (volumeType / 100) * masterVolume or 0.3
            fadeStartTime = CurTime()
            if muteVolume == nil then
                muteVolume = IsValid(currentStation) and currentStation:GetVolume()
                    or IsValid(currentPreviewStation) and currentPreviewStation:GetVolume()
                    or targetVolume
            end
        end
    end

    if fadeStartTime and (IsValid(currentStation) or IsValid(currentPreviewStation)) and targetVolume
        and not timer.Exists("BattleBeats_SmoothFade")
        and not (IsValid(currentStation) and timer.Exists("BattleBeats_Fade_" .. tostring(currentStation)))
        and not (IsValid(currentPreviewStation) and timer.Exists("BattleBeats_Fade_" .. tostring(currentPreviewStation))) then
        timer.Create("BattleBeats_SmoothFade", 0.1, 0, function()
            -- abort if a manual fade is already active
            if (IsValid(currentStation) and timer.Exists("BattleBeats_Fade_" .. tostring(currentStation))) or
                (IsValid(currentPreviewStation) and timer.Exists("BattleBeats_Fade_" .. tostring(currentPreviewStation))) then
                timer.Remove("BattleBeats_SmoothFade")
                if isAlive then muteVolume = nil end
                return
            end
            if not fadeStartTime or (not IsValid(currentStation) and not IsValid(currentPreviewStation)) or not targetVolume then
                timer.Remove("BattleBeats_SmoothFade")
                if isAlive then muteVolume = nil end
                return
            end
            local progress = math.min((CurTime() - fadeStartTime) / 2, 1)
            if muteVolume then
                muteVolume = Lerp(progress, muteVolume, targetVolume)
                if IsValid(currentStation) then currentStation:SetVolume(muteVolume) end
                if IsValid(currentPreviewStation) then currentPreviewStation:SetVolume(muteVolume) end
            end
            if progress >= 1 then
                fadeStartTime = nil
                if isAlive then muteVolume = nil end
                timer.Remove("BattleBeats_SmoothFade")
            end
        end)
    end
end)

timer.Create("BattleBeats_ClientAliveSoundCheck", 5, 0, function() -- sanity check
    if isAlive and not lastMuteState and (IsValid(currentStation) or IsValid(currentPreviewStation))
        and not timer.Exists("BattleBeats_SmoothFade")
        and not (IsValid(currentStation) and timer.Exists("BattleBeats_Fade_" .. tostring(currentStation)))
        and not (IsValid(currentPreviewStation) and timer.Exists("BattleBeats_Fade_" .. tostring(currentPreviewStation))) then
        local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
        local masterVolume = volumeSet:GetInt() / 100
        if IsValid(currentStation) then currentStation:SetVolume((volumeType / 100) * masterVolume) end
        if IsValid(currentPreviewStation) then currentPreviewStation:SetVolume(masterVolume) end
    end
end)

--MARK:State Switching
--------------------------------------------------------------------------------------

local function GetOffset(lastTrackPos, oppositeTrackLen, totalLength)
    if continueMode:GetInt() == 1 then
        if lastTrackPos + oppositeTrackLen > totalLength then -- continue only if total length allows both segments
            return nil
        else
            return lastTrackPos + oppositeTrackLen
        end
    else
        return lastTrackPos + 2
    end
end

local function TryPlayTrackWithOffset(track, offset, fallbackTrackRef, exclusiveOnly) -- plays track with offset, or falls back to a random track if not possible
    if offset then
        PlayNextTrack(track, offset)
    else
        local fallbackTrack = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, fallbackTrackRef, exclusiveOnly)
        if fallbackTrack then PlayNextTrack(fallbackTrack) end
    end
end

local function SwitchTrack()
    if IsValid(currentPreviewStation) then return end
    if not GetConVar("battlebeats_persistent_notification"):GetBool() then
        BATTLEBEATS.HideNotification()
    end
    if isInCombat then
        -- decide whether to continue last combat track or pick new one
        if (CurTime() - ambienceStartTime <= combatWaitTime:GetInt() and lastCombatTrack) or (alwaysContinue:GetBool() and lastCombatTrack) then
            if exclusivePlay:GetBool() and lastAmbienceTrack then
                local samePack = AreTracksFromSamePack(lastCombatTrack, lastAmbienceTrack)
                if not samePack then
                    -- pick a different track from same pack
                    local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, lastAmbienceTrack, true)
                    if track then PlayNextTrack(track) end
                else
                    -- continue same combat track from calculated offset
                    local offset = GetOffset(lastCombatPosition, lastAmbienceLength, lastCombatTotalLength)
                    TryPlayTrackWithOffset(lastCombatTrack, offset, lastAmbienceTrack, true)
                end
            else
                local offset = GetOffset(lastCombatPosition, lastAmbienceLength, lastCombatTotalLength)
                TryPlayTrackWithOffset(lastCombatTrack, offset, lastAmbienceTrack)
            end
        else
            if exclusivePlay:GetBool() then
                local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, lastAmbienceTrack, true)
                if track then PlayNextTrack(track) end
            else
                local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, lastAmbienceTrack)
                if track then PlayNextTrack(track) end
            end
        end
    else
        if not enableAmbient:GetBool() then
            if currentStation and IsValid(currentStation) then FadeMusic(currentStation, false) end
            BATTLEBEATS.HideNotification()
            return
        end
        if (CurTime() - combatStartTime <= ambientWaitTime:GetInt() and lastAmbienceTrack) or (alwaysContinue:GetBool() and lastAmbienceTrack) then
            if exclusivePlay:GetBool() and lastCombatTrack then
                local samePack = AreTracksFromSamePack(lastAmbienceTrack, lastCombatTrack)
                if not samePack then
                    local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, lastCombatTrack, true)
                    if track then PlayNextTrack(track) end
                else
                    local offset = GetOffset(lastAmbiencePosition, lastCombatLength, lastAmbienceTotalLength)
                    TryPlayTrackWithOffset(lastAmbienceTrack, offset, lastCombatTrack, true)
                end
            else
                local offset = GetOffset(lastAmbiencePosition, lastCombatLength, lastAmbienceTotalLength)
                TryPlayTrackWithOffset(lastAmbienceTrack, offset, lastCombatTrack)
            end
        else
            local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, lastCombatTrack)
            if track then PlayNextTrack(track) end
        end
    end
end

timer.Create("BattleBeats_ClientCombatCheck", 1, 0, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    isInCombat = ply:GetNWBool("BattleBeats_InCombat", false)
    BATTLEBEATS.isInCombat = isInCombat
    if isInCombat ~= lastCombatState then
        if ambienceStartTime == nil then ambienceStartTime = CurTime() end
        lastCombatState = isInCombat
        if isInCombat then combatStartTime = CurTime() else ambienceStartTime = CurTime() end
        if not table.IsEmpty(BATTLEBEATS.currentPacks) then
            local success, err = pcall(SwitchTrack)
            if not success then
                print("[BattleBeats Client] BattleBeats_ClientCombatCheck error: " .. tostring(err))
            end
        end
    end
end)

--MARK:Misc
--------------------------------------------------------------------------------------

cvars.AddChangeCallback("battlebeats_enable_ambient", function(_, old_value, new_value)
    if tonumber(new_value) == 0 and not isInCombat then
        if currentStation and IsValid(currentStation) then FadeMusic(currentStation, false) end
        RemoveSoundTimers()
        BATTLEBEATS.HideNotification()
    else
        if not table.IsEmpty(BATTLEBEATS.currentPacks) and not isInCombat then
            local track = GetRandomTrack(BATTLEBEATS.currentPacks, false, BATTLEBEATS.excludedTracks)
            if track then PlayNextTrack(track) end
        end
    end
end)

cvars.AddChangeCallback("battlebeats_show_preview_notification", function(_, old_value, new_value)
    if tonumber(new_value) == 0 then
        if IsValid(currentPreviewStation) then BATTLEBEATS.HideNotification() end
    else
        if IsValid(currentPreviewStation) then BATTLEBEATS.ShowTrackNotification(BATTLEBEATS.currentPreviewTrack, false, true) end
    end
end)

cvars.AddChangeCallback("battlebeats_persistent_notification", function(_, old_value, new_value)
    if tonumber(new_value) == 0 then
        BATTLEBEATS.HideNotification()
    else
        if currentStation and IsValid(currentStation) then
            BATTLEBEATS.ShowTrackNotification(currentStation:GetFileName(), isInCombat)
        end
    end
end)

cvars.AddChangeCallback("battlebeats_show_notification", function(_, old_value, new_value)
    if tonumber(new_value) == 0 then
        BATTLEBEATS.HideNotification()
    else
        if currentStation and IsValid(currentStation) and persistentNotification:GetBool() then
            BATTLEBEATS.ShowTrackNotification(currentStation:GetFileName(), isInCombat)
        end
    end
end)

local warningBox

local function applyVolume(vol)
    local masterVolume = vol / 100
    if IsValid(currentStation) then
        local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
        targetVolume = (volumeType / 100) * masterVolume
        currentStation:SetVolume(targetVolume)
    end
    if IsValid(currentPreviewStation) then
        currentPreviewStation:SetVolume(masterVolume)
    end
end

cvars.AddChangeCallback("battlebeats_volume_ambient", function(_, old_value, new_value)
    local newVolume = tonumber(new_value)
    if not newVolume then return end
    applyVolume(volumeSet:GetInt())
end)


cvars.AddChangeCallback("battlebeats_volume_combat", function(_, old_value, new_value)
    local newVolume = tonumber(new_value)
    if not newVolume then return end
    applyVolume(volumeSet:GetInt())
end)

cvars.AddChangeCallback("battlebeats_lower_volume_in_menu", function(_, old_value, new_value)
    if tonumber(new_value) == 0 then
        lastMuteState = false
    end
end)

local function createButton(text, x, y, callback, cancel)
    local btn = vgui.Create("DButton", warningBox)
    btn:SetSize(180, 36)
    btn:SetPos(x, y)
    btn:SetText("")
    btn.Paint = function(self, w, h)
        local col
        if cancel then
            col = self:IsHovered() and Color(40, 210, 0) or Color(40, 180, 0)
        else
            col = self:IsHovered() and Color(220, 0, 0) or Color(200, 0, 0)
        end
        draw.RoundedBox(6, 0, 0, w, h, col)
        draw.SimpleText(text, "DermaDefaultBold", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = callback
    return btn
end

cvars.AddChangeCallback("battlebeats_volume", function(_, old_value, new_value)
    local newVolume = tonumber(new_value)
    if not newVolume then return end
    if IsValid(warningBox) then return end
    if IsValid(currentPreviewStation) then currentPreviewStation:SetVolume(new_value / 100) end

    if newVolume > 200 then
        if IsValid(warningBox) then return end

        warningBox = vgui.Create("DFrame")
        warningBox:SetSize(420, 180)
        warningBox:Center()
        warningBox:SetTitle("")
        warningBox:MakePopup()
        warningBox:SetBackgroundBlur(true)
        warningBox:ShowCloseButton(false)
        warningBox:SetDraggable(false)
        warningBox.Paint = function(self, w, h)
            Derma_DrawBackgroundBlur(self, 1)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 240))
            draw.SimpleText("Warning: High Volume!", "DermaLarge", w / 2, 20, Color(255, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText("You set the volume above 200% (" .. newVolume .. "%)", "DermaDefault", w / 2, 60, color_white, TEXT_ALIGN_CENTER)
            draw.SimpleText("This may damage your hearing or audio equipment", "DermaDefault", w / 2, 75,
                Color(255, 180, 180), TEXT_ALIGN_CENTER)
            draw.SimpleText("Proceed only if you understand the risk", "DermaDefault", w / 2, 90, Color(200, 200, 255),
                TEXT_ALIGN_CENTER)
        end

        createButton("I understand the risk", 20, 120, function()
            applyVolume(newVolume)
            warningBox:Close()
        end)

        createButton("Cancel", 220, 120, function()
            RunConsoleCommand("battlebeats_volume", tostring(math.min(old_value or 100, 200)))
            warningBox:Close()
        end, true)
    else
        applyVolume(newVolume)
    end
end)

concommand.Add("battlebeats_force_next_track", function()
    if IsValid(currentPreviewStation) then
        BATTLEBEATS.SwitchPreviewTrack(1)
    elseif not table.IsEmpty(BATTLEBEATS.currentPacks) then
        local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks)
        if track then PlayNextTrack(track) end
    end
end)

print("BattleBeats Loading...")