local frame
local assignFrame
local lframe
local searchBox
local isLooping = false
local skipExcluded = false

BATTLEBEATS.activeConflicts = BATTLEBEATS.activeConflicts or {}

local wsCache = {}

local volumeSet = GetConVar("battlebeats_volume")
local persistentNotification = GetConVar("battlebeats_persistent_notification")
local showPreviewNotification = GetConVar("battlebeats_show_preview_notification")
local toogleFrame = CreateClientConVar("battlebeats_context_ui_toogle", "0", true, false, "", 0, 1)

local packIcons = {
    ["battlebeats"] = Material("packicons/btb.png"),
    ["nombat"] = Material("packicons/nombat.jpg"),
    ["sbm"] = Material("packicons/sbm.jpg"),
    ["16th"] = Material("packicons/16th.jpg"),
    ["amusic"] = Material("packicons/amusic.jpg"),
    ["dynamo"] = Material("packicons/dynamo.jpg"),
    ["mp3p"] = Material("packicons/mp3p.jpg"),
    ["na"] = Material("btbna.jpg")
}

surface.CreateFont("BattleBeats_Font", {
    font = "Roboto Bold",
    size = 30,
    weight = 800,
    antialias = true,
    shadow = true
})

surface.CreateFont("BattleBeats_Player_Font", {
    font = "Roboto Bold",
    size = 46,
    weight = 800,
    antialias = true,
    shadow = true
})

surface.CreateFont("BattleBeats_Checkbox_Font", {
    font = "Roboto Regular",
    size = 18,
    weight = 200,
    antialias = true,
})

surface.CreateFont("BattleBeats_Notification_Font", {
    font = "Roboto Medium",
    size = 28,
    weight = 800,
    antialias = true,
})

surface.CreateFont("BattleBeats_Notification_Font_Misc", {
    font = "Roboto Light",
    size = 16,
    weight = 500,
    antialias = true,
})

surface.CreateFont("BattleBeats_Subtitles", {
    font = "CloseCaption_Bold",
    size = 36,
    weight = 600
})

local c606060 = Color(60, 60, 60)
local c200200200 = Color(200, 200, 200)
local c2552100 = Color(255, 210, 0)
local c2001500 = Color(200, 150, 0)
local c404040 = Color(40, 40, 40)

local function parseSize(sizeStr)
    local num, unit = sizeStr:match("([%d%.]+)%s*(%a+)")
    num = tonumber(num) or 0
    if unit == "KB" then
        return num / 1024
    elseif unit == "GB" then
        return num * 1024
    else
        return num
    end
end

--MARK:Steamworks info
local function createInfoBoxes(panel, size, date, ownerName)
    if not IsValid(panel) then return end
    local buttonWidth, buttonHeight, spacing = 200, 30, 40
    local panelWidth = panel:GetWide()
    local totalWidth = buttonWidth * 3 + spacing * 2
    local startX = (panelWidth - totalWidth) / 2
    local y = 120

    local sizeColor
    local numericSize = parseSize(size)
    if numericSize < 200 then
        sizeColor = Color(0, 200, 0)
    elseif numericSize < 600 then
        sizeColor = Color(255, 140, 0)
    else
        sizeColor = Color(200, 0, 0)
    end

    local function addInfoBox(text, x, textColor)
        local box = vgui.Create("DPanel", panel)
        box:SetSize(buttonWidth, buttonHeight)
        box:SetPos(x, y)
        box.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, c2001500)
            draw.RoundedBox(8, 2, 2, w - 4, h - 4, c404040)
        end

        local label = vgui.Create("DLabel", box)
        label:SetText(text)
        label:SetFont("DermaDefault")
        label:SetTextColor(textColor or c200200200)
        label:SizeToContents()
        label:Center()

        table.insert(panel.infoPanels, box)
    end

    local ssize = language.GetPhrase("#btb.ps.info.size")
    local screated = language.GetPhrase("#btb.ps.info.created")
    local sauthor = language.GetPhrase("#btb.ps.info.author")

    addInfoBox(ssize .. size, startX, sizeColor)
    addInfoBox(screated .. date, startX + buttonWidth + spacing)
    addInfoBox(sauthor .. ownerName, startX + (buttonWidth + spacing) * 2)
end

local function createInfoPanel(panel, packData)
    if not IsValid(panel) then return end
    panel.infoPanels = {}

    local wsid = packData.wsid
    local function applyInfo(result)
        local size = result.size and string.NiceSize(result.size) or "N/A"
        local date = result.created and os.date("%Y-%m-%d", result.created) or "N/A"
        local ownerName = result.ownername or "N/A"
        createInfoBoxes(panel, size, date, ownerName)
    end

    createInfoBoxes(panel, "Loading...", "Loading...", "Loading...")

    if not wsid then
        createInfoBoxes(panel, "N/A", "N/A", "N/A")
        return
    end

    if wsCache[wsid] then
        applyInfo(wsCache[wsid])
        return
    end

    steamworks.FileInfo(wsid, function(result)
        if not result then
            result = {size = nil, created = nil, ownername = nil}
        end
        wsCache[wsid] = result
        applyInfo(result)
    end)
end

local Lerp = Lerp
local FrameTime = FrameTime
local Color = Color

local function colorsEqual(a, b)
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a
end

local function LerpColor(t, from, to)
    if colorsEqual(from, to) then return to end
    return Color(
        Lerp(t, from.r, to.r),
        Lerp(t, from.g, to.g),
        Lerp(t, from.b, to.b),
        Lerp(t, from.a or 255, to.a or 255)
    )
end

BATTLEBEATS.checking = false
local checking = false
local packNames = {}
local errorCount = 0
local currentPackIndex = 1
local function validateTracksInPack(packName)
    local packData = BATTLEBEATS.musicPacks[packName]
    if not packData then return end
    BATTLEBEATS.checking = true
    checking = true
    local tracks = {}
    if packData.ambient then
        for _, track in ipairs(packData.ambient) do
            table.insert(tracks, { track = track, type = "ambient" })
        end
    end
    if packData.combat then
        for _, track in ipairs(packData.combat) do
            table.insert(tracks, { track = track, type = "combat" })
        end
    end

    MsgC(
        Color(255, 255, 0), "[BattleBeats Debug] ",
        color_white, "Verifying pack: ",
        Color(0, 255, 255), packName .. "\n"
    )

    local trackIndex = 1
    packData.verifying = true

    local function nextTrack()
        if trackIndex > #tracks then
            packData.verifying = false
            currentPackIndex = currentPackIndex + 1
            if currentPackIndex <= #packNames then
                validateTracksInPack(packNames[currentPackIndex])
            else
                packNames = {}
                currentPackIndex = 1
                if errorCount > 0 then
                    MsgC(
                        Color(255, 255, 0), "[BattleBeats Debug] ",
                        color_white, "Pack verification",
                        Color(255, 0, 0), " FAILED! ",
                        color_white, "Found ",
                        Color(255, 0, 0), tostring(errorCount),
                        color_white, " error(s)\n"
                    )
                    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.ps.verification.failed_1") .. " " .. tostring(errorCount) .. " " .. language.GetPhrase("btb.ps.verification.failed_2"), NOTIFY_ERROR, 4)
                    surface.PlaySound("buttons/button8.wav")
                else
                    MsgC(
                        Color(255, 255, 0), "[BattleBeats Debug] ",
                        color_white, "Pack verification",
                        Color(0, 255, 0), " PASSED! ",
                        color_white, "No errors found\n"
                    )
                    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.ps.verification.pass"), NOTIFY_HINT, 4)
                    surface.PlaySound("buttons/button14.wav")
                end
                errorCount = 0
                checking = false
            end
            return
        end

        local info = tracks[trackIndex]
        BATTLEBEATS.ValidateTrack(info.track, function(track, errCode, errStr)
            errorCount = errorCount + 1
            packData.error = packData.error or {}
            packData.error = "track_error\nOne or more tracks have an error\nCheck console for details!"
            MsgC(
                Color(255, 255, 0), "[BattleBeats Debug] ",
                color_white, "Error in pack '",
                Color(0, 255, 255), packName,
                color_white, "' - ",
                Color(255, 255, 0), info.type .. " ",
                color_white, "track: ",
                color_white, track .. " ",
                color_white, "Code: ",
                Color(0, 255, 255), tostring(errCode) .. " ",
                color_white, "Error: ",
                Color(255, 0, 255), tostring(errStr) .. "\n"
            )
        end)

        trackIndex = trackIndex + 1
        timer.Simple(0.05, nextTrack)
    end

    nextTrack()
end

local cHover = Color(50, 50, 50, 200)
local cHover2 = Color(65, 65, 65, 200)

local c707070255 = Color(70, 70, 70, 255)
local c808080255 = Color(80, 80, 80, 255)

local c000200 = Color(0, 0, 0, 200)
local c909090 = Color(90, 90, 90)
local c25500 = Color(255, 0, 0)
local c3030300 = Color(30, 30, 30, 0)
local c100100100 = Color(100, 100, 100)
local c505050 = Color(50, 50, 50)
local c255255255200 = Color(255, 255, 255, 200)
local c202020215 = Color(20, 20, 20, 215)

local versionConVar = GetConVar("battlebeats_seen_version")

