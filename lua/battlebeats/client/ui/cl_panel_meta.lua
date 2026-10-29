local defColor = Color(255, 210, 0)
local btb = BATTLEBEATS

local DrawRect, SetDrawColor = surface.DrawRect, surface.SetDrawColor
local sqrt, floor = math.sqrt, math.floor

local cache = {}
local function buildCorner(R, t)
    local inner = R - t
    local rows = {}

    for j = 0, R - 1 do
        local dy = R - j - 0.5
        local i0, len
        for i = 0, R - 1 do
            local dx = R - i - 0.5
            local d = sqrt(dx * dx + dy * dy)
            if d >= inner and d < R then
                if not i0 then i0, len = i, 1 else len = len + 1 end
            elseif i0 then
                rows[#rows + 1] = { i0, j, len, 1 }
                i0 = nil
            end
        end
        if i0 then rows[#rows + 1] = { i0, j, len, 1 } end
    end

    local out = {}
    for _, r in ipairs(rows) do
        local merged = false
        for _, o in ipairs(out) do
            if o[1] == r[1] and o[3] == r[3] and o[2] + o[4] == r[2] then
                o[4] = o[4] + 1
                merged = true
                break
            end
        end
        if not merged then out[#out + 1] = r end
    end
    return out
end

function btb.drawRoundedOutline(radius, x, y, w, h, thickness, col)
    local half = (w < h and w or h) * 0.5
    if radius > half then radius = half end

    local R = floor(radius + 0.5)
    local t = floor(thickness + 0.5)
    if t < 1 then t = 1 end

    local r = col.r
    if r then
        SetDrawColor(r, col.g, col.b, col.a or 255)
    else
        SetDrawColor(col[1], col[2], col[3], col[4] or 255)
    end

    if R < 1 then
        DrawRect(x, y, w, t)
        DrawRect(x, y + h - t, w, t)
        DrawRect(x, y + t, t, h - t * 2)
        DrawRect(x + w - t, y + t, t, h - t * 2)
        return
    end

    local sw, sh = w - R * 2, h - R * 2
    DrawRect(x + R, y, sw, t)
    DrawRect(x + R, y + h - t, sw, t)
    DrawRect(x, y + R, t, sh)
    DrawRect(x + w - t, y + R, t, sh)

    local key = R * 1024 + t
    local rects = cache[key]
    if not rects then
        rects = buildCorner(R, t)
        cache[key] = rects
    end

    local rx, by = x + w - R, y + h - R
    for i = 1, #rects do
        local rc = rects[i]
        local ci, cj, cw, ch = rc[1], rc[2], rc[3], rc[4]
        local mx = R - ci - cw
        local my = R - cj - ch
        DrawRect(x + ci, y + cj, cw, ch)
        DrawRect(rx + mx, y + cj, cw, ch)
        DrawRect(x + ci, by + my, cw, ch)
        DrawRect(rx + mx, by + my, cw, ch)
    end
end

local function parseSegmentColor(segmentText)
    local textPart, r, g, b = string.match(segmentText, "^(.-)<(%d+),(%d+),(%d+)>$")
    if textPart then
        return textPart, Color(math.Clamp(tonumber(r) or 255, 0, 255), math.Clamp(tonumber(g) or 210, 0, 255), math.Clamp(tonumber(b) or 0, 0, 255))
    end
    return segmentText, defColor
end

local function addSegment(line, segmentText, mode)
    if not segmentText or segmentText == "" then return end
    local color = color_white
    if mode and mode > 0 then
        segmentText, color = parseSegmentColor(segmentText)
    end
    table.insert(line, {
        text = segmentText,
        mode = mode or 0,
        color = color
    })
end

local function setText(self, text)
    text = text or ""
    if string.StartWith(text, "#") then
        text = language.GetPhrase(string.sub(text, 2))
    end
    self.rText = text
    self.lines = {}
    local cleanText = string.gsub(self.rText, "\\n", "\n")
    for rawLine in string.gmatch(cleanText .. "\n", "(.-)\n") do
        local line = {}
        local pos = 1

        while pos <= #rawLine do
            local doubleStart = string.find(rawLine, "||", pos, true)
            local singleStart = string.find(rawLine, "|", pos, true)

            if not singleStart then
                addSegment(line, string.sub(rawLine, pos), 0)
                break
            end
            if doubleStart and doubleStart == singleStart then
                addSegment(line, string.sub(rawLine, pos, doubleStart - 1), 0)
                local doubleEnd = string.find(rawLine, "||", doubleStart + 2, true)
                if not doubleEnd then
                    addSegment(line, string.sub(rawLine, doubleStart), 0)
                    break
                end
                addSegment(line, string.sub(rawLine, doubleStart + 2, doubleEnd - 1), 2)
                pos = doubleEnd + 2
            else
                addSegment(line, string.sub(rawLine, pos, singleStart - 1), 0)
                local singleEnd = string.find(rawLine, "|", singleStart + 1, true)
                if not singleEnd then
                    addSegment(line, string.sub(rawLine, singleStart), 0)
                    break
                end
                addSegment(line, string.sub(rawLine, singleStart + 1, singleEnd - 1), 1)
                pos = singleEnd + 1
            end
        end
        table.insert(self.lines, line)
    end
    self:InvalidateLayout()
end

local function perfLayout(self)
    surface.SetFont("HudHintTextLarge")
    local maxW = 0
    local totalH = 0
    local lineGap = 2
    for _, line in ipairs(self.lines or {}) do
        local lineW = 0
        local lineH = 0
        for _, segment in ipairs(line) do
            local tw, th = surface.GetTextSize(segment.text)
            lineW = lineW + tw
            lineH = math.max(lineH, th)
        end
        maxW = math.max(maxW, lineW)
        totalH = totalH + lineH + lineGap
    end
    if totalH > 0 then
        totalH = totalH - lineGap
    end
    self:SetSize(maxW + 20, totalH + 14)
end

local function drawText(self, w, y, lineGap)
    for _, line in ipairs(self.lines or {}) do
        local lineW = 0
        local lineH = 0
        for _, segment in ipairs(line) do
            local tw, th = surface.GetTextSize(segment.text)
            lineW = lineW + tw
            lineH = math.max(lineH, th)
        end
        local x = (w - lineW) / 2
        for _, segment in ipairs(line) do
            local tw, th = surface.GetTextSize(segment.text)
            local segColor = segment.color or defColor
            if segment.mode == 2 then
                draw.RoundedBox(6, x - 2, y + lineH / 2 - th / 2 - 1, tw + 4, th + 2, Color(segColor.r - 30, segColor.g - 30, segColor.b - 30, 30))
                draw.SimpleText(segment.text, "HudHintTextLarge", x, y + lineH / 2, Color(segColor.r, segColor.g, segColor.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            elseif segment.mode == 1 then
                draw.SimpleText(segment.text, "HudHintTextLarge", x, y + lineH / 2, Color(segColor.r, segColor.g, segColor.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(segment.text, "HudHintTextLarge", x, y + lineH / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            x = x + tw
        end
        y = y + lineH + lineGap
    end
end

local tooltipPanel = {}
function tooltipPanel:SetText(text)
    setText(self, text)
end
function tooltipPanel:PerformLayout()
    perfLayout(self)
end
function tooltipPanel:Paint(w, h)
    draw.RoundedBox(10, 0, 0, w, h, defColor)
    draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
    surface.SetFont("HudHintTextLarge")
    local y = 7
    local lineGap = 2
    drawText(self, w, y, lineGap)
end
function tooltipPanel:Think()
    local mx, my = gui.MousePos()
    if not mx or mx == 0 then return end
    self:SetPos(mx - self:GetWide() / 2, my - self:GetTall() - 12)
end
vgui.Register("BattleBeatsTooltip", tooltipPanel, "DTooltip")

local tooltipTextOnly = {}
function tooltipTextOnly:SetMaxWidth(w)
    self.maxWidth = w or 330
    self:InvalidateLayout()
end
function tooltipTextOnly:SetText(text)
    setText(self, text)
end
function tooltipTextOnly:PerformLayout()
    perfLayout(self)
end
function tooltipTextOnly:Paint(w, h)
    surface.SetFont("HudHintTextLarge")
    local y = 0
    local lineGap = 2
    drawText(self, w, y, lineGap)
end
vgui.Register("BattleBeatsTooltipTextOnly", tooltipTextOnly, "DPanel")

local tooltipDelay = GetConVar("tooltip_delay"):GetFloat()
local PANEL = FindMetaTable("Panel")
function PANEL:BTB_SetImageTooltip(imagePath, text, width, maxImageHeight)
    width = width or 350
    maxImageHeight = maxImageHeight or 400
    self:SetMouseInputEnabled(true)
    local imgtooltipPanel = nil
    local timerID = "BTB_ImageTooltip_" .. tostring(self)
    self.OnCursorEntered = function()
        timer.Remove(timerID)
        timer.Create(timerID, tooltipDelay, 1, function()
            if IsValid(imgtooltipPanel) then
                imgtooltipPanel:Remove()
            end

            imgtooltipPanel = vgui.Create("DPanel")
            imgtooltipPanel:SetAlpha(0)
            imgtooltipPanel:MakePopup()
            imgtooltipPanel.Think = function(self)
                local mx, my = gui.MousePos()
                if not mx or mx == 0 then return end
                self:SetPos(mx - self:GetWide() / 2, my - self:GetTall() - 12)
            end
            imgtooltipPanel.Paint = function(self, w, h)
                draw.RoundedBox(10, 0, 0, w, h, defColor)
                draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
            end

            local baseWidth = width
            local padding = 20
            local textW = 0
            local textPanel = nil

            if text and text ~= "" then
                textPanel = vgui.Create("BattleBeatsTooltipTextOnly", imgtooltipPanel)
                textPanel:SetText(text)
                textPanel:InvalidateLayout(true)

                textW = textPanel.textW or textPanel:GetWide()
            end

            local finalWidth = math.max(baseWidth, textW + padding)
            finalWidth = math.min(finalWidth, ScrW() - 40)

            local img = vgui.Create("DImage", imgtooltipPanel)
            img:SetPos(10, 10)
            img:SetImage(imagePath)
            img:SetKeepAspect(true)

            local mat = Material(imagePath, "noclamp smooth")
            local realW, realH = mat:Width(), mat:Height()
            local targetW = finalWidth - 20
            local newImgH = maxImageHeight

            if realW > 0 and realH > 0 then
                local scale = targetW / realW
                newImgH = realH * scale
                if newImgH > maxImageHeight then
                    newImgH = maxImageHeight
                    targetW = realW * (maxImageHeight / realH)
                end
            end

            img:SetSize(targetW, newImgH)
            img:SetPos((finalWidth - targetW) / 2, 10)
            local imageBottom = 10 + newImgH + 5
            if IsValid(textPanel) then
                textPanel:SetPos((finalWidth - textPanel:GetWide()) / 2, imageBottom)
                local totalH = imageBottom + textPanel:GetTall() - 5
                imgtooltipPanel:SetSize(finalWidth, totalH)
            else
                imgtooltipPanel:SetSize(finalWidth, imageBottom)
            end
            imgtooltipPanel:SetAlpha(255)
        end)
    end

    self.OnCursorExited = function()
        timer.Remove(timerID)
        if IsValid(imgtooltipPanel) then
            imgtooltipPanel:Remove()
            imgtooltipPanel = nil
        end
    end
end

--MARK:UI SHARED
btb.uiShared = btb.uiShared or {}

local C = {
    Yellow = Color(255, 210, 0),
    Bg = Color(20, 20, 20, 215),
    Card = Color(45, 45, 45),
    CardIn = Color(56, 56, 56),
    C40 = Color(40, 40, 40),
    C50 = Color(50, 50, 50),
    C70 = Color(70, 70, 70),
    C90 = Color(90, 90, 90),
    C100 = Color(100, 100, 100),
    C200 = Color(200, 200, 200),
    Track = Color(22, 22, 22),
    Text = Color(230, 230, 230),
    Dim = Color(140, 140, 140),
    Good = Color(120, 210, 120),
    Warn = Color(255, 110, 110),
    Cut = Color(110, 170, 255),
    Missing = Color(80, 38, 38),
    MissingHov = Color(110, 48, 48),
    Select = Color(255, 210, 0, 90),
    Start = Color(100, 255, 100),
    End = Color(255, 100, 100),
    Shadow = Color(0, 0, 0, 70),
    Ambient = Color(120, 210, 120),
    Combat = Color(230, 120, 120),
    Off = Color(0, 0, 0, 200),
    Outline = Color(0, 0, 0, 120)
}
local TL, TC, TR, TT = TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP

local function LerpColor(t, from, to)
    return Color(
        Lerp(t, from.r, to.r),
        Lerp(t, from.g, to.g),
        Lerp(t, from.b, to.b),
        Lerp(t, from.a or 255, to.a or 255)
    )
end

local function ColA(col, a)
    return Color(col.r, col.g, col.b, a)
end

local function animHover(self, key, active, speed)
    self[key] = Lerp(FrameTime() * (speed or 12), self[key] or 0, active and 1 or 0)
    return self[key]
end

local blur = Material("pp/blurscreen")
local function drawBlur(panel, amount)
    local x, y = panel:LocalToScreen(0, 0)
    surface.SetMaterial(blur)
    surface.SetDrawColor(255, 255, 255)
    for i = 1, 3 do
        blur:SetFloat("$blur", (i / 3) * (amount or 6))
        blur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

local function makeSwitch(parent, x, y, getState, onClick)
    local sw = vgui.Create("DPanel", parent)
    sw:SetPos(x, y)
    sw:SetSize(40, 20)
    sw:SetCursor("hand")
    sw.Anim = getState() and 1 or 0

    sw.Paint = function(self, w, h)
        local target = getState() and 1 or 0
        self.Anim = Lerp(FrameTime() * 10, self.Anim, target)
        if math.abs(self.Anim - target) < 0.002 then self.Anim = target end
        local t = self.Anim

        local hov = animHover(self, "Hov", self:IsHovered())
        local ks = 16 + hov * 2
        local knobX = Lerp(t, 2, w - ks - 2)
        local knobY = (h - ks) / 2

        local track = LerpColor(t, C.C90, C.Yellow)
        draw.RoundedBox(h / 2, 0, 0, w, h, LerpColor(hov * 0.3, track, color_white))
        draw.RoundedBox(ks / 2, knobX, knobY + 1, ks, ks, C.Shadow)
        draw.RoundedBox(ks / 2, knobX, knobY, ks, ks, LerpColor(t, C.Text, C.C90))
    end

    sw.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        local new = not getState()
        surface.PlaySound(new and "btb_switch_on.mp3" or "btb_switch_off.mp3")
        onClick(new)
    end

    return sw
end

local function makeSearch(parent, x, y, w, h, placeholder, onChange, font)
    local e = vgui.Create("DTextEntry", parent)
    if x and y and w and h then
        e:SetPos(x, y)
        e:SetSize(w, h)
    else
        e:Dock(FILL)
    end
    e:SetFont(font or "BattleBeats_Font")
    e.OnChange = function(self) onChange(self:GetValue()) end
    e.Paint = function(self, pw, ph)
        local f = animHover(self, "Foc", self:HasFocus())
        draw.RoundedBox(8, 0, 0, pw, ph, LerpColor(f, C.C70, C.Yellow))
        draw.RoundedBox(7, 1, 1, pw - 2, ph - 2, C.C50)
        self:DrawTextEntryText(color_white, C.Yellow, color_white)
        if self:GetText() == "" and not self:HasFocus() then
            draw.SimpleText(placeholder, font or "BattleBeats_Font", 8, ph / 2, C.Dim, TL, TC)
        end
    end
    return e
end

local function makeScroll(parent)
    local s = vgui.Create("DScrollPanel", parent)
    local vbar = s:GetVBar()
    vbar:SetWide(6)
    vbar:SetHideButtons(true)
    vbar.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, C.Track) end
    vbar.btnGrip.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered() or self.Depressed)
        draw.RoundedBox(3, 0, 0, w, h, LerpColor(hov, C.C100, C.Yellow))
    end
    return s
end

btb.uiShared = {
    Colors = C,
    ColA = ColA,
    LerpColor = LerpColor,
    animHover = animHover,
    drawBlur = drawBlur,
    makeSwitch = makeSwitch,
    makeSearch = makeSearch,
    makeScroll = makeScroll
}

local c1003030200 = Color(100, 30, 30, 200)
local c602020200 = Color(60, 20, 20, 200)
local c707070200 = Color(70, 70, 70, 200)
local c404040200 = Color(40, 40, 40, 200)
function PANEL:BTB_SetButtons(showMin, cX, cY, noSound)
    cX = cX or 0
    cY = cY or 0
    self.PerformLayout = function(self)
        self.btnClose:SetPos(self:GetWide() - 31 - 4 + cX, 5 + cY)
        self.btnClose:SetSize(31, 20)
        self.btnMaxim:SetPos(self:GetWide() - 31 * 2 - 4 + cX, 5 + cY)
        self.btnMaxim:SetSize(31, 20)
        self.btnMinim:SetPos(self:GetWide() - 31 * 3 - 4 + cX, 5 + cY)
        self.btnMinim:SetSize(31, 20)
    end
    if not showMin then
        self.btnMinim:SetCursor("arrow")
        self.btnMinim.Paint = function(self, w, h)
            draw.RoundedBoxEx(4, 0, 0, w, h, Color(30, 30, 30, 200), true, false, true, false)
            surface.SetDrawColor(100, 100, 100, 200)
            surface.DrawRect(w * 0.25, h * 0.65, w * 0.5, 2)
        end
    else
        self.btnMinim:SetEnabled(true)
        self.btnMinim.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and c707070200 or c404040200
            draw.RoundedBoxEx(4, 0, 0, w, h, bgColor, true, false, true, false)
            surface.SetDrawColor(255, 255, 255, 200)
            surface.DrawRect(w * 0.25, h * 0.65, w * 0.5, 2)
        end
    end
    self.btnMaxim:SetCursor("arrow")
    self.btnMaxim.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(30, 30, 30, 200))
        surface.SetDrawColor(100, 100, 100, 200)
        surface.DrawOutlinedRect(w * 0.25, h * 0.35, w * 0.5, h * 0.4)
    end
    self.btnClose.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and c1003030200 or c602020200
        draw.RoundedBoxEx(4, 0, 0, w, h, bgColor, false, true, false, true)
        surface.SetDrawColor(255, 255, 255, 200)
        surface.DrawLine(8, 5, w - 8, h - 5)
        surface.DrawLine(w - 8, 5, 8, h - 5)
    end
    local oldDoClick = self.btnClose.DoClick
    self.btnClose.DoClick = function(s, ...)
        if not noSound then
            surface.PlaySound("btb_button_exit.mp3")
        end
        if oldDoClick then
            oldDoClick(s, ...)
        end
    end
end

local c202020215 = Color(20, 20, 20, 215)
local c505050 = Color(50, 50, 50)
function PANEL:BTB_PaintProperties()
    self:SetFont("ChatFont")
    self:SetTextColor(color_white)
    self:InvalidateLayout(true)
    self.Paint = function(self, w, h)
        local color = self:IsHovered() and c202020215 or c505050
        draw.RoundedBox(12, 2, 2, w - 4, h - 4, color)
    end
end

local hoveringButtons = {}
hook.Add("Think", "BTB_UniversalButtonHoverLerp", function()
    local ft = FrameTime() * 12
    for btn in pairs(hoveringButtons) do
        if not IsValid(btn) then
            hoveringButtons[btn] = nil
            continue
        end
        btn.currentColor = LerpColor(ft, btn.currentColor, btn.targetColor)
        if btn.currentColor == btn.targetColor then
            hoveringButtons[btn] = nil
        end
    end
end)

function PANEL:BTB_SetButton(outline, normalCol, hoverCol, noHover)
    self.currentColor = normalCol
    if not noHover then
        self.normalColor = normalCol
        self.hoverColor = hoverCol
        self.targetColor = normalCol
        local oldEnter = self.OnCursorEntered
        local oldExit = self.OnCursorExited
        self.OnCursorEntered = function(s, ...)
            s.targetColor = s.hoverColor
            hoveringButtons[s] = true
            if oldEnter then
                oldEnter(s, ...)
            end
        end
        self.OnCursorExited  = function(s, ...)
            s.targetColor = s.normalColor
            hoveringButtons[s] = true
            if oldExit then
                oldExit(s, ...)
            end
        end
    end
    self.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, outline)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, s.currentColor)
    end
end

local c2552100 = Color(255, 210, 0)
local c25500 = Color(255, 0, 0)
local c303030 = Color(30, 30, 30)
function PANEL:BTB_UpdatePackButton(btn, state)
    local col

    if state == "enabled" then
        col = c2552100
        btn.packText = "#btb.ps.pack_enabled"
    elseif state == "disabled" then
        col = c25500
        btn.packText = "#btb.ps.pack_disabled"
    elseif state == "debug" then
        col = c303030
        btn.packText = "N/A"
    end

    if not col then return end

    btn.normalColor = col
    btn.hoverColor = Color(col.r + 50, col.g + 50, col.b + 50)
    btn.targetColor = col
    hoveringButtons[btn] = true
end

function PANEL:BTB_SetPackButton(normalCol, hoverCol)
    self.currentColor = normalCol
    self.normalColor = normalCol
    self.hoverColor = hoverCol
    self.targetColor = normalCol
    local oldEnter = self.OnCursorEntered
    local oldExit = self.OnCursorExited
    self.OnCursorEntered = function(s, ...)
        s.targetColor = s.hoverColor
        hoveringButtons[s] = true
        if oldEnter then
            oldEnter(s, ...)
        end
    end
    self.OnCursorExited  = function(s, ...)
        s.targetColor = s.normalColor
        hoveringButtons[s] = true
        if oldExit then
            oldExit(s, ...)
        end
    end
    self.Paint = function(s, w, h)
        draw.RoundedBox(16, 0, 0, w, h, s.currentColor)
        if s.packText then
            draw.SimpleTextOutlined(language.GetPhrase(s.packText), "BattleBeats_Checkbox_Font", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
        end
    end
end

function PANEL:BTB_SetTitle(title, isCentered)
    local frameTitle = vgui.Create("DLabel", self)
    if isCentered then
        frameTitle:SetPos((self:GetWide() / 2) - 150, 5)
    else
        frameTitle:SetPos(10, 5)
    end
    frameTitle:SetSize(300, 20)
    frameTitle:SetText(title)
    frameTitle:SetContentAlignment(isCentered and 5 or 4)
    frameTitle:SetFont("DermaDefaultBold")
    frameTitle:SetTextColor(color_white)
    return frameTitle
end

function PANEL:BTB_SetTitleBig(title, isCentered)
    local frameTitle = vgui.Create("DLabel", self)
    if isCentered then
        frameTitle:SetPos((self:GetWide() / 2) - 250, 10)
    else
        frameTitle:SetPos(10, 10)
    end
    frameTitle:SetSize(500, 20)
    frameTitle:SetText(title)
    frameTitle:SetContentAlignment(isCentered and 5 or 4)
    frameTitle:SetFont("Trebuchet24")
    frameTitle:SetTextColor(color_white)
    return frameTitle
end