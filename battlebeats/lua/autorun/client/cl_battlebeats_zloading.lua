local autoPopup = CreateClientConVar("battlebeats_autopopup", "1", true, false, "", 0, 1)
local loadLocalPacks = CreateClientConVar("battlebeats_load_local_packs", "0", true, false, "", 0, 1)
local loadAMsuspense = CreateClientConVar("battlebeats_load_am_suspense", "0", true, false, "", 0, 1)
local startMode = CreateClientConVar("battlebeats_start_mode", "0", true, false, "", 0, 2)
local debugMode = GetConVar("battlebeats_debug_mode")
local enableAmbient = GetConVar("battlebeats_enable_ambient")

file.CreateDir("battlebeats")

local allowedAudioExtensions = {
    mp3  = true,
    wav  = true,
    aiff = true,
    ogg  = true,
    flac = true,
    m4a  = true,
    wma  = true
}

local function debugPrint(...)
    if debugMode:GetBool() then print("[BattleBeats Debug] " .. ...) end
end

local function extensionErrorPrint(file)
    local f = string.GetFileFromFilename(file)
    print("[BattleBeats Client] Unsupported file type: " .. f .. " | Allowed file types: mp3, wav, aiff, ogg, flac, m4a, wma")
end

local function isAudioFile(file)
    local ext = string.GetExtensionFromFilename(file)
    return ext and allowedAudioExtensions[string.lower(ext)] or false
end

local function trackExists(path)
    if not path or path == "" then return false end
    return file.Exists(path, "GAME")
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

local baseDirs = {"battlebeats", "nombat", "battlemusic", "16thnote", "am_music", "ayykyu_dynmus", "gmmp"}
local dirHandlers = {
    nombat = {
        packType = "nombat",
        handle = function(file)
            if file:match("/a.*%.mp3$") then
                return true, false
            elseif file:match("/c.*%.mp3$") then
                return false, true
            end
        end
    },
    am_music = {
        packType = "amusic",
        handle = function(file)
            if file:find("/background/", 1, true) then
                return true, false
            elseif file:find("/battle/", 1, true)
                or file:find("/battle_intensive/", 1, true) then
                return false, true
            elseif loadAMsuspense:GetBool()
                and file:find("/suspense/", 1, true) then
                return true, true
            end
        end
    },
    ayykyu_dynmus = {
        packType = "dynamo",
        handle = function(file)
            if file:find("/ambient/", 1, true) then
                return true, false
            elseif file:find("/combat/bosses/", 1, true)
                or file:find("/combat/soldiers/", 1, true)
                or file:find("/combat/cops/", 1, true)
                or file:find("/combat/aliens/", 1, true) then
                return false, true
            end
        end
    },
    gmmp = {
        packType = "mp3p",
        handle = function()
            return true, false
        end
    },
    default = {
        packType = "battlebeats",
        handle = function(file)
            if file:find("/ambient/", 1, true) then
                return true, false
            elseif file:find("/combat/", 1, true) then
                return false, true
            end
        end
    }
}

