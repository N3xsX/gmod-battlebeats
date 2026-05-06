local c2552100 = Color(255, 210, 0)
local c909090 = Color(90, 90, 90)
local c230230230 = Color(230, 230, 230)
local function checkbox(isServer, parent, x, y, labelText, cvarName, helpText, img)
    isServer = isServer or false
    local panel = vgui.Create("DPanel", parent)
    panel:SetTall(20)
    panel:SetPos(0, y)
    panel.Paint = nil

    local switch = vgui.Create("DPanel", panel)
    switch:SetSize(40, 20)

    local enabled = GetConVar(cvarName):GetBool()
    switch.KnobX = enabled and (40 - 16 - 2) or 2

    switch.Paint = function(self, w, h)
        local targetX = enabled and (w - 16 - 2) or 2
        self.KnobX = Lerp(FrameTime() * 10, self.KnobX, targetX)
        local bgColor = enabled and c2552100 or c909090
        draw.RoundedBox(h / 2, 0, 0, w, h, bgColor)
        draw.RoundedBox(h, self.KnobX, 2, 16, 16, c230230230)
    end

    switch.OnMousePressed = function()
        local newVal = GetConVar(cvarName):GetBool() and "0" or "1"
        if newVal == "1" then
            enabled = true
            surface.PlaySound("btb_switch_on.mp3")
        else
            enabled = false
            surface.PlaySound("btb_switch_off.mp3")
        end
        if not isServer then
            RunConsoleCommand(cvarName, newVal)
        else
            net.Start("BTB_Change_ConVar")
            net.WriteString(cvarName)
            net.WriteFloat(newVal)
            net.SendToServer()
        end
    end

    if helpText then
        if img then
            switch:BTB_SetImageTooltip(img, helpText)
            panel:BTB_SetImageTooltip(img, helpText)
        else
            switch:SetTooltip(helpText)
            switch:SetTooltipPanelOverride("BattleBeatsTooltip")
            panel:SetTooltip(helpText)
            panel:SetTooltipPanelOverride("BattleBeatsTooltip")
        end
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetFont("DermaDefaultBold")
    label:SetTextColor(color_white)
    label:SizeToContents()

    local totalWidth = 40 + 8 + label:GetWide()
    panel:SetWide(totalWidth)
    panel:SetPos(x - totalWidth / 2, y)

    switch:SetPos(0, (panel:GetTall() - 20) / 2)
    label:SetPos(40 + 8, (panel:GetTall() - label:GetTall()) / 2)

    local oldEnter = switch.OnCursorEntered
    local oldExit = switch.OnCursorExited
    switch.OnCursorEntered = function(self)
        self:SetCursor("hand")
        if oldEnter then
            oldEnter(self)
        end
    end
    switch.OnCursorExited = function(self)
        self:SetCursor("arrow")
        if oldExit then
            oldExit(self)
        end
    end
    panel.OnCursorEntered = switch.OnCursorEntered
    panel.OnCursorExited = switch.OnCursorExited
    panel.OnMousePressed = switch.OnMousePressed

    return panel
end

local function numSlider(parent, x, y, labelText, cvarName, min, max, helpText)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(300, 40)
    panel:SetPos(x, y)
    panel.Paint = nil

    if helpText then
        panel:SetTooltip(helpText)
        panel:SetTooltipPanelOverride("BattleBeatsTooltip")
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetFont("DermaDefaultBold")
    label:SetPos((300 - 200) / 2, 0)
    label:SetSize(200, 20)
    label:SetTextColor(color_white)
    label:SetContentAlignment(5)

    local sliderBar = vgui.Create("DPanel", panel)
    sliderBar:SetSize(300, 12)
    sliderBar:SetPos(0, 25)
    sliderBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c909090)
        local progress = (GetConVar(cvarName):GetInt() - min) / (max - min)
        draw.RoundedBox(4, 0, 0, w * progress, h, c2552100)
    end

    local function updateSlider(bar, x)
        local progress = math.Clamp(x / bar:GetWide(), 0, 1)
        local newValue = math.floor(min + progress * (max - min))
        RunConsoleCommand(cvarName, math.Round(newValue, 0))
    end

    sliderBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            local x, _ = self:CursorPos()
            updateSlider(self, x)
            self.IsDragging = true
        end
    end

    sliderBar.Think = function(self)
        if self.IsDragging and input.IsMouseDown(MOUSE_LEFT) then
            local x, _ = self:CursorPos()
            updateSlider(self, x)
        elseif self.IsDragging and not input.IsMouseDown(MOUSE_LEFT) then
            self.IsDragging = false
        end
    end

    panel.PaintOver = function(self, w, h)
        local val = GetConVar(cvarName):GetInt()
        local xx = sliderBar.x + sliderBar:GetWide() / 2
        local yy = sliderBar.y + sliderBar:GetTall() / 2 - 1
        draw.SimpleTextOutlined(val .. "%", "DermaDefaultBold", xx, yy, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 120))
    end

    sliderBar.OnCursorEntered = function(self)
        self:SetCursor("hand")
    end
    sliderBar.OnCursorExited = function(self)
        self:SetCursor("arrow")
    end

    return panel
end

