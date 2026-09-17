BATTLEBEATS = BATTLEBEATS or {}
local btb = BATTLEBEATS

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

btb.disableAmbient = false
btb.disableCombat = false

btb.currentStation = btb.currentStation or nil
btb.currentPreviewStation = btb.currentPreviewStation or nil
btb.currentPreviewPosition = btb.currentPreviewPosition or nil
btb.currentPreviewTrack = btb.currentPreviewTrack or nil
btb.frame = btb.frame or nil
btb.isInCombat = btb.isInCombat or false
btb.currentPacks = btb.currentPacks or {}
btb.musicPacks = btb.musicPacks or {}
btb.priorityStates = btb.priorityStates or {}
btb.packVolume = btb.packVolume or {}
btb.musicPlaylists = btb.musicPlaylists or {}

btb.trackData = btb.trackData or {}
btb.trackDataCache = btb.trackDataCache or {}

btb.fadeMul = btb.fadeMul or 1
btb.globalFade = btb.globalFade or nil
btb.fades = btb.fades or {}
btb.fadeStates = btb.fadeStates or {}
btb.threatLevel = 1

--Dev
btb.disableSwitch = btb.disableSwitch or false -- btb.isInCombat will still update
btb.disableNextTrackTimer = btb.disableNextTrackTimer or false
btb.disableCheckingTimer = btb.disableCheckingTimer or false

btb.currentVersion = "2.9.7"
CreateClientConVar("battlebeats_seen_version", "", true, false)

CreateClientConVar("battlebeats_detection_mode", "1", true, true, "", 0, 1)
CreateClientConVar("battlebeats_npc_combat", "0", true, true, "", 0, 1)

local allowEnforce = CreateClientConVar("battlebeats_allow_server", "1", true, false, "", 0, 1)
local allowNoti = GetConVar("battlebeats_server_client_allow_notifications")
local allowSub = GetConVar("battlebeats_server_client_allow_subtitles")

local maxDistance = GetConVar("battlebeats_server_max_distance")

local volumeSet = CreateClientConVar("battlebeats_volume", "100", true, false, "", 0, 1000)
local debugMode = CreateClientConVar("battlebeats_debug_mode", "0", true, true, "", 0, 1)
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
local forceCombat = CreateClientConVar("battlebeats_force_combat", "0", true, false, "", 0, 1)
local disableFade = CreateClientConVar("battlebeats_disable_fade", "0", true, false, "", 0, 1)
local favMultiplier = CreateClientConVar("battlebeats_favorite_weight", "3", true, false, "", 1, 10)

local enableSubtitles = CreateClientConVar("battlebeats_subtitles_enabled", "1", true, false, "", 0, 1)

local ambientVolume = CreateClientConVar("battlebeats_volume_ambient", "100", true, false, "", 0, 100)
local combatVolume = CreateClientConVar("battlebeats_volume_combat", "100", true, false, "", 0, 100)

local dynamicVolume = CreateClientConVar("battlebeats_dynamic_volume", "1", true, true, "", 0, 1)
local lowerInMenu = CreateClientConVar("battlebeats_lower_volume_in_menu", "1", true, false, "", 0, 1)
local lowerVC = CreateClientConVar("battlebeats_lower_volume_on_voice_chat", "1", true, false, "", 0, 1)

local switchOnLower = CreateClientConVar("battlebeats_switch_on_lower_priority", "1", true, false, "", 0, 1)
local enableAssignedTracks = CreateClientConVar("battlebeats_enable_assigned_tracks", "1", true, false, "", 0, 1)
--local switchOnNoNPC = CreateClientConVar("battlebeats_switch_on_no_npc_track", "1", true, false, "", 0, 1)
local excludeMappedTracks = CreateClientConVar("battlebeats_exclude_mapped_tracks", "0", true, false, "", 0, 1)
local lastCombatTrackPriority = 0
--local lastCombatPriorityTrack = nil

local function debugPrint(...)
    if debugMode:GetBool() then print("[BattleBeats Debug] " .. ...) end
end

function btb.getTrackData(t, cached)
    local d = (cached and btb.trackDataCache or btb.trackData)[t]
    return d or {}
end
function btb.setTrackData(t, k, v, cached)
    local x = cached and btb.trackDataCache or btb.trackData
    if v == nil then
        local d = x[t]
        if not d then return end
        d[k] = nil
        if next(d) == nil then x[t] = nil end
        return
    end
    x[t] = x[t] or {}
    x[t][k] = v
end

