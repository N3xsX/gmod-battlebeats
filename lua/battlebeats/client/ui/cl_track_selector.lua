-- TODO: add localization to some of the new strings

local btb = BATTLEBEATS
local isSingle = game.SinglePlayer()

local ls = { "Bulgarian (Български)", "Czech (Čeština)", "Danish (Dansk)", "German (Deutsch)",
    "Greek (Ελληνικά)", "English (English)", "Pirate English (Pirate English)", "Spanish (Español)",
    "Estonian (Eesti)", "Finnish (Suomi)", "French (Français)", "Hebrew (עברית)", "Croatian (Hrvatski)",
    "Hungarian (Magyar)", "Italian (Italiano)", "Japanese (日本語)", "Korean (한국어)", "Lithuanian (Lietuvių)",
    "Dutch (Nederlands)", "Norwegian (Norsk)", "Polish (Polski)", "Portuguese (Brazil) (Português do Brasil)",
    "Portuguese (Portugal) (Português)", "Russian (Русский)", "Slovak (Slovenčina)", "Swedish (Svenska)",
    "Thai (ไทย)", "Turkish (Türkçe)", "Ukrainian (Українська)", "Vietnamese (Tiếng Việt)",
    "Chinese Simplified (简体中文)", "Chinese Traditional (繁體中文)" }
local lv = { "bg", "cs", "da", "de", "el", "en", "en-tp", "es-es", "et", "fi", "fr", "he", "hr", "hu", "it",
    "ja", "ko", "lt", "nl", "no", "pl", "pt-br", "pt-pt", "ru", "sk", "sv-se", "th", "tr", "uk", "vi", "zh-cn",
    "zh-tw" }

local lm = {}
for i, v in ipairs(lv) do lm[v] = ls[i] end

local shared = btb.uiShared
local LerpColor = shared.LerpColor
local ColA = shared.ColA
local animHover = shared.animHover
local createBasePanel = shared.createBasePanel
local makeSearch = shared.makeSearch

local C = shared.Colors
local TL, TC, TR, TT = TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
local L = language.GetPhrase

local texGradient = surface.GetTextureID("gui/gradient")

local matCache = {}
local function mat(p)
    local m = matCache[p]
    if not m then
        m = Material(p)
        matCache[p] = m
    end
    return m
end

local function drawIcon(path, x, y, a)
    surface.SetMaterial(mat(path))
    surface.SetDrawColor(255, 255, 255, a or 255)
    surface.DrawTexturedRect(x, y, 16, 16)
end

local fitCache, fitCount = {}, 0
local function fitText(text, font, maxW)
    if maxW < 10 then return "" end
    local key = font .. "|" .. math.floor(maxW) .. "|" .. text
    local c = fitCache[key]
    if c then return c end
    surface.SetFont(font)
    local out = text
    if surface.GetTextSize(text) > maxW then
        while #out > 1 and surface.GetTextSize(out .. "…") > maxW do
            local off = utf8.offset(out, -1) or #out
            out = string.sub(out, 1, off - 1)
        end
        out = out .. "…"
    end
    fitCount = fitCount + 1
    if fitCount > 4000 then fitCache, fitCount = {}, 0 end
    fitCache[key] = out
    return out
end

local function isCtrl() return input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) end
local function isShift() return input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) end

--MARK: audio tag cache
local mfile = "battlebeats/trackmeta.txt"
btb.trackMeta = btb.trackMeta or {}
local metaCache = btb.trackMeta
if not btb._trackMetaLoaded then
    btb._trackMetaLoaded = true
    local raw = file.Read(mfile, "DATA")
    if raw then
        local t = util.JSONToTable(raw)
        if istable(t) then
            for k, v in pairs(t) do metaCache[k] = v end
        end
    end
end

local fieldAliases = {
    title = {"title", "tit2", "nam"},
    artist = {"artist", "tpe1", "art", "performer"},
    album = {"album", "talb", "alb"},
    year = {"year", "date", "tyer", "tdrc", "day"},
    genre = {"genre", "tcon", "gen"},
}
local fieldLookup = {}
for field, list in pairs(fieldAliases) do
    for _, k in ipairs(list) do fieldLookup[k] = field end
end

local function normKey(k)
    k = string.lower(tostring(k))
    k = string.gsub(k, "\194\169", "")
    k = string.gsub(k, "[^%w]", "")
    return k
end

local function absorb(tags, out)
    if not istable(tags) then return end
    for k, v in pairs(tags) do
        local key, val
        if isstring(k) then
            key, val = k, v
        elseif isstring(v) then
            key, val = string.match(v, "^([^=]+)=(.*)$")
        end
        if key and val ~= nil then
            if istable(val) then val = val[1] end
            val = string.Trim(tostring(val))
            local f = fieldLookup[normKey(key)]
            if f and val ~= "" and not out[f] then
                if f == "year" then val = string.match(val, "%d%d%d%d") or val end
                out[f] = val
            end
        end
    end
end

local metaQueue, metaBusy, metaBusyAt, metaToken = {}, false, 0, 0
local sessionChecked, lastPainted, firstPainted = {}, {}, {}
local function saveMetaSoon()
    timer.Create("BattleBeats_SaveMeta", 5, 1, function()
        file.Write(mfile, util.TableToJSON(metaCache))
    end)
end

local pumpMeta
local function schedulePump(delay, force)
    if not force and timer.Exists("BattleBeats_PumpMeta") then return end
    timer.Create("BattleBeats_PumpMeta", delay, 1, function() pumpMeta() end)
end