local function arrowStepper(isServer, parent, x, y, labelText, cvarName, min, max, helpText, suffix)
    isServer = isServer or false
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(300, 50)
    panel:SetPos(x, y)
    panel.Paint = nil

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetFont("DermaDefaultBold")
    label:SetPos((300 - 200) / 2, 0)
    label:SetSize(200, 20)
    label:SetTextColor(color_white)
    label:SetContentAlignment(5)

    if helpText then
        panel:SetTooltip(helpText)
        panel:SetTooltipPanelOverride("BattleBeatsTooltip")
    end

    local sliderBar = vgui.Create("DPanel", panel)
    sliderBar:SetSize(240, 8)
    sliderBar:SetPos(30, 25)
    sliderBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c909090)
        local progress = (GetConVar(cvarName):GetInt() - min) / (max - min)
        draw.RoundedBox(4, 0, 0, w * progress, h, c2552100)
    end

    local leftBtn = vgui.Create("DButton", panel)
    leftBtn:SetText("<")
    leftBtn:SetFont("CreditsText")
    leftBtn:SetTextColor(color_white)
    leftBtn:SetSize(20, 20)
    leftBtn:SetPos(0, 18)
    leftBtn.Paint = nil

    local rightBtn = vgui.Create("DButton", panel)
    rightBtn:SetText(">")
    rightBtn:SetFont("CreditsText")
    rightBtn:SetTextColor(color_white)
    rightBtn:SetSize(20, 20)
    rightBtn:SetPos(280, 18)
    rightBtn.Paint = nil

    local function sendValue(newVal)
        newVal = math.Clamp(math.Round(newVal), min, max)
        if not isServer then
            RunConsoleCommand(cvarName, newVal)
        else
            net.Start("BTB_Change_ConVar")
            net.WriteString(cvarName)
            net.WriteFloat(newVal)
            net.SendToServer()
        end
    end

    local valueLabel = vgui.Create("DLabel", panel)
    valueLabel:SetSize(40, 20)
    valueLabel:SetPos(130, 32)
    valueLabel:SetTextColor(color_white)
    valueLabel:SetContentAlignment(5)
    valueLabel:SetMouseInputEnabled(true)
    valueLabel.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        if IsValid(self.Entry) then return end

        local cvar = GetConVar(cvarName)
        local maxChars = string.len(tostring(math.floor(cvar:GetMax() or 111)))
        local entry = vgui.Create("DTextEntry", panel)
        entry:SetSize(30, 20)
        entry:SetPos(self:GetX() + 5, self:GetY() - 1)
        entry:SetNumeric(true)
        entry:SetMaximumCharCount(maxChars)
        entry:SetValue(cvar:GetInt())
        entry:RequestFocus()
        entry:SetCaretPos(string.len(cvar:GetInt()))
        entry.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, c909090)
            self:DrawTextEntryText(color_white, color_white, color_white)
        end

        self:SetVisible(false)
        self.Entry = entry

        local function finish()
            if not IsValid(entry) then return end

            local val = tonumber(entry:GetValue())
            if val then
                sendValue(val)
            end

            self:SetVisible(true)
            self.Entry = nil
            entry:Remove()
        end

        entry.OnEnter = finish

        entry.OnLoseFocus = function()
            finish()
        end
    end

    local function updateSlider(bar, x)
        local progress = math.Clamp(x / bar:GetWide(), 0, 1)
        local newValue = math.floor(min + progress * (max - min))
        local oldValue = GetConVar(cvarName):GetInt()
        if newValue ~= oldValue then
            sendValue(newValue)
        end
    end

    local function updateValue(delta)
        local current = GetConVar(cvarName):GetInt()
        sendValue(current + delta)
    end

    local function setupHoldButton(btn, delta)
        btn.NextRepeat = 0
        btn.HoldStart = 0
        btn.IsHeld = false

        btn.OnMousePressed = function(self, code)
            if code ~= MOUSE_LEFT then return end
            updateValue(delta)
            self.IsHeld = true
            self.HoldStart = CurTime()
            self.NextRepeat = CurTime() + 0.8
        end

        btn.OnMouseReleased = function(self, code)
            if code ~= MOUSE_LEFT then return end
            self.IsHeld = false
        end

        btn.Think = function(self)
            if not self.IsHeld then return end

            if not input.IsMouseDown(MOUSE_LEFT) then
                self.IsHeld = false
                return
            end

            if CurTime() >= self.NextRepeat then
                updateValue(delta)
                local heldTime = CurTime() - self.HoldStart
                local delay
                if heldTime < 3 then
                    delay = 0.16
                elseif heldTime < 6 then
                    delay = 0.08
                else
                    delay = 0.04
                end
                self.NextRepeat = CurTime() + delay
            end
        end
    end

    sliderBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            local x, _ = self:CursorPos()
            updateSlider(self, x)
            self.IsDragging = true
        end
    end

    setupHoldButton(leftBtn, -1)
    setupHoldButton(rightBtn, 1)

    sliderBar.Think = function(self)
        local val = GetConVar(cvarName):GetInt()
        if suffix then
            valueLabel:SetText(val .. " " .. suffix)
        else
            valueLabel:SetText(val)
        end
        if self.IsDragging and input.IsMouseDown(MOUSE_LEFT) then
            local x, _ = self:CursorPos()
            updateSlider(self, x)
        elseif self.IsDragging and not input.IsMouseDown(MOUSE_LEFT) then
            self.IsDragging = false
        end
    end

    sliderBar.OnCursorEntered = function(self)
        self:SetCursor("hand")
    end
    sliderBar.OnCursorExited = function(self)
        self:SetCursor("arrow")
    end

    return panel
