local c909090 = Color(90, 90, 90)
local c000200 = Color(0, 0, 0, 200)
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

local SEG = 6
local ang_step = math.rad(90 / SEG)
local quarter = {}
for i = 0, SEG do
    local a = i * ang_step
    quarter[i] = { math.cos(a), math.sin(a) }
end

function BATTLEBEATS.drawRoundedOutline(radius, x, y, w, h, thickness, col)
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
    local numericSize = parseSize(size)
    if not numericSize then return c200200200 end
    if numericSize < 200 then
        return Color(0, 200, 0)
    elseif numericSize < 600 then
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
function BATTLEBEATS.openImportFrame(frame)
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
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end
    local playlistBtn = vgui.Create("DButton", playlistFrame)
    playlistBtn:SetSize(360, 80)
    playlistBtn:SetPos(20, 20)
    playlistBtn:SetText("#btb.ps.button_create")
    playlistBtn:SetFont("BattleBeats_Font")
    playlistBtn:SetTextColor(color_white)
    playlistBtn:BTB_SetButton(c2552100, c707070255, c808080255)
    playlistBtn.DoClick = function()
        BATTLEBEATS.openPlaylistEditor(nil, function()
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
            BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
        end
        BATTLEBEATS.importBox = vgui.Create("DTextEntry", importFrame)
        BATTLEBEATS.importBox:SetSize(460, 80)
        BATTLEBEATS.importBox:SetPos(20, 20)
        BATTLEBEATS.importBox:SetMultiline(true)
        BATTLEBEATS.importBox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, c808080255)
            self:DrawTextEntryText(color_white, color_white, color_white)
            if self:GetText() == "" and not self:IsEditing() then
                draw.SimpleText("#btb.playlist.import.code", "BattleBeats_Checkbox_Font", 5, h / 2, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        BATTLEBEATS.plNameBox = vgui.Create("DTextEntry", importFrame)
        BATTLEBEATS.plNameBox:SetMaximumCharCount(30)
        BATTLEBEATS.plNameBox:SetSize(460, 30)
        BATTLEBEATS.plNameBox:SetPos(20, 110)
        BATTLEBEATS.plNameBox:SetFont("BattleBeats_Font")
        BATTLEBEATS.plNameBox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, c808080255)
            self:DrawTextEntryText(color_white, color_white, color_white)
            if self:GetText() == "" and not self:IsEditing() then
                draw.SimpleText("#btb.playlist.create.enter_name", "BattleBeats_Checkbox_Font", 5, h / 2, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
        BATTLEBEATS.importBox.OnTextChanged = function(self)
            timer.Remove("BTB_ImportDecodeTimer")
            timer.Create("BTB_ImportDecodeTimer", 0.3, 1, function()
                if not IsValid(self) then return end
                local text = self:GetValue()
                decodedData = nil
                missing = {}
                local data = BATTLEBEATS.importPlaylist(text)
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
            local name = BATTLEBEATS.plNameBox:GetValue()
            if name == "" then
                notification.AddLegacy("#btb.playlist.create.enter_name_error", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button11.wav")
                return
            end
            for packName, _ in pairs(BATTLEBEATS.musicPacks or {}) do
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
            BATTLEBEATS.musicPlaylists[name] = decodedData
            BATTLEBEATS.validateAndTransformPlaylist(name, decodedData)
            BATTLEBEATS.SavePlaylists()
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
            local name = BATTLEBEATS.plNameBox:GetValue()
            if name == "" then
                notification.AddLegacy("#btb.playlist.create.enter_name_error", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button11.wav")
                return
            end
            for packName, _ in pairs(BATTLEBEATS.musicPacks or {}) do
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
            BATTLEBEATS.musicPlaylists[name] = decodedData
            BATTLEBEATS.validateAndTransformPlaylist(name, decodedData)
            BATTLEBEATS.SavePlaylists()
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

function BATTLEBEATS.createInfoPanel(panel, packData, callback)
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

    if BATTLEBEATS.wsCache[wsid] then
        applyInfo(panel, BATTLEBEATS.wsCache[wsid])
        return
    end

    steamworks.FileInfo(wsid, function(result)
        result = result or {}
        BATTLEBEATS.wsCache[wsid] = result
        if IsValid(panel) then
            applyInfo(panel, result)
        end
    end)
end

--MARK:Volume edit
function BATTLEBEATS.openVolumeEditor(panel, track, pack, func)
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
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
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
        current = BATTLEBEATS.trackVolume[track] or 100
    elseif pack then
        current = BATTLEBEATS.packVolume[pack] or 100
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
            BATTLEBEATS.trackVolume = BATTLEBEATS.trackVolume or {}
            if value == 100 then
                BATTLEBEATS.trackVolume[track] = nil
            else
                BATTLEBEATS.trackVolume[track] = value
            end
            updateLabel()
            local sName = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetFileName() or nil
            if not sName then sName = IsValid(BATTLEBEATS.currentPreviewStation) and
                BATTLEBEATS.currentPreviewStation:GetFileName() or nil end
            if sName == track then
                if IsValid(BATTLEBEATS.currentStation) then
                    local targetVolume = BATTLEBEATS.adjustVolume(sName)
                    BATTLEBEATS.currentStation:SetVolume(targetVolume)
                elseif IsValid(BATTLEBEATS.currentPreviewStation) then
                    local targetVolume = BATTLEBEATS.adjustVolume(sName, nil, true)
                    BATTLEBEATS.currentPreviewStation:SetVolume(targetVolume)
                end
            end
        elseif pack then
            BATTLEBEATS.packVolume = BATTLEBEATS.packVolume or {}
            if value == 100 then
                BATTLEBEATS.packVolume[pack] = nil
            else
                BATTLEBEATS.packVolume[pack] = value
            end
            updateLabel()
            local sName = IsValid(BATTLEBEATS.currentStation) and BATTLEBEATS.currentStation:GetFileName() or nil
            if not sName then sName = IsValid(BATTLEBEATS.currentPreviewStation) and
                BATTLEBEATS.currentPreviewStation:GetFileName() or nil end
            if pack == BATTLEBEATS.trackToPack[sName] then
                if IsValid(BATTLEBEATS.currentStation) then
                    local targetVolume = BATTLEBEATS.adjustVolume(sName)
                    BATTLEBEATS.currentStation:SetVolume(targetVolume)
                elseif IsValid(BATTLEBEATS.currentPreviewStation) then
                    local targetVolume = BATTLEBEATS.adjustVolume(sName, nil, true)
                    BATTLEBEATS.currentPreviewStation:SetVolume(targetVolume)
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
        if track then
            BATTLEBEATS.SaveTrackVolumes()
        else
            BATTLEBEATS.SavePackVolumes()
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
function BATTLEBEATS.openTrimEditor(panel, track, func)
    local trackLength = 0
    local trimData = BATTLEBEATS.trackTrim[track] or {}

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
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end

    local title = language.GetPhrase("btb.ps.ts.rmb.trim_title")
    frame:BTB_SetTitle(title .. ": " .. BATTLEBEATS.FormatTrackName(track), true)

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

                    local startText = BATTLEBEATS.FormatTime(self.startValue)
                    local endText = BATTLEBEATS.FormatTime(self.endValue)
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
                        BATTLEBEATS.trackTrim[track] = nil
                        notification.AddLegacy("Trim removed", NOTIFY_GENERIC, 3)
                    else
                        BATTLEBEATS.trackTrim[track] = trim
                        notification.AddLegacy("Trim set: " .. startVal .. "s - " .. endVal .. "s", NOTIFY_GENERIC, 3)
                    end

                    BATTLEBEATS.SaveTrackTrim()

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
function BATTLEBEATS.createAssignFrame(panel, title, defaultClass, defaultPriority, onSave)
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
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
    end
    frame:BTB_SetTitle(title, true)

    local classLabel = vgui.Create("DLabel", frame)
    classLabel:SetPos(10, 25)
    classLabel:SetSize(270, 20)
    classLabel:SetText("#btb.ps.ts.rmb.assign_class")

    local textEntry = vgui.Create("DTextEntry", frame)
    textEntry:SetPos(10, 45)
    textEntry:SetSize(250, 20)
    textEntry:SetText(defaultClass or "")
    if not defaultClass then
        textEntry:SetPlaceholderText("#btb.ps.ts.rmb.assign_enter_class")
    end

    local helpBtn = vgui.Create("DImage", frame)
    helpBtn:SetPos(267.5, 47.5)
    helpBtn:SetSize(15, 15)
    helpBtn:SetImage("icon16/help.png")
    helpBtn:SetMouseInputEnabled(true)
    helpBtn:BTB_SetImageTooltip("assignhelp.png", "#btb.ps.ts.rmb.assign_img_tip")

    local priorityLabel = vgui.Create("DLabel", frame)
    priorityLabel:SetPos(290, 25)
    priorityLabel:SetSize(100, 20)
    priorityLabel:SetText("#btb.ps.ts.rmb.assign_priority")

    local priorityCombo = vgui.Create("DComboBox", frame)
    priorityCombo:SetPos(290, 45)
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
        local class = textEntry:GetText():gsub("^%s*(.-)%s*$", "%1")
        local _, prio = priorityCombo:GetSelected()
        prio = math.Clamp(prio or defaultPriority or 1, 1, 5)
        onSave(class, prio, background)
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

    return textEntry
end

--MARK:Subtitles
function BATTLEBEATS.openSubtitles(panel, trackName, subs)
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
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, c2552100)
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