function btb.ValidatePacks()
    local ha, hc = false, false
    for p in pairs(btb.currentPacks) do
        local pk = btb.musicPacks[p]
        if pk then
            if pk.ambient and #pk.ambient > 0 then ha = true end
            if pk.combat and #pk.combat > 0 then hc = true end
        end
    end
    local adis = cookie.GetNumber("battlebeats_auto_disabled_ambient", 0) == 1
    local cdis = cookie.GetNumber("battlebeats_auto_disabled_combat", 0) == 1
    if not ha and enableAmbient:GetBool() then
        RunConsoleCommand("battlebeats_enable_ambient", "0")
        cookie.Set("battlebeats_auto_disabled_ambient", "1")
    elseif ha and adis then
        RunConsoleCommand("battlebeats_enable_ambient", "1")
        cookie.Set("battlebeats_auto_disabled_ambient", "0")
    end
    if not hc and enableCombat:GetBool() then
        RunConsoleCommand("battlebeats_enable_combat", "0")
        cookie.Set("battlebeats_auto_disabled_combat", "1")
    elseif hc and cdis then
        RunConsoleCommand("battlebeats_enable_combat", "1")
        cookie.Set("battlebeats_auto_disabled_combat", "0")
    end
end

--MARK:Volume + Fade
--------------------------------------------------------------------------------------

function btb.adjustVolume(track, baseVolume, isPreview)
    local masterVolume = volumeSet:GetInt() / 100
    if not track or track == "" then
        return math.Clamp(math.Round((baseVolume or masterVolume) * (btb.fadeMul or 1), 2), 0, 10)
    end

    local d = btb.getTrackData(track, true)
    local vt = d.type == "ambient" and ambientVolume:GetInt() or d.type == "combat" and combatVolume:GetInt()
    local tgVolume = baseVolume or (vt / 100 * masterVolume)
    tgVolume = hook.Run("BattleBeats_PreAdjustVolume", track, tgVolume) or tgVolume

    local finalVol = tgVolume
    local packName = btb.getTrackData(track, true).pack
    if packName and btb.packVolume then
        local packAdj = btb.packVolume[packName]
        if packAdj then
            local packMult = math.Clamp(packAdj / 100, 0, 2)
            finalVol = finalVol * packMult
        end
    end

    local trackAdj = btb.getTrackData(track).vol or nil
    if trackAdj then
        local trackMult = math.Clamp(trackAdj / 100, 0, 2)
        finalVol = finalVol * trackMult
    end

    finalVol = hook.Run("BattleBeats_PostAdjustVolume", track, finalVol) or finalVol
    finalVol = finalVol * (btb.fadeMul or 1)
    finalVol = math.Clamp(finalVol, 0, 10)

    return math.Round(finalVol, 2)
end

-- this is used only to start or stop tracks
local lerp = Lerp
function btb.FadeMusic(st, fadeIn, fadeTime, isPreview)
    if not IsValid(st) then return end
    fadeTime = fadeTime or 2

    local base = btb.adjustVolume(st:GetFileName(), nil, isPreview)
    if disableFade:GetBool() or fadeTime == 0 then
        btb.fades[st] = nil
        if fadeIn then
            st:SetVolume(base)
        else
            st:SetVolume(0)
            st:Stop()
        end
        hook.Run("BattleBeats_PostFade", st, fadeIn)
        return
    end

    local old = btb.fades[st]
    local cur = old and lerp(math.Clamp(old.t / old.time, 0, 1), old.from, old.to) or nil

    if fadeIn then
        st:SetVolume(0)
        cur = 0
    else
        cur = cur or (base > 0 and st:GetVolume() / base or 1)
        cur = math.Clamp(cur, 0, 1)
    end

    btb.fades[st] = {
        from = cur,
        to = fadeIn and 1 or 0,
        time = fadeTime,
        t = 0,
        prio = 2,
        music = true,
        inn = fadeIn,
        preview = isPreview
    }

    debugPrint("[FadeMusic] Start " .. (fadeIn and "IN " or "OUT ") .. (isPreview and "[PREVIEW] " or "[AUTO] ") .. tostring(st) .. " targetVolume: " .. tostring(base))
end

local function fadeTo(volume, fadeTime)
    volume = math.Clamp(volume or 1, 0, 10)
    fadeTime = fadeTime or 2
    local f = btb.globalFade
    local from = f and lerp(math.Clamp(f.t / f.time, 0, 1), f.from, f.to) or (btb.fadeMul or 1)
    if from == volume then return end
    if fadeTime <= 0 then
        btb.fadeMul = volume
        btb.globalFade = nil
        local st = btb.currentStation
        if IsValid(st) and not btb.fades[st] then
            st:SetVolume(btb.adjustVolume(st:GetFileName()))
        end
        local pv = btb.currentPreviewStation
        if IsValid(pv) and not btb.fades[pv] then
            pv:SetVolume(btb.adjustVolume(pv:GetFileName(), nil, true))
        end
        return
    end
    btb.globalFade = {from = from, to = volume, time = fadeTime, t = 0}
end

function btb.SetFade(id, volume, fadeTime, isBoost, stack)
    if volume == nil then
        btb.fadeStates[id] = nil
    else
        btb.fadeStates[id] = {volume = volume, boost = isBoost, stack = stack}
    end
    local boost = 1
    local multiplier = 1
    local stack = 1
    for _, f in pairs(btb.fadeStates) do
        if f.boost then
            boost = math.max(boost, f.volume)
        elseif f.stack then
            stack = stack * f.volume
        else
            multiplier = math.min(multiplier, f.volume)
        end
    end
    if multiplier >= 0.5 then multiplier = math.max(multiplier * stack, 0.5) end
    fadeTo(boost * multiplier, fadeTime)
