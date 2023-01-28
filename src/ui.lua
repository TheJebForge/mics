local basalt = require("lib.basalt")

local events = require("src.events")
local devices = require("src.devices")
local config = require("src.config")
local inv = require("src.inv")
local craft = require("src.craft")
local utils = require("src.utils")

local monitor, _ = next(devices.monitors)

basalt.setVariable("test", function()
    devices.speaker.playSound("minecraft:block.note_block.bit")
end)

basalt.setVariable("refreshInv", inv.refresh)
basalt.setVariable("refreshCraft", craft.refresh)

local main = basalt.createFrame("main")
    :setBackground(colors.gray)
    :addLayout(layoutsFolder .. "main.xml")
    -- :setMonitor(monitor)

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
do
    local itemList = main:getDeepObject("itemList")
    local searchField = main:getDeepObject("searchField")
    local sortMethod = main:getDeepObject("sortMethod")
    local countField = main:getDeepObject("countField")

    local _, height = itemList:getSize()

    local uiInvCache = {}
    local position = 0
    local visibleCount = 0

    local function updateItems()
        for i = 1, height do
            local index = i + position
            local item = uiInvCache[index]

            local name = ""
            local quantity = ""
            if item and item.visible then
                name = item.name
                quantity = utils.formatQuantity(item.count)
            end

            local itemFrame = itemList:getObject("y" .. i)

            if itemFrame then
                local color = index % 2 == 1 and colors.white or colors.lightGray

                itemFrame:getObject("name")
                    :setText(name)
                    :setForeground(color)

                local quantityLen = string.len(quantity)
                itemFrame:getObject("count")
                    :setText(quantity)
                    :setSize(quantityLen, 1)
                    :setPosition("parent.w - " .. quantityLen)
                    :setForeground(color)
            end
        end
    end
    
    -- Populating item list with empty items
    for i = 1, height do
        itemList:addFrame("y"..i)
            :addLayout(layoutsFolder .. "item.xml")
            :setBackground(colors.gray)
            :setSize("parent.w", 1)
            :setPosition(1, i)
            :onClick(function()
                local index = i + position

                if uiInvCache[index] then
                    inv.dispenseItems(uiInvCache[index].id, tonumber(countField:getValue()) or 1)
                end
            end)
    end

    itemList:onScroll(function(list, ev, dir, x, y) 
        local floor = math.max(0, visibleCount - height)
        position = math.min(math.max(position + dir, 0), floor)
        updateItems()
    end)

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

        visibleCount = 0

        for y, item in pairs(uiInvCache) do
            local visibility = true

            if search ~= "" then
                visibility = string.find(item.name:lower(), search) ~= nil
            end

            if visibility then
                visibleCount = visibleCount + 1
            end

            item.visible = visibility
        end

        updateItems()
    end

    local function addItem(itemID)
        for _, item in pairs(uiInvCache) do
            if item.id == itemID then
                return
            end
        end
    
        local name = inv.getItemName(itemID)
        local count = inv.getItemCount(itemID)

        table.insert(uiInvCache, {
            id = itemID,
            count = count,
            name = name,
            visible = true,
        })
    end

    local function removeItem(itemID)
        for index, item in pairs(uiInvCache) do
            if item.id == itemID then
                table.remove(uiInvCache, index)
            end
        end
    end

    local function refresh()
        uiInvCache = {}

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
        position = 0
        applySortAndVisibility()
    end)
end

-- Craft functionality
-- do
--     local craftList = main:getDeepObject("craftList")
--     local searchField = main:getDeepObject("craftSearchField")

--     -- Populating item list with empty items
--     local _, height = craftList:getSize()

--     for i = 1, height do
--         local item = craftList:addFrame("y"..i)
--             :addLayout(layoutsFolder .. "item.xml")
--             :setBackground(colors.gray)
--             :setSize("parent.w", 1)
--             :setPosition(1, i)

--         item:getObject("count")
--             :setText("CRAFT")
--             :setSize(5, 1)
--             :setPosition("parent.w - " .. 5)
--     end

--     local uiCraftCache = {}
--     local position = 0
--     local visibleCount = 0

--     local function updateItems()
--         for i = 1, height do
--             local index = i + position
--             local item = uiCraftCache[index]

--             local name = ""
--             if item and item.visible then
--                 name = item.name
--             end

--             local itemFrame = craftList:getObject("y" .. i)

--             if itemFrame then
--                 local color = index % 2 == 1 and colors.white or colors.lightGray

--                 itemFrame:getObject("name")
--                     :setText(name)
--                     :setForeground(color)

--                 itemFrame:getObject("count")
--                     :setForeground(color)
--             end
--         end
--     end

--     craftList:onScroll(function(list, ev, dir, x, y) 
--         local floor = math.max(0, visibleCount - height)
--         position = math.min(math.max(position + dir, 0), floor)
--         updateItems()
--     end)

--     local function searchBasedSort(search)
--         return function(a, b)
--             local isSearch = search ~= ""
--             local aMatch = string.find(a.name:lower(), search)
--             local bMatch = string.find(b.name:lower(), search)

--             if aMatch and not bMatch then
--                 return true
--             elseif not aMatch and bMatch and isSearch then
--                 return false
--             else
--                 return a.name:lower() < b.name:lower()
--             end
--         end
--     end

--     local function applySortAndVisibility()
--         local search = searchField:getValue():lower()

--         table.sort(uiCraftCache, searchBasedSort(search))

--         visibleCount = 0

--         for y, item in pairs(uiCraftCache) do
--             local visibility = true

--             if search ~= "" then
--                 visibility = string.find(item.name:lower(), search) ~= nil
--             end

--             if visibility then
--                 visibleCount = visibleCount + 1
--             end

--             item.visible = visibility
--         end

--         updateItems()
--     end

--     local function addItem(craftID)
--         for _, item in pairs(uiCraftCache) do
--             if item.id == craftID then
--                 return
--             end
--         end

--         local name = craft.getRecipe(craftID).n

--         table.insert(uiCraftCache, {
--             id = craftID,
--             name = name,
--             visible = true,
--         })
--     end

--     local function refresh()
--         uiInvCache = {}

--         -- Adding new items
--         local yielder = utils.yielder()
--         for craftID, _ in pairs(craft.listCrafts()) do
--             addItem(craftID)
--             yielder.yield()
--         end
--     end

--     refresh()
--     applySortAndVisibility()

--     searchField:onChange(function(self)
--         position = 0
--         applySortAndVisibility()
--     end)
-- end

-- <!-- <input id="craftSearchField" default="Search..." x="1" y="1" width="parent.w" bg="lightGray"/> -->
--         <!-- <button text="+" x="parent.w - 2" y="1" width="1" height="1" onClick="refreshCraft" bg="lightGray"/>
--         <button text="R" x="parent.w" y="1" width="1" height="1" onClick="refreshCraft" bg="lightGray"/> -->
--         <!-- <frame id="craftList" x="1" y="2" width="parent.w + 1" height="parent.h - 2" bg="gray" scrollable="false" zIndex="1">

--         </frame> -->

return basalt.autoUpdate