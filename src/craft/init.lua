-- local utils = require("src.utils")
-- local inv = require("src.inv")
-- local tags = require("src.tags")

-- local export = {}

-- local recipes = {}

-- Functions for actually reading through minecraft recipes
-- local function convertRecipes()
--     local function recursiveList(start)
--         local filenames = {}

--         for _, filename in pairs(fs.list(start)) do
--             local combinedFilename = fs.combine(start, filename)
--             if fs.isDir(combinedFilename) then
--                 local got = recursiveList(combinedFilename)

--                 for _, gotFN in pairs(got) do
--                     table.insert(filenames, gotFN)
--                 end
--             else
--                 table.insert(filenames, combinedFilename)
--             end
--         end

--         return filenames
--     end

--     local yielder = utils.yielder()

--     for i, filename in pairs(recursiveList("mics/mc_recipes")) do
--         local file = fs.open(filename, "r")

--         local content = file.readAll()

--         file.close()

--         local recipe = textutils.unserialiseJSON(content)

--         local dot = string.find(filename, "%.")
--         local name = string.sub(filename, 1, dot - 1)
--         print(name)

--         local ty = nil

--         if recipe.type == "minecraft:crafting_shaped" then
--             ty = "shd"
--         elseif recipe.type == "minecraft:crafting_shapeless" then
--             ty = "shl"
--         elseif recipe.type == "minecraft:smelting" then
--             ty = "smt"
--         end

--         if ty then
--             local resultName = type(recipe.result) == "string" and recipe.result or recipe.result.item
        
--             local ingredients = nil

--             if recipe.ingredient then
--                 ingredients = {}
--                 if recipe.ingredient.item then
--                     ingredients[recipe.ingredient.item] = {
--                         t = "i",
--                         c = 1
--                     }
--                 elseif recipe.ingredient.tag then
--                     ingredients[recipe.ingredient.tag] = {
--                         t = "t",
--                         c = 1
--                     }
--                 elseif ty == "smt" then
--                     for _, tab in pairs(recipe.ingredient) do
--                         if tab.item then
--                             ingredients[tab.item] = {
--                                 t = "i",
--                                 c = 1
--                             }
--                         elseif tab.tag then
--                             ingredients[tab.tag] = {
--                                 t = "t",
--                                 c = 1
--                             }
--                         end
--                     end
--                 end
--             elseif recipe.ingredients then
--                 ingredients = {}
--                 for _, ingredient in pairs(recipe.ingredients) do
--                     if ingredient.item then
--                         ingredients[ingredient.item] = {
--                             t = "i",
--                             c = ((ingredients[ingredient.item] or {}).c or 0) + 1
--                         }
--                     elseif ingredient.tag then
--                         ingredients[ingredient.tag] = {
--                             t = "t",
--                             c = ((ingredients[ingredient.tag] or {}).c or 0) + 1
--                         }
--                     end
--                 end
--             end

--             local pattern = nil

--             if recipe.pattern then
--                 pattern = {}
--                 for y = 1, 3 do
--                     local line = recipe.pattern[y]

--                     if line then
--                         for x = 1, 3 do
--                             local item = line:sub(x, x)

--                             if item ~= "" and item ~= " " then
--                                 pattern[x + (y - 1) * 3] = item
--                             end
--                         end
--                     end
--                 end
--             end

--             local semicolon = resultName:find("%:")
--             local idname = resultName:sub(semicolon + 1, resultName:len())

--             local humanName = ""

--             for word in string.gmatch(idname, "([^_]+)") do
--                 humanName = humanName .. word:sub(1,1):upper() .. word:sub(2, word:len()) .. " "
--             end

--             humanName = humanName:sub(1, humanName:len()-1)

--             local formatted = {
--                 t = ty,
--                 k = recipe.key,
--                 p = pattern,
--                 i = ingredients,
--                 r = {
--                     [resultName] = recipe.result.count or 1
--                 }
--             }

--             if recipes[resultName] then
--                 table.insert(recipes[resultName].r, formatted)
--             else
--                 recipes[resultName] = { 
--                     n = humanName,
--                     r = { formatted }
--                  }
--             end
--         end

--         yielder.yield()
--     end
-- end

-- local function convertAndSave()
--     print("loading recipes...")
--     convertRecipes()
--     print("finished loading")

--     local file = fs.open("mics/recipes/switchcraft.json", "w")
--     file.write(textutils.serialiseJSON(recipes))
--     file.close()

--     print("saved")
-- end

-- convertAndSave()

-- local function calculateRequirements(recipeObj)
--     for _, recipe in pairs(recipeObj.r) do
--         if recipe.i then
--             recipe.requirements = {}

