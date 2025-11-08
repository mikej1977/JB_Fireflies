local randy = newrandom()
local shoreSquares, treeSquares, grassSquares, otherSquares = {}, {}, {}, {}

local function clearTable(t) t[#t] = nil end

-- since PZ java getGrassLike doesn't do any null checks on sprite name
local GRASS_PREFIXES = {
    { "e_newgrass_",            #"e_newgrass_" },
    { "blends_grassoverlays_",  #"blends_grassoverlays_" },
    { "d_plants_",              #"d_plants_" },
    { "d_generic_1_",           #"d_generic_1_" },
    { "d_floorleaves_",         #"d_floorleaves_" },
}

local function JB_hasGrassLike(sq)
    if not sq then return false end
    local objects = sq:getObjects()
    for i = 0, objects:size() - 1 do
        local sprite = objects:get(i):getSprite()
        if sprite then
            local name = sprite:getName()
            if name then
                for j = 1, #GRASS_PREFIXES do
                    local prefix, len = GRASS_PREFIXES[j][1], GRASS_PREFIXES[j][2]
                    if name:sub(1, len) == prefix then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function isBehindStuff(sq)
    if not sq or not sq:getProperties():Is(IsoFlagType.exterior) then
        return true
    end

    local cell = getCell()
    local x0, y0, z0 = sq:getX(), sq:getY(), sq:getZ()
    local maxZ = 8

    for dz = 1, maxZ - z0 do
        local z = z0 + dz
        local offset = dz * 3

        for dy = -5, 6 do
            for dx = -5, 6 do
                if dx >= dy - 5 and dx <= dy + 5 then
                    local x = x0 + dx + offset
                    local y = y0 + dy + offset
                    local square1 = cell:getGridSquare(x, y, z)

                    if square1 and not square1:getObjects():isEmpty() then
                        if dz ~= 1 or square1:getObjects():size() ~= 1 then
                            return true
                        end

                        local obj = square1:getObjects():get(0)
                        local sprite = obj:getSprite()
                        if sprite then
                            local name = sprite and sprite:getName()
                            if not name or not luautils.stringStarts(name, "lighting_outdoor") then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

--[[ local function isShoreline(sq)
    if not sq then return false end
    local water = sq:getWater()
    return water and water:isActualShore()
end ]]

local function isShoreline(square)
    if not square or not square:getProperties():Is(IsoFlagType.water) then return false end

    local directions = {
        IsoDirections.N, IsoDirections.NE, IsoDirections.E, IsoDirections.SE,
        IsoDirections.S, IsoDirections.SW, IsoDirections.W, IsoDirections.NW
    }

    for _, dir in ipairs(directions) do
        local adj = square:getAdjacentSquare(dir)
        if adj and not adj:getProperties():Is(IsoFlagType.water) then
            return true
        end
    end

    return false
end

local SquareCollector = {
    active = false,
    totalSamples = 0,
    processed = 0,
    perTick = 0,
    player = nil,
    cfg = nil,
    px = 0,
    py = 0,
    pz = 0,
    playerNum = 0,
}

function SquareCollector:start(player, cfg)
    clearTable(shoreSquares)
    clearTable(treeSquares)
    clearTable(grassSquares)
    clearTable(otherSquares)

    self.player = player
    self.cfg = cfg
    self.px, self.py, self.pz = player:getX(), player:getY(), player:getZ()
    self.playerNum = player:getPlayerNum()

    local area = (self.cfg.spawnArea * 2) * (self.cfg.spawnArea * 2)
    local sampleDensity = (cfg.overSample or 3) / 100
    self.totalSamples = math.max(100, math.floor(area * sampleDensity))
    self.perTick = math.max(1, math.floor(self.totalSamples / cfg.ticksToSpawn))
    self.processed = 0
    self.active = true
end

function SquareCollector:update()
    if not self.active then return end

    local cell = getWorld():getCell()
    local minSpawnDistSq = 2

    for _ = 1, self.perTick do
        if self.processed >= self.totalSamples then
            self.active = false
            break
        end
        self.processed = self.processed + 1

        local dx = randy:random(-self.cfg.spawnArea, self.cfg.spawnArea)
        local dy = randy:random(-self.cfg.spawnArea, self.cfg.spawnArea)

        if (dx * dx + dy * dy) > minSpawnDistSq then
            local sq = cell:getGridSquare(self.px + dx, self.py + dy, self.pz)
            if sq then
                local waterBody = sq:getWater()
                
                local isWaterNotShore = waterBody and not isShoreline(sq) --waterBody:isActualShore()
                
                local isViewBlocked = self.cfg.hideCantSee and not sq:isCanSee(self.playerNum)

                local isStandardValid =
                    sq:isOutside() and
                    sq:IsOnScreen() and
                    --not cell:IsBehindStuff(sq) and
                    not isBehindStuff(sq) and
                    not isViewBlocked

                if isStandardValid then
                    if isWaterNotShore and randy:random(1, 100) <= 1 then
                        table.insert(otherSquares, sq)
                    end

                    if isShoreline(sq) then
                        local randomX, randomY = randy:random(-1, 1), randy:random(-1, 1)
                        local randomSquare = cell:getGridSquare(
                            sq:getX() + randomX,
                            sq:getY() + randomY,
                            self.pz
                        )
                        table.insert(shoreSquares, randomSquare or sq)
                    end

                    if sq:HasTree() then
                        table.insert(treeSquares, sq)
                    elseif JB_hasGrassLike(sq) then
                    --elseif sq:hasGrassLike() then
                        table.insert(grassSquares, sq)
                    elseif not isWaterNotShore then
                        table.insert(otherSquares, sq)
                    end
                end
            end
        end
    end
end

function SquareCollector:getPools()
    return shoreSquares, treeSquares, grassSquares, otherSquares
end

return SquareCollector