--MARK:Main UI
local function openBTBmenu()
    if IsValid(frame) then return end
    if cookie.GetString('BattleBeats_FirstTime') ~= 'true' and versionConVar:GetString() == "" then
        RunConsoleCommand("battlebeats_guide")
        cookie.Set('BattleBeats_FirstTime', 'true')
    end
    local changesMade = false
    local selectedRow = nil
    frame = vgui.Create("DFrame")
    BATTLEBEATS.frame = frame
    frame:SetSize(1000, 700)
    frame:SetSizable(false)
    frame:Center()
    frame:SetTitle("#btb.ps.title")
    frame:MakePopup()
    frame:SetBackgroundBlur(true)
    frame.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, c202020215)
    end
    frame.isMinimalized = false

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

    for _, packData in pairs(BATTLEBEATS.musicPacks) do
        local wsid = packData.wsid
        if wsid and not wsCache[wsid] then
            steamworks.FileInfo(wsid, function(result)
                if result then
                    wsCache[wsid] = result
                end
            end)
        end
    end

    local scrollPanel = vgui.Create("DScrollPanel", frame)
    scrollPanel:SetSize(980, 600)
    scrollPanel:SetPos(10, 30)

    local scrollBar = scrollPanel:GetVBar()
    scrollBar:SetHideButtons(true)
    local c404040200 = Color(40, 40, 40, 200)

    scrollBar.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c404040200)
    end
    scrollBar.btnGrip.Paint = function(self, w, h)
        self:SetCursor("hand")
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, c606060)
    end

    function scrollBar:AddScroll(d)
        local animTarget = self:GetScroll() + d * 60
        animTarget = math.Clamp(animTarget, 0, self.CanvasSize)
        local speed = math.min(math.abs(d), 5)
        self:Stop()
        self:AnimateTo(animTarget, 0.5 / speed, 0, 0.3)
    end

    --MARK:Option button
    local optionsButton = vgui.Create("DButton", frame)
    optionsButton:SetSize(340, 40)
    optionsButton:SetPos(650, 650)
    optionsButton:SetText("#btb.ps.button.options")
    optionsButton:SetFont("CreditsText")
    optionsButton:SetTextColor(color_white)
    optionsButton.currentColor = c707070255
    optionsButton.targetColor = c707070255
    optionsButton.Think = function(self)
        if self:IsHovered() then
            self.targetColor = c808080255
        else
            self.targetColor = c707070255
        end
        self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
    end
    optionsButton.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, self.currentColor)
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
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, c707070255)
    end
    local volumeLabel = vgui.Create("DLabel", volumePanel)
    volumeLabel:SetText("#btb.ps.master_volume")
    volumeLabel:SetFont("DermaDefaultBold")
    volumeLabel:SetTextColor(color_white)
    volumeLabel:SizeToContents()
    local labelWidth = volumeLabel:GetWide()
    volumeLabel:SetPos((volumePanel:GetWide() - labelWidth) / 2, 4)
    local volumeBar = vgui.Create("DPanel", volumePanel)
    volumeBar:SetSize(300, 8)
    volumeBar:SetPos(15, 22)
    volumeBar:SetCursor("hand")
    volumeBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c909090)
        local cvar = volumeSet
        local progress = cvar:GetInt() / 200
        draw.RoundedBox(4, 0, 0, w * progress, h, c2552100)
    end

    local dotPanel = vgui.Create("DPanel", volumePanel)
    dotPanel:SetMouseInputEnabled(false)
    dotPanel:SetSize(12, 12)
    dotPanel.Paint = function(self, w, h)
        local cvar = volumeSet
        local progress = cvar:GetInt() / 200
        if progress >= 0 then
            draw.RoundedBox(4, 0, 0, w, h, color_white)
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

    local function updateVolume(bar, x)
        local progress = math.Clamp(x / bar:GetWide(), 0, 1)
        local newValue = math.floor(progress * 200)
        volumeSet:SetInt(newValue)
    end

    volumeBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            local x, _ = self:CursorPos()
            updateVolume(self, x)
            self.IsDragging = true
        end
    end
    volumeBar.Think = function(self)
        if self.IsDragging and input.IsMouseDown(MOUSE_LEFT) then
            local x, _ = self:CursorPos()
            updateVolume(self, x)
        elseif self.IsDragging and not input.IsMouseDown(MOUSE_LEFT) then
            self.IsDragging = false
        end
    end

    --MARK:Save button
    local saveButton = vgui.Create("DButton", frame)
    saveButton:SetSize(290, 40)
    saveButton:SetPos(350, 650)
    saveButton:SetText("#btb.ps.button.done")
    saveButton:SetFont("CreditsText")
    saveButton:SetTextColor(color_white)
    saveButton.currentColor = c707070255
    saveButton.targetColor = c707070255
    saveButton.Think = function(self)
        if self:IsHovered() then
            self.targetColor = c808080255
        else
            self.targetColor = c707070255
        end
        self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
    end
    saveButton.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, self.currentColor)
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
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, c404040)
    end

    local playPause = vgui.Create("DButton", playerPanel)
    playPause:SetSize(50, 50)
    playPause:SetPos((playerPanel:GetWide() / 2) - 28, 50)
    playPause:SetText("▶")
    playPause:SetFont("DermaLarge")
    playPause:SetTextColor(color_white)
    playPause.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, c3030300)
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
    currentTimeLabel:SetTextColor(color_white)

    local totalTimeLabel = vgui.Create("DLabel", playerPanel)
    totalTimeLabel:SetPos(850, 111)
    totalTimeLabel:SetSize(90, 20)
    totalTimeLabel:SetText("0:00")
    totalTimeLabel:SetFont("DermaDefaultBold")
    totalTimeLabel:SetTextColor(color_white)
    totalTimeLabel:SetContentAlignment(6)

    local trackNameLabel = vgui.Create("DLabel", playerPanel)
    trackNameLabel:SetPos(45, 15)
    trackNameLabel:SetSize(880, 50)
    trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
    trackNameLabel:SetFont("BattleBeats_Player_Font")
    trackNameLabel:SetTextColor(color_white)
    trackNameLabel:SetContentAlignment(5)

    local loopBtn = vgui.Create("DButton", playerPanel)
    loopBtn:SetSize(40, 40)
    loopBtn:SetPos((playerPanel:GetWide() / 2) + 85, 60)
    loopBtn:SetText("↻")
    loopBtn:SetFont("DermaLarge")
    loopBtn:SetTextColor(c100100100)
    loopBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, c3030300)
    end
    loopBtn:SetTooltip("#btb.ps.ts.mp.loop_disabled")
    loopBtn.DoClick = function()
        isLooping = not isLooping
        if isLooping then
            loopBtn:SetTextColor(color_white)
            loopBtn:SetTooltip("#btb.ps.ts.mp.loop_enabled")
        else
            loopBtn:SetTextColor(c100100100)
            loopBtn:SetTooltip("#btb.ps.ts.mp.loop_disabled")
        end
    end
    loopBtn:SetTooltipPanelOverride("BattleBeatsTooltip")

    local skipExcludedBtn = vgui.Create("DButton", playerPanel)
    skipExcludedBtn:SetSize(40, 40)
    skipExcludedBtn:SetPos((playerPanel:GetWide() / 2) - 130, 60)
    skipExcludedBtn:SetText("⇅")
    skipExcludedBtn:SetFont("DermaLarge")
    skipExcludedBtn:SetTextColor(color_white)
    skipExcludedBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, c3030300)
    end
    skipExcludedBtn:SetTooltip("#btb.ps.ts.mp.skip_play_all_tip")
    skipExcludedBtn.DoClick = function()
        skipExcluded = not skipExcluded
        if skipExcluded then
            skipExcludedBtn:SetTextColor(c100100100)
            skipExcludedBtn:SetTooltip("#btb.ps.ts.mp.skip_excluded_tip")
        else
            skipExcludedBtn:SetTextColor(color_white)
            skipExcludedBtn:SetTooltip("#btb.ps.ts.mp.skip_play_all_tip")
        end
    end
    skipExcludedBtn:SetTooltipPanelOverride("BattleBeatsTooltip")

    --MARK:Next/Previous track
    local currentFilteredTracks
    function BATTLEBEATS.SwitchPreviewTrack(direction)
        if not BATTLEBEATS.currentPreviewTrack or not BATTLEBEATS.musicPacks then return end

        local activeList = currentFilteredTracks
        if not activeList or #activeList == 0 then return end

        local currentIndex = table.KeyFromValue(activeList, BATTLEBEATS.currentPreviewTrack)
        if not currentIndex then
            BATTLEBEATS.currentPreviewTrack = activeList[1]
            currentIndex = 1
        end

        local totalTracks = #activeList
        local newIndex = currentIndex

        if skipExcluded then
            for i = 1, totalTracks do
                newIndex = newIndex + direction
                if newIndex < 1 then newIndex = totalTracks end
                if newIndex > totalTracks then newIndex = 1 end

                local candidate = activeList[newIndex]
                if not BATTLEBEATS.excludedTracks[candidate] then
                    BATTLEBEATS.currentPreviewTrack = candidate
                    break
                end
            end
            if BATTLEBEATS.excludedTracks[BATTLEBEATS.currentPreviewTrack] then
                newIndex = currentIndex + direction
                if newIndex < 1 then newIndex = totalTracks end
                if newIndex > totalTracks then newIndex = 1 end
                BATTLEBEATS.currentPreviewTrack = activeList[newIndex]
            end
        else
            newIndex = currentIndex + direction
            if newIndex < 1 then newIndex = totalTracks end
            if newIndex > totalTracks then newIndex = 1 end
            BATTLEBEATS.currentPreviewTrack = activeList[newIndex]
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
                    selectedRow = row.trackName
                    scrollPanel:ScrollToChild(row)
                    break
                end
            end
        end
    end

    local prevTrackBtn = vgui.Create("DButton", playerPanel)
    prevTrackBtn:SetSize(50, 50)
    prevTrackBtn:SetPos((playerPanel:GetWide() / 2) - 88, 50)
    prevTrackBtn:SetText("⏮")
    prevTrackBtn:SetFont("DermaLarge")
    prevTrackBtn:SetTextColor(color_white)
    prevTrackBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, c3030300)
    end
    prevTrackBtn.DoClick = function()
        BATTLEBEATS.SwitchPreviewTrack(-1)
    end
    prevTrackBtn:SetTooltip("#btb.ps.ts.mp.previous_track_tip")
    prevTrackBtn:SetTooltipPanelOverride("BattleBeatsTooltip")

    local nextTrackBtn = vgui.Create("DButton", playerPanel)
    nextTrackBtn:SetSize(50, 50)
    nextTrackBtn:SetPos((playerPanel:GetWide() / 2) + 28, 50)
    nextTrackBtn:SetText("⏭")
    nextTrackBtn:SetFont("DermaLarge")
    nextTrackBtn:SetTextColor(color_white)
    nextTrackBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, c3030300)
    end
    nextTrackBtn.DoClick = function()
        BATTLEBEATS.SwitchPreviewTrack(1)
    end
    nextTrackBtn:SetTooltip("#btb.ps.ts.mp.next_track_tip")
    nextTrackBtn:SetTooltipPanelOverride("BattleBeatsTooltip")
    --MARK:Player bars
    local hoverTimeDisplay = nil
    local progressBar = vgui.Create("DPanel", playerPanel)
    progressBar:SetSize(800, 20)
    progressBar:SetPos(90, 110)
    progressBar:SetCursor("hand")
    progressBar.Paint = function(self, w, h)
        local progressBarX, progressBarY = 0, h / 2 - 2
        local progressBarWidth, progressBarHeight = w, 8
        draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth, progressBarHeight, c909090)

        local currentTime = IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetTime() or 0
        local trackDuration = IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetLength() or 0
        local progress = trackDuration > 0 and math.Clamp(currentTime / trackDuration, 0, 1) or 0

        draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth * progress, progressBarHeight, c2552100)

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
            draw.SimpleText(hoverTimeDisplay.text, "DermaDefaultBold", lx, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
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

    local progressDot = vgui.Create("DPanel", progressBar)
    progressDot:SetSize(12, 12)
    progressDot:SetMouseInputEnabled(false)
    progressDot.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, color_white)
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
    local function createTrackList(parent, trackType, selectedPack)
        parent:Clear()
        local isAllMode = (trackType == "all")
        local function addTrackRow(track, excluded, isFavorite, actualTrackType)
            local trackName = BATTLEBEATS.FormatTrackName(track)
            local row = vgui.Create("DPanel", parent)
            row:SetSize(0, 50)
            row:Dock(TOP)
            row:DockMargin(0, 5, 13, 3)
            row:SetCursor("hand")
            row.trackPath = track
            row.trackName = trackName
            row.actualType = actualTrackType or trackType
            row.textX = 10
            row.isScrolling = false
            row.scrollResetTime = 0

            if selectedRow == row.trackName then
                timer.Simple(0.1, function ()
                    if IsValid(row) then
                        scrollPanel:ScrollToChild(row)
                    end
                end)
            end

            surface.SetFont("BattleBeats_Font")
            local textWidth = surface.GetTextSize(isFavorite and "★ " .. trackName or trackName)
            local panelWidth = 800
            local scrollSpeed = 60
            local npcs = BATTLEBEATS.npcTrackMappings[track] and BATTLEBEATS.npcTrackMappings[track].npcs
            local count = istable(npcs) and #npcs or 0

            local iconData = {
                {check = count == 1, tooltip = "#btb.ps.ts.icon_assigned", image = "icon16/user.png"},
                {check = count >= 2, tooltip = "#btb.ps.ts.icon_assigned_multiple", image = "icon16/group.png"},
                {check = BATTLEBEATS.trackOffsets[track] ~= nil, tooltip = "#btb.ps.ts.icon_offset", image = "icon16/time.png"},
                {check = BATTLEBEATS.parsedSubtitles[string.lower(trackName)] ~= nil, tooltip = "#btb.ps.ts.icon_subtitle", image = "icon16/comments.png"}
            }

            local xOffset = 840
            for _, data in ipairs(iconData) do
                if data.check then
                    local tooltipFrame = vgui.Create("DPanel", row)
                    tooltipFrame:SetSize(16, 16)
                    tooltipFrame:SetPos(xOffset, 17)
                    tooltipFrame:SetPaintBackground(false)
                    tooltipFrame:SetTooltip(data.tooltip)
                    tooltipFrame:SetTooltipPanelOverride("BattleBeatsTooltip")

                    local icon = vgui.Create("DImage", tooltipFrame)
                    icon:SetSize(16, 16)
                    icon:SetPos(0, 0)
                    icon:SetImage(data.image)

                    xOffset = xOffset - 20
                end
            end

            local colorLerp = excluded and c25500 or c2552100
            local targetColor = colorLerp
            local customCheckbox = vgui.Create("DPanel", row)
            customCheckbox:SetSize(85, 25)
            customCheckbox:SetPos(860, 12.5)
            customCheckbox:SetCursor("hand")
            customCheckbox.OnCursorEntered = function(self)
                targetColor = excluded and Color(255, 80, 80) or Color(255, 230, 50)
            end
            customCheckbox.OnCursorExited = function(self)
                targetColor = excluded and c25500 or c2552100
            end
            customCheckbox:SetTooltip(excluded and "#btb.ps.ts.exclude_tip" or "#btb.ps.ts.include_tip")

            customCheckbox.OnMousePressed = function(self)
                excluded = not excluded
                BATTLEBEATS.excludedTracks[track] = excluded
                changesMade = true
                BATTLEBEATS.SaveExcludedTracks()
                targetColor = excluded and c25500 or c2552100
                customCheckbox:SetTooltip(excluded and "#btb.ps.ts.exclude_tip" or "#btb.ps.ts.include_tip")
                surface.PlaySound(excluded and "btb_button_disable.mp3" or "btb_button_enable.mp3")
            end
            customCheckbox:SetTooltipPanelOverride("BattleBeatsTooltip")

            customCheckbox.Paint = function(self, w, h)
                colorLerp = LerpColor(FrameTime() * 10, colorLerp, targetColor)
                draw.RoundedBox(6, 0, 0, w, h, colorLerp)
                local text = excluded and "#btb.ps.ts.track_disabled" or "#btb.ps.ts.track_enabled"
                draw.SimpleTextOutlined(text, "BattleBeats_Checkbox_Font", w / 2, 3, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 0.9, c000200)
            end

            row.OnMousePressed = function(self, keyCode)
                if keyCode == MOUSE_LEFT then
                    selectedRow = row.trackName
                end
            end

            row.OnCursorEntered = function(self)
                self.isScrolling = textWidth > panelWidth
            end
            row.OnCursorExited = function(self)
                self.isScrolling = false
                self.scrollResetTime = CurTime()
            end

            row.currentColor = cHover
            row.targetColor = cHover
            row.initialized = false

            local texGradient = surface.GetTextureID("gui/gradient")
            row.Think = function(self)
                local isSelected = (self.trackName == selectedRow)

                if isSelected then
                    self.targetColor = c808080255
                elseif self:IsHovered() then
                    self.targetColor = cHover2
                else
                    self.targetColor = cHover
                end

                if not self.initialized then
                    self.initialized = true
                    self.currentColor = self.targetColor
                    return
                end

                if not colorsEqual(self.currentColor, self.targetColor) then
                    self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
                end
            end

            row.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, self.currentColor)
                if isAllMode then
                    local gradientCol = Color(0, 0, 0, 0)

                    if row.actualType == "combat" then
                        gradientCol = Color(255, 80, 40, 80)
                    elseif row.actualType == "ambient" then
                        gradientCol = Color(60, 180, 60, 70)
                    end

                    surface.SetDrawColor(gradientCol)
                    surface.SetTexture(texGradient)
                    surface.DrawTexturedRect(0, 0, w - 250, h)
                end
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
                draw.SimpleTextOutlined(displayName, "BattleBeats_Font", self.textX, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, c000200)
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
                    local copy = menu:AddOption("#btb.ps.ts.rmb.copy", function()
                        SetClipboardText(track)
                    end)
                    copy:SetImage("icon16/tag.png")

                    --MARK:RMB favorites
                    if isFavorite then
                        local unfavorite = menu:AddOption("#btb.ps.ts.rmb.remove_fav", function()
                            BATTLEBEATS.favoriteTracks[track] = nil
                            BATTLEBEATS.SaveFavoriteTracks()
                            changesMade = true
                            createTrackList(parent, trackType, selectedPack)
                        end)
                        unfavorite:SetImage("icon16/cancel.png")
                    elseif favoriteCount < 255 then
                        local favorite = menu:AddOption("#btb.ps.ts.rmb.add_fav", function()
                            BATTLEBEATS.favoriteTracks[track] = true
                            BATTLEBEATS.SaveFavoriteTracks()
                            changesMade = true
                            createTrackList(parent, trackType, selectedPack)
                        end)
                        favorite:SetImage("icon16/star.png")
                    else
                        local nofavorite = menu:AddOption("Add to Favorites (Limit Reached [25])", function() end)
                        nofavorite:SetEnabled(false)
                        nofavorite:SetImage("icon16/error_delete.png")
                    end

                    --MARK:RMB offset
                    local offsetValue = BATTLEBEATS.trackOffsets[track] or 0
                    local offsetOptionTitle = language.GetPhrase("#btb.ps.ts.rmb.offset_edit")
                    local offsetOption = menu:AddOption(offsetValue > 0 and offsetOptionTitle .. " (" .. offsetValue .. "s)" or "#btb.ps.ts.rmb.offset_set", function()
                        local offsetFrame = vgui.Create("DFrame")
                        offsetFrame:SetTitle("#btb.ps.ts.rmb.offset_title")
                        offsetFrame:SetSize(250, 110)
                        offsetFrame:Center()
                        offsetFrame:MakePopup()
                        offsetFrame.Paint = function(self, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, c000200)
                        end

                        local label = vgui.Create("DLabel", offsetFrame)
                        label:SetPos(10, 30)
                        label:SetSize(230, 20)
                        label:SetText("#btb.ps.ts.rmb.offset_text")

                        local textEntry = vgui.Create("DTextEntry", offsetFrame)
                        textEntry:SetPos(10, 50)
                        textEntry:SetSize(230, 20)
                        textEntry:SetNumeric(true)
                        textEntry:SetValue(offsetValue)

                        local saveButton = vgui.Create("DButton", offsetFrame)
                        saveButton:SetPos(10, 75)
                        saveButton:SetSize(110, 25)
                        saveButton:SetText("#btb.ps.ts.rmb.offset_save")
                        saveButton.DoClick = function()
                            local newOffset = tonumber(textEntry:GetValue()) or 0
                            if newOffset > 0 then
                                BATTLEBEATS.trackOffsets[track] = newOffset
                                notification.AddLegacy("Set offset " .. newOffset .. "s for track: " .. BATTLEBEATS.FormatTrackName(track), NOTIFY_GENERIC, 3)
                                surface.PlaySound("buttons/button14.wav")
                                changesMade = true
                                createTrackList(parent, trackType, selectedPack)
                            else
                                BATTLEBEATS.trackOffsets[track] = nil
                                notification.AddLegacy("Removed offset from track: " .. BATTLEBEATS.FormatTrackName(track), NOTIFY_GENERIC, 3)
                                surface.PlaySound("buttons/button14.wav")
                                changesMade = true
                                createTrackList(parent, trackType, selectedPack)
                            end
                            BATTLEBEATS.SaveTrackOffsets()
                            offsetFrame:Close()
                        end

                        local cancelButton = vgui.Create("DButton", offsetFrame)
                        cancelButton:SetPos(130, 75)
                        cancelButton:SetSize(110, 25)
                        cancelButton:SetText("#btb.ps.ts.rmb.offset_cancel")
                        cancelButton.DoClick = function()
                            offsetFrame:Close()
                        end
                    end)
                    offsetOption:SetImage("icon16/time.png")
                    offsetOption:SetTooltip("#btb.ps.ts.rmb.offset_tip")
                    offsetOption:SetTooltipPanelOverride("BattleBeatsTooltip")

                    --MARK:RMB npc assign
                    if row.actualType == "combat" then
                        local currentNPCs = BATTLEBEATS.npcTrackMappings[track] and
                        BATTLEBEATS.npcTrackMappings[track].npcs or {}

                        local priorityNames = {
                            [1] = "1 " .. language.GetPhrase("btb.ps.ts.rmb.assign_priority_highest"),
                            [2] = "2",
                            [3] = "3",
                            [4] = "4",
                            [5] = "5 " .. language.GetPhrase("btb.ps.ts.rmb.assign_priority_lowest")
                        }

                        local assignNPC = menu:AddOption("#btb.ps.ts.rmb.assign_add", function()
                            assignFrame = vgui.Create("DFrame")
                            assignFrame:SetTitle("#btb.ps.ts.rmb.assign_title")
                            assignFrame:SetSize(400, 110)
                            assignFrame:Center()
                            assignFrame:MakePopup()
                            assignFrame.Paint = function(self, w, h)
                                draw.RoundedBox(4, 0, 0, w, h, c000200)
                            end

                            local classLabel = vgui.Create("DLabel", assignFrame)
                            classLabel:SetPos(10, 25)
                            classLabel:SetSize(270, 20)
                            classLabel:SetText("#btb.ps.ts.rmb.assign_class")

                            local textEntry = vgui.Create("DTextEntry", assignFrame)
                            textEntry:SetPos(10, 45)
                            textEntry:SetSize(250, 20)
                            textEntry:SetPlaceholderText("#btb.ps.ts.rmb.assign_enter_class")

                            local helpBtn = vgui.Create("DImage", assignFrame)
                            helpBtn:SetPos(267.5, 47.5)
                            helpBtn:SetSize(15, 15)
                            helpBtn:SetImage("icon16/help.png")
                            helpBtn:SetMouseInputEnabled(true)
                            helpBtn:SetImageTooltip("assignhelp.png", "#btb.ps.ts.rmb.assign_img_tip")

                            local priorityLabel = vgui.Create("DLabel", assignFrame)
                            priorityLabel:SetPos(290, 25)
                            priorityLabel:SetSize(100, 20)
                            priorityLabel:SetText("#btb.ps.ts.rmb.assign_priority")

                            local priorityCombo = vgui.Create("DComboBox", assignFrame)
                            priorityCombo:SetPos(290, 45)
                            priorityCombo:SetSize(100, 20)
                            for i = 1, 5 do
                                priorityCombo:AddChoice(priorityNames[i], i)
                            end
                            priorityCombo:SetValue(priorityNames[1])

                            local saveButton = vgui.Create("DButton", assignFrame)
                            saveButton:SetPos(45, 75)
                            saveButton:SetSize(150, 25)
                            saveButton:SetText("#btb.ps.ts.rmb.assign_save")
                            saveButton:SetFont("CreditsText")
                            saveButton:SetTextColor(color_white)
                            saveButton.DoClick = function()
                                local class = textEntry:GetText():gsub("^%s*(.-)%s*$", "%1")
                                local _, priority = priorityCombo:GetSelected()
                                priority = math.Clamp(priority or 1, 1, 5)

                                if not class or class == "" then
                                    notification.AddLegacy("#btb.ps.ts.rmb.assign_no_class", NOTIFY_ERROR, 3)
                                    surface.PlaySound("buttons/button11.wav")
                                    return
                                end

                                local isDuplicateInTrack = false
                                if BATTLEBEATS.npcTrackMappings[track] and BATTLEBEATS.npcTrackMappings[track].npcs then
                                    for _, npc in ipairs(BATTLEBEATS.npcTrackMappings[track].npcs) do
                                        if npc.class == class then
                                            isDuplicateInTrack = true
                                            break
                                        end
                                    end
                                end

                                local oldTrack = nil
                                if not isDuplicateInTrack then
                                    for t, info in pairs(BATTLEBEATS.npcTrackMappings) do
                                        if t ~= track and info.npcs then
                                            for _, npc in ipairs(info.npcs) do
                                                if npc.class == class then
                                                    oldTrack = t
                                                    break
                                                end
                                            end
                                            if oldTrack then break end
                                        end
                                    end
                                end

                                local function assignNPCToTrack()
                                    BATTLEBEATS.npcTrackMappings[track] = BATTLEBEATS.npcTrackMappings[track] or {npcs = {}}
                                    table.insert(BATTLEBEATS.npcTrackMappings[track].npcs, { class = class, priority = priority })
                                    if oldTrack and BATTLEBEATS.npcTrackMappings[oldTrack] then
                                        for i = #BATTLEBEATS.npcTrackMappings[oldTrack].npcs, 1, -1 do
                                            if BATTLEBEATS.npcTrackMappings[oldTrack].npcs[i].class == class then
                                                table.remove(BATTLEBEATS.npcTrackMappings[oldTrack].npcs, i)
                                                break
                                            end
                                        end
                                        if #BATTLEBEATS.npcTrackMappings[oldTrack].npcs == 0 then
                                            BATTLEBEATS.npcTrackMappings[oldTrack] = nil
                                        end
                                    end
                                    notification.AddLegacy(language.GetPhrase("btb.ps.ts.rmb.assign_noti_class") .. ": " .. class .. " " .. language.GetPhrase("btb.ps.ts.rmb.assign_noti_priority") .. " " .. priority .. " " .. language.GetPhrase("btb.ps.ts.rmb.assign_noti_track") .. ": " .. BATTLEBEATS.FormatTrackName(track), NOTIFY_GENERIC, 3)
                                    surface.PlaySound("buttons/button14.wav")
                                    BATTLEBEATS.SaveNPCMappings()
                                    changesMade = true
                                    assignFrame:Close()
                                    createTrackList(parent, trackType, selectedPack)
                                end

                                if isDuplicateInTrack then
                                    notification.AddLegacy("NPC '" .. class .. "' " .. language.GetPhrase("btb.ps.ts.rmb.assign_this_track"), NOTIFY_ERROR, 3)
                                    surface.PlaySound("buttons/button11.wav")
                                elseif oldTrack then
                                    surface.PlaySound("buttons/button17.wav")
                                    Derma_Query("NPC: (" .. class .. ") " .. language.GetPhrase("btb.ps.ts.rmb.assign_already_assigned") .. ": (" .. BATTLEBEATS.FormatTrackName(oldTrack) .. "). " .. language.GetPhrase("btb.ps.ts.rmb.assign_overwrite"),
                                        "#btb.ps.ts.rmb.assign_conf_overwrite", "#btb.ps.ts.rmb.assign_yes", function() assignNPCToTrack() end, "#btb.ps.ts.rmb.assign_no", function() end)
                                else
                                    assignNPCToTrack()
                                end
                            end
                            saveButton.Paint = function(self, w, h)
                                local bgColor = self:IsHovered() and c808080255 or c707070255
                                draw.RoundedBox(4, 0, 0, w, h, bgColor)
                            end

                            local cancelButton = vgui.Create("DButton", assignFrame)
                            cancelButton:SetPos(205, 75)
                            cancelButton:SetSize(150, 25)
                            cancelButton:SetText("#btb.ps.ts.rmb.offset_cancel")
                            cancelButton:SetFont("CreditsText")
                            cancelButton:SetTextColor(color_white)
                            cancelButton.Paint = function(self, w, h)
                                local bgColor = self:IsHovered() and c808080255 or c707070255
                                draw.RoundedBox(4, 0, 0, w, h, bgColor)
                            end
                            cancelButton.DoClick = function() assignFrame:Close() end
                        end)
                        assignNPC:SetImage("icon16/user_add.png")
                        assignNPC:SetTooltip("#btb.ps.ts.rmb.assign_tip")
                        assignNPC:SetTooltipPanelOverride("BattleBeatsTooltip")

                        for _, npcInfo in ipairs(currentNPCs) do
                            local s1 = language.GetPhrase("#btb.ps.ts.rmb.assign_current")
                            local s2 = language.GetPhrase("#btb.ps.ts.rmb.assign_priority")
                            local npcText = s1 .. npcInfo.class .. " (" .. s2 .. npcInfo.priority .. ")"

                            local subMenu, parentOption = menu:AddSubMenu(npcText)
                            parentOption:SetImage("icon16/vcard.png")

                            local editOpt = subMenu:AddOption("#btb.ps.ts.rmb.assign_edit", function()
                                assignFrame = vgui.Create("DFrame")
                                assignFrame:SetTitle(language.GetPhrase("#btb.ps.ts.rmb.assign_edit") .. ": " .. npcInfo.class)
                                assignFrame:SetSize(400, 110)
                                assignFrame:Center()
                                assignFrame:MakePopup()
                                assignFrame.Paint = function(self, w, h)
                                    draw.RoundedBox(4, 0, 0, w, h, c000200)
                                end

                                local classLabel = vgui.Create("DLabel", assignFrame)
                                classLabel:SetPos(10, 25)
                                classLabel:SetSize(270, 20)
                                classLabel:SetText("#btb.ps.ts.rmb.assign_class")

                                local textEntry = vgui.Create("DTextEntry", assignFrame)
                                textEntry:SetPos(10, 45)
                                textEntry:SetSize(250, 20)
                                textEntry:SetText(npcInfo.class)

                                local helpBtn = vgui.Create("DImage", assignFrame)
                                helpBtn:SetPos(267.5, 47.5)
                                helpBtn:SetSize(15, 15)
                                helpBtn:SetImage("icon16/help.png")
                                helpBtn:SetMouseInputEnabled(true)
                                helpBtn:SetImageTooltip("assignhelp.png", "#btb.ps.ts.rmb.assign_img_tip")

                                local priorityLabel = vgui.Create("DLabel", assignFrame)
                                priorityLabel:SetPos(290, 25)
                                priorityLabel:SetSize(100, 20)
                                priorityLabel:SetText("#btb.ps.ts.rmb.assign_priority")

                                local priorityCombo = vgui.Create("DComboBox", assignFrame)
                                priorityCombo:SetPos(290, 45)
                                priorityCombo:SetSize(100, 20)
                                for i = 1, 5 do
                                    priorityCombo:AddChoice(priorityNames[i], i)
                                end
                                priorityCombo:SetValue(priorityNames[npcInfo.priority] or priorityNames[1])

                                local saveButton = vgui.Create("DButton", assignFrame)
                                saveButton:SetPos(45, 75)
                                saveButton:SetSize(150, 25)
                                saveButton:SetText("#btb.ps.ts.rmb.assign_save")
                                saveButton:SetFont("CreditsText")
                                saveButton:SetTextColor(color_white)
                                saveButton.DoClick = function()
                                    local newClass = textEntry:GetText():gsub("^%s*(.-)%s*$", "%1")
                                    local _, newPrio = priorityCombo:GetSelected()
                                    newPrio = math.Clamp(newPrio or npcInfo.priority, 1, 5)

                                    if not newClass or newClass == "" then
                                        notification.AddLegacy("#btb.ps.ts.rmb.assign_no_class", NOTIFY_ERROR, 3)
                                        surface.PlaySound("buttons/button11.wav")
                                        return
                                    end

                                    if newClass == npcInfo.class then
                                        for i, npc in ipairs(BATTLEBEATS.npcTrackMappings[track].npcs) do
                                            if npc.class == npcInfo.class then
                                                BATTLEBEATS.npcTrackMappings[track].npcs[i].priority = newPrio
                                                break
                                            end
                                        end
                                        BATTLEBEATS.SaveNPCMappings()
                                        changesMade = true
                                        notification.AddLegacy(language.GetPhrase("btb.ps.ts.rmb.assign_edited") .. ": " .. npcInfo.class .. " → " .. newClass .. " (" .. newPrio .. ")", NOTIFY_GENERIC, 3)
                                        surface.PlaySound("buttons/button14.wav")
                                        assignFrame:Close()
                                        createTrackList(parent, trackType, selectedPack)
                                        return
                                    end

                                    local isDuplicateInTrack = false
                                    for _, npc in ipairs(BATTLEBEATS.npcTrackMappings[track].npcs) do
                                        if npc.class == newClass and npc.class ~= npcInfo.class then
                                            isDuplicateInTrack = true
                                            break
                                        end
                                    end

                                    if isDuplicateInTrack then
                                        notification.AddLegacy("NPC '" .. newClass .. "' " .. language.GetPhrase("btb.ps.ts.rmb.assign_this_track"), NOTIFY_ERROR, 3)
                                        surface.PlaySound("buttons/button11.wav")
                                        return
                                    end

                                    local oldTrack = nil
                                    for t, info in pairs(BATTLEBEATS.npcTrackMappings) do
                                        if t ~= track and info.npcs then
                                            for _, npc in ipairs(info.npcs) do
                                                if npc.class == newClass then
                                                    oldTrack = t
                                                    break
                                                end
                                            end
                                            if oldTrack then break end
                                        end
                                    end

                                    local function saveEdit()
                                        for i = #BATTLEBEATS.npcTrackMappings[track].npcs, 1, -1 do
                                            if BATTLEBEATS.npcTrackMappings[track].npcs[i].class == npcInfo.class then
                                                table.remove(BATTLEBEATS.npcTrackMappings[track].npcs, i)
                                                break
                                            end
                                        end
                                        table.insert(BATTLEBEATS.npcTrackMappings[track].npcs, {class = newClass, priority = newPrio})
                                        if oldTrack and BATTLEBEATS.npcTrackMappings[oldTrack] then
                                            for j = #BATTLEBEATS.npcTrackMappings[oldTrack].npcs, 1, -1 do
                                                if BATTLEBEATS.npcTrackMappings[oldTrack].npcs[j].class == newClass then
                                                    table.remove(BATTLEBEATS.npcTrackMappings[oldTrack].npcs, j)
                                                    break
                                                end
                                            end
                                            if #BATTLEBEATS.npcTrackMappings[oldTrack].npcs == 0 then
                                                BATTLEBEATS.npcTrackMappings[oldTrack] = nil
                                            end
                                        end
                                        BATTLEBEATS.SaveNPCMappings()
                                        changesMade = true
                                        notification.AddLegacy(
                                        language.GetPhrase("btb.ps.ts.rmb.assign_edited") .. ": " .. npcInfo.class .. " → " .. newClass .. " (" .. newPrio .. ")", NOTIFY_GENERIC, 3)
                                        surface.PlaySound("buttons/button14.wav")
                                        assignFrame:Close()
                                        createTrackList(parent, trackType, selectedPack)
                                    end

                                    if oldTrack then
                                        surface.PlaySound("buttons/button17.wav")
                                        Derma_Query("NPC: (" .. newClass .. ") " .. language.GetPhrase("btb.ps.ts.rmb.assign_already_assigned") .. ": (" .. BATTLEBEATS.FormatTrackName(oldTrack) .. "). " .. language.GetPhrase("btb.ps.ts.rmb.assign_overwrite"),
                                        "#btb.ps.ts.rmb.assign_conf_overwrite", "#btb.ps.ts.rmb.assign_yes", function() saveEdit() end, "#btb.ps.ts.rmb.assign_no", function() end)
                                    else
                                        saveEdit()
                                    end
                                end
                                saveButton.Paint = function(s, w, h)
                                    local bg = s:IsHovered() and c808080255 or c707070255
                                    draw.RoundedBox(4, 0, 0, w, h, bg)
                                end

                                local cancelButton = vgui.Create("DButton", assignFrame)
                                cancelButton:SetPos(205, 75)
                                cancelButton:SetSize(150, 25)
                                cancelButton:SetText("#btb.ps.ts.rmb.offset_cancel")
                                cancelButton:SetFont("CreditsText")
                                cancelButton:SetTextColor(color_white)
                                cancelButton.Paint = function(self, w, h)
                                    local bgColor = self:IsHovered() and c808080255 or c707070255
                                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                                end
                                cancelButton.DoClick = function() assignFrame:Close() end
                            end)
                            editOpt:SetImage("icon16/user_edit.png")

                            local removeOpt = subMenu:AddOption("#btb.ps.ts.rmb.assign_remove", function()
                                for i = #BATTLEBEATS.npcTrackMappings[track].npcs, 1, -1 do
                                    if BATTLEBEATS.npcTrackMappings[track].npcs[i].class == npcInfo.class then
                                        table.remove(BATTLEBEATS.npcTrackMappings[track].npcs, i)
                                        break
                                    end
                                end
                                if #BATTLEBEATS.npcTrackMappings[track].npcs == 0 then
                                    BATTLEBEATS.npcTrackMappings[track] = nil
                                end
                                BATTLEBEATS.SaveNPCMappings()
                                changesMade = true
                                notification.AddLegacy(language.GetPhrase("btb.ps.ts.rmb.assign_removed") .. ": " .. npcInfo.class, NOTIFY_GENERIC, 3)
                                surface.PlaySound("buttons/button3.wav")
                                createTrackList(parent, trackType, selectedPack)
                            end)
                            removeOpt:SetImage("icon16/user_delete.png")
                        end
                    end

                    --MARK:RMB subtitles
                    local subs = BATTLEBEATS.parsedSubtitles[string.lower(trackName)]
                    if subs and #subs > 0 then
                        local lyricsOption = menu:AddOption("#btb.ps.ts.rmb.show_lyrics", function()
                            lframe = vgui.Create("DFrame")
                            local title = language.GetPhrase("#btb.ps.ts.rmb.show_lyrics_title")
                            lframe:SetTitle(title .. trackName)
                            lframe:SetSize(500, 400)
                            lframe:Center()
                            lframe:MakePopup()
                            lframe.Paint = function(self, w, h)
                                draw.RoundedBox(4, 0, 0, w, h, c000200)
                            end

                            local scroll = vgui.Create("DScrollPanel", lframe)
                            scroll:SetSize(480, 360)
                            scroll:SetPos(10, 30)

                            local rich = vgui.Create("RichText", scroll)
                            rich:SetSize(480, 360)
                            rich:SetVerticalScrollbarEnabled(true)
                            rich:SetWrap(true)
                            rich.PerformLayout = function(self)
                                if self:GetFont() ~= "ChatFont" then self:SetFontInternal("ChatFont") end
                                self:SetFGColor(color_white)
                            end

                            local lastEnd = 0
                            for _, sub in ipairs(subs) do
                                if lastEnd > 0 and (sub.start - lastEnd) > 5 then
                                    rich:AppendText("\n")
                                end
                                local m = math.floor(sub.start / 60)
                                local s = math.floor(sub.start % 60)
                                local ts = string.format("[%02d:%02d]", m, s)
                                rich:InsertColorChange(255, 210, 0, 255)
                                rich:AppendText(ts .. " ")
                                rich:InsertColorChange(255, 255, 255, 255)
                                rich:AppendText(sub.text .. "\n")
                                lastEnd = sub['end']
                            end
                        end)
                        lyricsOption:SetImage("icon16/text_align_left.png")
                    end
                    menu:Open()
                end
            end

            return row
        end

        local div = vgui.Create("DPanel", parent)
        div:Dock(TOP)
        div:SetTall(3)
        div:DockMargin(0, 0, 15, 5)
        div.Paint = function(self, w, h)
            draw.RoundedBox(1, 0, 0, w, h, c2552100)
        end

        --MARK:Sorting & search
        local searchPanel = vgui.Create("DPanel", parent)
        searchPanel:Dock(TOP)
        searchPanel:SetTall(60)
        searchPanel:DockMargin(0, 5, 15, 10)
        searchPanel.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, c2552100)
            draw.RoundedBox(8, 2, 2, w - 4, h - 4, c404040)
            surface.SetFont("DermaDefaultBold")

            local nameText = "#btb.ps.ts.header.name"
            local excludeText = "#btb.ps.ts.header.exclude"
            local listText = trackType == "ambient" and "#btb.ps.ts.header.ambient_list" or "#btb.ps.ts.header.combat_list"

            local excludeW = surface.GetTextSize(excludeText)
            local listW = surface.GetTextSize(listText)

            draw.SimpleText(nameText, "DermaDefaultBold", 40, 45, c100100100, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(excludeText, "DermaDefaultBold", w - excludeW - 40, 45, c100100100, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if isAllMode then return end
            draw.SimpleText(listText, "DermaDefaultBold", w / 2 - listW / 2, 45, c100100100, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        searchBox = vgui.Create("DTextEntry", searchPanel)
        searchBox:SetSize(600, 30)
        searchBox:SetPos(170, 10)
        searchBox:SetFont("BattleBeats_Font")
        searchBox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, c707070255)
            self:DrawTextEntryText(color_white, color_white, color_white)
            if self:GetText() == "" and not self:IsEditing() then
                draw.SimpleText("#btb.ps.search", "BattleBeats_Font", 5, h / 2, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        local sortCombo = vgui.Create("DComboBox", searchPanel)
        sortCombo:SetSize(100, 30)
        sortCombo:SetPos(830, 11)
        sortCombo:SetValue("A → Z")
        sortCombo:AddChoice("A → Z", "az", false, "icon16/arrow_down.png")
        sortCombo:AddChoice("Z → A", "za", false, "icon16/arrow_up.png")
        sortCombo:AddChoice("#btb.ps.sort.random", "rnd", false, "icon16/arrow_switch.png")
        sortCombo:AddChoice("#btb.ps.sort.favorite_only", "fav", false, "icon16/star.png")
        sortCombo:AddChoice("#btb.ps.sort.include_only", "inc", false, "icon16/tick.png")
        sortCombo:AddChoice("#btb.ps.sort.exclude_only", "ex", false, "icon16/cross.png")
        if isAllMode or trackType == "combat" then
            sortCombo:AddChoice("#btb.ps.sort.assigned_only", "assigned", false, "icon16/user.png")
        end
        sortCombo:AddChoice("#btb.ps.sort.offset_only", "offset", false, "icon16/time.png")
        sortCombo:SetSortItems(false)
        sortCombo:ChooseOptionID(1)
        --sortCombo:SetContentAlignment(5)
        sortCombo:SetTextColor(color_white)
        sortCombo:SetTooltip("#btb.ps.sort.tooltip")
        sortCombo:SetTooltipPanelOverride("BattleBeatsTooltip")
        sortCombo.DropButton:SetVisible(false)
        sortCombo.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, c404040)
        end

        local includeExcludeCombo = vgui.Create("DComboBox", searchPanel)
        includeExcludeCombo:SetSize(100, 30)
        includeExcludeCombo:SetPos(50, 11)
        includeExcludeCombo:SetValue("#btb.ps.sort.options")
        includeExcludeCombo:AddChoice("#btb.ps.sort.options_include", nil, false, "icon16/tick.png")
        includeExcludeCombo:AddChoice("#btb.ps.sort.options_exclude", nil, false, "icon16/delete.png")
        includeExcludeCombo:SetSortItems(false)
        includeExcludeCombo:SetTextColor(color_white)
        includeExcludeCombo.DropButton:SetVisible(false)
        includeExcludeCombo.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, c404040)
        end

        local packType = BATTLEBEATS.musicPacks[selectedPack].packType
        if packType ~= "16thnote" and packType ~= "battlebeats" and packType ~= "local" then
            local inforow = vgui.Create("DPanel", parent)
            inforow:SetSize(0, 30)
            inforow:Dock(TOP)
            inforow:DockMargin(0, 0, 15, 10)
            inforow.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, cHover)
                draw.SimpleText("#btb.ps.ts.format", "BattleBeats_Notification_Font_Misc", w / 2, h / 2, c255255255200, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        local divider = vgui.Create("DPanel", parent)
        divider:Dock(TOP)
        divider:SetTall(3)
        divider:DockMargin(0, 0, 15, 5)
        divider.Paint = function(self, w, h)
            draw.RoundedBox(1, 0, 0, w, h, c2552100)
        end

        local trackRows = {}
        local noResultsLabel
        local function filterAndSort()
            if not IsValid(searchBox) then return end
            local query = string.lower(searchBox:GetValue())
            local sortMode = sortCombo:GetOptionData(sortCombo:GetSelectedID()) or "az"

            for _, row in ipairs(trackRows) do row:Remove() end
            trackRows = {}

            if IsValid(noResultsLabel) then
                noResultsLabel:Remove()
            end

            local tracks = {}
            local typesToProcess = isAllMode and {"ambient", "combat"} or {trackType}
            for _, tType in ipairs(typesToProcess) do
                for _, t in ipairs(BATTLEBEATS.musicPacks[selectedPack][tType] or {}) do
                    local name = string.lower(BATTLEBEATS.FormatTrackName(t))
                    local excluded = BATTLEBEATS.excludedTracks[t]
                    local favorite = BATTLEBEATS.favoriteTracks[t]

                    if query == "" or string.find(name, query, 1, true) then
                        if sortMode == "fav" and not favorite then continue end
                        if sortMode == "ex" and not excluded then continue end
                        if sortMode == "inc" and excluded then continue end

                        table.insert(tracks, {
                            track = t,
                            name = name,
                            fav = favorite,
                            ex = excluded,
                            type = tType
                        })
                    end
                end
            end
            if sortMode == "rnd" then
                for i = #tracks, 2, -1 do
                    local j = math.random(i)
                    tracks[i], tracks[j] = tracks[j], tracks[i]
                end
            else
                if sortMode == "assigned" or sortMode == "offset" then
                    local filtered = {}
                    for _, data in ipairs(tracks) do
                        local hasFeature = false

                        if sortMode == "assigned" then
                            hasFeature = BATTLEBEATS.npcTrackMappings[data.track] and
                            #BATTLEBEATS.npcTrackMappings[data.track].npcs > 0
                        elseif sortMode == "offset" then
                            hasFeature = BATTLEBEATS.trackOffsets[data.track] and
                            BATTLEBEATS.trackOffsets[data.track] > 0
                        end

                        if hasFeature then
                            table.insert(filtered, data)
                        end
                    end
                    tracks = filtered
                end
                table.sort(tracks, function(a, b)
                    if a.fav and not b.fav then return true end
                    if not a.fav and b.fav then return false end

                    if sortMode == "az" or sortMode == "fav" or sortMode == "ex" or sortMode == "inc" or sortMode == "assigned" or sortMode == "offset" then
                        return a.name < b.name
                    elseif sortMode == "za" then
                        return a.name > b.name
                    end
                    return false
                end)
            end

            currentFilteredTracks = {}
            if #tracks == 0 then
                noResultsLabel = vgui.Create("DLabel", parent)
                noResultsLabel:SetSize(0, 50)
                noResultsLabel:Dock(TOP)
                noResultsLabel:DockMargin(0, 5, 0, 0)
                noResultsLabel:SetText("#btb.ps.sort.nothing_found")
                noResultsLabel:SetFont("BattleBeats_Font")
                noResultsLabel:SetTextColor(Color(255, 80, 80))
                noResultsLabel:SetContentAlignment(5)
                noResultsLabel.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(40, 20, 20, 200))
                end
            else
                for _, data in ipairs(tracks) do
                    local row = addTrackRow(data.track, data.ex, data.fav, data.type)
                    table.insert(trackRows, row)
                    table.insert(currentFilteredTracks, data.track)
                end
            end
        end

        includeExcludeCombo.OnSelect = function(_, _, value)
            if value == "#btb.ps.sort.options_include" then
                for _, t in ipairs(currentFilteredTracks or {}) do
                    BATTLEBEATS.excludedTracks[t] = false
                end
            elseif value == "#btb.ps.sort.options_exclude" then
                for _, t in ipairs(currentFilteredTracks or {}) do
                    BATTLEBEATS.excludedTracks[t] = true
                end
            end
            includeExcludeCombo:SetValue("#btb.ps.sort.options")
            filterAndSort()
        end

        searchBox.OnChange = function() timer.Create("BattleBeats_SearchDelay", 0.3, 1, filterAndSort) end
        sortCombo.OnSelect = filterAndSort
        scrollPanel:ScrollToChild(searchPanel)
        filterAndSort()
    end

    --MARK:Main UI list
    local expandedPanel = nil
    local selectedPanel = nil
    local selectedPackName = nil
    local expandedPackName = nil

    local c2201200150 = Color(220, 120, 0, 150)
    local function createBasePanel(parent, call)
        local panel = vgui.Create("DPanel", parent)
        panel:Dock(TOP)
        panel:DockMargin(0, 5, 0, 0)
        panel:SetTall(41)
        panel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, c2201200150)
        end
        local icon = vgui.Create("DImage", panel)
        icon:Dock(LEFT)
        icon:SetWide(30)
        icon:DockMargin(5, 5, 5, 5)
        icon:SetImage("btberror.png")
        icon:SetKeepAspect(true)
        if call then
            call(panel)
        end
        return panel
    end

    local function showConflicts()
        if not table.IsEmpty(BATTLEBEATS.activeConflicts) then
            createBasePanel(scrollPanel, function(panel)
                local conflictNames = table.GetKeys(BATTLEBEATS.activeConflicts)
                local label1 = vgui.Create("DLabel", panel)
                label1:Dock(TOP)
                label1:SetTall(20)
                label1:SetText(language.GetPhrase("btb.ps.error.conflict1") .. ": " .. table.concat(conflictNames, ", "))
                label1:SetFont("BattleBeats_Notification_Font_Misc")
                label1:SetTextColor(color_white)
                label1:SetContentAlignment(5)
                local label2 = vgui.Create("DLabel", panel)
                label2:Dock(TOP)
                label2:SetTall(20)
                label2:SetText("#btb.ps.error.conflict2")
                label2:SetFont("BattleBeats_Notification_Font_Misc")
                label2:SetTextColor(color_white)
                label2:SetContentAlignment(5)
            end)
        end
        if GetConVar("battlebeats_debug_mode"):GetBool() then
            createBasePanel(scrollPanel, function(panel)
                local label1 = vgui.Create("DLabel", panel)
                label1:Dock(TOP)
                label1:SetTall(20)
                label1:SetText("#btb.ps.error.debug1")
                label1:SetFont("BattleBeats_Notification_Font_Misc")
                label1:SetTextColor(color_white)
                label1:SetContentAlignment(5)
                local label2 = vgui.Create("DLabel", panel)
                label2:Dock(TOP)
                label2:SetTall(20)
                label2:SetText("#btb.ps.error.debug2")
                label2:SetFont("BattleBeats_Notification_Font_Misc")
                label2:SetTextColor(color_white)
                label2:SetContentAlignment(5)
            end)
        end
    end

    local function showPackList()
        scrollPanel:Clear()
        scrollPanel:SetVisible(true)
        saveButton:SetVisible(true)
        scrollBar:SetWide(0)
        frame:SetTitle("#btb.ps.title")
        showConflicts()

        local function createTrackEditor(trackType, packName, scrollPanel, frame)
            scrollPanel:Clear()
            scrollPanel:SetVisible(true)
            saveButton:SetVisible(false)
            scrollBar:SetWide(10)
            frame:SetTitle(language.GetPhrase("btb.ps.title") .. ": " .. BATTLEBEATS.stripPackPrefix(packName))
            if IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() ~= GMOD_CHANNEL_STOPPED then
                playerPanel:SetVisible(true)
                scrollPanel:SetSize(980, 430)
            end

            local backButton = vgui.Create("DButton", frame)
            backButton:SetSize(290, 40)
            backButton:SetPos(350, 650)
            backButton:SetText("#btb.ps.button.back")
            backButton:SetFont("CreditsText")
            backButton:SetTextColor(color_white)
            backButton.currentColor = c707070255
            backButton.targetColor = c707070255
            backButton.Think = function(self)
                if self:IsHovered() then
                    self.targetColor = c808080255
                else
                    self.targetColor = c707070255
                end
                self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
            end
            backButton.Paint = function(self, w, h)
                draw.RoundedBox(10, 0, 0, w, h, c2552100)
                draw.RoundedBox(8, 2, 2, w - 4, h - 4, self.currentColor)
            end
            backButton.OnCursorEntered = function(self)
                surface.PlaySound("ui/buttonrollover.wav")
            end
            backButton.DoClick = function()
                playerPanel:SetVisible(false)
                scrollPanel:SetSize(980, 600)
                backButton:Remove()
                showPackList()
            end

            createTrackList(scrollPanel, trackType, packName)
        end

        --MARK:No packs found
        if table.IsEmpty(BATTLEBEATS.musicPacks) then
            local promoPanel = vgui.Create("DPanel", frame)
            promoPanel:SetSize(850, 400)
            promoPanel:SetPos(80, 150)
            promoPanel.Paint = function(self, w, h)
                draw.RoundedBox(10, 0, 0, w, h, c2552100)
                draw.RoundedBox(8, 2, 2, w - 4, h - 4, c505050)
                draw.SimpleText("#btb.ps.no_packs_found_1", "CloseCaption_Bold", w / 2, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("#btb.ps.no_packs_found_2", "CloseCaption_Bold", w / 2, 365, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            local rbutton = vgui.Create("DButton", promoPanel)
            rbutton:SetSize(75, 30)
            rbutton:SetPos(600, 350)
            rbutton:SetText("")
            rbutton.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, color_transparent)
            end
            rbutton.DoClick = function()
                gui.OpenURL("https://steamcommunity.com/workshop/filedetails/discussion/3473911205/624436764983085955/")
            end

            local packButtons = {
                {
                    name = "Zenless Zone Zero",
                    image = "promo/btbzzz.jpg",
                    workshop = "3457857973"
                },
                {
                    name = "The Witcher 3 Wild Hunt",
                    image = "promo/btbtw3.jpg",
                    workshop = "3483273863"
                },
                {
                    name = "Devil May Cry 5",
                    image = "promo/btbdmc.jpg",
                    workshop = "3490225788"
                },
                {
                    name = "Far Cry 4",
                    image = "promo/btbfc4.jpg",
                    workshop = "3548098038"
                },
                {
                    name = "Cyberpunk 2077",
                    image = "promo/btbcp.jpeg",
                    workshop = "3556630048"
                },
                {
                    name = "Resident Evil 4",
                    image = "promo/btbre4.jpg",
                    workshop = "3588540579"
                }
            }

            local selectedPacks = {}
            local tempTable = table.Copy(packButtons)

            for i = 1, 3 do
                if #tempTable == 0 then break end
                local pack = table.Random(tempTable)
                table.insert(selectedPacks, pack)
                for k, v in ipairs(tempTable) do
                    if v == pack then
                        table.remove(tempTable, k)
                        break
                    end
                end
            end

            for i, pack in ipairs(selectedPacks) do
                local button = vgui.Create("DButton", promoPanel)
                button:SetSize(250, 270)
                button:SetPos(30 + (i - 1) * 270, 60)
                button:SetText("")
                button.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c808080255 or c707070255
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                    draw.SimpleText(pack.name, "CreditsText", w / 2, 250, color_white, TEXT_ALIGN_CENTER,
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
                    surface.SetDrawColor(color_white)
                    surface.SetMaterial(self:GetMaterial())
                    surface.DrawTexturedRect(0, 0, w, h)
                    surface.SetDrawColor(0, 0, 0, 200)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                end
            end
        end

        local cpanelerror = Color(70, 50, 50, 200)

        local cdebughover = Color(110, 110, 60, 200)
        local cdebugunselected = Color(100, 100, 60, 200)
        local cdebugselected = Color(120, 120, 60)

        local clocalhover = Color(50, 120, 120, 200)
        local clocalselected = Color(50, 120, 120)
        local clocalunselected = Color(50, 80, 80, 200)

        local cvererror = Color(150, 50, 0, 60)
        local cver = Color(255, 200, 0, 60)
        local cvertext = Color(255, 255, 255, 100)

        --MARK:Packs found
        local orderedPacks = {}
        for packName, data in pairs(BATTLEBEATS.musicPacks) do
            table.insert(orderedPacks, { name = packName, data = data })
        end

        table.sort(orderedPacks, function(a, b)
            local da = a.data or {}
            local db = b.data or {}

            local nameA = tostring(a.name or ""):lower()
            local nameB = tostring(b.name or ""):lower()

            local debugA = da.debug and true or false
            local debugB = db.debug and true or false

            if GetConVar("battlebeats_debug_mode"):GetBool() then
                if debugA ~= debugB then
                    return debugA and not debugB
                end
                if debugA and debugB then
                    return nameA < nameB
                end
            end

            local typeA = tostring(da.packType or "na")
            local typeB = tostring(db.packType or "na")

            if typeA ~= typeB then
                if typeA == "battlebeats" then return true end
                if typeB == "battlebeats" then return false end
            end

            return nameA < nameB
        end)

        local currentCategory = nil
        local function createCategoryDivider(text)
            local divPanel = vgui.Create("DPanel", scrollPanel)
            divPanel:Dock(TOP)
            divPanel:SetTall(40)
            divPanel:DockMargin(20, 5, 20, 5)
            divPanel.Paint = function(self, w, h)
                local lineY = h / 2
                surface.SetFont("BattleBeats_Font")
                local textW, _ = surface.GetTextSize(text)
                local lineLeftStart = 0
                local lineLeftEnd = (w / 2) - (textW / 2) - 30
                local lineRightStart = (w / 2) + (textW / 2) + 30
                local lineRightEnd = w
                if lineLeftEnd > lineLeftStart then
                    draw.RoundedBox(2, lineLeftStart, lineY, lineLeftEnd - lineLeftStart, 3, c2552100)
                end
                if lineRightEnd > lineRightStart then
                    draw.RoundedBox(2, lineRightStart, lineY, lineRightEnd - lineRightStart, 3, c2552100)
                end
                draw.SimpleText(text, "BattleBeats_Font", w / 2, h / 2, c2552100, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        local categoryMap = {
            debug = "DEBUG",
            battlebeats = "BattleBeats",
            nombat = "Nombat",
            sbm = "SBM",
            ["16thnote"] = "16th Note",
            amusic = "Action Music",
            dynamo = "DYNAMO",
            mp3p = "MP3 Radio",
            na = "Uncategorized",
            ["local"] = "Local"
        }

        for _, pack in pairs(orderedPacks) do
            local debugMode = GetConVar("battlebeats_debug_mode"):GetBool()
            local packName = pack.name
            local packData = pack.data
            local packType = packData.packType or "na"
            if not BATTLEBEATS.checking then
                if packData.debug == true then
                    table.insert(packNames, packName)
                end
            end
            local categoryName
            if debugMode and packData.debug then
                categoryName = categoryMap.debug
            else
                categoryName = categoryMap[packType] or "Uncategorized"
            end
            if currentCategory ~= categoryName then
                currentCategory = categoryName
                createCategoryDivider(currentCategory)
            end
            local isErrored = packData.error ~= nil
            local panel = scrollPanel:Add("DPanel")
            panel:SetSize(620, 80)
            panel:Dock(TOP)
            panel:DockMargin(0, 0, 0, 5)
            local currentColor = BATTLEBEATS.currentPacks[packName] and c2552100 or c25500
            local text = BATTLEBEATS.currentPacks[packName] and "#btb.ps.pack_enabled" or "#btb.ps.pack_disabled"
            local targetColor = currentColor
            local customCheckbox = vgui.Create("DPanel", panel)

            /*if currentCategory == categoryMap["local"] or (not debugMode and currentCategory == "Local") then
                timer.Simple(0.01, function()
                    if not IsValid(scrollPanel) then return end

                    if IsValid(scrollPanel.createLocalPackButton) then
                        scrollPanel.createLocalPackButton:Remove()
                    end

                    local createBtn = vgui.Create("DButton", scrollPanel)
                    scrollPanel.createLocalPackButton = createBtn

                    createBtn:Dock(TOP)
                    createBtn:SetTall(80)
                    createBtn:DockMargin(0, 20, 0, 10)
                    createBtn:SetText("")
                    createBtn:SetCursor("hand")

                    createBtn.Paint = function(self, w, h)
                        draw.RoundedBox(8, 4, 4, w - 8, h - 8, cHover)
                        draw.SimpleText("+ CREATE NEW LOCAL PACK", "BattleBeats_Font", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end

                    createBtn.DoClick = function()
                    end
                end)
            end*/
            
            local function createError()
                local errorIcon = vgui.Create("DImage", panel)
                errorIcon:SetPos(840, 28)
                errorIcon:SetSize(24, 24)
                errorIcon:SetImage("icon16/exclamation.png")
                local errorMessage = packData.error or "#btb.ps.unknown_error"
                errorIcon:SetTooltip("Pack error: " .. tostring(errorMessage))
                errorIcon.OnCursorEntered = function(self)
                    self:SetTooltip("Pack error: " .. tostring(errorMessage))
                end
                errorIcon:SetTooltipPanelOverride("BattleBeatsTooltip")
                errorIcon:SetMouseInputEnabled(true)
                errorIcon:SetVisible(true)
                if IsValid(customCheckbox) then
                    customCheckbox.OnMousePressed = function() end
                end
                currentColor = Color(100, 0, 0)
                targetColor = currentColor
                text = "Error"
            end

            panel.currentColor = cHover
            panel.targetColor = cHover
            panel.initialized = false
            panel.Think = function(self)
                if packData.verifying then return end

                local target
                if isErrored then
                    target = cpanelerror
                elseif self == selectedPanel then
                    if packData.debug == true then
                        target = cdebugselected
                    elseif packData.packType == "local" then
                        target = clocalselected
                    else
                        target = c707070255
                    end
                else
                    if packData.debug == true then
                        target = self:IsHovered() and cdebughover or cdebugunselected
                    elseif packData.packType == "local" then
                        target = self:IsHovered() and clocalhover or clocalunselected
                    else
                        target = self:IsHovered() and cHover2 or cHover
                    end
                end

                self.targetColor = target
                if not self.initialized then
                    self.initialized = true
                    self.currentColor = target
                    return
                end

                if not colorsEqual(self.currentColor, target) then
                    self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, target)
                end
            end

            panel.CreateErrorCalled = false
            panel.Paint = function(self, w, h)
                if packData.verifying then
                    local offset = (CurTime() * 200 * 5) % (w + 200)
                    local gradLeft = surface.GetTextureID("vgui/gradient-l")
                    local gradRight = surface.GetTextureID("vgui/gradient-r")
                    local barWidth = 300
                    local barX = offset - barWidth
                    local vColor = isErrored and cvererror or cver

                    draw.RoundedBox(4, 0, 0, w, h, Color(vColor.r, vColor.g, vColor.b, 60))

                    surface.SetTexture(gradRight)
                    surface.SetDrawColor(vColor.r, vColor.g, vColor.b, 200)
                    surface.DrawTexturedRect(barX, 0, barWidth / 2, h)
                    surface.SetTexture(gradLeft)
                    surface.DrawTexturedRect(barX + barWidth / 2, 0, barWidth / 2, h)

                    local loopX = barX - (w + barWidth)
                    surface.SetTexture(gradRight)
                    surface.DrawTexturedRect(loopX, 0, barWidth / 2, h)
                    surface.SetTexture(gradLeft)
                    surface.DrawTexturedRect(loopX + barWidth / 2, 0, barWidth / 2, h)

                    isErrored = packData.error ~= nil
                    if isErrored and not self.CreateErrorCalled then
                        self.CreateErrorCalled = true
                        createError()
                    end
                    return
                elseif debugMode and not packData.debug then
                    draw.RoundedBox(4, 0, 0, w, h, Color(10, 10, 10, 200))
                    return
                end
                draw.RoundedBox(4, 0, 0, w, h, self.currentColor)
            end

            panel.OnCursorEntered = function(self)
                if not isErrored and not packData.verifying and not (debugMode and not packData.debug) then
                    self:SetCursor("hand")
                elseif packData.verifying then
                    self:SetCursor("hourglass")
                elseif isErrored or (debugMode and not packData.debug) then
                    self:SetCursor("no")
                end
            end
            panel.OnCursorExited = function(self)
                self:SetCursor("arrow")
            end

            local packLabel = vgui.Create("DPanel", panel)
            packLabel:SetPos(10, 5)
            packLabel:SetSize(800, 80)
            packLabel:SetPaintBackground(false)
            packLabel:SetMouseInputEnabled(false)
            packLabel:SetKeyboardInputEnabled(false)

            local formattedName, packType = BATTLEBEATS.stripPackPrefix(packName)
            local iconMat = packIcons[packType] or packIcons["Unknown"]

            packLabel.Paint = function(self, w, h)
                if packData.verifying then
                    surface.SetMaterial(Material("btbver.png"))
                    surface.SetDrawColor(255, 255, 255, 150)
                    surface.DrawTexturedRect(0, 2, 65, 65)
                    draw.SimpleText(formattedName, "BattleBeats_Font", 80, 35, cvertext, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    return
                elseif debugMode and not packData.debug then
                    surface.SetMaterial(Material("btbblock.png"))
                    surface.SetDrawColor(255, 255, 255, 150)
                    surface.DrawTexturedRect(0, 2, 65, 65)
                    draw.SimpleText(formattedName, "BattleBeats_Font", 80, 35, cvertext, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    return
                end
                if packData.packType == "local" then
                    surface.SetMaterial(Material("btblocal.png"))
                else
                    surface.SetMaterial(iconMat)
                end
                surface.SetDrawColor(color_white)
                surface.DrawTexturedRect(0, 2, 65, 65)
                draw.SimpleTextOutlined(formattedName, "BattleBeats_Font", 80, 35, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, c000200)
            end

            customCheckbox:SetSize(80, 30)
            customCheckbox:SetPos(870, 25)

            local hoverStrength = 0
            customCheckbox.OnCursorEntered = function(self)
                if not isErrored and not packData.verifying and not debugMode then
                    self:SetCursor("hand")
                elseif isErrored or packData.verifying or debugMode then
                    self:SetCursor("no")
                end
            end

            customCheckbox.OnCursorExited = function(self)
                self:SetCursor("arrow")
            end

            if not isErrored then
                customCheckbox.OnMousePressed = function()
                    if debugMode then
                        notification.AddLegacy("#btb.ps.noti.cant_toggle", NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button10.wav")
                        return
                    end
                    changesMade = true
                    if BATTLEBEATS.currentPacks[packName] then
                        BATTLEBEATS.currentPacks[packName] = nil
                        surface.PlaySound("btb_button_disable.mp3")
                        targetColor = c25500
                        text = "#btb.ps.pack_disabled"
                    else
                        BATTLEBEATS.currentPacks[packName] = true
                        surface.PlaySound("btb_button_enable.mp3")
                        targetColor = c2552100
                        text = "#btb.ps.pack_enabled"
                    end
                end
            end

            if isErrored then
                createError()
            end

            customCheckbox.Think = function(self)
                currentColor = LerpColor(FrameTime() * 10, currentColor, targetColor)
                if self:IsHovered() and not isErrored then
                    hoverStrength = Lerp(FrameTime() * 10, hoverStrength, 0.15)
                else
                    hoverStrength = Lerp(FrameTime() * 10, hoverStrength, 0)
                end
            end

            local c2001300200 = Color(200, 130, 0, 200)
            local c000100 = Color(0, 0, 0, 100)
            local c303030 = Color(30, 30, 30)
            customCheckbox.Paint = function(self, w, h)
                if packData.verifying then
                    draw.RoundedBox(6, 0, 0, w, h, c2001300200)
                    draw.SimpleText("Verifying", "BattleBeats_Checkbox_Font", w / 2, h / 2, c255255255200, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    return
                elseif debugMode and not isErrored then
                    draw.RoundedBox(6, 0, 0, w, h, c303030)
                    draw.SimpleText("N/A", "BattleBeats_Checkbox_Font", w / 2, h / 2, c255255255200, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    return
                end
                local drawColor = Color(
                    math.min(255, currentColor.r + 255 * hoverStrength),
                    math.min(255, currentColor.g + 255 * hoverStrength),
                    math.min(255, currentColor.b + 255 * hoverStrength),
                    255
                )
                draw.RoundedBox(6, 0, 0, w, h, drawColor)
                draw.SimpleTextOutlined(text, "BattleBeats_Checkbox_Font", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, c000100)
            end

            --MARK:Packs dropdown functions
            local function createButtons(panel)
                if not IsValid(panel) then return end

                local buttonWidth, buttonHeight, spacing = 350, 30, 20
                local allButtonWidth = buttonWidth / 2
                local panelWidth = panel:GetWide()
                local totalWidth = buttonWidth * 2 + allButtonWidth + spacing * 2
                local startX = (panelWidth - totalWidth) / 2
                local ambientButton = vgui.Create("DButton", panel)
                ambientButton:SetSize(buttonWidth, buttonHeight)
                ambientButton:SetPos(startX, 80)
                ambientButton:SetText("#btb.ps.info.ambient_button")
                ambientButton:SetFont("DermaDefaultBold")
                ambientButton:SetTextColor(color_white)
                ambientButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c909090 or c606060
                    local bgOutlineColor = c2552100
                    if packData.packContent == "combat" then
                        bgColor = c404040
                        bgOutlineColor = c2001500
                        self:SetTooltip("#btb.ps.info.ambient_button_tip")
                        self:SetTooltipPanelOverride("BattleBeatsTooltip")
                        ambientButton:SetTextColor(c200200200)
                    end
                    draw.RoundedBox(10, 0, 0, w, h, bgOutlineColor)
                    draw.RoundedBox(8, 2, 2, w - 4, h - 4, bgColor)
                end
                ambientButton.OnCursorEntered = function(self)
                    if packData.packContent ~= "combat" then
                        self:SetCursor("hand")
                        surface.PlaySound("ui/buttonrollover.wav")
                    else
                        self:SetCursor("no")
                    end
                end
                ambientButton.DoClick = function()
                    if packData.packContent ~= "combat" then
                        createTrackEditor("ambient", packName, scrollPanel, frame)
                    end
                end
                panel.ambientButton = ambientButton

                local allButton = vgui.Create("DButton", panel)
                allButton:SetSize(allButtonWidth, buttonHeight)
                allButton:SetPos(startX + buttonWidth + spacing, 80)
                allButton:SetText("#btb.ps.info.all_button")
                allButton:SetFont("DermaDefaultBold")
                allButton:SetTextColor(color_white)
                allButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c909090 or c606060
                    draw.RoundedBox(10, 0, 0, w, h, c2552100)
                    draw.RoundedBox(8, 2, 2, w - 4, h - 4, bgColor)
                end
                allButton.OnCursorEntered = function(self)
                    self:SetCursor("hand")
                    surface.PlaySound("ui/buttonrollover.wav")
                end
                allButton.DoClick = function()
                    createTrackEditor("all", packName, scrollPanel, frame)
                end
                panel.allButton = allButton

                local combatButton = vgui.Create("DButton", panel)
                combatButton:SetSize(buttonWidth, buttonHeight)
                combatButton:SetPos(startX + buttonWidth + spacing + allButtonWidth + spacing, 80)
                combatButton:SetText("#btb.ps.info.combat_button")
                combatButton:SetFont("DermaDefaultBold")
                combatButton:SetTextColor(color_white)
                combatButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c909090 or c606060
                    local bgOutlineColor = c2552100
                    if packData.packContent == "ambient" then
                        bgColor = c404040
                        bgOutlineColor = c2001500
                        self:SetTooltip("#btb.ps.info.combat_button_tip")
                        self:SetTooltipPanelOverride("BattleBeatsTooltip")
                        combatButton:SetTextColor(c200200200)
                    end
                    draw.RoundedBox(10, 0, 0, w, h, bgOutlineColor)
                    draw.RoundedBox(8, 2, 2, w - 4, h - 4, bgColor)
                end
                combatButton.OnCursorEntered = function(self)
                    if packData.packContent ~= "ambient" then
                        self:SetCursor("hand")
                        surface.PlaySound("ui/buttonrollover.wav")
                    else
                        self:SetCursor("no")
                    end
                end
                combatButton.DoClick = function()
                    if packData.packContent ~= "ambient" then
                        createTrackEditor("combat", packName, scrollPanel, frame)
                    end
                end
                panel.combatButton = combatButton
            end

            --MARK:Packs dropdown
            panel.OnMouseReleased = function(self, keyCode)
                if keyCode == MOUSE_RIGHT then
                    if not packData then return end
                    local menu = DermaMenu()
                    menu:AddOption("#btb.ps.pack_rmb.copy", function()
                        local function formatList(tracks)
                            table.sort(tracks)
                            local lines = {}
                            for _, track in ipairs(tracks) do
                                local name = BATTLEBEATS.FormatTrackName(track)
                                table.insert(lines, "[*] " .. name)
                            end
                            return "[olist]\n" .. table.concat(lines, "\n") .. "\n[/olist]"
                        end

                        local parts = {}
                        if packData.ambient and #packData.ambient > 0 then
                            table.insert(parts, "[h2]Ambient:[/h2]\n" .. formatList(packData.ambient))
                        end
                        if packData.combat and #packData.combat > 0 then
                            table.insert(parts, "[h2]Combat:[/h2]\n" .. formatList(packData.combat))
                        end

                        local finalText = table.concat(parts, "\n\n")

                        SetClipboardText(finalText)
                        surface.PlaySound("buttons/button14.wav")
                        notification.AddLegacy("#btb.ps.pack_rmb.copy_noti", NOTIFY_GENERIC, 3)
                    end):SetIcon("icon16/page_copy.png")
                    if packData.wsid then
                        menu:AddOption("#btb.ps.pack_rmb.open_workshop", function()
                            steamworks.ViewFile(packData.wsid)
                        end):SetIcon("icon16/world_go.png")
                    end
                    menu:Open()
                    return
                end

                if checking and not (debugMode and not packData.debug) then
                    notification.AddLegacy("#btb.ps.noti.cant_edit_ver", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button10.wav")
                    return
                elseif isErrored then
                    notification.AddLegacy("#btb.ps.noti.cant_edit_error", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button10.wav")
                    return
                elseif debugMode and not packData.debug then
                    notification.AddLegacy("#btb.ps.noti.cant_edit_debug", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button10.wav")
                    return
                end

                scrollPanel:ScrollToChild(panel)

                selectedPanel = panel
                selectedPackName = packName
                expandedPackName = packName

                local function removeButtons(panel)
                    if not IsValid(panel) then return end
                    if panel.ambientButton then
                        panel.ambientButton:Remove()
                        panel.ambientButton = nil
                    end
                    if panel.allButton then
                        panel.allButton:Remove()
                        panel.allButton = nil
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
                        removeButtons(panel)
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
                        removeButtons(oldPanel)

                        panel:SizeTo(-1, 160, 0.15, 0, -1)
                        surface.PlaySound("ui/buttonrollover.wav")
                        createButtons(panel)
                        createInfoPanel(panel, packData)
                        expandedPanel = panel
                    end)
                else
                    panel:SizeTo(-1, 160, 0.15, 0, -1)
                    surface.PlaySound("ui/buttonrollover.wav")
                    createButtons(panel)
                    createInfoPanel(panel, packData)
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
                        createButtons(panel)
                        createInfoPanel(panel, packData)
                    end
                end)
            end
        end
    end

    showPackList()

    if #packNames > 0 and not BATTLEBEATS.checking then
        MsgC(
            Color(255, 255, 0), "[BattleBeats Debug] ",
            color_white, "Starting verification...\n"
        )
        validateTracksInPack(packNames[currentPackIndex])
    end

    saveButton.DoClick = function()
        frame:Close()
    end

    frame.OnClose = function()
        BATTLEBEATS.ValidatePacks()
        if IsValid(BATTLEBEATS.optionsFrame) then BATTLEBEATS.optionsFrame:Close() end
        if IsValid(assignFrame) then assignFrame:Close() end
        if IsValid(lframe) then lframe:Close() end
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

hook.Add("OnContextMenuOpen", "BattleBeats_OpenUI", function()
    if IsValid(frame) and not frame.isMinimalized then
        frame:SetVisible(true)
    end
end)

hook.Add("OnContextMenuClose", "BattleBeats_HideUI", function()
    if IsValid(frame) and not toogleFrame:GetBool() and not (IsValid(searchBox) and searchBox:IsEditing()) then
        frame:SetVisible(false)
    end
end)

list.Set("DesktopWindows", "BattleBeatsContextMenu", {
    title = "BattleBeats",
    icon = "packicons/btb.png",
    init = function()
        if IsValid(frame) and not frame:IsVisible() then
            frame:SetVisible(true)
            frame.isMinimalized = false
        end
        if not IsValid(frame) then openBTBmenu() end
    end
})

concommand.Add("battlebeats_menu", function()
    if IsValid(frame) and not frame:IsVisible() then
        frame:SetVisible(true)
        frame.isMinimalized = false
    end
    if not IsValid(frame) then openBTBmenu() end
end)