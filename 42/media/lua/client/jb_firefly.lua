local FireflyUI = require("jb_firefly_ui")
JBFireflies = JBFireflies or {}
local randy = newrandom()
local options = SandboxVars.JBFireflyOptions

JBFireflies.Config = {
    ticksToSpawn        = options.ticksToSpawn,
    minSpawn            = options.minSpawn,
    maxSpawn            = options.maxSpawn,
    maxFireflyInstances = options.maxFireflyInstances,
    shoreBias           = options.shoreBias,
    treeBias            = options.treeBias,
    spawnArea           = options.spawnArea,
    taperDays           = options.taperDays,
    startDay            = options.startDay,
    endDay              = options.endDay,
    hideCantSee         = options.hideCantSee,
    debug               = true
}

if JBFireflies.Config.debug then
    JBFireflies.Config = {
        ticksToSpawn        = 5,
        minSpawn            = 5,
        maxSpawn            = 25,
        maxFireflyInstances = 100,
        shoreBias           = 1,
        treeBias            = 10,
        spawnArea           = 25,
        taperDays           = options.taperDays,
        startDay            = options.startDay,
        endDay              = options.endDay,
        hideCantSee         = options.hideCantSee,
        debug               = true
    }
end

local function getDayOfYear()
    local gt = getGameTime()
    return (gt:getMonth() + 1) * 30 + gt:getDay()
end

local function isTreeOrBush(sq)
    return sq and (sq:HasTree() or sq:hasBush())
end

local function isGrass(sq)
    return sq and sq:getGrass()
end

local function isShoreline(sq)
    if not sq then return false end
    if sq:hasWater() then
        local water = sq:getWater()
        return water and water:isActualShore()
    end
    return false
end

local function orphanedWater(sq)
    if not sq then return false end
    local cell = getCell()
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local n = cell:getGridSquare(x, y - 1, z)
    local s = cell:getGridSquare(x, y + 1, z)
    local e = cell:getGridSquare(x + 1, y, z)
    local w = cell:getGridSquare(x - 1, y, z)
    return (n and n:hasWater()) and (s and s:hasWater()) and (e and e:hasWater()) and (w and w:hasWater())
end

function JBFireflies.getSeasonalFactor(dayOfYear)
    local cfg = JBFireflies.Config
    local taperStart = cfg.startDay - cfg.taperDays
    local taperEnd = cfg.endDay + cfg.taperDays

    if dayOfYear < taperStart or dayOfYear > taperEnd then
        return 0
    end

    local progress = (dayOfYear - taperStart) / (taperEnd - taperStart)
    return math.sin(progress * math.pi) -- 0 → 1 → 0
end

function JBFireflies.getTemperatureFactor()
    local temp = getClimateManager():getTemperature()
    if temp < 13 then return 0 end
    if temp >= 25 then return 1 end
    return (temp - 13) / 12
end

function JBFireflies.getNightFactor()
    local night = getGameTime():getNight()
    if night < 0.3 then return 0 end
    if night > 0.6 then return 1 end
    return night
end

function JBFireflies.getRainFactor()
    local rain = getClimateManager():getPrecipitationIntensity()
    if rain <= 0 then return 1 end
    return 1 / (rain * 10)
end

function JBFireflies.getAdjustedSpawnCount(baseCount)
    local dayOfYear = getDayOfYear()
    local cfg = JBFireflies.Config

    local seasonal = JBFireflies.getSeasonalFactor(dayOfYear)
    local temp = JBFireflies.getTemperatureFactor()
    local night = JBFireflies.getNightFactor()
    local rain = JBFireflies.getRainFactor()

    local adjusted = math.floor(baseCount * seasonal * temp * night * rain)

--[[     if cfg.debug then
        print(string.format(
            "Day %d | Seasonal %.2f | Temp %.2f | Night %.2f | Rain %.2f | %d fireflies",
            dayOfYear, seasonal, temp, night, rain, adjusted
        ))
    end ]]

    return adjusted
end

local shoreSquares, treeSquares, grassSquares, otherSquares = {}, {}, {}, {}

