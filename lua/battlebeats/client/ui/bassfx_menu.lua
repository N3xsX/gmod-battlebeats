local bLabel = { "100 Hz", "200 Hz", "400 Hz", "800 Hz", "1.6 kHz", "3.2 kHz", "6.4 kHz", "12.8 kHz" }
local effects = {
    {
        kind = "reverb",
        label = "Reverb",
        def = { fInGain = 0, fReverbMix = -12, fReverbTime = 1500, fHighFreqRTRatio = 0.5 },
        knobs = {
            { key = "fReverbMix", label = "Mix", min = -40, max = 0, dec = 0, suffix = "dB" },
            { key = "fReverbTime", label = "Time", min = 100, max = 3000, dec = 0, suffix = "ms" },
            { key = "fHighFreqRTRatio", label = "HF", min = 0.1, max = 0.99, dec = 2 },
            { key = "fInGain", label = "Gain", min = -40, max = 0, dec = 0, suffix = "dB" },
        }
    },
    {
        kind = "echo",
        label = "Echo",
        def = { fWetDryMix = 35, fFeedback = 35, fLeftDelay = 350, fRightDelay = 350, lPanDelay = 0 },
        knobs = {
            { key = "fWetDryMix", label = "Mix", min = 0, max = 100, dec = 0, suffix = "%" },
            { key = "fFeedback", label = "Feedback", min = 0, max = 100, dec = 0, suffix = "%" },
            { key = "fLeftDelay", label = "Left", min = 1, max = 1000, dec = 0, suffix = "ms" },
            { key = "fRightDelay", label = "Right", min = 1, max = 1000, dec = 0, suffix = "ms" },
        }
    },
    {
        kind = "compressor",
        label = "Compressor",
        def = { fGain = 4, fAttack = 10, fRelease = 200, fThreshold = -20, fRatio = 4, fPredelay = 4 },
        knobs = {
            { key = "fThreshold", label = "Threshold", min = -60, max = 0, dec = 0, suffix = "dB" },
            { key = "fRatio", label = "Ratio", min = 1, max = 20, dec = 1, suffix = ":1" },
            { key = "fAttack", label = "Attack", min = 1, max = 200, dec = 0, suffix = "ms" },
            { key = "fRelease", label = "Release", min = 50, max = 2000, dec = 0, suffix = "ms" },
            { key = "fGain", label = "Gain", min = -20, max = 20, dec = 0, suffix = "dB" },
        }
    },
    {
        kind = "chorus",
        label = "Chorus",
        def = { fWetDryMix = 50, fDepth = 25, fFeedback = 25, fFrequency = 0.5, lWaveform = 1, fDelay = 16, lPhase = 2 },
        knobs = {
            { key = "fWetDryMix", label = "Mix", min = 0, max = 100, dec = 0, suffix = "%" },
            { key = "fDepth", label = "Depth", min = 0, max = 100, dec = 0, suffix = "%" },
            { key = "fFeedback", label = "Feedback", min = -99, max = 99, dec = 0, suffix = "%" },
            { key = "fFrequency", label = "Rate", min = 0, max = 10, dec = 1, suffix = "Hz" },
            { key = "fDelay", label = "Delay", min = 0, max = 20, dec = 1, suffix = "ms" },
        }
    },
}

local shared = BATTLEBEATS.uiShared
local LerpColor = shared.LerpColor
local ColA = shared.ColA
local animHover = shared.animHover
local makeSwitch = shared.makeSwitch

local C = shared.Colors
local TL, TC, TR, TT = TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP

local function valueText(v, dec, suffix)
    local s = string.format("%." .. (dec or 0) .. "f", v)
    if not suffix then return s end
    return s .. (suffix == "%" and "" or " ") .. suffix
end

local function arcPos(cx, cy, r, a)
    local rad = math.rad(a)
    return cx + math.sin(rad) * r, cy - math.cos(rad) * r
end

local function buildArc(cx, cy, r, th, a0, a1)
    local polys = {}
    if a1 < a0 then a0, a1 = a1, a0 end
    if a1 - a0 < 0.5 then return polys end
    local steps = math.max(1, math.ceil((a1 - a0) / 15))
    local step = (a1 - a0) / steps
    local ri = r - th
    for i = 0, steps - 1 do
        local s, e = a0 + step * i, a0 + step * (i + 1)
        local ox1, oy1 = arcPos(cx, cy, r, s)
        local ox2, oy2 = arcPos(cx, cy, r, e)
        local ix2, iy2 = arcPos(cx, cy, ri, e)
        local ix1, iy1 = arcPos(cx, cy, ri, s)
        polys[#polys + 1] = {
            { x = ox1, y = oy1 }, { x = ox2, y = oy2 },
            { x = ix2, y = iy2 }, { x = ix1, y = iy1 },
        }
    end
    return polys
