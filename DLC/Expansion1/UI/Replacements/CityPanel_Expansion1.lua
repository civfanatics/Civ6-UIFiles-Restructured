-- Copyright 2017-2019, Firaxis Games

include("CityPanel");
BASE_ViewMain = ViewMain;

-- ===========================================================================
function ViewMain( kData:table )
	BASE_ViewMain( kData );
	local pCity :table = UI.GetHeadSelectedCity();
	if pCity ~= nil then
		local pCulturalIdentity :table = pCity:GetCulturalIdentity();
		local currentLoyalty	:number= pCulturalIdentity:GetLoyalty();

		Controls.BreakdownLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_CULTURAL_IDENTITY_LOYALTY_SUBSECTION")));
		Controls.BreakdownIcon:SetIcon("ICON_STAT_CULTURAL_FLAG");
		Controls.BreakdownNum:SetText(Round(currentLoyalty, 1));
		Controls.BreakdownNum:SetOffsetX(19);
	end
end

-- ===========================================================================
function OnCityLoyaltyChanged( ownerPlayerID:number, cityID:number )
	if UI.IsCityIDSelected(ownerPlayerID, cityID) then
		UI.DeselectCityID(ownerPlayerID, cityID);
	end
end

-- ===========================================================================
function LateInitialize()
	Events.CityLoyaltyChanged.Add(OnCityLoyaltyChanged);
end
