local frame
local assignFrame
local lframe
local isLooping = false
local skipExcluded = false

local wsCache = {}

local volumeSet = GetConVar("battlebeats_volume")
local persistentNotification = GetConVar("battlebeats_persistent_notification")
local showPreviewNotification = GetConVar("battlebeats_show_preview_notification")

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

--MARK:Steamworks info
local function createInfoBoxes(panel, size, date, ownerName)
    if not IsValid(panel) then return end
    local buttonWidth, buttonHeight, spacing = 200, 30, 40
    local panelWidth = panel:GetWide()
    local totalWidth = buttonWidth * 3 + spacing * 2
    local startX = (panelWidth - totalWidth) / 2
    local y = 120

    local function addInfoBox(text, x)
        local box = vgui.Create("DPanel", panel)
        box:SetSize(buttonWidth, buttonHeight)
        box:SetPos(x, y)
        box.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, c606060)
        end

        local label = vgui.Create("DLabel", box)
        label:SetText(text)
        label:SetFont("DermaDefault")
        label:SetTextColor(c200200200)
        label:SizeToContents()
        label:Center()

        table.insert(panel.infoPanels, box)
    end

    addInfoBox("Size: " .. size, startX)
    addInfoBox("Created: " .. date, startX + buttonWidth + spacing)
    addInfoBox("Author: " .. ownerName, startX + (buttonWidth + spacing) * 2)
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

local function getPackInfo(packName)
    local formattedName = packName
    local packType = "na"

    if packName:match("^[Bb][Aa][Tt][Tt][Ll][Ee][Bb][Ee][Aa][Tt][Ss] %- ") then
        formattedName = packName:gsub("^[Bb][Aa][Tt][Tt][Ll][Ee][Bb][Ee][Aa][Tt][Ss] %- ", "", 1)
        packType = "battlebeats"
    elseif packName:match("^[Nn][Oo][Mm][Bb][Aa][Tt] %- ") then
        formattedName = packName:gsub("^[Nn][Oo][Mm][Bb][Aa][Tt] %- ", "", 1)
        packType = "nombat"
    elseif packName:match("^[Ss][Bb][Mm]") then
        formattedName = packName
        formattedName = formattedName:gsub("^[Ss][Bb][Mm] [Dd][Ll][Cc]: ", "", 1)
        formattedName = formattedName:gsub("^[Ss][Bb][Mm]: ", "", 1)
        packType = "sbm"
    elseif packName:match("^%[16[Tt][Hh][Nn][Oo][Tt][Ee]%]") then
        formattedName = packName:gsub("^%[16[Tt][Hh][Nn][Oo][Tt][Ee]%]", "", 1)
        packType = "16th"
    else
        packType = "na"
    end

    return formattedName:Trim(), packType
end

local packIcons = {
    ["battlebeats"] = Material("btb.png"),
    ["nombat"] = Material("nombat.jpg"),
    ["sbm"] = Material("sbm.jpg"),
    ["16th"] = Material("16th.jpg"),
    ["na"] = Material("na.jpg")
}

local function LerpColor(t, from, to)
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
                    notification.AddLegacy("[BattleBeats] Pack verification FAILED! Found " .. tostring(errorCount) .. " error(s)", NOTIFY_ERROR, 4)
                    surface.PlaySound("buttons/button8.wav")
                else
                    MsgC(
                        Color(255, 255, 0), "[BattleBeats Debug] ",
                        color_white, "Pack verification",
                        Color(0, 255, 0), " PASSED! ",
                        color_white, "No errors found\n"
                    )
                    notification.AddLegacy("[BattleBeats] Pack verification PASSED!", NOTIFY_HINT, 4)
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
local cHover2 = Color(60, 60, 60, 200)

local c707070255 = Color(70, 70, 70, 255)
local c808080255 = Color(80, 80, 80, 255)

local c000200 = Color(0, 0, 0, 200)
local c909090 = Color(90, 90, 90)
local c2552100 = Color(255, 210, 0)
local c25500 = Color(255, 0, 0)
local c404040 = Color(40, 40, 40)
local c3030300 = Color(30, 30, 30, 0)
local c100100100 = Color(100, 100, 100)
local c505050 = Color(50, 50, 50)

