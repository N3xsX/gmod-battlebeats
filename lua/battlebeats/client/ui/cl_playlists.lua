local btb = BATTLEBEATS

local shared = btb.uiShared
local LerpColor = shared.LerpColor
local ColA = shared.ColA
local animHover = shared.animHover
local drawBlur = shared.drawBlur
local makeSwitch = shared.makeSwitch
local makeSearch = shared.makeSearch
local makeScroll = shared.makeScroll

local C = shared.Colors
local TL, TC, TR, TT = TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
local L = language.GetPhrase

function btb.isTrackInPlaylist(title, track, trackType)
    local playlist = btb.musicPlaylists[title]
    if not playlist or not playlist[trackType] then return false end
    for _, v in ipairs(playlist[trackType]) do
        if v.path == track then
            return true
        end
    end
    return false
end

function btb.addTrackToPlaylist(title, track, trackType)
    local playlist = btb.musicPlaylists[title]
    local pack = btb.musicPacks[title]
    if not playlist or not pack then return end
    playlist[trackType] = playlist[trackType] or {}
    pack[trackType] = pack[trackType] or {}
    table.insert(playlist[trackType], {
        path = track,
        exists = true
    })
    table.insert(pack[trackType], track)
    btb.savePlaylists()
end

function btb.removeTrackFromPlaylist(title, track, trackType)
    local playlist = btb.musicPlaylists[title]
    local pack = btb.musicPacks[title]
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
    btb.savePlaylists()
end

local function buildMusicPackFromPlaylist(title)
    local playlist = btb.musicPlaylists[title]
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
    btb.musicPacks[title] = {
        ambient = ambientFiles,
        combat = combatFiles,
        packType = "playlist",
        packContent = packContent,
    }
end

local function validatePlaylist(title)
    local playlist = btb.musicPlaylists[title]
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

function btb.validateAndTransformPlaylist(title, data)
    if not isstring(title) or not istable(data) then return nil end
    btb.musicPlaylists[title] = data
    validatePlaylist(title)
    buildMusicPackFromPlaylist(title)
    return title, btb.musicPlaylists[title]
end

local prefix = "BTB_PLAYLIST:"
function btb.exportPlaylist(title)
    local playlist = btb.musicPlaylists[title]
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

function btb.importPlaylist(encodedString)
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

local function fitText(text, font, maxW)
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxW then return text end
    while #text > 1 and surface.GetTextSize(text .. "…") > maxW do
        local off = utf8.offset(text, -1) or #text
        text = string.sub(text, 1, off - 1)
    end
    return text .. "…"
end

local function isCtrl() return input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) end
local function isShift() return input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) end

local function makeButton(parent, x, y, w, h, text, onClick, opts)
    opts = opts or {}
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y)
    b:SetSize(w, h)
    b:SetText("")
    b:SetCursor("hand")
    if opts.tip then
        b:SetTooltip(opts.tip)
        b:SetTooltipPanelOverride("BattleBeatsTooltip")
    end
    b.Paint = function(self, pw, ph)
        local enabled = not opts.enabled or opts.enabled()
        local hov = animHover(self, "Hov", enabled and self:IsHovered())
        local down = enabled and self:IsDown()
        local accent = isfunction(opts.accent) and opts.accent() or opts.accent or C.Yellow
        local isTab = opts.active ~= nil
        local act = isTab and opts.active()
        self.Act = Lerp(FrameTime() * 12, self.Act or (act and 1 or 0), act and 1 or 0)
        local a = enabled and 255 or 90
        local outBase = isTab and LerpColor(self.Act, C.C70, accent) or accent
        draw.RoundedBox(10, 0, 0, pw, ph, ColA(LerpColor(hov * 0.35, outBase, color_white), a))
        local bg = down and C.C50 or LerpColor(hov, C.C90, C.C100)
        if isTab then bg = LerpColor(self.Act * 0.3, C.C50, accent) end
        draw.RoundedBox(9, 1, 1, pw - 2, ph - 2, ColA(bg, a))
        local t = isfunction(text) and text() or text
        draw.SimpleText(t, opts.font or "DermaDefaultBold", pw / 2, ph / 2, enabled and color_white or C.Dim, TC, TC)
    end
    b.DoClick = function()
        if opts.enabled and not opts.enabled() then return end
        surface.PlaySound("btb_tab_switch.mp3")
        onClick(b)
    end
    return b
end

local function makeCard(parent, x, y, w, h, paintExtra)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h)
    p.Paint = function(self, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, C.Card)
        if paintExtra then paintExtra(self, pw, ph) end
    end
    return p
end

local function paintRow(self, w, h, selected, accent, missing)
    local hov = animHover(self, "Hov", self:IsHovered())
    local s = Lerp(FrameTime() * 14, self.SelAnim or (selected and 1 or 0), selected and 1 or 0)
    self.SelAnim = s
    local bg
    if missing then
        bg = LerpColor(hov, C.Missing, C.MissingHov)
    else
        bg = LerpColor(hov, C.CardIn, C.C70)
    end
    draw.RoundedBox(6, 0, 0, w, h, bg)
    if s > 0.01 then
        draw.RoundedBox(6, 0, 0, w, h, ColA(accent, 60 * s))
        draw.RoundedBoxEx(6, 0, 0, 4, h, ColA(accent, 255 * s), true, false, true, false)
    end
end

local frame
local showPreviewNotification = GetConVar("battlebeats_show_preview_notification")

