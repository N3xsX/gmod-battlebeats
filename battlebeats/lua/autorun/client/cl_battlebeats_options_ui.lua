local function CreateCustomCheckbox(parent, x, y, labelText, cvarName, helpText)
    local width, height = 40, 20
    local knobSize = 16

    local panel = vgui.Create("DPanel", parent)
    panel:SetTall(height)
    panel:SetPos(0, y)
    panel.Paint = function() end

    local switch = vgui.Create("DPanel", panel)
    switch:SetSize(width, height)

    local enabled = GetConVar(cvarName):GetBool()
    switch.KnobX = enabled and (width - knobSize - 2) or 2

    switch.Paint = function(self, w, h)
        local enabled = GetConVar(cvarName):GetBool()
        local targetX = enabled and (w - knobSize - 2) or 2
        self.KnobX = Lerp(FrameTime() * 10, self.KnobX, targetX)
        local bgColor = enabled and Color(255, 210, 0) or Color(90, 90, 90)
        draw.RoundedBox(h / 2, 0, 0, w, h, bgColor)
        draw.RoundedBox(h, self.KnobX, 2, knobSize, knobSize, Color(230, 230, 230))
    end

    switch.OnMousePressed = function()
        local newVal = GetConVar(cvarName):GetBool() and "0" or "1"
        RunConsoleCommand(cvarName, newVal)
    end

    if helpText then
        switch:SetTooltip(helpText)
        panel:SetTooltip(helpText)
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetTextColor(Color(255, 255, 255))
    label:SizeToContents()

    local spacing = 8
    local totalWidth = width + spacing + label:GetWide()
    panel:SetWide(totalWidth)
    panel:SetPos(x - totalWidth / 2, y)

    switch:SetPos(0, (panel:GetTall() - height) / 2)
    label:SetPos(width + spacing, (panel:GetTall() - label:GetTall()) / 2)

    switch.OnCursorEntered = function(self) self:SetCursor("hand") end
    switch.OnCursorExited = function(self) self:SetCursor("arrow") end
    panel.OnCursorEntered = switch.OnCursorEntered
    panel.OnCursorExited = switch.OnCursorExited
    panel.OnMousePressed = switch.OnMousePressed

    return panel
end

local function CreateCustomNumSlider(parent, x, y, labelText, cvarName, min, max)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(300, 40)
    panel:SetPos(x, y)
    panel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 0))
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetPos((300 - 150) / 2, 0)
    label:SetSize(150, 20)
    label:SetTextColor(Color(255, 255, 255))
    label:SetContentAlignment(5)

    local sliderBar = vgui.Create("DPanel", panel)
    sliderBar:SetSize(300, 8)
    sliderBar:SetPos(0, 25)
    sliderBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(90, 90, 90))
        local progress = (GetConVar(cvarName):GetInt() - min) / (max - min)
        draw.RoundedBox(4, 0, 0, w * progress, h, Color(255, 210, 0))
    end

    local function UpdateSlider(bar, x)
        local progress = math.Clamp(x / bar:GetWide(), 0, 1)
        local newValue = math.floor(min + progress * (max - min))
        RunConsoleCommand(cvarName, math.Round(newValue, 0))
    end

    sliderBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            local x, _ = self:CursorPos()
            UpdateSlider(self, x)
            self.IsDragging = true
        end
    end

    sliderBar.Think = function(self)
        if self.IsDragging and input.IsMouseDown(MOUSE_LEFT) then
            local x, _ = self:CursorPos()
            UpdateSlider(self, x)
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