end

local function buildPointer(cx, cy, r1, r2, a, hw)
    local rad = math.rad(a)
    local dx, dy = math.sin(rad), -math.cos(rad)
    local px, py = math.cos(rad) * hw, math.sin(rad) * hw
    return {
        { x = cx + dx * r1 - px, y = cy + dy * r1 - py },
        { x = cx + dx * r2 - px, y = cy + dy * r2 - py },
        { x = cx + dx * r2 + px, y = cy + dy * r2 + py },
        { x = cx + dx * r1 + px, y = cy + dy * r1 + py },
    }
end

local function drawPolys(polys, col)
    surface.SetDrawColor(col)
    draw.NoTexture()
    for i = 1, #polys do surface.DrawPoly(polys[i]) end
end

local function makeButton(parent, x, y, w, h, text, onClick, arrow)
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y)
    b:SetSize(w, h)
    b:SetText("")
    b:SetCursor("hand")
    b.Paint = function(self, pw, ph)
        local hov = animHover(self, "Hov", self:IsHovered())
        local bg = self:IsDown() and C.C50 or LerpColor(hov, C.C90, C.C100)
        draw.RoundedBox(10, 0, 0, pw, ph, LerpColor(hov * 0.35, C.Yellow, color_white))
        draw.RoundedBox(9, 1, 1, pw - 2, ph - 2, bg)
        local t = isfunction(text) and text() or text
        draw.SimpleText(t, "DermaDefaultBold", pw / 2 - (arrow and 6 or 0), ph / 2, color_white, TC, TC)
        if arrow then
            local ax, ay = pw - 18, ph / 2
            surface.SetDrawColor(255, 255, 255, 120 + 135 * hov)
            surface.DrawLine(ax - 5, ay - 3, ax, ay + 3)
            surface.DrawLine(ax, ay + 3, ax + 5, ay - 3)
        end
    end
    b.DoClick = function()
        surface.PlaySound("btb_tab_switch.mp3")
        onClick(b)
    end
    return b
end

--MARK: fader

local faderW = 52
local function fader(parent, o)
    local p = vgui.Create("DPanel", parent)
    p:SetSize(faderW, o.h)
    p:SetCursor("sizens")
    p.Value = o.value

    local HH = 9
    local top, bot = 22, o.h - 24

    local function valToY(v)
        return top + HH + (o.max - v) / (o.max - o.min) * (bot - top - 2 * HH)
    end
    local function yToVal(y)
        local t = math.Clamp((y - top - HH) / (bot - top - 2 * HH), 0, 1)
        return o.max - t * (o.max - o.min)
    end
    local function setVal(v)
        local step = input.IsShiftDown() and 0.1 or 0.5
        v = math.Round(math.Clamp(math.Round(v / step) * step, o.min, o.max), 1)
        if v == p.Value then return end
        p.Value = v
        o.onChange(v)
    end

    function p:SetValue(v) self.Value = v end

    p.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        if CurTime() - (self.LastClick or 0) < 0.3 then
            self.LastClick = 0
            setVal(0)
            return
        end
        self.LastClick = CurTime()
        self.Drag = true
        self:MouseCapture(true)
        local _, cy = self:CursorPos()
        setVal(yToVal(cy))
    end
    p.OnMouseReleased = function(self)
        self.Drag = false
        self:MouseCapture(false)
    end
    p.OnMouseWheeled = function(self, d)
        setVal(self.Value + d * (input.IsShiftDown() and 0.1 or 0.5))
    end
    p.Think = function(self)
        if not self.Drag then return end
        if not input.IsMouseDown(MOUSE_LEFT) then
            self.Drag = false
            self:MouseCapture(false)
            return
        end
        local _, cy = self:CursorPos()
        setVal(yToVal(cy))
    end

    p.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered() or self.Drag)
        local cx = w / 2
        local v = self.Value

        for db = o.min, o.max, 5 do
            local y = valToY(db)
            local len = db == 0 and 12 or 6
            surface.SetDrawColor(db == 0 and C.C100 or C.C70)
            surface.DrawLine(cx - 8 - len, y, cx - 8, y)
            surface.DrawLine(cx + 8, y, cx + 8 + len, y)
        end

        draw.RoundedBox(3, cx - 3, top + HH, 6, bot - top - 2 * HH, C.Track)

        local y0, yv = valToY(0), valToY(v)
        local fy = math.min(y0, yv)
        local fh = math.abs(y0 - yv)
        if fh > 0 then
            draw.RoundedBox(2, cx - 3, fy, 6, fh, LerpColor(hov * 0.3, C.Yellow, color_white))
        end

        local hw, hh = 32, HH * 2
        draw.RoundedBox(6, cx - hw / 2, yv - HH + 2, hw, hh, C.Shadow)
        draw.RoundedBox(6, cx - hw / 2, yv - HH, hw, hh, LerpColor(hov * 0.5, C.C50, C.Yellow))
        draw.RoundedBox(5, cx - hw / 2 + 1, yv - HH + 1, hw - 2, hh - 2, LerpColor(hov, C.C90, C.C100))
        surface.SetDrawColor(C.Yellow)
        surface.DrawRect(cx - 10, yv - 1, 20, 2)

        local txt = v == 0 and "0.0" or string.format("%+.1f", v)
        draw.SimpleText(txt, "DermaDefaultBold", cx, 2, v == 0 and C.Dim or C.Yellow, TC, TT)
        draw.SimpleText(o.label, "DermaDefault", cx, h - 4, C.Text, TC, TEXT_ALIGN_BOTTOM)
    end

    return p
