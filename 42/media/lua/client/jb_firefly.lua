local FireflyUI = require("jb_firefly_ui")
JBFireflies = JBFireflies or {}
local randy = newrandom()
local options = SandboxVars.JBFireflyOptions

JBFireflies.Config = {
    ticksToSpawn        = options.ticksToSpawn,
    minSpawn            = options.minSpawn,
    maxSpawn            = options.maxSpawn,
    maxFireflyInstances = options.maxFireflyInstances,
    spawnArea           = options.spawnArea,
    taperDays           = options.taperDays,
    startDay            = options.startDay,
    endDay              = options.endDay,
    hideCantSee         = options.hideCantSee,
    debug               = false
}

local function getDayOfYear()
    local gt = getGameTime()
    return (gt:getMonth() + 1)* 30 + gt:getDay()
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

    if cfg.debug then
        print(string.format(
            "Day %d | Seasonal %.2f | Temp %.2f | Night %.2f | Rain %.2f | %d fireflies",
            dayOfYear, seasonal, temp, night, rain, adjusted
        ))
    end

    return adjusted
end

function JBFireflies.spawnRandomFireflies(baseCount)
    local player = getPlayer()
    if not player then return end

    local cfg = JBFireflies.Config
    local cell = getWorld():getCell()
    local texture = getTexture("media/textures/jb_firefly.png")
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local playerNum = player:getPlayerNum()

    local count = JBFireflies.getAdjustedSpawnCount(baseCount)
    if count == 0 then return end

    local spawned = 0
    for _ = 1, count do
        local square
        for _ = 1, 10 do
            local dx = randy:random(-cfg.spawnArea, cfg.spawnArea)
            local dy = randy:random(-cfg.spawnArea, cfg.spawnArea)
            if dx * dx + dy * dy > 25 then
                local testSquare = cell:getGridSquare(px + dx, py + dy, pz)
                if testSquare and testSquare:isOutside() and testSquare:IsOnScreen() and not cell:IsBehindStuff(testSquare) and (not cfg.hideCantSee or testSquare:isCanSee(playerNum)) then
                    square = testSquare
                    break
                end
            end
        end
        if square then
            FireflyUI:new(playerNum, texture, square)
            spawned = spawned + 1
        end
    end

    if cfg.debug then
        print(string.format("Spawned %d fireflies", spawned))
    end
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