--MARK: RANDOM TRACK BTB
BATTLEBEATS.RegisterNode("audio.RANDOM_TRACK_BTB", {
    category = "Audio (BTB)",
    title = "Random Track",
    desc = "Selects random track from available battlebeats tracks",

    inputs = {
        { id = "impulse", type = "boolean" },
        { id = "iscombat", type = "boolean" }
    },

    outputs = {
        { id = "track", type = "string" }
    },

    args = {
        { id = "isCombat", title = "Constant Combat", type = "bool", default = false },
    },

    oninputschanged = function(ctx, node, args)
        if not ctx:ReadBool(node, "impulse") then return end

        local combat = ctx:ReadBool(node, "iscombat") or args.isCombat == true
        local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, combat)
        if not track or track == "" then
            ctx:Warn(node, "No track available (combat = %s)", tostring(combat))
            return
        end
        ctx:Write(node, "track", track)
    end
})

--MARK: PLAY TRACK BTB
BATTLEBEATS.RegisterNode("audio.PLAY_TRACK_BTB", {
    category = "Audio (BTB)",
    title = "Play Track",
    desc = "Plays selected track using BattleBeats system. It remembers the playback position of its own tracks: a pulse on 'resume' makes the next play continue from where this node's music stopped instead of using 'time'",

    inputs = {
        { id = "track", type = "string" },
        { id = "time", type = "number" },
        { id = "play", type = "boolean" },
        { id = "resume", type = "boolean" }
    },

    args = {
        { id = "nonoti", type = "bool", title = "No Track Notification", default = false },
        { id = "loop", type = "bool", title = "Loop Track", default = false },
        { id = "fadein", type = "number", title = "Fade in Time", default = 2 },
    },

    tick = function(ctx, node)
        local m = node.memory
        local st = BATTLEBEATS.currentStation
        if m.playing and IsValid(st) and st:GetFileName() == m.playing then
            m.pos = st:GetTime()
            m.len = st:GetLength()
        end
    end,

    oninputschanged = function(ctx, node, args)
        local m = node.memory
        local t = ctx:ReadString(node, "track")
        if t ~= "" then
            m.track = t
        end

        local rs = ctx:ReadBool(node, "resume")
        if rs and not m.oldResume then m.resumeNext = true end
        m.oldResume = rs

        if not ctx:ReadBool(node, "play") then return end

        local track = m.track
        if not track or track == "" then return end

        local time = ctx:Read(node, "time")
        if m.resumeNext then
            m.resumeNext = false
            if m.pos and (not m.len or m.pos < m.len - 1) then time = m.pos end
        end
        m.playing = track

        local prop = {
            noNotification = args.nonoti,
            loop = args.loop
        }
        BATTLEBEATS.PlayNextTrack(track, time, args.fadein, nil, nil, prop)
    end
})

--MARK: GET TIME
BATTLEBEATS.RegisterNode("audio.GET_TIME_BTB", {
    category = "Audio (BTB)",
    title = "Get Channel Current Time",
    desc = "Outputs the current playback time (seconds) of the BattleBeats channel when triggered. 'zero' resets the output to 0 (wins over the trigger), e.g. for a track that should start from the beginning",

    inputs = {
        { id = "toogle", type = "boolean" },
        { id = "zero", type = "boolean" }
    },

    outputs = {
        { id = "time", type = "number" }
    },

    args = {
        { id = "offset", type = "number", title = "Latency Offset (s)", default = 0 }
    },

    oninputschanged = function(ctx, node, args)
        if ctx:ReadBool(node, "zero") then
            ctx:Write(node, "time", 0)
            return
        end
        if ctx:ReadBool(node, "toogle") and IsValid(BATTLEBEATS.currentStation) then
            ctx:Write(node, "time", BATTLEBEATS.currentStation:GetTime() + (args.offset or 0))
        end
    end
})