end

local c505050 = Color(50, 50, 50)
local c100100100 = Color(100, 100, 100)
local function comboBox(isServer, parent, x, y, labelText, cvarName, options, helpText)
    isServer = isServer or false
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(200, 200)
    panel:SetPos(x, y)
    panel.Paint = nil

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetFont("DermaDefaultBold")
    label:SetPos((200 - 150) / 2, 0)
    label:SetSize(150, 20)
    label:SetTextColor(color_white)
    label:SetContentAlignment(5)

    local combo = vgui.Create("DPanel", panel)
    combo:SetSize(200, 30)
    combo:SetPos(0, 25)
    combo.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, c909090)
        local cvarValue = GetConVar(cvarName):GetInt()
        local index = math.Clamp(cvarValue + 1, 1, #options)
        local displayText = options[index] or "Unknown"
        draw.SimpleText(displayText, "DermaDefaultBold", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if helpText then
        combo:SetTooltip(helpText)
        combo:SetTooltipPanelOverride("BattleBeatsTooltip")
    end

    combo.OnCursorEntered = function(self)
        self:SetCursor("hand")
    end
    combo.OnCursorExited = function(self)
        self:SetCursor("arrow")
    end

    local isOpen = false
    local dropdown = vgui.Create("DPanel", panel)
    dropdown:SetSize(200, 0)
    dropdown:SetPos(0, 55)
    dropdown.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c505050)
    end
    dropdown:SetVisible(false)

    for i, option in ipairs(options) do
        local btn = vgui.Create("DButton", dropdown)
        btn:SetText(option)
        btn:SetPos(0, (i - 1) * 30)
        btn:SetSize(200, 30)
        btn:SetTextColor(color_white)
        btn.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and c100100100 or c505050
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end
        btn.DoClick = function()
            local value = tostring(i - 1)
            if not isServer then
                RunConsoleCommand(cvarName, value)
            else
                net.Start("BTB_Change_ConVar")
                net.WriteString(cvarName)
                net.WriteFloat(value)
                net.SendToServer()
            end
            isOpen = false
            dropdown:SetVisible(false)
            dropdown:SetSize(200, 0)
        end
    end

    combo.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            isOpen = not isOpen
            dropdown:SetVisible(isOpen)
            dropdown:SetSize(200, isOpen and (#options * 30) or 0)
        end
    end

    return panel
end

local function cbutton(parent, x, y, labelText, cvarName, helpText)
    local button = vgui.Create("DButton", parent)
    button:SetSize(200, 30)
    button:SetPos(x - 100, y)
    button:SetText(labelText)
    button:SetFont("DermaDefaultBold")
    button:SetTextColor(color_white)
    button.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and c100100100 or c909090
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, bgColor)
    end

    if helpText then
        button:SetTooltip(helpText)
        button:SetTooltipPanelOverride("BattleBeatsTooltip")
    end

    button.DoClick = function()
        RunConsoleCommand(cvarName)
    end

    return button
end

local function warningZone(parent, x, y, w, h)
    local frame = vgui.Create("DPanel", parent)
    frame:SetSize(w, h)
    frame:SetPos(x - (frame:GetWide() / 2), y)
    frame.Paint = function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material("btboptionbg.jpg"))
        surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, 1, 0.5)
    end

    local frameTitle = vgui.Create("DLabel", parent)
    frameTitle:SetPos(x - 100, y - 25)
    frameTitle:SetSize(200, 20)
    frameTitle:SetText("DANGER ZONE")
    frameTitle:SetContentAlignment(5)
    frameTitle:SetFont("DermaDefaultBold")
    frameTitle:SetTextColor(color_white)

    local inner = vgui.Create("DPanel", frame)
    inner:Dock(FILL)
    inner:DockMargin(6, 6, 6, 6)
    inner.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c505050)
    end

    return inner
end

local function LerpColor(t, from, to)
    return Color(
        Lerp(t, from.r, to.r),
        Lerp(t, from.g, to.g),
        Lerp(t, from.b, to.b),
        Lerp(t, from.a or 255, to.a or 255)
    )
end

local catSound = language.GetPhrase("btb.options.cat.sound")
local catNoti = language.GetPhrase("btb.options.cat.notification")
local catSub = language.GetPhrase("btb.options.cat.subtitles")
local catPlayer = language.GetPhrase("btb.options.cat.music_player")
local catOther = language.GetPhrase("btb.options.cat.misc")

local catGeneral = language.GetPhrase("btb.options.cat.general")
local catPvP = language.GetPhrase("btb.options.cat.pvp")

local hoverColor = Color(60, 60, 60, 255)
local normalColor = Color(50, 50, 50, 255)
local activeColor = Color(40, 40, 40, 255)
local blockedColor = Color(30, 30, 30, 255)

