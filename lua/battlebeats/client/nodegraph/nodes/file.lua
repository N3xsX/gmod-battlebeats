local function scanPath(path)
    path = string.Trim(path, "/")
    local parts = string.Explode("/", path)
    local paths = {""}
    for _, part in ipairs(parts) do
        local npath = {}
        for _, base in ipairs(paths) do
            local search = base == "" and part or base .. "/" .. part
            if string.find(part, "%*") then
                local files, folders = file.Find(search, "GAME")
                for _, folder in ipairs(folders or {}) do
                    npath[#npath + 1] =
                        base == "" and folder or base .. "/" .. folder
                end
                for _, fname in ipairs(files or {}) do
                    npath[#npath + 1] = base == "" and fname or base .. "/" .. fname
                end
            else
                local files, folders = file.Find(search, "GAME")
                if files and files[1] then
                    npath[#npath + 1] = search
                elseif folders and folders[1] then
                    npath[#npath + 1] = search
                end
            end
        end
        paths = npath
        if #paths == 0 then
            break
        end
    end
    return paths
end

--MARK: RANDOM_FROM
BATTLEBEATS.RegisterNode("file.RANDOM_FROM", {
    category = "File",
    title = "Random File",
    desc = "Searches the given path for matching files or folders and outputs one randomly selected result. Supports * wildcards",

    inputs = {
        { id = "path", type = "string" },
        { id = "select", type = "number" }
    },

    outputs = {
        { id = "rnd. path", type = "string" },
        { id = "ok", type = "boolean", pulse = true }
    },

    args = {
        { id = "dpath", type = "string", title = "Default Path", default = "" },
    },

    oninputschanged = function(ctx, node, args)
        if ctx:ReadBool(node, "path") then
            node.memory.path = ctx:ReadString(node, "path")
        end

        if not ctx:ReadBool(node, "select") then return end

        local path = node.memory.path or args.dpath
        if path == "" then return end

        local paths = scanPath(path)
        if #paths == 0 then
            return ctx:Warn(node, "No files or folders found for path '%s'", path)
        end

        ctx:Write(node, "rnd. path", paths[math.random(#paths)])
        ctx:Write(node, "ok")
    end
})

--MARK: SELECT
BATTLEBEATS.RegisterNode("file.SELECT", {
    category = "File",
    title = "File Select",
    desc = "Searches the given path for the specified file and outputs the first matching result. Supports * wildcards",

    inputs = {
        { id = "path", type = "string" },
        { id = "select", type = "number" }
    },

    outputs = {
        { id = "sel. path", type = "string" },
        { id = "ok", type = "boolean", pulse = true }
    },

    args = {
        { id = "dpath", type = "string", title = "Default Path", default = "" },
        { id = "file_name", type = "string", title = "Name", default = "" },
    },

    oninputschanged = function(ctx, node, args)
        if ctx:ReadBool(node, "path") then
            node.memory.path = ctx:ReadString(node, "path")
        end

        if not ctx:ReadBool(node, "select") then return end

        local path = node.memory.path or args.dpath
        if path == "" or args.file_name == "" then return end

        local paths = scanPath(path .. "/" .. args.file_name)
        if #paths == 0 then
            return ctx:Warn(node, "No files or folders found for path '%s'", path)
        end

        ctx:Write(node, "sel. path", paths[1])
        ctx:Write(node, "ok")
    end
})
