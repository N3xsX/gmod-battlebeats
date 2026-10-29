local btb = BATTLEBEATS

local shared = btb.uiShared
local LerpColor = shared.LerpColor
local ColA = shared.ColA
local animHover = shared.animHover

local C = shared.Colors
local TL, TC, TR, TT = TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
local L = language.GetPhrase

local function sendCvar(name, value, sv)
    if sv then
        net.Start("BTB_Change_ConVar")
        net.WriteString(name)
        net.WriteFloat(tonumber(value) or 0)
        net.SendToServer()
    else
        RunConsoleCommand(name, tostring(value))
    end
end

local function makeTip(helpText, defaultPart)
    local defLabel = L("btb.options.noti.default_pos")
    return L(helpText) .. "\n" .. "|" .. defLabel .. "<200,200,50>|" .. defaultPart
end

local helpPanel
hook.Add("PostRenderVGUI", "BTB_HelpCursor", function()
    if not IsValid(helpPanel) then
        helpPanel = nil
        return
    end
    local x, y = input.GetCursorPos()
    draw.SimpleTextOutlined("?", "DermaLarge", x + 14, y + 10, color_white, TL, TT, 1, color_black)
end)

local function helpCursor(p)
    local oldEnter, oldExit = p.OnCursorEntered, p.OnCursorExited
    p.OnCursorEntered = function(self)
        helpPanel = self
        if oldEnter then oldEnter(self) end
    end
    p.OnCursorExited = function(self)
        if helpPanel == self then helpPanel = nil end
        if oldExit then oldExit(self) end
    end
end

local function applyTip(tip, img, ...)
    for _, p in ipairs({ ... }) do
        if img then
            p:BTB_SetImageTooltip(img, tip)
        else
            p:SetTooltip(tip)
            p:SetTooltipPanelOverride("BattleBeatsTooltip")
        end
        helpCursor(p)
    end
end

local function handCursor(...)
    for _, p in ipairs({ ... }) do
        local oldEnter, oldExit = p.OnCursorEntered, p.OnCursorExited
        p.OnCursorEntered = function(self)
            self:SetCursor("hand")
            if oldEnter then oldEnter(self) end
        end
        p.OnCursorExited = function(self)
            self:SetCursor("arrow")
            if oldExit then oldExit(self) end
        end
    end
end

local function valueText(val, suffix)
    if not suffix then return tostring(val) end
    return val .. (suffix == "%" and "" or " ") .. suffix
end

local function getDisabled(o)
    local d = o.disabledIf
    if not d then return false end
    if isfunction(d) then
        local off, reason = d()
        return off and true or false, reason
    end
    local cv = GetConVar(d.cvar)
    if not cv then return false end
    local cur = cv:GetString()
    local match
    if d.not_value ~= nil then
        match = cur ~= tostring(d.not_value)
    else
        match = cur == tostring(d.value)
    end
    return match, d.reason
end

local cDisabledTint = Color(0, 0, 0, 150)
local function applyDisable(panel, o)
    if not o.disabledIf then return end

    local overlay = vgui.Create("DPanel", panel)
    overlay:SetZPos(100)
    overlay:SetPos(0, 0)
    overlay:SetSize(panel:GetSize())
    overlay:SetMouseInputEnabled(false)
    overlay.Anim = 0
    helpCursor(overlay)

    overlay.OnMousePressed = function()
        surface.PlaySound("buttons/button8.wav")
    end

    overlay.Think = function(self)
        local off, reason = getDisabled(o)
        local w, h = panel:GetSize()
        if self:GetWide() ~= w or self:GetTall() ~= h then
            self:SetSize(w, h)
        end

        if off ~= self.WasOff then
            self.WasOff = off
            self:SetMouseInputEnabled(off)
            self:SetCursor(off and "no" or "arrow")
        end

        if off then
            local tip = L(reason or "btb.options.disabled_generic")
            if self.CurTip ~= tip then
                self.CurTip = tip
                self:SetTooltip(tip)
                self:SetTooltipPanelOverride("BattleBeatsTooltip")
            end
        end
    end

    overlay.Paint = function(self, w, h)
        self.Anim = Lerp(FrameTime() * 10, self.Anim, self.WasOff and 1 or 0)
        if self.Anim < 0.01 then return end
        draw.RoundedBox(6, 0, 0, w, h, ColA(cDisabledTint, cDisabledTint.a * self.Anim))
    end
end

local builders = {}
local layoutRows
local c230230230 = Color(230, 230, 230)
builders.toggle = function(parent, o)
    local cvar = GetConVar(o.cvar)
    local isServer = o.server or false

    local panel = vgui.Create("DPanel", parent)
    panel:SetTall(20)
    panel.Paint = nil

    local switch = vgui.Create("DPanel", panel)
    switch:SetSize(40, 20)
    switch.Anim = cvar:GetBool() and 1 or 0

    switch.Paint = function(self, w, h)
        local enabled = cvar:GetBool()
        local target = enabled and 1 or 0

        self.Anim = Lerp(FrameTime() * 10, self.Anim, target)
        if math.abs(self.Anim - target) < 0.002 then self.Anim = target end
        local t = self.Anim

        local hov = animHover(self, "Hov", switch:IsHovered())
        local ks = 16 + hov * 2
        local knobX = Lerp(t, 2, w - ks - 2)
        local knobY = (h - ks) / 2

        local track = LerpColor(t, C.C90, C.Yellow)
        draw.RoundedBox(h / 2, 0, 0, w, h, LerpColor(hov * 0.3, track, color_white))
        draw.RoundedBox(ks / 2, knobX, knobY + 1, ks, ks, C.Shadow)
        draw.RoundedBox(ks / 2, knobX, knobY, ks, ks, LerpColor(t, c230230230, C.C90))
    end

    switch.OnMousePressed = function()
        if getDisabled(o) then return end
        local enable = not cvar:GetBool()
        surface.PlaySound(enable and "btb_switch_on.mp3" or "btb_switch_off.mp3")
        sendCvar(o.cvar, enable and 1 or 0, isServer)
    end

    local label = vgui.Create("DLabel", panel)
    label:SetText(o.label)
    label:SetFont("DermaDefaultBold")
    label:SetTextColor(color_white)
    label:SizeToContents()
    label:SetPos(40 + 8, (panel:GetTall() - label:GetTall()) / 2)
    label:SetMouseInputEnabled(true)

    if o.tip then
        local on = "||" .. L("btb.ps.pack_enabled") .. "<0,255,50>||"
        local off = "||" .. L("btb.ps.pack_disabled") .. "<220,0,0>||"
        applyTip(makeTip(o.tip, cvar:GetDefault() == "1" and on or off), o.img, label)
    end

    panel:SetWide(40 + 8 + label:GetWide())

    handCursor(switch)
    panel.OnMousePressed = switch.OnMousePressed
    applyDisable(panel, o, switch, label)
    return panel
