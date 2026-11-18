local btb = BATTLEBEATS

btb.Soundscripts = btb.Soundscripts or {}
btb.SoundscriptOrder = btb.SoundscriptOrder or {}
btb.ScriptZoneSets = btb.ScriptZoneSets or {}

local ready = false

local function ssError(msg)
    ErrorNoHaltWithStack("[BattleBeats Soundscripts] " .. msg .. "\n")
end

local path = "battlebeats/soundscripts.json"
local state = {}
if file.Exists(path, "DATA") then
    state = util.JSONToTable(file.Read(path, "DATA") or "") or {}
end

local function saveState()
    file.Write(path, util.TableToJSON(state, true))
end

--MARK: Helpers
local function toSet(v)
    if v == nil then return nil end
    if isstring(v) then return { [v] = true } end
    local out = {}
    for _, x in ipairs(v) do out[x] = true end
    return out
end

-- graph can be a Lua table or a raw JSON string
local function parseGraph(graph)
    if isstring(graph) then
        graph = util.JSONToTable(graph)
        if not graph then return nil, "graph is not valid JSON" end
    end
    if not istable(graph) then return nil, "graph must be a table or a JSON string" end
    if not istable(graph.nodes) or #graph.nodes == 0 then return nil, "graph has no nodes" end
    if graph.links ~= nil and not istable(graph.links) then return nil, "graph.links must be a table" end
    return graph
end

local function autostartsHere(entry)
    if not entry.autostart then return false end
    return entry.maps == nil or entry.maps[game.GetMap()] == true
end

--MARK: Zones
local function registerZones(id, z)
    if not isstring(z.name) or z.name == "" or not istable(z.zones) then
        ssError(id .. ": invalid zone set entry (needs 'name' and 'zones')")
        return nil
    end
    local existing = btb.ZoneSets[z.name]
    if existing and existing.source ~= "addon" then
        ssError(id .. ": zone set '" .. z.name .. "' already exists as a user set, skipping")
        return nil
    end
    btb.ZoneSets[z.name] = nil
    local ok, err = pcall(btb.RegisterZoneSet, z.name, z.map or game.GetMap(), z.zones)
    if not ok then
        ssError(id .. ": " .. tostring(err))
        return nil
    end
    return z.name
end

function btb.RegisterSoundscript(id, def)
    if not isstring(id) or not id:match("^[%w_%-%.]+$") then
        ssError("invalid soundscript id: " .. tostring(id))
        return false
    end
    if not istable(def) then
        ssError(id .. ": def must be a table")
        return false
    end
    local graph, err = parseGraph(def.graph)
    if not graph then
        ssError(id .. ": " .. err)
        return false
    end

    local zoneSets = {}
    for _, z in ipairs(def.zones or {}) do
        local name = registerZones(id, z)
        if name then zoneSets[#zoneSets + 1] = name end
    end
    for _, name in ipairs(def.linkedZones or {}) do
        zoneSets[#zoneSets + 1] = name
    end

    if not btb.Soundscripts[id] then
        btb.SoundscriptOrder[#btb.SoundscriptOrder + 1] = id
    end

    btb.Soundscripts[id] = {
        id = id,
        title = def.title or id,
        desc = def.desc or "",
        version = def.version or "",
        graph = graph,
        autostart = def.autostart == true,
        maps = toSet(def.maps),
        zoneSets = zoneSets
    }

    btb.RequestSoundscriptsApply()
    return true
end

function btb.UnregisterSoundscript(id)
    if not btb.Soundscripts[id] then return false end
    btb.Soundscripts[id] = nil
    table.RemoveByValue(btb.SoundscriptOrder, id)
    btb.RequestSoundscriptsApply()
    return true
end

--MARK: Enable / disable
function btb.IsSoundscriptEnabled(id)
    local entry = btb.Soundscripts[id]
    if not entry then return false end
    local s = state[id]
    if s ~= nil then return s end
    return autostartsHere(entry)
end

function btb.SetSoundscriptEnabled(id, enabled)
    if not btb.Soundscripts[id] then return false end
    state[id] = enabled == true
    saveState()
    btb.RequestSoundscriptsApply()
    return true
end

-- back to the script's own autostart rules
function btb.ResetSoundscriptState(id)
    state[id] = nil
    saveState()
    btb.RequestSoundscriptsApply()
end

function btb.GetSoundscripts()
    local out = {}
    for _, id in ipairs(btb.SoundscriptOrder) do
        out[#out + 1] = btb.Soundscripts[id]
    end
    return out
end

local function syncZones(wanted)
    for name in pairs(btb.ScriptZoneSets) do
        if not wanted[name] then
            btb.ActiveZoneSets[name] = nil
        end
    end
    for name in pairs(wanted) do
        if btb.ZoneSets[name] then
            btb.ActiveZoneSets[name] = true
        end
    end
    btb.ScriptZoneSets = wanted
    btb.RebuildZones()
    btb.ZoneState.current = {}
end

function btb.ApplySoundscripts()
    local graphs, wantedZones, names = {}, {}, {}

    for _, id in ipairs(btb.SoundscriptOrder) do
        local entry = btb.Soundscripts[id]
        if entry and btb.IsSoundscriptEnabled(id) then
            graphs[#graphs + 1] = entry.graph
            names[#names + 1] = id
            for _, zs in ipairs(entry.zoneSets) do
                wantedZones[zs] = true
            end
        end
    end

    syncZones(wantedZones)

    if #graphs == 0 then
        if btb.GetRuntime() then btb.UnloadRuntime() end
        btb.print(1, "SoundScripts", "No enabled soundscripts")
        hook.Run("BattleBeats_SoundscriptsChanged")
        return
    end

    local compiled, skipped = btb.CompileRuntime(unpack(graphs))
    if skipped > 0 then
        btb.print(2, "SoundScripts", string.format("Warning: %d nodes/links skipped while compiling", skipped))
    end

    btb.LoadRuntime(compiled)
    btb.print(1, "SoundScripts", "Running:", table.concat(names, ", "))
    hook.Run("BattleBeatsSoundscriptsChanged")
end


function btb.RequestSoundscriptsApply()
    if not ready then return end
    timer.Create("BattleBeats_SoundscriptsApply", 0.1, 1, btb.ApplySoundscripts)
end


hook.Add("InitPostEntity", "BattleBeats_SoundscriptsInit", function()
    timer.Simple(0, function()
        ready = true
        btb.ApplySoundscripts()
    end)
end)

if IsValid(LocalPlayer()) then
    ready = true
    btb.RequestSoundscriptsApply()
end