--             for id, obj in pairs(recipe.i) do
--                 recipe.requirements[id] = {
--                     type = obj.t,
--                     count = obj.c
--                 }
--             end
--         elseif recipe.p then
--             recipe.requirements = {}

--             for _, key in pairs(recipe.p) do
--                 local item = recipe.k[key]

--                 if item then
--                     if item.tag then
--                         if recipe.requirements[item.tag] then
--                             recipe.requirements[item.tag].count = recipe.requirements[item.tag].count + 1
--                         else
--                             recipe.requirements[item.tag] = {
--                                 type = "tag",
--                                 count = 1
--                             }
--                         end
--                     elseif item.item then
--                         if recipe.requirements[item.item] then
--                             recipe.requirements[item.item].count = recipe.requirements[item.item].count + 1
--                         else
--                             recipe.requirements[item.item] = {
--                                 type = "item",
--                                 count = 1
--                             }
--                         end
--                     end
--                 end
--             end
--         end
--     end
-- end

-- local function loadRecipes()
--     local yielder = utils.yielder()

--     for i, filename in pairs(fs.list("mics/recipes")) do
--         local file = fs.open("mics/recipes/"..filename, "r")

--         local content = file.readAll()

--         file.close()

--         for name, recipe in pairs(textutils.unserialiseJSON(content)) do
--             yielder.yield()

--             calculateRequirements(recipe)
--             recipes[name] = recipe
--         end
--     end
-- end

-- print("Loading recipes...")
-- loadRecipes()

-- export.refresh = loadRecipes

-- I've tried? to make the crafting algorithm actually smart for 3 weeks, I'm giving up and just using AE2's crafting calculator
-- because it was best one from my testing

-- local function pickCheapestRecipe(itemID)
--     if recipes[itemID] then
--         local options = {}

--         if #recipes[itemID].r > 1 then
--             for variantIndex, recipeVariant in pairs(recipes[itemID].r) do
--                 local availability = math.huge
--                 local requiredToCraft = {}

--                 for id, info in pairs(recipeVariant.requirements) do
--                     local availableCount = 0

--                     if info.type == "item" then
--                         availableCount = inv.getItemCount(id) / info.count
--                         requiredToCraft[id] = info.count
--                     elseif info.type == "tag" then
--                         local item = inv.getMostCommonItemByTag(id)

--                         if item then
--                             availableCount = item.count / info.count
--                             requiredToCraft[inv.formatItemID(item)] = info.count
--                         end
--                     end

--                     availability = math.min(availability, availableCount)
--                 end

--                 table.insert(options, {
--                     availability = availability,
--                     requiredToCraft = requiredToCraft,
--                     recipe = recipeVariant
--                 })
--             end
--         else
--             local recipe = recipes[itemID].r[1]
--             local requiredToCraft = {}

--             if recipe then
--                 local availability = math.huge

--                 for id, info in pairs(recipe.requirements) do
--                     local availableCount = math.huge

--                     if info.type == "item" then
--                         availableCount = inv.getItemCount(id) / info.count
--                         requiredToCraft[id] = info.count
--                     elseif info.type == "tag" then
--                         local item = inv.getMostCommonItemByTag(id)
                        

--                         if item then
--                             local actualID = inv.formatItemID(item)

--                             availableCount = item.count / info.count
--                             requiredToCraft[id] = actualID
--                             requiredToCraft[actualID] = info.count
--                         end
--                     end

--                     availability = math.min(availability, availableCount)
--                 end

--                 table.insert(options, {
--                     availability = availability,
--                     requiredToCraft = requiredToCraft,
--                     recipe = recipe
--                 })
--             end
--         end

--         return options
--     end
-- end

-- local function calculateCraft(id, count)
--     local yielder = utils.yielder()

--     local unresolvedRequirements = {
--         [id] = count
--     }

--     local calculationState = {
--         steps = {},
--         to_take = {},
--         to_craft = {},
--         missing = {},
--         canCraft = true,
--     }

--     while next(unresolvedRequirements) do
--         local newRequirements = {}

--         ---@diagnostic disable-next-line: redefined-local
--         for id, count in pairs(unresolvedRequirements) do
--             -- Try to find if there's any items in the storage already
--             local storageCount = inv.getItemCount(id)

--             local availableCount
--             if calculationState.to_take[id] then
--                 availableCount = storageCount - calculationState.to_take[id]
--             else
--                 availableCount = storageCount
--             end

--             local toCraftCount
--             if availableCount > 0 then
--                 toCraftCount = math.max(count - availableCount, 0)
--                 calculationState.to_take[id] = (calculationState.to_take[id] or 0) + math.min(availableCount, count)
--             else
--                 toCraftCount = count
--             end

