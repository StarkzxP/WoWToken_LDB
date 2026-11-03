local ADDON_NAME = ...
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local UPDATE_INTERVAL = 60   -- seconds between price requests
local HISTORY_MAX = 48       -- price changes kept per region
local TOOLTIP_HISTORY = 6    -- recent changes shown in the tooltip

local FORMATS = { "full", "gold", "short" }
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
-- |Tpath:height:width:offsetX:offsetY:...|t  (x +2 = closer to the text, y +1 = up / -1 = down)
local ARROW_UP = "|T" .. MEDIA .. "ArrowUp:0:0:2:1:32:32:0:32:0:32:64:255:64|t"
local ARROW_DOWN = "|T" .. MEDIA .. "ArrowDown:0:0:2:-1:32:32:0:32:0:32:255:64:64|t"
local GOLD_SUFFIX = "|cffffd100g|r"

local db, regionData
local sessionLow, sessionHigh
local lastCheck

local dataObj = LDB:NewDataObject("Token price", {
    label = "Token price",
    type = "data source",
    icon = "Interface\\Icons\\WoW_Token01",
    text = "---",
})

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(msg)
    print("|cff33aaffToken LDB:|r " .. msg)
end

local function GoldOf(copper)
    return math.floor(copper / 10000)
end

local function FormatGold(copper)
    return BreakUpLargeNumbers(GoldOf(copper)) .. GOLD_SUFFIX
end

local function FormatShort(copper)
    local gold = GoldOf(copper)
    if gold >= 1000000 then
        return string.format("%.2fM", gold / 1000000) .. GOLD_SUFFIX
    elseif gold >= 1000 then
        return string.format("%.1fk", gold / 1000) .. GOLD_SUFFIX
    end
    return gold .. GOLD_SUFFIX
end

local function FormatPrice(copper, fmt)
    fmt = fmt or (db and db.format) or "full"
    if fmt == "gold" then
        return FormatGold(copper)
    elseif fmt == "short" then
        return FormatShort(copper)
    end
    return GetMoneyString(copper, true)
end

local function TimeAgo(t)
    local diff = time() - t
    if diff < 60 then
        return "just now"
    end
    return SecondsToTime(diff, true) .. " ago"
end

local function GetRegionKey()
    if GetCurrentRegionName then
        local name = GetCurrentRegionName()
        if name and name ~= "" then
            return name
        end
    end
    if GetCurrentRegion then
        return "region" .. tostring(GetCurrentRegion())
    end
    return "default"
end

-- Last two recorded prices: current and the one before the last change.
local function GetLastChange()
    local h = regionData.history
    local n = #h
    if n >= 2 then
        return h[n], h[n - 1]
    end
    return h[n], nil
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------

local function Refresh()
    local current, previous = GetLastChange()
    if not current then
        dataObj.text = "---"
        return
    end
    local arrow = ""
    if previous then
        if current.p > previous.p then
            arrow = ARROW_UP .. " "
        elseif current.p < previous.p then
            arrow = ARROW_DOWN .. " "
        end
    end
    dataObj.text = arrow .. FormatPrice(current.p)
end

