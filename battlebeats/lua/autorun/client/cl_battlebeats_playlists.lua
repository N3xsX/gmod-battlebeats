function BATTLEBEATS.isTrackInPlaylist(playlistName, track, trackType)
    local playlist = BATTLEBEATS.musicPlaylists[playlistName]
    if not playlist or not playlist[trackType] then return false end
    for _, v in ipairs(playlist[trackType]) do
        if v.path == track then
            return true
        end
    end
    return false
end

function BATTLEBEATS.addTrackToPlaylist(playlistName, track, trackType)
    local playlist = BATTLEBEATS.musicPlaylists[playlistName]
    local pack = BATTLEBEATS.musicPacks[playlistName]
    if not playlist or not pack then return end
    playlist[trackType] = playlist[trackType] or {}
    pack[trackType] = pack[trackType] or {}
    table.insert(playlist[trackType], {
        path = track,
        exists = true
    })
    table.insert(pack[trackType], track)
    BATTLEBEATS.SavePlaylists()
end

function BATTLEBEATS.removeTrackFromPlaylist(playlistName, track, trackType)
    local playlist = BATTLEBEATS.musicPlaylists[playlistName]
    local pack = BATTLEBEATS.musicPacks[playlistName]
    if not playlist or not playlist[trackType] then return end
    for i, v in ipairs(playlist[trackType]) do
        if v.path == track then
            table.remove(playlist[trackType], i)
            break
        end
    end
    if pack and pack[trackType] then
        for i, v in ipairs(pack[trackType]) do
            if v == track then
                table.remove(pack[trackType], i)
                break
            end
        end
    end
    BATTLEBEATS.SavePlaylists()
end

local function buildMusicPackFromPlaylist(title)
    local playlist = BATTLEBEATS.musicPlaylists[title]
    if not playlist then return end

    local ambientFiles = {}
    local combatFiles = {}

    for _, track in ipairs(playlist.ambient or {}) do
        if track.exists then
            table.insert(ambientFiles, track.path)
        end
    end

    for _, track in ipairs(playlist.combat or {}) do
        if track.exists then
            table.insert(combatFiles, track.path)
        end
    end

    local hasAmbient = #ambientFiles > 0
    local hasCombat = #combatFiles > 0
    local packContent
    if hasAmbient and hasCombat then
        packContent = "both"
    elseif hasAmbient then
        packContent = "ambient"
    elseif hasCombat then
        packContent = "combat"
    else
        packContent = "empty"
    end
    BATTLEBEATS.musicPacks[title] = {
        ambient = ambientFiles,
        combat = combatFiles,
        packType = "playlist",
        packContent = packContent,
    }
end

local function validatePlaylist(title)
    local playlist = BATTLEBEATS.musicPlaylists[title]
    if not playlist then return end
    local missingTracks = {}
    local function check(list)
        for _, track in ipairs(list or {}) do
            local exists = file.Exists(track.path, "GAME")
            track.exists = exists
            if not exists then
                table.insert(missingTracks, {
                    path = track.path
                })
            end
        end
    end
    check(playlist.ambient)
    check(playlist.combat)
    return missingTracks
end

function BATTLEBEATS.validateAndTransformPlaylist(title, data)
    if not isstring(title) or not istable(data) then return nil end
    BATTLEBEATS.musicPlaylists[title] = data
    validatePlaylist(title)
    buildMusicPackFromPlaylist(title)
    return title, BATTLEBEATS.musicPlaylists[title]
end

local prefix = "BTB_PLAYLIST:"
function BATTLEBEATS.exportPlaylist(title)
    local playlist = BATTLEBEATS.musicPlaylists[title]
    if not playlist then return end
    local data = {
        ambient = playlist.ambient or {},
        combat = playlist.combat or {}
    }
    local json = util.TableToJSON(data, false)
    local compressed = util.Compress(json)
    local encoded = util.Base64Encode(compressed)
    local final = prefix .. encoded
    return final
end

