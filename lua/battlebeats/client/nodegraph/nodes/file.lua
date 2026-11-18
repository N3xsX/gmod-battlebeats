local function scanPath(path)
    path = string.Trim(path, "/")
    if path == "" then return {} end

    local parts = string.Explode("/", path)
    local paths = {""}

    for idx, part in ipairs(parts) do
        local last = idx == #parts
        local wild = string.find(part, "*", 1, true) ~= nil
        local npaths = {}

        for _, base in ipairs(paths) do
            local prefix = base == "" and "" or (base .. "/")
            local search = prefix .. part
            local files, folders = file.Find(search, "GAME")
            files = files or {}
            folders = folders or {}

            if wild then
                for _, f in ipairs(folders) do
                    npaths[#npaths + 1] = prefix .. f
                end
                if last then
                    for _, f in ipairs(files) do
                        npaths[#npaths + 1] = prefix .. f
                    end
                end
            elseif folders[1] or (last and files[1]) then
                npaths[#npaths + 1] = search
            end
        end

        paths = npaths
        if #paths == 0 then break end
    end

    return paths
end

local cache = {}
local cacheSize = 0

local function cachedScan(path)
    local now = RealTime()
    local e = cache[path]
    if e and now - e.t < 5 then return e.paths end

    local paths = scanPath(path)
    if cacheSize > 64 then
        cache = {}
        cacheSize = 0
    end
    if not cache[path] then cacheSize = cacheSize + 1 end
    cache[path] = { t = now, paths = paths }
    return paths
end

--MARK: RANDOM_FROM
BATTLEBEATS.RegisterNode("file.RANDOM_FROM", {
    category = "File",
    title = "Random File",
    desc = "Searches the given path for matching files or folders and outputs one randomly selected result. Supports * wildcards",

    inputs = {
        { id = "path", type = "string" },
        { id = "select", type = "number" },
        { id = "alive", type = "boolean" }
    },

    outputs = {
        { id = "rnd. path", type = "string" },
        { id = "ok", type = "boolean", pulse = true },
        { id = "reused", type = "boolean", pulse = true },
        { id = "notfound", type = "boolean", pulse = true }
    },

    args = {
        { id = "dpath", type = "string", title = "Default Path", default = "" },
        { id = "keep", type = "number", title = "Remember Pick (s)", default = 0, min = 0 },
    },

    tick = function(ctx, node, args)
        if (args.keep or 0) > 0 and ctx:ReadBool(node, "alive") then
            node.memory.aliveTick = ctx.tick
        end
    end,

    oninputschanged = function(ctx, node, args)
        local p = ctx:ReadString(node, "path")
        if p ~= "" then
            node.memory.path = p
        end

        if not ctx:ReadBool(node, "select") then return end

        local path = node.memory.path or args.dpath
        if path == "" then return end

        local keep = args.keep or 0
        local last = node.memory.last
        if keep > 0 and last and last.path == path then
            local ref = ctx:IsLinked(node, "alive") and node.memory.aliveTick or last.tick
            if ref and ctx.tick - ref <= math.floor(keep / BATTLEBEATS.TickInterval + 0.5) then
                ctx:Write(node, "rnd. path", last.pick)
                ctx:Pulse(node, "ok")
                ctx:Pulse(node, "reused") -- 'ok' fires for both; 'reused' only for a remembered pick
                return
            end
        end

        local paths = cachedScan(path)
        if #paths == 0 then
            ctx:Warn(node, "No files or folders found for path '%s'", path)
            ctx:Pulse(node, "notfound")
            return
        end

        local pick = paths[math.random(#paths)]
        node.memory.last = { path = path, pick = pick, tick = ctx.tick }
        ctx:Write(node, "rnd. path", pick)
        ctx:Pulse(node, "ok")
    end
})

--MARK: SELECT
BATTLEBEATS.RegisterNode("file.SELECT", {
    category = "File",
    title = "File Select",
    desc = "Searches the given path for the specified file and outputs the first matching result. Supports * wildcards",

    inputs = {
        { id = "path", type = "string" },
        { id = "select", type = "number" },
        { id = "name", type = "string" }
    },

    outputs = {
        { id = "sel. path", type = "string" },
        { id = "ok", type = "boolean", pulse = true },
        { id = "notfound", type = "boolean", pulse = true }
    },

    args = {
        { id = "dpath", type = "string", title = "Default Path", default = "" },
        { id = "file_name", type = "string", title = "Name", default = "" },
    },

    oninputschanged = function(ctx, node, args)
        local p = ctx:ReadString(node, "path")
        if p ~= "" then
            node.memory.path = p
        end

        if not ctx:ReadBool(node, "select") then return end

        local path = node.memory.path or args.dpath
        local name = ctx:ReadString(node, "name")
        if name == "" then name = args.file_name end
        if path == "" or name == "" then return end

        local paths = cachedScan(path .. "/" .. name)
        if #paths == 0 then
            ctx:Warn(node, "No files or folders found for path '%s'", path)
            ctx:Pulse(node, "notfound")
            return
        end

        ctx:Write(node, "sel. path", paths[1])
        ctx:Pulse(node, "ok")
    end
})
