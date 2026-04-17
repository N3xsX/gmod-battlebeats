BATTLEBEATS = BATTLEBEATS or {}

local targetVolume = 1

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

local forceVolume = false

BATTLEBEATS.currentStation = BATTLEBEATS.currentStation or nil
BATTLEBEATS.currentPreviewStation = BATTLEBEATS.currentPreviewStation or nil
BATTLEBEATS.currentPreviewPosition = BATTLEBEATS.currentPreviewPosition or nil
BATTLEBEATS.currentPreviewTrack = BATTLEBEATS.currentPreviewTrack or nil
BATTLEBEATS.frame = BATTLEBEATS.frame or nil
BATTLEBEATS.currentPacks = BATTLEBEATS.currentPacks or {}
BATTLEBEATS.musicPacks = BATTLEBEATS.musicPacks or {}
BATTLEBEATS.excludedTracks = BATTLEBEATS.excludedTracks or {}
BATTLEBEATS.favoriteTracks = BATTLEBEATS.favoriteTracks or {}
BATTLEBEATS.isInCombat = BATTLEBEATS.isInCombat or false
BATTLEBEATS.npcTrackMappings = BATTLEBEATS.npcTrackMappings or {}
BATTLEBEATS.priorityStates = BATTLEBEATS.priorityStates or {}
BATTLEBEATS.trackToPack = BATTLEBEATS.trackToPack or {}
BATTLEBEATS.packVolume = BATTLEBEATS.packVolume or {}
BATTLEBEATS.trackVolume = BATTLEBEATS.trackVolume or {}
BATTLEBEATS.trackTrim = BATTLEBEATS.trackTrim or {}
BATTLEBEATS.musicPlaylists = BATTLEBEATS.musicPlaylists or {}

--Dev
BATTLEBEATS.disableFade = BATTLEBEATS.disableFade or false
BATTLEBEATS.disableSwitch = BATTLEBEATS.disableSwitch or false -- BATTLEBEATS.isInCombat will still update
BATTLEBEATS.disableNextTrackTimer = BATTLEBEATS.disableNextTrackTimer or false
BATTLEBEATS.disableCheckingTimer = BATTLEBEATS.disableCheckingTimer or false
BATTLEBEATS.volumeOverride = BATTLEBEATS.volumeOverride or false -- use this to disable fade on death and in menu & periodic sound volume check

BATTLEBEATS.currentVersion = "2.6.7"
CreateClientConVar("battlebeats_seen_version", "", true, false)

CreateClientConVar("battlebeats_detection_mode", "1", true, true, "", 0, 1)
CreateClientConVar("battlebeats_npc_combat", "0", true, true, "", 0, 1)

CreateClientConVar("battlebeats_allow_server", "1", true, false, "", 0, 1)

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
local disableFade = CreateClientConVar("battlebeats_disable_fade", "0", true, true, "", 0, 1)

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

function BATTLEBEATS.adjustVolume(track, baseVolume, isPreview)
    local volumeType
    if isPreview and track and track ~= "" then
        local packName = BATTLEBEATS.trackToPack[track]
        local packData = packName and BATTLEBEATS.musicPacks and BATTLEBEATS.musicPacks[packName]
        if packData then
            if packData.ambient then
                for _, path in ipairs(packData.ambient) do
                    if path == track then
                        volumeType = ambientVolume:GetInt()
                        break
                    end
                end
            end
            if not volumeType and packData.combat then
                for _, path in ipairs(packData.combat) do
                    if path == track then
                        volumeType = combatVolume:GetInt()
                        break
                    end
                end
            end
        end
    end
    if not volumeType then
        volumeType = BATTLEBEATS.isInCombat and combatVolume:GetInt() or ambientVolume:GetInt()
    end
    local masterVolume = volumeSet:GetInt() / 100
    local tgVolume = baseVolume or (volumeType / 100 * masterVolume)

    tgVolume = hook.Run("BattleBeats_PreAdjustVolume", track, tgVolume) or tgVolume
    --debugPrint("[adjustVolume] Base Volume: " .. tostring(tgVolume) .. " | For track: " .. tostring(track))

    if not track or track == "" then
        return math.Round(tgVolume, 2)
    end

    local finalVol = tgVolume
    local packName = BATTLEBEATS.trackToPack[track]

    if packName and BATTLEBEATS.packVolume then
        local packAdj = BATTLEBEATS.packVolume[packName]
        if packAdj then
            local packMult = math.Clamp(packAdj / 100, 0, 2)
            finalVol = finalVol * packMult
        end
    end
    --debugPrint("[adjustVolume] Pack Volume: " .. tostring(finalVol))

    if BATTLEBEATS.trackVolume then
        local trackAdj = BATTLEBEATS.trackVolume[track]
        if trackAdj then
            local trackMult = math.Clamp(trackAdj / 100, 0, 2)
            finalVol = finalVol * trackMult
        end
    end
    --debugPrint("[adjustVolume] Pack + Track Volume: " .. tostring(finalVol))

    finalVol = hook.Run("BattleBeats_PostAdjustVolume", track, finalVol) or finalVol
    finalVol = math.Clamp(finalVol, 0, 10)
    --debugPrint("[adjustVolume] Final Volume: " .. tostring(finalVol))
    return math.Round(finalVol, 2)
