-- ive might overengineered this a little bit

local btb = BATTLEBEATS

local envCheckInterval = 0.5
local envTraceDist = 2000
local envSampleDist = 400

local envOpenness = 5
local envScore = 1
local lastEnvOpenness = envOpenness

local envFadeVolume = {
    [1] = 0.6,
    [2] = 0.7,
    [3] = 0.85,
    [4] = nil
}

local dynamicVolme = GetConVar("battlebeats_dynamic_volume")
local dynamicVolEnv = CreateClientConVar("battlebeats_dynamic_volume_env", "1", true, false, "", 0, 1)
local roomAcoustics = CreateClientConVar("battlebeats_dsp_env", "1", true, false, "", 0, 1)
local roomAcousticsStr = CreateClientConVar("battlebeats_dsp_env_strength", "0.8", true, false, "", 0, 1)
local roomAcousticsEcho = CreateClientConVar("battlebeats_dsp_env_echo", "1", true, false, "", 0, 1)
local roomAcousticsLim = CreateClientConVar("battlebeats_dsp_env_limiter", "1", true, false, "", 0, 1)
local roomAcousticsClutter = CreateClientConVar("battlebeats_dsp_env_clutter", "0", true, false, "", 0, 1)

local exs = type(render.GetLightColor) == "function"
local function getLight(pos)
    if not exs then return 1 end
    local c = render.GetLightColor(pos)
    return math.Clamp(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, 0, 1) -- relative luminance
end

local function getLightFactor(l)
    local ll = math.Clamp(l / 0.1, 0, 1) ^ 0.3
    if ll >= 0.75 then return 1 end
    if ll >= 0.5 then return 0.8 end
    return math.Round(ll, 2)
end

