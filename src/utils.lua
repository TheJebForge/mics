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

local quatitySuffixes = {
    "",
    "k",
    'M',
    "B",
    "T"
}

function export.round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
  end

function export.formatQuantity(quantity)
    local level = 1
    while (quantity / 1000) >= 1 do
        level = level + 1
        quantity = quantity / 1000
    end

    local rounded = export.round(quantity, 1)

    return tostring(rounded) .. (quatitySuffixes[level] or "??")
end

return export