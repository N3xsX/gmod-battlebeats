-- pls dont kill me for this mess

local frame
local volumePanel
local trackMenu = nil
local panelMenu = nil
local isLooping = false
local skipExcluded = false
local isSingle = game.SinglePlayer()

local activeTextEntries = {}

BATTLEBEATS.activeConflicts = BATTLEBEATS.activeConflicts or {}
BATTLEBEATS.wsCache = BATTLEBEATS.wsCache or {}

local volumeSet = GetConVar("battlebeats_volume")
local persistentNotification = GetConVar("battlebeats_persistent_notification")
local showPreviewNotification = GetConVar("battlebeats_show_preview_notification")
local toogleFrame = CreateClientConVar("battlebeats_context_ui_toogle", "0", true, false, "", 0, 1)
local customPackPanels = CreateClientConVar("battlebeats_custom_pack_panels", "1", true, false, "", 0, 1)

BATTLEBEATS.packIcons = {
    ["battlebeats"] = Material("packicons/btb.png"),
    ["nombat"] = Material("packicons/nombat.jpg"),
    ["sbm"] = Material("packicons/sbm.jpg"),
    ["16thnote"] = Material("packicons/16th.jpg"),
    ["amusic"] = Material("packicons/amusic.jpg"),
    ["dynamo"] = Material("packicons/dynamo.jpg"),
    ["mp3p"] = Material("packicons/mp3p.jpg"),
    ["playlist"] = Material("btbplaylist.png"),
    ["na"] = Material("btbna.jpg")
}

local verMat = Material("btbver.png")
local blockMat = Material("btbblock.png")
local locMat = Material("btblocal.png")

BATTLEBEATS.categoryNames = {
    debug = "DEBUG",
    battlebeats = "BattleBeats",
    nombat = "Nombat",
    sbm = "SBM",
    ["16thnote"] = "16th Note",
    amusic = "Action Music",
    dynamo = "DYNAMO",
    mp3p = "MP3 Radio",
    playlist = "Playlist",
    na = "Uncategorized",
    ["local"] = "Local"
}

BATTLEBEATS.packOrder = {
    battlebeats = 1,
    nombat = 2,
    amusic = 3,
    ["16thnote"] = 4,
    mp3p = 5,
    sbm = 6,
    dynamo = 7,
    playlist = 20,
    ["local"] = 97,
    na = 98
}

local packButtons = {
    {
        name = "Zenless Zone Zero",
        image = "promo/btbzzz.jpg",
        workshop = "3457857973"
    },
    {
        name = "The Witcher 3 Wild Hunt",
        image = "promo/btbtw3.jpg",
        workshop = "3483273863"
    },
    {
        name = "Devil May Cry 5",
        image = "promo/btbdmc.jpg",
        workshop = "3490225788"
    },
    {
        name = "Far Cry 4",
        image = "promo/btbfc4.jpg",
        workshop = "3548098038"
    },
    {
        name = "Cyberpunk 2077",
        image = "promo/btbcp.jpeg",
        workshop = "3556630048"
    },
    {
        name = "Resident Evil 4",
        image = "promo/btbre4.jpg",
        workshop = "3588540579"
    }
}

local clr = {}
clr.c606060 = Color(60, 60, 60)
clr.c200200200 = Color(200, 200, 200)
clr.c2552100 = Color(255, 210, 0)
clr.c2001500 = Color(200, 150, 0)
clr.c404040 = Color(40, 40, 40)

local Lerp = Lerp
local FrameTime = FrameTime
local Color = Color

local function colorsEqual(a, b)
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a
end

local function LerpColor(t, from, to)
    if colorsEqual(from, to) then return to end
    return Color(
        Lerp(t, from.r, to.r),
        Lerp(t, from.g, to.g),
        Lerp(t, from.b, to.b),
        Lerp(t, from.a or 255, to.a or 255)
    )
end

local function hasAnyDebugPack(packs)
    if not packs then return false end
    for _, pack in pairs(packs) do
        if pack.data and pack.data.debug then
            return true
        end
    end
    return false
end

BATTLEBEATS.checking = false
local checking = false
local packNames = {}
local errorCount = 0
local currentPackIndex = 1
local function validateTracksInPack(packName, func)
    local packData = BATTLEBEATS.musicPacks[packName]
    if not packData then return end
    BATTLEBEATS.checking = true
    checking = true
    local tracks = {}
    if packData.ambient then
        for _, track in ipairs(packData.ambient) do
            table.insert(tracks, { track = track, type = "ambient" })
        end
    end
    if packData.combat then
        for _, track in ipairs(packData.combat) do
            table.insert(tracks, { track = track, type = "combat" })
        end
    end

    MsgC(Color(255, 255, 0), "[BattleBeats Debug] ", color_white, "Verifying pack: ", Color(0, 255, 255), packName .. "\n")

    local trackIndex = 1
    packData.verifying = true

    local function nextTrack()
        if trackIndex > #tracks then
            packData.verifying = false
            currentPackIndex = currentPackIndex + 1
            if currentPackIndex <= #packNames then
                validateTracksInPack(packNames[currentPackIndex], func)
            else
                if errorCount > 0 then
                    MsgC(
                        Color(255, 255, 0), "[BattleBeats Debug] ",
                        color_white, "Pack verification",
                        Color(255, 0, 0), " FAILED! ",
                        color_white, "Found ",
                        Color(255, 0, 0), tostring(errorCount),
                        color_white, " error(s)\n"
                    )
                    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.ps.verification.failed_1") .. " " .. tostring(errorCount) .. " " .. language.GetPhrase("btb.ps.verification.failed_2"), NOTIFY_ERROR, 4)
                    surface.PlaySound("buttons/button8.wav")
                else
                    MsgC(
                        Color(255, 255, 0), "[BattleBeats Debug] ",
                        color_white, "Pack verification",
                        Color(0, 255, 0), " PASSED! ",
                        color_white, "No errors found\n"
                    )
                    notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.ps.verification.pass"), NOTIFY_HINT, 4)
                    surface.PlaySound("buttons/button14.wav")
                end
                errorCount = 0
                checking = false
                BATTLEBEATS.checking = false
                currentPackIndex = 1
                if isfunction(func) then
                    func()
                end
            end
            return
        end

        local info = tracks[trackIndex]
        BATTLEBEATS.ValidateTrack(info.track, function(track, errCode, errStr)
            errorCount = errorCount + 1
            packData.error = packData.error or {}
            packData.error = "track_error\nOne or more tracks have an error\nCheck console for details!"
            MsgC(
                Color(255, 255, 0), "[BattleBeats Debug] ",
                color_white, "Error in pack '",
                Color(0, 255, 255), packName,
                color_white, "' - ",
                Color(255, 255, 0), info.type .. " ",
                color_white, "track: ",
                color_white, track .. " ",
                color_white, "Code: ",
                Color(0, 255, 255), tostring(errCode) .. " ",
                color_white, "Error: ",
                Color(255, 0, 255), tostring(errStr) .. "\n"
            )
        end)

        trackIndex = trackIndex + 1
        timer.Create("BattleBeats_VerifyTimer", 0.05, 1, function() nextTrack() end)
    end
    nextTrack()
end

local btbClickSnd = "btb_button_click.mp3"
local texGradient = surface.GetTextureID("gui/gradient")

clr.cHover = Color(50, 50, 50, 200)
clr.cHover2 = Color(65, 65, 65, 200)

clr.c707070255 = Color(70, 70, 70, 255)
clr.c808080255 = Color(80, 80, 80, 255)

clr.c909090 = Color(90, 90, 90)
clr.c000200 = Color(0, 0, 0, 200)
clr.c25500 = Color(255, 0, 0)
clr.c100100100 = Color(100, 100, 100)
clr.c505050 = Color(50, 50, 50)
clr.c202020215 = Color(20, 20, 20, 215)
clr.c404040200 = Color(40, 40, 40, 200)
clr.c150150150 = Color(150, 150, 150)
clr.c120120120150 = Color(120, 120, 120, 150)

clr.c707070200 = Color(70, 70, 70, 200)

clr.cpanelerror = Color(70, 50, 50, 200)
clr.cdebughover = Color(110, 110, 60, 200)
clr.cdebugunselected = Color(100, 100, 60, 200)
clr.clocalhover = Color(50, 120, 120, 200)
clr.clocalunselected = Color(50, 80, 80, 200)
clr.cvererror = Color(150, 50, 0, 60)
clr.cver = Color(255, 200, 0, 60)
clr.cvertext = Color(255, 255, 255, 100)

local versionConVar = GetConVar("battlebeats_seen_version")

local function createButtons(panel, packName, packData)
    if not IsValid(panel) then return end
    if IsValid(panel.ambientButton) then return end
    local buttonWidth, buttonHeight, spacing = 350, 30, 20
    local allButtonWidth = buttonWidth / 2
    local totalWidth = buttonWidth * 2 + allButtonWidth + spacing * 2
    local startX = (950 - totalWidth) / 2
    local ambientButton = vgui.Create("DButton", panel)
    ambientButton:SetVisible(false)
    ambientButton:SetSize(buttonWidth, buttonHeight)
    ambientButton:SetPos(startX, 80)
    ambientButton:SetText("#btb.ps.info.ambient_button")
    ambientButton:SetFont("DermaDefaultBold")
    ambientButton:SetTextColor(color_white)
    local bgOutlineColorA = clr.c2552100
    if packData.packContent == "combat" or packData.packContent == "empty" then
        bgOutlineColorA = clr.c2001500
        ambientButton:SetCursor("no")
        ambientButton:BTB_SetButton(bgOutlineColorA, clr.c404040, nil, true)
        ambientButton:SetTooltip("#btb.ps.info.ambient_button_tip")
        ambientButton:SetTooltipPanelOverride("BattleBeatsTooltip")
        ambientButton:SetTextColor(clr.c200200200)
    else
        ambientButton:BTB_SetButton(bgOutlineColorA, clr.c606060, clr.c909090)
    end
    ambientButton.DoClick = function()
        if packData.packContent == "empty" then return end
        if packData.packContent ~= "combat" then
            surface.PlaySound(btbClickSnd)
            BATTLEBEATS.openTrackList("ambient", packName)
        end
    end
    panel.ambientButton = ambientButton

    local allButton = vgui.Create("DButton", panel)
    allButton:SetVisible(false)
    allButton:SetSize(allButtonWidth, buttonHeight)
    allButton:SetPos(startX + buttonWidth + spacing, 80)
    allButton:SetText("#btb.ps.info.all_button")
    allButton:SetFont("DermaDefaultBold")
    allButton:SetTextColor(color_white)
    local bgOutlineColorAL = clr.c2552100
    if packData.packContent == "empty" then
        bgOutlineColorAL = clr.c2001500
        allButton:SetCursor("no")
        allButton:BTB_SetButton(bgOutlineColorAL, clr.c404040, nil, true)
        allButton:SetTextColor(clr.c200200200)
    else
        allButton:BTB_SetButton(bgOutlineColorAL, clr.c606060, clr.c909090)
    end
    allButton.DoClick = function()
        if packData.packContent == "empty" then return end
        surface.PlaySound(btbClickSnd)
        BATTLEBEATS.openTrackList("all", packName)
    end
    panel.allButton = allButton

    local combatButton = vgui.Create("DButton", panel)
    combatButton:SetVisible(false)
    combatButton:SetSize(buttonWidth, buttonHeight)
    combatButton:SetPos(startX + buttonWidth + spacing + allButtonWidth + spacing, 80)
    combatButton:SetText("#btb.ps.info.combat_button")
    combatButton:SetFont("DermaDefaultBold")
    combatButton:SetTextColor(color_white)
    local bgOutlineColorC = clr.c2552100
    if packData.packContent == "ambient" or packData.packContent == "empty" then
        bgOutlineColorC = clr.c2001500
        combatButton:SetCursor("no")
        combatButton:BTB_SetButton(bgOutlineColorC, clr.c404040, nil, true)
        combatButton:SetTooltip("#btb.ps.info.combat_button_tip")
        combatButton:SetTooltipPanelOverride("BattleBeatsTooltip")
        combatButton:SetTextColor(clr.c200200200)
    else
        combatButton:BTB_SetButton(bgOutlineColorC, clr.c606060, clr.c909090)
    end
    combatButton.DoClick = function()
        if packData.packContent == "empty" then return end
        if packData.packContent ~= "ambient" then
            surface.PlaySound(btbClickSnd)
            BATTLEBEATS.openTrackList("combat", packName)
        end
    end
    panel.combatButton = combatButton
end

local c2201200150 = Color(220, 120, 0, 150)
local gradMat = Material("gui/center_gradient")
local function createBasePanel(parent, height, type, margin, call, duration)
    duration = duration or nil
    local startTime = CurTime()
    local iicon
    local bgColor
    local text
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, margin and 0 or 5, 0, margin or 0)
    panel:SetTall(duration and (height + 4) or height)
    if type == 1 then
        iicon = "btbinfo.png"
        bgColor = Color(150, 150, 150, 150)
        text = "Information"
    elseif type == 2 then
        iicon = "btbcriticalerror.png"
        panel.Think = function()
            local pulse = math.abs(math.sin(CurTime() * 3)) * 50
            bgColor = Color(200 + pulse, 50, 0, 150)
        end
        text = "Critical Error"
    elseif type == 3 then
        iicon = "btbhint.png"
        bgColor = Color(0, 200, 200, 150)
        text = "Hint"
        local clsbtn = vgui.Create("DButton", panel)
        clsbtn:SetSize(36, 36)
        clsbtn:SetPos(940, panel:GetTall() / 2 - 18)
        clsbtn:SetText("X")
        clsbtn:SetTextColor(Color(0, 0, 0))
        clsbtn:SetFont("CloseCaption_Bold")
        clsbtn.Paint = nil
        clsbtn.DoClick = function()
            panel:SizeTo(-1, 0, 0.5, 0, 0.5, function()
                if IsValid(panel) then
                    panel:Remove()
                end
            end)
        end
    else
        iicon = "btberror.png"
        bgColor = c2201200150
        text = "Warning"
    end
    panel.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, bgColor)
        if duration then
            local timeLeft = math.Clamp((startTime + duration - CurTime()) / duration, 0, 1)
            local barWidth = w * timeLeft
            local x = (w - barWidth) / 2
            surface.SetMaterial(gradMat)
            surface.SetDrawColor(255, 255, 255, 160)
            surface.DrawTexturedRect(x, h - 4, barWidth, h)
        end
    end
    if duration then
        timer.Simple(duration, function()
            if IsValid(panel) then
                panel:SizeTo(-1, 0, 0.5, 0, 0.5, function()
                    if IsValid(panel) then
                        panel:Remove()
                    end
                end)
            end
        end)
    end
    local icon = vgui.Create("DImage", panel)
    icon:SetSize(36, 36)
    icon:SetPos(5, panel:GetTall() / 2 - 18)
    icon:SetImage(iicon)
    icon:SetMouseInputEnabled(true)
    icon:SetTooltip(text)
    icon:SetTooltipPanelOverride("BattleBeatsTooltip")
    call(panel)
end