end

--MARK:Music Fade
--------------------------------------------------------------------------------------

local function removeSoundTimers()
    if timer.Exists("BattleBeats_NextTrack") then timer.Remove("BattleBeats_NextTrack") end
    if timer.Exists("BattleBeats_CheckSound") then timer.Remove("BattleBeats_CheckSound") end
end

function BATTLEBEATS.FadeMusic(station, fadeIn, fadeTime, isPreview)
    if not IsValid(station) then return end
    fadeTime = fadeTime or 2
    local sName = IsValid(station) and station:GetFileName() or nil
    local tgVolume = BATTLEBEATS.adjustVolume(sName, muteVolume, isPreview)
    local override = hook.Run("BattleBeats_PreFade", station, fadeIn, fadeTime, isPreview)
    if override == true then
        forceVolume = true
        return
    end
    if istable(override) then
        forceVolume = override.volume ~= nil
        if override.fadeTime ~= nil then
            fadeTime = math.Clamp(override.fadeTime, 0, 10)
        end
        if override.volume ~= nil then
            tgVolume = math.Clamp(override.volume, 0, 2)
        end
    end
    if disableFade:GetBool() or BATTLEBEATS.disableFade or fadeTime == 0 then
        if fadeIn then
            station:SetVolume(tgVolume)
        else
            station:SetVolume(0)
        end
        hook.Run("BattleBeats_PostFade", station, fadeIn)
        return
    end

    local startVolume = fadeIn and 0 or station:GetVolume()
    local endVolume = fadeIn and tgVolume or 0
    local startTime = CurTime()
    local timerName = "BattleBeats_Fade_" .. tostring(station)

    debugPrint("[FadeMusic] Start " .. (fadeIn and "IN " or "OUT ") .. tostring(station) .. " targetVolume: " .. tostring(tgVolume))

    timer.Create(timerName .. CurTime(), fadeTime, 3, function()
        if not fadeIn and IsValid(station) then
            debugPrint("[FadeMusic][Failsafe] Stopping station " .. tostring(station))
            hook.Run("BattleBeats_PostFade", station, fadeIn)
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
            hook.Run("BattleBeats_PostFade", station, fadeIn)
            station:SetVolume(0)
            station:Stop()
            station = nil
            timer.Remove(timerName)
        elseif progress >= 0.95 and fadeIn then
            debugPrint("[FadeMusic] Fade in complete, removing timer " .. tostring(station))
            hook.Run("BattleBeats_PostFade", station, fadeIn)
            timer.Remove(timerName)
        end
    end)
end

--MARK:Random track
--------------------------------------------------------------------------------------

local function areTracksFromSamePack(trackA, trackB)
    local packA = BATTLEBEATS.trackToPack[trackA]
    local packB = BATTLEBEATS.trackToPack[trackB]
    debugPrint("[AreTracksFromSamePack] packA: " .. packA .. " | packB:" .. packB)
    return packA ~= nil and packA == packB
end

