--MARK: BUFFER
BATTLEBEATS.RegisterNode("logic.BUFFER", {
    category = "Logic",
    title = "Buffer",
    desc = "Delays a signal by 1 tick",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "number" }
    },

    oninputschanged = function(ctx, node)
        ctx:Write(node, "out", ctx:Read(node, "in"))
    end
})

--MARK: LOGIC GATES
local function gate(class, title, desc, fn, startHigh)
    BATTLEBEATS.RegisterNode(class, {
        category = "Logic Gates",
        title = title,
        icon = "nodegraph/lg/" .. title .. ".png",
        desc = desc,

        inputs = {
            { id = "a", type = "number" },
            { id = "b", type = "number" }
        },

        outputs = {
            { id = "out", type = "boolean" }
        },

        oninputschanged = function(ctx, node)
            local a = ctx:ReadBool(node, "a")
            local b = ctx:ReadBool(node, "b")
            ctx:Write(node, "out", fn(a, b) and 1 or 0)
        end,

        init = startHigh and function(node)
            node.currentState.out = 1
            node.nextState.out = 1
        end or nil
    })
end

gate("logic.AND", "AND",
    "Outputs true only when both inputs are true",
    function(a, b) return a and b end)

gate("logic.NAND", "NAND",
    "Outputs false only when both inputs are true",
    function(a, b) return not (a and b) end, true)

gate("logic.OR", "OR",
    "Outputs true when at least one input is true",
    function(a, b) return a or b end)

gate("logic.NOR", "NOR",
    "Outputs true only when all inputs are false",
    function(a, b) return not (a or b) end, true)

gate("logic.XOR", "XOR",
    "Outputs true when exactly one input is true",
    function(a, b) return a ~= b end)

gate("logic.XNOR", "XNOR",
    "Outputs true when both inputs have the same value",
    function(a, b) return a == b end)

--MARK: NOT
BATTLEBEATS.RegisterNode("logic.NOT", {
    category = "Logic Gates",
    title = "NOT",
    icon = "nodegraph/lg/NOT.png",
    desc = "Inverts the input value",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "boolean" }
    },

    oninputschanged = function(ctx, node)
        local v = ctx:ReadBool(node, "in")
        ctx:Write(node, "out", v and 0 or 1)
    end,

    init = function(node)
        node.currentState.out = 1
        node.nextState.out = 1
    end,
})

--MARK: FALLING EDGE
BATTLEBEATS.RegisterNode("logic.FALLING_EDGE", {
    category = "Logic",
    title = "Falling Edge Pulse",
    desc = "Emits a pulse when the input changes from true to false",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "boolean", pulse = true }
    },

    oninputschanged = function(ctx, node)
        local v = ctx:ReadBool(node, "in")
        local old = node.memory.old or false
        if old and not v then
            ctx:Pulse(node, "out")
        end
        node.memory.old = v
    end
})

--MARK: RISING EDGE
BATTLEBEATS.RegisterNode("logic.RISING_EDGE", {
    category = "Logic",
    title = "Rising Edge Pulse",
    desc = "Emits a pulse when the input changes from false to true",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "boolean", pulse = true }
    },

    oninputschanged = function(ctx, node)
        local v = ctx:ReadBool(node, "in")
        local old = node.memory.old or false
        if not old and v then
            ctx:Pulse(node, "out")
        end
        node.memory.old = v
    end
})

--MARK: TOGGLE
BATTLEBEATS.RegisterNode("logic.TOGGLE", {
    category = "Logic",
    title = "Toggle",
    desc = "Toggles its state whenever a pulse is received. Output is false (0) by default",

    inputs = {
        { id = "toggle", type = "number" }
    },

    outputs = {
        { id = "state", type = "boolean" }
    },

    oninputschanged = function(ctx, node)
        local v = ctx:ReadBool(node, "toggle")
        local old = node.memory.old or false

        if not old and v then
            node.memory.state = not node.memory.state
        end

        node.memory.old = v
        ctx:Write(node, "state", node.memory.state and 1 or 0)
    end,

    init = function(node)
        node.memory.state = false
    end
})

