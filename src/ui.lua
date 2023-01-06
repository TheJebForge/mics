local basalt = require("lib.basalt")

local events = require("src.events")
local devices = require("src.devices")
local config = require("src.config")
local inv = require("src.inv")
local utils = require("src.utils")

local monitor, _ = next(devices.monitors)

basalt.setVariable("test", function()
    devices.speaker.playSound("minecraft:block.note_block.bit")
end)

basalt.setVariable("refreshInv", inv.refresh)

local main = basalt.createFrame("main")
    :setBackground(colors.gray)
    :addLayout(layoutsFolder .. "main.xml")
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

-- Inventory functionality
local itemList = main:getDeepObject("itemList")
local searchField = main:getDeepObject("searchField")
local sortMethod = main:getDeepObject("sortMethod")
local countField = main:getDeepObject("countField")

local uiInvCache = {}

local function searchBasedSort(search, sortFunction)
    return function(a, b)
        local isSearch = search ~= ""
        local aMatch = string.find(a.name:lower(), search)
        local bMatch = string.find(b.name:lower(), search)

        if aMatch and not bMatch then
            return true
        elseif not aMatch and bMatch and isSearch then
            return false
        else
            return sortFunction(a, b)
        end
    end
end

local function applySortAndVisibility()
    local method = config.sorting_method or 1
    local search = searchField:getValue():lower()

    if method == 1 then
        table.sort(uiInvCache, searchBasedSort(search, function(a, b)
            return a.id:lower() < b.id:lower()
        end))
    elseif method == 2 then
        table.sort(uiInvCache, searchBasedSort(search, function(a, b)
            return a.name:lower() < b.name:lower()
        end))
    elseif method == 3 then
        table.sort(uiInvCache, searchBasedSort(search, function(a, b)
            return b.count < a.count
        end))
    end

    local visible = 0

    for y, item in pairs(uiInvCache) do
        local obj = itemList:getObject(item.id)

        local visibility = true

        if search ~= "" then
            visibility = string.find(item.name:lower(), search) ~= nil
        end

        if obj then
            local color = y % 2 == 0 and colors.white or colors.lightGray

            obj:setPosition(1, y)

            obj:getObject("name"):setForeground(color)
            obj:getObject("count"):setForeground(color)

            if visibility then
                obj:show()
                visible = visible + 1
            else
                obj:hide()
            end
        end
    end

    local w, h = itemList:getSize()
    itemList:setScrollAmount(math.max(0, visible - h))
end

local function addItem(itemID)
    local row = #uiInvCache

    local itemFrame = itemList:addFrame(itemID)

    if itemFrame then
        itemFrame:addLayout(layoutsFolder .. "item.xml")
            :setBackground(colors.gray)
            :setSize("parent.w", 1)
            :setPosition(1, row)
            :onClick(function()
                inv.dispenseItems(itemID, tonumber(countField:getValue()) or 1)
            end)

        local name = inv.getItemName(itemID)
        itemFrame:getObject("name")
            :setText(name)

        local count = inv.getItemCount(itemID)
        
        local quantity = utils.formatQuantity(count)
        local quantityLen = string.len(quantity)
        itemFrame:getObject("count")
            :setText(quantity)
            :setSize(quantityLen, 1)
            :setPosition("parent.w - " .. quantityLen)

        table.insert(uiInvCache, {
            id = itemID,
            count = count,
            name = name,
        })
    end
end

local function removeItem(itemID)
    for index, item in pairs(uiInvCache) do
        if item.id == itemID then
            itemList:removeObject(itemID)
            table.remove(uiInvCache, index)
        end
    end
end

local function refresh()
    -- Clearing old items
    for i, item in pairs(uiInvCache) do
        itemList:removeObject(item.id)
        uiInvCache[i] = nil
    end

    -- Adding new items
    for itemID, _ in pairs(inv.listItems()) do
        addItem(itemID)
    end
end

-- Hiding item list when indexing is happening
local refreshScreen = main:getDeepObject("refreshScreen")

events.listen("inv_index_started", function()
    itemList:disable()
    itemList:hide()
    refreshScreen:enable()
    refreshScreen:show()
end)

events.listen("inv_index_done", function()
    refresh()
    applySortAndVisibility()
    itemList:enable()
    itemList:show()
    refreshScreen:disable()
    refreshScreen:hide()
end)

events.listen("item_added", function(_, itemID, _)
    addItem(itemID)
    applySortAndVisibility()
end)

events.listen("item_changed", function(_, itemID, _, newCount)
    for index, item in pairs(uiInvCache) do
        if item.id == itemID then
            item.count = newCount

            local itemFrame = itemList:getObject(item.id)
            
            if itemFrame then
                local quantity = utils.formatQuantity(item.count)
                local quantityLen = string.len(quantity)
                itemFrame:getObject("count")
                    :setText(quantity)
                    :setSize(quantityLen, 1)
                    :setPosition("parent.w - " .. quantityLen)
            end
        end
    end

    applySortAndVisibility()
end)

events.listen("item_removed", function(_, itemID)
    removeItem(itemID)
    applySortAndVisibility()
end)

-- Making sure sort method is preserved
sortMethod:selectItem(config.sorting_method or 1)

-- Process sorting method
sortMethod:onChange(function(self)
    config.sorting_method = self:getItemIndex()
    applySortAndVisibility()
end)

searchField:onChange(function(self)
    applySortAndVisibility()
    itemList:setOffset(0, 0)
end)


return basalt.autoUpdate