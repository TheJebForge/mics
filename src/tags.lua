local utils = require("src.utils")

local export = {}

local tags = {}

local function convertTags()
    local function recursiveList(path, tagPath)
        local filenames = {}

        for _, filename in pairs(fs.list(path)) do
            local combinedFilename = fs.combine(path, filename)

            local addedTagPath = ""

            if tagPath ~= "" then
                addedTagPath = tagPath .. "/"
            end

            local extensionDot = filename:find("%.")
            local tagName = filename:sub(1, (extensionDot or filename:len()) - 1)

            if fs.isDir(combinedFilename) then
                local got = recursiveList(combinedFilename, addedTagPath .. filename)

                for gotPath, gotTag in pairs(got) do
                    filenames[gotPath] = gotTag
                end
            else
                filenames[combinedFilename] = addedTagPath .. tagName
            end
        end

        return filenames
    end

    local yielder = utils.yielder()

    for _, namespace in pairs(fs.list("mics/mc_tags")) do
        if fs.exists("mics/mc_tags/"..namespace.."/tags/items") then
            for path, tag in pairs(recursiveList("mics/mc_tags/"..namespace.."/tags/items", "")) do
                print(path)

                local namespacedTag = namespace .. ":" .. tag

                local file = fs.open(path, "r")
                local content = file.readAll()
                file.close()

                local json = textutils.unserialiseJSON(content)

                for _, itemID in pairs(json.values) do
                    if tags[namespacedTag] then
                        tags[namespacedTag][itemID] = true
                    else
                        tags[namespacedTag] = { [itemID] = true }
                    end
                end
            end
        end

        yielder.yield()
    end
end

local function convertAndSave()
    print("loading tags...")
    convertTags()
    print("finished loading")

    local file = fs.open("mics/tags/switchcraft.json", "w")
    file.write(textutils.serialiseJSON(tags))
    file.close()

    print("saved")
end

-- convertAndSave()

local function loadTags()
    local yielder = utils.yielder()

    for i, filename in pairs(fs.list("mics/tags")) do
        local file = fs.open("mics/tags/"..filename, "r")

        local content = file.readAll()

        file.close()

        for name, taglist in pairs(textutils.unserialiseJSON(content)) do
            yielder.yield()

            tags[name] = taglist
        end
    end
end

print("Loading tags...")
loadTags()

export.refresh = loadTags

function export.resolveTag(tag)
    local itemIDs = {}

    if tags[tag] then
        for itemID, _ in pairs(tags[tag]) do
            if itemID:sub(1, 1) == "#" then
                for nestedItemID, _ in pairs(export.resolveTag(itemID:sub(2))) do
                    itemIDs[nestedItemID] = true
                end
            else
                itemIDs[itemID] = true
            end
        end
    end

    return itemIDs
end

local function addTags(item)
    if item.tags then
        local itemID = require("src.inv").formatItemID(item)

        for tag, _ in pairs(item.tags) do
            if tags[tag] then
                tags[tag][itemID] = true
            else
                tags[tag] = {
                    [itemID] = true
                }
            end
        end
    end
end

export.addTags = addTags

return export