local function checkVolume(parent)
    local time = tonumber(cookie.GetString("battlebeats_high_volume_time", "0")) or 0
    local level = tonumber(cookie.GetString("battlebeats_high_volume_warn", "0")) or 0
    local thresholds = {
        3600, -- 1h
        14400, -- 4h
        28800, -- 8h
        86400 -- 24h
    }
    local newLevel = level
    for i = level + 1, #thresholds do
        if time >= thresholds[i] then
            newLevel = i
        else
            break
        end
    end
    if newLevel > level then
        cookie.Set("battlebeats_high_volume_warn", tostring(newLevel))
        level = newLevel
    end
    if level <= 0 then return end
    createBasePanel(parent, 40, nil, nil, function(panel)
        local label1 = vgui.Create("DLabel", panel)
        label1:Dock(TOP)
        label1:SetTall(20)
        label1:SetText(language.GetPhrase("btb.ps.warn.volume_" .. (level)))
        label1:SetFont("BattleBeats_Notification_Font_Misc")
        label1:SetTextColor(color_white)
        label1:SetContentAlignment(5)
        local label2 = vgui.Create("DLabel", panel)
        label2:Dock(TOP)
        label2:SetTall(20)
        label2:SetText(language.GetPhrase("btb.ps.warn.volume_" .. (level) .. (level)))
        label2:SetFont("BattleBeats_Notification_Font_Misc")
        label2:SetTextColor(color_white)
        label2:SetContentAlignment(5)
    end)
end

local function showConflicts(ui)
    checkVolume(ui.scrollPanel)
    /*createBasePanel(ui.scrollPanel, 40, 3, nil, function(panel)
            local label1 = vgui.Create("DLabel", panel)
            label1:Dock(TOP)
            label1:SetTall(20)
            label1:SetText("etetq")
            label1:SetFont("BattleBeats_Notification_Font_Misc")
            label1:SetTextColor(color_white)
            label1:SetContentAlignment(5)
            local label2 = vgui.Create("DLabel", panel)
            label2:Dock(TOP)
            label2:SetTall(20)
            label2:SetText("weqwqeqwe")
            label2:SetFont("BattleBeats_Notification_Font_Misc")
            label2:SetTextColor(color_white)
            label2:SetContentAlignment(5)
        end)*/
    if BATTLEBEATS.errorCount > 3 then
        createBasePanel(ui.scrollPanel, 40, 2, nil, function(panel)
            local label1 = vgui.Create("DLabel", panel)
            label1:Dock(TOP)
            label1:SetTall(20)
            label1:SetText("Multiple track errors occurred or the audio system failed (BASS)")
            label1:SetFont("BattleBeats_Notification_Font_Misc")
            label1:SetTextColor(color_white)
            label1:SetContentAlignment(5)
            local label2 = vgui.Create("DLabel", panel)
            label2:Dock(TOP)
            label2:SetTall(20)
            label2:SetText("Verify or change your packs and type 'battlebeats_restart' in console to resume playback")
            label2:SetFont("BattleBeats_Notification_Font_Misc")
            label2:SetTextColor(color_white)
            label2:SetContentAlignment(5)
        end)
    end
    if not table.IsEmpty(BATTLEBEATS.activeConflicts) then
        createBasePanel(ui.scrollPanel, 40, nil, nil, function(panel)
            local conflictNames = table.GetKeys(BATTLEBEATS.activeConflicts)
            local label1 = vgui.Create("DLabel", panel)
            label1:Dock(TOP)
            label1:SetTall(20)
            label1:SetText(language.GetPhrase("btb.ps.error.conflict1") .. ": " .. table.concat(conflictNames, ", "))
            label1:SetFont("BattleBeats_Notification_Font_Misc")
            label1:SetTextColor(color_white)
            label1:SetContentAlignment(5)
            local label2 = vgui.Create("DLabel", panel)
            label2:Dock(TOP)
            label2:SetTall(20)
            label2:SetText("#btb.ps.error.conflict2")
            label2:SetFont("BattleBeats_Notification_Font_Misc")
            label2:SetTextColor(color_white)
            label2:SetContentAlignment(5)
        end)
    end
    if GetConVar("battlebeats_debug_mode"):GetBool() then
        createBasePanel(ui.scrollPanel, 40, nil, nil, function(panel)
            local label1 = vgui.Create("DLabel", panel)
            label1:Dock(TOP)
            label1:SetTall(20)
            label1:SetText("#btb.ps.error.debug1")
            label1:SetFont("BattleBeats_Notification_Font_Misc")
            label1:SetTextColor(color_white)
            label1:SetContentAlignment(5)
            local label2 = vgui.Create("DLabel", panel)
            label2:Dock(TOP)
            label2:SetTall(20)
            label2:SetText("#btb.ps.error.debug2")
            label2:SetFont("BattleBeats_Notification_Font_Misc")
            label2:SetTextColor(color_white)
            label2:SetContentAlignment(5)
        end)
    end
end

