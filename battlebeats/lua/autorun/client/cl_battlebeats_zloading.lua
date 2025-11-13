local autoPopup = CreateClientConVar("battlebeats_autopopup", "1", true, false, "", 0, 1)
local loadLocalPacks = CreateClientConVar("battlebeats_load_local_packs", "0", true, false, "", 0, 1)
local loadAMsuspense = CreateClientConVar("battlebeats_load_am_suspense", "0", true, false, "", 0, 1)
local debugMode = GetConVar("battlebeats_debug_mode")
local enableAmbient = GetConVar("battlebeats_enable_ambient")

file.CreateDir("battlebeats")

local function debugPrint(...)
    if debugMode:GetBool() then print("[BattleBeats Debug] " .. ...) end
end

local function recurseListContents(path, addon, direct, pattern)
    local files, dirs = file.Find(path .. "*", addon)
    files = files or {}
    dirs = dirs or {}
    local matchedFiles = {}

    for _, v in ipairs(files) do
        local fullPath = path .. v
        if not pattern or string.find(fullPath, pattern, 1, true) then
            table.insert(matchedFiles, fullPath)
        end
    end

    if direct then
        return matchedFiles
    end

    for _, dir in ipairs(dirs) do
        local subFiles = recurseListContents(path .. dir .. "/", addon, false, pattern)
        if #subFiles > 0 then
            for i = 1, #subFiles do
                matchedFiles[#matchedFiles + 1] = subFiles[i]
            end
        end
    end

    return matchedFiles
end

local function buildPaths(basePath, names)
    local out = {}
    for _, name in ipairs(names) do
        out[#out + 1] = basePath .. name
    end
    return out
end

local function pathExistsInMusicPacks(path)
    for _, pack in pairs(BATTLEBEATS.musicPacks) do
        for _, filePath in ipairs(pack.ambient or {}) do
            if filePath == path then return true end
        end
        for _, filePath in ipairs(pack.combat or {}) do
            if filePath == path then return true end
        end
    end
    return false
end

local baseDirs = { "battlebeats", "nombat", "battlemusic", "16thnote", "am_music", "ayykyu_dynmus" }

local function loadGenericMusicPacks()
    local startTime = SysTime()
    local addons = engine.GetAddons()

    for _, addon in ipairs(addons) do
        if addon.mounted then
            local title = addon.title
            local ambientFiles, combatFiles = {}, {}
            local packType = nil

            for _, dir in ipairs(baseDirs) do
                local matchedFiles = recurseListContents("sound/" .. dir .. "/", title, false)
                local isNombat = (dir == "nombat")
                local isSBM = (dir == "battlemusic")
                local is16th = (dir == "16thnote")
                local isAM = (dir == "am_music")
                local isDYNAMO = (dir == "ayykyu_dynmus")

                for _, file in ipairs(matchedFiles) do
                    if string.EndsWith(file, ".ogg") or string.EndsWith(file, ".mp3") or string.EndsWith(file, ".wav") then
                        if isNombat then
                            if file:match("/a.*%.mp3$") then
                                table.insert(ambientFiles, file)
                            elseif file:match("/c.*%.mp3$") then
                                table.insert(combatFiles, file)
                            end
                        elseif isAM then
                            if file:find("/background/", 1, true) then
                                table.insert(ambientFiles, file)
                            elseif file:find("/battle/", 1, true) or file:find("/battle_intensive/", 1, true) then
                                table.insert(combatFiles, file)
                            end
                            if loadAMsuspense:GetBool() and file:find("/suspense/", 1, true) then
                                table.insert(ambientFiles, file)
                                table.insert(combatFiles, file)
                            end
                        elseif isDYNAMO then
                            if file:find("/ambient/", 1, true) then
                                table.insert(ambientFiles, file)
                            elseif file:find("/combat/bosses/", 1, true)
                                or file:find("/combat/soldiers/", 1, true)
                                or file:find("/combat/cops/", 1, true)
                                or file:find("/combat/aliens/", 1, true) then
                                table.insert(combatFiles, file)
                            end
                        else
                            if file:find("/ambient/", 1, true) then
                                table.insert(ambientFiles, file)
                            elseif file:find("/combat/", 1, true) then
                                table.insert(combatFiles, file)
                            end
                        end
                    end
                end

                if not packType and (#ambientFiles > 0 or #combatFiles > 0) then
                    packType = isNombat and "nombat" or isSBM and "sbm" or is16th and "16thnote" or isAM and "amusic" or isDYNAMO and "dynamo" or "battlebeats"
                end
            end

            if #ambientFiles == 0 and #combatFiles == 0 then continue end

            local hasAmbient = #ambientFiles > 0
            local hasCombat = #combatFiles > 0

            if hasAmbient or hasCombat then
                local packContent = hasAmbient and hasCombat and "both"
                    or hasAmbient and "ambient"
                    or "combat"

                BATTLEBEATS.musicPacks[title] = {
                    ambient = ambientFiles,
                    combat = combatFiles,
                    packType = packType,
                    packContent = packContent,
                    wsid = addon.wsid
                }

                print("[BattleBeats Client] Loaded pack: " .. title)
            end
        end
    end
    local elapsed = SysTime() - startTime
    debugPrint("[LoadGenericMusicPacks] Finished loading in " .. elapsed .. " seconds")
end

local function loadBattleBeatsMusicPacks(isDebug)
    if isDebug then
        if not debugMode:GetBool() then return end
    else
        if debugMode:GetBool() or not loadLocalPacks:GetBool() then return end
    end

    local _, packDirs = file.Find("sound/battlebeats/*", "GAME")

    for _, packName in ipairs(packDirs) do
        if packName == "ambient" or packName == "combat" then
            if isDebug then
                BATTLEBEATS.musicPacks[packName .. " (DEBUG)"] = { error = "invalid_pack_name" }
                debugPrint("[BattleBeats Debug] Invalid pack name: " .. packName .. " (missing pack name folder)")
            end
            continue
        end

        local ambientMp3 = file.Find("sound/battlebeats/" .. packName .. "/ambient/*.mp3", "GAME") or {}
        local ambientOgg = file.Find("sound/battlebeats/" .. packName .. "/ambient/*.ogg", "GAME") or {}
        local combatMp3 = file.Find("sound/battlebeats/" .. packName .. "/combat/*.mp3", "GAME") or {}
        local combatOgg = file.Find("sound/battlebeats/" .. packName .. "/combat/*.ogg", "GAME") or {}

        local ambient = table.Add(ambientMp3, ambientOgg) or ambientMp3
        local combat = table.Add(combatMp3, combatOgg) or combatMp3

        local builtAmbient = buildPaths("sound/battlebeats/" .. packName .. "/ambient/", ambient)
        local builtCombat = buildPaths("sound/battlebeats/" .. packName .. "/combat/", combat)

        if not isDebug then
            local alreadyLoaded = false
            for _, path in ipairs(builtAmbient) do
                if pathExistsInMusicPacks(path) then
                    alreadyLoaded = true
                    break
                end
            end
            if not alreadyLoaded then
                for _, path in ipairs(builtCombat) do
                    if pathExistsInMusicPacks(path) then
                        alreadyLoaded = true
                        break
                    end
                end
            end
            if alreadyLoaded then continue end
        end

        local pack = {
            ambient = builtAmbient or {},
            combat  = builtCombat or {},
        }

        if isDebug then pack.debug = true else pack.packType = "local" end

        if #pack.ambient > 0 and #pack.combat > 0 then
            pack.packContent = "both"
            if isDebug then
                debugPrint("[BattleBeats Debug] Loaded valid pack: " .. packName)
            else
                print("[BattleBeats Client] Loaded local pack: " .. packName)
            end
        elseif #pack.ambient > 0 then
            pack.packContent = "ambient"
            if isDebug then
                debugPrint("[BattleBeats Debug] Loaded ambient-only pack: " .. packName)
            else
                print("[BattleBeats Client] Loaded local pack: " .. packName)
            end
        elseif #pack.combat > 0 then
            pack.packContent = "combat"
            if isDebug then
                debugPrint("[BattleBeats Debug] Loaded combat-only pack: " .. packName)
            else
                print("[BattleBeats Client] Loaded local pack: " .. packName)
            end
        else
            pack.error = "missing_ambient_and_combat_tracks"
            if isDebug then
                debugPrint("[BattleBeats Debug] Skipped empty pack: " .. packName)
            end
        end

        local suffix = isDebug and " [DEBUG]" or " [LOCAL]"
        BATTLEBEATS.musicPacks[packName .. suffix] = pack
    end
end

local function cleanupInvalidTracks(tbl)
    local toRemove = {}
    for trackPath, _ in pairs(tbl) do
        if not file.Exists(trackPath, "GAME") then
            table.insert(toRemove, trackPath)
        end
    end
    for _, trackPath in ipairs(toRemove) do
        tbl[trackPath] = nil
    end
end

function BATTLEBEATS.SaveExcludedTracks()
    local validExcluded = {}
    for track, isExcluded in pairs(BATTLEBEATS.excludedTracks) do
        if isExcluded then
            validExcluded[track] = true
        end
    end
    local jsonData = util.TableToJSON(validExcluded)
    file.Write("battlebeats/battlebeats_excluded_tracks.txt", jsonData)

    --note to myself: remove it later
    if file.Exists("battlebeats_excluded_tracks.txt", "DATA") then
        file.Delete("battlebeats_excluded_tracks.txt")
    end
end

local function loadExcludedTracks()
    BATTLEBEATS.excludedTracks = {}

    local paths = { "battlebeats/battlebeats_excluded_tracks.txt", "battlebeats_excluded_tracks.txt" }
    local jsonData
    for _, path in ipairs(paths) do
        if file.Exists(path, "DATA") then
            jsonData = file.Read(path, "DATA")
            break
        end
    end

    local loadedTracks = util.JSONToTable(jsonData or "") or {}
    for track, _ in pairs(loadedTracks) do
        for _, packData in pairs(BATTLEBEATS.musicPacks) do
            if (istable(packData.ambient) and table.HasValue(packData.ambient, track)) or
                (istable(packData.combat) and table.HasValue(packData.combat, track)) then
                BATTLEBEATS.excludedTracks[track] = true
                break
            end
        end
    end
    --cleanupInvalidTracks(BATTLEBEATS.excludedTracks)
    BATTLEBEATS.SaveExcludedTracks()
end

function BATTLEBEATS.SaveFavoriteTracks()
    local jsonFavorites = util.TableToJSON(BATTLEBEATS.favoriteTracks)
    file.Write("battlebeats/battlebeats_favorite_tracks.txt", jsonFavorites)

    --note to myself: remove it later
    if file.Exists("battlebeats_favorite_tracks.txt", "DATA") then
        file.Delete("battlebeats_favorite_tracks.txt")
    end
end

local function loadFavoriteTracks()
    BATTLEBEATS.favoriteTracks = {}

    local paths = { "battlebeats/battlebeats_favorite_tracks.txt", "battlebeats_favorite_tracks.txt" }
    local jsonData
    for _, path in ipairs(paths) do
        if file.Exists(path, "DATA") then
            jsonData = file.Read(path, "DATA")
            break
        end
    end

    local loadedFavorites = util.JSONToTable(jsonData or "") or {}
    for track, _ in pairs(loadedFavorites) do
        for _, packData in pairs(BATTLEBEATS.musicPacks) do
            if (istable(packData.ambient) and table.HasValue(packData.ambient, track)) or
                (istable(packData.combat) and table.HasValue(packData.combat, track)) then
                BATTLEBEATS.favoriteTracks[track] = true
                break
            end
        end
    end
    --cleanupInvalidTracks(BATTLEBEATS.favoriteTracks)
    BATTLEBEATS.SaveFavoriteTracks()
end

function BATTLEBEATS.SaveNPCMappings()
    local data = {}

    for track, mapping in pairs(BATTLEBEATS.npcTrackMappings or {}) do
        if mapping.npcs then
            data[track] = { npcs = table.Copy(mapping.npcs) }
        elseif mapping.class then
            data[track] = { npcs = { { class = mapping.class, priority = mapping.priority } } }
        end
    end

    file.Write("battlebeats/battlebeats_npc_mappings.txt", util.TableToJSON(data, true))
end

local function loadMappedTracks()
    BATTLEBEATS.npcTrackMappings = {}

    if not file.Exists("battlebeats/battlebeats_npc_mappings.txt", "DATA") then
        return
    end

    local jsonData = file.Read("battlebeats/battlebeats_npc_mappings.txt", "DATA")
    local loaded = util.JSONToTable(jsonData) or {}

    for track, mapping in pairs(loaded) do
        if not mapping then continue end

        if mapping.npcs and istable(mapping.npcs) then
            BATTLEBEATS.npcTrackMappings[track] = { npcs = {} }
            for _, npc in ipairs(mapping.npcs) do
                if npc.class and npc.priority then
                    table.insert(BATTLEBEATS.npcTrackMappings[track].npcs, {
                        class = tostring(npc.class),
                        priority = math.Clamp(tonumber(npc.priority) or 1, 1, 5)
                    })
                end
            end
        elseif mapping.class and mapping.priority then
            BATTLEBEATS.npcTrackMappings[track] = {
                npcs = {{
                    class = tostring(mapping.class),
                    priority = math.Clamp(tonumber(mapping.priority) or 1, 1, 5)
                }}
            }
        end
    end

    for track, mapping in pairs(BATTLEBEATS.npcTrackMappings) do
        if not mapping.npcs or #mapping.npcs == 0 then
            BATTLEBEATS.npcTrackMappings[track] = nil
        end
    end

    BATTLEBEATS.SaveNPCMappings()
end

function BATTLEBEATS.SaveTrackOffsets()
    local jsonFavorites = util.TableToJSON(BATTLEBEATS.trackOffsets)
    file.Write("battlebeats/battlebeats_track_offsets.txt", jsonFavorites)
end

local function loadTrackOffsets()
    BATTLEBEATS.trackOffsets = {}

    if file.Exists("battlebeats/battlebeats_track_offsets.txt", "DATA") then
        local jsonData = file.Read("battlebeats/battlebeats_track_offsets.txt", "DATA")
        BATTLEBEATS.trackOffsets = util.JSONToTable(jsonData) or {}

        --cleanupInvalidTracks(BATTLEBEATS.trackOffsets)
        BATTLEBEATS.SaveTrackOffsets()
    end
end

local function loadSavedPacks()
    local savedPacks = cookie.GetString("battlebeats_selected_packs", "")
    if savedPacks ~= "" then
        BATTLEBEATS.currentPacks = util.JSONToTable(savedPacks) or {}
        for packName, _ in pairs(BATTLEBEATS.currentPacks) do
            if not BATTLEBEATS.musicPacks[packName] then BATTLEBEATS.currentPacks[packName] = nil end
        end
        if not table.IsEmpty(BATTLEBEATS.currentPacks) then
            print("[BattleBeats Client] Loaded selected packs: " ..
            table.concat(table.GetKeys(BATTLEBEATS.currentPacks), ", "))
            local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, false, BATTLEBEATS.excludedTracks)
            if track and enableAmbient:GetBool() then BATTLEBEATS.PlayNextTrack(track) end
        else
            print("[BattleBeats Client] No saved packs found")
        end
    else
        print("[BattleBeats Client] No saved packs found")
    end
    if not table.IsEmpty(BATTLEBEATS.musicPacks) and table.IsEmpty(BATTLEBEATS.currentPacks) and autoPopup:GetBool() then
        RunConsoleCommand("battlebeats_menu")
        /*chat.AddText(
            Color(255, 255, 0), "[BattleBeats] ",
            Color(255, 255, 255), "You can disable this popup in battlebeats settings"
        )*/
    end
end

local function buildTrackMap()
    BATTLEBEATS.trackToPack = {}
    for packName, pack in pairs(BATTLEBEATS.musicPacks) do
        if not pack then continue end
        for _, category in ipairs({ pack.combat or {}, pack.ambient or {} }) do
            for _, track in ipairs(category) do
                BATTLEBEATS.trackToPack[track] = packName
            end
        end
    end
end

local versionConVar = GetConVar("battlebeats_seen_version")

hook.Add("InitPostEntity", "BattleBeats_StartMusic", function()
    loadGenericMusicPacks()
    loadBattleBeatsMusicPacks(true)
    loadBattleBeatsMusicPacks(false)
    loadExcludedTracks()
    loadFavoriteTracks()
    loadMappedTracks()
    loadTrackOffsets()
    buildTrackMap()
    --
    loadSavedPacks()
    BATTLEBEATS.ValidatePacks()
    for songName, _ in pairs(BATTLEBEATS.subtitles) do
        BATTLEBEATS.parseSRT(songName)
    end
    timer.Simple(2, function()
        local conflicts = {
            ["270169947"]  = "Nombat",
            ["3404184965"] = "16th Note",
            ["2911363186"] = "Action Music",
            ["2085721189"] = "Simple Battle Music",
        }

        local function warn(name)
            chat.AddText(
                Color(255, 255, 0), "[BattleBeats] ",
                Color(255, 255, 255), "Warning! ",
                Color(255, 100, 100), name,
                Color(255, 255, 255), " is enabled/mounted. Please disable it to avoid conflicts"
            )
        end

        for _, addon in ipairs(engine.GetAddons()) do
            local name = conflicts[addon.wsid]
            if name and addon.mounted then
                warn(name)
            end
        end
    end)
    if not versionConVar or versionConVar:GetString() ~= BATTLEBEATS.currentVersion then
        chat.AddText(
            Color(255, 255, 0), "[BattleBeats] ",
            Color(255, 255, 255), "Welcome to version ",
            Color(100, 255, 100), BATTLEBEATS.currentVersion,
            Color(255, 255, 255), "! Check out the new features:"
        )
        chat.AddText(
            Color(150, 255, 150), "- Added ability to assign multiple NPCs to one track"
            --Color(150, 255, 150), "- You can now add subtitles to your tracks"
        )
        chat.AddText(
            Color(255, 255, 255), "See workshop page for detailed changelog!"
        )

        RunConsoleCommand("battlebeats_seen_version", BATTLEBEATS.currentVersion)
    end
end)

concommand.Add("battlebeats_reload_packs", function()
    if IsValid(BATTLEBEATS.frame) then BATTLEBEATS.frame:Close() end
    BATTLEBEATS.musicPacks = {}
    BATTLEBEATS.checking = false
    loadGenericMusicPacks()
    loadBattleBeatsMusicPacks(true)
    loadBattleBeatsMusicPacks(false)
    buildTrackMap()
    BATTLEBEATS.ValidatePacks()
end)

print("BattleBeats " .. BATTLEBEATS.currentVersion .. " loaded")