local function clearTable(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function spawnRandomFireflies(baseCount)
    local player = getPlayer()
    if not player then return end

    local cfg = JBFireflies.Config
    local cell = getWorld():getCell()
    local texture = getTexture("media/textures/jb_firefly.png")
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local playerNum = player:getPlayerNum()

    local count = JBFireflies.getAdjustedSpawnCount(baseCount)
    if count == 0 then return end

    -- clear and reuse category tables
    clearTable(shoreSquares)
    clearTable(treeSquares)
    clearTable(grassSquares)
    clearTable(otherSquares)

    -- collect candidates (oversample factor 3x instead of 10x)
    local samples = count * 3
    for i = 1, samples do
        local dx = randy:random(-cfg.spawnArea, cfg.spawnArea + 1)
        local dy = randy:random(-cfg.spawnArea, cfg.spawnArea + 1)
        local sq = cell:getGridSquare(px + dx, py + dy, pz)

        if sq and sq:isOutside() and sq:IsOnScreen() and not cell:IsBehindStuff(sq) and not orphanedWater(sq) then
            if isShoreline(sq) then
                shoreSquares[#shoreSquares + 1] = sq
            elseif isTreeOrBush(sq) then
                treeSquares[#treeSquares + 1] = sq
            elseif isGrass(sq) then
                grassSquares[#grassSquares + 1] = sq
            else
                otherSquares[#otherSquares + 1] = sq
            end
        end
    end

    local totalSquares = #shoreSquares + #treeSquares + #grassSquares + #otherSquares
    if totalSquares == 0 then return end

    -- bias split
    local biasTarget  = math.floor(0.7 * totalSquares)
    local totalBias   = cfg.shoreBias + cfg.treeBias
    local rawShore    = biasTarget * (cfg.shoreBias / totalBias)
    local rawTree     = biasTarget * (cfg.treeBias / totalBias)

    local targetShore = math.floor(rawShore)
    local targetTree  = math.floor(rawTree)
    local remainder   = biasTarget - (targetShore + targetTree)
    if remainder > 0 then
        if (rawShore - targetShore) >= (rawTree - targetTree) then
            targetShore = targetShore + remainder
        else
            targetTree = targetTree + remainder
        end
    end

    local targetGrass = totalSquares - biasTarget
    local used = 0

    local function spawnFromPool(pool, count, playerNum, texture)
        for i = 1, math.min(count, #pool) do
            FireflyUI:new(playerNum, texture, pool[i])
        end
    end

    -- spawn directly from pools
    spawnFromPool(shoreSquares, targetShore, playerNum, texture); used = used + targetShore
    spawnFromPool(treeSquares, targetTree, playerNum, texture); used = used + targetTree
    spawnFromPool(grassSquares, targetGrass, playerNum, texture); used = used + targetGrass

    local remaining = totalSquares - used
    spawnFromPool(otherSquares, remaining, playerNum, texture)
end

local function isInSeason(day)
    local cfg = JBFireflies.Config
    local start = cfg.startDay - cfg.taperDays
    local finish = cfg.endDay + cfg.taperDays
    return day >= start and day <= finish
end

function JBFireflies.onDailyCheck()
    local day = getDayOfYear()
    if isInSeason(day) then
        -- switch to ontick
        print("switching to ontick check")
        Events.EveryTenMinutes.Remove(JBFireflies.onDailyCheck)
        Events.OnTick.Add(JBFireflies.onTickFireflies)
    end
end

function JBFireflies.onTickFireflies(tick)
    local day = getDayOfYear()
    if not isInSeason(day) then
        -- switch to daily
        print("switching to daily check")
        Events.OnTick.Remove(JBFireflies.onTickFireflies)
        Events.EveryTenMinutes.Add(JBFireflies.onDailyCheck)
        return
    end

    local cfg = JBFireflies.Config
    if tick % cfg.ticksToSpawn == 0 then
        local base = randy:random(cfg.minSpawn, cfg.maxSpawn)
        spawnRandomFireflies(base)
    end
end

Events.OnGameStart.Add(function()
    local day = getDayOfYear()
    if isInSeason(day) then
        Events.OnTick.Add(JBFireflies.onTickFireflies)
    else
        Events.EveryTenMinutes.Add(JBFireflies.onDailyCheck)
    end
end)