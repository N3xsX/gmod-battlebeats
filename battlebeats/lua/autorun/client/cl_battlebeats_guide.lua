local function LerpColor(t, from, to)
    return Color(
        Lerp(t, from.r, to.r),
        Lerp(t, from.g, to.g),
        Lerp(t, from.b, to.b),
        Lerp(t, from.a or 255, to.a or 255)
    )
end


local btbGuide = {
    {
        image = "",
        text = "Hey! Thanks for downloading BattleBeats. Looks like it's your first time using it. Want to see a quick guide that shows most of BattleBeats features? Don't worry, you can always access this guide later in the settings"
    },
    {
        image = "g1",
        text = "You can access the UI using the context menu (C)"
    },
    {
        image = "g2",
        text = "Alternatively, you can open it through Spawnmenu -> Utilities -> BattleBeats -> General (or by using the console command battlebeats_menu)"
    },
    {
        image = "g3",
        text = "Alright, here is the UI (that you are already seeing). This is the main panel"
    },
    {
        image = "g4",
        text = "You can enable each pack by pressing these buttons here"
    },
    {
        image = "g5",
        text = "You can also click the entire panel to open a dropdown menu"
    },
    {
        image = "g6",
        text = "By pressing either of these two buttons, you can access a list of ambient or combat tracks from the selected pack"
    },
    {
        image = "g7",
        text = "This is the main track panel"
    },
    {
        image = "g8",
        text = "You can search for any track name using the search bar at the top"
    },
    {
        image = "g9",
        text = "Next to it, you can select the sorting mode for the tracks; for example, from A-Z or Z-A"
    },
    {
        image = "g10",
        text = "Just like in the pack selector panel, you can enable or disable each track separately"
    },
    {
        image = "g11",
        text = "Clicking any track in the list will open the player for that track"
    },
    {
        image = "g12",
        text = "Use the controls below to, well... control playback"
    },
    {
        image = "g13",
        text = "You can use the slider to jump to a specific timestamp in the track"
    },
    {
        image = "g14",
        text = "Here can also adjust the volume of the playing track"
    },
    {
        image = "g15",
        text = "Right-clicking a track opens the properties menu, where you can copy its path, add it to favorites, set an offset, or, for combat tracks, assign an NPC to it"
    },
    {
        image = "g16",
        text = "Here you can assign a specific NPC class and set its priority"
    },
    {
        image = "g17",
        text = "You can go back to the pack selector using the button below"
    },
    {
        image = "g18",
        text = "Last but not least, the Options panel. You can access it by pressing the button in the lower-right corner"
    },
    {
        image = "g19",
        text = "Here you'll find all client-side options for BattleBeats. Alternatively, you can also find them in the spawnmenu"
    },
    {
        image = "g20",
        text = "You can switch between option categories using the tabs at the top. I won't go over every option here since each one has its own tooltip and explanation when you hover over it"
    },
    {
        image = "",
        text = "Well, that would be it! These are all the basics you need to know about BattleBeats. Hope you enjoy using it!"
    },
}


local currentPage = 1
local frame

local c000200 = Color(0, 0, 2, 200)
local c707070255 = Color(70, 70, 70, 255)
local c808080255 = Color(80, 80, 80, 255)

local function openGuide()
    if IsValid(frame) then frame:Remove() end

    frame = vgui.Create("DFrame")
    frame:SetSize(640, 580)
    frame:Center()
    frame:SetTitle("BattleBeats Guide")
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, c000200)
    end

    local img = vgui.Create("DImage", frame)
    img:SetSize(620, 400)
    img:SetPos(10, 30)
    img:SetKeepAspect(true)

    local text = vgui.Create("DLabel", frame)
    text:SetPos(20, 440)
    text:SetSize(600, 80)
    text:SetWrap(true)
    text:SetFont("CreditsText")
    text:SetTextColor(color_white)

    local textBg = vgui.Create("DPanel", frame)
    textBg:SetPos(8, 438)
    textBg:SetSize(624, 84)
    textBg:SetBackgroundColor(Color(0, 0, 0, 255))
    textBg:SetZPos(-1)

    local btnPrev, btnNext
    local function RefreshPage()
        local data = btbGuide[currentPage]
        if not data then return end

        img:SetVisible(true)
        if data.image == "" then
            img:SetVisible(false)
        end

        img:SetImage("materials/guide/" .. data.image .. ".jpg")

        text:SetText(data.text or "")
        frame:SetTitle(string.format("BattleBeats Guide (%d / %d)", currentPage, #btbGuide))

        btnPrev:SetVisible(currentPage > 1)
        btnNext:SetVisible(currentPage < #btbGuide)
    end

    local function makeButton(label, x, func)
        local btn = vgui.Create("DButton", frame)
        btn:SetSize(100, 30)
        btn:SetPos(x, 530)
        btn:SetText(label)
        btn:SetFont("DermaDefaultBold")
        btn:SetTextColor(color_white)
        btn:SetCursor("hand")

        btn.currentColor = c707070255
        btn.targetColor = c707070255

        btn.Think = function(self)
            if self:IsHovered() then
                self.targetColor = c808080255
            else
                self.targetColor = c707070255
            end
            self.currentColor = LerpColor(FrameTime() * 10, self.currentColor, self.targetColor)
        end

        btn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self.currentColor)
        end

        btn.DoClick = func
        return btn
    end

    btnPrev = makeButton("◀ Prev", 10, function()
        currentPage = math.max(currentPage - 1, 1)
        RefreshPage()
    end)

    local btnClose = makeButton("Close", 270, function()
        frame:Close()
    end)

    btnNext = makeButton("Next ▶", 530, function()
        currentPage = math.min(currentPage + 1, #btbGuide)
        RefreshPage()
    end)

    frame.OnClose = function ()
        currentPage = 1
    end

    RefreshPage()
end

concommand.Add("battlebeats_guide", openGuide)