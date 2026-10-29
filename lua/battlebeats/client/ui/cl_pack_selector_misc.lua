local btb = BATTLEBEATS

local shared = btb.uiShared
local LerpColor = shared.LerpColor
local ColA = shared.ColA
local animHover = shared.animHover
local drawBlur = shared.drawBlur
local makeSearch = shared.makeSearch
local makeScroll = shared.makeScroll

local C = shared.Colors
local TL, TC, TR, TT = TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
local L = language.GetPhrase

--MARK:Steamworks info
local buttonWidth, buttonHeight, spacing = 200, 30, 40
local panelWidth = 950
local ssize = language.GetPhrase("#btb.ps.info.size")
local screated = language.GetPhrase("#btb.ps.info.created")
local sauthor = language.GetPhrase("#btb.ps.info.author")
local function getSizeColor(size)
    size = tonumber(size) or 0
    if size < 200 * 1024 then
        return Color(0, 200, 0)
    elseif size < 600 * 1024 then
        return Color(255, 140, 0)
    else
        return Color(200, 0, 0)
    end
end

local function createInfoBox(panel, x)
    local box = vgui.Create("DPanel", panel)
    box:SetSize(buttonWidth, buttonHeight)
    box:SetPos(x, 120)
    box.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.Yellow)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, C.C40)
    end
    local label = vgui.Create("DLabel", box)
    label:SetFont("DermaDefault")
    label:SetTextColor(C.C200)
    label:Center()
    box.label = label
    return box
end

local function updateBox(box, text, color)
    box.label:SetText(text)
    box.label:SetTextColor(color or C.C200)
    box.label:SizeToContents()
    box.label:Center()
end

local function createInfoBoxes(panel)
    local totalWidth = buttonWidth * 3 + spacing * 2
    local startX = (panelWidth - totalWidth) / 2
    panel.infoPanels = {
        createInfoBox(panel, startX),
        createInfoBox(panel, startX + buttonWidth + spacing),
        createInfoBox(panel, startX + (buttonWidth + spacing) * 2)
    }
    return unpack(panel.infoPanels)
end

local function applyInfo(panel, result)
    local size = result.size and string.NiceSize(result.size) or "N/A"
    local date = result.created and os.date("%Y-%m-%d", result.created) or "N/A"
    local owner = result.ownername or "N/A"
    updateBox(panel.infoPanels[1], ssize .. ": " .. size, getSizeColor(size))
    updateBox(panel.infoPanels[2], screated .. ": " .. date)
    updateBox(panel.infoPanels[3], sauthor .. ": " .. owner)
end

function btb.createInfoPanel(panel, packData, callback)
    if not IsValid(panel) then return end

    local sizeP, dateP, authorP = createInfoBoxes(panel)
    updateBox(sizeP, ssize .. ": Loading...")
    updateBox(dateP, screated .. ": Loading...")
    updateBox(authorP, sauthor .. ": Loading...")

    if callback then
        callback(sizeP, dateP, authorP)
    end

    local wsid = packData.wsid
    if not wsid then
        applyInfo(panel, {})
        return
    end

    if btb.wsCache[wsid] then
        applyInfo(panel, btb.wsCache[wsid])
        return
    end

    steamworks.FileInfo(wsid, function(result)
        result = result or {}
        btb.wsCache[wsid] = result
        if IsValid(panel) then
            applyInfo(panel, result)
        end
    end)
end

--MARK: UI helpers
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
        local bgc = down and C.C50 or LerpColor(hov, C.C90, C.C100)
        if isTab then bgc = LerpColor(self.Act * 0.3, C.C50, accent) end
        draw.RoundedBox(9, 1, 1, pw - 2, ph - 2, ColA(bgc, a))
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

local function makeCard(parent, x, y, w, h)
    local p = vgui.Create("DPanel", parent)
    p:SetPos(x, y)
    p:SetSize(w, h)
    p.Paint = function(self, pw, ph)
        draw.RoundedBox(10, 0, 0, pw, ph, C.Card)
    end
    return p
end

local function makeEntry(parent, x, y, w, h, placeholder, font, multiline)
    font = font or "DermaDefault"
    local ph = string.sub(placeholder or "", 1, 1) == "#" and L(placeholder) or (placeholder or "")
    local e = vgui.Create("DTextEntry", parent)
    e:SetPos(x, y)
    e:SetSize(w, h)
    e:SetFont(font)
    if multiline then e:SetMultiline(true) end
    e:SetDrawLanguageID(false)
    e.Paint = function(self, pw, phh)
        local foc = animHover(self, "Foc", self:HasFocus())
        draw.RoundedBox(6, 0, 0, pw, phh, LerpColor(foc, C.C70, C.Yellow))
        draw.RoundedBox(5, 1, 1, pw - 2, phh - 2, LerpColor(foc * 0.5, C.Track, C.C50))
        self:DrawTextEntryText(color_white, C.Select, color_white)
        if self:GetText() == "" and not self:IsEditing() then
            if multiline then
                draw.SimpleText(ph, font, 8, 6, C.Dim, TL, TT)
            else
                draw.SimpleText(ph, font, 8, phh / 2, C.Dim, TL, TC)
            end
        end
    end
    return e
end

