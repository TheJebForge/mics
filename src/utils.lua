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

function export.yielder()
    local yielder = {
        lastYield = os.clock(),
    }

    function yielder.yield()
        local clock = os.clock()

        if clock - yielder.lastYield > 1 then
            sleep(0)
        end
    end

    return yielder
end

function export.keyOfBiggestValue(tab)
    expect(1, tab, "table")

    local maxKey = next(tab)

    if maxKey then
        for key, val in pairs(tab) do
            local num = tonumber(val) or 0

            if val > tab[maxKey] then
                maxKey = key
            end
        end

        return maxKey
    end
end

function export.keyOfSmallestValue(tab, valueFunc)
    expect(1, tab, "table")
    valueFunc = type(valueFunc) == "function" and valueFunc or function(a)
        return tonumber(a)
    end

    local minKey = next(tab)

    if minKey then
        for key, val in pairs(tab) do
            local num = valueFunc(val) or 0

            if num < valueFunc(tab[minKey]) then
                minKey = key
            end
        end

        return minKey
    end
end

function export.queue()
    local queue = {}

    function queue.push(item)
        queue[#queue + 1] = item
    end

    function queue.peek()
        return queue[#queue]
    end

    function queue.pop()
        local item = queue[#queue]

        queue[#queue] = nil
        
        return item
    end

    function queue.isEmpty()
        return queue.peek() == nil
    end

    return queue
end

function export.uniqueQueue(idFunc, noReorder)
    expect(1, idFunc, "function")

    local queue = {
        items = {},
        ids = {}
    }

    local function reorder(id)
        local bottom = {}
        local top = {}

        for _, item in pairs(queue.items) do
            local itemID = idFunc(item)

            if itemID == id then
                table.insert(top, item)
            else
                table.insert(bottom, item)
            end
        end

        queue.items = bottom

        for _, item in pairs(top) do
            table.insert(queue.items, item)
        end
    end

    function queue.push(item)
        local itemID = idFunc(item)

        if (queue.ids[itemID] or 0) > 0 then
            if not noReorder then
                reorder(itemID)
            end
        else
            queue.items[#queue.items + 1] = item
            queue.ids[itemID] = (queue.ids[itemID] or 0) + 1
        end
    end

    function queue.peek()
        return queue.items[#queue.items]
    end

    function queue.pop()
        local item = queue.items[#queue.items]

        queue.items[#queue.items] = nil

        if item then
            local itemID = idFunc(item)

            queue.ids[itemID] = (queue.ids[itemID] or 0) - 1
        end
        
        return item
    end

    function queue.isEmpty()
        return queue.peek() == nil
    end

    return queue
end

function export.reverseTable(x)
    rev = {}
    for i=#x, 1, -1 do
        rev[#rev+1] = x[i]
    end
    return rev
end

function export.maxTableValue(tab)
    expect(1, tab, "table")
    local biggestKey = export.keyOfBiggestValue(tab)

    if biggestKey then
        return tab[biggestKey]
    end
end

function export.minTableValue(tab)
    expect(1, tab, "table")
    local smallestKey = export.keyOfSmallestValue(tab)

    if smallestKey then
        return tab[smallestKey]
    end
end

function export.tableAll(tab, func)
    expect(1, tab, "table")
    expect(2, func, "function")

    for i, v in pairs(tab) do
        if not func(i, v) then
            return false
        end
    end

    return true
end

function export.tableClone(tab, depthLimit, depth)
    expect(1, tab, "table")
    depth = depth or 0
    depthLimit = depthLimit or 4

    local newTable = {}

    for i, v in pairs(tab) do
        if type(v) == "table" and depth < depthLimit then
            newTable[i] = export.tableClone(v, depthLimit, depth + 1)
        else
            newTable[i] = v
        end
    end

    return newTable
end

return export