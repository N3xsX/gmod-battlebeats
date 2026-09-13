local btb = BATTLEBEATS
local debugMode = GetConVar("battlebeats_debug_mode"):GetBool()

local ext = false

local td = { ec = 0, hp = 100, dmg = 0, s = 0, pt = 1, c = false }
net.Receive("BTB_ThreatDebug", function()
    td.ec = net.ReadUInt(8)
    td.hp = net.ReadUInt(7)
    td.dmg = net.ReadUInt(16)
    td.s = net.ReadUInt(5)
    td.pt = net.ReadUInt(2)
    td.c = net.ReadBool()
end)

hook.Add("HUDPaint", "BattleBeats_FadeDebug", function()
    if not debugMode then return end
    local x, y = 20, 200
    local lh = 18

    local function txt(label, value)
        draw.SimpleText(label .. ": " .. tostring(value), "DebugOverlay", x, y)
        y = y + lh
    end

    local function sep()
        y = y + 8
    end

    local function debugVolume(isCombat)
        local old = btb.isInCombat
        btb.isInCombat = isCombat
        local v = btb.adjustVolume(nil)
        btb.isInCombat = old
        return v
    end

    draw.SimpleText("BattleBeats Debug", "CloseCaption_Bold", x, y)
    y = y + 30

    txt("fadeMul", math.Round(btb.fadeMul or 1, 3))

    local gf = btb.globalFade
    txt("globalFade", gf and "YES" or "NO")

    if gf then
        local p = gf.time > 0 and math.Clamp(gf.t / gf.time, 0, 1) or 1

        txt("  from", math.Round(gf.from, 3))
        txt("  to", math.Round(gf.to, 3))
        txt("  progress", math.Round(p * 100, 1) .. "%")
        txt("  time", math.Round(gf.t, 2) .. " / " .. math.Round(gf.time, 2))
    end

    sep()

    local boost = 1
    local multiplier = 1

    txt("fade states", "")

    for id, f in pairs(btb.fadeStates or {}) do
        local v = f.volume

        if f.boost then
            boost = math.max(boost, v)
            txt("  BOOST " .. id, math.Round(v, 3))
        else
            multiplier = math.min(multiplier, v)
            txt("  REDUCTION " .. id, math.Round(v, 3))
        end
    end

    txt("boost result", math.Round(boost, 3))
    txt("mult result", math.Round(multiplier, 3))
    txt("calculated target", math.Round(boost * multiplier, 3))

    sep()

    local ambient = debugVolume(false)
    local combat = debugVolume(true)

    txt("ambient volume", ambient)
    txt("combat volume", combat)
    local st = btb.currentStation
    local stn = IsValid(st) and st:GetFileName()
    local pb = btb.packVolume[btb.getTrackData(stn, true).pack]
    local tb = btb.getTrackData(stn).vol
    txt("track vol boost", tb and (tb / 100) or "NONE")
    txt("pack vol boost", pb and (pb / 100) or "NONE")

    if ext then
        sep()
        txt("threat level", btb.threatLevel)
        txt("  threat peak: ", td.pt)
        txt("  threat score: ", td.s)
        txt("enemies: ", td.ec)
        txt("player hp: ", td.hp)
        txt("dmg taken: ", td.dmg)
    end

    sep()

    txt("current station", stn or "NONE")
    txt("station volume", IsValid(st) and math.Round(st:GetVolume(), 3) or "NONE")

    local pv = btb.currentPreviewStation

    txt("preview station", IsValid(pv) and pv:GetFileName() or "NONE")
    txt("preview volume", IsValid(pv) and math.Round(pv:GetVolume(), 3) or "NONE")

    sep()

    local fadeCount = 0

    for station, f in pairs(btb.fades or {}) do
        fadeCount = fadeCount + 1
        local p = f.time > 0 and math.Clamp(f.t / f.time, 0, 1) or 1
        txt("station fade", (IsValid(station) and station:GetFileName() or "INVALID") .. " " .. (f.inn and "IN" or "OUT") .. " " .. math.Round(p * 100, 1) .. "%")
    end

    txt("station fades", fadeCount)
end)

cvars.AddChangeCallback("battlebeats_debug_mode", function(_, _, newValue)
    debugMode = tobool(newValue)
end)