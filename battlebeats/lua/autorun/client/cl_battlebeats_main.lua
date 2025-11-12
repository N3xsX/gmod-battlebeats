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
BATTLEBEATS.npcTrackMappings = {}
BATTLEBEATS.priorityStates = {}
BATTLEBEATS.trackOffsets = {}
BATTLEBEATS.trackToPack = {}

BATTLEBEATS.currentVersion = "2.2.5"
CreateClientConVar("battlebeats_seen_version", "", true, false)

CreateClientConVar("battlebeats_detection_mode", "1", true, true, "", 0, 1)
CreateClientConVar("battlebeats_npc_combat", "0", true, true, "", 0, 1)

local maxDistance = CreateConVar("battlebeats_server_max_distance", "5000", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "", 100, 10000)

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
local forceCombat = CreateClientConVar("battlebeats_force_combat", "0", true, true, "", 0, 1)

local enableSubtitles = CreateClientConVar("battlebeats_subtitles_enabled", "1", true, false, "", 0, 1)

local ambientVolume = CreateClientConVar("battlebeats_volume_ambient", "100", true, false, "", 0, 100)
local combatVolume = CreateClientConVar("battlebeats_volume_combat", "100", true, false, "", 0, 100)

local switchOnLower = CreateClientConVar("battlebeats_switch_on_lower_priority", "1", true, false, "", 0, 1)
local enableAssignedTracks = CreateClientConVar("battlebeats_enable_assigned_tracks", "1", true, false, "", 0, 1)
local switchOnNoNPC = CreateClientConVar("battlebeats_switch_on_no_npc_track", "1", true, false, "", 0, 1)
local excludeMappedTracks = CreateClientConVar("battlebeats_exclude_mapped_tracks", "0", true, false, "", 0, 1)
local lastCombatTrackPriority = 0
local lastCombatPriorityTrack = nil

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

local function removeSoundTimers()
    if timer.Exists("BattleBeats_NextTrack") then timer.Remove("BattleBeats_NextTrack") end
    if timer.Exists("BattleBeats_CheckSound") then timer.Remove("BattleBeats_CheckSound") end
end

