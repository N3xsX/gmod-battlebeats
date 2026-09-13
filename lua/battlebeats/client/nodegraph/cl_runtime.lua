local btb = BATTLEBEATS

btb.Nodes = btb.Nodes or {}
btb.NodeCategories = btb.NodeCategories or {}
btb.ActiveRuntime = btb.ActiveRuntime or nil
btb.TickInterval = 0.1
btb.ZoneTickInterval = 0.5
btb.ZoneState = btb.ZoneState or {current = {}}

local function fuck(msg)
    ErrorNoHaltWithStack("[BattleBeats Nodes] " .. msg .. "\n")
end

local combiners = {}
combiners.max = function(ctx, links, default)
    local value
    for _, link in ipairs(links) do
        local src = ctx.nodes[link.node]
        if src then
            local v = src.currentState[link.output]
            if v ~= nil then
                value = value and math.max(value, v) or v
            end
        end
    end
    return value or default or 0
end
combiners.min = function(ctx, links, default)
    local value
    for _, link in ipairs(links) do
        local src = ctx.nodes[link.node]
        if src then
            local v = src.currentState[link.output]
            if v ~= nil then
                value = value and math.min(value, v) or v
            end
        end
    end
    return value or default or 0
end
combiners.sum = function(ctx, links, default)
    local value = 0
    local hasAny = false
    for _, link in ipairs(links) do
        local src = ctx.nodes[link.node]
        if src then
            value = value + (src.currentState[link.output] or 0)
            hasAny = true
        end
    end
    return hasAny and value or default or 0
end
combiners.avg = function(ctx, links, default)
    local sum = 0
    local count = 0
    for _, link in ipairs(links) do
        local src = ctx.nodes[link.node]
        if src then
            local v = src.currentState[link.output]
            if v ~= nil then
                sum = sum + v
                count = count + 1
            end
        end
    end
    return count > 0 and sum / count or default or 0
end

local pt = {
    boolean = true,
    number = true,
    string = true
}

