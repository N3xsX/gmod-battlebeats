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

function BATTLEBEATS.FormatTime(seconds)
    if not seconds or seconds < 0 then return "0:00" end
    local time = string.ToMinutesSeconds(math.floor(seconds))
    time = string.gsub(time, "^0(%d:)", "%1") -- remove unnecessary 0 in minute mark (eg 01:23 -> 1:23)
    return time
end

local function capitalizeLetters(str)
    str = string.Trim(str)
    str = str:lower()
    -- every first letter
    str = str:gsub("(%S)(%S*)", function(a, b)
        return a:upper() .. b
    end)
    -- . ! ? _ - space
    str = str:gsub("([%.%!%?%_%-]%s*)(%l)", function(punct, letter)
        return punct .. letter:upper()
    end)
    -- ( [ {
    str = str:gsub("([%(%[%{])(%l)", function(open, letter)
        return open .. letter:upper()
    end)
    return str
end

function BATTLEBEATS.FormatTrackName(trackName) -- cleans file path, extensions, suffix numbers, capitalizes
    trackName = string.GetFileFromFilename(trackName)
    trackName = string.StripExtension(trackName)
    trackName = string.gsub(trackName, "(_%d%d%d)$", "") -- remove numbers from the end of the track name (for SBM packs)
    trackName = capitalizeLetters(trackName)
    return trackName
end

local c100100100 = Color(100, 100, 100)
local c000200 = Color(0, 0, 0, 200)
local gradient = surface.GetTextureID("gui/gradient_up")
local animDur = 0.25
local trackNotification = nil

function BATTLEBEATS.HideNotification()
    local override = hook.Run("BattleBeats_PreHideNotification")
    if override == true then return end
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

local function expandPanel(panel, finalX, finalY, finalWidth, finalHeight, onDone)
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

local prefixes = {
    {prefix = "BattleBeats", type = "battlebeats"},
    {prefix = "Nombat", type = "nombat"},
    {prefix = "SBM DLC", type = "sbm"},
    {prefix = "SBM", type = "sbm"},
    {prefix = "16th Note", type = "16th"},
    {prefix = "16thNote", type = "16th"},
    {prefix = "Action Music", type = "amusic"},
    {prefix = "Dynamo Pack", type = "dynamo"},
    {prefix = "Dynamo", type = "dynamo"},
    {prefix = "MP3 Radio", type = "mp3p"},
}

function BATTLEBEATS.stripPackPrefix(name)
    local original = name
    for _, data in ipairs(prefixes) do
        local prefix = data.prefix
        local esc = prefix:gsub("([%(%)%[%]%-%_%.])", "%%%1")
        local pattern = "^%s*[%[%(%<]*%s*" .. esc .. "%s*[%]%)%>]*%s*[%-–—:%|%!]*%s*"

        local lname = name:lower()
        local lpattern = pattern:lower()
        local startpos, endpos = lname:find(lpattern)
        if startpos and startpos == 1 then
            local rend = endpos
            local candidate = original:sub(1, endpos):match(pattern)
            if candidate then
                rend = #candidate
            end
            local clean = original:sub(rend + 1)
            clean = clean:gsub("^[%s%p]+", ""):gsub("^%s+", ""):Trim()
            if clean ~= "" then
                return clean, data.type
            end
        end
    end
    return original:Trim(), "na"
end

local function getPackName(trackName)
    local packName = BATTLEBEATS.trackToPack[trackName]
    if not packName then return language.GetPhrase("btb.notification.unknown_pack") end
    return BATTLEBEATS.stripPackPrefix(packName)
end

local finalWidth, finalHeight = 300, 80

function BATTLEBEATS.ShowTrackNotification(trackName, inCombat, isPreviewedTrack)
    if not trackName then return end
    local override = hook.Run("BattleBeats_PreShowNotification", trackName, inCombat, isPreviewedTrack)
    if override == true then return end
    local packName = getPackName(trackName)
    trackName = BATTLEBEATS.FormatTrackName(trackName)

    if istable(override) then
        if isstring(override.trackName) then
            trackName = override.trackName
        end
        if isstring(override.packName) then
            packName = override.packName
        end
        if isnumber(override.type) then
            local otype = math.Clamp(override.type, 1, 3)
            isPreviewedTrack = (otype == 3)
            inCombat = (otype == 2)
        end
    end

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

    timer.Simple(0.1, function() -- delay to prevent animation breaking when called during Initialization
        expandPanel(panel, finalX, finalY, finalWidth, finalHeight)
    end)

    surface.SetFont("BattleBeats_Notification_Font")

    local textX = 10
    local radius = 16
    local textWidth = surface.GetTextSize(trackName)
    local isScrolling = textWidth > 280 -- scroll if text too long
    local textColor = inCombat and Color(255, 165, 0) or Color(0, 255, 0) -- green = ambient, orange = in combat, gold = preview
    textColor = isPreviewedTrack and Color(255, 215, 0) or textColor
    local lastAmplitudes = {}

    local barWidth = 8
    local bars = 24

    local progressBarX, progressBarY = 40, 60
    local progressBarWidth, progressBarHeight = 216, 5

    --local from = language.GetPhrase("btb.notification.from")

    panel.Paint = function(self, w, h)
        draw.RoundedBoxEx(radius, 0, 0, w, radius, c000200, true, true, false, false)
        surface.SetDrawColor(c000200)
        surface.DrawRect(0, radius, w, h - radius)
        draw.SimpleText("#btb.notification.now_playing", "BattleBeats_Notification_Font_Misc", progressBarX + progressBarWidth / 2, 10, color_white, TEXT_ALIGN_CENTER)

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

                    local height = math.Clamp(lastAmplitudes[i] * 60, 1, 60)
                    local x = 7 + (i - 1) * (barWidth + 4)

                    surface.SetDrawColor(textColor.r, textColor.g, textColor.b, 100)
                    surface.DrawTexturedRect(x, yBase - height, barWidth, height)
                end
            else
                lastAmplitudes = {}
            end
        end

        if isScrolling then
            textX = textX - (50 * FrameTime())
            if textX < -textWidth - 50 then
                textX = textX + textWidth + 40
            end
            draw.SimpleText(trackName, "BattleBeats_Notification_Font", textX + 30, 25, textColor, TEXT_ALIGN_LEFT)
            draw.SimpleText(trackName, "BattleBeats_Notification_Font", textX + textWidth + 70, 25, textColor, TEXT_ALIGN_LEFT)
        else
            draw.SimpleText(trackName, "BattleBeats_Notification_Font", 150, 25, textColor, TEXT_ALIGN_CENTER)
        end

        if showBar:GetBool() then
            local currentTime = IsValid(station) and station:GetTime() or 0
            local trackDuration = IsValid(station) and station:GetLength() or 0
            local progress = trackDuration > 0 and math.Clamp(currentTime / trackDuration, 0, 1) or 0

            local elapsedTime = CurTime() - self.startTime
            if math.floor(elapsedTime % 30) < 4 and showNotificationPackName:GetBool() then -- text visible for 4 seconds every 30 seconds
                draw.SimpleText(packName, "CenterPrintText", progressBarX + progressBarWidth / 2, progressBarY - 6, color_white, TEXT_ALIGN_CENTER)
            else
                draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth, progressBarHeight, c100100100)
                draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth * progress, progressBarHeight, textColor)
                draw.SimpleText(BATTLEBEATS.FormatTime(currentTime), "CenterPrintText", progressBarX - 30, progressBarY - 6, color_white, TEXT_ALIGN_LEFT)
                draw.SimpleText(BATTLEBEATS.FormatTime(trackDuration), "CenterPrintText", progressBarX + progressBarWidth + 5, progressBarY - 6, color_white, TEXT_ALIGN_LEFT)
            end
        elseif showNotificationPackName:GetBool() then
            draw.SimpleText(packName, "CenterPrintText", progressBarX + progressBarWidth / 2, progressBarY - 6, color_white, TEXT_ALIGN_CENTER)
        end
    end

    if not GetConVar("battlebeats_persistent_notification"):GetBool() then
        timer.Simple(isScrolling and 12 or 6, function()
            if IsValid(panel) then BATTLEBEATS.HideNotification() end
        end)
    end
end

local function addNotificationPreview() -- shows outline box when adjusting notif X/Y
    local startTime = CurTime()
    local finalX = notifX:GetInt()
    local finalY = notifY:GetInt()

    hook.Add("HUDPaint", "BattleBeats_NotificationPreview", function()
        surface.SetDrawColor(255, 255, 255, 100)
        surface.DrawOutlinedRect(finalX, finalY, finalWidth, finalHeight)
        draw.SimpleText("#btb.notification.position", "DermaDefault", finalX + finalWidth / 2, finalY + finalHeight / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if CurTime() - startTime > 5 then
            hook.Remove("HUDPaint", "BattleBeats_NotificationPreview")
            if IsValid(trackNotification) then
                trackNotification:SetPos(finalX, finalY)
            end
        end
    end)
end

cvars.AddChangeCallback("battlebeats_notif_x", function() addNotificationPreview() end, "BattleBeatsNotifX")
cvars.AddChangeCallback("battlebeats_notif_y", function() addNotificationPreview() end, "BattleBeatsNotifY")