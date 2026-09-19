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
