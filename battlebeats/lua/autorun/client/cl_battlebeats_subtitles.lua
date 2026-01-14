BATTLEBEATS.subtitles = BATTLEBEATS.subtitles or {}
BATTLEBEATS.parsedSubtitles = BATTLEBEATS.parsedSubtitles or {}

local defaultY = tostring(ScrH() - 200)

local enableSubtitles = GetConVar("battlebeats_subtitles_enabled")
local subtitlesMode = CreateClientConVar("battlebeats_subtitles_mode", 1, true, false)
local staticSubtitles = CreateClientConVar("battlebeats_subtitles_static", 0, true, false)
local subtitlesYpos = CreateClientConVar("battlebeats_subtitles_y", defaultY, true, false, "", 0, ScrH())

local debugMode = GetConVar("battlebeats_debug_mode")
local function debugPrint(...)
    if debugMode:GetBool() then print("[BattleBeats Debug] " .. ...) end
end

local function toSeconds(t)
    local h, m, s, ms = string.match(t, "(%d+):(%d+):(%d+),(%d+)")
    return (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60 + (tonumber(s) or 0) + (tonumber(ms) or 0) / 1000
end

local function parseBlocks(rawLines, parseFunc)
    local subs = {}
    local i = 1

    while i <= #rawLines do
        local startSec, endSec, text, newIndex = parseFunc(rawLines, i)
        if startSec then
            table.insert(subs, {
                start = startSec,
                ['end'] = endSec,
                text = text
            })
        end

        if not newIndex or newIndex <= i then
            i = i + 1
        else
            i = newIndex
        end
    end

    table.sort(subs, function(a, b) return a.start < b.start end)
    return subs
end

local function parseSRTBlock(lines, i)
    local line = lines[i]
    local num = string.match(line, "^%s*(%d+)%s*$")
    if not num then return nil, nil, nil, i + 1 end

    i = i + 1
    if i > #lines then return nil end

    local tsLine = lines[i]
    local startStr, endStr = string.match(tsLine, "(%d+:%d+:%d+,%d+)%s*-->%s*(%d+:%d+:%d+,%d+)")
    if not startStr or not endStr then
        debugPrint("[parseSRT] Timestamp error on line " .. i .. ": '" .. tsLine .. "'")
        return nil, nil, nil, i + 1
    end

    local startSec = toSeconds(startStr)
    local endSec = toSeconds(endStr)

    i = i + 1
    local textLines = {}

    while i <= #lines do
        local t = lines[i]
        if string.match(t, "^%s*$") then
            i = i + 1
            break
        end
        table.insert(textLines, t)
        i = i + 1
    end

    local text = table.concat(textLines, "\n")
    return startSec, endSec, text, i
end

function BATTLEBEATS.parseSRT(songName)
    songName = string.lower(songName)

    if not BATTLEBEATS.subtitles or not BATTLEBEATS.subtitles[songName] then
        debugPrint("[parseSRT] No SRT found for: " .. songName)
        return {}
    end

    local raw = BATTLEBEATS.subtitles[songName].raw
    local lines = string.Explode("\n", raw)

    local subs = parseBlocks(lines, parseSRTBlock)
    table.Empty(BATTLEBEATS.subtitles[songName])

    BATTLEBEATS.parsedSubtitles[songName] = subs
    debugPrint("[parseSRT] Parsed '" .. songName .. "' | Subtitles: " .. #subs .. " | Input Lines: " .. #lines)
    return subs
end

local function parse16thBlock(frames)
    local subs = {}

    for i, f in ipairs(frames) do
        local start = f.time
        local text = f.lyric or ""
        local nextFrame = frames[i + 1]

        local finish
        if nextFrame then
            finish = math.min(nextFrame.time - 0.01, start + 5)
        else
            finish = start + 5
        end

        table.insert(subs, {
            start = start,
            ['end'] = finish,
            text = text
        })
    end

    table.sort(subs, function(a, b) return a.start < b.start end)
    return subs
end

function BATTLEBEATS.parse16thNote(songName)
    songName = string.lower(songName)

    if not BATTLEBEATS.subtitles or not BATTLEBEATS.subtitles[songName] then
        debugPrint("[parse16th] No 16th-note data for: " .. songName)
        return {}
    end

    local data = BATTLEBEATS.subtitles[songName]

    if not data.keyframes then
        debugPrint("[parse16th] Missing keyframes for: " .. songName)
        return {}
    end

    local frames = data.keyframes
    local subs = parse16thBlock(frames)
    table.Empty(BATTLEBEATS.subtitles[songName])

    BATTLEBEATS.parsedSubtitles[songName] = subs
    debugPrint("[parse16th] Parsed '" .. songName .. "' | Blocks: " .. #subs)
    return subs
end

local activeSubtitles = nil
local currentLine = nil
local currentChannel = nil
local lastLine = nil
local transitionStart = 0
local incomingText = false

local activeWorldSubtitles = {}

local function easeInOut(x)
    return x < 0.5 and 2 * x * x or 1 - math.pow(-2 * x + 2, 2) / 2
end

local function drawMultilineText(text, x, y)
    local lines = string.Explode("\n", text)
    local lineH = select(2, surface.GetTextSize("A")) + 2
    for i, line in ipairs(lines) do
        local lw = surface.GetTextSize(line)
        surface.SetTextPos(x - lw / 2, y + (i - 1) * lineH)
        surface.DrawText(line)
    end
    return #lines * lineH
end

local texGradient = surface.GetTextureID("gui/center_gradient")
local function draw3DSubtitle(sub, alpha)
    if not sub or not sub.text or sub.text == "" then return end
    local pos = sub.pos
    local ang = sub.ang
    local scale = sub.scale or 0.08
    local ignoreZ = sub.ignoreZ
    if not staticSubtitles:GetBool() then
        local ply = LocalPlayer()
        if IsValid(ply) then
            sub.lastPlayerPos = sub.lastPlayerPos or ply:GetPos()
            local currentPos = ply:GetPos()
            local delta = currentPos - sub.lastPlayerPos
            pos = pos + delta * 0.9
            sub.lastPlayerPos = currentPos
        end
    end

    cam.Start3D2D(pos, ang, scale)
    cam.IgnoreZ(ignoreZ)
    surface.SetFont("BattleBeats_Subtitles")

    local lines = string.Explode("\n", sub.text)
    local maxW = 0
    local lineH = select(2, surface.GetTextSize("A")) + 2
    for _, line in ipairs(lines) do
        local lw = surface.GetTextSize(line)
        maxW = math.max(maxW, lw)
    end
    local totalH = #lines * lineH

    surface.SetDrawColor(0, 0, 0, alpha * 0.65)
    surface.SetTexture(texGradient)
    surface.DrawTexturedRect(-maxW / 2 - 150, -totalH / 2 - 8, maxW + 300, totalH + 16)

    for dx = -2, 2, 2 do
        for dy = -2, 2, 2 do
            if dx ~= 0 or dy ~= 0 then
                surface.SetTextColor(0, 0, 0, alpha)
                drawMultilineText(sub.text, 0 + dx, -totalH / 2 + dy)
            end
        end
    end

    surface.SetTextColor(255, 255, 255, alpha)
    drawMultilineText(sub.text, 0, -totalH / 2)
    cam.IgnoreZ(false)
    cam.End3D2D()
    sub.pos = pos
end

local function spawnWorldSubtitle(text, lifetime)
    local ply = LocalPlayer()
    local eyePos = ply:EyePos()
    local eyeAng = ply:EyeAngles()
    local forward = eyeAng:Forward()
    local right = eyeAng:Right()
    local up = eyeAng:Up()
    local offset = forward * math.random(700, 900) + up * math.random(-20, 200) + right * math.random(-300, 300)
    local pos = eyePos + offset
    local dir = (eyePos - pos):GetNormalized()
    local ang = dir:Angle()
    ang:RotateAroundAxis(ang:Right(), -90)
    ang:RotateAroundAxis(ang:Up(), 90)

    local id = #activeWorldSubtitles + 1
    activeWorldSubtitles[id] = {
        text = text,
        pos = pos,
        ang = ang,
        scale = 0.60 + math.random() * 0.05,
        alpha = 255,
        birth = CurTime(),
        death = CurTime() + (lifetime or 5),
        ignoreZ = true,
        lastPlayerPos = ply:GetPos()
    }

    return id
end

local fadeInTime = 0.2
local fadeOutTime = 1.5
local function drawAllWorldSubtitles()
    if not enableSubtitles:GetBool() or subtitlesMode:GetInt() == 0 then return end
    local ct = CurTime()
    for id, sub in pairs(activeWorldSubtitles) do
        if ct > sub.death then
            activeWorldSubtitles[id] = nil
            continue
        end
        local age = ct - sub.birth
        local alpha = 255
        if age < fadeInTime then
            local progress = age / fadeInTime
            alpha = 255 * easeInOut(progress)
        elseif ct > sub.death - fadeOutTime then
            local progress = (ct - (sub.death - fadeOutTime)) / fadeOutTime
            alpha = 255 * (1 - easeInOut(progress))
        end
        draw3DSubtitle(sub, alpha)
    end
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
local centerY = subtitlesYpos:GetInt()
local spacing = 40
local clamp = math.Clamp
local start = false
local function drawSubtitles()
    if not enableSubtitles:GetBool() or subtitlesMode:GetInt() == 1 then return end
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

    local currY = centerY + spacing * (1 - p)
    drawCenteredText(currentLine.text, "BattleBeats_Subtitles", currY, 255)

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
            local s = easeInOut(1 - clamp(timeToNext / 0.7, 0, 1))
            local nextAlpha = 255 * s
            local nextY = centerY + spacing + (1 - s) * 20
            drawCenteredText(nextLine.text, "BattleBeats_Subtitles", nextY, nextAlpha)
        else
            incomingText = false
        end
    end
end

local lastSpawnedLine = nil
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
            if currentLine ~= lastSpawnedLine then
                spawnWorldSubtitle(currentLine.text, currentLine["end"] - elapsed + 1)
                lastSpawnedLine = currentLine
            end
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
        activeWorldSubtitles = {}
        lastSpawnedLine = nil
        hook.Remove("Think", "BattleBeats_UpdateSubtitles")
        hook.Remove("HUDPaint", "BattleBeats_DrawSubtitles")
        hook.Remove("PostDrawTranslucentRenderables", "BattleBeats_WorldSubtitles")
    end
end

cvars.AddChangeCallback("battlebeats_subtitles_enabled", function(_, _, newValue)
    if tonumber(newValue) == 0 then
        hook.Remove("Think", "BattleBeats_UpdateSubtitles")
        hook.Remove("HUDPaint", "BattleBeats_DrawSubtitles")
        hook.Remove("PostDrawTranslucentRenderables", "BattleBeats_WorldSubtitles")
    elseif tonumber(newValue) == 1 and activeSubtitles then
        hook.Add("Think", "BattleBeats_UpdateSubtitles", updateSubtitleLine)
        if subtitlesMode:GetInt() == 0 then
            hook.Add("HUDPaint", "BattleBeats_DrawSubtitles", drawSubtitles)
        else
            hook.Add("PostDrawTranslucentRenderables", "BattleBeats_WorldSubtitles", drawAllWorldSubtitles)
        end
    end
end)

cvars.AddChangeCallback("battlebeats_subtitles_mode", function(_, _, newValue)
    if tonumber(newValue) == 0 and activeSubtitles then
        hook.Remove("HUDPaint", "BattleBeats_DrawSubtitles")
        hook.Remove("PostDrawTranslucentRenderables", "BattleBeats_WorldSubtitles")
        hook.Add("HUDPaint", "BattleBeats_DrawSubtitles", drawSubtitles)
    elseif tonumber(newValue) == 1 and activeSubtitles then
        hook.Remove("HUDPaint", "BattleBeats_DrawSubtitles")
        hook.Remove("PostDrawTranslucentRenderables", "BattleBeats_WorldSubtitles")
        hook.Add("PostDrawTranslucentRenderables", "BattleBeats_WorldSubtitles", drawAllWorldSubtitles)
    end
end)

function BATTLEBEATS.StartSubtitles(track, channel)
    local songName = string.lower(track)
    local subs = BATTLEBEATS.parsedSubtitles and BATTLEBEATS.parsedSubtitles[songName]
    if not subs or #subs == 0 then
        debugPrint("[StartSubtitles] No subtitles found for: " .. songName)
        return
    end
    if not channel or not IsValid(channel) then
        debugPrint("[StartSubtitles] Invalid or missing audio channel for: " .. songName)
        return
    end

    hook.Add("Think", "BattleBeats_UpdateSubtitles", updateSubtitleLine)
    if subtitlesMode:GetInt() == 0 then
        hook.Add("HUDPaint", "BattleBeats_DrawSubtitles", drawSubtitles)
    else
        hook.Add("PostDrawTranslucentRenderables", "BattleBeats_WorldSubtitles", drawAllWorldSubtitles)
    end

    start = true
    activeSubtitles = subs
    currentChannel = channel
    currentLine = nil
    lastLine = nil
    fadeLine = nil
    elapsed = 0
    activeWorldSubtitles = {}
    lastSpawnedLine = nil

    debugPrint("[StartSubtitles] Now displaying subtitles for: " .. songName)
end

local function addSubtitlesPreview(newValue)
    local startTime = CurTime()
    local finalX = ScrW() / 2 - 300
    local finalY = subtitlesYpos:GetInt()

    hook.Add("HUDPaint", "BattleBeats_NotificationPreview", function()
        surface.SetDrawColor(255, 255, 255, 100)
        surface.DrawOutlinedRect(finalX, finalY - 75, 600, 150)
        draw.SimpleText("#btb.options.sub.sub_height_noti_text", "DermaDefault", finalX + 600 / 2, (finalY + 150 / 2) - 75, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if CurTime() - startTime > 5 then
            hook.Remove("HUDPaint", "BattleBeats_NotificationPreview")
            centerY = newValue
        end
    end)
end

cvars.AddChangeCallback("battlebeats_subtitles_y", function(_, _, newValue)
    addSubtitlesPreview(newValue)
end)