local function FadeMusic(station, fadeIn, fadeTime, isPreview)
    if not IsValid(station) then return end
    fadeTime = fadeTime or 2
    local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
    local masterVolume = volumeSet:GetInt() / 100
    local tgVolume = muteVolume or ((volumeType / 100) * masterVolume)
    if isPreview then tgVolume = muteVolume or masterVolume end

    local startVolume = fadeIn and 0 or station:GetVolume()
    local endVolume = fadeIn and tgVolume or 0
    local startTime = CurTime()
    local timerName = "BattleBeats_Fade_" .. tostring(station)

    debugPrint("[FadeMusic] Start " .. (fadeIn and "IN " or "OUT ") .. tostring(station) .. " targetVolume: " .. tostring(tgVolume))

    timer.Create(timerName .. CurTime(), fadeTime, 3, function()
        if not fadeIn and IsValid(station) then
            debugPrint("[FadeMusic][Failsafe] Stopping station " .. tostring(station))
            station:SetVolume(0)
            station:Stop()
            station = nil
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
            station = nil
            timer.Remove(timerName)
        elseif progress >= 0.95 and fadeIn then
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

local function areTracksFromSamePack(trackA, trackB)
    local packA = BATTLEBEATS.trackToPack[trackA]
    local packB = BATTLEBEATS.trackToPack[trackB]
    debugPrint("[AreTracksFromSamePack] packA: " .. packA .. " | packB:" .. packB)
    return packA ~= nil and packA == packB, packA, packB
end

local function GetRandomTrack(packs, isCombat, excluded, previousTrack, exclusivePlayOnly)
    if not packs or table.IsEmpty(packs) then
        debugPrint("[GetRandomTrack] No packs provided")
        return nil
    end
    if (isCombat and not enableCombat:GetBool()) or
        (not isCombat and not enableAmbient:GetBool()) then
        return nil
    end
    local allTracks = {}
    if exclusivePlay:GetBool() and previousTrack and exclusivePlayOnly then
        local packName = BATTLEBEATS.trackToPack[previousTrack] -- restrict to same pack if exclusive play is enabled
        debugPrint("[GetRandomTrack] Exclusive play enabled. Using pack: " .. packName)
        if packName and BATTLEBEATS.musicPacks[packName] then
            local selectedTracks = isCombat and BATTLEBEATS.musicPacks[packName].combat or BATTLEBEATS.musicPacks[packName].ambient
            if selectedTracks and #selectedTracks > 0 then
                for _, t in ipairs(selectedTracks) do
                    table.insert(allTracks, t)
                end
            else
                debugPrint("[GetRandomTrack] Selected pack is empty. Falling back to all")
                for packName, _ in pairs(packs) do
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
            if not excluded[track] and (not excludeMappedTracks:GetBool() or not BATTLEBEATS.npcTrackMappings[track]) then
                table.insert(availableTracks, track)
            end
        end
        debugPrint("[GetRandomTrack] Available after exclusion: " .. #availableTracks)
        if #availableTracks > 1 then
            local lastTrack = isCombat and lastCombatTrack or lastAmbienceTrack
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
            notification.AddLegacy("#btb.main.allexcluded", NOTIFY_ERROR, 4)
            return allTracks[math.random(#allTracks)] -- fallback: return random track even if excluded
        end
    end
    return nil
end

function BATTLEBEATS.GetRandomTrack(packs, isCombat, excluded, previousTrack, exclusivePlayOnly)
    return GetRandomTrack(packs, isCombat, excluded, previousTrack, exclusivePlayOnly)
end

local function printStationError(track, errCode, errStr)
    notification.AddLegacy("#btb.main.soundfail", NOTIFY_ERROR, 4)
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
    removeSoundTimers()
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

local function PlayNextTrack(track, time, noFade, priority)
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
            local offset = BATTLEBEATS.trackOffsets[track] or 0
            station:SetTime(time or offset, true)
            local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
            local masterVolume = volumeSet:GetInt() / 100
            if not noFade then
                FadeMusic(station, true)
            else
                station:SetVolume((volumeType / 100) * masterVolume)
                --station:SetVolume(volumeSet:GetInt() / 100)
            end

            if enableSubtitles:GetBool() then
                local subtitleTrack = BATTLEBEATS.FormatTrackName(track)
                if BATTLEBEATS.parsedSubtitles and BATTLEBEATS.parsedSubtitles[string.lower(subtitleTrack)] then
                    BATTLEBEATS.StartSubtitles(subtitleTrack, station)
                end
            end

            removeSoundTimers()

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
                if (isInCombat and not enableCombat:GetBool()) or
                    (not isInCombat and not enableAmbient:GetBool()) then
                    return
                end
                if priority then -- looping assigned tracks
                    PlayNextTrack(track, 0, false, priority)
                    local state = BATTLEBEATS.priorityStates[priority] or {}
                    state.length = 0
                    BATTLEBEATS.priorityStates[priority] = state
                else
                    local nextTrack = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks)
                    if nextTrack then PlayNextTrack(nextTrack) end
                end
            end)

            timer.Create("BattleBeats_CheckSound", 1, 0, function() -- timer to check if track stops playing unexpectedly
                if not IsValid(station) or station:GetState() ~= GMOD_CHANNEL_PLAYING then
                    debugPrint("[PlayNextTrack] Track stopped unexpectedly. Selecting next track")
                    timer.Remove("BattleBeats_CheckSound")
                    if timer.Exists("BattleBeats_NextTrack") then timer.Remove("BattleBeats_NextTrack") end
                    if (isInCombat and not enableCombat:GetBool()) or
                        (not isInCombat and not enableAmbient:GetBool()) then
                        return
                    end
                    if priority then -- looping assigned tracks
                        PlayNextTrack(track, 0, false, priority)
                        local state = BATTLEBEATS.priorityStates[priority] or {}
                        state.length = 0
                        BATTLEBEATS.priorityStates[priority] = state
                    else
                        local nextTrack = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks)
                        if nextTrack then PlayNextTrack(nextTrack) end
                    end
                end
                -- update playback length and position
                if IsValid(station) then
                    if priority then
                        local state = BATTLEBEATS.priorityStates[priority] or {}
                        if state.track == track then
                            state.length = (state.length or 0) + 1
                        else
                            state.length = 0
                        end
                        state.track = track
                        state.position = station:GetTime()
                        state.totalLength = station:GetLength()
                        state.time = CurTime()
                        BATTLEBEATS.priorityStates[priority] = state
                    else
                        if not isInCombat then
                            lastAmbiencePosition = station:GetTime()
                            lastAmbienceLength = lastAmbienceLength + 1
                        else
                            lastCombatPosition = station:GetTime()
                            lastCombatLength = lastCombatLength + 1
                        end
                    end
                end
            end)
        else
            printStationError(track, errCode, errStr)
            local nextTrack = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks)
            if nextTrack then PlayNextTrack(nextTrack) end
        end
    end)
end