local function OnPrice(price)
    local now = time()
    lastCheck = now

    sessionLow = (not sessionLow or price < sessionLow) and price or sessionLow
    sessionHigh = (not sessionHigh or price > sessionHigh) and price or sessionHigh

    if not regionData.low or price < regionData.low.p then
        regionData.low = { t = now, p = price }
    end
    if not regionData.high or price > regionData.high.p then
        regionData.high = { t = now, p = price }
    end

    local h = regionData.history
    if not h[#h] or h[#h].p ~= price then
        h[#h + 1] = { t = now, p = price }
        while #h > HISTORY_MAX do
            table.remove(h, 1)
        end
    end

    Refresh()
end

---------------------------------------------------------------------------
-- LDB callbacks
---------------------------------------------------------------------------

function dataObj.OnTooltipShow(tt)
    tt:AddLine("WoW Token")
    local current, previous = GetLastChange()
    if not current then
        tt:AddLine("Waiting for price data...", 0.7, 0.7, 0.7)
        return
    end

    tt:AddDoubleLine("Current price", FormatPrice(current.p, "full"), 1, 1, 1, 1, 1, 1)
    if previous then
        local diff = current.p - previous.p
        local pct = previous.p > 0 and (diff / previous.p * 100) or 0
        local sign = diff >= 0 and "+" or "-"
        local text = string.format("%s%s (%s%.1f%%)", sign, FormatGold(math.abs(diff)), sign, math.abs(pct))
        local r, g = diff >= 0 and 0.25 or 1, diff >= 0 and 1 or 0.25
        tt:AddDoubleLine("Last change", text, 1, 1, 1, r, g, 0.25)
        tt:AddDoubleLine("Changed", TimeAgo(current.t), 1, 1, 1, 0.8, 0.8, 0.8)
    end
    if lastCheck then
        tt:AddDoubleLine("Checked", TimeAgo(lastCheck), 1, 1, 1, 0.8, 0.8, 0.8)
    end

    if sessionLow then
        tt:AddLine(" ")
        tt:AddDoubleLine("Session low / high",
            FormatGold(sessionLow) .. " / " .. FormatGold(sessionHigh), 1, 1, 1, 1, 1, 1)
    end
    if regionData.low and regionData.high then
        tt:AddDoubleLine("Recorded low", FormatGold(regionData.low.p) .. "  " .. date("%Y-%m-%d", regionData.low.t),
            1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine("Recorded high", FormatGold(regionData.high.p) .. "  " .. date("%Y-%m-%d", regionData.high.t),
            1, 1, 1, 1, 1, 1)
    end

    local h = regionData.history
    if #h > 1 then
        tt:AddLine(" ")
        tt:AddLine("Recent changes", 1, 0.82, 0)
        for i = #h, math.max(1, #h - TOOLTIP_HISTORY + 1), -1 do
            local entry, prev = h[i], h[i - 1]
            local arrow = ""
            if prev then
                arrow = entry.p > prev.p and ARROW_UP or (entry.p < prev.p and ARROW_DOWN or "")
            end
            tt:AddDoubleLine(date("%m-%d %H:%M", entry.t), arrow .. " " .. FormatGold(entry.p),
                0.8, 0.8, 0.8, 1, 1, 1)
        end
    end

    tt:AddLine(" ")
    tt:AddLine("Shift-click: post price to chat", 0, 1, 0)
    tt:AddLine("Right-click: change display format", 0, 1, 0)
end

function dataObj.OnClick(_, button)
    if button == "RightButton" then
        local idx = 1
        for i, f in ipairs(FORMATS) do
            if f == db.format then
                idx = i
            end
        end
        db.format = FORMATS[idx % #FORMATS + 1]
        Refresh()
        return
    end

    if IsShiftKeyDown() then
        local current = GetLastChange()
        if not current then
            return
        end
        local msg = "WoW Token: " .. BreakUpLargeNumbers(GoldOf(current.p)) .. "g"
        local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
        if not (insert and insert(msg)) then
            Print(msg)
        end
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_WOWTOKENLDB1 = "/tokenldb"
SlashCmdList.WOWTOKENLDB = function(input)
    local cmd, arg = strtrim(input or ""):lower():match("^(%S*)%s*(.-)$")
    if cmd == "format" and (arg == "full" or arg == "gold" or arg == "short") then
        db.format = arg
        Refresh()
        Print("display format set to " .. arg .. ".")
    elseif cmd == "reset" then
        wipe(regionData.history)
        regionData.low, regionData.high = nil, nil
        Print("price history cleared for this region.")
        Refresh()
    else
        Print("commands:")
        print("  /tokenldb format full | gold | short - display format")
        print("  /tokenldb reset - clear price history for this region")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then
            return
        end
        self:UnregisterEvent("ADDON_LOADED")
        WoWToken_LDB_DB = WoWToken_LDB_DB or {}
        db = WoWToken_LDB_DB
        db.format = db.format or "full"
        db.regions = db.regions or {}
        return
    end

    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        local key = GetRegionKey()
        db.regions[key] = db.regions[key] or { history = {} }
        regionData = db.regions[key]
        Refresh() -- show the last known price until the first update arrives

        self:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
        C_WowTokenPublic.UpdateMarketPrice()
        C_Timer.NewTicker(UPDATE_INTERVAL, function()
            C_WowTokenPublic.UpdateMarketPrice()
        end)
        return
    end

    -- TOKEN_MARKET_PRICE_UPDATED
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if price and price > 0 then
        OnPrice(price)
    end
end)