local function createModal(parent, w, h, title)
    if isstring(title) then title = L(title) end

    local bg = vgui.Create("DPanel", parent)
    bg:SetPos(0, 0)
    bg:SetSize(parent:GetWide(), parent:GetTall())
    bg:SetKeyboardInputEnabled(true)
    bg:SetAlpha(0)
    bg:AlphaTo(255, 0.12, 0)
    bg.Paint = function(self, pw, ph)
        drawBlur(self, 2)
        surface.SetDrawColor(0, 0, 0, 90)
        surface.DrawRect(0, 0, pw, ph)
    end
    bg.Cancel = function(self) self:Remove() end

    local frame = vgui.Create("DPanel", bg)
    frame:SetSize(w, h)
    frame:Center()
    frame.Paint = function(self, pw, ph)
        draw.RoundedBox(12, 0, 0, pw, ph, C.Bg)
        surface.SetDrawColor(C.Yellow)
        surface.DrawRect(0, 36 - 1, pw, 1)
        draw.SimpleText(fitText(title or "", "Trebuchet24", pw - 64), "Trebuchet24", 16, 36 / 2, C.Yellow, TL, TC)
        if self.PaintExtra then self:PaintExtra(pw, ph) end
        btb.drawRoundedOutline(12, 0, 0, pw, ph, 1, C.Yellow)
    end

    bg.OnKeyCodePressed = function(self, key)
        if key == KEY_ESCAPE then
            gui.HideGameUI()
            self:Cancel()
            return
        end
        local focus = vgui.GetKeyboardFocus()
        if IsValid(focus) and isfunction(focus.IsEditing) and focus:IsEditing() then return end
        if self.onKey then self.onKey(key) end
    end
    bg:RequestFocus()

    return bg, frame
end

local function notify(text, kind, sound)
    notification.AddLegacy(text, kind or NOTIFY_GENERIC, 3)
    if sound then surface.PlaySound(sound) end
end

-- from my roblox chat bubbles addon
local function wrapText(text, font, maxWidth)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines = {}
    local currentLine = ""
    for i = 1, #words do
        local word = words[i]
        ::retry_word::
        local testLine = currentLine .. (currentLine == "" and "" or " ") .. word
        local w = surface.GetTextSize(testLine)
        if w > maxWidth then
            if currentLine == "" then
                for j = 1, #word do
                    local substr = string.sub(word, 1, j)
                    local sw = surface.GetTextSize(substr)
                    if sw > maxWidth then
                        local cut = j > 1 and string.sub(word, 1, j - 1) or string.sub(word, 1, 1)
                        word = j > 1 and string.sub(word, j) or string.sub(word, 2)
                        table.insert(lines, cut)
                        goto retry_word
                    end
                end
                currentLine = word
            else
                table.insert(lines, currentLine)
                currentLine = ""
                goto retry_word
            end
        else
            currentLine = testLine
        end
    end
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    return lines
end

