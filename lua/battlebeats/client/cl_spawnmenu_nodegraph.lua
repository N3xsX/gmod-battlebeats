local function num(n)
    return string.format("%.2f", n):gsub("%.?0+$", "")
end

local function toLUA(name, set)
    local out = {}

    out[#out + 1] = string.format(
        "BATTLEBEATS.RegisterZoneSet(%q, %q, {",
        name,
        game.GetMap()
    )

    for _, zone in ipairs(set.zones) do
        out[#out + 1] = string.format([[
    {
        name = %q,

        minx = %s,
        miny = %s,
        minz = %s,

        maxx = %s,
        maxy = %s,
        maxz = %s
    },]],
            zone.name,
            num(zone.min.x), num(zone.min.y), num(zone.min.z),
            num(zone.max.x), num(zone.max.y), num(zone.max.z)
        )
    end

    out[#out + 1] = "})"

    return table.concat(out, "\n")
end

hook.Add("PopulateToolMenu", "BattleBeats_Settings_Nodegraph", function()
    spawnmenu.AddToolMenuOption("Utilities", "BattleBeats Nodegraph", "BattleBeatsMenuZones", "Zones", "", "",
        function(panel)
            panel:ClearControls()

            local container = vgui.Create("DPanel")
            container:SetTall(500)

            panel:AddItem(container)

            local tree = vgui.Create("DTree", container)
            tree:Dock(FILL)

            local function BuildTree()
                tree:Clear()

                local root = tree:AddNode("Zone sets for: " .. tostring(game.GetMap()))
                root:SetExpanded(true)

                local addSet = root:AddNode("+ New Set")

                addSet.DoClick = function()
                    Derma_StringRequest(
                        "Create Zone Set",
                        "Set name",
                        "",
                        function(name)
                            name = string.Trim(name)

                            if name == "" then return end
                            if not BATTLEBEATS.CreateZoneSet(name) then return end

                            BuildTree()
                        end
                    )
                end

                for setName, set in SortedPairs(BATTLEBEATS.ZoneSets) do
                    local displayName = setName
                    if BATTLEBEATS.GetCurrentZoneSet() == setName then
                        displayName = displayName .. " (currently editing)"
                    end
                    local node = root:AddNode(displayName)

                    node.Icon:SetImage(BATTLEBEATS.ActiveZoneSets[setName] and "icon16/accept.png" or "icon16/cancel.png")

                    node.DoClick = function()
                        BATTLEBEATS.CurrentZoneSet = setName
                        BuildTree()
                    end

                    node.DoRightClick = function()
                        local menu = DermaMenu()

                        if BATTLEBEATS.ActiveZoneSets[setName] then
                            menu:AddOption("Disable", function()
                                BATTLEBEATS.ActiveZoneSets[setName] = nil
                                BATTLEBEATS.SaveActiveZones()
                                BATTLEBEATS.RebuildZones()

                                BuildTree()
                            end):SetIcon("icon16/cancel.png")
                        else
                            menu:AddOption("Enable", function()
                                BATTLEBEATS.ActiveZoneSets[setName] = true
                                BATTLEBEATS.SaveActiveZones()
                                BATTLEBEATS.RebuildZones()

                                BuildTree()
                            end):SetIcon("icon16/accept.png")
                        end

                        if set.source ~= "addon" and setName ~= "default" then
                            menu:AddSpacer()
                            menu:AddOption("Delete Set", function()
                                BATTLEBEATS.DeleteZoneSet(setName)
                                BuildTree()
                            end):SetIcon("icon16/delete.png")
                        end

                        menu:AddSpacer()

                        menu:AddOption("Copy as Lua", function()
                            SetClipboardText(toLUA(setName, set))
                            notification.AddLegacy("Copied Lua to clipboard", NOTIFY_GENERIC, 3)
                        end):SetIcon("icon16/page_white_code.png")

                        menu:Open()
                    end

                    for id, zone in ipairs(set.zones) do
                        local zoneNode = node:AddNode(zone.name)
                        zoneNode.Icon:SetImage("icon16/world.png")
                        zoneNode.DoRightClick = function()
                            local menu = DermaMenu()
                            menu:AddOption("Delete", function()
                                BATTLEBEATS.DeleteZone(setName, id)
                                BuildTree()
                            end):SetIcon("icon16/delete.png")
                            menu:Open()
                        end
                    end
                end
            end
            BuildTree()

            hook.Add("BattleBeatsZoneSetsChanged", tree, function()
                if IsValid(tree) then
                    BuildTree()
                end
            end)
            tree.OnRemove = function()
                hook.Remove("BattleBeatsZoneSetsChanged", tree)
            end
        end)
end)