function BATTLEBEATS.PlayNextTrack(track, time, noFade, priority)
    PlayNextTrack(track, time, noFade, priority)
end

local cleanupTrack = nil
local cleanupTime = nil
hook.Add("PreCleanupMap", "BattleBeats_SaveMusic", function()
    if IsValid(currentStation) then
        cleanupTrack = currentStation:GetFileName()
        cleanupTime = currentStation:GetTime()
    end
end)

hook.Add("PostCleanupMap", "BattleBeats_ResumeMusic", function()
    if not isPreviewing then
        if not cleanupTrack then return end
        PlayNextTrack(cleanupTrack, cleanupTime)
    else
        if not BATTLEBEATS.currentPreviewTrack then return end
        PlayNextTrackPreview(BATTLEBEATS.currentPreviewTrack, BATTLEBEATS.currentPreviewPosition)
    end
end)

local function ValidateTrack(track, errCallback)
    if not track or track == "" then
        if errCallback then
            errCallback(track, -1, "Invalid track path")
        end
        return
    end
    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if errCode or errStr then
            errCallback(track, errCode, errStr)
        end
        if station then
            station:Stop()
        end
    end)
end

function BATTLEBEATS.ValidateTrack(track, errCallback)
    ValidateTrack(track, errCallback)
end

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

local volumeFrameOn = false
timer.Create("BattleBeats_ClientAliveSoundCheck", 5, 0, function() -- sanity check
    if isAlive and not lastMuteState and (IsValid(currentStation) or IsValid(currentPreviewStation))
        and not timer.Exists("BattleBeats_SmoothFade")
        and not (IsValid(currentStation) and timer.Exists("BattleBeats_Fade_" .. tostring(currentStation)))
        and not (IsValid(currentPreviewStation) and timer.Exists("BattleBeats_Fade_" .. tostring(currentPreviewStation))) then
        if volumeFrameOn then return end
        local volumeType = isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
        local masterVolume = volumeSet:GetInt() / 100
        if IsValid(currentStation) then currentStation:SetVolume((volumeType / 100) * masterVolume) end
        if IsValid(currentPreviewStation) then currentPreviewStation:SetVolume(masterVolume) end
    end
end)

--MARK:State Switching
--------------------------------------------------------------------------------------

local function getOffset(lastTrackPos, oppositeTrackLen, totalLength)
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

local function tryPlayTrackWithOffset(track, offset, fallbackTrackRef, exclusiveOnly, priority) -- plays track with offset, or falls back to a random track if not possible
    if offset then
        PlayNextTrack(track, offset, false, priority)
    else
        local fallbackTrack = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, fallbackTrackRef, exclusiveOnly)
        if fallbackTrack then PlayNextTrack(fallbackTrack) end
    end
end