end

hook.Add("Think", "BattleBeats_FadeSystem", function()
    local ft = FrameTime()

    if btb.globalFade then
        local f = btb.globalFade
        f.t = math.min(f.t + ft, f.time)
        local p = f.time > 0 and f.t / f.time or 1
        btb.fadeMul = lerp(p, f.from, f.to)
        if p >= 1 then
            btb.fadeMul = f.to
            btb.globalFade = nil
        end
    end

    for st, f in pairs(btb.fades) do
        if not IsValid(st) then
            btb.fades[st] = nil
            continue
        end
        f.t = math.min(f.t + ft, f.time)
        local p = f.time > 0 and f.t / f.time or 1
        local v = btb.adjustVolume(st:GetFileName(), nil, f.preview)
        st:SetVolume(v * lerp(p, f.from, f.to))
        if p >= 1 then
            btb.fades[st] = nil
            if f.music then
                hook.Run("BattleBeats_PostFade", st, f.inn)
                if not f.inn then
                    st:SetVolume(0)
                    st:Stop()
                end
            end
            if f.cb then f.cb(st) end
        end
    end

    if not btb.globalFade then return end -- good enough, we dont need to match the volume 1:1 

    local st = btb.currentStation
    if IsValid(st) and not btb.fades[st] then
        st:SetVolume(btb.adjustVolume(st:GetFileName()))
    end
    local pv = btb.currentPreviewStation
    if IsValid(pv) and not btb.fades[pv] then
        pv:SetVolume(btb.adjustVolume(pv:GetFileName(), nil, true))
    end
end)

local function removeSoundTimers()
    if timer.Exists("BattleBeats_NextTrack") then timer.Remove("BattleBeats_NextTrack") end
    if timer.Exists("BattleBeats_CheckSound") then timer.Remove("BattleBeats_CheckSound") end
end

--MARK:Random track
--------------------------------------------------------------------------------------

local function same(t1, t2)
    local p1 = btb.getTrackData(t1, true).pack
    local p2 = btb.getTrackData(t2, true).pack
    debugPrint("[Same Pack] packA: " .. p1 .. " | packB:" .. p2)
    return p1 ~= nil and p1 == p2
end

