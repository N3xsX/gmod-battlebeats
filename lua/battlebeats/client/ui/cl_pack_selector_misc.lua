local c909090 = Color(90, 90, 90)
local c000200 = Color(0, 0, 0, 200)
local c200200200 = Color(200, 200, 200)
local c2552100 = Color(255, 210, 0)
local c2001500 = Color(200, 150, 0)
local c404040 = Color(40, 40, 40)

local btb = BATTLEBEATS

local SEG = 6
local ang_step = math.rad(90 / SEG)
local quarter = {}
for i = 0, SEG do
    local a = i * ang_step
    quarter[i] = { math.cos(a), math.sin(a) }
end

function btb.drawRoundedOutline(radius, x, y, w, h, thickness, col)
    if radius > math.min(w, h) / 2 then radius = math.min(w, h) / 2 end
    if thickness < 1 then thickness = 1 end

    local inner_r = math.max(radius - thickness, 0.01)
    surface.SetDrawColor(col.r or col[1], col.g or col[2], col.b or col[3], col.a or col[4] or 255)
    surface.DrawRect(x + radius, y, w - radius * 2, thickness)
    surface.DrawRect(x + radius, y + h - thickness, w - radius * 2, thickness)
    surface.DrawRect(x, y + radius, thickness, h - radius * 2)
    surface.DrawRect(x + w - thickness, y + radius, thickness, h - radius * 2)
    draw.NoTexture()

    local rotations = {
        { cx = x + radius, cy = y + radius, cx_mul = -1, cy_mul = -1 }, -- TL
        { cx = x + w - radius, cy = y + radius, cx_mul = 1,  cy_mul = -1 }, -- TR
        { cx = x + w - radius, cy = y + h - radius, cx_mul = 1,  cy_mul = 1 }, -- BR
        { cx = x + radius, cy = y + h - radius, cx_mul = -1, cy_mul = 1 }, -- BL
    }

    local poly = {}
    for _, r in ipairs(rotations) do
        local cx, cy = r.cx, r.cy
        local cxm, cym = r.cx_mul, r.cy_mul

        local reverse_order = (cxm * cym < 0)

        for i = 0, SEG - 1 do
            local s = quarter[i]
            local e = quarter[i + 1]

            local sxo = cx + s[1] * cxm * radius
            local syo = cy + s[2] * cym * radius
            local exo = cx + e[1] * cxm * radius
            local eyo = cy + e[2] * cym * radius

            local sxi = cx + s[1] * cxm * inner_r
            local syi = cy + s[2] * cym * inner_r
            local exi = cx + e[1] * cxm * inner_r
            local eyi = cy + e[2] * cym * inner_r

            if reverse_order then
                poly[1] = { x = sxo, y = syo }
                poly[2] = { x = sxi, y = syi }
                poly[3] = { x = exi, y = eyi }
                poly[4] = { x = exo, y = eyo }
            else
                poly[1] = { x = sxo, y = syo }
                poly[2] = { x = exo, y = eyo }
                poly[3] = { x = exi, y = eyi }
                poly[4] = { x = sxi, y = syi }
            end

            surface.DrawPoly(poly)
        end
    end
end

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
        draw.RoundedBox(10, 0, 0, w, h, c2001500)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, c404040)
    end
    local label = vgui.Create("DLabel", box)
    label:SetFont("DermaDefault")
    label:SetTextColor(c200200200)
    label:Center()
    box.label = label
    return box
end

local function updateBox(box, text, color)
    box.label:SetText(text)
    box.label:SetTextColor(color or c200200200)
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