--MARK: IS IN COMBAT BTB
BATTLEBEATS.RegisterNode("condition.IN_COMBAT_BTB", {
    category = "Audio (BTB)",
    title = "Is In Combat",
    desc = "Outputs whether the player is in combat (BattleBeats)",

    outputs = {
        { id = "isincombat", type = "boolean" }
    }
})

--MARK: THREAT LEVEL BTB
BATTLEBEATS.RegisterNode("audio.THREAT_LEVEL_BTB", {
    category = "Audio (BTB)",
    title = "Threat level",
    desc = "Outputs the current BattleBeats threat level",

    outputs = {
        { id = "threat lvl", type = "number" }
    },

    tick = function(ctx, node, args)
        ctx:Write(node, "threat lvl", BATTLEBEATS.threatLevel or 0)
    end
})

--MARK: DISABLE AMBIENT / COMBAT
local function registerToggle(class, title, desc, flag)
    BATTLEBEATS.RegisterNode(class, {
        category = "Audio (BTB)",
        title = title,
        desc = desc,

        inputs = {
            { id = "toogle", type = "boolean" }
        },

        oninputschanged = function(ctx, node, args)
            local v = ctx:ReadBool(node, "toogle")
            local old = node.memory.old or false
            node.memory.old = v

            if v and not old then
                if node.memory.orig == nil then
                    node.memory.orig = BATTLEBEATS[flag] or false
                end
                BATTLEBEATS[flag] = not BATTLEBEATS[flag]
            end
        end,

        shutdown = function(ctx, node)
            if node.memory.orig ~= nil then
                BATTLEBEATS[flag] = node.memory.orig
            end
        end
    })
end

registerToggle("audio.DISABLE_AMBIENT_BTB", "Disable Ambient", "Toggles ambient music on/off on every rising edge. Restored when the runtime unloads", "disableAmbient")
registerToggle("audio.DISABLE_COMBAT_BTB", "Disable Combat", "Toggles combat music on/off on every rising edge. Restored when the runtime unloads", "disableCombat")

--MARK: COMBAT HOLD (afterglow)
hook.Add("BattleBeats_OverrideCombatState", "BattleBeats_CombatHoldNode", function(real)
    local ctx = BATTLEBEATS.GetRuntime()
    local list = ctx and ctx.running and ctx.classIndex["audio.COMBAT_HOLD_BTB"]
    if not list then return end

    local now = CurTime()
    local holding = false
    for _, n in ipairs(list) do
        if not n.disabled then
            local m = n.memory
            if real then
                if not m.inSession then m.peak = 1 end
                m.inSession = true
                m.holding = false
                m.lastReal = now
                m.peak = math.max(m.peak, BATTLEBEATS.threatLevel or 1)
            elseif m.inSession then
                local len = n.args.hold + n.args.perLevel * math.max(m.peak - 1, 0)
                if now - m.lastReal < len then
                    m.holding = true
                    holding = true
                else
                    m.holding = false
                    m.inSession = false
                    m.endedFlag = true
                end
            end
        end
    end
    if holding then return true end
end)

BATTLEBEATS.RegisterNode("audio.COMBAT_HOLD_BTB", {
    category = "Audio (BTB)",
    title = "Combat Hold (Afterglow)",
    desc = "Keeps the combat state alive for a while after the real combat has ended, so combat music lasts longer and short breaks do not start ambient or a new combat. The hold grows with the highest threat level of the session",

    outputs = {
        { id = "active", type = "boolean" },
        { id = "lingering", type = "boolean" },
        { id = "ended", type = "boolean", pulse = true }
    },

    args = {
        { id = "hold", type = "number", title = "Hold After Combat (s)", default = 8, min = 0 },
        { id = "perLevel", type = "number", title = "Extra Per Threat Level Above 1 (s)", default = 3, min = 0 }
    },

    init = function(node)
        local m = node.memory
        m.inSession, m.holding, m.peak, m.lastReal = false, false, 1, 0
    end,

    tick = function(ctx, node)
        local m = node.memory
        local a, l = m.inSession and 1 or 0, m.holding and 1 or 0
        if m.wA ~= a then m.wA = a ctx:Write(node, "active", a) end
        if m.wL ~= l then m.wL = l ctx:Write(node, "lingering", l) end
        if m.endedFlag then
            m.endedFlag = false
            ctx:Pulse(node, "ended")
        end
    end,

    shutdown = function(ctx, node)
        node.memory.inSession, node.memory.holding = false, false
    end
})

