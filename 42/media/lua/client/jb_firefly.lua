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

--[[     if cfg.debug then
        cfg.ticksToSpawn        = 5
        cfg.minSpawn            = 5
        cfg.maxSpawn            = 25
        cfg.maxFireflyInstances = 250
        cfg.shoreBias           = 25
        cfg.treeBias            = 10
        cfg.spawnArea           = 50
        cfg.overSample          = 5,
    end ]]
    return cfg
end

JBFireflies.Config = setupConfig()

local function isShoreline(sq)
    if not sq then return false end
    local water = sq:getWater()
    return water and water:isActualShore()
end

local function clearTable(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function getDayOfYear()
    local gt = getGameTime()
    return (gt:getMonth() + 1) * 30 + gt:getDay()
end

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

    if dayOfYear < taperStart or dayOfYear > taperEnd then
        return 0
    end

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

function JBFireflies.getAdjustedSpawnCount(baseCount)
    local dayOfYear = getDayOfYear()
    local cfg = JBFireflies.Config

    local seasonal = JBFireflies.getSeasonalFactor(dayOfYear)
    local temp = JBFireflies.getTemperatureFactor()
    local night = JBFireflies.getNightFactor()
    local rain = JBFireflies.getRainFactor()

    local adjusted = math.floor(baseCount * seasonal * temp * night * rain)
    return adjusted
end

local shoreSquares = {}
local treeSquares = {}
local grassSquares = {}
local otherSquares = {}

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

local function isTreeOrBush(sq)
    return sq:HasTree() or sq:hasBush()
end

-- print(getPlayer():getSquare():hasGrassLike())
local function isGrassy(sq)
    return not sq:hasGrassLike()
end

function JBFireflies.spawnRandomFireflies(baseCount)
    local player = getPlayer()
    if not player then return end

    local cfg = JBFireflies.Config
    local count = JBFireflies.getAdjustedSpawnCount(baseCount)
    if count == 0 then return end

    local cell = getWorld():getCell()
    local texture = getTexture("media/textures/jb_firefly.png")
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local playerNum = player:getPlayerNum()
    local minSpawnDistSq = 2

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
                local isWaterNotShore = testSquare:hasWater() and not testSquare:getWater():isActualShore()
                local isViewBlocked = cfg.hideCantSee and not testSquare:isCanSee(playerNum)

                local isStandardValid = testSquare:isOutside() and testSquare:IsOnScreen() and
                    not cell:IsBehindStuff(testSquare) and not isViewBlocked

                if isStandardValid then
                    if isWaterNotShore then -- chance to spawn a few on orphaned water
                        if randy:random(1, 100) <= 5 then
                            table.insert(otherSquares, testSquare)
                        end
                    else
                        if isShoreline(testSquare) then -- it's a shoreline
                            table.insert(shoreSquares, testSquare)
                        elseif isTreeOrBush(testSquare) then
                            table.insert(treeSquares, testSquare)
                        elseif isGrassy(testSquare) then
                            table.insert(grassSquares, testSquare)
                        else -- it's a normal
                            table.insert(otherSquares, testSquare)
                        end
                    end
                end
            end
        end
    end

    local totalCandidates = #shoreSquares + #otherSquares + #treeSquares + #grassSquares
    if totalCandidates == 0 then return end

    local targetShore = math.floor(count * ((#shoreSquares / totalCandidates) * (cfg.shoreBias or 5)))
    local targetTree = math.floor(count * ((#treeSquares / totalCandidates) * (cfg.treeBias or 2)))
    local targetGrass = math.floor(count * ((#grassSquares / totalCandidates) * 2))
    targetShore = math.min(targetShore, count)
    targetTree = math.min(targetTree, count)
    targetGrass = math.min(targetGrass, count)
    local targetOther = count - targetShore - targetTree - targetGrass

    local spawned = 0

    local shoreSpawned = spawnFromPool(shoreSquares, targetShore, playerNum, texture)
    spawned = spawned + shoreSpawned

    local treeSpawned = spawnFromPool(treeSquares, targetTree, playerNum, texture)
    spawned = spawned + treeSpawned

    local grassSpawned = spawnFromPool(grassSquares, targetGrass, playerNum, texture)
    spawned = spawned + grassSpawned

    local otherSpawned = spawnFromPool(otherSquares, targetOther / 10, playerNum, texture)
    spawned = spawned + otherSpawned

    --[[ if cfg.debug then
        print(string.format("Spawned %d fireflies (%d from shore, %d from other)", spawned, shoreSpawned, otherSpawned))
    end ]]
end

function JBFireflies.onDailyCheck()
    local day = getDayOfYear()
    if isInSeason(day) then
        -- switch to ontick
        --print("JB's Fireflies: In season. Switching to OnTick check.")
        Events.EveryTenMinutes.Remove(JBFireflies.onDailyCheck)
        Events.OnTick.Add(JBFireflies.onTickFireflies)
    end
end

function JBFireflies.onTickFireflies(tick)
    local day = getDayOfYear()
    if not isInSeason(day) then
        -- switch to daily
        --print("JB's Fireflies: Out of season. Switching to daily check.")
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
