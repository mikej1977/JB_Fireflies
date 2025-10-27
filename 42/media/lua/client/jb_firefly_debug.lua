local SpawnStatsWindow = ISCollapsableWindow:derive("SpawnStatsWindow")

function SpawnStatsWindow:initialise()
    ISCollapsableWindow.initialise(self)

    local y = 30
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local pad = 4

    self.spawnedLabel = ISLabel:new(10, y, fontHgt, "Spawned:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.spawnedLabel)
    y = y + fontHgt + pad

    self.shoreLabel = ISLabel:new(10, y, fontHgt, "Shore:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.shoreLabel)
    y = y + fontHgt + pad

    self.treeLabel = ISLabel:new(10, y, fontHgt, "Tree:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.treeLabel)
    y = y + fontHgt + pad

    self.grassLabel = ISLabel:new(10, y, fontHgt, "Grass:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.grassLabel)
    y = y + fontHgt + pad

    self.otherLabel = ISLabel:new(10, y, fontHgt, "Other:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.otherLabel)
end

function SpawnStatsWindow:updateStats(spawned, count, shore, tree, grass, other)
    self.spawnedLabel:setName(string.format("Spawned: %d of %d", spawned, count))
    self.shoreLabel:setName(string.format("Shore: %d", shore))
    self.treeLabel:setName(string.format("Tree: %d", tree))
    self.grassLabel:setName(string.format("Grass: %d", grass))
    self.otherLabel:setName(string.format("Other: %d", other))
end

function SpawnStatsWindow:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height, true)
    setmetatable(o, self)
    self.__index = self
    o.title = "Firefly Spawn Debug"
    o.resizable = false
    o.pin = false
    o:initialise()
    return o
end

return SpawnStatsWindow
