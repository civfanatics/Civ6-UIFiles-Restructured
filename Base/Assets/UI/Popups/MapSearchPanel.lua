include( "InstanceManager" );

-- ===========================================================================
-- Global constants
-- ===========================================================================
SEARCHCONTEXT_MAPSEARCH   = "MapSearch_Primary"
SEARCHCONTEXT_SUGGESTIONS = "MapSearch_Suggestions";
g_bMapSearchInitialized   = false;
g_bSuggestionsInitialized = false;

local COLOR_WHITE = UI.GetColorValueFromHexLiteral(0xFFFFFFFF);
local COLOR_GREEN = UI.GetColorValueFromHexLiteral(0x2800FF00);
local PLOTS_CHECKED_PER_FRAME = 128;
local MAXIMUM_SEARCH_HISTORY = 5;

-- Enable suggestions that exactly match the current search term
-- Personally, I prefer it the other way, but this seems to be common
local g_bShowExactMatchSuggestions = true;

-- ===========================================================================
-- Global variables
-- ===========================================================================
local m_Search = { Whitelist = { }, Blacklist = { } };
local m_nLastPlotSearched = -1;

local m_ResultPlots = { };
local m_ResultGroups = { };
local m_FocusedResult = 0;

local m_SearchSuggestionIM : table = InstanceManager:new( "SuggestionEntry", "SuggestionButton", Controls.SearchSuggestionStack );
local m_FilterSuggestionIM : table = InstanceManager:new( "SuggestionEntry", "SuggestionButton", Controls.FilterSuggestionStack );

local m_bIsShutdown : boolean = false;
local m_TabCompleteString = nil;

local m_SearchHistory = { }
local m_FilterHistory = { }

-- ===========================================================================
-- Lookup tables, mostly copied from PlotToolTip.lua
-- ===========================================================================
local ResourceClassNameMap = {
["RESOURCECLASS_BONUS"]     = "LOC_TOOLTIP_BONUS_RESOURCE",
["RESOURCECLASS_LUXURY"]    = "LOC_TOOLTIP_LUXURY_RESOURCE",
["RESOURCECLASS_STRATEGIC"] = "LOC_TOOLTIP_STRATEGIC_RESOURCE",
["RESOURCECLASS_ARTIFACT"]  = "LOC_TOOLTIP_ARTIFACT_RESOURCE",
};

local GreatWorkTypeNameMap = {
["GREATWORKOBJECT_SCULPTURE"] = "LOC_GREAT_WORK_OBJECT_SCULPTURE_NAME",
["GREATWORKOBJECT_PORTRAIT"]  = "LOC_GREAT_WORK_OBJECT_PORTRAIT_NAME",
["GREATWORKOBJECT_LANDSCAPE"] = "LOC_GREAT_WORK_OBJECT_LANDSCAPE_NAME",
["GREATWORKOBJECT_RELIGIOUS"] = "LOC_GREAT_WORK_OBJECT_RELIGIOUS_NAME",
["GREATWORKOBJECT_ARTIFACT"]  = "LOC_GREAT_WORK_OBJECT_ARTIFACT_NAME",
["GREATWORKOBJECT_WRITING"]   = "LOC_GREAT_WORK_OBJECT_WRITING_NAME",
["GREATWORKOBJECT_MUSIC"]     = "LOC_GREAT_WORK_OBJECT_MUSIC_NAME",
["GREATWORKOBJECT_RELIC"]     = "LOC_GREAT_WORK_OBJECT_RELIC_NAME",
};

local FormationClassNameMap = {
["FORMATION_CLASS_LAND_COMBAT"] = "LOC_FORMATION_CLASS_LAND_COMBAT_NAME",
["FORMATION_CLASS_SUPPORT"]     = "LOC_FORMATION_CLASS_SUPPORT_NAME",
["FORMATION_CLASS_CIVILIAN"]    = "LOC_FORMATION_CLASS_CIVILIAN_NAME",
["FORMATION_CLASS_NAVAL"]       = "LOC_FORMATION_CLASS_NAVAL_NAME",
["FORMATION_CLASS_AIR"]         = "LOC_FORMATION_CLASS_AIR_NAME",
};

local OmittedTermsMap = {
["LOC_BUILDING_SMALL_ROCKET_NAME"]  = true,
["LOC_BUILDING_MEDIUM_ROCKET_NAME"] = true,
["LOC_BUILDING_LARGE_ROCKET_NAME"]  = true,
["LOC_UNIT_BARBARIAN_GALLEY_NAME"]  = true,
["LOC_TOOLTIP_ARTIFACT_RESOURCE"]   = true,
};

local TerrainTypeMap :table = {};
do
	for row in GameInfo.Terrains() do
		TerrainTypeMap[row.Index] = row.TerrainType;
	end
end

local FeatureTypeMap :table = {};
do
	for row in GameInfo.Features() do
		FeatureTypeMap[row.Index] = row.FeatureType;
	end
end

local ImprovementTypeMap :table = {};
do
	for row in GameInfo.Improvements() do
		ImprovementTypeMap[row.Index] = row.ImprovementType;
	end
end

local ResourceTypeMap :table = {};
do
	for row in GameInfo.Resources() do
		ResourceTypeMap[row.Index] = row.ResourceType;
	end
end

local UnitTypeMap :table = {};
do
	for row in GameInfo.Units() do
		UnitTypeMap[row.Index] = row.UnitType;
	end
end

local BuildingTypeMap :table = {};
do
	for row in GameInfo.Buildings() do
		BuildingTypeMap[row.Index] = row.BuildingType;
	end
end

local DistrictTypeMap :table = {};
do
	for row in GameInfo.Districts() do
		DistrictTypeMap[row.Index] = row.DistrictType;
	end
end

local ContinentTypeMap :table = {};
do
	for row in GameInfo.Continents() do
		ContinentTypeMap[row.Index] = row.ContinentType;
	end
end

-- ===========================================================================
-- ===========================================================================
function StopSearch()
	ContextPtr:ClearUpdate();
	m_nLastPlotSearched = -1;
end