local function getNPCMatchingTrack()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    if table.IsEmpty(BATTLEBEATS.npcTrackMappings) then return nil end
    if not enableAssignedTracks:GetBool() then return nil end

    local trackPriorities = {}
    local nearbyNPCs = ents.FindInSphere(ply:GetPos(), maxDistance:GetInt())

    for _, ent in ipairs(nearbyNPCs) do
        if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
            local npcClass = ent.GetClass and ent:GetClass()
            for track, mapping in pairs(BATTLEBEATS.npcTrackMappings or {}) do
                if mapping.class == npcClass then
                    trackPriorities[track] = mapping.priority
                end
            end
        end
    end

    if table.IsEmpty(trackPriorities) then return nil end

    local minPriority = nil
    for _, priority in pairs(trackPriorities) do
        if priority > 0 and (not minPriority or priority < minPriority) then
            minPriority = priority
        end
    end

    local topTracks = {}
    for track, priority in pairs(trackPriorities) do
        if priority == minPriority then
            table.insert(topTracks, track)
        end
    end

    local selectedTrack = topTracks[math.random(#topTracks)]
    return selectedTrack
end

local function SwitchTrack(npcTrack)
    if IsValid(currentPreviewStation) then return end
    if not GetConVar("battlebeats_persistent_notification"):GetBool() then
        BATTLEBEATS.HideNotification()
    end
    if isInCombat then
        if npcTrack then
            local priority = BATTLEBEATS.npcTrackMappings[npcTrack].priority
            local npcState = BATTLEBEATS.priorityStates[priority]
            local shouldContinue = npcState and ((CurTime() - npcState.time <= combatWaitTime:GetInt()) or alwaysContinue:GetBool()) or false

            if npcState and npcState.track == npcTrack and shouldContinue then
                local offset = getOffset(npcState.position, lastAmbienceLength, npcState.totalLength)
                tryPlayTrackWithOffset(npcState.track, offset, lastAmbienceTrack, false, priority)
            else
                PlayNextTrack(npcTrack, nil, false, priority)
            end
            lastCombatTrackPriority = priority
        else
            local shouldContinue = (CurTime() - ambienceStartTime <= combatWaitTime:GetInt() and lastCombatTrack) or (alwaysContinue:GetBool() and lastCombatTrack)
            if shouldContinue then
                if exclusivePlay:GetBool() and lastAmbienceTrack then
                    local samePack = areTracksFromSamePack(lastCombatTrack, lastAmbienceTrack)
                    if not samePack then
                        -- pick a different track from same pack
                        local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks,
                            lastAmbienceTrack, true)
                        if track then PlayNextTrack(track) end
                    else
                        -- continue same combat track from calculated offset
                        local offset = getOffset(lastCombatPosition, lastAmbienceLength, lastCombatTotalLength)
                        tryPlayTrackWithOffset(lastCombatTrack, offset, lastAmbienceTrack, true)
                    end
                else
                    local offset = getOffset(lastCombatPosition, lastAmbienceLength, lastCombatTotalLength)
                    tryPlayTrackWithOffset(lastCombatTrack, offset, lastAmbienceTrack)
                end
            else
                if exclusivePlay:GetBool() then
                    local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks,
                        lastAmbienceTrack, true)
                    if track then PlayNextTrack(track) end
                else
                    local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks,
                        lastAmbienceTrack)
                    if track then PlayNextTrack(track) end
                end
            end
            lastCombatTrackPriority = 0
        end
    else
        if not enableAmbient:GetBool() then
            if currentStation and IsValid(currentStation) then FadeMusic(currentStation, false) end
            BATTLEBEATS.HideNotification()
            return
        end
        if (CurTime() - combatStartTime <= ambientWaitTime:GetInt() and lastAmbienceTrack) or (alwaysContinue:GetBool() and lastAmbienceTrack) then
            if exclusivePlay:GetBool() and lastCombatTrack then
                local samePack = areTracksFromSamePack(lastAmbienceTrack, lastCombatTrack)
                if not samePack then
                    local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, lastCombatTrack, true)
                    if track then PlayNextTrack(track) end
                else
                    local offset = getOffset(lastAmbiencePosition, lastCombatLength, lastAmbienceTotalLength)
                    tryPlayTrackWithOffset(lastAmbienceTrack, offset, lastCombatTrack, true)
                end
            else
                local offset = getOffset(lastAmbiencePosition, lastCombatLength, lastAmbienceTotalLength)
                tryPlayTrackWithOffset(lastAmbienceTrack, offset, lastCombatTrack)
            end
        else
            local track = GetRandomTrack(BATTLEBEATS.currentPacks, isInCombat, BATTLEBEATS.excludedTracks, lastCombatTrack)
            if track then PlayNextTrack(track) end
        end
    end
end

local pendingSwitch = nil
local pendingTrack = nil

timer.Create("BattleBeats_ClientCombatCheck", 1, 0, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    isInCombat = ply:GetNWBool("BattleBeats_InCombat", false)
    if forceCombat:GetBool() and enableCombat:GetBool() then
        isInCombat = true
    end
    BATTLEBEATS.isInCombat = isInCombat

    if isInCombat ~= lastCombatState then
        if ambienceStartTime == nil then ambienceStartTime = CurTime() end
        lastCombatState = isInCombat
        if isInCombat then
            combatStartTime = CurTime()
            local npcTrack = getNPCMatchingTrack()
            local success, err = pcall(SwitchTrack, npcTrack)
            if not success then
                print("[BattleBeats Client] BattleBeats_ClientCombatCheck error: " .. tostring(err))
            end
        else
            ambienceStartTime = CurTime()
            local success, err = pcall(SwitchTrack, nil)
            if not success then
                print("[BattleBeats Client] BattleBeats_ClientCombatCheck error: " .. tostring(err))
            end
            lastCombatTrackPriority = 0 
        end
    elseif isInCombat then
        local npcTrack = getNPCMatchingTrack()
        if not npcTrack then return end
        local newPriority = npcTrack and BATTLEBEATS.npcTrackMappings[npcTrack].priority or 0

        if npcTrack ~= lastCombatTrack and npcTrack ~= pendingTrack then
            local shouldSwitch = false

            if newPriority > 0 then
                if lastCombatTrackPriority == 0 or newPriority < lastCombatTrackPriority then
                    shouldSwitch = true
                    debugPrint("Switching to higher priority NPC track: " .. npcTrack .. " (priority " .. newPriority .. ")")
                elseif newPriority == lastCombatTrackPriority then
                    shouldSwitch = false
                elseif switchOnLower:GetBool() then
                    shouldSwitch = true
                    debugPrint("Switching to lower priority NPC track: " .. npcTrack .. " (priority " .. newPriority .. ")")
                else
                    debugPrint("Keeping current track (higher priority active)")
                end
            end

            if shouldSwitch then
                pendingSwitch = { track = npcTrack, time = CurTime() + 2 }
                pendingTrack = npcTrack
            end
        end

        if pendingSwitch and CurTime() >= pendingSwitch.time then
            local success, err = pcall(SwitchTrack, pendingSwitch.track)
            if not success then
                print("[BattleBeats Client] NPC track switch error: " .. tostring(err))
            end
            pendingSwitch = nil
            pendingTrack = nil
        end
    end
end)

