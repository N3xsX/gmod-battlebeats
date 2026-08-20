local autoPopup = CreateClientConVar("battlebeats_autopopup", "1", true, false, "", 0, 1)
--local loadLocalPacks = CreateClientConVar("battlebeats_load_local_packs", "0", true, false, "", 0, 1)
local loadAMsuspense = CreateClientConVar("battlebeats_load_am_suspense", "0", true, false, "", 0, 1)
local startMode = CreateClientConVar("battlebeats_start_mode", "0", true, false, "", 0, 3)
local debugMode = GetConVar("battlebeats_debug_mode")
local enableAmbient = GetConVar("battlebeats_enable_ambient")

local ae = {mp3  = true, wav  = true, aiff = true, ogg  = true, flac = true, m4a = true, wma = true}
local function badExt(f)
    print("[BattleBeats Client] Unsupported file type: " .. string.GetFileFromFilename(f))
end

local function isAudio(file)
    local ext = string.GetExtensionFromFilename(file)
    return ext and ae[string.lower(ext)] or false
end

local function trackExists(path)
    if not path or path == "" then return false end
    return file.Exists(path, "GAME")
end

local function scan(p, src, out, rel)
    local fs, ds = file.Find(p .. "*", src)
    rel = rel or p
    for _, f in ipairs(fs or {}) do out[#out + 1] = rel .. f end
    for _, d in ipairs(ds or {}) do scan(p .. d .. "/", src, out, rel .. d .. "/") end
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
    ["16thnote"] = {
        packType = "16thnote",
        handle = function(file)
            if file:find("/ambient/", 1, true) then
                return true, false
            elseif file:find("/combat/", 1, true) then
                return false, true
            end
        end
    },
    battlemusic = {
        packType = "sbm",
        handle = function(file)
            if file:find("/ambient/", 1, true) then
                return true, false
            elseif file:find("/combat/", 1, true) then
                return false, true
            end
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

--MARK: Finding packs
local function loadSource(name, src, wsid, dbg, root)
    local a, c, pt = {}, {}, nil
    root = root or "sound/"

    for _, d in ipairs(baseDirs) do
        local h = dirHandlers[d] or dirHandlers.default
        local fs = {}
        scan(root .. d .. "/", src, fs, "sound/" .. d .. "/")
        for _, f in ipairs(fs) do
            if not isAudio(f) then
                if dbg then badExt(f) end
                continue
            end
            local aa, cc = h.handle(f)
            if aa then a[#a + 1] = f end
            if cc then c[#c + 1] = f end
            if not pt and (aa or cc) then pt = h.packType end
        end
    end

    if #a == 0 and #c == 0 then return end

    print("[BattleBeats Client] Loaded pack: " .. name)
    assert(not BATTLEBEATS.musicPacks[name], "Duplicate BattleBeats pack name: " .. name)
    BATTLEBEATS.musicPacks[name] = {
        ambient = a,
        combat = c,
        packType = pt,
        source = wsid and "workshop" or "local",
        packContent = #a > 0 and (#c > 0 and "both" or "ambient") or "combat",
        wsid = wsid,
        debug = dbg or nil
    }
end

local function loadBTB()
    local a, c = {}, {}
    local root = "sound/btb/"
    for _, f in ipairs(file.Find(root .. "*", "GAME") or {}) do
        if isAudio(f) then
            a[#a + 1] = root .. f
        else
            badExt(f)
        end
    end
    for _, f in ipairs(file.Find(root .. "ambient/*", "GAME") or {}) do
        if isAudio(f) then
            a[#a + 1] = root .. "ambient/" .. f
        else
            badExt(f)
        end
    end

    for _, f in ipairs(file.Find(root .. "combat/*", "GAME") or {}) do
        if isAudio(f) then
            c[#c + 1] = root .. "combat/" .. f
        else
            badExt(f)
        end
    end
    if #a == 0 and #c == 0 then return end
    BATTLEBEATS.musicPacks["#btb.loading.local_pack"] = {
        ambient = a,
        combat = c,
        packType = "local",
        source = "local",
        packContent = #a > 0 and (#c > 0 and "both" or "ambient") or "combat"
    }
end

local function mainloadPacks(dbg)
    local t = SysTime()

    local bd, dh = hook.Run("BattleBeats_PreLoadPacks", baseDirs, dirHandlers)
    if bd then baseDirs = bd end
    if dh then dirHandlers = dh end

    -- sound/btb
    loadBTB()

    -- mounted addons
    for _, addon in ipairs(engine.GetAddons()) do
        if addon.mounted then
            loadSource(addon.title, addon.title, addon.wsid, dbg)
        end
    end

    -- local addons
    local _, packs = file.Find("addons/*", "GAME")
    for _, name in ipairs(packs or {}) do
        loadSource(name, "GAME", nil, dbg, "addons/" .. name .. "/sound/")
    end

    print("[BattleBeats Client] Loaded packs in " .. math.Truncate(SysTime() - t, 3) .. " seconds")
end

local function loadPacks() mainloadPacks(false) end
local function loadPacksDebug() if debugMode:GetBool() then mainloadPacks(true) end end

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

local function loadTableFromFile(path, targetKey, transformFn, saveFn)
    BATTLEBEATS[targetKey] = {}

    if not file.Exists(path, "DATA") then return end

    local jsonData = file.Read(path, "DATA")
    local loaded = util.JSONToTable(jsonData) or {}

    for key, value in pairs(loaded) do
        if transformFn then
            local newKey, newValue = transformFn(key, value)
            if newKey ~= nil then
                BATTLEBEATS[targetKey][newKey] = newValue
            end
        else
            BATTLEBEATS[targetKey][key] = value
        end
    end

    if saveFn then
        saveFn()
    end
end

--MARK: Save functions
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

function BATTLEBEATS.SaveFavoriteTracks()
    local jsonFavorites = util.TableToJSON(BATTLEBEATS.favoriteTracks)
    file.Write("battlebeats/battlebeats_favorite_tracks.txt", jsonFavorites)
end

function BATTLEBEATS.SaveTrackTrim()
    local json = util.TableToJSON(BATTLEBEATS.trackTrim, true)
    file.Write("battlebeats/battlebeats_track_trims.txt", json)
end

function BATTLEBEATS.SaveTrackVolumes()
    local valid = {}
    if BATTLEBEATS.trackVolume then
        for track, value in pairs(BATTLEBEATS.trackVolume) do
            if isnumber(value) then
                value = math.Clamp(math.floor(value), 0, 200)
                if value ~= 100 then
                    valid[track] = value
                end
            end
        end
    end
    local jsonData = util.TableToJSON(valid, true)
    file.CreateDir("battlebeats")
    file.Write("battlebeats/battlebeats_track_volumes.txt", jsonData or "{}")
end

function BATTLEBEATS.SavePackVolumes()
    local valid = {}
    if BATTLEBEATS.packVolume then
        for pack, value in pairs(BATTLEBEATS.packVolume) do
            if isnumber(value) then
                value = math.Clamp(math.floor(value), 0, 200)
                if value ~= 100 then
                    valid[pack] = value
                end
            end
        end
    end
    local jsonData = util.TableToJSON(valid, true)
    file.CreateDir("battlebeats")
    file.Write("battlebeats/battlebeats_pack_volumes.txt", jsonData or "{}")
end

function BATTLEBEATS.SavePlaylists()
    local json = util.TableToJSON(BATTLEBEATS.musicPlaylists, true)
    file.Write("battlebeats/battlebeats_playlists.txt", json)
end

function BATTLEBEATS.SaveTrackAliases()
    local json = util.TableToJSON(BATTLEBEATS.trackAliases, true)
    file.Write("battlebeats/battlebeats_track_aliases.txt", json)
end

--MARK: Loading functions
local function loadExcludedTracks()
    loadTableFromFile("battlebeats/battlebeats_excluded_tracks.txt", "excludedTracks", function(track) return track, true end, BATTLEBEATS.SaveExcludedTracks)
end

local function loadFavoriteTracks()
    loadTableFromFile("battlebeats/battlebeats_favorite_tracks.txt", "favoriteTracks", function(track) return track, true end, BATTLEBEATS.SaveFavoriteTracks)
end

local function npcTransform(track, mapping)
    if not mapping then return nil end
    local result = {npcs = {}}
    if mapping.npcs and istable(mapping.npcs) then
        for _, npc in ipairs(mapping.npcs) do
            if npc.class and npc.priority then
                table.insert(result.npcs, {
                    class = tostring(npc.class),
                    priority = math.Clamp(tonumber(npc.priority) or 1, 1, 5)
                })
            end
        end
    elseif mapping.class and mapping.priority then
        table.insert(result.npcs, {
            class = tostring(mapping.class),
            priority = math.Clamp(tonumber(mapping.priority) or 1, 1, 5)
        })
    end
    if #result.npcs == 0 then
        return nil
    end
    return track, result
end

local function loadMappedTracks()
    loadTableFromFile("battlebeats/battlebeats_npc_mappings.txt", "npcTrackMappings", npcTransform, BATTLEBEATS.SaveNPCMappings)
end

local function loadTrackTrims()
    BATTLEBEATS.trackTrim = {}

    local trimsPath = "battlebeats/battlebeats_track_trims.txt"
    local offsetsPath = "battlebeats/battlebeats_track_offsets.txt"

    if file.Exists(trimsPath, "DATA") then
        local json = file.Read(trimsPath, "DATA")
        BATTLEBEATS.trackTrim = util.JSONToTable(json) or {}
        return
    end

    if file.Exists(offsetsPath, "DATA") then
        local json = file.Read(offsetsPath, "DATA")
        local oldOffsets = util.JSONToTable(json) or {}

        for track, offset in pairs(oldOffsets) do
            if tonumber(offset) and offset > 0 then
                BATTLEBEATS.trackTrim[track] = {
                    start = math.floor(offset),
                    finish = nil
                }
            end
        end

        BATTLEBEATS.SaveTrackTrim()
        file.Delete(offsetsPath)
        BATTLEBEATS.trackOffsets = nil
    end
end

local function volumeTransform(key, value)
    if not isnumber(value) then return nil end
    value = math.Clamp(math.floor(value), 0, 200)
    if value == 100 then return nil end
    return key, value
end

local function loadTrackVolumes()
    loadTableFromFile("battlebeats/battlebeats_track_volumes.txt", "trackVolume", volumeTransform)
end

local function loadPackVolumes()
    loadTableFromFile("battlebeats/battlebeats_pack_volumes.txt", "packVolume", volumeTransform)
end

local function loadTrackAliases()
    loadTableFromFile("battlebeats/battlebeats_track_aliases.txt", "trackAliases")
end

local function loadPlaylists()
    loadTableFromFile("battlebeats/battlebeats_playlists.txt", "musicPlaylists",
        function(name, data)
            if not isstring(name) or not istable(data) then return nil end
            local newName, newData = BATTLEBEATS.validateAndTransformPlaylist(name, data)
            if not newName or not newData then return nil end
            return newName, newData
        end,
        function()
            BATTLEBEATS.SavePlaylists()
        end
    )
end

--MARK: Initialization
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
            if not trackExists(trackPath) then continue end
            local packName = BATTLEBEATS.trackToPack[trackPath]
            local pack = packName and BATTLEBEATS.musicPacks[packName]
            if pack and pack.ambient and table.HasValue(pack.ambient, trackPath) then
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

    -- last track
    if mode == 3 then
        local selected = cookie.GetString("battlebeats_last_track", "")
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
            print("[BattleBeats Client] Loaded selected packs: " .. table.concat(table.GetKeys(BATTLEBEATS.currentPacks), ", "))
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
    end
end

local function buildTrackMap()
    BATTLEBEATS.trackToPack = {}
    for packName, pack in pairs(BATTLEBEATS.musicPacks) do
        if not pack or pack.packType == "playlist" then continue end
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
            Color(150, 255, 150), "- New UI for assigning NPCs to tracks\n",
            Color(150, 255, 150), "- Improved tooltip readability"
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
    for songName, data in pairs(BATTLEBEATS.subtitles) do
        if data.raw then
            BATTLEBEATS.parseSRT(songName)
        elseif data.keyframes then
            BATTLEBEATS.parse16thNote(songName)
        end
    end
end)

hook.Add("InitPostEntity", "BattleBeats_StartMusic", function()
    if game.IsDedicated() then MsgC(Color(220, 30, 30), "BattleBeats is running on dedicated server, all server packs will be loaded as local\n") end
    loadPacks()
    loadPacksDebug()
    loadExcludedTracks()
    loadFavoriteTracks()
    loadMappedTracks()
    loadTrackTrims()
    loadTrackVolumes()
    loadPackVolumes()
    loadPlaylists()
    loadTrackAliases()
    buildTrackMap()
    findConflicts()
    --
    loadSavedPacks()
    for songName, data in pairs(BATTLEBEATS.subtitles) do
        if data.raw then
            BATTLEBEATS.parseSRT(songName)
        elseif data.keyframes then
            BATTLEBEATS.parse16thNote(songName)
        end
    end
    BATTLEBEATS.ValidatePacks()
    --loadPatchNotes()
end)

concommand.Add("battlebeats_reload_packs", function()
    if IsValid(BATTLEBEATS.frame) then BATTLEBEATS.frame:Close() end
    BATTLEBEATS.musicPacks = {}
    BATTLEBEATS.checking = false
    loadPacks()
    loadPacksDebug()
    loadPlaylists()
    buildTrackMap()
    BATTLEBEATS.ValidatePacks()
end)

print("BattleBeats version " .. BATTLEBEATS.currentVersion .. "_" .. jit.arch .. " loaded")