function BATTLEBEATS.createOptions(panel)
    if IsValid(BATTLEBEATS.optionsFrame) then return end
    local plyIsAdmin = LocalPlayer():IsSuperAdmin()
    local frame = vgui.Create("DPanel", panel)
    frame:SetSize(950, 600)
    frame:Center()
    frame:SetPos(frame:GetX(), frame:GetY() - 20)
    frame.Paint = nil

    BATTLEBEATS.optionsFrame = frame
    local currentScope = "client"
    local selectedTabs = {
        client = 1,
        server = 1
    }

    local tabPanel = vgui.Create("DPanel", frame)
    tabPanel:SetSize(frame:GetWide() - 20, 40)
    tabPanel:SetPos(10, 30)
    tabPanel.Paint = nil

    local clientCategories = {
        { name = catSound,  panel = nil },
        { name = catNoti,   panel = nil },
        { name = catSub,    panel = nil },
        { name = catPlayer, panel = nil },
        { name = catOther,  panel = nil }
    }

    local serverCategories = {
        { name = catGeneral, panel = nil },
        { name = catPvP,  panel = nil }
    }

    local categories = clientCategories

    local contentPanel = vgui.Create("DPanel", frame)
    contentPanel:SetSize(frame:GetWide() - 20, frame:GetTall() - 120)
    contentPanel:SetPos(10, 70)
    contentPanel.Paint = nil

    local function createScopeButton(text, x, scope)
        local button = vgui.Create("DButton", frame)
        button:SetZPos(-1)
        button:SetText(text)
        button:SetFont("Trebuchet24")
        button:SetSize(contentPanel:GetWide() / 2, 40)
        button.posY = frame:GetTall() - button:GetTall() - 10
        button:SetPos(x, button.posY)
        button:SetTextColor(Color(255, 255, 255))
        button.currentColor = normalColor
        button.targetColor = normalColor
        button.currentY = button.currentY or button.posY - 8
        button.targetY = button.posY - 8
        if scope == "server" and not plyIsAdmin then
            button:SetCursor("no")
        end

        button.Think = function(self)
            if not self.initialized then
                self.initialized = true
                button.currentY = currentScope == scope and button.posY or button.posY - 8
                self:SetPos(self:GetX(), self.currentY)
                return
            end
            if currentScope == scope then
                self.targetColor = activeColor
                self.targetY = button.posY
            elseif self:IsHovered() and plyIsAdmin then
                self.targetColor = hoverColor
                self.targetY = button.posY - 5
            else
                if not plyIsAdmin then
                    self.targetColor = blockedColor
                else
                    self.targetColor = normalColor
                end
                self.targetY = button.posY - 8
            end

            self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
            self.currentY = Lerp(FrameTime() * 12, self.currentY, self.targetY)

            self:SetPos(self:GetX(), self.currentY)
        end

        button.Paint = function(self, w, h)
            if currentScope == scope then
                draw.RoundedBoxEx(16, 0, 0, w, h, activeColor, false, false, true, true)
                return
            end
            draw.RoundedBoxEx(16, 0, 0, w, h, self.currentColor, false, false, true, true)
        end

        button.DoClick = function()
            if scope == "server" and not plyIsAdmin then
                surface.PlaySound("buttons/button8.wav")
                return
            end
            surface.PlaySound("btb_tab_switch.mp3")
            currentScope = scope
            BuildTabs()
        end
    end

    createScopeButton("#btb.options.client", 10, "client")
    createScopeButton("#btb.options.server", 475, "server")

    function BuildTabs()
        tabPanel:Clear()
        categories = currentScope == "client" and clientCategories or serverCategories
        local tabWidth = tabPanel:GetWide() / #categories

        for _, cat in ipairs(clientCategories) do
            if IsValid(cat.panel) then
                cat.panel:SetVisible(false)
            end
        end
        for _, cat in ipairs(serverCategories) do
            if IsValid(cat.panel) then
                cat.panel:SetVisible(false)
            end
        end

        for i, category in ipairs(categories) do
            local button = vgui.Create("DButton", tabPanel)
            button:SetText(category.name)
            button:SetFont("CreditsText")
            button:SetPos((i - 1) * tabWidth, 8)
            button:SetSize(tabWidth, 40)
            button:SetTextColor(Color(255, 255, 255))
            button.currentColor = normalColor
            button.targetColor = normalColor
            button.currentY = button.currentY or 8
            button.targetY = 8
            button.initialized = false

            button.Think = function(self)
                local isActive = category.panel and category.panel:IsVisible()
                if not self.initialized then
                    self.initialized = true
                    button.currentY = isActive and 0 or 8
                    self:SetPos(self:GetX(), self.currentY)
                    return
                end

                if isActive then
                    self.targetColor = activeColor
                    self.targetY = 0
                elseif self:IsHovered() then
                    self.targetColor = hoverColor
                    self.targetY = 5
                else
                    self.targetColor = normalColor
                    self.targetY = 8
                end

                self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
                self.currentY = Lerp(FrameTime() * 12, self.currentY, self.targetY)

                self:SetPos(self:GetX(), self.currentY)
            end

            button.Paint = function(self, w, h)
                if category.panel and category.panel:IsVisible() then
                    draw.RoundedBoxEx(16, 0, 0, w, h, activeColor, true, true, false, false)
                    return
                end
                draw.RoundedBoxEx(16, 0, 0, w, h, self.currentColor, true, true, false, false)
            end

            if not IsValid(category.panel) then
                local panel = vgui.Create("DPanel", contentPanel)
                panel:SetSize(contentPanel:GetWide(), contentPanel:GetTall())
                panel:SetPos(0, 0)
                panel.Paint = function(self, w, h)
                    draw.RoundedBox(0, 0, 0, w, h, activeColor)
                end
                panel:SetVisible(false)
                category.panel = panel

                local translation = language.GetPhrase("btb.translated.by")
                local lang = GetConVar("gmod_language"):GetString()
                if lang ~= "en" and translation ~= "///" then
                    local translationLabel = vgui.Create("DLabel", panel)
                    translationLabel:SetText(language.GetPhrase("btb.translated.by.label") .. translation)
                    translationLabel:SetPos((contentPanel:GetWide() - 400) / 2, 420)
                    translationLabel:SetSize(400, 20)
                    translationLabel:SetTextColor(Color(80, 80, 80, 200))
                    translationLabel:SetContentAlignment(5)
                end

                local versionlabel = vgui.Create("DLabel", panel)
                versionlabel:SetText(language.GetPhrase("btb.options.version.label") .. " " .. BATTLEBEATS.currentVersion .. " | " .. jit.arch .. " :: " .. jit.os)
                versionlabel:SetPos((contentPanel:GetWide() - 250) / 2, 440)
                versionlabel:SetSize(250, 20)
                versionlabel:SetTextColor(Color(80, 80, 80, 200))
                versionlabel:SetContentAlignment(5)

                local contentPanel_2 = contentPanel:GetWide() / 2
                local contentPanel_NumSlider = (panel:GetWide() - 300) / 2
                local btbDefault = language.GetPhrase("btb.options.noti.default_pos")

                if category.name == catSound then
                    numSlider(panel, contentPanel_NumSlider, 10, "#btb.options.snd.master_volume", "battlebeats_volume", 0, 200, "#btb.options.snd.master_volume_tip")
                    numSlider(panel, contentPanel_NumSlider, 50, "#btb.options.snd.ambient_volume", "battlebeats_volume_ambient", 0, 100)
                    numSlider(panel, contentPanel_NumSlider, 90, "#btb.options.snd.combat_volume", "battlebeats_volume_combat", 0, 100)
                    checkbox(nil, panel, contentPanel_2, 150, "#btb.options.snd.enable_ambient", "battlebeats_enable_ambient")
                    checkbox(nil, panel, contentPanel_2, 180, "#btb.options.snd.enable_combat", "battlebeats_enable_combat")
                    checkbox(nil, panel, contentPanel_2, 210, "#btb.spawnmenu.general.force_combat", "battlebeats_force_combat", "#btb.spawnmenu.general.force_combat_tip")
                    comboBox(nil, panel, (contentPanel_2 - 100) - 110, 250, "#btb.spawnmenu.general.combo", "battlebeats_disable_mode", { "#btb.spawnmenu.general.combo_1", "#btb.spawnmenu.general.combo_2", "#btb.spawnmenu.general.combo_3" })
                    comboBox(nil, panel, (contentPanel_2 - 100) + 110, 250, "#btb.options.snd.start_mode", "battlebeats_start_mode", { "#btb.options.snd.start_mode_1", "#btb.options.snd.start_mode_2", "#btb.options.snd.start_mode_3", "#btb.options.snd.start_mode_4" }, "#btb.options.snd.start_mode_tip")
                elseif category.name == catNoti then
                    checkbox(nil, panel, contentPanel:GetWide() / 4, 10, "#btb.options.noti.enable_noti", "battlebeats_show_notification", "#btb.options.noti.enable_noti_tip", "tooltips/shownoti.png")
                    checkbox(nil, panel, contentPanel:GetWide() / 1.4, 10, "#btb.options.noti.noti_always_vis", "battlebeats_persistent_notification", "#btb.options.noti.noti_always_vis_tip")
                    checkbox(nil, panel, contentPanel:GetWide() / 4, 40, "#btb.options.noti.progress_bar", "battlebeats_show_status_bar", "#btb.options.noti.progress_bar_tip", "tooltips/showprog.png")
                    checkbox(nil, panel, contentPanel:GetWide() / 1.4, 40, "#btb.options.noti.replay", "battlebeats_show_notification_after_continue", "#btb.options.noti.replay_tip")
                    checkbox(nil, panel, contentPanel:GetWide() / 4, 70, "#btb.options.noti.show_nombat", "battlebeats_skip_nombat_names", "#btb.options.noti.show_nombat_tip")
                    checkbox(nil, panel, contentPanel:GetWide() / 1.4, 70, "#btb.options.noti.pack_name", "battlebeats_show_notification_pack_name", "#btb.options.noti.pack_name_tip", "tooltips/showname.png")
                    checkbox(nil, panel, contentPanel_2, 100, "#btb.options.noti.preview", "battlebeats_show_preview_notification", "#btb.options.noti.preview_tip", "tooltips/showprev.png")
                    checkbox(nil, panel, contentPanel_2, 130, "#btb.options.noti.visualizer", "battlebeats_show_notification_visualizer", "#btb.options.noti.visualizer_tip", "tooltips/showbars.png")
                    checkbox(nil, panel, contentPanel_2, 160, "#btb.options.noti.visualizer_smooth", "battlebeats_visualizer_smooth", "#btb.options.noti.visualizer_smooth_tip")
                    arrowStepper(nil, panel, contentPanel_NumSlider, 200, "#btb.options.noti.visualizer_boost", "battlebeats_visualizer_boost", 1, 20, "#btb.options.noti.visualizer_boost_tip")
                    arrowStepper(nil, panel, contentPanel_NumSlider, 250, "#btb.options.noti.x_pos", "battlebeats_notif_x", 0, ScrW(), btbDefault .. tostring(ScrW() - 310))
                    arrowStepper(nil, panel, contentPanel_NumSlider, 300, "#btb.options.noti.y_pos", "battlebeats_notif_y", 0, ScrH(), btbDefault .. tostring(ScrH() / 6))
                elseif category.name == catSub then
                    checkbox(nil, panel, contentPanel_2, 10, "#btb.options.sub.enable_sub", "battlebeats_subtitles_enabled")
                    arrowStepper(nil, panel, contentPanel_NumSlider, 40, "#btb.options.sub.sub_height", "battlebeats_subtitles_y", 0, ScrH(), btbDefault .. tostring(ScrH() - 200))
                    checkbox(nil, panel, contentPanel_2, 100, "#btb.options.sub.static", "battlebeats_subtitles_static", "#btb.options.sub.static_tip")
                    comboBox(nil, panel, (contentPanel_2 - 100), 130, "#btb.options.sub.combo", "battlebeats_subtitles_mode", {"#btb.options.sub.combo1", "#btb.options.sub.combo2"}, "#btb.options.sub.combo_tip")
                elseif category.name == catPlayer then
                    checkbox(nil, panel, contentPanel_2, 10, "#btb.options.mplayer.curr_pack_only", "battlebeats_exclusive_play", "#btb.options.mplayer.curr_pack_only_tip")
                    arrowStepper(nil, panel, contentPanel_NumSlider / 3, 40, "#btb.options.mplayer.a_wait_time", "battlebeats_ambient_wait_time", 1, 120, "#btb.options.mplayer.wait_time_tip", "s")
                    arrowStepper(nil, panel, contentPanel_NumSlider / 0.6, 40, "#btb.options.mplayer.c_wait_time", "battlebeats_combat_wait_time", 1, 120, "#btb.options.mplayer.wait_time_tip", "s")
                    checkbox(nil, panel, contentPanel_2, 100, "#btb.options.mplayer.always_continue", "battlebeats_always_continue", "#btb.options.mplayer.always_continue_tip")
                    checkbox(nil, panel, contentPanel_2, 130, "#btb.spawnmenu.general.npc_combat", "battlebeats_npc_combat", "#btb.spawnmenu.general.npc_combat_tip")
                    checkbox(nil, panel, contentPanel_2, 160, "#btb.spawnmenu.general.enable_assigned", "battlebeats_enable_assigned_tracks", "#btb.spawnmenu.general.enable_assigned_tip")
                    checkbox(nil, panel, contentPanel_2, 190, "#btb.options.mplayer.exclude_assigned", "battlebeats_exclude_mapped_tracks", "#btb.options.mplayer.exclude_assigned_tip")
                    checkbox(nil, panel, contentPanel_2, 220, "#btb.options.mplayer.switch_to_lower", "battlebeats_switch_on_lower_priority", "#btb.options.mplayer.switch_to_lower_tip")
                    checkbox(nil, panel, contentPanel_2, 250, "#btb.options.mplayer.disable_fade", "battlebeats_disable_fade", "#btb.options.mplayer.disable_fade_tip")
                    arrowStepper(nil, panel, contentPanel_NumSlider, 280, "#btb.options.mplayer.fav_weight", "battlebeats_favorite_weight", 1, 10, "#btb.options.mplayer.fav_weight_tip")
                    comboBox(nil, panel, (contentPanel_2 - 100), 340, "#btb.options.mplayer.combo", "battlebeats_continue_mode", { "#btb.options.mplayer.combo_1", "#btb.options.mplayer.combo_2" }, "#btb.options.mplayer.combo_tip")
                elseif category.name == catOther then
                    checkbox(nil, panel, contentPanel:GetWide() / 4, 10, "#btb.options.misc.npc_los", "battlebeats_detection_mode", "#btb.spawnmenu.server.enable_pvp_los_tip")
                    checkbox(nil, panel, contentPanel:GetWide() / 1.4, 10, "#btb.options.misc.auto_popup", "battlebeats_autopopup", "#btb.options.misc.auto_popup_tip")
                    checkbox(nil, panel, contentPanel:GetWide() / 4, 40, "#btb.options.misc.load_local", "battlebeats_load_local_packs", "#btb.options.misc.load_local_tip")
                    checkbox(nil, panel, contentPanel:GetWide() / 1.4, 40, "#btb.options.misc.debug_mode", "battlebeats_debug_mode", "#btb.options.misc.debug_mode_tip")
                    checkbox(nil, panel, contentPanel_2, 70, "#btb.options.misc.lower_vol_in_menu", "battlebeats_lower_volume_in_menu", "#btb.options.misc.lower_vol_in_menu_tip")
                    checkbox(nil, panel, contentPanel_2, 100, "#btb.options.misc.load_am_sus", "battlebeats_load_am_suspense", "#btb.options.misc.load_am_sus_tip")
                    checkbox(nil, panel, contentPanel_2, 130, "#btb.options.misc.toggle_ui", "battlebeats_context_ui_toogle", "#btb.options.misc.toggle_ui_tip")
                    checkbox(nil, panel, contentPanel_2, 160, "#btb.options.misc.allow_enforce", "battlebeats_allow_server", "#btb.options.misc.allow_enforce_tip")
                    cbutton(panel, contentPanel_2, 210, "#btb.options.misc.reload_packs", "battlebeats_reload_packs")
                    --cbutton(panel, contentPanel_2 + 110, 220, "#btb.options.misc.open_guide", "battlebeats_guide")
                    warningZone(panel, contentPanel_2, 280, 480, 120)
                    cbutton(panel, contentPanel_2 - 110, 300, "#btb.options.misc.restore", "battlebeats_restore_defaults", "#btb.options.misc.restore_tip")
                    cbutton(panel, contentPanel_2 + 110, 300, "#btb.options.misc.clean_unused_tracks", "battlebeats_clean_unused_tracks", "#btb.options.misc.clean_unused_tracks_tip")
                    cbutton(panel, contentPanel_2 - 110, 350, "#btb.options.misc.clean_cache", "battlebeats_clean_cache", "#btb.options.misc.clean_cache_tip")
                    cbutton(panel, contentPanel_2 + 110, 350, "#btb.options.misc.delete_data", "battlebeats_delete_data", "#btb.options.misc.delete_data_tip")
                elseif category.name == catGeneral then
                    arrowStepper(true, panel, contentPanel_NumSlider, 10, "#btb.spawnmenu.server.combat_cooldown", "battlebeats_server_combat_cooldown", 3, 30, "#btb.spawnmenu.server.combat_cooldown_tip")
                    arrowStepper(true, panel, contentPanel_NumSlider, 60, "#btb.spawnmenu.server.trigger_distance", "battlebeats_server_max_distance", 100, 10000, "#btb.spawnmenu.server.trigger_distance_tip")
                elseif category.name == catPvP then
                    checkbox(true, panel, contentPanel_2, 10, "#btb.spawnmenu.server.enable_pvp", "battlebeats_pvp_enable")
                    checkbox(true, panel, contentPanel_2, 40, "#btb.spawnmenu.server.enable_pvp_teammates", "battlebeats_pvp_allow_team_combat")
                    checkbox(true, panel, contentPanel_2, 70, "#btb.spawnmenu.server.enable_pvp_los", "battlebeats_pvp_lineofsight", "#btb.spawnmenu.server.enable_pvp_los_tip")
                    arrowStepper(true, panel, contentPanel_NumSlider, 100, "#btb.spawnmenu.server.combat_time", "battlebeats_pvp_combat_time", 5, 120, "#btb.spawnmenu.server.combat_time_tip")
                    arrowStepper(true, panel, contentPanel_NumSlider, 150, "#btb.spawnmenu.server.visibility", "battlebeats_pvp_max_distance", 100, 10000, "#btb.spawnmenu.server.visibility_tip")
                    local tip = (language.GetPhrase("#btb.spawnmenu.server.combo_1_tip") .. "\n" .. language.GetPhrase("#btb.spawnmenu.server.combo_2_tip") .. "\n" .. language.GetPhrase("#btb.spawnmenu.server.combo_3_tip"))
                    comboBox(true, panel, (contentPanel_2 - 100), 210, "#btb.spawnmenu.server.combo", "battlebeats_pvp_mode", { "#btb.spawnmenu.server.combo_1", "#btb.spawnmenu.server.combo_2", "#btb.spawnmenu.server.combo_3"}, tip)
                end
            end

            button.DoClick = function()
                surface.PlaySound("btb_tab_switch.mp3")
                selectedTabs[currentScope] = i
                for _, cat in ipairs(categories) do
                    if IsValid(cat.panel) then
                        cat.panel:SetVisible(false)
                    end
                end
                if IsValid(category.panel) then
                    category.panel:SetVisible(true)
                end
            end
        end
        
        local selected = selectedTabs[currentScope] or 1
        if selected > #categories then
            selected = 1
            selectedTabs[currentScope] = 1
        end

        if categories[selected] and IsValid(categories[selected].panel) then
            categories[selected].panel:SetVisible(true)
        end
    end

    BuildTabs()