local c202020215 = Color(20, 20, 20, 215)
local c707070255 = Color(70, 70, 70, 255)
local c808080255 = Color(80, 80, 80, 255)
local c150150150 = Color(150, 150, 150)
local c100100100 = Color(100, 100, 100)
local c606060 = Color(60, 60, 60)
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
--MARK: Import frame
function btb.openImportFrame(frame)
    local background = vgui.Create("DPanel", frame)
    background:SetSize(frame:GetWide(), frame:GetTall())
    background:Center()
    background.Paint = function(self)
        drawBlur(self, 2)
    end
    local importFrame
    local playlistFrame = vgui.Create("DPanel", background)
    playlistFrame:SetSize(400, 220)
    playlistFrame:Center()
    playlistFrame.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, c202020215)
        btb.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end
    local playlistBtn = vgui.Create("DButton", playlistFrame)
    playlistBtn:SetSize(360, 80)
    playlistBtn:SetPos(20, 20)
    playlistBtn:SetText("#btb.ps.button_create")
    playlistBtn:SetFont("BattleBeats_Font")
    playlistBtn:SetTextColor(color_white)
    playlistBtn:BTB_SetButton(c2552100, c707070255, c808080255)
    playlistBtn.DoClick = function()
        btb.openPlaylistEditor(nil, function()
            RefreshList()
        end)
        background:Remove()
    end
    local importBtn = vgui.Create("DButton", playlistFrame)
    importBtn:SetSize(360, 80)
    importBtn:SetPos(20, 120)
    importBtn:SetText("#btb.ps.button_import")
    importBtn:SetFont("BattleBeats_Font")
    importBtn:SetTextColor(color_white)
    importBtn:BTB_SetButton(c2552100, c707070255, c808080255)
    importBtn.DoClick = function()
        playlistFrame:Remove()
        if IsValid(importFrame) then return end
        surface.PlaySound("btb_button_click.mp3")
        importFrame = vgui.Create("DPanel", frame)
        importFrame:SetSize(500, 230)
        importFrame:Center()
        importFrame.Paint = function(self, w, h)
            drawBlur(self, 3)
            draw.RoundedBox(12, 0, 0, w, h, c202020215)
            btb.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
        end
        btb.importBox = vgui.Create("DTextEntry", importFrame)
        btb.importBox:SetSize(460, 80)
        btb.importBox:SetPos(20, 20)
        btb.importBox:SetMultiline(true)
        btb.importBox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, c808080255)
            self:DrawTextEntryText(color_white, color_white, color_white)
            if self:GetText() == "" and not self:IsEditing() then
                draw.SimpleText("#btb.playlist.import.code", "BattleBeats_Checkbox_Font", 5, h / 2, c150150150, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        btb.plNameBox = vgui.Create("DTextEntry", importFrame)
        btb.plNameBox:SetMaximumCharCount(30)
        btb.plNameBox:SetSize(460, 30)
        btb.plNameBox:SetPos(20, 110)
        btb.plNameBox:SetFont("BattleBeats_Font")
        btb.plNameBox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, c808080255)
            self:DrawTextEntryText(color_white, color_white, color_white)
            if self:GetText() == "" and not self:IsEditing() then
                draw.SimpleText("#btb.playlist.create.enter_name", "BattleBeats_Checkbox_Font", 5, h / 2, c150150150, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        local infoLabel = vgui.Create("DLabel", importFrame)
        infoLabel:SetPos(20, 150)
        infoLabel:SetSize(460, 20)
        infoLabel:SetTextColor(color_white)
        infoLabel:SetFont("CenterPrintText")
        infoLabel:SetContentAlignment(5)
        infoLabel:SetText("No data loaded")
        local decodedData = nil
        local missing = {}
        local importClean = vgui.Create("DButton", importFrame)
        local importKeep = vgui.Create("DButton", importFrame)
        importClean:SetEnabled(false)
        importKeep:SetEnabled(false)
        importClean:SetTooltip("#btb.ps.button_import_clean_tip")
        importClean:SetTooltipPanelOverride("BattleBeatsTooltip")
        importKeep:SetTooltip("#btb.ps.button_import_keep_tip")
        importKeep:SetTooltipPanelOverride("BattleBeatsTooltip")
        importClean:SetTextColor(c100100100)
        importKeep:SetTextColor(c100100100)
        importClean:SetCursor("no")
        importKeep:SetCursor("no")
        importClean:SetFont("CenterPrintText")
        importKeep:SetFont("CenterPrintText")
        btb.importBox.OnTextChanged = function(self)
            timer.Remove("BTB_ImportDecodeTimer")
            timer.Create("BTB_ImportDecodeTimer", 0.3, 1, function()
                if not IsValid(self) then return end
                local text = self:GetValue()
                decodedData = nil
                missing = {}
                local data = btb.importPlaylist(text)
                if not data then
                    infoLabel:SetText("#btb.playlist.import.invalid_code")
                    importClean:SetEnabled(false)
                    importKeep:SetEnabled(false)
                    importClean:SetCursor("no")
                    importKeep:SetCursor("no")
                    importClean:SetTextColor(c100100100)
                    importKeep:SetTextColor(c100100100)
                    return
                end
                decodedData = data
                local function check(list)
                    for _, track in ipairs(list or {}) do
                        if not file.Exists(track.path, "GAME") then
                            table.insert(missing, track.path)
                        end
                    end
                end
                check(data.ambient)
                check(data.combat)
                if #missing > 0 then
                    importClean:SetEnabled(true)
                    importKeep:SetEnabled(true)
                    importClean:SetCursor("hand")
                    importKeep:SetCursor("hand")
                    importClean:SetTextColor(color_white)
                    importKeep:SetTextColor(color_white)
                    infoLabel:SetText(language.GetPhrase("btb.playlist.import.missing_tracks") .. ": " .. table.concat(missing, ", "))
                else
                    importClean:SetEnabled(true)
                    importKeep:SetEnabled(false)
                    importClean:SetCursor("hand")
                    importKeep:SetCursor("no")
                    importClean:SetTextColor(color_white)
                    importKeep:SetTextColor(c100100100)
                    infoLabel:SetText("#btb.playlist.import.all_good")
                end
            end)
        end

        importClean:SetSize(140, 30)
        importClean:SetPos(20, 180)
        importClean:SetText("#btb.ps.button_import_clean")
        importClean.DoClick = function()
            if not decodedData then return end
            background:Remove()
            local name = btb.plNameBox:GetValue()
            if name == "" then
                notification.AddLegacy("#btb.playlist.create.enter_name_error", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button11.wav")
                return
            end
            for packName, _ in pairs(btb.musicPacks or {}) do
                if name == packName then
                    if not isEdit or editedTitle ~= title then
                        notification.AddLegacy("#btb.playlist.create.name_error", NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button11.wav")
                        return
                    end
                end
            end

            local function filter(list)
                local new = {}
                for _, track in ipairs(list or {}) do
                    if file.Exists(track.path, "GAME") then
                        table.insert(new, track)
                    end
                end
                return new
            end
            notification.AddLegacy("#btb.playlist.import.succ", NOTIFY_GENERIC, 3)
            surface.PlaySound("buttons/button3.wav")
            decodedData.ambient = filter(decodedData.ambient)
            decodedData.combat = filter(decodedData.combat)
            btb.musicPlaylists[name] = decodedData
            btb.validateAndTransformPlaylist(name, decodedData)
            btb.savePlaylists()
            importFrame:Remove()
            RefreshList()
        end
        importClean.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h,
                self:IsEnabled() and (self:IsHovered() and c100100100 or c808080255) or c606060)
        end

        importKeep:SetSize(140, 30)
        importKeep:SetPos(180, 180)
        importKeep:SetText("#btb.ps.button_import_keep")
        importKeep.DoClick = function()
            if not decodedData then return end
            background:Remove()
            local name = btb.plNameBox:GetValue()
            if name == "" then
                notification.AddLegacy("#btb.playlist.create.enter_name_error", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button11.wav")
                return
            end
            for packName, _ in pairs(btb.musicPacks or {}) do
                if name == packName then
                    if not isEdit or editedTitle ~= title then
                        notification.AddLegacy("#btb.playlist.create.name_error", NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button11.wav")
                        return
                    end
                end
            end
            notification.AddLegacy("#btb.playlist.import.succ", NOTIFY_GENERIC, 3)
            surface.PlaySound("buttons/button3.wav")
            btb.musicPlaylists[name] = decodedData
            btb.validateAndTransformPlaylist(name, decodedData)
            btb.savePlaylists()
            importFrame:Remove()
            RefreshList()
        end
        importKeep.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h,
                self:IsEnabled() and (self:IsHovered() and c100100100 or c808080255) or c606060)
        end

        local cancelBtn = vgui.Create("DButton", importFrame)
        cancelBtn:SetSize(140, 30)
        cancelBtn:SetPos(340, 180)
        cancelBtn:SetText("#btb.main.volume_cancel")
        cancelBtn:SetTextColor(color_white)
        cancelBtn:SetFont("CenterPrintText")
        cancelBtn.DoClick = function()
            background:Remove()
            importFrame:Remove()
        end
        cancelBtn.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and c100100100 or c808080255)
        end
    end
    return playlistFrame
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

--MARK:Volume edit
function btb.openVolumeEditor(panel, track, pack, func)
    local background = vgui.Create("DPanel", panel)
    background:SetSize(panel:GetWide(), panel:GetTall())
    background:Center()
    background.Paint = function(self)
        drawBlur(self, 2)
    end
    local frame = vgui.Create("DPanel", background)
    frame:SetSize(360, 150)
    frame:Center()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, c000200)
        btb.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end
    frame:BTB_SetTitle("Volume Boost", true)

    local warning = vgui.Create("DLabel", frame)
    warning:SetFont("DermaDefault")
    warning:SetTextColor(Color(255, 200, 120))
    warning:SetSize(340, 30)
    warning:SetPos(10, 85)
    warning:SetWrap(true)
    warning:SetText("Volume boost multiplies final volume. Raising base volume makes the boost stronger (e.g 2x can become 4x)")

    local current = 100
    if track then
        current = btb.getTrackData(track).vol or 100
    elseif pack then
        current = btb.packVolume[pack] or 100
    end

    local bar = vgui.Create("DPanel", frame)
    bar:SetSize(320, 8)
    bar:SetPos(20, 65)
    bar:SetCursor("hand")

    local valueLabel = vgui.Create("DLabel", frame)
    valueLabel:SetFont("DermaDefaultBold")
    valueLabel:SetTextColor(color_white)
    valueLabel:SetSize(200, 20)
    valueLabel:SetPos(80, 40)
    valueLabel:SetContentAlignment(5)

    local leftBtn = vgui.Create("DButton", frame)
    leftBtn:SetText("<")
    leftBtn:SetFont("CreditsText")
    leftBtn:SetTextColor(color_white)
    leftBtn:SetSize(20, 20)
    leftBtn:SetPos(3, 58)
    leftBtn.Paint = function(self, w, h)
        local bgColor = Color(0, 0, 0, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end

    local rightBtn = vgui.Create("DButton", frame)
    rightBtn:SetText(">")
    rightBtn:SetFont("CreditsText")
    rightBtn:SetTextColor(color_white)
    rightBtn:SetSize(20, 20)
    rightBtn:SetPos(340, 58)
    rightBtn.Paint = function(self, w, h)
        local bgColor = Color(0, 0, 0, 0)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
    end

    local value = current

    local function updateLabel()
        local offset = value - 100
        if offset == 0 then
            valueLabel:SetText("0%")
        elseif offset > 0 then
            valueLabel:SetText("+" .. offset .. "%")
        else
            valueLabel:SetText(offset .. "%")
        end
    end

    bar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c909090)
        local progress = value / 200
        local center = w * 0.5
        local pos = w * progress
        if pos >= center then
            draw.RoundedBox(0, center, 0, pos - center, h, c2552100)
        else
            draw.RoundedBox(0, pos, 0, center - pos, h, c2552100)
        end
    end
    frame.PaintOver = function()
        surface.SetDrawColor(255, 255, 255, 180)
        local center = 20 + bar:GetWide() / 2
        surface.DrawRect(center - 1, bar:GetY() - 1, 2, bar:GetTall() + 2)
    end

    local dot = vgui.Create("DPanel", frame)
    dot:SetMouseInputEnabled(false)
    dot:SetSize(12, 12)

    dot.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, color_white)
    end

    dot.Think = function(self)
        local progress = value / 200
        local x = 20 + bar:GetWide() * progress - 6
        self:SetPos(x, 65 + bar:GetTall() / 2 - 6)
    end

    local function applyValue(val)
        value = math.Clamp(math.floor(val), 0, 200)

        if track then
            if value == 100 then
                btb.setTrackData(track, "vol", nil)
            else
                btb.setTrackData(track, "vol", value)
            end
            updateLabel()
            local sName = IsValid(btb.currentStation) and btb.currentStation:GetFileName() or nil
            if not sName then sName = IsValid(btb.currentPreviewStation) and
                btb.currentPreviewStation:GetFileName() or nil end
            if sName == track then
                if IsValid(btb.currentStation) then
                    local targetVolume = btb.adjustVolume(sName)
                    btb.currentStation:SetVolume(targetVolume)
                elseif IsValid(btb.currentPreviewStation) then
                    local targetVolume = btb.adjustVolume(sName, nil, true)
                    btb.currentPreviewStation:SetVolume(targetVolume)
                end
            end
        elseif pack then
            btb.packVolume = btb.packVolume or {}
            if value == 100 then
                btb.packVolume[pack] = nil
            else
                btb.packVolume[pack] = value
            end
            updateLabel()
            local sName = IsValid(btb.currentStation) and btb.currentStation:GetFileName() or nil
            if not sName then sName = IsValid(btb.currentPreviewStation) and
                btb.currentPreviewStation:GetFileName() or nil end
            if pack == btb.trackToPack[sName] then
                if IsValid(btb.currentStation) then
                    local targetVolume = btb.adjustVolume(sName)
                    btb.currentStation:SetVolume(targetVolume)
                elseif IsValid(btb.currentPreviewStation) then
                    local targetVolume = btb.adjustVolume(sName, nil, true)
                    btb.currentPreviewStation:SetVolume(targetVolume)
                end
            end
        end
    end

    local function applySnap(val)
        local offset = val - 100
        if offset >= -5 and offset <= 5 then
            return 100
        end
        return val
    end

    local function updateValue(x)
        local progress = math.Clamp(x / bar:GetWide(), 0, 1)
        local newValue = progress * 200
        newValue = applySnap(newValue)
        applyValue(newValue)
    end

    leftBtn.DoClick = function()
        applyValue(value - 1)
    end

    rightBtn.DoClick = function()
        applyValue(value + 1)
    end

    bar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT then
            local x = self:CursorPos()
            updateValue(x)
            self.IsDragging = true
        end
    end

    bar.Think = function(self)
        if self.IsDragging and input.IsMouseDown(MOUSE_LEFT) then
            local x = self:CursorPos()
            updateValue(x)
        elseif self.IsDragging then
            self.IsDragging = false
        end
    end

    frame.OnRemove = function()
        if isfunction(func) then
            func()
        end
        if not track then
            btb.savePackVolumes()
        end
    end

    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos((frame:GetWide() - 150) / 2, 120)
    saveBtn:SetSize(150, 25)
    saveBtn:SetText("#btb.ps.ts.rmb.assign_save")
    saveBtn:SetFont("CreditsText")
    saveBtn:SetTextColor(color_white)
    saveBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and c808080255 or c707070255)
    end

    saveBtn.DoClick = function() background:Remove() end

    updateLabel()
