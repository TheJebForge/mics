local utils = require("src.utils")
local events = require("src.events")
local devices = require("src.devices")
local config = require("src.config")

local expectModule = require "cc.expect"
local expect, field = expectModule.expect, expectModule.field

local export = {}

local oldInvCache = {}
local invCache = {}
local refreshing = false

function export.formatItemID(item)
    expect(1, item, "table")

    return (item.name or "") .. ":" .. (item.nbt or "")
end

local function scanInventory(_, index, continue)
    continue = continue or true
    local name, inventory = index, devices.inventories[index]

    if inventory then
        for slot, item in pairs(inventory.list()) do
            local itemID = export.formatItemID(item)

            if invCache[itemID] then
                invCache[itemID].count = invCache[itemID].count + item.count
                if invCache[itemID].places[name] then
                    invCache[itemID].places[name][slot] = item.count
                else
                    invCache[itemID].places[name] = { [slot] = item.count }
                end
            else
                local detailedItem = inventory.getItemDetail(slot)

                detailedItem.places = { [name] = { [slot] = item.count } }
                invCache[itemID] = detailedItem
            end
        end

        if continue then
            events.queue("scan_inventory", next(devices.inventories, name))
        end
    else
        refreshing = false
        events.queue("inv_index_done")
    end
end

events.listen("scan_inventory", scanInventory)

local function detectInventoryChanges()
    local keys = utils.listAllKeys(oldInvCache, invCache)

    for id, _ in pairs(keys) do
        local oldItem = oldInvCache[id]
        local item = invCache[id]

        if oldItem and item then
            if oldItem.count ~= item.count then
                events.queue("item_changed", id, oldItem.count, item.count)
            end
        elseif oldItem then
            events.queue("item_removed", id, oldItem)
        else
            events.queue("item_added", id, item)
        end
    end
end

events.listen("inv_index_done", function()
    detectInventoryChanges()
end)

events.listen("device_added", function(_, ty)
    if ty == "inventory" then
        export.refresh()
    end
end)

events.listen("device_removed", function(_, ty)
    if ty == "inventory" then
        export.refresh()
    end
end)

function export.refresh()
    if not refreshing then
        oldInvCache = invCache
        invCache = {}
        
        refreshing = true
        events.queue("inv_index_started")

        events.queue("scan_inventory", next(devices.inventories))
    end
end

function export.listItems()
    return invCache 
end

local function pushItems(itemID, count, method)
    expect(1, itemID, "string")
    expect(2, count, "number")
    expect(3, method, "function")

    if not invCache[itemID] then
        return 0, "Item not found"
    end

    local totalPulled = 0
    local item = invCache[itemID]
    local full = false

    for inventoryName, slots in pairs(item.places) do
        local inventory = devices.inventories[inventoryName]
        
        for slot, slotCount in pairs(slots) do
            if inventory then
                local pulled = method(inventoryName, inventory, slot, count)

                if pulled == 0 then
                    full = true
                    break
                else
                    count = count - pulled
                    totalPulled = totalPulled + pulled
                end

                slots[slot] = slots[slot] - pulled
                item.count = item.count - pulled

                if slots[slot] <= 0 then
                    slots[slot] = nil
                end
            else
                item.count = item.count - slotCount
                slots[slot] = nil
            end

            sleep(0)
        end

        if not next(slots) then
            item.places[inventoryName] = nil
        end

        if full then
            break
        end
    end

    if item.count <= 0 then
        events.queue("item_removed", itemID, item)
        invCache[itemID] = nil
    else
        events.queue("item_changed", itemID, item.count + totalPulled, item.count)
    end

    if count > 0 then
        return totalPulled, "Not enough items"
    end

    if full then
        return totalPulled, "Target is full"
    else
        return totalPulled
    end
end

function export.pushItems(itemID, count, target, targetSlot)
    expect(1, itemID, "string")
    expect(2, count, "number")
    expect(3, target, "string")
    expect(4, targetSlot, "number", "nil")

    local method

    if target == "introspection" then
        local introspection = devices.getIntrospectionManipulator()

        if introspection then
            ---@diagnostic disable-next-line: redefined-local
            method = function(inventoryName, inventory, slot, count)
                return introspection.getInventory().pullItems(inventoryName, slot, count, targetSlot)
            end
        else
            return 0, "No bound introspection module found"
        end
    else
        ---@diagnostic disable-next-line: redefined-local
        method = function(inventoryName, inventory, slot, count)
            return inventory.pushItems(target, slot, count, targetSlot)
        end
    end 

    return pushItems(itemID, count, method)
end