function BATTLEBEATS.importPlaylist(encodedString)
    if not encodedString or encodedString == "" then
        return false
    end
    if not encodedString:StartWith(prefix) then
        return false
    end
    local pureBase64 = encodedString:sub(#prefix + 1)
    local compressed = util.Base64Decode(pureBase64)
    if not compressed then
        return false
    end
    local json = util.Decompress(compressed)
    if not json then
        return false
    end
    local data = util.JSONToTable(json)
    if not data or not data.ambient or not data.combat then
        return false
    end
    return data
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

local c202020215 = Color(20, 20, 20, 215)
local c2552100 = Color(255, 210, 0)
local c606060 = Color(60, 60, 60)
local c404040 = Color(40, 40, 40)
local c909090 = Color(90, 90, 90)
local c808080 = Color(80, 80, 80)
local c707070 = Color(70, 70, 70)
local frame

local cNormalA = Color(25, 35, 25)
local cNormalC = Color(35, 25, 25)
local cHoverA = Color(40, 70, 40)
local cHoverC = Color(70, 40, 40)
local cSelectA = Color(80, 120, 80)
local cSelectC = Color(120, 80, 80)
local cTextA = Color(180, 255, 180)
local cTextC = Color(255, 180, 180)

local showPreviewNotification = GetConVar("battlebeats_show_preview_notification")
local selectedTrack = nil

local function createPlayer(frame)
    local playerPanel = vgui.Create("DPanel", frame)
    playerPanel:SetSize(1080, 170)
    playerPanel:SetPos(10, 650)
    playerPanel.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, c404040)
    end

    local playPause = vgui.Create("DButton", playerPanel)
    playPause:SetSize(50, 50)
    playPause:SetPos((playerPanel:GetWide() / 2) - 28, 50)
    playPause:SetText("▶")
    playPause:SetFont("DermaLarge")
    playPause:SetTextColor(color_white)
    playPause.Paint = nil
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
    totalTimeLabel:SetPos(950, 111)
    totalTimeLabel:SetSize(90, 20)
    totalTimeLabel:SetText("0:00")
    totalTimeLabel:SetFont("DermaDefaultBold")
    totalTimeLabel:SetTextColor(color_white)
    totalTimeLabel:SetContentAlignment(6)

    local trackNameLabel = vgui.Create("DLabel", playerPanel)
    trackNameLabel:SetPos(95, 15)
    trackNameLabel:SetSize(880, 50)
    trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
    trackNameLabel:SetFont("BattleBeats_Player_Font")
    trackNameLabel:SetTextColor(color_white)
    trackNameLabel:SetContentAlignment(5)

    local hoverTimeDisplay = nil
    local progressBar = vgui.Create("DPanel", playerPanel)
    progressBar:SetSize(900, 20)
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

    playerPanel.PaintOver = function(self)
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
        if not IsValid(BATTLEBEATS.currentPreviewStation) then
            self:SetPos(0, progressBar:GetTall() / 2 - progressDot:GetTall() / 2 + 2)
            currentTimeLabel:SetText("0:00")
            totalTimeLabel:SetText("0:00")
            return
        end
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
        if IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() == GMOD_CHANNEL_PLAYING then
            BATTLEBEATS.currentPreviewStation:Pause()
            playPause:SetText("▶")
            if showPreviewNotification:GetBool() then BATTLEBEATS.HideNotification() end
        elseif IsValid(BATTLEBEATS.currentPreviewStation) then
            BATTLEBEATS.currentPreviewStation:Play()
            playPause:SetText("⏸")
            if showPreviewNotification:GetBool() then BATTLEBEATS.ShowTrackNotification(BATTLEBEATS.currentPreviewTrack, false, true) end
        end
        if not gui.IsGameUIVisible() or not game.SinglePlayer() then
            if not selectedTrack then return end
            if selectedTrack.path == BATTLEBEATS.currentPreviewTrack then return end
            BATTLEBEATS.PlayNextTrackPreview(selectedTrack.path, nil, false)
            BATTLEBEATS.currentPreviewTrack = selectedTrack.path
            playPause:SetText("⏸")
            if not showPreviewNotification:GetBool() then BATTLEBEATS.HideNotification() end
            if not timer.Exists("BattleBeats_NextPreviewTrackPlaylist") then
                timer.Create("BattleBeats_NextPreviewTrackPlaylist", 0.5, 0, function()
                    if IsValid(BATTLEBEATS.currentPreviewStation) then
                        BATTLEBEATS.currentPreviewPosition = BATTLEBEATS.currentPreviewStation:GetTime()
                    end
                end)
            end
        end
    end

    return trackNameLabel, playPause
end

local c505050 = Color(50, 50, 50)
local btnHoverError = Color(100, 50, 50)
local btnNormalError = Color(70, 30, 30)

