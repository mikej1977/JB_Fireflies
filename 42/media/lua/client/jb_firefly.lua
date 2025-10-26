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
        cfg.spawnArea           = 50
        cfg.overSample          = 5
    end

    return cfg
end

JBFireflies.Config = setupConfig()

local zoneSpawnWeight = {
    Nav = 0,
    Forest = 3,
    DeepForest = 5,
    Farm = 2,
    FarmLand = 1,
    ForagingNav = 0,
    TownZone = 1,
    TrailerPark = 1,
    Unknown = 1,
    Vegitation = 2,
    PHForest = 3,
    PRForest = 3,
    PHMixForest = 3,
    FarmForest = 2,
    FarmMixForest = 2,
    BirchForest = 3,
    BirchMixForest = 3,
    OrganicForest = 4,
}

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

local shoreSquares = {}
local treeSquares = {}
local grassSquares = {}
local otherSquares = {}

local function collectCandidateSquares(player, cfg, count)
    local cell = getWorld():getCell()
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local playerNum = player:getPlayerNum()
    local minSpawnDistSq = 2
    local sampleSize = count * (cfg.overSample or 3)

    -- Clear tables for this new batch of bugs
    clearTable(shoreSquares)
    clearTable(treeSquares)
    clearTable(grassSquares)
    clearTable(otherSquares)

    local shoreSampleSize = sampleSize * 2
    for _ = 1, shoreSampleSize do
        local dx = randy:random(-cfg.spawnArea, cfg.spawnArea)
        local dy = randy:random(-cfg.spawnArea, cfg.spawnArea)

        if (dx * dx + dy * dy) > minSpawnDistSq then
            local testSquare = cell:getGridSquare(px + dx, py + dy, pz)
            if testSquare then
                local isViewBlocked = cfg.hideCantSee and not testSquare:isCanSee(playerNum)
                local isStandardValid = testSquare:isOutside() and testSquare:IsOnScreen() and
                    not cell:IsBehindStuff(testSquare) and not isViewBlocked

                if isStandardValid and isShoreline(testSquare) then
                    table.insert(shoreSquares, testSquare)
                end
            end
        end
    end

    local sampleSize = count * (cfg.overSample or 25)
    for _ = 1, sampleSize do
        local dx = randy:random(-cfg.spawnArea, cfg.spawnArea)
        local dy = randy:random(-cfg.spawnArea, cfg.spawnArea)

        if (dx * dx + dy * dy) > minSpawnDistSq then
            local testSquare = cell:getGridSquare(px + dx, py + dy, pz)

            if testSquare then
                local waterBody = testSquare:getWater()
                local isWaterNotShore = (waterBody and not waterBody:isActualShore())
                local isViewBlocked = cfg.hideCantSee and not testSquare:isCanSee(playerNum)
                local isStandardValid = testSquare:isOutside() and testSquare:IsOnScreen() and not cell:IsBehindStuff(testSquare) and not isViewBlocked

                if isStandardValid then
                    -- Check for non-shore categories
                    if isWaterNotShore then
                        if randy:random(1, 100) <= 5 then
                            table.insert(otherSquares, testSquare)
                        end
                    elseif isTreeOrBush(testSquare) and not isShoreline(testSquare) then
                        table.insert(treeSquares, testSquare)
                    elseif isGrassLike(testSquare) and not isShoreline(testSquare) then
                        table.insert(grassSquares, testSquare)
                    elseif not isShoreline(testSquare) then
                        table.insert(otherSquares, testSquare)
                    end
                end
            end
        end
    end
end

-- bias shit
local function calculateSpawnTargets(totalToSpawn)
    local shorePercent     = 0.50
    local treePercent      = 0.30
    local grassPercent     = 0.20

    local shorePool        = #shoreSquares
    local treePool         = #treeSquares
    local grassPool        = #grassSquares
    local otherPool        = #otherSquares

    local remainingToSpawn = totalToSpawn

    local targetShore      = math.floor(totalToSpawn * shorePercent)
    local actualShore      = math.min(shorePool, targetShore)
    remainingToSpawn       = remainingToSpawn - actualShore

    local unspawnedShore   = targetShore - actualShore
    local targetTree       = math.floor(totalToSpawn * treePercent) + unspawnedShore
    local actualTree       = math.min(treePool, targetTree)
    remainingToSpawn       = remainingToSpawn - actualTree

    local unspawnedTree    = targetTree - actualTree
    local targetGrass      = math.floor(totalToSpawn * grassPercent) + unspawnedTree
    local actualGrass      = math.min(grassPool, targetGrass)
    remainingToSpawn       = remainingToSpawn - actualGrass

    local targetOther      = remainingToSpawn
    local actualOther      = math.min(otherPool, targetOther)

    return actualShore, actualTree, actualGrass, actualOther
end

-- spawn from the pools
local function spawnFromPool(pool, count, playerNum, texture)
    local spawnedCount = 0
    while count > 0 and #pool > 0 do
        local index = randy:random(1, #pool)
        local gsq = pool[index]
        local zoneWeight = zoneSpawnWeight[gsq:getZoneType()] or 1
        table.remove(pool, index)
        if zoneWeight > 0 then
            FireflyUI:new(playerNum, texture, gsq)
            count = count - 1
            spawnedCount = spawnedCount + 1
        end
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

    collectCandidateSquares(player, cfg, count)

    -- bias math shit
    local totalCandidates = #shoreSquares + #otherSquares + #treeSquares + #grassSquares
    if totalCandidates == 0 then return end

    local targetShore, targetTree, targetGrass, targetOther = calculateSpawnTargets(count)

    local texture = getTexture("media/textures/jb_firefly.png")
    local playerNum = player:getPlayerNum()

    local shoreSpawned = spawnFromPool(shoreSquares, targetShore, playerNum, texture)
    local treeSpawned = spawnFromPool(treeSquares, targetTree, playerNum, texture)
    local grassSpawned = spawnFromPool(grassSquares, targetGrass, playerNum, texture)

    local otherSpawned = spawnFromPool(otherSquares, targetOther, playerNum, texture)

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
