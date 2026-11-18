local btb = BATTLEBEATS

btb.Nodes = btb.Nodes or {}
btb.NodeCategories = btb.NodeCategories or {}
btb.ActiveRuntime = btb.ActiveRuntime or nil
btb.TickInterval = 0.1
btb.ZoneTickInterval = 0.5
btb.ZoneState = btb.ZoneState or {current = {}}

local dbg = CreateClientConVar("btb_runtime_debug", "0", true, false, "")

local function nodeError(msg)
    ErrorNoHaltWithStack("[BattleBeats Nodes] " .. msg .. "\n")
end

local function nodeWarn(msg)
    btb.print(2, "Runtime", "Warning:", msg)
end

--MARK: Combiners
local function makeCombiner(step, finish)
    return function(ctx, links, default)
        local acc, count = nil, 0
        local nodes = ctx.nodes
        for i = 1, #links do
            local link = links[i]
            local src = nodes[link.node]
            local v = src and src.currentState[link.output]
            if v ~= nil then
                acc = step(acc, v)
                count = count + 1
            end
        end
        if count == 0 then return default or 0 end
        if finish then return finish(acc, count) end
        return acc
    end
end

local combiners = {
    max = makeCombiner(function(a, v)
        if a == nil or v > a then return v end
        return a
    end),
    min = makeCombiner(function(a, v)
        if a == nil or v < a then return v end
        return a
    end),
    sum = makeCombiner(function(a, v)
        return (a or 0) + v
    end),
    avg = makeCombiner(function(a, v)
        return (a or 0) + v
    end, function(a, n)
        return a / n
    end)
}

--MARK: Pin / arg normalization
local validPinTypes = {
    boolean = true,
    number = true,
    string = true
}

local validPinFields = {
    id = true,
    type = true,
    title = true,
    pulse = true,
    combine = true
}

local function normPins(list, kind, class)
    local out, ids = {}, {}

    for _, pin in ipairs(list or {}) do
        if not pin.id then
            nodeError(class .. " has " .. kind .. " without id")
            return {}
        end
        if ids[pin.id] then
            nodeError(class .. " has duplicated pin: " .. pin.id)
            return {}
        end
        if kind == "input" and pin.pulse then
            nodeError(class .. " " .. kind .. " pin '" .. pin.id .. "' has incorrect field 'pulse'")
            return {}
        end
        local t = pin.type or "number"
        if not validPinTypes[t] then
            nodeError(class .. " " .. kind .. " pin '" .. pin.id .. "' has invalid type '" .. t .. "'")
            return {}
        end
        local cb
        if t == "string" then
            if pin.combine ~= nil then
                nodeError(class .. " " .. kind .. " pin '" .. pin.id .. "' has incorrect field 'combine'")
                return {}
            end
        else
            cb = pin.combine or "max"
            if not combiners[cb] then
                nodeError(class .. " " .. kind .. " pin '" .. pin.id .. "' uses unknown combiner '" .. cb .. "'")
                return {}
            end
        end
        for k in pairs(pin) do
            if not validPinFields[k] then
                nodeError(class .. " " .. kind .. " pin '" .. pin.id .. "' has unknown field '" .. k .. "'")
                return {}
            end
        end

        ids[pin.id] = true
        out[#out + 1] = {
            id = pin.id,
            type = t,
            title = pin.title or pin.id,
            pulse = pin.pulse == true,
            combine = cb
        }
    end
    return out
end

local validArgTypes = {
    string = true,
    number = true,
    bool = true,
    list = true,
}

local validArgFields = {
    id = true,
    type = true,
    title = true,
    default = true,
    choices = true,
    min = true,
    max = true,
    enabled = true,
    show = true
}

