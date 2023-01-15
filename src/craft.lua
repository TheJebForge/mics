local utils = require("src.utils")
local inv = require("src.inv")

local export = {}

local recipes = {}

-- Functions for actually reading through minecraft recipes
local function convertRecipes()
    for i, filename in pairs(fs.list("mics/mc_recipes")) do
        local file = fs.open("mics/mc_recipes/"..filename, "r")

        local content = file.readAll()

        file.close()

        local recipe = textutils.unserialiseJSON(content)

        local dot = string.find(filename, "%.")
        local name = string.sub(filename, 1, dot - 1)
        print(name)

        local ty = nil

        if recipe.type == "minecraft:crafting_shaped" then
            ty = "shaped"
        elseif recipe.type == "minecraft:crafting_shapeless" then
            ty = "shapeless"
        elseif recipe.type == "minecraft:smelting" then
            ty = "smelt"
        end

        if ty then
            local resultName = type(recipe.result) == "string" and recipe.result or recipe.result.item
        
            local ingredients = nil

            if recipe.ingredient then
                ingredients = {}
                if recipe.ingredient.item then
                    ingredients[recipe.ingredient.item] = "item"
                elseif recipe.ingredient.tag then
                    ingredients[recipe.ingredient.tag] = "tag"
                end
            elseif recipe.ingredients then
                ingredients = {}
                for _, ingredient in pairs(recipe.ingredients) do
                    if ingredient.item then
                        ingredients[ingredient.item] = "item"
                    elseif ingredient.tag then
                        ingredients[ingredient.tag] = "tag"
                    end
                end
            end

            local pattern = nil

            if recipe.pattern then
                pattern = {}
                for y = 1, 3 do
                    local line = recipe.pattern[y]

                    if line then
                        for x = 1, 3 do
                            local item = line:sub(x, x)

                            if item ~= "" and item ~= " " then
                                pattern[x + (y - 1) * 3] = item
                            end
                        end
                    end
                end
            end

            local semicolon = resultName:find("%:")
            local idname = resultName:sub(semicolon + 1, resultName:len())

            local humanName = ""

            for word in string.gmatch(idname, "([^_]+)") do
                humanName = humanName .. word:sub(1,1):upper() .. word:sub(2, word:len()) .. " "
            end

            humanName = humanName:sub(1, humanName:len()-1)

            local formatted = {
                t = ty,
                k = recipe.key,
                p = pattern,
                i = ingredients,
                r = {
                    [resultName] = recipe.result.count or 1
                }
            }

            if recipes[resultName] then
                table.insert(recipes[resultName].r, formatted)
            else
                recipes[resultName] = { 
                    n = humanName,
                    r = { formatted }
                 }
            end
        end

        sleep(0)
    end
end

local function convertAndSave()
    print("loading recipes...")
    convertRecipes()
    print("finished loading")

    local file = fs.open("mics/recipes/vanilla_1_19_recipes.json", "w")
    file.write(textutils.serialiseJSON(recipes))
    file.close()

    print("saved")
end

--convertAndSave()

local function calculateRequirements(recipeObj)
    for _, recipe in pairs(recipeObj.r) do
        if recipe.i then
            recipe.requirements = {}

            for id, ty in pairs(recipe.i) do
                recipe.requirements[id] = {
                    type = ty,
                    count = 1
                }
            end
        elseif recipe.p then
            recipe.requirements = {}

            for _, key in pairs(recipe.p) do
                local item = recipe.k[key]

                if item then
                    if item.tag then
                        if recipe.requirements[item.tag] then
                            recipe.requirements[item.tag].count = recipe.requirements[item.tag].count + 1
                        else
                            recipe.requirements[item.tag] = {
                                type = "tag",
                                count = 1
                            }
                        end
                    elseif item.item then
                        if recipe.requirements[item.item] then
                            recipe.requirements[item.item].count = recipe.requirements[item.item].count + 1
                        else
                            recipe.requirements[item.item] = {
                                type = "item",
                                count = 1
                            }
                        end
                    end
                end
            end
        end
    end
end