local function getLightScore(pos, ply)
    local a = ply:EyeAngles()
    local f = a:Forward()
    local r = a:Right()
    local u = a:Up()
    local d = 64
    local ps = {pos, pos + f * d, pos - f * d, pos + r * d, pos - r * d, pos + u * d, pos - u * d}
    local ls = {}
    for _, p in ipairs(ps) do
        local tr = util.TraceLine({ start = pos, endpos = p, filter = ply, mask = MASK_SOLID })
        if not tr.Hit then ls[#ls + 1] = getLight(p) end
    end
    if #ls == 0 then return getLight(pos) end
    table.sort(ls)
    return ls[math.min(2, #ls)]
end

local function getViewScore(pos, ply)
    local a = ply:EyeAngles()
    local f = a:Forward()
    local r = a:Right()
    local u = a:Up()
    local ds = {f, (f + r * 0.35):GetNormalized(), (f - r * 0.35):GetNormalized(), (f + r * 0.7):GetNormalized(), (f - r * 0.7):GetNormalized(), (f + u * 0.35):GetNormalized(), (f - u * 0.35):GetNormalized()}
    local s = 0
    for _, d in ipairs(ds) do
        local tr = util.TraceLine({start = pos, endpos = pos + d * envTraceDist, filter = ply, mask = MASK_VISIBLE})
        s = s + (tr.Hit and tr.Fraction or 1)
    end
    return math.Round(s / #ds, 2)
end

local function traceSpace(pos, dir, ply)
    local tr = util.TraceLine({start = pos, endpos = pos + dir * envTraceDist, filter = ply, mask = MASK_SOLID_BRUSHONLY})
    local frac = tr.Hit and tr.Fraction or 1
    --debugoverlay.Line(pos, tr.HitPos, envCheckInterval + 0.1, tr.Hit and Color(255, 80, 80) or Color(80, 255, 80), false)
    return frac
end

local function checkEnvironment()
    if not dynamicVolme:GetBool() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local base = ply:EyePos()
    local floor = util.TraceLine({start = base, endpos = base - Vector(0, 0, 100), filter = ply, mask = MASK_SOLID_BRUSHONLY})
    local n = floor.Hit and floor.HitNormal or Vector(0, 0, 1)
    local f = Vector(0, 0, 1)
    if math.abs(n:Dot(f)) > 0.95 then f = Vector(1, 0, 0) end
    local t1 = f:Cross(n):GetNormalized()
    local t2 = n:Cross(t1):GetNormalized()
    local ds = {t1, -t1, t2, -t2, n}

    local function grid(pos, col)
        local ss = {pos, pos + t1 * envSampleDist, pos - t1 * envSampleDist, pos + t2 * envSampleDist, pos - t2 * envSampleDist}
        local total = 0
        local count = 0
        for _, p in ipairs(ss) do
            local reach = util.TraceLine({start = pos, endpos = p, filter = ply, mask = MASK_SOLID})
            if not reach.Hit then
                --debugoverlay.Cross(p, 10, envCheckInterval + 0.1, col, false)
                for _, dir in ipairs(ds) do
                    total = total + traceSpace(p, dir, ply)
                    count = count + 1
                end
            end
        end
        return count > 0 and total / count or 0
    end

    local s1 = grid(base, Color(255, 220, 80))
    local s2 = grid(base + Vector(0, 0, envSampleDist), Color(180, 100, 255))
    local skyTrace = util.TraceLine({start = base, endpos = base + Vector(0, 0, 100000), filter = ply, mask = MASK_VISIBLE})

    if skyTrace.HitSky then s1 = s1 + 0.6 end

    --debugoverlay.Line(base, skyTrace.HitPos, envCheckInterval + 0.1, skyTrace.HitSky and Color(80, 180, 255) or Color(255, 80, 80), false)

    if ply:WaterLevel() == 3 then
        s1 = s1 - 2
    end

    local viewScore = getViewScore(base, ply) * 0.9
    local lightFactor = getLightFactor(getLightScore(base, ply))
    envScore = s1 * 0.75 + math.min(s1, s2) * 0.25
    envScore = envScore * lightFactor
    envScore = envScore + viewScore * (1 - envScore) * 0.35
    envOpenness = math.Clamp(math.floor(envScore * 7) + 1, 1, 4)

    if envOpenness ~= lastEnvOpenness then
        lastEnvOpenness = envOpenness
        btb.SetFade("environment", envFadeVolume[envOpenness], 1, false, true)
    end

    btb.Debug.Add("environment", false, function(d)
        d.sep()
        d.section("ENVIRONMENT")
        d.row("environment openess", envOpenness)
        d.row("view score", viewScore)
        d.row("light score", lightFactor)
        d.row("final score", math.Round(envScore, 2))
    end)
end

hook.Add("InitPostEntity", "BattleBeats_EnvironmentInit", function()
    if not dynamicVolEnv:GetBool() then return end
    timer.Create("BattleBeats_EnvironmentCheck", envCheckInterval, 0, checkEnvironment)
end)

cvars.AddChangeCallback("battlebeats_dynamic_volume_env", function(_, _, newValue)
    if tonumber(newValue) == 1 then
        timer.Create("BattleBeats_EnvironmentCheck", envCheckInterval, 0, checkEnvironment)
    elseif tonumber(newValue) == 0 then
        timer.Remove("BattleBeats_EnvironmentCheck")
        btb.Debug.Remove("environment")
        btb.SetFade("environment", nil, 1, false)
        lastEnvOpenness = -1
    end
end)

--MARK: room acoustics wip
if not (BassFX and BassFX.installed) then return end

-- tuning
local tick = 0.1
local perTick = 3 -- rays per batch

-- estimator: sliding window of the most recent rays, weighted by age and by distance from where they were cast
local window = 96 -- rays kept (~3 s at perTick / TICK)
local ageTau = 1.8 -- s, older rays count less (effective averaging time)
local ageMax = 9 -- s, rays older than this are ignored
local radius = 350 -- units, rays cast further than this from the player are ignored
local minWeight = 8 -- no estimate until this much ray weight has accumulated
local losPerTick = 4 -- old rays re-checked per tick: no line of sight to the player = other room, dropped
local losMinDist = 48 -- units, closer origins are always considered the same space

-- stability: a published value only changes when the new estimate differs by more than the band
local bandDB = 1.5 -- reverb mix [dB]
local bandTime = 150 -- reverb time [ms]
local bandEcho = 2 -- echo wet [%]
local bandDelay = 40 -- echo delay [ms]

-- reverb
local minDB, offDB, maxDB = -60, -55, -6
local maxWet = 0.5 -- cap on the linear reverb wet (0.5 = -6 dB)
local headroomDB = 3 -- input attenuation applied when the reverb is at its maximum
local reverbMinMS = 150
local reverbMaxMS = 3000 -- DX8 reverb limit
local eyringK = 0.04025 -- T60 = eyringK * meanFreePath / -ln(survival per bounce)
local nearM = 4 -- m, hits closer than this count as "confined"
local confBoost = 0.4 -- how much confinement raises/lowers the reverb level (0 = ignore)
local openPow = 0.5 -- reverb level *= (1 - open)^openPow (0 = ignore openness, 1 = linear)
local sizeRef = 5.5 -- m, mean free path at/above which the reverb level is not reduced
local sizePow = 2 -- how fast the level drops in smaller spaces (0 = ignore size)

local EQtau, FXtau = 0.25, 0.9 -- smoothing time constants [s]
local slowTau = 3 -- reverb time glides slowly
local swapTau = 0.4 -- s, fade-out of an echo that has to change its delay
local swapHold = 4 -- s, minimum time between echo delay swaps
local limTau = 0.5 -- s, limiter threshold slides in/out (no sudden gain reduction)
local limHold = 6 -- s, limiter stays this long after the last env effect faded
local blendStep = 1 / 30 -- max blend/Refresh rate
local EPS = 0.05

-- echo: only reflections arriving later than ~80ms are heard as distinct echoes
local echoMinDelay = 0.08 -- s
local echoMaxDelay = 0.60 -- s
local echoStep = 0.025 -- s, delay is quantized to this
local echoGain = 200 -- echo energy -> fWetDryMix [%]
local echoMaxWet = 30 -- fWetDryMix cap [%]
local echoMinWet = 2 -- below this the echo is not used (once on, it stays until half of this)
local echoOpenPow = 2 -- echo level *= (1 - open)^echoOpenPow

-- tunnels/corridors: distances are very uneven (short to the sides, long along the axis), sound is guided
local tunnelElongMin = 4 -- axis length / mean free path: below this no tunnel
local tunnelElongFull = 10 -- ... at or above this the space counts as a full tunnel
local tunnelEchoWet = 18 -- extra echo wet [%] at full tunnelness
local tunnelFeedback = 10 -- extra echo feedback [%] at full tunnelness (repeats ring down the tunnel)
local tunnelReverbCut = 0.25 -- full tunnel: reverb level * 0.75 (the echo should lead there); 0 = off
local probeJitter = 0.15 -- axis probe: random jitter of the candidate direction
local probeSmooth = 0.3 -- axis probe: share of a fresh measurement mixed into the smoothed distance

local coupleMin = 2          -- dFar / lambda, below this no coupling
local coupleFull = 6         -- ... at or above this fully coupled
local coupleShare = 0.6      -- how much of the far space counts as "my room" at full coupling
local coupleEchoWet = 12     -- extra echo wet [%] at full coupling
local echoEndMin = 14        -- m, an axis end this far gives a delay >= echoMinDelay (2*d/spd >= 0.08)

-- clutter: how much of the surroundings is covered by props (furniture) that the brush-only rays cannot see
local clutterMaxD = 524 -- units (~10 m), only props this close count
local clutterGain = 3 -- share of rays intercepted by props -> clutter 0..1
local clutterAbsorb = 0.25 -- full clutter: energy kept per bounce * 0.75 (shorter reverb time)
local clutterWet = 0.4 -- full clutter: reverb level * 0.6

-- limiter (DX8 compressor with a high ratio), only present while env effects are active
local LIM = "compressor#lim"
local limParams = {fGain = 0, fAttack = 1, fRelease = 150, fThreshold = -4, fRatio = 10, fPredelay = 0}

local reflections = {
    [MAT_CONCRETE] = 0.9,
    [MAT_METAL] = 0.95,
    [MAT_TILE] = 0.9,
    [MAT_GLASS] = 0.8,
    [MAT_VENT] = 0.85,
    [MAT_PLASTIC] = 0.6,
    [MAT_WOOD] = 0.6,
    [MAT_DIRT] = 0.4,
    [MAT_SAND] = 0.3,
    [MAT_GRASS] = 0.3,
    [MAT_FOLIAGE] = 0.2,
    [MAT_SNOW] = 0.2,
}
local dRefl = 0.6

-- debug mode: bypasses the estimator and applies these values directly
local dbgForce = CreateClientConVar("battlebeats_dsp_env_force", "0", false, false, "", 0, 1)
local dbgForceTime = CreateClientConVar("battlebeats_dsp_env_force_time", "800", false, false, "", 1, 3000) -- reverb time [ms]
local dbgForceMix = CreateClientConVar("battlebeats_dsp_env_force_mix", "-12", false, false, "", -60, 0) -- reverb mix [dB]
local dbgForceEcho = CreateClientConVar("battlebeats_dsp_env_force_echo", "0", false, false, "", 0, 100) -- echo wet [%], 0 = no echo
local dbgForceDelay = CreateClientConVar("battlebeats_dsp_env_force_delay", "200", false, false, "", 1, 2000) -- echo delay [ms]

-- effect slots driven by the environment
local slots = {
    {
        name = "reverb#1",
        key = "fReverbMix",
        silent = minDB,
        off = offDB,
        label = "reverb (dB)",
        bands = { fReverbMix = bandDB, fReverbTime = bandTime },
        slow = { fReverbTime = true },
    },
    {
        name = "echo#1",
        key = "fWetDryMix",
        silent = 0,
        off = 0.5,
        label = "echo (% wet)",
        bands = { fWetDryMix = bandEcho, fLeftDelay = bandDelay, fRightDelay = bandDelay },
        frozen = { fLeftDelay = true, fRightDelay = true },
        swapKey = "fLeftDelay",
        swapKey2 = "fRightDelay",
        swapBand = 60,
        lastSwap = -1e9,
        swapping = false,
    },
}
local sbn = {}
for _, s in ipairs(slots) do sbn[s.name] = s end

BassFX.Env = BassFX.Env or { eq = { 0, 0, 0, 0, 0, 0, 0, 0 }, fx = {} }
local env = BassFX.Env

local zero = {0, 0, 0, 0, 0, 0, 0, 0}
local target = {eq = zero, fx = {}}
local room = {}

local function copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function active()
    if not roomAcoustics:GetBool() then return false end
    return true
end

-- debug
local dbgEst, dbgT60, dbgRaw, dbgGate, dbgTun = nil, 0, 0, 1, 0
local dbgOn = false
local function dbgAdd()
    if dbgOn or not (btb and btb.Debug and btb.Debug.Add) then return end
    dbgOn = true
    btb.Debug.Add("bassfx_env", false, function(d)
        d.sep()
        d.section("DSP ENVIRONMENT")
        local e = dbgEst
        if e then
            d.row("ray weight", math.Round(e.weight, 1))
            d.row("open (floor excluded)", math.Round(e.open, 2))
            d.row("mean free path (m)", e.lambda and math.Round(e.lambda, 1) or "-")
            d.row("confinement", math.Round(e.conf, 2))
            d.row("absorption (reflectivity)", math.Round(e.absorb, 2))
            d.row("returned energy", math.Round(e.ret, 3))
            d.row("reverb time (ms)", math.Round(dbgT60))
            d.row("wet before cap", math.Round(dbgRaw, 3))
            d.row("size gate", math.Round(dbgGate, 2))
            d.row("tunnel", math.Round(dbgTun, 2))
            d.row("longest run (m)", e.dFar and math.Round(e.dFar, 1) or "-")
            d.row("clutter (props)", math.Round(e.clutter, 2))
        end
        for _, s in ipairs(slots) do
            local p = room[s.name]
            d.row(s.label, p and math.Round(p[s.key], 1) or s.silent)
        end
    end)
end
local function dbgRemove()
    dbgOn = false
    if btb and btb.Debug and btb.Debug.Remove then btb.Debug.Remove("bassfx_env") end
end

-- R2 low-discrepancy sequence on the sphere: every new ray lands where the previous ones are not
-- so any window of consecutive rays covers all directions evenly (no sweeps, no random rotation)
local phi1, phi2 = 0.7548776662466927, 0.5698402909980532
local seq = math.random(0, 100000)
local function nextDir()
    seq = seq + 1
    local u = (0.5 + seq * phi1) % 1
    local v = (0.5 + seq * phi2) % 1
    local z = 1 - 2 * u
    local r = math.sqrt(1 - z * z)
    local th = 6.2831853 * v
    return Vector(r * math.cos(th), r * math.sin(th), z)
end


local maxDis = 4096
local u2m = 0.0191 -- units -> meters
local spd = 343 -- m/s
local function castRay(origin, dir, ply, res)
    res.ok, res.vis, res.hit, res.esc, res.dist, res.near = 1, true, 0, 0, 0, 0
    res.gnd, res.hitNG, res.nearNG, res.clu = 0, 0, 0, 0
    res.ret, res.e, res.et, res.r, res.n = 0, 0, 0, 0, 0

    local pos, energy, dist = origin, 1, 0
    for b = 1, 3 do
        local tr = util.TraceLine({
            start = pos,
            endpos = pos + dir * maxDis,
            filter = ply,
            mask = MASK_SOLID_BRUSHONLY,
        })
        if tr.StartSolid then
            if b == 1 then res.ok = 0 end
            return
        end
        if b == 1 and roomAcousticsClutter:GetBool() then
            local stop = tr.Hit and tr.HitPos or (pos + dir * maxDis)
            local lim = pos + dir * math.min(clutterMaxD, pos:Distance(stop))
            local tp = util.TraceLine({ start = pos, endpos = lim, filter = ply, mask = MASK_SOLID })
            if tp.Hit and tp.HitTexture == "**studio**" then
                local ent = tp.Entity
                if not (IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() or ent:IsVehicle() or ent:IsWeapon())) then
                    res.clu = 1
                end
            end
        end

        if not tr.Hit or tr.HitSky then
            if b == 1 then res.esc = 1 end
            return -- escaped, no energy comes back
        end

        local seg = tr.Fraction * maxDis
        if b == 1 then
            res.hit = 1
            res.dist = seg * u2m
            if res.dist < nearM then res.near = 1 end
            -- the floor is always there it says nothing about enclosure: tracked separately
            if dir.z < -0.1 and tr.HitNormal.z > 0.7 then
                res.gnd = 1
            else
                res.hitNG = 1
                if res.dist < nearM then res.nearNG = 1 end
            end
        end

        dist = dist + seg
        local refl = reflections[tr.MatType] or dRefl
        energy = energy * refl
        res.r, res.n = res.r + refl, res.n + 1

        local hp = tr.HitPos + tr.HitNormal * 2
        local vis = util.TraceLine({ start = hp, endpos = origin, filter = ply, mask = MASK_SOLID_BRUSHONLY })
        if not vis.Hit then
            local path = dist + hp:Distance(origin)
            local t = path * u2m / spd
            local en = energy * 0.25
            res.ret = res.ret + en
            if t >= echoMinDelay and t <= echoMaxDelay then
                res.e  = res.e + en
                res.et = res.et + en * t -- energy-weighted delay
            end
        end

        pos = hp
        dir = dir - 2 * dir:Dot(tr.HitNormal) * tr.HitNormal
    end
end

-- sliding window of recent rays
local ring, head = {}, 0
for i = 1, window do
    ring[i] = {
        t = -1e9,
        ox = 0,
        oy = 0,
        oz = 0,
        ok = 0,
        vis = true,
        hit = 0,
        esc = 0,
        dist = 0,
        near = 0,
        gnd = 0,
        hitNG = 0,
        clu = 0,
        nearNG = 0,
        ret = 0,
        e = 0,
        et = 0,
        r = 0,
        n = 0,
    }
end

-- a ray cast from a spot that can no longer see the player describes another space (other room behind a door)
local losCursor = 0
local function updateVisibility(origin, ply, now)
    for _ = 1, losPerTick do
        losCursor = losCursor % window + 1
        local q = ring[losCursor]
        if now - q.t < ageMax then
            local dx, dy, dz = q.ox - origin.x, q.oy - origin.y, q.oz - origin.z
            if dx * dx + dy * dy + dz * dz > losMinDist * losMinDist then
                local tr = util.TraceLine({
                    start = Vector(q.ox, q.oy, q.oz),
                    endpos = origin,
                    filter = ply,
                    mask = MASK_SOLID_BRUSHONLY,
                })
                q.vis = not tr.Hit
            else
                q.vis = true
            end
        end
    end
end

-- tunnel axis probe
-- Random rays almost never line up with a tunnel axis (a 5 degree cone is 0.2% of the sphere), so one
-- direction is hill-climbed instead: it is re-measured every tick in both ways, a jittered candidate is
-- tried next to it, and it is swapped for a clearly longer one. Its two distances are the two ends of the
-- tunnel; they are NOT mixed into the unbiased estimate above (mean free path, openness, ...)
local probe = { dir = nil, dA = 0, dB = 0, escA = false, escB = false, score = 0 }
local probeTick = 0

local function probeRay(origin, dir, ply)
    local tr = util.TraceLine({
        start = origin, endpos = origin + dir * maxDis, filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    if tr.StartSolid then return 0, false end
    if not tr.Hit or tr.HitSky then return maxDis * u2m, true end -- no end within reach
    return tr.Fraction * maxDis * u2m, false
end

local function updateProbe(origin, ply, now)
    probeTick = probeTick + 1

    if probe.dir then
        local a, ea = probeRay(origin, probe.dir, ply)
        local b, eb = probeRay(origin, -probe.dir, ply)
        probe.dA = Lerp(probeSmooth, probe.dA, a)
        probe.dB = Lerp(probeSmooth, probe.dB, b)
        probe.escA, probe.escB = ea, eb
        probe.score = a + b
    end

    local cand
    if not probe.dir or probeTick % 5 == 0 then
        local best, bestD = nil, 0
        for i = 1, window do
            local q = ring[i]
            if q.ok == 1 and q.dir and now - q.t < ageMax then
                local d = q.esc == 1 and (maxDis * u2m) or q.dist
                if d > bestD then best, bestD = q.dir, d end
            end
        end
        cand = best or nextDir()
    else
        cand = probe.dir + VectorRand() * probeJitter
        cand:Normalize()
    end

    local a, ea = probeRay(origin, cand, ply)
    local b, eb = probeRay(origin, -cand, ply)
    if not probe.dir or a + b > probe.score * 1.05 then
        probe.dir, probe.score = cand, a + b
        probe.dA, probe.dB, probe.escA, probe.escB = a, b, ea, eb
    end
end

-- weighted features over the window: newer and closer rays count more
local function estimate(origin, now)
    local W, esc, hit, dsum, near, ret, e, et, r, n = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    local gnd, hitNG, nearNG, clu = 0, 0, 0, 0
    local ox, oy, oz = origin.x, origin.y, origin.z

    for i = 1, window do
        local q = ring[i]
        local age = now - q.t
        if q.ok == 1 and q.vis and age < ageMax then
            local dx, dy, dz = q.ox - ox, q.oy - oy, q.oz - oz
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            local w = math.exp(-age / ageTau) * (1 - d / radius)
            if w > 0 then
                W = W + w
                esc = esc + w * q.esc
                hit = hit + w * q.hit
                dsum = dsum + w * q.dist
                near = near + w * q.near
                ret = ret + w * q.ret
                e = e + w * q.e
                et = et + w * q.et
                r = r + w * q.r
                n = n + w * q.n
                gnd = gnd + w * q.gnd
                hitNG = hitNG + w * q.hitNG
                nearNG = nearNG + w * q.nearNG
                clu = clu + w * q.clu
            end
        end
    end

    if W < minWeight then return end
    return {
        weight = W,
        -- open = share of escaping rays among everything that is not floor
        open = (W - gnd) > 0.5 and esc / (W - gnd) or 0,
        -- length of the probed axis [m]
        dFar = probe.dir and (probe.dA + probe.dB) / 2 or nil,
        axisA = probe.dir and probe.dA or nil,
        axisB = probe.dir and probe.dB or nil,
        escA = probe.escA,
        escB = probe.escB,
        lambda = hit > 0.5 and dsum / hit or nil, -- mean free path [m]
        conf = hitNG > 0 and nearNG / hitNG or 0, -- fraction of near hits, floor excluded
        absorb = n > 0 and r / n or dRefl, -- average reflectivity
        ret = ret / W, -- returned energy per ray
        e = e / W, -- late (echo-range) returned energy per ray
        delay = e > 0 and et / e or nil, -- energy-weighted late delay [s]
        clutter = clu / W -- share of rays intercepted by props
    }
end

local function differs(slot, prev, new)
    for pk, band in pairs(slot.bands) do
        if math.abs((new[pk] or 0) - (prev[pk] or 0)) >= band then return true end
    end
    return false
end

local function settle(slot, params)
    if not params then
        room[slot.name] = nil
        return
    end
    local prev = room[slot.name]
    if not prev or differs(slot, prev, params) then
        room[slot.name] = params
    end
end

-- 0..1: how much the surroundings look like a tunnel/corridor (long clear axis, narrow sideways), closed ones only
local function tunnelness(est)
    if not (est.dFar and est.lambda) then return 0 end
    return math.Clamp((est.dFar / est.lambda - tunnelElongMin) / (tunnelElongFull - tunnelElongMin), 0, 1) * (1 - est.open)
end

local function coupling(est)
    if not (est.dFar and est.lambda) then return 0 end
    return math.Clamp((est.dFar / est.lambda - coupleMin) / (coupleFull - coupleMin), 0, 1) * (1 - est.open)
end

local function publish(est)
    local k = roomAcousticsStr:GetFloat()
    local reverb
    local coup = coupling(est)
    local lam = est.lambda
    if est.dFar then
        lam = est.lambda + coup * coupleShare * math.max(0, est.dFar * 0.5 - est.lambda)
    end
    if est.lambda then
        local cl = roomAcousticsClutter:GetBool() and math.Clamp(est.clutter * clutterGain, 0, 1) or 0
        local m = math.Clamp((1 - est.open) * est.absorb * (1 - clutterAbsorb * cl), 0.02, 0.98) -- energy kept per bounce; open space 'absorbs' too
        local t60 = eyringK * lam / (-math.log(m))
        local ms = math.Clamp(t60 * 1000, reverbMinMS, reverbMaxMS)
        dbgT60 = ms

        local wetRaw = est.ret * k * (1 + confBoost * (est.conf - 0.5)) * (1 - est.open) ^ openPow * (1 - clutterWet * cl) * (1 - tunnelReverbCut * tunnelness(est))
        dbgRaw = wetRaw
        local gate = math.min(1, (lam / sizeRef) ^ sizePow)
        dbgGate = gate
        local wet = math.min(wetRaw * gate, maxWet)
        local db = wet > 1e-4 and math.Clamp(20 * math.log10(wet), minDB, maxDB) or minDB
        local bright = math.Clamp((est.absorb - 0.3) / 0.65, 0, 1)
        reverb = {fInGain = -headroomDB * math.min(wet / maxWet, 1), fReverbMix = db, fReverbTime = ms, fHighFreqRTRatio = Lerp(bright, 0.3, 0.9)}
    end
    settle(sbn["reverb#1"], reverb)

    local echo
    -- tunnelness: very uneven distances = corridor/tunnel
    local tun = tunnelness(est)
    dbgTun = tun
    local delay = est.delay
    local delayL, delayR
    if (tun > 0.3 or coup > 0.3) and est.axisA then
        local dA, dB = est.axisA, est.axisB
        if est.escA and not est.escB then dA = dB elseif est.escB and not est.escA then dB = dA end
        -- an end that is too close would give a fake <80ms "echo": mirror the longer one
        if dA < echoEndMin and dB >= echoEndMin then
            dA = dB
        elseif dB < echoEndMin and dA >= echoEndMin then
            dB = dA
        end
        if math.max(dA, dB) >= echoEndMin then
            delayL, delayR = 2 * dA / spd, 2 * dB / spd
            delay = delayL
        end
    end

    if roomAcousticsEcho:GetBool() and delay then
        local echoOpen = (1 - est.open) ^ echoOpenPow
        local wetPct = math.min((est.e * k * echoGain + tunnelEchoWet * tun * k) * echoOpen, echoMaxWet)
        local thr = room["echo#1"] and echoMinWet * 0.5 or echoMinWet -- hysteresis
        if wetPct >= thr then
            local function quant(t)
                return math.Clamp(math.Round(t / echoStep) * echoStep, echoMinDelay, echoMaxDelay) * 1000
            end
            local msL, msR
            if delayL then
                msL, msR = quant(delayL), quant(delayR)
            else
                local ms0 = quant(delay)
                msL, msR = ms0 * 0.93, ms0 * 1.07
            end
            -- msL / msR: left and right delay in ms
            echo = {
                fWetDryMix = wetPct,
                fFeedback = math.min(Lerp(math.Clamp((est.absorb - 0.3) / 0.65, 0, 1), 10, 35) + tunnelFeedback * tun, 50),
                fLeftDelay = msL,
                fRightDelay = msR,
                lPanDelay = 0,
            }
        end
    end
    settle(sbn["echo#1"], echo)

    dbgEst = est
    dbgAdd()
end

-- debug
local function applyForce()
    room["reverb#1"] = {
        fInGain = 0,
        fReverbMix = dbgForceMix:GetFloat(),
        fReverbTime = dbgForceTime:GetFloat(),
        fHighFreqRTRatio = 0.6,
    }
    local ew = dbgForceEcho:GetFloat()
    if ew > 0 then
        local ms = dbgForceDelay:GetFloat()
        room["echo#1"] = {
            fWetDryMix = ew,
            fFeedback = 20,
            fLeftDelay = ms * 0.93,
            fRightDelay = ms * 1.07,
            lPanDelay = 0,
        }
    else
        room["echo#1"] = nil
    end
end

-- target: what we are blending towards
local function applyTarget(ply, on)
    local under = on and ply:WaterLevel() >= 3
    local uw = BassFX.EQPresets and BassFX.EQPresets.underwater
    target.eq = (under and uw) or zero
    for _, s in ipairs(slots) do
        local p = room[s.name]
        if on and not under and p then
            target.fx[s.name] = p
        else
            target.fx[s.name] = nil
        end
    end
end

hook.Add("InitPostEntity", "BattleBeats_EnvironmentsInit", function()
    timer.Create("BassFX_EnvRays", tick, 0, function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        if not active() then
            if next(room) then
                room = {}
                dbgRemove()
            end
            applyTarget(ply, false)
            return
        end

        local origin = ply:EyePos()
        local now = SysTime()
        for _ = 1, perTick do
            head = head % window + 1
            local q = ring[head]
            q.t, q.ox, q.oy, q.oz = now, origin.x, origin.y, origin.z
            local dir = nextDir()
            q.dir = dir
            castRay(origin, dir, ply, q)
        end
        updateVisibility(origin, ply, now)
        updateProbe(origin, ply, now)

        local est = estimate(origin, now)
        if est then
            dbgEst = est
            dbgAdd()
        end
        if dbgForce:GetBool() then
            applyForce()
        elseif est then
            publish(est)
        end

        applyTarget(ply, true)
    end)
end)

-- blending
local elapsed = 0
local limUntil = 0
hook.Add("Think", "BassFX_EnvBlend", function()
    elapsed = elapsed + FrameTime()
    if elapsed < blendStep then return end
    local dt = elapsed
    elapsed = 0

    local aEQ = 1 - math.exp(-dt / EQtau)
    local aFX = 1 - math.exp(-dt / FXtau)
    local aSlow = 1 - math.exp(-dt / slowTau)
    local aSwap = 1 - math.exp(-dt / swapTau)
    local aLim = 1 - math.exp(-dt / limTau)
    local changed = false

    for i = 1, #zero do
        local cur, tgt = env.eq[i] or 0, target.eq[i] or 0
        local new = cur + (tgt - cur) * aEQ
        if math.abs(tgt - new) < EPS then new = tgt end
        if new ~= cur then
            env.eq[i] = new
            changed = true
        end
    end

    local anyWet = false

    for _, s in ipairs(slots) do
        local name, key = s.name, s.key
        local tgt = target.fx[name]
        local cur = env.fx[name]
        local tgtVal = tgt and tgt[key] or s.silent

        if not cur and tgtVal > s.off then
            cur = copy(tgt)
            cur[key] = s.silent
            env.fx[name] = cur
            changed = true
        end

        -- an echo that would have to change its delay is faded out, removed and re-created at the new delay
        if cur and tgt and s.swapKey and not s.swapping
            and (math.abs(cur[s.swapKey] - tgt[s.swapKey]) >= s.swapBand
                or math.abs(cur[s.swapKey2] - tgt[s.swapKey2]) >= s.swapBand)
            and SysTime() - s.lastSwap > swapHold then
            s.swapping = true
            s.lastSwap = SysTime()
        end

        if cur then
            if tgt and not s.swapping then
                for pk, v in pairs(tgt) do
                    local c = cur[pk] or v
                    local a = (s.frozen and s.frozen[pk]) and 0 or ((s.slow and s.slow[pk]) and aSlow or aFX)
                    local n = c + (v - c) * a
                    if math.abs(v - n) < EPS then n = v end
                    if n ~= cur[pk] then
                        cur[pk] = n
                        changed = true
                    end
                end
            else
                -- fade the tail out instead of cutting it
                cur[key] = cur[key] + (s.silent - cur[key]) * (s.swapping and aSwap or aFX)
                changed = true
            end

            if cur[key] <= s.off and (tgtVal <= s.off or s.swapping) then
                env.fx[name] = nil
                changed = true
                cur = nil
                s.swapping = false
            end
        end

        if cur then anyWet = true end
    end

    local now = SysTime()
    if anyWet then limUntil = now + limHold end
    local wantLim = roomAcousticsLim:GetBool() and now < limUntil
    local lim = env.fx[LIM]
    if wantLim then
        if not lim then
            lim = copy(limParams)
            lim.fThreshold = 0
            env.fx[LIM] = lim
            changed = true
        end
        local goal = limParams.fThreshold
        local th = lim.fThreshold + (goal - lim.fThreshold) * aLim
        if math.abs(th - goal) < EPS then th = goal end
        if th ~= lim.fThreshold then
            lim.fThreshold = th
            changed = true
        end
    elseif lim then
        local th = lim.fThreshold + (0 - lim.fThreshold) * aLim
        if th > -0.1 then
            env.fx[LIM] = nil
        else
            lim.fThreshold = th
        end
        changed = true
    end

    if changed then BassFX.Refresh() end
end)

concommand.Add("battlebeats_dsp_env_dump", function()
    local function f(v, d)
        return v and string.format("%." .. (d or 2) .. "f", v) or "-"
    end
    local e = dbgEst
    local rv, ec = room["reverb#1"], room["echo#1"]
    print(string.format(
        "[env]%s open=%s lambda=%sm conf=%s absorb=%s ret=%s wetRaw=%s gate=%s elong=%s tunnel=%s clutter=%s | reverb: time=%sms mix=%sdB inGain=%s | echo: wet=%s%% delay=%sms | weight=%s",
        dbgForce:GetBool() and " FORCED" or "",
        f(e and e.open), f(e and e.lambda, 1), f(e and e.conf), f(e and e.absorb), f(e and e.ret), f(dbgRaw, 3),
        f(dbgGate), f(e and e.dFar and e.lambda and e.dFar / e.lambda, 1), f(dbgTun), f(e and e.clutter),
        f(rv and rv.fReverbTime, 0), f(rv and rv.fReverbMix, 1), f(rv and rv.fInGain, 1),
        f(ec and ec.fWetDryMix, 1), f(ec and ec.fLeftDelay and ec.fLeftDelay / 0.93, 0),
        f(e and e.weight, 0)
    ))
end)