local function normArgs(list, class)
    local out, ids = {}, {}

    for _, arg in ipairs(list or {}) do
        if not arg.id then
            nodeError(class .. " has arg without id")
            return {}
        end
        if ids[arg.id] then
            nodeError(class .. " has duplicated arg: " .. arg.id)
            return {}
        end
        local t = arg.type or "string"
        if not validArgTypes[t] then
            nodeError(class .. " '" .. arg.id .. "' has invalid type '" .. t .. "'")
            return {}
        end
        if t ~= "number" then
            if arg.min ~= nil then
                nodeError(class .. " arg '" .. arg.id .. "' has incorrect field 'min'")
                return {}
            end
            if arg.max ~= nil then
                nodeError(class .. " arg '" .. arg.id .. "' has incorrect field 'max'")
                return {}
            end
        end
        for k in pairs(arg) do
            if not validArgFields[k] then
                nodeError(class .. " arg '" .. arg.id .. "' has unknown field '" .. k .. "'")
                return {}
            end
        end
        if t == "list" then
            if not arg.choices then
                nodeError(class .. " arg '" .. arg.id .. "' uses type 'list' but is missing 'choices'")
                return {}
            end
            if not istable(arg.choices) or #arg.choices == 0 then
                nodeError(class .. " arg '" .. arg.id .. "' has invalid choices")
                return {}
            end
        else
            if arg.choices then
                nodeError(class .. " arg '" .. arg.id .. "' has incorrect field 'choices'")
                return {}
            end
        end

        ids[arg.id] = true
        out[#out + 1] = {
            id = arg.id,
            type = t,
            title = arg.title or arg.id,
            default = arg.default,
            choices = arg.choices,
            min = arg.min or nil,
            max = arg.max or nil,
            enabled = arg.enabled or nil,
            show = arg.show or false
        }
    end

    for _, arg in ipairs(out) do
        if arg.enabled ~= nil then
            if not isstring(arg.enabled) then
                nodeError(class .. " arg '" .. arg.id .. "' 'enabled' field must be a string")
                return {}
            end
            if not ids[arg.enabled] then
                nodeError(class .. " arg '" .. arg.id .. "' references unknown enabled arg '" .. arg.enabled .. "'")
                return {}
            end
        end
    end
    return out
end

local function coerceArg(arg, v)
    if v == nil then return arg.default end
    local t = arg.type
    if t == "number" then
        v = tonumber(v)
        if not v or v ~= v then return arg.default end
        if arg.min then v = math.max(v, arg.min) end
        if arg.max then v = math.min(v, arg.max) end
        return v
    elseif t == "bool" then
        return v == true or v == 1 or v == "1" or v == "true"
    elseif t == "list" then
        for _, c in ipairs(arg.choices) do
            if c == v then return v end
        end
        return arg.default
    end
    return tostring(v)
end

-- Link validation
local function checkLink(fromDef, fromOutput, toDef, toInput)
    local o = fromDef.outputMap[fromOutput]
    if not o then
        return false, fromDef.class .. " has no output '" .. tostring(fromOutput) .. "'"
    end
    local i = toDef.inputMap[toInput]
    if not i then
        return false, toDef.class .. " has no input '" .. tostring(toInput) .. "'"
    end
    if (o.type == "string") ~= (i.type == "string") then
        return false, string.format("type mismatch %s.%s (%s) -> %s.%s (%s)", fromDef.class, fromOutput, o.type, toDef.class, toInput, i.type)
    end
    return true
end

local function coerce(pin, v)
    if pin.type == "string" then
        return v == nil and "" or tostring(v)
    end
    if v == true then
        v = 1
    elseif v == false or v == nil then
        v = 0
    end
    v = tonumber(v) or 0
    if v ~= v or v == math.huge or v == -math.huge then v = 0 end
    if pin.type == "boolean" then v = v ~= 0 and 1 or 0 end
    return v
end

function btb.SetRuntime(ctx)
    btb.ActiveRuntime = ctx
end

function btb.GetRuntime()
    return btb.ActiveRuntime
end

function btb.ClearRuntime()
    btb.ActiveRuntime = nil
end

--MARK: Runtime context
local CTX = {}
CTX.__index = CTX

