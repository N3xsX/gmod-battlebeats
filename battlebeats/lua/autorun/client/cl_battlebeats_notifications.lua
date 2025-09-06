local defaultX = tostring(ScrW() - 310)
local defaultY = tostring(ScrH() / 6)

local notifX = CreateClientConVar("battlebeats_notif_x", defaultX, true, false, "", 0, ScrW())
local notifY = CreateClientConVar("battlebeats_notif_y", defaultY, true, false, "", 0, ScrH())
local showNotificationVisualizer = CreateClientConVar("battlebeats_show_notification_visualizer", "1", true, false, "", 0, 1)
local showNotificationPackName = CreateClientConVar("battlebeats_show_notification_pack_name", "1", true, false, "", 0, 1)
local notificationVisualizerBoost = CreateClientConVar("battlebeats_visualizer_boost", "6", true, false, "", 1, 20)
local notificationVisualizerSmooth = CreateClientConVar("battlebeats_visualizer_smooth", "1", true, false, "", 0, 1)
local skipNombat = CreateClientConVar("battlebeats_skip_nombat_names", "1", true, false, "", 0, 1)
local showBar = CreateClientConVar("battlebeats_show_status_bar", "1", true, false, "", 0, 1)

function BATTLEBEATS.FormatTime(seconds) -- formats seconds into m:ss
    if not seconds or seconds < 0 then return "0:00" end
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, secs)
end

local function CapitalizeLetters(str) -- capitalizes words and fixes punctuation
    local result = {}
    for part in str:gmatch("[^%.]+") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        if part ~= "" then
            local words = {}
            for word in part:gmatch("%S+") do
                table.insert(words, word:sub(1, 1):upper() .. word:sub(2):lower())
            end
            table.insert(result, table.concat(words, " "))
        end
    end
    local final = table.concat(result, ".")
    final = final:gsub("^%l", string.upper)
    final = final:gsub("%. (%l)", function(letter) return ". " .. letter:upper() end)
    final = final:gsub("([%(%[%{])(%l)", function(open, letter)
        return open .. letter:upper()
    end)
    return final
end

function BATTLEBEATS.FormatTrackName(trackName) -- cleans file path, extensions, suffix numbers, capitalizes
    trackName = string.match(trackName, "[^/\\]+$") -- remove file path
    trackName = string.gsub(trackName, "%.mp3$", "") -- remove mp3 suffix
    trackName = string.gsub(trackName, "%.ogg$", "") -- remove ogg suffix
    trackName = string.gsub(trackName, "(_%d%d%d)$", "") -- remove numbers from the end of the track name (for SBM packs)
    trackName = CapitalizeLetters(trackName)
    return trackName
end

local c1 = Color(100, 100, 100) -- grey
local c2 = Color(255, 255, 255) -- white
local c3 = Color(0, 0, 0, 200) -- transparent black
local gradient = surface.GetTextureID("gui/gradient_up")
local animDur = 0.25
local trackNotification = nil

function BATTLEBEATS.HideNotification()
    if not IsValid(trackNotification) then return end

    local panel = trackNotification
    local finalW, finalH = panel:GetWide(), panel:GetTall()
    local finalX, finalY = panel:GetPos()

    panel:SizeTo(finalW, 10, animDur, 0, -1, function()
        if IsValid(panel) then
            panel:SizeTo(10, 10, animDur, 0, -1, function()
                if IsValid(panel) then
                    panel:Remove()
                end
            end)
        end
    end)
    panel:AlphaTo(0, 0.40, 0)

    local stage = 1
    local animStart = CurTime()

    panel.Think = function(self)
        local t = (CurTime() - animStart) / animDur
        if stage == 1 then
            local curW, curH = self:GetSize()
            self:SetPos(finalX + (finalW - curW) / 2, finalY + (finalH - curH) / 2)
            if t >= 1 then
                stage = 2
                animStart = CurTime()
            end
        elseif stage == 2 then
            local curW, curH = self:GetSize()
            self:SetPos(finalX + (finalW - curW) / 2, finalY + (finalH - curH) / 2)
            if t >= 1 then
                self.Think = nil
            end
        end
    end
end

