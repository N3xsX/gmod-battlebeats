BATTLEBEATS.subtitles = BATTLEBEATS.subtitles or {}
BATTLEBEATS.parsedSubtitles = BATTLEBEATS.parsedSubtitles or {}

local enableSubtitles = GetConVar("battlebeats_subtitles_enabled")

local function toSeconds(t)
    local h, m, s, ms = string.match(t, "(%d+):(%d+):(%d+),(%d+)")
    return (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60 + (tonumber(s) or 0) + (tonumber(ms) or 0) / 1000
end

function BATTLEBEATS.parseSRT(songName)
    songName = string.lower(songName)
    if not BATTLEBEATS.subtitles or not BATTLEBEATS.subtitles[songName] then
        print("[parseSRT] No SRT found for: " .. songName)
        return {}
    end

    local raw = BATTLEBEATS.subtitles[songName].raw
    local lines = string.Explode("\n", raw, false)
    local subs = {}
    local i = 1

    while i <= #lines do
        local line = lines[i]

        local num = string.match(line, "^%s*(%d+)%s*$")
        if num then
            i = i + 1
            if i > #lines then break end

            local tsLine = lines[i]
            local startStr, endStr = string.match(tsLine, "(%d+:%d+:%d+,%d+)%s*-->%s*(%d+:%d+:%d+,%d+)")
            if not startStr or not endStr then -- skip this block if timestamps are wrong
                print("[parseSRT] Timestamp error on line " .. i .. ": '" .. tsLine .. "'")
                i = i + 1
                goto endd
            end

            local startSec = toSeconds(startStr)
            local endSec = toSeconds(endStr)

            i = i + 1
            local textLines = {}

            while i <= #lines do
                local textLine = lines[i]
                if string.match(textLine, "^%s*$") then
                    i = i + 1
                    break -- empty line means end of subtitle block
                end
                table.insert(textLines, textLine)
                i = i + 1
            end

            local text = table.concat(textLines, "\n") -- join text lines
            if #textLines > 0 then
                table.insert(subs, {
                    start = startSec,
                    ['end'] = endSec,
                    text = text
                })
            end
        else
            i = i + 1
        end

        ::endd::
    end

    table.sort(subs, function(a, b) return a.start < b.start end) -- sort subtitles by start time
    table.Empty(BATTLEBEATS.subtitles[songName])
    BATTLEBEATS.parsedSubtitles[songName] = subs
    print("[parseSRT] Parsed '" .. songName .. "' | Subtitles: " .. #subs .. " | Input Lines: " .. #lines)
    return subs
end

local activeSubtitles = nil
local currentLine = nil
local currentChannel = nil
local lastLine = nil
local transitionStart = 0
local incomingText = false

local function easeInOut(x)
    return x < 0.5 and 2 * x * x or 1 - math.pow(-2 * x + 2, 2) / 2
end

local function drawCenteredText(text, font, y, alpha)
    if not text or text == "" then return end

    surface.SetFont(font)
    local lines = string.Explode("\n", text, false)
    local totalHeight = 0

    for _, line in ipairs(lines) do
        local _, h = surface.GetTextSize(line)
        totalHeight = totalHeight + h
    end

    y = y - totalHeight / 2

    for _, line in ipairs(lines) do
        local w, h = surface.GetTextSize(line)
        local x = (ScrW() - w) / 2

        surface.SetTextColor(0, 0, 0, alpha * 0.5)
        surface.SetTextPos(x + 1, y + 1)
        surface.DrawText(line)

        surface.SetTextColor(255, 255, 255, alpha)
        surface.SetTextPos(x, y)
        surface.DrawText(line)

        y = y + h * 0.8
    end
end

local elapsed = 0
local fadeLine = nil
local fadeStart = 0
local centerY = ScrH() - 200
local spacing = 40
local clamp = math.Clamp
local start = false
local function drawSubtitles()
    if not enableSubtitles:GetBool() then return end
    if BATTLEBEATS.currentStation ~= currentChannel and not fadeLine then return end
    if not activeSubtitles or not currentLine or not IsValid(currentChannel) then
        if fadeLine then
            local fadeProgress = (CurTime() - fadeStart) / 1
            local fadeAlpha = 255 * (1 - clamp(fadeProgress, 0, 1))
            if fadeAlpha > 0 then
                drawCenteredText(fadeLine.text, "BattleBeats_Subtitles", centerY, fadeAlpha)
                return
            else
                fadeLine = nil
            end
        end
        return
    end

    --local elapsed = currentChannel:GetTime() or 0
    local curTime = CurTime()

    if lastLine ~= currentLine then
        lastLine = currentLine
        transitionStart = curTime
    end

    -- transition progress from 0 to 1 over 0.7 seconds
    local t = clamp((curTime - transitionStart) / 0.7, 0, 1)
    local p = easeInOut(t)

    -- find previous subtitle line (the one before current)
    local prevIndex = nil
    for i, sub in ipairs(activeSubtitles) do
        if sub == currentLine then
            prevIndex = i - 1; break
        end
    end

    -- fade out the previous line smoothly as the new one fades in
    local prevLine = prevIndex and activeSubtitles[prevIndex]
    if prevLine then
        local timeSincePrevEnd = elapsed - prevLine["end"]
        if timeSincePrevEnd > 2 or start then
            start = false
            prevLine = nil
        end
    end
    if prevLine and t < 1 then
        local prevAlpha = 255 * (1 - p)
        local prevY = centerY - spacing * p
        drawCenteredText(prevLine.text, "BattleBeats_Subtitles", prevY, prevAlpha)
    end

    -- draw the current subtitle line, sliding into the center position
    local currY = centerY + spacing * (1 - p)
    drawCenteredText(currentLine.text, "BattleBeats_Subtitles", currY, 255)

    -- find the next subtitle line (upcoming)
    local nextIndex = nil
    for i, sub in ipairs(activeSubtitles) do
        if sub == currentLine then
            nextIndex = i + 1; break
        end
    end

    -- handle the "incoming" next line preview animation
    local nextLine = nextIndex and activeSubtitles[nextIndex]
    if nextLine then
        local timeToNext = nextLine.start - elapsed
        if timeToNext <= 2 then
            incomingText = true
            -- s increases from 0 to 1 as the next line approaches
            local s = easeInOut(1 - clamp(timeToNext / 0.7, 0, 1))
            local nextAlpha = 255 * s
            local nextY = centerY + spacing + (1 - s) * 20
            drawCenteredText(nextLine.text, "BattleBeats_Subtitles", nextY, nextAlpha)
        else
            incomingText = false
        end
    end
end

local function updateSubtitleLine()
    if not enableSubtitles:GetBool() then return end
    if BATTLEBEATS.currentStation ~= currentChannel then return end
    if not activeSubtitles or not currentChannel or not IsValid(currentChannel) then return end

    elapsed = currentChannel:GetTime()
    if not elapsed then return end

    if currentLine and (elapsed > currentLine["end"]) and not incomingText then
        fadeLine = currentLine
        fadeStart = CurTime()
        currentLine = nil
    end

    if not incomingText then
        currentLine = nil
    end

    for _, sub in ipairs(activeSubtitles) do
        if elapsed >= sub.start and elapsed <= sub["end"] then
            currentLine = sub
            break
        end
    end

    if elapsed > (activeSubtitles[#activeSubtitles]["end"] + 0.1) then
        fadeLine = currentLine
        fadeStart = CurTime()
        lastLine = nil
        activeSubtitles = nil
        currentLine = nil
        currentChannel = nil
        elapsed = 0
        hook.Remove("Think", "BattleBeats_UpdateSubtitles")
        hook.Remove("HUDPaint", "BattleBeats_DrawSubtitles")
    end
end

cvars.AddChangeCallback("battlebeats_subtitles_enabled", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        hook.Remove("Think", "BattleBeats_UpdateSubtitles")
        hook.Remove("HUDPaint", "BattleBeats_DrawSubtitles")
    elseif tonumber(newValue) == 1 and activeSubtitles then
        hook.Add("Think", "BattleBeats_UpdateSubtitles", updateSubtitleLine)
        hook.Add("HUDPaint", "BattleBeats_DrawSubtitles", drawSubtitles)
    end
end)

function BATTLEBEATS.StartSubtitles(track, channel)
    local songName = string.lower(track)
    local subs = BATTLEBEATS.parsedSubtitles and BATTLEBEATS.parsedSubtitles[songName]
    if not subs or #subs == 0 then
        print("[StartSubtitles] No subtitles found for: " .. songName)
        return
    end
    if not channel or not IsValid(channel) then
        print("[StartSubtitles] Invalid or missing audio channel for: " .. songName)
        return
    end

    hook.Add("Think", "BattleBeats_UpdateSubtitles", updateSubtitleLine)
    hook.Add("HUDPaint", "BattleBeats_DrawSubtitles", drawSubtitles)

    start = true
    activeSubtitles = subs
    currentChannel = channel
    currentLine = nil
    lastLine = nil
    fadeLine = nil
    elapsed = 0

    print("[StartSubtitles] Now displaying subtitles for: " .. songName)
end