function CTX:MarkDirty(node)
    if node.dirty then return end
    node.dirty = true
    local list = self.dirtyList
    list[#list + 1] = node
end

function CTX:IsLinked(node, inputId)
    local nl = self.links[node.id]
    local il = nl and nl[inputId]
    return il ~= nil and #il > 0
end

function CTX:Read(node, inputId, default)
    local pin = node.def.inputMap[inputId]
    if not pin then
        self:Error(node, "Read: unknown input '%s'", tostring(inputId))
        return default or 0
    end

    local isString = pin.type == "string"
    local fallback = default
    if fallback == nil then fallback = isString and "" or 0 end

    local nl = self.links[node.id]
    local il = nl and nl[inputId]
    if not il or #il == 0 then return fallback end

    if isString then
        local link = il[1]
        local src = self.nodes[link.node]
        local v = src and src.currentState[link.output]
        if v == nil then v = fallback end

        if self.debugEnabled then
            self:Dbg("read", {
                node = node.id,
                input = inputId,
                from = link.node,
                output = link.output,
                value = v
            })
        end

        return v
    end

    local v = combiners[pin.combine or "max"](self, il, fallback)

    if self.debugEnabled then
        self:Dbg("read", {
            node = node.id,
            input = inputId,
            combine = pin.combine or "max",
            value = v
        })
    end

    return v
end

-- Returns nil when the input has no links
function CTX:ReadOptional(node, inputId)
    if not self:IsLinked(node, inputId) then return nil end
    return self:Read(node, inputId)
end

function CTX:ReadBool(node, inputId)
    local pin = node.def.inputMap[inputId]
    if pin and pin.type == "string" then
        return self:Read(node, inputId, "") ~= ""
    end
    return self:Read(node, inputId, 0) ~= 0
end

function CTX:ReadString(node, inputId, default)
    local v = self:Read(node, inputId, default)
    return v == nil and "" or tostring(v)
end

function CTX:Write(node, output, value)
    local pin = node.def.outputMap[output]
    if not pin then
        self:Error(node, "Write: unknown output '%s'", tostring(output))
        return
    end
    if value == nil and pin.pulse then value = 1 end
    value = coerce(pin, value)
    node.nextState[output] = value
    self:MarkDirty(node)
    if self.debugEnabled then
        self:Dbg("write", { node = node.id, class = node.class, output = output, value = value })
    end
end

function CTX:Pulse(node, output)
    self:Write(node, output, 1)
end

function CTX:Error(node, msg, ...)
    if select("#", ...) > 0 then msg = string.format(msg, ...) end
    local eid = self:Dbg("error", {
        node = node and node.id,
        class = node and node.class,
        message = msg
    })
    print(string.format("[BattleBeats RT Error] [Node %s | %s | tick %d] %s", tostring(node and node.id or "?"), tostring(node and node.class or "Runtime"), self.tick, msg))
    return eid
end

function CTX:Warn(node, msg, ...)
    if select("#", ...) > 0 then msg = string.format(msg, ...) end
    local p = node and string.format("[Node: %s | %s | tick %d]", tostring(node.id), tostring(node.class), self.tick) or string.format("[Runtime | tick %d]", self.tick)
    print(string.format("[BattleBeats RT Warn] %s %s", p, msg))
end

function CTX:Invoke(node, name, fn, ...)
    if node.disabled then return end

    local eid
    if self.debugEnabled then
        eid = self:Dbg("call", { node = node.id, class = node.class, handler = name })
        self:DbgPush(eid)
    end

    local ok, a, b, c = xpcall(fn, debug.traceback, ...)

    self:DbgPop(eid)

    if ok then
        node.errCount = 0
        return a, b, c
    end

    node.errCount = (node.errCount or 0) + 1
    self:Error(node, "Handler '%s' crashed:\n%s", name, tostring(a))
    if node.errCount >= 5 then
        node.disabled = true
        self:Error(node, "Node disabled after %d consecutive errors", 5)
    end
end

function CTX:Call(node, handler, ...)
    local f = node.def.handlers[handler]
    if not f then
        self:Error(node, "No handler '%s'", handler)
        return
    end
    return self:Invoke(node, handler, f, self, node, ...)
end

--MARK: Debug tracing
function CTX:Dbg(event, data, parent)
    if not self.debugEnabled then return end
    local d = self.debug
    if not d.cur then return end
    if event == "read" and not d.reads then return end
    if event == "write" and not d.writes then return end
    if event == "propagate" and not d.propagation then return end
    if event == "call" and not d.calls then return end
    if event == "error" and not d.errors then return end
    if event == "change" and not d.change then return end
    local e = { id = #d.cur.events + 1, type = event, tick = self.tick, parent = parent or d.stack[#d.stack], data = data }
    d.cur.events[#d.cur.events + 1] = e
    if event == "change" and d.printChanges then
        print(string.format("[BattleBeats RT Debug] %d [STATE] %s.%s %s -> %s", self.tick, data.node, data.output, tostring(data.old), tostring(data.new)))
    end
    return e.id
end

function CTX:DbgPush(id)
    if not id then return end
    local stack = self.debug.stack
    stack[#stack + 1] = id
end

function CTX:DbgPop(id)
    if not id then return end
    local stack = self.debug.stack
    stack[#stack] = nil
end

function CTX:DbgTickStart()
    if not self.debugEnabled then return end
    local d = self.debug
    d.cur = { tick = self.tick, events = {} }
    table.Empty(d.stack)
end

-- Only ticks that produced events are stored
function CTX:DbgTickEnd()
    if not self.debugEnabled then return end
    local d = self.debug
    if not d.cur or #d.cur.events == 0 then return end
    d.head = d.head % d.maxTicks + 1
    d.ring[d.head] = d.cur
    d.count = math.min(d.count + 1, d.maxTicks)
end

local function ringList(d)
    local out = {}
    local start = d.count < d.maxTicks and 1 or (d.head % d.maxTicks + 1)
    for i = 0, d.count - 1 do
        out[#out + 1] = d.ring[(start - 1 + i) % d.maxTicks + 1]
    end
    return out
end

local function fmtValue(v)
    if istable(v) then return util.TableToJSON(v, false) or "{}" end
    if v == nil then return "nil" end
    return tostring(v)
end

local function dumpTick(t)
    local ch = {}
    for _, e in ipairs(t.events) do
        local p = e.parent
        if istable(p) then p = p[1] end
        p = p or 0
        ch[p] = ch[p] or {}
        ch[p][#ch[p] + 1] = e
    end

    local function printEvent(e, depth, seen)
        if seen[e.id] then return end
        seen[e.id] = true

        local d = e.data or {}
        local s = string.rep("  ", depth)

        local src = ""
        if istable(e.parent) then
            local x = {}
            for _, id in ipairs(e.parent) do
                x[#x + 1] = "#" .. id
            end
            src = " <- " .. table.concat(x, ", ")
        elseif e.parent then
            src = " <- #" .. e.parent
        end

        if e.type == "change" then
            print(s .. string.format("[%d] CHANGE %s.%s %s -> %s", e.id, d.node, d.output, fmtValue(d.old), fmtValue(d.new)))
        elseif e.type == "propagate" then
            print(s .. string.format("[%d] PROPAGATE %s.%s -> %s.%s", e.id, d.from, d.output, d.to, d.input))
        elseif e.type == "input" then
            print(s .. string.format("[%d] INPUT %s (%s)%s", e.id, d.node, d.class, src))
        elseif e.type == "call" then
            print(s .. string.format("[%d] CALL %s.%s", e.id, d.node, d.handler))
        elseif e.type == "read" then
            print(s .. string.format("[%d] READ %s.%s = %s", e.id, d.node, d.input, fmtValue(d.value)))
        elseif e.type == "write" then
            print(s .. string.format("[%d] WRITE %s.%s = %s", e.id, d.node, d.output, fmtValue(d.value)))
        elseif e.type == "error" then
            print(s .. string.format("[%d] ERROR %s", e.id, d.message))
        end

        local list = ch[e.id]
        if list then
            for _, x in ipairs(list) do
                printEvent(x, depth + 1, seen)
            end
        end
    end

    print(string.format("[BattleBeats RT Debug] ===== TICK %d =====", t.tick))

    local seen = {}
    for _, e in ipairs(t.events) do
        local p = e.parent
        if istable(p) then p = p[1] end
        if not p then
            printEvent(e, 0, seen)
        end
    end

    print("[BattleBeats RT Debug] ===== END =====")
end

function CTX:DebugDump(tick)
    local d = self.debug
    if not self.debugEnabled then
        btb.print(2, "Runtime Debug", "Runtime debug mode is disabled (set btb_runtime_debug 1)")
        return
    end
    local t
    if tick then
        if d.cur and d.cur.tick == tick then
            t = d.cur
        else
            local list = ringList(d)
            for i = #list, 1, -1 do
                if list[i].tick == tick then
                    t = list[i]
                    break
                end
            end
        end
    else
        t = d.cur
    end

    if not t then
        btb.print(1, "Runtime Debug", "No debug data for tick", tostring(tick or "?"))
        return
    end
    dumpTick(t)
end

function CTX:DebugDumpAll()
    local d = self.debug
    if not self.debugEnabled then
        btb.print(2, "Runtime Debug", "Runtime debug mode is disabled (set btb_runtime_debug 1)")
        return
    end
    if d.count == 0 then
        btb.print(1, "Runtime Debug", "No debug data")
        return
    end
    local list = ringList(d)
    for _, t in ipairs(list) do
        dumpTick(t)
    end
    btb.print(1, "Runtime Debug", string.format("Dumped %d ticks", #list))
end

--MARK: Compile Runtime
-- Merges graphs into one runtime description. Unknown classes and invalid links are skipped with an error
function btb.CompileRuntime(...)
    local out = {nodes = {}, links = {}}
    local nextId = 1
    local classOf = {}
    local skipped = 0

    for _, data in ipairs({ ... }) do
        local nodeMap = {}
        for _, node in ipairs(data.nodes or {}) do
            local def = btb.GetNode(node.class)
            if not def then
                nodeError("CompileRuntime: skipping node '" .. tostring(node.id) .. "' of unknown class '" .. tostring(node.class) .. "'")
                skipped = skipped + 1
            else
                local newId = nextId
                nextId = nextId + 1
                nodeMap[node.id] = newId
                classOf[newId] = def
                out.nodes[#out.nodes + 1] = {
                    id = newId,
                    class = node.class,
                    args = table.Copy(node.args or {})
                }
            end
        end
        for _, link in ipairs(data.links or {}) do
            local from, to = nodeMap[link.fromNode], nodeMap[link.toNode]
            local ok, err
            if not from or not to then
                ok, err = false, "link references a missing node"
            else
                ok, err = checkLink(classOf[from], link.fromOutput, classOf[to], link.toInput)
            end
            if ok then
                out.links[#out.links + 1] = {
                    fromNode = from,
                    fromOutput = link.fromOutput,
                    toNode = to,
                    toInput = link.toInput
                }
            else
                nodeError("CompileRuntime: skipping link: " .. err)
                skipped = skipped + 1
            end
        end
    end
    return out, skipped
end

--MARK: Create Instance
function btb.CreateNodeInstance(class, id, args)
    local def = btb.GetNode(class)
    if not def then nodeError("unidentified node: " .. tostring(class)) return end

    local aa = {}
    for _, arg in ipairs(def.args) do
        aa[arg.id] = coerceArg(arg, args and args[arg.id])
    end

    local inst = {
        id = id,
        class = class,
        def = def,

        currentState = {},
        nextState = {},

        memory = {},
        args = aa,

        dirty = false,
        disabled = false,
        errCount = 0
    }

    for _, pin in ipairs(def.outputs) do
        local zero = pin.type == "string" and "" or 0
        inst.currentState[pin.id] = zero
        inst.nextState[pin.id] = zero
    end

    if def.init then
        local ok, err = xpcall(def.init, debug.traceback, inst, aa)
        if not ok then
            nodeError("init of " .. class .. " (node " .. tostring(id) .. ") crashed:\n" .. tostring(err))
            inst.disabled = true
        end
    end

    return inst
end

--MARK: Create Runtime
function btb.CreateRuntime(data)
    btb.print(1, "Runtime", "Creating new runtime...")
    local memBefore = collectgarbage("count")

    local ctx = setmetatable({
        nodes = {},
        nodeList = {},
        tickNodes = {},
        links = {},
        listeners = {},
        classIndex = {},
        argIndex = {},
        changed = {},

        dirtyList = {},
        dirtySpare = {},

        tick = 0,
        running = false,
        firstTick = true,

        debugEnabled = dbg:GetBool(),

        debug = {
            ring = {},
            head = 0,
            count = 0,
            cur = nil,
            stack = {},
            maxTicks = 1000,

            printChanges = true,
            reads = true,
            writes = true,
            propagation = true,
            calls = true,
            errors = true,
            change = true
        }
    }, CTX)

    for _, n in ipairs(data.nodes or {}) do
        if ctx.nodes[n.id] then
            nodeError("duplicated node id: " .. tostring(n.id))
        else
            local inst = btb.CreateNodeInstance(n.class, n.id, n.args)
            if inst then
                ctx.nodes[n.id] = inst
                ctx.nodeList[#ctx.nodeList + 1] = inst

                if inst.def.tick then
                    ctx.tickNodes[#ctx.tickNodes + 1] = inst
                end

                local cls = ctx.classIndex[inst.class]
                if not cls then
                    cls = {}
                    ctx.classIndex[inst.class] = cls
                end
                cls[#cls + 1] = inst

                local c = ctx.argIndex[inst.class]
                if not c then
                    c = {}
                    ctx.argIndex[inst.class] = c
                end

                for argId, argValue in pairs(inst.args) do
                    local t = type(argValue)
                    if t == "string" or t == "number" or t == "boolean" then
                        local a = c[argId]
                        if not a then
                            a = {}
                            c[argId] = a
                        end
                        local v = a[argValue]
                        if not v then
                            v = {}
                            a[argValue] = v
                        end
                        v[#v + 1] = inst
                    end
                end
            end
        end
    end

    for _, l in ipairs(data.links or {}) do
        local from, to = ctx.nodes[l.fromNode], ctx.nodes[l.toNode]
        local ok, err
        if not from or not to then
            ok, err = false, "link references a missing node"
        else
            ok, err = checkLink(from.def, l.fromOutput, to.def, l.toInput)
        end

        if not ok then
            nodeError("Skipping link: " .. err)
        else
            local links = ctx.links
            local listeners = ctx.listeners

            local nlinks = links[l.toNode] or {}
            links[l.toNode] = nlinks
            local ilinks = nlinks[l.toInput] or {}
            nlinks[l.toInput] = ilinks
            ilinks[#ilinks + 1] = {node = l.fromNode, output = l.fromOutput}

            local nlisteners = listeners[l.fromNode] or {}
            listeners[l.fromNode] = nlisteners
            local olisteners = nlisteners[l.fromOutput] or {}
            nlisteners[l.fromOutput] = olisteners
            olisteners[#olisteners + 1] = {node = l.toNode, input = l.toInput}
        end
    end

    for i = 1, #ctx.nodeList do
        local node = ctx.nodeList[i]
        for k, v in pairs(node.nextState) do
            node.currentState[k] = v
        end
    end

    btb.print(1, "Runtime", string.format("Ready (%d nodes)", #ctx.nodeList))
    if ctx.debugEnabled then
        local kb = math.max(collectgarbage("count") - memBefore, 0)
        btb.print(2, "Runtime Debug", string.format("[BattleBeats Runtime] Approx. memory usage: %.1f KB", kb))
    end

    return ctx
end

local function getChangedInputs(ctx, nodeId)
    local inputs = ctx.changed[nodeId]
    if not inputs then
        inputs = {}
        ctx.changed[nodeId] = inputs
    end
    return inputs
end

--MARK: Runtime tick
function btb.TickRuntime(ctx)
    if not ctx then return end

    ctx.tick = ctx.tick + 1
    ctx.debugEnabled = dbg:GetBool()
    ctx:DbgTickStart()

    hook.Run("BattleBeats_PreRuntimeTick", ctx)

    -- 1) tick nodes write their outputs
    local tickNodes = ctx.tickNodes
    for i = 1, #tickNodes do
        local node = tickNodes[i]
        ctx:Invoke(node, "tick", node.def.tick, ctx, node, node.args)
    end

    table.Empty(ctx.changed)

    -- 2) commit nextState -> currentState (only for nodes that wrote something) and propagate changes
    local list = ctx.dirtyList
    ctx.dirtyList = ctx.dirtySpare
    ctx.dirtySpare = list

    local debugOn = ctx.debugEnabled
    for i = 1, #list do
        local node = list[i]
        node.dirty = false
        local cur = node.currentState

        for outputId, value in pairs(node.nextState) do
            local old = cur[outputId]
            if old ~= value then
                local sid
                if debugOn then
                    sid = ctx:Dbg("change", {
                        node = node.id,
                        class = node.class,
                        output = outputId,
                        old = old,
                        new = value
                    })
                end
                local nl = ctx.listeners[node.id]
                local ol = nl and nl[outputId]
                if ol then
                    for j = 1, #ol do
                        local link = ol[j]
                        local inputs = getChangedInputs(ctx, link.node)
                        local props = inputs[link.input]
                        if not props then
                            props = {}
                            inputs[link.input] = props
                        end
                        local p = {node = node.id, output = outputId, value = value}
                        if debugOn then
                            p.debug = ctx:Dbg("propagate", {
                                from = node.id,
                                output = outputId,
                                to = link.node,
                                input = link.input
                            }, sid)
                        end
                        props[#props + 1] = p
                    end
                end
                cur[outputId] = value
            end
        end

        -- pulses fall back to 0 on the next tick
        local pulses = node.def.pulseOutputs
        for j = 1, #pulses do
            local pin = pulses[j]
            local zero = pin.type == "string" and "" or 0
            if cur[pin.id] ~= zero then
                node.nextState[pin.id] = zero
                ctx:MarkDirty(node)
            end
        end
    end
    for i = #list, 1, -1 do
        list[i] = nil
    end

    -- 3) on the very first tick every node evaluates its inputs once,
    -- so constants settle without waiting for a change
    if ctx.firstTick then
        ctx.firstTick = false
        local nodeList = ctx.nodeList
        for i = 1, #nodeList do
            local n = nodeList[i]
            if n.def.oninputschanged then getChangedInputs(ctx, n.id) end
        end
    end

    -- 4) nodes with changed inputs react
    local nodeList = ctx.nodeList
    local changed = ctx.changed
    for i = 1, #nodeList do
        local node = nodeList[i]
        local inputs = changed[node.id]
        if inputs then
            local fn = node.def.oninputschanged
            if fn and not node.disabled then
                if debugOn then
                    local parents = {}
                    for _, props in pairs(inputs) do
                        for _, p in ipairs(props) do
                            if p.debug then
                                parents[#parents + 1] = p.debug
                            end
                        end
                    end
                    table.sort(parents)

                    local eid = ctx:Dbg("input", {
                        node = node.id,
                        class = node.class,
                        inputs = inputs
                    }, parents)

                    ctx:DbgPush(eid)
                    ctx:Invoke(node, "oninputschanged", fn, ctx, node, node.args, inputs)
                    ctx:DbgPop(eid)
                else
                    ctx:Invoke(node, "oninputschanged", fn, ctx, node, node.args, inputs)
                end
            end
        end
    end

    ctx:DbgTickEnd()

    hook.Run("BattleBeats_PostRuntimeTick", ctx)
end

concommand.Add("btb_runtime_dump_debug", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local ctx = btb.ActiveRuntime
    if not ctx then
        btb.print(2, "Runtime Debug", "No runtime")
        return
    end
    local tick = tonumber(args[1])
    if tick then
        ctx:DebugDump(tick)
    else
        ctx:DebugDumpAll()
    end
end)

function btb.StartClock()
    btb.StopClock()
    btb.FireNodeByClass("event.RUNTIME_START", "out")
    hook.Add("Think", "BattleBeats_MainClock", function()
        local ctx = btb.GetRuntime()
        if not ctx then return end

        local ft = FrameTime()
        ctx._accum = (ctx._accum or 0) + ft

        local steps = 0
        while ctx._accum >= btb.TickInterval and steps < 10 do
            ctx._accum = ctx._accum - btb.TickInterval
            btb.TickRuntime(ctx)
            steps = steps + 1
        end

        if steps >= 10 then
            ctx._accum = 0
        end

        ctx._zoneAccum = (ctx._zoneAccum or 0) + ft
        if ctx._zoneAccum >= btb.ZoneTickInterval then
            ctx._zoneAccum = 0
            if btb.TickZones then btb.TickZones() end
        end
    end)
end

function btb.StopClock()
    hook.Remove("Think", "BattleBeats_MainClock")
end

function btb.LoadRuntime(data)
    if not istable(data) or not istable(data.nodes) or table.IsEmpty(data.nodes) then
        btb.print(2, "Runtime", "Runtime data is empty")
        return
    end

    if btb.GetRuntime() then btb.UnloadRuntime() end

    local ctx = btb.CreateRuntime(data)
    btb.SetRuntime(ctx)
    btb.StartClock()
    ctx.running = true
    return ctx
end

function btb.UnloadRuntime()
    btb.StopClock()
    local ctx = btb.GetRuntime()
    if ctx then
        ctx.running = false
        for _, n in pairs(ctx.nodes) do
            local d = n.def
            if d and d.shutdown then
                local ok, err = pcall(d.shutdown, ctx, n)
                if not ok then
                    print(string.format("[BattleBeats RT Error] shutdown of %s (node %s) failed: %s", tostring(n.class), tostring(n.id), tostring(err)))
                end
            end
        end
    end
    btb.ClearRuntime()
end

--MARK: Node definition validation
local allowedFields = {
    category = true,
    title = true,
    icon = true,
    desc = true,
    inputs = true,
    outputs = true,
    args = true,
    handlers = true,
    visiblePins = true,
    tick = true,
    init = true,
    oninputschanged = true,
    shutdown = true
}

local coreFunctions = {
    tick = true,
    init = true,
    oninputschanged = true,
    shutdown = true
}

local knownFunctions = {
    tick = true,
    init = true,
    oninputschanged = true,
    shutdown = true,
    visiblePins = true
}

local function validateDef(class, def)
    if not isstring(class) or class == "" then
        nodeError("class needs to be a string")
        return false
    end
    if btb.Nodes[class] then
        nodeError("node already exists: " .. class)
        return false
    end
    if not istable(def) then
        nodeError(class .. " def must be a table")
        return false
    end
    if (not istable(def.inputs) or #def.inputs == 0) and (not istable(def.outputs) or #def.outputs == 0) then
        nodeError(class .. " has no inputs and outputs")
        return false
    end
    if def.category ~= nil and not isstring(def.category) then
        nodeError(class .. ".category must be a string")
        return false
    end
    if def.title ~= nil and not isstring(def.title) then
        nodeError(class .. ".title must be a string")
        return false
    end
    if def.desc ~= nil and not isstring(def.desc) then
        nodeError(class .. ".desc must be a string")
        return false
    end
    if def.icon ~= nil and not isstring(def.icon) then
        nodeError(class .. ".icon must be a string")
        return false
    end
    if def.inputs ~= nil and not istable(def.inputs) then
        nodeError(class .. ".inputs must be a table")
        return false
    end
    if def.outputs ~= nil and not istable(def.outputs) then
        nodeError(class .. ".outputs must be a table")
        return false
    end
    if def.args ~= nil and not istable(def.args) then
        nodeError(class .. ".args must be a table")
        return false
    end
    if def.handlers ~= nil then
        if not istable(def.handlers) then
            nodeError(class .. ".handlers must be a table")
            return false
        end
        for k, v in pairs(def.handlers) do
            if not isfunction(v) then
                nodeError(class .. ".handlers." .. tostring(k) .. " must be a function")
                return false
            end
        end
    end
    if def.visiblePins ~= nil and not isfunction(def.visiblePins) then
        nodeError(class .. ".visiblePins must be a function")
        return false
    end
    if def.tick and not isfunction(def.tick) then
        nodeError(class .. ".tick must be a function")
        return false
    end
    if def.init and not isfunction(def.init) then
        nodeError(class .. ".init must be a function")
        return false
    end
    if def.oninputschanged and not isfunction(def.oninputschanged) then
        nodeError(class .. ".oninputschanged must be a function")
        return false
    end
    if def.shutdown and not isfunction(def.shutdown) then
        nodeError(class .. ".shutdown must be a function")
        return false
    end
    if def.oninputschanged and (not istable(def.inputs) or #def.inputs == 0) then
        nodeError(class .. " defines oninputschanged but has no inputs")
        return false
    end
    for k, v in pairs(def) do
        if isfunction(v) then
            if not knownFunctions[k] then
                nodeWarn(class .. " has unknown function field '" .. tostring(k) .. "' (treated as a custom handler; put custom handlers in 'handlers = {}' to silence this - or check for a typo in tick/init/oninputschanged/shutdown)")
            end
        elseif not allowedFields[k] then
            nodeError(class .. " has unknown field '" .. tostring(k) .. "'")
            return false
        end
    end
    return true
end

--MARK: Register Node
function btb.RegisterNode(class, def)
    if not validateDef(class, def) then return end

    local inputs = normPins(def.inputs, "input", class)
    local outputs = normPins(def.outputs, "output", class)
    local ids = {}
    for _, pin in ipairs(inputs) do
        ids[pin.id] = true
    end
    for _, pin in ipairs(outputs) do
        if ids[pin.id] then
            nodeError(class .. " uses the same pin id for both input and output: " .. pin.id)
            return
        end
    end

    local node = {
        class = class,

        category = def.category or "Other",
        title = def.title or class,
        icon = def.icon or nil,
        desc = def.desc or "",

        inputs = inputs,
        outputs = outputs,
        args = normArgs(def.args, class),

        tick = def.tick,
        init = def.init,
        oninputschanged = def.oninputschanged,
        shutdown = def.shutdown,
        visiblePins = def.visiblePins,

        handlers = {},
        pulseOutputs = {}
    }

    node.inputMap = {}
    for i, input in ipairs(node.inputs) do
        input.index = i
        node.inputMap[input.id] = input
    end

    node.outputMap = {}
    for i, output in ipairs(node.outputs) do
        output.index = i
        node.outputMap[output.id] = output
        if output.pulse then
            node.pulseOutputs[#node.pulseOutputs + 1] = output
        end
    end

    if istable(def.handlers) then
        for k, v in pairs(def.handlers) do
            node.handlers[k] = v
        end
    end
    for k, v in pairs(def) do
        if isfunction(v) and not coreFunctions[k] then
            node.handlers[k] = v
        end
    end

    btb.Nodes[class] = node
    btb.NodeCategories[node.category] = btb.NodeCategories[node.category] or {}
    btb.NodeCategories[node.category][class] = node

    return node
end

function btb.GetNode(class)
    return btb.Nodes[class]
end

--MARK: Fire Node
local function fireNode(ctx, node, outputId, value)
    local pin = node.def.outputMap[outputId]
    if not pin then
        return false, "missing output: " .. tostring(outputId)
    end
    if value == nil and pin.type ~= "string" then value = 1 end
    ctx:Write(node, outputId, value)
    return true
end

function btb.FireNode(nodeId, outputId, value)
    local ctx = btb.GetRuntime()
    if not ctx then
        return false, "missing active runtime"
    end
    local node = ctx.nodes[nodeId]
    if not node then
        return false, "missing node: " .. tostring(nodeId)
    end
    return fireNode(ctx, node, outputId, value)
end

function btb.FireNodeByClass(class, outputId, value)
    local ctx = btb.GetRuntime()
    if not ctx then return false, "missing active runtime" end
    local count = 0
    local er
    local nodes = ctx.classIndex[class]
    if not nodes then
        if not btb.GetNode(class) then
            return false, "unknown node class: " .. tostring(class)
        else
            return false, "no runtime nodes of class: " .. tostring(class)
        end
    end
    for i = 1, #nodes do
        local ok, err = fireNode(ctx, nodes[i], outputId, value)
        if ok then
            count = count + 1
        else
            er = err
        end
    end
    if count > 0 then return true, count end
    return false, er or ("missing node class: " .. tostring(class))
end

function btb.FireNodeByClassArg(class, outputId, value, argId, argValue)
    local ctx = btb.GetRuntime()
    if not ctx then return false, "missing active runtime" end
    local count = 0
    local er
    local nodes = ctx.argIndex[class]
    nodes = nodes and nodes[argId]
    nodes = nodes and nodes[argValue]
    if not nodes then
        if not btb.GetNode(class) then
            return false, "unknown node class: " .. tostring(class)
        else
            return false, "no runtime nodes of class: " .. tostring(class)
        end
    end
    for i = 1, #nodes do
        local ok, err = fireNode(ctx, nodes[i], outputId, value)
        if ok then
            count = count + 1
        else
            er = err
        end
    end
    if count > 0 then return true, count end
    return false, er or ("missing node class: " .. tostring(class))
end
