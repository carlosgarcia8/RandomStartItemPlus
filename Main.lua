local json = require("json")

local mod = RegisterMod("Random Start Item Plus", 1)

local config = {
    ["NumberOfItems"] = 1,
    ["IncludeActiveItems"] = true,
    ["NoIdenticalItems"] = true,
    ["SpawnItemEveryFloor"] = false,
    ["DecreaseNumberOfItems"] = false,
    ["TreasurePool"] = true,
    ["ShopPool"] = false,
    ["BossPool"] = false,
    ["DevilPool"] = false,
    ["AngelPool"] = false,
    ["SecretPool"] = false,
    ["LibraryPool"] = false,
    ["UltraSecretPool"] = false,
    ["PlanetariumPool"] = false,
}

function getItemPool()
    local itemPools = {}

    if config["TreasurePool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_TREASURE
    end

    if config["ShopPool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_SHOP
    end

    if config["BossPool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_BOSS
    end

    if config["DevilPool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_DEVIL
    end

    if config["AngelPool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_ANGEL
    end

    if config["SecretPool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_SECRET
    end

    if config["LibraryPool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_LIBRARY
    end

    if config["UltraSecretPool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_ULTRA_SECRET
    end

    if config["PlanetariumPool"] then
        itemPools[#itemPools+1] = ItemPoolType.POOL_PLANETARIUM
    end

    if #itemPools == 0 then
        itemPools[#itemPools+1] = ItemPoolType.POOL_TREASURE
    end

    local itemPool = itemPools[math.random(#itemPools)]

    return itemPool
end

function getSpawnLocations(numberOfItems)
    local centerX = 320
    local centerY = 300
    local spacing = 60

    local locations = {}
    local startX = centerX - (numberOfItems - 1) * spacing / 2

    for i = 0, numberOfItems - 1 do
        locations[i + 1] = Vector(startX + i * spacing, centerY)
    end

    return locations
end

function mod:getItemFromPool()
    local includeActive = config["IncludeActiveItems"]
    local itemPool = getItemPool()

    if not config["NoIdenticalItems"] then
        local itemId = Game():GetItemPool():GetCollectible(itemPool)
        if includeActive then
            return itemId
        else
            while itemId and Isaac.GetItemConfig():GetCollectible(itemId).Type ~= ItemType.ITEM_PASSIVE do
                itemId = Game():GetItemPool():GetCollectible(itemPool)
            end
        end
        return itemId
    end

    local game = Game()
    local numPlayers = game:GetNumPlayers()

    local function playerHasItem(itemId)
        for i = 0, numPlayers - 1 do
            if Isaac.GetPlayer(i):HasCollectible(itemId) then
                return true
            end
        end
        return false
    end

    for _ = 1, 100 do
        local itemId = game:GetItemPool():GetCollectible(itemPool, true, Random())

        if not itemId or itemId == CollectibleType.COLLECTIBLE_NULL then
            return nil
        end

        local itemCfg = Isaac.GetItemConfig():GetCollectible(itemId)
        local typeOk = includeActive or (itemCfg and itemCfg.Type == ItemType.ITEM_PASSIVE)

        if typeOk and not playerHasItem(itemId) then
            return itemId
        end
    end

    return nil
end

local currentNumberOfItems = 0

function mod:doSpawnItems(count)
    count = count or config["NumberOfItems"]
    for i = 1, count, 1 do
        local itemId = mod:getItemFromPool()

        if itemId then
            local spawnLocation = getSpawnLocations(count)[i]

            Isaac.Spawn(EntityType.ENTITY_PICKUP,
                PickupVariant.PICKUP_COLLECTIBLE,
                itemId,
                spawnLocation, Vector(0,0), nil)
        end
    end
end

function mod:spawnItemOnUpdate()
    if not config["SpawnItemEveryFloor"] and Game():GetFrameCount() == 1 then
        mod:doSpawnItems()
    end
end

function mod:spawnItemOnNewLevel()
    -- Floor 1 is handled in onGameStart to avoid the MC_POST_NEW_LEVEL/MC_POST_GAME_STARTED race.
    if Game():GetLevel():GetStage() == LevelStage.STAGE1_1 then return end

    if config["SpawnItemEveryFloor"] then
        if config["DecreaseNumberOfItems"] then
            if currentNumberOfItems > 0 then
                mod:doSpawnItems(currentNumberOfItems)
                currentNumberOfItems = currentNumberOfItems - 1
            end
        else
            mod:doSpawnItems()
        end
    end
end

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.spawnItemOnUpdate)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.spawnItemOnNewLevel)

local isGameStarted = false

function mod.onGameStart(isContinued)
    if mod:HasData() then
        local savedConfig = json.decode(Isaac.LoadModData(mod))
        for k, v in pairs(savedConfig) do
            config[k] = v
        end
    end
    currentNumberOfItems = config["NumberOfItems"]

    -- MC_POST_NEW_LEVEL fires before this callback on a new run, so floor 1
    -- must be handled here to guarantee config is already loaded.
    if not isContinued and config["SpawnItemEveryFloor"] then
        if config["DecreaseNumberOfItems"] then
            if currentNumberOfItems > 0 then
                mod:doSpawnItems(currentNumberOfItems)
                currentNumberOfItems = currentNumberOfItems - 1
            end
        else
            mod:doSpawnItems()
        end
    end
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)

--Saving Moddata--
function mod:SaveGame()
    mod.SaveData(mod, json.encode(config))
end

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.SaveGame)

if ModConfigMenu then

    function AnIndexOf(t,val)
        for k,v in ipairs(t) do 
            if v == val then return k end
        end

        return 1
    end

    local sizes = {1, 2, 3, 4, 5, 6}
    ModConfigMenu.AddSetting("Random Start Item Plus", "General", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
            return AnIndexOf(sizes, config["NumberOfItems"])
        end,
        Minimum = 1,
        Maximum = #sizes,
        Display = function()
            return "# of Items to Spawn: " .. config["NumberOfItems"]
        end,
        OnChange = function(currentNum)
            config["NumberOfItems"] = sizes[currentNum]
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus", "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["IncludeActiveItems"]
        end,
        Display = function()
            local onOff = "False"

            if config["IncludeActiveItems"] then
                onOff = "True"
            end
            return "Include Active Items: " .. onOff
        end,
        OnChange = function(currentBool)
            config["IncludeActiveItems"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus", "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["NoIdenticalItems"]
        end,
        Display = function()
            local onOff = "False"

            if config["NoIdenticalItems"] then
                onOff = "True"
            end
            return "No Identical Items: " .. onOff
        end,
        OnChange = function(currentBool)
            config["NoIdenticalItems"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus", "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["SpawnItemEveryFloor"]
        end,
        Display = function()
            local onOff = "False"

            if config["SpawnItemEveryFloor"] then
                onOff = "True"
            end
            return "Spawn Item Every Floor: " .. onOff
        end,
        OnChange = function(currentBool)
            config["SpawnItemEveryFloor"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus", "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["DecreaseNumberOfItems"]
        end,
        Display = function()
            local onOff = "False"

            if config["DecreaseNumberOfItems"] then
                onOff = "True"
            end
            return "Decrease Items Each Floor: " .. onOff
        end,
        OnChange = function(currentBool)
            config["DecreaseNumberOfItems"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["TreasurePool"]
        end,
        Display = function()
            local onOff = "False"

            if config["TreasurePool"] then
                onOff = "True"
            end
            return "Use Treasure Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["TreasurePool"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["ShopPool"]
        end,
        Display = function()
            local onOff = "False"

            if config["ShopPool"] then
                onOff = "True"
            end
            return "Use Shop Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["ShopPool"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["BossPool"]
        end,
        Display = function()
            local onOff = "False"

            if config["BossPool"] then
                onOff = "True"
            end
            return "Use Boss Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["BossPool"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["DevilPool"]
        end,
        Display = function()
            local onOff = "False"

            if config["DevilPool"] then
                onOff = "True"
            end
            return "Use Devil Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["DevilPool"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["AngelPool"]
        end,
        Display = function()
            local onOff = "False"

            if config["AngelPool"] then
                onOff = "True"
            end
            return "Use Angel Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["AngelPool"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["SecretPool"]
        end,
        Display = function()
            local onOff = "False"

            if config["SecretPool"] then
                onOff = "True"
            end
            return "Use Secret Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["SecretPool"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["LibraryPool"]
        end,
        Display = function()
            local onOff = "False"

            if config["LibraryPool"] then
                onOff = "True"
            end
            return "Use Library Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["LibraryPool"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["UltraSecretPool"]
        end,
        Display = function()
            local onOff = "False"

            if config["UltraSecretPool"] then
                onOff = "True"
            end
            return "Use Ultra Secret Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["UltraSecretPool"] = currentBool
        end,
    })

    ModConfigMenu.AddSetting("Random Start Item Plus","Item Pools", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return config["PlanetariumPool"]
        end,
        Display = function()
            local onOff = "False"

            if config["PlanetariumPool"] then
                onOff = "True"
            end
            return "Use Planetarium Pool: " .. onOff
        end,
        OnChange = function(currentBool)
            config["PlanetariumPool"] = currentBool
        end,
    })
end