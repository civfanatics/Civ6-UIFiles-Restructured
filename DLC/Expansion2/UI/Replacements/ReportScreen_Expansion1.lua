-- Copyright 2017-2018, 2017 Firaxis Games
include("ReportScreen");

-- ===========================================================================
-- Override base game
-- ===========================================================================
function CreateCityStatusInstance( kParentInstance:table, kCityData:table )
	local cityName :string = kCityData.CityName;
	local pCityInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityStatusEntryInstance", pCityInstance, kParentInstance.Top ) ;	
	TruncateStringWithTooltip(pCityInstance.CityName, 130, Locale.Lookup(kCityData.CityName)); 
	pCityInstance.Population:SetText( tostring(kCityData.Population) .. "/" .. tostring(kCityData.Housing));

	if kCityData.HousingMultiplier == 0 or kCityData.Occupied then
		status = "LOC_HUD_REPORTS_STATUS_HALTED";
	elseif kCityData.HousingMultiplier <= 0.5 then
		status = "LOC_HUD_REPORTS_STATUS_SLOWED";
	else
		if kCityData.HappinessGrowthModifier > 0 then
			status = "LOC_HUD_REPORTS_STATUS_ACCELERATED";
		else
			status = "LOC_HUD_REPORTS_STATUS_NORMAL";
		end
	end
	pCityInstance.GrowthRateStatus:SetText( Locale.Lookup(status) );

	pCityInstance.Amenities:SetText( tostring(kCityData.AmenitiesNum).." / "..tostring(kCityData.AmenitiesRequiredNum) );

	local happinessText:string = Locale.Lookup( GameInfo.Happinesses[kCityData.Happiness].Name );
	pCityInstance.CitizenHappiness:SetText( happinessText );

	local warWearyValue:number = kCityData.AmenitiesLostFromWarWeariness;
	pCityInstance.WarWeariness:SetText( (warWearyValue==0) and "0" or "-"..tostring(warWearyValue) );

	-- Loyalty
	local pCulturalIdentity	:table = kCityData.City:GetCulturalIdentity();
	local currentLoyalty	:number = pCulturalIdentity:GetLoyalty();
	local maxLoyalty		:number = pCulturalIdentity:GetMaxLoyalty();
	local loyaltyPerTurn	:number = pCulturalIdentity:GetLoyaltyPerTurn();
	local loyaltyFontIcon	:string = loyaltyPerTurn >= 0 and "[ICON_PressureUp]" or "[ICON_PressureDown]";
	pCityInstance.Loyalty:SetText(loyaltyFontIcon .. " " .. Round(currentLoyalty, 1) .. "/" .. maxLoyalty);

	local pAssignedGovernor = kCityData.City:GetAssignedGovernor();
	if pAssignedGovernor then
		local eGovernorType = pAssignedGovernor:GetType();
		local governorDefinition = GameInfo.Governors[eGovernorType];
		local governorMode = pAssignedGovernor:IsEstablished() and "_FILL" or "_SLOT";
		local governorIcon = "ICON_" .. governorDefinition.GovernorType .. governorMode;
		pCityInstance.Governor:SetText("[" .. governorIcon .. "]");
	else
		pCityInstance.Governor:SetText("");
	end

	pCityInstance.Strength:SetText( tostring(kCityData.Defense) );
	pCityInstance.Damage:SetText( tostring(kCityData.HitpointsTotal - kCityData.HitpointsCurrent) );
end