-- ===========================================================================
--	Functions related to finding the yield bonuses (district) plots are given
--	due to some attribute of an adjacent plot.
-- ==========================================================================
include( "Civ6Common" );		-- GetYieldString()
include( "MapEnums" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local START_INDEX	:number = GameInfo.Yields["YIELD_FOOD"].Index;
local END_INDEX		:number = GameInfo.Yields["YIELD_FAITH"].Index;


local m_DistrictsWithAdjacencyBonuses	:table = {};
for row in GameInfo.District_Adjacencies() do
	local districtIndex = GameInfo.Districts[row.DistrictType].Index;
	if (districtIndex ~= nil) then
		m_DistrictsWithAdjacencyBonuses[districtIndex] = true;
	end
end

-- ===========================================================================
--	Obtain the artdef string name that shows an adjacency icon for a plot type.
--	RETURNS: Artdef string name for an icon to display between hexes
-- ===========================================================================
function GetAdjacentIconArtdefName( targetDistrictType:string, plot:table, pkCity:table, direction:number )

	local eDistrict = GameInfo.Districts[targetDistrictType].Index;
	local eType = -1;
	local iSubType = -1;
	eType, iSubType = plot:GetAdjacencyBonusType(Game.GetLocalPlayer(), pkCity:GetID(), eDistrict, direction);

	if eType == AdjacencyBonusTypes.NO_ADJACENCY then
		return "";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_DISTRICT then
		return "Districts_Generic_District";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_FEATURE then
		if iSubType == g_FEATURE_JUNGLE then
			return "Terrain_Jungle";
		elseif iSubType == g_FEATURE_FOREST then
			return "Terrain_Forest";
		elseif iSubType == g_FEATURE_GEOTHERMAL_FISSURE then
			return "Terrain_Generic_Resource";
		elseif iSubType == g_FEATURE_REEF then
			return "Terrain_Reef";
		end
	elseif eType == AdjacencyBonusTypes.ADJACENCY_IMPROVEMENT then
		if iSubType == 1 then
			return "Improvements_Farm";
		elseif iSubType == 2 then
			return "Improvement_Mine";
		elseif iSubType == 3 then
			return "Improvement_Quarry";
		end
	elseif eType == AdjacencyBonusTypes.ADJACENCY_NATURAL_WONDER then
		return "Wonders_Natural_Wonder";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_RESOURCE then
		return "Terrain_Generic_Resource";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_RESOURCE_CLASS then
		return "Terrain_Generic_Resource_Class";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_RIVER then
		return "Terrain_River";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_SEA_RESOURCE then
		return "Terrain_Sea";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_TERRAIN then
		if iSubType == g_TERRAIN_TYPE_TUNDRA or iSubType == g_TERRAIN_TYPE_TUNDRA_HILLS then
			return "Terrain_Tundra";
		elseif iSubType == g_TERRAIN_TYPE_DESERT or iSubType == g_TERRAIN_TYPE_DESERT_HILLS then
			return "Terrain_Desert";
		elseif iSubType == g_TERRAIN_TYPE_COAST then -- TODO or TERRAIN_TYPE_OCEAN?
			return "Terrain_Coast";
		else -- TODO specify mountain and have an error asset if no match?
			return "Terrain_Mountain";
		end
	elseif eType == AdjacencyBonusTypes.ADJACENCY_WONDER then
		return "Generic_Wonder";
	end
	
	-- Default to generic icon
	return "Terrain_Generic_Resource";
end

-- ===========================================================================
--	Obtain a table of adjacency bonuses
-- ===========================================================================
function AddAdjacentPlotBonuses( kPlot:table, districtType:string, pSelectedCity:table, tCurrentBonuses:table )
	local adjacentPlotBonuses:table = {};
	local x		:number = kPlot:GetX();
	local y		:number = kPlot:GetY();

	for _,direction in pairs(DirectionTypes) do			
		if direction ~= DirectionTypes.NO_DIRECTION and direction ~= DirectionTypes.NUM_DIRECTION_TYPES then
			local adjacentPlot	:table= Map.GetAdjacentPlot( x, y, direction);
			if adjacentPlot ~= nil then
				local artdefIconName:string = GetAdjacentIconArtdefName( districtType, adjacentPlot, pSelectedCity, direction );
			
				if artdefIconName ~= nil and artdefIconName ~= "" then

		
					local districtViewInfo:table = GetViewPlotInfo( adjacentPlot, tCurrentBonuses );
					local oppositeDirection :number = -1;
					if direction == DirectionTypes.DIRECTION_NORTHEAST	then oppositeDirection = DirectionTypes.DIRECTION_SOUTHWEST; end
					if direction == DirectionTypes.DIRECTION_EAST		then oppositeDirection = DirectionTypes.DIRECTION_WEST; end
					if direction == DirectionTypes.DIRECTION_SOUTHEAST	then oppositeDirection = DirectionTypes.DIRECTION_NORTHWEST; end
					if direction == DirectionTypes.DIRECTION_SOUTHWEST	then oppositeDirection = DirectionTypes.DIRECTION_NORTHEAST; end
					if direction == DirectionTypes.DIRECTION_WEST		then oppositeDirection = DirectionTypes.DIRECTION_EAST; end
					if direction == DirectionTypes.DIRECTION_NORTHWEST	then oppositeDirection = DirectionTypes.DIRECTION_SOUTHEAST; end

					table.insert( districtViewInfo.adjacent, {
						direction	= oppositeDirection,
						iconArtdef	= artdefIconName,
						inBonus		= false,
						outBonus	= true					
						}
					);				

					adjacentPlotBonuses[adjacentPlot:GetIndex()] = districtViewInfo;
				end
			end		
		end
	end

	return adjacentPlotBonuses;
end

-- ===========================================================================
--	Adds a plot and all the adjacencent plots, unless already added.
--	ARGS:		kPlot,			gamecore plot object
--	ARGS:		kExistingTable,	table of existing plot into to check if we already have info about this plot
--	RETURNS:	A new/updated plotInfo table
-- ===========================================================================
function GetViewPlotInfo( kPlot:table, kExistingTable:table )
	local plotId	:number = kPlot:GetIndex();
	local plotInfo	:table = kExistingTable[plotId];
	if plotInfo == nil then 
		plotInfo = {
			index	= plotId, 
			x		= kPlot:GetX(), 
			y		= kPlot:GetY(),
			adjacent= {},				-- adjacent edge bonuses
			selectable = false,			-- change state with mouse over?
			purchasable = false
		}; 
	end
	--print( "   plot: " .. plotInfo.x .. "," .. plotInfo.y..": " .. tostring(plotInfo.iconArtdef) );
	return plotInfo;
end

-- ===========================================================================
--	RETURNS: true or false, indicating whether this placement option should be 
--	shown when the player can purchase the plot.
-- ===========================================================================
function IsShownIfPlotPurchaseable(eDistrict:number, pkCity:table, plot:table)
	local yieldBonus:string = GetAdjacentYieldBonusString(eDistrict, pkCity, plot);

	-- If we would get a bonus for placing here, then show it as an option
	if (yieldBonus ~= nil and yieldBonus ~= "") then
		return true;
	end

	-- If there are no adjacency bonuses for this district type (and so no bonuses to be had), then show it as an option
	if (m_DistrictsWithAdjacencyBonuses[eDistrict] == nil or m_DistrictsWithAdjacencyBonuses[eDistrict] == false) then
		return true;
	end

	return false;
end

-- ===========================================================================
--	RETURNS: "" if no bonus or...
--		1. Text with the bonuses for a district if added to the given plot,
--		2. parameter is a tooltip with detailed bonus informatin
--		3. NIL if can be used or a string explaining what needs to be done for plot to be usable.
-- ===========================================================================
function GetAdjacentYieldBonusString( eDistrict:number, pkCity:table, plot:table )

	local tooltipText	:string = "";
	local totalBonuses	:string = "";
	local requiredText	:string = "";
	local isFirstEntry	:boolean = true;	
	local iconString:string = "";
	
	-- Special handling for Neighborhoods
	if (GameInfo.Districts[eDistrict].OnePerCity == false) then

		tooltipText, requiredText = plot:GetAdjacencyBonusTooltip(Game.GetLocalPlayer(), pkCity:GetID(), eDistrict, 0);
		-- Ensure required text is NIL if none was returned.
		if requiredText ~= nil and string.len(requiredText) < 1 then
			requiredText = nil;
		end

	-- Normal handling for all other districts
	else
		-- Check each neighbor if it matches criteria with the adjacency rules
		for iBonusYield = START_INDEX, END_INDEX do
			local iBonus:number = plot:GetAdjacencyYield(Game.GetLocalPlayer(), pkCity:GetID(), eDistrict, iBonusYield); 
			if (iBonus > 0) then
				local yieldTooltip, yieldRequireText = plot:GetAdjacencyBonusTooltip(Game.GetLocalPlayer(), pkCity:GetID(), eDistrict, iBonusYield);
				if tooltipText == "" then
					tooltipText = yieldTooltip;
				else
					tooltipText = tooltipText .. "[NEWLINE]" .. yieldTooltip;
				end

				-- There is always only one requiredText so just replace it
				requiredText = yieldRequireText;

				local yieldString:string = GetYieldString( GameInfo.Yields[iBonusYield].YieldType, iBonus );
				if iconString == "" then
					iconString = yieldString;
				else
					iconString = iconString .. "[NEWLINE]" .. yieldString;
				end
			end
		end
			
		-- Ensure required text is NIL if none was returned.
		if requiredText ~= nil and string.len(requiredText) < 1 then
			requiredText = nil;
		end
	end	

	-- Housing effects from districts (both one-per and normal)
	local iAppeal = plot:GetAppeal();
	local iBaseHousing = GameInfo.Districts[eDistrict].Housing;

	-- Default is Mbanza case (no appeal change)
	local iTotalHousing:number = iBaseHousing;

	for row in GameInfo.AppealHousingChanges() do
		if (row.DistrictType == GameInfo.Districts[eDistrict].DistrictType) then
			local iMinimumValue = row.MinimumValue;
			local iAppealChange = row.AppealChange;
			local szDescription = row.Description;
			if (iAppeal >= iMinimumValue) then
				iTotalHousing = iBaseHousing + iAppealChange;
				tooltipText = Locale.Lookup("LOC_DISTRICT_ZONE_NEIGHBORHOOD_TOOLTIP", iBaseHousing + iAppealChange, szDescription);
				break;
			end
		end
	end

	if iTotalHousing ~= 0 then
		iconString = "[ICON_Housing]+" .. tostring(iTotalHousing);
	end

	return iconString, tooltipText, requiredText;
end



-- ===========================================================================
--	Obtain all the owned (or could be owned) plots of a city.
--	ARGS: pCity, the city to obtain plots from
--	RETURNS: table of plot indices
-- ===========================================================================
function GetCityRelatedPlotIndexes( pCity:table )
	
	print("GetCityRelatedPlotIndexes() isn't updated with the latest purchaed plot if one was just purchased and this is being called on Event.CityMadePurchase !");
	local plots:table = Map.GetCityPlots():GetPurchasedPlots( pCity );

	-- Plots that arent't owned, but could be (and hence, could be a great spot for that district!)
	local tParameters :table = {};
	tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
	local tResults = CityManager.GetCommandTargets( pCity, CityCommandTypes.PURCHASE, tParameters );
	if (tResults[CityCommandResults.PLOTS] ~= nil and table.count(tResults[CityCommandResults.PLOTS]) ~= 0) then
		for _,plotId in pairs(tResults[CityCommandResults.PLOTS]) do
			table.insert(plots, plotId);
		end
	end

	return plots;
end

-- ===========================================================================
--	Same as above but specific to districts and works despite the cache not having an updated value.
-- ===========================================================================
function GetCityRelatedPlotIndexesDistrictsAlternative( pCity:table, districtHash:number )

	local district		:table = GameInfo.Districts[districtHash];
	local plots			:table = {};
	local tParameters	:table = {};

	tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtHash;


	-- Available to place plots.
	local tResults :table = CityManager.GetOperationTargets( pCity, CityOperationTypes.BUILD, tParameters );
	if (tResults[CityOperationResults.PLOTS] ~= nil and table.count(tResults[CityOperationResults.PLOTS]) ~= 0) then			
		local kPlots:table = tResults[CityOperationResults.PLOTS];			
		for i, plotId in ipairs(kPlots) do
			table.insert(plots, plotId);
		end	
	end	

	--[[
	-- antonjs: Removing blocked plots from the UI display. Now that district placement can automatically remove features, resources, and improvements,
	-- as long as the player has the tech, there is not much need to show blocked plots and they end up being confusing.
	-- Plots that eventually can hold a district but are blocked by some required operation.
	if (tResults[CityOperationResults.BLOCKED_PLOTS] ~= nil and table.count(tResults[CityOperationResults.BLOCKED_PLOTS]) ~= 0) then			
		for _, plotId in ipairs(tResults[CityOperationResults.BLOCKED_PLOTS]) do
			table.insert(plots, plotId);		
		end
	end
	--]]

	-- Plots that arent't owned, but if they were, would give a bonus.
	tParameters = {};
	tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
	local tResults = CityManager.GetCommandTargets( pCity, CityCommandTypes.PURCHASE, tParameters );
	if (tResults[CityCommandResults.PLOTS] ~= nil and table.count(tResults[CityCommandResults.PLOTS]) ~= 0) then
		for _,plotId in pairs(tResults[CityCommandResults.PLOTS]) do
			
			local kPlot	:table = Map.GetPlotByIndex(plotId);	
			if kPlot:CanHaveDistrict(district.Index, pCity:GetOwner(), pCity:GetID()) then
				local isValid :boolean = IsShownIfPlotPurchaseable(district.Index, pCity, kPlot);
				if isValid then
					table.insert(plots, plotId);
				end
			end
			
		end
	end
	return plots;
end

-- ===========================================================================
--	Same as above but specific to wonders and works despite the cache not having an updated value.
-- ===========================================================================
function GetCityRelatedPlotIndexesWondersAlternative( pCity:table, buildingHash:number )

	local building		:table = GameInfo.Buildings[buildingHash];
	local plots			:table = {};
	local tParameters	:table = {};

	tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingHash;


	-- Available to place plots.
	local tResults :table = CityManager.GetOperationTargets( pCity, CityOperationTypes.BUILD, tParameters );
	if (tResults[CityOperationResults.PLOTS] ~= nil and table.count(tResults[CityOperationResults.PLOTS]) ~= 0) then			
		local kPlots:table = tResults[CityOperationResults.PLOTS];			
		for i, plotId in ipairs(kPlots) do
			table.insert(plots, plotId);
		end	
	end	

	-- Plots that aren't owned, but if they were, would give a bonus.
	tParameters = {};
	tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
	local tResults = CityManager.GetCommandTargets( pCity, CityCommandTypes.PURCHASE, tParameters );
	if (tResults[CityCommandResults.PLOTS] ~= nil and table.count(tResults[CityCommandResults.PLOTS]) ~= 0) then
		for _,plotId in pairs(tResults[CityCommandResults.PLOTS]) do
			
			local kPlot	:table = Map.GetPlotByIndex(plotId);	
			if kPlot:CanHaveWonder(building.Index, pCity:GetOwner(), pCity:GetID()) then
				table.insert(plots, plotId);
			end
			
		end
	end
	return plots;
end
