local function createCustomCheckbox(parent, x, y, labelText, cvarName, helpText)
    local panel = vgui.Create("DPanel", parent)
    panel:SetTall(20)
    panel:SetPos(0, y)
    panel.Paint = function() end

    local switch = vgui.Create("DPanel", panel)
    switch:SetSize(40, 20)

    local enabled = GetConVar(cvarName):GetBool()
    switch.KnobX = enabled and (40 - 16 - 2) or 2

    switch.Paint = function(self, w, h)
        local enabled = GetConVar(cvarName):GetBool()
        local targetX = enabled and (w - 16 - 2) or 2
        self.KnobX = Lerp(FrameTime() * 10, self.KnobX, targetX)
        local bgColor = enabled and Color(255, 210, 0) or Color(90, 90, 90)
        draw.RoundedBox(h / 2, 0, 0, w, h, bgColor)
        draw.RoundedBox(h, self.KnobX, 2, 16, 16, Color(230, 230, 230))
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

    local totalWidth = 40 + 8 + label:GetWide()
    panel:SetWide(totalWidth)
    panel:SetPos(x - totalWidth / 2, y)

    switch:SetPos(0, (panel:GetTall() - 20) / 2)
    label:SetPos(40 + 8, (panel:GetTall() - label:GetTall()) / 2)

    switch.OnCursorEntered = function(self) self:SetCursor("hand") end
    switch.OnCursorExited = function(self) self:SetCursor("arrow") end
    panel.OnCursorEntered = switch.OnCursorEntered
    panel.OnCursorExited = switch.OnCursorExited
    panel.OnMousePressed = switch.OnMousePressed

    return panel
end

local function createCustomNumSlider(parent, x, y, labelText, cvarName, min, max)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(300, 40)
    panel:SetPos(x, y)
    panel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 0))
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetPos((300 - 200) / 2, 0)
    label:SetSize(200, 20)
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

    sliderBar.OnCursorEntered = function(self)
        self:SetCursor("hand")
    end
    sliderBar.OnCursorExited = function(self)
        self:SetCursor("arrow")
    end

    return panel
end

local function createArrowStepper(parent, x, y, labelText, cvarName, min, max, helpText)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(300, 50)
    panel:SetPos(x, y)
    panel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 0))
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(labelText)
    label:SetPos((300 - 200) / 2, 0)
    label:SetSize(200, 20)
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

    local function updateSlider(bar, x)
        local progress = math.Clamp(x / bar:GetWide(), 0, 1)
        local newValue = math.floor(min + progress * (max - min))
        RunConsoleCommand(cvarName, math.Round(newValue, 0))
    end

    local function updateValue(delta)
        local current = GetConVar(cvarName):GetInt()
        local newVal = math.Clamp(current + delta, min, max)
        RunConsoleCommand(cvarName, newVal)
    end

    sliderBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            local x, _ = self:CursorPos()
            updateSlider(self, x)
            self.IsDragging = true
        end
    end

    leftBtn.DoClick = function()
        updateValue(-1)
    end

    rightBtn.DoClick = function()
        updateValue(1)
    end

    sliderBar.Think = function(self)
        local val = GetConVar(cvarName):GetInt()
        valueLabel:SetText(val)
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

local function createCustomComboBox(parent, x, y, labelText, cvarName, options, helpText)
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

local function createCustomButton(parent, x, y, labelText, cvarName, helpText)
    local button = vgui.Create("DButton", parent)
    button:SetSize(200, 30)
    button:SetPos(x - 100, y)
    button:SetText(labelText)
    button:SetTextColor(Color(255, 255, 255))

    button.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and Color(100, 100, 100) or Color(90, 90, 90)
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end

    if helpText then
        button:SetTooltip(helpText)
    end

    button.DoClick = function()
        RunConsoleCommand(cvarName)
    end

    return button
end