function BATTLEBEATS.openPlaylistEditor(title, func)
    if IsValid(frame) then frame:MakePopup() return end
    local isEdit = title and BATTLEBEATS.musicPlaylists[title] ~= nil
    local playlist = isEdit and table.Copy(BATTLEBEATS.musicPlaylists[title]) or {
        ambient = {},
        combat = {}
    }
    local editedTitle = isEdit and title or ""

    frame = vgui.Create("DFrame")
    frame:SetSize(1100, 870)
    frame:Center()
    frame:SetTitle("")
    frame:BTB_SetTitle(isEdit and (language.GetPhrase("btb.playlist.create.title_edit") .. ": " .. title) or "#btb.playlist.create.title_new", true)
    frame:BTB_SetButtons(false)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        drawBlur(self, 3)
        draw.RoundedBox(12, 0, 0, w, h, c202020215)
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end
    local trackNameLabel, playPause = createPlayer(frame)

    local availablePanel = vgui.Create("DPanel", frame)
    availablePanel:SetPos(10, 80)
    availablePanel:SetSize(480, 560)
    availablePanel.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, c404040)
    end

    local search = vgui.Create("DTextEntry", availablePanel)
    search:Dock(TOP)
    search:DockMargin(4, 4, 4, 0)
    search:SetTall(28)
    search.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c505050)
        self:DrawTextEntryText(color_white, color_white, color_white)
        if self:GetText() == "" and not self:IsEditing() then
            draw.SimpleText("#btb.ps.search", "BattleBeats_Checkbox_Font", 5, h / 2, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local availScroll = vgui.Create("DScrollPanel", availablePanel)
    availScroll:Dock(FILL)
    availScroll:DockMargin(4, 4, 4, 4)
    availScroll:GetVBar():SetWide(0)

    local availList = vgui.Create("DListLayout", availScroll)
    availList:Dock(TOP)

    local panelX, _ = availablePanel:GetPos()
    local panelW, _ = availablePanel:GetSize()
    local nameEntry = vgui.Create("DTextEntry", frame)
    nameEntry:SetSize(300, 30)
    nameEntry:SetPos(panelX + (panelW - 300) / 2, 35)
    nameEntry:SetText(editedTitle)
    nameEntry:SetFont("BattleBeats_Font")
    nameEntry.OnChange = function(self)
        editedTitle = self:GetValue():Trim()
    end
    nameEntry.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c606060)
        self:DrawTextEntryText(color_white, color_white, color_white)
        if self:GetText() == "" and not self:IsEditing() then
            draw.SimpleText("#btb.playlist.create.enter_name", "BattleBeats_Checkbox_Font", 5, h / 2, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local playlistPanel = vgui.Create("DPanel", frame)
    playlistPanel:SetPos(610, 80)
    playlistPanel:SetSize(480, 560)
    playlistPanel.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, c404040)
    end

    local plScroll = vgui.Create("DScrollPanel", playlistPanel)
    plScroll:Dock(FILL)
    plScroll:DockMargin(4, 4, 4, 4)
    local scrollBar = plScroll:GetVBar()
    scrollBar:SetWide(0)

    local plList = vgui.Create("DListLayout", plScroll)
    plList:SetSize(480, 560)
    plList:SetWide(470)

    local tabAmbient = true
    local btnAmbient = nil
    local btnCombat  = nil
    local pX, _ = playlistPanel:GetPos()
    local pW, _ = playlistPanel:GetSize()
    local totalW = 120 * 2 + 10
    local startX = pX + (pW - totalW) / 2

    btnAmbient = vgui.Create("DButton", frame)
    btnAmbient:SetPos(startX, 35)
    btnAmbient:SetSize(120, 30)
    btnAmbient:SetText("AMBIENT")
    btnAmbient:SetTextColor(color_white)
    btnAmbient.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, tabAmbient and Color(40, 100, 40) or c606060)
    end
    btnAmbient.DoClick = function()
        tabAmbient = true
        RebuildAvailableSide()
        RebuildPlaylistSide()
    end

    btnCombat = vgui.Create("DButton", frame)
    btnCombat:SetPos(startX + 130, 35)
    btnCombat:SetSize(120, 30)
    btnCombat:SetText("COMBAT")
    btnCombat:SetTextColor(color_white)
    btnCombat.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, not tabAmbient and Color(100, 40, 40) or c606060)
    end
    btnCombat.DoClick = function()
        tabAmbient = false
        RebuildAvailableSide()
        RebuildPlaylistSide()
    end

    selectedTrack = nil
    local addBtn = vgui.Create("DButton", frame)
    addBtn:SetPos(530, 280)
    addBtn:SetSize(43, 40)
    addBtn:SetText("▶")
    addBtn:SetTextColor(color_white)
    addBtn:SetFont("DermaLarge")
    addBtn.DoClick = function()
        if not selectedTrack or selectedTrack.from ~= "available" then return end
        local currentTracks = tabAmbient and playlist.ambient or playlist.combat
        table.insert(currentTracks, {
            path = selectedTrack.path,
            exists = file.Exists(selectedTrack.path, "GAME")
        })
        selectedTrack = nil
        trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
        RebuildPlaylistSide()
        RebuildAvailableSide()
    end
    addBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and c606060 or c404040)
    end

    local removeBtn = vgui.Create("DButton", frame)
    removeBtn:SetPos(530, 340)
    removeBtn:SetSize(43, 40)
    removeBtn:SetText("◀")
    removeBtn:SetTextColor(color_white)
    removeBtn:SetFont("DermaLarge")
    removeBtn.DoClick = function()
        if not selectedTrack or selectedTrack.from ~= "playlist" then return end
        local currentTracks = tabAmbient and playlist.ambient or playlist.combat
        table.remove(currentTracks, selectedTrack.index)
        selectedTrack = nil
        trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
        RebuildPlaylistSide()
        RebuildAvailableSide()
    end
    removeBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and c606060 or c404040)
    end

    local searchQuery = ""
    local collapsed = {}

    local function matchesSearch(str)
        if searchQuery == "" then return true end
        return string.find(string.lower(str), string.lower(searchQuery), 1, true)
    end

    search.OnChange = function(self)
        searchQuery = self:GetValue()
        RebuildAvailableSide()
    end

    function RebuildAvailableSide()
        availList:Clear()
        selectedTrack = nil
        trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
        local btnHover = tabAmbient and cHoverA or cHoverC
        local btnNormal = tabAmbient and cNormalA or cNormalC
        local currentTracks = tabAmbient and playlist.ambient or playlist.combat
        local existingPaths = {}
        for _, t in ipairs(currentTracks) do
            existingPaths[t.path] = true
        end
        for packName, pack in pairs(BATTLEBEATS.musicPacks or {}) do
            if pack.packType == "playlist" then continue end

            if collapsed[packName] == nil then
                collapsed[packName] = true
            end

            local tracks = tabAmbient and (pack.ambient or {}) or (pack.combat or {})

            if #tracks > 0 then
                local visibleTracks = {}

                for _, path in ipairs(tracks) do
                    local name = BATTLEBEATS.FormatTrackName(path)
                    if not existingPaths[path] and matchesSearch(name) then
                        table.insert(visibleTracks, path)
                    end
                end

                if #visibleTracks > 0 then
                    local container = vgui.Create("DPanel", availList)
                    container:Dock(TOP)
                    container:DockMargin(0, 0, 0, 0)
                    container:SetTall(24)
                    container.Paint = nil

                    local cat = vgui.Create("DButton", container)
                    cat:Dock(TOP)
                    cat:SetText((collapsed[packName] and " ▶ " or "▼ "))
                    cat:SetContentAlignment(4)
                    cat:SetFont("DermaDefaultBold")
                    cat:SetTextColor(color_white)
                    cat:SetTall(24)

                    local pName = language.GetPhrase(packName)
                    local catName = vgui.Create("DLabel", cat)
                    catName:Dock(FILL)
                    catName:SetText(BATTLEBEATS.stripPackPrefix(pName))
                    catName:SetContentAlignment(5)
                    catName:SetFont("DermaDefaultBold")
                    catName:SetTextColor(color_white)

                    cat.Paint = function(self, w, h)
                        draw.RoundedBox(0, 0, 0, w, h, c505050)
                    end

                    local content = vgui.Create("DPanel", container)
                    content:Dock(TOP)
                    content.Paint = nil

                    cat.DoClick = function()
                        collapsed[packName] = not collapsed[packName]
                        RebuildAvailableSide()
                    end

                    if not collapsed[packName] then
                        for _, track in ipairs(visibleTracks) do
                            local trackName = BATTLEBEATS.FormatTrackName(track)
                            local row = vgui.Create("DButton", content)
                            row:Dock(TOP)
                            row:SetText(trackName)
                            row:SetTextColor(tabAmbient and cTextA or cTextC)
                            row:SetTall(24)
                            row.Paint = function(self, w, h)
                                local isSelected = selectedTrack and selectedTrack.path == track and selectedTrack.from == "available"
                                draw.RoundedBox(0, 0, 0, w, h, isSelected and (tabAmbient and cSelectA or cSelectC) or (self:IsHovered() and btnHover or btnNormal))
                            end

                            row.DoClick = function()
                                trackNameLabel:SetText(trackName)
                                playPause:SetText("▶")
                                if IsValid(BATTLEBEATS.currentPreviewStation) then
                                    BATTLEBEATS.FadeMusic(BATTLEBEATS.currentPreviewStation, nil, 0.5)
                                    BATTLEBEATS.HideNotification()
                                    BATTLEBEATS.currentPreviewTrack = nil
                                end
                                selectedTrack = {
                                    path = track,
                                    from = "available"
                                }
                            end
                            row.DoDoubleClick = function()
                                table.insert(currentTracks, {
                                    path = track,
                                    exists = file.Exists(track, "GAME")
                                })
                                selectedTrack = nil
                                trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
                                RebuildPlaylistSide()
                                RebuildAvailableSide()
                            end
                        end
                    end
                    content:InvalidateLayout(true)
                    content:SizeToChildren(false, true)
                    container:InvalidateLayout(true)
                    container:SizeToChildren(false, true)
                end
            end
        end
        availScroll:InvalidateLayout(true)
    end

    local draggingTrack = nil
    local dragStartPos = nil
    local isDragging = false
    local ghostPanel = nil
    local dropIndex = nil
    function RebuildPlaylistSide()
        plList:Clear()
        selectedTrack = nil
        trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
        local currentTracks = tabAmbient and playlist.ambient or playlist.combat
        for i, track in ipairs(currentTracks) do
            local btnHover = tabAmbient and cHoverA or cHoverC
            local btnNormal = tabAmbient and cNormalA or cNormalC
            local trackName = BATTLEBEATS.FormatTrackName(track.path)
            local row = vgui.Create("DButton", plList)
            row:Dock(TOP)
            row:SetText(trackName)
            row:SetTextColor(tabAmbient and cTextA or cTextC)
            row:SetTall(24)
            row.Paint = function(self, w, h)
                local isSelected = selectedTrack and selectedTrack.path == track.path and selectedTrack.from == "playlist"
                btnHover = track.exists and btnHover or btnHoverError
                btnNormal = track.exists and btnNormal or btnNormalError
                draw.RoundedBox(0, 0, 0, w, h, isSelected and (tabAmbient and cSelectA or cSelectC) or (self:IsHovered() and btnHover or btnNormal))
            end
            if not track.exists then
                row:SetTooltip("#btb.playlist.create.track_error")
                row:SetTooltipPanelOverride("BattleBeatsTooltip")
            end

            row.lastClick = 0
            row.OnMousePressed = function(self, code)
                if code == MOUSE_LEFT then
                    local now = CurTime()
                    if now - (self.lastClick or 0) < 0.3 then
                        table.remove(currentTracks, i)
                        selectedTrack = nil
                        trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
                        RebuildPlaylistSide()
                        RebuildAvailableSide()
                        return
                    end
                    self.lastClick = now
                    local x, y = gui.MousePos()
                    dragStartPos = { x = x, y = y }
                    isDragging = false
                    draggingTrack = {
                        index = i,
                        data = track
                    }
                    self:MouseCapture(true)
                end
            end
            row.OnCursorMoved = function(self)
                if not draggingTrack or not dragStartPos then return end
                local mx, my = gui.MousePos()
                local dist = math.abs(mx - dragStartPos.x) + math.abs(my - dragStartPos.y)
                if dist > 5 and not isDragging then
                    isDragging = true
                    ghostPanel = vgui.Create("DPanel")
                    ghostPanel:SetSize(self:GetWide(), self:GetTall())
                    ghostPanel:MakePopup()
                    ghostPanel:SetMouseInputEnabled(false)
                    ghostPanel.Paint = function(_, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 30))
                        draw.SimpleText(trackName, "DermaDefault", 5, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                end
            end
            row.Think = function()
                if isDragging and ghostPanel then
                    local mx, my = gui.MousePos()
                    ghostPanel:SetPos(mx - (ghostPanel:GetWide() / 2), my + 10)
                    for j, child in ipairs(plList:GetChildren()) do
                        local _, y = child:LocalToScreen(0, 0)
                        if my > y then
                            dropIndex = j + 1
                        end
                    end
                end
            end
            row.OnMouseReleased = function(self, code)
                if code ~= MOUSE_LEFT then return end
                self:MouseCapture(false)
                if draggingTrack then
                    if isDragging then
                        local mouseY = gui.MouseY()
                        local newIndex = 1
                        for j, child in ipairs(plList:GetChildren()) do
                            local _, y = child:LocalToScreen(0, 0)
                            if mouseY > y then
                                newIndex = j
                            end
                        end
                        local moved = table.remove(currentTracks, draggingTrack.index)
                        table.insert(currentTracks, newIndex, moved)
                        RebuildPlaylistSide()
                    else
                        trackNameLabel:SetText(trackName)
                        playPause:SetText("▶")
                        if IsValid(BATTLEBEATS.currentPreviewStation) then
                            BATTLEBEATS.FadeMusic(BATTLEBEATS.currentPreviewStation, nil, 0.5)
                            BATTLEBEATS.HideNotification()
                            BATTLEBEATS.currentPreviewTrack = nil
                        end
                        selectedTrack = {
                            path = track.path,
                            from = "playlist",
                            index = i
                        }
                    end
                end
                draggingTrack = nil
                dragStartPos = nil
                isDragging = false
                if ghostPanel then
                    ghostPanel:Remove()
                    ghostPanel = nil
                end
            end
        end
    end

    plList.PaintOver = function(self, w, h)
        if not isDragging or not dropIndex then return end
        local children = self:GetChildren()
        local target = children[dropIndex]
        local y
        if target then
            local _, ty = target:LocalToScreen(0, 0)
            local _, ly = self:ScreenToLocal(0, ty)
            y = ly
        else
            y = h
        end
        surface.SetDrawColor(255, 210, 0)
        surface.DrawRect(0, y - 1, w, 2)
    end

    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos(10, frame:GetTall() - 40)
    saveBtn:SetSize(frame:GetWide() - 20, 30)
    saveBtn:SetText("#btb.ps.ts.rmb.assign_save")
    saveBtn:SetFont("DermaLarge")
    saveBtn:SetTextColor(color_white)
    saveBtn:BTB_SetButton(c2552100, c707070, c808080)
    saveBtn.DoClick = function()
        if editedTitle == "" then
            notification.AddLegacy("#btb.playlist.create.enter_name_error", NOTIFY_ERROR, 3)
            surface.PlaySound("buttons/button11.wav")
            return
        end

        if table.IsEmpty(playlist.ambient) and table.IsEmpty(playlist.combat) then
            notification.AddLegacy("#btb.playlist.create.tracks_error", NOTIFY_ERROR, 3)
            surface.PlaySound("buttons/button11.wav")
            return
        end

        for packName, _ in pairs(BATTLEBEATS.musicPacks or {}) do
            if editedTitle == packName then
                if not isEdit or editedTitle ~= title then
                    notification.AddLegacy("#btb.playlist.create.name_error", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button11.wav")
                    return
                end
            end
        end

        if isEdit and editedTitle ~= title then
            BATTLEBEATS.musicPlaylists[title] = nil
            BATTLEBEATS.musicPacks[title] = nil
        end

        if isEdit then
            notification.AddLegacy("#btb.playlist.create.edit_succ", NOTIFY_GENERIC, 3)
        else
            notification.AddLegacy("#btb.playlist.create.create_succ", NOTIFY_GENERIC, 3)
        end
        surface.PlaySound("buttons/button3.wav")

        BATTLEBEATS.musicPlaylists[editedTitle] = playlist

        validatePlaylist(editedTitle)
        buildMusicPackFromPlaylist(editedTitle)

        BATTLEBEATS.SavePlaylists()

        if isfunction(func) then
            func()
        end

        frame:Close()
    end
    frame.OnClose = function()
        if timer.Exists("BattleBeats_NextPreviewTrackPlaylist") then
            timer.Remove("BattleBeats_NextPreviewTrackPlaylist")
        end
        if IsValid(BATTLEBEATS.currentPreviewStation) then
            BATTLEBEATS.FadeMusic(BATTLEBEATS.currentPreviewStation)
            BATTLEBEATS.HideNotification()
            BATTLEBEATS.currentPreviewTrack = nil
        end
        timer.Simple(2, function()
            if not table.IsEmpty(BATTLEBEATS.currentPacks) and not IsValid(BATTLEBEATS.currentStation) then
                local nextTrack = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks)
                if nextTrack then
                    BATTLEBEATS.PlayNextTrack(nextTrack)
                end
            end
        end)
    end

    RebuildAvailableSide()
    RebuildPlaylistSide()
end

concommand.Add("battlebeats_playlist_editor", function()
    BATTLEBEATS.openPlaylistEditor()
end)