local function loadGenericMusicPacks()
    local startTime = SysTime()
    local addons = engine.GetAddons()

    local customBaseDirs, customDirHandlers = hook.Run("BattleBeats_PreLoadPacks", baseDirs, dirHandlers)
    if customBaseDirs then baseDirs = customBaseDirs end
    if customDirHandlers then dirHandlers = customDirHandlers end

    for _, addon in ipairs(addons) do
        if addon.mounted then
            local title = addon.title
            local ambientFiles, combatFiles = {}, {}
            local packType = nil

            for _, dir in ipairs(baseDirs) do
                local handler = dirHandlers[dir] or dirHandlers.default
                local matchedFiles = recurseListContents("sound/" .. dir .. "/", title, false)

                for _, file in ipairs(matchedFiles) do
                    if not isAudioFile(file) then continue end

                    local addAmbient, addCombat = handler.handle(file)
                    if addAmbient then table.insert(ambientFiles, file) end
                    if addCombat then table.insert(combatFiles, file) end
                end

                if not packType and (#ambientFiles > 0 or #combatFiles > 0) then
                    packType = handler.packType
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
                BATTLEBEATS.musicPacks[packName .. " (DEBUG)"] = {error = "invalid_pack_name"}
                debugPrint("[BattleBeats Debug] Invalid pack name: " .. packName .. " (missing pack name folder)")
            end
            continue
        end

        local ambient = {}
        local combat  = {}
        for _, fileName in ipairs(file.Find("sound/battlebeats/" .. packName .. "/ambient/*.*", "GAME") or {}) do
            if isAudioFile(fileName) then
                ambient[#ambient + 1] = fileName
            else
                extensionErrorPrint(fileName)
            end
        end
        for _, fileName in ipairs(file.Find("sound/battlebeats/" .. packName .. "/combat/*.*", "GAME") or {}) do
            if isAudioFile(fileName) then
                combat[#combat + 1] = fileName
            else
                extensionErrorPrint(fileName)
            end
        end

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

local function loadBattleBeatsLocal()
    if not file.IsDir("sound/btb", "GAME") then return end
    local basePath = "sound/btb/"
    local rootFiles = file.Find(basePath .. "*", "GAME") or {}
    local ambientFiles = file.Find(basePath .. "ambient/*", "GAME") or {}
    local combatFiles = file.Find(basePath .. "combat/*", "GAME") or {}

    local ambient = {}
    local combat = {}
    for _, f in ipairs(rootFiles) do
        if not isAudioFile(f) then extensionErrorPrint(f) continue end
        table.insert(ambient, basePath .. f)
    end
    for _, f in ipairs(ambientFiles) do
        if not isAudioFile(f) then extensionErrorPrint(f) continue end
        table.insert(ambient, basePath .. "ambient/" .. f)
    end
    for _, f in ipairs(combatFiles) do
        if not isAudioFile(f) then extensionErrorPrint(f) continue end
        table.insert(combat, basePath .. "combat/" .. f)
    end

    local pack = {
        ambient = ambient,
        combat  = combat,
    }

    pack.packType = "local"
    if #ambient > 0 and #combat > 0 then
        pack.packContent = "both"
    elseif #ambient > 0 then
        pack.packContent = "ambient"
    elseif #combat > 0 then
        pack.packContent = "combat"
    else
        pack.packContent = "empty"
    end
    BATTLEBEATS.musicPacks["#btb.loading.local_pack"] = pack
end

local function cleanupInvalidTracks(tbl)
    local toRemove = {}
    for trackPath, _ in pairs(tbl) do
        if not file.Exists(trackPath, "GAME") then
            print("[BattleBeats Cleanup] Removing: " .. trackPath)
            --table.insert(toRemove, trackPath)
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
end

local function loadExcludedTracks()
    BATTLEBEATS.excludedTracks = {}

    local jsonData
    if file.Exists("battlebeats/battlebeats_excluded_tracks.txt", "DATA") then
        jsonData = file.Read("battlebeats/battlebeats_excluded_tracks.txt", "DATA")
    end

    local loadedTracks = util.JSONToTable(jsonData or "") or {}
    for track, _ in pairs(loadedTracks) do
        BATTLEBEATS.excludedTracks[track] = true
    end

    --cleanupInvalidTracks(BATTLEBEATS.excludedTracks)
    BATTLEBEATS.SaveExcludedTracks()
end

function BATTLEBEATS.SaveFavoriteTracks()
    local jsonFavorites = util.TableToJSON(BATTLEBEATS.favoriteTracks)
    file.Write("battlebeats/battlebeats_favorite_tracks.txt", jsonFavorites)
end

local function loadFavoriteTracks()
    BATTLEBEATS.favoriteTracks = {}

    local jsonData
    if file.Exists("battlebeats/battlebeats_favorite_tracks.txt", "DATA") then
        jsonData = file.Read("battlebeats/battlebeats_favorite_tracks.txt", "DATA")
    end

    local loadedFavorites = util.JSONToTable(jsonData or "") or {}
    for track, _ in pairs(loadedFavorites) do
        BATTLEBEATS.favoriteTracks[track] = true
    end

    -- cleanupInvalidTracks(BATTLEBEATS.favoriteTracks)
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

    cleanupInvalidTracks(BATTLEBEATS.npcTrackMappings)
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

local function _getRandomTrack()
    return BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, false, BATTLEBEATS.excludedTracks)
end

local function getStartingTrack()
    local mode = startMode:GetInt()

    --random
    if mode == 0 then
        return _getRandomTrack()
    end

    -- random favorite
    if mode == 1 then
        if table.IsEmpty(BATTLEBEATS.favoriteTracks) then
            return _getRandomTrack()
        end

        local validFavorites = {}
        for trackPath, _ in pairs(BATTLEBEATS.favoriteTracks) do
            if trackExists(trackPath) then
                table.insert(validFavorites, trackPath)
            end
        end

        if table.IsEmpty(validFavorites) then
            return _getRandomTrack()
        end

        local idx = math.random(1, #validFavorites)
        return validFavorites[idx]
    end

    -- user selected
    if mode == 2 then
        local selected = cookie.GetString("battlebeats_start_track", "")
        if selected == "" then
            return _getRandomTrack()
        end

        if trackExists(selected) then
            return selected
        else
            return _getRandomTrack()
        end
    end
    return _getRandomTrack()
end

local function loadSavedPacks()
    local savedPacks = cookie.GetString("battlebeats_selected_packs", "")
    local override = hook.Run("BattleBeats_PreStartBattleBeats", savedPacks)
    if override == true then return end
    if savedPacks ~= "" then
        BATTLEBEATS.currentPacks = util.JSONToTable(savedPacks) or {}
        for packName, _ in pairs(BATTLEBEATS.currentPacks) do
            if not BATTLEBEATS.musicPacks[packName] then BATTLEBEATS.currentPacks[packName] = nil end
        end
        if not table.IsEmpty(BATTLEBEATS.currentPacks) then
            print("[BattleBeats Client] Loaded selected packs: " ..
            table.concat(table.GetKeys(BATTLEBEATS.currentPacks), ", "))
            local track = getStartingTrack()
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

local function findConflicts()
    local conflicts = {
        ["270169947"]  = "Nombat",
        ["3404184965"] = "16th Note",
        ["2911363186"] = "Action Music",
        ["2085721189"] = "Simple Battle Music",
        ["2408876405"] = "DYNAMO",
        ["306423885"]  = "MP3 Radio",
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
            BATTLEBEATS.activeConflicts[name] = true
        end
    end
end

local versionConVar = GetConVar("battlebeats_seen_version")
local function loadPatchNotes()
    if not versionConVar or versionConVar:GetString() ~= BATTLEBEATS.currentVersion then
        chat.AddText(
            Color(255, 255, 0), "[BattleBeats] ",
            Color(255, 255, 255), "Welcome to version ",
            Color(100, 255, 100), BATTLEBEATS.currentVersion,
            Color(255, 255, 255), "! Check out the new features:"
        )
        chat.AddText(
            Color(150, 255, 150), "- Added support for more audio extensions: AIFF, WAV, FLAC, M4A, WMA\n",
            Color(150, 255, 150), "- Added an option to select the starting track"
        )
        chat.AddText(
            Color(255, 255, 255), "See workshop page for detailed changelog!"
        )

        RunConsoleCommand("battlebeats_seen_version", BATTLEBEATS.currentVersion)
    end
end

SXNOTE = SXNOTE or {}
local old = SXNOTE.RegisterLyrics
function SXNOTE:RegisterLyrics(path, data)
    if old then
        old(self, path, data)
    end
    local songName = string.lower(BATTLEBEATS.FormatTrackName(path))
    BATTLEBEATS.subtitles[songName] = {
        keyframes = data.keyframes or {}
    }
end

hook.Add("InitPostEntity", "BattleBeats_Load16thNoteLyrics", function()
    local files, _ = file.Find("16thnote_lyric/*.lua", "LUA")
    if not files or #files == 0 then
        return
    end
    for _, filename in ipairs(files) do
        include("16thnote_lyric/" .. filename)
    end
end)

hook.Add("InitPostEntity", "BattleBeats_StartMusic", function()
    loadGenericMusicPacks()
    loadBattleBeatsMusicPacks(true)
    loadBattleBeatsMusicPacks(false)
    loadBattleBeatsLocal()
    loadExcludedTracks()
    loadFavoriteTracks()
    loadMappedTracks()
    loadTrackOffsets()
    buildTrackMap()
    findConflicts()
    --
    loadSavedPacks()
    BATTLEBEATS.ValidatePacks()
    for songName, data in pairs(BATTLEBEATS.subtitles) do
        if data.raw then
            BATTLEBEATS.parseSRT(songName)
        elseif data.keyframes then
            BATTLEBEATS.parse16thNote(songName)
        end
    end
    loadPatchNotes()
end)

concommand.Add("battlebeats_reload_packs", function()
    if IsValid(BATTLEBEATS.frame) then BATTLEBEATS.frame:Close() end
    BATTLEBEATS.musicPacks = {}
    BATTLEBEATS.checking = false
    loadGenericMusicPacks()
    loadBattleBeatsMusicPacks(true)
    loadBattleBeatsMusicPacks(false)
    loadBattleBeatsLocal()
    buildTrackMap()
    BATTLEBEATS.ValidatePacks()
end)

print("BattleBeats version " .. BATTLEBEATS.currentVersion .. "_" .. jit.arch .. " loaded")