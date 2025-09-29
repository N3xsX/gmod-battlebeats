local frame
local assignFrame
local isLooping = false
local skipExcluded = false

local volumeSet = GetConVar("battlebeats_volume")
local persistentNotification = GetConVar("battlebeats_persistent_notification")
local showPreviewNotification = GetConVar("battlebeats_show_preview_notification")

--MARK:Steamworks info
local function CreateInfoPanel(panel, packData)
    if not IsValid(panel) then return end
    panel.infoPanels = {}
    local function CreateInfoBoxes(panel, size, date, ownerName)
        if not IsValid(panel) then return end
        local buttonWidth, buttonHeight, spacing = 200, 30, 40
        local panelWidth = panel:GetWide()
        local totalWidth = buttonWidth * 3 + spacing * 2
        local startX = (panelWidth - totalWidth) / 2
        local y = 120

        local function AddInfoBox(text, x)
            local box = vgui.Create("DPanel", panel)
            box:SetSize(buttonWidth, buttonHeight)
            box:SetPos(x, y)
            box.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60))
            end

            local label = vgui.Create("DLabel", box)
            label:SetText(text)
            label:SetFont("DermaDefault")
            label:SetTextColor(Color(200, 200, 200))
            label:SizeToContents()
            label:Center()

            table.insert(panel.infoPanels, box)
        end

        AddInfoBox("Size: " .. size, startX)
        AddInfoBox("Created: " .. date, startX + buttonWidth + spacing)
        AddInfoBox("Author: " .. ownerName, startX + (buttonWidth + spacing) * 2)
    end
    CreateInfoBoxes(panel, "Loading...", "Loading...", "Loading...")
    if packData.wsid then
        steamworks.FileInfo(packData.wsid, function(result)
            if not result then
                CreateInfoBoxes(panel, "N/A", "N/A", "N/A")
                return
            end

            local size = result.size and string.NiceSize(result.size) or "N/A"
            local date = result.created and os.date("%Y-%m-%d", result.created) or "N/A"
            local ownerName = result.ownername or "N/A"

            CreateInfoBoxes(panel, size, date, ownerName)
        end)
    else
        CreateInfoBoxes(panel, "N/A", "N/A", "N/A")
    end
end

