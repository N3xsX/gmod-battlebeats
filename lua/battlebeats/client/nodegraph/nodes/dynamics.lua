
local function toTicks(sec)
    return math.max(math.floor((sec or 0) / BATTLEBEATS.TickInterval + 0.5), 0)
end

--MARK: STABILIZE
BATTLEBEATS.RegisterNode("logic.STABILIZE", {
    category = "Logic",
    title = "Stabilize (Hysteresis)",
    desc = "Stabilizes a level. The output follows the input only after it has stayed higher for 'Rise delay' or lower for 'Fall delay' seconds. Flicker shorter than that is ignored. Optionally falls one level at a time",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "number" },
        { id = "up", type = "boolean", pulse = true },
        { id = "down", type = "boolean", pulse = true },
        { id = "changed", type = "boolean", pulse = true }
    },

    args = {
        { id = "upTime", title = "Rise delay (s)", type = "number", default = 1, min = 0 },
        { id = "downTime", title = "Fall delay (s)", type = "number", default = 5, min = 0 },
        { id = "step", title = "Fall one level at a time", type = "bool", default = false }
    },

    init = function(node)
        node.memory.timer = 0
        node.memory.dir = 0
    end,

    tick = function(ctx, node, args)
        local m = node.memory
        local cur = node.currentState.out
        local v = ctx:Read(node, "in")

        local dir = 0
        if v > cur then dir = 1 elseif v < cur then dir = -1 end

        if dir == 0 then
            m.timer, m.dir = 0, 0
            return
        end
        if dir ~= m.dir then
            m.dir, m.timer = dir, 0
        end

        m.timer = m.timer + 1
        if m.timer < toTicks(dir > 0 and args.upTime or args.downTime) then return end

        local nv = v
        if dir < 0 and args.step then nv = math.max(v, cur - 1) end

        m.timer = 0
        ctx:Write(node, "out", nv)
        ctx:Pulse(node, dir > 0 and "up" or "down")
        ctx:Pulse(node, "changed")
    end
})

--MARK: THRESHOLD
BATTLEBEATS.RegisterNode("logic.THRESHOLD", {
    category = "Logic",
    title = "Threshold (Schmitt)",
    desc = "Schmitt trigger. State turns on when input >= 'On at' and off only when input <= 'Off at' (the gap between them is the hysteresis). Emits a pulse on every on/off transition",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "state", type = "boolean" },
        { id = "rise", type = "boolean", pulse = true },
        { id = "fall", type = "boolean", pulse = true }
    },

    args = {
        { id = "high", title = "On at (>=)", type = "number", default = 1 },
        { id = "low", title = "Off at (<=)", type = "number", default = 0 }
    },

    init = function(node)
        node.memory.on = false
    end,

    oninputschanged = function(ctx, node, args)
        local v = ctx:Read(node, "in")
        local high = args.high or 1
        local low = math.min(args.low or 0, high)
        local on = node.memory.on

        if not on and v >= high then
            node.memory.on = true
            ctx:Write(node, "state", 1)
            ctx:Pulse(node, "rise")
        elseif on and v <= low then
            node.memory.on = false
            ctx:Write(node, "state", 0)
            ctx:Pulse(node, "fall")
        end
    end
})

--MARK: COOLDOWN
BATTLEBEATS.RegisterNode("logic.COOLDOWN", {
    category = "Logic",
    title = "Cooldown",
    desc = "Passes a pulse only if at least N seconds have passed since the last passed pulse. Other pulses go to 'blocked'",

    inputs = {
        { id = "in", type = "boolean" }
    },

    outputs = {
        { id = "out", type = "boolean", pulse = true },
        { id = "blocked", type = "boolean", pulse = true }
    },

    args = {
        { id = "time", title = "Cooldown (s)", type = "number", default = 10, min = 0 }
    },

    oninputschanged = function(ctx, node, args)
        local v = ctx:ReadBool(node, "in")
        local old = node.memory.old or false
        node.memory.old = v
        if not v or old then return end

        local last = node.memory.last
        if last == nil or ctx.tick - last >= toTicks(args.time) then
            node.memory.last = ctx.tick
            ctx:Pulse(node, "out")
        else
            ctx:Pulse(node, "blocked")
        end
    end
})