end

--MARK: knob

local amin, amax = -135, 135
local knobW = 68
local kr = 24
local kcx, kcy = knobW / 2, 18 + kr
local knobBg = buildArc(kcx, kcy, kr, 4, amin, amax)
local function knob(parent, o)
    local p = vgui.Create("DPanel", parent)
    p:SetSize(knobW, 88)
    p:SetCursor("sizewe")
    p.Value = o.value
    p.Enabled = true

    local minStep = 10 ^ -(o.dec or 0)
    local br = kr - 7
    local origin = amin
    if o.min < 0 and o.max > 0 then
        origin = amin + (-o.min / (o.max - o.min)) * (amax - amin)
    end

    local function setVal(v)
        v = math.Clamp(math.Round(v, o.dec or 0), o.min, o.max)
        if v == p.Value then return end
        p.Value = v
        o.onChange(v)
    end

    p.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        if CurTime() - (self.LastClick or 0) < 0.3 then
            self.LastClick = 0
            setVal(o.def)
            return
        end
        self.LastClick = CurTime()
        self.Drag = true
        self.DragX = gui.MouseX()
        self.DragVal = self.Value
        self:MouseCapture(true)
    end
    p.OnMouseReleased = function(self)
        self.Drag = false
        self:MouseCapture(false)
    end
    p.OnMouseWheeled = function(self, d)
        local step = math.max((o.max - o.min) / (input.IsShiftDown() and 500 or 100), minStep)
        setVal(self.Value + d * step)
    end
    p.Think = function(self)
        if not self.Drag then return end
        if not input.IsMouseDown(MOUSE_LEFT) then
            self.Drag = false
            self:MouseCapture(false)
            return
        end
        local px = input.IsShiftDown() and 600 or 150
        setVal(self.DragVal + (gui.MouseX() - self.DragX) / px * (o.max - o.min))
    end

    p.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered() or self.Drag)
        self.En = Lerp(FrameTime() * 10, self.En or 1, self.Enabled and 1 or 0)
        local k = Lerp(self.En, 0.4, 1)

        if self.cacheVal ~= self.Value then
            self.cacheVal = self.Value
            local ang = amin + (self.Value - o.min) / (o.max - o.min) * (amax - amin)
            self.valArc = buildArc(kcx, kcy, kr, 4, origin, ang)
            self.ptr = { buildPointer(kcx, kcy, br * 0.3, br * 0.9, ang, 1.5) }
        end

        draw.SimpleText(o.label, "DermaDefaultBold", kcx, 0, ColA(C.Text, 255 * k), TC, TT)

        drawPolys(knobBg, ColA(C.C70, 255 * k))
        drawPolys(self.valArc, ColA(LerpColor(hov * 0.3, C.Yellow, color_white), 255 * k))

        draw.RoundedBox(br, kcx - br, kcy - br + 1, br * 2, br * 2, ColA(C.Shadow, C.Shadow.a * k))
        draw.RoundedBox(br, kcx - br, kcy - br, br * 2, br * 2, ColA(LerpColor(hov, C.C90, C.C100), 255 * k))
        drawPolys(self.ptr, ColA(C.Yellow, 255 * k))

        draw.SimpleText(valueText(self.Value, o.dec, o.suffix), "DermaDefaultBold", kcx, kcy + kr + 6,
            ColA(hov > 0.5 and C.Yellow or C.Text, 255 * k), TC, TT)
    end
    return p
