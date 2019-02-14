g_PanelHasFocus = false;

-------------------------------------------------------------------------------
g_PlacementSettings =
{
	Active = false,
	Player = -1,
	CityID = -1,
	DistrictID = -1,
	PlacementConstruction = 100,
	PlacementHandler = nil,

	EditKey = "",
	EditVal = ""
}

-------------------------------------------------------------------------------
function GetSelectedCity()
	if (g_PlacementSettings.Player >= 0 and g_PlacementSettings.CityID >= 0) then
		local pPlayer = Players[g_PlacementSettings.Player];
		if pPlayer ~= nil then
			local cities = pPlayer:GetCities();
			if ( cities ~= nil ) then
				return cities:FindID(g_PlacementSettings.CityID);
			end
		end
	end
	return nil;
end

-------------------------------------------------------------------------------
function GetSelectedDistrict()
	local pCity = GetSelectedCity();
	if pCity ~= nil and g_PlacementSettings.DistrictID >= 0 then
		local pCityDistricts = pCity:GetDistricts();
		if pCityDistricts ~= nil then
			return pCityDistricts:GetDistrictByID(g_PlacementSettings.DistrictID);
		end
	end
	return nil;
end

-------------------------------------------------------------------------------
function GetSelectedPlayer()
	if (g_PlacementSettings.Player >= 0) then
		local pPlayer = Players[g_PlacementSettings.Player];
		return pPlayer;
	end
	return nil;
end

-------------------------------------------------------------------------------
function GetCityAt(plot)
	local city = Cities.GetPlotWorkingCity(plot:GetIndex())
	if ( city == nil ) then return end

	g_PlacementSettings.Player = city:GetOwner();
	g_PlacementSettings.CityID = city:GetID();
end

g_CityPicker = 
{
	Place = GetCityAt,
	Remove = GetCityAt
}

-------------------------------------------------------------------------------
g_DistrictPlacement =
{
	DistrictType = -1,
	DistrictTypeName = "",

	Place =
	function(plot)
		local city = GetSelectedCity();
		if (city ~= nil) then
			local pBuildQueue = city:GetBuildQueue();
			pBuildQueue:CreateIncompleteDistrict(g_DistrictPlacement.DistrictType, plot:GetIndex(), 
				g_PlacementSettings.PlacementConstruction);
		end
	end,
	
	Remove =
	function(plot)
		local pDistrict = CityManager.GetDistrictAt(plot);
		if (pDistrict ~= nil) then
			CityManager.DestroyDistrict(pDistrict);
		end
	end
}

-------------------------------------------------------------------------------
g_BuildingPlacement =
{
	BuildingType = -1,
	BuildingTypeName = "",
	
	Place =
	function(plot)
		local city = GetSelectedCity();
		if (city ~= nil) then
			local pBuildQueue = city:GetBuildQueue();
			pBuildQueue:CreateIncompleteBuilding(g_BuildingPlacement.BuildingType, plot:GetIndex(), 
				g_PlacementSettings.PlacementConstruction);
		end
	end,
	
	Remove =
	function(plot)

	end
}

-------------------------------------------------------------------------------
function OnLButtonUp( plotX, plotY )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );

		if (g_PlacementSettings ~= nil and
				g_PlacementSettings.PlacementHandler ~= nil and
				g_PlacementSettings.PlacementHandler.Place ~= nil) then

			g_PlacementSettings.PlacementHandler.Place(plot);
		end
	
		-- LuaEvents.TunerExitDebugMode();
	end
	return;
end

LuaEvents.TunerMapLButtonUp.Add(OnLButtonUp);

-------------------------------------------------------------------------------
function OnRButtonDown( plotX, plotY )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );
		
		if (g_PlacementSettings ~= nil and
				g_PlacementSettings.PlacementHandler ~= nil and
				g_PlacementSettings.PlacementHandler.Remove ~= nil) then

			g_PlacementSettings.PlacementHandler.Remove(plot);
		end
	
		-- LuaEvents.TunerExitDebugMode();
	end
	return;
end

LuaEvents.TunerMapRButtonDown.Add(OnRButtonDown);

-------------------------------------------------------------------------------
function OnUIDebugModeEntered()
	if (g_PanelHasFocus == true) then
		g_PlacementSettings.Active = true;
	end
end

LuaEvents.UIDebugModeEntered.Add(OnUIDebugModeEntered);

-------------------------------------------------------------------------------
function OnUIDebugModeExited()
	if (g_PanelHasFocus == true) then
		g_PlacementSettings.Active = false;
	end
end

LuaEvents.UIDebugModeExited.Add(OnUIDebugModeExited);
