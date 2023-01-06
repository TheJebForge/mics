local expectModule = require "cc.expect"
local expect, field = expectModule.expect, expectModule.field

local export = {}

function export.has_value (tab, val)
    for index, value in pairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

function export.listAllKeys(...)
    local tables = {...}

    local keys = {}

    for i, t in pairs(tables) do
        expect(i, t, "table")

        for k, _ in pairs(t) do
            keys[k] = k
        end
    end

    return keys
end

function export.startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
 end
 

return export