end

builders.slider = function(parent, o)
    local cvar = GetConVar(o.cvar)
    local min, max, suffix = o.min, o.max, o.suffix
    local isServer = o.server or false
    local stepper = o.arrows or false

    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(300, stepper and 50 or 40)
    panel.Paint = nil

    local label = vgui.Create("DLabel", panel)
    label:SetText(o.label)
    label:SetFont("DermaDefaultBold")
    label:SetPos((300 - 200) / 2, 0)
    label:SetSize(200, 20)
    label:SetTextColor(color_white)
    label:SetContentAlignment(5)
    label:SetMouseInputEnabled(true)
    if o.tip then
        applyTip(makeTip(o.tip, "||" .. cvar:GetDefault() .. (suffix or "") .. "<200,200,200>||"), nil, label)
    end

    local bar = vgui.Create("DPanel", panel)
    if stepper then
        bar:SetSize(240, 8)
        bar:SetPos(30, 25)
    else
        bar:SetSize(300, 12)
        bar:SetPos(0, 25)
    end
    bar.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered() or self.IsDragging)
        local progress = math.Clamp((cvar:GetInt() - min) / (max - min), 0, 1)
        draw.RoundedBox(4, 0, 0, w, h, LerpColor(hov * 0.12, C.C90, color_white))
        draw.RoundedBox(4, 0, 0, w * progress, h, LerpColor(hov * 0.3, C.Yellow, color_white))
        if stepper and hov > 0.01 then
            local x = math.Clamp(w * progress, h / 2, w - h / 2)
            draw.RoundedBox(h / 2, x - h / 2, 0, h, h, ColA(color_white, 255 * hov))
        end
    end

    local lastSent, lastSentAt = nil, 0
    local function sendValue(newVal)
        if getDisabled(o) then return end
        newVal = math.Clamp(math.Round(newVal), min, max)
        if newVal == cvar:GetInt() then return end
        if newVal == lastSent and CurTime() < lastSentAt + 0.5 then return end
        lastSent, lastSentAt = newVal, CurTime()
        sendCvar(o.cvar, newVal, isServer)
    end

    local function valueFromCursor(b)
        local cx = b:CursorPos()
        local progress = math.Clamp(cx / b:GetWide(), 0, 1)
        sendValue(math.floor(min + progress * (max - min)))
    end

    local valueLabel
    if stepper then
        local function addArrow(text, x)
            local btn = vgui.Create("DButton", panel)
            btn:SetText(text)
            btn:SetFont("CreditsText")
            btn:SetTextColor(color_white)
            btn:SetSize(20, 20)
            btn:SetPos(x, 18)
            btn.Paint = function(self, w, h)
                local hov = animHover(self, "Hov", self:IsHovered())
                local col = LerpColor(hov, color_white, C.Yellow)
                if self:IsDown() then col = C.C90 end
                self:SetTextColor(col)
            end
            return btn
        end

        local function setupHoldButton(btn, delta)
            btn.NextRepeat = 0
            btn.HoldStart = 0
            btn.IsHeld = false

            btn.OnMousePressed = function(self, code)
                if code ~= MOUSE_LEFT then return end
                sendValue(cvar:GetInt() + delta)
                self.IsHeld = true
                self.HoldStart = CurTime()
                self.NextRepeat = CurTime() + 0.8
            end

            btn.OnMouseReleased = function(self, code)
                if code ~= MOUSE_LEFT then return end
                self.IsHeld = false
            end

            btn.Think = function(self)
                if not self.IsHeld then return end
                if not input.IsMouseDown(MOUSE_LEFT) then
                    self.IsHeld = false
                    return
                end
                if CurTime() >= self.NextRepeat then
                    sendValue(cvar:GetInt() + delta)
                    local heldTime = CurTime() - self.HoldStart
                    local delay = heldTime < 3 and 0.16 or heldTime < 6 and 0.08 or 0.04
                    self.NextRepeat = CurTime() + delay
                end
            end
        end

        setupHoldButton(addArrow("<", 0), -1)
        setupHoldButton(addArrow(">", 280), 1)

        valueLabel = vgui.Create("DLabel", panel)
        valueLabel:SetSize(40, 20)
        valueLabel:SetPos(130, 32)
        valueLabel:SetTextColor(color_white)
        valueLabel:SetContentAlignment(5)
        valueLabel:SetMouseInputEnabled(true)
        valueLabel.OnMousePressed = function(self, code)
            if code ~= MOUSE_LEFT then return end
            if IsValid(self.Entry) then return end

            local entry = vgui.Create("DTextEntry", panel)
            entry:SetSize(30, 20)
            entry:SetPos(self:GetX() + 5, self:GetY() - 1)
            entry:SetNumeric(true)
            entry:SetMaximumCharCount(string.len(tostring(math.floor(max))))
            entry:SetValue(cvar:GetInt())
            entry:RequestFocus()
            entry:SetCaretPos(string.len(tostring(cvar:GetInt())))
            entry.Paint = function(e, w, h)
                draw.RoundedBox(4, 0, 0, w, h, C.C90)
                e:DrawTextEntryText(color_white, color_white, color_white)
            end

            self:SetVisible(false)
            self.Entry = entry

            local function finish()
                if not IsValid(entry) then return end
                local val = tonumber(entry:GetValue())
                if val then sendValue(val) end
                self:SetVisible(true)
                self.Entry = nil
                entry:Remove()
            end

            entry.OnEnter = finish
            entry.OnLoseFocus = finish
        end
        valueLabel.Paint = function(self)
            self:SetTextColor(LerpColor(animHover(self, "Hov", self:IsHovered()), color_white, C.Yellow))
        end
    else
        panel.PaintOver = function()
            local xx = bar.x + bar:GetWide() / 2
            local yy = bar.y + bar:GetTall() / 2 - 1
            draw.SimpleTextOutlined(valueText(cvar:GetInt(), suffix), "DermaDefaultBold", xx, yy, color_white, TC, TC, 1, C.Outline)
        end
    end

    bar.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        valueFromCursor(self)
        self.IsDragging = true
    end

    bar.Think = function(self)
        if valueLabel then valueLabel:SetText(valueText(cvar:GetInt(), suffix)) end
        if not self.IsDragging then return end
        if input.IsMouseDown(MOUSE_LEFT) then
            valueFromCursor(self)
        else
            self.IsDragging = false
        end
    end

    handCursor(bar)
    applyDisable(panel, o, bar, valueLabel)
    return panel