local function finishMeta(path, ch, token)
    local m = {}
    if IsValid(ch) then
        if token == metaToken then
            local ok = pcall(function()
                m.len = ch:GetLength()
                for _, fn in ipairs({ "GetTagsID3", "GetTagsMP4", "GetTagsOGG", "GetTagsMeta" }) do
                    if isfunction(ch[fn]) then
                        local okT, t = pcall(ch[fn], ch)
                        if okT then absorb(t, m) end
                    end
                end
            end)
            if not ok then m = { fail = true } end
        end
        pcall(ch.Stop, ch)
    else
        m.fail = true
    end

    if token ~= metaToken then return end

    local parts = {}
    for _, k in ipairs({ "artist", "album", "genre", "title" }) do
        if m[k] then parts[#parts + 1] = string.lower(m[k]) end
    end
    m.q = table.concat(parts, " ")
    m.mt = file.Time(path, "GAME")
    metaCache[path] = m
    saveMetaSoon()
    metaBusy = false
    if #metaQueue > 0 then schedulePump(0.05) end
end

pumpMeta = function()
    local now = SysTime()
    if metaBusy then
        if now - metaBusyAt <= 12 then
            schedulePump(1, true)
            return
        end
        metaToken = metaToken + 1
        metaBusy = false
    end

    local path
    local i = #metaQueue
    while i >= 1 do
        local p = metaQueue[i]
        local seen = lastPainted[p]
        if not seen or now - seen > 0.25 then
            table.remove(metaQueue, i)
            sessionChecked[p] = nil
            firstPainted[p] = nil
        elseif now - (firstPainted[p] or now) >= 0.35 then
            table.remove(metaQueue, i)
            path = p
            break
        end
        i = i - 1
    end

    if not path then
        if #metaQueue > 0 then schedulePump(0.15, true) end
        return
    end

    firstPainted[path] = nil
    metaToken = metaToken + 1
    local token = metaToken
    metaBusy, metaBusyAt = true, now
    local ok = pcall(sound.PlayFile, path, "noplay", function(ch)
        finishMeta(path, ch, token)
    end)
    if not ok then
        metaBusy = false
        sessionChecked[path] = nil
    end
end

local function requestMeta(path)
    local now = SysTime()
    if not lastPainted[path] or now - lastPainted[path] > 0.25 then
        firstPainted[path] = now
    end
    lastPainted[path] = now
    if sessionChecked[path] then return end
    sessionChecked[path] = true
    local m = metaCache[path]
    if m and m.mt == file.Time(path, "GAME") then return end
    metaQueue[#metaQueue + 1] = path
    schedulePump(0.15)
end

--MARK: widgets
local function makeButton(parent, w, text, onClick, opts)
    opts = opts or {}
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:SetCursor("hand")
    b:Dock(RIGHT)
    b:DockMargin(6, 0, 0, 0)
    b:SetWide(w)
    if opts.tip then
        b:SetTooltip(opts.tip)
        b:SetTooltipPanelOverride("BattleBeatsTooltip")
    end
    b.Paint = function(self, pw, ph)
        local enabled = not opts.enabled or opts.enabled()
        local hov = animHover(self, "Hov", enabled and self:IsHovered())
        local down = enabled and self:IsDown()
        local accent = opts.accent or C.Yellow
        local a = enabled and 255 or 90
        draw.RoundedBox(10, 0, 0, pw, ph, ColA(LerpColor(hov * 0.35, accent, color_white), a))
        draw.RoundedBox(9, 1, 1, pw - 2, ph - 2, ColA(down and C.C50 or LerpColor(hov, C.C90, C.C100), a))
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

local function cardPaint(self, w, h) draw.RoundedBox(10, 0, 0, w, h, C.Card) end

-- batch playlist edit
local function batchPlaylist(name, its, adding)
    local pl, pack = btb.musicPlaylists[name], btb.musicPacks[name]
    if not pl or not pack then return 0 end
    local n = 0
    for _, it in ipairs(its) do
        local ty = it.type
        pl[ty] = pl[ty] or {}
        pack[ty] = pack[ty] or {}
        local idx
        for i, v in ipairs(pl[ty]) do
            if v.path == it.track then
                idx = i
                break
            end
        end
        if adding and not idx then
            table.insert(pl[ty], { path = it.track, exists = true })
            table.insert(pack[ty], it.track)
            n = n + 1
        elseif not adding and idx then
            table.remove(pl[ty], idx)
            for i, v in ipairs(pack[ty]) do
                if v == it.track then
                    table.remove(pack[ty], i)
                    break
                end
            end
            n = n + 1
        end
    end
    if n > 0 then btb.savePlaylists() end
    return n
end

--MARK: track list

local rowH, step, pad = 56, 60, 6
local swW = 40
local chipH = 28
local qsAmbient = {
    { id = "vol", icon = "icon16/sound.png", tip = "#btb.ps.pack_rmb.set_volume" },
    { id = "trim", icon = "icon16/time.png", tip = "#btb.ps.ts.rmb.trim_set" },
    { id = "rename", icon = "icon16/tag_blue_edit.png", tip = "#btb.ps.ts.rmb.set_name" },
    { id = "more", tip = "More options" }
}
local qsCombat = {qsAmbient[1], qsAmbient[2], qsAmbient[3],
    { id = "assign", icon = "icon16/user_add.png", tip = "#btb.ps.ts.rmb.assign_add" },
qsAmbient[4]}

function BATTLEBEATS.createTrackList(ctx, parent, trackType, selectedPack)
    local ui = ctx.ui
    local frame = ctx.frame
    local playerPanel = ctx.playerPanel
    local playPause = ctx.playPause
    local trackNameLabel = ctx.trackNameLabel
    local activeTextEntries = ctx.activeTextEntries
    local showPreviewNotification = GetConVar("battlebeats_show_preview_notification")

    local tls = ui.trackListState
    if not tls then
        tls = {}
        ui.trackListState = tls
    end
    tls.filters = tls.filters or {}
    ui.allRows = {}

    parent:Clear()
    local packData = selectedPack and btb.musicPacks[selectedPack]
    if not packData then return end
    local isAllMode = (trackType == "all")
    local isPlaylist = packData.packType == "playlist"

    local root = vgui.Create("DPanel", parent)
    root:Dock(TOP)
    root:SetPaintBackground(false)
    root:SetTall(ui.scrollPanel:GetTall())

    local ctxKey = tostring(selectedPack) .. "|" .. tostring(trackType)
    if tls.key ~= ctxKey then
        tls.key = ctxKey
        tls.query = ""
        tls.filters = {}
        tls.sort = isPlaylist and "playlist" or "az"
    end
    if tls.sort == "playlist" and not isPlaylist then tls.sort = "az" end
    tls.sort = tls.sort or "az"

    -- state
    local items, shown, counts, total = {}, {}, {}, 0
    local sel = { set = {}, anchor = nil, cursor = nil, primary = nil }
    local rowState = {}
    local cache = { frame = -1 }
    local list, chips, sc
    local refresh

    local function tg()
        if cache.frame ~= FrameNumber() then
            cache.frame = FrameNumber()
            local s = {}
            for _, it in ipairs(shown) do
                if sel.set[it.track] then s[#s + 1] = it end
            end
            cache.sel = s
            cache.selN = #s
            cache.list = #s > 0 and s or shown
        end
        return cache
    end
    local function touch() cache.frame = -1 end

    ui.scrollPanel.Think = function(self)
        if not ui.isTrackSelectorOpen then return end
        if IsValid(root) and root:GetTall() ~= self:GetTall() then root:SetTall(self:GetTall()) end
        if IsValid(tls.menu) and IsValid(sc) and math.abs(sc:GetVBar():GetScroll() - (tls.menuScroll or 0)) > 2 then
            tls.menu:Remove()
            tls.menu = nil
        end
    end

    --MARK: filter definitions
    local filterDefs = {
        { id = "fav", label = "#btb.ps.sort.favorite_only", icon = "icon16/star.png", test = function(it) return it.fav end },
        { id = "inc", label = "#btb.ps.sort.include_only", icon = "icon16/tick.png", test = function(it) return not it.ex end },
        { id = "ex", label = "#btb.ps.sort.exclude_only", icon = "icon16/cross.png", test = function(it) return it.ex end },
    }
    if isAllMode or trackType == "combat" then
        filterDefs[#filterDefs + 1] = { id = "assigned", label = "#btb.ps.sort.assigned_only", icon = "icon16/user.png", test = function(it) return it.npcs > 0 end }
    end
    filterDefs[#filterDefs + 1] = { id = "rename", label = "#btb.ps.sort.renamed_only", icon = "icon16/tag_blue.png", test = function(it) return it.alias ~= nil end }
    filterDefs[#filterDefs + 1] = { id = "offset", label = "#btb.ps.sort.offset_only", icon = "icon16/time.png", test = function(it) return it.trimActive end }
    filterDefs[#filterDefs + 1] = { id = "volume", label = "#btb.ps.sort.volume_only", icon = "icon16/sound.png", test = function(it) return it.hasVol end }
    filterDefs[#filterDefs + 1] = { id = "lyrics", label = "Lyrics", icon = "icon16/comment.png", test = function(it) return it.hasSub end }
    local filterById = {}
    for _, d in ipairs(filterDefs) do filterById[d.id] = d end

    local function setExcluded(its, state)
        for _, it in ipairs(its) do btb.setTrackData(it.track, "exl", state and true or nil) end
        ui.changesMade = true
        surface.PlaySound(state and "btb_button_disable.mp3" or "btb_button_enable.mp3")
        refresh()
    end
    local function setFavorite(its, state)
        for _, it in ipairs(its) do btb.setTrackData(it.track, "fav", state and true or nil) end
        ui.changesMade = true
        refresh()
    end
    local function targetsFor(it)
        local c = tg()
        if sel.set[it.track] and c.selN > 1 then return c.sel end
        return {it}
    end
    local function toggleExcluded(it) setExcluded(targetsFor(it), not it.ex) end
    local function toggleFav(it) setFavorite(targetsFor(it), not it.fav) end

    --MARK: selection
    local function selectOnly(idx)
        local it = shown[idx]
        if not it then return end
        sel.set = { [it.track] = true }
        sel.anchor, sel.cursor, sel.primary = idx, idx, it.track
        ui.selectedRow = it.trackName
        touch()
    end
    local function selectRange(a, b)
        local lo, hi = math.min(a, b), math.max(a, b)
        local set = {}
        for k = lo, hi do
            if shown[k] then set[shown[k].track] = true end
        end
        sel.set, sel.cursor = set, b
        touch()
    end
    local function clearSel()
        sel.set, sel.anchor, sel.cursor, sel.primary = {}, nil, nil, nil
        ui.selectedRow = nil
        touch()
    end

    local function scrollToIdx(idx, center)
        if not IsValid(list) then return end
        local vb = sc:GetVBar()
        local y = list:GetY() + pad + (idx - 1) * step
        local tall = sc:GetTall()
        local cur = vb:GetScroll()
        if center then
            vb:SetScroll(y - tall / 2 + rowH / 2)
        elseif y < cur then
            vb:SetScroll(y - 8)
        elseif y + rowH > cur + tall then
            vb:SetScroll(y + rowH - tall + 8)
        end
    end

    --MARK: preview
    local function playItem(it)
        ui.changesMade = true
        ui.previewList = ui.currentFilteredTracks
        ui.previewKey = ctxKey
        if not gui.IsGameUIVisible() or not isSingle then
            local track = it.track
            if track == btb.currentPreviewTrack then return end
            if not playerPanel:IsVisible() then
                playerPanel:SetAlpha(0)
                playerPanel:AlphaTo(255, 0.3, 0)
            end
            playerPanel:SetVisible(true)
            ui.scrollPanel:SetSize(980, ui.playerMin and 540 or 410)
            playPause:SetText("⏸")
            trackNameLabel:SetText(it.display)
            for idx, s in ipairs(shown) do
                if s == it then
                    scrollToIdx(idx)
                    break
                end
            end

            btb.PlayNextTrackPreview(track, nil, false, function()
                playerPanel:SetVisible(false)
            end)
            btb.currentPreviewTrack = track
            if not showPreviewNotification:GetBool() then btb.HideNotification() end
            if not timer.Exists("BattleBeats_NextPreviewTrack") then
                timer.Create("BattleBeats_NextPreviewTrack", 0.5, 0, function()
                    if IsValid(btb.currentPreviewStation) and btb.currentPreviewStation:GetState() == GMOD_CHANNEL_STOPPED then
                        if ctx.isLooping() then
                            btb.PlayNextTrackPreview(btb.currentPreviewTrack, nil, true, function()
                                playerPanel:SetVisible(false)
                            end)
                        else
                            btb.SwitchPreviewTrack(1)
                        end
                    end
                    if IsValid(btb.currentPreviewStation) then
                        btb.currentPreviewPosition = btb.currentPreviewStation:GetTime()
                    end
                end)
            end
        else
            btb.print(1, "UI", "Cannot preview sound while the game is paused")
        end
    end

    --MARK: per-track actions
    local function actVolume(it)
        btb.openVolumeEditor(frame, it.track, nil, function() refresh() end)
    end
    local function actTrim(it)
        btb.openTrimEditor(frame, it.track, function()
            ui.changesMade = true
            refresh()
        end)
    end
    local function actRename(it)
        activeTextEntries.changeNameBox = btb.changeName(frame, it.track, function() refresh() end)
    end
    local function actAssign(it)
        local track = it.track
        activeTextEntries.assignBox, activeTextEntries.assignBoxSearch = btb.createAssignFrame(
            frame, "#btb.ps.ts.rmb.assign_title", nil, 1, function(class, priority, fframe)
                if not class or class == "" then
                    notification.AddLegacy("#btb.ps.ts.rmb.assign_no_class", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button11.wav")
                    return
                end
                local d = btb.getTrackData(track)
                for _, npc in ipairs(d.npcMap or {}) do
                    if npc.class == class then
                        notification.AddLegacy("NPC '" .. class .. "' " .. L("btb.ps.ts.rmb.assign_this_track"), NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button11.wav")
                        return
                    end
                end
                d.npcMap = d.npcMap or {}
                d.npcMap[#d.npcMap + 1] = { class = class, priority = priority }
                btb.setTrackData(track, "npcMap", d.npcMap)
                btb.buildNPCTrackMap()
                ui.changesMade = true
                notification.AddLegacy(
                    L("btb.ps.ts.rmb.assign_noti_class") .. ": " .. class .. " " ..
                    L("btb.ps.ts.rmb.assign_noti_priority") .. " " .. priority .. " " ..
                    L("btb.ps.ts.rmb.assign_noti_track") .. ": " .. btb.FormatTrackName(track), NOTIFY_GENERIC, 3)
                surface.PlaySound("buttons/button14.wav")
                fframe:Remove()
                refresh()
            end)
    end
    local function actEditNPC(it, npcInfo)
        local track = it.track
        local oldClass, oldPrio = npcInfo.class, npcInfo.priority
        activeTextEntries.assignBox, activeTextEntries.assignBoxSearch = btb.createAssignFrame(
            frame, L("btb.ps.ts.rmb.assign_edit") .. ": " .. oldClass, oldClass, oldPrio,
            function(newClass, newPrio, fframe)
                if not newClass or newClass == "" then
                    notification.AddLegacy("#btb.ps.ts.rmb.assign_no_class", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button11.wav")
                    return
                end
                local npcMap = btb.getTrackData(track).npcMap or {}
                if newClass ~= oldClass then
                    for _, npc in ipairs(npcMap) do
                        if npc.class == newClass then
                            notification.AddLegacy("NPC '" .. newClass .. "' " .. L("btb.ps.ts.rmb.assign_this_track"), NOTIFY_ERROR, 3)
                            surface.PlaySound("buttons/button11.wav")
                            return
                        end
                    end
                end
                for i, npc in ipairs(npcMap) do
                    if npc.class == oldClass then
                        npcMap[i] = { class = newClass, priority = newPrio }
                        break
                    end
                end
                btb.setTrackData(track, "npcMap", npcMap)
                btb.buildNPCTrackMap()
                ui.changesMade = true
                notification.AddLegacy(L("btb.ps.ts.rmb.assign_edited") .. ": " .. oldClass .. " (" .. oldPrio .. ") → " .. newClass .. " (" .. newPrio .. ")", NOTIFY_GENERIC, 3)
                surface.PlaySound("buttons/button14.wav")
                fframe:Remove()
                refresh()
            end)
    end
    local function actRemoveNPC(it, npcInfo)
        local npcMap = btb.getTrackData(it.track).npcMap
        if not npcMap then return end
        for i = #npcMap, 1, -1 do
            if npcMap[i].class == npcInfo.class then
                table.remove(npcMap, i)
                break
            end
        end
        if #npcMap == 0 then btb.setTrackData(it.track, "npcMap", nil) end
        btb.buildNPCTrackMap()
        ui.changesMade = true
        notification.AddLegacy(L("btb.ps.ts.rmb.assign_removed") .. ": " .. npcInfo.class, NOTIFY_GENERIC, 3)
        surface.PlaySound("buttons/button3.wav")
        refresh()
    end

    --MARK: menus
    local function menuPaint(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.Yellow)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, C.C50)
    end
    local function addOpt(menu, text, icon, fn, tip)
        local o = menu:AddOption(text, fn)
        if icon then o:SetImage(icon) end
        if tip then
            o:SetTooltip(tip)
            o:SetTooltipPanelOverride("BattleBeatsTooltip")
        end
        o:BTB_PaintProperties()
        return o
    end
    local function addSub(menu, text, icon)
        local sub, opt = menu:AddSubMenu(text)
        if icon then opt:SetImage(icon) end
        opt:BTB_PaintProperties()
        sub.Paint = menuPaint
        return sub, opt
    end
    local function openMenuPanel(menu)
        tls.menu = menu
        tls.menuScroll = sc:GetVBar():GetScroll()
        menu:Open()
        menu.Paint = menuPaint
    end
    local function playlistNames()
        local n = {}
        for name in pairs(btb.musicPlaylists or {}) do n[#n + 1] = name end
        table.sort(n, function(a, b) return string.lower(a) < string.lower(b) end)
        return n
    end

    local function createPlaylistFrom(its)
        Derma_StringRequest("New playlist", "Playlist name (" .. #its .. " tracks):", "", function(txt)
            local name = string.Trim(txt or "")
            if name == "" then
                notification.AddLegacy("#btb.playlist.create.enter_name_error", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button11.wav")
                return
            end
            if #name > 30 then name = string.sub(name, 1, 30) end
            if btb.musicPacks[name] or btb.musicPlaylists[name] then
                notification.AddLegacy("#btb.playlist.create.name_error", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button11.wav")
                return
            end
            local data, seen = { ambient = {}, combat = {} }, {}
            for _, it in ipairs(its) do
                local key = it.type .. "|" .. it.track
                if not seen[key] then
                    seen[key] = true
                    table.insert(data[it.type], { path = it.track, exists = true })
                end
            end
            btb.validateAndTransformPlaylist(name, data)
            btb.savePlaylists()
            ui.changesMade = true
            notification.AddLegacy("#btb.playlist.create.create_succ", NOTIFY_GENERIC, 3)
            surface.PlaySound("buttons/button3.wav")
        end)
    end

    -- add-to / remove-from playlist 
    local function addPlaylistEntries(menu, its)
        if isPlaylist then
            addOpt(menu, "#btb.playlist.remove_track", "icon16/delete.png", function()
                batchPlaylist(selectedPack, its, false)
                surface.PlaySound("buttons/button14.wav")
                clearSel()
                refresh()
            end)
            addOpt(menu, "New playlist from " .. #its .. "…", "icon16/add.png", function() createPlaylistFrom(its) end)
            return
        end
        local names = playlistNames()
        addOpt(menu, "New playlist from " .. #its .. "…", "icon16/add.png", function() createPlaylistFrom(its) end)
        if #names == 0 then return end
        local sub = addSub(menu, L("btb.playlist.add_to") .. ":", "icon16/arrow_branch.png")
        for _, name in ipairs(names) do
            addOpt(sub, name, nil, function()
                batchPlaylist(name, its, true)
                surface.PlaySound("buttons/button14.wav")
            end)
        end
        if #its == 1 then
            local it = its[1]
            local rem = {}
            for _, name in ipairs(names) do
                if btb.isTrackInPlaylist(name, it.track, it.type) then rem[#rem + 1] = name end
            end
            if #rem > 0 then
                local rsub = addSub(menu, L("btb.playlist.remove_from") .. ":", "icon16/delete.png")
                for _, name in ipairs(rem) do
                    addOpt(rsub, name, nil, function()
                        batchPlaylist(name, its, false)
                        surface.PlaySound("buttons/button14.wav")
                    end)
                end
            end
        end
    end

    local function openBulkMenu(its)
        local menu = DermaMenu()
        tls.menu = menu
        addOpt(menu, "Enable (" .. #its .. ")", "icon16/tick.png", function() setExcluded(its, false) end)
        addOpt(menu, "Disable (" .. #its .. ")", "icon16/cross.png", function() setExcluded(its, true) end)
        addOpt(menu, "Add to favorites", "icon16/star.png", function() setFavorite(its, true) end)
        addOpt(menu, "Remove from favorites", "icon16/cancel.png", function() setFavorite(its, false) end)
        menu:AddSpacer()
        addPlaylistEntries(menu, its)
        menu:AddSpacer()
        addOpt(menu, "Clear selection", "icon16/arrow_undo.png", clearSel)
        openMenuPanel(menu)
    end

    local function openMenu(it)
        local c = tg()
        if c.selN > 1 and sel.set[it.track] then
            openBulkMenu(c.sel)
            return
        end
        local track = it.track
        local td = btb.getTrackData(track)
        local menu = DermaMenu()
        it.menuActive = true
        menu.OnRemove = function() it.menuActive = false end

        --MARK:RMB admin
        if LocalPlayer():IsSuperAdmin() and not isSingle then
            local d1 = menu:AddOption("------ADMIN------")
            d1:BTB_PaintProperties()
            local enforceSub, enforceBtn = addSub(menu, "#btb.ps.ts.rmb.enforce", "icon16/music.png")
            enforceBtn:SetTooltip("#btb.ps.ts.rmb.enforce_tip")
            enforceBtn:SetTooltipPanelOverride("BattleBeatsTooltip")
            addOpt(enforceSub, "#btb.ps.ts.rmb.enforce_to_all", "icon16/group.png", function()
                net.Start("BTB_SV_Receive_Sound")
                net.WritePlayer(NULL)
                net.WriteString(track)
                net.SendToServer()
            end)
            local playerSub = addSub(enforceSub, L("btb.ps.ts.rmb.enforce_to_player") .. ":", "icon16/user_orange.png")
            for _, ply in ipairs(player.GetAll()) do
                addOpt(playerSub, ply:Nick(), nil, function()
                    net.Start("BTB_SV_Receive_Sound")
                    net.WritePlayer(ply)
                    net.WriteString(track)
                    net.SendToServer()
                end)
            end
            local d2 = menu:AddOption("------CLIENT------")
            d2:BTB_PaintProperties()
        end

        --MARK:RMB volume
        local vol = (td.vol ~= nil and (td.vol - 100)) or 0
        local volName = vol ~= 0 and (L("btb.ps.pack_rmb.edit_volume") .. " [" .. vol .. "%]") or "#btb.ps.pack_rmb.set_volume"
        addOpt(menu, volName, "icon16/sound.png", function() actVolume(it) end)

        --MARK:RMB playlists
        addPlaylistEntries(menu, { it })

        --MARK:RMB favorites
        if it.fav then
            addOpt(menu, "#btb.ps.ts.rmb.remove_fav", "icon16/cancel.png", function() setFavorite({ it }, false) end)
        else
            addOpt(menu, "#btb.ps.ts.rmb.add_fav", "icon16/star.png", function() setFavorite({ it }, true) end)
        end

        --MARK:RMB start track
        local currentStart = cookie.GetString("battlebeats_start_track", "")
        if currentStart == track and currentStart ~= "" then
            addOpt(menu, "#btb.ps.ts.rmb.remove_start_track", "icon16/cancel.png", function()
                cookie.Delete("battlebeats_start_track")
                refresh()
            end)
        else
            addOpt(menu, "#btb.ps.ts.rmb.set_start_track", "icon16/door_in.png", function()
                cookie.Set("battlebeats_start_track", track)
                RunConsoleCommand("battlebeats_start_mode", "2")
                refresh()
            end, "#btb.ps.ts.rmb.set_start_track_tip")
        end

        --MARK:RMB offset/trim
        local trim = td.trim
        local trimTitle = L("btb.ps.ts.rmb.trim_edit")
        local trimText
        if trim then
            trimText = (trim.start and btb.FormatTime(trim.start) or "start") .. " - " .. (trim.finish and btb.FormatTime(trim.finish) or "end")
        end
        addOpt(menu, trimText and (trimTitle .. " (" .. trimText .. ")") or "#btb.ps.ts.rmb.trim_set", "icon16/time.png", function() actTrim(it) end, "#btb.ps.ts.rmb.trim_tip")

        --MARK:RMB npc assign
        if it.type == "combat" then
            addOpt(menu, "#btb.ps.ts.rmb.assign_add", "icon16/user_add.png", function() actAssign(it) end, "#btb.ps.ts.rmb.assign_tip")
            for _, npcInfo in ipairs(td.npcMap or {}) do
                local npcText = L("btb.ps.ts.rmb.assign_current") ..
                npcInfo.class .. " (" .. L("btb.ps.ts.rmb.assign_priority") .. npcInfo.priority .. ")"
                local sub = addSub(menu, npcText, "icon16/vcard.png")
                addOpt(sub, "#btb.ps.ts.rmb.assign_edit", "icon16/user_edit.png", function() actEditNPC(it, npcInfo) end)
                addOpt(sub, "#btb.ps.ts.rmb.assign_remove", "icon16/user_delete.png", function() actRemoveNPC(it, npcInfo) end)
            end
        end

        --MARK:RMB subtitles
        if #it.subLangs > 0 then
            local sub = addSub(menu, "#btb.ps.ts.rmb.show_lyrics", "icon16/text_align_left.png")
            for _, lang in ipairs(it.subLangs) do
                addOpt(sub, lm[lang] or lang, "icon16/page_white_text.png", function()
                    local subs = btb.readCache(string.lower(it.trackName))
                    if subs and subs[lang] then btb.openSubtitles(frame, it.trackName, subs[lang].cues) end
                end)
            end
        end

        --MARK:RMB rename / copy
        addOpt(menu, "#btb.ps.ts.rmb.set_name", "icon16/tag_blue_edit.png", function() actRename(it) end)
        addOpt(menu, "#btb.ps.ts.rmb.copy", "icon16/tag.png", function() SetClipboardText(track) end)
        openMenuPanel(menu)
    end

    local function runQuick(it, slot)
        if slot.id == "vol" then
            actVolume(it)
        elseif slot.id == "trim" then
            actTrim(it)
        elseif slot.id == "rename" then
            actRename(it)
        elseif slot.id == "assign" then
            actAssign(it)
        elseif slot.id == "more" then
            openMenu(it)
        end
    end

    --MARK: toolbar (search + sort)
    local bar = vgui.Create("DPanel", root)
    bar:Dock(TOP)
    bar:SetTall(48)
    bar:DockMargin(5, 5, 5, 6)
    bar:DockPadding(8, 8, 8, 8)
    bar.Paint = cardPaint

    local sortDefs = {}
    if isPlaylist then
        sortDefs[#sortDefs + 1] = { "playlist", "#btb.ps.sort.playlist_order", "icon16/text_list_numbers.png" }
    end
    sortDefs[#sortDefs + 1] = { "az", "A → Z", "icon16/arrow_down.png" }
    sortDefs[#sortDefs + 1] = { "za", "Z → A", "icon16/arrow_up.png" }
    sortDefs[#sortDefs + 1] = { "rnd", "#btb.ps.sort.random", "icon16/arrow_switch.png" }

    makeButton(bar, 160, function()
        for _, d in ipairs(sortDefs) do
            if d[1] == tls.sort then return L(d[2]) .. "  ▼" end
        end
        return "Sort  ▼"
    end, function()
        local menu = DermaMenu()
        for _, d in ipairs(sortDefs) do
            addOpt(menu, d[2], d[3], function()
                tls.sort = d[1]
                if d[1] == "rnd" then tls.seed = tostring(os.time()) .. math.random(1000) end
                refresh(true)
            end)
        end
        openMenuPanel(menu)
    end, { tip = "#btb.ps.sort.tooltip" })

    activeTextEntries.searchBox = makeSearch(bar, nil, nil, nil, nil, "#btb.ps.search", function(v)
        tls.query = v
        timer.Create("BattleBeats_SearchDelay", 0.25, 1, function() refresh(true) end)
    end)
    activeTextEntries.searchBox:DockMargin(0, 0, 0, 0)
    activeTextEntries.searchBox:SetText(tls.query or "")
    local ph = activeTextEntries.searchBox.Paint
    activeTextEntries.searchBox.Paint = function(self, w, h)
        if self:GetText() == "" and not self:HasFocus() then
            draw.RoundedBox(8, 0, 0, w, h, C.C70)
            draw.RoundedBox(7, 1, 1, w - 2, h - 2, C.C50)
            draw.SimpleText(L("#btb.ps.search"), "BattleBeats_Font", 8, h / 2, C.Dim, TL, TC)
            return
        end
        ph(self, w, h)
    end

    --MARK: toolbar
    chips = vgui.Create("DPanel", root)
    chips:Dock(TOP)
    chips:SetTall(chipH)
    chips:DockMargin(5, 0, 5, 6)
    chips:SetCursor("hand")
    chips.hovs, chips.acts = {}, {}
    chips.PerformLayout = function(self, w, h)
        surface.SetFont("BattleBeats_Chip")
        local x, y = 0, 0
        local rects = {}
        for _, def in ipairs(filterDefs) do
            local label = L(def.label)
            local cnt = tostring(counts[def.id] or 0)
            local cw = 12 + 22 + surface.GetTextSize(label) + 10 + surface.GetTextSize(cnt) + 12
            if x > 0 and x + cw > w then x, y = 0, y + chipH + 6 end
            rects[#rects + 1] = { def = def, label = label, cnt = cnt, x = x, y = y, w = cw }
            x = x + cw + 6
        end
        if next(tls.filters) then
            local label = "✕ Reset"
            local cw = 12 + surface.GetTextSize(label) + 12
            if x > 0 and x + cw > w then x, y = 0, y + chipH + 6 end
            rects[#rects + 1] = { def = { id = "_reset" }, label = label, x = x, y = y, w = cw, reset = true }
        end
        self.rects = rects
        local th = y + chipH
        if self:GetTall() ~= th then self:SetTall(th) end
    end

    chips.Paint = function(self, w, h)
        local cx, cy = self:CursorPos()
        local hovered = self:IsHovered()
        for _, r in ipairs(self.rects or {}) do
            local id = r.def.id
            local isH = hovered and cx >= r.x and cx <= r.x + r.w and cy >= r.y and cy <= r.y + chipH
            self.hovs[id] = Lerp(FrameTime() * 12, self.hovs[id] or 0, isH and 1 or 0)
            local actTarget = tls.filters[id] and 1 or 0
            self.acts[id] = Lerp(FrameTime() * 12, self.acts[id] or actTarget, actTarget)
            local hov, act = self.hovs[id], self.acts[id]
            local empty = (not r.reset) and (counts[id] or 0) == 0 and actTarget == 0
            local a = empty and 120 or 255
            draw.RoundedBox(8, r.x, r.y, r.w, chipH, ColA(LerpColor(act, LerpColor(hov * 0.4, C.C70, color_white), C.Yellow), a))
            draw.RoundedBox(7, r.x + 1, r.y + 1, r.w - 2, chipH - 2, ColA(LerpColor(act * 0.3, LerpColor(hov, C.C50, C.C70), C.Yellow), a))
            if r.reset then
                draw.SimpleText(r.label, "BattleBeats_Chip", r.x + r.w / 2, r.y + chipH / 2, ColA(C.Warn, a), TC, TC)
            else
                drawIcon(r.def.icon, r.x + 10, r.y + (chipH - 16) / 2, a)
                draw.SimpleText(r.label, "BattleBeats_Chip", r.x + 32, r.y + chipH / 2, ColA(color_white, a), TL, TC)
                draw.SimpleText(r.cnt, "BattleBeats_Chip", r.x + r.w - 10, r.y + chipH / 2, ColA(C.Dim, a), TR, TC)
            end
        end
    end

    chips.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        local cx, cy = self:CursorPos()
        for _, r in ipairs(self.rects or {}) do
            if cx >= r.x and cx <= r.x + r.w and cy >= r.y and cy <= r.y + chipH then
                surface.PlaySound("btb_tab_switch.mp3")
                local id = r.def.id
                if id == "_reset" then
                    tls.filters = {}
                else
                    if tls.filters[id] then
                        tls.filters[id] = nil
                    else
                        tls.filters[id] = true
                        if id == "inc" then tls.filters.ex = nil end
                        if id == "ex" then tls.filters.inc = nil end
                    end
                end
                self:InvalidateLayout(true)
                refresh(true)
                return
            end
        end
    end

    --MARK: tbar (info + bulk actions)
    local act = vgui.Create("DPanel", root)
    act:Dock(TOP)
    act:SetTall(38)
    act:DockMargin(5, 0, 5, 8)
    act:DockPadding(6, 5, 6, 5)
    act.Paint = function(self, w, h)
        cardPaint(self, w, h)
        local c = tg()
        local info = #shown .. " / " .. total .. " tracks"
        if c.selN > 0 then info = info .. "  ·  " .. c.selN .. " selected" end
        draw.SimpleText(info, "DermaDefaultBold", 14, h / 2, c.selN > 0 and C.Yellow or C.Dim, TL, TC)
    end

    local function hasTargets() return #tg().list > 0 end
    makeButton(act, 70, "Clear", clearSel, {enabled = function() return tg().selN > 0 end, tip = "Clear selection"})
    makeButton(act, 110, function()
        local c = tg()
        local allFav = #c.list > 0
        for _, it in ipairs(c.list) do
            if not it.fav then
                allFav = false
                break
            end
        end
        return (allFav and "☆ Unfavorite" or "★ Favorite") .. " (" .. #c.list .. ")"
    end, function()
        local c = tg()
        local allFav = true
        for _, it in ipairs(c.list) do
            if not it.fav then
                allFav = false
                break
            end
        end
        setFavorite(c.list, not allFav)
    end, { enabled = hasTargets, tip = "Applies to the selection, or to everything shown when nothing is selected" })
    makeButton(act, 110, function() return (isPlaylist and "Remove" or "Playlist") .. " (" .. #tg().list .. ")" end,
        function()
            local menu = DermaMenu()
            addPlaylistEntries(menu, tg().list)
            openMenuPanel(menu)
        end, { enabled = hasTargets })
    makeButton(act, 110, function() return "Disable (" .. #tg().list .. ")" end, function() setExcluded(tg().list, true) end, { enabled = hasTargets, accent = C.Warn })
    makeButton(act, 110, function() return "Enable (" .. #tg().list .. ")" end, function() setExcluded(tg().list, false) end, { enabled = hasTargets })

    local packType = packData.packType
    if packType ~= "16thnote" and packType ~= "battlebeats" and packType ~= "local" and packType ~= "playlist" then
        createBasePanel(root, 40, 1, 10, function(panel)
            local label1 = vgui.Create("DLabel", panel)
            label1:Dock(TOP)
            label1:SetTall(41)
            label1:SetText("#btb.ps.ts.format")
            label1:SetFont("BattleBeats_Notification_Font_Misc")
            label1:SetTextColor(color_white)
            label1:SetContentAlignment(5)
        end)
    elseif packType == "playlist" then
        createBasePanel(root, 40, 1, 10, function(panel)
            local label1 = vgui.Create("DLabel", panel)
            label1:Dock(TOP)
            label1:SetTall(20)
            label1:SetText("#btb.ps.ts.playlist_info1")
            label1:SetFont("BattleBeats_Notification_Font_Misc")
            label1:SetTextColor(color_white)
            label1:SetContentAlignment(5)
            local label2 = vgui.Create("DLabel", panel)
            label2:Dock(TOP)
            label2:SetTall(20)
            label2:SetText("#btb.ps.ts.playlist_info2")
            label2:SetFont("BattleBeats_Notification_Font_Misc")
            label2:SetTextColor(color_white)
            label2:SetContentAlignment(5)
        end)
    end

    local divider = vgui.Create("DPanel", root)
    divider:Dock(TOP)
    divider:SetTall(3)
    divider:DockMargin(5, 0, 5, 5)
    divider.Paint = function(self, w, h) draw.RoundedBox(1, 0, 0, w, h, C.Yellow) end

    --MARK: virtual list
    sc = shared.makeScroll(root)
    sc:Dock(FILL)

    list = vgui.Create("DPanel", sc)
    list:Dock(TOP)
    list:DockMargin(5, 0, 5, 0)
    list:SetTall(90)
    list:SetPaintBackground(false)
    list:SetKeyboardInputEnabled(true)
    list:SetMouseInputEnabled(true)
    list:SetCursor("hand")

    local function rowGeom(it, w)
        local sw = w - 14 - swW
        local durR = sw - 12
        local clusterR = durR - 50
        local badgeL = clusterR - #it.badges * 20
        local slots = it.type == "combat" and qsCombat or qsAmbient
        local qR = badgeL - 8
        local qL = qR - #slots * 28
        return sw, durR, clusterR, badgeL, slots, qL, qR
    end

    local function hitTest(w, mx, my)
        local idx = math.floor((my - pad) / step) + 1
        if idx < 1 or idx > #shown then return nil end
        local ry = pad + (idx - 1) * step
        if my < ry or my > ry + rowH then return nil end
        local it = shown[idx]
        local sw, _, clusterR, badgeL, slots, qL, qR = rowGeom(it, w)
        local zone, arg = "row", nil
        if mx >= 4 and mx <= 34 then
            zone = "fav"
        elseif mx >= sw - 6 then
            zone = "toggle"
        elseif mx >= qL and mx < qR then
            zone = "q"
            arg = slots[math.floor((mx - qL) / 28) + 1]
        elseif #it.badges > 0 and mx >= badgeL and mx < clusterR then
            zone = "badge"
            arg = math.Clamp(math.ceil((clusterR - mx) / 20), 1, #it.badges)
        end
        return idx, zone, arg
    end

    local function tipFor(it, zone, arg)
        if zone == "fav" then return it.fav and "#btb.ps.ts.rmb.remove_fav" or "#btb.ps.ts.rmb.add_fav" end
        --if zone == "toggle" then return it.ex and "#btb.ps.ts.include_tip" or "#btb.ps.ts.exclude_tip" end
        if zone == "q" and arg then return arg.tip end
        if zone == "badge" and arg then return it.badges[arg][2] end
        local st = rowState[it.track]
        if st and st.truncated then
            return it.display .. (it.alias and ("\n" .. it.trackName) or "")
        end
    end

    --MARK: tooltip zones
    local zonePool = {}
    local function hideZones()
        for _, z in ipairs(zonePool) do
            if IsValid(z) and z:IsVisible() then z:SetVisible(false) end
        end
    end
    local function getZone(i)
        local z = zonePool[i]
        if IsValid(z) then return z end
        z = vgui.Create("DPanel", list)
        z:SetPaintBackground(false)
        z:SetCursor("hand")
        z:SetVisible(false)
        z:SetTooltipPanelOverride("BattleBeatsTooltip")
        z.OnMousePressed = function(_, code) list:OnMousePressed(code) end
        z.OnMouseReleased = function(_, code) list:OnMouseReleased(code) end
        z.OnMouseWheeled = function(_, delta) return sc:OnMouseWheeled(delta) end
        zonePool[i] = z
        return z
    end
    local function layoutZones(idx)
        local it = shown[idx]
        local w = list:GetWide()
        local ry = pad + (idx - 1) * step
        local sw, _, clusterR, badgeL, slots, qL = rowGeom(it, w)
        local n = 0
        local function put(x, zw, tip)
            if not tip then return end
            n = n + 1
            local z = getZone(n)
            z:SetPos(x, ry)
            z:SetSize(zw, rowH)
            z:SetTooltip(tip)
            z:SetVisible(true)
        end
        put(4, 30, tipFor(it, "fav"))
        put(sw - 6, swW + 6, tipFor(it, "toggle"))
        for k, slot in ipairs(slots) do
            put(qL + (k - 1) * 28, 28, tipFor(it, "q", slot))
        end
        for j = 1, #it.badges do
            put(clusterR - j * 20, 20, tipFor(it, "badge", j))
        end
        put(34, math.max(10, math.min(qL, badgeL) - 40), tipFor(it, "row"))
        for k = n + 1, #zonePool do
            if IsValid(zonePool[k]) then zonePool[k]:SetVisible(false) end
        end
    end

    list.Think = function(self)
        if self:IsHovered() or self:IsChildHovered() then
            local mx, my = self:CursorPos()
            local idx, zone, arg = hitTest(self:GetWide(), mx, my)
            self.hoverIdx, self.hoverZone, self.hoverArg = idx, zone, arg
            if idx ~= self.zoneIdx then
                self.zoneIdx = idx
                hideZones()
            elseif idx then
                layoutZones(idx)
            end
        else
            self.hoverIdx, self.zoneIdx = nil, nil
            hideZones()
        end
    end

    local function paintItem(self, it, idx, w, y)
        local st = rowState[it.track]
        if not st then
            st = { hov = 0, sel = 0, dim = it.ex and 1 or 0, star = 0, sw = 0 }
            rowState[it.track] = st
        end
        local ft = FrameTime()
        local hovered = self.hoverIdx == idx
        local selected = sel.set[it.track] == true
        local isCur = (it.track == btb.currentPreviewTrack and IsValid(btb.currentPreviewStation)) or ((IsValid(btb.currentStation) and not IsValid(btb.currentPreviewStation)) and it.track == btb.currentStation:GetFileName())
        st.hov = Lerp(ft * 12, st.hov, hovered and 1 or 0)
        st.sel = Lerp(ft * 14, st.sel, (selected or it.menuActive) and 1 or 0)
        st.dim = Lerp(ft * 10, st.dim, it.ex and 1 or 0)
        st.star = Lerp(ft * 12, st.star, (hovered and self.hoverZone == "fav") and 1 or 0)
        st.sw = Lerp(ft * 12, st.sw, (hovered and self.hoverZone == "toggle") and 1 or 0)

        local alpha = 255 - st.dim * 100
        local accent = it.type == "combat" and C.Combat or C.Ambient
        local bg = LerpColor(st.hov, C.CardIn, C.C70)
        local h = rowH

        if st.sel > 0.01 then
            local af = alpha / 255
            draw.RoundedBox(6, 0, y, w, h, ColA(bg, alpha))
            draw.RoundedBox(6, 0, y, w, h, ColA(C.Yellow, 30 * st.sel * af))
            btb.drawRoundedOutline(6, 0, y, w, h, 1, ColA(C.Yellow, 230 * st.sel * af))
        else
            draw.RoundedBox(6, 0, y, w, h, ColA(bg, alpha))
        end
        draw.RoundedBoxEx(6, 0, y, 4, h, ColA(accent, alpha), true, false, true, false)
        surface.SetTexture(texGradient)
        surface.SetDrawColor(accent.r, accent.g, accent.b, (30 + st.hov * 20) * (1 - st.dim * 0.6))
        surface.DrawTexturedRect(5, y + 3, w * (0.45 + st.hov * 0.15), h - 6)

        local cy = y + h / 2
        -- star
        if it.fav then
            draw.SimpleText("★", "BattleBeats_Font", 25, cy - 2, ColA(C.Yellow, alpha), TC, TC)
        else
            draw.SimpleText("★", "BattleBeats_Font", 25, cy - 2, Color(140, 140, 140, 35 + st.hov * 60 + st.star * 150), TC, TC)
        end

        -- preview marker
        if isCur then
            surface.SetDrawColor(255, 210, 0, 255)
            for i = 0, 2 do
                local hh = (4 + math.abs(math.sin(CurTime() * 5 + i * 1.7)) * 12)
                surface.DrawRect(40 + i * 5, cy - hh / 2, 3, hh)
            end
        end

        local sw, durR, clusterR, badgeL, slots, qL, qR = rowGeom(it, w)
        local tx = 58
        local tw = badgeL - 12 - tx

        -- title (+ alias original name)
        local fitKey = it.display .. "|" .. (it.alias and it.trackName or "") .. "|" .. tw
        if st.fitKey ~= fitKey then
            st.fitKey = fitKey
            surface.SetFont("BattleBeats_Font")
            st.tFit = fitText(it.display, "BattleBeats_Font", tw)
            st.truncated = st.tFit ~= it.display
            surface.SetFont("BattleBeats_Font")
            st.tW = surface.GetTextSize(st.tFit)
            local room = tw - st.tW - 12
            st.aFit = (it.alias and room > 60) and fitText(it.trackName, "BattleBeats_Rename_Font", room) or nil
        end
        draw.SimpleText(st.tFit, "BattleBeats_Font", tx, cy, ColA(color_white, alpha), TL, TC)
        if st.aFit then
            draw.SimpleText(st.aFit, "BattleBeats_Rename_Font", tx + st.tW + 10, cy, ColA(Color(150, 150, 150), alpha), TL, TC)
        end

        -- track length only
        local m = metaCache[it.track]
        requestMeta(it.track)

        -- badges
        for j, b in ipairs(it.badges) do
            drawIcon(b[1], clusterR - j * 20 + 2, cy - 8, alpha)
        end

        -- duration
        if m and m.len and m.len > 0 then
            draw.SimpleText(btb.FormatTime(m.len), "BattleBeats_Meta", durR, cy, ColA(C.Dim, alpha), TR, TC)
        end

        -- include / exclude switch
        local t = 1 - st.dim
        local sx, sy = sw, cy - 10
        draw.RoundedBox(10, sx, sy, swW, 20, LerpColor(st.sw * 0.3, LerpColor(t, C.C90, C.Yellow), color_white))
        local ks = 16 + st.sw * 2
        local kx = Lerp(t, sx + 10, sx + swW - 10) - ks / 2
        local ky = sy + 10 - ks / 2
        draw.RoundedBox(ks / 2, kx, ky + 1, ks, ks, C.Shadow)
        draw.RoundedBox(ks / 2, kx, ky, ks, ks, LerpColor(t, C.Text, C.C90))

        -- quick actions overlay
        if st.hov > 0.02 then
            local qa = st.hov
            for k, slot in ipairs(slots) do
                local bx = qL + (k - 1) * 28
                local by = cy - 13
                local sh = (hovered and self.hoverZone == "q" and self.hoverArg == slot) and 1 or 0
                st["q" .. slot.id] = Lerp(ft * 14, st["q" .. slot.id] or 0, sh)
                local sv = st["q" .. slot.id]
                draw.RoundedBox(5, bx, by, 26, 26, ColA(LerpColor(sv, C.C50, C.Yellow), 255 * qa))
                draw.RoundedBox(4, bx + 1, by + 1, 24, 24, ColA(LerpColor(sv * 0.35, C.C90, C.Yellow), 255 * qa))
                if slot.icon then
                    drawIcon(slot.icon, bx + 5, by + 5, 255 * qa)
                else
                    surface.SetDrawColor(255, 255, 255, 255 * qa)
                    for d = 0, 2 do surface.DrawRect(bx + 6 + d * 5, by + 12, 3, 3) end
                end
            end
        end
    end

    list.Paint = function(self, w, h)
        local n = #shown
        if n == 0 then
            draw.SimpleText(L("#btb.ps.sort.nothing_found"), "BattleBeats_Font", w / 2, 45, C.Warn, TC, TC)
            return
        end
        local vb = sc:GetVBar()
        local top = vb:GetScroll() - self:GetY()
        local bottom = top + sc:GetTall()
        local first = math.max(1, math.floor((top - pad) / step) + 1)
        local last = math.min(n, math.floor((bottom - pad) / step) + 1)
        for idx = first, last do
            paintItem(self, shown[idx], idx, w, pad + (idx - 1) * step)
        end
    end

    list.OnMousePressed = function(self, code)
        self:RequestFocus()
        local mx, my = self:CursorPos()
        local idx, zone, arg = hitTest(self:GetWide(), mx, my)
        if not idx then
            if code == MOUSE_LEFT and not (isCtrl() or isShift()) then clearSel() end
            return
        end
        local it = shown[idx]
        if code == MOUSE_LEFT then
            if zone == "fav" then
                toggleFav(it)
                return
            end
            if zone == "toggle" then
                toggleExcluded(it)
                return
            end
            if zone == "q" and arg then
                self.pendingQ = { idx = idx, slot = arg }
                return
            end
            if isShift() and sel.anchor then
                selectRange(sel.anchor, idx)
                sel.primary = it.track
                ui.selectedRow = it.trackName
            elseif isCtrl() then
                if sel.set[it.track] then sel.set[it.track] = nil else sel.set[it.track] = true end
                if not sel.set[it.track] then ui.selectedRow = nil end
                sel.anchor, sel.cursor, sel.primary = idx, idx, it.track
                ui.selectedRow = it.trackName
                touch()
            else
                local now = CurTime()
                local isDouble = self.lastClickIdx == idx and now - (self.lastClickTime or 0) < 0.3
                self.lastClickIdx, self.lastClickTime = idx, now
                selectOnly(idx)
                if isDouble then
                    self.lastClickIdx = nil
                    playItem(it)
                    clearSel()
                    timer.Simple(0, function()
                        scrollToIdx(idx)
                    end)
                end
            end
        elseif code == MOUSE_RIGHT then
            if not sel.set[it.track] then selectOnly(idx) end
            openMenu(it)
        end
    end

    list.OnMouseReleased = function(self, code)
        local p = self.pendingQ
        self.pendingQ = nil
        if code ~= MOUSE_LEFT or not p then return end
        local mx, my = self:CursorPos()
        local idx, zone, arg = hitTest(self:GetWide(), mx, my)
        if idx == p.idx and zone == "q" and arg == p.slot and shown[idx] then
            runQuick(shown[idx], arg)
        end
    end

    list.OnKeyCodePressed = function(self, key)
        local n = #shown
        if n == 0 then return end
        local ctrl, shift = isCtrl(), isShift()
        local cur = sel.cursor or 0
        local nx
        if key == KEY_UP then
            nx = math.Clamp(cur - 1, 1, n)
        elseif key == KEY_DOWN then
            nx = math.Clamp(cur + 1, 1, n)
        elseif key == KEY_HOME then
            nx = 1
        elseif key == KEY_END then
            nx = n
        end
        if nx then
            if shift and sel.anchor then selectRange(sel.anchor, nx) else selectOnly(nx) end
            scrollToIdx(nx)
        elseif key == KEY_ENTER or key == KEY_PAD_ENTER or key == KEY_SPACE then
            if shown[cur] then playItem(shown[cur]) end
        elseif ctrl and key == KEY_A then
            sel.anchor = 1
            selectRange(1, n)
        elseif key == KEY_E and shown[cur] then
            toggleExcluded(shown[cur])
        elseif key == KEY_F and shown[cur] then
            toggleFav(shown[cur])
        end
    end

    --MARK: refresh
    refresh = function(resetScroll)
        if not IsValid(list) then return end
        local pd = btb.musicPacks[selectedPack] or packData
        local startTrack = cookie.GetString("battlebeats_start_track", "")
        local all = {}
        counts, total = {}, 0
        local types = isAllMode and { "ambient", "combat" } or { trackType }
        for _, tType in ipairs(types) do
            for _, t in ipairs(pd[tType] or {}) do
                local td = btb.getTrackData(t)
                local trackName = btb.FormatTrackName(t)
                local sd = btb.getTrackData(string.lower(trackName), true)
                local subLangs = (sd and sd.hasSub) and btb.GetSubtitleLanguages(trackName) or {}
                local npcs = istable(td.npcMap) and #td.npcMap or 0
                local trim = td.trim
                local it = {
                    track = t,
                    type = tType,
                    td = td,
                    trackName = trackName,
                    alias = td.alias,
                    display = td.alias or trackName,
                    ex = td.exl and true or false,
                    fav = td.fav and true or false,
                    npcs = npcs,
                    subLangs = subLangs,
                    hasSub = #subLangs > 0,
                    hasVol = td.vol ~= nil,
                    trimActive = (trim and ((trim.start and trim.start > 0) or (trim.finish and trim.finish > 0))) and true or false,
                }
                it.lname = string.lower(it.display)

                local b = {}
                if npcs == 1 then
                    b[#b + 1] = {"icon16/user.png", "#btb.ps.ts.icon_assigned"}
                elseif npcs >= 2 then
                    b[#b + 1] = {"icon16/group.png", "#btb.ps.ts.icon_assigned_multiple"}
                end
                if trim ~= nil then b[#b + 1] = {"icon16/time.png", "#btb.ps.ts.icon_trim"} end
                if #subLangs > 0 then
                    local names = {}
                    for _, v in ipairs(subLangs) do names[#names + 1] = lm[v] or v end
                    b[#b + 1] = {#subLangs == 1 and "icon16/comment.png" or "icon16/comments.png", L("#btb.ps.ts.icon_subtitle") .. "\n" .. table.concat(names, ", ")}
                end
                if startTrack == t then b[#b + 1] = {"icon16/door_in.png", "#btb.ps.ts.icon_start"} end
                if td.vol ~= nil then b[#b + 1] = {"icon16/sound.png", "#btb.ps.ts.icon_volume"} end
                it.badges = b

                for _, def in ipairs(filterDefs) do
                    if def.test(it) then counts[def.id] = (counts[def.id] or 0) + 1 end
                end
                total = total + 1
                all[#all + 1] = it
            end
        end
        items = all

        local query = string.lower(tls.query or "")
        local out = {}
        for _, it in ipairs(all) do
            local ok = true
            for id in pairs(tls.filters) do
                local def = filterById[id]
                if def and not def.test(it) then
                    ok = false
                    break
                end
            end
            if ok and query ~= "" then
                local m = metaCache[it.track]
                ok = string.find(it.lname, query, 1, true) or string.find(string.lower(it.trackName), query, 1, true) or (m and m.q and string.find(m.q, query, 1, true))
                ok = ok and true or false
            end
            if ok then out[#out + 1] = it end
        end

        local mode = tls.sort
        if mode == "rnd" then
            local seed = tls.seed or "0"
            for _, it in ipairs(out) do it.rk = tonumber(util.CRC(seed .. it.track)) or 0 end
            table.sort(out, function(a, b) return a.rk < b.rk end)
        elseif mode ~= "playlist" then
            table.sort(out, function(a, b)
                if a.fav ~= b.fav then return a.fav end
                if a.lname ~= b.lname then
                    if mode == "za" then return a.lname > b.lname end
                    return a.lname < b.lname
                end
                return a.track < b.track
            end)
        end
        shown = out
        touch()

        local vis = {}
        for _, it in ipairs(shown) do vis[it.track] = true end
        for tr in pairs(sel.set) do
            if not vis[tr] then sel.set[tr] = nil end
        end
        if sel.primary and not vis[sel.primary] then sel.primary = nil end
        for i, it in ipairs(shown) do
            if it.track == sel.primary then
                sel.anchor, sel.cursor = i, i
                break
            end
        end

        ui.currentFilteredTracks = {}
        for _, it in ipairs(shown) do ui.currentFilteredTracks[#ui.currentFilteredTracks + 1] = it.track end
        if ui.previewKey == ctxKey then ui.previewList = ui.currentFilteredTracks end

        list.zoneIdx = nil
        list:SetTall(math.max(#shown * step + pad * 2, 90))
        if IsValid(chips) then chips:InvalidateLayout(true) end
        sc:GetCanvas():InvalidateLayout()
        if resetScroll then sc:GetVBar():SetScroll(0) end
    end

    refresh()

    local foundIdx
    for i, it in ipairs(shown) do
        if it.trackName == ui.selectedRow then
            sel.set = { [it.track] = true }
            sel.anchor, sel.cursor, sel.primary = i, i, it.track
            foundIdx = i
            break
        end
    end
    timer.Simple(0.1, function()
        if not IsValid(list) then return end
        if foundIdx then scrollToIdx(foundIdx, true) else sc:GetVBar():SetScroll(0) end
    end)
end
