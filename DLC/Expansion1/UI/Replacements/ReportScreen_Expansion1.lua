--[[
-- Copyright (c) 2017 Firaxis Games
--]]
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("ReportScreen");


function ViewCityStatusPage()

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	local pHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityStatusHeaderInstance", pHeaderInstance, instance.Top ) ;	

	-- 
	for cityName,kCityData in pairs(m_kCityData) do

		local pCityInstance:table = {}
		ContextPtr:BuildInstanceForControl( "CityStatusEntryInstance", pCityInstance, instance.Top ) ;	
		TruncateStringWithTooltip(pCityInstance.CityName, 130, Locale.Lookup(kCityData.CityName)); 
		pCityInstance.Population:SetText( tostring(kCityData.Population) .. "/" .. tostring(kCityData.Housing));

		if kCityData.HousingMultiplier == 0 or kCityData.Occupied then
			status = "LOC_HUD_REPORTS_STATUS_HALTED";
		elseif kCityData.HousingMultiplier <= 0.5 then
			status = "LOC_HUD_REPORTS_STATUS_SLOWED";
		else
			status = "LOC_HUD_REPORTS_STATUS_NORMAL";
		end
		pCityInstance.GrowthRateStatus:SetText( Locale.Lookup(status) );

		pCityInstance.Amenities:SetText( tostring(kCityData.AmenitiesNum).." / "..tostring(kCityData.AmenitiesRequiredNum) );

		local happinessText:string = Locale.Lookup( GameInfo.Happinesses[kCityData.Happiness].Name );
		pCityInstance.CitizenHappiness:SetText( happinessText );

		local warWearyValue:number = kCityData.AmenitiesLostFromWarWeariness;
		pCityInstance.WarWeariness:SetText( (warWearyValue==0) and "0" or "-"..tostring(warWearyValue) );

		-- Loyalty
		local pCulturalIdentity = kCityData.City:GetCulturalIdentity();
		local currentLoyalty = pCulturalIdentity:GetLoyalty();
		local maxLoyalty = pCulturalIdentity:GetMaxLoyalty();
		local loyaltyPerTurn:number = pCulturalIdentity:GetLoyaltyPerTurn();
		local loyaltyFontIcon:string = loyaltyPerTurn >= 0 and "[ICON_PressureUp]" or "[ICON_PressureDown]";
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

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	Controls.CollapseAll:SetHide(true);
	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( true );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88);
end


function Initialize()

	m_tabIM:ResetInstances();
	m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
	AddTabSection( "LOC_HUD_REPORTS_TAB_YIELDS",		ViewYieldsPage );
	AddTabSection( "LOC_HUD_REPORTS_TAB_RESOURCES",		ViewResourcesPage );
	AddTabSection( "LOC_HUD_REPORTS_TAB_CITY_STATUS",	ViewCityStatusPage );	

	m_tabs.SameSizedTabs(50);
	m_tabs.CenterAlignTabs(-10);	
end
Initialize();

