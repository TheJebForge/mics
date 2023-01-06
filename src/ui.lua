local basalt = require("lib.basalt")

local events = require("src.events")
local devices = require("src.devices")
local config = require("src.config")

local monitor, _ = next(devices.monitors)

local main = basalt.createFrame("main")
    :setBackground(colors.gray)
    :addLayout("mics/src/layouts/main.xml")
    --:setMonitor(monitor)

local rootMenu = main:getDeepObject("rootMenu")
local rootFrame = main:getDeepObject("rootFrame")

-- Scroll the frame on menu bar click
local selectedTab = 1

rootMenu:onChange(function(self)
    selectedTab = self:getItemIndex()
    local position = main:getWidth() * (selectedTab - 1)
    main:addAnimation():setObject(rootFrame):setAutoDestroy():offset(position,0,0.2):play()
end)

-- Inventory tab
local searchField = main:getDeepObject("searchField")
local sortMethod = main:getDeepObject("sortMethod")

sortMethod:selectItem(config.sorting_method or 1)

-- Process sorting method
sortMethod:onChange(function(self)
    config.sorting_method = self:getItemIndex()
end)


return basalt.autoUpdate