local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local UPDATE_INTERVAL = 60

local dataObj = LDB:NewDataObject("Token price", {
    label = "Token price",
    type = "data source",
    icon = "Interface\\Icons\\WoW_Token01",
    text = "---"
})

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        C_WowTokenPublic.UpdateMarketPrice()
        C_Timer.NewTicker(UPDATE_INTERVAL, function()
            C_WowTokenPublic.UpdateMarketPrice()
        end)
        return
    end

    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if price then
        dataObj.text = GetMoneyString(price, true)
    end
end)
