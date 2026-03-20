local tooltipPanel = {}
function tooltipPanel:PerformLayout()
    self:SetFontInternal("HudHintTextLarge")
    self:SetTextColor(color_white)
    self:SetContentAlignment(5)
    local tw, th = self:GetContentSize()
    self:SetWide(tw + 15)
    self:SetTall(th + 10)
end

function tooltipPanel:Think()
    local mx, my = gui.MousePos()
    if not mx or mx == 0 then return end
    local w = self:GetWide()
    local h = self:GetTall()
    local targetX = mx - w / 2
    local targetY = my - h - 12
    self:SetPos(targetX, targetY)
end

function tooltipPanel:Paint(w, h)
    draw.RoundedBox(10, 0, 0, w, h, Color(255, 210, 0))
    draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
end

vgui.Register("BattleBeatsTooltip", tooltipPanel, "DTooltip")

local PANEL = FindMetaTable("Panel")
function PANEL:BTB_SetImageTooltip(imagePath, text, width, maxImageHeight)
    width = width or 350
    maxImageHeight = maxImageHeight or 400

    self:SetMouseInputEnabled(true)
    local imgtooltipPanel = nil

    self.OnCursorEntered = function()
        if IsValid(imgtooltipPanel) then imgtooltipPanel:Remove() end
        imgtooltipPanel = vgui.Create("DPanel")
        imgtooltipPanel:SetAlpha(0)
        imgtooltipPanel:MakePopup()
        imgtooltipPanel.Think = function(self)
            local mx, my = gui.MousePos()
            if not mx or mx == 0 then return end
            local w = self:GetWide()
            local h = self:GetTall()
            local targetX = mx - w / 2
            local targetY = my - h - 12
            self:SetPos(targetX, targetY)
        end

        local img = vgui.Create("DImage", imgtooltipPanel)
        img:SetPos(10, 10)
        img:SetSize(width - 20, maxImageHeight)
        img:SetImage(imagePath)
        img:SetKeepAspect(true)

        local mat = Material(imagePath, "noclamp smooth")
        local realW, realH = mat:Width(), mat:Height()
        local targetW = width - 20
        local scale = targetW / realW
        local newImgH = realH * scale
        if newImgH > maxImageHeight then
            newImgH = maxImageHeight
            scale = maxImageHeight / realH
        end
        img:SetSize(targetW, newImgH)

        local imageBottom = 10 + newImgH + 15
        if text and text ~= "" then
            local label = vgui.Create("DLabel", imgtooltipPanel)
            label:SetPos(10, imageBottom)
            label:SetSize(width - 20, 20)
            label:SetText(text)
            label:SetTextColor(color_white)
            label:SetFont("HudHintTextLarge")
            label:SetWrap(true)
            label:SetAutoStretchVertical(true)
            timer.Simple(0, function()
                if IsValid(label) and IsValid(imgtooltipPanel) then
                    label:SizeToContentsY(15)
                    local totalH = imageBottom + label:GetTall()
                    imgtooltipPanel:SetSize(width, totalH)
                    imgtooltipPanel:SetAlpha(255)
                end
            end)
        else
            imgtooltipPanel:SetSize(width, imageBottom)
            imgtooltipPanel:SetAlpha(255)
        end

        imgtooltipPanel.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(255, 210, 0))
            draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
        end
    end

    self.OnCursorExited = function()
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