local pf = {
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
            fuck(class .. " has " .. kind .. " without id")
            return {}
        end
        if ids[pin.id] then
            fuck(class .. " has duplicated pin: " .. pin.id)
            return {}
        end
        if kind == "input" and pin.pulse then
            fuck(class .. " " .. kind .. " pin '" .. pin.id .. "' has incorrect field 'pulse'")
            return {}
        end
        local t = pin.type or "number"
        if not pt[t] then
            fuck(class .. " " .. kind .. " pin '" .. pin.id .. "' has invalid type '" .. t .. "'")
            return {}
        end
        local cb
        if t == "string" then
            if pin.combine ~= nil then
                fuck(class .. " " .. kind .. " pin '" .. pin.id .. "' has incorrect field 'combiner'")
                return {}
            end
        else
            cb = pin.combine or "max"
            if not combiners[cb] then
                fuck(class .. " " .. kind .. " pin '" .. pin.id .. "' uses unknown combiner '" .. cb .. "'")
                return {}
            end
        end
        for k in pairs(pin) do
            if not pf[k] then
                fuck(class .. " " .. kind .. " pin '" .. pin.id .. "' has unknown field '" .. k .. "'")
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

local at = {
    string = true,
    number = true,
    bool = true,
    list = true,
}

local af = {
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
            fuck(class .. " has arg without id")
            return {}
        end
        if ids[arg.id] then
            fuck(class .. " has duplicated arg: " .. arg.id)
            return {}
        end
        local t = arg.type or "string"
        if not at[t] then
            fuck(class .. " '" .. arg.id .. "' has invalid type '" .. t .. "'")
            return {}
        end
        if t ~= "number" then
            if arg.min ~= nil then
                fuck(class .. " arg '" .. arg.id .. "' has incorrect field 'min'")
                return {}
            end
            if arg.max ~= nil then
                fuck(class .. " arg '" .. arg.id .. "' has incorrect field 'max'")
                return {}
            end
        end
        for k in pairs(arg) do
            if not af[k] then
                fuck(class .. " arg '" .. arg.id .. "' has unknown field '" .. k .. "'")
                return {}
            end
        end
        if t == "list" then
            if not arg.choices then
                fuck(class .. " arg '" .. arg.id .. "' uses type 'list' but is missing 'choices'")
                return {}
            end
            if not istable(arg.choices) or #arg.choices == 0 then
                fuck(class .. " arg '" .. arg.id .. "' has invalid choices")
                return {}
            end
        else
            if arg.choices then
                fuck(class .. " arg '" .. arg.id .. "' has incorrect field 'choices'")
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
                fuck(class .. " arg '" .. arg.id .. "' 'enabled' field must be a string")
                return {}
            end
            if not ids[arg.enabled] then
                fuck(class .. " arg '" .. arg.id .. "' references unknown enabled arg '" .. arg.enabled .. "'")
                return {}
            end
        end
    end
    return out
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

--MARK: Create Runtime
local function sizeeeeeeeeeeeeeeeeee(v, seen)
    seen = seen or {}
    local t = type(v)
    if t == "table" then
        if seen[v] then return 0 end
        seen[v] = true
        local b = 56
        for k, val in pairs(v) do
            b = b + sizeeeeeeeeeeeeeeeeee(k, seen)
            b = b + sizeeeeeeeeeeeeeeeeee(val, seen)
            b = b + 16
        end
        return b
    end
    if t == "string" then return #v + 24 end
    if t == "number" then return 8 end
    if t == "boolean" then return 1 end
    if t == "function" then return 0 end
    if t == "userdata" then return 8 end
    return 0
end

function btb.CompileRuntime(...)
    local out = {nodes = {}, links = {}}
    local nodeMap = {}
    local nextId = 1
    for _, data in ipairs({ ... }) do
        for _, node in ipairs(data.nodes or {}) do
            local newId = nextId
            nextId = nextId + 1
            nodeMap[node.id] = newId
            out.nodes[#out.nodes + 1] = {
                id = newId,
                class = node.class,
                args = table.Copy(node.args or {})
            }
        end
        for _, link in ipairs(data.links or {}) do
            out.links[#out.links + 1] = {
                fromNode = nodeMap[link.fromNode],
                fromOutput = link.fromOutput,
                toNode = nodeMap[link.toNode],
                toInput = link.toInput
            }
        end
        table.Empty(nodeMap)
    end
    return out
end

function btb.CreateRuntime(data)
    print("[BattleBeats Runtime] Creating new runtime...")
    local ctx = {
        nodes = {},
        nodeList = {},
        tickNodes = {},
        links = {},
        listeners = {},
        classIndex = {},
        argIndex = {},
        changed = {},
        tick = 0,
        running = false,

        --debugEnabled = data.debug == true,
        debugEnabled = true,

        debug = {
            ticks = {},
            cur = nil,
            stack = {},
            maxTicks = 1000,

            reads = true,
            writes = true,
            propagation = true,
            calls = true,
            errors = true,
            change = true
        }
    }
    if ctx.debugEnabled then
        print("[Runtime] Debug mode enabled...")
    end

    function ctx:Read(node, inputId, default)
        local nLinks = self.links[node.id]
        if not nLinks then return default or 0 end

        local iLinks = nLinks[inputId]
        if not iLinks then return default or 0 end

        local i = node.def.inputMap[inputId]
        if not i then return default or 0 end

        if i.type == "string" then
            local link = iLinks[1]
            if not link then return default or "" end

            local src = self.nodes[link.node]
            if not src then return default or "" end

            local v = src.currentState[link.output]

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

        local cb = combiners[i.combine or "max"]
        if not cb then return default or 0 end

        local v = cb(self, iLinks, default)

        if self.debugEnabled then
            self:Dbg("read", {
                node = node.id,
                input = inputId,
                combine = i.combine or "max",
                value = v
            })
        end

        return v
    end

    function ctx:ReadBool(node, inputId)
        return tobool(self:Read(node, inputId, 0))
    end

    function ctx:ReadString(node, inputId, default)
        local v = ctx:Read(node, inputId, default)
        return v == nil and "" or tostring(v)
    end

    function ctx:Write(node, output, value)
        node.nextState[output] = value == nil and 1 or value
        if not self.debugEnabled then return end
        self:Dbg("write", { node = node.id, class = node.class, output = output, value = value })
    end

    function ctx:Call(node, handler, ...)
        local f = node.def.handlers[handler]

        if not f then
            self:Error(node, "No handler '%s'", handler)
            return
        end

        if not self.debugEnabled then
            return f(self, node, ...)
        end

        local eid = self:Dbg("call", {
            node = node.id,
            class = node.class,
            handler = handler
        })

        self:DbgPush(eid)
        local ok, a, b, c = xpcall(f, debug.traceback, self, node, ...)
        self:DbgPop()

        if not ok then
            self:Error(node, "Handler '%s' crashed:\n%s", handler, a)
            return
        end

        return a, b, c
    end

    function ctx:Error(node, msg, trace, ...)
        local s = { ... }
        if #s > 0 then msg = string.format(msg, unpack(s)) end
        local eid = self:Dbg("error", {
            node = node and node.id,
            class = node and node.class,
            message = msg,
            trace = trace
        })
        print(string.format("[BattleBeats RT Error] [Node %s | %s | tick %d] %s", tostring(node and node.id or "?"), tostring(node and node.class or "Runtime"), self.tick, msg))
        return eid
    end

    function ctx:Warn(node, msg, ...)
        local s = { ... }
        if #s > 0 then msg = string.format(msg, unpack(s)) end
        local p = node and string.format("[Node: %s | %s | tick %d]", tostring(node.id), tostring(node.class), self.tick) or string.format("[Runtime | tick %d]", self.tick)
        print(string.format("[BattleBeats RT Warn] %s %s", p, msg))
    end

    function ctx:Dbg(event, data, parent)
        if not self.debugEnabled then return end
        local d = self.debug
        if event == "read" and not d.reads then return end
        if event == "write" and not d.writes then return end
        if event == "propagate" and not d.propagation then return end
        if event == "call" and not d.calls then return end
        if event == "error" and not d.errors then return end
        if event == "change" and not d.change then return end
        local e = { id = #d.cur.events + 1, type = event, tick = self.tick, parent = parent or d.stack[#d.stack], data = data }
        d.cur.events[#d.cur.events + 1] = e
        if event == "change" then
            print(string.format("[BattleBeats RT Debug] %d [STATE] %s.%s %s -> %s", self.tick, data.node, data.output, tostring(data.old), tostring(data.new)))
        end
        return e.id
    end

    function ctx:DbgPush(id)
        if self.debugEnabled then
            local stack = self.debug.stack
            stack[#stack + 1] = id
        end
    end

    function ctx:DbgPop()
        if self.debugEnabled then
            local stack = self.debug.stack
            stack[#stack] = nil
        end
    end

    function ctx:DbgTickStart()
        if not self.debugEnabled then return end

        local d = self.debug
        d.cur = { tick = self.tick, events = {} }
        d.ticks[#d.ticks + 1] = d.cur

        while #d.ticks > d.maxTicks do
            table.remove(d.ticks, 1)
        end

        table.Empty(d.stack)
    end

    function ctx:DebugDump(tick)
        local d = self.debug
        if not self.debugEnabled then
            print("[BattleBeats RT Debug] Runtime debug mode is disabled")
            return
        end
        local t
        if tick then
            for i = #d.ticks, 1, -1 do
                if d.ticks[i].tick == tick then
                    t = d.ticks[i]
                    break
                end
            end
        else
            t = d.cur
        end

        if not t then
            print("[BattleBeats RT Debug] No debug data for tick " .. tostring(tick or "?"))
            return
        end

        local ch = {}
        for _, e in ipairs(t.events) do
            local p = e.parent
            if istable(p) then
                p = p[1]
            end
            p = p or 0
            ch[p] = ch[p] or {}
            ch[p][#ch[p] + 1] = e
        end

        local function fmt(v)
            if istable(v) then return util.TableToJSON(v, false) or "{}" end
            if v == nil then return "nil" end
            return tostring(v)
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
                print(s .. string.format("[%d] CHANGE %s.%s %s -> %s", e.id, d.node, d.output, fmt(d.old), fmt(d.new)))
            elseif e.type == "propagate" then
                print(s .. string.format("[%d] PROPAGATE %s.%s -> %s.%s", e.id, d.from, d.output, d.to, d.input))
            elseif e.type == "input" then
                print(s .. string.format("[%d] INPUT %s (%s)%s", e.id, d.node, d.class, src))
            elseif e.type == "call" then
                print(s .. string.format("[%d] CALL %s.%s", e.id, d.node, d.handler))
            elseif e.type == "read" then
                print(s .. string.format("[%d] READ %s.%s = %s", e.id, d.node, d.input, fmt(d.value)))
            elseif e.type == "write" then
                print(s .. string.format("[%d] WRITE %s.%s = %s", e.id, d.node, d.output, fmt(d.value)))
            elseif e.type == "error" then
                print(s .. string.format("[%d] ERROR %s", e.id, d.message))
                if d.trace then
                    print(s .. "    " .. string.gsub(d.trace, "\n", "\n" .. s .. "    "))
                end
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
            if istable(p) then
                p = p[1]
            end
            if not p then
                printEvent(e, 0, seen)
            end
        end

        print("[BattleBeats RT Debug] ===== END =====")
    end

    function ctx:DebugDumpAll()
        local d = self.debug
        if not self.debugEnabled then
            print("[BattleBeats RT Debug] Runtime debug mode is disabled")
            return
        end
        if #d.ticks == 0 then
            print("[BattleBeats RT Debug] No debug data")
            return
        end
        local count = 0
        for _, t in ipairs(d.ticks) do
            if #t.events > 0 then
                count = count + 1
                self:DebugDump(t.tick)
            end
        end
        if count == 0 then
            print("[BattleBeats RT Debug] No debug events")
            return
        end
        print(string.format("[BattleBeats RT Debug] Dumped %d/%d ticks", count, #d.ticks))
    end

    print("[Runtime] Creating node instances...")

    for _, n in ipairs(data.nodes or {}) do
        local inst = btb.CreateNodeInstance(n.class, n.id, n.args)
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

    print("[Runtime] Creating links...")

    for _, l in ipairs(data.links or {}) do
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

    print("[Runtime] Initializing 'currentState'")

    for i = 1, #ctx.nodeList do
        local node = ctx.nodeList[i]
        for k, v in pairs(node.nextState) do
            node.currentState[k] = v
        end
    end

    if ctx.debugEnabled then
        print(string.format("[BattleBeats Runtime] Ready (%d nodes, %d links)", table.Count(ctx.nodes), #(data.links or {})))
        local bytes = sizeeeeeeeeeeeeeeeeee(ctx)
        print(string.format("[BattleBeats Runtime] Estimated memory usage: %.1f KB", bytes / 1024))
    end

    return ctx
end

local function getChangedInputs(ctx, nodeId)
    local inputs = ctx.changed[nodeId]
    if not inputs then
        inputs = {}; ctx.changed[nodeId] = inputs
    end
    return inputs
end

--MARK: Runtime tick
function btb.TickRuntime(ctx)
    if not ctx then return end

    ctx.tick = ctx.tick + 1
    ctx:DbgTickStart()

    hook.Run("BattleBeats_PreRuntimeTick", ctx)

    for i = 1, #ctx.tickNodes do
        local node = ctx.tickNodes[i]
        node.def.tick(ctx, node, node.args)
    end

    table.Empty(ctx.changed)

    for i = 1, #ctx.nodeList do
        local node = ctx.nodeList[i]
        for outputId, value in pairs(node.nextState) do
            local old = node.currentState[outputId]
            if old ~= value then
                local sid
                if ctx.debugEnabled then
                    sid = ctx:Dbg("change", {
                        node = node.id,
                        class = node.class,
                        output = outputId,
                        old = old,
                        new = value
                    })
                end
                local listeners = ctx.listeners[node.id]
                listeners = listeners and listeners[outputId]
                if listeners then
                    for _, link in ipairs(listeners) do
                        local inputs = getChangedInputs(ctx, link.node)
                        local propagations = inputs[link.input]
                        if not propagations then
                            propagations = {}
                            inputs[link.input] = propagations
                        end
                        local p = {node = node.id, output = outputId, value = value}
                        if ctx.debugEnabled then
                            p.debug = ctx:Dbg("propagate", {
                                from = node.id,
                                output = outputId,
                                to = link.node,
                                input = link.input
                            }, sid)
                        end
                        propagations[#propagations + 1] = p
                    end
                end
            end
            node.currentState[outputId] = value
        end
    end

    for i = 1, #ctx.nodeList do
        local node = ctx.nodeList[i]
        local def = node.def
        if def then
            for _, out in ipairs(def.outputs or {}) do
                if out.pulse then
                    node.nextState[out.id] = 0
                else
                    node.nextState[out.id] = node.currentState[out.id] or 0
                end
            end
        end
    end

    for nodeId, changedInputs in pairs(ctx.changed) do
        local node = ctx.nodes[nodeId]
        local def = node.def
        if def and def.oninputschanged then
            if ctx.debugEnabled then
                local parents = {}

                for _, propagations in pairs(changedInputs) do
                    for _, p in ipairs(propagations) do
                        if p.debug then
                            parents[#parents + 1] = p.debug
                        end
                    end
                end
                table.sort(parents)

                local eid = ctx:Dbg("input", {
                    node = node.id,
                    class = node.class,
                    inputs = changedInputs
                }, parents)

                ctx:DbgPush(eid)

                local cid = ctx:Dbg("call", {
                    node = node.id,
                    class = node.class,
                    handler = "oninputschanged"
                })

                ctx:DbgPush(cid)

                local ok, err = xpcall(def.oninputschanged, debug.traceback, ctx, node, node.args, changedInputs)

                ctx:DbgPop()
                ctx:DbgPop()

                if not ok then
                    ctx:Error(node, "Handler 'oninputschanged' crashed:\n%s", err)
                end
            else
                def.oninputschanged(ctx, node, node.args, changedInputs)
            end
        end
    end

    hook.Run("BattleBeats_PostRuntimeTick", ctx)
end

concommand.Add("btb_runtime_dump_debug", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local ctx = btb.ActiveRuntime
    if not ctx then
        print("[BattleBeats RT Debug] No runtime")
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

        ctx._accum = (ctx._accum or 0) + FrameTime()

        local steps = 0
        while ctx._accum >= btb.TickInterval and steps < 10 do
            ctx._accum = ctx._accum - btb.TickInterval
            btb.TickRuntime(ctx)
            steps = steps + 1
        end

        if steps >= 10 then
            ctx._accum = 0
        end

        ctx._zoneAccum = (ctx._zoneAccum or 0) + FrameTime()
        if ctx._zoneAccum >= btb.ZoneTickInterval then
            ctx._zoneAccum = 0
            btb.TickZones()
        end
    end)
end

function btb.StopClock()
    hook.Remove("Think", "BattleBeats_MainClock")
end

function btb.LoadRuntime(data)
    if table.IsEmpty(data.nodes) then
        print("[BattleBeats Runtime] Runtime data is empty")
        return
    end
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
                pcall(d.shutdown, ctx, n)
            end
        end
    end
    btb.ClearRuntime()
end

local a = {
    category = true,
    title = true,
    icon = true,
    desc = true,
    inputs = true,
    outputs = true,
    args = true,
    tick = true,
    init = true,
    oninputschanged = true,
    shutdown = true
}

local function checkthisshit(class, def)
    if not isstring(class) or class == "" then
        fuck("class needs to be a string")
        return false
    end
    if btb.Nodes[class] then 
        fuck("node already exists: " .. class)
        return false
    end
    if not istable(def) then 
        fuck(class .. " def must be a table")
        return false
    end
    if (not istable(def.inputs) or #def.inputs == 0) and (not istable(def.outputs) or #def.outputs == 0) then
        fuck(class .. " has no inputs and outputs")
        return false
    end
    if def.category ~= nil and not isstring(def.category) then
        fuck(class .. ".category must be a string")
        return false
    end
    if def.title ~= nil and not isstring(def.title) then
        fuck(class .. ".title must be a string")
        return false
    end
    if def.desc ~= nil and not isstring(def.desc) then
        fuck(class .. ".desc must be a string")
        return false
    end
    if def.icon ~= nil and not isstring(def.icon) then
        fuck(class .. ".icon must be a string")
        return false
    end
    if def.inputs ~= nil and not istable(def.inputs) then
        fuck(class .. ".inputs must be a table")
        return false
    end
    if def.outputs ~= nil and not istable(def.outputs) then
        fuck(class .. ".outputs must be a table")
        return false
    end
    if def.args ~= nil and not istable(def.args) then
        fuck(class .. ".args must be a table")
        return false
    end
    if def.tick and not isfunction(def.tick) then
        fuck(class .. ".tick must be a function")
        return false
    end
    if def.init and not isfunction(def.init) then
        fuck(class .. ".init must be a function")
        return false
    end
    if def.oninputschanged and not isfunction(def.oninputschanged) then
        fuck(class .. ".oninputschanged must be a function")
        return false
    end
    if def.shutdown and not isfunction(def.shutdown) then
        fuck(class .. ".shutdown must be a function")
        return false
    end
    if def.oninputschanged and (not istable(def.inputs) or #def.inputs == 0) then
        fuck(class .. " defines oninputschanged but has no inputs")
        return false
    end
    for k, v in pairs(def) do
        if isfunction(v) then
            --
        elseif not a[k] then
            fuck(class .. " has unknown field '" .. k .. "'")
            return false
        end
    end
    return true
end

--MARK: Register Node
function btb.RegisterNode(class, def)
    if not checkthisshit(class, def) then return end

    local inputs = normPins(def.inputs, "input", class)
    local outputs = normPins(def.outputs, "output", class)
    local ids = {}
    for _, pin in ipairs(inputs) do
        ids[pin.id] = true
    end
    for _, pin in ipairs(outputs) do
        if ids[pin.id] then
            fuck(class .. " uses the same pin id for both input and output: " .. pin.id)
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

        handlers = {}
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
    end

    for k, v in pairs(def) do
        if isfunction(v) and k ~= "tick" and k ~= "init" and k ~= "oninputschanged" and k ~= "shutdown" then
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
local function fireNode(node, outputId, value)
    value = value == nil and 1 or value
    if not node.def.outputMap[outputId] then
        return false, "missing output: " .. tostring(outputId)
    end
    node.nextState[outputId] = value
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
    return fireNode(node, outputId, value)
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
        local ok, err = fireNode(nodes[i], outputId, value)
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
        local ok, err = fireNode(nodes[i], outputId, value)
        if ok then
            count = count + 1
        else
            er = err
        end
    end
    if count > 0 then return true, count end
    return false, er or ("missing node class: " .. tostring(class))
end

--MARK: Create Instance
function btb.CreateNodeInstance(class, id, args)
    local def = btb.GetNode(class)
    if not def then fuck("unidentified node: " .. tostring(class)) end

    local aa = {}

    for _, arg in ipairs(def.args) do
        aa[arg.id] = args and args[arg.id]
        if aa[arg.id] == nil then aa[arg.id] = arg.default end
    end

    local inst = {
        id = id,
        class = class,
        def = def,

        currentState = {},
        nextState = {},

        memory = {},
        args = aa
    }

    for _, pin in ipairs(def.outputs) do
        inst.currentState[pin.id] = 0
        inst.nextState[pin.id] = 0
    end

    if def.init then def.init(inst, aa) end

    return inst
end
