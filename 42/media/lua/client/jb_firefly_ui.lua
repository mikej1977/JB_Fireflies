local FireflyUI = {}
FireflyUI.__index = FireflyUI

local randy = newrandom()
FireflyUI.instances = {}

local SIN_TABLE = {}
for i = 1, 360 do
    local angleRad = math.rad(i)
    SIN_TABLE[i] = {
        sin = math.sin(angleRad),
        cos = math.cos(angleRad),
    }
end

local function getSinCos(angleInDegrees)
    local roundedAngle = ((math.floor(angleInDegrees) % 360) + 360) % 360 + 1
    return SIN_TABLE[roundedAngle].sin, SIN_TABLE[roundedAngle].cos
end

local EASE_TABLE = {}
for i = 1, 100 do
    local t = i / 100
    EASE_TABLE[i] = 1 - t ^ 0.3
end
EASE_TABLE[0] = 1

local function randomFloat(min, max)
    return min + randy:random() * (max - min)
end

local function setupRandoms(playerNum)
    local zoom = getCore():getZoom(playerNum)
    return {
        maxFrames = randy:random(60, 250),
        size = math.max(2, randy:random(2, 5) * zoom),
        offsetX = randy:random(-1, 1) / 10,
        offsetY = randy:random(-1, 1) / 10,
        baseAlpha = randy:random(50, 100) / 100
    }
end

function FireflyUI:new(playerNum, texture, square)
    local cfg = JBFireflies.Config
    if #FireflyUI.instances >= cfg.maxFireflyInstances then return end

    local o = setmetatable({}, self)
    o.playerNum = playerNum
    o.texture = texture
    o.square = square
    o.frameCount = 0
    o.doneFlashing = false

    local params = setupRandoms(playerNum)
    o.maxFrames = params.maxFrames
    o.size = params.size
    o.offsetX = params.offsetX
    o.offsetY = params.offsetY
    o.baseAlpha = params.baseAlpha

    o.angle = randomFloat(0, 360)
    o.speed = randomFloat(0.001, 0.002)
    o.rotationRate = randomFloat(-0.02, 0.02)

    table.insert(FireflyUI.instances, o)
    return o
end

function FireflyUI:render()
    self.frameCount = self.frameCount + 1

    if self.doneFlashing then return end

    if self.frameCount > self.maxFrames then
        self.doneFlashing = true
        return
    end

    if not self.texture or not self.square:IsOnScreen() then
        self.doneFlashing = true
        return
    end

    local player = getSpecificPlayer(self.playerNum)
    local px, py = player:getX(), player:getY()
    local fx = self.square:getX() + self.offsetX
    local fy = self.square:getY() + self.offsetY

    local dx, dy = fx - px, fy - py
    local dist = math.sqrt(dx * dx + dy * dy)
    local distFactor = math.max(.1, 1 - (dist / 4))

    local lightLevel = self.square:getLightLevel(self.playerNum) or -1
    local lightFactor = 1 - math.min(lightLevel / 1.0, 1.0)

    self.angle = self.angle + self.rotationRate
    local sin, cos = getSinCos(self.angle)
    self.offsetX = self.offsetX + cos * self.speed
    self.offsetY = self.offsetY + sin * self.speed

    local sqx = self.square:getX() + self.offsetX
    local sqy = self.square:getY() + self.offsetY
    local sqz = self.square:getZ()
    local scrx, scry = ISCoordConversion.ToScreen(sqx, sqy, sqz, self.playerNum)

    local t = self.frameCount / self.maxFrames
    local easedAlpha = self.baseAlpha * EASE_TABLE[math.floor(t * 100)]
    local finalAlpha = easedAlpha * distFactor * (lightFactor * 25)

    if finalAlpha < 0.1 then
        self.doneFlashing = true
        return
    end

    UIManager.DrawTexture(self.texture, scrx, scry, self.size, self.size, finalAlpha)
end

function FireflyUI.renderAll()
    for i = #FireflyUI.instances, 1, -1 do
        local inst = FireflyUI.instances[i]

        inst:render()

        if inst.doneFlashing then
            table.remove(FireflyUI.instances, i)
        end
    end

    if JBFireflies.Config.debug then
        getTextManager():DrawString(150, 150,
            string.format("Fireflies: %d", #FireflyUI.instances),
            0.6, 1.0, 0.6, 1.0)
    end
end

Events.OnGameStart.Add(function()
    Events.OnPostRender.Add(FireflyUI.renderAll)
end)

return FireflyUI