--             if toCraftCount > 0 then
--                 local recipeOption = pickCheapestRecipe(id)

--                 if recipeOption then
--                     -- Adding new requirements
--                     for requiredID, requiredCount in pairs(recipeOption.requiredToCraft) do
--                         newRequirements[requiredID] = (newRequirements[requiredID] or 0) + (requiredCount * toCraftCount)
--                     end

--                     -- Adding crafting step
--                     table.insert(calculationState.steps, {
--                         recipe = recipeOption.recipe,
--                         choices = recipeOption.requiredToCraft,
--                         outputName = recipes[id].n
--                     })

--                     -- Adding to craft info
--                     calculationState.to_craft[id] = (calculationState.to_craft[id] or 0) + toCraftCount
--                 else
--                     calculationState.missing[id] = (calculationState.missing[id] or 0) + toCraftCount
--                     calculationState.canCraft = false
--                 end
--             end

--             yielder.yield()
--         end

--         unresolvedRequirements = newRequirements
--     end

--     return calculationState
-- end

-- ## Another failed attempt that did not account for "spent" items and ended up "duping" items in its memory ##
-- local function calculateRecipeAvailability(itemID)
--     local queue = utils.uniqueQueue(function(item)
--         return item.itemID .. item.variant
--     end)

--     ---@diagnostic disable-next-line: redefined-local
--     local function pushItemsRecipes(itemID)
--         if recipes[itemID] then
--             for i, recipe in pairs(recipes[itemID].r) do
--                 queue.push({variant = i, recipe = recipe, itemID = itemID, output = recipe.r[itemID]})
--             end

--             return true
--         end
--     end

--     pushItemsRecipes(itemID)

--     local availability = {}
--     local repeatCount = {}

--     while not queue.isEmpty() do
--         local item = queue.peek()

--         local satisfied = true

--         local itemAvailabilities = {

--         }

--         for id, info in pairs(item.recipe.requirements) do
--             local matchingItems = {}
--             if info.type == "tag" then
--                 local itemIDs = tags.resolveTag(id)

--                 for iID, _ in pairs(itemIDs) do
--                     matchingItems[iID] = inv.getItemCount(iID)
--                 end
--             elseif info.type == "item" then
--                 matchingItems[id] = inv.getItemCount(id)
--             end

--             if not next(matchingItems) then
--                 if availability[item.itemID] then
--                     availability[item.itemID][item.variant] = 0
--                 else
--                     availability[item.itemID] = { [item.variant] = 0 }
--                 end
--             else
--                 for iID, iCount in pairs(matchingItems) do
--                     if iCount > 0 then
--                         itemAvailabilities[iID] = (itemAvailabilities[iID] or 0) + math.floor(iCount / info.count)
--                     end

--                     if availability[iID] then
--                         itemAvailabilities[iID] = (itemAvailabilities[iID] or 0) + utils.maxTableValue(availability[iID])
--                     else
--                         if not pushItemsRecipes(iID) then
--                             itemAvailabilities[iID] = math.floor(iCount / info.count)
--                         else
--                             repeatCount[iID] = (repeatCount[iID] or 0) + 1
--                             satisfied = false

--                             local maxAvailable = (utils.minTableValue(itemAvailabilities) or 0) + inv.getItemCount(item.itemID)

--                             if availability[item.itemID] then
--                                 availability[item.itemID][item.variant] = maxAvailable * item.output
--                             else
--                                 availability[item.itemID] = { [item.variant] = maxAvailable * item.output }
--                             end
--                         end
--                     end
--                 end
                    
--             end
--         end

--         print(textutils.serialize(queue.ids))

--         if satisfied then
--             local maxAvailable = (utils.minTableValue(itemAvailabilities) or 0) + inv.getItemCount(item.itemID)

--             if availability[item.itemID] then
--                 availability[item.itemID][item.variant] = maxAvailable * item.output
--             else
--                 availability[item.itemID] = { [item.variant] = maxAvailable * item.output }
--             end
--         end

--         if satisfied then
--             queue.pop()
--         end

--         sleep(3)
--     end

--     return availability
-- end

-- function calculateRecipeAvailability(itemID)
--     local queue = utils.uniqueQueue(function(item)
--         return item.itemID .. item.variant
--     end, true)

--     local function pushAllVariants(recipeID, spent)
--         if recipes[recipeID] then
--             for variantIndex, recipe in pairs(recipes[recipeID].r) do
--                 queue.push({
--                     itemID = recipeID,
--                     variant = variantIndex,
--                     recipe = recipe,
--                     spent = spent and utils.tableClone(spent) or {},
--                 })
--             end
--         end
--     end