end

local frame
local presetLabel = cookie.GetString("btb_bassfx_preset", "flat")
local function setPresetLabel(name)
    if presetLabel == name then return end
    presetLabel = name
    cookie.Set("btb_bassfx_preset", name)
end

local function eqMatches(name)
    local gains = BassFX.EQPresets[name]
    if not gains then return false end
    for i = 1, 8 do
        if math.abs((gains[i] or 0) - (BassFX.Profile.eq[i] or 0)) > 0.05 then return false end
    end
    return true
end

local function isOn()
    return BassFX.installed and BassFX.Profile.enabled
end
--MARK: main frame
function BassFX.OpenMenu(px, py)
    if IsValid(frame) then frame:Remove() end
    local unavailable = not BassFX.installed

    local fw, fh = 960, 600
    local head = 44
    frame = vgui.Create("DFrame")
    local f = frame
    f:SetSize(fw, fh)
    f:Center()
    if px and py then f:SetPos(px, py) end
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetAlpha(0)
    f:AlphaTo(255, 0.15, 0)
    f.isMinimalized = false

    f.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, C.Bg)
        surface.SetDrawColor(C.Yellow)
        surface.DrawRect(0, head - 1, w, 1)
        draw.SimpleText("BassFX", "Trebuchet24", 30, head / 2 - 5, C.Yellow, TL, TC)
        draw.SimpleText("BattleBeats", "HudSelectionText", 18, head / 2 + 8, C.Yellow, TL, TC)
        local on = isOn()
        draw.SimpleText(unavailable and "Unavailable" or (on and "Enabled" or "Disabled"), "DermaDefaultBold", 178, head / 2 - 1, on and color_white or C.Dim, TL, TC)
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, C.Yellow)
    end

    f:BTB_SetButtons(true, -5, 6, true)
    f.btnClose.DoClick = function()
        f:AlphaTo(0, 0.1, 0, function() if IsValid(f) then f:Remove() end end)
    end
    f.btnMinim.DoClick = function()
        f:SetVisible(false)
        f.isMinimalized = true
    end

    local faders = {}
    if BassFX.EQPresets[presetLabel] and not eqMatches(presetLabel) then
        setPresetLabel("Custom")
    end

    makeSwitch(f, 120, 12, function() return BassFX.Profile.enabled end, function(v) if unavailable then return end BassFX.SetEnabled(v) end)
    makeButton(f, fw - 38 - 8 - 90 - 70, 8, 90, 28, "Reset", function()
        if unavailable then return end
        local x, y = f:GetPos()
        BassFX.SetEQ(BassFX.EQPresets.flat)
        for _, e in ipairs(effects) do BassFX.ClearEffect(e.kind) end
        setPresetLabel("flat")
        BassFX.OpenMenu(x, y)
    end)

    local names = table.GetKeys(BassFX.EQPresets)
    table.sort(names)

    local function applyPreset(name)
        local gains = BassFX.EQPresets[name]
        if not gains then return end
        BassFX.SetEQ(gains)
        for i, fd in ipairs(faders) do fd:SetValue(gains[i] or 0) end
        setPresetLabel(name)
    end

    makeButton(f, fw - 38 - 8 - 90 - 8 - 200 - 70, 8, 200, 28, function() return presetLabel end, function(btn)
        if unavailable then return end
        local m = DermaMenu()
        m:SetMaxHeight(320)
        m:SetMinimumWidth(btn:GetWide())
        m.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, C.C50) end
        for _, n in ipairs(names) do
            local opt = m:AddOption(n, function() applyPreset(n) end)
            opt:SetFont("DermaDefaultBold")
            opt.Paint = function(s, w, h)
                s:SetTextColor(color_white)
                local hv = animHover(s, "Hov", s:IsHovered())
                draw.RoundedBox(4, 0, 0, w, h, LerpColor(hv, C.C50, C.C100))
                draw.RoundedBox(2, 0, h / 2 - 8 * hv, 3, 16 * hv, C.Yellow)
            end
        end
        local x, y = btn:LocalToScreen(0, btn:GetTall() + 2)
        m:Open(x, y, false, btn)
    end, true)

    local content = vgui.Create("DPanel", f)
    content:SetPos(0, head)
    content:SetSize(fw, fh - head)
    content.Paint = nil
    content.PaintOver = function(self, w, h)
        self.Off = Lerp(FrameTime() * 8, self.Off or 0, isOn() and 0 or 1)
        if self.Off < 0.01 then return end
        draw.RoundedBoxEx(12, 0, 0, w, h, ColA(C.Off, C.Off.a * self.Off), false, false, true, true)

        if unavailable then
            draw.SimpleText("Work In Progress", "Trebuchet24", w / 2, h / 2 - 22, Color(255, 100, 100), TC, TC)
            --draw.SimpleText("BassFX module unavailable", "Trebuchet24", w / 2, h / 2 - 22, Color(255, 100, 100), TC, TC)
            --draw.SimpleText("gmcl_bassfx_win64.dll or lua/autorun/client/bass.lua is missing", "DermaDefault", w / 2, h / 2 + 8, color_white, TC, TC)
        end
    end

    local ch = fh - head - 12
    local left = vgui.Create("DPanel", content)
    left:SetPos(12, 8)
    left:SetSize(440, ch - 8)
    left.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.Card)
        draw.SimpleText("EQUALIZER", "DermaDefaultBold", 16, 10, color_white, TL, TT)
        draw.SimpleText("dB", "DermaDefault", w - 16, 10, C.Dim, TR, TT)
    end

    local CURVE_H = 96
    local curve = vgui.Create("DPanel", left)
    curve:SetPos(12, 32)
    curve:SetSize(faderW * 8, CURVE_H)

    local function curveY(v, h)
        return 8 + (15 - v) / 30 * (h - 16)
    end
    local function curveVal(x)
        local pos = math.Clamp(x / faderW + 0.5, 1, 8)
        local i0 = math.floor(pos)
        local i1 = math.min(i0 + 1, 8)
        local fr = pos - i0
        fr = (1 - math.cos(fr * math.pi)) / 2
        local a = faders[i0] and faders[i0].Value or 0
        local b = faders[i1] and faders[i1].Value or 0
        return Lerp(fr, a, b)
    end

    local cStep = 4
    local curveVals, curveYs = {}, {}
    curve.Paint = function(_, w, h)
        local dirty = false
        for i = 1, 8 do
            local v = faders[i] and faders[i].Value or 0
            if curveVals[i] ~= v then
                curveVals[i] = v
                dirty = true
            end
        end
        if dirty then
            local n = 0
            for x = 6, w - 6, cStep do
                n = n + 1
                curveYs[n] = curveY(curveVal(x), h)
            end
        end
        draw.RoundedBox(8, 0, 0, w, h, C.CardIn)
        local y0 = curveY(0, h)
        surface.SetDrawColor(C.C90)
        surface.DrawLine(6, y0, w - 6, y0)
        surface.SetDrawColor(C.C70)
        surface.DrawLine(6, curveY(7.5, h), w - 6, curveY(7.5, h))
        surface.DrawLine(6, curveY(-7.5, h), w - 6, curveY(-7.5, h))
        surface.SetDrawColor(255, 210, 0, 18)
        local n = 0
        for x = 6, w - 6, cStep do
            n = n + 1
            local y = curveYs[n]
            surface.DrawRect(x, math.min(y0, y), cStep, math.abs(y0 - y))
        end
        surface.SetDrawColor(C.Yellow)
        for i = 2, n do
            local x = 6 + (i - 2) * cStep
            surface.DrawLine(x, curveYs[i - 1], x + cStep, curveYs[i])
            surface.DrawLine(x, curveYs[i - 1] + 1, x + cStep, curveYs[i] + 1)
        end
        for i = 1, 8 do
            local y = curveY(curveVals[i], h)
            draw.RoundedBox(3, (i - 0.5) * faderW - 3, y - 2, 6, 6, color_white)
        end
    end

    for i, label in ipairs(bLabel) do
        local fd = fader(left, {
            label = label,
            min = -15,
            max = 15,
            h = 380,
            value = BassFX.Profile.eq[i] or 0,
            onChange = function(v)
                BassFX.SetBand(i, v)
                setPresetLabel("Custom")
            end,
        })
        fd:SetPos(12 + (i - 1) * faderW, 32 + CURVE_H + 8)
        faders[i] = fd
    end

    local right = vgui.Create("DPanel", content)
    right:SetPos(464, 8)
    right:SetSize(fw - 464 - 12, ch - 8)
    right.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.Card)
        draw.SimpleText("EFFECTS", "DermaDefaultBold", 16, 10, color_white, TL, TT)
    end

    local rowh = 112
    for idx, e in ipairs(effects) do
        local saved = BassFX.Profile.fx[e.kind]
        local params = table.Copy(e.def)
        if saved then
            for k, v in pairs(saved) do params[k] = v end
        end
        local on = saved ~= nil

        local row = vgui.Create("DPanel", right)
        row:SetPos(12, 34 + (idx - 1) * (rowh + 10))
        row:SetSize(right:GetWide() - 24, rowh)
        row.Anim = on and 1 or 0

        local knobs = {}

        local function push()
            if on then BassFX.SetEffect(e.kind, table.Copy(params)) end
        end

        row.Paint = function(self, w, h)
            self.Anim = Lerp(FrameTime() * 10, self.Anim, on and 1 or 0)
            draw.RoundedBox(8, 0, 0, w, h, C.CardIn)
            draw.RoundedBoxEx(8, 0, 0, 4, h, ColA(C.Yellow, 255 * self.Anim), true, false, true, false)
            draw.SimpleText(e.label, "DermaDefaultBold", 16, 50,
                LerpColor(self.Anim, C.Dim, color_white), TL, TT)
        end

        makeSwitch(row, 16, 24, function() return on end, function(v)
            on = v
            for _, kn in ipairs(knobs) do kn.Enabled = on end
            if on then
                BassFX.SetEffect(e.kind, table.Copy(params))
            else
                BassFX.ClearEffect(e.kind)
            end
        end)

        for j, kd in ipairs(e.knobs) do
            local kn = knob(row, {
                label = kd.label,
                min = kd.min,
                max = kd.max,
                dec = kd.dec,
                suffix = kd.suffix,
                def = e.def[kd.key],
                value = params[kd.key],
                onChange = function(v)
                    params[kd.key] = v
                    push()
                end,
            })
            kn:SetPos(106 + (j - 1) * knobW, 12)
            kn.Enabled = on
            knobs[j] = kn
        end
    end

    local hint = vgui.Create("DLabel", right)
    hint:SetPos(0, right:GetTall() - 20)
    hint:SetSize(right:GetWide(), 18)
    hint:SetText("Double-click: reset  |  Mouse wheel: adjust  |  Shift: fine control")
    hint:SetTextColor(Color(90, 90, 90))
    hint:SetContentAlignment(5)

    if unavailable then
        local blocker = vgui.Create("DPanel", content)
        blocker:SetPos(0, 0)
        blocker:SetSize(fw, fh - head)
        blocker.Paint = nil
        blocker:SetMouseInputEnabled(true)
        blocker:SetCursor("no")
        blocker:MoveToFront()
        blocker.OnMouseWheeled = function() return true end
    end
