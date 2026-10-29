local btb = BATTLEBEATS
btb.activeConflicts = btb.activeConflicts or {}
btb.wsCache = btb.wsCache or {}

local shared = btb.uiShared
local LerpColor = shared.LerpColor
local ColA = shared.ColA
local animHover = shared.animHover
local drawBlur = shared.drawBlur

local C = shared.Colors
local TL, TC, TR = TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT

local volumeCvar = GetConVar("battlebeats_volume")
local persistentNotification = GetConVar("battlebeats_persistent_notification")
local showPreviewNotification = GetConVar("battlebeats_show_preview_notification")
local toggleFrame = CreateClientConVar("battlebeats_context_ui_toogle", "0", true, false, "", 0, 1)
local customPackPanels = CreateClientConVar("battlebeats_custom_pack_panels", "1", true, false, "", 0, 1)

local debugCvar
local function isDebug()
    debugCvar = debugCvar or GetConVar("battlebeats_debug_mode")
    return debugCvar ~= nil and debugCvar:GetBool()
end

local frame
local volumePanel
local panelMenu
local activeTextEntries = {}

local btbClickSnd = "btb_button_click.mp3"
local e = {}

btb.packIcons = {
    ["battlebeats"] = Material("packicons/btb.png"),
    ["nombat"] = Material("packicons/nombat.jpg"),
    ["sbm"] = Material("packicons/sbm.jpg"),
    ["16thnote"] = Material("packicons/16th.jpg"),
    ["amusic"] = Material("packicons/amusic.jpg"),
    ["dynamo"] = Material("packicons/dynamo.jpg"),
    ["mp3p"] = Material("packicons/mp3p.jpg"),
    ["recordplayer"] = Material("packicons/recordplayer.jpg"),
    ["playlist"] = Material("btbplaylist.png"),
    ["na"] = Material("btbna.jpg")
}

local verMat = Material("btbver.png")
local blockMat = Material("btbblock.png")
local locMat = Material("btblocal.png")

btb.categoryNames = {
    debug = "DEBUG",
    battlebeats = "BattleBeats",
    nombat = "Nombat",
    sbm = "SBM",
    ["16thnote"] = "16th Note",
    amusic = "Action Music",
    dynamo = "DYNAMO",
    mp3p = "MP3 Radio",
    playlist = "Playlist",
    recordplayer = "Working Record Player",
    na = "Uncategorized",
    ["local"] = "Local"
}

btb.packOrder = {
    battlebeats = 1,
    nombat = 2,
    amusic = 3,
    ["16thnote"] = 4,
    recordplayer = 5,
    mp3p = 6,
    sbm = 7,
    dynamo = 8,
    playlist = 20,
    ["local"] = 97,
    na = 98
}

local packButtons = {
    { name = "Zenless Zone Zero", image = "promo/btbzzz.jpg", workshop = "3457857973" },
    { name = "The Witcher 3 Wild Hunt", image = "promo/btbtw3.jpg", workshop = "3483273863" },
    { name = "Devil May Cry 5", image = "promo/btbdmc.jpg", workshop = "3490225788" },
    { name = "Far Cry 4", image = "promo/btbfc4.jpg", workshop = "3548098038" },
    { name = "Cyberpunk 2077", image = "promo/btbcp.jpeg", workshop = "3556630048" },
    { name = "Resident Evil 4", image = "promo/btbre4.jpg", workshop = "3588540579" },
}

local P = {
    Btn = Color(60, 60, 60),
    C80 = Color(80, 80, 80),
    YellowDim = Color(200, 150, 0),
    Red = Color(255, 0, 0),
    ErrorBtn = Color(100, 0, 0),
    Idle = Color(50, 50, 50, 200),
    Hover = Color(65, 65, 65, 200),
    Error = Color(70, 50, 50, 200),
    DebugIdle = Color(100, 100, 60, 200),
    DebugHover = Color(110, 110, 60, 200),
    LocalIdle = Color(50, 80, 80, 200),
    LocalHover = Color(50, 120, 120, 200),
    Blocked = Color(10, 10, 10, 200),
    Ver = Color(255, 200, 0, 60),
    VerError = Color(150, 50, 0, 60),
    VerText = Color(255, 255, 255, 100),
    Divider = Color(240, 210, 100),
    TabIdle = Color(150, 150, 150),
    TabLine = Color(120, 120, 120, 150),
    TimerBar = Color(255, 255, 255, 90),
    Tag = Color(255, 255, 0),
    TextFail = Color(255, 150, 130),
    TextOk = Color(150, 255, 150),
}

local gradLeft = surface.GetTextureID("vgui/gradient-l")
local gradRight = surface.GetTextureID("vgui/gradient-r")

local function stepColor(cur, target, t)
    if cur == target then return cur end
    local c = LerpColor(t, cur, target)
    if math.abs(c.r - target.r) + math.abs(c.g - target.g) + math.abs(c.b - target.b) + math.abs(c.a - target.a) < 3 then
        return target
    end
    return c
end

local function stepNumber(cur, target, speed)
    local n = Lerp(FrameTime() * speed, cur, target)
    if math.abs(n - target) < 0.5 then return target end
    return n
end

local function hasDebugPack()
    for _, data in pairs(btb.musicPacks or e) do
        if data.debug then return true end
    end
    return false
end

--MARK:Notification panels
local NOTE = { INFO = 1, ERROR = 2, HINT = 3, WARN = 4, SUCCESS = 5 }
shared.NOTE = NOTE

local noteStyles = {
    [NOTE.INFO] = { icon = "btbinfo.png", text = "Information", color = Color(150, 150, 150, 150) },
    [NOTE.ERROR] = { icon = "btbcriticalerror.png", text = "Critical Error", pulse = true },
    [NOTE.HINT] = { icon = "btbhint.png", text = "Hint", color = Color(0, 200, 200, 150), closable = true },
    [NOTE.WARN] = { icon = "btberror.png", text = "Warning", color = Color(220, 120, 0, 150) },
    [NOTE.SUCCESS] = { icon = "btbinfo.png", text = "Success", color = Color(60, 170, 80, 150) },
}

local function dismiss(panel)
    if not IsValid(panel) or panel.Dismissing then return end
    panel.Dismissing = true
    panel:SizeTo(-1, 0, 0.5, 0, 0.5, function()
        if IsValid(panel) then panel:Remove() end
    end)
end

local function createBasePanel(parent, height, kind, margin, build, duration, closable)
    local style = noteStyles[kind or NOTE.WARN] or noteStyles[NOTE.WARN]
    closable = closable or style.closable
    local startTime = CurTime()
    local bg = style.pulse and Color(200, 50, 0, 150) or style.color

    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, margin and 0 or 5, 0, margin or 0)
    panel:SetTall(duration and (height + 4) or height)
    panel.Paint = function(self, w, h)
        if style.pulse then bg.r = 200 + math.abs(math.sin(CurTime() * 3)) * 50 end
        draw.RoundedBox(6, 0, 0, w, h, bg)
        if duration then
            local left = math.Clamp((startTime + duration - CurTime()) / duration, 0, 1)
            draw.RoundedBox(2, 0, h - 4, math.max(w * left, 4), 4, P.TimerBar)
        end
    end

    if duration then
        timer.Simple(duration, function() dismiss(panel) end)
    end

    local icon = vgui.Create("DImage", panel)
    icon:SetSize(36, 36)
    icon:SetPos(5, panel:GetTall() / 2 - 18)
    icon:SetImage(style.icon)
    icon:SetMouseInputEnabled(true)
    icon:SetTooltip(style.text)
    icon:SetTooltipPanelOverride("BattleBeatsTooltip")

    if closable then
        local btn = vgui.Create("DButton", panel)
        btn:SetSize(36, 36)
        btn:SetText("X")
        btn:SetTextColor(color_black)
        btn:SetFont("CloseCaption_Bold")
        btn.Paint = nil
        btn.DoClick = function()
            dismiss(panel)
            if isfunction(closable) then closable() end
        end
        panel.PerformLayout = function(self, w, h)
            btn:SetPos(w - 46, h / 2 - 18)
        end
    end

    if build then build(panel) end
    return panel
end

shared.createBasePanel = createBasePanel

local function addLabel(panel, text, color)
    local label = vgui.Create("DLabel", panel)
    label:Dock(TOP)
    label:SetTall(20)
    label:SetText(text)
    label:SetFont("BattleBeats_Notification_Font_Misc")
    label:SetTextColor(color or color_white)
    label:SetContentAlignment(5)
    return label
end