--MARK: TRUE
BATTLEBEATS.RegisterNode("logic.TRUE", {
    category = "Logic",
    title = "TRUE",
    desc = "Outputs true (1) continuously",

    outputs = {
        { id = "out", type = "boolean" }
    },

    init = function(node)
        node.currentState.out = 1
        node.nextState.out = 1
    end
})

--MARK: FALSE
BATTLEBEATS.RegisterNode("logic.FALSE", {
    category = "Logic",
    title = "FALSE",
    desc = "Outputs false (0) continuously",

    outputs = {
        { id = "out", type = "boolean" }
    },

    init = function(node)
        node.currentState.out = 0
        node.nextState.out = 0
    end
})

--MARK: ONCE
BATTLEBEATS.RegisterNode("logic.ONCE", {
    category = "Logic",
    title = "Once",
    desc = "Passes pulse only once per runtime",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "boolean", pulse = true }
    },

    oninputschanged = function(ctx, node)
        if node.memory.fired then return end
        if ctx:ReadBool(node, "in") then
            node.memory.fired = true
            ctx:Pulse(node, "out")
        end
    end,

    init = function(node)
        node.memory.fired = false
    end
})

--MARK: HOLD
BATTLEBEATS.RegisterNode("logic.HOLD", {
    category = "Logic",
    title = "Hold",
    desc = "Blocks the signal for the first N ticks after runtime starts",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "number" }
    },

    args = {
        { id = "ticks", title = "Ticks", type = "number", default = 10, min = 0 }
    },

    init = function(node, args)
        node.memory.left = args.ticks or 10
        node.nextState.out = 0
    end,

    tick = function(ctx, node)
        local left = node.memory.left
        if left and left > 0 then
            left = left - 1
            node.memory.left = left
            if left == 0 then
                ctx:Write(node, "out", ctx:Read(node, "in"))
            end
        end
    end,

    oninputschanged = function(ctx, node)
        if (node.memory.left or 0) > 0 then
            ctx:Write(node, "out", 0)
        else
            ctx:Write(node, "out", ctx:Read(node, "in"))
        end
    end,

    shutdown = function(ctx, node)
        node.memory.left = nil
    end
})

--MARK: DELAY
local function delayTick(ctx, node, delay)
    local q = node.memory.queue
    if not q then return end

    q.last = q.last + 1
    q[q.last] = ctx:Read(node, "in")

    if q.last - q.first + 1 > delay then
        ctx:Write(node, "out", q[q.first])

        q[q.first] = nil
        q.first = q.first + 1

        if q.first > q.last then
            q.first = 1
            q.last = 0
        end
    end
end

--MARK: DELAY TICK
BATTLEBEATS.RegisterNode("logic.DELAY_TICKS", {
    category = "Logic",
    title = "Delay (Ticks)",
    desc = "Delays the input signal by the specified number of ticks",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "number" }
    },

    args = {
        { id = "ticks", title = "Ticks", type = "number", default = 10, min = 0 }
    },

    init = function(node)
        node.memory.queue = { first = 1, last = 0 }
    end,

    tick = function(ctx, node, args)
        delayTick(ctx, node, math.max(math.floor(args.ticks or 0), 0))
    end,

    shutdown = function(ctx, node)
        node.memory.queue = nil
    end
})

--MARK: DELAY SECOND
BATTLEBEATS.RegisterNode("logic.DELAY_SECONDS", {
    category = "Logic",
    title = "Delay (Seconds)",
    desc = "Delays the input signal by the specified number of seconds",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "number" }
    },

    args = {
        { id = "sec", title = "Seconds", type = "number", default = 10, min = 0 }
    },

    init = function(node)
        node.memory.queue = { first = 1, last = 0 }
    end,

    tick = function(ctx, node, args)
        delayTick(ctx, node, math.max(math.floor((args.sec or 0) / BATTLEBEATS.TickInterval + 0.5), 0))
    end,

    shutdown = function(ctx, node)
        node.memory.queue = nil
    end
})

