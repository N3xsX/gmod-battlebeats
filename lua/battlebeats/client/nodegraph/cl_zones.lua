BATTLEBEATS.ZoneSets = BATTLEBEATS.ZoneSets or {}
BATTLEBEATS.ActiveZones = BATTLEBEATS.ActiveZones or {}
BATTLEBEATS.CurrentZoneSet = "default"

local active = {}
if file.Exists("battlebeats_zones/active.json", "DATA") then
    active = util.JSONToTable(file.Read("battlebeats_zones/active.json", "DATA")) or {}
end
BATTLEBEATS.ActiveZoneSets = active[game.GetMap()] or {
    default = true
}

local function zoneToVector(zone)
    if zone.min then return zone end
    zone.min = Vector(zone.minx, zone.miny, zone.minz)
    zone.max = Vector(zone.maxx, zone.maxy, zone.maxz)
    zone.minx = nil
    zone.miny = nil
    zone.minz = nil
    zone.maxx = nil
    zone.maxy = nil
    zone.maxz = nil
    return zone
end

local function convertZones(zones)
    for _, zone in ipairs(zones) do
        zoneToVector(zone)
    end
    return zones
end

local function pointInZone(pos, zone)
    local min = zone.min
    local max = zone.max
    return pos.x >= min.x and pos.x <= max.x
        and pos.y >= min.y and pos.y <= max.y
        and pos.z >= min.z and pos.z <= max.z
end

function BATTLEBEATS.TickZones()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local pos = ply:EyePos()
    local c = BATTLEBEATS.ZoneState.current
    for _, zone in ipairs(BATTLEBEATS.ActiveZones) do
        local a = c[zone]
        local inn = pointInZone(pos, zone)
        if a == nil then
            c[zone] = inn
            continue
        end
        if a ~= inn then
            if inn then
                BATTLEBEATS.FireNodeByClassArg("event.ZONE", "entered", 1, "zone", zone.name)
            else
                BATTLEBEATS.FireNodeByClassArg("event.ZONE", "exited", 1, "zone", zone.name)
                BATTLEBEATS.FireNodeByClassArg("event.ZONE", "stay", 0, "zone", zone.name)
            end
        end
        if inn then
            BATTLEBEATS.FireNodeByClassArg("event.ZONE", "stay", 1, "zone", zone.name)
        end
        c[zone] = inn
    end
end

function BATTLEBEATS.GetCurrentZoneSet()
    return BATTLEBEATS.CurrentZoneSet or "default"
end

function BATTLEBEATS.RegisterZoneSet(n, m, z)
    assert(isstring(n) and n ~= "" and n ~= "default", "[BattleBeats ZoneSets] Invalid zone set name")
    if BATTLEBEATS.ZoneSets[n] then error("[BattleBeats ZoneSets] Duplicate zone set: " .. n, 2) end
    assert(isstring(m) and m ~= "", "[BattleBeats ZoneSets] Invalid map name")
    assert(istable(z), "[BattleBeats ZoneSets] Invalid zone data")
    if m ~= game.GetMap() then return end
    BATTLEBEATS.ZoneSets[n] = { source = "addon", zones = convertZones(z) }
    if BATTLEBEATS.ActiveZoneSets[n] then BATTLEBEATS.RebuildZones() end
end

function BATTLEBEATS.RebuildZones()
    BATTLEBEATS.ActiveZones = {}
    for setName in pairs(BATTLEBEATS.ActiveZoneSets) do
        local set = BATTLEBEATS.ZoneSets[setName]
        if set then
            table.Add(BATTLEBEATS.ActiveZones, set.zones)
        end
    end
end

function BATTLEBEATS.DeleteZone(setName, zone)
    local set = BATTLEBEATS.ZoneSets[setName]
    if not set then return false end
    table.remove(set.zones, zone)
    BATTLEBEATS.SaveZoneSet(setName)
    BATTLEBEATS.RebuildZones()
    return true
end

function BATTLEBEATS.AddZone(setName, zone)
    local set = BATTLEBEATS.ZoneSets[setName]
    if not set then return false end
    zoneToVector(zone)
    table.insert(set.zones, zone)
    BATTLEBEATS.SaveZoneSet(setName)
    BATTLEBEATS.RebuildZones()
    hook.Run("BattleBeatsZoneSetsChanged")
    return true
end

function BATTLEBEATS.LoadZoneSets()
    local dir = "battlebeats_zones/" .. game.GetMap()
    file.CreateDir("battlebeats_zones")
    file.CreateDir(dir)
    local files = file.Find(dir .. "/*.json", "DATA")
    for _, fileName in ipairs(files) do
        local setName = string.StripExtension(fileName)
        local zones = util.JSONToTable(file.Read(dir .. "/" .. fileName, "DATA")) or {}
        BATTLEBEATS.ZoneSets[setName] = {source = "data", zones = convertZones(zones)}
    end
end

function BATTLEBEATS.SaveZoneSet(name)
    if not name then name = "default" end
    local set = BATTLEBEATS.ZoneSets[name]
    if not set then return false end
    if set.source ~= "data" then
        return false
    end

    local dir = "battlebeats_zones/" .. game.GetMap()
    file.CreateDir(dir)

    local path = dir .. "/" .. name .. ".json"
    local zones = table.Copy(set.zones)
    for _, zone in ipairs(zones) do
        zone.minx = zone.min.x
        zone.miny = zone.min.y
        zone.minz = zone.min.z
        zone.maxx = zone.max.x
        zone.maxy = zone.max.y
        zone.maxz = zone.max.z
        zone.min = nil
        zone.max = nil
    end
    file.Write(path, util.TableToJSON(zones, true))
    return true
end

function BATTLEBEATS.CreateZoneSet(name, zones)
    if BATTLEBEATS.ZoneSets[name] then return false end
    BATTLEBEATS.ZoneSets[name] = {source = "data", zones = zones or {}}
    BATTLEBEATS.SaveZoneSet(name)
    return true
end

function BATTLEBEATS.DeleteZoneSet(name)
    local set = BATTLEBEATS.ZoneSets[name]
    if not set then return false end
    if set.source ~= "data" then
        return false
    end
    BATTLEBEATS.ZoneSets[name] = nil
    BATTLEBEATS.ActiveZoneSets[name] = nil
    local path = "battlebeats_zones/" .. game.GetMap() .. "/" .. name .. ".json"
    if file.Exists(path, "DATA") then
        file.Delete(path)
    end
    BATTLEBEATS.SaveActiveZones()
    BATTLEBEATS.RebuildZones()
end

function BATTLEBEATS.SaveActiveZones()
    local path = "battlebeats_zones/active.json"
    local activee = {}
    if file.Exists(path, "DATA") then
        activee = util.JSONToTable(file.Read(path, "DATA")) or {}
    end
    activee[game.GetMap()] = BATTLEBEATS.ActiveZoneSets
    file.Write(path, util.TableToJSON(activee, true))
end

hook.Add("InitPostEntity", "LoadZones", function()
    BATTLEBEATS.LoadZoneSets()
    if not BATTLEBEATS.ZoneSets.default then
        BATTLEBEATS.CreateZoneSet("default")
    end
    BATTLEBEATS.RebuildZones()
    BATTLEBEATS.SaveActiveZones()
end)