local function CreateArrowStepper(parent, x, y, labelText, cvarName, min, max, helpText)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(300, 50)
    panel:SetPos(x, y)
    panel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 0))
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetPos((300 - 150) / 2, 0)
    label:SetSize(150, 20)
    label:SetTextColor(Color(255, 255, 255))
    label:SetContentAlignment(5)

    if helpText then
        panel:SetTooltip(helpText)
    end

    local sliderBar = vgui.Create("DPanel", panel)
    sliderBar:SetSize(240, 8)
    sliderBar:SetPos(30, 25)
    sliderBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(90, 90, 90))
        local progress = (GetConVar(cvarName):GetInt() - min) / (max - min)
        draw.RoundedBox(4, 0, 0, w * progress, h, Color(255, 210, 0))
    end

    local leftBtn = vgui.Create("DButton", panel)
    leftBtn:SetText("<")
    leftBtn:SetFont("CreditsText")
    leftBtn:SetTextColor(Color(255, 255, 255))
    leftBtn:SetSize(20, 20)
    leftBtn:SetPos(0, 18)
    leftBtn.Paint = function(self, w, h)
        local bgColor = Color(0, 0, 0, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end

    local rightBtn = vgui.Create("DButton", panel)
    rightBtn:SetText(">")
    rightBtn:SetFont("CreditsText")
    rightBtn:SetTextColor(Color(255, 255, 255))
    rightBtn:SetSize(20, 20)
    rightBtn:SetPos(280, 18)
    rightBtn.Paint = function(self, w, h)
        local bgColor = Color(0, 0, 0, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end

    local valueLabel = vgui.Create("DLabel", panel)
    valueLabel:SetSize(40, 20)
    valueLabel:SetPos(130, 32)
    valueLabel:SetTextColor(Color(255, 255, 255))
    valueLabel:SetContentAlignment(5)

    local function UpdateSlider(bar, x)
        local progress = math.Clamp(x / bar:GetWide(), 0, 1)
        local newValue = math.floor(min + progress * (max - min))
        RunConsoleCommand(cvarName, math.Round(newValue, 0))
    end

    local function UpdateValue(delta)
        local current = GetConVar(cvarName):GetInt()
        local newVal = math.Clamp(current + delta, min, max)
        RunConsoleCommand(cvarName, newVal)
    end

    sliderBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            local x, _ = self:CursorPos()
            UpdateSlider(self, x)
            self.IsDragging = true
        end
    end

    leftBtn.DoClick = function()
        UpdateValue(-1)
    end

    rightBtn.DoClick = function()
        UpdateValue(1)
    end

    sliderBar.Think = function(self)
        local val = GetConVar(cvarName):GetInt()
        valueLabel:SetText(val)
        if self.IsDragging and input.IsMouseDown(MOUSE_LEFT) then
            local x, _ = self:CursorPos()
            UpdateSlider(self, x)
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

local function CreateCustomComboBox(parent, x, y, labelText, cvarName, options, helpText)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(200, 200)
    panel:SetPos(x, y)
    panel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 0))
    end

    if helpText then
        panel:SetTooltip(helpText)
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetPos((200 - 150) / 2, 0)
    label:SetSize(150, 20)
    label:SetTextColor(Color(255, 255, 255))
    label:SetContentAlignment(5)

    local combo = vgui.Create("DPanel", panel)
    combo:SetSize(200, 30)
    combo:SetPos(0, 25)
    combo.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(90, 90, 90))
        local cvarValue = GetConVar(cvarName):GetInt()
        local index = math.Clamp(cvarValue + 1, 1, #options)
        local displayText = options[index] or "Unknown"
        draw.SimpleText(displayText, "DermaDefault", 10, h / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50))
    end
    dropdown:SetVisible(false)

    for i, option in ipairs(options) do
        local btn = vgui.Create("DButton", dropdown)
        btn:SetText(option)
        btn:SetPos(0, (i - 1) * 30)
        btn:SetSize(200, 30)
        btn:SetTextColor(Color(255, 255, 255))
        btn.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(100, 100, 100) or Color(50, 50, 50)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end
        btn.DoClick = function()
            local value = tostring(i - 1)
            RunConsoleCommand(cvarName, value)
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