-- wrapText that also respects explicit line breaks
local function wrapMulti(text, font, maxWidth)
    local out = {}
    for _, para in ipairs(string.Explode("\n", text)) do
        local lines = wrapText(para, font, maxWidth)
        if #lines == 0 then lines = { "" } end
        for _, l in ipairs(lines) do out[#out + 1] = l end
    end
    return out
end

--MARK: Import frame
local function openImportDialog(frame)
    local bg, box = createModal(frame, 520, 416, "#btb.ps.button_import")
    local timerName = "BTB_ImportDecodeTimer"
    local state = { data = nil, missing = {}, invalid = false }

    local codeBox = makeEntry(box, 16, 48, 488, 84, "#btb.playlist.import.code", "BattleBeats_Checkbox_Font", true)
    local nameBox = makeEntry(box, 16, 142, 488, 30, "#btb.playlist.create.enter_name", "BattleBeats_Font")
    nameBox:SetMaximumCharCount(30)
    btb.importBox = codeBox
    btb.plNameBox = nameBox

    local function nameTaken()
        local n = string.Trim(nameBox:GetValue() or "")
        if n == "" then return false end
        return (btb.musicPacks and btb.musicPacks[n]) ~= nil or (btb.musicPlaylists and btb.musicPlaylists[n]) ~= nil
    end

    nameBox.PaintOver = function(self, w, h)
        if not nameTaken() then return end
        btb.drawRoundedOutline(6, 0, 0, w, h, 1, C.Warn)
        draw.SimpleText(fitText(L("btb.playlist.create.name_error"), "DermaDefault", w / 2), "DermaDefault", w - 8, h / 2, C.Warn, TR, TC)
    end

    local card = makeCard(box, 16, 180, 488, 168)
    card.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.Card)
        if state.invalid then
            draw.SimpleText(L("btb.playlist.import.invalid_code"), "DermaDefaultBold", 14, 12, C.Warn, TL, TT)
        elseif not state.data then
            draw.SimpleText("No data loaded", "DermaDefaultBold", 14, 12, C.Dim, TL, TT)
        else
            local info = "Ambient: " .. #(state.data.ambient or {}) .. "   ·   Combat: " .. #(state.data.combat or {})
            draw.SimpleText(info, "DermaDefaultBold", 14, 12, color_white, TL, TT)
            if #state.missing > 0 then
                draw.SimpleText(L("btb.playlist.import.missing_tracks") .. ": " .. #state.missing, "DermaDefaultBold", w - 14, 12, C.Warn, TR, TT)
            else
                draw.SimpleText(L("btb.playlist.import.all_good"), "DermaDefaultBold", w - 14, 12, C.Good, TR, TT)
            end
        end
    end

    local missScroll = makeScroll(card)
    missScroll:SetPos(8, 36)
    missScroll:SetSize(472, 124)

    local function rebuildMissing()
        missScroll:Clear()
        for _, p in ipairs(state.missing) do
            local row = vgui.Create("DPanel", missScroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 2)
            row:SetTall(22)
            row:SetTooltip(p)
            row:SetTooltipPanelOverride("BattleBeatsTooltip")
            row.Paint = function(self, w, h)
                draw.RoundedBox(5, 0, 0, w, h, C.Missing)
                draw.SimpleText(fitText(p, "DermaDefault", w - 16), "DermaDefault", 8, h / 2, C.Warn, TL, TC)
            end
        end
    end

    local function decode()
        local text = string.Trim(codeBox:GetValue() or "")
        state.data, state.missing, state.invalid = nil, {}, false
        if text == "" then
            rebuildMissing()
            return
        end
        local data = btb.importPlaylist(text)
        if not data then
            state.invalid = true
            rebuildMissing()
            return
        end
        state.data = data
        local function check(list)
            for _, track in ipairs(list or {}) do
                if not file.Exists(track.path, "GAME") then
                    table.insert(state.missing, track.path)
                end
            end
        end
        check(data.ambient)
        check(data.combat)
        rebuildMissing()
    end

    codeBox.OnChange = function()
        timer.Remove(timerName)
        timer.Create(timerName, 0.3, 1, function()
            if IsValid(box) then decode() end
        end)
    end

    local function doImport(keepMissing)
        local data = state.data
        if not data then return end
        local name = string.Trim(nameBox:GetValue() or "")
        if name == "" then
            notify("#btb.playlist.create.enter_name_error", NOTIFY_ERROR, "buttons/button11.wav")
            nameBox:RequestFocus()
            return
        end
        if nameTaken() then
            notify("#btb.playlist.create.name_error", NOTIFY_ERROR, "buttons/button11.wav")
            nameBox:RequestFocus()
            return
        end

        local imported = table.Copy(data)
        if not keepMissing then
            local function filter(list)
                local new = {}
                for _, track in ipairs(list or {}) do
                    if file.Exists(track.path, "GAME") then new[#new + 1] = track end
                end
                return new
            end
            imported.ambient = filter(imported.ambient)
            imported.combat = filter(imported.combat)
        end
        if #(imported.ambient or {}) + #(imported.combat or {}) == 0 then
            notify("#btb.playlist.create.tracks_error", NOTIFY_ERROR, "buttons/button11.wav")
            return
        end

        notify("#btb.playlist.import.succ", NOTIFY_GENERIC, "buttons/button3.wav")
        btb.musicPlaylists[name] = imported
        btb.validateAndTransformPlaylist(name, imported)
        btb.savePlaylists()
        bg:Remove()
        if isfunction(RefreshList) then RefreshList() end
    end

    makeButton(box, 16, 364, 170, 34, L("btb.ps.button_import_clean"), function() doImport(false) end, {
        enabled = function() return state.data ~= nil end,
        tip = "#btb.ps.button_import_clean_tip"
    })
    makeButton(box, 194, 364, 170, 34, L("btb.ps.button_import_keep"), function() doImport(true) end, {
        enabled = function() return state.data ~= nil and #state.missing > 0 end,
        tip = "#btb.ps.button_import_keep_tip"
    })
    makeButton(box, 372, 364, 132, 34, L("btb.main.volume_cancel"), function() bg:Remove() end)

    nameBox.OnEnter = function() doImport(false) end

    bg.OnRemove = function()
        timer.Remove(timerName)
    end

    codeBox:RequestFocus()
    return bg
end

function btb.openImportFrame(frame)
    local bg, box = createModal(frame, 420, 220, "Add playlist")

    makeButton(box, 16, 52, 388, 70, L("btb.ps.button_create"), function()
        bg:Remove()
        btb.openPlaylistEditor(nil, function()
            if isfunction(RefreshList) then RefreshList() end
        end)
    end, { font = "BattleBeats_Font" })

    makeButton(box, 16, 134, 388, 70, L("btb.ps.button_import"), function()
        bg:Remove()
        openImportDialog(frame)
    end, { font = "BattleBeats_Font" })

    return box
end

--MARK: Volume edit
function btb.openVolumeEditor(panel, track, pack, func)
    local bg, box = createModal(panel, 440, 252, "Volume Boost")

    local subject = ""
    if track then
        subject = btb.getTrackData(track).alias or btb.FormatTrackName(track)
    elseif pack then
        subject = btb.stripPackPrefix(L(pack))
    end

    local value = 100
    if track then
        value = btb.getTrackData(track).vol or 100
    elseif pack then
        value = (btb.packVolume or {})[pack] or 100
    end
    local original = value

    local function refreshLive()
        local main = IsValid(btb.currentStation) and btb.currentStation or nil
        local prev = (not main and IsValid(btb.currentPreviewStation)) and btb.currentPreviewStation or nil
        local st = main or prev
        if not st then return end
        local sName = st:GetFileName()
        if not sName then return end
        if track then
            if sName ~= track then return end
        elseif btb.getTrackData(sName, true).pack ~= pack then
            return
        end
        if main then
            st:SetVolume(btb.adjustVolume(sName))
        else
            st:SetVolume(btb.adjustVolume(sName, nil, true))
        end
    end

    local function applyValue(v)
        local nv = math.Clamp(math.floor(v), 0, 200)
        if nv == value then return end
        value = nv
        if track then
            btb.setTrackData(track, "vol", value ~= 100 and value or nil)
        elseif pack then
            btb.packVolume = btb.packVolume or {}
            btb.packVolume[pack] = value ~= 100 and value or nil
        else
            return
        end
        refreshLive()
    end

    local function snap(v)
        if math.abs(v - 100) <= 5 then return 100 end
        return v
    end

    local function step(d)
        applyValue(value + d * (isShift() and 10 or 1))
    end

    local barX, barW, pad = 44, 352, 9
    box.PaintExtra = function(self, w, h)
        draw.SimpleText(fitText(subject, "DermaDefault", w - 40), "DermaDefault", w / 2, 52, C.Dim, TC, TC)
        local off = value - 100
        local txt = off == 0 and "0%" or (off > 0 and ("+" .. off .. "%") or (off .. "%"))
        local col = off > 0 and C.Yellow or (off < 0 and C.Cut or color_white)
        draw.SimpleText(txt, "Trebuchet24", w / 2, 78, col, TC, TC)
        draw.SimpleText("-100%", "DermaDefault", barX + pad, 134, C.Dim, TL, TC)
        draw.SimpleText("0%", "DermaDefault", barX + barW / 2, 134, C.Dim, TC, TC)
        draw.SimpleText("+100%", "DermaDefault", barX + barW - pad, 134, C.Dim, TR, TC)
    end

    local bar = vgui.Create("DPanel", box)
    bar:SetPos(barX, 100)
    bar:SetSize(barW, 28)
    bar:SetCursor("hand")

    local function barPos(w, v) return pad + (w - pad * 2) * (v / 200) end

    bar.Paint = function(self, w, h)
        local ty = h / 2 - 4
        draw.RoundedBox(4, pad, ty, w - pad * 2, 8, C.Track)
        local center = w / 2
        local pos = barPos(w, value)
        local col = value >= 100 and C.Yellow or C.Cut
        if pos >= center then
            draw.RoundedBox(0, center, ty, pos - center, 8, col)
        else
            draw.RoundedBox(0, pos, ty, center - pos, 8, col)
        end
        surface.SetDrawColor(255, 255, 255, 140)
        surface.DrawRect(center - 1, ty - 4, 2, 16)
        local hov = animHover(self, "Hov", self:IsHovered() or self.dragging)
        local r = 7 + hov * 2
        draw.RoundedBox(r, pos - r, h / 2 - r, r * 2, r * 2, color_white)
    end

    local function updateFromCursor(self)
        local x = self:CursorPos()
        local w = self:GetWide()
        local progress = math.Clamp((x - pad) / (w - pad * 2), 0, 1)
        local nv = progress * 200
        if not isCtrl() then nv = snap(nv) end
        applyValue(nv)
    end

    bar.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self.dragging = true
        self:MouseCapture(true)
        updateFromCursor(self)
    end
    bar.OnMouseReleased = function(self)
        self.dragging = false
        self:MouseCapture(false)
    end
    bar.Think = function(self)
        if not self.dragging then return end
        if not input.IsMouseDown(MOUSE_LEFT) then
            self.dragging = false
            self:MouseCapture(false)
            return
        end
        updateFromCursor(self)
    end
    bar.OnMouseWheeled = function(self, delta) applyValue(value + delta * (isShift() and 5 or 1)) end
    bg.OnMouseWheeled = bar.OnMouseWheeled

    makeButton(box, 10, 100, 28, 28, "<", function() step(-1) end, { tip = "-1% (Shift: -10%)" })
    makeButton(box, 402, 100, 28, 28, ">", function() step(1) end, { tip = "+1% (Shift: +10%)" })

    local warning = vgui.Create("DLabel", box)
    warning:SetFont("DermaDefault")
    warning:SetTextColor(Color(255, 200, 120))
    warning:SetPos(20, 152)
    warning:SetSize(400, 36)
    warning:SetWrap(true)
    warning:SetText("Volume boost multiplies final volume. Raising base volume makes the boost stronger (e.g 2x can become 4x)")

    local function cancel()
        applyValue(original)
        bg:Remove()
    end
    bg.Cancel = cancel

    makeButton(box, 20, 204, 110, 32, "Reset", function() applyValue(100) end, {
        enabled = function() return value ~= 100 end,
        tip = "Back to 0%"
    })
    makeButton(box, 200, 204, 100, 32, L("btb.main.volume_cancel"), cancel)
    makeButton(box, 310, 204, 110, 32, L("btb.ps.ts.rmb.assign_save"), function() bg:Remove() end)

    bg.onKey = function(key)
        if key == KEY_LEFT then
            step(-1)
        elseif key == KEY_RIGHT then
            step(1)
        elseif key == KEY_ENTER or key == KEY_PAD_ENTER then
            bg:Remove()
        end
    end

    bg.OnRemove = function()
        if isfunction(func) then func() end
        if not track then btb.savePackVolumes() end
    end
end

--MARK: Track trim
function btb.openTrimEditor(panel, track, func)
    local minTrim = 30
    local trackLength = 0
    local trimData = btb.getTrackData(track).trim or {}
    local state = "loading"
    local slider

    local title = L("btb.ps.ts.rmb.trim_title") .. ": " .. btb.FormatTrackName(track)
    local bg, box = createModal(panel, 560, 234, title)

    box.PaintExtra = function(self, w, h)
        if state ~= "ok" then
            if state == "loading" then
                draw.SimpleText("Loading track data...", "BattleBeats_Checkbox_Font", w / 2, 95, C.Dim, TC, TC)
            elseif state == "error" then
                draw.SimpleText("There was an error with getting track data!", "BattleBeats_Checkbox_Font", w / 2, 95, C.Warn, TC, TC)
            else
                draw.SimpleText("Cannot trim track because it's too short!", "BattleBeats_Checkbox_Font", w / 2, 88, color_white, TC, TC)
                draw.SimpleText("(track needs to be at least 30 seconds long)", "BattleBeats_Checkbox_Font", w / 2, 108, C.Dim, TC, TC)
            end
            return
        end
        local s, e = slider.startValue, slider.endValue
        draw.SimpleText("Start  " .. btb.FormatTime(s), "DermaDefaultBold", 24, 114, C.Start, TL, TC)
        draw.SimpleText("Selected  " .. btb.FormatTime(e - s) .. "  /  " .. btb.FormatTime(trackLength), "DermaDefaultBold", w / 2, 114, color_white, TC, TC)
        draw.SimpleText("End  " .. btb.FormatTime(e), "DermaDefaultBold", w - 24, 114, C.End, TR, TC)
    end

    local pad = 8
    slider = vgui.Create("DPanel", box)
    slider:SetPos(24, 62)
    slider:SetSize(512, 32)
    slider:SetVisible(false)
    slider:SetCursor("hand")
    slider.startValue, slider.endValue = 0, 0

    local function toPos(w, v) return pad + (w - pad * 2) * (v / math.max(trackLength, 1)) end
    local function fromPos(w, x) return ((x - pad) / (w - pad * 2)) * trackLength end

    slider.Paint = function(self, w, h)
        if state ~= "ok" then slider:SetCursor("arrow") return end
        if trackLength <= 0 then return end
        local ty = h / 2 - 5
        draw.RoundedBox(5, pad, ty, w - pad * 2, 10, C.Track)
        local sp, ep = toPos(w, self.startValue), toPos(w, self.endValue)
        draw.RoundedBox(3, sp, ty, ep - sp, 10, ColA(C.Yellow, 200))
        local hov = animHover(self, "Hov", self:IsHovered() or self.dragging ~= nil)
        local hw = 8 + hov * 2
        draw.RoundedBox(4, sp - hw / 2, 2, hw, h - 4, C.Start)
        draw.RoundedBox(4, ep - hw / 2, 2, hw, h - 4, C.End)
    end

    local function updateDrag(self)
        local x = self:CursorPos()
        local v = math.Round(math.Clamp(fromPos(self:GetWide(), x), 0, trackLength))
        if self.dragging == "start" then
            self.startValue = math.Clamp(v, 0, self.endValue - minTrim)
        elseif self.dragging == "end" then
            self.endValue = math.Clamp(v, self.startValue + minTrim, trackLength)
        end
    end

    slider.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT or trackLength <= 0 then return end
        local x = self:CursorPos()
        local w = self:GetWide()
        local sp, ep = toPos(w, self.startValue), toPos(w, self.endValue)
        self.dragging = math.abs(x - sp) < math.abs(x - ep) and "start" or "end"
        self:MouseCapture(true)
        updateDrag(self)
    end
    slider.OnMouseReleased = function(self)
        self.dragging = nil
        self:MouseCapture(false)
    end
    slider.Think = function(self)
        if not self.dragging then return end
        if not input.IsMouseDown(MOUSE_LEFT) then
            self.dragging = nil
            self:MouseCapture(false)
            return
        end
        updateDrag(self)
    end

    local function nudge(which, d)
        if state ~= "ok" then return end
        local stepv = (isShift() and 10 or 1) * d
        if which == "start" then
            slider.startValue = math.Clamp(slider.startValue + stepv, 0, slider.endValue - minTrim)
        else
            slider.endValue = math.Clamp(slider.endValue + stepv, slider.startValue + minTrim, trackLength)
        end
    end

    local function ok() return state == "ok" end
    makeButton(box, 24, 138, 80, 28, "Start -1s", function() nudge("start", -1) end, { enabled = ok, tip = "Shift: 10s" })
    makeButton(box, 108, 138, 80, 28, "Start +1s", function() nudge("start", 1) end, { enabled = ok, tip = "Shift: 10s" })
    makeButton(box, 240, 138, 80, 28, "Reset", function()
        slider.startValue, slider.endValue = 0, trackLength
    end, { enabled = ok, accent = C.Warn, tip = "Remove trim" })
    makeButton(box, 372, 138, 80, 28, "End -1s", function() nudge("end", -1) end, { enabled = ok, tip = "Shift: 10s" })
    makeButton(box, 456, 138, 80, 28, "End +1s", function() nudge("end", 1) end, { enabled = ok, tip = "Shift: 10s" })

    local function save()
        if state ~= "ok" then return end
        if slider.endValue - slider.startValue < minTrim then
            notify("Track must be at least 30 seconds", NOTIFY_ERROR)
            return
        end

        local startVal = math.floor(slider.startValue)
        local endVal = math.floor(slider.endValue)

        local trim = {}
        if startVal > 0 then trim.start = startVal end
        if endVal < trackLength then trim.finish = endVal end

        if next(trim) == nil then
            btb.setTrackData(track, "trim", nil)
            notify("Trim removed")
        else
            btb.setTrackData(track, "trim", trim)
            notify("Trim set: " .. startVal .. "s - " .. endVal .. "s")
        end

        if isfunction(func) then func() end

        surface.PlaySound("buttons/button14.wav")
        bg:Remove()
    end

    makeButton(box, 125, 186, 150, 32, L("btb.ps.ts.rmb.assign_save"), save, { enabled = ok, tip = "Enter" })
    makeButton(box, 285, 186, 150, 32, L("btb.main.volume_cancel"), function() bg:Remove() end)

    bg.onKey = function(key)
        if key == KEY_ENTER or key == KEY_PAD_ENTER then save() end
    end

    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if not IsValid(box) then
            if IsValid(station) then station:Stop() end
            return
        end
        if errCode or errStr or not IsValid(station) then
            state = "error"
            return
        end
        trackLength = math.floor(station:GetLength())
        station:Stop()
        if trackLength <= minTrim then
            state = "short"
            return
        end
        slider.startValue = math.Clamp(trimData.start or 0, 0, trackLength - minTrim)
        slider.endValue = math.Clamp(trimData.finish or trackLength, slider.startValue + minTrim, trackLength)
        slider:SetVisible(true)
        state = "ok"
    end)
end

--MARK:NPC assign
local function getIcon(npc)
    local candidates = { npc.id, npc.class, npc.name and string.lower(string.Replace(npc.name, " ", "_")) or nil }
    if npc.data and npc.data.Model then
        local modelName = string.GetFileFromFilename(npc.data.Model or "")
        modelName = string.StripExtension(modelName or "")
        if modelName and modelName ~= "" then
            table.insert(candidates, modelName)
        end
    end
    for _, candidate in ipairs(candidates) do
        if isstring(candidate) and candidate ~= "" then
            if file.Exists("materials/entities/" .. candidate .. ".png", "GAME") then
                return "entities/" .. candidate .. ".png"
            end
            if file.Exists("materials/entities/" .. candidate .. ".vmt", "GAME") then
                return "entities/" .. candidate
            end
            if file.Exists("materials/vgui/entities/" .. candidate .. ".png", "GAME") then
                return "vgui/entities/" .. candidate .. ".png"
            end
            if file.Exists("materials/vgui/entities/" .. candidate .. ".vtf", "GAME") then
                return "vgui/entities/" .. candidate
            end
            if file.Exists("materials/vgui/entities/" .. candidate .. ".vmt", "GAME") then
                return "vgui/entities/" .. candidate
            end
        end
    end
    return "btbna.jpg"
end

local NPCAssignCache = { list = nil, icons = {}, wrappedText = {} }
local NPCBlacklist = {
    npc_crow = true,
    npc_pigeon = true,
    npc_seagull = true,
    nb_example = true,
    npc_monk = true,
    npc_stalker = true,
    npc_antlion_grub = true,
    npc_alyx = true,
    npc_barney = true,
    npc_breen = true,
    npc_citizen = true,
    Medic = true,
    Rebel = true,
    Refugee = true,
    npc_dog = true,
    npc_eli = true,
    npc_fisherman = true,
    npc_gman = true,
    npc_kleiner = true,
    npc_magnusson = true,
    npc_mossman = true,
    npc_odessa = true,
    npc_rollermine_hacked = true,
    npc_turret_floor_resistance = true,
    npc_vortigaunt = true,
    VortigauntSlave = true,
    VortigauntUriah = true,
    --VJ BASE exclusive
    npc_vj_test_aerial = true,
    npc_vj_test_interactive = true,
    npc_vj_test_player = true,
}

local function getCachedIcon(npc)
    local key = npc.id or npc.class
    if NPCAssignCache.icons[key] then
        return NPCAssignCache.icons[key]
    end
    local icon = getIcon(npc)
    NPCAssignCache.icons[key] = icon
    return icon
end

local function getCachedNPCList()
    if NPCAssignCache.list then
        return NPCAssignCache.list
    end
    local npcList = {}
    for listClass, npcData in SortedPairsByMemberValue(list.Get("NPC"), "Name") do
        local class = npcData.Class or npcData.class or listClass
        if isstring(class) and class ~= "" and not NPCBlacklist[class] and not NPCBlacklist[listClass] then
            table.insert(npcList, {
                id = listClass,
                class = class,
                name = npcData.Name or npcData.PrintName or listClass,
                category = npcData.Category or "Other",
                data = npcData
            })
        end
    end
    NPCAssignCache.list = npcList
    return npcList
end

local function getCachedWrappedText(text, font, maxWidth)
    local key = text .. "|" .. font .. "|" .. maxWidth
    if NPCAssignCache.wrappedText[key] then
        return NPCAssignCache.wrappedText[key]
    end
    local lines = wrapText(text, font, maxWidth)
    NPCAssignCache.wrappedText[key] = lines
    return lines
end

function btb.createAssignFrame(panel, title, defaultClass, defaultPriority, onSave)
    local priority = math.Clamp(tonumber(defaultPriority) or 1, 1, 5)
    local curID = string.Trim(string.lower(defaultClass or ""))
    local shown = 0
    local npcTiles = {}
    local textEntry, searchEntry

    local bg, frame = createModal(panel, 640, 560, title)
    local searchDebounceName = "BTB_AssignNPCSearchDebounce_" .. tostring(frame)

    frame.PaintExtra = function(self, w, h)
        draw.SimpleText(
        L("btb.ps.ts.rmb.assign_priority") ~= "btb.ps.ts.rmb.assign_priority" and L("btb.ps.ts.rmb.assign_priority") or
        "Priority", "DermaDefaultBold", 430, 60, C.Dim, TR, TC)
        draw.SimpleText(shown .. " / " .. #npcTiles .. " NPCs", "DermaDefault", 18, 126, C.Dim, TL, TC)
        draw.SimpleText("Double-click a tile to save", "DermaDefault", w - 18, 126, C.Dim, TR, TC)
    end

    textEntry = makeEntry(frame, 16, 46, 330, 28, "#btb.ps.ts.rmb.assign_enter_class", "BattleBeats_Checkbox_Font")
    textEntry:SetText(defaultClass or "")
    textEntry.OnChange = function(self)
        curID = string.Trim(string.lower(self:GetText() or ""))
    end

    local helpBtn = vgui.Create("DImage", frame)
    helpBtn:SetPos(354, 52)
    helpBtn:SetSize(16, 16)
    helpBtn:SetImage("icon16/help.png")
    helpBtn:SetMouseInputEnabled(true)
    helpBtn:BTB_SetImageTooltip("assignhelp.png", "#btb.ps.ts.rmb.assign_img_tip")

    -- priority selector (1 = highest, 5 = lowest)
    for i = 1, 5 do
        local tip
        if i == 1 then
            tip = "1 " .. L("btb.ps.ts.rmb.assign_priority_highest")
        elseif i == 5 then
            tip = "5 " .. L("btb.ps.ts.rmb.assign_priority_lowest")
        end
        makeButton(frame, 438 + (i - 1) * 38, 46, 34, 28, tostring(i), function() priority = i end, {
            active = function() return priority == i end,
            tip = tip
        })
    end

    local scroll = makeScroll(frame)
    scroll:SetPos(16, 140)
    scroll:SetSize(608, 366)

    local iconLayout = vgui.Create("DIconLayout", scroll)
    iconLayout:Dock(TOP)
    iconLayout:SetWide(scroll:GetWide() - 8)
    iconLayout:SetSpaceX(10)
    iconLayout:SetSpaceY(10)

    local function createNPCTile(npc)
        local tile = iconLayout:Add("DButton")
        tile:SetSize(138, 146)
        tile:SetText("")
        tile.NPCIDLower = string.lower(tostring(npc.id))
        tile.SearchText = string.lower(L(tostring(npc.name)) ..
        " " .. tostring(npc.id) .. " " .. tostring(npc.class) .. " " .. L(tostring(npc.category)))
        tile.Paint = function(self, w, h)
            local hov = animHover(self, "Hov", self:IsHovered())
            local selected = curID ~= "" and self.NPCIDLower == curID
            local sel = Lerp(FrameTime() * 14, self.SelAnim or (selected and 1 or 0), selected and 1 or 0)
            self.SelAnim = sel
            draw.RoundedBox(8, 0, 0, w, h, LerpColor(sel, LerpColor(hov, C.Card, C.C90), C.Yellow))
            draw.RoundedBox(7, 1, 1, w - 2, h - 2, LerpColor(sel * 0.25, LerpColor(hov, C.CardIn, C.C70), C.Yellow))
        end
        tile:SetTooltip("|Name:| " .. L(npc.name or "N/A") .. "\n|Category:| " .. L(npc.category or "N/A") .. "\n|Class:| " .. npc.class .. "\n|Key:| ||" .. npc.id .. "<255,255,255>||")
        tile:SetTooltipPanelOverride("BattleBeatsTooltip")

        local icon = vgui.Create("DImage", tile)
        icon:SetPos(24, 8)
        icon:SetSize(90, 90)
        icon:SetImage(getCachedIcon(npc))
        icon:SetKeepAspect(true)
        icon:SetMouseInputEnabled(false)

        local nameLabel = vgui.Create("DPanel", tile)
        nameLabel:SetPos(4, 102)
        nameLabel:SetSize(130, 38)
        nameLabel:SetMouseInputEnabled(false)
        local lines = getCachedWrappedText(L(npc.name or "N/A"), "CreditsText", 130)
        if #lines > 2 then lines = { lines[1], lines[2] .. "…" } end
        nameLabel.Paint = function(self, w, h)
            local lineH = 16
            local totalH = #lines * lineH
            local startY = (h - totalH) / 2
            for i, line in ipairs(lines) do
                draw.SimpleText(line, "CreditsText", w / 2, startY + (i - 1) * lineH + lineH / 2, color_white, TC, TC)
            end
        end

        local function select()
            textEntry:SetText(npc.id)
            curID = tile.NPCIDLower
            textEntry:RequestFocus()
            textEntry:SetCaretPos(#npc.id)
        end
        tile.DoClick = function()
            select()
            surface.PlaySound("ui/buttonclickrelease.wav")
        end
        tile.DoDoubleClick = function()
            select()
            onSave(string.Trim(textEntry:GetText() or ""), math.Clamp(priority, 1, 5), bg)
        end

        npcTiles[#npcTiles + 1] = tile
    end

    local function filterNPCTiles(filter)
        filter = string.Trim(string.lower(filter or ""))
        shown = 0
        for _, tile in ipairs(npcTiles) do
            if IsValid(tile) then
                local visible = filter == "" or string.find(tile.SearchText or "", filter, 1, true) ~= nil
                tile:SetVisible(visible)
                if visible then shown = shown + 1 end
            end
        end
        iconLayout:InvalidateLayout(true)
        timer.Simple(0, function()
            if not IsValid(iconLayout) or not IsValid(scroll) then return end
            iconLayout:Layout()
            iconLayout:InvalidateLayout(true)
            scroll:InvalidateLayout(true)
            local canvas = scroll:GetCanvas()
            if IsValid(canvas) then
                canvas:InvalidateLayout(true)
            end
        end)
    end

    for _, npc in ipairs(getCachedNPCList()) do
        createNPCTile(npc)
    end
    filterNPCTiles("")

    scroll.PaintOver = function(self, w, h)
        if shown == 0 then
            draw.SimpleText("No NPCs found", "Trebuchet18", w / 2, h / 2, C.Dim, TC, TC)
        end
    end

    searchEntry = makeSearch(frame, 16, 84, 608, 28, "Search NPC (name, class, category)...", function(v)
        timer.Remove(searchDebounceName)
        timer.Create(searchDebounceName, 0.08, 1, function()
            if IsValid(frame) then filterNPCTiles(v) end
        end)
    end, "DermaDefault")

    if curID ~= "" then
        timer.Simple(0.1, function()
            if not IsValid(scroll) then return end
            for _, tile in ipairs(npcTiles) do
                if IsValid(tile) and tile.NPCIDLower == curID then
                    scroll:ScrollToChild(tile)
                    break
                end
            end
        end)
    end

    local function doSave()
        onSave(string.Trim(textEntry:GetText() or ""), math.Clamp(priority, 1, 5), bg)
    end
    textEntry.OnEnter = doSave

    makeButton(frame, 165, 518, 150, 30, L("btb.ps.ts.rmb.assign_save"), doSave, { tip = "Enter" })
    makeButton(frame, 325, 518, 150, 30, L("btb.main.volume_cancel"), function()
        bg:Cancel()
    end)

    bg.Cancel = function(self)
        timer.Remove(searchDebounceName)
        self:Remove()
    end
    bg.OnRemove = function()
        timer.Remove(searchDebounceName)
    end

    if IsValid(searchEntry) then searchEntry:RequestFocus() end
    return textEntry, searchEntry
end

--MARK: Rename track
function btb.changeName(panel, track, func)
    local tname = btb.FormatTrackName(track)
    local td = btb.getTrackData(track)
    local currentAlias = td.alias or tname

    local bg, box = createModal(panel, 440, 170, "#btb.ps.ts.rmb.set_name_title")

    local entry = makeEntry(box, 16, 48, 408, 36, tname, "BattleBeats_Font")
    entry:SetMaximumCharCount(56)
    entry:SetText(currentAlias)

    box.PaintExtra = function(self, w, h)
        local text = entry:GetValue() or ""
        local cur = string.Trim(text)
        if cur ~= "" and cur ~= tname then
            draw.SimpleText(fitText("Original: " .. tname, "DermaDefault", w - 110), "DermaDefault", 18, 98, C.Dim, TL, TC)
        end
        draw.SimpleText((utf8.len(text) or #text) .. "/" .. 56, "DermaDefault", w - 18, 98, C.Dim, TR, TC)
    end

    local function saveAlias()
        local text = string.Trim(entry:GetValue() or "")
        if text == tname or text == "" then
            btb.setTrackData(track, "alias", nil)
        else
            btb.setTrackData(track, "alias", text)
        end
        if isfunction(func) then func() end
        bg:Remove()
    end

    entry.OnEnter = saveAlias

    makeButton(box, 16, 118, 100, 32, "Reset", function()
        entry:SetText(tname)
        entry:RequestFocus()
        entry:SetCaretPos(#tname)
    end, {
        enabled = function() return string.Trim(entry:GetValue() or "") ~= tname end,
        tip = "Restore the original track name"
    })
    makeButton(box, 216, 118, 100, 32, L("btb.ps.ts.rmb.assign_save"), saveAlias, { tip = "Enter" })
    makeButton(box, 324, 118, 100, 32, L("btb.main.volume_cancel"), function() bg:Remove() end)

    entry:RequestFocus()
    entry:SelectAllText()
    return entry
end

--MARK:Subtitles
function btb.openSubtitles(panel, trackName, subs)
    subs = subs or {}
    local query = ""
    local lineCount = 0

    local title = L("#btb.ps.ts.rmb.show_lyrics_title") .. trackName
    local bg, box = createModal(panel, 540, 520, title)

    box.PaintExtra = function(self, w, h)
        local info = lineCount .. " / " .. #subs .. " lines"
        draw.SimpleText(info, "DermaDefault", 18, 86, C.Dim, TL, TC)
        draw.SimpleText("Click a line to copy it", "DermaDefault", w - 18, 86, C.Dim, TR, TC)
    end

    local scroll = makeScroll(box)
    scroll:SetPos(16, 98)
    scroll:SetSize(508, 372)
    scroll.PaintOver = function(self, w, h)
        if lineCount == 0 then
            draw.SimpleText(#subs == 0 and "No subtitles" or "No matches", "Trebuchet18", w / 2, h / 2, C.Dim, TC, TC)
        end
    end

    local function stamp(t)
        return string.format("[%02d:%02d]", math.floor(t / 60), math.floor(t % 60))
    end
    local function matches(sub)
        return query == "" or string.find(string.lower(tostring(sub.text or "")), query, 1, true) ~= nil
    end

    local function rebuild()
        scroll:Clear()
        lineCount = 0
        local lastEnd = 0
        for _, sub in ipairs(subs) do
            if matches(sub) then
                lineCount = lineCount + 1
                local text = tostring(sub.text or "")
                local lines = wrapMulti(text, "ChatFont", 428)
                local ts = stamp(sub.start or 0)
                local gap = (query == "" and lastEnd > 0 and ((sub.start or 0) - lastEnd) > 5) and 10 or 0

                local row = vgui.Create("DButton", scroll)
                row:Dock(TOP)
                row:DockMargin(0, gap, 0, 2)
                row:SetTall(#lines * 16 + 8)
                row:SetText("")
                row:SetCursor("hand")
                row.Paint = function(self, w, h)
                    local hov = animHover(self, "Hov", self:IsHovered())
                    draw.RoundedBox(6, 0, 0, w, h, LerpColor(hov, C.Card, C.C70))
                    draw.SimpleText(ts, "DermaDefaultBold", 8, 4, C.Yellow, TL, TT)
                    for i, line in ipairs(lines) do
                        draw.SimpleText(line, "ChatFont", 62, 4 + (i - 1) * 16, color_white, TL, TT)
                    end
                end
                row.DoClick = function()
                    SetClipboardText(text)
                    notify("Line copied", NOTIFY_GENERIC)
                end
            end
            lastEnd = sub['end'] or sub.start or lastEnd
        end
        scroll:GetCanvas():InvalidateLayout(true)
        scroll:InvalidateLayout(true)
    end

    makeSearch(box, 16, 46, 508, 28, "Search lyrics...", function(v)
        query = string.lower(string.Trim(v or ""))
        rebuild()
    end, "DermaDefault")

    makeButton(box, 140, 480, 120, 30, "Copy all", function()
        local out = {}
        local withTime = isShift()
        for _, sub in ipairs(subs) do
            if matches(sub) then
                local text = tostring(sub.text or "")
                out[#out + 1] = withTime and (stamp(sub.start or 0) .. " " .. text) or text
            end
        end
        SetClipboardText(table.concat(out, "\n"))
        notify("Copied " .. #out .. " lines")
    end, { tip = "Copy shown lines (Shift: with timestamps)" })
    makeButton(box, 280, 480, 120, 30, L("btb.main.volume_cancel"), function() bg:Remove() end)

    rebuild()
end