-- ===========================================================================
-- ===========================================================================
function ClearSearch(bFullClear)
	StopSearch();

	if bFullClear then
		local pOverlay:object = UILens.GetOverlay("MapSearch");
		if (pOverlay ~= nil) then
			pOverlay:ClearAll();
		end

		m_Search.Whitelist = { };
		m_Search.Blacklist = { };
	end
	
	Controls.NextResultButton:SetDisabled(true);
	Controls.PrevResultButton:SetDisabled(true);

	m_ResultPlots = { };
	m_ResultGroups = { };
	m_FocusedResult = 0;
end

-- ===========================================================================
-- ===========================================================================
function ValidateSearchTerms()

	-- if the same term is in the blacklist AND whitelist, remove it from the blacklist
	for _,pTermWL in ipairs(m_Search.Whitelist) do
		for i,pTermBL in ipairs(m_Search.Blacklist) do
			local pLowerWL = Locale.ToLower(pTermWL);
			local pLowerBL = Locale.ToLower(pTermBL);
			if Locale.Compare(pLowerWL, pLowerBL) == 0 then
				m_Search.Blacklist[i] = "";
			end
		end
	end

	if table.count(m_Search.Whitelist) > 0 then
		return true;
	end

	return false
end

-- ===========================================================================
-- This function assumes SEARCHCONTEXT_MAPSEARCH has already been populated
-- ===========================================================================
function CheckForMatches()
	
	-- this seems to be required for correctness
	Search.Optimize(SEARCHCONTEXT_MAPSEARCH);
	
	local kResultCounters = { }
	local nRequiredCount = 0;

	-- ensure *ALL* of the whitelist terms are found
	for _,key in pairs(m_Search.Whitelist) do
		local kResults = Search.Search(SEARCHCONTEXT_MAPSEARCH, key, PLOTS_CHECKED_PER_FRAME);
		if (kResults == nil) or (#kResults == 0) then
			-- none of the plots match, early out
			return;
		end
		
		nRequiredCount = nRequiredCount + 1;
		for _,result in pairs(kResults) do
			local iPlot = tonumber(result[1]);
			if kResultCounters[iPlot] == nil then
				kResultCounters[iPlot] = 1;
			else
				kResultCounters[iPlot] = kResultCounters[iPlot] + 1;
			end
		end
	end

	-- ensure *NONE* of the blacklist terms are found
	for _,key in pairs(m_Search.Blacklist) do
		local kResults = Search.Search(SEARCHCONTEXT_MAPSEARCH, key, PLOTS_CHECKED_PER_FRAME);
		if (kResults ~= nil) and (#kResults > 0) then
			for _,result in pairs(kResults) do
				local iPlot = tonumber(result[1]);
				kResultCounters[iPlot] = -1;
			end
		end
	end

	for iPlot,nCount in pairs(kResultCounters) do
		if nCount >= nRequiredCount then
			table.insert(m_ResultPlots, iPlot);
		end
	end

end

-- ===========================================================================
-- GetPlotSearchTerms(data)
-- Construct a list of search terms that will match with this plot
-- ===========================================================================
function GetPlotSearchTerms(data)

	local bAlwaysHasAppeal = false;
	local eLocalPlayer = Game.GetLocalPlayer();
	local pLocalPlayer = Players[eLocalPlayer];

	local pSearchTerms = { };
	local AddLocalizedSearchTerm = function(kLocKey)
		table.insert( pSearchTerms, Locale.Lookup(kLocKey) );
	end

	-- OWNER
	if(data.Owner ~= nil) then
		AddLocalizedSearchTerm( data.OwningCityName );
		AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_OWNED" );
		local pPlayerConfig = PlayerConfigurations[data.Owner];
		if (pPlayerConfig ~= nil) then
			AddLocalizedSearchTerm( pPlayerConfig:GetCivilizationShortDescription() );
			local pPlayer = Players[data.Owner];
			if(GameConfiguration:IsAnyMultiplayer() and pPlayer:IsHuman()) then
				AddLocalizedSearchTerm( pPlayerConfig:GetPlayerName() );
			end
		end
	else
		AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_UNCLAIMED" );
	end
	
	-- TERRAIN
	if data.IsLake then
		AddLocalizedSearchTerm( "LOC_TOOLTIP_LAKE" );
	elseif data.TerrainTypeName == "LOC_TERRAIN_COAST_NAME" then
		AddLocalizedSearchTerm( "LOC_TOOLTIP_COAST" );
	else
		AddLocalizedSearchTerm( data.TerrainTypeName );
	end
	if data.IsWater then
		AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_WATER" );
	end
	if data.IsMountain then
		AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_MOUNTAIN" );
	end
	if data.IsHill then
		AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_HILL" );
	end
	if data.IsRiver then
		AddLocalizedSearchTerm( "LOC_TOOLTIP_RIVER" );
	end
	if data.Impassable then
		AddLocalizedSearchTerm( "LOC_TOOLTIP_PLOT_IMPASSABLE_TEXT" );
	end

	-- FEATURES
	-- TODO add 'Second Growth' and 'Old Growth' terms
	if (data.FeatureType ~= nil) then
		local pFeature = GameInfo.Features[data.FeatureType];
		AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_FEATURE" );
		if pFeature.NaturalWonder then
			AddLocalizedSearchTerm( "LOC_NATURAL_WONDER_NAME" );
			bAlwaysHasAppeal = true;
		end

		AddLocalizedSearchTerm( pFeature.Name );
	end
	
	-- RESOURCES
	if(data.ResourceType ~= nil) then
		local pResource = GameInfo.Resources[data.ResourceType];

		-- If there is no local player, it can be visible
		local bResourceVisible = true;
		if pLocalPlayer ~= nil then
			local pPlayerResources = pLocalPlayer:GetResources();
			bResourceVisible = pPlayerResources:IsResourceVisible(pResource.Hash);
		end
		
		if bResourceVisible then
			AddLocalizedSearchTerm( ResourceClassNameMap[pResource.ResourceClassType] );
			AddLocalizedSearchTerm( pResource.Name );
		end
	end
	
	-- ROUTE TILE
	if (data.IsRoute and not data.Impassable) then -- Filter out Mountain Tunnels which are marked as routes
		local routeInfo = GameInfo.Routes[data.RouteType];
		if (routeInfo ~= nil and routeInfo.Name ~= nil) then
			AddLocalizedSearchTerm( "LOC_ROUTE_NAME" );
			AddLocalizedSearchTerm( routeInfo.Name );
			if data.RoutePillaged then
				AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_PILLAGED" );
			end
		end
	end

	-- APPEAL
	if (bAlwaysHasAppeal or not data.IsWater) then
		for row in GameInfo.AppealHousingChanges() do
			if (data.Appeal >= row.MinimumValue) then
				AddLocalizedSearchTerm( row.Description );
				break;
			end
		end
	end

	-- CONTINENT
	if (data.Continent ~= nil) then
		AddLocalizedSearchTerm( GameInfo.Continents[data.Continent].Description );
	end

	-- WONDER
	if (data.WonderType ~= nil) then
		AddLocalizedSearchTerm( "LOC_WONDER_NAME" );
		AddLocalizedSearchTerm( GameInfo.Buildings[data.WonderType].Name );
		if not data.WonderComplete then
			AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_UNDER_CONSTRUCTION" );
		end
	end
	
	-- IMPROVEMENT
	if (data.ImprovementType ~= nil) then
		AddLocalizedSearchTerm( "LOC_IMPROVEMENT_NAME" );
		AddLocalizedSearchTerm( GameInfo.Improvements[data.ImprovementType].Name );
		if (data.ImprovementPillaged) then
			AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_PILLAGED" );
		end
	end
	
	-- YIELDS
	for yieldType, v in pairs(data.Yields) do
		AddLocalizedSearchTerm( GameInfo.Yields[yieldType].Name );
	end
	
	-- FALLOUT
	if (data.Fallout > 0) then
		AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_CONTAMINATION" );
	end
	
	-- NATIONAL PARK
	if (data.NationalPark ~= nil) then
		AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_NATIONAL_PARK" );
		table.insert( pSearchTerms, data.NationalPark ); -- this is already localized
	end

	-- CITY TILE
	if (data.IsCity == true and data.DistrictType ~= nil) then
		
		AddLocalizedSearchTerm( GameInfo.Districts[data.DistrictType].Name )

	-- NON-CITY DISTRICT
	elseif (data.DistrictID ~= -1 and data.DistrictType ~= nil) then
		if (not GameInfo.Districts[data.DistrictType].InternalOnly) then --Ignore 'Wonder' districts
			-- Plot yields (ie. from Specialists)
			if (data.Yields ~= nil and table.count(data.Yields) > 0) then
				-- On a district tile, data.Yields can only come from specialists
				-- Yield search terms from specialists are handled in the YIELDS section above
				AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_SPECIALIST" );
			end

			AddLocalizedSearchTerm( "LOC_DISTRICT_NAME" );
			AddLocalizedSearchTerm( GameInfo.Districts[data.DistrictType].Name );
			if (data.DistrictPillaged) then
				AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_PILLAGED" );
			elseif (not data.DistrictComplete) then
				AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_UNDER_CONSTRUCTION" );
			end
			
			-- Inherent district yields
			for yieldType, v in pairs(data.DistrictYields) do
				AddLocalizedSearchTerm( GameInfo.Yields[yieldType].Name );
			end
		end
	end

	-- BUILDINGS + GREAT WORKS
	if (data.IsCity or data.WonderType ~= nil or data.DistrictID ~= -1) then
		if(data.BuildingNames ~= nil and table.count(data.BuildingNames) > 0) then

			local cityBuildings = data.OwnerCity:GetBuildings();
			if (data.WonderType == nil) then
				AddLocalizedSearchTerm( "LOC_BUILDING_NAME" );
			end

			local kGreatWorkTable = { };
			for i,szBuildingName in ipairs(data.BuildingNames) do 
			    if (data.WonderType == nil) then
					AddLocalizedSearchTerm( szBuildingName );
					if (data.BuildingsPillaged[i]) then
						AddLocalizedSearchTerm( "LOC_HUD_MAP_SEARCH_TERMS_PILLAGED" );
					end
				end

				local iSlots = cityBuildings:GetNumGreatWorkSlots(data.BuildingTypes[i]);
				for j = 0, iSlots - 1, 1 do
					local greatWorkIndex:number = cityBuildings:GetGreatWorkInSlot(data.BuildingTypes[i], j);
					if (greatWorkIndex ~= -1) then
						local greatWorkType:number = cityBuildings:GetGreatWorkTypeFromIndex(greatWorkIndex)
						local pGreatWork = GameInfo.GreatWorks[greatWorkType];
						
						if (kGreatWorkTable[pGreatWork.GreatWorkObjectType] == nil) then
							kGreatWorkTable[pGreatWork.GreatWorkObjectType] = { pGreatWork.Name };
						else
							table.insert(kGreatWorkTable[pGreatWork.GreatWorkObjectType], pGreatWork.Name);
						end
					end
				end
			end

			if table.count(kGreatWorkTable) > 0 then
				AddLocalizedSearchTerm( "LOC_GREAT_WORKS" );
				for kGreatWorkType,kGreatWorkList in pairs(kGreatWorkTable) do
					AddLocalizedSearchTerm( GreatWorkTypeNameMap[kGreatWorkType] );
					for _,szWorkName in pairs(kGreatWorkList) do
						AddLocalizedSearchTerm( szWorkName );
					end
				end
			end
		end
	end
	
	-- UNITS
	local pPlayerVis = PlayersVisibility[eLocalPlayer];
	if pPlayerVis ~= nil and pPlayerVis:IsVisible(data.X, data.Y) then
		local pUnitList:table = Units.GetUnitsInPlotLayerID( data.X, data.Y, MapLayers.ANY );
		if pUnitList ~= nil then
			-- A set of additional terms to add
			local pAdditionalTerms = { };

			for _,pUnit in pairs(pUnitList) do
				if pPlayerVis:IsUnitVisible(pUnit) and not pUnit:IsDelayedDeath() then
					local pUnitInfo:table = GameInfo.Units[pUnit:GetUnitType()];

					-- Add the unit name, and the unit type name if the unit has a custom name
					local pUnitName = pUnit:GetName();
					local pTypeName = pUnitInfo.Name;
					AddLocalizedSearchTerm(pUnitName);
					if pUnitName ~= pTypeName then
						AddLocalizedSearchTerm(pTypeName);
					end
					
					-- Add the unit owner's name
					local eUnitOwner = pUnit:GetOwner();
					local pPlayerConfig = PlayerConfigurations[eUnitOwner];
					if (pPlayerConfig ~= nil) then
						local pOwnerName = pPlayerConfig:GetCivilizationShortDescription();
						pAdditionalTerms[pOwnerName] = true;
						local pPlayer = Players[eUnitOwner];
						if(GameConfiguration:IsAnyMultiplayer() and pPlayer:IsHuman()) then
							local pPlayerName = pPlayerConfig:GetCivilizationShortDescription();
							pAdditionalTerms[pPlayerName] = true;
						end
					end

					-- Add the unit formations
					local eFormation = pUnit:GetMilitaryFormation();
					if pUnitInfo.Domain == "DOMAIN_SEA" then
						if (eFormation == MilitaryFormationTypes.CORPS_FORMATION) then
							pAdditionalTerms["LOC_UNITFLAG_FLEET_SUFFIX"] = true;
						elseif (eFormation == MilitaryFormationTypes.ARMY_FORMATION) then
							pAdditionalTerms["LOC_UNITFLAG_ARMADA_SUFFIX"] = true;
						end	
					else
						if (eFormation == MilitaryFormationTypes.CORPS_FORMATION) then
							pAdditionalTerms["LOC_UNITFLAG_CORPS_SUFFIX"] = true;
						elseif (eFormation == MilitaryFormationTypes.ARMY_FORMATION) then
							pAdditionalTerms["LOC_UNITFLAG_ARMY_SUFFIX"] = true;
						end
					end

					-- TODO more precise unit classes, e.g. heavy cavalry and anti air
					if pUnitInfo.Combat and pUnitInfo.Combat > 0 then
						pAdditionalTerms["LOC_PROMOTION_CLASS_MELEE_NAME"] = true;
					end
					if pUnitInfo.RangedCombat and pUnitInfo.RangedCombat > 0 then
						pAdditionalTerms["LOC_PROMOTION_CLASS_RANGED_NAME"] = true;
					end
					if pUnitInfo.BombardCombat and pUnitInfo.BombardCombat > 0 then
						pAdditionalTerms["LOC_PROMOTION_CLASS_SIEGE_NAME"] = true;
					end

					-- Add additional terms to the set (only once)
					local pFormationClass = FormationClassNameMap[pUnitInfo.FormationClass]
					pAdditionalTerms[pFormationClass] = true;
					pAdditionalTerms["LOC_UNIT_NAME"] = true;
				end
			end

			for pTerm,_ in pairs(pAdditionalTerms) do
				AddLocalizedSearchTerm(pTerm);
			end
		end
	end
	
	-- maybe more?

	return pSearchTerms;
end

-- ===========================================================================
-- Collect plot data and return it as a table
-- ===========================================================================
function FetchData(plot)

	local kFalloutManager = Game.GetFalloutManager();
	return {
		X		= plot:GetX(),
		Y		= plot:GetY(),
		Index	= plot:GetIndex(),
		Appeal				= plot:GetAppeal(),
		Continent			= ContinentTypeMap[plot:GetContinentType()] or nil,
		DistrictID			= plot:GetDistrictID(),
		DistrictComplete	= false,
		DistrictPillaged	= false,
		DistrictType		= DistrictTypeMap[plot:GetDistrictType()],
		Fallout				= kFalloutManager:GetFalloutTurnsRemaining(plot:GetIndex());
		FeatureType			= FeatureTypeMap[plot:GetFeatureType()],
		FeatureAdded		= plot:HasFeatureBeenAdded();
		Impassable			= plot:IsImpassable();
		ImprovementType		= ImprovementTypeMap[plot:GetImprovementType()],
		ImprovementPillaged = plot:IsImprovementPillaged(),
		IsCity				= plot:IsCity(),
		IsLake				= plot:IsLake(),
		IsRiver				= plot:IsRiver(),
		IsMountain			= plot:IsMountain(),
		IsHill				= plot:IsHills(),
		IsRoute				= plot:IsRoute(),
		IsWater				= plot:IsWater(),
		NationalPark		= plot:IsNationalPark() and plot:GetNationalParkName() or nil,
		Owner				= (plot:GetOwner() ~= -1) and plot:GetOwner() or nil,
		OwnerCity			= Cities.GetPlotPurchaseCity(plot);
		ResourceCount		= plot:GetResourceCount(),
		ResourceType		= ResourceTypeMap[plot:GetResourceType()],
		RoutePillaged		= plot:IsRoutePillaged(),
		RouteType			= plot:GetRouteType(),
		TerrainType			= TerrainTypeMap[plot:GetTerrainType()],
		TerrainTypeName		= GameInfo.Terrains[TerrainTypeMap[plot:GetTerrainType()]].Name,
		WonderComplete		= false,
		WonderType			= BuildingTypeMap[plot:GetWonderType()],
		--IsCliff
	
		BuildingNames		= {},
		BuildingsPillaged	= {},
		BuildingTypes		= {},
		Constructions		= {},
		Yields				= {},
		DistrictYields		= {},
		--Buildings
		--GreatWorks
	};
end

-- ===========================================================================
--	Show the information for a given plot
-- ===========================================================================
function GetPlotInfo( plotId:number, pPlayerVis )

	local plot = Map.GetPlotByIndex(plotId);
	if (plot == nil) then
		return;
	end

	local new_data = FetchData(plot);

	-- TODO move the below stuff into FetchData
	if (new_data.OwnerCity) then
		new_data.OwningCityName = new_data.OwnerCity:GetName();

		local eDistrictType = plot:GetDistrictType();
		if (eDistrictType) then
			local cityDistricts = new_data.OwnerCity:GetDistricts();
			if (cityDistricts) then
				if (cityDistricts:IsPillaged(eDistrictType, plotId)) then
					new_data.DistrictPillaged = true;
				end
				if (cityDistricts:IsComplete(eDistrictType, plotId)) then
					new_data.DistrictComplete = true;
				end
			end
		end

		local cityBuildings = new_data.OwnerCity:GetBuildings();
		if (cityBuildings) then
			local buildingTypes = cityBuildings:GetBuildingsAtLocation(plotId);
			for _, type in ipairs(buildingTypes) do
				local building = GameInfo.Buildings[type];
				table.insert(new_data.BuildingTypes, type);
				local name = GameInfo.Buildings[building.BuildingType].Name;
				table.insert(new_data.BuildingNames, name);
				local bPillaged = cityBuildings:IsPillaged(type);
				table.insert(new_data.BuildingsPillaged, bPillaged);
			end
			if (cityBuildings:HasBuilding(plot:GetWonderType())) then
				new_data.WonderComplete = true;
			end
		end

		local cityBuildQueue = new_data.OwnerCity:GetBuildQueue();
		if (cityBuildQueue) then
			local constructionTypes = cityBuildQueue:GetConstructionsAtLocation(plotID);
			for _, type in ipairs(constructionTypes) do
				local construction = GameInfo.Buildings[type];
				local name = GameInfo.Buildings[construction.BuildingType].Name;
				table.insert(new_data.Constructions, name);
			end
		end
	end
	if (new_data.IsCity == true or new_data.DistrictID == -1) then
		for row in GameInfo.Yields() do
			local yield = plot:GetYield(row.Index);
			if (yield > 0) then
				new_data.Yields[row.YieldType] = yield;
			end
		end	
	else
		local plotOwner = plot:GetOwner();
		local plotPlayer = Players[plotOwner];
		local district = plotPlayer:GetDistricts():FindID(new_data.DistrictID);

		for row in GameInfo.Yields() do
			local yield = plot:GetYield(row.Index);
			local workers = plot:GetWorkerCount();
			if (yield > 0 and workers > 0) then
				yield = yield * workers;
				new_data.Yields[row.YieldType] = yield;
			end

			local districtYield = district:GetYield(row.Index);
			if (districtYield > 0) then
				new_data.DistrictYields[row.YieldType] = districtYield;
			end

		end									
	end

	return GetPlotSearchTerms(new_data);
end

-- ===========================================================================
-- ===========================================================================
function IncrementalSearch()
	
	local eObserverID = Game.GetLocalObserver();
	local pPlayerVis = PlayersVisibility[eObserverID];
	local nPlotsCheckedThisFrame = 0;
	
	-- Clear the previous frame's search data
	Search.ClearData(SEARCHCONTEXT_MAPSEARCH);

	local nPlots = Map.GetPlotCount();
	for iPlot = m_nLastPlotSearched + 1, nPlots - 1 do

		if pPlayerVis:IsRevealed(iPlot) then
			
			local szPlotString = tostring(iPlot);
			local pInfo = GetPlotInfo(iPlot);
			if (pInfo) then
				-- repopulate the search context
				Search.AddData(SEARCHCONTEXT_MAPSEARCH, szPlotString, "", "", pInfo);
				
			end

			nPlotsCheckedThisFrame = nPlotsCheckedThisFrame + 1;
			if (nPlotsCheckedThisFrame == PLOTS_CHECKED_PER_FRAME) then
				-- We will continue where we left off next frame
				CheckForMatches();
				Controls.ProgressBar:SetPercent(iPlot / (nPlots - 1));
				m_nLastPlotSearched = iPlot;
				return;
			end

		end
		
	end

	-- Check if the last few remaining plots were a match
	CheckForMatches();
	
	-- If we made it this far, we have searched the whole map :)

	-- Highlight the matching results
	local pOverlay:object = UILens.GetOverlay("MapSearch");
	if (pOverlay ~= nil) then
		pOverlay:ClearAll();
		pOverlay:SetPlotChannel(m_ResultPlots, 0);
	end

	-- Group adjacent results together so the next/previous buttons are more practical
	m_ResultGroups = { };
	local pGroups = UI.PartitionRegions( m_ResultPlots );
	for _,pGroup in pairs(pGroups) do
		local x, y = UI.GetRegionCenter(pGroup);
		table.insert(m_ResultGroups, { Plots=pGroup, CenterX=x, CenterY=y });
	end

	Controls.ProgressBar:SetPercent(1.0);
	Controls.ResultsLabel:SetText( Locale.Lookup("LOC_HUD_MAP_SEARCH_RESULTS", #m_ResultPlots) );

	local bDisableButtons = not (#m_ResultPlots > 0);
	Controls.NextResultButton:SetDisabled(bDisableButtons);
	Controls.PrevResultButton:SetDisabled(bDisableButtons);
	
	StopSearch();

	-- what was searched for and how long it took in MapSearch.log
	UI.MapSearch_LogEnd("Complete with " .. tostring(#m_ResultPlots) .. " results");
end

-- ===========================================================================
-- ===========================================================================
function PopulateSuggestionData()

	if not g_bSuggestionsInitialized then
		return;
	end

	local AddSearchTerm = function(kLocKey)
		if OmittedTermsMap[kLocKey] == nil then
			local szTerm = Locale.Lookup(kLocKey);
			Search.AddData(SEARCHCONTEXT_SUGGESTIONS, szTerm, szTerm, "");
		end
	end
		
	-- city states?
	-- fresh water access?
	-- active Owners/PlayerNames?
	-- active Continent Names?

	-- PLOT STATE
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_OWNED");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_UNCLAIMED");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_PILLAGED");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_CONTAMINATION");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_UNDER_CONSTRUCTION");

	-- TERRAIN
	AddSearchTerm("LOC_TOOLTIP_LAKE");
	AddSearchTerm("LOC_TOOLTIP_COAST");
	AddSearchTerm("LOC_TOOLTIP_RIVER");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_MOUNTAIN");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_HILL");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_WATER");
	for row in GameInfo.Terrains() do
		-- TODO filter out terrain types with parentheses as separate suggestions?
		if row.Name ~= "LOC_TERRAIN_COAST_NAME" then -- omit 'Coast and Lake'
			AddSearchTerm(row.Name);
		end
	end

	-- FEATURES
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_FEATURE");
	AddSearchTerm("LOC_NATURAL_WONDER_NAME");
	for row in GameInfo.Features() do
		AddSearchTerm(row.Name);
	end

	-- BUILDINGS + GREAT WORKS
	-- LOC_WONDER_NAME is added from GameInfo.Districts()
	AddSearchTerm("LOC_BUILDING_NAME");
	for row in GameInfo.Buildings() do
		AddSearchTerm(row.Name);
	end
	for _,term in pairs(GreatWorkTypeNameMap) do
		AddSearchTerm(term);
	end
		
	-- DISTRICTS
	AddSearchTerm("LOC_DISTRICT_NAME");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_SPECIALIST");
	for row in GameInfo.Districts() do
		AddSearchTerm(row.Name);
	end

	-- IMPROVEMENT
	AddSearchTerm("LOC_IMPROVEMENT_NAME");
	for row in GameInfo.Improvements() do
		AddSearchTerm(row.Name);
	end
		
	-- RESOURCES
	AddSearchTerm("LOC_RESOURCE_NAME");
	for row in GameInfo.Resources() do
		AddSearchTerm(row.Name);
	end
	for _,term in pairs(ResourceClassNameMap) do
		AddSearchTerm(term);
	end

	-- ROUTES
	AddSearchTerm("LOC_ROUTE_NAME");
	AddSearchTerm("LOC_TOOLTIP_PLOT_IMPASSABLE_TEXT");
	for row in GameInfo.Routes() do
		AddSearchTerm(row.Name);
	end
		
	-- YIELDS
	for row in GameInfo.Yields() do
		AddSearchTerm(row.Name);
	end

	-- APPEAL
	for row in GameInfo.AppealHousingChanges() do
		AddSearchTerm(row.Description);
	end

	-- NATIONAL PARK
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_NATIONAL_PARK");

	-- UNITS
	AddSearchTerm("LOC_UNIT_NAME");
	AddSearchTerm("LOC_UNITFLAG_ARMY_SUFFIX");
	AddSearchTerm("LOC_UNITFLAG_CORPS_SUFFIX");
	AddSearchTerm("LOC_UNITFLAG_ARMADA_SUFFIX");
	AddSearchTerm("LOC_UNITFLAG_FLEET_SUFFIX");
	AddSearchTerm("LOC_PROMOTION_CLASS_MELEE_NAME");
	AddSearchTerm("LOC_PROMOTION_CLASS_RANGED_NAME");
	AddSearchTerm("LOC_PROMOTION_CLASS_SIEGE_NAME");
	for row in GameInfo.Units() do
		AddSearchTerm(row.Name);
	end
	for _,term in pairs(FormationClassNameMap) do
		AddSearchTerm(term);
	end
end

-- ===========================================================================
-- ===========================================================================
function OnSuggestionClicked(pEditBox, szSuggestion)
	-- TODO append space delimited terms
	pEditBox:SetText(szSuggestion);
end

-- ===========================================================================
-- ===========================================================================
function UpdateSuggestions(pEditBox, pSuggestionPanel, pInstanceManager, pHistoryList)

	pInstanceManager:ResetInstances();
	local str = pEditBox:GetText();

	m_TabCompleteString = nil;

	-- If the user hasn't typed anything, show some default suggestions
	if str == nil or string.len(str) == 0 then
		for _,szSuggestion in pairs(pHistoryList) do
			if m_TabCompleteString == nil then
				m_TabCompleteString = szSuggestion;
			end

			local pInstance = pInstanceManager:GetInstance();
			pInstance.SuggestionButton:SetText(szSuggestion);
			
			pInstance.SuggestionButton:RegisterCallback(Mouse.eLClick, function()
				OnSuggestionClicked(pEditBox, pInstance.SuggestionButton:GetText());
			end); 
		end
		
		-- If there are any suggestions, make the suggestion panel visible
		if pEditBox:HasFocus() then
			pSuggestionPanel:SetHide(m_TabCompleteString == nil);
		end

		return;
	end

	if g_bSuggestionsInitialized then
		local results = Search.Search(SEARCHCONTEXT_SUGGESTIONS, str, 10);
		if (results and #results > 0) then
			for _,result in pairs(results) do

				-- Don't suggest the exact same string that is already there
				local szString1 = Locale.ToLower(result[1]);
				local szString2 = Locale.ToLower(str)
				if (g_bShowExactMatchSuggestions or szString1 ~= szString2) then
					if m_TabCompleteString == nil then
						m_TabCompleteString = result[1];
					end

					local pInstance = pInstanceManager:GetInstance();
					pInstance.SuggestionButton:SetText(result[1]);
			
					pInstance.SuggestionButton:RegisterCallback(Mouse.eLClick, function()
						OnSuggestionClicked(pEditBox, pInstance.SuggestionButton:GetText());
					end);
				end
			end
		end
	end
	
	-- If there are any suggestions, make the suggestion panel visible
	if pEditBox:HasFocus() then
		pSuggestionPanel:SetHide(m_TabCompleteString == nil);
	end
end

-- ===========================================================================
-- ===========================================================================
function UpdateEnabledButtons()
	local szSearchString = Controls.MapSearchBox:GetText();
	if szSearchString and string.len(szSearchString) > 0 then
		Controls.SearchButton:SetDisabled(false);
		Controls.SearchButton:SetToolTipString(nil);
	else
		Controls.SearchButton:SetDisabled(true);
		Controls.SearchButton:LocalizeAndSetToolTip("LOC_HUD_MAP_SEARCH_NO_SEARCH_TERMS_TOOLTIP");
	end
end

-- ===========================================================================
-- ===========================================================================
function OnEditBoxFocusGained()
	if Controls.MapSearchBox:HasFocus() then
		-- Update and show the search suggestions
		UpdateSuggestions(Controls.MapSearchBox, Controls.SearchSuggestions, m_SearchSuggestionIM, m_SearchHistory);
		Controls.SearchSuggestionsTimer:Stop();
		
		-- Reset and hide the filter suggestions
		Controls.FilterSuggestions:SetHide(true);
		m_FilterSuggestionIM:ResetInstances();

	elseif Controls.MapSearchFilterBox:HasFocus() then
		-- Update and show the filter suggestions
		UpdateSuggestions(Controls.MapSearchFilterBox, Controls.FilterSuggestions, m_FilterSuggestionIM, m_FilterHistory);
		Controls.SearchSuggestionsTimer:Stop();
		
		-- Reset and hide the search suggestions
		Controls.SearchSuggestions:SetHide(true);
		m_SearchSuggestionIM:ResetInstances();
	end
end

-- ===========================================================================
-- ===========================================================================
function OnEditBoxFocusLost()
	if not m_bIsShutdown then -- fixes hotload crash
		-- We may have lost focus by the user clicking on a suggestion, so we
		-- have to delay hiding the suggestions so it can get clicked on
		Controls.SearchSuggestionsTimer:SetToBeginning();
		Controls.SearchSuggestionsTimer:Play();
	end
end

-- ===========================================================================
-- ===========================================================================
function HideAllSuggestions()
	Controls.FilterSuggestions:SetHide(true);
	m_FilterSuggestionIM:ResetInstances();
	Controls.SearchSuggestions:SetHide(true);
	m_SearchSuggestionIM:ResetInstances();
end

-- ===========================================================================
-- ===========================================================================
function UpdateHistory(pHistoryTable, szNewString)
	-- Skip invalid strings
	if (szNewString == nil or string.len(szNewString) == 0) then
		return;
	end

	-- TODO add strings to the suggestion search context?

	-- Remove existing copies of the search string
	for i,szString in ipairs(pHistoryTable) do
		if szNewString == szString then
			table.remove(pHistoryTable, i);
		end
	end

	-- Insert the new string at the front of the list
	table.insert(pHistoryTable, 1, szNewString);

	-- Trim the history down to the maximum number of entries
	while table.count(pHistoryTable) > MAXIMUM_SEARCH_HISTORY do
		table.remove(pHistoryTable);
	end
end

-- ===========================================================================
-- ===========================================================================
function OnSearchCommit()

	ClearSearch(true);

	local szSearchString = Controls.MapSearchBox:GetText();
	local szFilterString = Controls.MapSearchFilterBox:GetText();

	m_Search.Whitelist = szSearchString and Locale.SplitString(szSearchString) or { };
	m_Search.Blacklist = szFilterString and Locale.SplitString(szFilterString) or { };
	Controls.MapSearchBox:DropFocus();
	Controls.MapSearchFilterBox:DropFocus();

	if ValidateSearchTerms() and g_bMapSearchInitialized then
		UpdateHistory(m_SearchHistory, szSearchString);
		UpdateHistory(m_FilterHistory, szFilterString);

		Controls.ProgressBar:SetPercent(0.0);
		Controls.ResultsLabel:SetText( Locale.Lookup("LOC_HUD_MAP_SEARCH_IN_PROGRESS") );
		UI.MapSearch_LogBegin(m_Search.Whitelist, m_Search.Blacklist);
		ContextPtr:SetUpdate(IncrementalSearch);

		local pOverlay:object = UILens.GetOverlay("MapSearch");
		if (pOverlay ~= nil) then
			pOverlay:SetVisible(true);
			pOverlay:ShowHighlights(true);
			pOverlay:SetBorderColors(0, COLOR_WHITE, COLOR_WHITE);
			pOverlay:SetHighlightColor(0, COLOR_GREEN);
		end
	end
end

-- ===========================================================================
-- ===========================================================================
function OnClearSearchButton()
	ClearSearch(true);
	Controls.MapSearchBox:ClearString();
	Controls.MapSearchFilterBox:ClearString();
	Controls.ResultsLabel:SetText("");
end

-- ===========================================================================
-- ===========================================================================
function OnNextResult()
	m_FocusedResult = m_FocusedResult + 1;
	if m_FocusedResult > #m_ResultGroups then
		m_FocusedResult = 1;
	end

	local pGroup = m_ResultGroups[m_FocusedResult];
	UI.LookAtPosition(pGroup.CenterX, pGroup.CenterY);
end

-- ===========================================================================
-- ===========================================================================
function OnPrevResult()
	m_FocusedResult = m_FocusedResult - 1;
	if m_FocusedResult <= 0 then
		m_FocusedResult = #m_ResultGroups;
	end
	
	local pGroup = m_ResultGroups[m_FocusedResult];
	UI.LookAtPosition(pGroup.CenterX, pGroup.CenterY);
end

-- ===========================================================================
-- ===========================================================================
function OnMapSearchPanelOpened()
	Controls.MapSearchBox:ClearString();
	Controls.MapSearchBox:TakeFocus();
	Controls.MapSearchFilterBox:ClearString();
end

-- ===========================================================================
-- ===========================================================================
function OnMapSearchPanelClosed()
	ClearSearch(true);
	Controls.ResultsLabel:SetText("");
end

-- ===========================================================================
-- ===========================================================================
function RefreshMapSearchResults()
	-- If we have valid search terms, try searching with them again
	if ValidateSearchTerms() and g_bMapSearchInitialized then
		print("REFRESHING MAP SEARCH RESULTS");
		
		ClearSearch(false);
		Controls.ProgressBar:SetPercent(0.0);
		Controls.ResultsLabel:SetText( Locale.Lookup("LOC_HUD_MAP_SEARCH_UPDATING") );
		UI.MapSearch_LogBegin(m_Search.Whitelist, m_Search.Blacklist);
		ContextPtr:SetUpdate(IncrementalSearch);
	end
end

-- ===========================================================================
-- ===========================================================================
function OnInputHandler( pInputStruct:table )

	if pInputStruct:GetKey() == Keys.VK_TAB and m_TabCompleteString ~= nil then
		if Controls.MapSearchBox:HasFocus() then
			Controls.MapSearchBox:SetText(m_TabCompleteString);
			return true;
		elseif Controls.MapSearchFilterBox:HasFocus() then
			Controls.MapSearchFilterBox:SetText(m_TabCompleteString);
			return true;
		end
	end
end

-- ===========================================================================
-- ===========================================================================
function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )
	if eNewMode == InterfaceModeTypes.CINEMATIC then
		UILens.HideOverlays("MapSearch");
	end
	if eOldMode == InterfaceModeTypes.CINEMATIC then
		UILens.ShowOverlays("MapSearch");
	end
end

-- ===========================================================================
-- ===========================================================================
function OnLocalPlayerChanged(eLocalPlayer:number , ePrevLocalPlayer:number)
	ClearSearch(true);
	Controls.MapSearchBox:ClearString();
	Controls.MapSearchFilterBox:ClearString();
	Controls.ResultsLabel:SetText("");
end

-- ===========================================================================
-- ===========================================================================
function OnPlayerTurnActivated(ePlayer, isFirstTimeThisTurn)
	if Game.GetLocalPlayer() == ePlayer then
		RefreshMapSearchResults();
	end
end

-- ===========================================================================
-- ===========================================================================
function OnEventPlaybackComplete()
	local eLocalPlayer = Game.GetLocalPlayer();
	if eLocalPlayer < 0 then
		-- Update search results for the observer
		RefreshMapSearchResults();
	elseif Players[eLocalPlayer]:IsTurnActive() then
		-- Update search results immediately
		RefreshMapSearchResults();
	else
		if ValidateSearchTerms() and g_bMapSearchInitialized then
			-- Wait until OnPlayerTurnActivated to update
			Controls.ResultsLabel:SetText( Locale.Lookup("LOC_HUD_MAP_SEARCH_WAITING_FOR_TURN") );
		end
	end
end

-- ===========================================================================
-- ===========================================================================
function LateInitialize()
	if (Search.CreateContext(SEARCHCONTEXT_MAPSEARCH, "", "", "...")) then
		g_bMapSearchInitialized = true;
		print("Created SearchContext '" .. SEARCHCONTEXT_MAPSEARCH .. "'");
	end
	
	if (Search.CreateContext(SEARCHCONTEXT_SUGGESTIONS, "", "", "...")) then
		g_bSuggestionsInitialized = true;
		PopulateSuggestionData();
		Search.Optimize(SEARCHCONTEXT_SUGGESTIONS);
		print("Created SearchContext '" .. SEARCHCONTEXT_SUGGESTIONS .. "'");
	end

	UI.AssertMsg(g_bMapSearchInitialized, "Failed to initialize search context: " .. SEARCHCONTEXT_MAPSEARCH);
	UI.AssertMsg(g_bSuggestionsInitialized, "Failed to initialize search context: " .. SEARCHCONTEXT_SUGGESTIONS);
end

-- ===========================================================================
-- ===========================================================================
function OnInit(bIsReload:boolean)
	if bIsReload then
		ClearSearch(true);
	end
	LateInitialize();
end

-- ===========================================================================
-- ===========================================================================
function OnShutdown()
	Search.DestroyContext(SEARCHCONTEXT_MAPSEARCH);
	Search.DestroyContext(SEARCHCONTEXT_SUGGESTIONS);

	g_bMapSearchInitialized   = false;
	g_bSuggestionsInitialized = false;
	
	LuaEvents.MapSearch_PanelOpened.Remove( OnMapSearchPanelOpened );
	LuaEvents.MapSearch_PanelClosed.Remove( OnMapSearchPanelClosed );
	
	Events.InterfaceModeChanged.Remove( OnInterfaceModeChanged );
	Events.LocalPlayerChanged.Remove( OnLocalPlayerChanged );
	Events.PlayerTurnActivated.Remove( OnPlayerTurnActivated);
	Events.GameCoreEventPlaybackComplete.Remove( OnEventPlaybackComplete );

	m_bIsShutdown = true;
end

-- ===========================================================================
-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );	
	Controls.MapSearchBox:RegisterCommitCallback( OnSearchCommit );
	Controls.MapSearchBox:RegisterStringChangedCallback( function() UpdateEnabledButtons(); UpdateSuggestions(Controls.MapSearchBox, Controls.SearchSuggestions, m_SearchSuggestionIM, m_SearchHistory); end );
	Controls.MapSearchBox:RegisterHasFocusCallback( OnEditBoxFocusGained );
	Controls.MapSearchBox:RegisterLostFocusCallback( OnEditBoxFocusLost );
	Controls.MapSearchFilterBox:RegisterCommitCallback( OnSearchCommit );
	Controls.MapSearchFilterBox:RegisterStringChangedCallback( function() UpdateSuggestions(Controls.MapSearchFilterBox, Controls.FilterSuggestions, m_FilterSuggestionIM, m_FilterHistory); end );
	Controls.MapSearchFilterBox:RegisterHasFocusCallback( OnEditBoxFocusGained );
	Controls.MapSearchFilterBox:RegisterLostFocusCallback( OnEditBoxFocusLost );
	Controls.NextResultButton:RegisterCallback( Mouse.eLClick, OnNextResult );
	Controls.PrevResultButton:RegisterCallback( Mouse.eLClick, OnPrevResult );
	Controls.ClearButton:RegisterCallback( Mouse.eLClick, OnClearSearchButton );
	Controls.SearchButton:RegisterCallback( Mouse.eLClick, OnSearchCommit );
	Controls.SearchSuggestionsTimer:RegisterEndCallback( HideAllSuggestions );

	LuaEvents.MapSearch_PanelOpened.Add( OnMapSearchPanelOpened );
	LuaEvents.MapSearch_PanelClosed.Add( OnMapSearchPanelClosed );
	
	-- TODO InputActions, InterfaceMode and LensLayers
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
	Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );
	Events.PlayerTurnActivated.Add( OnPlayerTurnActivated);
	Events.GameCoreEventPlaybackComplete.Add( OnEventPlaybackComplete );

	-- Initialize search history with some useful examples
	m_SearchHistory = { };
	table.insert(m_SearchHistory, Locale.Lookup("LOC_TOOLTIP_STRATEGIC_RESOURCE"));
	table.insert(m_SearchHistory, Locale.Lookup("LOC_TOOLTIP_LUXURY_RESOURCE"));
	table.insert(m_SearchHistory, Locale.Lookup("LOC_IMPROVEMENT_GOODY_HUT_NAME"));
	table.insert(m_SearchHistory, Locale.Lookup("LOC_RESOURCE_ANTIQUITY_SITE_NAME"));
	
	-- Initialize filter history with some useful examples
	m_FilterHistory = { };
	table.insert(m_FilterHistory, Locale.Lookup("LOC_IMPROVEMENT_NAME"));      -- search for something WITHOUT an improvement
	table.insert(m_FilterHistory, Locale.Lookup("LOC_BUILDING_LIBRARY_NAME")); -- search for something WITHOUT a library

	UpdateEnabledButtons();
end
Initialize();