end

--MARK: Track trim
local c808080255 = Color(80, 80, 80, 255)
local c707070255 = Color(70, 70, 70, 255)
local c255100100 = Color(255, 100, 100)
local c100255100 = Color(100, 255, 100)
function btb.openTrimEditor(panel, track, func)
    local trackLength = 0
    local trimData = btb.getTrackData(track).trim or {}

    local background = vgui.Create("DPanel", panel)
    background:SetSize(panel:GetWide(), panel:GetTall())
    background:Center()
    background.Paint = function(self)
        drawBlur(self, 2)
    end

    local frame = vgui.Create("DPanel", background)
    frame:SetSize(500, 130)
    frame:Center()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, c000200)
        btb.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end

    local title = language.GetPhrase("btb.ps.ts.rmb.trim_title")
    frame:BTB_SetTitle(title .. ": " .. btb.FormatTrackName(track), true)

    local slider = vgui.Create("DPanel", frame)
    slider:SetPos(20, 55)
    slider:SetSize(460, 25)
    slider:SetVisible(false)

    sound.PlayFile(track, "noplay", function(station, errCode, errStr)
        if errCode or errStr then
            local error = vgui.Create("DLabel", frame)
            error:SetPos((frame:GetWide() / 2) - 200, 60)
            error:SetSize(400, 40)
            error:SetText("There was an error with getting track data!")
            error:SetContentAlignment(5)
            error:SetFont("BattleBeats_Checkbox_Font")
            error:SetTextColor(color_white)
            return
        end
        if station then
            trackLength = math.floor(station:GetLength())
            station:Stop()
            slider.startValue = trimData.start or 0
            slider.endValue = trimData.finish or trackLength
            if slider.endValue > 30 then
                slider:SetVisible(true)
                slider.draggingStart = false
                slider.draggingEnd = false

                slider.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 5, w, h - 10, c909090)
                    if trackLength <= 0 then return end

                    local startFrac = self.startValue / trackLength
                    local endFrac = self.endValue / trackLength
                    local startPos = w * startFrac
                    local endPos = w * endFrac

                    draw.RoundedBox(4, startPos, 5, endPos - startPos, h - 10, c2552100)

                    draw.RoundedBox(4, startPos - 4, 0, 8, h, c100255100)
                    draw.RoundedBox(4, endPos - 4, 0, 8, h, c255100100)

                    local startText = btb.FormatTime(self.startValue)
                    local endText = btb.FormatTime(self.endValue)
                    draw.SimpleTextOutlined(startText .. " - " .. endText, "BattleBeats_Checkbox_Font", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 255))
                end

                slider.OnMousePressed = function(self)
                    if trackLength <= 0 then return end
                    local x = self:LocalCursorPos()
                    local w = self:GetWide()
                    local startPos = (self.startValue / trackLength) * w
                    local endPos = (self.endValue / trackLength) * w
                    if math.abs(x - startPos) < math.abs(x - endPos) then
                        self.draggingStart = true
                    else
                        self.draggingEnd = true
                    end
                    self:MouseCapture(true)
                end

                slider.OnMouseReleased = function(self)
                    self.draggingStart = false
                    self.draggingEnd = false
                    self:MouseCapture(false)
                end

                slider.Think = function(self)
                    if not self.draggingStart and not self.draggingEnd then return end
                    if trackLength <= 0 then return end
                    local x = self:LocalCursorPos()
                    local w = self:GetWide()
                    local newValue = math.Clamp((x / w) * trackLength, 0, trackLength)
                    if self.draggingStart then
                        self.startValue = math.Clamp(newValue, 0, self.endValue - 30)
                    elseif self.draggingEnd then
                        self.endValue = math.Clamp(newValue, self.startValue + 30, trackLength)
                    end
                end

                local saveButton = vgui.Create("DButton", frame)
                saveButton:SetPos(60, 90)
                saveButton:SetSize(150, 25)
                saveButton:SetText("#btb.ps.ts.rmb.assign_save")
                saveButton:SetFont("CreditsText")
                saveButton:SetTextColor(color_white)

                saveButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c808080255 or c707070255
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                end

                saveButton.DoClick = function()
                    if slider.endValue - slider.startValue < 30 then
                        notification.AddLegacy("Track must be at least 30 seconds", NOTIFY_ERROR, 3)
                        return
                    end

                    local startVal = math.floor(slider.startValue)
                    local endVal = math.floor(slider.endValue)

                    local trim = {}
                    if startVal > 0 then
                        trim.start = startVal
                    end
                    if endVal < trackLength then
                        trim.finish = endVal
                    end

                    if next(trim) == nil then
                        btb.setTrackData(track, "trim", nil)
                        notification.AddLegacy("Trim removed", NOTIFY_GENERIC, 3)
                    else
                        btb.setTrackData(track, "trim", trim)
                        notification.AddLegacy("Trim set: " .. startVal .. "s - " .. endVal .. "s", NOTIFY_GENERIC, 3)
                    end

                    if isfunction(func) then
                        func()
                    end

                    surface.PlaySound("buttons/button14.wav")
                    background:Remove()
                end

                local cancelButton = vgui.Create("DButton", frame)
                cancelButton:SetPos(290, 90)
                cancelButton:SetSize(150, 25)
                cancelButton:SetText("#btb.main.volume_cancel")
                cancelButton:SetFont("CreditsText")
                cancelButton:SetTextColor(color_white)

                cancelButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c808080255 or c707070255
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                end

                cancelButton.DoClick = function()
                    background:Remove()
                end
            elseif slider.endValue <= 30 then
                local frameTitle = vgui.Create("DLabel", frame)
                frameTitle:SetPos((frame:GetWide() / 2) - 200, 30)
                frameTitle:SetSize(400, 40)
                frameTitle:SetText("Cannot trim track because it's too short!")
                frameTitle:SetContentAlignment(5)
                frameTitle:SetFont("BattleBeats_Checkbox_Font")
                frameTitle:SetTextColor(color_white)
                local frameTitle2 = vgui.Create("DLabel", frame)
                frameTitle2:SetPos((frame:GetWide() / 2) - 200, 45)
                frameTitle2:SetSize(400, 40)
                frameTitle2:SetText("(track needs to be at least 30 seconds long)")
                frameTitle2:SetContentAlignment(5)
                frameTitle2:SetFont("BattleBeats_Checkbox_Font")
                frameTitle2:SetTextColor(color_white)

                local cancelButton = vgui.Create("DButton", frame)
                cancelButton:SetPos((frame:GetWide() - 150) / 2, 90)
                cancelButton:SetSize(150, 25)
                cancelButton:SetText("#btb.main.volume_cancel")
                cancelButton:SetFont("CreditsText")
                cancelButton:SetTextColor(color_white)

                cancelButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c808080255 or c707070255
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                end

                cancelButton.DoClick = function()
                    background:Remove()
                end
            end
        end
    end)