function BATTLEBEATS.GetRandomTrack(packs, isCombat, excluded, previousTrack, exclusivePlayOnly)
    if not packs or table.IsEmpty(packs) then
        debugPrint("[GetRandomTrack] No packs provided")
        return nil
    end
    if (isCombat and not enableCombat:GetBool()) or
        (not isCombat and not enableAmbient:GetBool()) then
        return nil
    end
    packs = hook.Run("BattleBeats_PreBuildTrackList", packs, isCombat) or packs
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
            local hasMapping = BATTLEBEATS.npcTrackMappings[track] and BATTLEBEATS.npcTrackMappings[track].npcs and #BATTLEBEATS.npcTrackMappings[track].npcs > 0
            local exclusionOverride = hook.Run("BattleBeats_ShouldExcludeTrack", track, hasMapping, isCombat)
            if exclusionOverride == true then continue end
            local isExcludedByCore = excluded[track] or (excludeMappedTracks:GetBool() and hasMapping)
            if exclusionOverride == false then isExcludedByCore = false end
            if not isExcludedByCore then table.insert(availableTracks, track) end
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
            local chosen = availableTracks[math.random(#availableTracks)]
            local override = hook.Run("BattleBeats_OnTrackSelected", chosen, isCombat)
            if isstring(override) then return override end
            return chosen
        else
            local fallbackTrack = allTracks[math.random(#allTracks)]
            local override = hook.Run("BattleBeats_OnFallbackTrack", fallbackTrack, isCombat)
            if isstring(override) then
                return override
            end
            notification.AddLegacy("#btb.main.allexcluded", NOTIFY_ERROR, 4)
            return fallbackTrack
        end
    end
    return nil
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

function BATTLEBEATS.PlayNextTrackPreview(track, time, isLooped, errCallback)
    removeSoundTimers()
    if BATTLEBEATS.currentStation and IsValid(BATTLEBEATS.currentStation) then
        BATTLEBEATS.FadeMusic(BATTLEBEATS.currentStation, false)
    end
    if BATTLEBEATS.currentPreviewStation and IsValid(BATTLEBEATS.currentPreviewStation) then
        BATTLEBEATS.FadeMusic(BATTLEBEATS.currentPreviewStation, false)
    end
    if showPreviewNotification:GetBool() and not isLooped then BATTLEBEATS.ShowTrackNotification(track, false, true) end
    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if IsValid(station) then
            forceVolume = false
            isPreviewing = true
            BATTLEBEATS.currentPreviewStation = station
            station:SetVolume(0)
            station:Play()
            station:SetTime(time or 0, true)
            BATTLEBEATS.FadeMusic(station, true, 2, true)
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

local function handleTrackEnd(track, reason, priority)
    local override = hook.Run("BattleBeats_OnTrackEnded", track, reason, priority)
    if override == true then
        debugPrint("[PlayNextTrack] Autoplay cancelled by hook (" .. reason .. ")")
        return
    end

    if isstring(override) then
        BATTLEBEATS.PlayNextTrack(override)
        return
    end

    if istable(override) then
        BATTLEBEATS.PlayNextTrack(override.track or track, override.time or 0, override.noFade, override.cFadeIn or nil, override.cFadeOut or nil, override.priority or priority)
        return
    end

    -- default behavior
    if priority then
        BATTLEBEATS.PlayNextTrack(track, 0, nil, nil, priority) -- looping assigned tracks
        local state = BATTLEBEATS.priorityStates[priority] or {}
        state.length = 0
        BATTLEBEATS.priorityStates[priority] = state
    else
        local nextTrack = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks)
        if nextTrack then BATTLEBEATS.PlayNextTrack(nextTrack) end
    end
end

BATTLEBEATS.errorCount = 0
function BATTLEBEATS.PlayNextTrack(track, time, cFadeIn, cFadeOut, priority)
    if not track or track == "" then
        debugPrint("[PlayNextTrack] Attempted to play nil/empty track! Aborting...")
        return
    end
    if BATTLEBEATS.errorCount > 3 then
        ErrorNoHalt("\n[BattleBeats] Multiple track errors occurred or the audio system failed (BASS)! Stopping playback...\n          Verify or change your packs and type 'battlebeats_restart' to resume playback\n")
        surface.PlaySound("buttons/button8.wav")
        removeSoundTimers()
        return
    end
    local override = hook.Run("BattleBeats_PrePlayTrack", track, time, cFadeIn, cFadeOut, priority)
    if override == true then
        debugPrint("[PlayNextTrack] Playback cancelled by hook")
        return
    end
    if istable(override) then
        if isstring(override.track) and override.track ~= "" then
            track = override.track
        end
        time = isnumber(override.time) and override.time or time
        cFadeIn = isnumber(override.cFadeIn) and override.cFadeIn or cFadeIn
        cFadeOut = isnumber(override.cFadeOut) and override.cFadeOut or cFadeOut
        if isnumber(override.priority) or isstring(override.priority) then
            priority = override.priority
        end
    end
    debugPrint("[PlayNextTrack] Starting playback for track: " .. tostring(track))
    debugPrint("[PlayNextTrack] Start time: " .. tostring(math.Truncate(time or 0, 1)) .. " (s)")
    if BATTLEBEATS.currentStation and IsValid(BATTLEBEATS.currentStation) then
        cFadeOut = cFadeOut and math.Clamp(cFadeOut, 0, 10) or nil
        BATTLEBEATS.FadeMusic(BATTLEBEATS.currentStation, false, cFadeOut)
    end

    -- store last track info based on combat state
    if not BATTLEBEATS.isInCombat then
        lastAmbienceTrack = track
        cookie.Set("battlebeats_last_track", lastAmbienceTrack)
        lastAmbienceLength = 0
    else
        lastCombatTrack = track
        lastCombatLength = 0
    end

    if (not time or replayNotification:GetBool() or persistentNotification:GetBool())
        and showNotification:GetBool()
        and volumeSet:GetInt() > 0 then
        BATTLEBEATS.ShowTrackNotification(track, BATTLEBEATS.isInCombat)
    end

    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if IsValid(station) then
            BATTLEBEATS.errorCount = 0
            isPreviewing = false
            forceVolume = false
            BATTLEBEATS.currentStation = station
            station:SetVolume(0)
            station:Play()
            local trimData = BATTLEBEATS.trackTrim[track]
            local offset = trimData and trimData.start or 0
            station:SetTime(time or offset, true)
            hook.Run("BattleBeats_OnTrackStarted", station, track, BATTLEBEATS.isInCombat, priority)
            cFadeIn = cFadeIn and math.Clamp(cFadeIn, 0, 10) or nil
            BATTLEBEATS.FadeMusic(station, true, cFadeIn)

            if enableSubtitles:GetBool() then
                local subtitleTrack = BATTLEBEATS.FormatTrackName(track)
                if BATTLEBEATS.parsedSubtitles and BATTLEBEATS.parsedSubtitles[string.lower(subtitleTrack)] then
                    BATTLEBEATS.StartSubtitles(subtitleTrack, station)
                end
            end

            removeSoundTimers()

            local trackLength = trimData and trimData.finish or station:GetLength()
            if not BATTLEBEATS.isInCombat then
                lastAmbiencePosition = station:GetTime()
                lastAmbienceTotalLength = trackLength
            else
                lastCombatPosition = station:GetTime()
                lastCombatTotalLength = trackLength
            end

            local startTime = time or 0
            local playDuration = math.max(trackLength - startTime - 1, 1)

            debugPrint("[PlayNextTrack] Track length: " .. math.Truncate(trackLength or 0, 1) .. " (s) | Will play for: " .. math.Truncate(playDuration or 0, 1) .. " (s)")

            timer.Create("BattleBeats_NextTrack", playDuration, 1, function() -- timer to play next track when current finishes
                if BATTLEBEATS.disableNextTrackTimer then return end
                debugPrint("[PlayNextTrack] Timer reached end. Selecting next track")
                if timer.Exists("BattleBeats_CheckSound") then timer.Remove("BattleBeats_CheckSound") end
                if (BATTLEBEATS.isInCombat and not enableCombat:GetBool()) or
                    (not BATTLEBEATS.isInCombat and not enableAmbient:GetBool()) then
                    return
                end
                handleTrackEnd(track, "finished", priority)
            end)

            timer.Create("BattleBeats_CheckSound", 1, 0, function() -- timer to check if track stops playing unexpectedly
                if not IsValid(station) or (station:GetState() ~= GMOD_CHANNEL_PLAYING and station:GetState() ~= GMOD_CHANNEL_STALLED) then
                    if BATTLEBEATS.disableCheckingTimer then return end
                    debugPrint("[PlayNextTrack] Track stopped unexpectedly. Selecting next track")
                    timer.Remove("BattleBeats_CheckSound")
                    if timer.Exists("BattleBeats_NextTrack") then timer.Remove("BattleBeats_NextTrack") end
                    if (BATTLEBEATS.isInCombat and not enableCombat:GetBool()) or
                        (not BATTLEBEATS.isInCombat and not enableAmbient:GetBool()) then
                        return
                    end
                    handleTrackEnd(track, "stopped", priority)
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
                        if not BATTLEBEATS.isInCombat then
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
            BATTLEBEATS.errorCount = BATTLEBEATS.errorCount + 1
            printStationError(track, errCode, errStr)
            hook.Run("BattleBeats_OnTrackEnded", track, "error", priority)
            local _override = hook.Run("BattleBeats_OnTrackError", track, errCode, errStr, BATTLEBEATS.isInCombat, priority)
            if _override == true then return end
            if isstring(_override) then
                BATTLEBEATS.PlayNextTrack(_override)
                return
            end
            local nextTrack = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks)
            if nextTrack then BATTLEBEATS.PlayNextTrack(nextTrack) end
        end
    end)
end

local cleanupTrack = nil
local cleanupTime = nil
hook.Add("PreCleanupMap", "BattleBeats_SaveMusic", function()
    if IsValid(BATTLEBEATS.currentStation) then
        cleanupTrack = BATTLEBEATS.currentStation:GetFileName()
        cleanupTime = BATTLEBEATS.currentStation:GetTime()
    end
end)

hook.Add("PostCleanupMap", "BattleBeats_ResumeMusic", function()
    if not isPreviewing then
        if not cleanupTrack then return end
        BATTLEBEATS.PlayNextTrack(cleanupTrack, cleanupTime)
    else
        if not BATTLEBEATS.currentPreviewTrack then return end
        BATTLEBEATS.PlayNextTrackPreview(BATTLEBEATS.currentPreviewTrack, BATTLEBEATS.currentPreviewPosition)
    end
end)

function BATTLEBEATS.ValidateTrack(track, errCallback)
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

--MARK:Client Timers
--------------------------------------------------------------------------------------

timer.Create("BattleBeats_ClientAliveCheck", 1, 0, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if forceVolume or BATTLEBEATS.volumeOverride then return end

    isAlive = ply:Alive()
    if isAlive ~= lastAliveState then
        lastAliveState = isAlive
        if disableMode:GetInt() == 1 then -- fade volume to 0 when dead, restore when alive
            local sName = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetFileName() or nil
            local tgVolume = BATTLEBEATS.adjustVolume(sName)
            targetVolume = isAlive and tgVolume or 0
            fadeStartTime = CurTime()
            if muteVolume == nil then
                muteVolume = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetVolume() or
                IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetVolume()
                or targetVolume
            end
        elseif disableMode:GetInt() == 2 then -- fade volume to 30% when dead, restore when alive
            local sName = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetFileName() or nil
            local tgVolume = BATTLEBEATS.adjustVolume(sName)
            targetVolume = isAlive and tgVolume or 0.3
            fadeStartTime = CurTime()
            if muteVolume == nil then
                muteVolume = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetVolume() or
                IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetVolume()
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

            local sName = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetFileName() or nil
            local tgVolume = BATTLEBEATS.adjustVolume(sName)

            targetVolume = not shouldMute and tgVolume or 0.3
            fadeStartTime = CurTime()
            if muteVolume == nil then
                muteVolume = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetVolume()
                    or IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetVolume()
                    or targetVolume
            end
        end
    end

    if fadeStartTime and (IsValid(BATTLEBEATS.currentStation) or IsValid(BATTLEBEATS.currentPreviewStation)) and targetVolume
        and not timer.Exists("BattleBeats_SmoothFade")
        and not (IsValid(BATTLEBEATS.currentStation) and timer.Exists("BattleBeats_Fade_" .. tostring(BATTLEBEATS.currentStation)))
        and not (IsValid(BATTLEBEATS.currentPreviewStation) and timer.Exists("BattleBeats_Fade_" .. tostring(BATTLEBEATS.currentPreviewStation))) then
        timer.Create("BattleBeats_SmoothFade", 0.1, 0, function()
            -- abort if a manual fade is already active
            if (IsValid(BATTLEBEATS.currentStation) and timer.Exists("BattleBeats_Fade_" .. tostring(BATTLEBEATS.currentStation))) or
                (IsValid(BATTLEBEATS.currentPreviewStation) and timer.Exists("BattleBeats_Fade_" .. tostring(BATTLEBEATS.currentPreviewStation))) then
                timer.Remove("BattleBeats_SmoothFade")
                if isAlive then muteVolume = nil end
                return
            end
            if not fadeStartTime or (not IsValid(BATTLEBEATS.currentStation) and not IsValid(BATTLEBEATS.currentPreviewStation)) or not targetVolume then
                timer.Remove("BattleBeats_SmoothFade")
                if isAlive then muteVolume = nil end
                return
            end
            local progress = math.min((CurTime() - fadeStartTime) / 2, 1)
            if muteVolume then
                muteVolume = Lerp(progress, muteVolume, targetVolume)
                if IsValid(BATTLEBEATS.currentStation) then BATTLEBEATS.currentStation:SetVolume(muteVolume) end
                if IsValid(BATTLEBEATS.currentPreviewStation) then BATTLEBEATS.currentPreviewStation:SetVolume(muteVolume) end
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
    if forceVolume or BATTLEBEATS.volumeOverride then return end
    if volumeSet:GetInt() > 200 then
        local time = tonumber(cookie.GetString("battlebeats_high_volume_time", "0")) or 0
        time = time + 5
        cookie.Set("battlebeats_high_volume_time", tostring(time))
    end
    if isAlive and not lastMuteState and (IsValid(BATTLEBEATS.currentStation) or IsValid(BATTLEBEATS.currentPreviewStation))
        and not timer.Exists("BattleBeats_SmoothFade")
        and not (IsValid(BATTLEBEATS.currentStation) and timer.Exists("BattleBeats_Fade_" .. tostring(BATTLEBEATS.currentStation)))
        and not (IsValid(BATTLEBEATS.currentPreviewStation) and timer.Exists("BattleBeats_Fade_" .. tostring(BATTLEBEATS.currentPreviewStation))) then
        if volumeFrameOn then return end
        if IsValid(BATTLEBEATS.currentStation) then
            local sName = BATTLEBEATS.currentStation:GetFileName() or nil
            local tgVolume = BATTLEBEATS.adjustVolume(sName)
            BATTLEBEATS.currentStation:SetVolume(tgVolume)
        end
        if IsValid(BATTLEBEATS.currentPreviewStation) then
            local sName = BATTLEBEATS.currentPreviewStation:GetFileName() or nil
            local tgVolume = BATTLEBEATS.adjustVolume(sName, nil, true)
            BATTLEBEATS.currentPreviewStation:SetVolume(tgVolume)
        end
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
        BATTLEBEATS.PlayNextTrack(track, offset, nil, nil, priority)
    else
        local fallbackTrack = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks, fallbackTrackRef, exclusiveOnly)
        if fallbackTrack then BATTLEBEATS.PlayNextTrack(fallbackTrack) end
    end
end

local function getNPCMatchingTrack()
    local override = hook.Run("BattleBeats_SelectNPCTrack")
    if override == true then return nil end
    if isstring(override) then return override end
    local mappingOverride = hook.Run("BattleBeats_GetNPCTrackMappings")
    local mappings = istable(mappingOverride) and mappingOverride or BATTLEBEATS.npcTrackMappings
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    if table.IsEmpty(mappings) then return nil end
    if not enableAssignedTracks:GetBool() then return nil end

    local trackCandidates = {}
    local nearbyNPCs = ents.FindInSphere(ply:GetPos(), maxDistance:GetInt())

    for _, ent in ipairs(nearbyNPCs) do
        if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
            local npcClass = ent.GetClass and ent:GetClass()
            if not npcClass then continue end
            for track, mapping in pairs(mappings) do
                if mapping.npcs then
                    for _, npcInfo in ipairs(mapping.npcs) do
                        if npcInfo.class == npcClass then
                            trackCandidates[track] = math.min(trackCandidates[track] or 6, npcInfo.priority)
                        end
                    end
                end
            end
        end
    end

    if table.IsEmpty(trackCandidates) then return nil end

    local bestPriority = 6
    local bestTracks = {}

    for track, priority in pairs(trackCandidates) do
        if priority < bestPriority then
            bestPriority = priority
            bestTracks = {track}
        elseif priority == bestPriority then
            table.insert(bestTracks, track)
        end
    end

    return bestTracks[math.random(#bestTracks)]
end

local function getTrackPriority(track)
    local override = hook.Run("BattleBeats_GetNPCTrackPriority", track)
    if isnumber(override) then return override end
    if not BATTLEBEATS.npcTrackMappings[track] or not BATTLEBEATS.npcTrackMappings[track].npcs then
        return 6
    end
    local minPrio = 6
    for _, npc in ipairs(BATTLEBEATS.npcTrackMappings[track].npcs) do
        if npc.priority < minPrio then
            minPrio = npc.priority
        end
    end
    return minPrio
end

local function switchTrack(npcTrack)
    if IsValid(BATTLEBEATS.currentPreviewStation) then return end
    if not GetConVar("battlebeats_persistent_notification"):GetBool() then
        BATTLEBEATS.HideNotification()
    end
    if BATTLEBEATS.isInCombat then
        if npcTrack then
            local priority = getTrackPriority(npcTrack)
            local npcState = BATTLEBEATS.priorityStates[priority]
            local shouldContinue = npcState and ((CurTime() - npcState.time <= combatWaitTime:GetInt()) or alwaysContinue:GetBool()) or false

            if npcState and npcState.track == npcTrack and shouldContinue then
                local offset = getOffset(npcState.position, lastAmbienceLength, npcState.totalLength)
                tryPlayTrackWithOffset(npcState.track, offset, lastAmbienceTrack, false, priority)
            else
                BATTLEBEATS.PlayNextTrack(npcTrack, nil, nil, nil, priority)
            end
            lastCombatTrackPriority = priority
        else
            local shouldContinue = (CurTime() - ambienceStartTime <= combatWaitTime:GetInt() and lastCombatTrack) or (alwaysContinue:GetBool() and lastCombatTrack)
            if shouldContinue then
                if exclusivePlay:GetBool() and lastAmbienceTrack then
                    local samePack = areTracksFromSamePack(lastCombatTrack, lastAmbienceTrack)
                    if not samePack then
                        -- pick a different track from same pack
                        local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks, lastAmbienceTrack, true)
                        if track then BATTLEBEATS.PlayNextTrack(track) end
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
                    local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks, lastAmbienceTrack, true)
                    if track then BATTLEBEATS.PlayNextTrack(track) end
                else
                    local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks, lastAmbienceTrack)
                    if track then BATTLEBEATS.PlayNextTrack(track) end
                end
            end
            lastCombatTrackPriority = 0
        end
    else
        if not enableAmbient:GetBool() then
            if BATTLEBEATS.currentStation and IsValid(BATTLEBEATS.currentStation) then BATTLEBEATS.FadeMusic(BATTLEBEATS.currentStation, false) end
            BATTLEBEATS.HideNotification()
            return
        end
        if (CurTime() - combatStartTime <= ambientWaitTime:GetInt() and lastAmbienceTrack) or (alwaysContinue:GetBool() and lastAmbienceTrack) then
            if exclusivePlay:GetBool() and lastCombatTrack then
                local samePack = areTracksFromSamePack(lastAmbienceTrack, lastCombatTrack)
                if not samePack then
                    local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks, lastCombatTrack, true)
                    if track then BATTLEBEATS.PlayNextTrack(track) end
                else
                    local offset = getOffset(lastAmbiencePosition, lastCombatLength, lastAmbienceTotalLength)
                    tryPlayTrackWithOffset(lastAmbienceTrack, offset, lastCombatTrack, true)
                end
            else
                local offset = getOffset(lastAmbiencePosition, lastCombatLength, lastAmbienceTotalLength)
                tryPlayTrackWithOffset(lastAmbienceTrack, offset, lastCombatTrack)
            end
        else
            local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks, lastCombatTrack)
            if track then BATTLEBEATS.PlayNextTrack(track) end
        end
    end
