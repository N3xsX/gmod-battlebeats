local defColor = Color(255, 210, 0)
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

function PANEL:BTB_SetFocus()
    local bg = vgui.Create("DPanel")
    bg:SetSize(ScrW(), ScrH())
    bg:Center()
    bg:MakePopup()
    bg.OnMousePressed = function()
        self:MakePopup()
    end
    bg.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, color_transparent)
    end
    bg.Think = function()
        if not IsValid(self) then bg:Remove() end
    end
end

local c202020215 = Color(20, 20, 20, 215)
local c505050 = Color(50, 50, 50)
function PANEL:BTB_PaintProperties()
    self.Paint = function(self, w, h)
        self:SetFontInternal("ChatFont")
        self:SetTextColor(color_white)
        local color = self:IsHovered() and c202020215 or c505050
        draw.RoundedBox(12, 2, 2, w - 4, h - 4, color)
    end
end

local function LerpColor(t, from, to)
    return Color(
        Lerp(t, from.r, to.r),
        Lerp(t, from.g, to.g),
        Lerp(t, from.b, to.b),
        Lerp(t, from.a or 255, to.a or 255)
    )
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

function PANEL:BTB_SetButtonOutline(outline, normalCol, hoverCol, noHover)
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
        draw.RoundedBox(12, 0, 0, w, h, s.currentColor)
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, outline)
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
