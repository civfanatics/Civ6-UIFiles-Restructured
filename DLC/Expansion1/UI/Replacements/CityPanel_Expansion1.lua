--[[
-- Created by Tyler Berry, Aug 14 2017
-- Copyright (c) Firaxis Games
--]]
-- ===========================================================================
-- Base File
-- ===========================================================================
include("CityPanel");
BASE_ViewMain = ViewMain;
-- ===========================================================================

function ViewMain( data:table )
	BASE_ViewMain( data );
	local pCity = UI.GetHeadSelectedCity();
	if pCity ~= nil then
		local pCulturalIdentity = pCity:GetCulturalIdentity();
		local currentLoyalty = pCulturalIdentity:GetLoyalty();

		Controls.BreakdownLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_CULTURAL_IDENTITY_LOYALTY_SUBSECTION")));
		Controls.BreakdownIcon:SetIcon("ICON_STAT_CULTURAL_FLAG");
		Controls.BreakdownNum:SetText(Round(currentLoyalty, 1));
		Controls.BreakdownNum:SetOffsetX(19);
	end
end

function OnCityLoyaltyChanged( ownerPlayerID:number, cityID:number )
	if UI.IsCityIDSelected(ownerPlayerID, cityID) then
		UI.DeselectCityID(ownerPlayerID, cityID);
	end
end

function Initialize()
	Events.CityLoyaltyChanged.Add(OnCityLoyaltyChanged);
end
Initialize();