local function LerpColor(t, from, to)
    return Color(
        Lerp(t, from.r, to.r),
        Lerp(t, from.g, to.g),
        Lerp(t, from.b, to.b),
        Lerp(t, from.a or 255, to.a or 255)
    )
end

concommand.Add("battlebeats_options", function()
    local frame = vgui.Create("DFrame")
    frame:SetSize(600, 550)
    frame:Center()
    frame:SetTitle("#btb.ps.options.title")
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
        {name = "#btb.options.cat.sound", panel = nil},
        {name = "#btb.options.cat.notification", panel = nil},
        {name = "#btb.options.cat.subtitles", panel = nil},
        {name = "#btb.options.cat.music_player", panel = nil},
        {name = "#btb.options.cat.misc", panel = nil}
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
        button:SetFont("CreditsText")
        button:SetPos((i - 1) * tabWidth, 0)
        button:SetSize(tabWidth, 40)
        button:SetTextColor(Color(255, 255, 255))
        local hoverColor = Color(100, 100, 100, 255)
        local normalColor = Color(50, 50, 50, 255)
        local activeColor = Color(40, 40, 40, 255)
        button.currentColor = Color(50, 50, 50, 255)
        button.targetColor = Color(50, 50, 50, 255)
        button.Think = function(self)
            if self:IsHovered() then
                self.targetColor = hoverColor
            else
                self.targetColor = normalColor
            end
            self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
        end

        button.Paint = function(self, w, h)
            if category.panel and category.panel:IsVisible() then 
                draw.RoundedBoxEx(8, 0, 0, w, h, activeColor, true, true, false, false)
                return
            end
            draw.RoundedBoxEx(8, 0, 0, w, h, self.currentColor, true, true, false, false)
        end

        local panel = vgui.Create("DPanel", contentPanel)
        panel:SetSize(contentPanel:GetWide(), contentPanel:GetTall())
        panel:SetPos(0, 0)
        panel.Paint = function(self, w, h)
            draw.RoundedBoxEx(8, 0, 0, w, h, Color(40, 40, 40, 255), false, false, true, true)
        end
        panel:SetVisible(false)
        category.panel = panel

        local translation = language.GetPhrase("#btb.translated.by")
        local lang = GetConVar("gmod_language"):GetString()
        if lang ~= "en" and translation ~= "///" then
            local translationLabel = vgui.Create("DLabel", panel)
            translationLabel:SetText(language.GetPhrase("#btb.translated.by.label") .. translation)
            translationLabel:SetPos((contentPanel:GetWide() - 400) / 2, 420)
            translationLabel:SetSize(400, 20)
            translationLabel:SetTextColor(Color(80, 80, 80, 200))
            translationLabel:SetContentAlignment(5)
        end

        local versionlabel = vgui.Create("DLabel", panel)
        versionlabel:SetText(language.GetPhrase("#btb.options.version.label") .. BATTLEBEATS.currentVersion)
        versionlabel:SetPos((contentPanel:GetWide() - 150) / 2, 440)
        versionlabel:SetSize(150, 20)
        versionlabel:SetTextColor(Color(80, 80, 80, 200))
        versionlabel:SetContentAlignment(5)

        local contentPanel_2 = contentPanel:GetWide() / 2
        local contentPanel_NumSlider = (panel:GetWide() - 300) / 2
        local btbDefault = language.GetPhrase("btb.options.noti.default_pos")

        if category.name == "#btb.options.cat.sound" then
            createCustomNumSlider(panel, contentPanel_NumSlider, 10, "#btb.options.snd.master_volume", "battlebeats_volume", 0, 200)
            createCustomNumSlider(panel, contentPanel_NumSlider, 50, "#btb.options.snd.ambient_volume", "battlebeats_volume_ambient", 0, 100)
            createCustomNumSlider(panel, contentPanel_NumSlider, 90, "#btb.options.snd.combat_volume", "battlebeats_volume_combat", 0, 100)
            createCustomCheckbox(panel, contentPanel_2, 150, "#btb.options.snd.enable_ambient", "battlebeats_enable_ambient")
            createCustomCheckbox(panel, contentPanel_2, 180, "#btb.options.snd.enable_combat", "battlebeats_enable_combat")
            createCustomCheckbox(panel, contentPanel_2, 210, "#btb.spawnmenu.general.force_combat", "battlebeats_force_combat", "#btb.spawnmenu.general.force_combat_tip")
            createCustomComboBox(panel, (contentPanel_2 - 100), 250, "#btb.spawnmenu.general.combo", "battlebeats_disable_mode", { "#btb.spawnmenu.general.combo_1", "#btb.spawnmenu.general.combo_2", "#btb.spawnmenu.general.combo_3" })
        elseif category.name == "#btb.options.cat.notification" then
            createCustomCheckbox(panel, contentPanel:GetWide() / 4, 10, "#btb.options.noti.enable_noti", "battlebeats_show_notification")
            createCustomCheckbox(panel, contentPanel:GetWide() / 1.4, 10, "#btb.options.noti.noti_always_vis", "battlebeats_persistent_notification", "#btb.options.noti.noti_always_vis_tip")
            createCustomCheckbox(panel, contentPanel:GetWide() / 4, 40, "#btb.options.noti.progress_bar", "battlebeats_show_status_bar", "#btb.options.noti.progress_bar_tip")
            createCustomCheckbox(panel, contentPanel:GetWide() / 1.4, 40, "#btb.options.noti.replay", "battlebeats_show_notification_after_continue", "#btb.options.noti.replay_tip")
            createCustomCheckbox(panel, contentPanel:GetWide() / 4, 70, "#btb.options.noti.show_nombat", "battlebeats_skip_nombat_names", "#btb.options.noti.show_nombat_tip")
            createCustomCheckbox(panel, contentPanel:GetWide() / 1.4, 70, "#btb.options.noti.pack_name", "battlebeats_show_notification_pack_name", "#btb.options.noti.pack_name_tip")
            createCustomCheckbox(panel, contentPanel_2, 100, "#btb.options.noti.preview", "battlebeats_show_preview_notification", "#btb.options.noti.preview_tip")
            createCustomCheckbox(panel, contentPanel_2, 130, "#btb.options.noti.visualizer", "battlebeats_show_notification_visualizer", "#btb.options.noti.visualizer_tip")
            createCustomCheckbox(panel, contentPanel_2, 160, "#btb.options.noti.visualizer_smooth", "battlebeats_visualizer_smooth", "#btb.options.noti.visualizer_smooth_tip")
            createArrowStepper(panel, contentPanel_NumSlider, 200, "#btb.options.noti.visualizer_boost", "battlebeats_visualizer_boost", 1, 20, "#btb.options.noti.visualizer_boost_tip")
            createArrowStepper(panel, contentPanel_NumSlider, 250, "#btb.options.noti.x_pos", "battlebeats_notif_x", 0, ScrW(), btbDefault .. tostring(ScrW() - 310))
            createArrowStepper(panel, contentPanel_NumSlider, 300, "#btb.options.noti.y_pos", "battlebeats_notif_y", 0, ScrH(), btbDefault .. tostring(ScrH() / 6))
        elseif category.name == "#btb.options.cat.subtitles" then
            createCustomCheckbox(panel, contentPanel_2, 10, "#btb.options.sub.enable_sub", "battlebeats_subtitles_enabled")
        elseif category.name == "#btb.options.cat.music_player" then
            createCustomCheckbox(panel, contentPanel_2, 10, "#btb.options.mplayer.curr_pack_only", "battlebeats_exclusive_play", "#btb.options.mplayer.curr_pack_only_tip")
            createArrowStepper(panel, contentPanel_NumSlider, 50, "#btb.options.mplayer.a_wait_time", "battlebeats_ambient_wait_time", 1, 120, "#btb.options.mplayer.wait_time_tip")
            createArrowStepper(panel, contentPanel_NumSlider, 100, "#btb.options.mplayer.c_wait_time", "battlebeats_combat_wait_time", 1, 120, "#btb.options.mplayer.wait_time_tip")
            createCustomCheckbox(panel, contentPanel_2, 160, "#btb.options.mplayer.always_continue", "battlebeats_always_continue", "#btb.options.mplayer.always_continue_tip")
            createCustomCheckbox(panel, contentPanel_2, 190, "#btb.spawnmenu.general.npc_combat", "battlebeats_npc_combat", "#btb.spawnmenu.general.npc_combat_tip")
            createCustomCheckbox(panel, contentPanel_2, 220, "#btb.spawnmenu.general.enable_assigned", "battlebeats_enable_assigned_tracks", "#btb.spawnmenu.general.enable_assigned_tip")
            createCustomCheckbox(panel, contentPanel_2, 250, "#btb.options.mplayer.exclude_assigned", "battlebeats_exclude_mapped_tracks", "#btb.options.mplayer.exclude_assigned_tip")
            createCustomCheckbox(panel, contentPanel_2, 280, "#btb.options.mplayer.switch_to_lower", "battlebeats_switch_on_lower_priority", "#btb.options.mplayer.switch_to_lower_tip")
            createCustomComboBox(panel, (contentPanel_2 - 100), 310, "#btb.options.mplayer.combo", "battlebeats_continue_mode", { "#btb.options.mplayer.combo_1", "#btb.options.mplayer.combo_2" }, "#btb.options.mplayer.combo_tip")
        elseif category.name == "#btb.options.cat.misc" then
            createCustomCheckbox(panel, contentPanel_2, 10, "#btb.options.misc.npc_los", "battlebeats_detection_mode", "#btb.spawnmenu.server.enable_pvp_los_tip")
            createCustomCheckbox(panel, contentPanel_2, 40, "#btb.options.misc.auto_popup", "battlebeats_autopopup", "#btb.options.misc.auto_popup_tip")
            createCustomCheckbox(panel, contentPanel_2, 70, "#btb.options.misc.load_local", "battlebeats_load_local_packs", "#btb.options.misc.load_local_tip")
            createCustomCheckbox(panel, contentPanel_2, 100, "#btb.options.misc.debug_mode", "battlebeats_debug_mode", "#btb.options.misc.debug_mode_tip")
            createCustomCheckbox(panel, contentPanel_2, 130, "#btb.options.misc.lower_vol_in_menu", "battlebeats_lower_volume_in_menu", "#btb.options.misc.lower_vol_in_menu_tip")
            createCustomCheckbox(panel, contentPanel_2, 160, "#btb.options.misc.load_am_sus", "battlebeats_load_am_suspense", "#btb.options.misc.load_am_sus_tip")
            createCustomCheckbox(panel, contentPanel_2, 190, "#btb.options.misc.toggle_ui", "battlebeats_context_ui_toogle", "#btb.options.misc.toggle_ui_tip")
            createCustomButton(panel, contentPanel_2, 220, "#btb.options.misc.reload_packs", "battlebeats_reload_packs")
            createCustomButton(panel, contentPanel_2, 260, "#btb.options.misc.open_guide", "battlebeats_guide")
            createCustomButton(panel, contentPanel_2, 300, "#btb.options.misc.restore", "battlebeats_restore_defaults")
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

local defaultX = tostring(ScrW() - 310)
local defaultY = tostring(ScrH() / 6)
concommand.Add("battlebeats_restore_defaults", function()
    RunConsoleCommand("battlebeats_detection_mode", "1")
    RunConsoleCommand("battlebeats_npc_combat", "0")

    RunConsoleCommand("battlebeats_autopopup", "1")
    RunConsoleCommand("battlebeats_load_local_packs", "0")
    RunConsoleCommand("battlebeats_load_am_suspense", "0")

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

    RunConsoleCommand("battlebeats_subtitles_enabled", "1")
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
end)