end

local defaultX = tostring(ScrW() - 310)
local defaultY = tostring(ScrH() / 6)
local subdefaultY = tostring(ScrH() - 200)

local confirmations = {}
local function confirmAction(id, timeout)
    local now = CurTime()
    local state = confirmations[id]
    if not state or now > state.expires then
        confirmations[id] = {expires = now + (timeout or 5)}
        notification.AddLegacy("[BattleBeats] " .. (language.GetPhrase("btb.options.misc.button_conf")), NOTIFY_HINT, timeout or 5)
        surface.PlaySound("ambient/water/drip" .. math.random(1, 4) .. ".wav")
        return false
    end
    confirmations[id] = nil
    surface.PlaySound("buttons/button14.wav")
    return true
end

local function cleanupInvalidTracks(tbl)
    local toRemove = {}
    for trackPath, _ in pairs(tbl) do
        if not file.Exists(trackPath, "GAME") then
            print("[BattleBeats Cleanup] Removing: " .. trackPath)
            table.insert(toRemove, trackPath)
        end
    end
    for _, trackPath in ipairs(toRemove) do
        tbl[trackPath] = nil
    end
end

concommand.Add("battlebeats_restore_defaults", function()
    if not confirmAction("restore_defaults", 5) then return end

    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.options.misc.restore_tip_conf"), NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")
    
    RunConsoleCommand("battlebeats_detection_mode", "1")
    RunConsoleCommand("battlebeats_npc_combat", "0")

    RunConsoleCommand("battlebeats_autopopup", "1")
    RunConsoleCommand("battlebeats_load_local_packs", "0")
    RunConsoleCommand("battlebeats_load_am_suspense", "0")
    RunConsoleCommand("battlebeats_allow_server", "1")

    RunConsoleCommand("battlebeats_volume", "100")
    RunConsoleCommand("battlebeats_debug_mode", "0")
    RunConsoleCommand("battlebeats_ambient_wait_time", "40")
    RunConsoleCommand("battlebeats_combat_wait_time", "40")
    RunConsoleCommand("battlebeats_enable_ambient", "1")
    RunConsoleCommand("battlebeats_enable_combat", "1")
    RunConsoleCommand("battlebeats_disable_mode", "0")
    RunConsoleCommand("battlebeats_persistent_notification", "0")
    RunConsoleCommand("battlebeats_show_notification", "1")
    RunConsoleCommand("battlebeats_show_notification_after_continue", "0")
    RunConsoleCommand("battlebeats_exclusive_play", "0")
    RunConsoleCommand("battlebeats_always_continue", "0")
    RunConsoleCommand("battlebeats_continue_mode", "0")
    RunConsoleCommand("battlebeats_show_preview_notification", "0")
    RunConsoleCommand("battlebeats_lower_volume_in_menu", "0")
    RunConsoleCommand("battlebeats_force_combat", "0")
    RunConsoleCommand("battlebeats_disable_fade", "0")
    RunConsoleCommand("battlebeats_start_mode", "0")
    RunConsoleCommand("battlebeats_favorite_weight", "3")

    RunConsoleCommand("battlebeats_subtitles_enabled", "1")
    RunConsoleCommand("battlebeats_subtitles_mode", "1")
    RunConsoleCommand("battlebeats_subtitles_static", "0")
    RunConsoleCommand("battlebeats_context_ui_toogle", "0")

    RunConsoleCommand("battlebeats_volume_ambient", "100")
    RunConsoleCommand("battlebeats_volume_combat", "100")

    RunConsoleCommand("battlebeats_switch_on_lower_priority", "1")
    RunConsoleCommand("battlebeats_enable_assigned_tracks", "1")
    RunConsoleCommand("battlebeats_exclude_mapped_tracks", "0")

    RunConsoleCommand("battlebeats_show_notification_visualizer", "1")
    RunConsoleCommand("battlebeats_show_notification_pack_name", "1")
    RunConsoleCommand("battlebeats_visualizer_boost", "6")
    RunConsoleCommand("battlebeats_visualizer_smooth", "1")
    RunConsoleCommand("battlebeats_skip_nombat_names", "1")
    RunConsoleCommand("battlebeats_show_status_bar", "1")

    RunConsoleCommand("battlebeats_notif_x", defaultX)
    RunConsoleCommand("battlebeats_notif_y", defaultY)

    RunConsoleCommand("battlebeats_subtitles_y", subdefaultY)
