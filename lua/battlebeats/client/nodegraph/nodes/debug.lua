--MARK: PRINT
BATTLEBEATS.RegisterNode("debug.PRINT", {
    category = "Debug",
    title = "Print",
    desc = "Prints the node ID and input value to the console",

    inputs = {
        { id = "in", type = "number" },
    },

    oninputschanged = function(ctx, node)
        print(string.format("[BattleBeats Print] tick %d | node %s | %s", ctx.tick, tostring(node.id), tostring(ctx:Read(node, "in"))))
    end
})
--MARK: PRINT STRING
BATTLEBEATS.RegisterNode("debug.PRINT_STRING", {
    category = "Debug",
    title = "Print String",
    desc = "Prints the node ID and input value to the console",

    inputs = {
        { id = "in", type = "string" },
    },

    oninputschanged = function(ctx, node)
        print(string.format("[BattleBeats Print] tick %d | node %s | %s", ctx.tick, tostring(node.id), ctx:ReadString(node, "in")))
    end
})
--MARK: COMMAND TRIGGER
BATTLEBEATS.RegisterNode("debug.COMMAND_TRIGGER", {
    category = "Debug",
    title = "Manual Trigger",
    desc = "Emits a single output pulse when manually triggered via 'btb_runtime_debugnode_fire' console command",

    outputs = {
        { id = "out", type = "boolean", pulse = true }
    }
})

concommand.Add("btb_runtime_debugnode_fire", function()
    local ok, res = BATTLEBEATS.FireNodeByClass("debug.COMMAND_TRIGGER", "out")
    if not ok then
        print("[BattleBeats] Manual trigger failed: " .. tostring(res))
    end
end)
