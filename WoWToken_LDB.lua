local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local dataObj = LDB:NewDataObject("Token price", {
  label = "Token price",
  type = "data source",
  icon = "Interface\\Icons\\WoW_Token01",
  text = GetMoneyString(0)
})

local function UpdateDisplay()
  local currentprice = C_WowTokenPublic.GetCurrentMarketPrice()
  if currentprice ~= nil then
    dataObj.text = GetMoneyString(currentprice)
  end
end

local function UpdatePriceReschedule()
  C_WowTokenPublic.UpdateMarketPrice()
  C_Timer.After(5, UpdateDisplay)
  C_Timer.After(55, UpdatePriceReschedule)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    UpdatePriceReschedule()
    self:UnregisterEvent("PLAYER_LOGIN")
  end
end)