local function loadRecipes()
    local yielder = utils.yielder()

    for i, filename in pairs(fs.list("mics/recipes")) do
        local file = fs.open("mics/recipes/"..filename, "r")

        local content = file.readAll()

        file.close()

        for name, recipe in pairs(textutils.unserialiseJSON(content)) do
            yielder.yield()

            calculateRequirements(recipe)
            recipes[name] = recipe
        end
    end
end

loadRecipes()

export.refresh = loadRecipes

local thinkLog = ""

local function log(msg)
    thinkLog = thinkLog .. tostring(msg) .. "\n"
end

local function pickCheapestRecipe(itemID)
    if recipes[itemID] then
        local options = {}

        if #recipes[itemID].r > 1 then
            for variantIndex, recipeVariant in pairs(recipes[itemID].r) do
                local availability = math.huge
                local requiredToCraft = {}

                for id, info in pairs(recipeVariant.requirements) do
                    local availableCount = 0

                    if info.type == "item" then
                        availableCount = inv.getItemCount(id) / info.count
                        requiredToCraft[id] = info.count
                    elseif info.type == "tag" then
                        local item = inv.getMostCommonItemByTag(id)

                        if item then
                            availableCount = item.count / info.count
                            requiredToCraft[inv.formatItemID(item)] = info.count
                        end
                    end

                    availability = math.min(availability, availableCount)
                end

                table.insert(options, {
                    availability = availability,
                    requiredToCraft = requiredToCraft,
                    recipe = recipeVariant
                })
            end
        else
            local recipe = recipes[itemID].r[1]
            local requiredToCraft = {}

            if recipe then
                local availability = math.huge

                for id, info in pairs(recipe.requirements) do
                    local availableCount = math.huge

                    if info.type == "item" then
                        availableCount = inv.getItemCount(id) / info.count
                        requiredToCraft[id] = info.count
                    elseif info.type == "tag" then
                        local item = inv.getMostCommonItemByTag(id)
                        

                        if item then
                            local actualID = inv.formatItemID(item)

                            availableCount = item.count / info.count
                            requiredToCraft[id] = actualID
                            requiredToCraft[actualID] = info.count
                        end
                    end

                    availability = math.min(availability, availableCount)
                end

                table.insert(options, {
                    availability = availability,
                    requiredToCraft = requiredToCraft,
                    recipe = recipe
                })
            end
        end

        return options
    end
end

local function calculateCraft(id, count)
    local yielder = utils.yielder()

    local unresolvedRequirements = {
        [id] = count
    }

    local calculationState = {
        steps = {},
        to_take = {},
        to_craft = {},
        missing = {},
        canCraft = true,
    }

    while next(unresolvedRequirements) do
        local newRequirements = {}

        ---@diagnostic disable-next-line: redefined-local
        for id, count in pairs(unresolvedRequirements) do
            -- Try to find if there's any items in the storage already
            local storageCount = inv.getItemCount(id)

            local availableCount
            if calculationState.to_take[id] then
                availableCount = storageCount - calculationState.to_take[id]
            else
                availableCount = storageCount
            end

            local toCraftCount
            if availableCount > 0 then
                toCraftCount = math.max(count - availableCount, 0)
                calculationState.to_take[id] = (calculationState.to_take[id] or 0) + math.min(availableCount, count)
            else
                toCraftCount = count
            end

            if toCraftCount > 0 then
                local recipeOption = pickCheapestRecipe(id)

                if recipeOption then
                    -- Adding new requirements
                    for requiredID, requiredCount in pairs(recipeOption.requiredToCraft) do
                        newRequirements[requiredID] = (newRequirements[requiredID] or 0) + (requiredCount * toCraftCount)
                    end

                    -- Adding crafting step
                    table.insert(calculationState.steps, {
                        recipe = recipeOption.recipe,
                        choices = recipeOption.requiredToCraft,
                        outputName = recipes[id].n
                    })

                    -- Adding to craft info
                    calculationState.to_craft[id] = (calculationState.to_craft[id] or 0) + toCraftCount
                else
                    calculationState.missing[id] = (calculationState.missing[id] or 0) + toCraftCount
                    calculationState.canCraft = false
                end
            end

            yielder.yield()
        end

        unresolvedRequirements = newRequirements
    end

    return calculationState
end

export.calculateCraft = calculateCraft

function export.listCrafts()
    return recipes
end

function export.getRecipe(craftID)
    return recipes[craftID]
end

return export