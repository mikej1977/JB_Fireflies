JBFireflies = JBFireflies or {}
local FireflyUI = require("jb_firefly_ui")
local SquareCollector = require("jb_firefly_collector")
local SpawnStatsWindow = require("jb_firefly_debug")
local spawnStatsUI
local gt = getGameTime()
local cm = getClimateManager()
local randy = newrandom()
local FIREFLY_TEXTURE = getTexture("media/textures/jb_firefly.png")

local function getDayOfYear()
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
    if dayOfYear < taperStart or dayOfYear > taperEnd then return 0 end
    local progress = (dayOfYear - taperStart) / (taperEnd - taperStart)
    return math.sin(progress * math.pi)
end

function JBFireflies.getTemperatureFactor()
    local temp = cm:getTemperature()
    if temp < 13 then return 0 end
    if temp >= 25 then return 1 end
    return (temp - 13) / 12
end

function JBFireflies.getNightFactor()
    local night = gt:getNight()
    if night < 0.3 then return 0 end
    if night > 0.6 then return 1 end
    return night
end

function JBFireflies.getRainFactor()
    local rain = math.min(cm:getPrecipitationIntensity(), 1)
    return 1 - rain
end

function JBFireflies.getAdjustedSpawnCount(baseCount)
    local dayOfYear = getDayOfYear()
    local seasonal = JBFireflies.getSeasonalFactor(dayOfYear)
    local temp = JBFireflies.getTemperatureFactor()
    local night = JBFireflies.getNightFactor()
    local rain = JBFireflies.getRainFactor()
    return math.floor(baseCount * seasonal * temp * night * rain)
end

local function calculateSpawnTargets(totalToSpawn, shoreSquares, treeSquares, grassSquares, otherSquares)
    local shorePercent = 0.40
    local treePercent = 0.40
    local grassPercent = 0.20

    local shorePool = #shoreSquares
    local treePool = #treeSquares
    local grassPool = #grassSquares
    local otherPool = #otherSquares

    local remainingToSpawn = totalToSpawn

    local targetShore = math.floor(totalToSpawn * shorePercent)
    local actualShore = math.min(shorePool, targetShore)
    remainingToSpawn = remainingToSpawn - actualShore

    local unspawnedShore = targetShore - actualShore
    local targetTree = math.floor(totalToSpawn * treePercent) + unspawnedShore
    local actualTree = math.min(treePool, targetTree)
    remainingToSpawn = remainingToSpawn - actualTree

    local unspawnedTree = targetTree - actualTree
    local targetGrass = math.floor(totalToSpawn * grassPercent) + unspawnedTree
    local actualGrass = math.min(grassPool, targetGrass)
    remainingToSpawn = remainingToSpawn - actualGrass

    local targetOther = remainingToSpawn
    local actualOther = math.min(otherPool, targetOther)

    return actualShore, actualTree, actualGrass, actualOther
end

local function spawnFromPool(pool, count, playerNum, texture)
    local spawnedCount = 0
    while count > 0 and #pool > 0 do
        local index = randy:random(1, #pool)
        local gsq = pool[index]
        table.remove(pool, index)
        FireflyUI:new(playerNum, texture, gsq)
        count = count - 1
        spawnedCount = spawnedCount + 1
    end
    return spawnedCount
end

function JBFireflies.spawnFromPools(totalToSpawn, shoreSquares, treeSquares, grassSquares, otherSquares)
    local cfg = SandboxVars.JBFireflyOptions
    local player = getPlayer()
    if not player then return end

    local playerNum = player:getPlayerNum()

    local targetShore, targetTree, targetGrass, targetOther =
        calculateSpawnTargets(totalToSpawn, shoreSquares, treeSquares, grassSquares, otherSquares)

    local shoreSpawned = spawnFromPool(shoreSquares, targetShore, playerNum, FIREFLY_TEXTURE)
    local treeSpawned = spawnFromPool(treeSquares, targetTree, playerNum, FIREFLY_TEXTURE)
    local grassSpawned = spawnFromPool(grassSquares, targetGrass, playerNum, FIREFLY_TEXTURE)
    local otherSpawned = spawnFromPool(otherSquares, targetOther, playerNum, FIREFLY_TEXTURE)

    if cfg.debug and spawnStatsUI then
        local spawned = shoreSpawned + treeSpawned + grassSpawned + otherSpawned
        spawnStatsUI:updateStats(spawned, totalToSpawn, shoreSpawned, treeSpawned, grassSpawned, otherSpawned)
    end
end

local function toggleSpawnStatsWindow()
    if spawnStatsUI and spawnStatsUI:getIsVisible() then
        spawnStatsUI:setVisible(false)
        spawnStatsUI:removeFromUIManager()
    else
        if not spawnStatsUI then
            spawnStatsUI = SpawnStatsWindow:new(300, 300, 300, 250)
        end
        spawnStatsUI:addToUIManager()
        spawnStatsUI:setVisible(true)
    end
end

function JBFireflies.onDailyCheck()
    local day = getDayOfYear()
    if isInSeason(day) then
        -- if JBFireflies.Config.debug then print("JB's Fireflies: In season. Switching to OnTick check.") end
        Events.EveryTenMinutes.Remove(JBFireflies.onDailyCheck)
        Events.OnTick.Add(JBFireflies.onTickFireflies)
    end
end

function JBFireflies.onTickFireflies(tick)
    local day = getDayOfYear()
    if not isInSeason(day) then
        Events.OnTick.Remove(JBFireflies.onTickFireflies)
        Events.EveryTenMinutes.Add(JBFireflies.onDailyCheck)
        return
    end

    local cfg = SandboxVars.JBFireflyOptions

    if tick % cfg.ticksToSpawn == 0 and not SquareCollector.active then
        local base = randy:random(cfg.minSpawn, cfg.maxSpawn)
        JBFireflies.pendingSpawnCount = base
        SquareCollector:start(getPlayer(), cfg)
    end

    SquareCollector:update()

    if JBFireflies.pendingSpawnCount and not SquareCollector.active then
        local shoreSquares, treeSquares, grassSquares, otherSquares = SquareCollector:getPools()
        JBFireflies.spawnFromPools(JBFireflies.pendingSpawnCount, shoreSquares, treeSquares, grassSquares, otherSquares)
        JBFireflies.pendingSpawnCount = nil
    end
end

Events.OnGameStart.Add(function()
    JBFireflies.Config = SandboxVars.JBFireflyOptions
    JBFireflies.Config.debug = false ---------------------------------------------- ########################## MAKE SURE AND TURN THIS SHIT OFF BEFORE UPLOADING NEXT TIME
    JBFireflies.Config.spawnArea = math.min(JBFireflies.Config.spawnArea, 150)
    local day = getDayOfYear()
    if isInSeason(day) then
        Events.OnTick.Add(JBFireflies.onTickFireflies)
    else
        Events.EveryTenMinutes.Add(JBFireflies.onDailyCheck)
    end

    if JBFireflies.Config.debug then
        Events.OnKeyPressed.Add(function(key)
            if key == Keyboard.KEY_0 then
                toggleSpawnStatsWindow()
            end
        end)
    end
end)


