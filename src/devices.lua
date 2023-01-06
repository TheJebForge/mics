local events = require("src.events")
local utils = require("src.utils")
local config = require("src.config")

local export = {}

local sides = {"bottom", "top", "left", "right", "front", "back"}

local inventory_types = {
    "sc-goodies:iron_chest",
    "sc-goodies:gold_chest",
    "sc-goodies:diamond_chest",
    "sc-goodies:shulker_box_iron",
    "sc-goodies:shulker_box_gold",
    "sc-goodies:shulker_box_diamond",
    "minecraft:chest",
    "minecraft:barrel",
    "minecraft:shulker_box"
}

function export.isPresent(device)
    if device then
        local name = peripheral.getName(device)
        return peripheral.isPresent(name)
    else
        return false
    end
end

function export.compareName(device, name) 
    local deviceName = ""

    if device then
        deviceName = peripheral.getName(device)
    end

    return deviceName == name
end

local function refresh()
    -- Searching for modems
    export.modem = nil
    export.wireless = nil

    for _, side in pairs(sides) do 
        if peripheral.hasType(side, "modem") then
            if not peripheral.call(side, "isWireless") then
                if not export.modem then
                    export.modem = peripheral.wrap(side)
                else
                    printError("Multiple modem networks detected! Please remove the extra network as that will cause confusion with peripherals and item transfers")
                    export.modem = nil
                    return
                end
            end
        end
    end

    if export.modem then
        export.self = export.modem.getNameLocal()
    end

    -- Searching for drive
    export.drive = peripheral.find("drive")

    -- Searching for speaker
    export.speaker = peripheral.find("speaker")

    -- Searching for workbench
    export.workbench = peripheral.find("workbench")

    -- Searching for other devices
    export.monitors = {}
    export.inventories = {}
    export.manipulators = {}
    export.input_chests = {}
    export.output_chests = {}

    export.monitorCount = 0
    export.inventoryCount = 0
    export.manipulatorCount = 0
    export.inputChestCount = 0
    export.outputChestCount = 0

    if export.modem then
        for _, name in pairs(peripheral.getNames()) do
            local type = peripheral.getType(name)

            if utils.has_value(inventory_types, type) then
                if config.input_chests[name] then
                    export.inputChestCount = export.inputChestCount + 1
                    export.input_chests[name] = peripheral.wrap(name)
                elseif config.output_chests[name] then
                    export.outputChestCount = export.outputChestCount + 1
                    export.output_chests[name] = peripheral.wrap(name)
                else
                    export.inventoryCount = export.inventoryCount + 1
                    export.inventories[name] = peripheral.wrap(name)
                end
            elseif type == "monitor" then
                export.monitorCount = export.monitorCount + 1
                export.monitors[name] = peripheral.wrap(name)
            elseif type == "manipulator" then
                export.manipulatorCount = export.manipulatorCount + 1
                export.manipulators[name] = peripheral.wrap(name)
            elseif type == "modem" then
                if peripheral.call(name, "isWireless") and not export.wireless then
                    export.wireless = peripheral.wrap(name)
                end
            end
        end
    end

    events.queue("devices_refreshed")
end

function export.getIntrospectionManipulator()
    for name, manipulator in pairs(export.manipulators) do
        if export.isPresent(manipulator) then
            if manipulator.hasModule("plethora:introspection") and manipulator.getInventory and not utils.has_value(sides, name) then
                return manipulator, name
            end
        end
    end
end

refresh()

export.refresh = refresh

local function peripheralListener(...)
    local event = { ... }

    if event[1] == "peripheral" then
        local name = event[2]
        local type = peripheral.getType(name)

        if utils.has_value(inventory_types, type) then -- Adding to list if inventory
            if config.input_chests[name] then
                export.inputChestCount = export.inputChestCount + 1
                export.input_chests[name] = peripheral.wrap(name)
                events.queue("device_added", "input_chest", name)
            elseif config.output_chests[name] then
                export.outputChestCount = export.outputChestCount + 1
                export.output_chests[name] = peripheral.wrap(name)
                events.queue("device_added", "output_chest", name)
            else
                export.inventoryCount = export.inventoryCount + 1
                export.inventories[name] = peripheral.wrap(name)
                events.queue("device_added", "inventory", name)
            end
        elseif type == "monitor" then
            export.monitorCount = export.monitorCount + 1
            export.monitors[name] = peripheral.wrap(name)

            events.queue("device_added", "monitor", name)
        elseif type == "manipulator" then
            export.manipulatorCount = export.manipulatorCount + 1
            export.manipulators[name] = peripheral.wrap(name)

            events.queue("device_added", "manipulator", name)
        elseif type == "modem" then
            if not export.isPresent(export.wireless) then
                if peripheral.call(name, "isWireless") then
                    export.wireless = peripheral.wrap(name)

                    events.queue("device_added", "wireless", name)
                end
            end
        elseif type == "drive" then
            if not export.isPresent(export.drive) then
                export.drive = peripheral.wrap(name)

                events.queue("device_added", "drive", name)
            end
        elseif type == "speaker" then
            if not export.isPresent(export.speaker) then
                export.speaker = peripheral.wrap(name)

                events.queue("device_added", "speaker", name)
            end
        elseif type == "workbench" then
            if not export.isPresent(export.workbench) then
                export.workbench = peripheral.wrap(name)

                events.queue("device_added", "workbench", name)
            end
        end
    elseif event[1] == "peripheral_detach" then
        local name = event[2]

        if export.compareName(export.wireless, name) then
            export.wireless = nil

            events.queue("device_removed", "wireless", name)
        elseif export.compareName(export.drive, name) then
            export.drive = nil

            events.queue("device_removed", "drive", name)
        elseif export.compareName(export.speaker, name) then
            export.speaker = nil

            events.queue("device_removed", "speaker", name)
        elseif export.compareName(export.workbench, name) then
            export.workbench = nil

            events.queue("device_removed", "workbench", name)
        elseif export.inventories[name] then
            if config.input_chests[name] then
                export.inputChestCount = export.inputChestCount - 1
                export.input_chests[name] = nil
                events.queue("device_removed", "input_chest", name)
            elseif config.output_chests[name] then
                export.outputChestCount = export.outputChestCount - 1
                export.output_chests[name] = nil
                events.queue("device_removed", "output_chest", name)
            else
                export.inventories[name] = nil
                export.inventoryCount = export.inventoryCount - 1
                events.queue("device_removed", "inventory", name)
            end
        elseif export.manipulators[name] then
            export.manipulators[name] = nil
            export.manipulatorCount = export.manipulatorCount - 1

            events.queue("device_removed", "manipulator", name)
        elseif export.monitors[name] then
            export.monitors[name] = nil
            export.monitorCount = export.monitorCount - 1

            events.queue("device_removed", "monitors", name)
        end
    end
end

events.listen("peripheral", peripheralListener)
events.listen("peripheral_detach", peripheralListener)

return export