--MARK:Main UI
local function OpenMusicMenu()
    if IsValid(frame) then return end
    local changesMade = false
    local selectedRow = nil
    frame = vgui.Create("DFrame")
    BATTLEBEATS.frame = frame
    frame:SetSize(1000, 700)
    frame:SetSizable(false)
    frame:Center()
    frame:SetTitle("BattleBeats Music Packs")
    frame:MakePopup()
    frame:SetBackgroundBlur(true)
    frame.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 200))
    end
    frame.isMinimalized = false

    local versionLabel = vgui.Create("DLabel", frame)
    versionLabel:SetFont("DermaDefault")
    versionLabel:SetText(BATTLEBEATS.currentVersion)
    versionLabel:SetTextColor(Color(200, 200, 200))
    versionLabel:SetPos(870, 3)

    for _, child in ipairs(frame:GetChildren()) do -- cheesy way to enable minimalize button
        if child:GetClassName() == "Label" then
            local x = child:GetPos()
            if x > 900 and x < 910 then
                child:SetEnabled(true)
                child.OnMousePressed = function()
                    frame:SetVisible(false)
                    frame.isMinimalized = true
                end
            end
        end
    end

    local scrollPanel = vgui.Create("DScrollPanel", frame)
    scrollPanel:SetSize(980, 600)
    scrollPanel:SetPos(10, 30)

    local scrollBar = scrollPanel:GetVBar() -- custom scroll bar
    scrollBar.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40, 200))
    end
    scrollBar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(60, 60, 60, 255))
    end
    scrollBar.btnUp.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(60, 60, 60, 255))
    end
    scrollBar.btnDown.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(60, 60, 60, 255))
    end

    --MARK:Option button
    local optionsButton = vgui.Create("DButton", frame)
    optionsButton:SetSize(340, 40)
    optionsButton:SetPos(650, 650)
    optionsButton:SetText("Options")
    optionsButton:SetFont("CreditsText")
    optionsButton:SetTextColor(Color(255, 255, 255))
    optionsButton.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and Color(80, 80, 80, 255) or Color(70, 70, 70, 255)
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end
    optionsButton.OnCursorEntered = function(self)
        surface.PlaySound("ui/buttonrollover.wav")
    end
    optionsButton.DoClick = function()
        RunConsoleCommand("battlebeats_options")
    end

    --MARK:Volume bar
    local volumePanel = vgui.Create("DPanel", frame)
    volumePanel:SetSize(330, 40)
    volumePanel:SetPos(10, 650)
    volumePanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 255))
    end
    local volumeLabel = vgui.Create("DLabel", volumePanel)
    volumeLabel:SetText("MASTER VOLUME")
    volumeLabel:SetFont("DermaDefaultBold")
    volumeLabel:SetTextColor(Color(255, 255, 255))
    volumeLabel:SizeToContents()
    local labelWidth = volumeLabel:GetWide()
    volumeLabel:SetPos((volumePanel:GetWide() - labelWidth) / 2, 4)
    local volumeBar = vgui.Create("DPanel", volumePanel)
    volumeBar:SetSize(300, 8)
    volumeBar:SetPos(15, 22)
    volumeBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(90, 90, 90))
        local cvar = volumeSet
        local progress = cvar:GetInt() / 200
        draw.RoundedBox(4, 0, 0, w * progress, h, Color(50, 255, 50))
    end

    local dotPanel = vgui.Create("DPanel", volumePanel)
    dotPanel:SetMouseInputEnabled(false)
    dotPanel:SetSize(12, 12)
    dotPanel.Paint = function(self, w, h)
        local cvar = volumeSet
        local progress = cvar:GetInt() / 200
        if progress >= 0 then
            draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255))
        end
    end
    dotPanel.Think = function(self)
        local cvar = volumeSet
        local progress = cvar:GetInt() / 200
        if progress > 1 then progress = 1 end
        local barWidth = volumeBar:GetWide()
        local dotX = 15 + barWidth * progress - 6
        local dotY = 22 + volumeBar:GetTall() / 2 - 6
        self:SetPos(dotX, dotY)
    end

    local function UpdateVolume(bar, x)
        local progress = math.Clamp(x / bar:GetWide(), 0, 1)
        local newValue = math.floor(progress * 200)
        volumeSet:SetInt(newValue)
    end

    volumeBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            local x, _ = self:CursorPos()
            UpdateVolume(self, x)
            self.IsDragging = true
        end
    end
    volumeBar.Think = function(self)
        if self.IsDragging and input.IsMouseDown(MOUSE_LEFT) then
            local x, _ = self:CursorPos()
            UpdateVolume(self, x)
        elseif self.IsDragging and not input.IsMouseDown(MOUSE_LEFT) then
            self.IsDragging = false
        end
    end

    volumeBar.OnCursorEntered = function(self)
        self:SetCursor("hand")
    end
    volumeBar.OnCursorExited = function(self)
        self:SetCursor("arrow")
    end

    --MARK:Save button
    local saveButton = vgui.Create("DButton", frame)
    saveButton:SetSize(290, 40)
    saveButton:SetPos(350, 650)
    saveButton:SetText("Done")
    saveButton:SetFont("CreditsText")
    saveButton:SetTextColor(Color(255, 255, 255))
    saveButton.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and Color(80, 80, 80, 255) or Color(70, 70, 70, 255)
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end
    saveButton.OnCursorEntered = function(self)
        surface.PlaySound("ui/buttonrollover.wav")
    end

    --MARK:Music player panel
    local playerPanel = vgui.Create("DPanel", frame)
    playerPanel:SetSize(980, 170)
    playerPanel:SetPos(10, 470)
    playerPanel:SetVisible(false)
    playerPanel.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(30, 30, 30, 240))
    end

    local playPause = vgui.Create("DButton", playerPanel)
    playPause:SetSize(50, 50)
    playPause:SetPos((playerPanel:GetWide() / 2) - 28, 50)
    playPause:SetText("▶")
    playPause:SetFont("DermaLarge")
    playPause:SetTextColor(Color(255, 255, 255))
    playPause.Paint = function(self, w, h)
        local bgColor = Color(30, 30, 30, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end
    playPause.Think = function()
        if playPause:GetText() == "▶" then
            playPause:SetPos((playerPanel:GetWide() / 2) - 28, 55)
        else
            playPause:SetPos((playerPanel:GetWide() / 2) - 28, 50)
        end
    end

    local currentTimeLabel = vgui.Create("DLabel", playerPanel)
    currentTimeLabel:SetPos(50, 111)
    currentTimeLabel:SetSize(90, 20)
    currentTimeLabel:SetText("0:00")
    currentTimeLabel:SetFont("DermaDefaultBold")
    currentTimeLabel:SetTextColor(Color(255, 255, 255))

    local totalTimeLabel = vgui.Create("DLabel", playerPanel)
    totalTimeLabel:SetPos(850, 111)
    totalTimeLabel:SetSize(90, 20)
    totalTimeLabel:SetText("0:00")
    totalTimeLabel:SetFont("DermaDefaultBold")
    totalTimeLabel:SetTextColor(Color(255, 255, 255))
    totalTimeLabel:SetContentAlignment(6)

    local trackNameLabel = vgui.Create("DLabel", playerPanel)
    trackNameLabel:SetPos(45, 20)
    trackNameLabel:SetSize(880, 30)
    trackNameLabel:SetText("No Track Selected")
    trackNameLabel:SetFont("DermaLarge")
    trackNameLabel:SetTextColor(Color(255, 255, 255))
    trackNameLabel:SetContentAlignment(5)

    local loopBtn = vgui.Create("DButton", playerPanel)
    loopBtn:SetSize(40, 40)
    loopBtn:SetPos((playerPanel:GetWide() / 2) + 85, 60)
    loopBtn:SetText("↻")
    loopBtn:SetFont("DermaLarge")
    loopBtn:SetTextColor(Color(100, 100, 100))
    loopBtn.Paint = function(self, w, h)
        local bgColor = Color(30, 30, 30, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end
    loopBtn:SetTooltip("Loop Disabled")
    loopBtn.DoClick = function()
        isLooping = not isLooping
        if isLooping then
            loopBtn:SetTextColor(Color(255, 255, 255))
            loopBtn:SetTooltip("Loop Enabled")
        else
            loopBtn:SetTextColor(Color(100, 100, 100))
            loopBtn:SetTooltip("Loop Disabled")
        end
    end

    local skipExcludedBtn = vgui.Create("DButton", playerPanel)
    skipExcludedBtn:SetSize(40, 40)
    skipExcludedBtn:SetPos((playerPanel:GetWide() / 2) - 130, 60)
    skipExcludedBtn:SetText("⇅")
    skipExcludedBtn:SetFont("DermaLarge")
    skipExcludedBtn:SetTextColor(Color(255, 255, 255))
    skipExcludedBtn.Paint = function(self, w, h)
        local bgColor = Color(30, 30, 30, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end
    skipExcludedBtn:SetTooltip("Playing all")
    skipExcludedBtn.DoClick = function()
        skipExcluded = not skipExcluded
        if skipExcluded then
            skipExcludedBtn:SetTextColor(Color(100, 100, 100))
            skipExcludedBtn:SetTooltip("Skipping Excluded Tracks")
        else
            skipExcludedBtn:SetTextColor(Color(255, 255, 255))
            skipExcludedBtn:SetTooltip("Playing all")
        end
    end

    --MARK:Next/Previous track
    function BATTLEBEATS.SwitchPreviewTrack(direction)
        if not BATTLEBEATS.currentPreviewTrack or not BATTLEBEATS.musicPacks then return end

        local currentPack = nil
        local trackType = nil
        for packName, packData in pairs(BATTLEBEATS.musicPacks) do -- identify which pack and type the current preview track belongs to
            if istable(packData.ambient) and table.HasValue(packData.ambient, BATTLEBEATS.currentPreviewTrack) then
                currentPack = packName
                trackType = "ambient"
                break
            elseif istable(packData.combat) and table.HasValue(packData.combat, BATTLEBEATS.currentPreviewTrack) then
                currentPack = packName
                trackType = "combat"
                break
            end
        end
        if not currentPack or not trackType then -- fallback to first track if current preview track is invalid
            local tracks = BATTLEBEATS.musicPacks[currentPack] and BATTLEBEATS.musicPacks[currentPack][trackType] or {}
            if #tracks > 0 then
                BATTLEBEATS.currentPreviewTrack = tracks[1]
            else
                return
            end
        end

        local tracks = BATTLEBEATS.musicPacks[currentPack][trackType] or {}

        local includedTracks, excluded = {}, {} -- separate included and excluded tracks based on exclusion list
        for _, track in ipairs(tracks) do
            if not BATTLEBEATS.excludedTracks[track] then
                table.insert(includedTracks, track)
            else
                table.insert(excluded, track)
            end
        end

        local function SortFavorites(list)
            local favorites, nonFavorites = {}, {}
            for _, track in ipairs(list) do
                if BATTLEBEATS.favoriteTracks[track] then
                    table.insert(favorites, track)
                else
                    table.insert(nonFavorites, track)
                end
            end

            local sorted = {}
            for _, t in ipairs(favorites) do table.insert(sorted, t) end
            for _, t in ipairs(nonFavorites) do table.insert(sorted, t) end
            return sorted
        end

        local trackList = SortFavorites(tracks)
        local currentIndex = table.KeyFromValue(trackList, BATTLEBEATS.currentPreviewTrack)
        if not currentIndex then return end

        local totalTracks = #trackList
        local newIndex = currentIndex

        if skipExcluded then -- find next non-excluded track if skipExcluded is enabled
            for i = 1, totalTracks do
                newIndex = newIndex + direction
                if newIndex < 1 then newIndex = totalTracks end
                if newIndex > totalTracks then newIndex = 1 end

                local candidate = trackList[newIndex]
                if not BATTLEBEATS.excludedTracks[candidate] then
                    BATTLEBEATS.currentPreviewTrack = candidate
                    break
                end
            end
            if BATTLEBEATS.excludedTracks[BATTLEBEATS.currentPreviewTrack] then -- fallback in case all are excluded
                newIndex = currentIndex + direction
                if newIndex < 1 then newIndex = totalTracks end
                if newIndex > totalTracks then newIndex = 1 end
                BATTLEBEATS.currentPreviewTrack = trackList[newIndex]
            end
        else -- skip logic disabled, cycle to next/previous
            newIndex = currentIndex + direction
            if newIndex < 1 then newIndex = totalTracks end
            if newIndex > totalTracks then newIndex = 1 end
            BATTLEBEATS.currentPreviewTrack = trackList[newIndex]
        end

        BATTLEBEATS.PlayNextTrackPreview(BATTLEBEATS.currentPreviewTrack, nil, false, function ()
            BATTLEBEATS.SwitchPreviewTrack(direction)
        end)
        local trackName = BATTLEBEATS.FormatTrackName(BATTLEBEATS.currentPreviewTrack)
        trackNameLabel:SetText(trackName)
        playPause:SetText("⏸")
        if IsValid(scrollPanel) then
            local rows = scrollPanel:GetCanvas():GetChildren()
            for _, row in ipairs(rows) do
                if row.trackPath == BATTLEBEATS.currentPreviewTrack then
                    selectedRow = row
                    scrollPanel:ScrollToChild(row)
                    break
                end
            end
        end
    end

    --MARK:Next/Prev buttons
    local prevTrackBtn = vgui.Create("DButton", playerPanel)
    prevTrackBtn:SetSize(50, 50)
    prevTrackBtn:SetPos((playerPanel:GetWide() / 2) - 88, 50)
    prevTrackBtn:SetText("⏮")
    prevTrackBtn:SetFont("DermaLarge")
    prevTrackBtn:SetTextColor(Color(255, 255, 255))
    prevTrackBtn.Paint = function(self, w, h)
        local bgColor = Color(30, 30, 30, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end
    prevTrackBtn.DoClick = function()
        BATTLEBEATS.SwitchPreviewTrack(-1)
    end
    prevTrackBtn:SetTooltip("Previous Track")

    local nextTrackBtn = vgui.Create("DButton", playerPanel)
    nextTrackBtn:SetSize(50, 50)
    nextTrackBtn:SetPos((playerPanel:GetWide() / 2) + 28, 50)
    nextTrackBtn:SetText("⏭")
    nextTrackBtn:SetFont("DermaLarge")
    nextTrackBtn:SetTextColor(Color(255, 255, 255))
    nextTrackBtn.Paint = function(self, w, h)
        local bgColor = Color(30, 30, 30, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end
    nextTrackBtn.DoClick = function()
        BATTLEBEATS.SwitchPreviewTrack(1)
    end
    nextTrackBtn:SetTooltip("Next Track")
    --MARK:Player bars
    local hoverTimeDisplay = nil
    local progressBar = vgui.Create("DPanel", playerPanel)
    progressBar:SetSize(800, 20)
    progressBar:SetPos(90, 110)
    progressBar.Paint = function(self, w, h)
        local progressBarX, progressBarY = 0, h / 2 - 2
        local progressBarWidth, progressBarHeight = w, 8
        draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth, progressBarHeight, Color(90, 90, 90))

        local currentTime = IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetTime() or 0
        local trackDuration = IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetLength() or 0
        local progress = trackDuration > 0 and math.Clamp(currentTime / trackDuration, 0, 1) or 0

        draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth * progress, progressBarHeight, Color(50, 255, 50))

        if self:IsHovered() and trackDuration > 0 then
            local mx, _ = self:CursorPos()
            local hoverProgress = math.Clamp(mx / w, 0, 1)
            local hoverTime = hoverProgress * trackDuration
            hoverTimeDisplay = {
                text = BATTLEBEATS.FormatTime(hoverTime),
                x = self:LocalToScreen(mx, 0)
            }
        else
            hoverTimeDisplay = nil
        end
    end

    playerPanel.PaintOver = function(self, w, h)
        if hoverTimeDisplay then
            local lx, _ = self:ScreenToLocal(hoverTimeDisplay.x, 0)
            local y = progressBar.y - 8
            draw.SimpleText(hoverTimeDisplay.text, "DermaDefaultBold", lx, y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
    end

    progressBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT and IsValid(BATTLEBEATS.currentPreviewStation) then
            local x, _ = self:CursorPos()
            local progress = math.Clamp(x / self:GetWide(), 0, 1)
            local len = BATTLEBEATS.currentPreviewStation:GetLength()
            if len > 0 then
                local newTime = progress * len
                BATTLEBEATS.currentPreviewStation:SetTime(newTime, true)
                currentTimeLabel:SetText(BATTLEBEATS.FormatTime(newTime))
            end
        end
    end

    progressBar.Think = function(self)
        if not IsValid(BATTLEBEATS.currentPreviewStation) then return end
        local len = BATTLEBEATS.currentPreviewStation:GetLength()
        local pos = BATTLEBEATS.currentPreviewStation:GetTime()

        if len > 0 then
            currentTimeLabel:SetText(BATTLEBEATS.FormatTime(pos))
            totalTimeLabel:SetText(BATTLEBEATS.FormatTime(len))
        end
    end

    progressBar.OnCursorEntered = function(self)
        self:SetCursor("hand")
    end
    progressBar.OnCursorExited = function(self)
        self:SetCursor("arrow")
    end

    local progressDot = vgui.Create("DPanel", progressBar)
    progressDot:SetSize(12, 12)
    progressDot:SetMouseInputEnabled(false)
    progressDot.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255))
    end

    progressDot.Think = function(self)
        if not IsValid(BATTLEBEATS.currentPreviewStation) then return end
        local currentTime = BATTLEBEATS.currentPreviewStation:GetTime()
        local trackDuration = BATTLEBEATS.currentPreviewStation:GetLength()
        if trackDuration <= 0 then return end

        local progress = math.Clamp(currentTime / trackDuration, 0, 1)
        local barWidth = progressBar:GetWide()
        local dotX = barWidth * progress - self:GetWide() / 2
        local dotY = progressBar:GetTall() / 2 - self:GetTall() / 2 + 2
        self:SetPos(dotX, dotY)
    end

    playPause.DoClick = function()
        if not IsValid(BATTLEBEATS.currentPreviewStation) then
            print("[BattleBeats Debug] No track loaded on play/pause!")
            return
        end

        if BATTLEBEATS.currentPreviewStation:GetState() == GMOD_CHANNEL_PLAYING then
            BATTLEBEATS.currentPreviewStation:Pause()
            playPause:SetText("▶")
            if showPreviewNotification:GetBool() then BATTLEBEATS.HideNotification() end
        else
            BATTLEBEATS.currentPreviewStation:Play()
            playPause:SetText("⏸")
            if showPreviewNotification:GetBool() then BATTLEBEATS.ShowTrackNotification(BATTLEBEATS.currentPreviewTrack, false, true) end
        end
    end
    --MARK:Tracks list
    local headerExpanded = false
    local function CreateTrackList(parent, trackType, selectedPack)
        parent:Clear()
        selectedRow = nil
        local function AddTrackRow(track, excluded, isFavorite)
            local trackName = BATTLEBEATS.FormatTrackName(track)
            local row = vgui.Create("DPanel", parent)
            row:SetSize(0, 50)
            row:Dock(TOP)
            row:DockMargin(0, 5, 13, 3)
            row.trackPath = track
            row.textX = 10
            row.isScrolling = false
            row.scrollResetTime = 0

            surface.SetFont("DermaLarge")
            local textWidth = surface.GetTextSize(isFavorite and "★ " .. trackName or trackName)
            local panelWidth = 820
            local scrollSpeed = 60

            local npcAssigned = BATTLEBEATS.npcTrackMappings[track] ~= nil
            local offsetAssigned = BATTLEBEATS.trackOffsets[track] ~= nil
            if npcAssigned then
                local tooltipFrame = vgui.Create("DPanel", row)
                tooltipFrame:SetSize(16, 16)
                tooltipFrame:SetPos(840, 17)
                tooltipFrame:SetPaintBackground(false)
                tooltipFrame:SetTooltip("This track has an assigned NPC")

                local npcIcon = vgui.Create("DImage", tooltipFrame)
                npcIcon:SetSize(16, 16)
                npcIcon:SetPos(0, 0)
                npcIcon:SetImage("icon16/user.png")
            end
            if offsetAssigned then
                local tooltipFrame = vgui.Create("DPanel", row)
                tooltipFrame:SetSize(16, 16)
                if not npcAssigned then
                    tooltipFrame:SetPos(840, 17)
                else
                    tooltipFrame:SetPos(820, 17)
                end
                tooltipFrame:SetPaintBackground(false)
                tooltipFrame:SetTooltip("This track has an assigned offset")

                local offsetIcon = vgui.Create("DImage", tooltipFrame)
                offsetIcon:SetSize(16, 16)
                offsetIcon:SetPos(0, 0)
                offsetIcon:SetImage("icon16/time.png")
            end

            local customCheckbox = vgui.Create("DPanel", row)
            customCheckbox:SetSize(80, 20)
            customCheckbox:SetPos(860, 15)

            local targetColor = excluded and Color(255, 0, 0) or Color(0, 255, 0)
            customCheckbox.OnCursorEntered = function(self)
                self:SetCursor("hand")
            end
            customCheckbox.OnCursorExited = function(self)
                self:SetCursor("arrow")
            end

            local checkboxText = vgui.Create("DLabel", customCheckbox)
            checkboxText:SetFont("DermaDefaultBold")
            checkboxText:SetText(excluded and "✖ Excluded" or "✔ Included")
            checkboxText:SetTextColor(Color(255, 255, 255))
            checkboxText:Dock(FILL)
            checkboxText:SetContentAlignment(5)
            customCheckbox:SetTooltip(excluded and "Excluded tracks won’t be selected by the music player" or "Included packs play normally")
            customCheckbox:SetBackgroundColor(targetColor)

            local function updateCheckboxVisual()
                checkboxText:SetText(excluded and "✖ Excluded" or "✔ Included")
                customCheckbox:SetTooltip(excluded and "Excluded tracks won’t be selected by the music player" or "Included packs play normally")
                customCheckbox:SetBackgroundColor(excluded and Color(255, 0, 0) or Color(0, 255, 0))
                surface.PlaySound(excluded and "btb_button_disable.mp3" or "btb_button_enable.mp3")
            end

            customCheckbox.OnMousePressed = function(self, mousecode)
                excluded = not excluded
                BATTLEBEATS.excludedTracks[track] = excluded
                changesMade = true
                BATTLEBEATS.SaveExcludedTracks()
                updateCheckboxVisual()
            end

            row.OnMousePressed = function(self, keyCode)
                if keyCode == MOUSE_LEFT then
                    selectedRow = row
                end
            end

            row.OnCursorEntered = function(self)
                surface.PlaySound("ui/buttonrollover.wav")
                self:SetCursor("hand")
                self.isScrolling = textWidth > panelWidth
            end
            row.OnCursorExited = function(self)
                self:SetCursor("arrow")
                self.isScrolling = false
                self.scrollResetTime = CurTime()
            end

            row.Paint = function(self, w, h)
                local isSelected = (self == selectedRow)
                local bg
                if isSelected then
                    bg = Color(80, 80, 80, 255)
                elseif self:IsHovered() then
                    bg = Color(60, 60, 60, 200)
                else
                    bg = Color(50, 50, 50, 200)
                end
                draw.RoundedBox(4, 0, 0, w, h, bg)
                local displayName = isFavorite and "★ " .. trackName or trackName
                if self.isScrolling and textWidth > panelWidth then
                    self.textX = self.textX - (scrollSpeed * FrameTime())
                    local maxScroll = -(textWidth - panelWidth)
                    if self.textX < maxScroll then
                        self.textX = maxScroll
                    end
                elseif not self.isScrolling and self.textX < 10 then
                    local timeSinceExit = CurTime() - self.scrollResetTime
                    self.textX = Lerp(math.min(timeSinceExit * 0.2, 1), self.textX, 10)
                end

                local screenX, screenY = self:LocalToScreen(0, 0)
                render.SetScissorRect(screenX, screenY, screenX + panelWidth, screenY + h, true)
                draw.SimpleText(displayName, "DermaLarge", self.textX, h / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER)
                render.SetScissorRect(0, 0, 0, 0, false)
            end

            --MARK:Track list player
            row.OnMouseReleased = function(self, keyCode)
                if keyCode == MOUSE_LEFT then
                    changesMade = true
                    if not gui.IsGameUIVisible() or not game.SinglePlayer() then
                        if track == BATTLEBEATS.currentPreviewTrack then return end
                        if not playerPanel:IsVisible() then
                            playerPanel:SetAlpha(0)
                            playerPanel:AlphaTo(255, 0.3, 0)
                        end
                        playerPanel:SetVisible(true)
                        scrollPanel:SetSize(980, 430)
                        playPause:SetText("⏸")
                        currentTimeLabel:SetText("0:00")
                        totalTimeLabel:SetText("0:00")
                        trackNameLabel:SetText(trackName)
                        scrollPanel:ScrollToChild(row)

                        BATTLEBEATS.PlayNextTrackPreview(track, nil, false, function()
                            playerPanel:SetVisible(false)
                        end)
                        BATTLEBEATS.currentPreviewTrack = track
                        if not showPreviewNotification:GetBool() then BATTLEBEATS.HideNotification() end
                        if not timer.Exists("BattleBeats_NextPreviewTrack") then
                            timer.Create("BattleBeats_NextPreviewTrack", 0.5, 0, function()
                                if IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() == GMOD_CHANNEL_STOPPED then
                                    if isLooping then
                                        BATTLEBEATS.PlayNextTrackPreview(BATTLEBEATS.currentPreviewTrack, nil, true, function()
                                            playerPanel:SetVisible(false)
                                        end)
                                    else
                                        BATTLEBEATS.SwitchPreviewTrack(1)
                                    end
                                end
                                if IsValid(BATTLEBEATS.currentPreviewStation) then
                                    BATTLEBEATS.currentPreviewPosition = BATTLEBEATS.currentPreviewStation:GetTime()
                                end
                            end)
                        end
                    else
                        print("[BattleBeats Client] Cannot preview sound while the game is paused")
                    end
                elseif keyCode == MOUSE_RIGHT then
                    local menu = DermaMenu()
                    local favoriteCount = 0
                    for _ in pairs(BATTLEBEATS.favoriteTracks) do
                        favoriteCount = favoriteCount + 1
                    end
                    local copy = menu:AddOption("Copy Track Path", function()
                        SetClipboardText(track)
                    end)
                    copy:SetImage("icon16/tag.png")
                    if isFavorite then
                        local unfavorite = menu:AddOption("Remove from Favorites", function()
                            BATTLEBEATS.favoriteTracks[track] = nil
                            BATTLEBEATS.SaveFavoriteTracks()
                            changesMade = true
                            CreateTrackList(parent, trackType, selectedPack)
                        end)
                        unfavorite:SetImage("icon16/cancel.png")
                    elseif favoriteCount < 25 then
                        local favorite = menu:AddOption("Add to Favorites", function()
                            BATTLEBEATS.favoriteTracks[track] = true
                            BATTLEBEATS.SaveFavoriteTracks()
                            changesMade = true
                            CreateTrackList(parent, trackType, selectedPack)
                        end)
                        favorite:SetImage("icon16/star.png")
                    else
                        local nofavorite = menu:AddOption("Add to Favorites (Limit Reached [25])", function() end)
                        nofavorite:SetEnabled(false)
                        nofavorite:SetImage("icon16/error_delete.png")
                    end
                    local offsetValue = BATTLEBEATS.trackOffsets[track] or 0
                    local offsetOption = menu:AddOption(offsetValue > 0 and "Edit Offset (" .. offsetValue .. "s)" or "Set Offset", function()
                        local offsetFrame = vgui.Create("DFrame")
                        offsetFrame:SetTitle("Set Track Offset")
                        offsetFrame:SetSize(250, 110)
                        offsetFrame:Center()
                        offsetFrame:MakePopup()
                        offsetFrame.Paint = function(self, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 200))
                        end

                        local label = vgui.Create("DLabel", offsetFrame)
                        label:SetPos(10, 30)
                        label:SetSize(230, 20)
                        label:SetText("Offset (in seconds):")

                        local textEntry = vgui.Create("DTextEntry", offsetFrame)
                        textEntry:SetPos(10, 50)
                        textEntry:SetSize(230, 20)
                        textEntry:SetNumeric(true)
                        textEntry:SetValue(offsetValue)

                        local saveButton = vgui.Create("DButton", offsetFrame)
                        saveButton:SetPos(10, 75)
                        saveButton:SetSize(110, 25)
                        saveButton:SetText("Save")
                        saveButton.DoClick = function()
                            local newOffset = tonumber(textEntry:GetValue()) or 0
                            if newOffset > 0 then
                                BATTLEBEATS.trackOffsets[track] = newOffset
                                notification.AddLegacy("Set offset " .. newOffset .. "s for track: " .. BATTLEBEATS.FormatTrackName(track), NOTIFY_GENERIC, 3)
                                surface.PlaySound("buttons/button14.wav")
                                changesMade = true
                                CreateTrackList(parent, trackType, selectedPack)
                            else
                                BATTLEBEATS.trackOffsets[track] = nil
                                notification.AddLegacy("Removed offset from track: " .. BATTLEBEATS.FormatTrackName(track), NOTIFY_GENERIC, 3)
                                surface.PlaySound("buttons/button14.wav")
                                changesMade = true
                                CreateTrackList(parent, trackType, selectedPack)
                            end
                            BATTLEBEATS.SaveTrackOffsets()
                            offsetFrame:Close()
                        end

                        local cancelButton = vgui.Create("DButton", offsetFrame)
                        cancelButton:SetPos(130, 75)
                        cancelButton:SetSize(110, 25)
                        cancelButton:SetText("Cancel")
                        cancelButton.DoClick = function()
                            offsetFrame:Close()
                        end
                    end)
                    offsetOption:SetImage("icon16/time.png")
                    offsetOption:SetTooltip("Adds an offset to the track\nOn first play, it will start from this offset")
                    if trackType == "combat" then
                        local currentNPC = BATTLEBEATS.npcTrackMappings[track]
                        local npcOptionText = currentNPC and "Edit assigned NPC" or "Assign NPC Class"

                        if currentNPC then
                            local assignInfo = menu:AddOption("Assigned NPC: " .. currentNPC.class .. " (Priority: " .. currentNPC.priority .. ")", function() end)
                            assignInfo:SetImage("icon16/vcard.png")
                        end

                        local assignNPC = menu:AddOption(npcOptionText, function()
                            assignFrame = vgui.Create("DFrame")
                            assignFrame:SetTitle("Assign NPC to Track")
                            assignFrame:SetSize(400, 110)
                            assignFrame:Center()
                            assignFrame:MakePopup()
                            assignFrame.Paint = function(self, w, h)
                                draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 200))
                            end

                            local classLabel = vgui.Create("DLabel", assignFrame)
                            classLabel:SetPos(10, 25)
                            classLabel:SetSize(270, 20)
                            classLabel:SetText("Class:")

                            local textEntry = vgui.Create("DTextEntry", assignFrame)
                            textEntry:SetPos(10, 45)
                            textEntry:SetSize(270, 20)
                            textEntry:SetPlaceholderText("Enter NPC class (e.g npc_zombie)")
                            if currentNPC then textEntry:SetText(currentNPC.class) end

                            local priorityNames = {
                                [1] = "1 (Highest)",
                                [2] = "2",
                                [3] = "3",
                                [4] = "4",
                                [5] = "5 (Lowest)"
                            }

                            local priorityLabel = vgui.Create("DLabel", assignFrame)
                            priorityLabel:SetPos(290, 25)
                            priorityLabel:SetSize(100, 20)
                            priorityLabel:SetText("Priority:")

                            local priorityCombo = vgui.Create("DComboBox", assignFrame)
                            priorityCombo:SetPos(290, 45)
                            priorityCombo:SetSize(100, 20)
                            for i = 1, 5 do
                                priorityCombo:AddChoice(priorityNames[i])
                            end
                            priorityCombo:SetValue(currentNPC and tostring(currentNPC.priority) or "1 (Highest)")

                            local saveButton = vgui.Create("DButton", assignFrame)
                            saveButton:SetPos(45, 75)
                            saveButton:SetSize(150, 25)
                            saveButton:SetText(currentNPC and "Save/Remove" or "Save")
                            saveButton:SetFont("CreditsText")
                            saveButton:SetTextColor(Color(255, 255, 255))
                            saveButton.DoClick = function()
                                local class = textEntry:GetText()
                                local _, priorityStr = priorityCombo:GetSelected()
                                local priority = tonumber(priorityStr) or 1

                                if not class or class == "" then
                                    if currentNPC then
                                        BATTLEBEATS.npcTrackMappings[track] = nil
                                        notification.AddLegacy("Removed NPC class from track: " .. BATTLEBEATS.FormatTrackName(track), NOTIFY_GENERIC, 3)
                                        surface.PlaySound("buttons/button14.wav")
                                    else
                                        notification.AddLegacy("No NPC class entered", NOTIFY_ERROR, 3)
                                        surface.PlaySound("buttons/button11.wav")
                                    end
                                    BATTLEBEATS.SaveNPCMappings()
                                    changesMade = true
                                    assignFrame:Close()
                                    CreateTrackList(parent, trackType, selectedPack)
                                    return
                                end

                                local oldTrack = nil
                                for t, info in pairs(BATTLEBEATS.npcTrackMappings) do
                                    if t ~= track and info.class == class then
                                        oldTrack = t
                                        break
                                    end
                                end

                                local function assignNPCToTrack()
                                    BATTLEBEATS.npcTrackMappings[track] = { class = class, priority = math.Clamp(priority, 1, 5) }
                                    if oldTrack then
                                        BATTLEBEATS.npcTrackMappings[oldTrack] = nil
                                    end
                                    notification.AddLegacy("Assigned NPC class " .. class .. " with priority " .. priority .. " to track: " .. BATTLEBEATS.FormatTrackName(track), NOTIFY_GENERIC, 3)
                                    surface.PlaySound("buttons/button14.wav")
                                    BATTLEBEATS.SaveNPCMappings()
                                    changesMade = true
                                    assignFrame:Close()
                                    CreateTrackList(parent, trackType, selectedPack)
                                end

                                if oldTrack then
                                    surface.PlaySound("buttons/button17.wav")
                                    Derma_Query("NPC: (" .. class .. ") is already assigned to track: (" .. BATTLEBEATS.FormatTrackName(oldTrack) .. "). Overwrite?",
                                        "Confirm Overwrite", "Yes", function() assignNPCToTrack() end, "No", function() end)
                                else
                                    assignNPCToTrack()
                                end
                            end
                            saveButton.Paint = function(self, w, h)
                                local bgColor = self:IsHovered() and Color(80, 80, 80, 255) or Color(70, 70, 70, 255)
                                draw.RoundedBox(4, 0, 0, w, h, bgColor)
                            end

                            local cancelButton = vgui.Create("DButton", assignFrame)
                            cancelButton:SetPos(205, 75)
                            cancelButton:SetSize(150, 25)
                            cancelButton:SetText("Cancel")
                            cancelButton:SetFont("CreditsText")
                            cancelButton:SetTextColor(Color(255, 255, 255))
                            cancelButton.Paint = function(self, w, h)
                                local bgColor = self:IsHovered() and Color(80, 80, 80, 255) or Color(70, 70, 70, 255)
                                draw.RoundedBox(4, 0, 0, w, h, bgColor)
                            end
                            cancelButton.DoClick = function()
                                assignFrame:Close()
                            end
                        end)

                        assignNPC:SetImage(currentNPC and "icon16/user_edit.png" or "icon16/user_add.png")
                        assignNPC:SetTooltip("Assign an NPC class to this combat track with a priority (1-5)\nThe track with the highest priority will play when fighting multiple NPCs")
                    end
                    menu:Open()
                end
            end

            return row
        end

        --MARK:Tracks header
        local header = vgui.Create("DPanel", parent)
        header:Dock(TOP)
        header:DockMargin(0, 0, 15, 5)
        header:SetTall(headerExpanded and 60 or 25)
        header.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and not headerExpanded and Color(50, 50, 50, 255) or Color(40, 40, 40, 255)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
            draw.SimpleText("Name", "DermaDefaultBold", 40, 12, Color(255, 255, 255), TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText("Exclude", "DermaDefaultBold", 877, 12, Color(255, 255, 255), TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            if headerExpanded then
                draw.SimpleText("∆", "DermaDefaultBold", 933, 12, Color(255, 255, 255), TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            else
                draw.SimpleText("∇", "DermaDefaultBold", 930, 12, Color(255, 255, 255), TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            end
            if trackType == "ambient" then
                draw.SimpleText("Ambient List", "DermaDefaultBold", (w / 2) - 30, 12, Color(255, 255, 255),TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText("Combat List", "DermaDefaultBold", (w / 2) - 30, 12, Color(255, 255, 255),TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        header.OnCursorEntered = function(self)
            if not headerExpanded then
                self:SetCursor("hand")
            end
        end
        header.OnCursorExited = function(self)
            self:SetCursor("arrow")
        end

        local function CreateHeaderButtons(header, parent, trackType, selectedPack)
            for _, child in ipairs(header:GetChildren()) do
                if IsValid(child) and child:GetClassName() == "DButton" then
                    child:Remove()
                end
            end

            local enableAllButton = vgui.Create("DButton", header)
            enableAllButton:SetSize(270, 20)
            enableAllButton:SetPos(110, 25)
            enableAllButton:SetText("Enable All")
            enableAllButton:SetFont("DermaDefaultBold")
            enableAllButton:SetTextColor(Color(255, 255, 255))
            enableAllButton.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and Color(80, 80, 80, 255) or Color(70, 70, 70, 255)
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
            end
            enableAllButton.OnCursorEntered = function()
                surface.PlaySound("ui/buttonrollover.wav")
            end
            enableAllButton.DoClick = function()
                local tracks = BATTLEBEATS.musicPacks[selectedPack][trackType] or {}
                for _, track in ipairs(tracks) do
                    BATTLEBEATS.excludedTracks[track] = false
                end
                changesMade = true
                BATTLEBEATS.SaveExcludedTracks()
                surface.PlaySound("btb_button_enable.mp3")
                CreateTrackList(parent, trackType, selectedPack)
            end

            local disableAllButton = vgui.Create("DButton", header)
            disableAllButton:SetSize(270, 20)
            disableAllButton:SetPos(570, 25)
            disableAllButton:SetText("Disable All")
            disableAllButton:SetFont("DermaDefaultBold")
            disableAllButton:SetTextColor(Color(255, 255, 255))
            disableAllButton.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and Color(80, 80, 80, 255) or Color(70, 70, 70, 255)
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
            end
            disableAllButton.OnCursorEntered = function()
                surface.PlaySound("ui/buttonrollover.wav")
            end
            disableAllButton.DoClick = function()
                local tracks = BATTLEBEATS.musicPacks[selectedPack][trackType] or {}
                for _, track in ipairs(tracks) do
                    BATTLEBEATS.excludedTracks[track] = true
                end
                changesMade = true
                BATTLEBEATS.SaveExcludedTracks()
                surface.PlaySound("btb_button_disable.mp3")
                CreateTrackList(parent, trackType, selectedPack)
            end
        end

        if headerExpanded then
            CreateHeaderButtons(header, parent, trackType, selectedPack)
        end

        header.OnMousePressed = function(self, code)
            if code == MOUSE_LEFT then
                headerExpanded = not headerExpanded
                parent:GetParent():InvalidateLayout()

                if headerExpanded then
                    CreateHeaderButtons(header, parent, trackType, selectedPack)
                    self:SizeTo(-1, 60, 0.3, 0, -1)
                else
                    self:SizeTo(-1, 25, 0.3, 0, -1)
                    for _, child in ipairs(self:GetChildren()) do
                        if IsValid(child) and child:GetClassName() == "DButton" then
                            child:Remove()
                        end
                    end
                end
            end
        end

        local tracks = BATTLEBEATS.musicPacks[selectedPack][trackType] or {}
        local favoriteList = {}
        local nonFavoriteList = {}
        for _, track in ipairs(tracks) do
            if BATTLEBEATS.favoriteTracks[track] then
                table.insert(favoriteList, track)
            else
                table.insert(nonFavoriteList, track)
            end
        end

        --MARK:SBM/Nombat info
        if BATTLEBEATS.musicPacks[selectedPack].packType == "nombat" or BATTLEBEATS.musicPacks[selectedPack].packType == "sbm" then
            local inforow = vgui.Create("DPanel", parent)
            inforow:SetSize(0, 50)
            inforow:Dock(TOP)
            inforow:DockMargin(0, 5, 13, 3)
            inforow.Paint = function(self, w, h)
                local bg = Color(40, 40, 40, 255)
                draw.RoundedBox(4, 0, 0, w, h, bg)
                if BATTLEBEATS.musicPacks[selectedPack].packType == "sbm" then
                    draw.SimpleText("Track names may appear unusual due to the naming conventions used in SBM", "Trebuchet24", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText("Track names appear unusual due to the naming conventions used in Nombat", "Trebuchet24", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end

        for _, track in ipairs(favoriteList) do
            AddTrackRow(track, BATTLEBEATS.excludedTracks[track], true)
        end
        for _, track in ipairs(nonFavoriteList) do
            AddTrackRow(track, BATTLEBEATS.excludedTracks[track], false)
        end
    end
    --MARK:Main UI list
    local expandedPanel = nil
    local selectedPanel = nil
    local selectedPackName = nil
    local expandedPackName = nil

    local function ShowPackList()
        scrollPanel:Clear()
        scrollPanel:SetVisible(true)
        saveButton:SetVisible(true)

        local function CreateTrackEditor(trackType, packName, scrollPanel, frame)
            scrollPanel:Clear()
            scrollPanel:SetVisible(true)
            saveButton:SetVisible(false)
            if IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() ~= GMOD_CHANNEL_STOPPED then
                playerPanel:SetVisible(true)
                scrollPanel:SetSize(980, 430)
            end

            local backButton = vgui.Create("DButton", frame)
            backButton:SetSize(290, 40)
            backButton:SetPos(350, 650)
            backButton:SetText("Back")
            backButton:SetFont("CreditsText")
            backButton:SetTextColor(Color(255, 255, 255))
            backButton.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and Color(80, 80, 80, 255) or Color(70, 70, 70, 255)
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
            end
            backButton.OnCursorEntered = function(self)
                surface.PlaySound("ui/buttonrollover.wav")
            end
            backButton.DoClick = function()
                playerPanel:SetVisible(false)
                scrollPanel:SetSize(980, 600)
                backButton:Remove()
                headerExpanded = false
                ShowPackList()
            end

            CreateTrackList(scrollPanel, trackType, packName)
        end

        --MARK:No packs found
        if table.IsEmpty(BATTLEBEATS.musicPacks) then
            local promoPanel = vgui.Create("DPanel", frame)
            promoPanel:SetSize(850, 350)
            promoPanel:SetPos(80, 150)
            promoPanel.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 255))
                draw.SimpleText("No packs found. You might want to try one of these", "CloseCaption_Bold", w / 2, 30,
                Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            local packButtons = {
                {
                    name = "Zenless Zone Zero",
                    image = "btbzzz.jpg",
                    workshop = "3457857973"
                },
                {
                    name = "The Witcher 3 Wild Hunt",
                    image = "btbtw3.jpg",
                    workshop = "3483273863"
                },
                {
                    name = "Devil May Cry 5",
                    image = "btbdmc.jpg",
                    workshop = "3490225788"
                }
            }

            for i, pack in ipairs(packButtons) do
                local button = vgui.Create("DButton", promoPanel)
                button:SetSize(250, 270)
                button:SetPos(30 + (i - 1) * 270, 60)
                button:SetText("")
                button.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and Color(80, 80, 80, 255) or Color(70, 70, 70, 255)
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                    draw.SimpleText(pack.name, "CreditsText", w / 2, 250, Color(255, 255, 255), TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER)
                end
                button.OnCursorEntered = function(self)
                    surface.PlaySound("ui/buttonrollover.wav")
                end
                button.DoClick = function()
                    steamworks.ViewFile(pack.workshop)
                end

                local thumbnail = vgui.Create("DImage", button)
                thumbnail:SetSize(230, 220)
                thumbnail:SetPos(10, 10)
                thumbnail:SetImage(pack.image)
                thumbnail.Paint = function(self, w, h)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(self:GetMaterial())
                    surface.DrawTexturedRect(0, 0, w, h)
                    surface.SetDrawColor(0, 0, 0, 200)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                end
            end
        end

        --MARK:Packs found
        for packName, _ in pairs(BATTLEBEATS.musicPacks) do
            local packData = BATTLEBEATS.musicPacks[packName]
            local isErrored = packData.error ~= nil
            local panel = scrollPanel:Add("DPanel")
            panel:SetSize(580, 80)
            panel:Dock(TOP)
            panel:DockMargin(0, 0, 0, 5)
            panel.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and Color(60, 60, 60, 200) or Color(50, 50, 50, 200)
                if packData.packType == "local" then bgColor = self:IsHovered() and Color(50, 140, 140, 200) or Color(50, 120, 120, 200) end
                if packData.debug == true then bgColor = self:IsHovered() and Color(110, 110, 60, 200) or Color(100, 100, 60, 200) end
                if isErrored then
                    draw.RoundedBox(4, 0, 0, w, h, Color(70, 50, 50, 200))
                elseif panel == selectedPanel then
                    if packData.debug == true then
                        draw.RoundedBox(4, 0, 0, w, h, Color(120, 120, 60, 255))
                    elseif packData.packType == "local" then
                        draw.RoundedBox(4, 0, 0, w, h, Color(50, 140, 140, 255))
                    else
                        draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 70, 255))
                    end
                else
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                end
            end

            panel.OnCursorEntered = function(self)
                if not isErrored then
                    self:SetCursor("hand")
                else
                    self:SetCursor("no")
                end
            end
            panel.OnCursorExited = function(self)
                self:SetCursor("arrow")
            end

            local packLabel = vgui.Create("DLabel", panel)
            packLabel:SetText(packName)
            packLabel:SetFont("CloseCaption_Bold")
            packLabel:SetPos(10, 25)
            packLabel:SetSize(800, 30)
            packLabel:SetTextColor(Color(255, 255, 255))

            if isErrored then
                local errorIcon = vgui.Create("DImage", panel)
                errorIcon:SetPos(840, 28)
                errorIcon:SetSize(24, 24)
                errorIcon:SetImage("icon16/exclamation.png")
                local errorMessage = packData.error or "Unknown error"
                errorIcon:SetTooltip("Pack error: " .. tostring(errorMessage))
                errorIcon.OnCursorEntered = function(self)
                    self:SetTooltip("Pack error: " .. tostring(errorMessage))
                end
                errorIcon:SetMouseInputEnabled(true)
                errorIcon:SetVisible(true)
            end

            local customCheckbox = vgui.Create("DPanel", panel)
            customCheckbox:SetSize(80, 30)
            customCheckbox:SetPos(870, 25)

            customCheckbox.OnCursorEntered = function(self)
                if not isErrored then
                    self:SetCursor("hand")
                else
                    self:SetCursor("no")
                end
            end
            customCheckbox.OnCursorExited = function(self)
                self:SetCursor("arrow")
            end

            local checkboxText = vgui.Create("DLabel", customCheckbox)
            checkboxText:SetFont("DermaDefaultBold")
            checkboxText:SetText(BATTLEBEATS.currentPacks[packName] and "Enabled" or "Disabled")
            checkboxText:SetTextColor(Color(255, 255, 255))
            checkboxText:Dock(FILL)
            checkboxText:SetContentAlignment(5)

            if not isErrored then
                customCheckbox.OnMousePressed = function()
                    changesMade = true
                    if BATTLEBEATS.currentPacks[packName] then
                        BATTLEBEATS.currentPacks[packName] = nil
                    else
                        BATTLEBEATS.currentPacks[packName] = true
                    end
                    checkboxText:SetText(BATTLEBEATS.currentPacks[packName] and "Enabled" or "Disabled")
                    if not BATTLEBEATS.currentPacks[packName] then
                        customCheckbox:SetBackgroundColor(Color(255, 0, 0))
                        surface.PlaySound("btb_button_disable.mp3")
                    else
                        customCheckbox:SetBackgroundColor(Color(0, 255, 0))
                        surface.PlaySound("btb_button_enable.mp3")
                    end
                end
            else
                customCheckbox:SetBackgroundColor(Color(100, 0, 0))
                checkboxText:SetText("Unavailable")
            end

            if not isErrored then
                if not BATTLEBEATS.currentPacks[packName] then
                    customCheckbox:SetBackgroundColor(Color(255, 0, 0))
                else
                    customCheckbox:SetBackgroundColor(Color(0, 255, 0))
                end
            end

            --MARK:Packs dropdown functions
            local function CreateButtons(panel)
                if not IsValid(panel) then return end

                local buttonWidth, buttonHeight, spacing = 430, 30, 40
                local panelWidth = panel:GetWide()
                local totalWidth = buttonWidth * 2 + spacing
                local startX = (panelWidth - totalWidth) / 2
                local ambientButton = vgui.Create("DButton", panel)
                ambientButton:SetSize(buttonWidth, buttonHeight)
                ambientButton:SetPos(startX, 80)
                ambientButton:SetText("Ambient Tracks")
                ambientButton:SetFont("DermaDefaultBold")
                ambientButton:SetTextColor(Color(255, 255, 255))
                ambientButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and Color(90, 90, 90) or Color(60, 60, 60)
                    if packData.packContent == "combat" then
                        bgColor = Color(40, 40, 40)
                        self:SetTooltip("This pack doesn't have ambient tracks")
                        ambientButton:SetTextColor(Color(200, 200, 200))
                    end
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                end
                ambientButton.OnCursorEntered = function(self)
                    if packData.packContent ~= "combat" then
                        self:SetCursor("hand")
                        surface.PlaySound("ui/buttonrollover.wav")
                    else
                        self:SetCursor("no")
                    end
                end
                ambientButton.OnCursorExited = function(self)
                    self:SetCursor("arrow")
                end
                ambientButton.DoClick = function()
                    if packData.packContent ~= "combat" then
                        CreateTrackEditor("ambient", packName, scrollPanel, frame)
                    end
                end
                panel.ambientButton = ambientButton

                local combatButton = vgui.Create("DButton", panel)
                combatButton:SetSize(buttonWidth, buttonHeight)
                combatButton:SetPos(startX + buttonWidth + spacing, 80)
                combatButton:SetText("Combat Tracks")
                combatButton:SetFont("DermaDefaultBold")
                combatButton:SetTextColor(Color(255, 255, 255))
                combatButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and Color(90, 90, 90) or Color(60, 60, 60)
                    if packData.packContent == "ambient" then
                        bgColor = Color(40, 40, 40)
                        self:SetTooltip("This pack doesn't have combat tracks")
                        combatButton:SetTextColor(Color(200, 200, 200))
                    end
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                end
                combatButton.OnCursorEntered = function(self)
                    if packData.packContent ~= "ambient" then
                        self:SetCursor("hand")
                        surface.PlaySound("ui/buttonrollover.wav")
                    else
                        self:SetCursor("no")
                    end
                end
                combatButton.OnCursorExited = function(self)
                    self:SetCursor("arrow")
                end
                combatButton.DoClick = function()
                    if packData.packContent ~= "ambient" then
                        CreateTrackEditor("combat", packName, scrollPanel, frame)
                    end
                end
                panel.combatButton = combatButton
            end

            --MARK:Packs dropdown
            panel.OnMousePressed = function()
                if isErrored then
                    notification.AddLegacy("This pack has an error and cannot be edited!", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button10.wav")
                    return
                end

                scrollPanel:ScrollToChild(panel)

                selectedPanel = panel
                selectedPackName = packName
                expandedPackName = packName

                local function RemoveButtons(panel)
                    if not IsValid(panel) then return end
                    if panel.ambientButton then
                        panel.ambientButton:Remove()
                        panel.ambientButton = nil
                    end
                    if panel.combatButton then
                        panel.combatButton:Remove()
                        panel.combatButton = nil
                    end
                    if panel.infoPanels then
                        for _, p in ipairs(panel.infoPanels) do
                            if IsValid(p) then p:Remove() end
                        end
                    end
                end

                if expandedPanel == panel then
                    panel:SizeTo(-1, 80, 0.15, 0, -1, function()
                        RemoveButtons(panel)
                        expandedPanel = nil
                        selectedPanel = nil
                        selectedPackName = nil
                        expandedPackName = nil
                    end)
                    return
                end

                if expandedPanel and IsValid(expandedPanel) then
                    local oldPanel = expandedPanel
                    expandedPanel = nil
                    oldPanel:SizeTo(-1, 80, 0.15, 0, -1, function()
                        RemoveButtons(oldPanel)

                        panel:SizeTo(-1, 160, 0.15, 0, -1)
                        surface.PlaySound("ui/buttonrollover.wav")
                        CreateButtons(panel)
                        CreateInfoPanel(panel, packData)
                        expandedPanel = panel
                    end)
                else
                    panel:SizeTo(-1, 160, 0.15, 0, -1)
                    surface.PlaySound("ui/buttonrollover.wav")
                    CreateButtons(panel)
                    CreateInfoPanel(panel, packData)
                    expandedPanel = panel
                end
            end
            if packName == selectedPackName then
                selectedPanel = panel
            end

            if packName == expandedPackName then
                selectedPanel = panel
                expandedPanel = panel
                panel:SetTall(160)
                timer.Simple(0, function()
                    if IsValid(panel) then
                        CreateButtons(panel)
                        CreateInfoPanel(panel, packData)
                    end
                end)
            end
        end
    end

    ShowPackList()

    saveButton.DoClick = function()
        frame:Close()
    end

    frame.OnClose = function()
        BATTLEBEATS.ValidatePacks()
        if IsValid(BATTLEBEATS.optionsFrame) then BATTLEBEATS.optionsFrame:Close() end
        if IsValid(assignFrame) then assignFrame:Close() end
        if timer.Exists("BattleBeats_NextPreviewTrack") then
            timer.Remove("BattleBeats_NextPreviewTrack")
        end
        if BATTLEBEATS.currentPreviewStation and IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() == GMOD_CHANNEL_PLAYING then
            if not persistentNotification:GetBool() then BATTLEBEATS.HideNotification() end
            -- play the previewed track as the main track, resuming from current playback time, no fade
            BATTLEBEATS.PlayNextTrack(BATTLEBEATS.currentPreviewTrack, BATTLEBEATS.currentPreviewStation:GetTime(), true)
            timer.Simple(0.05, function() -- stop the preview station shortly after to avoid conflicts
                BATTLEBEATS.currentPreviewStation:Stop()
            end)
        else
            surface.PlaySound("btb_ui_exit.mp3")
        end
        if changesMade then
            -- if no preview track is playing, start a random track from selected packs
            if BATTLEBEATS.currentPreviewTrack == nil or (IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() ~= GMOD_CHANNEL_PLAYING) then
                local nextTrack = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks)
                if nextTrack then
                    BATTLEBEATS.PlayNextTrack(nextTrack)
                end
            end
            BATTLEBEATS.currentPreviewTrack = nil
            local jsonPacks = util.TableToJSON(BATTLEBEATS.currentPacks)
            cookie.Set("battlebeats_selected_packs", jsonPacks)
        end
        if table.IsEmpty(BATTLEBEATS.currentPacks) and IsValid(BATTLEBEATS.currentStation) then
            BATTLEBEATS.FadeMusic(BATTLEBEATS.currentStation)
            BATTLEBEATS.HideNotification()
        end
    end
end

hook.Add("OnContextMenuOpen", "BattleBeats_OpenMusicMenu", function()
    if IsValid(frame) and not frame.isMinimalized then
        frame:SetVisible(true)
    end
end)

hook.Add("OnContextMenuClose", "BattleBeats_HideMusicMenu", function()
    if IsValid(frame) then
        frame:SetVisible(false)
    end
end)

list.Set("DesktopWindows", "BattleBeatsContextMenu", {
    title = "BattleBeats",
    icon = "btb.png",
    init = function()
        if IsValid(frame) and not frame:IsVisible() then
            frame:SetVisible(true)
            frame.isMinimalized = false
        end
        if not IsValid(frame) then OpenMusicMenu() end
    end
})

concommand.Add("battlebeats_menu", function()
    if IsValid(frame) and not frame:IsVisible() then
        frame:SetVisible(true)
        frame.isMinimalized = false
    end
    if not IsValid(frame) then OpenMusicMenu() end
end)