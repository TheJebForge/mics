local events = require("src.events")

local export = {}

local log = {}
local logLimit = 20

local function deleteOldLogs()
    if #log > logLimit then
        for i = 21, #log do
            log[i] = nil
        end
    end
end

function export.log(msg)
    local datetime = os.date("!UTC %F %T")

    local logMessage = { datetime = datetime, message = msg }

    table.insert(log, 1, logMessage)
    deleteOldLogs()

    events.queue("new_log", logMessage)
end

function export.getLogs()
    return log
end

return export