--MARK: editor

function btb.openPlaylistEditor(title, func)
    if IsValid(frame) then
        frame:MakePopup()
        return
    end
    local isEdit = title and btb.musicPlaylists[title] ~= nil
    local playlist = isEdit and table.Copy(btb.musicPlaylists[title]) or {
        ambient = {},
        combat = {}
    }
    playlist.ambient = playlist.ambient or {}
    playlist.combat = playlist.combat or {}
    local editedTitle = isEdit and title or ""

    local tab = "ambient"
    local searchAvail, searchPl = "", ""
    local hideAdded = cookie.GetNumber("btb_pl_hide_added", 1) == 1
    local collapsed = {}
    local sel = { side = nil, set = {}, anchor = nil, primary = nil }
    local availRows, availPanels, availAll, plRows = {}, {}, {}, {}
    local missingCount = 0
    local undoStack, redoStack = {}, {}
    local dirty = false
    local drag, ghost, dropIdx = nil, nil, nil
    local playerTitle = nil

    local availScroll, plScroll
    local rebuildAvailable, rebuildPlaylist, refreshAll

    local function notifOn() return showPreviewNotification and showPreviewNotification:GetBool() end
    local function accentColor() return tab == "ambient" and C.Ambient or C.Combat end
    local function curList() return playlist[tab] end
    local function selCount()
        local n = 0
        for _ in pairs(sel.set) do n = n + 1 end
        return n
    end
    local function clearSel() sel.side, sel.set, sel.anchor = nil, {}, nil end
    local function sortedSel()
        local t = {}
        for i in pairs(sel.set) do t[#t + 1] = i end
        table.sort(t)
        return t
    end

    --MARK: preview
    local function stopPreview()
        if IsValid(btb.currentPreviewStation) then
            btb.FadeMusic(btb.currentPreviewStation, nil, 0.5)
            btb.HideNotification()
            btb.currentPreviewTrack = nil
        end
    end

    local function previewPlay(path)
        if not path or not file.Exists(path, "GAME") then return end
        btb.PlayNextTrackPreview(path, nil, false)
        btb.currentPreviewTrack = path
        if not notifOn() then btb.HideNotification() end
        if not timer.Exists("BattleBeats_NextPreviewTrackPlaylist") then
            timer.Create("BattleBeats_NextPreviewTrackPlaylist", 0.5, 0, function()
                if IsValid(btb.currentPreviewStation) then
                    btb.currentPreviewPosition = btb.currentPreviewStation:GetTime()
                end
            end)
        end
    end

    local function onPrimaryChanged(path, forcePlay)
        sel.primary = path
        playerTitle = path and btb.FormatTrackName(path) or nil
        if not path then return end
        if not forcePlay and path == btb.currentPreviewTrack and IsValid(btb.currentPreviewStation) then return end
        if forcePlay then previewPlay(path) else stopPreview() end
    end

    local function togglePlayPause()
        local st = btb.currentPreviewStation
        local path = sel.primary
        if path and (path ~= btb.currentPreviewTrack or not IsValid(st)) then
            previewPlay(path)
            return
        end
        if not IsValid(st) then return end
        if st:GetState() == GMOD_CHANNEL_PLAYING then
            st:Pause()
            if notifOn() then btb.HideNotification() end
        else
            st:Play()
            if notifOn() then btb.ShowTrackNotification(btb.currentPreviewTrack, false, true) end
        end
    end

    --MARK: history / mutations
    local function commit()
        undoStack[#undoStack + 1] = table.Copy(playlist)
        if #undoStack > 50 then table.remove(undoStack, 1) end
        redoStack = {}
        dirty = true
    end

    local function undo()
        if #undoStack == 0 then return end
        redoStack[#redoStack + 1] = table.Copy(playlist)
        playlist = table.remove(undoStack)
        dirty = true
        clearSel()
        refreshAll()
    end

    local function redo()
        if #redoStack == 0 then return end
        undoStack[#undoStack + 1] = table.Copy(playlist)
        playlist = table.remove(redoStack)
        dirty = true
        clearSel()
        refreshAll()
    end

    local function addAndSelect(paths)
        if #paths == 0 then return end
        local list = curList()
        local existing = {}
        for _, t in ipairs(list) do existing[t.path] = true end
        local toAdd = {}
        for _, p in ipairs(paths) do
            if not existing[p] then
                existing[p] = true
                toAdd[#toAdd + 1] = p
            end
        end
        if #toAdd == 0 then return end
        commit()
        local start = #list + 1
        for _, p in ipairs(toAdd) do
            list[#list + 1] = { path = p, exists = file.Exists(p, "GAME") }
        end
        sel.side, sel.set, sel.anchor = "playlist", {}, start
        for i = start, #list do sel.set[i] = true end
        refreshAll()
        timer.Simple(0, function()
            if IsValid(plScroll) then plScroll:GetVBar():SetScroll(math.huge) end
        end)
    end

    local function addSelected()
        if sel.side ~= "available" then return end
        local paths = {}
        for _, p in ipairs(availRows) do
            if sel.set[p] then paths[#paths + 1] = p end
        end
        addAndSelect(paths)
    end

    local function removeSelected()
        if sel.side ~= "playlist" then return end
        local idxs = sortedSel()
        if #idxs == 0 then return end
        commit()
        local list = curList()
        for k = #idxs, 1, -1 do table.remove(list, idxs[k]) end
        clearSel()
        sel.primary, playerTitle = nil, nil
        refreshAll()
    end

    local function moveSelected(dir)
        if sel.side ~= "playlist" then return end
        local idxs = sortedSel()
        local list = curList()
        local n = #list
        if #idxs == 0 then return end
        if (dir < 0 and idxs[1] <= 1) or (dir > 0 and idxs[#idxs] >= n) then return end
        commit()
        local newSet = {}
        if dir < 0 then
            for _, i in ipairs(idxs) do
                list[i], list[i - 1] = list[i - 1], list[i]
                newSet[i - 1] = true
            end
        else
            for k = #idxs, 1, -1 do
                local i = idxs[k]
                list[i], list[i + 1] = list[i + 1], list[i]
                newSet[i + 1] = true
            end
        end
        sel.set = newSet
        sel.anchor = sel.anchor and (sel.anchor + dir) or nil
        rebuildPlaylist(false)
    end

    local function reorder(idxs, di)
        if #idxs == 0 or not di then return end
        local contiguous = (idxs[#idxs] - idxs[1] + 1) == #idxs
        if contiguous and di >= idxs[1] and di <= idxs[#idxs] + 1 then return end
        commit()
        local list = curList()
        local moved, before = {}, 0
        for _, i in ipairs(idxs) do
            moved[#moved + 1] = list[i]
            if i < di then before = before + 1 end
        end
        for k = #idxs, 1, -1 do table.remove(list, idxs[k]) end
        local at = di - before
        local newSet = {}
        for k, t in ipairs(moved) do
            table.insert(list, at + k - 1, t)
            newSet[at + k - 1] = true
        end
        sel.set = newSet
        sel.anchor = at
        rebuildPlaylist(false)
    end

    --MARK: selection handlers
    local function handleAvailClick(flat, path)
        local ctrl, shift = isCtrl(), isShift()
        if shift and sel.side == "available" and sel.anchor then
            local a, b = math.min(sel.anchor, flat), math.max(sel.anchor, flat)
            local set = {}
            for k = a, b do
                if availRows[k] then set[availRows[k]] = true end
            end
            sel.set = set
        elseif ctrl then
            if sel.side ~= "available" then clearSel() end
            sel.side = "available"
            if sel.set[path] then sel.set[path] = nil else sel.set[path] = true end
            sel.anchor = flat
        else
            sel.side, sel.set, sel.anchor = "available", { [path] = true }, flat
        end
        onPrimaryChanged(path)
    end

    local function handlePlaylistClick(trackIndex, path)
        local ctrl, shift = isCtrl(), isShift()
        if shift and sel.side == "playlist" and sel.anchor then
            local a, b = math.min(sel.anchor, trackIndex), math.max(sel.anchor, trackIndex)
            local set = {}
            for _, row in ipairs(plRows) do
                if row.trackIndex >= a and row.trackIndex <= b then set[row.trackIndex] = true end
            end
            sel.set = set
        elseif ctrl then
            if sel.side ~= "playlist" then clearSel() end
            sel.side = "playlist"
            if sel.set[trackIndex] then sel.set[trackIndex] = nil else sel.set[trackIndex] = true end
            sel.anchor = trackIndex
        else
            sel.side, sel.set, sel.anchor = "playlist", { [trackIndex] = true }, trackIndex
        end
        onPrimaryChanged(path)
    end

    local function selectAll()
        local side = sel.side or "playlist"
        local set = {}
        if side == "available" then
            for _, p in ipairs(availRows) do set[p] = true end
            sel.anchor = 1
        else
            for _, row in ipairs(plRows) do set[row.trackIndex] = true end
            sel.anchor = plRows[1] and plRows[1].trackIndex or nil
        end
        if next(set) == nil then return end
        sel.side, sel.set = side, set
    end

    local function stepSelection(dir, forcePlay)
        local side = sel.side or "available"
        if side == "available" then
            if #availRows == 0 then return end
            local k = 0
            for idx, p in ipairs(availRows) do
                if p == sel.primary then
                    k = idx
                    break
                end
            end
            k = math.Clamp(k + dir, 1, #availRows)
            local path = availRows[k]
            sel.side, sel.set, sel.anchor = "available", { [path] = true }, k
            local pnl = availPanels[path]
            if IsValid(pnl) then availScroll:ScrollToChild(pnl) end
            onPrimaryChanged(path, forcePlay)
        else
            if #plRows == 0 then return end
            local pos = 0
            for idx, row in ipairs(plRows) do
                if row.trackIndex == sel.anchor then
                    pos = idx
                    break
                end
            end
            pos = math.Clamp(pos + dir, 1, #plRows)
            local row = plRows[pos]
            local tr = curList()[row.trackIndex]
            if not tr then return end
            sel.side, sel.set, sel.anchor = "playlist", {[row.trackIndex] = true}, row.trackIndex
            plScroll:ScrollToChild(row)
            onPrimaryChanged(tr.path, forcePlay)
        end
    end

    --MARK: drag & drop (playlist)
    local function calcDropIndex()
        local _, my = gui.MousePos()
        for _, row in ipairs(plRows) do
            if IsValid(row) then
                local _, ry = row:LocalToScreen(0, 0)
                if my < ry + row:GetTall() / 2 then return row.trackIndex end
            end
        end
        local last = plRows[#plRows]
        return last and (last.trackIndex + 1) or 1
    end

    local function finishDrag(doDrop)
        if IsValid(ghost) then ghost:Remove() end
        ghost = nil
        local d, di = drag, dropIdx
        drag, dropIdx = nil, nil
        if not d or not d.active or not doDrop then return end
        if not sel.set[d.index] then return end
        reorder(sortedSel(), di)
    end

    --MARK: frame
    local fw, fh = 1100, 824
    local hd = 44
    frame = vgui.Create("DFrame")
    local f = frame
    f:SetSize(fw, fh)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:BTB_SetButtons(false, -5, 7)
    f:MakePopup()
    f:SetAlpha(0)
    f:AlphaTo(255, 0.15, 0)

    f.Paint = function(self, w, h)
        drawBlur(self, 3)
        draw.RoundedBox(12, 0, 0, w, h, C.Bg)
        surface.SetDrawColor(C.Yellow)
        surface.DrawRect(0, hd - 1, w, 1)
        draw.SimpleText("Playlist", "Trebuchet24", 27, hd / 2 - 7, C.Yellow, TL, TC)
        draw.SimpleText("BattleBeats", "HudSelectionText", 18, hd / 2 + 8, C.Yellow, TL, TC)
        local status = dirty and "● Unsaved changes" or (isEdit and "Editing" or "New playlist")
        draw.SimpleText(status, "DermaDefaultBold", 130, hd / 2, dirty and C.Yellow or C.Dim, TL, TC)
        btb.drawRoundedOutline(12, 0, 0, w, h, 1, C.Yellow)
    end

    local nameEntry = makeSearch(f, f:GetWide() / 2 - 150, 8, 300, 28, L("btb.playlist.create.enter_name"), function(v)
        editedTitle = v:Trim()
        dirty = true
    end, "DermaDefaultBold")
    nameEntry:SetMaximumCharCount(30)
    nameEntry:SetText(editedTitle)

    makeButton(f, fw - 130 - 56 - 6 - 56, 8, 56, 28, "Undo", undo, {enabled = function() return #undoStack > 0 end, tip = "Undo (Ctrl+Z)"})
    makeButton(f, fw - 130 - 56, 8, 56, 28, "Redo", redo, {enabled = function() return #redoStack > 0 end, tip = "Redo (Ctrl+Y)"})

    -- tabs
    local function switchTab(t)
        if tab == t then return end
        tab = t
        clearSel()
        rebuildAvailable(true)
        rebuildPlaylist(true)
    end
    makeButton(f, fw / 2 - 208, 52, 200, 28, function() return "AMBIENT  (" .. #playlist.ambient .. ")" end, function() switchTab("ambient") end, { accent = C.Ambient, active = function() return tab == "ambient" end })
    makeButton(f, fw / 2 + 8, 52, 200, 28, function() return "COMBAT  (" .. #playlist.combat .. ")" end, function() switchTab("combat") end, { accent = C.Combat, active = function() return tab == "combat" end })

    --MARK: library card (left)
    local cardY, cardH = 90, 542
    local left = makeCard(f, 12, cardY, 480, cardH, function(self, pw, ph)
        surface.SetFont("DermaDefaultBold")
        draw.SimpleText("LIBRARY", "DermaDefaultBold", 16, 10, color_white, TL, TT)
        local tw = surface.GetTextSize("LIBRARY")
        local info = #availAll .. " tracks"
        if sel.side == "available" and selCount() > 0 then info = info .. "  ·  " .. selCount() .. " selected" end
        draw.SimpleText(info, "DermaDefault", 16 + tw + 10, 10, C.Dim, TL, TT)
        draw.SimpleText("Hide added", "DermaDefault", pw - 62, 18, C.Dim, TR, TC)
    end)
    makeSwitch(left, 480 - 56, 8, function() return hideAdded end, function(v)
        hideAdded = v
        cookie.Set("btb_pl_hide_added", v and "1" or "0")
        rebuildAvailable(false)
    end)
    makeSearch(left, 12, 34, 456, 28, "Search library...", function(v)
        searchAvail = v
        rebuildAvailable(true)
    end, "DermaDefault")

    local function setAllCollapsed(v)
        for name in pairs(btb.musicPacks or {}) do collapsed[name] = v end
        rebuildAvailable(false)
    end
    makeButton(left, 12, 68, 100, 26, "Expand all", function() setAllCollapsed(false) end)
    makeButton(left, 120, 68, 100, 26, "Collapse all", function() setAllCollapsed(true) end)
    makeButton(left, 228, 68, 240, 26, function() return "Add all shown (" .. #availAll .. ")" end, function() addAndSelect(table.Copy(availAll)) end, {enabled = function() return #availAll > 0 end, accent = accentColor})

    availScroll = makeScroll(left)
    availScroll:SetPos(12, 100)
    availScroll:SetSize(456, cardH - 100 - 8)
    availScroll.PaintOver = function(self, w, h)
        if #availRows > 0 then return end
        local msg = #availAll == 0 and "No tracks to show" or ""
        draw.SimpleText(msg, "Trebuchet18", w / 2, h / 2, C.Dim, TC, TC)
    end

    --MARK: playlist card (right)
    local right = makeCard(f, 608, cardY, 480, cardH, function(self, pw, ph)
        surface.SetFont("DermaDefaultBold")
        draw.SimpleText("PLAYLIST", "DermaDefaultBold", 16, 10, color_white, TL, TT)
        local tw = surface.GetTextSize("PLAYLIST")
        local info = #curList() .. " tracks"
        if missingCount > 0 then info = info .. "  ·  " .. missingCount .. " missing" end
        if sel.side == "playlist" and selCount() > 0 then info = info .. "  ·  " .. selCount() .. " selected" end
        draw.SimpleText(info, "DermaDefault", 16 + tw + 10, 10, missingCount > 0 and C.Warn or C.Dim, TL, TT)
    end)
    makeSearch(right, 12, 34, 456, 28, "Search playlist...", function(v)
        searchPl = v
        rebuildPlaylist(true)
    end, "DermaDefault")

    makeButton(right, 12, 68, 108, 26, "Shuffle", function()
        commit()
        local list = curList()
        for i = #list, 2, -1 do
            local j = math.random(i)
            list[i], list[j] = list[j], list[i]
        end
        clearSel()
        rebuildPlaylist(false)
    end, { enabled = function() return #curList() > 1 end })
    makeButton(right, 128, 68, 108, 26, "Sort A-Z", function()
        commit()
        table.sort(curList(), function(a, b)
            return string.lower(btb.FormatTrackName(a.path)) < string.lower(btb.FormatTrackName(b.path))
        end)
        clearSel()
        rebuildPlaylist(false)
    end, { enabled = function() return #curList() > 1 end })
    makeButton(right, 244, 68, 108, 26, "Clear", function()
        commit()
        local list = curList()
        for i = #list, 1, -1 do list[i] = nil end
        clearSel()
        refreshAll()
    end, { enabled = function() return #curList() > 0 end, accent = C.Warn })
    makeButton(right, 360, 68, 108, 26, "Fix missing", function()
        commit()
        local list = curList()
        for i = #list, 1, -1 do
            if not list[i].exists then table.remove(list, i) end
        end
        clearSel()
        refreshAll()
    end, { enabled = function() return missingCount > 0 end, accent = C.Warn, tip = "Remove tracks whose files no longer exist" })

    plScroll = makeScroll(right)
    plScroll:SetPos(12, 100)
    plScroll:SetSize(456, cardH - 100 - 8)

    plScroll.PaintOver = function(self, w, h)
        if #plRows == 0 then
            if #curList() == 0 then
                draw.SimpleText(L(tab == "ambient" and "btb.playlist.create.ambient_empty" or "btb.playlist.create.combat_empty"), "Trebuchet18", w / 2, h / 2 - 12, C.Dim, TC, TC)
                draw.SimpleText(L("btb.playlist.create.list_empty"), "Trebuchet18", w / 2, h / 2 + 12, C.Dim, TC, TC)
            else
                draw.SimpleText("No matches", "Trebuchet18", w / 2, h / 2, C.Dim, TC, TC)
            end
        end
        if drag and drag.active and dropIdx and #plRows > 0 then
            local target
            for _, row in ipairs(plRows) do
                if row.trackIndex == dropIdx then
                    target = row
                    break
                end
            end
            local y
            if IsValid(target) then
                local _, ry = target:LocalToScreen(0, 0)
                local _, ly = self:ScreenToLocal(0, ry)
                y = ly - 1
            else
                local last = plRows[#plRows]
                local _, ry = last:LocalToScreen(0, last:GetTall())
                local _, ly = self:ScreenToLocal(0, ry)
                y = ly + 1
            end
            surface.SetDrawColor(C.Yellow)
            surface.DrawRect(0, y - 1, w, 2)
        end
    end

    plScroll.Think = function(self)
        if not drag then return end
        if not input.IsMouseDown(MOUSE_LEFT) then
            drag.up = (drag.up or 0) + 1
            if drag.up > 5 then finishDrag(false) end
            return
        end
        drag.up = 0
        local mx, my = gui.MousePos()
        if not drag.active then
            if searchPl == "" and math.abs(mx - drag.sx) + math.abs(my - drag.sy) > 6 then
                drag.active = true
                local n = selCount()
                local label = n > 1 and (n .. " tracks") or
                btb.FormatTrackName(curList()[drag.index] and curList()[drag.index].path or "")
                ghost = vgui.Create("DPanel", f)
                ghost:SetSize(260, 26)
                ghost:SetMouseInputEnabled(false)
                ghost:SetKeyboardInputEnabled(false)
                ghost.Paint = function(_, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, ColA(C.Yellow, 220))
                    draw.RoundedBox(5, 1, 1, w - 2, h - 2, ColA(C.C50, 240))
                    draw.SimpleText(fitText(label, "DermaDefaultBold", w - 16), "DermaDefaultBold", 8, h / 2, color_white, TL, TC)
                end
            end
            return
        end
        if IsValid(ghost) then
            local lx, ly = f:ScreenToLocal(mx, my)
            ghost:SetPos(lx + 12, ly + 8)
            ghost:MoveToFront()
        end
        dropIdx = calcDropIndex()
        local _, py = self:LocalToScreen(0, 0)
        if my < py + 30 then
            self:GetVBar():AddScroll(-0.4)
        elseif my > py + self:GetTall() - 30 then
            self:GetVBar():AddScroll(0.4)
        end
    end

    --MARK: middle column
    local midX = 526
    makeButton(f, midX, 240, 48, 40, "▶", addSelected, {
        font = "DermaLarge",
        tip = "Add selected (Enter / double-click)",
        enabled = function() return sel.side == "available" and selCount() > 0 end,
        accent = accentColor
    })
    makeButton(f, midX, 288, 48, 40, "◀", removeSelected, {
        font = "DermaLarge",
        tip = "Remove selected (Del / double-click)",
        enabled = function() return sel.side == "playlist" and selCount() > 0 end,
        accent = C.Warn
    })
    makeButton(f, midX, 372, 48, 40, "▲", function() moveSelected(-1) end, {
        font = "DermaLarge",
        tip = "Move up (Ctrl+Up)",
        enabled = function() return sel.side == "playlist" and selCount() > 0 end
    })
    makeButton(f, midX, 420, 48, 40, "▼", function() moveSelected(1) end, {
        font = "DermaLarge",
        tip = "Move down (Ctrl+Down)",
        enabled = function() return sel.side == "playlist" and selCount() > 0 end
    })

    --MARK: rebuild: library
    rebuildAvailable = function(reset)
        local vb = availScroll:GetVBar()
        local keep = reset and 0 or vb:GetScroll()
        availScroll:Clear()
        availRows, availPanels, availAll = {}, {}, {}

        local accent = accentColor()
        local existing = {}
        for _, t in ipairs(curList()) do existing[t.path] = true end
        local q = string.lower(searchAvail)

        local names = {}
        for packName, pack in pairs(btb.musicPacks or {}) do
            if pack.packType ~= "playlist" then names[#names + 1] = packName end
        end
        table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)

        for _, packName in ipairs(names) do
            local pack = btb.musicPacks[packName]
            local tracks = (tab == "ambient" and pack.ambient or pack.combat) or {}
            if #tracks > 0 then
                if collapsed[packName] == nil then collapsed[packName] = true end
                local displayName = btb.stripPackPrefix(L(packName))
                local packMatch = q ~= "" and string.find(string.lower(displayName), q, 1, true)

                local visible = {}
                for _, path in ipairs(tracks) do
                    if not (hideAdded and existing[path]) then
                        if q == "" or packMatch or string.find(string.lower(btb.FormatTrackName(path)), q, 1, true) then
                            visible[#visible + 1] = path
                            availAll[#availAll + 1] = path
                        end
                    end
                end

                if #visible > 0 then
                    local expanded = q ~= "" or not collapsed[packName]
                    local ph = vgui.Create("DButton", availScroll)
                    ph:Dock(TOP)
                    ph:DockMargin(0, 0, 0, 2)
                    ph:SetTall(28)
                    ph:SetText("")
                    ph:SetCursor("hand")
                    ph.Paint = function(self, w, h)
                        local hov = animHover(self, "Hov", self:IsHovered())
                        draw.RoundedBox(6, 0, 0, w, h, LerpColor(hov, C.C50, C.C70))
                        draw.SimpleText(expanded and "▼" or "▶", "DermaDefault", 12, h / 2, C.Yellow, TL, TC)
                        draw.SimpleText(fitText(displayName, "DermaDefaultBold", w - 110), "DermaDefaultBold", 30, h / 2, color_white, TL, TC)
                        draw.SimpleText(tostring(#visible), "DermaDefault", w - 44, h / 2, C.Dim, TR, TC)
                    end
                    ph.DoClick = function()
                        collapsed[packName] = not collapsed[packName]
                        rebuildAvailable(false)
                    end

                    local addAll = vgui.Create("DButton", ph)
                    addAll:Dock(RIGHT)
                    addAll:DockMargin(0, 3, 4, 3)
                    addAll:SetWide(28)
                    addAll:SetText("")
                    addAll:SetCursor("hand")
                    addAll:SetTooltip("Add whole pack (" .. #visible .. ")")
                    addAll:SetTooltipPanelOverride("BattleBeatsTooltip")
                    addAll.Paint = function(self, w, h)
                        local hov = animHover(self, "Hov", self:IsHovered())
                        draw.RoundedBox(5, 0, 0, w, h, LerpColor(hov, C.C90, accent))
                        draw.SimpleText("+", "DermaDefaultBold", w / 2, h / 2, color_white, TC, TC)
                    end
                    addAll.DoClick = function()
                        surface.PlaySound("btb_tab_switch.mp3")
                        addAndSelect(table.Copy(visible))
                    end

                    if expanded then
                        for _, path in ipairs(visible) do
                            availRows[#availRows + 1] = path
                            local flat = #availRows
                            local name = btb.FormatTrackName(path)
                            local row = vgui.Create("DButton", availScroll)
                            row:Dock(TOP)
                            row:DockMargin(10, 0, 0, 2)
                            row:SetTall(26)
                            row:SetText("")
                            row:SetCursor("hand")
                            availPanels[path] = row
                            row.Paint = function(self, w, h)
                                paintRow(self, w, h, sel.side == "available" and sel.set[path], accent, false)
                                draw.SimpleText(fitText(name, "DermaDefault", w - 20), "DermaDefault", 12, h / 2, C.Text, TL, TC)
                            end
                            row.DoClick = function() handleAvailClick(flat, path) end
                            row.DoDoubleClick = function() addAndSelect({ path }) end
                        end
                    end
                end
            end
        end

        if sel.side == "available" then
            local vis = {}
            for _, p in ipairs(availRows) do vis[p] = true end
            for p in pairs(sel.set) do
                if not vis[p] then sel.set[p] = nil end
            end
            sel.anchor = nil
        end

        availScroll:GetCanvas():InvalidateLayout(true)
        availScroll:InvalidateLayout(true)
        vb:SetScroll(keep)
    end

    --MARK: rebuild: playlist
    rebuildPlaylist = function(reset)
        local vb = plScroll:GetVBar()
        local keep = reset and 0 or vb:GetScroll()
        plScroll:Clear()
        plRows = {}
        missingCount = 0

        local list = curList()
        local accent = accentColor()
        local q = string.lower(searchPl)

        if sel.side == "playlist" then
            for i in pairs(sel.set) do
                if i > #list then sel.set[i] = nil end
            end
        end

        for i, track in ipairs(list) do
            if not track.exists then missingCount = missingCount + 1 end
            local name = btb.FormatTrackName(track.path)
            if q == "" or string.find(string.lower(name), q, 1, true) then
                local row = vgui.Create("DButton", plScroll)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 2)
                row:SetTall(26)
                row:SetText("")
                row:SetCursor("hand")
                row.trackIndex = i
                plRows[#plRows + 1] = row
                local path = track.path

                row.Paint = function(self, w, h)
                    paintRow(self, w, h, sel.side == "playlist" and sel.set[i], accent, not track.exists)
                    draw.SimpleText(string.format("%02d", i), "DermaDefaultBold", 12, h / 2, C.Dim, TL, TC)
                    draw.SimpleText(fitText(name, "DermaDefault", w - 110), "DermaDefault", 42, h / 2, track.exists and C.Text or C.Warn, TL, TC)
                    if not track.exists then
                        draw.SimpleText("MISSING", "DermaDefaultBold", w - 10, h / 2, C.Warn, TR, TC)
                    end
                end
                if not track.exists then
                    row:SetTooltip("#btb.playlist.create.track_error")
                    row:SetTooltipPanelOverride("BattleBeatsTooltip")
                end

                row.lastClick = 0
                row.OnMousePressed = function(self, code)
                    if code ~= MOUSE_LEFT then return end
                    local now = CurTime()
                    if now - (self.lastClick or 0) < 0.3 then
                        commit()
                        table.remove(curList(), i)
                        clearSel()
                        refreshAll()
                        return
                    end
                    self.lastClick = now

                    if isCtrl() or isShift() then
                        handlePlaylistClick(i, path)
                        return
                    end

                    local wasSelected = sel.side == "playlist" and sel.set[i]
                    local collapse = false
                    if not wasSelected then
                        handlePlaylistClick(i, path)
                    elseif selCount() > 1 then
                        collapse = true
                    else
                        onPrimaryChanged(path)
                    end
                    local mx, my = gui.MousePos()
                    drag = { index = i, sx = mx, sy = my, active = false, collapse = collapse }
                    self:MouseCapture(true)
                end
                row.OnMouseReleased = function(self, code)
                    if code ~= MOUSE_LEFT then return end
                    self:MouseCapture(false)
                    local d = drag
                    local wasActive = d and d.active
                    finishDrag(true)
                    if d and not wasActive and d.collapse then
                        handlePlaylistClick(i, path)
                    end
                end
            end
        end

        plScroll:GetCanvas():InvalidateLayout(true)
        plScroll:InvalidateLayout(true)
        vb:SetScroll(keep)
    end

    refreshAll = function()
        rebuildAvailable(false)
        rebuildPlaylist(false)
    end

    --MARK: player card
    local pw = fw - 24
    local player = makeCard(f, 12, 644, pw, 116, function(self, w, h)
        local st = btb.currentPreviewStation
        local valid = IsValid(st)
        local cur = valid and st:GetTime() or 0
        local len = valid and st:GetLength() or 0
        local ttl = playerTitle or (btb.currentPreviewTrack and btb.FormatTrackName(btb.currentPreviewTrack)) or L("btb.ps.ts.mp.no_track")
        draw.SimpleText(fitText(ttl, "BattleBeats_Player_Font", w - 280), "BattleBeats_Player_Font", w / 2, 22, color_white, TC, TC)
        draw.SimpleText(btb.FormatTime(cur), "DermaDefaultBold", 16, 99, C.Text, TL, TC)
        draw.SimpleText(btb.FormatTime(len), "DermaDefaultBold", w - 16, 99, C.Text, TR, TC)
    end)

    makeButton(player, pw / 2 - 20 - 10 - 44, 45, 44, 30, "◀◀", function() stepSelection(-1, true) end, { tip = "Previous track" })
    makeButton(player, pw / 2 + 20 + 10, 45, 44, 30, "▶▶", function() stepSelection(1, true) end, { tip = "Next track" })

    local pb = vgui.Create("DButton", player)
    pb:SetPos(pw / 2 - 20, 40)
    pb:SetSize(40, 40)
    pb:SetText("")
    pb:SetCursor("hand")
    pb:SetTooltip("Play / pause (Space)")
    pb:SetTooltipPanelOverride("BattleBeatsTooltip")
    pb.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered())
        local st = btb.currentPreviewStation
        local playing = IsValid(st) and st:GetState() == GMOD_CHANNEL_PLAYING
        draw.RoundedBox(h / 2, 0, 0, w, h, LerpColor(hov * 0.4, C.Yellow, color_white))
        surface.SetDrawColor(C.C50)
        if playing then
            surface.DrawRect(w / 2 - 7, h / 2 - 8, 5, 16)
            surface.DrawRect(w / 2 + 2, h / 2 - 8, 5, 16)
        else
            draw.NoTexture()
            surface.DrawPoly({
                { x = w / 2 - 5, y = h / 2 - 9 },
                { x = w / 2 + 9, y = h / 2 },
                { x = w / 2 - 5, y = h / 2 + 9 },
            })
        end
    end
    pb.DoClick = togglePlayPause

    local prog = vgui.Create("DPanel", player)
    prog:SetPos(64, 72)
    prog:SetSize(pw - 128, 36)
    prog:SetCursor("hand")

    local function seekTo(x)
        local st = btb.currentPreviewStation
        if not IsValid(st) then return end
        local len = st:GetLength()
        if len <= 0 then return end
        st:SetTime(math.Clamp(x / prog:GetWide(), 0, 1) * len, true)
    end

    prog.Paint = function(self, w, h)
        local st = btb.currentPreviewStation
        local valid = IsValid(st)
        local len = valid and st:GetLength() or 0
        local cur = valid and st:GetTime() or 0
        local hov = animHover(self, "Hov", self:IsHovered())
        local bh = 6 + hov * 2
        local by = 27 - bh / 2
        draw.RoundedBox(4, 0, by, w, bh, C.Track)
        local p = len > 0 and math.Clamp(cur / len, 0, 1) or 0
        if p > 0 then
            draw.RoundedBox(4, 0, by, math.max(w * p, bh), bh, LerpColor(hov * 0.3, C.Yellow, color_white))
        end
        local dr = 5 + hov * 2
        draw.RoundedBox(dr, math.Clamp(w * p - dr, 0, w - dr * 2), 27 - dr, dr * 2, dr * 2, color_white)
        if len > 0 and (self:IsHovered()) then
            local mx = (self:CursorPos())
            local t = math.Clamp(mx / w, 0, 1) * len
            draw.SimpleText(btb.FormatTime(t), "DermaDefaultBold", math.Clamp(mx, 20, w - 20), 8, color_white, TC, TC)
        end
    end
    prog.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self:MouseCapture(true)
        seekTo((self:CursorPos()))
    end
    prog.OnMouseReleased = function(self)
        self:MouseCapture(false)
    end

    --MARK: save
    local function doSave()
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

        for packName, _ in pairs(btb.musicPacks or {}) do
            if editedTitle == packName then
                if not isEdit or editedTitle ~= title then
                    notification.AddLegacy("#btb.playlist.create.name_error", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button11.wav")
                    return
                end
            end
        end

        if isEdit and editedTitle ~= title then
            btb.musicPlaylists[title] = nil
            btb.musicPacks[title] = nil
        end

        if isEdit then
            notification.AddLegacy("#btb.playlist.create.edit_succ", NOTIFY_GENERIC, 3)
        else
            notification.AddLegacy("#btb.playlist.create.create_succ", NOTIFY_GENERIC, 3)
        end
        surface.PlaySound("buttons/button3.wav")

        btb.musicPlaylists[editedTitle] = playlist

        validatePlaylist(editedTitle)
        buildMusicPackFromPlaylist(editedTitle)

        btb.savePlaylists()

        if isfunction(func) then
            func()
        end

        dirty = false
        f:Close()
    end

    makeButton(f, 12, 772, fw - 24, 40, function() return L("btb.ps.ts.rmb.assign_save") end, doSave, {font = "Trebuchet24", tip = "Ctrl+S" })

    --MARK: keyboard
    f.OnKeyCodePressed = function(self, key)
        local focus = vgui.GetKeyboardFocus()
        if IsValid(focus) and isfunction(focus.IsEditing) and focus:IsEditing() then return end
        local ctrl = isCtrl()
        if key == KEY_DELETE or key == KEY_BACKSPACE then
            removeSelected()
        elseif ctrl and key == KEY_A then
            selectAll()
        elseif ctrl and key == KEY_Z then
            undo()
        elseif ctrl and key == KEY_Y then
            redo()
        elseif ctrl and key == KEY_S then
            doSave()
        elseif key == KEY_SPACE then
            togglePlayPause()
        elseif key == KEY_ENTER or key == KEY_PAD_ENTER then
            addSelected()
        elseif key == KEY_UP then
            if ctrl then moveSelected(-1) else stepSelection(-1) end
        elseif key == KEY_DOWN then
            if ctrl then moveSelected(1) else stepSelection(1) end
        end
    end

    if IsValid(f.btnClose) then
        local origClose = f.btnClose.DoClick
        f.btnClose.DoClick = function()
            local function doClose()
                if origClose then origClose(f.btnClose) else f:Close() end
            end
            if dirty then
                Derma_Query("You have unsaved changes. Discard them?", "Playlist editor",
                    "Discard", function()
                        dirty = false
                        doClose()
                    end, "Keep editing")
            else
                doClose()
            end
        end
    end

    f.OnClose = function()
        if timer.Exists("BattleBeats_NextPreviewTrackPlaylist") then
            timer.Remove("BattleBeats_NextPreviewTrackPlaylist")
        end
        if IsValid(btb.currentPreviewStation) then
            btb.FadeMusic(btb.currentPreviewStation)
            btb.HideNotification()
            btb.currentPreviewTrack = nil
        end
        timer.Simple(2, function()
            if not table.IsEmpty(btb.currentPacks) and not IsValid(btb.currentStation) then
                local nextTrack = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat)
                if nextTrack then
                    btb.PlayNextTrack(nextTrack)
                end
            end
        end)
    end

    rebuildAvailable(true)
    rebuildPlaylist(true)
end

concommand.Add("battlebeats_playlist_editor", function()
    btb.openPlaylistEditor()
end)
