local btb = BATTLEBEATS

btb.subtitles = btb.subtitles or {}

local enableSubtitles = GetConVar("battlebeats_subtitles_enabled")
local subtitlesMode = CreateClientConVar("battlebeats_subtitles_mode", 0, true, false)
local staticSubtitles = CreateClientConVar("battlebeats_subtitles_static", 0, true, false)
local subtitlesYpos = CreateClientConVar("battlebeats_subtitles_y", tostring(ScrH() - 200), true, false, "", 0, ScrH())
local subtitlesLang = CreateClientConVar("battlebeats_subtitles_lang", "auto", true, false)
local subtitlesLang2 = CreateClientConVar("battlebeats_subtitles_lang2", "original", true, false)
--local surfaceMode = CreateClientConVar("battlebeats_subtitles_surface", 1, true, false) -- ill may add it later

local session
local clamp = math.Clamp
local cd = "battlebeats/subtitles/cache/"
local langdef = "en"
local langC = {}
local function easeInOut(x)
    return x < 0.5 and 2 * x * x or 1 - math.pow(-2 * x + 2, 2) / 2
end

local function clearCache()
    langC = {}
    for _, f in ipairs(file.Find(cd .. "*.dat", "DATA")) do
        file.Delete(cd .. f)
    end
end

local function normalizeLangs(v)
    if not istable(v) then return end
    if v[1] ~= nil then return {[langdef] = v} end
    return v
end

local function writeCache(name, langs)
    if not next(langs) then return false end
    local json = util.TableToJSON(langs, false)
    local data = json and util.Compress(json)
    if not data then return false end
    file.Write(cd .. name .. ".dat", data)
    langC[name] = nil
    btb.setTrackData(name, "hasSub", true, true)
    return true
end

function btb.readCache(name)
    local raw = file.Read(cd .. name .. ".dat", "DATA")
    if not raw then return end
    local json = util.Decompress(raw)
    return json and normalizeLangs(util.JSONToTable(json))
end

