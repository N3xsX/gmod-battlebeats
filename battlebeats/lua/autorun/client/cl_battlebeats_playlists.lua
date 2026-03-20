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
local frame

function BATTLEBEATS.openPlaylistEditor(title, func)
    if IsValid(frame) then frame:MakePopup() return end
    local isEdit = title and BATTLEBEATS.musicPlaylists[title] ~= nil
    local playlist = isEdit and table.Copy(BATTLEBEATS.musicPlaylists[title]) or {
        ambient = {},
        combat = {}
    }
    local editedTitle = isEdit and title or ""

    frame = vgui.Create("DFrame")
    frame:SetSize(1000, 690)
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

    local availablePanel = vgui.Create("DPanel", frame)
    availablePanel:SetPos(10, 80)
    availablePanel:SetSize(480, 560)
    availablePanel.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, c404040)
    end

    local availScroll = vgui.Create("DScrollPanel", availablePanel)
    availScroll:Dock(FILL)
    availScroll:DockMargin(4, 4, 4, 4)
    local scrollBar = availScroll:GetVBar()
    scrollBar:SetWide(0)

    local availList = vgui.Create("DListLayout", availScroll)
    availList:Dock(FILL)

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
    playlistPanel:SetPos(510, 80)
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
    local panelX, _ = playlistPanel:GetPos()
    local panelW, _ = playlistPanel:GetSize()
    local totalW = 120 * 2 + 10
    local startX = panelX + (panelW - totalW) / 2

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
        btnAmbient:SetTextColor(color_white)
        btnCombat:SetTextColor(color_gray)
        RebuildAvailableSide()
        RebuildPlaylistSide()
    end

    btnCombat = vgui.Create("DButton", frame)
    btnCombat:SetPos(startX + 130, 35)
    btnCombat:SetSize(120, 30)
    btnCombat:SetText("COMBAT")
    btnCombat:SetTextColor(color_gray)
    btnCombat.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, not tabAmbient and Color(100, 40, 40) or c606060)
    end
    btnCombat.DoClick = function()
        tabAmbient = false
        btnCombat:SetTextColor(color_white)
        btnAmbient:SetTextColor(color_gray)
        RebuildAvailableSide()
        RebuildPlaylistSide()
    end

    function RebuildAvailableSide()
        availList:Clear()

        local currentTracks = tabAmbient and playlist.ambient or playlist.combat
        local existingPaths = {}
        for _, t in ipairs(currentTracks) do
            existingPaths[t.path] = true
        end

        for packName, pack in pairs(BATTLEBEATS.musicPacks or {}) do
            if pack.packType == "playlist" then continue end
            local tracks = tabAmbient and (pack.ambient or {}) or (pack.combat or {})

            if #tracks > 0 then
                local btnHover  = tabAmbient and Color(40, 70, 40) or Color(70, 40, 40)
                local btnNormal = tabAmbient and Color(25, 35, 25) or Color(35, 25, 25)
                local textColor = tabAmbient and Color(180, 255, 180) or Color(255, 180, 180)

                local cat = vgui.Create("DLabel", availList)
                cat:SetText(packName)
                cat:SetContentAlignment(5)
                cat:SetFont("DermaDefaultBold")
                cat:SetTextColor(color_white)
                cat:SetTall(22)
                cat:Dock(TOP)

                for _, path in ipairs(tracks) do
                    if not existingPaths[path] then
                        local btn = vgui.Create("DButton", availList)
                        btn:SetText("  " .. BATTLEBEATS.FormatTrackName(path))
                        btn:SetTall(24)
                        btn:SetTextColor(textColor)
                        btn.Paint = function(s, w, h)
                            draw.RoundedBox(0, 0, 0, w, h, s:IsHovered() and btnHover or btnNormal)
                        end
                        btn.DoClick = function()
                            table.insert(currentTracks, {
                                path = path,
                                exists = file.Exists(path, "GAME")
                            })
                            RebuildPlaylistSide()
                            RebuildAvailableSide()
                        end
                        btn:Dock(TOP)
                    end
                end
            end
        end
    end

    function RebuildPlaylistSide()
        plList:Clear()
        local currentTracks = tabAmbient and playlist.ambient or playlist.combat
        for i, track in ipairs(currentTracks) do
            local row = vgui.Create("DPanel", plList)
            row:SetTall(28)
            row:Dock(TOP)
            row:DockMargin(0, 1, 0, 1)
            row.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, track.exists and Color(30, 30, 60) or Color(70, 30, 30))
            end
            if not track.exists then
                row:SetTooltip("#btb.playlist.create.track_error")
                row:SetTooltipPanelOverride("BattleBeatsTooltip")
            end

            local name = vgui.Create("DLabel", row)
            name:Dock(LEFT)
            name:SetWide(360)
            name:DockMargin(8, 0, 0, 0)
            name:SetText(BATTLEBEATS.FormatTrackName(track.path))
            name:SetTextColor(track.exists and Color(220, 255, 220) or Color(255, 120, 120))
            name:SetContentAlignment(4)

            local del = vgui.Create("DButton", row)
            del:Dock(RIGHT)
            del:SetWide(90)
            del:SetText("REMOVE")
            del:SetTextColor(Color(255, 80, 80))
            del.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(100, 30, 30) or Color(60, 20, 20))
            end
            del.DoClick = function()
                table.remove(currentTracks, i)
                RebuildPlaylistSide()
                RebuildAvailableSide()
            end
        end
    end

    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos(10, frame:GetTall() - 40)
    saveBtn:SetSize(frame:GetWide() - 20, 30)
    saveBtn:SetText("#btb.ps.ts.rmb.assign_save")
    saveBtn:SetFont("DermaLarge")
    saveBtn:SetTextColor(color_white)
    saveBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(70, 70, 70) or c606060)
    end
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

    RebuildAvailableSide()
    RebuildPlaylistSide()
end

concommand.Add("battlebeats_playlist_editor", function()
    BATTLEBEATS.openPlaylistEditor()
end)