concommand.Add("battlebeats_options", function(ply, cmd, args)
    local frame = vgui.Create("DFrame")
    frame:SetSize(600, 550)
    frame:Center()
    frame:SetTitle("BattleBeats Client Options")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:SetSizable(false)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 200))
    end
    
    BATTLEBEATS.optionsFrame = frame

    local tabPanel = vgui.Create("DPanel", frame)
    tabPanel:SetSize(frame:GetWide() - 20, 40)
    tabPanel:SetPos(10, 30)
    tabPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end

    local categories = {
        { name = "Sound", panel = nil },
        { name = "Notifications", panel = nil },
        { name = "M. Player", panel = nil },
        { name = "Misc", panel = nil }
    }

    local contentPanel = vgui.Create("DPanel", frame)
    contentPanel:SetSize(frame:GetWide() - 20, frame:GetTall() - 80)
    contentPanel:SetPos(10, 70)
    contentPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
    end

    local tabWidth = (frame:GetWide() - 20) / #categories

    for i, category in ipairs(categories) do
        local button = vgui.Create("DButton", tabPanel)
        button:SetText(category.name)
        button:SetPos((i - 1) * tabWidth, 0)
        button:SetSize(tabWidth, 40)
        button:SetTextColor(Color(255, 255, 255))
        button.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(100, 100, 100, 255) or Color(50, 50, 50, 255)
            if category.panel and category.panel:IsVisible() then
                bgColor = Color(40, 40, 40, 255)
            end
            draw.RoundedBoxEx(8, 0, 0, w, h, bgColor, true, true, false, false)
        end

        local panel = vgui.Create("DPanel", contentPanel)
        panel:SetSize(contentPanel:GetWide(), contentPanel:GetTall())
        panel:SetPos(0, 0)
        panel.Paint = function(self, w, h)
            draw.RoundedBoxEx(8, 0, 0, w, h, Color(40, 40, 40, 255), false, false, true, true)
        end
        panel:SetVisible(false)
        category.panel = panel

        if category.name == "Sound" then
            CreateCustomNumSlider(panel, (panel:GetWide() - 300) / 2, 10, "Master Volume", "battlebeats_volume", 0, 200)
            CreateCustomNumSlider(panel, (panel:GetWide() - 300) / 2, 50, "Ambient Volume", "battlebeats_volume_ambient", 0, 100)
            CreateCustomNumSlider(panel, (panel:GetWide() - 300) / 2, 90, "Combat Volume", "battlebeats_volume_combat", 0, 100)
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 150, "Enable Ambient", "battlebeats_enable_ambient")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 180, "Enable Combat", "battlebeats_enable_combat")
            CreateCustomComboBox(panel, (contentPanel:GetWide() / 2 - 100), 220, "On death behavior", "battlebeats_disable_mode", { "Nothing", "Mute completely", "Lower volume" })
        elseif category.name == "Notifications" then
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 4, 10, "Enable notification", "battlebeats_show_notification")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 1.4, 10, "Notification always visible", "battlebeats_persistent_notification", "The notification will remain visible for the entire duration of the music, instead of disappearing after a few seconds")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 4, 50, "Show progress bar", "battlebeats_show_status_bar", "Displays a progress bar for the current track (showing total time and current time) at the bottom of the notification")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 1.4, 50, "Show replay notification", "battlebeats_show_notification_after_continue", "Displays a notification even if the same track is replayed (e.g. after leaving combat before the wait time ends). \n(This is enabled by default if 'Notification always visible' is active)")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 4, 90, "Skip Nombat track names", "battlebeats_skip_nombat_names", "Hides track names like C7 or A2 when playing tracks from Nombat packs")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 1.4, 90, "Show pack name in notification", "battlebeats_show_notification_pack_name", "Shows the pack name of the currently played track in the notification")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 130, "Enable preview notification", "battlebeats_show_preview_notification", "Shows notification when you are previewing tracks")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 170, "Show notification visualizer", "battlebeats_show_notification_visualizer", "Show FFT bars in the track notification")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 210, "Visualizer amplitude smoothing", "battlebeats_visualizer_smooth", "Enable amplitude smoothing for the visualizer")
            CreateArrowStepper(panel, (panel:GetWide() - 300) / 2, 250, "Visualizer Boost", "battlebeats_visualizer_boost", 1, 20, "Multiplier for visualizer amplitude boost (used in log scale)")
            CreateArrowStepper(panel, (panel:GetWide() - 300) / 2, 300, "Notification X position", "battlebeats_notif_x", 0, ScrW(), "Default: " .. tostring(ScrW() - 310))
            CreateArrowStepper(panel, (panel:GetWide() - 300) / 2, 350, "Notification Y position", "battlebeats_notif_y", 0, ScrH(), "Default: " .. tostring(ScrH() / 6))
        elseif category.name == "M. Player" then
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 10, "Switch to current pack only", "battlebeats_exclusive_play", "When switching between ambient and combat, only tracks from the same pack will be used. When a track ends naturally, the next one will still be chosen randomly from all enabled packs")
            CreateArrowStepper(panel, (panel:GetWide() - 300) / 2, 50, "Ambient wait time (in seconds)", "battlebeats_ambient_wait_time", 1, 120, "Wait time defines how long the music player will wait before replacing the previous track with a new one")
            CreateArrowStepper(panel, (panel:GetWide() - 300) / 2, 100, "Combat wait time (in seconds)", "battlebeats_combat_wait_time", 1, 120, "Wait time defines how long the music player will wait before replacing the previous track with a new one")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 160, "Always continue previous track", "battlebeats_always_continue", "Skips the wait time and always resumes the previous track until it finishes playing")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 190, "NPC's fight triggers combat", "battlebeats_npc_combat", "Triggers combat when an NPC is targeting other NPCs or players")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 220, "Enable assigned tracks", "battlebeats_enable_assigned_tracks", "Plays assigned tracks when their NPCs are present")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 250, "Exclude assigned tracks", "battlebeats_exclude_mapped_tracks", "Tracks assigned to NPCs will not play when selecting random combat tracks")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 280, "Switch to lower priority", "battlebeats_switch_on_lower_priority", "A track with higher priority will switch to a lower priority (if available) when the NPC with that priority dies")
            CreateCustomComboBox(panel, (contentPanel:GetWide() / 2 - 100), 310, "Continue Mode", "battlebeats_continue_mode", { "Resume from last position", "Play simultaneously" }, "Resume from last position: the track will continue from where it left off before switching.\nPlay simultaneously: tracks continue playing in the background during switches (not actually audible - they just remain active in the background)")
        elseif category.name == "Misc" then
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 10, "NPC Combat requires LoS", "battlebeats_detection_mode", "LoS - Line of Sight. If enabled, combat will only trigger when you have visual contact with an enemy")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 40, "Auto Popup", "battlebeats_autopopup", "Automatically open the BattleBeats pack selector on startup if no packs are selected")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 70, "Load local packs", "battlebeats_load_local_packs", "Enables loading music packs directly from the addons/ folder without needing to upload them to Workshop. This will not work if Debug Mode is enabled\n(Not intended for testing sound packs - use debug mode for that instead)\n(Requires restart or packs reload)")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 100, "Debug Mode", "battlebeats_debug_mode", "Used for testing sound packs and debugging functions. Some features may be disabled while debug mode is active\n(Requires restart or packs reload)")
            CreateCustomCheckbox(panel, contentPanel:GetWide() / 2, 130, "Lower volume in menu", "battlebeats_lower_volume_in_menu", "Lowers volume in game/spawn menu ('escape' menu won't work in singleplayer - timers pause when menu is open)")
        end

        button.DoClick = function()
            for _, cat in ipairs(categories) do
                cat.panel:SetVisible(false)
            end
            category.panel:SetVisible(true)
        end

    end

    if categories[1].panel then
        categories[1].panel:SetVisible(true)
    end
end)