--MARK:Main UI
local function openBTBmenu()
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
        draw.RoundedBox(4, 0, 0, w, h, c000200)
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

    local scrollBar = scrollPanel:GetVBar() -- custom scroll bar
    local c404040200 = Color(40, 40, 40, 200)
    scrollBar.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, c404040200)
    end
    scrollBar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, c606060)
    end
    scrollBar.btnUp.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, c606060)
    end
    scrollBar.btnDown.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, c606060)
    end

    --MARK:Option button
    local optionsButton = vgui.Create("DButton", frame)
    optionsButton:SetSize(340, 40)
    optionsButton:SetPos(650, 650)
    optionsButton:SetText("Options")
    optionsButton:SetFont("CreditsText")
    optionsButton:SetTextColor(color_white)
    optionsButton.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and c808080255 or c707070255
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
        draw.RoundedBox(4, 0, 0, w, h, c707070255)
    end
    local volumeLabel = vgui.Create("DLabel", volumePanel)
    volumeLabel:SetText("MASTER VOLUME")
    volumeLabel:SetFont("DermaDefaultBold")
    volumeLabel:SetTextColor(color_white)
    volumeLabel:SizeToContents()
    local labelWidth = volumeLabel:GetWide()
    volumeLabel:SetPos((volumePanel:GetWide() - labelWidth) / 2, 4)
    local volumeBar = vgui.Create("DPanel", volumePanel)
    volumeBar:SetSize(300, 8)
    volumeBar:SetPos(15, 22)
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
    saveButton:SetTextColor(color_white)
    saveButton.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and c808080255 or c707070255
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
    local c303030240 = Color(30, 30, 30, 240)
    playerPanel.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c303030240)
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
    trackNameLabel:SetText("No Track Selected")
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
    loopBtn:SetTooltip("Loop Disabled")
    loopBtn.DoClick = function()
        isLooping = not isLooping
        if isLooping then
            loopBtn:SetTextColor(color_white)
            loopBtn:SetTooltip("Loop Enabled")
        else
            loopBtn:SetTextColor(c100100100)
            loopBtn:SetTooltip("Loop Disabled")
        end
    end

    local skipExcludedBtn = vgui.Create("DButton", playerPanel)
    skipExcludedBtn:SetSize(40, 40)
    skipExcludedBtn:SetPos((playerPanel:GetWide() / 2) - 130, 60)
    skipExcludedBtn:SetText("⇅")
    skipExcludedBtn:SetFont("DermaLarge")
    skipExcludedBtn:SetTextColor(color_white)
    skipExcludedBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, c3030300)
    end
    skipExcludedBtn:SetTooltip("Playing all")
    skipExcludedBtn.DoClick = function()
        skipExcluded = not skipExcluded
        if skipExcluded then
            skipExcludedBtn:SetTextColor(c100100100)
            skipExcludedBtn:SetTooltip("Skipping Excluded Tracks")
        else
            skipExcludedBtn:SetTextColor(color_white)
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

        local function sortFavorites(list)
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

        local trackList = sortFavorites(tracks)
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
    prevTrackBtn:SetTextColor(color_white)
    prevTrackBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, c3030300)
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
    nextTrackBtn:SetTextColor(color_white)
    nextTrackBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, c3030300)
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
        draw.RoundedBox(6, 0, 0, w, h, color_white)
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
    local function createTrackList(parent, trackType, selectedPack)
        parent:Clear()
        selectedRow = nil
        local function addTrackRow(track, excluded, isFavorite)
            local trackName = BATTLEBEATS.FormatTrackName(track)
            local row = vgui.Create("DPanel", parent)
            row:SetSize(0, 50)
            row:Dock(TOP)
            row:DockMargin(0, 5, 13, 3)
            row.trackPath = track
            row.textX = 10
            row.isScrolling = false
            row.scrollResetTime = 0

            surface.SetFont("BattleBeats_Font")
            local textWidth = surface.GetTextSize(isFavorite and "★ " .. trackName or trackName)
            local panelWidth = 800
            local scrollSpeed = 60

            local iconData = {
                {check = BATTLEBEATS.npcTrackMappings[track] ~= nil, tooltip = "This track has an assigned NPC", image = "icon16/user.png"},
                {check = BATTLEBEATS.trackOffsets[track] ~= nil, tooltip = "This track has an assigned offset", image = "icon16/time.png"},
                {check = BATTLEBEATS.parsedSubtitles[string.lower(trackName)] ~= nil, tooltip = "This track has subtitles", image = "icon16/comments.png"}
            }

            local xOffset = 840
            for _, data in ipairs(iconData) do
                if data.check then
                    local tooltipFrame = vgui.Create("DPanel", row)
                    tooltipFrame:SetSize(16, 16)
                    tooltipFrame:SetPos(xOffset, 17)
                    tooltipFrame:SetPaintBackground(false)
                    tooltipFrame:SetTooltip(data.tooltip)

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
            customCheckbox.OnCursorEntered = function(self)
                self:SetCursor("hand")
                targetColor = excluded and Color(255, 80, 80) or Color(255, 230, 50)
            end
            customCheckbox.OnCursorExited = function(self)
                self:SetCursor("arrow")
                targetColor = excluded and c25500 or c2552100
            end
            customCheckbox:SetTooltip(excluded and "Excluded tracks won't be selected by the music player" or "Included packs play normally")

            customCheckbox.OnMousePressed = function(self)
                excluded = not excluded
                BATTLEBEATS.excludedTracks[track] = excluded
                changesMade = true
                BATTLEBEATS.SaveExcludedTracks()
                targetColor = excluded and c25500 or c2552100
                customCheckbox:SetTooltip(excluded and "Excluded tracks won't be selected by the music player" or "Included packs play normally")
                surface.PlaySound(excluded and "btb_button_disable.mp3" or "btb_button_enable.mp3")
            end

            customCheckbox.Paint = function(self, w, h)
                colorLerp = LerpColor(FrameTime() * 10, colorLerp, targetColor)
                draw.RoundedBox(6, 0, 0, w, h, colorLerp)
                local text = excluded and "✖ Excluded" or "✔ Included"
                draw.SimpleTextOutlined(text, "BattleBeats_Checkbox_Font", w / 2, 3, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 0.9, c000200)
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
                    bg = c808080255
                elseif self:IsHovered() then
                    bg = cHover2
                else
                    bg = cHover
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
                    local copy = menu:AddOption("Copy Track Path", function()
                        SetClipboardText(track)
                    end)
                    copy:SetImage("icon16/tag.png")

                    --favorites
                    if isFavorite then
                        local unfavorite = menu:AddOption("Remove from Favorites", function()
                            BATTLEBEATS.favoriteTracks[track] = nil
                            BATTLEBEATS.SaveFavoriteTracks()
                            changesMade = true
                            createTrackList(parent, trackType, selectedPack)
                        end)
                        unfavorite:SetImage("icon16/cancel.png")
                    elseif favoriteCount < 25 then
                        local favorite = menu:AddOption("Add to Favorites", function()
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

                    --offset
                    local offsetValue = BATTLEBEATS.trackOffsets[track] or 0
                    local offsetOption = menu:AddOption(offsetValue > 0 and "Edit Offset (" .. offsetValue .. "s)" or "Set Offset", function()
                        local offsetFrame = vgui.Create("DFrame")
                        offsetFrame:SetTitle("Set Track Offset")
                        offsetFrame:SetSize(250, 110)
                        offsetFrame:Center()
                        offsetFrame:MakePopup()
                        offsetFrame.Paint = function(self, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, c000200)
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
                        cancelButton:SetText("Cancel")
                        cancelButton.DoClick = function()
                            offsetFrame:Close()
                        end
                    end)
                    offsetOption:SetImage("icon16/time.png")
                    offsetOption:SetTooltip("Adds an offset to the track\nOn first play, it will start from this offset")

                    --npc assign
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
                                draw.RoundedBox(4, 0, 0, w, h, c000200)
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
                                priorityCombo:AddChoice(priorityNames[i], i)
                            end
                            priorityCombo:SetValue(currentNPC and tostring(currentNPC.priority) or "1 (Highest)")

                            local saveButton = vgui.Create("DButton", assignFrame)
                            saveButton:SetPos(45, 75)
                            saveButton:SetSize(150, 25)
                            saveButton:SetText(currentNPC and "Save/Remove" or "Save")
                            saveButton:SetFont("CreditsText")
                            saveButton:SetTextColor(color_white)
                            saveButton.DoClick = function()
                                local class = textEntry:GetText()
                                local _, priority = priorityCombo:GetSelected()
                                priority = priority or 1

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
                                    createTrackList(parent, trackType, selectedPack)
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
                                    createTrackList(parent, trackType, selectedPack)
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
                                local bgColor = self:IsHovered() and c808080255 or c707070255
                                draw.RoundedBox(4, 0, 0, w, h, bgColor)
                            end

                            local cancelButton = vgui.Create("DButton", assignFrame)
                            cancelButton:SetPos(205, 75)
                            cancelButton:SetSize(150, 25)
                            cancelButton:SetText("Cancel")
                            cancelButton:SetFont("CreditsText")
                            cancelButton:SetTextColor(color_white)
                            cancelButton.Paint = function(self, w, h)
                                local bgColor = self:IsHovered() and c808080255 or c707070255
                                draw.RoundedBox(4, 0, 0, w, h, bgColor)
                            end
                            cancelButton.DoClick = function()
                                assignFrame:Close()
                            end
                        end)

                        assignNPC:SetImage(currentNPC and "icon16/user_edit.png" or "icon16/user_add.png")
                        assignNPC:SetTooltip("Assign an NPC class to this combat track with a priority (1-5)\nThe track with the highest priority will play when fighting multiple NPCs")
                    end

                    --subtitles
                    local subs = BATTLEBEATS.parsedSubtitles[string.lower(trackName)]
                    if subs and #subs > 0 then
                        local lyricsOption = menu:AddOption("Show Lyrics", function()
                            lframe = vgui.Create("DFrame")
                            lframe:SetTitle("Lyrics for: " .. trackName)
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

        --MARK:Tracks header
        local header = vgui.Create("DPanel", parent)
        header:Dock(TOP)
        header:DockMargin(0, 0, 15, 5)
        header:SetTall(headerExpanded and 60 or 25)
        header.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and not headerExpanded and c505050 or c404040
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
            draw.SimpleText("Name", "DermaDefaultBold", 40, 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Exclude", "DermaDefaultBold", 877, 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if headerExpanded then
                draw.SimpleText("∆", "DermaDefaultBold", 933, 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText("∇", "DermaDefaultBold", 930, 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            if trackType == "ambient" then
                draw.SimpleText("Ambient List", "DermaDefaultBold", (w / 2) - 30, 12, color_white,TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText("Combat List", "DermaDefaultBold", (w / 2) - 30, 12, color_white,TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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

        local function createHeaderButtons(header, parent, trackType, selectedPack)
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
            enableAllButton:SetTextColor(color_white)
            enableAllButton.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and c808080255 or c707070255
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
                createTrackList(parent, trackType, selectedPack)
            end

            local disableAllButton = vgui.Create("DButton", header)
            disableAllButton:SetSize(270, 20)
            disableAllButton:SetPos(570, 25)
            disableAllButton:SetText("Disable All")
            disableAllButton:SetFont("DermaDefaultBold")
            disableAllButton:SetTextColor(color_white)
            disableAllButton.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and c808080255 or c707070255
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
                createTrackList(parent, trackType, selectedPack)
            end
        end

        if headerExpanded then
            createHeaderButtons(header, parent, trackType, selectedPack)
        end

        header.OnMousePressed = function(self, code)
            if code == MOUSE_LEFT then
                headerExpanded = not headerExpanded
                parent:GetParent():InvalidateLayout()

                if headerExpanded then
                    createHeaderButtons(header, parent, trackType, selectedPack)
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
                local bg = c404040
                draw.RoundedBox(4, 0, 0, w, h, bg)
                if BATTLEBEATS.musicPacks[selectedPack].packType == "sbm" then
                    draw.SimpleText("Track names may appear unusual due to the naming conventions used in SBM", "BattleBeats_Font", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText("Track names appear unusual due to the naming conventions used in Nombat", "BattleBeats_Font", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end

        for _, track in ipairs(favoriteList) do
            addTrackRow(track, BATTLEBEATS.excludedTracks[track], true)
        end
        for _, track in ipairs(nonFavoriteList) do
            addTrackRow(track, BATTLEBEATS.excludedTracks[track], false)
        end
    end
    --MARK:Main UI list
    local expandedPanel = nil
    local selectedPanel = nil
    local selectedPackName = nil
    local expandedPackName = nil

    local function showPackList()
        scrollPanel:Clear()
        scrollPanel:SetVisible(true)
        saveButton:SetVisible(true)

        local function createTrackEditor(trackType, packName, scrollPanel, frame)
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
            backButton:SetTextColor(color_white)
            backButton.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and c808080255 or c707070255
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
                draw.RoundedBox(8, 0, 0, w, h, c505050)
                draw.SimpleText("No packs found. You might want to try one of these", "CloseCaption_Bold", w / 2, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Don’t see your packs? Report your issue [HERE]", "CloseCaption_Bold", w / 2, 365, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

        local c705050200 = Color(70, 50, 50, 200)
        local c50140140200 = Color(50, 140, 140, 200)
        local c50120120200 = Color(50, 120, 120, 200)
        local c11011060200 = Color(110, 110, 60, 200)
        local c10010060200 = Color(100, 100, 60, 200)
        local c12012060 = Color(120, 120, 60)
        local c50140140 = Color(50, 140, 140)
        local c15050060 = Color(150, 50, 0, 60)
        local c255200060 = Color(255, 200, 0, 60)
        local c255255255100 = Color(255, 255, 255, 100)

        --MARK:Packs found
        for packName, _ in pairs(BATTLEBEATS.musicPacks) do
            local debugMode = GetConVar("battlebeats_debug_mode"):GetBool()
            local packData = BATTLEBEATS.musicPacks[packName]
            if not BATTLEBEATS.checking then
                if packData.debug == true then
                    table.insert(packNames, packName)
                end
            end
            local isErrored = packData.error ~= nil
            local panel = scrollPanel:Add("DPanel")
            panel:SetSize(580, 80)
            panel:Dock(TOP)
            panel:DockMargin(0, 0, 0, 5)
            local currentColor = BATTLEBEATS.currentPacks[packName] and c2552100 or c25500
            local text = BATTLEBEATS.currentPacks[packName] and "Enabled" or "Disabled"
            local targetColor = currentColor
            local customCheckbox = vgui.Create("DPanel", panel)
            
            local function createError()
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
                if IsValid(customCheckbox) then
                    customCheckbox.OnMousePressed = function() end
                end
                currentColor = Color(100, 0, 0)
                targetColor = currentColor
                text = "Error"
            end

            panel.CreateErrorCalled = false
            panel.Paint = function(self, w, h)
                if packData.verifying then
                    local offset = (CurTime() * 200 * 5) % (w + 200)
                    local gradLeft = surface.GetTextureID("vgui/gradient-l")
                    local gradRight = surface.GetTextureID("vgui/gradient-r")
                    local barWidth = 300
                    local barX = offset - barWidth
                    local vColor = isErrored and c15050060 or c255200060
                    draw.RoundedBox(4, 0, 0, w, h, Color(vColor.r, vColor.g, vColor.b, 60))

                    surface.SetTexture(gradRight)
                    surface.SetDrawColor(vColor.r, vColor.g, vColor.b, 200)
                    surface.DrawTexturedRect(barX, 0, barWidth / 2, h)
                    surface.SetTexture(gradLeft)
                    surface.SetDrawColor(vColor.r, vColor.g, vColor.b, 200)
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
                local bgColor = self:IsHovered() and cHover2 or cHover
                if packData.packType == "local" then bgColor = self:IsHovered() and c50140140200 or c50120120200 end
                if packData.debug == true then bgColor = self:IsHovered() and c11011060200 or c10010060200 end
                if isErrored then
                    draw.RoundedBox(4, 0, 0, w, h, c705050200)
                elseif panel == selectedPanel then
                    if packData.debug == true then
                        draw.RoundedBox(4, 0, 0, w, h, c12012060)
                    elseif packData.packType == "local" then
                        draw.RoundedBox(4, 0, 0, w, h, c50140140)
                    else
                        draw.RoundedBox(4, 0, 0, w, h, c707070255)
                    end
                else
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                end
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

            local formattedName, packType = getPackInfo(packName)
            local iconMat = packIcons[packType] or packIcons["Unknown"]

            packLabel.Paint = function(self, w, h)
                if packData.verifying then
                    surface.SetMaterial(Material("ver.png"))
                    surface.SetDrawColor(255, 255, 255, 150)
                    surface.DrawTexturedRect(0, 2, 65, 65)
                    draw.SimpleText(formattedName, "BattleBeats_Font", 80, 35, c255255255100, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    return
                elseif debugMode and not packData.debug then
                    surface.SetMaterial(Material("block.png"))
                    surface.SetDrawColor(255, 255, 255, 150)
                    surface.DrawTexturedRect(0, 2, 65, 65)
                    draw.SimpleText(formattedName, "BattleBeats_Font", 80, 35, c255255255100, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    return
                end
                surface.SetMaterial(iconMat)
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
                        notification.AddLegacy("Cannot toggle packs while debug mode is active!", NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button10.wav")
                        return
                    end
                    changesMade = true
                    if BATTLEBEATS.currentPacks[packName] then
                        BATTLEBEATS.currentPacks[packName] = nil
                        surface.PlaySound("btb_button_disable.mp3")
                        targetColor = c25500
                        text = "Disabled"
                    else
                        BATTLEBEATS.currentPacks[packName] = true
                        surface.PlaySound("btb_button_enable.mp3")
                        targetColor = c2552100
                        text = "Enabled"
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

            local c255255255200 = Color(255, 255, 255, 200)
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

                local buttonWidth, buttonHeight, spacing = 430, 30, 40
                local panelWidth = panel:GetWide()
                local totalWidth = buttonWidth * 2 + spacing
                local startX = (panelWidth - totalWidth) / 2
                local ambientButton = vgui.Create("DButton", panel)
                ambientButton:SetSize(buttonWidth, buttonHeight)
                ambientButton:SetPos(startX, 80)
                ambientButton:SetText("Ambient Tracks")
                ambientButton:SetFont("DermaDefaultBold")
                ambientButton:SetTextColor(color_white)
                ambientButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c909090 or c606060
                    if packData.packContent == "combat" then
                        bgColor = c404040
                        self:SetTooltip("This pack doesn't have ambient tracks")
                        ambientButton:SetTextColor(c200200200)
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
                        createTrackEditor("ambient", packName, scrollPanel, frame)
                    end
                end
                panel.ambientButton = ambientButton

                local combatButton = vgui.Create("DButton", panel)
                combatButton:SetSize(buttonWidth, buttonHeight)
                combatButton:SetPos(startX + buttonWidth + spacing, 80)
                combatButton:SetText("Combat Tracks")
                combatButton:SetFont("DermaDefaultBold")
                combatButton:SetTextColor(color_white)
                combatButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c909090 or c606060
                    if packData.packContent == "ambient" then
                        bgColor = c404040
                        self:SetTooltip("This pack doesn't have combat tracks")
                        combatButton:SetTextColor(c200200200)
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
                        createTrackEditor("combat", packName, scrollPanel, frame)
                    end
                end
                panel.combatButton = combatButton
            end

            --MARK:Packs dropdown
            panel.OnMousePressed = function()
                if checking and not (debugMode and not packData.debug) then
                    notification.AddLegacy("Cannot edit packs during verification", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button10.wav")
                    return
                elseif isErrored then
                    notification.AddLegacy("This pack has an error and cannot be edited!", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button10.wav")
                    return
                elseif debugMode and not packData.debug then
                    notification.AddLegacy("Cannot edit workshop packs while debug mode is active!", NOTIFY_ERROR, 3)
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