local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local dataObj = LDB:NewDataObject("Token price", {
    label = "Token price",
    type = "data source",
    icon = "Interface\\Icons\\WoW_Token01",
	text = GetMoneyString(0)
})

local function UpdatePriceReschedule()
    C_WowTokenPublic.UpdateMarketPrice()
    local currentprice = C_WowTokenPublic.GetCurrentMarketPrice()
    if currentprice ~= nil then
		dataObj.text = GetMoneyString(currentprice)
    end
    C_Timer.After(60, UpdatePriceReschedule)
end
C_Timer.After(5, UpdatePriceReschedule)