end)

concommand.Add("battlebeats_clean_cache", function()
    if not confirmAction("clean_cache", 5) then return end

    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.options.misc.clean_cache_tip_conf"), NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")
    
    RunConsoleCommand("battlebeats_seen_version", "0")
    cookie.Delete("battlebeats_start_track")
    cookie.Delete('BattleBeats_FirstTime')
    cookie.Delete("battlebeats_high_volume_time")
    cookie.Delete("battlebeats_high_volume_warn")
    cookie.Delete("battlebeats_last_track")
    cookie.Delete("battlebeats_vol_expanded")
end)

concommand.Add("battlebeats_delete_data", function()
    if not confirmAction("delete_data", 5) then return end

    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.options.misc.delete_data_tip_conf"), NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")
    
    cookie.Delete("battlebeats_selected_packs")
    file.Delete("battlebeats/battlebeats_excluded_tracks.txt")
    BATTLEBEATS.excludedTracks = {}
    file.Delete("battlebeats/battlebeats_favorite_tracks.txt")
    BATTLEBEATS.favoriteTracks = {}
    file.Delete("battlebeats/battlebeats_npc_mappings.txt")
    BATTLEBEATS.npcTrackMappings = {}
    file.Delete("battlebeats/battlebeats_track_volumes.txt")
    BATTLEBEATS.trackVolume = {}
    file.Delete("battlebeats/battlebeats_pack_volumes.txt")
    BATTLEBEATS.packVolume = {}
    file.Delete("battlebeats/battlebeats_track_trims.txt")
    BATTLEBEATS.trackTrim = {}
    file.Delete("battlebeats/battlebeats_playlists.txt")
    BATTLEBEATS.musicPlaylists = {}
end)

concommand.Add("battlebeats_clean_unused_tracks", function()
    if not confirmAction("clean_unused_tracks", 5) then return end

    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.options.misc.clean_unused_tracks_tip_conf"), NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")

    cleanupInvalidTracks(BATTLEBEATS.excludedTracks)
    BATTLEBEATS.SaveExcludedTracks()
    cleanupInvalidTracks(BATTLEBEATS.favoriteTracks)
    BATTLEBEATS.SaveFavoriteTracks()
    cleanupInvalidTracks(BATTLEBEATS.npcTrackMappings)
    BATTLEBEATS.SaveNPCMappings()
    cleanupInvalidTracks(BATTLEBEATS.trackVolume)
    BATTLEBEATS.SaveTrackVolumes()
    cleanupInvalidTracks(BATTLEBEATS.packVolume)
    BATTLEBEATS.SavePackVolumes()
    cleanupInvalidTracks(BATTLEBEATS.trackTrim)
    BATTLEBEATS.SaveTrackTrim()
end)