local function styleTabButton(btn, typeName, currentFilter)
    btn:SetText("")
    btn.OnCursorEntered = function(self)
        surface.PlaySound("ui/buttonrollover.wav")
    end
    btn.Paint = function(self, w, h)
        local isActive = (currentFilter == typeName)
        local txtColor = isActive and color_white or
        ((self:IsHovered() and self:IsEnabled()) and clr.c200200200 or clr.c150150150)
        draw.SimpleText(typeName == "packages" and "#btb.ps.tab_packs" or "#btb.ps.tab_playlists", "BattleBeats_Font", w / 2, h / 2 - 5, txtColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local lineW = isActive and w * 0.6 or ((self:IsHovered() and self:IsEnabled()) and w * 0.4 or w * 0.2)
        local lineX = (w - lineW) / 2
        local lineColor = isActive and clr.c2552100 or clr.c120120120150
        draw.RoundedBox(2, lineX, h - 6, lineW, 3, lineColor)
    end
end

local gradLeft = surface.GetTextureID("vgui/gradient-l")
local gradRight = surface.GetTextureID("vgui/gradient-r")

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

--MARK:Main UI
local function openBTBmenu()
    if IsValid(frame) then return end
    /*if cookie.GetString('BattleBeats_FirstTime') ~= 'true' and versionConVar:GetString() == "" then
        RunConsoleCommand("battlebeats_guide")
        cookie.Set('BattleBeats_FirstTime', 'true')
    end*/
    local ui = {
        selectedRow = nil,
        changesMade = false,
        collapsedWidth = 55,
        expandedWidth = 330
    }
    frame = vgui.Create("DFrame")
    BATTLEBEATS.frame = frame
    frame:SetSize(1000, 700)
    frame:SetSizable(false)
    frame:SetAlpha(0)
    frame:AlphaTo(255, 0.1)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        drawBlur(self, 3)
        draw.RoundedBox(12, 0, 0, w, h, clr.c202020215)
        surface.SetDrawColor(clr.c2552100)
        surface.DrawRect(0, 40, w, 1)
        surface.DrawRect(0, 640, w, 1)
        BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, clr.c2552100)
    end
    frame:BTB_SetButtons(true, -5, 5, true)
    frame.isMinimalized = false

    ui.frameTitle = frame:BTB_SetTitleBig("#btb.ps.title", true)

    frame.btnMinim.DoClick = function()
        frame:SetVisible(false)
        frame.isMinimalized = true
    end

    for _, packData in pairs(BATTLEBEATS.musicPacks) do
        local wsid = packData.wsid
        if wsid and not BATTLEBEATS.wsCache[wsid] then
            steamworks.FileInfo(wsid, function(result)
                if result then
                    BATTLEBEATS.wsCache[wsid] = result
                end
            end)
        end
    end

    ui.scrollPanel = vgui.Create("DScrollPanel", frame)
    ui.scrollPanel:SetSize(980, 580)
    ui.scrollPanel:SetPos(10, 45)

    ui.scrollBar = ui.scrollPanel:GetVBar()
    ui.scrollBar:SetHideButtons(true)
    ui.scrollBar.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, clr.c404040200)
    end
    ui.scrollBar.btnGrip:SetCursor("hand")
    ui.scrollBar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c606060)
    end
    ui.scrollBar.AddScroll = function(self, d)
        local animTarget = self:GetScroll() + d * 60
        animTarget = math.Clamp(animTarget, 0, self.CanvasSize)
        local speed = math.min(math.abs(d), 5)
        self:AnimateTo(animTarget, 0.2 / speed, 0, 0.3)
    end

    --MARK:Option button
    local optionsButton = vgui.Create("DButton", frame)
    optionsButton:SetSize(55, 40)
    optionsButton:SetPos(935, 650)
    optionsButton:SetText("")
    optionsButton:BTB_SetButton(clr.c2552100, clr.c707070255, clr.c808080255)
    optionsButton.DoClick = function()
        surface.PlaySound(btbClickSnd)
        --RunConsoleCommand("battlebeats_options")
        OpenOptions()
    end
    optionsButton:SetTooltip("#btb.ps.button.options")
    optionsButton:SetTooltipPanelOverride("BattleBeatsTooltip")
    local settingsIcon = vgui.Create("DImage", optionsButton)
    settingsIcon:SetSize(32, 32)
    settingsIcon:SetPos(12, 4)
    settingsIcon:SetImage("btbsettings.png")

    --MARK:Volume bar
    volumePanel = vgui.Create("DPanel", frame)
    volumePanel.expanded = cookie.GetNumber("battlebeats_vol_expanded", 0) == 1
    volumePanel:SetSize(ui.collapsedWidth, 40)
    volumePanel:SetWide(volumePanel.expanded and ui.expandedWidth or ui.collapsedWidth)
    volumePanel:SetPos(10, 650)
    volumePanel.progress = volumeSet:GetInt() / 200
    volumePanel.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c707070255)
    end
    local volumeLabel = vgui.Create("DLabel", volumePanel)
    volumeLabel:SetText("#btb.ps.master_volume")
    volumeLabel:SetFont("DermaDefaultBold")
    volumeLabel:SetTextColor(color_white)
    volumeLabel:SizeToContents()
    local volumeBar = vgui.Create("DPanel", volumePanel)
    volumeBar:SetSize(250, 8)
    volumeBar:SetPos(65, 22)
    volumeBar:SetCursor("hand")
    volumeBar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, clr.c909090)
        draw.RoundedBox(4, 0, 0, w * volumePanel.progress, h, clr.c2552100)
    end
    volumeLabel:SetPos(volumeBar:GetX(), 4)
    volumeLabel:SetVisible(false)
    volumeBar:SetVisible(false)

    local volumeIcon = vgui.Create("DImage", volumePanel)
    volumeIcon:SetSize(40, 40)
    volumeIcon:SetPos(7, 0)
    volumeIcon:SetCursor("hand")
    volumeIcon:SetMouseInputEnabled(true)
    local currentIcon
    local function updateIcon(progress)
        local icon
        if progress < 0.01 then
            icon = "volume/v0.png"
        elseif progress < 0.3 then
            icon = "volume/v1.png"
        elseif progress < 0.75 then
            icon = "volume/v2.png"
        else
            icon = "volume/v3.png"
        end
        if icon ~= currentIcon then
            currentIcon = icon
            volumeIcon:SetImage(icon)
        end
    end
    updateIcon(volumePanel.progress)

    local dotPanel = vgui.Create("DPanel", volumePanel)
    dotPanel:SetMouseInputEnabled(false)
    dotPanel:SetSize(16, 12)
    dotPanel.Paint = function(self, w, h)
        if volumePanel.progress >= 0 then
            draw.RoundedBox(12, 0, 0, w, h, color_white)
        end
    end

    function UpdateDot(progress)
        local barWidth = volumeBar:GetWide()
        dotPanel:SetPos(65 + barWidth * progress - 6, 22 + volumeBar:GetTall() / 2 - 6)
    end
    UpdateDot(volumePanel.progress)

    local function updateVolume()
        local newValue = math.floor(volumePanel.progress * 200)
        UpdateDot(volumePanel.progress)
        updateIcon(volumePanel.progress)
        volumeSet:SetInt(newValue)
    end

    volumePanel.Think = function(self)
        local targetWidth = self.expanded and ui.expandedWidth or ui.collapsedWidth
        local newWidth = math.Approach(self:GetWide(), targetWidth, FrameTime() * 800)
        self:SetWide(newWidth)
        local visible = newWidth > 120
        volumeBar:SetVisible(visible)
        volumeLabel:SetVisible(visible)
    end

    local function setBarInteractive(enabled)
        if enabled then
            volumeBar.OnMousePressed = function(self, code)
                if code ~= MOUSE_LEFT then return end
                local x, _ = self:CursorPos()
                volumePanel.progress = math.Clamp(x / self:GetWide(), 0, 1)
                updateVolume()
                self.IsDragging = true
            end
            volumeBar.Think = function(self)
                if self.IsDragging and input.IsMouseDown(MOUSE_LEFT) then
                    local x, _ = self:CursorPos()
                    volumePanel.progress = math.Clamp(x / self:GetWide(), 0, 1)
                    updateVolume()
                elseif self.IsDragging and not input.IsMouseDown(MOUSE_LEFT) then
                    self.IsDragging = false
                end
            end
        else
            volumeBar.OnMousePressed = nil
            volumeBar.Think = nil
            volumeBar.IsDragging = false
        end
    end

    volumeIcon.OnMousePressed = function()
        volumePanel.expanded = not volumePanel.expanded
        cookie.Set("battlebeats_vol_expanded", volumePanel.expanded and 1 or 0)
        setBarInteractive(volumePanel.expanded)
    end
    setBarInteractive(volumePanel.expanded)

    --MARK:Save button
    ui.saveButton = vgui.Create("DButton", frame)
    ui.saveButton:SetSize(290, 40)
    ui.saveButton:SetPos(350, 650)
    ui.saveButton:SetText("#btb.ps.button.done")
    ui.saveButton:SetFont("CreditsText")
    ui.saveButton:SetTextColor(color_white)
    ui.saveButton:BTB_SetButton(clr.c2552100, clr.c707070255, clr.c808080255)

    --MARK:New playlist button
    local playlistFrame
    ui.createPlaylistBtn = vgui.Create("DButton", frame)
    ui.createPlaylistBtn:SetSize(200, 40)
    ui.createPlaylistBtn:SetPos(690, 650)
    ui.createPlaylistBtn:SetText("#btb.ps.button_new")
    ui.createPlaylistBtn:SetFont("CreditsText")
    ui.createPlaylistBtn:SetTextColor(color_white)
    ui.createPlaylistBtn:BTB_SetButton(clr.c2552100, clr.c707070255, clr.c808080255)
    ui.createPlaylistBtn.DoClick = function()
        if IsValid(playlistFrame) then return end
        surface.PlaySound(btbClickSnd)
        playlistFrame = BATTLEBEATS.openImportFrame(frame)
    end

    --MARK:Music player panel
    local playerPanel = vgui.Create("DPanel", frame)
    playerPanel:SetSize(980, 170)
    playerPanel:SetPos(10, 460)
    playerPanel:SetVisible(false)
    playerPanel.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c404040)
    end

    local playPause = vgui.Create("DButton", playerPanel)
    playPause:SetSize(50, 50)
    playPause:SetPos((playerPanel:GetWide() / 2) - 28, 50)
    playPause:SetText("▶")
    playPause:SetFont("DermaLarge")
    playPause:SetTextColor(color_white)
    playPause.Paint = nil
    playPause.Think = function()
        if playPause:GetText() == "▶" then
            playPause:SetPos((playerPanel:GetWide() / 2) - 28, 55)
        else
            playPause:SetPos((playerPanel:GetWide() / 2) - 28, 50)
        end
    end

    local currentTimeLabel = vgui.Create("DLabel", playerPanel)
    currentTimeLabel:SetPos(50, 111)
    currentTimeLabel:SetSize(90, 20)
    currentTimeLabel:SetText("0:00")
    currentTimeLabel:SetFont("DermaDefaultBold")
    currentTimeLabel:SetTextColor(color_white)

    local totalTimeLabel = vgui.Create("DLabel", playerPanel)
    totalTimeLabel:SetPos(850, 111)
    totalTimeLabel:SetSize(90, 20)
    totalTimeLabel:SetText("0:00")
    totalTimeLabel:SetFont("DermaDefaultBold")
    totalTimeLabel:SetTextColor(color_white)
    totalTimeLabel:SetContentAlignment(6)

    local trackNameLabel = vgui.Create("DLabel", playerPanel)
    trackNameLabel:SetPos(45, 15)
    trackNameLabel:SetSize(880, 50)
    trackNameLabel:SetText("#btb.ps.ts.mp.no_track")
    trackNameLabel:SetFont("BattleBeats_Player_Font")
    trackNameLabel:SetTextColor(color_white)
    trackNameLabel:SetContentAlignment(5)

    local loopBtn = vgui.Create("DButton", playerPanel)
    loopBtn:SetSize(40, 40)
    loopBtn:SetPos((playerPanel:GetWide() / 2) + 85, 60)
    loopBtn:SetText("↻")
    loopBtn:SetFont("DermaLarge")
    loopBtn:SetTextColor(clr.c100100100)
    loopBtn.Paint = nil
    loopBtn:SetTooltip("#btb.ps.ts.mp.loop_disabled")
    loopBtn.DoClick = function()
        isLooping = not isLooping
        if isLooping then
            loopBtn:SetTextColor(color_white)
            loopBtn:SetTooltip("#btb.ps.ts.mp.loop_enabled")
        else
            loopBtn:SetTextColor(clr.c100100100)
            loopBtn:SetTooltip("#btb.ps.ts.mp.loop_disabled")
        end
    end
    loopBtn:SetTooltipPanelOverride("BattleBeatsTooltip")

    local skipExcludedBtn = vgui.Create("DButton", playerPanel)
    skipExcludedBtn:SetSize(40, 40)
    skipExcludedBtn:SetPos((playerPanel:GetWide() / 2) - 130, 60)
    skipExcludedBtn:SetText("⇅")
    skipExcludedBtn:SetFont("DermaLarge")
    skipExcludedBtn:SetTextColor(color_white)
    skipExcludedBtn.Paint = nil
    skipExcludedBtn:SetTooltip("#btb.ps.ts.mp.skip_play_all_tip")
    skipExcludedBtn.DoClick = function()
        skipExcluded = not skipExcluded
        if skipExcluded then
            skipExcludedBtn:SetTextColor(clr.c100100100)
            skipExcludedBtn:SetTooltip("#btb.ps.ts.mp.skip_excluded_tip")
        else
            skipExcludedBtn:SetTextColor(color_white)
            skipExcludedBtn:SetTooltip("#btb.ps.ts.mp.skip_play_all_tip")
        end
    end
    skipExcludedBtn:SetTooltipPanelOverride("BattleBeatsTooltip")

    --MARK:Next/Previous track
    local currentFilteredTracks
    local allRows = {}
    function BATTLEBEATS.SwitchPreviewTrack(direction)
        if not BATTLEBEATS.currentPreviewTrack or not BATTLEBEATS.musicPacks then return end

        local activeList = currentFilteredTracks
        if not activeList or #activeList == 0 then return end

        local currentIndex = table.KeyFromValue(activeList, BATTLEBEATS.currentPreviewTrack)
        if not currentIndex then
            BATTLEBEATS.currentPreviewTrack = activeList[1]
            currentIndex = 1
        end

        local totalTracks = #activeList
        local newIndex = currentIndex

        if skipExcluded then
            for i = 1, totalTracks do
                newIndex = newIndex + direction
                if newIndex < 1 then newIndex = totalTracks end
                if newIndex > totalTracks then newIndex = 1 end

                local candidate = activeList[newIndex]
                if not BATTLEBEATS.excludedTracks[candidate] then
                    BATTLEBEATS.currentPreviewTrack = candidate
                    break
                end
            end
            if BATTLEBEATS.excludedTracks[BATTLEBEATS.currentPreviewTrack] then
                newIndex = currentIndex + direction
                if newIndex < 1 then newIndex = totalTracks end
                if newIndex > totalTracks then newIndex = 1 end
                BATTLEBEATS.currentPreviewTrack = activeList[newIndex]
            end
        else
            newIndex = currentIndex + direction
            if newIndex < 1 then newIndex = totalTracks end
            if newIndex > totalTracks then newIndex = 1 end
            BATTLEBEATS.currentPreviewTrack = activeList[newIndex]
        end

        BATTLEBEATS.PlayNextTrackPreview(BATTLEBEATS.currentPreviewTrack, nil, false, function ()
            BATTLEBEATS.SwitchPreviewTrack(direction)
        end)
        local trackName = BATTLEBEATS.FormatTrackName(BATTLEBEATS.currentPreviewTrack)
        trackNameLabel:SetText(trackName)
        playPause:SetText("⏸")
        if IsValid(ui.scrollPanel) then
            for _, row in ipairs(allRows) do
                if row.trackPath == BATTLEBEATS.currentPreviewTrack then
                    ui.selectedRow = row.trackName
                    ui.scrollPanel:ScrollToChild(row)
                    break
                end
            end
        end
    end

    local prevTrackBtn = vgui.Create("DButton", playerPanel)
    prevTrackBtn:SetSize(50, 50)
    prevTrackBtn:SetPos((playerPanel:GetWide() / 2) - 88, 50)
    prevTrackBtn:SetText("⏮")
    prevTrackBtn:SetFont("DermaLarge")
    prevTrackBtn:SetTextColor(color_white)
    prevTrackBtn.Paint = nil
    prevTrackBtn.DoClick = function()
        BATTLEBEATS.SwitchPreviewTrack(-1)
    end
    prevTrackBtn:SetTooltip("#btb.ps.ts.mp.previous_track_tip")
    prevTrackBtn:SetTooltipPanelOverride("BattleBeatsTooltip")

    local nextTrackBtn = vgui.Create("DButton", playerPanel)
    nextTrackBtn:SetSize(50, 50)
    nextTrackBtn:SetPos((playerPanel:GetWide() / 2) + 28, 50)
    nextTrackBtn:SetText("⏭")
    nextTrackBtn:SetFont("DermaLarge")
    nextTrackBtn:SetTextColor(color_white)
    nextTrackBtn.Paint = nil
    nextTrackBtn.DoClick = function()
        BATTLEBEATS.SwitchPreviewTrack(1)
    end
    nextTrackBtn:SetTooltip("#btb.ps.ts.mp.next_track_tip")
    nextTrackBtn:SetTooltipPanelOverride("BattleBeatsTooltip")
    --MARK:Player bars
    local hoverTimeDisplay = nil
    local progressBar = vgui.Create("DPanel", playerPanel)
    progressBar:SetSize(800, 20)
    progressBar:SetPos(90, 110)
    progressBar:SetCursor("hand")
    progressBar.Paint = function(self, w, h)
        local progressBarX, progressBarY = 0, h / 2 - 2
        local progressBarWidth, progressBarHeight = w, 8
        draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth, progressBarHeight, clr.c909090)

        local currentTime = IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetTime() or 0
        local trackDuration = IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetLength() or 0
        local progress = trackDuration > 0 and math.Clamp(currentTime / trackDuration, 0, 1) or 0

        draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth * progress, progressBarHeight, clr.c2552100)

        if self:IsHovered() and trackDuration > 0 then
            local mx, _ = self:CursorPos()
            local hoverProgress = math.Clamp(mx / w, 0, 1)
            local hoverTime = hoverProgress * trackDuration
            hoverTimeDisplay = {
                text = BATTLEBEATS.FormatTime(hoverTime),
                x = self:LocalToScreen(mx, 0)
            }
        else
            hoverTimeDisplay = nil
        end
    end

    playerPanel.PaintOver = function(self, w, h)
        if hoverTimeDisplay then
            local lx, _ = self:ScreenToLocal(hoverTimeDisplay.x, 0)
            local y = progressBar.y - 8
            draw.SimpleText(hoverTimeDisplay.text, "DermaDefaultBold", lx, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
    end

    progressBar.OnMousePressed = function(self, code)
        if code == MOUSE_LEFT and IsValid(BATTLEBEATS.currentPreviewStation) then
            local x, _ = self:CursorPos()
            local progress = math.Clamp(x / self:GetWide(), 0, 1)
            local len = BATTLEBEATS.currentPreviewStation:GetLength()
            if len > 0 then
                local newTime = progress * len
                BATTLEBEATS.currentPreviewStation:SetTime(newTime, true)
                currentTimeLabel:SetText(BATTLEBEATS.FormatTime(newTime))
            end
        end
    end

    progressBar.Think = function(self)
        if not IsValid(BATTLEBEATS.currentPreviewStation) then return end
        local len = BATTLEBEATS.currentPreviewStation:GetLength()
        local pos = BATTLEBEATS.currentPreviewStation:GetTime()

        if len > 0 then
            currentTimeLabel:SetText(BATTLEBEATS.FormatTime(pos))
            totalTimeLabel:SetText(BATTLEBEATS.FormatTime(len))
        end
    end

    local progressDot = vgui.Create("DPanel", progressBar)
    progressDot:SetSize(12, 12)
    progressDot:SetMouseInputEnabled(false)
    progressDot.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, color_white)
    end

    progressDot.Think = function(self)
        if not IsValid(BATTLEBEATS.currentPreviewStation) then return end
        local currentTime = BATTLEBEATS.currentPreviewStation:GetTime()
        local trackDuration = BATTLEBEATS.currentPreviewStation:GetLength()
        if trackDuration <= 0 then return end

        local progress = math.Clamp(currentTime / trackDuration, 0, 1)
        local barWidth = progressBar:GetWide()
        local dotX = barWidth * progress - self:GetWide() / 2
        local dotY = progressBar:GetTall() / 2 - self:GetTall() / 2 + 2
        self:SetPos(dotX, dotY)
    end

    playPause.DoClick = function()
        if not IsValid(BATTLEBEATS.currentPreviewStation) then
            print("[BattleBeats Debug] No track loaded on play/pause!")
            return
        end

        if BATTLEBEATS.currentPreviewStation:GetState() == GMOD_CHANNEL_PLAYING then
            BATTLEBEATS.currentPreviewStation:Pause()
            playPause:SetText("▶")
            if showPreviewNotification:GetBool() then BATTLEBEATS.HideNotification() end
        else
            BATTLEBEATS.currentPreviewStation:Play()
            playPause:SetText("⏸")
            if showPreviewNotification:GetBool() then BATTLEBEATS.ShowTrackNotification(BATTLEBEATS.currentPreviewTrack, false, true) end
        end
    end
    --MARK:Tracks list
    local selectedSorting = nil
    local selectedText = nil
    local ambientGrad = Color(60, 180, 60, 70)
    local combatGrad = Color(255, 80, 40, 80)
    local pWidth = 800
    local cachedScrollOffset = 0
    local cachedScrollH = 0
    local lastCacheTime = 0
    local lastVisibilityCheck = 0
    local function isRowVisible(row)
        if not IsValid(ui.scrollPanel) then return true end
        local y = row:GetY()
        local rowBottom = y + 50
        return rowBottom > cachedScrollOffset - 100 and y < cachedScrollOffset + cachedScrollH + 100
    end
    ui.scrollPanel.Think = function(self)
        local ct = CurTime()
        if trackMenu and IsValid(trackMenu) then
            local currentScroll = self:GetVBar():GetScroll()
            if math.abs(currentScroll - cachedScrollOffset) > 2 then
                trackMenu:Remove()
                trackMenu = nil
            end
        end
        if ct - lastCacheTime > 0.1 then
            cachedScrollOffset = self:GetVBar():GetScroll()
            cachedScrollH = self:GetTall()
            lastCacheTime = ct
        end
        if ct - lastVisibilityCheck > 0.1 then
            for _, row in ipairs(allRows) do
                if IsValid(row) then
                    row.isVisibleCached = isRowVisible(row)
                end
            end
            lastVisibilityCheck = ct
        end
    end
    local function createTrackList(parent, trackType, selectedPack)
        parent:Clear()
        local isAllMode = (trackType == "all")
        local function addTrackRow(track, excluded, isFavorite, actualTrackType)
            local aliasName = BATTLEBEATS.trackAliases and BATTLEBEATS.trackAliases[track]
            local trackName = BATTLEBEATS.FormatTrackName(track)
            local displayName = aliasName or trackName
            local row = vgui.Create("DPanel", parent)
            row:SetSize(0, 50)
            row:Dock(TOP)
            row:DockMargin(0, 5, 13, 3)
            row:SetCursor("hand")
            row.trackPath = track
            row.trackName = trackName
            row.actualType = actualTrackType or trackType
            row.textX = 10
            row.isScrolling = false
            row.scrollResetTime = 0
            row.currentColor = clr.cHover
            row.targetColor = clr.cHover
            row.initialized = false
            row.gradientWidth = 0
            row.targetWidth = 0
            row.isVisibleCached = false

            row.fadeAlpha = 0
            row.targetFadeAlpha = 255

            row.Think = function(self)
                if not self.isVisibleCached then
                    self.targetFadeAlpha = 0
                    return
                end
                local rowY = self:GetY()
                local rowCenter = rowY + 25
                local viewCenter = cachedScrollOffset + (cachedScrollH / 2)
                local distanceFromCenter = math.abs(rowCenter - viewCenter)
                local fadeRange = cachedScrollH * 0.4
                if distanceFromCenter < fadeRange then
                    self.targetFadeAlpha = 255
                else
                    local over = distanceFromCenter - fadeRange
                    self.targetFadeAlpha = math.max(60, 255 - (over * 1.2))
                end
                self.fadeAlpha = Lerp(FrameTime() * 9, self.fadeAlpha, self.targetFadeAlpha)

                local isSelected = (self.trackName == ui.selectedRow)
                if isSelected or self.menuActive then
                    self.targetColor = clr.c707070200
                    self.targetWidth = self:GetWide() + 500
                elseif self:IsHovered() then
                    self.targetColor = clr.cHover2
                    self.targetWidth = (self:GetWide() - 350) + 300
                else
                    self.targetColor = clr.cHover
                    self.targetWidth = self:GetWide() - 350
                end

                if not self.initialized then
                    self.initialized = true
                    self.currentColor = self.targetColor
                    self.gradientWidth = self:GetWide() - 350
                    return
                end

                if self.gradientWidth ~= self.targetWidth then
                    self.gradientWidth = Lerp(FrameTime() * 10, self.gradientWidth, self.targetWidth)
                end
                self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
            end

            if ui.selectedRow == row.trackName then
                timer.Simple(0.1, function ()
                    if IsValid(row) then
                        ui.scrollPanel:ScrollToChild(row)
                    end
                end)
            end

            surface.SetFont("BattleBeats_Font")
            local textWidth = surface.GetTextSize(isFavorite and "★ " .. displayName or displayName)
            if aliasName then
                surface.SetFont("BattleBeats_Rename_Font")
                textWidth = textWidth + surface.GetTextSize("   " .. trackName)
            end
            local npcs = BATTLEBEATS.npcTrackMappings[track] and BATTLEBEATS.npcTrackMappings[track].npcs
            local count = istable(npcs) and #npcs or 0
            local startTrack = cookie.GetString("battlebeats_start_track", "") == track

            local iconData = {
                {check = count == 1, tooltip = "#btb.ps.ts.icon_assigned", image = "icon16/user.png"},
                {check = count >= 2, tooltip = "#btb.ps.ts.icon_assigned_multiple", image = "icon16/group.png"},
                {check = BATTLEBEATS.trackTrim[track] ~= nil, tooltip = "#btb.ps.ts.icon_trim", image = "icon16/time.png"},
                {check = BATTLEBEATS.parsedSubtitles[string.lower(trackName)] ~= nil, tooltip = "#btb.ps.ts.icon_subtitle", image = "icon16/comments.png"},
                {check = startTrack, tooltip = "#btb.ps.ts.icon_start", image = "icon16/door_in.png"},
                {check = BATTLEBEATS.trackVolume[track] ~= nil, tooltip = "#btb.ps.ts.icon_volume", image = "icon16/sound.png"},
            }

            local xOffset = 840
            for _, data in ipairs(iconData) do
                if data.check then
                    local tooltipFrame = vgui.Create("DPanel", row)
                    tooltipFrame:SetSize(16, 16)
                    tooltipFrame:SetPos(xOffset, 17)
                    tooltipFrame:SetPaintBackground(false)
                    tooltipFrame:SetTooltip(data.tooltip)
                    tooltipFrame:SetTooltipPanelOverride("BattleBeatsTooltip")

                    local icon = vgui.Create("DImage", tooltipFrame)
                    icon:SetSize(16, 16)
                    icon:SetPos(0, 0)
                    icon:SetImage(data.image)

                    xOffset = xOffset - 20
                end
            end

            local colorLerp = excluded and clr.c25500 or clr.c2552100
            local targetColor = colorLerp
            local customCheckbox = vgui.Create("DPanel", row)
            customCheckbox:SetSize(85, 25)
            customCheckbox:SetPos(860, 12.5)
            customCheckbox:SetCursor("hand")
            customCheckbox.OnCursorEntered = function(self)
                targetColor = excluded and Color(255, 80, 80) or Color(255, 230, 50)
            end
            customCheckbox.OnCursorExited = function(self)
                targetColor = excluded and clr.c25500 or clr.c2552100
            end
            customCheckbox:SetTooltip(excluded and "#btb.ps.ts.exclude_tip" or "#btb.ps.ts.include_tip")

            customCheckbox.OnMousePressed = function(self)
                excluded = not excluded
                BATTLEBEATS.excludedTracks[track] = excluded
                ui.changesMade = true
                BATTLEBEATS.SaveExcludedTracks()
                targetColor = excluded and clr.c25500 or clr.c2552100
                customCheckbox:SetTooltip(excluded and "#btb.ps.ts.exclude_tip" or "#btb.ps.ts.include_tip")
                surface.PlaySound(excluded and "btb_button_disable.mp3" or "btb_button_enable.mp3")
            end
            customCheckbox:SetTooltipPanelOverride("BattleBeatsTooltip")

            customCheckbox.Paint = function(self, w, h)
                if not row.isVisibleCached then return end
                if row.fadeAlpha < 1 then return end
                surface.SetAlphaMultiplier(row.fadeAlpha / 255)
                colorLerp = LerpColor(FrameTime() * 10, colorLerp, targetColor)
                draw.RoundedBox(6, 0, 0, w, h, colorLerp)
                local text = excluded and "#btb.ps.ts.track_disabled" or "#btb.ps.ts.track_enabled"
                draw.SimpleTextOutlined(text, "BattleBeats_Checkbox_Font", w / 2, 3, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 0.9, clr.c000200)
                surface.SetAlphaMultiplier(1)
            end

            row.OnMousePressed = function(self, keyCode)
                if keyCode == MOUSE_LEFT then
                    ui.selectedRow = row.trackName
                end
            end

            row.OnCursorEntered = function(self)
                self.isScrolling = textWidth > pWidth
            end
            row.OnCursorExited = function(self)
                self.isScrolling = false
                self.scrollResetTime = CurTime()
            end

            local gradientCol = nil
            if row.actualType == "combat" then
                gradientCol = combatGrad
            elseif row.actualType == "ambient" then
                gradientCol = ambientGrad
            end
            row.Paint = function(self, w, h)
                if not self.isVisibleCached then return end
                if self.fadeAlpha < 1 then return end
                surface.SetAlphaMultiplier(self.fadeAlpha / 255)
                draw.RoundedBox(4, 0, 0, w, h, self.currentColor)
                surface.SetDrawColor(gradientCol)
                surface.SetTexture(texGradient)
                surface.DrawTexturedRect(0, 0, self.gradientWidth, h)
                if self.isScrolling and textWidth > pWidth then
                    self.textX = self.textX - (60 * FrameTime())
                    local maxScroll = -(textWidth - pWidth)
                    if self.textX < maxScroll then
                        self.textX = maxScroll
                    end
                elseif not self.isScrolling and self.textX < 10 then
                    local timeSinceExit = CurTime() - self.scrollResetTime
                    self.textX = Lerp(math.min(timeSinceExit * 0.2, 1), self.textX, 10)
                end

                local screenX, screenY = self:LocalToScreen(0, 0)
                render.SetScissorRect(screenX, screenY, screenX + pWidth, screenY + h, true)
                local textPosX = self.textX
                if isFavorite then
                    draw.SimpleTextOutlined("★", "BattleBeats_Font", textPosX, h / 2, clr.c2552100, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, clr.c000200)
                    local starW = surface.GetTextSize("★ ")
                    textPosX = textPosX + starW
                end
                draw.SimpleTextOutlined(displayName, "BattleBeats_Font", textPosX, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, clr.c000200)
                if aliasName then
                    local aliasW = surface.GetTextSize(displayName .. " ")
                    draw.SimpleText(trackName, "BattleBeats_Rename_Font", textPosX + aliasW, h / 2, clr.c150150150, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                render.SetScissorRect(0, 0, 0, 0, false)
                surface.SetAlphaMultiplier(1)
            end

            --MARK:Track list player
            row.OnMouseReleased = function(self, keyCode)
                if keyCode == MOUSE_LEFT then
                    ui.changesMade = true
                    if not gui.IsGameUIVisible() or not game.SinglePlayer() then
                        if track == BATTLEBEATS.currentPreviewTrack then return end
                        if not playerPanel:IsVisible() then
                            playerPanel:SetAlpha(0)
                            playerPanel:AlphaTo(255, 0.3, 0)
                        end
                        playerPanel:SetVisible(true)
                        ui.scrollPanel:SetSize(980, 410)
                        playPause:SetText("⏸")
                        currentTimeLabel:SetText("0:00")
                        totalTimeLabel:SetText("0:00")
                        trackNameLabel:SetText(displayName)
                        ui.scrollPanel:ScrollToChild(self)

                        BATTLEBEATS.PlayNextTrackPreview(track, nil, false, function()
                            playerPanel:SetVisible(false)
                        end)
                        BATTLEBEATS.currentPreviewTrack = track
                        if not showPreviewNotification:GetBool() then BATTLEBEATS.HideNotification() end
                        if not timer.Exists("BattleBeats_NextPreviewTrack") then
                            timer.Create("BattleBeats_NextPreviewTrack", 0.5, 0, function()
                                if IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() == GMOD_CHANNEL_STOPPED then
                                    if isLooping then
                                        BATTLEBEATS.PlayNextTrackPreview(BATTLEBEATS.currentPreviewTrack, nil, true, function()
                                            playerPanel:SetVisible(false)
                                        end)
                                    else
                                        BATTLEBEATS.SwitchPreviewTrack(1)
                                    end
                                end
                                if IsValid(BATTLEBEATS.currentPreviewStation) then
                                    BATTLEBEATS.currentPreviewPosition = BATTLEBEATS.currentPreviewStation:GetTime()
                                end
                            end)
                        end
                    else
                        print("[BattleBeats Client] Cannot preview sound while the game is paused")
                    end
                elseif keyCode == MOUSE_RIGHT then
                    local menu = DermaMenu()
                    trackMenu = menu
                    self.menuActive = true
                    menu.OnRemove = function()
                        if IsValid(self) then
                            self.menuActive = false
                        end
                    end
                    if LocalPlayer():IsSuperAdmin() and not isSingle then
                        local adminDivider = menu:AddOption("------ADMIN------")
                        adminDivider:BTB_PaintProperties()
                        local enforceSub, enforceBtn = menu:AddSubMenu("#btb.ps.ts.rmb.enforce")
                        enforceBtn:SetImage("icon16/music.png")
                        enforceBtn:BTB_PaintProperties()
                        enforceSub.Paint = function(self, w, h)
                            draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
                            draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c505050)
                        end
                        enforceBtn:SetTooltip("#btb.ps.ts.rmb.enforce_tip")
                        enforceBtn:SetTooltipPanelOverride("BattleBeatsTooltip")

                        local allOpt = enforceSub:AddOption("#btb.ps.ts.rmb.enforce_to_all", function()
                            net.Start("BTB_SV_Receive_Sound")
                            net.WritePlayer(NULL)
                            net.WriteString(track)
                            net.SendToServer()
                        end)
                        allOpt:SetImage("icon16/group.png")
                        allOpt:BTB_PaintProperties()

                        local playerSub, playerBtn = enforceSub:AddSubMenu(language.GetPhrase("btb.ps.ts.rmb.enforce_to_player") .. ":")
                        playerBtn:SetImage("icon16/user_orange.png")
                        playerBtn:BTB_PaintProperties()
                        playerSub.Paint = function(self, w, h)
                            draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
                            draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c505050)
                        end

                        for _, ply in ipairs(player.GetAll()) do
                            local opt = playerSub:AddOption(ply:Nick(), function()
                                net.Start("BTB_SV_Receive_Sound")
                                net.WritePlayer(ply)
                                net.WriteString(track)
                                net.SendToServer()
                            end)
                            opt:BTB_PaintProperties()
                        end
                        local clientDivider = menu:AddOption("------CLIENT------")
                        clientDivider:BTB_PaintProperties()
                    end
                    local vol = (BATTLEBEATS.trackVolume[track] ~= nil and (BATTLEBEATS.trackVolume[track] - 100)) or 0
                    local optionName
                    if vol ~= 0 then
                        local opTrans = language.GetPhrase("btb.ps.pack_rmb.edit_volume")
                        optionName = opTrans .. " [" .. vol .. "%]"
                    else
                        optionName = "#btb.ps.pack_rmb.set_volume"
                    end
                    local volumeOption = menu:AddOption(optionName, function()
                        BATTLEBEATS.openVolumeEditor(frame, track, nil, function()
                            createTrackList(parent, trackType, selectedPack)
                        end)
                    end)
                    volumeOption:SetImage("icon16/sound.png")
                    volumeOption:BTB_PaintProperties()

                    local addList = {}
                    local removeList = {}
                    for playlistName, _ in pairs(BATTLEBEATS.musicPlaylists) do
                        local isIn = BATTLEBEATS.isTrackInPlaylist(playlistName, track, self.actualType)
                        if isIn then
                            table.insert(removeList, playlistName)
                        else
                            table.insert(addList, playlistName)
                        end
                    end

                    local packData = selectedPack and BATTLEBEATS.musicPacks[selectedPack]
                    if #addList > 0 and packData and packData.packType ~= "playlist" then
                        local addSub, menPaint = menu:AddSubMenu(language.GetPhrase("btb.playlist.add_to") .. ":")
                        menPaint:BTB_PaintProperties()
                        menPaint:SetImage("icon16/arrow_branch.png")
                        addSub.Paint = function(self, w, h)
                            draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
                            draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c505050)
                        end
                        for _, playlistName in ipairs(addList) do
                            local opt = addSub:AddOption(playlistName, function()
                                BATTLEBEATS.addTrackToPlaylist(playlistName, track, self.actualType)
                                surface.PlaySound("buttons/button14.wav")
                            end)
                            opt:BTB_PaintProperties()
                        end
                    end

                    if #removeList > 0 and packData and packData.packType ~= "playlist" then
                        local removeSub, menPaint = menu:AddSubMenu(language.GetPhrase("btb.playlist.remove_from") .. ":")
                        menPaint:BTB_PaintProperties()
                        menPaint:SetImage("icon16/delete.png")
                        removeSub.Paint = function(self, w, h)
                            draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
                            draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c505050)
                        end
                        for _, playlistName in ipairs(removeList) do
                            local opt = removeSub:AddOption(playlistName, function()
                                BATTLEBEATS.removeTrackFromPlaylist(playlistName, track, self.actualType)
                                surface.PlaySound("buttons/button14.wav")
                            end)
                            opt:BTB_PaintProperties()
                        end
                    end

                    if packData and packData.packType == "playlist" then
                        menu:AddSpacer()
                        local opt = menu:AddOption("#btb.playlist.remove_track", function()
                            BATTLEBEATS.removeTrackFromPlaylist(selectedPack, track, self.actualType)
                            createTrackList(parent, trackType, selectedPack)
                            surface.PlaySound("buttons/button14.wav")
                        end)
                        opt:SetImage("icon16/delete.png")
                        opt:BTB_PaintProperties()
                    end

                    --MARK:RMB favorites
                    if isFavorite then
                        local unfavorite = menu:AddOption("#btb.ps.ts.rmb.remove_fav", function()
                            BATTLEBEATS.favoriteTracks[track] = nil
                            BATTLEBEATS.SaveFavoriteTracks()
                            ui.changesMade = true
                            createTrackList(parent, trackType, selectedPack)
                        end)
                        unfavorite:SetImage("icon16/cancel.png")
                        unfavorite:BTB_PaintProperties()
                    else
                        local favorite = menu:AddOption("#btb.ps.ts.rmb.add_fav", function()
                            BATTLEBEATS.favoriteTracks[track] = true
                            BATTLEBEATS.SaveFavoriteTracks()
                            ui.changesMade = true
                            createTrackList(parent, trackType, selectedPack)
                        end)
                        favorite:SetImage("icon16/star.png")
                        favorite:BTB_PaintProperties()
                    end

                    --MARK:RMB start track
                    local currentStartTrack = cookie.GetString("battlebeats_start_track", "")
                    if currentStartTrack == track and currentStartTrack ~= "" then
                        local removeStart = menu:AddOption("#btb.ps.ts.rmb.remove_start_track", function()
                            cookie.Delete("battlebeats_start_track")
                            createTrackList(parent, trackType, selectedPack)
                        end)
                        removeStart:SetImage("icon16/cancel.png")
                        removeStart:BTB_PaintProperties()
                    else
                        local setAsStart = menu:AddOption("#btb.ps.ts.rmb.set_start_track", function()
                            cookie.Set("battlebeats_start_track", track)
                            RunConsoleCommand("battlebeats_start_mode", "2")
                            createTrackList(parent, trackType, selectedPack)
                        end)
                        setAsStart:SetImage("icon16/door_in.png")
                        setAsStart:SetTooltip("#btb.ps.ts.rmb.set_start_track_tip")
                        setAsStart:SetTooltipPanelOverride("BattleBeatsTooltip")
                        setAsStart:BTB_PaintProperties()
                    end

                    --MARK:RMB offset/trim
                    local trim = BATTLEBEATS.trackTrim[track]
                    local trimOptionTitle = language.GetPhrase("#btb.ps.ts.rmb.trim_edit")
                    local trimText = nil
                    if trim then
                        local startVal = trim.start
                        local endVal = trim.finish
                        local startText = startVal and BATTLEBEATS.FormatTime(startVal) or "start"
                        local endText = endVal and BATTLEBEATS.FormatTime(endVal) or "end"
                        trimText = startText .. " - " .. endText
                    end
                    local offsetOption = menu:AddOption(trimText and (trimOptionTitle .. " (" .. trimText .. ")") or "#btb.ps.ts.rmb.trim_set", function()
                        BATTLEBEATS.openTrimEditor(frame, track, function()
                            ui.changesMade = true
                            createTrackList(parent, trackType, selectedPack)
                        end)
                    end)
                    offsetOption:SetImage("icon16/time.png")
                    offsetOption:SetTooltip("#btb.ps.ts.rmb.trim_tip")
                    offsetOption:SetTooltipPanelOverride("BattleBeatsTooltip")
                    offsetOption:BTB_PaintProperties()

                    --MARK:RMB npc assign
                    if row.actualType == "combat" then
                        local currentNPCs = BATTLEBEATS.npcTrackMappings[track] and
                        BATTLEBEATS.npcTrackMappings[track].npcs or {}
                        local assignNPC = menu:AddOption("#btb.ps.ts.rmb.assign_add", function()
                            activeTextEntries.assignBox = BATTLEBEATS.createAssignFrame(frame, "#btb.ps.ts.rmb.assign_title", nil, 1, function(class, priority, fframe)
                                if not class or class == "" then
                                    notification.AddLegacy("#btb.ps.ts.rmb.assign_no_class", NOTIFY_ERROR, 3)
                                    surface.PlaySound("buttons/button11.wav")
                                    return
                                end

                                local isDuplicateInTrack = false
                                if BATTLEBEATS.npcTrackMappings[track] and BATTLEBEATS.npcTrackMappings[track].npcs then
                                    for _, npc in ipairs(BATTLEBEATS.npcTrackMappings[track].npcs) do
                                        if npc.class == class then
                                            isDuplicateInTrack = true
                                            break
                                        end
                                    end
                                end

                                local oldTrack = nil
                                if not isDuplicateInTrack then
                                    for t, info in pairs(BATTLEBEATS.npcTrackMappings) do
                                        if t ~= track and info.npcs then
                                            for _, npc in ipairs(info.npcs) do
                                                if npc.class == class then
                                                    oldTrack = t
                                                    break
                                                end
                                            end
                                            if oldTrack then break end
                                        end
                                    end
                                end

                                local function assignNPCToTrack()
                                    BATTLEBEATS.npcTrackMappings[track] = BATTLEBEATS.npcTrackMappings[track] or
                                    { npcs = {} }
                                    table.insert(BATTLEBEATS.npcTrackMappings[track].npcs,
                                        { class = class, priority = priority })
                                    if oldTrack and BATTLEBEATS.npcTrackMappings[oldTrack] then
                                        for i = #BATTLEBEATS.npcTrackMappings[oldTrack].npcs, 1, -1 do
                                            if BATTLEBEATS.npcTrackMappings[oldTrack].npcs[i].class == class then
                                                table.remove(BATTLEBEATS.npcTrackMappings[oldTrack].npcs, i)
                                                break
                                            end
                                        end
                                        if #BATTLEBEATS.npcTrackMappings[oldTrack].npcs == 0 then
                                            BATTLEBEATS.npcTrackMappings[oldTrack] = nil
                                        end
                                    end
                                    notification.AddLegacy(language.GetPhrase("btb.ps.ts.rmb.assign_noti_class") .. ": " .. class .. " " .. language.GetPhrase("btb.ps.ts.rmb.assign_noti_priority") .. " " .. priority .. " " .. language.GetPhrase("btb.ps.ts.rmb.assign_noti_track") .. ": " .. BATTLEBEATS.FormatTrackName(track), NOTIFY_GENERIC, 3)
                                    surface.PlaySound("buttons/button14.wav")
                                    BATTLEBEATS.SaveNPCMappings()
                                    ui.changesMade = true
                                    fframe:Remove()
                                    createTrackList(parent, trackType, selectedPack)
                                end

                                if isDuplicateInTrack then
                                    notification.AddLegacy("NPC '" .. class .. "' " .. language.GetPhrase("btb.ps.ts.rmb.assign_this_track"), NOTIFY_ERROR, 3)
                                    surface.PlaySound("buttons/button11.wav")
                                elseif oldTrack then
                                    surface.PlaySound("buttons/button17.wav")
                                    Derma_Query("NPC: (" .. class .. ") " .. language.GetPhrase("btb.ps.ts.rmb.assign_already_assigned") .. ": (" .. BATTLEBEATS.FormatTrackName(oldTrack) .. "). " .. language.GetPhrase("btb.ps.ts.rmb.assign_overwrite"), "#btb.ps.ts.rmb.assign_conf_overwrite", "#btb.ps.ts.rmb.assign_yes", function() assignNPCToTrack() end, "#btb.ps.ts.rmb.assign_no", function() end)
                                else
                                    assignNPCToTrack()
                                end
                            end)
                        end)
                        assignNPC:SetImage("icon16/user_add.png")
                        assignNPC:SetTooltip("#btb.ps.ts.rmb.assign_tip")
                        assignNPC:SetTooltipPanelOverride("BattleBeatsTooltip")
                        assignNPC:BTB_PaintProperties()

                        for _, npcInfo in ipairs(currentNPCs) do
                            local s1 = language.GetPhrase("#btb.ps.ts.rmb.assign_current")
                            local s2 = language.GetPhrase("#btb.ps.ts.rmb.assign_priority")
                            local npcText = s1 .. npcInfo.class .. " (" .. s2 .. npcInfo.priority .. ")"

                            local subMenu, parentOption = menu:AddSubMenu(npcText)
                            parentOption:SetImage("icon16/vcard.png")
                            parentOption:BTB_PaintProperties()
                            subMenu.Paint = function(self, w, h)
                                draw.RoundedBox(10, 0, 0, w, h, Color(255, 210, 0))
                                draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
                            end

                            local editOpt = subMenu:AddOption("#btb.ps.ts.rmb.assign_edit", function()
                                activeTextEntries.assignBox = BATTLEBEATS.createAssignFrame(frame, language.GetPhrase("#btb.ps.ts.rmb.assign_edit") .. ": " .. npcInfo.class, npcInfo.class, npcInfo.priority, function(newClass, newPrio, fframe)
                                    if not newClass or newClass == "" then
                                        notification.AddLegacy("#btb.ps.ts.rmb.assign_no_class", NOTIFY_ERROR, 3)
                                        surface.PlaySound("buttons/button11.wav")
                                        return
                                    end

                                    if newClass == npcInfo.class then
                                        for i, npc in ipairs(BATTLEBEATS.npcTrackMappings[track].npcs) do
                                            if npc.class == npcInfo.class then
                                                BATTLEBEATS.npcTrackMappings[track].npcs[i].priority = newPrio
                                                break
                                            end
                                        end
                                        BATTLEBEATS.SaveNPCMappings()
                                        ui.changesMade = true
                                        notification.AddLegacy(language.GetPhrase("btb.ps.ts.rmb.assign_edited") .. ": " .. npcInfo.class .. " (" .. npcInfo.priority .. ") " .. " → " .. newClass .. " (" .. newPrio .. ")", NOTIFY_GENERIC, 3)
                                        surface.PlaySound("buttons/button14.wav")
                                        fframe:Remove()
                                        createTrackList(parent, trackType, selectedPack)
                                        return
                                    end

                                    local isDuplicateInTrack = false
                                    for _, npc in ipairs(BATTLEBEATS.npcTrackMappings[track].npcs) do
                                        if npc.class == newClass and npc.class ~= npcInfo.class then
                                            isDuplicateInTrack = true
                                            break
                                        end
                                    end

                                    if isDuplicateInTrack then
                                        notification.AddLegacy("NPC '" .. newClass .. "' " .. language.GetPhrase("btb.ps.ts.rmb.assign_this_track"), NOTIFY_ERROR, 3)
                                        surface.PlaySound("buttons/button11.wav")
                                        return
                                    end

                                    local oldTrack = nil
                                    for t, info in pairs(BATTLEBEATS.npcTrackMappings) do
                                        if t ~= track and info.npcs then
                                            for _, npc in ipairs(info.npcs) do
                                                if npc.class == newClass then
                                                    oldTrack = t
                                                    break
                                                end
                                            end
                                            if oldTrack then break end
                                        end
                                    end

                                    local function saveEdit()
                                        for i = #BATTLEBEATS.npcTrackMappings[track].npcs, 1, -1 do
                                            if BATTLEBEATS.npcTrackMappings[track].npcs[i].class == npcInfo.class then
                                                table.remove(BATTLEBEATS.npcTrackMappings[track].npcs, i)
                                                break
                                            end
                                        end
                                        table.insert(BATTLEBEATS.npcTrackMappings[track].npcs, {class = newClass, priority = newPrio})
                                        if oldTrack and BATTLEBEATS.npcTrackMappings[oldTrack] then
                                            for j = #BATTLEBEATS.npcTrackMappings[oldTrack].npcs, 1, -1 do
                                                if BATTLEBEATS.npcTrackMappings[oldTrack].npcs[j].class == newClass then
                                                    table.remove(BATTLEBEATS.npcTrackMappings[oldTrack].npcs, j)
                                                    break
                                                end
                                            end
                                            if #BATTLEBEATS.npcTrackMappings[oldTrack].npcs == 0 then
                                                BATTLEBEATS.npcTrackMappings[oldTrack] = nil
                                            end
                                        end
                                        BATTLEBEATS.SaveNPCMappings()
                                        ui.changesMade = true
                                        notification.AddLegacy(
                                        language.GetPhrase("btb.ps.ts.rmb.assign_edited") .. ": " .. npcInfo.class .. " (" .. npcInfo.priority .. ") " .. " → " .. newClass .. " (" .. newPrio .. ")", NOTIFY_GENERIC, 3)
                                        surface.PlaySound("buttons/button14.wav")
                                        fframe:Remove()
                                        createTrackList(parent, trackType, selectedPack)
                                    end

                                    if oldTrack then
                                        surface.PlaySound("buttons/button17.wav")
                                        Derma_Query("NPC: (" .. newClass .. ") " .. language.GetPhrase("btb.ps.ts.rmb.assign_already_assigned") .. ": (" .. BATTLEBEATS.FormatTrackName(oldTrack) .. "). " .. language.GetPhrase("btb.ps.ts.rmb.assign_overwrite"),
                                        "#btb.ps.ts.rmb.assign_conf_overwrite", "#btb.ps.ts.rmb.assign_yes", function() saveEdit() end, "#btb.ps.ts.rmb.assign_no", function() end)
                                    else
                                        saveEdit()
                                    end
                                end)
                            end)
                            editOpt:SetImage("icon16/user_edit.png")
                            editOpt:BTB_PaintProperties()

                            local removeOpt = subMenu:AddOption("#btb.ps.ts.rmb.assign_remove", function()
                                for i = #BATTLEBEATS.npcTrackMappings[track].npcs, 1, -1 do
                                    if BATTLEBEATS.npcTrackMappings[track].npcs[i].class == npcInfo.class then
                                        table.remove(BATTLEBEATS.npcTrackMappings[track].npcs, i)
                                        break
                                    end
                                end
                                if #BATTLEBEATS.npcTrackMappings[track].npcs == 0 then
                                    BATTLEBEATS.npcTrackMappings[track] = nil
                                end
                                BATTLEBEATS.SaveNPCMappings()
                                ui.changesMade = true
                                notification.AddLegacy(language.GetPhrase("btb.ps.ts.rmb.assign_removed") .. ": " .. npcInfo.class, NOTIFY_GENERIC, 3)
                                surface.PlaySound("buttons/button3.wav")
                                createTrackList(parent, trackType, selectedPack)
                            end)
                            removeOpt:BTB_PaintProperties()
                            removeOpt:SetImage("icon16/user_delete.png")
                        end
                    end

                    --MARK:RMB subtitles
                    local subs = BATTLEBEATS.parsedSubtitles[string.lower(trackName)]
                    if subs and #subs > 0 then
                        local lyricsOption = menu:AddOption("#btb.ps.ts.rmb.show_lyrics", function()
                            BATTLEBEATS.openSubtitles(frame, trackName, subs)
                        end)
                        lyricsOption:SetImage("icon16/text_align_left.png")
                        lyricsOption:BTB_PaintProperties()
                    end

                    --MARK:RMB Rename
                    BATTLEBEATS.trackAliases = BATTLEBEATS.trackAliases or {}
                    local renameOption = menu:AddOption("#btb.ps.ts.rmb.set_name", function()
                        activeTextEntries.changeNameBox = BATTLEBEATS.changeName(frame, track, function()
                            createTrackList(parent, trackType, selectedPack)
                        end)
                    end)

                    renameOption:SetImage("icon16/tag_blue_edit.png")
                    renameOption:BTB_PaintProperties()

                    local copy = menu:AddOption("#btb.ps.ts.rmb.copy", function()
                        SetClipboardText(track)
                    end)
                    copy:SetImage("icon16/tag.png")
                    copy:BTB_PaintProperties()
                    menu:Open()
                    menu.Paint = function(self, w, h)
                        draw.RoundedBox(10, 0, 0, w, h, Color(255, 210, 0))
                        draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
                    end
                end
            end

            return row
        end

        --MARK:Sorting & search
        local nameText = "#btb.ps.ts.header.name"
        local excludeText = "#btb.ps.ts.header.exclude"
        local searchPanel = vgui.Create("DPanel", parent)
        searchPanel:Dock(TOP)
        searchPanel:SetTall(60)
        searchPanel:DockMargin(0, 5, 15, 10)
        searchPanel.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
            draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c404040)
            surface.SetFont("DermaDefaultBold")
            local excludeW = surface.GetTextSize(excludeText)
            draw.SimpleText(nameText, "DermaDefaultBold", 40, 45, clr.c100100100, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(excludeText, "DermaDefaultBold", w - excludeW - 40, 45, clr.c100100100, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        activeTextEntries.searchBox = vgui.Create("DTextEntry", searchPanel)
        activeTextEntries.searchBox:SetSize(600, 30)
        activeTextEntries.searchBox:SetPos(170, 10)
        activeTextEntries.searchBox:SetFont("BattleBeats_Font")
        activeTextEntries.searchBox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, clr.c707070255)
            self:DrawTextEntryText(color_white, color_white, color_white)
            if self:GetText() == "" and not self:IsEditing() then
                draw.SimpleText("#btb.ps.search", "BattleBeats_Font", 5, h / 2, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        local sortCombo = vgui.Create("DComboBox", searchPanel)
        sortCombo:SetSize(100, 30)
        sortCombo:SetPos(830, 11)
        sortCombo:SetValue(selectedText or "A → Z")
        local packData = selectedPack and BATTLEBEATS.musicPacks[selectedPack]
        if packData and packData.packType == "playlist" then
            sortCombo:AddChoice("#btb.ps.sort.playlist_order", "playlist", false, "icon16/text_list_numbers.png")
        end
        sortCombo:AddChoice("A → Z", "az", false, "icon16/arrow_down.png")
        sortCombo:AddChoice("Z → A", "za", false, "icon16/arrow_up.png")
        sortCombo:AddChoice("#btb.ps.sort.random", "rnd", false, "icon16/arrow_switch.png")
        sortCombo:AddChoice("#btb.ps.sort.favorite_only", "fav", false, "icon16/star.png")
        sortCombo:AddChoice("#btb.ps.sort.include_only", "inc", false, "icon16/tick.png")
        sortCombo:AddChoice("#btb.ps.sort.exclude_only", "ex", false, "icon16/cross.png")
        if isAllMode or trackType == "combat" then
            sortCombo:AddChoice("#btb.ps.sort.assigned_only", "assigned", false, "icon16/user.png")
        end
        sortCombo:AddChoice("#btb.ps.sort.renamed_only", "rename", false, "icon16/tag_blue.png")
        sortCombo:AddChoice("#btb.ps.sort.offset_only", "offset", false, "icon16/time.png")
        sortCombo:AddChoice("#btb.ps.sort.volume_only", "volume", false, "icon16/sound.png")
        sortCombo:SetSortItems(false)
        sortCombo:ChooseOptionID(selectedSorting or 1)
        --sortCombo:SetContentAlignment(5)
        sortCombo:SetTextColor(color_white)
        sortCombo:SetTooltip("#btb.ps.sort.tooltip")
        sortCombo:SetTooltipPanelOverride("BattleBeatsTooltip")
        sortCombo.DropButton:SetVisible(false)
        sortCombo.OnMenuOpened = function(panel)
            panel.Menu.Paint = function(self, w, h)
                draw.RoundedBox(10, 0, 0, w, h, Color(255, 210, 0))
                draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
            end
            for _, child in pairs(panel.Menu:GetChildren()) do
                if IsValid(child) then
                    for _, c in pairs(child:GetChildren()) do
                        if c.SetTextColor then
                            c:BTB_PaintProperties()
                        end
                    end
                end
            end
        end
        sortCombo.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, clr.c404040)
        end

        local includeExcludeCombo = vgui.Create("DComboBox", searchPanel)
        includeExcludeCombo:SetSize(100, 30)
        includeExcludeCombo:SetPos(50, 11)
        includeExcludeCombo:SetValue("#btb.ps.sort.options")
        includeExcludeCombo:AddChoice("#btb.ps.sort.options_include", nil, false, "icon16/tick.png")
        includeExcludeCombo:AddChoice("#btb.ps.sort.options_exclude", nil, false, "icon16/delete.png")
        includeExcludeCombo:SetSortItems(false)
        includeExcludeCombo:SetTextColor(color_white)
        includeExcludeCombo.DropButton:SetVisible(false)
        includeExcludeCombo.OnMenuOpened = function(panel)
            panel.Menu.Paint = function(self, w, h)
                draw.RoundedBox(10, 0, 0, w, h, Color(255, 210, 0))
                draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
            end
            for _, child in pairs(panel.Menu:GetChildren()) do
                if IsValid(child) then
                    for _, c in pairs(child:GetChildren()) do
                        if c.SetTextColor then
                            c:BTB_PaintProperties()
                        end
                    end
                end
            end
        end
        includeExcludeCombo.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, clr.c404040)
        end

        local packType = BATTLEBEATS.musicPacks[selectedPack].packType
        if packType ~= "16thnote" and packType ~= "battlebeats" and packType ~= "local" and packType ~= "playlist" then
            createBasePanel(ui.scrollPanel, 40, 1, 10, function(panel)
                local label1 = vgui.Create("DLabel", panel)
                label1:Dock(TOP)
                label1:SetTall(41)
                label1:SetText("#btb.ps.ts.format")
                label1:SetFont("BattleBeats_Notification_Font_Misc")
                label1:SetTextColor(color_white)
                label1:SetContentAlignment(5)
            end)
        elseif packType == "playlist" then
            createBasePanel(parent, 40, 1, 10, function(panel)
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

        local divider = vgui.Create("DPanel", parent)
        divider:Dock(TOP)
        divider:SetTall(3)
        divider:DockMargin(0, 0, 15, 5)
        divider.Paint = function(self, w, h)
            draw.RoundedBox(1, 0, 0, w, h, clr.c2552100)
        end

        local trackRows = {}
        local noResultsLabel
        local function filterAndSort()
            if not IsValid(activeTextEntries.searchBox) then return end
            local query = string.lower(activeTextEntries.searchBox:GetValue())
            local sortMode = sortCombo:GetOptionData(sortCombo:GetSelectedID()) or "az"

            for _, row in ipairs(trackRows) do row:Remove() end
            trackRows = {}

            if IsValid(noResultsLabel) then
                noResultsLabel:Remove()
            end

            local tracks = {}
            local typesToProcess = isAllMode and {"ambient", "combat"} or {trackType}
            for _, tType in ipairs(typesToProcess) do
                for _, t in ipairs(BATTLEBEATS.musicPacks[selectedPack][tType] or {}) do
                    local name = string.lower(BATTLEBEATS.trackAliases[t] or BATTLEBEATS.FormatTrackName(t))
                    local excluded = BATTLEBEATS.excludedTracks[t]
                    local favorite = BATTLEBEATS.favoriteTracks[t]

                    if query == "" or string.find(name, query, 1, true) then
                        if sortMode == "fav" and not favorite then continue end
                        if sortMode == "ex" and not excluded then continue end
                        if sortMode == "inc" and excluded then continue end

                        table.insert(tracks, {
                            track = t,
                            name = name,
                            fav = favorite,
                            ex = excluded,
                            type = tType
                        })
                    end
                end
            end
            if sortMode == "rnd" then
                for i = #tracks, 2, -1 do
                    local j = math.random(i)
                    tracks[i], tracks[j] = tracks[j], tracks[i]
                end
            else
                if sortMode == "assigned" or sortMode == "offset" or sortMode == "volume" or sortMode == "rename" then
                    local filtered = {}
                    for _, data in ipairs(tracks) do
                        local hasFeature = false

                        if sortMode == "assigned" then
                            hasFeature = BATTLEBEATS.npcTrackMappings[data.track] and
                            #BATTLEBEATS.npcTrackMappings[data.track].npcs > 0
                        elseif sortMode == "offset" then
                            local trim = BATTLEBEATS.trackTrim[data.track]
                            hasFeature = trim and trim.start and trim.start > 0 or
                            (trim and trim.finish and trim.finish > 0)
                        elseif sortMode == "volume" then
                            hasFeature = BATTLEBEATS.trackVolume[data.track]
                        elseif sortMode == "rename" then
                            hasFeature = BATTLEBEATS.trackAliases[data.track] ~= nil
                        end

                        if hasFeature then
                            table.insert(filtered, data)
                        end
                    end
                    tracks = filtered
                end
                if sortMode ~= "playlist" then
                    table.sort(tracks, function(a, b)
                        if a.fav and not b.fav then return true end
                        if not a.fav and b.fav then return false end

                        if sortMode == "az" or sortMode == "fav" or sortMode == "ex" or sortMode == "inc" or sortMode == "assigned" or sortMode == "offset" or sortMode == "volume" or sortMode == "rename" then
                            return a.name < b.name
                        elseif sortMode == "za" then
                            return a.name > b.name
                        end
                        return false
                    end)
                end
            end

            currentFilteredTracks = {}
            if #tracks == 0 then
                noResultsLabel = vgui.Create("DLabel", parent)
                noResultsLabel:SetSize(0, 50)
                noResultsLabel:Dock(TOP)
                noResultsLabel:DockMargin(0, 5, 0, 0)
                noResultsLabel:SetText("#btb.ps.sort.nothing_found")
                noResultsLabel:SetFont("BattleBeats_Font")
                noResultsLabel:SetTextColor(Color(255, 80, 80))
                noResultsLabel:SetContentAlignment(5)
                noResultsLabel.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(40, 20, 20, 200))
                end
            else
                for _, data in ipairs(tracks) do
                    local row = addTrackRow(data.track, data.ex, data.fav, data.type)
                    table.insert(trackRows, row)
                    table.insert(currentFilteredTracks, data.track)
                end
            end
            allRows = ui.scrollPanel:GetCanvas():GetChildren()
        end

        includeExcludeCombo.OnSelect = function(_, _, value)
            if value == "#btb.ps.sort.options_include" then
                for _, t in ipairs(currentFilteredTracks or {}) do
                    BATTLEBEATS.excludedTracks[t] = false
                end
            elseif value == "#btb.ps.sort.options_exclude" then
                for _, t in ipairs(currentFilteredTracks or {}) do
                    BATTLEBEATS.excludedTracks[t] = true
                end
            end
            includeExcludeCombo:SetValue("#btb.ps.sort.options")
            filterAndSort()
        end

        activeTextEntries.searchBox.OnChange = function() timer.Create("BattleBeats_SearchDelay", 0.3, 1, filterAndSort) end
        sortCombo.OnSelect = function()
            selectedSorting = sortCombo:GetSelectedID()
            selectedText = sortCombo:GetOptionText(selectedSorting)
            filterAndSort()
        end
        ui.scrollPanel:ScrollToChild(searchPanel)
        filterAndSort()
    end

    --MARK:Main UI list

    ui.currentFilter = "packages"
    ui.verifyButton = nil
    ui.isTrackSelectorOpen = false
    local function showPackList()
        local debugMode = GetConVar("battlebeats_debug_mode"):GetBool()
        ui.scrollPanel:Clear()
        ui.scrollPanel:SetVisible(true)
        ui.isTrackSelectorOpen = false
        ui.saveButton:SetVisible(true)
        if IsValid(ui.verifyButton) then ui.verifyButton:SetVisible(true) end
        ui.scrollBar:SetWide(0)
        ui.frameTitle:SetText("#btb.ps.title")
        ui.createPlaylistBtn:SetVisible(ui.currentFilter == "playlists")

        local btnPanel = vgui.Create("DPanel", ui.scrollPanel)
        btnPanel:Dock(TOP)
        btnPanel:SetTall(40)
        btnPanel.Paint = function () end
        local packagesBtn = vgui.Create("DButton", btnPanel)
        packagesBtn:Dock(LEFT)
        packagesBtn:SetWide(500)
        packagesBtn:SetText("Packages")
        local playlistsBtn = vgui.Create("DButton", btnPanel)
        playlistsBtn:Dock(RIGHT)
        playlistsBtn:SetWide(500)
        playlistsBtn:SetText("Playlists")
        if debugMode then 
            playlistsBtn:SetEnabled(false)
            packagesBtn:SetEnabled(false)
        else
            playlistsBtn:SetEnabled(true)
            packagesBtn:SetEnabled(true)
        end
        styleTabButton(packagesBtn, "packages", ui.currentFilter)
        styleTabButton(playlistsBtn, "playlists", ui.currentFilter)
        packagesBtn.DoClick = function()
            surface.PlaySound(btbClickSnd)
            ui.currentFilter = "packages"
            RefreshList()
        end
        playlistsBtn.DoClick = function()
            surface.PlaySound(btbClickSnd)
            ui.currentFilter = "playlists"
            RefreshList()
        end
        showConflicts(ui)

        local function createTrackEditor(trackType, packName, scrollPanel, frame)
            scrollPanel:Clear()
            scrollPanel:SetVisible(true)
            ui.isTrackSelectorOpen = true
            ui.saveButton:SetVisible(false)
            ui.createPlaylistBtn:SetVisible(false)
            if IsValid(ui.verifyButton) then ui.verifyButton:SetVisible(false) end
            ui.scrollBar:SetWide(10)
            ui.frameTitle:SetText(BATTLEBEATS.stripPackPrefix(packName))
            if IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() ~= GMOD_CHANNEL_STOPPED then
                playerPanel:SetVisible(true)
                scrollPanel:SetSize(980, 410)
            end

            local backButton = vgui.Create("DButton", frame)
            backButton:SetSize(290, 40)
            backButton:SetPos(350, 650)
            backButton:SetText("#btb.ps.button.back")
            backButton:SetFont("CreditsText")
            backButton:SetTextColor(color_white)
            backButton:BTB_SetButton(clr.c2552100, clr.c707070255, clr.c808080255)
            backButton.DoClick = function()
                surface.PlaySound(btbClickSnd)
                playerPanel:SetVisible(false)
                scrollPanel:SetSize(980, 580)
                backButton:Remove()
                showPackList()
            end

            createTrackList(scrollPanel, trackType, packName)
        end

        --MARK:No packs found
        if table.IsEmpty(BATTLEBEATS.musicPacks) then
            ui.promoPanel = vgui.Create("DPanel", frame)
            ui.promoPanel:SetSize(850, 400)
            ui.promoPanel:SetPos(80, 150)
            ui.promoPanel.Paint = function(self, w, h)
                draw.RoundedBox(10, 0, 0, w, h, clr.c2552100)
                draw.RoundedBox(9, 1, 1, w - 2, h - 2, clr.c505050)
                draw.SimpleText("#btb.ps.no_packs_found_1", "CloseCaption_Bold", w / 2, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("#btb.ps.no_packs_found_2", "CloseCaption_Bold", w / 2, 365, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            local rbutton = vgui.Create("DButton", ui.promoPanel)
            rbutton:SetSize(75, 30)
            rbutton:SetPos(600, 350)
            rbutton:SetText("")
            rbutton.Paint = nil
            rbutton.DoClick = function()
                gui.OpenURL("https://steamcommunity.com/workshop/filedetails/discussion/3473911205/624436764983085955/")
            end

            local selectedPacks = {}
            local tempTable = table.Copy(packButtons)

            for i = 1, 3 do
                if #tempTable == 0 then break end
                local pack = table.Random(tempTable)
                table.insert(selectedPacks, pack)
                for k, v in ipairs(tempTable) do
                    if v == pack then
                        table.remove(tempTable, k)
                        break
                    end
                end
            end

            for i, pack in ipairs(selectedPacks) do
                local button = vgui.Create("DButton", ui.promoPanel)
                button:SetSize(250, 270)
                button:SetPos(30 + (i - 1) * 270, 60)
                button:SetText("")
                button.Paint = function(self, w, h)
                    local bgColor = self:IsHovered() and clr.c808080255 or clr.c707070255
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                    draw.SimpleText(pack.name, "CreditsText", w / 2, 250, color_white, TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER)
                end
                button.OnCursorEntered = function(self)
                    surface.PlaySound("ui/buttonrollover.wav")
                end
                button.DoClick = function()
                    steamworks.ViewFile(pack.workshop)
                end

                local thumbnail = vgui.Create("DImage", button)
                thumbnail:SetSize(230, 220)
                thumbnail:SetPos(10, 10)
                thumbnail:SetImage(pack.image)
                thumbnail.Paint = function(self, w, h)
                    surface.SetDrawColor(color_white)
                    surface.SetMaterial(self:GetMaterial())
                    surface.DrawTexturedRect(0, 0, w, h)
                    surface.SetDrawColor(0, 0, 0, 200)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                end
            end
        end

        --MARK:Packs found
        local orderedPacks = {}
        for packName, data in pairs(BATTLEBEATS.musicPacks) do
            table.insert(orderedPacks, { name = packName, data = data })
        end

        local function getTypeRank(t)
            return BATTLEBEATS.packOrder[t] or 99
        end

        table.sort(orderedPacks, function(a, b)
            local da = a.data or {}
            local db = b.data or {}

            if GetConVar("battlebeats_debug_mode"):GetBool() then
                local debugA = da.debug and true or false
                local debugB = db.debug and true or false

                if debugA ~= debugB then
                    return debugA and not debugB
                end
            end

            local rankA = getTypeRank(da.packType)
            local rankB = getTypeRank(db.packType)
            if rankA ~= rankB then
                return rankA < rankB
            end
            local nameA = tostring(a.name or ""):lower()
            local nameB = tostring(b.name or ""):lower()
            return nameA < nameB
        end)

        local currentCategory = nil
        local ctets = Color(240, 210, 100, 255)
        local function createCategoryDivider(text)
            local divPanel = vgui.Create("DPanel", ui.scrollPanel)
            divPanel:Dock(TOP)
            divPanel:SetTall(40)
            divPanel:DockMargin(20, 5, 20, 5)
            divPanel.Paint = function(self, w, h)
                local lineY = h / 2
                surface.SetFont("BattleBeats_Font")
                local textW, _ = surface.GetTextSize(text)

                local textStartX = w * 0.15
                local textCenterX = textStartX + textW / 2
                local lineLeftEnd = textStartX - 10
                local lineRightStart = textStartX + textW + 10

                if lineLeftEnd > 0 then
                    draw.RoundedBox(2, 0, lineY, lineLeftEnd - 0, 3, ctets)
                end
                if w > lineRightStart then
                    draw.RoundedBox(2, lineRightStart, lineY, w - lineRightStart, 3, ctets)
                end

                draw.SimpleText(text, "BattleBeats_Font", textCenterX, lineY, ctets, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        if GetConVar("battlebeats_debug_mode"):GetBool() and not hasAnyDebugPack(orderedPacks) then
            createBasePanel(ui.scrollPanel, 40, 1, nil, function(panel)
                local label1 = vgui.Create("DLabel", panel)
                label1:Dock(TOP)
                label1:SetTall(40)
                label1:SetText("#btb.ps.info.reload")
                label1:SetFont("BattleBeats_Notification_Font_Misc")
                label1:SetTextColor(color_white)
                label1:SetContentAlignment(5)
            end)
        end

        function BATTLEBEATS.openTrackList(type, packName)
            if not IsValid(ui.scrollPanel) or not IsValid(frame) then return end
            if type == "ambient" then
                createTrackEditor("ambient", packName, ui.scrollPanel, frame)
            elseif type == "combat" then
                createTrackEditor("combat", packName, ui.scrollPanel, frame)
            elseif type == "all" then
                createTrackEditor("all", packName, ui.scrollPanel, frame)
            end
        end

        packNames = {}
        local allPackPanels = {}
        local visibleCount = 0
        for _, pack in pairs(orderedPacks) do
            if IsValid(BATTLEBEATS.optionsFrame) then continue end
            local packName = pack.name
            local packData = pack.data
            local packType = packData.packType or "na"
            local isPlaylist = packType == "playlist"
            if ui.currentFilter == "playlists" and not isPlaylist then
                continue
            end
            if ui.currentFilter == "packages" and isPlaylist then
                continue
            end
            visibleCount = visibleCount + 1
            if not BATTLEBEATS.checking then
                if packData.debug == true then
                    table.insert(packNames, packName)
                end
            end
            local categoryName
            if debugMode and packData.debug then
                categoryName = BATTLEBEATS.categoryNames.debug
            else
                categoryName = BATTLEBEATS.categoryNames[packType] or "Uncategorized"
            end
            if currentCategory ~= categoryName then
                currentCategory = categoryName
                createCategoryDivider(currentCategory)
            end
            local isErrored = packData.error ~= nil
            local wrapper = ui.scrollPanel:Add("DPanel")
            wrapper:Dock(TOP)
            wrapper:SetTall(80)
            wrapper:DockMargin(5, 0, 5, 8)
            wrapper.Paint = function () end
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
            local targetPanel = override or panel
            if IsValid(targetPanel) then
                targetPanel.OnMouseReleased = function(self, keyCode)
                    if keyCode == MOUSE_RIGHT then
                        if not packData then return end
                        local menu = DermaMenu()
                        panelMenu = menu
                        menu.packPanel = panel
                        if not isPlaylist then -- temporary disabled for playlists
                        local vol = (BATTLEBEATS.packVolume[packName] ~= nil and (BATTLEBEATS.packVolume[packName] - 100)) or 0
                        local optionName
                        if vol ~= 0 then
                            local opTrans = language.GetPhrase("btb.ps.pack_rmb.edit_volume")
                            optionName = opTrans .. " [" .. vol .. "%]"
                        else
                            optionName = "#btb.ps.pack_rmb.set_volume"
                        end
                        local volumeOption = menu:AddOption(optionName, function()
                            BATTLEBEATS.openVolumeEditor(frame, nil, packName)
                        end)
                        volumeOption:SetImage("icon16/sound.png")
                        volumeOption:BTB_PaintProperties()
                        volumeOption.packPanel = panel
                        end
                        if isPlaylist then
                            local editPlaylist = menu:AddOption("#btb.playlist.edit", function()
                                BATTLEBEATS.openPlaylistEditor(packName, function()
                                    RefreshList()
                                end)
                            end)
                            editPlaylist:SetImage("icon16/layout_edit.png")
                            editPlaylist:BTB_PaintProperties()
                            editPlaylist.packPanel = panel
                            local deletePlaylist = menu:AddOption("#btb.playlist.delete", function()
                                Derma_Query("#btb.playlist.delete_conf", "#btb.playlist.delete", "#btb.playlist.delete_button", function()
                                        BATTLEBEATS.musicPlaylists[packName] = nil
                                        BATTLEBEATS.musicPacks[packName] = nil
                                        BATTLEBEATS.packVolume[packName] = nil
                                        BATTLEBEATS.SavePlaylists()
                                        RefreshList()
                                        surface.PlaySound("buttons/button15.wav")
                                        ui.changesMade = true
                                    end, "#btb.main.volume_cancel", function()
                                        surface.PlaySound("buttons/button10.wav")
                                    end
                                )
                            end)
                            deletePlaylist:SetImage("icon16/layout_delete.png")
                            deletePlaylist:BTB_PaintProperties()
                            deletePlaylist.packPanel = panel
                            local exportPlaylist = menu:AddOption("#btb.playlist.export", function()
                                SetClipboardText(BATTLEBEATS.exportPlaylist(packName))
                                surface.PlaySound("buttons/button14.wav")
                                notification.AddLegacy("#btb.playlist.export_noti", NOTIFY_GENERIC, 3)
                            end)
                            exportPlaylist:SetImage("icon16/group_go.png")
                            exportPlaylist:BTB_PaintProperties()
                            exportPlaylist:SetTooltip("#btb.playlist.export_tip")
                            exportPlaylist:SetTooltipPanelOverride("BattleBeatsTooltip")
                            exportPlaylist.packPanel = panel
                        end
                        if not isPlaylist then
                        local copyOption = menu:AddOption("#btb.ps.pack_rmb.copy", function()
                            local function formatList(tracks)
                                table.sort(tracks)
                                local lines = {}
                                for _, track in ipairs(tracks) do
                                    local name = BATTLEBEATS.FormatTrackName(track)
                                    table.insert(lines, "[*] " .. name)
                                end
                                return "[olist]\n" .. table.concat(lines, "\n") .. "\n[/olist]"
                            end

                            local parts = {}
                            if packData.ambient and #packData.ambient > 0 then
                                table.insert(parts, "[h2]Ambient:[/h2]\n" .. formatList(packData.ambient))
                            end
                            if packData.combat and #packData.combat > 0 then
                                table.insert(parts, "[h2]Combat:[/h2]\n" .. formatList(packData.combat))
                            end

                            local finalText = table.concat(parts, "\n\n")

                            SetClipboardText(finalText)
                            surface.PlaySound("buttons/button14.wav")
                            notification.AddLegacy("#btb.ps.pack_rmb.copy_noti", NOTIFY_GENERIC, 3)
                        end)
                        copyOption:SetIcon("icon16/page_copy.png")
                        copyOption:SetTooltip("#btb.ps.pack_rmb.copy_tip")
                        copyOption:SetTooltipPanelOverride("BattleBeatsTooltip")
                        copyOption:BTB_PaintProperties()
                        copyOption.packPanel = panel
                        end
                        if packData.wsid then
                            local wsOption = menu:AddOption("#btb.ps.pack_rmb.open_workshop", function()
                                steamworks.ViewFile(packData.wsid)
                            end)
                            wsOption:SetIcon("icon16/world_go.png")
                            wsOption:BTB_PaintProperties()
                            wsOption.packPanel = panel
                        end
                        menu:Open()
                        menu.Paint = function(self, w, h)
                            draw.RoundedBox(10, 0, 0, w, h, Color(255, 210, 0))
                            draw.RoundedBox(9, 1, 1, w - 2, h - 2, Color(50, 50, 50))
                        end
                        return
                    end

                    if checking and not (debugMode and not packData.debug) then
                        notification.AddLegacy("#btb.ps.noti.cant_edit_ver", NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button10.wav")
                        return
                    elseif isErrored then
                        notification.AddLegacy("#btb.ps.noti.cant_edit_error", NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button10.wav")
                        return
                    elseif debugMode and not packData.debug then
                        notification.AddLegacy("#btb.ps.noti.cant_edit_debug", NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button10.wav")
                        return
                    end
                    ui.scrollPanel:ScrollToChild(panel)
                end
            end
            if override then
                local ok = true
                if not IsValid(override) then
                    print("[BattleBeats] Hook returned invalid panel for pack:", packName)
                    ok = false
                end
                if ok and override.fadeTargets == nil then
                    print("[BattleBeats] Missing field 'fadeTargets' in hook panel:", packName)
                    ok = false
                end
                if ok then
                    table.insert(allPackPanels, override)
                    continue
                else
                    print("[BattleBeats] Hook panel rejected:", packName)
                end
            end
            panel:SetSize(900, 80)
            table.insert(allPackPanels, panel)
            local currentColor = BATTLEBEATS.currentPacks[packName] and clr.c2552100 or clr.c25500
            local targetColor = currentColor
            local customCheckbox = vgui.Create("DButton", panel)
            customCheckbox:SetText("")
            customCheckbox.packText = BATTLEBEATS.currentPacks[packName] and "#btb.ps.pack_enabled" or "#btb.ps.pack_disabled"
            customCheckbox:SetVisible(false)
            customCheckbox.packPanel = panel
            createButtons(panel, packName, packData)
            if not isPlaylist and packType ~= "local" then
                BATTLEBEATS.createInfoPanel(panel, packData, function(sizeP, dateP, authorP)
                    if IsValid(sizeP) then sizeP.packPanel = panel end
                    if IsValid(dateP) then dateP.packPanel = panel end
                    if IsValid(authorP) then authorP.packPanel = panel end
                end)
            end
            panel.ambientButton.packPanel = panel
            panel.allButton.packPanel = panel
            panel.combatButton.packPanel = panel
            
            local function createError()
                local errorIcon = vgui.Create("DImage", panel)
                errorIcon.packPanel = panel
                errorIcon:SetPos(840, 28)
                errorIcon:SetSize(24, 24)
                errorIcon:SetImage("icon16/exclamation.png")
                local errorMessage = packData.error or "#btb.ps.unknown_error"
                errorIcon:SetTooltip("Pack error: " .. tostring(errorMessage))
                errorIcon.OnCursorEntered = function(self)
                    self:SetTooltip("Pack error: " .. tostring(errorMessage))
                end
                errorIcon:SetTooltipPanelOverride("BattleBeatsTooltip")
                errorIcon:SetMouseInputEnabled(true)
                errorIcon:SetVisible(true)
                if IsValid(customCheckbox) then
                    customCheckbox.DoClick = nil
                end
                currentColor = Color(100, 0, 0)
                targetColor = currentColor
            end

            if not debugMode and not isPlaylist and customPackPanels:GetBool() then
                hook.Run("BattleBeats_ModifyPackPanel", panel, packName, packData)
            end
            panel.currentColor = clr.cHover
            panel.targetColor = clr.cHover
            panel.initialized = false
            panel.isExpanded = false
            panel.isCollapsed = false
            panel.fadeTargets = {
                customCheckbox,
                panel.ambientButton,
                panel.allButton,
                panel.combatButton
            }
            panel.Think = function(self)
                if packData.verifying then return end
                local target
                if isErrored then
                    target = clr.cpanelerror
                else
                    if packData.debug == true then
                        target = self.isExpanded and clr.cdebughover or clr.cdebugunselected
                    elseif packData.packType == "local" then
                        target = self.isExpanded and clr.clocalhover or clr.clocalunselected
                    else
                        target = self.isExpanded and (self.customHoverColor or clr.cHover2) or (self.customColor or clr.cHover)
                    end
                end

                self.targetColor = target
                if not self.initialized then
                    self.initialized = true
                    self.currentColor = target
                    return
                end
                self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, target)
            end

            local barWidth = 300
            panel.CreateErrorCalled = false
            panel.Paint = function(self, w, h)
                if packData.verifying then
                    local offset = (CurTime() * 200 * 5) % (w + 200)
                    local barX = offset - barWidth
                    local vColor = isErrored and clr.cvererror or clr.cver

                    draw.RoundedBox(12, 0, 0, w, h, Color(vColor.r, vColor.g, vColor.b, 60))

                    surface.SetTexture(gradRight)
                    surface.SetDrawColor(vColor.r, vColor.g, vColor.b, 200)
                    surface.DrawTexturedRect(barX, 0, barWidth / 2, h)
                    surface.SetTexture(gradLeft)
                    surface.DrawTexturedRect(barX + barWidth / 2, 0, barWidth / 2, h)

                    local loopX = barX - (w + barWidth)
                    surface.SetTexture(gradRight)
                    surface.DrawTexturedRect(loopX, 0, barWidth / 2, h)
                    surface.SetTexture(gradLeft)
                    surface.DrawTexturedRect(loopX + barWidth / 2, 0, barWidth / 2, h)

                    isErrored = packData.error ~= nil
                    if isErrored and not self.CreateErrorCalled then
                        self.CreateErrorCalled = true
                        createError()
                    end
                    return
                elseif debugMode and not packData.debug then
                    draw.RoundedBox(12, 0, 0, w, h, Color(10, 10, 10, 200))
                    return
                end
                draw.RoundedBox(12, 0, 0, w, h, self.currentColor)
                if BATTLEBEATS.currentPacks[packName] then
                    BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, clr.c2552100)
                else
                    BATTLEBEATS.drawRoundedOutline(12, 0, 0, w, h, 1, clr.c25500)
                end
            end

            panel.OnCursorEntered = function(self)
                if packData.verifying then
                    self:SetCursor("hourglass")
                elseif isErrored or (debugMode and not packData.debug) then
                    self:SetCursor("no")
                end
            end
            panel.OnCursorExited = function(self)
                self:SetCursor("arrow")
            end

            local packLabel = vgui.Create("DPanel", panel)
            packLabel.packPanel = panel
            packLabel:SetPos(10, 5)
            packLabel:SetSize(800, 80)
            packLabel:SetPaintBackground(false)
            packLabel:SetMouseInputEnabled(false)
            packLabel:SetKeyboardInputEnabled(false)

            local formattedName = BATTLEBEATS.stripPackPrefix(packName)
            local iconMat = BATTLEBEATS.packIcons[packData.packType] or BATTLEBEATS.packIcons["na"]
            formattedName = panel.customTitle or formattedName
            iconMat = panel.customIcon and Material(panel.customIcon) or iconMat
            local cFont = panel.customFont or "BattleBeats_Font"

            packLabel.Paint = function()
                if packData.verifying then
                    surface.SetMaterial(verMat)
                    surface.SetDrawColor(255, 255, 255, 150)
                    surface.DrawTexturedRect(0, 2, 65, 65)
                    draw.SimpleText(formattedName, "BattleBeats_Font", 80, 35, clr.cvertext, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    return
                elseif debugMode and not packData.debug then
                    surface.SetMaterial(blockMat)
                    surface.SetDrawColor(255, 255, 255, 150)
                    surface.DrawTexturedRect(0, 2, 65, 65)
                    draw.SimpleText(formattedName, "BattleBeats_Font", 80, 35, clr.cvertext, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    return
                end
                if packData.packType == "local" then
                    surface.SetMaterial(locMat)
                else
                    surface.SetMaterial(iconMat)
                end
                surface.SetDrawColor(color_white)
                surface.DrawTexturedRect(0, 2, 65, 65)
                draw.SimpleTextOutlined(formattedName, cFont, 80, 35, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, clr.c000200)
            end

            customCheckbox:SetSize(90, 30)
            customCheckbox:SetPos(840, 25)
            customCheckbox.OnCursorEntered = function(self)
                if not isErrored and not packData.verifying and not debugMode then
                    self:SetCursor("hand")
                elseif isErrored or packData.verifying or debugMode then
                    self:SetCursor("no")
                end
            end

            if not isErrored then
                customCheckbox.DoClick = function(self)
                    if debugMode then
                        notification.AddLegacy("#btb.ps.noti.cant_toggle", NOTIFY_ERROR, 3)
                        surface.PlaySound("buttons/button10.wav")
                        return
                    end
                    ui.changesMade = true
                    if BATTLEBEATS.currentPacks[packName] then
                        BATTLEBEATS.currentPacks[packName] = nil
                        surface.PlaySound("btb_button_disable.mp3")
                        self:BTB_UpdatePackButton(customCheckbox, "disabled")
                    else
                        BATTLEBEATS.currentPacks[packName] = true
                        surface.PlaySound("btb_button_enable.mp3")
                        self:BTB_UpdatePackButton(customCheckbox, "enabled")
                    end
                end
            end

            if isErrored then
                createError()
            end

            customCheckbox:BTB_SetPackButton(targetColor, Color(targetColor.r + 50, targetColor.g + 50, targetColor.b + 50))
            customCheckbox.Think = function(self)
                if debugMode and not isErrored then
                    self:BTB_UpdatePackButton(customCheckbox, "debug")
                end
            end
        end

        if visibleCount == 0 then
            local label = ui.scrollPanel:Add("DLabel")
            label:Dock(TOP)
            if ui.currentFilter == "packages" then
                label:SetText("#btb.ps.no_packs")
            else
                label:SetText("#btb.ps.no_packs_playlist")
            end
            label:SetFont("BattleBeats_Font")
            label:SetTall(50)
            label:SetContentAlignment(5)
            label:DockMargin(0, 55, 0, 0)
        end

        function RefreshList()
            if not IsValid(frame) then return end
            if ui.isTrackSelectorOpen then return end
            showPackList()
        end

        function OpenOptions()
            if IsValid(BATTLEBEATS.optionsFrame) then return end
            BATTLEBEATS.createOptions(frame)
            RefreshList()
            if IsValid(ui.createPlaylistBtn) then ui.createPlaylistBtn:SetVisible(false) end
            if IsValid(playerPanel) then playerPanel:SetVisible(false) end
            if IsValid(ui.promoPanel) then ui.promoPanel:SetVisible(false) end
            if IsValid(ui.verifyButton) then ui.verifyButton:SetVisible(false) end
            local lasttext = ui.frameTitle:GetText()
            ui.frameTitle:SetText("#btb.ps.options.title")
            ui.saveButton:SetVisible(false)
            ui.scrollPanel:SetVisible(false)
            local backButton = vgui.Create("DButton", frame)
            backButton:SetSize(290, 40)
            backButton:SetPos(350, 650)
            backButton:SetText("#btb.ps.button.back")
            backButton:SetFont("CreditsText")
            backButton:SetTextColor(color_white)
            backButton:BTB_SetButton(clr.c2552100, clr.c707070255, clr.c808080255)
            backButton.DoClick = function()
                ui.frameTitle:SetText(lasttext)
                if IsValid(ui.verifyButton) and not ui.isTrackSelectorOpen then ui.verifyButton:SetVisible(true) end
                if IsValid(ui.promoPanel) then ui.promoPanel:SetVisible(true) end
                if IsValid(ui.createPlaylistBtn) and not ui.isTrackSelectorOpen then ui.createPlaylistBtn:SetVisible(true) end
                if IsValid(playerPanel) and ui.isTrackSelectorOpen and IsValid(BATTLEBEATS.currentPreviewStation) then playerPanel:SetVisible(true) end
                if IsValid(BATTLEBEATS.optionsFrame) then BATTLEBEATS.optionsFrame:Remove() end
                ui.scrollPanel:SetVisible(true)
                surface.PlaySound(btbClickSnd)
                ui.saveButton:SetVisible(true)
                RefreshList()
                backButton:Remove()
            end
        end

        frame.OnMousePressed = function(self)
            local _, screenY = self:LocalToScreen(0, 0)
            if self:GetDraggable() and gui.MouseY() < (screenY + 38) then
                self.Dragging = { gui.MouseX() - self.x, gui.MouseY() - self.y }
                self:MouseCapture(true)
                return
            end
        end
        frame.Think = function(self)
            local mousex = math.Clamp(gui.MouseX(), 1, ScrW() - 1)
            local mousey = math.Clamp(gui.MouseY(), 1, ScrH() - 1)
            local _, screenY = self:LocalToScreen(0, 0)
            if self.Dragging then
                local x = mousex - self.Dragging[1]
                local y = mousey - self.Dragging[2]
                if self:GetScreenLock() then
                    x = math.Clamp(x, 0, ScrW() - self:GetWide())
                    y = math.Clamp(y, 0, ScrH() - self:GetTall())
                end
                self:SetPos(x, y)
            end
            if self.Hovered and self:GetDraggable() and mousey < (screenY + 37) then
                self:SetCursor("sizeall")
            else
                self:SetCursor("arrow")
            end
            if self.y < 0 then
                self:SetPos(self.x, 0)
            end
            if ui.isTrackSelectorOpen then return end
            local ft = FrameTime()
            local hoveredPanel = vgui.GetHoveredPanel()
            local hovered = hoveredPanel and hoveredPanel.packPanel

            if hovered ~= self.lastHovered then
                self.lastHovered = hovered

                if panelMenu and IsValid(panelMenu) then
                    panelMenu:Remove()
                    panelMenu = nil
                end

                for _, p in ipairs(allPackPanels) do
                    p.isExpanded = (p == hovered)
                    p.isCollapsed = hovered ~= nil
                    for _, v in ipairs(p.fadeTargets) do
                        if IsValid(v) then
                            v:Stop()

                            if (debugMode and not p.packData.debug) or p.packData.verifying or p.packData.error then
                                v:SetVisible(false)
                                continue
                            end

                            if p == hovered then
                                v:SetVisible(true)
                                v:AlphaTo(255, 0.15, 0)
                            else
                                v:AlphaTo(0, 0.15, 0, function()
                                    if IsValid(v) then
                                        v:SetVisible(false)
                                    end
                                end)
                            end
                        end
                    end
                end
            end

            for _, p in ipairs(allPackPanels) do
                local tw, th

                if p == hovered then
                    if p.packData.packType ~= "playlist" and p.packData.packType ~= "local" then
                        tw, th = 950, 165
                    else
                        tw, th = 950, 130
                    end
                elseif hovered then
                    tw, th = 850, 80
                else
                    tw, th = 900, 80
                end

                p.curWidth  = Lerp(ft * 12, p.curWidth or 900, tw)
                p.curHeight = Lerp(ft * 6, p.curHeight or 80, th)

                local w = p.curWidth
                local h = p.curHeight
                if p.packData.error or (debugMode and not p.packData.debug) or p.packData.verifying then
                    w, h = 900, 80
                end
                p:SetSize(w, h)
                p.wrapper:SetTall(h)
                p:CenterHorizontal(0.5)
            end
        end

        --MARK: Verify button
        if GetConVar("battlebeats_debug_mode"):GetBool() and hasAnyDebugPack(orderedPacks) then
            ui.verifyButton = vgui.Create("DButton", frame)
            ui.verifyButton:SetSize(200, 20)
            ui.verifyButton:SetPos(650, 10)
            ui.verifyButton:SetText("Verify Packs")
            ui.verifyButton:SetFont("CreditsText")
            ui.verifyButton:SetTextColor(color_white)
            ui.verifyButton.currentColor = clr.c707070255
            ui.verifyButton.targetColor = clr.c707070255
            ui.verifyButton.Think = function(self)
                if BATTLEBEATS.checking then
                    self.targetColor = clr.c505050
                elseif self:IsHovered() then
                    self.targetColor = clr.c200200200
                else
                    self.targetColor = clr.c100100100
                end
                self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
            end
            ui.verifyButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, self.currentColor)
            end
            ui.verifyButton.DoClick = function(self)
                if #packNames > 0 and not BATTLEBEATS.checking then
                    MsgC(Color(255, 255, 0), "[BattleBeats Debug] ", color_white, "Starting verification...\n")
                    ui.verifyButton:SetCursor("no")
                    ui.verifyButton:SetText("Verifying...")
                    ui.verifyButton:InvalidateLayout()
                    validateTracksInPack(packNames[currentPackIndex], function()
                        ui.verifyButton:SetCursor("hand")
                        ui.verifyButton:SetText("Verify Packs")
                    end)
                end
            end
        end
    end

    showPackList()

    ui.saveButton.DoClick = function()
        frame:Close()
    end

    local oldClose = frame.Close
    frame.Close = function(self)
        if self.Closing then return end
        self.Closing = true
        self:AlphaTo(0, 0.04, 0, function()
            oldClose(self)
        end)
        if BATTLEBEATS.checking and timer.Exists("BattleBeats_VerifyTimer") then
            timer.Remove("BattleBeats_VerifyTimer")
            MsgC(Color(255, 255, 0), "[BattleBeats Debug] ", color_white, "Pack verification", Color(255, 0, 0), " CANCELED!")
            notification.AddLegacy("[BattleBeats] " .. language.GetPhrase("btb.ps.verification.cancel"), NOTIFY_ERROR, 4)
            surface.PlaySound("buttons/button8.wav")
            for _, pack in pairs(BATTLEBEATS.musicPacks) do
                pack.verifying = false
            end
            errorCount = 0
            checking = false
            BATTLEBEATS.checking = false
            currentPackIndex = 1
        end
    end

    frame.OnClose = function()
        BATTLEBEATS.ValidatePacks()
        if IsValid(BATTLEBEATS.optionsFrame) then BATTLEBEATS.optionsFrame:Remove() end
        if timer.Exists("BattleBeats_NextPreviewTrack") then
            timer.Remove("BattleBeats_NextPreviewTrack")
        end
        if BATTLEBEATS.currentPreviewStation and IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() == GMOD_CHANNEL_PLAYING then
            if not persistentNotification:GetBool() then BATTLEBEATS.HideNotification() end
            -- play the previewed track as the main track, resuming from current playback time, no fade
            BATTLEBEATS.PlayNextTrack(BATTLEBEATS.currentPreviewTrack, BATTLEBEATS.currentPreviewStation:GetTime(), 0)
            timer.Simple(0.05, function()
                BATTLEBEATS.currentPreviewStation:Stop()
            end)
        else
            surface.PlaySound("btb_ui_exit.mp3")
        end
        if ui.changesMade then
            -- if no preview track is playing, start a random track from selected packs
            if BATTLEBEATS.currentPreviewTrack == nil or (IsValid(BATTLEBEATS.currentPreviewStation) and BATTLEBEATS.currentPreviewStation:GetState() ~= GMOD_CHANNEL_PLAYING) then
                local nextTrack = BATTLEBEATS.GetRandomTrack(BATTLEBEATS.currentPacks, BATTLEBEATS.isInCombat, BATTLEBEATS.excludedTracks)
                if nextTrack then
                    BATTLEBEATS.PlayNextTrack(nextTrack)
                end
            end
            BATTLEBEATS.currentPreviewTrack = nil
        end
        local jsonPacks = util.TableToJSON(BATTLEBEATS.currentPacks)
        cookie.Set("battlebeats_selected_packs", jsonPacks)
        if table.IsEmpty(BATTLEBEATS.currentPacks) and IsValid(BATTLEBEATS.currentStation) then
            BATTLEBEATS.FadeMusic(BATTLEBEATS.currentStation)
            BATTLEBEATS.HideNotification()
        end
    end
end

cvars.AddChangeCallback("battlebeats_volume", function(_, _, newValue)
    if IsValid(volumePanel) then
        volumePanel.progress = tonumber(newValue) / 200
        UpdateDot(volumePanel.progress)
    end
end)

hook.Add("OnContextMenuOpen", "BattleBeats_OpenUI", function()
    if IsValid(frame) and not frame.isMinimalized then
        frame:SetVisible(true)
    end
end)

local function isAnyTextEntryEditing()
    activeTextEntries.plNameBox = BATTLEBEATS.plNameBox
    activeTextEntries.importBox = BATTLEBEATS.importBox
    for _, pnl in pairs(activeTextEntries) do
        if IsValid(pnl) and pnl:IsEditing() then
            return true
        end
    end
    return false
end

hook.Add("OnContextMenuClose", "BattleBeats_HideUI", function()
    if isAnyTextEntryEditing() then return end
    if IsValid(frame) and not toogleFrame:GetBool() then
        frame:SetVisible(false)
    end
end)

list.Set("DesktopWindows", "BattleBeatsContextMenu", {
    title = "BattleBeats",
    icon = "packicons/btb.png",
    init = function()
        if IsValid(frame) and not frame:IsVisible() then
            frame:SetVisible(true)
            frame.isMinimalized = false
        end
        if not IsValid(frame) then openBTBmenu() end
    end
})

concommand.Add("battlebeats_menu", function()
    if IsValid(frame) and not frame:IsVisible() then
        frame:SetVisible(true)
        frame.isMinimalized = false
    end
    if not IsValid(frame) then openBTBmenu() end
end)