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

--MARK:Steamworks info
local buttonWidth, buttonHeight, spacing = 200, 30, 40
local function createInfoBoxes(panel, size, date, ownerName)
    if not IsValid(panel) then return end
    local panelWidth = panel:GetWide()
    local totalWidth = buttonWidth * 3 + spacing * 2
    local startX = (panelWidth - totalWidth) / 2

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
        box:SetPos(x, 120)
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

    addInfoBox(ssize .. ": " .. size, startX, sizeColor)
    addInfoBox(screated .. ": " .. date, startX + buttonWidth + spacing)
    addInfoBox(sauthor .. ": " .. ownerName, startX + (buttonWidth + spacing) * 2)
end

function BATTLEBEATS.createInfoPanel(panel, packData)
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

    if BATTLEBEATS.wsCache[wsid] then
        applyInfo(BATTLEBEATS.wsCache[wsid])
        return
    end

    steamworks.FileInfo(wsid, function(result)
        if not result then
            result = { size = nil, created = nil, ownername = nil }
        end
        BATTLEBEATS.wsCache[wsid] = result
        applyInfo(result)
    end)
end

--MARK:Volume edit
function BATTLEBEATS.openVolumeEditor(track, pack, func)
    local frame = vgui.Create("DFrame")
    frame:BTB_SetButtons(false)
    frame:SetSize(360, 120)
    frame:SetTitle("")
    frame:Center()
    frame:BTB_SetFocus()
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, 1)
        draw.RoundedBox(4, 0, 0, w, h, c000200)
    end
    frame:BTB_SetTitle("Volume Boost", false)

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

    frame.OnClose = function()
        if isfunction(func) then
            func()
        end
        if track then
            BATTLEBEATS.SaveTrackVolumes()
        else
            BATTLEBEATS.SavePackVolumes()
        end
    end

    updateLabel()
end

--MARK: Track trim
local c808080255 = Color(80, 80, 80, 255)
local c707070255 = Color(70, 70, 70, 255)
local c255100100 = Color(255, 100, 100)
local c100255100 = Color(100, 255, 100)
function BATTLEBEATS.openTrimEditor(track, func)
    local trackLength = 0
    local trimData = BATTLEBEATS.trackTrim[track] or {}

    local frame = vgui.Create("DFrame")
    frame:BTB_SetButtons(false)
    frame:SetTitle("")
    frame:SetSize(500, 160)
    frame:Center()
    frame:BTB_SetFocus()
    frame:MakePopup()

    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, 1)
        draw.RoundedBox(4, 0, 0, w, h, c000200)
    end

    local title = language.GetPhrase("btb.ps.ts.rmb.trim_title")
    frame:BTB_SetTitle(title .. ": " .. BATTLEBEATS.FormatTrackName(track), false)

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
                saveButton:SetPos(70, 115)
                saveButton:SetSize(130, 30)
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
                    frame:Close()
                end

                local cancelButton = vgui.Create("DButton", frame)
                cancelButton:SetPos(300, 115)
                cancelButton:SetSize(130, 30)
                cancelButton:SetText("#btb.main.volume_cancel")
                cancelButton:SetFont("CreditsText")
                cancelButton:SetTextColor(color_white)

                cancelButton.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and c808080255 or c707070255
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                end

                cancelButton.DoClick = function()
                    frame:Close()
                end
            elseif slider.endValue <= 30 then
                local frameTitle = vgui.Create("DLabel", frame)
                frameTitle:SetPos((frame:GetWide() / 2) - 200, 53)
                frameTitle:SetSize(400, 40)
                frameTitle:SetText("Cannot trim track because it's too short!")
                frameTitle:SetContentAlignment(5)
                frameTitle:SetFont("BattleBeats_Checkbox_Font")
                frameTitle:SetTextColor(color_white)
                local frameTitle2 = vgui.Create("DLabel", frame)
                frameTitle2:SetPos((frame:GetWide() / 2) - 200, 67)
                frameTitle2:SetSize(400, 40)
                frameTitle2:SetText("(track needs to be at least 30 seconds long)")
                frameTitle2:SetContentAlignment(5)
                frameTitle2:SetFont("BattleBeats_Checkbox_Font")
                frameTitle2:SetTextColor(color_white)
            end
        end
    end)
end

--MARK:NPC assign
function BATTLEBEATS.createAssignFrame(title, defaultClass, defaultPriority, onSave)
    local frame = vgui.Create("DFrame")
    frame:BTB_SetButtons(false)
    frame:SetTitle("")
    frame:SetSize(400, 110)
    frame:Center()
    frame:BTB_SetFocus()
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, 1)
        draw.RoundedBox(4, 0, 0, w, h, c000200)
    end
    frame:BTB_SetTitle(title, false)

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
        onSave(class, prio, frame)
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
    cancelBtn.DoClick = function() frame:Close() end

    return frame, textEntry, priorityCombo
end

--MARK:Subtitles
function BATTLEBEATS.openSubtitles(trackName, subs)
    local frame = vgui.Create("DFrame")
    frame:BTB_SetButtons(false)
    local title = language.GetPhrase("#btb.ps.ts.rmb.show_lyrics_title")
    frame:SetTitle("")
    frame:SetSize(500, 400)
    frame:Center()
    frame:BTB_SetFocus()
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, 1)
        draw.RoundedBox(4, 0, 0, w, h, c000200)
    end
    frame:BTB_SetTitle(title .. trackName, false)

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
    return frame
end