--     pushAllVariants(itemID)

--     local availability = {}

--     local function getAvailability(item)
--         local available = inv.getItemCount(item.itemID)

--         if availability[item.itemID] then
--             for _, obj in pairs(availability[item.itemID]) do
--                 available = available + obj.count
--             end
--         end

--         return math.max(0, available - (item.spent[item.itemID] or 0))
--     end

--     while not queue.isEmpty() do
--         local item = queue.peek()

--         local itemsToPost = {}

--         -- How much of the item is available right now
--         local currentAvailability = getAvailability(item)

--         -- Keeps how much can be crafted based on separate requirements
--         local possibleCraftCounts = {}

--         local function considerRequirement(requirementIndex, ty, itemsToConsider, amountNeeded)
--             possibleCraftCounts[requirementIndex] = {
--                 type = ty,
--                 amountNeeded = amountNeeded,
--                 options = {},
--                 totalPossible = 0
--             }

--             for id, _ in pairs(itemsToConsider) do
--                 -- Posting the items into queue so this queue iteration can be reconsidered later
--                 if not availability[id] then
--                     itemsToPost[id] = true
--                 end

--                 local couldBeCrafted = getAvailability({
--                     itemID = id,
--                     spent = item.spent
--                 }) / math.max(1, amountNeeded)

--                 possibleCraftCounts[requirementIndex].options[id] = couldBeCrafted

--                 possibleCraftCounts[requirementIndex].totalPossible =
--                     (possibleCraftCounts[requirementIndex].totalPossible or 0)
--                     + couldBeCrafted
--             end
--         end

--         -- Get how much of the item can be crafted right now
--         if item.recipe then
--             if item.recipe.t == "smt" then
--                 local matchingItems = {}

--                 for id, info in pairs(item.recipe.requirements) do
--                     if info.type == "t" then
--                         for actualID, _ in pairs(tags.resolveTag(id)) do
--                             matchingItems[actualID] = true
--                         end
--                     elseif info.type == "i" then
--                         matchingItems[id] = true
--                     end
--                 end

--                 considerRequirement(1, "a", item.recipe.requirements, 1)
--             else
--                 for id, info in pairs(item.recipe.requirements) do
--                     local matchingItems = {}

--                     if info.type == "t" then
--                         for actualID, _ in pairs(tags.resolveTag(id)) do
--                             matchingItems[actualID] = true
--                         end
--                     elseif info.type == "i" then
--                         matchingItems[id] = true
--                     end

--                     considerRequirement(id, info.type, matchingItems, info.count)
--                 end
--             end
--         end

--         -- Max possible crafting amount
--         local lowestPossibleCountKey = utils.keyOfSmallestValue(possibleCraftCounts, function(a)
--             return a.totalPossible
--         end) or 1

--         local lowestPossibleCount = ((possibleCraftCounts[lowestPossibleCountKey] or {}).totalPossible or 0)

--         -- Removing unused requirement options
--         for requirementIndex, requirement in pairs(possibleCraftCounts) do
--             -- Creating a sorted table of item ids to availability
--             local sortedReferences = {}

--             for id, amount in pairs(requirement.options) do
--                 table.insert(sortedReferences, {
--                     id = id,
--                     amount = amount
--                 })
--             end

--             table.sort(sortedReferences, function(a, b)
--                 return b.amount < a.amount
--             end)

--             -- Using up most common resources first
--             local newOptions = {}

--             local neededAmount = lowestPossibleCount

--             for _, obj in pairs(sortedReferences) do
--                 local newAmount = math.max(neededAmount - obj.amount, 0)
--                 local taken = neededAmount - newAmount

--                 newOptions[obj.id] = taken

--                 -- Also using the chance to update the spent table
--                 item.spent[obj.id] = (item.spent[obj.id] or 0) + taken

--                 neededAmount = newAmount
--             end

--             requirement.options = newOptions
--         end

--         -- Updating availability of the item
--         if not availability[item.itemID] then
--             availability[item.itemID] = {}
--         end

--         availability[item.itemID][item.variant] = {
--             count = currentAvailability + (lowestPossibleCount * item.recipe.r[item.itemID]),
--             possibilities = possibleCraftCounts
--         }

--         -- Putting items into the queue
--         for id, _ in pairs(itemsToPost) do
--             if not recipes[id] then
--                 availability[id] = {
--                     {
--                         count = inv.getItemCount(id),
--                         possibilities = {}
--                     }
--                 }
                
--                 print("recipes were not found for ", id)