end

builders.combo = function(parent, o)
    local cvar = GetConVar(o.cvar)
    local options, values = o.options, o.values
    local isServer = o.server or false
    local W, c = 200, 55
    local dropH = math.min(#options, 3) * 30

    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(W, c)
    panel.Paint = nil

    local label = vgui.Create("DLabel", panel)
    label:SetText(o.label)
    label:SetFont("DermaDefaultBold")
    label:SetPos(25, 0)
    label:SetSize(150, 20)
    label:SetTextColor(color_white)
    label:SetContentAlignment(5)
    label:SetMouseInputEnabled(true)

    local isOpen = false
    local combo = vgui.Create("DPanel", panel)
    combo:SetSize(W, 30)
    combo:SetPos(0, 25)
    combo.Paint = function(self, w, h)
        local hov = animHover(self, "Hov", self:IsHovered() or isOpen)
        local open = animHover(self, "Open", isOpen, 14)
        draw.RoundedBox(10, 0, 0, w, h, LerpColor(hov * 0.35, C.Yellow, color_white))
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, LerpColor(hov, C.C90, C.C100))

        local i
        if values then
            local v = cvar:GetString()
            for k, val in ipairs(values) do
                if val == v then
                    i = k
                    break
                end
            end
        else
            i = math.Clamp(cvar:GetInt() + 1, 1, #options)
        end

        draw.SimpleText(options[i or 1] or "Unknown", "DermaDefaultBold", w / 2, h / 2, color_white, TC, TC)

        local ax, ay, s = w - 18, h / 2, 3 * (1 - 2 * open)
        surface.SetDrawColor(255, 255, 255, 120 + 135 * hov)
        surface.DrawLine(ax - 5, ay - s, ax, ay + s)
        surface.DrawLine(ax, ay + s, ax + 5, ay - s)
    end

    local def = cvar:GetDefault()
    local defaultIndex = (values and table.KeyFromValue(values, def)) or ((tonumber(def) or 0) + 1)
    defaultIndex = math.Clamp(defaultIndex, 1, #options)
    applyTip(makeTip(o.tip or "\n", "||" .. (options[defaultIndex] or "Unknown") .. "||"), nil, label)

    handCursor(combo)

    local dropdown = vgui.Create("DPanel", panel)
    dropdown:SetSize(W, 0)
    dropdown:SetPos(0, c)
    dropdown:SetVisible(false)
    dropdown.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, C.C50) end

    local scroll = vgui.Create("DScrollPanel", dropdown)
    scroll:Dock(FILL)
    scroll:SetPaintBackground(false)

    local vbar = scroll:GetVBar()
    vbar:SetWide(6)
    vbar.Paint = function() end
    vbar.btnUp.Paint = function() end
    vbar.btnDown.Paint = function() end
    vbar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, C.C100) end

    local function close()
        isOpen = false
        dropdown:SizeTo(W, 0, 0.15, 0, -1, function()
            if isOpen then return end
            dropdown:SetVisible(false)
            panel:SetTall(c)
        end)
    end

    for i, option in ipairs(options) do
        local btn = scroll:Add("DButton")
        btn:SetText(option)
        btn:SetTextColor(color_white)
        btn:SetTall(30)
        btn:Dock(TOP)
        btn.Paint = function(self, w, h)
            local hov = animHover(self, "Hov", self:IsHovered())
            draw.RoundedBox(4, 0, 0, w, h, LerpColor(hov, C.C50, C.C100))
            draw.RoundedBox(2, 0, h / 2 - 8 * hov, 3, 16 * hov, C.Yellow)
        end

        btn.DoClick = function()
            local value = values and values[i] or tostring(i - 1)
            sendCvar(o.cvar, value, isServer and not values)
            close()
        end
    end

    combo.OnMousePressed = function(self, code)
        if getDisabled(o) then return end
        if code ~= MOUSE_LEFT then return end
        if isOpen then
            close()
            return
        end
        isOpen = true
        panel:SetTall(c + dropH)
        panel:MoveToFront()
        dropdown:SetVisible(true)
        dropdown:SetSize(W, 0)
        dropdown:SizeTo(W, dropH, 0.2, 0, -1)
    end

    applyDisable(panel, o, combo)
    return panel
end

builders.button = function(parent, o)
    local button = vgui.Create("DButton", parent)
    button:SetSize(200, 30)
    button:SetText(o.label)
    button:SetFont("DermaDefaultBold")
    button:SetTextColor(color_white)
    button.Paint = function(self, w, h)
        if getDisabled(o) then draw.RoundedBox(10, 0, 0, w, h, cDisabledTint) end
        local hov = animHover(self, "Hov", self:IsHovered())
        local bg = self:IsDown() and C.C50 or LerpColor(hov, C.C90, C.C100)
        draw.RoundedBox(10, 0, 0, w, h, LerpColor(hov * 0.35, C.Yellow, color_white))
        draw.RoundedBox(9, 1, 1, w - 2, h - 2, bg)
    end

    if o.tip then
        button:SetTooltip(o.tip)
        button:SetTooltipPanelOverride("BattleBeatsTooltip")
    end

    button.DoClick = function()
        if getDisabled(o) then return end
        RunConsoleCommand(o.cmd)
    end

    return button
end

builders.group = function(parent, o)
    local ww = o.w or 480
    local bg = Material("btboptionbg.jpg")

    local holder = vgui.Create("DPanel", parent)
    holder:SetWide(ww)
    holder.Paint = nil

    local title = vgui.Create("DLabel", holder)
    title:SetPos(0, 0)
    title:SetSize(ww, 20)
    title:SetText(o.title or "")
    title:SetContentAlignment(5)
    title:SetFont("DermaDefaultBold")
    title:SetTextColor(color_white)

    local box = vgui.Create("DPanel", holder)
    box:SetPos(0, 25)
    box:SetWide(ww)
    box.Paint = function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(bg)
        surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, 1, 0.5)
    end

    local inner = vgui.Create("DPanel", box)
    inner:SetPos(6, 6)
    inner:SetWide(ww - 12)
    inner.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, C.C50) end

    local bottom = layoutRows(inner, o.rows, 15)
    inner:SetTall(bottom + 15)
    box:SetTall(inner:GetTall() + 12)
    holder:SetTall(25 + box:GetTall())

    return holder
