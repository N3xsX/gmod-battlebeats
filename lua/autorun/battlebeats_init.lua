include("battlebeats/sh_battlebeats.lua")

if SERVER then
    AddCSLuaFile("battlebeats/sh_battlebeats.lua")

    AddCSLuaFile("battlebeats/client/ui/cl_fonts.lua")

    AddCSLuaFile("battlebeats/client/cl_main.lua")
    AddCSLuaFile("battlebeats/client/nodegraph/cl_runtime.lua")

    AddCSLuaFile("battlebeats/client/nodegraph/nodes/logic.lua")
    AddCSLuaFile("battlebeats/client/nodegraph/nodes/debug.lua")
    AddCSLuaFile("battlebeats/client/nodegraph/nodes/audio.lua")
    AddCSLuaFile("battlebeats/client/nodegraph/nodes/event.lua")
    AddCSLuaFile("battlebeats/client/nodegraph/nodes/math.lua")

    AddCSLuaFile("battlebeats/client/nodegraph/cl_zones.lua")

    AddCSLuaFile("battlebeats/client/ui/cl_notifications.lua")

    AddCSLuaFile("battlebeats/client/cl_server_enforcer.lua")
    AddCSLuaFile("battlebeats/client/cl_subtitles.lua")

    AddCSLuaFile("battlebeats/client/ui/cl_panel_meta.lua")
    AddCSLuaFile("battlebeats/client/ui/cl_pack_selector_misc.lua")
    AddCSLuaFile("battlebeats/client/ui/cl_pack_selector.lua")
    AddCSLuaFile("battlebeats/client/ui/cl_options_ui.lua")
    AddCSLuaFile("battlebeats/client/ui/cl_playlists.lua")

    AddCSLuaFile("battlebeats/client/cl_spawnmenu.lua")
    AddCSLuaFile("battlebeats/client/cl_spawnmenu_nodegraph.lua")
    AddCSLuaFile("battlebeats/client/cl_loading.lua")

    include("battlebeats/server/sv_main.lua")
    include("battlebeats/server/sv_enforcer.lua")

    resource.AddWorkshop("3473911205")
end

if CLIENT then
    file.CreateDir("battlebeats")
    file.CreateDir("battlebeats_graphs")
    file.CreateDir("battlebeats_zones")

    local function includeF(path)
        local files, dirs = file.Find(path .. "/*", "LUA")
        for _, f in ipairs(files) do
            if string.GetExtensionFromFilename(f) == "lua" then
                include(path .. "/" .. f)
            end
        end
        for _, dir in ipairs(dirs) do
            includeF(path .. "/" .. dir)
        end
    end
    local function includeNF(root, name)
        local function scan(p)
            local _, dirs = file.Find(p .. "/*", "LUA")
            for _, d in ipairs(dirs) do
                local x = p .. "/" .. d
                if d == name then
                    includeF(x)
                else
                    scan(x)
                end
            end
        end
        scan(root)
    end

    include("battlebeats/client/ui/cl_fonts.lua")

    include("battlebeats/client/cl_main.lua")
    include("battlebeats/client/nodegraph/cl_runtime.lua")

    include("battlebeats/client/nodegraph/nodes/logic.lua")
    include("battlebeats/client/nodegraph/nodes/debug.lua")
    include("battlebeats/client/nodegraph/nodes/audio.lua")
    include("battlebeats/client/nodegraph/nodes/event.lua")
    include("battlebeats/client/nodegraph/nodes/math.lua")

    include("battlebeats/client/nodegraph/cl_zones.lua")

    include("battlebeats/client/ui/cl_notifications.lua")

    include("battlebeats/client/cl_server_enforcer.lua")
    include("battlebeats/client/cl_subtitles.lua")

    include("battlebeats/client/ui/cl_panel_meta.lua")
    include("battlebeats/client/ui/cl_pack_selector_misc.lua")
    include("battlebeats/client/ui/cl_pack_selector.lua")
    include("battlebeats/client/ui/cl_options_ui.lua")
    include("battlebeats/client/ui/cl_playlists.lua")

    include("battlebeats/client/cl_spawnmenu.lua")
    include("battlebeats/client/cl_spawnmenu_nodegraph.lua")
    include("battlebeats/client/cl_loading.lua")

    includeNF("battlebeats", "subtitles")
    includeNF("battlebeats", "graphs")
end