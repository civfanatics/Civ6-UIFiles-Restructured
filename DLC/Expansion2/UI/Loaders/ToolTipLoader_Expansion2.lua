--[[
-- Created by Anton Strenger, April 17 2018
-- Copyright (c) Firaxis Games
--]]

-- ===========================================================================

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_GetBuildingToolTip = ToolTipHelper.GetBuildingToolTip;
BASE_AddBuildingExtraCostTooltip = AddBuildingExtraCostTooltip;
BASE_AddBuildingYieldTooltip = AddBuildingYieldTooltip;
BASE_AddBuildingEntertainmentTooltip = AddBuildingEntertainmentTooltip;
BASE_AddUnitStrategicResourceTooltip = AddUnitStrategicResourceTooltip;
BASE_AddUnitResourceMaintenanceTooltip = AddUnitResourceMaintenanceTooltip;
BASE_AddGovernmentExtraInfoTooltip = AddGovernmentExtraInfoTooltip;
BASE_AddProjectStrategicResourceTooltip = AddProjectStrategicResourceTooltip;
BASE_AddReactorProjectData = AddReactorProjectData;

-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================

-- ===========================================================================
AddBuildingExtraCostTooltip = function(buildingHash, tooltipLines)
	local buildingReference:table = GameInfo.Buildings[buildingHash];
	if (buildingReference ~= nil) then
		local buildingType:string = buildingReference.BuildingType;
		if (GameInfo.Buildings_XP2 ~= nil) then
			for row in GameInfo.Buildings_XP2() do
				if (row.BuildingType == buildingType) then
					if (row.RequiredPower ~= nil and row.RequiredPower ~= 0) then
						table.insert(tooltipLines, Locale.Lookup("LOC_TOOLTIP_POWER_REQUIRED", row.RequiredPower));
					end
				end
			end
		end
	end
end

-- ===========================================================================
AddBuildingYieldTooltip = function(buildingHash, city, tooltipLines)
	local buildingReference:table = GameInfo.Buildings[buildingHash];
	if (buildingReference ~= nil) then
		local buildingType:string = buildingReference.BuildingType;
		if (city == nil) then
			for row in GameInfo.Building_YieldChanges() do
				if(row.BuildingType == buildingType) then
					local yield = GameInfo.Yields[row.YieldType];
					if (yield) then
						local yieldChange = row.YieldChange;
						table.insert(tooltipLines, Locale.Lookup("LOC_TYPE_TRAIT_YIELD", yieldChange, yield.IconString, yield.Name)); 
						for rowPowered in GameInfo.Building_YieldChangesBonusWithPower() do
							if (rowPowered.BuildingType == buildingType and rowPowered.YieldType == row.YieldType and rowPowered.YieldChange > 0) then
								table.insert(tooltipLines, Locale.Lookup("LOC_TYPE_TRAIT_YIELD_POWER_ENHANCEMENT", rowPowered.YieldChange, yield.IconString, yield.Name)); 
							end
						end
					end
				end
			end
		else
			for yield in GameInfo.Yields() do
				local yieldChangeWithoutPower = city:GetBuildingPotentialYield(buildingHash, yield.YieldType, false);
				local yieldChangeWithPower = city:GetBuildingPotentialYield(buildingHash, yield.YieldType, true);
				if (yieldChangeWithoutPower > 0) then
					table.insert(tooltipLines, Locale.Lookup("LOC_TYPE_TRAIT_YIELD", yieldChangeWithoutPower, yield.IconString, yield.Name)); 
				end
				isChangedWithPower = (yieldChangeWithoutPower ~= yieldChangeWithPower);
				if (isChangedWithPower) then
					local yieldChangeDifference = yieldChangeWithPower - yieldChangeWithoutPower;
					table.insert(tooltipLines, Locale.Lookup("LOC_TYPE_TRAIT_YIELD_POWER_ENHANCEMENT", yieldChangeDifference, yield.IconString, yield.Name));
				end
			end
		end
	end
end

-- ===========================================================================
AddBuildingEntertainmentTooltip = function(buildingHash, city, district, tooltipLines)
	local buildingReference:table = GameInfo.Buildings[buildingHash];
	if (buildingReference ~= nil) then
		local buildingType:string = buildingReference.BuildingType;
		local entertainment:number = buildingReference.Entertainment or 0;
		if (entertainment ~= 0) then
			if district ~= nil and buildingReference.RegionalRange ~= 0 then
				entertainment = entertainment + district:GetExtraRegionalEntertainment();
			end
			table.insert(tooltipLines, Locale.Lookup("LOC_TYPE_TRAIT_AMENITY_ENTERTAINMENT", entertainment));
		end

		if (GameInfo.Buildings_XP2 ~= nil) then
			for row in GameInfo.Buildings_XP2() do
				if (row.BuildingType == buildingType) then
					if (row.EntertainmentBonusWithPower ~= nil and row.EntertainmentBonusWithPower ~= 0) then
						table.insert(tooltipLines, Locale.Lookup("LOC_TYPE_TRAIT_AMENITY_ENTERTAINMENT_POWER_ENHANCEMENT", row.EntertainmentBonusWithPower));
					end
				end
			end
		end
	end
end

