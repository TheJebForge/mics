local expectModule = require "cc.expect"
local expect, field = expectModule.expect, expectModule.field

local utils = require("src.utils")

local export = {}

local currentListener = 0
local listeners = {}
local queue = {}

-- Registers a listener
function export.listen(filter, func)
    expect(1, filter, "string")
    expect(2, func, "function")


    if listeners[filter] then
        table.insert(listeners[filter], func)
    else
        listeners[filter] = { func }
    end
end

local function callFor(filter, ...)
    if listeners[filter] then
        for i, listener in pairs(listeners[filter]) do
            currentListener = i
            listener(...)
        end
    end
end

local function callListeners(event, ...)
    callFor("any", event, ...)
    callFor(event, event, ...)
end

-- Calls all listeners of "any" and the event
function export.queue(event, ...)
    table.insert(queue, {event, ...})
end

-- Processes all events from OS and other libs
function export.processEvents()
    parallel.waitForAny(
        function()
            while true do 
                local event = { os.pullEventRaw() }
                table.insert(queue, event)
            end
        end,
        function()
            while true do
                for _, event in pairs(queue) do
                    if event then
                        if event[1] == "terminate" then
                            return
                        end

                        callListeners(unpack(event))
                    end
                end
        
                queue = {}

                coroutine.yield()
            end
        end
    )
end

return export