local vTimer = "BattleBeats_VerifyTimer"
local verify = {
    running = false,
    queue = {},
    pos = 1,
    total = 0,
    packTotal = 0,
    activePack = nil,
    errors = {},
    errorsByPack = {},
    startedAt = 0,
    report = nil,
    onFinish = nil,
}

local function dbgPrint(...)
    MsgC(P.Tag, "[BattleBeats Debug] ", color_white, ...)
end

local function setActivePack(name)
    local old = verify.activePack and btb.musicPacks[verify.activePack]
    if old then old.verifying = false end
    verify.activePack = name
    local new = name and btb.musicPacks[name]
    if new then new.verifying = true end
end

local function registerError(item, track, code, msg)
    if not verify.running then return end
    local entry = { pack = item.pack, type = item.type, track = track or item.track, code = code, msg = msg }
    verify.errors[#verify.errors + 1] = entry
    local list = verify.errorsByPack[item.pack]
    if not list then
        list = {}
        verify.errorsByPack[item.pack] = list
    end
    list[#list + 1] = entry
    local pd = btb.musicPacks[item.pack]
    if pd then pd.error = "track_error\nOne or more tracks have an error\nCheck the verification report!" end
    dbgPrint(
        "Error in pack '", Color(0, 255, 255), item.pack, color_white, "' - ",
        P.Tag, item.type .. " ", color_white, "track: ", tostring(entry.track) .. " ",
        "Code: ", Color(0, 255, 255), tostring(code) .. " ",
        color_white, "Error: ", Color(255, 0, 255), tostring(msg) .. "\n"
    )
end

local function finishVerification()
    setActivePack(nil)
    timer.Remove(vTimer)
    verify.running = false
    btb.checking = false

    local errorCount = #verify.errors
    verify.report = {
        failed = errorCount > 0,
        errorCount = errorCount,
        failedPacks = table.Count(verify.errorsByPack),
        trackCount = verify.total,
        packCount = verify.packTotal,
        duration = SysTime() - verify.startedAt,
        errors = verify.errors,
    }

    if errorCount > 0 then
        dbgPrint("Pack verification", Color(255, 0, 0), " FAILED! ", color_white, "Found ", Color(255, 0, 0), tostring(errorCount), color_white, " error(s)\n")
        notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.ps.verification.failed_1") .. " " .. errorCount .. " " .. language.GetPhrase("btb.ps.verification.failed_2"), NOTIFY_ERROR, 4)
        surface.PlaySound("buttons/button8.wav")
    else
        dbgPrint("Pack verification", Color(0, 255, 0), " PASSED! ", color_white, "No errors found\n")
        notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.ps.verification.pass"), NOTIFY_HINT, 4)
        surface.PlaySound("buttons/button14.wav")
    end

    local cb = verify.onFinish
    verify.onFinish = nil
    if cb then cb() end
end

local function runNextTrack()
    if not verify.running then return end
    local item = verify.queue[verify.pos]
    if not item then return finishVerification() end

    if item.pack ~= verify.activePack then
        setActivePack(item.pack)
        dbgPrint("Verifying pack: ", Color(0, 255, 255), item.pack .. "\n")
    end

    btb.ValidateTrack(item.track, function(track, errCode, errStr)
        registerError(item, track, errCode, errStr)
    end)

    verify.pos = verify.pos + 1
    timer.Create(vTimer, 0.05, 1, runNextTrack)
end

local function startVerification(onFinish)
    if verify.running then return false end

    local names = {}
    for name, data in pairs(btb.musicPacks) do
        if data.debug then names[#names + 1] = name end
    end
    if #names == 0 then return false end
    table.sort(names)

    verify.queue = {}
    verify.errors = {}
    verify.errorsByPack = {}
    verify.report = nil
    verify.pos = 1
    verify.activePack = nil
    verify.packTotal = #names
    verify.onFinish = onFinish

    for _, name in ipairs(names) do
        local data = btb.musicPacks[name]
        if isstring(data.error) and string.StartWith(data.error, "track_error") then data.error = nil end
        for _, track in ipairs(data.ambient or e) do
            verify.queue[#verify.queue + 1] = { pack = name, track = track, type = "ambient" }
        end
        for _, track in ipairs(data.combat or e) do
            verify.queue[#verify.queue + 1] = { pack = name, track = track, type = "combat" }
        end
    end
    verify.total = #verify.queue
    verify.startedAt = SysTime()
    verify.running = true
    btb.checking = true

    dbgPrint("Starting verification...\n")
    runNextTrack()
    return true
end

local function cancelVerification()
    if not verify.running then return end
    timer.Remove(vTimer)
    setActivePack(nil)
    verify.running = false
    verify.onFinish = nil
    verify.report = nil
    btb.checking = false
    dbgPrint("Pack verification", Color(255, 0, 0), " CANCELED!\n")
    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.ps.verification.cancel"), NOTIFY_ERROR, 4)
    surface.PlaySound("buttons/button8.wav")
end

local function getPackErrorText(packName, packData)
    local lines = { "Pack error: " .. tostring(packData.error or "#btb.ps.unknown_error") }
    local list = verify.errorsByPack[packName]
    if list then
        for i = 1, math.min(#list, 4) do
            lines[#lines + 1] = "- " .. tostring(btb.FormatTrackName(list[i].track))
        end
        if #list > 4 then lines[#lines + 1] = "+ " .. (#list - 4) .. " more" end
    end
    return table.concat(lines, "\n")
end

local function showVerifyReport(ui)
    local report = verify.report
    if not report or not ui.debugMode then return end

    local summary, color
    if report.failed then
        summary = string.format("Verification FAILED: %d error(s) in %d pack(s)  |  %d tracks checked in %.1fs", report.errorCount, report.failedPacks, report.trackCount, report.duration)
        color = P.TextFail
    else
        summary = string.format("Verification PASSED: %d tracks in %d pack(s), no errors  |  %.1fs", report.trackCount, report.packCount, report.duration)
        color = P.TextOk
    end

    local lines = {}
    local shown = math.min(#report.errors, 5)
    for i = 1, shown do
        local e = report.errors[i]
        lines[i] = string.format("%s / %s: %s  (code %s: %s)", btb.stripPackPrefix(e.pack), e.type, tostring(btb.FormatTrackName(e.track)), tostring(e.code), tostring(e.msg))
    end
    if #report.errors > shown then
        lines[#lines + 1] = string.format("... and %d more (see console)", #report.errors - shown)
    end

    createBasePanel(ui.scrollPanel, math.max(40, 20 * (1 + #lines) + 6),
        report.failed and NOTE.WARN or NOTE.SUCCESS, nil, function(panel)
            panel:DockPadding(0, 3, 0, 3)
            addLabel(panel, summary, color)
            for _, text in ipairs(lines) do addLabel(panel, text) end
        end, nil, function() verify.report = nil end)
end

local function showConflicts(ui)
    local function notify(lines)
        createBasePanel(ui.scrollPanel, 40, nil, nil, function(panel)
            for _, text in ipairs(lines) do addLabel(panel, text) end
        end)
    end
    if (btb.errorCount or 0) > 3 then
        notify({"Multiple track errors occurred or the audio system failed (BASS)", "Verify or change your packs and type 'battlebeats_restart' in console to resume playback"})
    end
    if not table.IsEmpty(btb.activeConflicts) then
        notify({language.GetPhrase("btb.ps.error.conflict1") .. ": " .. table.concat(table.GetKeys(btb.activeConflicts), ", "), "#btb.ps.error.conflict2"})
    end
    if ui.debugMode then
        notify({"#btb.ps.error.debug1", "#btb.ps.error.debug2"})
    end
    showVerifyReport(ui)
end

--MARK:Pack panel pieces
local function makeModeButton(panel, x, w, text, disabled, tip, onClick)
    local b = vgui.Create("DButton", panel)
    b:SetVisible(false)
    b:SetSize(w, 30)
    b:SetPos(x, 80)
    b:SetText(text)
    b:SetFont("DermaDefaultBold")
    if disabled then
        b:SetCursor("no")
        b:BTB_SetButton(P.YellowDim, C.C40, nil, true)
        if tip then
            b:SetTooltip(tip)
            b:SetTooltipPanelOverride("BattleBeatsTooltip")
        end
        b:SetTextColor(C.C200)
    else
        b:SetTextColor(color_white)
        b:BTB_SetButton(C.Yellow, P.Btn, C.C90)
    end
    b.DoClick = function()
        if disabled then return end
        surface.PlaySound(btbClickSnd)
        onClick()
    end
    b.packPanel = panel
    return b
end

local function createModeButtons(panel, packName, packData)
    if not IsValid(panel) or IsValid(panel.ambientButton) then return end
    local w, spacing = 350, 20
    local allW = w / 2
    local startX = (950 - (w * 2 + allW + spacing * 2)) / 2
    local content = packData.packContent
    local empty = content == "empty"

    panel.ambientButton = makeModeButton(panel, startX, w, "#btb.ps.info.ambient_button",
        empty or content == "combat", "#btb.ps.info.ambient_button_tip",
        function() btb.openTrackList("ambient", packName) end)

    panel.allButton = makeModeButton(panel, startX + w + spacing, allW, "#btb.ps.info.all_button",
        empty, nil, function() btb.openTrackList("all", packName) end)

    panel.combatButton = makeModeButton(panel, startX + w + spacing + allW + spacing, w, "#btb.ps.info.combat_button",
        empty or content == "ambient", "#btb.ps.info.combat_button_tip",
        function() btb.openTrackList("combat", packName) end)
end

local function formatTrackList(tracks)
    local sorted = table.Copy(tracks)
    table.sort(sorted)
    local lines = {}
    for _, track in ipairs(sorted) do
        lines[#lines + 1] = "[*] " .. btb.FormatTrackName(track)
    end
    return "[olist]\n" .. table.concat(lines, "\n") .. "\n[/olist]"
end

local function addOpt(menu, panel, text, icon, fn, tip)
    local o = menu:AddOption(text, fn)
    o.packPanel = panel
    if icon then o:SetImage(icon) end
    if tip then
        o:SetTooltip(tip)
        o:SetTooltipPanelOverride("BattleBeatsTooltip")
    end
    o:BTB_PaintProperties()
    return o
end

local function openPackMenu(ui, panel, packName, packData, isPlaylist)
    local menu = DermaMenu()
    panelMenu = menu
    menu.packPanel = panel

    if isPlaylist then
        addOpt(menu, panel, "#btb.playlist.edit", "icon16/layout_edit.png", function()
            btb.openPlaylistEditor(packName, function() ui.refreshPacks(true) end)
        end)
        addOpt(menu, panel, "#btb.playlist.delete", "icon16/layout_delete.png", function()
            Derma_Query("#btb.playlist.delete_conf", "#btb.playlist.delete", "#btb.playlist.delete_button", function()
                btb.musicPlaylists[packName] = nil
                btb.musicPacks[packName] = nil
                btb.packVolume[packName] = nil
                btb.savePlaylists()
                ui.refreshPacks(true)
                surface.PlaySound("buttons/button15.wav")
                ui.changesMade = true
            end, "#btb.main.volume_cancel", function()
                surface.PlaySound("buttons/button10.wav")
            end)
        end)
        addOpt(menu, panel, "#btb.playlist.export", "icon16/group_go.png", function()
            SetClipboardText(btb.exportPlaylist(packName))
            surface.PlaySound("buttons/button14.wav")
            notification.AddLegacy("#btb.playlist.export_noti", NOTIFY_GENERIC, 3)
        end, "#btb.playlist.export_tip")
    else
        local vol = btb.packVolume[packName] ~= nil and (btb.packVolume[packName] - 100) or 0
        local volumeText = vol ~= 0 and (language.GetPhrase("btb.ps.pack_rmb.edit_volume") .. " [" .. vol .. "%]") or "#btb.ps.pack_rmb.set_volume"
        addOpt(menu, panel, volumeText, "icon16/sound.png", function()
            btb.openVolumeEditor(frame, nil, packName)
        end)
        addOpt(menu, panel, "#btb.ps.pack_rmb.copy", "icon16/page_copy.png", function()
            local parts = {}
            if packData.ambient and #packData.ambient > 0 then
                parts[#parts + 1] = "[h2]Ambient:[/h2]\n" .. formatTrackList(packData.ambient)
            end
            if packData.combat and #packData.combat > 0 then
                parts[#parts + 1] = "[h2]Combat:[/h2]\n" .. formatTrackList(packData.combat)
            end
            SetClipboardText(table.concat(parts, "\n\n"))
            surface.PlaySound("buttons/button14.wav")
            notification.AddLegacy("#btb.ps.pack_rmb.copy_noti", NOTIFY_GENERIC, 3)
        end, "#btb.ps.pack_rmb.copy_tip")
    end

    if packData.wsid then
        addOpt(menu, panel, "#btb.ps.pack_rmb.open_workshop", "icon16/world_go.png", function()
            steamworks.ViewFile(packData.wsid)
        end)
    end

    menu:Open()
    menu.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.Yellow)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, C.C50)
    end
end

--MARK: Pack panel
local function buildPackPanel(ui, entry)
    local packName, packData = entry.name, entry.data
    local packType = packData.packType or "na"
    local isPlaylist = packType == "playlist"
    local debugMode = ui.debugMode
    local blocked = debugMode and not packData.debug

    local function errored() return packData.error ~= nil end
    local function enabled() return btb.currentPacks[packName] end

    local wrapper = ui.scrollPanel:Add("DPanel")
    wrapper:Dock(TOP)
    wrapper:SetTall(80)
    wrapper:DockMargin(5, 0, 5, 8)
    wrapper.Paint = nil

    local panel = wrapper:Add("DPanel")
    panel:SetAlpha(0)
    panel:AlphaTo(255, 0.1)
    panel.packPanel = panel
    panel.isPackPanel = true
    panel.packName = packName
    panel.wrapper = wrapper
    panel.packData = packData

    local override
    if not debugMode and not isPlaylist and customPackPanels:GetBool() then
        override = hook.Run("BattleBeats_BuildPackPanel", panel, packName, packData)
    end
    if override ~= nil then
        local reason
        if not IsValid(override) then
            reason = "Hook returned invalid panel for pack:"
        elseif override.fadeTargets == nil then
            reason = "Missing field 'fadeTargets' in hook panel:"
        end
        if reason then
            btb.print(2, "UI", reason, packName)
            btb.print(2, "UI", "Hook panel rejected:", packName)
            if IsValid(override) and override ~= panel then override:Remove() end
            override = nil
        end
    end

    local target = override or panel
    target.packPanel = target.packPanel or target
    target.packName = target.packName or packName
    target.packData = target.packData or packData
    target.wrapper = target.wrapper or wrapper
    wrapper.PerformLayout = function(self)
        if IsValid(target) then target:CenterHorizontal(0.5) end
    end
    target.OnMousePressed = function() end
    target.OnMouseReleased = function(self, keyCode)
        if keyCode == MOUSE_RIGHT then
            openPackMenu(ui, panel, packName, packData, isPlaylist)
            return
        end
        if verify.running and not blocked then
            notification.AddLegacy("#btb.ps.noti.cant_edit_ver", NOTIFY_ERROR, 3)
            surface.PlaySound("buttons/button10.wav")
        elseif errored() then
            notification.AddLegacy("#btb.ps.noti.cant_edit_error", NOTIFY_ERROR, 3)
            surface.PlaySound("buttons/button10.wav")
        elseif blocked then
            notification.AddLegacy("#btb.ps.noti.cant_edit_debug", NOTIFY_ERROR, 3)
            surface.PlaySound("buttons/button10.wav")
        elseif IsValid(wrapper) and IsValid(ui.scrollPanel) then
            ui.scrollPanel:ScrollToChild(wrapper)
        end
    end

    if override then
        ui.packPanels[#ui.packPanels + 1] = override
        return
    end

    panel:SetSize(900, 80)
    ui.packPanels[#ui.packPanels + 1] = panel

    local checkbox = vgui.Create("DButton", panel)
    checkbox:SetText("")
    checkbox.packText = enabled() and "#btb.ps.pack_enabled" or "#btb.ps.pack_disabled"
    checkbox.packPanel = panel
    checkbox:SetVisible(false)

    createModeButtons(panel, packName, packData)
    if not isPlaylist and packType ~= "local" and packData.source ~= "local" then
        btb.createInfoPanel(panel, packData, function(sizeP, dateP, authorP)
            if IsValid(sizeP) then sizeP.packPanel = panel end
            if IsValid(dateP) then dateP.packPanel = panel end
            if IsValid(authorP) then authorP.packPanel = panel end
        end)
    end

    local function showError()
        if IsValid(panel.errorIcon) then return end
        local icon = vgui.Create("DImage", panel)
        icon.packPanel = panel
        icon:SetPos(840, 28)
        icon:SetSize(24, 24)
        icon:SetImage("icon16/exclamation.png")
        icon:SetTooltip(getPackErrorText(packName, packData))
        icon.OnCursorEntered = function(self)
            self:SetTooltip(getPackErrorText(packName, packData))
        end
        icon:SetTooltipPanelOverride("BattleBeatsTooltip")
        icon:SetMouseInputEnabled(true)
        panel.errorIcon = icon
    end

    if not debugMode and not isPlaylist and customPackPanels:GetBool() then
        hook.Run("BattleBeats_ModifyPackPanel", panel, packName, packData)
    end

    panel.currentColor = P.Idle
    panel.targetColor = P.Idle
    panel.initialized = false
    panel.isExpanded = false
    panel.isCollapsed = false
    panel.fadeTargets = { checkbox, panel.ambientButton, panel.allButton, panel.combatButton }

    panel.Think = function(self)
        if packData.error and not IsValid(self.errorIcon) then showError() end
        if packData.verifying then return end

        local tc
        if packData.error then
            tc = P.Error
        elseif packData.debug == true then
            tc = self.isExpanded and P.DebugHover or P.DebugIdle
        elseif packType == "local" then
            tc = self.isExpanded and P.LocalHover or P.LocalIdle
        else
            tc = self.isExpanded and (self.customHoverColor or P.Hover) or (self.customColor or P.Idle)
        end
        self.targetColor = tc
        if not self.initialized then
            self.initialized = true
            self.currentColor = tc
            return
        end
        self.currentColor = stepColor(self.currentColor, tc, FrameTime() * 10)
    end

    local sweepW = 300
    panel.Paint = function(self, w, h)
        if packData.verifying then
            local vColor = errored() and P.VerError or P.Ver
            draw.RoundedBox(6, 0, 0, w, h, vColor)

            local barX = ((CurTime() * 1000) % (w + 200)) - sweepW
            local loopX = barX - (w + sweepW)
            surface.SetDrawColor(vColor.r, vColor.g, vColor.b, 200)
            for _, x in ipairs({ barX, loopX }) do
                surface.SetTexture(gradRight)
                surface.DrawTexturedRect(x, 0, sweepW / 2, h)
                surface.SetTexture(gradLeft)
                surface.DrawTexturedRect(x + sweepW / 2, 0, sweepW / 2, h)
            end
            return
        elseif blocked then
            draw.RoundedBox(6, 0, 0, w, h, P.Blocked)
            return
        end
        draw.RoundedBox(6, 0, 0, w, h, self.currentColor)
        btb.drawRoundedOutline(6, 0, 0, w, h, 1, enabled() and C.Yellow or P.Red)
    end

    panel.OnCursorEntered = function(self)
        if packData.verifying then
            self:SetCursor("hourglass")
        elseif errored() or blocked then
            self:SetCursor("no")
        end
    end
    panel.OnCursorExited = function(self) self:SetCursor("arrow") end

    local formattedName = panel.customTitle or btb.stripPackPrefix(packName)
    local iconMat = panel.customIcon and Material(panel.customIcon) or
    (btb.packIcons[packData.packType] or btb.packIcons["na"])
    local cFont = panel.customFont or "BattleBeats_Font"

    local packLabel = vgui.Create("DPanel", panel)
    packLabel.packPanel = panel
    packLabel:SetPos(10, 5)
    packLabel:SetSize(800, 80)
    packLabel:SetPaintBackground(false)
    packLabel:SetMouseInputEnabled(false)
    packLabel:SetKeyboardInputEnabled(false)
    packLabel.Paint = function()
        if packData.verifying or blocked then
            surface.SetMaterial(packData.verifying and verMat or blockMat)
            surface.SetDrawColor(255, 255, 255, 150)
            surface.DrawTexturedRect(0, 2, 65, 65)
            draw.SimpleText(formattedName, "BattleBeats_Font", 80, 35, P.VerText, TL, TC)
            return
        end
        surface.SetMaterial(packType == "local" and locMat or iconMat)
        surface.SetDrawColor(color_white)
        surface.DrawTexturedRect(0, 2, 65, 65)
        draw.SimpleTextOutlined(formattedName, cFont, 80, 35, color_white, TL, TC, 1, C.Off)
    end

    -- enable / disable button
    checkbox:SetSize(90, 30)
    checkbox:SetPos(840, 25)
    checkbox.OnCursorEntered = function(self)
        self:SetCursor((not errored() and not packData.verifying and not debugMode) and "hand" or "no")
    end
    checkbox.DoClick = function(self)
        if errored() then return end
        if debugMode then
            notification.AddLegacy("#btb.ps.noti.cant_toggle", NOTIFY_ERROR, 3)
            surface.PlaySound("buttons/button10.wav")
            return
        end
        ui.changesMade = true
        if enabled() then
            btb.currentPacks[packName] = nil
            surface.PlaySound("btb_button_disable.mp3")
            self:BTB_UpdatePackButton(checkbox, "disabled")
        else
            btb.currentPacks[packName] = true
            surface.PlaySound("btb_button_enable.mp3")
            self:BTB_UpdatePackButton(checkbox, "enabled")
        end
    end

    local baseColor = errored() and P.ErrorBtn or (enabled() and C.Yellow or P.Red)
    checkbox:BTB_SetPackButton(baseColor, Color(baseColor.r + 50, baseColor.g + 50, baseColor.b + 50))
    checkbox.Think = function(self)
        if debugMode and not errored() then
            self:BTB_UpdatePackButton(checkbox, "debug")
        end
    end

    if errored() then showError() end
end

--MARK:Main UI pieces
local function createCategoryDivider(ui, text)
    local div = vgui.Create("DPanel", ui.scrollPanel)
    div:Dock(TOP)
    div:SetTall(40)
    div:DockMargin(20, 5, 20, 5)
    local textW
    div.Paint = function(self, w, h)
        if not textW then
            surface.SetFont("BattleBeats_Font")
            textW = surface.GetTextSize(text)
        end
        local lineY = h / 2
        local textX = w * 0.15
        local leftEnd = textX - 10
        local rightStart = textX + textW + 10
        if leftEnd > 0 then draw.RoundedBox(2, 0, lineY, leftEnd, 3, P.Divider) end
        if w > rightStart then draw.RoundedBox(2, rightStart, lineY, w - rightStart, 3, P.Divider) end
        draw.SimpleText(text, "BattleBeats_Font", textX + textW / 2, lineY, P.Divider, TC, TC)
    end
end

local function buildTabs(ui, onChange)
    local bar = vgui.Create("DPanel", ui.scrollPanel)
    bar:Dock(TOP)
    bar:SetTall(40)
    bar.Paint = nil

    local function addTab(dock, filter, phrase)
        local b = vgui.Create("DButton", bar)
        b:Dock(dock)
        b:SetWide(500)
        b:SetText("")
        b:SetEnabled(not ui.debugMode)
        local label = language.GetPhrase(phrase)
        b.OnCursorEntered = function() surface.PlaySound("ui/buttonrollover.wav") end
        b.Paint = function(self, w, h)
            local active = ui.currentFilter == filter
            local usable = self:IsHovered() and self:IsEnabled()
            draw.SimpleText(label, "BattleBeats_Font", w / 2, h / 2 - 5,
                active and color_white or (usable and C.C200 or P.TabIdle), TC, TC)
            local lineW = w * (active and 0.6 or (usable and 0.4 or 0.2))
            self.LineW = Lerp(FrameTime() * 14, self.LineW or lineW, lineW)
            draw.RoundedBox(2, (w - self.LineW) / 2, h - 6, self.LineW, 3, active and C.Yellow or P.TabLine)
        end
        b.DoClick = function()
            if ui.currentFilter == filter then return end
            surface.PlaySound(btbClickSnd)
            ui.currentFilter = filter
            onChange()
        end
    end
    addTab(LEFT, "packages", "btb.ps.tab_packs")
    addTab(RIGHT, "playlists", "btb.ps.tab_playlists")
end

local function buildPromo(ui)
    if IsValid(ui.promoPanel) then ui.promoPanel:Remove() end

    local text1 = language.GetPhrase("btb.ps.no_packs_found_1")
    local text2 = language.GetPhrase("btb.ps.no_packs_found_2")

    local promo = vgui.Create("DPanel", frame)
    ui.promoPanel = promo
    promo:SetSize(850, 400)
    promo:SetPos(80, 150)
    promo.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.Yellow)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, C.C50)
        draw.SimpleText(text1, "CloseCaption_Bold", w / 2, 30, color_white, TC, TC)
        draw.SimpleText(text2, "CloseCaption_Bold", w / 2, 365, color_white, TC, TC)
    end

    local link = vgui.Create("DButton", promo)
    link:SetSize(75, 30)
    link:SetPos(600, 350)
    link:SetText("")
    link:SetCursor("hand")
    link.Paint = nil
    link.DoClick = function()
        gui.OpenURL("https://steamcommunity.com/workshop/filedetails/discussion/3473911205/624436764983085955/")
    end

    local pool = {}
    for i, pack in ipairs(packButtons) do pool[i] = pack end
    table.Shuffle(pool)

    for i = 1, math.min(3, #pool) do
        local pack = pool[i]
        local card = vgui.Create("DButton", promo)
        card:SetSize(250, 270)
        card:SetPos(30 + (i - 1) * 270, 60)
        card:SetText("")
        card.OnCursorEntered = function() surface.PlaySound("ui/buttonrollover.wav") end
        card.DoClick = function() steamworks.ViewFile(pack.workshop) end
        card.Paint = function(self, w, h)
            local hov = animHover(self, "Hov", self:IsHovered())
            pack.mat = pack.mat or Material(pack.image, "smooth")
            draw.RoundedBox(6, 0, 0, w, h, LerpColor(hov, C.C70, P.C80))
            if hov > 0.01 then
                draw.RoundedBox(6, 0, 0, w, h, ColA(C.Yellow, 255 * hov))
                draw.RoundedBox(5, 1, 1, w - 2, h - 2, LerpColor(hov, C.C70, P.C80))
            end
            surface.SetDrawColor(color_white)
            surface.SetMaterial(pack.mat)
            surface.DrawTexturedRect(10, 10, 230, 220)
            surface.SetDrawColor(0, 0, 0, 200)
            surface.DrawOutlinedRect(10, 10, 230, 220, 2)
            draw.SimpleText(pack.name, "CreditsText", w / 2, 250, color_white, TC, TC)
        end
    end
end

local function syncVerifyButton(ui)
    local want = ui.debugMode and hasDebugPack()
    if not want then
        if IsValid(ui.verifyButton) then ui.verifyButton:Remove() end
        ui.verifyButton = nil
        return
    end
    if IsValid(ui.verifyButton) then return end

    local b = vgui.Create("DButton", frame)
    ui.verifyButton = b
    b:SetSize(220, 20)
    b:SetPos(650, 10)
    b:SetText("")
    b:SetCursor("hand")
    b.OnCursorEntered = function(self)
        self:SetTooltip(verify.running and "Click to cancel verification" or "Check every track of the debug packs")
        self:SetTooltipPanelOverride("BattleBeatsTooltip")
    end
    b.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered())
        local errors = #verify.errors
        if verify.running then
            draw.RoundedBox(8, 0, 0, w, h, C.C50)
            local frac = verify.total > 0 and (verify.pos - 1) / verify.total or 0
            if frac > 0 then
                draw.RoundedBox(8, 0, 0, math.max(w * frac, 16), h, ColA(C.Yellow, 90 + 40 * hov))
            end
            draw.SimpleText(string.format("Verifying %d/%d  |  %d error(s)", verify.pos - 1, verify.total, errors), "DermaDefaultBold", w / 2, h / 2, errors > 0 and P.TextFail or color_white, TC, TC)
        else
            draw.RoundedBox(8, 0, 0, w, h, LerpColor(hov, C.C70, C.C100))
            draw.SimpleText("Verify Packs", "DermaDefaultBold", w / 2, h / 2, color_white, TC, TC)
        end
    end
    b.DoClick = function()
        surface.PlaySound(btbClickSnd)
        if verify.running then
            cancelVerification()
            return
        end
        if startVerification(function() ui.refreshPacks(true) end) then
            ui.refreshPacks(true)
        end
    end
end

--MARK:Bottom bar widgets
local volumeMats = {}
for i = 0, 3 do volumeMats[i] = Material("volume/v" .. i .. ".png", "smooth") end
local function volumeMat(progress)
    if progress < 0.01 then return volumeMats[0] end
    if progress < 0.3 then return volumeMats[1] end
    if progress < 0.75 then return volumeMats[2] end
    return volumeMats[3]
end

local function makeIconButton(parent, x, y, mat, tip, onClick)
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y)
    b:SetSize(40, 40)
    b:SetText("")
    b:SetCursor("hand")
    b:SetTooltip(tip)
    b:SetTooltipPanelOverride("BattleBeatsTooltip")
    b.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered())
        local down = self:IsDown()
        draw.RoundedBox(10, 0, 0, w, h, LerpColor(hov, C.C70, C.Yellow))
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, down and C.C40 or LerpColor(hov, C.C50, C.C70))
        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255, 190 + 65 * hov)
        surface.DrawTexturedRect(6, down and 7 or 6, 28, 28)
    end
    b.DoClick = function()
        surface.PlaySound(btbClickSnd)
        onClick()
    end
    return b
end

local volWoff, volWon = 40, 230
local vol0, vol1 = 46, volWon - 52
local function buildVolume(parent)
    local p = vgui.Create("DPanel", parent)
    volumePanel = p
    p:SetPos(56, 650)
    p:SetSize(volWoff, 40)
    p:SetCursor("hand")
    p.Progress = volumeCvar:GetInt() / 200
    p.Open = 0

    local function setProgress(v, snap)
        v = math.Clamp(v, 0, 1)
        if snap and math.abs(v - 0.5) < 0.015 then v = 0.5 end
        p.Progress = v
        volumeCvar:SetInt(math.Round(v * 200))
    end
    local function setFromCursor()
        local x = p:CursorPos()
        setProgress((x - vol0) / (vol1 - vol0), not input.IsShiftDown())
    end

    p.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        local x = self:CursorPos()
        if x < volWoff or self.Open < 0.5 then
            surface.PlaySound(btbClickSnd)
            if self.Progress > 0 then
                self.Restore = self.Progress
                setProgress(0)
            else
                setProgress(self.Restore or 0.5)
            end
            return
        end
        self.Drag = true
        self:MouseCapture(true)
        setFromCursor()
    end
    p.OnMouseReleased = function(self)
        self.Drag = false
        self:MouseCapture(false)
    end
    p.OnMouseWheeled = function(self, d)
        setProgress(self.Progress + d * 0.025)
        return true
    end
    p.Think = function(self)
        if self.Drag then
            if input.IsMouseDown(MOUSE_LEFT) then
                setFromCursor()
            else
                self.Drag = false
                self:MouseCapture(false)
            end
        end
        local want = (self.Drag or self:IsHovered()) and 1 or 0
        self.Open = Lerp(FrameTime() * 14, self.Open, want)
        if math.abs(self.Open - want) < 0.01 then self.Open = want end
        local w = math.Round(Lerp(self.Open, volWoff, volWon))
        if w ~= self:GetWide() then self:SetWide(w) end
    end

    p.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered() or self.Drag)
        draw.RoundedBox(10, 0, 0, w, h, LerpColor(hov, C.C70, C.Yellow))
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, LerpColor(hov, C.C50, C.C70))
        surface.SetMaterial(volumeMat(self.Progress))
        surface.SetDrawColor(255, 255, 255, 190 + 65 * hov)
        surface.DrawTexturedRect(6, 6, 28, 28)

        if self.Open < 0.05 then return end
        local a = 255 * self.Open
        local len = vol1 - vol0
        local fill = len * self.Progress
        draw.RoundedBox(3, vol0, h / 2 - 3, len, 6, ColA(C.Track, a))
        surface.SetDrawColor(255, 255, 255, a * 0.3)
        if fill > 0 then
            draw.RoundedBox(3, vol0, h / 2 - 3, math.max(fill, 6), 6, ColA(C.Yellow, a))
        end
        draw.RoundedBox(6, vol0 + fill - 6, h / 2 - 6, 12, 12, ColA(color_white, a))
        draw.SimpleText(string.format("%d%%", math.Round(self.Progress * 200)), "DermaDefaultBold", volWon - 8, h / 2, ColA(C.Text, a), TR, TC)
    end
    return p
end

local function buildScrollHint(ui)
    local b = vgui.Create("DButton", frame)
    b:SetSize(44, 26)
    b:SetText("")
    b:SetCursor("hand")
    b.Alpha = 0
    b.DoClick = function()
        surface.PlaySound(btbClickSnd)
        ui.scrollBar:AddScroll(5)
    end
    b.Think = function(self)
        local sp, vbar = ui.scrollPanel, ui.scrollBar
        local canScroll = IsValid(sp) and sp:IsVisible() and vbar.CanvasSize ~= nil and vbar:GetScroll() < vbar.CanvasSize - 60 and not ui.isTrackSelectorOpen
        self.Alpha = Lerp(FrameTime() * 10, self.Alpha, canScroll and 1 or 0)
        self:SetAlpha(255 * self.Alpha)
        self:SetMouseInputEnabled(self.Alpha > 0.5)
        if IsValid(sp) then
            self:SetPos(sp.x + sp:GetWide() / 2 - 22, sp.y + sp:GetTall() - 32)
        end
    end
    b.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered())
        draw.RoundedBox(12, 0, 0, w, h, LerpColor(hov, C.C70, C.Yellow))
        draw.RoundedBox(11, 1, 1, w - 2, h - 2, LerpColor(hov, C.C50, C.C70))
        local cx, cy = w / 2, h / 2 + math.sin(CurTime() * 4) * 1.5
        surface.SetDrawColor(255, 255, 255, 200 + 55 * hov)
        for o = 0, 1 do
            surface.DrawLine(cx - 6, cy - 3 + o, cx, cy + 3 + o)
            surface.DrawLine(cx, cy + 3 + o, cx + 6, cy - 3 + o)
        end
    end
    b:MoveToFront()
    return b
end

--MARK:Preview player panel
local function flatButton(parent, text, x, y, size, tip, onClick)
    local b = vgui.Create("DButton", parent)
    b:SetSize(size, size)
    b:SetPos(x, y)
    b:SetText(text)
    b:SetFont("DermaLarge")
    b:SetTextColor(color_white)
    b.Paint = nil
    if tip then
        b:SetTooltip(tip)
        b:SetTooltipPanelOverride("BattleBeatsTooltip")
    end
    b.DoClick = onClick
    return b
end

local function wrapIndex(i, n)
    if i < 1 then return n end
    if i > n then return 1 end
    return i
end

local function buildPlayerPanel(ui)
    local panel = vgui.Create("DPanel", frame)
    panel:SetSize(980, 170)
    panel:SetPos(10, 460)
    panel:SetVisible(false)
    local cx = panel:GetWide() / 2

    local fullParts = {}
    local function part(p)
        fullParts[#fullParts + 1] = p
        return p
    end

    panel.Paint = function(self, w, h)
        local st = btb.currentPreviewStation
        local valid = IsValid(st)
        local ty = ui.playerMin and 19 or 130
        draw.RoundedBox(10, 0, 0, w, h, C.Yellow)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, C.C40)
        draw.SimpleText(btb.FormatTime(valid and st:GetTime() or 0), "DermaDefaultBold", 50, ty, color_white, TL, TC)
        draw.SimpleText(btb.FormatTime(valid and st:GetLength() or 0), "DermaDefaultBold", 930, ty, color_white, TR, TC)
    end

    local playPause = part(flatButton(panel, "▶", cx - 28, 50, 50, nil, function()
        local st = btb.currentPreviewStation
        if not IsValid(st) then return end
        if st:GetState() == GMOD_CHANNEL_PLAYING then
            st:Pause()
            ui.playPause:SetText("▶")
            if showPreviewNotification:GetBool() then btb.HideNotification() end
        else
            st:Play()
            ui.playPause:SetText("⏸")
            if showPreviewNotification:GetBool() then btb.ShowTrackNotification(btb.currentPreviewTrack, false, true) end
        end
    end))
    playPause.Think = function(self)
        local y = self:GetText() == "▶" and 55 or 50
        local _, cur = self:GetPos()
        if cur ~= y then self:SetPos(cx - 28, y) end
    end
    ui.playPause = playPause

    local nameLabel = vgui.Create("DLabel", panel)
    part(nameLabel)
    nameLabel:SetPos(45, 15)
    nameLabel:SetSize(880, 50)
    nameLabel:SetText("#btb.ps.ts.mp.no_track")
    nameLabel:SetFont("BattleBeats_Player_Font")
    nameLabel:SetTextColor(color_white)
    nameLabel:SetContentAlignment(5)
    ui.trackNameLabel = nameLabel

    local loopBtn
    loopBtn = part(flatButton(panel, "↻", cx + 85, 60, 40, "#btb.ps.ts.mp.loop_disabled", function()
        ui.isLooping = not ui.isLooping
        loopBtn:SetTextColor(ui.isLooping and color_white or C.C100)
        loopBtn:SetTooltip(ui.isLooping and "#btb.ps.ts.mp.loop_enabled" or "#btb.ps.ts.mp.loop_disabled")
    end))
    loopBtn:SetTextColor(C.C100)

    local skipBtn
    skipBtn = part(flatButton(panel, "⇅", cx - 130, 60, 40, "#btb.ps.ts.mp.skip_play_all_tip", function()
        ui.skipExcluded = not ui.skipExcluded
        skipBtn:SetTextColor(ui.skipExcluded and C.C100 or color_white)
        skipBtn:SetTooltip(ui.skipExcluded and "#btb.ps.ts.mp.skip_excluded_tip" or "#btb.ps.ts.mp.skip_play_all_tip")
    end))

    part(flatButton(panel, "⏮", cx - 88, 50, 50, "#btb.ps.ts.mp.previous_track_tip", function() btb.SwitchPreviewTrack(-1) end))
    part(flatButton(panel, "⏭", cx + 28, 50, 50, "#btb.ps.ts.mp.next_track_tip", function() btb.SwitchPreviewTrack(1) end))

    local prog = vgui.Create("DPanel", panel)
    prog:SetPos(90, 104)
    prog:SetSize(800, 36)
    prog:SetCursor("hand")
    local function seek(x)
        local st = btb.currentPreviewStation
        if not IsValid(st) then return end
        local len = st:GetLength()
        if len <= 0 then return end
        st:SetTime(math.Clamp(x / prog:GetWide(), 0, 1) * len, true)
    end
    prog.Paint = function(self, w, h)
        local st = btb.currentPreviewStation
        local valid = IsValid(st)
        local len = valid and st:GetLength() or 0
        local cur = valid and st:GetTime() or 0
        local hov = animHover(self, "Hov", self:IsHovered())
        local bh = 6 + hov * 2
        local by = 27 - bh / 2
        draw.RoundedBox(4, 0, by, w, bh, C.Track)
        local p = len > 0 and math.Clamp(cur / len, 0, 1) or 0
        if p > 0 then
            draw.RoundedBox(4, 0, by, math.max(w * p, bh), bh, LerpColor(hov * 0.3, C.Yellow, color_white))
        end
        local dr = 5 + hov * 2
        draw.RoundedBox(dr, math.Clamp(w * p - dr, 0, w - dr * 2), 27 - dr, dr * 2, dr * 2, color_white)
        if len > 0 and self:IsHovered() and not ui.playerMin then
            local mx = (self:CursorPos())
            draw.SimpleText(btb.FormatTime(math.Clamp(mx / w, 0, 1) * len), "DermaDefaultBold", math.Clamp(mx, 20, w - 20), 8, color_white, TC, TC)
        end
    end
    prog.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self:MouseCapture(true)
        seek((self:CursorPos()))
    end
    prog.OnMouseReleased = function(self) self:MouseCapture(false) end

    local minBtn = flatButton(panel, "▼", 942, 5, 30, "Minimize", function()
        ui.playerMin = not ui.playerMin
        ui.applyPlayerMin()
        surface.PlaySound("btb_tab_switch.mp3")
    end)
    minBtn:SetFont("DermaDefaultBold")

    function ui.applyPlayerMin()
        if not IsValid(panel) then return end
        local min = ui.playerMin and true or false
        panel:SetTall(min and 40 or 170)
        panel:SetPos(10, 630 - (min and 40 or 170))
        for _, p in ipairs(fullParts) do
            if IsValid(p) then p:SetVisible(not min) end
        end
        prog:SetPos(90, min and -7 or 104)
        minBtn:SetText(min and "▲" or "▼")
        minBtn:SetTooltip(min and "Expand" or "Minimize")
        if panel:IsVisible() and IsValid(ui.scrollPanel) then
            ui.scrollPanel:SetSize(980, min and 540 or 410)
        end
    end

    ui.applyPlayerMin()

    return panel
end

--MARK:Main frame
local function openBTBmenu()
    if IsValid(frame) then return end

    local ui = {
        view = "packs",
        prevView = "packs",
        currentFilter = "packages",
        changesMade = false,
        debugMode = false,
        allRows = {},
        packPanels = {},
        isLooping = false,
        skipExcluded = false,
    }

    local hd = 40
    frame = vgui.Create("DFrame")
    btb.frame = frame
    frame:SetSize(1000, 700)
    frame:SetSizable(false)
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.1)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame.isMinimalized = false
    frame.Paint = function(self, w, h)
        drawBlur(self, 3)
        draw.RoundedBox(12, 1, 1, w - 2, h - 2, C.Bg)
        surface.SetDrawColor(C.Yellow)
        draw.SimpleText("Menu", "Trebuchet24", 34, hd / 2 - 7, C.Yellow, TL, TC)
        draw.SimpleText("BattleBeats", "HudSelectionText", 18, hd / 2 + 8, C.Yellow, TL, TC)
        surface.DrawRect(0, hd, w, 1)
        surface.DrawRect(0, 640, w, 1)
        btb.drawRoundedOutline(12, 0, 0, w, h, 1, C.Yellow)
    end
    frame:BTB_SetButtons(true, -5, 5, true)
    ui.frameTitle = frame:BTB_SetTitleBig("", true)
    frame.btnMinim.DoClick = function()
        frame:SetVisible(false)
        frame.isMinimalized = true
    end

    for _, packData in pairs(btb.musicPacks) do
        local wsid = packData.wsid
        if wsid and not btb.wsCache[wsid] then
            steamworks.FileInfo(wsid, function(result)
                if result then btb.wsCache[wsid] = result end
            end)
        end
    end

    --MARK:Scroll area
    ui.scrollPanel = shared.makeScroll(frame)
    ui.scrollPanel:SetSize(980, 580)
    ui.scrollPanel:SetPos(10, 45)
    ui.scrollBar = ui.scrollPanel:GetVBar()
    ui.scrollBar.btnGrip:SetCursor("hand")
    ui.scrollBar.AddScroll = function(self, d)
        local target = math.Clamp(self:GetScroll() + d * 60, 0, self.CanvasSize)
        self:AnimateTo(target, 0.2 / math.min(math.abs(d), 5), 0, 0.3)
    end

    --MARK:Bottom bar
    makeIconButton(frame, 950, 650, Material("btbsettings.png", "smooth"), "#btb.ps.button.options", function()
        ui.openOptions()
    end)
    makeIconButton(frame, 10, 650, Material("btbeq.png", "smooth"), "BassFX", function()
        RunConsoleCommand("battlebeats_equalizer_menu")
    end)
    buildVolume(frame)

    local function bigButton(x, w, text)
        local b = vgui.Create("DButton", frame)
        b:SetSize(w, 40)
        b:SetPos(x, 650)
        b:SetText(text)
        b:SetFont("CreditsText")
        b:SetTextColor(color_white)
        b:BTB_SetButton(C.Yellow, C.C70, P.C80)
        return b
    end

    ui.saveButton = bigButton(350, 290, "#btb.ps.button.done")
    ui.saveButton.DoClick = function() frame:Close() end

    ui.backButton = bigButton(350, 290, "#btb.ps.button.back")
    ui.backButton:SetVisible(false)

    local playlistFrame
    ui.createPlaylistBtn = bigButton(690, 200, "#btb.ps.button_new")
    ui.createPlaylistBtn.DoClick = function()
        if IsValid(playlistFrame) then return end
        surface.PlaySound(btbClickSnd)
        playlistFrame = btb.openImportFrame(frame)
    end

    ui.playerPanel = buildPlayerPanel(ui)
    buildScrollHint(ui)

    --MARK:Preview next / previous
    function btb.SwitchPreviewTrack(direction)
        if not btb.currentPreviewTrack or not btb.musicPacks then return end
        local list = ui.previewList or ui.currentFilteredTracks
        if not list or #list == 0 then return end

        local n = #list
        local current = table.KeyFromValue(list, btb.currentPreviewTrack)
        if not current then
            btb.currentPreviewTrack = list[1]
            current = 1
        end

        local nextTrack
        for i = 1, n do
            local candidate = list[wrapIndex(current + direction * i, n)]
            if not ui.skipExcluded or not btb.getTrackData(candidate).exl then
                nextTrack = candidate
                break
            end
        end
        btb.currentPreviewTrack = nextTrack or list[wrapIndex(current + direction, n)]

        btb.PlayNextTrackPreview(btb.currentPreviewTrack, nil, false, function()
            btb.SwitchPreviewTrack(direction)
        end)
        ui.trackNameLabel:SetText(btb.FormatTrackName(btb.currentPreviewTrack))
        ui.playPause:SetText("⏸")
    end

    --MARK:Views
    local showPackList

    local function applyView()
        local v = ui.view
        local packs, tracks, options = v == "packs", v == "tracks", v == "options"
        ui.isTrackSelectorOpen = tracks

        if IsValid(panelMenu) then panelMenu:Remove() end
        panelMenu = nil

        ui.saveButton:SetVisible(packs)
        ui.backButton:SetVisible(not packs)
        ui.createPlaylistBtn:SetVisible(packs and ui.currentFilter == "playlists")
        if IsValid(ui.verifyButton) then ui.verifyButton:SetVisible(packs) end
        if IsValid(ui.promoPanel) then ui.promoPanel:SetVisible(packs) end
        ui.scrollPanel:SetVisible(not options)

        if packs then
            ui.frameTitle:SetText("")
        elseif tracks then
            ui.frameTitle:SetText(btb.stripPackPrefix(ui.currentPack or ""))
        else
            ui.frameTitle:SetText("#btb.ps.options.title")
        end

        if not options then
            ui.scrollBar:SetWide(tracks and 10 or 0)
            local st = btb.currentPreviewStation
            local showPlayer = tracks and IsValid(st) and st:GetState() ~= GMOD_CHANNEL_STOPPED
            ui.playerPanel:SetVisible(showPlayer)
            ui.scrollPanel:SetSize(980, showPlayer and (ui.playerMin and 540 or 410) or 580)
        else
            ui.playerPanel:SetVisible(false)
        end
    end

    function ui.refreshPacks(keepScroll)
        if not IsValid(frame) or ui.view ~= "packs" then return end
        showPackList(keepScroll)
    end

    RefreshList = function() ui.refreshPacks(true) end
    btb.RefreshPackList = RefreshList

    function btb.openTrackList(trackType, packName)
        if not IsValid(ui.scrollPanel) or not IsValid(frame) then return end
        if trackType ~= "ambient" and trackType ~= "combat" and trackType ~= "all" then return end
        ui.pendingScroll = ui.scrollBar:GetScroll()
        ui.currentPack = packName
        ui.view = "tracks"
        ui.scrollPanel:Clear()
        ui.scrollBar:SetScroll(0)
        applyView()
        btb.createTrackList(ui.trackListCtx, ui.scrollPanel, trackType, packName)
    end

    function ui.openOptions()
        if IsValid(btb.optionsFrame) then return end
        btb.createOptions(frame)
        ui.prevView = ui.view
        ui.view = "options"
        applyView()
    end

    ui.backButton.DoClick = function()
        surface.PlaySound(btbClickSnd)
        if ui.view == "options" then
            if IsValid(btb.optionsFrame) then btb.optionsFrame:Remove() end
            ui.view = ui.prevView
        else
            ui.view = "packs"
        end
        applyView()
        if ui.view == "packs" then showPackList(true) end
    end

    ui.trackListCtx = {
        ui = ui,
        frame = frame,
        playerPanel = ui.playerPanel,
        playPause = ui.playPause,
        trackNameLabel = ui.trackNameLabel,
        activeTextEntries = activeTextEntries,
        isLooping = function() return ui.isLooping end,
    }

    --MARK:Pack list
    showPackList = function(keepScroll)
        ui.debugMode = isDebug()
        local scroll = 0
        if keepScroll then scroll = ui.pendingScroll or ui.scrollBar:GetScroll() end
        ui.pendingScroll = nil

        ui.packPanels = {}
        ui.lastHovered = nil
        if IsValid(ui.promoPanel) then ui.promoPanel:Remove() end
        ui.scrollPanel:Clear()

        buildTabs(ui, function() showPackList() end)
        showConflicts(ui)

        if table.IsEmpty(btb.musicPacks) then buildPromo(ui) end

        local sorted = {}
        for name, data in pairs(btb.musicPacks) do sorted[#sorted + 1] = { name = name, data = data } end
        table.sort(sorted, function(a, b)
            local da, db = a.data or e, b.data or e
            if ui.debugMode then
                local debugA, debugB = da.debug and true or false, db.debug and true or false
                if debugA ~= debugB then return debugA end
            end
            local ra, rb = btb.packOrder[da.packType] or 99, btb.packOrder[db.packType] or 99
            if ra ~= rb then return ra < rb end
            return tostring(a.name):lower() < tostring(b.name):lower()
        end)

        if ui.debugMode and not hasDebugPack() then
            createBasePanel(ui.scrollPanel, 40, NOTE.INFO, nil, function(panel)
                local label = addLabel(panel, "#btb.ps.info.reload")
                label:SetTall(40)
            end)
        end

        local showPlaylists = ui.currentFilter == "playlists"
        local category, visible = nil, 0
        for _, entry in ipairs(sorted) do
            local packType = entry.data.packType or "na"
            if (packType == "playlist") == showPlaylists then
                visible = visible + 1
                local name
                if ui.debugMode and entry.data.debug then
                    name = btb.categoryNames.debug
                else
                    name = btb.categoryNames[packType] or "Uncategorized"
                end
                if category ~= name then
                    category = name
                    createCategoryDivider(ui, name)
                end
                buildPackPanel(ui, entry)
            end
        end

        if visible == 0 then
            local label = ui.scrollPanel:Add("DLabel")
            label:Dock(TOP)
            label:SetText(showPlaylists and "#btb.ps.no_packs_playlist" or "#btb.ps.no_packs")
            label:SetFont("BattleBeats_Font")
            label:SetTall(50)
            label:SetContentAlignment(5)
            label:DockMargin(0, 55, 0, 0)
        end

        syncVerifyButton(ui)
        applyView()

        if scroll > 0 then
            ui.scrollPanel:InvalidateLayout(true)
            ui.scrollBar:SetScroll(scroll)
        end
    end

    --MARK:Hover / expand logic
    local function setHoveredPack(hovered)
        ui.lastHovered = hovered
        if IsValid(panelMenu) then panelMenu:Remove() end
        panelMenu = nil

        for _, p in ipairs(ui.packPanels) do
            if IsValid(p) then
                p.isExpanded = (p == hovered)
                p.isCollapsed = hovered ~= nil
                local pd = p.packData or e
                local hide = (ui.debugMode and not pd.debug) or pd.verifying or pd.error
                for _, v in ipairs(p.fadeTargets or e) do
                    if IsValid(v) then
                        v:Stop()
                        if hide then
                            v:SetVisible(false)
                        elseif p == hovered then
                            if not v:IsVisible() then
                                v:SetAlpha(0)
                                v:SetVisible(true)
                            end
                            v:AlphaTo(255, 0.15, 0)
                        elseif v:IsVisible() then
                            v:AlphaTo(0, 0.15, 0, function()
                                if IsValid(v) then v:SetVisible(false) end
                            end)
                        end
                    end
                end
            end
        end
    end

    local function layoutPackPanels()
        local hoveredPanel = vgui.GetHoveredPanel()
        local hovered = hoveredPanel and hoveredPanel.packPanel
        if hovered ~= ui.lastHovered then setHoveredPack(hovered) end

        for _, p in ipairs(ui.packPanels) do
            if IsValid(p) then
                local pd = p.packData or e
                local w, h
                if pd.error or (ui.debugMode and not pd.debug) or pd.verifying then
                    w, h = 900, 80
                    p.curWidth, p.curHeight = w, h
                else
                    local tw, th = 900, 80
                    if p == hovered then
                        local plain = pd.packType == "playlist" or pd.packType == "local" or pd.source == "local"
                        tw, th = 950, plain and 130 or 165
                    elseif hovered then
                        tw, th = 850, 80
                    end
                    p.curWidth = stepNumber(p.curWidth or 900, tw, 12)
                    p.curHeight = stepNumber(p.curHeight or 80, th, 6)
                    w, h = p.curWidth, p.curHeight
                end
                w, h = math.Round(w), math.Round(h)
                if w ~= p.lastW or h ~= p.lastH then
                    p.lastW, p.lastH = w, h
                    p:SetSize(w, h)
                    if IsValid(p.wrapper) then p.wrapper:SetTall(h) end
                    p:CenterHorizontal(0.5)
                end
            end
        end
    end

    frame.OnMousePressed = function(self)
        local _, screenY = self:LocalToScreen(0, 0)
        if self:GetDraggable() and gui.MouseY() < (screenY + 38) then
            self.Dragging = { gui.MouseX() - self.x, gui.MouseY() - self.y }
            self:MouseCapture(true)
        end
    end
    frame.Think = function(self)
        local mx = math.Clamp(gui.MouseX(), 1, ScrW() - 1)
        local my = math.Clamp(gui.MouseY(), 1, ScrH() - 1)
        local _, screenY = self:LocalToScreen(0, 0)
        if self.Dragging then
            local x, y = mx - self.Dragging[1], my - self.Dragging[2]
            if self:GetScreenLock() then
                x = math.Clamp(x, 0, ScrW() - self:GetWide())
                y = math.Clamp(y, 0, ScrH() - self:GetTall())
            end
            self:SetPos(x, y)
        end
        self:SetCursor((self.Hovered and self:GetDraggable() and my < (screenY + 37)) and "sizeall" or "arrow")
        if self.y < 0 then self:SetPos(self.x, 0) end

        if ui.view == "packs" then layoutPackPanels() end
    end

    local oldClose = frame.Close
    frame.Close = function(self)
        if self.Closing then return end
        self.Closing = true
        self:AlphaTo(0, 0.04, 0, function() oldClose(self) end)
        cancelVerification()
    end

    frame.OnClose = function()
        btb.ValidatePacks()
        btb.saveTrackData()
        if IsValid(btb.optionsFrame) then btb.optionsFrame:Remove() end
        timer.Remove("BattleBeats_NextPreviewTrack")

        local st = btb.currentPreviewStation
        if IsValid(st) and st:GetState() == GMOD_CHANNEL_PLAYING then
            if not persistentNotification:GetBool() then btb.HideNotification() end
            btb.PlayNextTrack(btb.currentPreviewTrack, st:GetTime(), 0)
            timer.Simple(0.05, function()
                if IsValid(st) then st:Stop() end
            end)
        else
            surface.PlaySound("btb_ui_exit.mp3")
        end

        if ui.changesMade then
            if btb.currentPreviewTrack == nil or (IsValid(st) and st:GetState() ~= GMOD_CHANNEL_PLAYING) then
                local nextTrack = btb.GetRandomTrack(btb.currentPacks, btb.isInCombat)
                if nextTrack then btb.PlayNextTrack(nextTrack) end
            end
            btb.currentPreviewTrack = nil
        end

        cookie.Set("battlebeats_selected_packs", util.TableToJSON(btb.currentPacks))
        if table.IsEmpty(btb.currentPacks) and IsValid(btb.currentStation) then
            btb.FadeMusic(btb.currentStation)
            btb.HideNotification()
        end
    end

    showPackList()
end

--MARK:Hooks
cvars.AddChangeCallback("battlebeats_volume", function(_, _, new)
    if IsValid(volumePanel) and not volumePanel.Drag then
        volumePanel.Progress = (tonumber(new) or 0) / 200
    end
end)

hook.Add("VGUIMousePressed", "BattleBeats_KeepFront", function(pnl)
    if not IsValid(frame) or not frame:IsVisible() then return end
    if not (IsValid(g_ContextMenu) and g_ContextMenu:IsVisible()) then return end
    if pnl ~= g_ContextMenu then return end
    timer.Simple(0, function()
        if IsValid(frame) and frame:IsVisible() then frame:MoveToFront() end
    end)
end)

hook.Add("OnContextMenuOpen", "BattleBeats_OpenUI", function()
    if IsValid(frame) and not frame.isMinimalized then
        frame:SetVisible(true)
        timer.Simple(0, function()
            if IsValid(frame) then frame:MoveToFront() end
        end)
    end
end)

local function isAnyTextEntryEditing()
    activeTextEntries.plNameBox = btb.plNameBox
    activeTextEntries.importBox = btb.importBox
    for _, pnl in pairs(activeTextEntries) do
        if IsValid(pnl) and pnl:IsEditing() then return true end
    end
    return false
end

hook.Add("OnContextMenuClose", "BattleBeats_HideUI", function()
    if isAnyTextEntryEditing() then return end
    if IsValid(frame) and not toggleFrame:GetBool() then
        frame:SetVisible(false)
    end
end)

local function showMenu()
    if not IsValid(frame) then
        openBTBmenu()
    elseif not frame:IsVisible() then
        frame:SetVisible(true)
        frame.isMinimalized = false
    end
end

list.Set("DesktopWindows", "BattleBeats_ContextMenu", {
    title = "BattleBeats",
    icon = "packicons/btb.png",
    init = showMenu
})

concommand.Add("battlebeats_menu", showMenu)