local function pullItems(count, infoMethod, pullMethod)
    local item = infoMethod() or {}
    local itemID = export.formatItemID(item)

    if not item.count then
        return 0
    end

    if (item.count or 0) < count then
        count = item.count
    end

    if count <= 0 then
        return 0
    end

    local previouslyExisted = false
    local totalPushed = 0

    -- Attempting to push items into chests together with other similar items
    if invCache[itemID] then
        previouslyExisted = true
        local storageItem = invCache[itemID]

        for inventory, slots in pairs(storageItem.places) do
            local invObject = devices.inventories[inventory]
            local pushed = pullMethod(inventory, invObject, count)

            count = count - pushed
            storageItem.count = storageItem.count + pushed
            totalPushed = totalPushed + pushed
            
            if pushed > 0 then
                for slotIndex, slotItem in pairs(invObject.list()) do
                    if export.formatItemID(slotItem) == itemID then
                        slots[slotIndex] = slotItem.count
                    end
                end
            end

            if count <= 0 then
                break
            end

            sleep(0)
        end

        item = storageItem
    else
        invCache[itemID] = item
    end

    -- Checking if we still have some items to push
    if count > 0 then
        for invName, invObject in pairs(devices.inventories) do
            local pushed = pullMethod(invName, invObject, count)

            count = count - pushed
            totalPushed = totalPushed + pushed
            
            if pushed > 0 then
                if not item.places then
                    item.places = { [invName] = {} }
                end

                if not item.places[invName] then
                    item.places[invName] = {}
                end

                for slotIndex, slotItem in pairs(invObject.list()) do
                    if export.formatItemID(slotItem) == itemID then
                        item.places[invName][slotIndex] = slotItem.count
                    end
                end
            end

            if count <= 0 then
                break
            end

            sleep(0)
        end

        item.count = totalPushed
    end

    if previouslyExisted then
        events.queue("item_changed", itemID, item.count - totalPushed, item.count)
    else
        events.queue("item_added", itemID, item)
    end

    if count > 0 then
        return totalPushed, "Storage system is full"
    else
        return totalPushed
    end
end

function export.pullItems(source, sourceSlot, count)
    local infoMethod = function() end

    if source == devices.self then
        infoMethod = function()
            return turtle.getItemDetail(sourceSlot)
        end
    elseif source == "introspection" then
        local manipulator = devices.getIntrospectionManipulator()

        if manipulator then
            infoMethod = function()
                return manipulator.getInventory().getItemDetail(sourceSlot)
            end
        end
    else
        local inv = peripheral.wrap(source)

        if inv and inv.getItemDetail then
            infoMethod = function()
                return inv.getItemDetail(sourceSlot)
            end
        end
    end

    local pullMethod

    if source == "introspection" then
        local manipulator = devices.getIntrospectionManipulator()

        ---@diagnostic disable-next-line: redefined-local
        pullMethod = function(invName, invObject, count)
            return manipulator.getInventory().pushItems(invName, sourceSlot, count)
        end
    else
        ---@diagnostic disable-next-line: redefined-local
        pullMethod = function(invName, invObject, count)
            return invObject.pullItems(source, sourceSlot, count)
        end
    end

    return pullItems(count, infoMethod, pullMethod)
end

function export.getItem(itemID)
    return invCache[itemID]
end

function export.getItemCount(itemID)
    if invCache[itemID] then
        return invCache[itemID].count
    else
        return 0
    end
end

-- Recurring tasks
local invTimer = os.startTimer(config.inventory_tick_interval)

local function checkRules(rules, itemID)
    local mode = rules.mode or "whitelist"
    local items = rules.items or {}

    if mode == "blacklist" then
        if not items[itemID] then
            return true
        end
    elseif mode == "whitelist" then
        if items[itemID] then
            return true
        end
    end

    return false
end

local function doInputChests()
    for name, rules in pairs(config.input_chests) do
        local inventory = devices.input_chests[name]
        if inventory and inventory.list then
            for slot, item in pairs(inventory.list()) do
                local itemID = export.formatItemID(item)
                
                if checkRules(rules, itemID) then
                    export.pullItems(name, slot, 100)
                end
            end
        end
    end
end

local function doOutputChests()
    for name, rules in pairs(config.output_chests) do
        local items = rules.items or {}

        for itemID, _ in pairs(items) do
            local count = export.getItemCount(itemID)

            if count > 0 then
                export.pushItems(itemID, count, name)
            end
        end
    end
end

local function inventoryTick(event, timerID)
    if timerID == invTimer and not refreshing then
        doInputChests()
        doOutputChests()

        invTimer = os.startTimer(config.inventory_tick_interval)
    end
end

events.listen("timer", inventoryTick)

return export