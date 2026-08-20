--MARK: MATH
local mt = {}
mt.add = function(a, b)
    return a + b
end
mt.sub = function(a, b)
    return a - b
end
mt.mul = function(a, b)
    return a * b
end
mt.div = function(a, b)
    return b ~= 0 and a / b or 0
end
mt.mod = function(a, b)
    return b ~= 0 and a % b or 0
end
mt.pow = function(a, b)
    return a ^ b
end
mt.min = function(a, b, c)
    return math.min(a, b, c)
end
mt.max = function(a, b, c)
    return math.max(a, b, c)
end
mt.abs = function(a)
    return math.abs(a)
end
mt.floor = function(a)
    return math.floor(a)
end
mt.ceil = function(a)
    return math.ceil(a)
end
mt.sqrt = function(a)
    return math.sqrt(math.max(a, 0))
end
mt.sin = function(a)
    return math.sin(math.rad(a))
end
mt.cos = function(a)
    return math.cos(math.rad(a))
end
mt.tan = function(a)
    return math.tan(math.rad(a))
end
mt.clamp = function(a, b, c)
    return math.Clamp(a, b, c)
end

BATTLEBEATS.RegisterNode("logic.MATH", {
    category = "Logic",
    title = "Math",
    desc = "Performs mathematical operations",

    inputs = {
        { id = "a", type = "number" },
        { id = "b", type = "number" },
        { id = "c", type = "number" }
    },

    outputs = {
        { id = "out", type = "number" }
    },

    args = {
        {
            id = "op",
            title = "Operation",
            type = "list",
            default = "add",
            choices = {
                "add",
                "sub",
                "mul",
                "div",
                "mod",
                "pow",
                "min",
                "max",
                "abs",
                "floor",
                "ceil",
                "sqrt",
                "sin",
                "cos",
                "tan",
                "clamp"
            },
            show = true
        }
    },

    visiblePins = function(args)
        local op = args.op
        if op == "abs" or op == "floor" or op == "ceil" or op == "sqrt" or op == "sin" or op == "cos" or op == "tan" then
            return {
                inputs = {
                    b = false,
                    c = false
                }
            }
        elseif op == "clamp" or op == "min" or op == "max" then
            return
        else
            return {
                inputs = {
                    c = false
                }
            }
        end
    end,

    oninputschanged = function(ctx, node, args)
        local fn = mt[args.op]
        if not fn then return end
        local a = ctx:Read(node, "a")
        local b = ctx:Read(node, "b")
        local c = ctx:Read(node, "c")
        ctx:Write(node, "out", fn(a, b, c))
    end
})