--MARK:Misc
--------------------------------------------------------------------------------------

cvars.AddChangeCallback("battlebeats_enable_ambient", function(_, _, newValue)
    if tonumber(newValue) == 0 and not isInCombat then
        if currentStation and IsValid(currentStation) then FadeMusic(currentStation, false) end
        removeSoundTimers()
        BATTLEBEATS.HideNotification()
    else
        if not isInCombat then
            local track = GetRandomTrack(BATTLEBEATS.currentPacks, false, BATTLEBEATS.excludedTracks)
            if track then PlayNextTrack(track) end
        end
    end
end)

cvars.AddChangeCallback("battlebeats_show_preview_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        if IsValid(currentPreviewStation) then BATTLEBEATS.HideNotification() end
    else
        if IsValid(currentPreviewStation) then BATTLEBEATS.ShowTrackNotification(BATTLEBEATS.currentPreviewTrack, false, true) end
    end
end)

cvars.AddChangeCallback("battlebeats_persistent_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        BATTLEBEATS.HideNotification()
    else
        if currentStation and IsValid(currentStation) then
            BATTLEBEATS.ShowTrackNotification(currentStation:GetFileName(), isInCombat)
        end
    end
end)

cvars.AddChangeCallback("battlebeats_show_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
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

cvars.AddChangeCallback("battlebeats_volume_ambient", function(_, _, newValue)
    local newVolume = tonumber(newValue)
    if not newVolume then return end
    applyVolume(volumeSet:GetInt())
end)


cvars.AddChangeCallback("battlebeats_volume_combat", function(_, _, newValue)
    local newVolume = tonumber(newValue)
    if not newVolume then return end
    applyVolume(volumeSet:GetInt())
end)

cvars.AddChangeCallback("battlebeats_lower_volume_in_menu", function(_, _, newValue)
    if tonumber(newValue) == 0 then
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

cvars.AddChangeCallback("battlebeats_volume", function(_, oldValue, newValue)
    local newVolume = tonumber(newValue)
    if not newVolume then return end
    if IsValid(warningBox) then return end

    if newVolume > 200 then
        volumeFrameOn = true
        warningBox = vgui.Create("DFrame")
        warningBox:SetSize(420, 180)
        warningBox:Center()
        warningBox:SetTitle("")
        warningBox:MakePopup()
        warningBox:SetBackgroundBlur(true)
        warningBox:ShowCloseButton(false)
        warningBox:SetDraggable(false)
        local w2 = language.GetPhrase("btb.main.volume_warning_2")
        warningBox.Paint = function(self, w, h)
            Derma_DrawBackgroundBlur(self, 1)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 240))
            draw.SimpleText("#btb.main.volume_warning_1", "DermaLarge", w / 2, 20, Color(255, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText(w2 ..  " (" .. newVolume .. "%)", "DermaDefault", w / 2, 60, color_white, TEXT_ALIGN_CENTER)
            draw.SimpleText("#btb.main.volume_warning_3", "DermaDefault", w / 2, 75, Color(255, 180, 180), TEXT_ALIGN_CENTER)
            draw.SimpleText("#btb.main.volume_warning_4", "DermaDefault", w / 2, 90, Color(200, 200, 255), TEXT_ALIGN_CENTER)
        end
        warningBox.OnClose = function ()
            volumeFrameOn = false
        end

        createButton("#btb.main.volume_confirm", 20, 120, function()
            applyVolume(newVolume)
            warningBox:Close()
        end)

        createButton("#btb.main.volume_cancel", 220, 120, function()
            RunConsoleCommand("battlebeats_volume", tostring(math.min(oldValue or 100, 200)))
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