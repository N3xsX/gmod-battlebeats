--MARK: PRINT
BATTLEBEATS.RegisterNode("debug.PRINT", {
    category = "Debug",
    title = "Print",
    desc = "Prints the node ID and input value to the console",

    inputs = {
        { id = "in", type = "number" },
    },

    oninputschanged = function(ctx, node)
        print(ctx:ReadBool(node, "in"))
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
    BATTLEBEATS.FireNodeByClass("debug.COMMAND_TRIGGER", "out")
end)