--                 itemsToPost[id] = nil
--             else
--                 pushAllVariants(id, item.spent)
--             end
--         end

--         -- Not popping current item if waiting for any items
--         if not next(itemsToPost) then
--             queue.pop()
--         end
--     end

--     return availability
-- end

-- local function pickBestItemFromTagForAvailability(tag, availability)
--     local itemIDs = tags.resolveTag(tag)

--     local maxKey = next(itemIDs)

--     if maxKey then
--         for itemID, _ in pairs(itemIDs) do
--             local current = math.max(
--                 utils.maxTableValue(availability[maxKey] or { 0 }),
--                 inv.getItemCount(maxKey)
--             )
--             local avail = math.max(
--                 utils.maxTableValue(availability[itemID] or { 0 }),
--                 inv.getItemCount(itemID)
--             )

--             if avail > current then
--                 maxKey = itemID
--             end
--         end

--         return maxKey
--     end
-- end

-- local function calculateCraftingPlan(itemID, count)
--     local availability = calculateRecipeAvailability(itemID)

--     textutils.pagedPrint(textutils.serialize(availability))

--     local plan = {
--         steps = {},
--         toTake = {},
--         toCraft = {},
--         missing = {},
--         craftable = true
--     }

--     local queue = utils.queue()

--     queue.push({id = itemID, amount = count + inv.getItemCount(itemID)})

--     local yielder = utils.yielder()

--     while not queue.isEmpty() do
--         local item = queue.pop()

--         local availableCount = inv.getItemCount(item.id) - (plan.toTake[item.id] or 0)

--         local toCraft = 0
--         if availableCount > 0 then
--             local taken = math.min(item.amount, availableCount)
--             plan.toTake[item.id] = (plan.toTake[item.id] or 0) + taken

--             toCraft = math.max(0, item.amount - taken)
--         else
--             toCraft = item.amount
--         end

--         if toCraft > 0 then
--             if recipes[item.id] then
--                 local bestRecipeVariant = utils.keyOfBiggestValue(availability[item.id] or { 0 })

--                 local recipe = recipes[item.id].r[bestRecipeVariant]
--                 local output = recipe.r[item.id]

--                 local toRequest = math.ceil(toCraft / output)
--                 toCraft = math.ceil(toCraft / output) * output
--                 plan.toCraft[item.id] = (plan.toCraft[item.id] or 0) + toCraft

--                 local craftingStep = {
--                     id = item.id,
--                     recipeVariant = bestRecipeVariant,
--                     tagChoices = {},
--                     amount = math.ceil(toCraft / output)
--                 }

--                 for id, info in pairs(recipe.requirements) do
--                     local pickedID = id

--                     local neededAmount = toRequest * info.count

--                     if info.type == "tag" then
--                         pickedID = pickBestItemFromTagForAvailability(id, availability)

--                         if not pickedID then
--                             plan.missing["#" .. id] = (plan.missing["#" .. id] or 0) + toCraft
--                             plan.craftable = false
--                         else
--                             craftingStep.tagChoices[id] = pickedID
--                         end
--                     end

--                     local calculatedAmount = (utils.maxTableValue(availability[pickedID] or { 0 }) + inv.getItemCount(pickedID))

--                     if pickedID and calculatedAmount > 0 then
--                         queue.push({id = pickedID, amount = neededAmount})
--                     else
--                         plan.missing[id] = (plan.missing[id] or 0) + toCraft
--                         plan.craftable = false
--                     end
--                 end

--                 table.insert(plan.steps, craftingStep)
--             else
--                 plan.missing[item.id] = (plan.missing[item.id] or 0) + toCraft
--                 plan.craftable = false
--             end
--         end

--         yielder.yield()
--     end

--     plan.steps = utils.reverseTable(plan.steps)

--     -- add amounts and remove duplicates
--     local seen = {}

--     for index, step in pairs(plan.steps) do
--         if not seen[step.id] then
--             local recipe = recipes[step.id].r[step.recipeVariant]
--             local output = recipe.r[step.id]

--             local neededAmount = (plan.toCraft[step.id] or 0)

--             step.amount = math.ceil(neededAmount / output)

--             seen[step.id] = true
--         else
--             table.remove(plan.steps, index)
--         end
--     end

--     return plan
-- end

-- export.calculateRecipeAvailability = calculateRecipeAvailability
-- export.calculateCraftingPlan = calculateCraftingPlan

-- function export.listCrafts()
--     return recipes
-- end

-- function export.getRecipe(craftID)
--     return recipes[craftID]
-- end

-- Above is my attempts at autocrafting, down here is ported code from AE2

local export = {}



return export