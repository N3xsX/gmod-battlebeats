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
        if ctx:ReadBool(node, "impulse") then
            if ctx:ReadBool(node, "iscombat") or (args.isCombat == true) then
                local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, true)
                ctx:Write(node, "track", track)
            else
                local track = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, false)
                ctx:Write(node, "track", track)
            end
        end
    end
})

--MARK: PLAY TRACK BTB
BATTLEBEATS.RegisterNode("audio.PLAY_TRACK_BTB", {
    category = "Audio (BTB)",
    title = "Play Track",
    desc = "Plays selected track using BattleBeats system",

    inputs = {
        { id = "track", type = "string" }
    },

    oninputschanged = function(ctx, node, args)
        if ctx:ReadBool(node, "track") then
            BATTLEBEATS.PlayNextTrack(ctx:ReadString(node, "track"))
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

local function stop(ctx, n)
    local c = n.memory.channel
    if IsValid(c) then
        c:Stop()
    end
    n.memory.channel = nil
    if n.memory.timer then
        timer.Remove(n.memory.timer)
        n.memory.timer = nil
    end
    if not ctx.running then return end
    ctx:Write(n, "playing", 0)
    ctx:Write(n, "paused", 0)
    ctx:Write(n, "stalled", 0)
end

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
        { id = "volume", type = "number", title = "Default Volume", default = 1 }
    },

    init = function(node)
        node.memory.channel = nil
    end,

    oninputschanged = function(ctx, n, args)
        local c = n.memory.channel
        local v = ctx:Read(n, "volume")
        v = math.Clamp(v == 0 and args.volume or v, 0, 5)
        if IsValid(c) then
            c:SetVolume(v)
        end
        if ctx:ReadBool(n, "stop") then
            stop(ctx, n)
            return
        end
        if not ctx:ReadBool(n, "play") then return end

        stop(ctx, n)

        local p = ctx:ReadString(n, "track")
        if p == "" or p == "0" then p = args.path end
        if p == "" then return end
        sound.PlayFile(p, "noplay", function(c)
            if not IsValid(c) then
                ctx:Write(n, "error")
                return
            end
            local o = n.memory.channel
            if IsValid(o) then o:Stop() end
            n.memory.channel = c
            c:SetVolume(v)
            c:Play()
            local id = "btb_" .. tostring(n.id)
            n.memory.timer = id
            timer.Create(id, 0.2, 0, function()
                if not IsValid(c) then
                    timer.Remove(id)
                    ctx:Write(n, "playing", 0)
                    return
                end

                local s = c:GetState()
                if s == GMOD_CHANNEL_STOPPED then
                    timer.Remove(id)
                    ctx:Write(n, "playing", 0)
                    ctx:Write(n, "paused", 0)
                    ctx:Write(n, "stalled", 0)
                elseif s == GMOD_CHANNEL_PLAYING then
                    ctx:Write(n, "playing")
                    ctx:Write(n, "paused", 0)
                    ctx:Write(n, "stalled", 0)
                elseif s == GMOD_CHANNEL_PAUSED then
                    ctx:Write(n, "playing", 0)
                    ctx:Write(n, "paused")
                    ctx:Write(n, "stalled", 0)
                elseif s == GMOD_CHANNEL_STALLED then
                    ctx:Write(n, "playing", 0)
                    ctx:Write(n, "paused", 0)
                    ctx:Write(n, "stalled")
                end
            end)
        end)
    end,

    shutdown = function(ctx, n)
        stop(ctx, n)
    end
})

local allowed = {
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
    for _, v in ipairs(f) do
        local e = string.GetExtensionFromFilename(v)
        if e and allowed[string.lower(e)] then
            t[#t + 1] = d .. "/" .. v
        end
    end
    for _, v in ipairs(dir) do
        scan(d .. "/" .. v, t)
    end
    return t
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
        { id = "folder", type = "string", title = "Folder",   default = "" },
        { id = "volume", type = "number", title = "Default Volume", default = 1 }
    },

    init = function(n, args)
        n.memory.channel = nil
        n.memory.cache = nil
        if args.folder ~= "" then
            n.memory.cache = scan(args.folder)
        end
    end,

    oninputschanged = function(ctx, n, args)
        local c = n.memory.channel
        local v = ctx:Read(n, "volume")
        v = math.Clamp(v == 0 and args.volume or v, 0, 5)
        if IsValid(c) then c:SetVolume(v) end
        if ctx:ReadBool(n, "stop") then
            stop(ctx, n)
            return
        end
        if not ctx:ReadBool(n, "play") then return end

        stop(ctx, n)

        local p
        if n.memory.cache then
            if #n.memory.cache == 0 then return end
            p = n.memory.cache[math.random(#n.memory.cache)]
        else
            local pk = args.pack and BATTLEBEATS.musicPacks[args.pack]
            if not pk then
                local t = {}
                for _, v in pairs(BATTLEBEATS.musicPacks) do t[#t + 1] = v end
                if #t == 0 then return end
                pk = t[math.random(#t)]
            end

            local t = {}
            for _, l in pairs(pk) do
                if istable(l) then
                    for _, s in ipairs(l) do t[#t + 1] = s end
                end
            end

            if #t == 0 then return end
            p = t[math.random(#t)]
        end

        sound.PlayFile(p, "noplay", function(c)
            if not IsValid(c) then
                ctx:Write(n, "error")
                return
            end

            local o = n.memory.channel
            if IsValid(o) then o:Stop() end

            n.memory.channel = c
            c:SetVolume(v)
            c:Play()

            local id = "btb_" .. tostring(n.id)
            print(id)
            n.memory.timer = id
            timer.Create(id, 0.2, 0, function()
                if not IsValid(c) then
                    timer.Remove(id)
                    ctx:Write(n, "playing", 0)
                    return
                end

                local s = c:GetState()
                if s == GMOD_CHANNEL_STOPPED then
                    timer.Remove(id)
                    ctx:Write(n, "playing", 0)
                    ctx:Write(n, "paused", 0)
                    ctx:Write(n, "stalled", 0)
                elseif s == GMOD_CHANNEL_PLAYING then
                    ctx:Write(n, "playing")
                    ctx:Write(n, "paused", 0)
                    ctx:Write(n, "stalled", 0)
                elseif s == GMOD_CHANNEL_PAUSED then
                    ctx:Write(n, "playing", 0)
                    ctx:Write(n, "paused")
                    ctx:Write(n, "stalled", 0)
                elseif s == GMOD_CHANNEL_STALLED then
                    ctx:Write(n, "playing", 0)
                    ctx:Write(n, "paused", 0)
                    ctx:Write(n, "stalled")
                end
            end)
        end)
    end,

    shutdown = function(ctx, n)
        stop(ctx, n)
    end
})
