-- Copyright 2018-2019, Firaxis Games

include("CityPanel_Expansion1");

-- ===========================================================================
-- Function overrides
-- ===========================================================================
function DisplayGrowthTile()
	local bCanShowGrowth:boolean = true;
	local iLocalPlayerID:number = Game.GetLocalPlayer();
	local kResolutions:table = Game.GetWorldCongress():GetResolutions(iLocalPlayerID);

	if kResolutions ~= nil then
		for i, kResolutionData in pairs(kResolutions) do
            if type(kResolutionData) == "table" then -- There's a "Stage" key in kResolutions
                if kResolutionData.ChosenOption == "LOC_WORLD_CONGRESS_NO_CULTURE_BORDER_GROWTH_DESC" and tonumber(kResolutionData.ChosenThing) == iLocalPlayerID then
					bCanShowGrowth = false;
				end
            end
		end
	end

	if g_pCity ~= nil and bCanShowGrowth and HasCapability("CAPABILITY_CULTURE") then
		local cityCulture:table = g_pCity:GetCulture();
		if cityCulture ~= nil then
			local newGrowthPlot:number = cityCulture:GetNextPlot();
			if(newGrowthPlot ~= -1 and newGrowthPlot ~= g_growthPlotId) then
				g_growthPlotId = newGrowthPlot;
				
				local cost:number = cityCulture:GetNextPlotCultureCost();
				local currentCulture:number = cityCulture:GetCurrentCulture();
				local currentYield:number = cityCulture:GetCultureYield();
				local currentGrowth:number = math.max(math.min(currentCulture / cost, 1.0), 0);
				local nextTurnGrowth:number = math.max(math.min((currentCulture + currentYield) / cost, 1.0), 0);

				UILens.SetLayerGrowthHex(m_PurchasePlot, Game.GetLocalPlayer(), g_growthPlotId, 1, "GrowthHexBG");
				UILens.SetLayerGrowthHex(m_PurchasePlot, Game.GetLocalPlayer(), g_growthPlotId, nextTurnGrowth, "GrowthHexNext");
				UILens.SetLayerGrowthHex(m_PurchasePlot, Game.GetLocalPlayer(), g_growthPlotId, currentGrowth, "GrowthHexCurrent");

				local turnsRemaining:number = cityCulture:GetTurnsUntilExpansion();
				Controls.TurnsLeftDescription:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITY_TURNS_UNTIL_BORDER_GROWTH", turnsRemaining)));
				Controls.TurnsLeftLabel:SetText(turnsRemaining);
				Controls.GrowthHexStack:CalculateSize();
				g_growthHexTextWidth = Controls.GrowthHexStack:GetSizeX();

				Events.Camera_Updated.Add(OnCameraUpdate);
				Events.CityMadePurchase.Add(OnCityMadePurchase);
				Controls.GrowthHexAnchor:SetHide(false);
				OnCameraUpdate();
			end
		end
	end
end