end

local pendingSwitch = nil
local pendingTrack = nil

timer.Create("BattleBeats_ClientCombatCheck", 0.5, 0, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local isInCombat = ply:GetNWBool("BattleBeats_InCombat", false)
    if forceCombat:GetBool() and enableCombat:GetBool() then
        isInCombat = true
    end
    BATTLEBEATS.isInCombat = isInCombat

    if BATTLEBEATS.disableSwitch then return end

    if BATTLEBEATS.isInCombat ~= lastCombatState then
        if ambienceStartTime == nil then ambienceStartTime = CurTime() end
        lastCombatState = BATTLEBEATS.isInCombat
        if BATTLEBEATS.isInCombat then
            combatStartTime = CurTime()
            local npcTrack = getNPCMatchingTrack()
            local success, err = pcall(switchTrack, npcTrack)
            if not success then
                print("[BattleBeats Client] BattleBeats_ClientCombatCheck error: " .. tostring(err))
            end
        else
            ambienceStartTime = CurTime()
            local success, err = pcall(switchTrack, nil)
            if not success then
                print("[BattleBeats Client] BattleBeats_ClientCombatCheck error: " .. tostring(err))
            end
            lastCombatTrackPriority = 0 
        end
    elseif BATTLEBEATS.isInCombat then
        local npcTrack = getNPCMatchingTrack()
        if not npcTrack then return end
        local newPriority = getTrackPriority(npcTrack)

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
            local success, err = pcall(switchTrack, pendingSwitch.track)
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
    if tonumber(newValue) == 0 and not BATTLEBEATS.isInCombat then
        if BATTLEBEATS.currentStation and IsValid(BATTLEBEATS.currentStation) then BATTLEBEATS.FadeMusic(BATTLEBEATS.currentStation, false) end
        removeSoundTimers()
        BATTLEBEATS.HideNotification()
    else
        if not BATTLEBEATS.isInCombat then
            local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, false, BATTLEBEATS.excludedTracks)
            if track then BATTLEBEATS.PlayNextTrack(track) end
        end
    end