--MARK: CHANCE
BATTLEBEATS.RegisterNode("logic.CHANCE", {
    category = "Logic",
    title = "Chance",
    desc = "Passes a pulse with the given probability (percent). Otherwise the pulse goes to 'fail'",

    inputs = {
        { id = "in", type = "boolean" }
    },

    outputs = {
        { id = "pass", type = "boolean", pulse = true },
        { id = "fail", type = "boolean", pulse = true }
    },

    args = {
        { id = "percent", title = "Chance (%)", type = "number", default = 50, min = 0, max = 100 }
    },

    oninputschanged = function(ctx, node, args)
        local v = ctx:ReadBool(node, "in")
        local old = node.memory.old or false
        node.memory.old = v
        if not v or old then return end

        if math.random() * 100 < (args.percent or 0) then
            ctx:Pulse(node, "pass")
        else
            ctx:Pulse(node, "fail")
        end
    end
})

--MARK: PULSE STRETCH
BATTLEBEATS.RegisterNode("logic.PULSE_STRETCH", {
    category = "Logic",
    title = "Pulse Stretch",
    desc = "Turns a pulse into a signal that stays true for N seconds. A new pulse restarts the timer",

    inputs = {
        { id = "in", type = "boolean" }
    },

    outputs = {
        { id = "out", type = "boolean" }
    },

    args = {
        { id = "time", title = "Duration (s)", type = "number", default = 5, min = 0 }
    },

    init = function(node)
        node.memory.left = 0
    end,

    oninputschanged = function(ctx, node, args)
        local v = ctx:ReadBool(node, "in")
        local old = node.memory.old or false
        node.memory.old = v
        if v and not old then
            node.memory.left = toTicks(args.time)
            if node.memory.left > 0 then ctx:Write(node, "out", 1) end
        end
    end,

    tick = function(ctx, node)
        local left = node.memory.left
        if left and left > 0 then
            left = left - 1
            node.memory.left = left
            if left == 0 then ctx:Write(node, "out", 0) end
        end
    end
})

--MARK: CHOOSE STRING
local cSlots = 8
local chooseArgs = {}
for i = 0, cSlots - 1 do
    chooseArgs[#chooseArgs + 1] = { id = "s" .. i, title = "Value " .. i, type = "string", default = "" }
end

BATTLEBEATS.RegisterNode("string.CHOOSE", {
    category = "String",
    title = "Choose String",
    desc = "Outputs the string whose number equals the input index (0-7). Index above the last filled value uses the last one. 'changed' pulses together with the new string, so it can safely trigger nodes that read 'out'",

    inputs = {
        { id = "index", type = "number" }
    },

    outputs = {
        { id = "out", type = "string" },
        { id = "changed", type = "boolean", pulse = true }
    },

    args = chooseArgs,

    init = function(node, args)
        node.memory.idx = 0
        node.currentState.out = args.s0 or ""
        node.nextState.out = args.s0 or ""
    end,

    oninputschanged = function(ctx, node, args)
        local last = 0
        for i = 0, cSlots - 1 do
            if (args["s" .. i] or "") ~= "" then last = i end
        end

        local idx = math.floor(ctx:Read(node, "index") + 0.5)
        idx = math.Clamp(idx, 0, last)
        if node.memory.idx == idx then return end

        node.memory.idx = idx
        ctx:Write(node, "out", args["s" .. idx] or "")
        ctx:Pulse(node, "changed")
    end
})

--MARK: ONCE RESET
BATTLEBEATS.RegisterNode("logic.ONCE_RESET", {
    category = "Logic",
    title = "Once (Resettable)",
    desc = "Passes only the first pulse. Later pulses go to 'blocked' until a pulse arrives on 'reset'. Reset wins if both arrive in the same tick",

    inputs = {
        { id = "in", type = "boolean" },
        { id = "reset", type = "boolean" }
    },

    outputs = {
        { id = "out", type = "boolean", pulse = true },
        { id = "blocked", type = "boolean", pulse = true }
    },

    init = function(node)
        node.memory.fired = false
    end,

    oninputschanged = function(ctx, node)
        local m = node.memory
        local v, r = ctx:ReadBool(node, "in"), ctx:ReadBool(node, "reset")
        local oldV, oldR = m.oldIn or false, m.oldReset or false
        m.oldIn, m.oldReset = v, r

        if r and not oldR then m.fired = false end
        if v and not oldV then
            if m.fired then
                ctx:Pulse(node, "blocked")
            else
                m.fired = true
                ctx:Pulse(node, "out")
            end
        end
    end
})