function btb.GetRandomTrack(packs, isCombat, previousTrack, exclusivePlayOnly)
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
        local packName = btb.getTrackData(previousTrack, true).pack -- restrict to same pack if exclusive play is enabled
        debugPrint("[GetRandomTrack] Exclusive play enabled. Using pack: " .. tostring(packName))
        if packName and btb.musicPacks[packName] then
            local selectedTracks = isCombat and btb.musicPacks[packName].combat or btb.musicPacks[packName].ambient
            if selectedTracks and #selectedTracks > 0 then
                for _, t in ipairs(selectedTracks) do
                    table.insert(allTracks, t)
                end
            else
                debugPrint("[GetRandomTrack] Selected pack is empty. Falling back to all")
                for packName, _ in pairs(packs) do
                    if btb.musicPacks[packName] then
                        local tracks = isCombat and btb.musicPacks[packName].combat or btb.musicPacks[packName].ambient
                        for _, track in ipairs(tracks or {}) do
                            table.insert(allTracks, track)
                        end
                    end
                end
            end
        end
    else
        for packName, _ in pairs(packs) do --not in exclusive mode: use all tracks from all selected pack
            if btb.musicPacks[packName] then
                local tracks = isCombat and btb.musicPacks[packName].combat or btb.musicPacks[packName].ambient
                for _, track in ipairs(tracks) do
                    table.insert(allTracks, track)
                end
            end
        end
    end
    debugPrint("[GetRandomTrack] Found " .. #allTracks .. " tracks before exclusion")
    if #allTracks > 0 then
        local availableTracks = {}
        local emp = excludeMappedTracks:GetBool()
        for _, track in ipairs(allTracks) do
            local td = btb.getTrackData(track)
            local hasMapping = td.npcMap and #td.npcMap > 0
            local ex = td.exl or (emp and hasMapping)
            local o = hook.Run("BattleBeats_ShouldExcludeTrack", track, hasMapping, isCombat)
            if o == true then continue end
            if o == false then ex = false end
            if not ex then availableTracks[#availableTracks + 1] = track end
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
            local chosen
            local fmul = favMultiplier:GetInt()
            if fmul <= 1 then
                chosen = availableTracks[math.random(#availableTracks)]
            else
                local n = 0
                for _, t in ipairs(availableTracks) do n = n + (btb.getTrackData(t).fav and fmul or 1) end
                local r = math.random(n)
                for _, t in ipairs(availableTracks) do
                    r = r - (btb.getTrackData(t).fav and fmul or 1)
                    if r <= 0 then
                        chosen = t
                        break
                    end
                end
            end
            local override = hook.Run("BattleBeats_OnTrackSelected", chosen, isCombat)
            if isstring(override) then return override end
            return chosen
        else
            local fallbackTrack = allTracks[math.random(#allTracks)]
            local override = hook.Run("BattleBeats_OnFallbackTrack", fallbackTrack, isCombat)
            if isstring(override) then return override end
            notification.AddLegacy("#btb.main.allexcluded", NOTIFY_ERROR, 4)
            return fallbackTrack
        end
    end
    return nil
end

local function errr(t, c, es)
    notification.AddLegacy("#btb.main.soundfail", NOTIFY_ERROR, 4)
    MsgC(
        Color(255, 255, 0), "[BattleBeats Client] ",
        Color(255, 255, 255), "Error playing sound: ",
        Color(255, 255, 0), t .. " ",
        Color(255, 255, 255), "Code: ",
        Color(0, 255, 255), tostring(c) .. " ",
        Color(255, 255, 255), "Error: ",
        Color(255, 0, 255), es .. "\n"
    )
end

--MARK:Music Player
--------------------------------------------------------------------------------------

local isPreviewing = false
function btb.PlayNextTrackPreview(track, time, isLooped, errCallback)
    removeSoundTimers()
    if btb.currentStation and IsValid(btb.currentStation) then
        if track == btb.currentStation:GetFileName() then
            debugPrint("[Preview] Same track already playing, switching to preview")
            btb.FadeMusic(btb.currentStation, false, 0)
            btb.currentStation = nil
        else
            btb.FadeMusic(btb.currentStation, false)
        end
    end
    if btb.currentPreviewStation and IsValid(btb.currentPreviewStation) then
        btb.FadeMusic(btb.currentPreviewStation, false)
    end
    if showPreviewNotification:GetBool() and not isLooped then btb.ShowTrackNotification(track, false, true) end
    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if IsValid(station) then
            isPreviewing = true
            btb.currentPreviewStation = station
            station:SetVolume(0)
            station:Play()
            station:SetTime(time or 0, true)
            btb.FadeMusic(station, true, 2, true)
        else
            timer.Simple(2, function ()
                btb.HideNotification()
            end)
            errr(track, errCode, errStr)
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
        btb.PlayNextTrack(override)
        return
    end

    if istable(override) then
        btb.PlayNextTrack(override.track or track, override.time or 0, override.noFade, override.cFadeIn or nil, override.cFadeOut or nil, override.priority or priority)
        return
    end

    -- default behavior
    if priority then
        btb.PlayNextTrack(track, 0, nil, nil, priority) -- looping assigned tracks
        local state = btb.priorityStates[priority] or {}
        state.length = 0
        btb.priorityStates[priority] = state
    else
        local nextTrack = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat)
        if nextTrack then btb.PlayNextTrack(nextTrack) end
    end
end

btb.errorCount = 0
function btb.PlayNextTrack(track, time, cFadeIn, cFadeOut, priority, propeties)
    propeties = propeties or {}
    if not track or track == "" then
        debugPrint("[PlayNextTrack] Attempted to play nil/empty track! Aborting...")
        return
    end
    if btb.errorCount > 3 then
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
    if btb.currentStation and IsValid(btb.currentStation) then
        cFadeOut = cFadeOut and math.Clamp(cFadeOut, 0, 10) or nil
        btb.FadeMusic(btb.currentStation, false, cFadeOut)
    end

    -- store last track info based on combat state
    if not btb.isInCombat then
        lastAmbienceTrack = track
        cookie.Set("battlebeats_last_track", lastAmbienceTrack)
        lastAmbienceLength = 0
    else
        lastCombatTrack = track
        lastCombatLength = 0
    end

    if (not time or replayNotification:GetBool() or persistentNotification:GetBool()) and showNotification:GetBool() and volumeSet:GetInt() > 0 then
        if not (allowEnforce:GetBool() and not allowNoti:GetBool()) then
            if not propeties.noNotification == true then
                btb.ShowTrackNotification(track, btb.isInCombat)
            end
        end
    end

    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if IsValid(station) then
            btb.errorCount = 0
            isPreviewing = false
            btb.currentStation = station
            station:SetVolume(0)
            station:Play()
            local trimData = btb.getTrackData(track).trim
            local offset = trimData and trimData.start or 0
            station:SetTime(time or offset, true)
            hook.Run("BattleBeats_OnTrackStarted", station, track, btb.isInCombat, priority)
            cFadeIn = cFadeIn and math.Clamp(cFadeIn, 0, 10) or nil
            btb.FadeMusic(station, true, cFadeIn)

            if enableSubtitles:GetBool() then
                local subtitleTrack = btb.FormatTrackName(track)
                if btb.parsedSubtitles and btb.parsedSubtitles[string.lower(subtitleTrack)] then
                    if not (allowEnforce:GetBool() and not allowSub:GetBool()) then
                        btb.StartSubtitles(subtitleTrack, station)
                    end
                end
            end

            removeSoundTimers()

            local trackLength = trimData and trimData.finish or station:GetLength()
            if not btb.isInCombat then
                lastAmbiencePosition = station:GetTime()
                lastAmbienceTotalLength = trackLength
            else
                lastCombatPosition = station:GetTime()
                lastCombatTotalLength = trackLength
            end

            local loop = propeties.loop == true
            local startTime = time or 0
            local playDuration = math.max(trackLength - startTime - 0.5, 1)

            debugPrint("[PlayNextTrack] Track length: " .. math.Truncate(trackLength or 0, 1) .. " (s) | Will play for: " .. math.Truncate(playDuration or 0, 1) .. " (s)")

            timer.Create("BattleBeats_NextTrack", playDuration, 1, function() -- timer to play next track when current finishes
                if btb.disableNextTrackTimer then return end
                    if loop then
                        debugPrint("[PlayNextTrack] Looping track: " .. tostring(track))
                        if timer.Exists("BattleBeats_CheckSound") then timer.Remove("BattleBeats_CheckSound") end
                        btb.PlayNextTrack(track, nil, 0, nil, priority, propeties)
                        return
                    end
                debugPrint("[PlayNextTrack] Timer reached end. Selecting next track")
                if timer.Exists("BattleBeats_CheckSound") then timer.Remove("BattleBeats_CheckSound") end
                if (btb.isInCombat and not enableCombat:GetBool()) or
                    (not btb.isInCombat and not enableAmbient:GetBool()) then
                    return
                end
                handleTrackEnd(track, "finished", priority)
            end)

            timer.Create("BattleBeats_CheckSound", 1, 0, function() -- timer to check if track stops playing unexpectedly
                if not IsValid(station) or (station:GetState() ~= GMOD_CHANNEL_PLAYING and station:GetState() ~= GMOD_CHANNEL_STALLED) then
                    if btb.disableCheckingTimer then return end
                    debugPrint("[PlayNextTrack] Track stopped unexpectedly. Selecting next track")
                    timer.Remove("BattleBeats_CheckSound")
                    if timer.Exists("BattleBeats_NextTrack") then timer.Remove("BattleBeats_NextTrack") end
                    if (btb.isInCombat and not enableCombat:GetBool()) or
                        (not btb.isInCombat and not enableAmbient:GetBool()) then
                        return
                    end
                    handleTrackEnd(track, "stopped", priority)
                end
                -- update playback length and position
                if IsValid(station) then
                    if priority then
                        local state = btb.priorityStates[priority] or {}
                        if state.track == track then
                            state.length = (state.length or 0) + 1
                        else
                            state.length = 0
                        end
                        state.track = track
                        state.position = station:GetTime()
                        state.totalLength = station:GetLength()
                        state.time = CurTime()
                        btb.priorityStates[priority] = state
                    else
                        if not btb.isInCombat then
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
            btb.errorCount = btb.errorCount + 1
            errr(track, errCode, errStr)
            hook.Run("BattleBeats_OnTrackEnded", track, "error", priority)
            local _override = hook.Run("BattleBeats_OnTrackError", track, errCode, errStr, btb.isInCombat, priority)
            if _override == true then return end
            if isstring(_override) then
                btb.PlayNextTrack(_override)
                return
            end
            local nextTrack = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat)
            if nextTrack then btb.PlayNextTrack(nextTrack) end
        end
    end)
end

local cleanupTrack = nil
local cleanupTime = nil
hook.Add("PreCleanupMap", "BattleBeats_SaveMusic", function()
    if IsValid(btb.currentStation) then
        cleanupTrack = btb.currentStation:GetFileName()
        cleanupTime = btb.currentStation:GetTime()
    end
end)

hook.Add("PostCleanupMap", "BattleBeats_ResumeMusic", function()
    if not isPreviewing then
        if not cleanupTrack then return end
        btb.PlayNextTrack(cleanupTrack, cleanupTime)
    else
        if not btb.currentPreviewTrack then return end
        btb.PlayNextTrackPreview(btb.currentPreviewTrack, btb.currentPreviewPosition)
    end
end)

function btb.ValidateTrack(track, errCallback)
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

local lastAliveState = true
local lastMuteState = false
timer.Create("BattleBeats_ClientAliveCheck", 0.5, 0, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local isAlive = ply:Alive()
    if isAlive ~= lastAliveState then
        lastAliveState = isAlive
        if isAlive then
            btb.SetFade("death", nil, 2, false)
        elseif disableMode:GetInt() == 1 then
            btb.SetFade("death", 0, 2, false)
        elseif disableMode:GetInt() == 2 then
            btb.SetFade("death", 0.3, 2, false)
        end
    end

    if isAlive and lowerInMenu:GetBool() then
        local spawnMenu = g_SpawnMenu and g_SpawnMenu:IsVisible()
        local isOpen = gui.IsGameUIVisible() or spawnMenu
        if isOpen ~= lastMuteState then
            lastMuteState = isOpen
            btb.SetFade("menu", isOpen and 0.5 or nil, 0.8, false)
        end
    end
end)

timer.Create("BattleBeats_ClientVolCheck", 5, 0, function()
    if volumeSet:GetInt() > 200 then
        local time = tonumber(cookie.GetString("battlebeats_high_volume_time", "0")) or 0
        time = time + 5
        cookie.Set("battlebeats_high_volume_time", tostring(time))
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
        btb.PlayNextTrack(track, offset, nil, nil, priority)
    else
        local fallbackTrack = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat, fallbackTrackRef, exclusiveOnly)
        if fallbackTrack then btb.PlayNextTrack(fallbackTrack) end
    end
end

local npcTrackMap = {}
function btb.buildNPCTrackMap()
    npcTrackMap = {}
    for track, d in pairs(btb.trackData) do
        for _, m in ipairs(d.npcMap or {}) do
            npcTrackMap[m.class] = npcTrackMap[m.class] or {}
            npcTrackMap[m.class][#npcTrackMap[m.class] + 1] = {track = track, priority = m.priority}
        end
    end
end

local function getNPCMatchingTrack()
    local override = hook.Run("BattleBeats_SelectNPCTrack")
    if override == true then return nil end
    if isstring(override) then return override end

    local ply = LocalPlayer()
    if not IsValid(ply) or not enableAssignedTracks:GetBool() then return nil end

    local nearbyNPCs = ents.FindInSphere(ply:GetPos(), maxDistance:GetInt())
    local candidates = {}

    for _, ent in ipairs(nearbyNPCs) do
        if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
            local cls = ent.GetClass and ent:GetClass()
            local maps = cls and npcTrackMap[cls]
            if maps then
                for _, m in ipairs(maps) do
                    candidates[m.track] = math.min(candidates[m.track] or 6, m.priority)
                end
            end
        end
    end

    if table.IsEmpty(candidates) then return nil end

    local best = 6
    local tracks = {}
    for t, p in pairs(candidates) do
        if p < best then
            best = p
            tracks = {t}
        elseif p == best then
            tracks[#tracks + 1] = t
        end
    end
    return tracks[math.random(#tracks)]
end

local function getTrackPriority(track)
    local override = hook.Run("BattleBeats_GetNPCTrackPriority", track)
    if isnumber(override) then return override end
    local td = btb.getTrackData(track)
    if not td.npcMap then return 6 end
    local minPrio = 6
    for _, npc in ipairs(td.npcMap) do
        if npc.priority < minPrio then minPrio = npc.priority end
    end
    return minPrio
end

local function switchTrack(npcTrack)
    if IsValid(btb.currentPreviewStation) then return end
    if not GetConVar("battlebeats_persistent_notification"):GetBool() then
        btb.HideNotification()
    end
    if btb.isInCombat then
        if npcTrack then
            local priority = getTrackPriority(npcTrack)
            local npcState = btb.priorityStates[priority]
            local shouldContinue = npcState and ((CurTime() - npcState.time <= combatWaitTime:GetInt()) or alwaysContinue:GetBool()) or false

            if npcState and npcState.track == npcTrack and shouldContinue then
                local offset = getOffset(npcState.position, lastAmbienceLength, npcState.totalLength)
                tryPlayTrackWithOffset(npcState.track, offset, lastAmbienceTrack, false, priority)
            else
                btb.PlayNextTrack(npcTrack, nil, nil, nil, priority)
            end
            lastCombatTrackPriority = priority
        else
            local shouldContinue = (CurTime() - ambienceStartTime <= combatWaitTime:GetInt() and lastCombatTrack) or (alwaysContinue:GetBool() and lastCombatTrack)
            if shouldContinue then
                if exclusivePlay:GetBool() and lastAmbienceTrack then
                    local samePack = same(lastCombatTrack, lastAmbienceTrack)
                    if not samePack then
                        -- pick a different track from same pack
                        local track = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat, lastAmbienceTrack, true)
                        if track then btb.PlayNextTrack(track) end
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
                    local track = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat, lastAmbienceTrack, true)
                    if track then btb.PlayNextTrack(track) end
                else
                    local track = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat, lastAmbienceTrack)
                    if track then btb.PlayNextTrack(track) end
                end
            end
            lastCombatTrackPriority = 0
        end
    else
        if not enableAmbient:GetBool() then
            if btb.currentStation and IsValid(btb.currentStation) then btb.FadeMusic(btb.currentStation, false) end
            btb.HideNotification()
            return
        end
        if (CurTime() - combatStartTime <= ambientWaitTime:GetInt() and lastAmbienceTrack) or (alwaysContinue:GetBool() and lastAmbienceTrack) then
            if exclusivePlay:GetBool() and lastCombatTrack then
                local samePack = same(lastAmbienceTrack, lastCombatTrack)
                if not samePack then
                    local track = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat, lastCombatTrack, true)
                    if track then btb.PlayNextTrack(track) end
                else
                    local offset = getOffset(lastAmbiencePosition, lastCombatLength, lastAmbienceTotalLength)
                    tryPlayTrackWithOffset(lastAmbienceTrack, offset, lastCombatTrack, true)
                end
            else
                local offset = getOffset(lastAmbiencePosition, lastCombatLength, lastAmbienceTotalLength)
                tryPlayTrackWithOffset(lastAmbienceTrack, offset, lastCombatTrack)
            end
        else
            local track = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat, lastCombatTrack)
            if track then btb.PlayNextTrack(track) end
        end
    end
end

local pendingSwitch = nil
local pendingTrack = nil
local lastThreatBoost = nil

local lastCombatState = false
local lastCombatEnemyState = false
local combatNoEnemyTime = nil
local combatFadeLevel = nil
local combatPeak = 1
local combatAfterglowTime = nil
local combatAfterglowStage = -1

timer.Create("BattleBeats_ClientCombatCheck", 0.5, 0, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local curTime = CurTime()

    btb.isInCombat = ply:GetNWBool("BattleBeats_InCombat", false)
    local isEnemy = ply:GetNWBool("BattleBeats_HasCombatEnemy", false)
    btb.threatLevel = ply:GetNWInt("BattleBeats_ThreatLevel", 1)

    if forceCombat:GetBool() and enableCombat:GetBool() then
        btb.isInCombat = true
    end

    if dynamicVolume:GetBool() and not btb.isInCombat and combatAfterglowTime then
        if combatPeak ~= 1 then
            local e = curTime - combatAfterglowTime
            local st, lv

            if combatPeak == 3 then
                if e >= 10 then
                    st, lv = 3, nil
                elseif e >= 6 then
                    st, lv = 2, 0.7
                else
                    st, lv = 1, 0.4
                end
            elseif combatPeak == 2 then
                if e >= 6 then
                    st, lv = 2, nil
                else
                    st, lv = 1, 0.6
                end
            end

            if st ~= combatAfterglowStage then
                combatAfterglowStage = st
                btb.SetFade("combat afterglow", lv, 1, false)
            end

            if st == 3 or (combatPeak == 2 and st == 2) then
                combatAfterglowTime = nil
                combatPeak = 1
                combatAfterglowStage = -1
            end
        else
            combatAfterglowTime = nil
            combatPeak = 1
            combatAfterglowStage = -1
        end
    end

    if dynamicVolume:GetBool() then
        local threatBoost = btb.threatLevel == 3 and 1.6 or btb.threatLevel == 2 and 1.3 or nil
        local threatSwitch = btb.threatLevel == 3 and 1 or btb.threatLevel == 2 and 2 or 3

        if threatBoost ~= lastThreatBoost then
            lastThreatBoost = threatBoost
            btb.SetFade("threat", threatBoost, threatSwitch, true)
        end

        local shouldLower = btb.isInCombat and not isEnemy
        if shouldLower ~= lastCombatEnemyState then
            lastCombatEnemyState = shouldLower
            if shouldLower then
                combatNoEnemyTime = curTime
                combatFadeLevel = nil
            else
                combatNoEnemyTime = nil
                combatFadeLevel = nil
                btb.SetFade("combat no enemies", nil, 3, false)
            end
        end

        if shouldLower and combatNoEnemyTime then
            local elapsed = curTime - combatNoEnemyTime
            local t = combatPeak == 3 and 14 or combatPeak == 2 and 10 or 6
            local t2 = combatPeak == 3 and 8 or combatPeak == 2 and 5 or 2
            local newLevel
            if elapsed >= t then
                newLevel = 0.6
            elseif elapsed >= t2 then
                newLevel = 0.8
            end
            if newLevel and newLevel ~= combatFadeLevel then
                combatFadeLevel = newLevel
                btb.SetFade("combat no enemies", newLevel, 3, false)
            end
        end
    end

    if btb.disableSwitch then return end

    if btb.isInCombat ~= lastCombatState then
        if ambienceStartTime == nil then ambienceStartTime = curTime end
        lastCombatState = btb.isInCombat
        btb.FireNodeByClass("condition.IN_COMBAT_BTB", "isincombat", btb.isInCombat and 1 or 0)
        if btb.isInCombat then
            btb.FireNodeByClass("event.COMBAT_START_BTB", "start", 1)
            combatStartTime = curTime
            combatPeak = btb.threatLevel
            combatAfterglowTime = nil
            combatAfterglowStage = -1
            btb.SetFade("combat afterglow", nil, 3, false)
            local npcTrack = getNPCMatchingTrack()
            if btb.disableCombat then
                removeSoundTimers()
                btb.FadeMusic(btb.currentStation)
                return
            end
            local success, err = pcall(switchTrack, npcTrack)
            if not success then
                print("[BattleBeats Client] BattleBeats_ClientCombatCheck error: " .. tostring(err))
            end
        else
            btb.FireNodeByClass("event.AMBIENT_START_BTB", "start", 1)
            btb.SetFade("combat no enemies", nil, 3, false) -- just to be safe
            ambienceStartTime = curTime
            combatAfterglowTime = curTime
            combatAfterglowStage = -1
            if btb.disableAmbient then
                removeSoundTimers()
                btb.FadeMusic(btb.currentStation)
                return
            end
            local success, err = pcall(switchTrack, nil)
            if not success then
                print("[BattleBeats Client] BattleBeats_ClientCombatCheck error: " .. tostring(err))
            end
            lastCombatTrackPriority = 0 
        end
    elseif btb.isInCombat then
        combatPeak = math.max(combatPeak, btb.threatLevel)
        if pendingSwitch then
            if curTime >= pendingSwitch.time then
                local success, err = pcall(switchTrack, pendingSwitch.track)
                if not success then print("[BattleBeats Client] NPC track switch error: " .. tostring(err)) end
                pendingSwitch = nil
                pendingTrack = nil
            end
            return
        end

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
                pendingSwitch = { track = npcTrack, time = curTime + 2 }
                pendingTrack = npcTrack
            end
        end
    end
end)

--MARK:Misc
--------------------------------------------------------------------------------------

-- day 69420 of asking rubat to add DSP effects to bass channels
net.Receive("BTB_ExplosionFade", function()
    if not dynamicVolume:GetBool() then return end
    btb.SetFade("grenade dsp", 0.15, 0.5, false)
    timer.Remove("BattleBeats_ExplosionDSP")
    timer.Create("BattleBeats_ExplosionDSP", 1.5, 1, function()
        btb.SetFade("grenade dsp", nil, 1, false)
    end)
end)

local voiceActive = false
local function checkVC()
    timer.Create("BattleBeats_VoiceCheck", 0.25, 0, function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local speaking = false
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsSpeaking() then
                speaking = true
                break
            end
        end
        if speaking == voiceActive then return end
        voiceActive = speaking
        btb.SetFade("voice chat", speaking and 0.5 or nil, 0.15, false)
    end)
end
if not game.SinglePlayer() and lowerVC:GetBool() then
    checkVC()
end

cvars.AddChangeCallback("battlebeats_lower_volume_on_voice_chat", function(_, _, newValue)
    if tonumber(newValue) == 0 and not game.SinglePlayer() then
        timer.Remove("BattleBeats_VoiceCheck")
        btb.SetFade("voice chat", nil, 1, false)
    elseif tonumber(newValue) == 1 and not game.SinglePlayer() then
        checkVC()
    end
end)

cvars.AddChangeCallback("battlebeats_dynamic_volume", function(_, _, newValue)
    if tonumber(newValue) == 0 and btb.isInCombat then
        btb.SetFade("combat no enemies", nil, 1, false)
        btb.SetFade("threat", nil, 1, true)
    elseif tonumber(newValue) == 0 and not btb.isInCombat then
        combatAfterglowTime = nil
        combatAfterglowStage = -1
        btb.SetFade("combat afterglow", nil, 3, false)
    end
end)

cvars.AddChangeCallback("battlebeats_enable_ambient", function(_, _, newValue)
    if tonumber(newValue) == 0 and not btb.isInCombat then
        if btb.currentStation and IsValid(btb.currentStation) then btb.FadeMusic(btb.currentStation, false) end
        removeSoundTimers()
        btb.HideNotification()
    else
        if not btb.isInCombat then
            local track = btb.GetRandomTrack(btb.currentPacks, false)
            if track then btb.PlayNextTrack(track) end
        end
    end
end)

cvars.AddChangeCallback("battlebeats_show_preview_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        if IsValid(btb.currentPreviewStation) then btb.HideNotification() end
    else
        if IsValid(btb.currentPreviewStation) then btb.ShowTrackNotification(btb.currentPreviewTrack, false, true) end
    end
end)

cvars.AddChangeCallback("battlebeats_persistent_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        btb.HideNotification()
    else
        if btb.currentStation and IsValid(btb.currentStation) then
            btb.ShowTrackNotification(btb.currentStation:GetFileName(), btb.isInCombat)
        end
    end
end)

cvars.AddChangeCallback("battlebeats_show_notification", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        btb.HideNotification()
    else
        if btb.currentStation and IsValid(btb.currentStation) and persistentNotification:GetBool() then
            btb.ShowTrackNotification(btb.currentStation:GetFileName(), btb.isInCombat)
        end
    end
end)

local warningBox

local function applyVolume()
    if IsValid(btb.currentStation) then
        local sName = IsValid(btb.currentStation) and btb.currentStation:GetFileName() or nil
        local tgVolume = btb.adjustVolume(sName)
        btb.currentStation:SetVolume(tgVolume)
    end
    if IsValid(btb.currentPreviewStation) then
        local sName = IsValid(btb.currentPreviewStation) and btb.currentPreviewStation:GetFileName() or nil
        local tgVolume = btb.adjustVolume(sName, nil, true)
        btb.currentPreviewStation:SetVolume(tgVolume)
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
    btb.errorCount = 0
    btb.fadeStates = {}
    if not table.IsEmpty(btb.currentPacks) then
        local track = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat)
        if track then btb.PlayNextTrack(track) end
    end
end)

concommand.Add("battlebeats_force_next_track", function()
    if IsValid(btb.currentPreviewStation) then
        btb.SwitchPreviewTrack(1)
    elseif not table.IsEmpty(btb.currentPacks) then
        local track = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat)
        if track then btb.PlayNextTrack(track) end
    end
end)

print("BattleBeats Loading...")