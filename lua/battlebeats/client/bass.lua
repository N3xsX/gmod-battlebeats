BassFX = BassFX or {}
BassFX.EQPresets = {
    flat = { 0, 0, 0, 0, 0, 0, 0, 0 },
    bass = { 6, 5, 3, 1, 0, 0, 0, 0 },
    vocal = { -3, -2, 0, 3, 4, 3, 0, -1 },
    treble = { 0, 0, 0, 0, 1, 3, 5, 6 },
    loud = { 5, 3, 0, -1, -1, 0, 3, 4 },
    radio = { -12, -10, -6, 1, 5, 4, -3, -8 },
    telephone = { -15, -12, -8, 2, 5, 3, -8, -15 },
    warm = { 3, 3, 2, 0, -1, -2, -3, -4 },
    bright = { -3, -2, -1, 1, 3, 4, 5, 4 },
    night = { 2, 2, 1, 0, -2, -4, -7, -10 },
    bassboost = { 10, 7, 4, 1, 0, 0, -1, -2 },
    footsteps = { -6, -4, 0, 4, 6, 5, 2, 0 },
    underwater = { 4, 3, 1, -2, -5, -8, -12, -15 },
    crisp = { -2, -1, 0, 2, 4, 3, 2, 1 },
    cinematic = { 5, 3, -1, -2, 1, 3, 2, 0 },
    soft = { -2, -1, 1, 2, 1, -1, -3, -4 },
    sci_fi = { -4, 1, 4, -2, -3, 4, 2, -2 },
    vocal_cut = { -8, -5, 0, 5, 6, 2, -5, -10 },
}
local function defProfile()
    return { enabled = true, eq = { 0, 0, 0, 0, 0, 0, 0, 0 }, fx = {} }
end
BassFX.Profile = BassFX.Profile or defProfile()
BassFX.installed = false
if file.Exists("lua/bin/gmcl_bassfx_win64.dll", "GAME") then
    if jit.arch ~= "x64" then
        BATTLEBEATS.print(2, "Init", "BassFX supports only 64 bit version of GMod!")
    else
        local ok, err = pcall(require, "bassfx")
        if ok then
            BassFX.installed = true
            BATTLEBEATS.print(1, "Init", "BassFX Library successfully loaded")
        else
            BATTLEBEATS.print(2, "Init", "BassFX failed to load:", tostring(err))
        end
    end
end
if not BassFX.installed then return end
local META = FindMetaTable("IGModAudioChannel")
local active = setmetatable({}, { __mode = "k" })

function META:GetBassHandle()
    if not IsValid(self) then return end
    return bassfx.Handle(self, self:GetSamplingRate())
end

function META:SetDSP(name, params, priority)
    if not IsValid(self) then return false end
    local kind = string.match(name, "^[^#]+")
    local t = active[self]
    if not t then
        t = {}
        active[self] = t
    end

    if t[name] then
        local ok, res, err = pcall(bassfx.SetFX, t[name], kind, params or {})
        if not ok then return false, res end
        if res then return true end
        if err ~= 5 then return false, err end
        t[name] = nil
    end

    local ok, fx, err = pcall(bassfx.AddFX, self, self:GetSamplingRate(), kind, params, priority)
    if not ok then return false, fx end
    if not fx then return false, err end
    t[name] = fx
    return true
end

function META:ClearDSP()
    local t = active[self]
    if not t then return end
    for name in pairs(t) do self:RemoveDSP(name) end
end

function META:ResetDSP()
    local t = active[self]
    if not (t and IsValid(self)) then return end
    for _, fx in pairs(t) do bassfx.ResetFX(fx) end
end

function META:RemoveDSP(name)
    local t = active[self]
    if not (t and t[name]) then return false end
    local fx = t[name]
    t[name] = nil
    return IsValid(self) and bassfx.RemoveFX(self, self:GetSamplingRate(), fx) or false
end

local bands = { 100, 200, 400, 800, 1600, 3200, 6400, 12800 }
local stations = setmetatable({}, { __mode = "k" })
local applied = setmetatable({}, { __mode = "k" })

function BassFX.Apply(st)
    if not (BassFX.installed and IsValid(st)) then return end

    local p, e, freq = BassFX.Profile, BassFX.Env or {}, st:GetSamplingRate()
    local had, want = applied[st] or {}, {}

    for i, center in ipairs(bands) do
        local gain = (p.enabled and (p.eq[i] or 0) or 0) + (e.eq[i] or 0)
        gain = math.Clamp(gain, -15, 15)
        if math.abs(gain) >= 0.1 and center * 3 < freq then
            local name = "eq#b" .. i
            if st:SetDSP(name, { fCenter = center, fBandwidth = 12, fGain = gain }, 1) then want[name] = true end
        end
    end

    if p.enabled then
        for kind, params in pairs(p.fx) do
            local name = kind .. "#fx"
            if st:SetDSP(name, params) then want[name] = true end
        end
    end

    for name, params in pairs(e.fx or {}) do
        if st:SetDSP(name, params) then want[name] = true end
    end

    for name in pairs(had) do
        if not want[name] then st:RemoveDSP(name) end
    end

    applied[st] = want
end

function BassFX.Attach(st)
    if not (BassFX.installed and IsValid(st)) then return end
    stations[st] = true
    BassFX.Apply(st)
end

function BassFX.Refresh()
    for st in pairs(stations) do
        if IsValid(st) then BassFX.Apply(st) end
    end
end

function BassFX.SetEnabled(b)
    BassFX.Profile.enabled = b and true or false
    BassFX.Refresh()
    BassFX.QueueSave()
end

function BassFX.SetBand(i, gain)
    if not bands[i] then return end
    BassFX.Profile.eq[i] = math.Clamp(tonumber(gain) or 0, -15, 15)
    BassFX.Refresh()
    BassFX.QueueSave()
end

function BassFX.SetEQ(gains)
    for i = 1, #bands do
        BassFX.Profile.eq[i] = math.Clamp(tonumber(gains[i]) or 0, -15, 15)
    end
    BassFX.Refresh()
    BassFX.QueueSave()
end

function BassFX.SetEffect(kind, params)
    BassFX.Profile.fx[kind] = params or {}
    BassFX.Refresh()
    BassFX.QueueSave()
end

function BassFX.ClearEffect(kind)
    BassFX.Profile.fx[kind] = nil
    BassFX.Refresh()
    BassFX.QueueSave()
end

function BassFX.Save()
    file.Write("battlebeats/bassfx_profile.json", util.TableToJSON(BassFX.Profile))
end

function BassFX.QueueSave()
    timer.Create("bassfx_save", 0.5, 1, BassFX.Save)
end

function BassFX.Load()
    local raw = file.Read("battlebeats/bassfx_profile.json", "DATA")
    local t = raw and util.JSONToTable(raw)
    if not istable(t) then return end

    local p = defProfile()
    p.enabled = t.enabled ~= false
    for i = 1, #bands do
        p.eq[i] = math.Clamp(tonumber(istable(t.eq) and t.eq[i]) or 0, -15, 15)
    end
    if istable(t.fx) then
        for kind, params in pairs(t.fx) do
            if isstring(kind) and istable(params) then p.fx[kind] = params end
        end
    end
    BassFX.Profile = p
end

BassFX.Load()
