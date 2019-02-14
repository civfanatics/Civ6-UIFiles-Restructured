-- ===========================================================================
--	Copyright (c) 2018 Firaxis Games
-- ===========================================================================

-- ===========================================================================
-- INCLUDE XP1 FILE
-- ===========================================================================
include("UnitPanel_Expansion1");


-- ===========================================================================
--	Add to base tables
-- ===========================================================================
local BASE_InitSubjectData = InitSubjectData;
local BASE_GetBuildImprovementParameters = GetBuildImprovementParameters;
local BASE_ReadCustomUnitStats = ReadCustomUnitStats;
local Base_RealizeSpecializedViews = RealizeSpecializedViews;
local BASE_FilterUnitStatsFromUnitData = FilterUnitStatsFromUnitData;


-- ===========================================================================
--	OVERRIDE
--	Call base to get values and then XP2 related fields.
-- ===========================================================================
function InitSubjectData()
	local kSubjectData:table = BASE_InitSubjectData();
	kSubjectData.RockBandLevel	= -1;
	kSubjectData.AlbumSales		= 0;	
	kSubjectData.IsRockbandUnit	= false;
	return kSubjectData;	
end


-- ===========================================================================
--	OVERRIDE
--	Populate XP2 specific units that have custom stats.
-- ===========================================================================
function ReadCustomUnitStats( pUnit:table, kSubjectData:table )	
	kSubjectData = BASE_ReadCustomUnitStats(pUnit, kSubjectData );
	if GameInfo.Units[kSubjectData.UnitType].UnitType == "UNIT_ROCK_BAND" then 
		kSubjectData.IsRockbandUnit = true;
		kSubjectData.RockBandLevel	= pUnit:GetRockBand():GetRockBandLevel();
		kSubjectData.AlbumSales		= pUnit:GetRockBand():GetAlbumSales();
	end

	return kSubjectData;
end


-- ===========================================================================
--	OVERRIDE
--	Is this hash representing an improvement to be built?
-- ===========================================================================
function IsBuildingImprovement( actionHash:number )
	return (actionHash == UnitOperationTypes.BUILD_IMPROVEMENT 
	  	or actionHash == UnitOperationTypes.BUILD_IMPROVEMENT_ADJACENT);
end


-- ===========================================================================
--	OVERRIDE
--	Obtain the parameters for a building improvement.
--	actionHash, the hash of the type of the operation type
--	pUnit, the unit doing the operation
-- ===========================================================================
function GetBuildImprovementParameters(actionHash, pUnit)
	if actionHash == UnitOperationTypes.BUILD_IMPROVEMENT_ADJACENT then
		return {};	-- no parameters
	end
	return BASE_GetBuildImprovementParameters(actionHash, pUnit);
end

-- ===========================================================================
--	OVERRIDE
--	Returns: Callback function, Disabled state
-- ===========================================================================
function GetBuildImprovementCallback( actionHash :number, isDisabledIn:boolean )
	local callbackFn	:ifunction = OnUnitActionClicked_BuildImprovement;
	local isDisabled	:boolean = isDisabledIn;
	if (actionHash == UnitOperationTypes.BUILD_IMPROVEMENT_ADJACENT) then
		callbackFn = OnUnitActionClicked_BuildImprovementAdjacent;
		isDisabledModified = false;
	else
		callbackFn = OnUnitActionClicked_BuildImprovement;
		isDisabledModified = isDisabled;
	end
	return callbackFn, isDisabledModified;
end

-- ===========================================================================
function AddUpgradeResourceCost( pUnit:table )
	local toolTipString:string = "";
	if (GameInfo.Units_XP2~= nil) then
		local upgradeResource, upgradeResourceCost = pUnit:GetUpgradeResourceCost();
		if (upgradeResource ~= nil and upgradeResource >= 0) then
			local resourceName:string = Locale.Lookup(GameInfo.Resources[upgradeResource].Name);
			local resourceIcon = "[ICON_" .. GameInfo.Resources[upgradeResource].ResourceType .. "]";
			toolTipString = "[NEWLINE]" .. Locale.Lookup("LOC_UNITOPERATION_UPGRADE_RESOURCE_INFO", upgradeResourceCost, resourceIcon, resourceName)
		end
	end
	return toolTipString;
end

-- ===========================================================================
-- UnitAction<BuildImprovementAdjacent> was clicked.
-- ===========================================================================
function OnUnitActionClicked_BuildImprovementAdjacent( improvementHash, dummy )
	if (g_isOkayToProcess) then
		local pSelectedUnit = UI.GetHeadSelectedUnit();
		if (pSelectedUnit ~= nil) then
			local tParameters = {};
			tParameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash;
			tParameters[UnitOperationTypes.PARAM_OPERATION_TYPE] = UnitOperationTypes.BUILD_IMPROVEMENT_ADJACENT;
			UI.SetInterfaceMode(InterfaceModeTypes.BUILD_IMPROVEMENT_ADJACENT, tParameters);
		end
		ContextPtr:RequestRefresh();
	end
end

-- ===========================================================================
function RockbandView( kData:table )
	if kData.IsRockbandUnit == false then return; end
	-- TODO: populate with rock band information if using a custom view (may want to remove stats data entries)
end


-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function FilterUnitStatsFromUnitData( kUnitData:table, ignoreStatType:number )
	local kData:table= BASE_FilterUnitStatsFromUnitData( kUnitData, ignoreStatType );

	if kUnitData.IsRockbandUnit then 
		table.insert(kData, {Value = kUnitData.AlbumSales,		Type = "ActionCharges",	Label = "LOC_HUD_UNIT_PANEL_ROCK_BAND_ALBUM_SALES",	FontIcon="[ICON_Charges_Large]",		IconName="ICON_STAT_RECORD_SALES"});
		table.insert(kData, {Value = kUnitData.RockBandLevel,	Type = "SpreadCharges", Label = "LOC_HUD_UNIT_PANEL_ROCK_BAND_LEVEL",		FontIcon="[ICON_ReligionStat_Large]",	IconName="ICON_STAT_ROCKBAND_LEVEL"});
	end

	return kData;
end

-- ===========================================================================
function RealizeSpecializedViews( kData:table )
	Base_RealizeSpecializedViews(kData);
	RockbandView(kData);
end