-- ===========================================================================
AddUnitStrategicResourceTooltip = function(unitReference, formationType, pBuildQueue, toolTip)
	local resource = GameInfo.Resources[unitReference.StrategicResource];
	if (pBuildQueue ~= nil ) then
		local resourceAmount = pBuildQueue:GetUnitResourceCost(unitReference.Index, formationType);
		if (resource ~= nil) then
			local resourceIcon = "[ICON_" .. resource.ResourceType .. "]";
			table.insert(toolTip, Locale.Lookup("LOC_UNIT_PRODUCTION_RESOURCE_COST", resourceAmount, resourceIcon, resource.Name));
		end
	else
		if (GameInfo.Units_XP2~= nil) then
			for row in GameInfo.Units_XP2() do
				if (row.UnitType == unitReference.UnitType) then
					local resourceAmount = row.ResourceCost;
					local resourceIcon = "[ICON_" .. resource.ResourceType .. "]";
					table.insert(toolTip, Locale.Lookup("LOC_UNIT_PRODUCTION_RESOURCE_COST", resourceAmount, resourceIcon, resource.Name));
				end
			end
		end
	end
end

-- ===========================================================================
AddUnitResourceMaintenanceTooltip = function(unitReference, formationType, pBuildQueue, toolTip)
	if (GameInfo.Units_XP2~= nil) then
		for row in GameInfo.Units_XP2() do
			if (row.UnitType == unitReference.UnitType) then
				local resourceMaintenanceAmount = row.ResourceMaintenanceAmount;
				if (resourceMaintenanceAmount > 0) then
					local resource = GameInfo.Resources[row.ResourceMaintenanceType];
					if (resource ~= nil) then
						local fuelName = Locale.Lookup(resource.Name);
						local iconName:string = "[ICON_" .. row.ResourceMaintenanceType .. "]";
						table.insert(toolTip, Locale.Lookup("LOC_UNIT_PRODUCTION_FUEL_CONSUMPTION", resourceMaintenanceAmount,  iconName, fuelName));
					end
				end
			end
		end
	end
end

-- ===========================================================================
AddProjectStrategicResourceTooltip = function(projectReference, toolTip)
	if (GameInfo.Project_ResourceCosts ~= nil) then
		for row in GameInfo.Project_ResourceCosts() do
			if (row.ProjectType == projectReference.ProjectType) then
				local resource = GameInfo.Resources[row.ResourceType];
				if (resource ~= nil) then
					local resourceAmount = row.StartProductionCost;
					table.insert(toolTip, Locale.Lookup("LOC_TOOLTIP_BUILDING_REQUIRES") .. resourceAmount .. " [ICON_" .. resource.ResourceType .. "]" .. Locale.Lookup(resource.Name));
					break;
				end
			end
		end
	end
end

-- ===========================================================================
AddReactorProjectData = function(projectReference, toolTipLines)
	if (projectReference ~= nil and pBuildQueue ~= nil) then
		if (projectReference.ProjectType == "PROJECT_RECOMMISSION_REACTOR") then
			local pCity:table = UI.GetHeadSelectedCity();
			if (pCity ~= nil) then
				local kFalloutManager = Game.GetFalloutManager();
				if (kFalloutManager ~= nil) then
					local iReactorAge = kFalloutManager:GetReactorAge(pCity);
					if (iReactorAge ~= nil) then
						table.insert(toolTipLines, "[NEWLINE]" .. Locale.Lookup("LOC_TOOLTIP_PROJECT_REACTOR_AGE", iReactorAge));
					end
					local iAccidentThreshold:number = kFalloutManager:GetReactorAccidentThreshold(pCity);
					if (iAccidentThreshold ~= nil) then
						if (iAccidentThreshold > 0) then
							table.insert(toolTipLines, Locale.Lookup("LOC_TOOLTIP_PROJECT_REACTOR_ACCIDENT1_POSSIBLE"));
						end
						if (iAccidentThreshold > 1) then
							table.insert(toolTipLines, Locale.Lookup("LOC_TOOLTIP_PROJECT_REACTOR_ACCIDENT2_POSSIBLE"));
						end
						if (iAccidentThreshold > 2) then
							table.insert(toolTipLines, Locale.Lookup("LOC_TOOLTIP_PROJECT_REACTOR_ACCIDENT3_POSSIBLE"));
						end
					end
				end
			end
		end
	end
end

-- ===========================================================================
AddGovernmentExtraInfoTooltip = function(governmentReference, toolTipLines)
	if (GameInfo.Governments_XP2 ~= nil and governmentReference ~= nil) then
		for row in GameInfo.Governments_XP2() do
			if (row.GovernmentType == governmentReference.GovernmentType) then
				local favor = row.Favor;
				if (favor > 0) then
					local favorBonusDescription = Locale.Lookup("LOC_GOVT_FAVOR_PER_TURN", favor);
					if(not Locale.IsNilOrWhitespace(favorBonusDescription)) then
						table.insert(toolTipLines, Locale.Lookup("{LOC_GOVERNMENT_FAVOR_BONUS}: {1}", favorBonusDescription));
					end
				end
			end
		end
	end
end

g_ToolTipGenerators.KIND_BUILDING = ToolTipHelper.GetBuildingToolTip;