local function ExpandPanel(panel, finalX, finalY, finalWidth, finalHeight, onDone)
    if not IsValid(panel) then return end
    local startW, startH = 10, 10
    local startX = finalX + (finalWidth - startW) / 2
    local startY = finalY + (finalHeight - startH) / 2
    panel:SetSize(startW, startH)
    panel:SetPos(startX, startY)
    panel:SetAlpha(0)
    panel:AlphaTo(255, 0.40, 0)

    local stage = 1
    local animStart = CurTime()

    panel:SizeTo(finalWidth, startH, animDur, 0, -1, function()
        local curW = panel:GetWide()
        panel:SetPos(finalX + (finalWidth - curW) / 2, finalY + (finalHeight - startH) / 2)
        panel:SizeTo(finalWidth, finalHeight, animDur, 0, -1, function()
            if onDone then onDone(panel) end
        end)
    end)

    panel.Think = function(self)
        local t = (CurTime() - animStart) / animDur
        if stage == 1 then
            local curW, curH = self:GetSize()
            self:SetPos(finalX + (finalWidth - curW) / 2, finalY + (finalHeight - curH) / 2)
            if t >= 1 then
                stage = 2
                animStart = CurTime()
            end
        elseif stage == 2 then
            local curW, curH = self:GetSize()
            self:SetPos(finalX + (finalWidth - curW) / 2, finalY + (finalHeight - curH) / 2)
            if t >= 1 then
                self.Think = nil
            end
        end
    end
end

local function GetPackName(trackName)
    for packName, pack in pairs(BATTLEBEATS.musicPacks) do
        for _, f in ipairs(pack.ambient or {}) do
            if f == trackName then
                local formattedName = packName:gsub("^[Bb][Aa][Tt][Tt][Ll][Ee][Bb][Ee][Aa][Tt][Ss] %- ", "", 1, true)
                    :gsub("^[Nn][Oo][Mm][Bb][Aa][Tt] %- ", "", 1, true)
                    :gsub("^[Ss][Bb][Mm] [Dd][Ll][Cc]: ", "", 1, true)
                    :gsub("^%[16[Tt][Hh][Nn][Oo][Tt][Ee]%]", "", 1, true)
                return formattedName
            end
        end
        for _, f in ipairs(pack.combat or {}) do
            if f == trackName then
                local formattedName = packName:gsub("^[Bb][Aa][Tt][Tt][Ll][Ee][Bb][Ee][Aa][Tt][Ss] %- ", "", 1, true)
                    :gsub("^[Nn][Oo][Mm][Bb][Aa][Tt] %- ", "", 1, true)
                    :gsub("^[Ss][Bb][Mm] [Dd][Ll][Cc]: ", "", 1, true)
                    :gsub("^%[16[Tt][Hh][Nn][Oo][Tt][Ee]%]", "", 1, true)
                return formattedName
            end
        end
    end
    return "Unknown Pack"
end

local finalWidth, finalHeight = 300, 80