end

hook.Add("VGUIMousePressed", "BattleBeats_BassFX_KeepFront", function(pnl, code)
    if not IsValid(frame) or not frame:IsVisible() then return end
    if not (IsValid(g_ContextMenu) and g_ContextMenu:IsVisible()) then return end
    if pnl ~= g_ContextMenu then return end
    timer.Simple(0, function()
        if IsValid(frame) and frame:IsVisible() then
            frame:MoveToFront()
        end
    end)
end)

hook.Add("OnContextMenuOpen", "BattleBeats_BassFX_OpenUI", function()
    if IsValid(frame) and not frame.isMinimalized then
        frame:SetVisible(true)
    end
end)

hook.Add("OnContextMenuClose", "BattleBeats_BassFX_HideUI", function()
    if IsValid(frame) then
        frame:SetVisible(false)
    end
end)

if BassFX.installed then
    list.Set("DesktopWindows", "BattleBeats_BassFX_ContextMenu", {
        title = "Equalizer",
        icon = "packicons/btb.png",
        init = function()
            if IsValid(frame) and not frame:IsVisible() then
                frame:SetVisible(true)
                frame.isMinimalized = false
            end
            if not IsValid(frame) then BassFX.OpenMenu() end
        end
    })
end

concommand.Add("battlebeats_equalizer_menu", function()
    if IsValid(frame) and not frame:IsVisible() then
        frame:SetVisible(true)
        frame.isMinimalized = false
    end
    if not IsValid(frame) then BassFX.OpenMenu() end
end)