--MARK: Shared playback helpers (PLAY_SOUND / PLAY_SOUND_RANDOM)
local function setState(ctx, n, playing, paused, stalled)
    local s = (playing and 1 or 0) + (paused and 2 or 0) + (stalled and 4 or 0)
    local m = n.memory
    if m.pstate == s then return end
    m.pstate = s
    ctx:Write(n, "playing", playing and 1 or 0)
    ctx:Write(n, "paused", paused and 1 or 0)
    ctx:Write(n, "stalled", stalled and 1 or 0)
end

local function stop(ctx, n)
    local m = n.memory
    m.gen = (m.gen or 0) + 1
    local c = m.channel
    m.channel = nil
    if IsValid(c) then c:Stop() end
    if ctx.running then
        setState(ctx, n, false, false, false)
    end
end

local function startPlayback(ctx, n, path, volume, loop)
    stop(ctx, n)
    local gen = n.memory.gen

    sound.PlayFile(path, "noplay", function(c, code, err)
        if n.memory.gen ~= gen or not ctx.running then
            if IsValid(c) then c:Stop() end
            return
        end
        if not IsValid(c) then
            ctx:Warn(n, "sound.PlayFile failed for '%s' (%s): %s", tostring(path), tostring(code), tostring(err))
            ctx:Pulse(n, "error")
            return
        end
        n.memory.channel = c
        c:SetVolume(volume)
        if loop then c:EnableLooping(true) end
        c:Play()
    end)
end

local function pollChannel(ctx, n)
    local m = n.memory
    local c = m.channel
    if not c then return end

    if not IsValid(c) then
        m.channel = nil
        setState(ctx, n, false, false, false)
        return
    end

    local s = c:GetState()
    if s == GMOD_CHANNEL_STOPPED then
        m.channel = nil
        setState(ctx, n, false, false, false)
    elseif s == GMOD_CHANNEL_PLAYING then
        setState(ctx, n, true, false, false)
    elseif s == GMOD_CHANNEL_PAUSED then
        setState(ctx, n, false, true, false)
    elseif s == GMOD_CHANNEL_STALLED then
        setState(ctx, n, false, false, true)
    end
end

local function getVolume(ctx, n, args)
    local v = ctx:ReadOptional(n, "volume")
    return math.Clamp(v or args.volume or 1, 0, 5)
end

--MARK: PLAY SOUND
BATTLEBEATS.RegisterNode("audio.PLAY_SOUND", {
    category = "Audio",
    title = "Play Sound",
    desc = "Plays a sound using sound.PlayFile. Every node owns its own audio channel",

    inputs = {
        { id = "play", type = "boolean" },
        { id = "stop", type = "boolean" },
        { id = "track", type = "string" },
        { id = "volume", type = "number" }
    },

    outputs = {
        { id = "playing", type = "boolean" },
        { id = "paused",  type = "boolean" },
        { id = "stalled", type = "boolean" },
        { id = "error",   type = "boolean", pulse = true }
    },

    args = {
        { id = "path", type = "string", title = "Default Path", default = "" },
        { id = "volume", type = "number", title = "Default Volume", default = 1 },
        { id = "loop", type = "bool", title = "Loop", default = false }
    },

    init = function(node)
        node.memory.channel = nil
    end,

    tick = function(ctx, n)
        pollChannel(ctx, n)
    end,

    oninputschanged = function(ctx, n, args)
        local v = getVolume(ctx, n, args)
        local c = n.memory.channel
        if IsValid(c) then c:SetVolume(v) end

        if ctx:ReadBool(n, "stop") then
            stop(ctx, n)
            return
        end
        if not ctx:ReadBool(n, "play") then return end

        local p = ctx:ReadString(n, "track")
        if p == "" then p = args.path end
        if p == "" then return end

        startPlayback(ctx, n, p, v, args.loop)
    end,

    shutdown = function(ctx, n)
        stop(ctx, n)
    end
})

