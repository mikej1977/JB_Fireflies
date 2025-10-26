local FireflyUI = require("jb_firefly_ui")
JBFireflies = JBFireflies or {}
local randy = newrandom()

local function setupConfig()
    local options = SandboxVars.JBFireflyOptions
    local cfg = {
        ticksToSpawn        = options.ticksToSpawn,
        minSpawn            = options.minSpawn,
        maxSpawn            = options.maxSpawn,
        maxFireflyInstances = options.maxFireflyInstances,
        shoreBias           = options.shoreBias,
        treeBias            = options.treeBias,
        spawnArea           = options.spawnArea,
        overSample          = options.overSample,
        taperDays           = options.taperDays,
        startDay            = options.startDay,
        endDay              = options.endDay,
        hideCantSee         = options.hideCantSee,
        debug               = true
    }

    if cfg.debug then
        cfg.ticksToSpawn        = 5
        cfg.minSpawn            = 5
        cfg.maxSpawn            = 25
        cfg.maxFireflyInstances = 250
        cfg.shoreBias           = 25
        cfg.treeBias            = 10
        cfg.spawnArea           = 50
        cfg.overSample          = 5
    end

    return cfg
end

JBFireflies.Config = setupConfig()

-- Clears tables for reuse
local function clearTable(t)
    for i = #t, 1, -1 do t[i] = nil end
end

-- Predicate functions
local function isShoreline(sq)
    if not sq then return false end
    local water = sq:getWater()
    return water and water:isActualShore()
end

local function isTreeOrBush(sq)
    return sq:HasTree() or sq:hasBush()
end

local function isGrassLike(sq)
    return sq:hasGrassLike()
end

-- maths the days, like 185 for approx June 15th
local function getDayOfYear()
    local gt = getGameTime()
    return (gt:getMonth() + 1) * 30 + gt:getDay()
end

-- pare those bugs back a bit based on spawn dates, temp, light and rain
local function isInSeason(day)
    local cfg = JBFireflies.Config
    local start = cfg.startDay - cfg.taperDays
    local finish = cfg.endDay + cfg.taperDays
    return day >= start and day <= finish
end

function JBFireflies.getSeasonalFactor(dayOfYear)
    local cfg = JBFireflies.Config
    local taperStart = cfg.startDay - cfg.taperDays
    local taperEnd = cfg.endDay + cfg.taperDays
    if dayOfYear < taperStart or dayOfYear > taperEnd then return 0 end
    local progress = (dayOfYear - taperStart) / (taperEnd - taperStart)
    return math.sin(progress * math.pi)
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

-- how many are left after decimation
function JBFireflies.getAdjustedSpawnCount(baseCount)
    local dayOfYear = getDayOfYear()
    local cfg = JBFireflies.Config
    local seasonal = JBFireflies.getSeasonalFactor(dayOfYear)
    local temp = JBFireflies.getTemperatureFactor()
    local night = JBFireflies.getNightFactor()
    local rain = JBFireflies.getRainFactor()
    return math.floor(baseCount * seasonal * temp * night * rain)
end

-- avoid gc, not sure if this is better?
local shoreSquares = {}
local treeSquares = {}
local grassSquares = {}
local otherSquares = {}

local function collectCandidateSquares(player, cfg, count)
    local cell = getWorld():getCell()
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local playerNum = player:getPlayerNum()
    local minSpawnDistSq = 2

    -- Clear tables for this new batch of bugs
    clearTable(shoreSquares)
    clearTable(treeSquares)
    clearTable(grassSquares)
    clearTable(otherSquares)

    local sampleSize = count * (cfg.overSample or 3)
    for _ = 1, sampleSize do
        local dx = randy:random(-cfg.spawnArea, cfg.spawnArea)
        local dy = randy:random(-cfg.spawnArea, cfg.spawnArea)

        if (dx * dx + dy * dy) > minSpawnDistSq then
            local testSquare = cell:getGridSquare(px + dx, py + dy, pz)

            if testSquare then
                local waterBody = testSquare:getWater() -- Safe nil-check
                local isWaterNotShore = (waterBody and not waterBody:isActualShore())
                local isViewBlocked = cfg.hideCantSee and not testSquare:isCanSee(playerNum)
                local isStandardValid = testSquare:isOutside() and testSquare:IsOnScreen() and
                    not cell:IsBehindStuff(testSquare) and not isViewBlocked

                if isStandardValid then
                    if isWaterNotShore then -- Chance to spawn a few on orphaned water
                        if randy:random(1, 100) <= 5 then
                            table.insert(otherSquares, testSquare)
                        end
                    else -- It's valid land, tree or shore, sort it
                        if isShoreline(testSquare) then
                            table.insert(shoreSquares, testSquare)
                        elseif isTreeOrBush(testSquare) then
                            table.insert(treeSquares, testSquare)
                        elseif isGrassLike(testSquare) then -- Fixed logic
                            table.insert(grassSquares, testSquare)
                        else
                            table.insert(otherSquares, testSquare)
                        end
                    end
                end
            end
        end
    end