end)

cvars.AddChangeCallback("battlebeats_show_preview_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        if IsValid(BATTLEBEATS.currentPreviewStation) then BATTLEBEATS.HideNotification() end
    else
        if IsValid(BATTLEBEATS.currentPreviewStation) then BATTLEBEATS.ShowTrackNotification(BATTLEBEATS.currentPreviewTrack, false, true) end
    end
end)

cvars.AddChangeCallback("battlebeats_persistent_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        BATTLEBEATS.HideNotification()
    else
        if BATTLEBEATS.currentStation and IsValid(BATTLEBEATS.currentStation) then
            BATTLEBEATS.ShowTrackNotification(BATTLEBEATS.currentStation:GetFileName(), BATTLEBEATS.isInCombat)
        end
    end
end)

cvars.AddChangeCallback("battlebeats_show_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        BATTLEBEATS.HideNotification()
    else
        if BATTLEBEATS.currentStation and IsValid(BATTLEBEATS.currentStation) and persistentNotification:GetBool() then
            BATTLEBEATS.ShowTrackNotification(BATTLEBEATS.currentStation:GetFileName(), BATTLEBEATS.isInCombat)
        end
    end
end)

local warningBox

local function applyVolume()
    local sName = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetFileName() or nil
    if IsValid(BATTLEBEATS.currentStation) then
        local tgVolume = BATTLEBEATS.adjustVolume(sName)
        BATTLEBEATS.currentStation:SetVolume(tgVolume)
    end
    if IsValid(BATTLEBEATS.currentPreviewStation) then
        local tgVolume = BATTLEBEATS.adjustVolume(sName, nil, true)
        BATTLEBEATS.currentPreviewStation:SetVolume(tgVolume)
    end
