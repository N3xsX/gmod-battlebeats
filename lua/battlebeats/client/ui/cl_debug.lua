local btb = BATTLEBEATS
local debugMode = GetConVar("battlebeats_debug_mode"):GetBool()

btb.Debug = btb.Debug or {}
btb.Debug.f = btb.Debug.f or {}

function btb.Debug.Add(id, right, f)
    if not isstring(id) or not isfunction(f) then return end
    btb.Debug.f[id] = { r = right == true, f = f }
end
function btb.Debug.Remove(id) btb.Debug.f[id] = nil end
function btb.Debug.Clear() btb.Debug.f = {} end

local td = { ec = 0, hp = 100, dmg = 0, s = 0, pt = 1, c = false }
net.Receive("BTB_ThreatDebug", function()
    td.ec = net.ReadUInt(8)
    td.hp = net.ReadUInt(7)
    td.dmg = net.ReadUInt(16)
    td.s = net.ReadUInt(5)
    td.pt = net.ReadUInt(2)
    td.c = net.ReadBool()
end)

local volumeSet = GetConVar("battlebeats_volume")
local ambientVolume = GetConVar("battlebeats_volume_ambient")
local combatVolume = GetConVar("battlebeats_volume_combat")

local function rnd(v, n) return math.Round(v or 0, n or 3) end

hook.Add("HUDPaint", "BattleBeats_FadeDebug", function()
    if not debugMode then return end

    local x, y = 20, 200
    local cw, gap, lh = 300, 30, 18
    local lx, rx = x, x + cw + gap
    local ly, ry = y + 32, y + 32

    local function text(c, s)
        draw.SimpleText(s, "DebugOverlay", c.x, c.y)
        c.y = c.y + lh
    end

    local function row(c, k, v)
        draw.SimpleText(tostring(k), "DebugOverlay", c.x, c.y)
        draw.SimpleText(tostring(v), "DebugOverlay", c.x + cw, c.y, nil, TEXT_ALIGN_RIGHT)
        c.y = c.y + lh
    end

    local function section(c, s)
        draw.SimpleTextOutlined(s, "CloseCaption_Bold", c.x, c.y, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
        c.y = c.y + 24
    end

    local function sep(c)
        c.y = c.y + 8
    end

    local function pct(f)
        if not f or not f.time or f.time <= 0 then return 1 end
        return math.Clamp(f.t / f.time, 0, 1)
    end

    local function ctx(x, y)
        local c = { x = x, y = y }
        c.row = function(k, v) row(c, k, v) end
        c.section = function(s) section(c, s) end
        c.sep = function() sep(c) end
        c.text = function(s) text(c, s) end
        c.rnd = rnd
        c.pct = pct
        c.btb = btb
        c.td = td
        return c
    end

    local l = ctx(lx, ly)
    local r = ctx(rx, ry)

    draw.SimpleTextOutlined("BattleBeats Debug", "CloseCaption_Bold", x, y, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)

    -- STATIC
    l.section("VOLUME")

    local mv = volumeSet:GetInt() / 100
    local function debugVolume(c)
        local cv = (c and combatVolume or ambientVolume):GetInt() / 100
        return rnd(btb.adjustVolume(nil, cv * mv))
    end

    l.row("master", mv)
    l.row("ambient (pure)", debugVolume(false))
    l.row("combat (pure)", debugVolume(true))

    local st = btb.currentStation
    local pv = btb.currentPreviewStation
    local stn = IsValid(st) and st:GetFileName() or IsValid(pv) and pv:GetFileName() or nil
    local tb = btb.getTrackData(stn).vol
    local tdc = btb.getTrackData(stn, true)
    local pb = btb.packVolume[tdc.pack]

    l.row("track boost", tb and rnd(tb / 100) or "NONE")
    l.row("pack boost", pb and rnd(pb / 100) or "NONE")
    --l.sep()
    --l.row("fadeMul", rnd(btb.fadeMul))

    local vol = IsValid(st) and rnd(st:GetVolume()) or IsValid(pv) and rnd(pv:GetVolume()) or "NONE"
    l.sep()
    l.row("current", vol)

    l.sep()
    l.section("STATIONS")

    l.row("track", IsValid(st) and btb.FormatTrackName(stn) or IsValid(pv) and btb.FormatTrackName(stn) or "NONE")
    l.row("pack", tdc.pack and btb.stripPackPrefix(tdc.pack) or "NONE")
    l.sep()
    l.row("is combat?", tdc.type == "combat" and "YES" or "NO")
    l.row("is preview?", IsValid(pv) and "YES" or "NO")
    l.sep()
    l.row("total length", IsValid(st) and btb.FormatTime(st:GetLength()) or IsValid(pv) and btb.FormatTime(st:GetLength()) or "NONE")
    l.row("cur time", IsValid(st) and btb.FormatTime(st:GetTime()) or IsValid(pv) and btb.FormatTime(st:GetTime()) or "NONE")

    -- DYNAMIC
    r.section("FADE STATES")
    r.row("globalFade", btb.globalFade and "YES" or "NO")
    local boost, mult, stack = 1, 1, 1
    local fc = 0
    for id, f in pairs(btb.fadeStates or {}) do
        local v = f.volume
        fc = fc + 1
        if f.boost then
            boost = math.max(boost, v)
            r.row("BOOST " .. id, rnd(v))
        elseif f.stack then
            stack = stack * v
            r.row("STACK " .. id, rnd(v))
        else
            mult = math.min(mult, v)
            r.row("REDUCE " .. id, rnd(v))
        end
    end
    if fc == 0 then r.row("states", "NONE") end

    r.sep()
    r.row("boost result", rnd(boost))
    r.row("reduction result", rnd(mult))
    r.row("stack result", rnd(stack))
    r.row("calculated target", rnd(btb.fadeMul))

    r.sep()
    r.section("FADE PROGRESS")

    local gf = btb.globalFade

    if gf then
        local p = pct(gf)
        r.row("global from", rnd(gf.from))
        r.row("global to", rnd(gf.to))
        r.row("progress", rnd(p * 100, 1) .. "%")
        r.row("time", rnd(gf.t, 2) .. " / " .. rnd(gf.time, 2))
    else
        r.row("global fade", "IDLE")
    end

    r.sep()
    r.section("STATION FADES")

    local fadeCount = 0

    for station, f in pairs(btb.fades or {}) do
        fadeCount = fadeCount + 1
        local p = pct(f)
        local sn = IsValid(station) and station:GetFileName() or "INVALID"
        r.row(f.inn and "IN" or "OUT", rnd(p * 100, 1) .. "%")
        r.text(sn)
    end

    r.row("fade count", fadeCount)

    -- EXTENSIONS
    for id, d in pairs(btb.Debug.f) do
        local c = d.r and r or l
        local ok, err = pcall(d.f, c)
        if not ok then
            c.row("[" .. id .. "] ERROR", err)
        end
    end
end)

cvars.AddChangeCallback("battlebeats_debug_mode", function(_, _, v)
    debugMode = tobool(v)
end)
