local events = require("src.events")
local utils = require("src.utils")

function printError(...)
    term.setTextColor(colors.red)
    print(...)
    term.setTextColor(colors.white)
end

layoutsFolder = "mics/src/layouts/"

-- Initialization step
term.clear()
term.setCursorPos(1, 1)

if not turtle or not term.isColor() then
    printError("Basic or non-turtle computers are not supported!")
end

print("Device discovery report\n")

local devices = require("src.devices")

if devices.modem and devices.self then
    print("Wired modem found")
else
    printError("Cannot work without a connected wired modem!")
    sleep(3)
    return
end

if devices.wireless then
    print("Wireless modem found")
else
    printError("No wireless modem found. MICS Remote will not work")
    sleep(2)
end

if devices.speaker then
    print("Speaker found")
end

if devices.drive then
    print("Drive found")
end

if devices.manipulatorCount > 0 and devices.wireless then
    print("Manipulator found")

    local manipulator, name = devices.getIntrospectionManipulator()
    if manipulator then
        print("Introspection module found")
    else
        printError("No bound introspection module found. Storage system will be unable to send items remotely. Please make sure the module is bound, and the manipulator is connected to a modem rather than being directly next to the turtle!")
        sleep(5)
    end
end

if devices.workbench then
    print("Workbench found")
else
    printError("No workbench found. Storage system will not be able to craft anything")
    sleep(2)
end

print(devices.monitorCount .. " monitors found")
print(devices.inventoryCount .. " inventories found\n")

print("Starting services...")

-- Initializing services
local inv = require("src.inv")

print("Indexing inventories...")
inv.refresh()

events.listen("inv_index_done", function()
    -- textutils.pagedPrint(
    --     textutils.serialise(inv.listItems())
    -- )
end)

print("Loading recipes...")
local craft = require("src.craft")

-- textutils.pagedPrint(
--     textutils.serialize(
--         craft.calculateCraft("minecraft:oak_planks", 64)
--     )
-- )

events.listen("inv_index_done", function()
    inv.pullItems("introspection", 1, 64)
end)

-- Actually starting processes
parallel.waitForAny(
    events.processEvents,
    require("src.ui")
)