function BATTLEBEATS.ShowTrackNotification(trackName, inCombat, isPreviewedTrack)
    if not trackName then return end
    local packName = GetPackName(trackName)
    trackName = BATTLEBEATS.FormatTrackName(trackName)

    if string.match(trackName:lower(), "^[ca]%d+$") and skipNombat:GetBool() then -- if the name of the track is letter A or C then skip it
        if IsValid(trackNotification) then BATTLEBEATS.HideNotification() end
        return
    end

    if IsValid(trackNotification) then
        trackNotification:Remove()
    end

    local finalX = notifX:GetInt()
    local finalY = notifY:GetInt()

    local panel = vgui.Create("DPanel")
    panel.startTime = CurTime()
    trackNotification = panel
    panel:SetAlpha(0)

    timer.Simple(0.1, function() -- workaround: delay to prevent animation breaking when called during Initialization
        ExpandPanel(panel, finalX, finalY, finalWidth, finalHeight)
    end)

    surface.SetFont("CloseCaption_Bold")

    local textX = 10
    local radius = 16
    local textWidth = surface.GetTextSize(trackName)
    local panelWidth = 280
    local scrollSpeed = 50
    local isScrolling = textWidth > panelWidth -- scroll if text too long
    local textColor = inCombat and Color(255, 165, 0) or Color(0, 255, 0) -- green = ambient, orange = in combat, gold = preview
    textColor = isPreviewedTrack and Color(255, 215, 0) or textColor
    local lastAmplitudes = {}

    local barWidth = 8
    local spacing = 4
    local maxHeight = 60
    local startX = 7
    local bars = 24

    local progressBarX, progressBarY = 40, 60
    local progressBarWidth, progressBarHeight = 216, 5

    panel.Paint = function(self, w, h)
        draw.RoundedBoxEx(radius, 0, 0, w, radius, c3, true, true, false, false)
        surface.SetDrawColor(c3)
        surface.DrawRect(0, radius, w, h - radius)
        draw.SimpleText("NOW PLAYING", "HudHintTextLarge", progressBarX + progressBarWidth / 2, 10, c2, TEXT_ALIGN_CENTER)

        surface.SetTexture(gradient)
        surface.DrawTexturedRect(0, 0, w, h)

        local yBase = h

        local station = isPreviewedTrack and BATTLEBEATS.currentPreviewStation or BATTLEBEATS.currentStation
        if IsValid(station) and showNotificationVisualizer:GetBool() then
            local fft = {}
            if station:FFT(fft, 0) then
                for i = 1, bars do
                    -- pick FFT index (linear for first half, exponential for second)
                    local idx
                    if i <= bars / 2 then
                        idx = i
                    else
                        local t = (i - bars / 2) / (bars / 2)
                        idx = math.floor((#fft) ^ t)
                    end

                    -- raw amplitude
                    local amp = fft[idx] or 0
                    if i <= bars / 2 then
                        amp = amp * 2
                    end

                    local boost = Lerp(i / bars, 1, 3)
                    local vol = math.min(station:GetVolume(), 2)
                    local scaled

                    if vol <= 0 then
                        scaled = 0
                    else
                        local boostedAmp = amp * boost * (notificationVisualizerBoost:GetInt() * vol)
                        scaled = math.log(1 + boostedAmp)
                    end

                    if notificationVisualizerSmooth:GetBool() then
                        lastAmplitudes[i] = lastAmplitudes[i] or 0
                        lastAmplitudes[i] = Lerp(FrameTime() * 5, lastAmplitudes[i], scaled)
                    else
                        lastAmplitudes[i] = scaled
                    end

                    local height = math.Clamp(lastAmplitudes[i] * maxHeight, 1, maxHeight)
                    local x = startX + (i - 1) * (barWidth + spacing)

                    surface.SetDrawColor(textColor.r, textColor.g, textColor.b, 100)
                    surface.DrawTexturedRect(x, yBase - height, barWidth, height)
                end
            else
                lastAmplitudes = {}
            end
        end

        if isScrolling then
            textX = textX - (scrollSpeed * FrameTime())
            if textX < -textWidth - 50 then
                textX = textX + textWidth + 40
            end
            draw.SimpleText(trackName, "CloseCaption_Bold", textX + 30, 25, textColor, TEXT_ALIGN_LEFT)
            draw.SimpleText(trackName, "CloseCaption_Bold", textX + textWidth + 70, 25, textColor, TEXT_ALIGN_LEFT)
        else
            draw.SimpleText(trackName, "CloseCaption_Bold", 150, 25, textColor, TEXT_ALIGN_CENTER)
        end

        if showBar:GetBool() then
            local currentTime = IsValid(station) and station:GetTime() or 0
            local trackDuration = IsValid(station) and station:GetLength() or 0
            local progress = trackDuration > 0 and math.Clamp(currentTime / trackDuration, 0, 1) or 0

            local elapsedTime = CurTime() - self.startTime
            if math.floor(elapsedTime % 30) < 4 and showNotificationPackName:GetBool() then -- text visible for 4 seconds every 30 seconds
                draw.SimpleText("From: " .. packName, "CenterPrintText", progressBarX + progressBarWidth / 2, progressBarY - 6, c2, TEXT_ALIGN_CENTER)
            else
                draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth, progressBarHeight, c1)
                draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth * progress, progressBarHeight, textColor)
                draw.SimpleText(BATTLEBEATS.FormatTime(currentTime), "CenterPrintText", progressBarX - 30,
                    progressBarY - 6, c2, TEXT_ALIGN_LEFT)
                draw.SimpleText(BATTLEBEATS.FormatTime(trackDuration), "CenterPrintText",
                    progressBarX + progressBarWidth + 5, progressBarY - 6, c2, TEXT_ALIGN_LEFT)
            end
        elseif showNotificationPackName:GetBool() then
            draw.SimpleText("From: " .. packName, "CenterPrintText", progressBarX + progressBarWidth / 2, progressBarY - 6, c2, TEXT_ALIGN_CENTER)
        end
    end

    if not GetConVar("battlebeats_persistent_notification"):GetBool() then
        timer.Simple(isScrolling and 12 or 6, function()
            if IsValid(panel) then BATTLEBEATS.HideNotification() end
        end)
    end
end

local function AddNotificationPreview() -- shows outline box when adjusting notif X/Y
    local startTime = CurTime()
    local finalX = notifX:GetInt()
    local finalY = notifY:GetInt()

    hook.Add("HUDPaint", "BattleBeats_NotificationPreview", function()
        surface.SetDrawColor(255, 255, 255, 100)
        surface.DrawOutlinedRect(finalX, finalY, finalWidth, finalHeight)

        draw.SimpleText("Notification Position", "DermaDefault", finalX + finalWidth / 2, finalY + finalHeight / 2,
            Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if CurTime() - startTime > 5 then
            hook.Remove("HUDPaint", "BattleBeats_NotificationPreview")
            if IsValid(trackNotification) then
                trackNotification:SetPos(finalX, finalY)
            end
        end
    end)
end

cvars.AddChangeCallback("battlebeats_notif_x", function() AddNotificationPreview() end, "BattleBeatsNotifX")
cvars.AddChangeCallback("battlebeats_notif_y", function() AddNotificationPreview() end, "BattleBeatsNotifY")