end

cvars.AddChangeCallback("battlebeats_volume_ambient", function(_, _, newValue)
    local newVolume = tonumber(newValue)
    if not newVolume then return end
    applyVolume()
end)


cvars.AddChangeCallback("battlebeats_volume_combat", function(_, _, newValue)
    local newVolume = tonumber(newValue)
    if not newVolume then return end
    applyVolume()
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
            applyVolume()
            warningBox:Close()
        end)

        createButton("#btb.main.volume_cancel", 220, 120, function()
            RunConsoleCommand("battlebeats_volume", tostring(math.min(oldValue or 100, 200)))
            warningBox:Close()
        end, true)
    else
        cookie.Set("battlebeats_high_volume_warn", "0")
        cookie.Set("battlebeats_high_volume_time", "0")
        applyVolume()
    end
end)

concommand.Add("battlebeats_restart", function()
    BATTLEBEATS.errorCount = 0
    if not table.IsEmpty(BATTLEBEATS.currentPacks) then
        local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks)
        if track then BATTLEBEATS.PlayNextTrack(track) end
    end
end)

concommand.Add("battlebeats_force_next_track", function()
    if IsValid(BATTLEBEATS.currentPreviewStation) then
        BATTLEBEATS.SwitchPreviewTrack(1)
    elseif not table.IsEmpty(BATTLEBEATS.currentPacks) then
        local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks)
        if track then BATTLEBEATS.PlayNextTrack(track) end
    end
end)

print("BattleBeats Loading...")