local function toSeconds(str)
    local h, m, s, frac = string.match(str, "(%d+):(%d+):(%d+)[,.](%d+)")
    return (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60 + (tonumber(s) or 0) +
    (tonumber("0." .. (frac or "0")) or 0)
end

local function cleanText(text)
    text = text:gsub("<[^>]*>", ""):gsub("{\\[^}]*}", "")
    return string.Trim(text)
end

local function parseSRT(raw)
    raw = raw:gsub("\r", ""):gsub("^\239\187\191", "")

    local subs, cur = {}, nil
    for line in string.gmatch(raw .. "\n", "(.-)\n") do
        local s, e = string.match(line, "(%d+:%d+:%d+[,.]%d+)%s*%-%->%s*(%d+:%d+:%d+[,.]%d+)")
        if s then
            cur = { start = toSeconds(s), ["end"] = toSeconds(e), lines = {} }
            subs[#subs + 1] = cur
        elseif cur then
            if string.match(line, "^%s*$") then
                cur = nil
            else
                cur.lines[#cur.lines + 1] = line
            end
        end
    end

    local out = {}
    for _, c in ipairs(subs) do
        local text = cleanText(table.concat(c.lines, "\n"))
        if text ~= "" then
            out[#out + 1] = { start = c.start, ["end"] = c["end"], text = text }
        end
    end
    table.sort(out, function(a, b) return a.start < b.start end)
    return out
end

local function parseKeyframes(frames)
    local sorted = {}
    for _, f in ipairs(frames or {}) do
        if isnumber(f.time) then sorted[#sorted + 1] = f end
    end
    table.sort(sorted, function(a, b) return a.time < b.time end)

    local subs = {}
    for i, f in ipairs(sorted) do
        local finish = f.time + 5
        local nextFrame = sorted[i + 1]
        if nextFrame then finish = math.min(nextFrame.time - 0.01, finish) end

        local text = cleanText(f.lyric or "")
        if text ~= "" then
            subs[#subs + 1] = { start = f.time, ["end"] = finish, text = text }
        end
    end
    return subs
end

local lv = {
    bg = true,
    cs = true,
    da = true,
    de = true,
    el = true,
    en = true,
    ["en-pt"] = true,
    ["es-es"] = true,
    et = true,
    fi = true,
    fr = true,
    he = true,
    hr = true,
    hu = true,
    it = true,
    ja = true,
    ko = true,
    lt = true,
    nl = true,
    no = true,
    pl = true,
    ["pt-br"] = true,
    ["pt-pt"] = true,
    ru = true,
    sk = true,
    ["sv-se"] = true,
    th = true,
    tr = true,
    uk = true,
    vi = true,
    ["zh-cn"] = true,
    ["zh-tw"] = true
}

function btb.RegisterSubtitles(p, data)
    if isstring(p) then p = { name = p } end
    assert(istable(p), "invalid subtitle properties")
    assert(isstring(p.name) and p.name ~= "", "invalid subtitle name")
    p.name = string.lower(p.name)

    if isstring(data) then data = { raw = data } end
    assert(istable(data), "invalid subtitle data")
    assert(isstring(data.raw) or istable(data.keyframes), "missing subtitle data")
    data.offset = tonumber(p.offset) or 0
    data.original = p.langoriginal == true or data.langoriginal == true

    local lang = string.lower(string.Trim(tostring(p.lang or data.lang or langdef)))
    if lang == "" then lang = langdef end
    assert(lang == langdef or lv[lang], "invalid subtitle language: " .. lang)

    local e = btb.subtitles[p.name] or {}
    if e[lang] then error("duplicate subtitles: " .. p.name .. " [" .. lang .. "]", 2) end
    e[lang] = data
    btb.subtitles[p.name] = e
end

function btb.GetSubtitleLanguages(track)
    track = string.lower(track)
    local list = langC[track]
    if list then return list end
    local langs = btb.readCache(track)
    if langs then
        list = {}
        for lang in pairs(langs) do list[#list + 1] = lang end
        table.sort(list)
    else
        list = {}
    end
    langC[track] = list
    return list
end

local function saveSubData()
    if not game.SinglePlayer() then return end

    local data = {}
    for _, f in ipairs(file.Find(cd .. "*.dat", "DATA")) do
        local name = string.StripExtension(f)
        local langs = btb.readCache(name)
        if langs and next(langs) then data[name] = langs end
    end

    local json = util.TableToJSON(data, false)
    local packed = json and util.Compress(json)
    if not packed then
        btb.print(2, "Subtitles", "Failed to serialize sub_data.dat")
        return
    end
    file.Write("battlebeats/subtitles/sub_data.dat", packed)
    btb.print(1, "Subtitles", "Saved", table.Count(data), "tracks to sub_data.dat")
end

local function loadSubServer()
    if game.SinglePlayer() then return end

    local raw = file.Read("battlebeats/subtitles/sub_data.dat", "DATA")
    local json = raw and util.Decompress(raw)
    local data = json and util.JSONToTable(json)
    if not data then return end

    local n = 0
    for name, langs in pairs(data) do
        langs = normalizeLangs(langs)
        if langs and not file.Exists(cd .. name .. ".dat", "DATA") and writeCache(name, langs) then
            n = n + 1
        end
    end
    btb.print(1, "Subtitles", "Loaded", n, "tracks from sub_data.dat")
end

function btb.InitializeSubtitles()
    clearCache()

    local built = 0
    for name, langs in pairs(btb.subtitles) do
        if istable(langs) and (langs.raw ~= nil or langs.keyframes ~= nil) then
            langs = { [langdef] = langs }
        end

        local parsed = {}
        for lang, d in pairs(istable(langs) and langs or {}) do
            local subs
            if istable(d) and isstring(d.raw) then
                subs = parseSRT(d.raw)
            elseif istable(d) and istable(d.keyframes) then
                subs = parseKeyframes(d.keyframes)
            end
            if subs and #subs > 0 then
                local off = tonumber(d.offset) or 0
                if off ~= 0 then
                    for i, c in ipairs(subs) do
                        if c.start + off < 0 then
                            btb.print(2, "Subtitles", "Subtitle offset moves cue", i, "start before 0:", name, "[", lang, "] start:", c.start + off)
                        end
                    end
                end
                parsed[lang] = { cues = subs, offset = off, orig = d.original == true or nil }
            end
        end

        if writeCache(string.lower(name), parsed) then
            built = built + 1
            btb.print(3, "Subtitles", "Parsed '", name, "' | Languages:", table.Count(parsed))
        end
    end

    table.Empty(btb.subtitles)
    loadSubServer()
    btb.print(1, "Subtitles", "Built", built, "subtitle caches")
end

gameevent.Listen("client_disconnect")
hook.Add("client_disconnect", "BattleBeats_SaveSubtitles", function()
    session = nil
    saveSubData()
    clearCache()
end)

hook.Add("ShutDown", "BattleBeats_ClearSubtitles", function()
    clearCache()
end)

local function pickLang(langs, v)
    v = string.lower(string.Trim(v or ""))
    if v == "original" then
        local list = {}
        for lang, d in pairs(langs) do
            if d.orig then list[#list + 1] = lang end
        end
        table.sort(list)
        return list[1]
    end
    if v == "" or v == "auto" or v == "default" then
        local cv = GetConVar("gmod_language")
        v = cv and string.lower(cv:GetString()) or langdef
    end
    return langs[v] and v or nil
end

local function resolveLanguages(langs)
    local available = {}
    for lang in pairs(langs) do available[#available + 1] = lang end
    if #available == 0 then return end
    table.sort(available)

    local primary = pickLang(langs, subtitlesLang:GetString()) or pickLang(langs, "auto") or (langs[langdef] and langdef) or available[1]
    local secondary
    local want2 = string.lower(string.Trim(subtitlesLang2:GetString()))
    if want2 ~= "" and want2 ~= "none" then
        secondary = pickLang(langs, want2)
        if secondary == primary then secondary = nil end
    end

    return primary, secondary
end

local function mergeCues(a, b)
    local cues, cueOf, used = {}, {}, {}
    local j0 = 1
    local prev, prevJ

    for i, ca in ipairs(a) do
        local bestJ, bestOverlap
        if b then
            while b[j0] and b[j0]["end"] <= ca.start do j0 = j0 + 1 end
            for j = j0, #b do
                local cb = b[j]
                if cb.start >= ca["end"] then break end
                local overlap = math.min(ca["end"], cb["end"]) - math.max(ca.start, cb.start)
                if overlap > 0 and (not bestOverlap or overlap > bestOverlap) then
                    bestJ, bestOverlap = j, overlap
                end
            end
        end

        if bestJ then used[bestJ] = true end

        if bestJ and bestJ == prevJ then
            prev["end"] = math.max(prev["end"], ca["end"])
            prev.text = prev.text .. "\n" .. ca.text
        else
            prev = { start = ca.start, ["end"] = ca["end"], text = ca.text }
            if bestJ then prev.t2 = { { s = b[bestJ].start, t = b[bestJ].text } } end
            cues[#cues + 1] = prev
            prevJ = bestJ
        end
        cueOf[i] = prev
    end

    if b then
        local extra, i0 = {}, 1

        for j, cb in ipairs(b) do
            if not used[j] then
                while a[i0] and a[i0]["end"] <= cb.start do i0 = i0 + 1 end

                local bestI, bestOverlap
                for i = i0, #a do
                    local ca = a[i]
                    if ca.start >= cb["end"] then break end
                    local overlap = math.min(ca["end"], cb["end"]) - math.max(ca.start, cb.start)
                    if overlap > 0 and (not bestOverlap or overlap > bestOverlap) then
                        bestI, bestOverlap = i, overlap
                    end
                end

                if bestI then
                    local c = cueOf[bestI]
                    c.t2 = c.t2 or {}
                    c.t2[#c.t2 + 1] = { s = cb.start, t = cb.text }
                else
                    extra[#extra + 1] = { start = cb.start, ["end"] = cb["end"], text = cb.text }
                end
            end
        end

        for _, c in ipairs(extra) do cues[#cues + 1] = c end
        table.sort(cues, function(x, y) return x.start < y.start end)
    end

    for _, c in ipairs(cues) do
        if c.t2 then
            table.sort(c.t2, function(x, y) return x.s < y.s end)
            local parts, seen = {}, { [c.text] = true }
            for _, p in ipairs(c.t2) do
                if not seen[p.t] then
                    seen[p.t] = true
                    parts[#parts + 1] = p.t
                end
            end
            c.text2 = #parts > 0 and table.concat(parts, "\n") or nil
            c.t2 = nil
        end
    end

    local out = {}
    for _, c in ipairs(cues) do
        local p = out[#out]
        if p and p.text == c.text and p.text2 == c.text2 and c.start - p["end"] <= 1 then
            p["end"] = math.max(p["end"], c["end"])
        else
            out[#out + 1] = c
        end
    end

    return out
end

local function getCues(entry)
    local off = tonumber(entry.offset) or 0
    if off == 0 then return entry.cues end
    local out = {}
    for i, c in ipairs(entry.cues) do
        out[i] = { start = c.start + off, ["end"] = c["end"] + off, text = c.text }
    end
    return out
end

local trans = 0.7
local function buildCues(langs)
    local primary, secondary = resolveLanguages(langs)
    if not primary then return {} end
    local cues = mergeCues(getCues(langs[primary]), secondary and getCues(langs[secondary]))
    for _, c in ipairs(cues) do
        c.start = math.max(0, c.start - 0.3)
    end
    for i, c in ipairs(cues) do
        local before = cues[i - 1] and (c.start - cues[i - 1].start) or math.huge
        local after  = cues[i + 1] and (cues[i + 1].start - c.start) or math.huge
        c.dur = clamp(math.min(before, after) * 0.5, 0.3, trans)
    end
    return cues
end

-- MARK: Layout

local layoutEpoch = 0
hook.Add("OnScreenSizeChanged", "BattleBeats_SubtitlesRelayout", function()
    layoutEpoch = layoutEpoch + 1
end)

local function wrapText(text, maxW)
    local out = {}
    for _, para in ipairs(string.Explode("\n", text, false)) do
        local line = ""
        for word in string.gmatch(para, "%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if line ~= "" and surface.GetTextSize(try) > maxW then
                out[#out + 1] = line
                line = word
            else
                line = try
            end
        end
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

local lgap = 0.9
local langgap = 0.3
local function getLayout(cue)
    local lay = cue.layout
    if lay and lay.epoch == layoutEpoch then return lay end

    surface.SetFont("BattleBeats_Subtitles")
    local _, fh = surface.GetTextSize("Ag")
    local step = math.floor(fh * lgap)
    local maxW = ScrW() * 0.6

    local primary = wrapText(cue.text, maxW)
    local secondary = cue.text2 and wrapText(cue.text2, maxW) or {}
    local gap = (#primary > 0 and #secondary > 0) and math.floor(fh * langgap) or 0

    local lines, width = {}, 0
    local function add(list, sec)
        for _, text in ipairs(list) do
            local w = surface.GetTextSize(text)
            width = math.max(width, w)
            lines[#lines + 1] = {text = text, w = w, y = #lines * step + (sec and gap or 0), sec = sec}
        end
    end
    add(primary, false)
    add(secondary, true)

    lay = {lines = lines, w = width, h = math.max(#lines - 1, 0) * step + fh + gap, epoch = layoutEpoch}
    cue.layout = lay
    return lay
end

local langalpha = 0.7
local function drawLines(lay, cx, top, alpha, outline)
    surface.SetFont("BattleBeats_Subtitles")

    for _, ln in ipairs(lay.lines) do
        local a = ln.sec and alpha * langalpha or alpha
        local x = cx - ln.w / 2
        local y = top + ln.y

        if outline then
            surface.SetTextColor(0, 0, 0, a)
            for dx = -outline, outline, outline do
                for dy = -outline, outline, outline do
                    if dx ~= 0 or dy ~= 0 then
                        surface.SetTextPos(x + dx, y + dy)
                        surface.DrawText(ln.text)
                    end
                end
            end
        else
            surface.SetTextColor(0, 0, 0, a * 0.5)
            surface.SetTextPos(x + 1, y + 1)
            surface.DrawText(ln.text)
        end

        local c = ln.sec and 215 or 255
        surface.SetTextColor(c, c, c, a)
        surface.SetTextPos(x, y)
        surface.DrawText(ln.text)
    end
end

-- MARK: Time

local function lastStarted(cues, t)
    local lo, hi = 0, #cues
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        if cues[mid].start <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end

local function cueAlpha(cues, i, t)
    local c = cues[i]
    local d = c.dur or trans
    local alpha = easeInOut(clamp((t - (c.start - d)) / d, 0, 1))

    local nxt = cues[i + 1]
    if nxt and nxt.start - c["end"] <= 2 then
        alpha = alpha * (1 - easeInOut(clamp((t - nxt.start) / (nxt.dur or trans), 0, 1)))
    else
        alpha = alpha * (1 - easeInOut(clamp((t - c["end"]) / 1, 0, 1)))
    end

    return alpha
end

local function heightOf(cues, i)
    local c = cues[i]
    return c and getLayout(c).h or 0
end

local function drawCue(cues, i, cx, cy, t, master)
    local cue = cues[i]
    if not cue then return end
    local a = cueAlpha(cues, i, t) * master * 255
    if a < 1 then return end
    local lay = getLayout(cue)
    drawLines(lay, cx, cy - lay.h / 2, a)
end

-- MARK: Cur seesion

local function updSub(s)
    local ch = s.channel
    if not s.stopAt then
        local alive = IsValid(ch) and (btb.currentStation == ch or CurTime() - s.startedAt < 1)
        if alive then
            s.t = ch:GetTime() or s.t
        else
            s.stopAt = CurTime()
        end
    end
    if s.stopAt then
        s.master = 1 - clamp((CurTime() - s.stopAt) / 1, 0, 1)
        if s.master <= 0 then session = nil end
    end
end

function btb.StartSubtitles(track, channel)
    local name = string.lower(track)
    local langs = btb.readCache(name)

    if not langs then
        btb.print(2, "Subtitles", "No subtitles found for:", name)
        return
    end

    if not channel or not IsValid(channel) then
        btb.print(2, "Subtitles", "Invalid or missing audio channel for:", name)
        return
    end

    local cues = buildCues(langs)
    if #cues == 0 then
        btb.print(2, "Subtitles", "No subtitles found for:", name)
        return
    end

    session = {
        langs = langs,
        cues = cues,
        channel = channel,
        t = channel:GetTime() or 0,
        startedAt = CurTime(),
        master = 1,
        world = {}
    }

    btb.print(3, "Subtitles", "Now displaying subtitles for:", name, "| Cues:", #cues)
end

function btb.StopSubtitles(instant)
    if not session then return end
    if instant then
        session = nil
    else
        session.stopAt = session.stopAt or CurTime()
    end
end

local function rebuildSub()
    timer.Simple(0, function()
        if not session then return end
        local cues = buildCues(session.langs)
        if #cues == 0 then return end
        session.cues = cues
        session.spawned = nil
    end)
end
cvars.AddChangeCallback("battlebeats_subtitles_lang", rebuildSub)
cvars.AddChangeCallback("battlebeats_subtitles_lang2", rebuildSub)

-- MARK: 2D

local centerY = subtitlesYpos:GetInt()
local function isEnabled()
    enableSubtitles = enableSubtitles or GetConVar("battlebeats_subtitles_enabled")
    return enableSubtitles and enableSubtitles:GetBool()
end

local function drawHUD()
    local s = session
    if not s or subtitlesMode:GetInt() == 1 or not isEnabled() then return end

    local cues, t = s.cues, s.t
    local k = lastStarted(cues, t)

    local hPrev, hCur, hNext = heightOf(cues, k - 1), heightOf(cues, k), heightOf(cues, k + 1)
    local gap = math.max(6, ScrH() * 0.01)
    local dPrev = (hPrev + hCur) / 2 + gap
    local dNext = (hCur + hNext) / 2 + gap

    local p = 1
    if k >= 1 then p = easeInOut(clamp((t - cues[k].start) / (cues[k].dur or trans), 0, 1)) end

    local focusH = hPrev + (hCur - hPrev) * p
    local cy = clamp(centerY, 16 + focusH / 2, ScrH() - 16 - focusH / 2)
    local base = cy + dPrev * (1 - p)

    local cx = ScrW() / 2
    drawCue(cues, k - 1, cx, base - dPrev, t, s.master)
    drawCue(cues, k, cx, base, t, s.master)
    drawCue(cues, k + 1, cx, base + dNext, t, s.master)
end

-- MARK: 3D 

local texGradient = surface.GetTextureID("gui/center_gradient")
local function spawnWorld(s, cue, lifetime)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local eyePos, eyeAng = ply:EyePos(), ply:EyeAngles()
    local pos = eyePos + eyeAng:Forward() * math.random(700, 900) + eyeAng:Up() * math.random(-20, 200) + eyeAng:Right() * math.random(-300, 300)
    local ang = (eyePos - pos):GetNormalized():Angle()
    ang:RotateAroundAxis(ang:Right(), -90)
    ang:RotateAroundAxis(ang:Up(), 90)

    local cur = CurTime()
    s.world[#s.world + 1] = {
        cue = cue,
        pos = pos,
        ang = ang,
        scale = 0.60 + math.random() * 0.05,
        birth = cur,
        death = cur + lifetime,
        lastPlayerPos = ply:GetPos()
    }
end

local fin  = 0.2
local fout = 1
local function worldAlpha(w, cur)
    local age = cur - w.birth
    if age < fin then return easeInOut(age / fin) end
    local left = w.death - cur
    if left < fout then return 1 - easeInOut(1 - left / fout) end
    return 1
end

local function draw3D(w, alpha)
    local lay = getLayout(w.cue)
    local ply = LocalPlayer()
    if IsValid(ply) then
        local cur = ply:GetPos()
        if not staticSubtitles:GetBool() then
            w.pos = w.pos + (cur - w.lastPlayerPos) * 0.9
        end
        w.lastPlayerPos = cur
    end

    cam.Start3D2D(w.pos, w.ang, w.scale)
    cam.IgnoreZ(true)

    surface.SetDrawColor(0, 0, 0, alpha * 0.65)
    surface.SetTexture(texGradient)
    surface.DrawTexturedRect(-lay.w / 2 - 150, -lay.h / 2 - 8, lay.w + 300, lay.h + 16)

    drawLines(lay, 0, -lay.h / 2, alpha, 2)

    cam.IgnoreZ(false)
    cam.End3D2D()
end

local function drawWorld(_, bDrawingSkybox)
    local s = session
    if not s or bDrawingSkybox or subtitlesMode:GetInt() ~= 1 or not isEnabled() then return end

    local cur = CurTime()
    local world = s.world
    for i = #world, 1, -1 do
        local w = world[i]
        if cur > w.death then
            table.remove(world, i)
        else
            local a = worldAlpha(w, cur) * s.master * 255
            if a >= 1 then draw3D(w, a) end
        end
    end
end

local function think()
    local s = session
    if not s then return end
    updSub(s)
    if session ~= s or s.stopAt or subtitlesMode:GetInt() ~= 1 or not isEnabled() then return end
    local cues = s.cues
    local k = lastStarted(cues, s.t)
    local cue = cues[k]
    if cue and k ~= s.spawned and s.t <= cue["end"] then
        s.spawned = k
        spawnWorld(s, cue, cue["end"] - s.t + 1)
    end
end

hook.Add("Think", "BattleBeats_Subtitles", think)
hook.Add("HUDPaint", "BattleBeats_Subtitles", drawHUD)
hook.Add("PostDrawTranslucentRenderables", "BattleBeats_Subtitles", drawWorld)

local pe, py = 0, 0
local function drawYPreview()
    if CurTime() >= pe then
        centerY = py
        hook.Remove("HUDPaint", "BattleBeats_NotificationPreview")
        return
    end
    surface.SetDrawColor(255, 255, 255, 100)
    surface.DrawOutlinedRect(ScrW() / 2 - 300, py - 75, 600, 150)
    draw.SimpleText("#btb.options.sub.sub_height_noti_text", "DermaDefault", ScrW() / 2, py, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

cvars.AddChangeCallback("battlebeats_subtitles_y", function(_, _, newValue)
    py = tonumber(newValue) or centerY
    pe = CurTime() + 5
    hook.Add("HUDPaint", "BattleBeats_NotificationPreview", drawYPreview)
end)
