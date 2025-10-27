local FireflyUI = require("jb_firefly_ui")
local SpawnStatsWindow = require("jb_firefly_debug")
local spawnStatsUI

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
        debug               = false
    }

--[[
    if cfg.debug then
        cfg.ticksToSpawn        = 10
        cfg.minSpawn            = 3
        cfg.maxSpawn            = 8
        cfg.maxFireflyInstances = 500
        cfg.spawnArea           = 40
        cfg.overSample          = 25
    end
]]

    return cfg
end

JBFireflies.Config = setupConfig()

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

local function clearTable(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function isShoreline(sq)
    if not sq then return false end
    local water = sq:getWater()
    return water and water:isActualShore()
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

function JBFireflies.getAdjustedSpawnCount(baseCount)
    local dayOfYear = getDayOfYear()
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

    clearTable(shoreSquares)
    clearTable(treeSquares)
    clearTable(grassSquares)
    clearTable(otherSquares)

    local sampleSize = count * (cfg.overSample or 5)

    for _ = 1, sampleSize do
        local dx = randy:random(-cfg.spawnArea, cfg.spawnArea)
        local dy = randy:random(-cfg.spawnArea, cfg.spawnArea)

        if (dx * dx + dy * dy) > minSpawnDistSq then
            local testSquare = cell:getGridSquare(px + dx, py + dy, pz)

            if testSquare then
                local waterBody = testSquare:getWater()
                local isWaterNotShore = (waterBody and not waterBody:isActualShore())
                local isViewBlocked = cfg.hideCantSee and not testSquare:isCanSee(playerNum)
                local isStandardValid = testSquare:isOutside() and testSquare:IsOnScreen() and
                    not cell:IsBehindStuff(testSquare) and not isViewBlocked

                if isStandardValid then
                    if isWaterNotShore then
                        if randy:random(1, 100) <= 2 then
                            table.insert(otherSquares, testSquare)
                        end
                    end
                    if isShoreline(testSquare) then
                        local randomX = randy:random(-1,1)
                        local randomY = randy:random(-1, 1)
                        local randomSquare = cell:getGridSquare(testSquare:getX() + randomX, testSquare:getY() + randomY, pz)
                        if randomSquare then
                            table.insert(shoreSquares, randomSquare)
                        else
                            table.insert(shoreSquares, testSquare)
                        end
                    end
                    if testSquare:HasTree() then
                        table.insert(treeSquares, testSquare)
                    elseif testSquare:hasGrassLike() then
                        table.insert(grassSquares, testSquare)
                    else
                        if not isWaterNotShore then
                            table.insert(otherSquares, testSquare)
                        end
                    end
                end
            end
        end
    end
end

local function calculateSpawnTargets(totalToSpawn)
    local shorePercent = 0.70
    local treePercent = 0.20
    local grassPercent = 0.10

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

function JBFireflies.spawnRandomFireflies(baseCount)
    local player = getPlayer()
    if not player then return end

    local cfg = JBFireflies.Config
    local count = JBFireflies.getAdjustedSpawnCount(baseCount)
    if count == 0 then return end

    collectCandidateSquares(player, cfg, count)

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
        if spawnStatsUI then
            spawnStatsUI:updateStats(spawned, count, shoreSpawned, treeSpawned, grassSpawned, otherSpawned)
        end
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
        -- if JBFireflies.Config.debug then print("JB's Fireflies: Out of season. Switching to daily check.") end
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

if JBFireflies.Config.debug then
    Events.OnKeyPressed.Add(function(key)
        if key == Keyboard.KEY_0 then
            toggleSpawnStatsWindow()
        end
    end)
end