end

-- bias shit
local function calculateSpawnTargets(totalToSpawn, cfg)
    -- get bias
    local shoreWeight = #shoreSquares * (cfg.shoreBias or 1)
    local treeWeight = #treeSquares * (cfg.treeBias or 1)
    local grassWeight = #grassSquares * 2 -- No bias set for grass, default to 1
    local otherWeight = #otherSquares * 1 -- No bias for other

    local totalWeight = shoreWeight + treeWeight + grassWeight + otherWeight
    if totalWeight == 0 then
        return 0, 0, 0, 0
    end

    -- calc how many based on weight
    local targetShore = math.floor((shoreWeight / totalWeight) * totalToSpawn)
    local targetTree = math.floor((treeWeight / totalWeight) * totalToSpawn)
    local targetGrass = math.floor((grassWeight / totalWeight) * totalToSpawn)

    -- others for the leftovers
    local spawnedSoFar = targetShore + targetTree + targetGrass
    local targetOther = math.max(0, totalToSpawn - spawnedSoFar)

    return targetShore, targetTree, targetGrass, targetOther
end

-- spawn from the pools
local function spawnFromPool(pool, count, playerNum, texture)
    local spawnedCount = 0
    while count > 0 and #pool > 0 do
        local index = randy:random(1, #pool)
        local sq = pool[index]
        table.remove(pool, index)

        FireflyUI:new(playerNum, texture, sq)

        count = count - 1
        spawnedCount = spawnedCount + 1
    end
    return spawnedCount
end

-- main func to spawn
function JBFireflies.spawnRandomFireflies(baseCount)
    local player = getPlayer()
    if not player then return end

    local cfg = JBFireflies.Config
    local count = JBFireflies.getAdjustedSpawnCount(baseCount)
    if count == 0 then return end

    -- get and sort the squares
    collectCandidateSquares(player, cfg, count)

    -- bias math shit
    local totalCandidates = #shoreSquares + #otherSquares + #treeSquares + #grassSquares
    if totalCandidates == 0 then return end

    local targetShore, targetTree, targetGrass, targetOther = calculateSpawnTargets(count, cfg)

    -- do the spawn
    local texture = getTexture("media/textures/jb_firefly.png")
    local playerNum = player:getPlayerNum()

    local shoreSpawned = spawnFromPool(shoreSquares, targetShore, playerNum, texture)
    local treeSpawned = spawnFromPool(treeSquares, targetTree, playerNum, texture)
    local grassSpawned = spawnFromPool(grassSquares, targetGrass, playerNum, texture)
    local otherSpawned = spawnFromPool(otherSquares, targetOther / 10, playerNum, texture)

    if cfg.debug then
        local spawned = shoreSpawned + treeSpawned + grassSpawned + otherSpawned
        print(string.format("Spawned: %d (Shore: %d, Tree: %d, Grass: %d, Other: %d)", spawned, shoreSpawned, treeSpawned, grassSpawned, otherSpawned))
    end
end

-- events
function JBFireflies.onDailyCheck()
    local day = getDayOfYear()
    if isInSeason(day) then
        if JBFireflies.Config.debug then print("JB's Fireflies: In season. Switching to OnTick check.") end
        Events.EveryTenMinutes.Remove(JBFireflies.onDailyCheck)
        Events.OnTick.Add(JBFireflies.onTickFireflies)
    end
end

function JBFireflies.onTickFireflies(tick)
    local day = getDayOfYear()
    if not isInSeason(day) then
        if JBFireflies.Config.debug then print("JB's Fireflies: Out of season. Switching to daily check.") end
        Events.OnTick.Remove(JBFireflies.onTickFireflies)
        Events.EveryTenMinutes.Add(JBFireflies.onDailyCheck)
        return
    end

    local cfg = JBFireflies.Config
    if tick % cfg.ticksToSpawn == 0 then
        local base = randy:random(cfg.minSpawn, cfg.maxSpawn)
        JBFireflies.spawnRandomFireflies(base)
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