--MARK: PLAY SOUND RANDOM
local allowedExt = {
    mp3  = true,
    wav  = true,
    aiff = true,
    ogg  = true,
    flac = true,
    m4a  = true,
    wma  = true
}

local function scan(d, t)
    t = t or {}
    local f, dir = file.Find(d .. "/*", "GAME")
    for _, v in ipairs(f or {}) do
        local e = string.GetExtensionFromFilename(v)
        if e and allowedExt[string.lower(e)] then
            t[#t + 1] = d .. "/" .. v
        end
    end
    for _, v in ipairs(dir or {}) do
        scan(d .. "/" .. v, t)
    end
    return t
end

local folderCache = {}
local function folderTracks(folder)
    local now = RealTime()
    local e = folderCache[folder]
    if e and now - e.t < 30 then return e.list end
    local list = scan(folder)
    folderCache[folder] = { t = now, list = list }
    return list
end

local packCache = setmetatable({}, { __mode = "k" })
local function packTracks(pk)
    local now = RealTime()
    local e = packCache[pk]
    if e and now - e.t < 30 then return e.list end
    local list = {}
    for _, l in pairs(pk) do
        if istable(l) then
            for _, s in ipairs(l) do list[#list + 1] = s end
        end
    end
    packCache[pk] = { t = now, list = list }
    return list
end

local function pickPack(name)
    local packs = BATTLEBEATS.musicPacks
    if not istable(packs) then return nil end
    if name ~= "" and istable(packs[name]) then return packs[name] end
    local arr = {}
    for _, p in pairs(packs) do
        if istable(p) then arr[#arr + 1] = p end
    end
    if #arr == 0 then return nil end
    return arr[math.random(#arr)]
end

BATTLEBEATS.RegisterNode("audio.PLAY_SOUND_RANDOM", {
    category = "Audio",
    title = "Play Random Sound",
    desc = "Plays random sound. If pack or folder is not specified, it will play random track from BattleBeats music packs. Every node owns its own audio channel",

    inputs = {
        { id = "play", type = "boolean" },
        { id = "stop", type = "boolean" },
        { id = "volume", type = "number" }
    },

    outputs = {
        { id = "playing", type = "boolean" },
        { id = "paused", type = "boolean" },
        { id = "stalled", type = "boolean" },
        { id = "error", type = "boolean", pulse = true }
    },

    args = {
        { id = "pack", type = "string", title = "Music Pack", default = "" },
        { id = "folder", type = "string", title = "Folder", default = "" },
        { id = "volume", type = "number", title = "Default Volume", default = 1 },
        { id = "loop", type = "bool", title = "Loop", default = false }
    },

    init = function(n)
        n.memory.channel = nil
    end,

    tick = function(ctx, n)
        pollChannel(ctx, n)
    end,

    oninputschanged = function(ctx, n, args)
        local v = getVolume(ctx, n, args)
        local c = n.memory.channel
        if IsValid(c) then c:SetVolume(v) end

        if ctx:ReadBool(n, "stop") then
            stop(ctx, n)
            return
        end
        if not ctx:ReadBool(n, "play") then return end

        local list
        if args.folder ~= "" then
            list = folderTracks(args.folder)
        else
            local pk = pickPack(args.pack)
            list = pk and packTracks(pk)
        end

        if not list or #list == 0 then
            ctx:Warn(n, "No tracks to play (pack '%s', folder '%s')", tostring(args.pack), tostring(args.folder))
            return
        end

        startPlayback(ctx, n, list[math.random(#list)], v, args.loop)
    end,

    shutdown = function(ctx, n)
        stop(ctx, n)
    end
})
