local logger = require("src.log")

local export = {}

local config = {
    inventory_tick_interval = 2,
    input_chests = {},
    output_chests = {},
}

local function saveConfig()
    local file = fs.open("mics/config", "w")
    file.write("return "..textutils.serialize(config))
    file.close()

    logger.log("Saved config")
end

function export.reload()
    local configFile = loadfile("mics/config")

    local loadedConfig = {}
    if configFile then
        loadedConfig = configFile()
    end

    for i, v in pairs(loadedConfig) do
        config[i] = v
    end
end

export.reload()

local metatable = {
    __index = function(t, k)
        return config[k]
    end,

    __newindex = function(t, k, v)
        config[k] = v
        saveConfig()
    end
}

setmetatable(export, metatable)

return export