end

local function createWidget(parent, o)
    local builder = builders[o.type]
    if not builder then
        ErrorNoHalt("[BattleBeats] options: unknown widget type '" .. tostring(o.type) .. "'\n")
        return
    end
    if o.cvar and not GetConVar(o.cvar) then
        ErrorNoHalt("[BattleBeats] options: missing convar '" .. o.cvar .. "'\n")
        return
    end
    return builder(parent, o)
end

layoutRows = function(parent, rows, top, areaH)
    local W = parent:GetWide()
    local startY = top or 10
    local y = startY
    local bottom = y
    local created = {}

    for _, entry in ipairs(rows) do
        if entry.type == "space" then
            y = y + (entry.h or 10)
        else
            local items = entry.type and { entry } or entry
            local n = #items
            local colW = entry.colW or (n > 1 and math.min(W / n, 420) or W)
            local x0 = (W - colW * n) / 2
            local rowH = 0

            for i, item in ipairs(items) do
                local p = createWidget(parent, item)
                if p then
                    p:SetPos(x0 + colW * (i - 0.5) - p:GetWide() / 2, y)
                    rowH = math.max(rowH, p:GetTall())
                    created[#created + 1] = p
                end
            end

            if rowH > 0 then
                bottom = y + rowH
                y = bottom + 10
            end
        end
    end

    if areaH then
        local offset = math.floor((areaH - (bottom - startY)) / 2) - startY
        if offset > 0 then
            for _, p in ipairs(created) do
                if IsValid(p) then p:SetY(p:GetY() + offset) end
            end
            bottom = bottom + offset
        end
    end

    return bottom
end

local hoverColor = Color(60, 60, 60, 255)
local normalColor = Color(50, 50, 50, 255)
local activeColor = Color(40, 40, 40, 255)
local blockedColor = Color(30, 30, 30, 255)

local ls = { "Auto", "Original", "Bulgarian (Български)", "Czech (Čeština)", "Danish (Dansk)", "German (Deutsch)",
    "Greek (Ελληνικά)", "English (English)", "Pirate English (Pirate English)", "Spanish (Español)",
    "Estonian (Eesti)", "Finnish (Suomi)", "French (Français)", "Hebrew (עברית)", "Croatian (Hrvatski)",
    "Hungarian (Magyar)", "Italian (Italiano)", "Japanese (日本語)", "Korean (한국어)", "Lithuanian (Lietuvių)",
    "Dutch (Nederlands)", "Norwegian (Norsk)", "Polish (Polski)", "Portuguese (Brazil) (Português do Brasil)",
    "Portuguese (Portugal) (Português)", "Russian (Русский)", "Slovak (Slovenčina)", "Swedish (Svenska)",
    "Thai (ไทย)", "Turkish (Türkçe)", "Ukrainian (Українська)", "Vietnamese (Tiếng Việt)",
    "Chinese Simplified (简体中文)", "Chinese Traditional (繁體中文)" }
local lv = { "auto", "original", "bg", "cs", "da", "de", "el", "en", "en-PT", "es-ES", "et", "fi", "fr", "he", "hr", "hu", "it",
    "ja", "ko", "lt", "nl", "no", "pl", "pt-BR", "pt-PT", "ru", "sk", "sv-SE", "th", "tr", "uk", "vi", "zh-CN",
    "zh-TW" }

local function toggle(label, cvar, tip, img, disabledIf)
    return { type = "toggle", label = label, cvar = cvar, tip = tip, img = img, disabledIf = disabledIf }
end

local function slider(label, cvar, min, max, tip, suffix, disabledIf)
    return { type = "slider", label = label, cvar = cvar, min = min, max = max, tip = tip, suffix = suffix, disabledIf = disabledIf }
end

local function stepper(label, cvar, min, max, tip, suffix, disabledIf)
    return { type = "slider", arrows = true, label = label, cvar = cvar, min = min, max = max, tip = tip, suffix = suffix, disabledIf = disabledIf }
end

local function combo(label, cvar, options, tip, values, disabledIf)
    return { type = "combo", label = label, cvar = cvar, options = options, tip = tip, values = values, disabledIf = disabledIf }
end

local function button(label, cmd, tip, disabledIf)
    return { type = "button", label = label, cmd = cmd, tip = tip, disabledIf = disabledIf }
end

local function group(title, rows)
    return { type = "group", title = title, rows = rows }
end

local function space(h)
    return { type = "space", h = h }
end

local function server(opt)
    opt.server = true
    return opt
end

local function disabledWhen(opt, cvar, value, reason)
    opt.disabledIf = { cvar = cvar, value = value, reason = reason }
    return opt
end

local function buildSpec()
    local scrW, scrH = ScrW(), ScrH()
    local ls2, lv2 = { "None" }, { "" }
    for i = 2, #ls do
        ls2[#ls2 + 1] = ls[i]
        lv2[#lv2 + 1] = lv[i]
    end
    local pvpModeTip = L("#btb.spawnmenu.server.combo_1_tip") .. "\n" .. L("#btb.spawnmenu.server.combo_2_tip") .. "\n" .. L("#btb.spawnmenu.server.combo_3_tip")
    return {
        client = {
            {
                name = L("btb.options.cat.sound"),
                tabs = {
                    {
                        name = L("btb.options.cat.general"),
                        rows = {
                            slider("#btb.options.snd.master_volume", "battlebeats_volume", 0, 200, "#btb.options.snd.master_volume_tip", "%"),
                            slider("#btb.options.snd.ambient_volume", "battlebeats_volume_ambient", 0, 100, nil, "%"),
                            slider("#btb.options.snd.combat_volume", "battlebeats_volume_combat", 0, 100, nil, "%"),
                            toggle("#btb.options.snd.enable_ambient", "battlebeats_enable_ambient"),
                            toggle("#btb.options.snd.enable_combat", "battlebeats_enable_combat"),
                            disabledWhen(toggle("#btb.spawnmenu.general.force_combat", "battlebeats_force_combat", "#btb.spawnmenu.general.force_combat_tip"),
                                "battlebeats_enable_combat", "0", "#btb.options.disabled.enable_combat")
                        }
                    },
                    {
                        name = L("btb.options.tab.advanced"),
                        rows = {
                            toggle("#btb.options.snd.dynamic_volume", "battlebeats_dynamic_volume", "#btb.options.snd.dynamic_volume_tip"),
                            disabledWhen(toggle("#btb.options.snd.dynamic_volume_env", "battlebeats_dynamic_volume_env", "#btb.options.snd.dynamic_volume_env_tip"),
                                "battlebeats_dynamic_volume", "0", "#btb.options.disabled.dynamic_volume"),
                            {
                                colW = 230,
                                combo("#btb.spawnmenu.general.combo", "battlebeats_disable_mode", {"#btb.spawnmenu.general.combo_1", "#btb.spawnmenu.general.combo_2", "#btb.spawnmenu.general.combo_3"}),
                                combo("#btb.options.snd.start_mode", "battlebeats_start_mode", {"#btb.options.snd.start_mode_1", "#btb.options.snd.start_mode_2", "#btb.options.snd.start_mode_3", "#btb.options.snd.start_mode_4"}, "#btb.options.snd.start_mode_tip")
                            },
                        }
                    },
                }
            },
            {
                name = L("btb.options.cat.notification"),
                rows = {
                    {
                        toggle("#btb.options.noti.enable_noti", "battlebeats_show_notification", "#btb.options.noti.enable_noti_tip", "tooltips/shownoti.png"),
                        toggle("#btb.options.noti.noti_always_vis", "battlebeats_persistent_notification", "#btb.options.noti.noti_always_vis_tip")
                    },
                    {
                        toggle("#btb.options.noti.progress_bar", "battlebeats_show_status_bar", "#btb.options.noti.progress_bar_tip", "tooltips/showprog.png"),
                        toggle("#btb.options.noti.replay", "battlebeats_show_notification_after_continue", "#btb.options.noti.replay_tip")
                    },
                    {
                        toggle("#btb.options.noti.show_nombat", "battlebeats_skip_nombat_names", "#btb.options.noti.show_nombat_tip"),
                        toggle("#btb.options.noti.pack_name", "battlebeats_show_notification_pack_name", "#btb.options.noti.pack_name_tip", "tooltips/showname.png")
                    },
                    toggle("#btb.options.noti.preview", "battlebeats_show_preview_notification", "#btb.options.noti.preview_tip", "tooltips/showprev.png"),
                    toggle("#btb.options.noti.visualizer", "battlebeats_show_notification_visualizer", "#btb.options.noti.visualizer_tip", "tooltips/showbars.png"),
                    stepper("#btb.options.noti.x_pos", "battlebeats_notif_x", 0, scrW, "\n"),
                    stepper("#btb.options.noti.y_pos", "battlebeats_notif_y", 0, scrH, "\n"),
                }
            },
            {
                name = L("btb.options.cat.subtitles"),
                rows = {
                    toggle("#btb.options.sub.enable_sub", "battlebeats_subtitles_enabled"),
                    stepper("#btb.options.sub.sub_height", "battlebeats_subtitles_y", 0, scrH, "\n"),
                    toggle("#btb.options.sub.static", "battlebeats_subtitles_static", "#btb.options.sub.static_tip"),
                    combo("#btb.options.sub.combo", "battlebeats_subtitles_mode", {"#btb.options.sub.combo1", "#btb.options.sub.combo2"}, "#btb.options.sub.combo_tip"),
                    {
                        colW = 230,
                        combo("#btb.options.sub.lang", "battlebeats_subtitles_lang", ls, "#btb.options.sub.lang_tip", lv),
                        combo("#btb.options.sub.lang2", "battlebeats_subtitles_lang2", ls2, "#btb.options.sub.lang2_tip", lv2)
                    },
                }
            },
            {
                name = L("btb.options.cat.music_player"),
                tabs = {
                    {
                        name = L("btb.options.cat.general"),
                        rows = {
                            toggle("#btb.options.mplayer.curr_pack_only", "battlebeats_exclusive_play", "#btb.options.mplayer.curr_pack_only_tip"),
                            toggle("#btb.spawnmenu.general.npc_combat", "battlebeats_npc_combat", "#btb.spawnmenu.general.npc_combat_tip"),
                            toggle("#btb.spawnmenu.general.enable_assigned", "battlebeats_enable_assigned_tracks", "#btb.spawnmenu.general.enable_assigned_tip"),
                            stepper("#btb.options.mplayer.fav_weight", "battlebeats_favorite_weight", 1, 10, "#btb.options.mplayer.fav_weight_tip"),
                        }
                    },
                    {
                        name = L("btb.options.tab.advanced"),
                        rows = {
                            disabledWhen(stepper("#btb.options.mplayer.a_wait_time", "battlebeats_ambient_wait_time", 1, 120, "#btb.options.mplayer.wait_time_tip", "s"),
                                "battlebeats_always_continue", "1", "#btb.options.disabled.always_continue"),
                            disabledWhen(stepper("#btb.options.mplayer.c_wait_time", "battlebeats_combat_wait_time", 1, 120, "#btb.options.mplayer.wait_time_tip", "s"),
                                "battlebeats_always_continue", "1", "#btb.options.disabled.always_continue"),
                            toggle("#btb.options.mplayer.always_continue", "battlebeats_always_continue", "#btb.options.mplayer.always_continue_tip"),
                            toggle("#btb.options.mplayer.exclude_assigned", "battlebeats_exclude_mapped_tracks", "#btb.options.mplayer.exclude_assigned_tip"),
                            toggle("#btb.options.mplayer.switch_to_lower", "battlebeats_switch_on_lower_priority", "#btb.options.mplayer.switch_to_lower_tip"),
                            toggle("#btb.options.mplayer.disable_fade", "battlebeats_disable_fade", "#btb.options.mplayer.disable_fade_tip"),
                            combo("#btb.options.mplayer.combo", "battlebeats_continue_mode", {"#btb.options.mplayer.combo_1", "#btb.options.mplayer.combo_2"}, "#btb.options.mplayer.combo_tip"),
                        }
                    },
                }
            },
            {
                name = L("btb.options.cat.misc"),
                rows = {
                    {
                        toggle("#btb.options.misc.npc_los", "battlebeats_detection_mode", "#btb.spawnmenu.server.enable_pvp_los_tip"),
                        toggle("#btb.options.misc.auto_popup", "battlebeats_autopopup", "#btb.options.misc.auto_popup_tip")
                    },
                    {
                        toggle("#btb.options.misc.lower_vol_in_menu", "battlebeats_lower_volume_in_menu", "#btb.options.misc.lower_vol_in_menu_tip"),
                        toggle("#btb.options.misc.lower_vol_on_voice", "battlebeats_lower_volume_on_voice_chat", "#btb.options.misc.lower_vol_on_voice_tip")
                    },
                    toggle("#btb.options.misc.debug_mode", "battlebeats_debug_mode", "#btb.options.misc.debug_mode_tip"),
                    toggle("#btb.options.misc.load_am_sus", "battlebeats_load_am_suspense", "#btb.options.misc.load_am_sus_tip"),
                    toggle("#btb.options.misc.toggle_ui", "battlebeats_context_ui_toogle", "#btb.options.misc.toggle_ui_tip"),
                    toggle("#btb.options.misc.allow_enforce", "battlebeats_allow_server", "#btb.options.misc.allow_enforce_tip"),
                    space(10),
                    button("#btb.options.misc.reload_packs", "battlebeats_reload_packs"),
                    space(10),
                    group("DANGER ZONE", {
                        {
                            colW = 220,
                            button("#btb.options.misc.restore", "battlebeats_restore_defaults", "#btb.options.misc.restore_tip"),
                            button("#btb.options.misc.clean_unused_tracks", "battlebeats_clean_unused_tracks", "#btb.options.misc.clean_unused_tracks_tip")
                        },
                        {
                            colW = 220,
                            button("#btb.options.misc.clean_cache", "battlebeats_clean_cache", "#btb.options.misc.clean_cache_tip"),
                            button("#btb.options.misc.delete_data", "battlebeats_delete_data", "#btb.options.misc.delete_data_tip")
                        },
                    }),
                }
            },
        },
        server = {
            {
                name = L("btb.options.cat.general"),
                rows = {
                    server(stepper("#btb.spawnmenu.server.trigger_distance", "battlebeats_server_max_distance", 100, 10000, "#btb.spawnmenu.server.trigger_distance_tip")),
                }
            },

            {
                name = L("btb.options.cat.user"),
                rows = {
                    server(toggle("#btb.options.server.user.noti", "battlebeats_server_client_allow_notifications", "#btb.options.server.user.noti_tip")),
                    server(toggle("#btb.options.server.user.subtitles", "battlebeats_server_client_allow_subtitles", "#btb.options.server.user.subtitles_tip")),
                }
            },

            {
                name = L("btb.options.cat.pvp"),
                rows = {
                    server(toggle("#btb.spawnmenu.server.enable_pvp", "battlebeats_pvp_enable")),
                    server(toggle("#btb.spawnmenu.server.enable_pvp_teammates", "battlebeats_pvp_allow_team_combat")),
                    server(toggle("#btb.spawnmenu.server.enable_pvp_los", "battlebeats_pvp_lineofsight", "#btb.spawnmenu.server.enable_pvp_los_tip")),
                    server(stepper("#btb.spawnmenu.server.combat_time", "battlebeats_pvp_combat_time", 5, 120, "#btb.spawnmenu.server.combat_time_tip")),
                    server(stepper("#btb.spawnmenu.server.visibility", "battlebeats_pvp_max_distance", 100, 10000, "#btb.spawnmenu.server.visibility_tip")),
                    server(combo("#btb.spawnmenu.server.combo", "battlebeats_pvp_mode", {"#btb.spawnmenu.server.combo_1", "#btb.spawnmenu.server.combo_2", "#btb.spawnmenu.server.combo_3"}, pvpModeTip)),
                }
            },
        },
    }
end

local subIdle = Color(140, 140, 140)
local subActive = Color(255, 255, 255)
local function createSubTabs(category, parent, subs)
    local w, h = parent:GetWide(), parent:GetTall()
    local btnW = 340
    local startX = (w - btnW * #subs) / 2
    local pages = {}

    local strip = vgui.Create("DPanel", parent)
    strip:SetSize(w, 40)
    strip:SetPos(0, 0)
    strip.Paint = function(_, pw, ph)
        draw.RoundedBox(0, 0, ph, pw, 1, blockedColor)
    end

    local function setPage(i)
        category.subSelected = i
        for j, pg in ipairs(pages) do
            pg:SetVisible(j == i)
        end
    end

    for i, sub in ipairs(subs) do
        local page = vgui.Create("DPanel", parent)
        page:SetPos(0, 40)
        page:SetSize(w, h - 40)
        page.Paint = nil
        pages[i] = page
        sub.build(page)

        local btn = vgui.Create("DButton", strip)
        btn:SetText(sub.name)
        btn:SetFont("DermaDefaultBold")
        btn:SetPos(startX + (i - 1) * btnW, 0)
        btn:SetSize(btnW, 40)
        btn:SetTextColor(subIdle)
        btn.textColor = subIdle
        btn.lineW = 0

        btn.Think = function(self)
            local active = (category.subSelected or 1) == i
            local targetLine = active and self:GetWide() * 0.8 or (self:IsHovered() and self:GetWide() * 0.3 or 0)
            self.lineW = Lerp(FrameTime() * 12, self.lineW, targetLine)
            self.textColor = LerpColor(FrameTime() * 10, self.textColor, active and subActive or subIdle)
            self:SetTextColor(self.textColor)
        end

        btn.Paint = function(self, bw, bh)
            draw.RoundedBox(0, (bw - self.lineW) / 2, bh - 3, self.lineW, 2, subActive)
        end

        btn.DoClick = function()
            if (category.subSelected or 1) == i then return end
            surface.PlaySound("btb_tab_switch.mp3")
            setPage(i)
        end
    end

    setPage(category.subSelected or 1)
end

local function populateCategory(category, panel)
    if category.tabs then
        local subs = {}
        for _, t in ipairs(category.tabs) do
            subs[#subs + 1] = { name = t.name, build = function(page) layoutRows(page, t.rows, nil, 375) end }
        end
        createSubTabs(category, panel, subs)
    else
        layoutRows(panel, category.rows, nil, 410)
    end
end

function btb.createOptions(panel)
    if IsValid(btb.optionsFrame) then return end
    local plyIsAdmin = LocalPlayer():IsSuperAdmin()
    local frame = vgui.Create("DPanel", panel)
    frame:SetSize(950, 600)
    frame:Center()
    frame:SetPos(frame:GetX(), frame:GetY() - 20)
    frame.Paint = nil

    btb.optionsFrame = frame
    local currentScope = "client"
    local selectedTabs = { client = 1, server = 1 }

    local tabPanel = vgui.Create("DPanel", frame)
    tabPanel:SetSize(frame:GetWide() - 20, 40)
    tabPanel:SetPos(10, 30)
    tabPanel.Paint = nil

    local spec = buildSpec()
    local clientCategories = spec.client
    local serverCategories = spec.server
    local categories = clientCategories

    local contentPanel = vgui.Create("DPanel", frame)
    contentPanel:SetSize(frame:GetWide() - 20, frame:GetTall() - 120)
    contentPanel:SetPos(10, 70)
    contentPanel.Paint = nil

    local BuildTabs

    local function createScopeButton(text, x, scope)
        local button = vgui.Create("DButton", frame)
        button:SetZPos(-1)
        button:SetText(text)
        button:SetFont("Trebuchet24")
        button:SetSize(contentPanel:GetWide() / 2, 40)
        button.posY = frame:GetTall() - button:GetTall() - 10
        button:SetPos(x, button.posY)
        button:SetTextColor(Color(255, 255, 255))
        button.currentColor = normalColor
        button.targetColor = normalColor
        button.currentY = button.currentY or button.posY - 8
        button.targetY = button.posY - 8
        if scope == "server" and not plyIsAdmin then
            button:SetCursor("no")
        end

        button.Think = function(self)
            if not self.initialized then
                self.initialized = true
                button.currentY = currentScope == scope and button.posY or button.posY - 8
                self:SetPos(self:GetX(), self.currentY)
                return
            end
            if currentScope == scope then
                self.targetColor = activeColor
                self.targetY = button.posY
            elseif self:IsHovered() and plyIsAdmin then
                self.targetColor = hoverColor
                self.targetY = button.posY - 5
            else
                if not plyIsAdmin then
                    self.targetColor = blockedColor
                else
                    self.targetColor = normalColor
                end
                self.targetY = button.posY - 8
            end

            self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
            self.currentY = Lerp(FrameTime() * 12, self.currentY, self.targetY)

            self:SetPos(self:GetX(), self.currentY)
        end

        button.Paint = function(self, w, h)
            if currentScope == scope then
                draw.RoundedBoxEx(16, 0, 0, w, h, activeColor, false, false, true, true)
                return
            end
            draw.RoundedBoxEx(16, 0, 0, w, h, self.currentColor, false, false, true, true)
        end

        button.DoClick = function()
            if scope == "server" and not plyIsAdmin then
                surface.PlaySound("buttons/button8.wav")
                return
            end
            surface.PlaySound("btb_tab_switch.mp3")
            currentScope = scope
            BuildTabs()
        end
    end

    createScopeButton("#btb.options.client", 10, "client")
    createScopeButton("#btb.options.server", 475, "server")

    function BuildTabs()
        tabPanel:Clear()
        categories = currentScope == "client" and clientCategories or serverCategories
        local tabWidth = tabPanel:GetWide() / #categories

        for _, cat in ipairs(clientCategories) do
            if IsValid(cat.panel) then
                cat.panel:SetVisible(false)
            end
        end
        for _, cat in ipairs(serverCategories) do
            if IsValid(cat.panel) then
                cat.panel:SetVisible(false)
            end
        end

        for i, category in ipairs(categories) do
            local button = vgui.Create("DButton", tabPanel)
            button:SetText(category.name)
            button:SetFont("CreditsText")
            button:SetPos((i - 1) * tabWidth, 8)
            button:SetSize(tabWidth, 40)
            button:SetTextColor(Color(255, 255, 255))
            button.currentColor = normalColor
            button.targetColor = normalColor
            button.currentY = button.currentY or 8
            button.targetY = 8
            button.initialized = false

            button.Think = function(self)
                local isActive = category.panel and category.panel:IsVisible()
                if not self.initialized then
                    self.initialized = true
                    button.currentY = isActive and 0 or 8
                    self:SetPos(self:GetX(), self.currentY)
                    return
                end

                if isActive then
                    self.targetColor = activeColor
                    self.targetY = 0
                elseif self:IsHovered() then
                    self.targetColor = hoverColor
                    self.targetY = 5
                else
                    self.targetColor = normalColor
                    self.targetY = 8
                end

                self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
                self.currentY = Lerp(FrameTime() * 12, self.currentY, self.targetY)

                self:SetPos(self:GetX(), self.currentY)
            end

            button.Paint = function(self, w, h)
                if category.panel and category.panel:IsVisible() then
                    draw.RoundedBoxEx(16, 0, 0, w, h, activeColor, true, true, false, false)
                    return
                end
                draw.RoundedBoxEx(16, 0, 0, w, h, self.currentColor, true, true, false, false)
            end

            if not IsValid(category.panel) then
                local panel = vgui.Create("DPanel", contentPanel)
                panel:SetSize(contentPanel:GetWide(), contentPanel:GetTall())
                panel:SetPos(0, 0)
                panel.Paint = function(self, w, h)
                    draw.RoundedBox(0, 0, 0, w, h, activeColor)
                end
                panel:SetVisible(false)
                category.panel = panel

                local translation = L("btb.translated.by")
                local lang = GetConVar("gmod_language"):GetString()
                if lang ~= "en" and translation ~= "///" then
                    local translationLabel = vgui.Create("DLabel", panel)
                    translationLabel:SetText(L("btb.translated.by.label") .. translation)
                    translationLabel:SetPos((contentPanel:GetWide() - 400) / 2, 420)
                    translationLabel:SetSize(400, 20)
                    translationLabel:SetTextColor(Color(80, 80, 80, 200))
                    translationLabel:SetContentAlignment(5)
                end

                local versionlabel = vgui.Create("DLabel", panel)
                versionlabel:SetText(L("btb.options.version.label") .. " " .. btb.currentVersion .. " | " .. jit.arch .. " :: " .. jit.os)
                versionlabel:SetPos((contentPanel:GetWide() - 250) / 2, 440)
                versionlabel:SetSize(250, 20)
                versionlabel:SetTextColor(Color(80, 80, 80, 200))
                versionlabel:SetContentAlignment(5)

                populateCategory(category, panel)
            end

            button.DoClick = function()
                surface.PlaySound("btb_tab_switch.mp3")
                selectedTabs[currentScope] = i
                for _, cat in ipairs(categories) do
                    if IsValid(cat.panel) then
                        cat.panel:SetVisible(false)
                    end
                end
                if IsValid(category.panel) then
                    category.panel:SetVisible(true)
                end
            end
        end

        local selected = selectedTabs[currentScope] or 1
        if selected > #categories then
            selected = 1
            selectedTabs[currentScope] = 1
        end

        if categories[selected] and IsValid(categories[selected].panel) then
            categories[selected].panel:SetVisible(true)
        end
    end

    BuildTabs()
end

local defaultX = tostring(ScrW() - 310)
local defaultY = tostring(ScrH() / 6)
local subdefaultY = tostring(ScrH() - 200)

local confirmations = {}
local function confirmAction(id, timeout)
    local now = CurTime()
    local state = confirmations[id]
    if not state or now > state.expires then
        confirmations[id] = { expires = now + (timeout or 5) }
        notification.AddLegacy("[BattleBeats] " .. (L("btb.options.misc.button_conf")), NOTIFY_HINT, timeout or 5)
        surface.PlaySound("ambient/water/drip" .. math.random(1, 4) .. ".wav")
        return false
    end
    confirmations[id] = nil
    surface.PlaySound("buttons/button14.wav")
    return true
end

local function cleanupInvalidTracks(tbl)
    local toRemove = {}
    for trackPath, _ in pairs(tbl) do
        if not file.Exists(trackPath, "GAME") then
            print("[BattleBeats Cleanup] Removing: " .. trackPath)
            table.insert(toRemove, trackPath)
        end
    end
    for _, trackPath in ipairs(toRemove) do
        tbl[trackPath] = nil
    end
end

concommand.Add("battlebeats_restore_defaults", function()
    if not confirmAction("restore_defaults", 5) then return end

    notification.AddLegacy("[BattleBeats] " .. L("btb.options.misc.restore_tip_conf"), NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")

    RunConsoleCommand("battlebeats_detection_mode", "1")
    RunConsoleCommand("battlebeats_npc_combat", "0")

    RunConsoleCommand("battlebeats_autopopup", "1")
    RunConsoleCommand("battlebeats_load_am_suspense", "0")
    RunConsoleCommand("battlebeats_allow_server", "1")

    RunConsoleCommand("battlebeats_volume", "100")
    RunConsoleCommand("battlebeats_debug_mode", "0")
    RunConsoleCommand("battlebeats_ambient_wait_time", "40")
    RunConsoleCommand("battlebeats_combat_wait_time", "40")
    RunConsoleCommand("battlebeats_enable_ambient", "1")
    RunConsoleCommand("battlebeats_enable_combat", "1")
    RunConsoleCommand("battlebeats_disable_mode", "0")
    RunConsoleCommand("battlebeats_persistent_notification", "0")
    RunConsoleCommand("battlebeats_show_notification", "1")
    RunConsoleCommand("battlebeats_show_notification_after_continue", "0")
    RunConsoleCommand("battlebeats_exclusive_play", "0")
    RunConsoleCommand("battlebeats_always_continue", "0")
    RunConsoleCommand("battlebeats_continue_mode", "0")
    RunConsoleCommand("battlebeats_show_preview_notification", "1")
    RunConsoleCommand("battlebeats_lower_volume_in_menu", "1")
    RunConsoleCommand("battlebeats_force_combat", "0")
    RunConsoleCommand("battlebeats_disable_fade", "0")
    RunConsoleCommand("battlebeats_start_mode", "0")
    RunConsoleCommand("battlebeats_favorite_weight", "3")
    RunConsoleCommand("battlebeats_crossfade_type", "0")

    RunConsoleCommand("battlebeats_subtitles_enabled", "1")
    RunConsoleCommand("battlebeats_subtitles_mode", "0")
    RunConsoleCommand("battlebeats_subtitles_static", "0")
    RunConsoleCommand("battlebeats_context_ui_toogle", "0")
    RunConsoleCommand("battlebeats_subtitles_lang", "auto")
    RunConsoleCommand("battlebeats_subtitles_lang2", "")

    RunConsoleCommand("battlebeats_volume_ambient", "100")
    RunConsoleCommand("battlebeats_volume_combat", "100")

    RunConsoleCommand("battlebeats_dynamic_volume", "1")
    RunConsoleCommand("battlebeats_dynamic_volume_env", "1")

    RunConsoleCommand("battlebeats_switch_on_lower_priority", "1")
    RunConsoleCommand("battlebeats_enable_assigned_tracks", "1")
    RunConsoleCommand("battlebeats_exclude_mapped_tracks", "0")

    RunConsoleCommand("battlebeats_show_notification_visualizer", "1")
    RunConsoleCommand("battlebeats_show_notification_pack_name", "1")
    RunConsoleCommand("battlebeats_visualizer_boost", "6")
    RunConsoleCommand("battlebeats_visualizer_smooth", "1")
    RunConsoleCommand("battlebeats_skip_nombat_names", "1")
    RunConsoleCommand("battlebeats_show_status_bar", "1")

    RunConsoleCommand("battlebeats_notif_x", defaultX)
    RunConsoleCommand("battlebeats_notif_y", defaultY)

    RunConsoleCommand("battlebeats_subtitles_y", subdefaultY)
end)

concommand.Add("battlebeats_clean_cache", function()
    if not confirmAction("clean_cache", 5) then return end

    notification.AddLegacy("[BattleBeats] " .. L("btb.options.misc.clean_cache_tip_conf"), NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")

    RunConsoleCommand("battlebeats_seen_version", "0")
    cookie.Delete("battlebeats_start_track")
    cookie.Delete('BattleBeats_FirstTime')
    cookie.Delete("battlebeats_last_track")
    cookie.Delete("battlebeats_vol_expanded")

    file.Delete("battlebeats/trackmeta.txt")
    btb.trackMeta = {}
end)

concommand.Add("battlebeats_delete_data", function()
    if not confirmAction("delete_data", 5) then return end

    notification.AddLegacy("[BattleBeats] " .. L("btb.options.misc.delete_data_tip_conf"), NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")

    cookie.Delete("battlebeats_selected_packs")
    cookie.Delete("battlebeats_start_track")
    cookie.Delete('BattleBeats_FirstTime')
    cookie.Delete("battlebeats_last_track")
    cookie.Delete("battlebeats_vol_expanded")
    RunConsoleCommand("battlebeats_seen_version", "0")
    file.Delete("battlebeats/battlebeats_pack_volumes.txt")
    btb.packVolume = {}
    file.Delete("battlebeats/battlebeats_playlists.txt")
    btb.musicPlaylists = {}
    file.Delete("battlebeats/track_data.json")
    btb.trackData = {}
    file.Delete("battlebeats/trackmeta.txt")
    btb.trackMeta = {}
end)

concommand.Add("battlebeats_clean_unused_tracks", function()
    if not confirmAction("clean_unused_tracks", 5) then return end

    notification.AddLegacy("[BattleBeats] " .. L("btb.options.misc.clean_unused_tracks_tip_conf"), NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")

    cleanupInvalidTracks(btb.packVolume)
    btb.SavePackVolumes()
end)