--MARK: COMPARATOR
local compareOps = {
    ["=="] = function(a, b) return a == b end,
    ["!="] = function(a, b) return a ~= b end,
    [">"]  = function(a, b) return a > b end,
    ["<"]  = function(a, b) return a < b end,
    [">="] = function(a, b) return a >= b end,
    ["<="] = function(a, b) return a <= b end
}

BATTLEBEATS.RegisterNode("logic.COMPARATOR", {
    category = "Logic",
    title = "Comparator",
    desc = "Compares A input to B input values",

    inputs = {
        { id = "a", type = "number" },
        { id = "b", type = "number" }
    },

    outputs = {
        { id = "out", type = "boolean" }
    },

    args = {
        {id = "useConstant", title = "Compare with Constant (B)", type = "bool", default = false},
        {id = "constant", title = "Constant", type = "number", default = 0, enabled = "useConstant"},
        {id = "op", title = "Operator (A -> B)", type = "list", default = "==", choices = {"==", "!=", ">", "<", ">=", "<="}, show = true}
    },

    visiblePins = function(args)
        if args.useConstant then
            return {
                inputs = {
                    b = false
                }
            }
        end
    end,

    oninputschanged = function(ctx, node, args)
        local fn = compareOps[args.op]
        if not fn then return end
        local a = ctx:Read(node, "a")
        local b
        if args.useConstant then
            b = args.constant or 0
        else
            b = ctx:Read(node, "b")
        end
        ctx:Write(node, "out", fn(a, b) and 1 or 0)
    end
})

--MARK: SELECT
BATTLEBEATS.RegisterNode("logic.SELECT", {
    category = "Logic",
    title = "Select",
    desc = "Selects one of two inputs based on the condition. 'A' if condition is false (0) or 'B' if true (1)",

    inputs = {
        { id = "a", type = "number" },
        { id = "b", type = "number" },
        { id = "condition", type = "boolean" }
    },

    outputs = {
        { id = "out", type = "number" }
    },

    oninputschanged = function(ctx, node)
        if ctx:ReadBool(node, "condition") then
            ctx:Write(node, "out", ctx:Read(node, "b"))
        else
            ctx:Write(node, "out", ctx:Read(node, "a"))
        end
    end
})

--MARK: ON CHANGED
BATTLEBEATS.RegisterNode("logic.ON_CHANGED", {
    category = "Logic",
    title = "On Changed",
    desc = "Emits a pulse whenever the input value changes",

    inputs = {
        { id = "in", type = "number" }
    },

    outputs = {
        { id = "out", type = "boolean", pulse = true }
    },

    oninputschanged = function(ctx, node)
        local v = ctx:Read(node, "in")
        local old = node.memory.old
        if old ~= nil and old ~= v then
            ctx:Pulse(node, "out")
        end
        node.memory.old = v
    end
})

--MARK: LUA (wip)
BATTLEBEATS.RegisterNode("logic.LUA", {
    category = "Logic",
    title = "Script",
    desc = "Work in progress - not implemented yet",

    inputs = {
        { id = "a", type = "number" },
        { id = "b", type = "number" },
        { id = "c", type = "number" },
        { id = "d", type = "number" },
        { id = "e", type = "number" },
        { id = "f", type = "number" },
        { id = "g", type = "string" },
        { id = "h", type = "string" },
    },

    outputs = {
        { id = "i", type = "number" },
        { id = "j", type = "number" },
        { id = "k", type = "number" },
        { id = "l", type = "number" },
        { id = "m", type = "number", pulse = true },
        { id = "n", type = "number", pulse = true },
        { id = "o", type = "string" },
        { id = "p", type = "string" },
    },

    oninputschanged = function(ctx, node)
        --
    end
})