end

--MARK:NPC assign

local function getIcon(npc)
    local candidates = {npc.id, npc.class, npc.name and string.lower(string.Replace(npc.name, " ", "_")) or nil}
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

local c808080220 = Color(80, 80, 80, 220)
local c454545220 = Color(45, 45, 45, 220)
local c505050 = Color(50,50,50)

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
    local background = vgui.Create("DPanel", panel)
    background:SetSize(panel:GetWide(), panel:GetTall())
    background:Center()
    background.Paint = function(self)
        drawBlur(self, 2)
    end

    local frame = vgui.Create("DPanel", background)
    frame:SetSize(620, 520)
    frame:Center()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, c000200)
        btb.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
        surface.SetDrawColor(c2552100)
        surface.DrawRect(0, 65, w, 1)
    end
    frame:BTB_SetTitle(title, true)

    local textEntry = vgui.Create("DTextEntry", frame)
    textEntry:SetPos(120, 30)
    textEntry:SetSize(250, 20)
    textEntry:SetText(defaultClass or "")
    textEntry:SetFont("BattleBeats_Checkbox_Font")
    textEntry.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, c808080255)
        self:DrawTextEntryText(color_white, color_white, color_white)
        if self:GetText() == "" and not self:IsEditing() then
            draw.SimpleText("#btb.ps.ts.rmb.assign_enter_class", "BattleBeats_Checkbox_Font", 5, h / 2, c150150150, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local helpBtn = vgui.Create("DImage", frame)
    helpBtn:SetPos(382, 32.5)
    helpBtn:SetSize(15, 15)
    helpBtn:SetImage("icon16/help.png")
    helpBtn:SetMouseInputEnabled(true)
    helpBtn:BTB_SetImageTooltip("assignhelp.png", "#btb.ps.ts.rmb.assign_img_tip")

    local priorityCombo = vgui.Create("DComboBox", frame)
    priorityCombo:SetPos(410, 30)
    priorityCombo:SetSize(100, 20)

    local priorityNames = {
        [1] = "1 " .. language.GetPhrase("btb.ps.ts.rmb.assign_priority_highest"),
        [2] = "2",
        [3] = "3",
        [4] = "4",
        [5] = "5 " .. language.GetPhrase("btb.ps.ts.rmb.assign_priority_lowest")
    }

    for i = 1, 5 do
        priorityCombo:AddChoice(priorityNames[i], i)
    end

    priorityCombo:SetValue(priorityNames[defaultPriority or 1])

    local searchEntry = vgui.Create("DTextEntry", frame)
    searchEntry:SetPos(10, 76)
    searchEntry:SetSize(600, 22)
    searchEntry:SetFont("BattleBeats_Checkbox_Font")
    searchEntry.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, c808080255)
        self:DrawTextEntryText(color_white, color_white, color_white)
        if self:GetText() == "" and not self:IsEditing() then
            draw.SimpleText("Search NPC...", "BattleBeats_Checkbox_Font", 5, h / 2, c150150150, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(10, 110)
    scroll:SetSize(600, 360)
    scroll:GetVBar():SetWide(0)

    local iconLayout = vgui.Create("DIconLayout", scroll)
    iconLayout:Dock(TOP)
    iconLayout:SetWide(scroll:GetWide())
    iconLayout:SetSpaceX(13)
    iconLayout:SetSpaceY(10)

    local function getSelectedNPCID()
        return string.Trim(string.lower(textEntry:GetText() or ""))
    end

    local npcList = getCachedNPCList()
    local searchDebounceName = "BTB_AssignNPCSearchDebounce_" .. tostring(frame)
    local npcTiles = {}
    local function createNPCTile(npc)
        local tile = iconLayout:Add("DButton")
        tile:SetSize(140, 150)
        tile:SetText("")
        tile.NPCIDLower = string.lower(tostring(npc.id))
        tile.SearchText = string.lower(tostring(npc.name))
        tile.Paint = function(self, w, h)
            local selected = getSelectedNPCID() ~= "" and self.NPCIDLower == getSelectedNPCID()
            if selected then
                draw.RoundedBox(6, 0, 0, w, h, c2552100)
                draw.RoundedBox(5, 1, 1, w - 2, h - 2, c808080255)
                return
            end
            draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and c808080220 or c454545220)
        end
        tile:SetTooltip("|Name:| " .. language.GetPhrase(npc.name or "N/A") .. "\n|Category:| " .. language.GetPhrase(npc.category or "N/A") .. "\n|Class:| " .. npc.class .. "\n|Key:| ||" .. npc.id .. "<255,255,255>||")
        tile:SetTooltipPanelOverride("BattleBeatsTooltip")

        local icon = vgui.Create("DImage", tile)
        icon:SetPos(25, 10)
        icon:SetSize(90, 90)
        icon:SetImage(getCachedIcon(npc))
        icon:SetKeepAspect(true)
        icon:SetMouseInputEnabled(false)

        local nameLabel = vgui.Create("DPanel", tile)
        nameLabel:SetPos(5, 105)
        nameLabel:SetSize(130, 40)
        nameLabel:SetMouseInputEnabled(false)
        local lines = getCachedWrappedText(language.GetPhrase(npc.name or "N/A"), "CreditsText", 130)
        nameLabel.Paint = function(self, w, h)
            local lineH = 16
            local totalH = #lines * lineH
            local startY = (h - totalH) / 2
            for i, line in ipairs(lines) do
                draw.SimpleText(line, "CreditsText", w / 2, startY + (i - 1) * lineH + lineH / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        tile.DoClick = function()
            textEntry:SetText(npc.id)
            textEntry:RequestFocus()
            textEntry:SetCaretPos(#npc.id)
            surface.PlaySound("ui/buttonclickrelease.wav")
        end

        npcTiles[#npcTiles + 1] = tile
    end

    local function filterNPCTiles(filter)
        filter = string.Trim(string.lower(filter or ""))
        for _, tile in ipairs(npcTiles) do
            if IsValid(tile) then
                local visible = filter == "" or string.find(tile.SearchText or "", filter, 1, true) ~= nil
                tile:SetVisible(visible)
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

    for _, npc in ipairs(npcList) do
        createNPCTile(npc)
    end

    filterNPCTiles("")

    searchEntry.OnChange = function(self)
        local value = self:GetValue()
        timer.Remove(searchDebounceName)
        timer.Create(searchDebounceName, 0.08, 1, function()
            if IsValid(self) then
                filterNPCTiles(value)
            end
        end)
    end

    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos(150, 485)
    saveBtn:SetSize(150, 25)
    saveBtn:SetText("#btb.ps.ts.rmb.assign_save")
    saveBtn:SetFont("CreditsText")
    saveBtn:SetTextColor(color_white)
    saveBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and c808080255 or c707070255)
    end

    saveBtn.DoClick = function()
        local class = textEntry:GetText():gsub("^%s*(.-)%s*$", "%1")
        local _, prio = priorityCombo:GetSelected()
        prio = math.Clamp(prio or defaultPriority or 1, 1, 5)
        onSave(class, prio, background)
    end

    local cancelBtn = vgui.Create("DButton", frame)
    cancelBtn:SetPos(320, 485)
    cancelBtn:SetSize(150, 25)
    cancelBtn:SetText("#btb.main.volume_cancel")
    cancelBtn:SetFont("CreditsText")
    cancelBtn:SetTextColor(color_white)
    cancelBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and c808080255 or c707070255)
    end

    cancelBtn.DoClick = function()
        timer.Remove(searchDebounceName)
        background:Remove()
    end

    background.OnRemove = function()
        timer.Remove(searchDebounceName)
    end

    return textEntry, searchEntry
end

function btb.changeName(panel, track, func)
    local tname = btb.FormatTrackName(track)
    local td = btb.getTrackData(track)
    local currentAlias = td.alias or tname
    local background = vgui.Create("DPanel", panel)
    background:SetSize(panel:GetWide(), panel:GetTall())
    background:Center()
    background.Paint = function(self)
        drawBlur(self, 2)
    end

    local frame = vgui.Create("DPanel", background)
    frame:SetSize(400, 110)
    frame:Center()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, c000200)
        btb.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end
    frame:BTB_SetTitle("#btb.ps.ts.rmb.set_name_title", true)

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(10, 30)
    entry:SetSize(380, 40)
    entry:SetText(currentAlias)
    entry:SetMaximumCharCount(56)
    entry:SetCaretPos(string.len(currentAlias))
    entry:RequestFocus()
    entry:SetFont("BattleBeats_Font")
    entry.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c707070255)
        self:DrawTextEntryText(color_white, color_white, color_white)
        if self:GetText() == "" and not self:IsEditing() then
            draw.SimpleText(tname, "BattleBeats_Font", 5, h / 2, c150150150, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local function saveAlias()
        local text = string.Trim(entry:GetValue() or "")
        if text == tname or text == "" then
            btb.setTrackData(track, "alias", nil)
        else
            btb.setTrackData(track, "alias", text)
        end
        func()
        background:Remove()
    end

    entry.OnEnter = function ()
        saveAlias()
    end

    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos(45, 75)
    saveBtn:SetSize(150, 25)
    saveBtn:SetText("#btb.ps.ts.rmb.assign_save")
    saveBtn:SetFont("CreditsText")
    saveBtn:SetTextColor(color_white)
    saveBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and c808080255 or c707070255)
    end

    saveBtn.DoClick = function()
        saveAlias()
    end

    local cancelBtn = vgui.Create("DButton", frame)
    cancelBtn:SetPos(205, 75)
    cancelBtn:SetSize(150, 25)
    cancelBtn:SetText("#btb.main.volume_cancel")
    cancelBtn:SetFont("CreditsText")
    cancelBtn:SetTextColor(color_white)
    cancelBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and c808080255 or c707070255)
    end
    cancelBtn.DoClick = function() background:Remove() end

    return entry
end

--MARK:Subtitles
function btb.openSubtitles(panel, trackName, subs)
    local background = vgui.Create("DPanel", panel)
    background:SetSize(panel:GetWide(), panel:GetTall())
    background:Center()
    background.Paint = function(self)
        drawBlur(self, 2)
    end

    local frame = vgui.Create("DPanel", background)
    frame:SetSize(500, 430)
    frame:Center()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, c000200)
        btb.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end
    local title = language.GetPhrase("#btb.ps.ts.rmb.show_lyrics_title")
    frame:BTB_SetTitle(title .. trackName, true)

    local scroll = vgui.Create("DScrollPanel", frame)
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

    local cancelButton = vgui.Create("DButton", frame)
    cancelButton:SetPos((frame:GetWide() - 150) / 2, 400)
    cancelButton:SetSize(150, 25)
    cancelButton:SetText("#btb.main.volume_cancel")
    cancelButton:SetFont("CreditsText")
    cancelButton:SetTextColor(color_white)
    cancelButton.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and c808080255 or c707070255
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end

    cancelButton.DoClick = function()
        background:Remove()
    end
end