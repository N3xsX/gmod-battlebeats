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
        image = "g0",
        text = "#btb.guide.g0"
    },
    {
        image = "g1",
        text = "#btb.guide.g1"
    },
    {
        image = "g2",
        text = "#btb.guide.g2"
    },
    {
        image = "g3",
        text = "#btb.guide.g3"
    },
    {
        image = "g4",
        text = "#btb.guide.g4"
    },
    {
        image = "g5",
        text = "#btb.guide.g5"
    },
    {
        image = "g6",
        text = "#btb.guide.g6"
    },
    {
        image = "g7",
        text = "#btb.guide.g7"
    },
    {
        image = "g8",
        text = "#btb.guide.g8"
    },
    {
        image = "g9",
        text = "#btb.guide.g9"
    },
    {
        image = "g10",
        text = "#btb.guide.g10"
    },
    {
        image = "g11",
        text = "#btb.guide.g11"
    },
    {
        image = "g12",
        text = "#btb.guide.g12"
    },
    {
        image = "g13",
        text = "#btb.guide.g13"
    },
    {
        image = "g14",
        text = "#btb.guide.g14"
    },
    {
        image = "g15",
        text = "#btb.guide.g15"
    },
    {
        image = "g16",
        text = "#btb.guide.g16"
    },
    {
        image = "g17",
        text = "#btb.guide.g17"
    },
    {
        image = "g18",
        text = "#btb.guide.g18"
    },
    {
        image = "g19",
        text = "#btb.guide.g19"
    },
    {
        image = "g20",
        text = "#btb.guide.g20"
    },
    {
        image = "",
        text = "#btb.guide.end"
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
    local function refreshPage()
        local data = btbGuide[currentPage]
        if not data then return end

        img:SetVisible(true)
        if data.image == "" then
            img:SetVisible(false)
        end

        img:SetImage("materials/guide/" .. data.image .. ".jpg")

        text:SetText(data.text or "")
        frame:SetTitle("BattleBeats Guide (" .. currentPage .. "/" .. #btbGuide .. ")")

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

    btnPrev = makeButton("#btb.guide.prev", 10, function()
        currentPage = math.max(currentPage - 1, 1)
        refreshPage()
    end)

    local btnClose = makeButton("#btb.guide.close", 270, function()
        frame:Close()
    end)

    btnNext = makeButton("#btb.guide.next", 530, function()
        currentPage = math.min(currentPage + 1, #btbGuide)
        refreshPage()
    end)

    frame.OnClose = function ()
        currentPage = 1
    end

    refreshPage()
end

concommand.Add("battlebeats_guide", openGuide)