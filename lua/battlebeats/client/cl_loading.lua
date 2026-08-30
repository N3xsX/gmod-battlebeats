local autoPopup = CreateClientConVar("battlebeats_autopopup", "1", true, false, "", 0, 1)
--local loadLocalPacks = CreateClientConVar("battlebeats_load_local_packs", "0", true, false, "", 0, 1)
local loadAMsuspense = CreateClientConVar("battlebeats_load_am_suspense", "0", true, false, "", 0, 1)
local startMode = CreateClientConVar("battlebeats_start_mode", "0", true, false, "", 0, 3)
local debugMode = GetConVar("battlebeats_debug_mode")
local enableAmbient = GetConVar("battlebeats_enable_ambient")

local btb = BATTLEBEATS

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

btb.baseDirs = {"battlebeats", "nombat", "battlemusic", "16thnote", "am_music", "ayykyu_dynmus", "gmmp"}
btb.dirHandlers = {
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

local loadedWS = {}

--MARK: Finding packs
local function loadSource(name, src, wsid, dbg, root, base, pack)
    local a, c, pt = {}, {}, nil
    root = root or "sound/"

    local function load(d, p)
        local h = btb.dirHandlers[d] or btb.dirHandlers.default
        local fs = {}

        if p then
            scan(root .. d .. "/" .. p .. "/", src, fs, "sound/" .. d .. "/" .. p .. "/")
        else
            local _, packs = file.Find(root .. d .. "/*", src)
            for _, n in ipairs(packs or {}) do
                loadedWS[d .. "/" .. n] = true
                scan(root .. d .. "/" .. n .. "/", src, fs, "sound/" .. d .. "/" .. n .. "/")
            end
        end

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

    if base then
        if not wsid and loadedWS[base .. "/" .. pack] then return end
        load(base, pack)
    else
        for _, d in ipairs(btb.baseDirs) do load(d) end
    end

    if #a == 0 and #c == 0 then return end

    print("[BattleBeats Client] Loaded pack: " .. name)
    assert(not btb.musicPacks[name], "duplicate BattleBeats pack name: " .. name)

    btb.musicPacks[name] = {
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
    btb.musicPacks["#btb.loading.local_pack"] = {
        ambient = a,
        combat = c,
        packType = "local",
        source = "local",
        packContent = #a > 0 and (#c > 0 and "both" or "ambient") or "combat"
    }
end

local function mainloadPacks(dbg)
    if dbg then btb.musicPacks = {} end
    local t = SysTime()

    -- sound/btb
    loadBTB()

    -- mounted addons
    for _, addon in ipairs(engine.GetAddons()) do
        if addon.mounted then
            loadSource(addon.title, addon.title, addon.wsid)
        end
    end

    -- local/dedicated server addons
    for _, d in ipairs(btb.baseDirs) do
        local _, packs = file.Find("sound/" .. d .. "/*", "GAME")
        for _, name in ipairs(packs or {}) do
            if not loadedWS[d .. "/" .. name] then
                loadSource(name, "GAME", nil, dbg, "sound/", d, name)
            end
        end
    end

    print("[BattleBeats Client] Loaded packs in " .. math.Truncate(SysTime() - t, 3) .. " seconds")
end

local function loadPacks() mainloadPacks(false) end
local function loadPacksDebug() if debugMode:GetBool() then mainloadPacks(true) end end
local function loadtbl(p, tk, tFn, sFn)
    btb[tk] = {}
    if not file.Exists(p, "DATA") then return end
    local fl = util.JSONToTable(file.Read(p, "DATA")) or {}
    for k, v in pairs(fl) do
        if tFn then
            local nk, nv = tFn(k, v)
            if nk ~= nil then
                btb[tk][nk] = nv
            end
        else
            btb[tk][k] = v
        end
    end
    if sFn then sFn() end
end

--MARK: Save functions
function btb.savePackVolumes()
    local valid = {}
    if btb.packVolume then
        for pack, value in pairs(btb.packVolume) do
            if isnumber(value) then
                value = math.Clamp(math.floor(value), 0, 200)
                if value ~= 100 then
                    valid[pack] = value
                end
            end
        end
    end
    local jsonData = util.TableToJSON(valid, true)
    file.Write("battlebeats/battlebeats_pack_volumes.txt", jsonData or "{}")
end

function btb.savePlaylists()
    file.Write("battlebeats/battlebeats_playlists.txt", util.TableToJSON(btb.musicPlaylists or {}, true))
end

function btb.saveTrackData()
    file.Write("battlebeats/track_data.json", util.TableToJSON(btb.trackData or {}, true))
end

--MARK: Loading functions
local function loadExcludedTracks()
    loadtbl("battlebeats/battlebeats_excluded_tracks.txt", "excludedTracks", function(track) return track, true end)
end

local function loadFavoriteTracks()
    loadtbl("battlebeats/battlebeats_favorite_tracks.txt", "favoriteTracks", function(track) return track, true end)
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
    loadtbl("battlebeats/battlebeats_npc_mappings.txt", "npcTrackMappings", npcTransform)
end

local function loadTrackTrims()
    btb.trackTrim = {}

    local trimsPath = "battlebeats/battlebeats_track_trims.txt"
    local offsetsPath = "battlebeats/battlebeats_track_offsets.txt"

    if file.Exists(trimsPath, "DATA") then
        local json = file.Read(trimsPath, "DATA")
        btb.trackTrim = util.JSONToTable(json) or {}
        return
    end

    if file.Exists(offsetsPath, "DATA") then
        local json = file.Read(offsetsPath, "DATA")
        local oldOffsets = util.JSONToTable(json) or {}
        for track, offset in pairs(oldOffsets) do
            if tonumber(offset) and offset > 0 then
                btb.trackTrim[track] = {
                    start = math.floor(offset),
                    finish = nil
                }
            end
        end
        file.Delete(offsetsPath)
        btb.trackOffsets = nil
    end
end

local function volumeTransform(key, value)
    if not isnumber(value) then return nil end
    value = math.Clamp(math.floor(value), 0, 200)
    if value == 100 then return nil end
    return key, value
end

local function loadTrackVolumes()
    loadtbl("battlebeats/battlebeats_track_volumes.txt", "trackVolume", volumeTransform)
end

local function loadPackVolumes()
    loadtbl("battlebeats/battlebeats_pack_volumes.txt", "packVolume", volumeTransform)
end

local function loadTrackAliases()
    loadtbl("battlebeats/battlebeats_track_aliases.txt", "trackAliases")
end

local function loadPlaylists()
    loadtbl("battlebeats/battlebeats_playlists.txt", "musicPlaylists",
        function(name, data)
            if not isstring(name) or not istable(data) then return nil end
            local newName, newData = btb.validateAndTransformPlaylist(name, data)
            if not newName or not newData then return nil end
            return newName, newData
        end,
        function()
            btb.savePlaylists()
        end
    )
end

local function loadTrackData()
    btb.trackData = {}

    local p = "battlebeats/track_data.json"
    if file.Exists(p, "DATA") then
        btb.trackData = util.JSONToTable(file.Read(p, "DATA")) or {}

        btb.npcTrackMappings = {}
        btb.excludedTracks = {}
        btb.favoriteTracks = {}
        btb.trackVolume = {}
        btb.trackTrim = {}
        btb.trackAliases = {}
        return
    end

    --temp
    for t, v in pairs(btb.excludedTracks or {}) do
        if v and not btb.trackData[t] then btb.trackData[t] = {} end
        if v then btb.trackData[t].exl = true end
    end

    for t, v in pairs(btb.favoriteTracks or {}) do
        if v and not btb.trackData[t] then btb.trackData[t] = {} end
        if v then btb.trackData[t].fav = true end
    end

    for t, v in pairs(btb.npcTrackMappings or {}) do
        if v.npcs then
            btb.trackData[t] = btb.trackData[t] or {}
            btb.trackData[t].npcMap = table.Copy(v.npcs)
        end
    end

    for t, v in pairs(btb.trackVolume or {}) do
        if not btb.trackData[t] then btb.trackData[t] = {} end
        if btb.trackData[t].vol == nil then btb.trackData[t].vol = v end
    end

    for t, v in pairs(btb.trackTrim or {}) do
        if not btb.trackData[t] then btb.trackData[t] = {} end
        if btb.trackData[t].trim == nil then btb.trackData[t].trim = table.Copy(v) end
    end

    for t, v in pairs(btb.trackAliases or {}) do
        if not btb.trackData[t] then btb.trackData[t] = {} end
        if btb.trackData[t].alias == nil then btb.trackData[t].alias = v end
    end

    btb.npcTrackMappings = {}
    btb.excludedTracks = {}
    btb.favoriteTracks = {}
    btb.trackVolume = {}
    btb.trackTrim = {}
    btb.trackAliases = {}

    btb.saveTrackData()
end

--MARK: Initialization
local function _getRandomTrack()
    return btb.GetRandomTrack(btb.currentPacks, false)
end

local function getStartingTrack()
    local mode = startMode:GetInt()

    --random
    if mode == 0 then
        return _getRandomTrack()
    end

    -- random favorite
    if mode == 1 then
        local validFavorites = {}
        for trackPath, data in pairs(btb.trackData) do
            if not data.fav then continue end
            if not trackExists(trackPath) then continue end
            local packName = btb.trackToPack[trackPath]
            local pack = packName and btb.musicPacks[packName]
            if pack and pack.ambient and table.HasValue(pack.ambient, trackPath) then
                validFavorites[#validFavorites + 1] = trackPath
            end
        end
        if #validFavorites == 0 then return _getRandomTrack() end
        return validFavorites[math.random(#validFavorites)]
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
        btb.currentPacks = util.JSONToTable(savedPacks) or {}
        for packName, _ in pairs(btb.currentPacks) do
            if not btb.musicPacks[packName] then btb.currentPacks[packName] = nil end
        end
        if not table.IsEmpty(btb.currentPacks) then
            print("[BattleBeats Client] Loaded selected packs: " .. table.concat(table.GetKeys(btb.currentPacks), ", "))
            local track = getStartingTrack()
            if track and enableAmbient:GetBool() then btb.PlayNextTrack(track) end
        else
            print("[BattleBeats Client] No saved packs found")
        end
    else
        print("[BattleBeats Client] No saved packs found")
    end
    if not table.IsEmpty(btb.musicPacks) and table.IsEmpty(btb.currentPacks) and autoPopup:GetBool() then
        RunConsoleCommand("battlebeats_menu")
    end
end

local function buildTrackMap()
    btb.trackToPack = {}
    for packName, pack in pairs(btb.musicPacks) do
        if not pack or pack.packType == "playlist" then continue end
        for _, category in ipairs({ pack.combat or {}, pack.ambient or {} }) do
            for _, track in ipairs(category) do
                btb.trackToPack[track] = packName
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
            btb.activeConflicts[name] = true
        end
    end
end

local versionConVar = GetConVar("battlebeats_seen_version")
local function loadPatchNotes()
    if not versionConVar or versionConVar:GetString() ~= btb.currentVersion then
        chat.AddText(
            Color(255, 255, 0), "[BattleBeats] ",
            Color(255, 255, 255), "Welcome to version ",
            Color(100, 255, 100), btb.currentVersion,
            Color(255, 255, 255), "! Check out the new features:"
        )
        chat.AddText(
            Color(150, 255, 150), "- New UI for assigning NPCs to tracks\n",
            Color(150, 255, 150), "- Improved tooltip readability"
        )
        chat.AddText(
            Color(255, 255, 255), "See workshop page for detailed changelog!"
        )

        RunConsoleCommand("battlebeats_seen_version", btb.currentVersion)
    end
end

SXNOTE = SXNOTE or {}
local old = SXNOTE.RegisterLyrics
function SXNOTE:RegisterLyrics(path, data)
    if old then
        old(self, path, data)
    end
    local songName = string.lower(btb.FormatTrackName(path))
    btb.subtitles[songName] = {
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
    for songName, data in pairs(btb.subtitles) do
        if data.raw then
            btb.parseSRT(songName)
        elseif data.keyframes then
            btb.parse16thNote(songName)
        end
    end
end)

hook.Add("InitPostEntity", "BattleBeats_StartMusic", function()
    if game.IsDedicated() then MsgC(Color(220, 30, 30), "BattleBeats is running on dedicated server, all server packs will be loaded as local\n") end
    --to be removed
    loadExcludedTracks()
    loadFavoriteTracks()
    loadMappedTracks()
    loadTrackTrims()
    loadTrackVolumes()
    loadTrackAliases()
    --
    loadTrackData()

    loadPackVolumes()
    findConflicts()

    loadPacks()
    loadPacksDebug()
    loadPlaylists()
    buildTrackMap()
    btb.buildNPCTrackMap()
    --
    loadSavedPacks()
    for songName, data in pairs(btb.subtitles) do
        if data.raw then
            btb.parseSRT(songName)
        elseif data.keyframes then
            btb.parse16thNote(songName)
        end
    end
    btb.ValidatePacks()
    --loadPatchNotes()
end)

concommand.Add("battlebeats_reload_packs", function()
    if IsValid(btb.frame) then btb.frame:Close() end
    btb.musicPacks = {}
    btb.checking = false
    loadedWS = {}
    loadPacks()
    loadPacksDebug()
    loadPlaylists()
    buildTrackMap()
    btb.ValidatePacks()
end)

print("BattleBeats version " .. btb.currentVersion .. "_" .. jit.arch .. " loaded")