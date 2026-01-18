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
    draw.RoundedBox(8, 2, 2, w - 4, h - 4, Color(50, 50, 50))
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
            draw.RoundedBox(8, 2, 2, w - 4, h - 4, Color(50, 50, 50))
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
function PANEL:BTB_SetButtons(showMin)
    self.PerformLayout = function(self)
        self.btnClose:SetPos(self:GetWide() - 31 - 4, 5)
        self.btnClose:SetSize(31, 20)
        self.btnMaxim:SetPos(self:GetWide() - 31 * 2 - 4, 5)
        self.btnMaxim:SetSize(31, 20)
        self.btnMinim:SetPos(self:GetWide() - 31 * 3 - 4, 5)
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
