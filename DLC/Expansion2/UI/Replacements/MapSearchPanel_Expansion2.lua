-- Copyright 2019, Firaxis Games

include("MapSearchPanel");


-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_FetchData = FetchData;
BASE_GetPlotSearchTerms = GetPlotSearchTerms;
BASE_PopulateSuggestionData = PopulateSuggestionData;

-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function GetPlotSearchTerms(data)
	-- Get the original search terms
	local pSearchTerms = BASE_GetPlotSearchTerms(data);
	local AddLocalizedSearchTerm = function(kLocKey)
		-- TODO try caching localized strings
		table.insert( pSearchTerms, Locale.Lookup(kLocKey) );
	end

	if (data.IsVolcano == true) then
		-- Generic 'Volcano' term already added in BASE_GetPlotSearchTerms
		if (data.Erupting) then
			AddLocalizedSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_ERUPTING");
		end
		if (data.Active) then
			AddLocalizedSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_ACTIVE");
		end
		AddLocalizedSearchTerm(data.VolcanoName);
	end

	if (data.IsRiver and table.count(data.RiverNames) > 0) then
		-- Generic 'River' term already added in BASE_GetPlotSearchTerms
		for _,szRiverName in pairs(data.RiverNames) do
			AddLocalizedSearchTerm(szRiverName);
		end
	end

	if (data.TerritoryName ~= nil) then
		AddLocalizedSearchTerm(data.TerritoryName);
	end

	local pEvents = GameInfo.RandomEvents;
	if (data.Storm ~= -1) then
		AddLocalizedSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_STORM");
		AddLocalizedSearchTerm(GameInfo.RandomEvents[data.Storm].Name);
	end

	if (data.Drought ~= -1) then
		AddLocalizedSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_DROUGHT");
		AddLocalizedSearchTerm(GameInfo.RandomEvents[data.Drought].Name);
	end

	if (data.CoastalLowland ~= -1) then
		AddLocalizedSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_COASTAL_LOWLAND");
		if (data.CoastalLowland == 0) then
			AddLocalizedSearchTerm("LOC_COASTAL_LOWLAND_1M_NAME");
		elseif (data.CoastalLowland == 1) then
			AddLocalizedSearchTerm("LOC_COASTAL_LOWLAND_2M_NAME");
		elseif (data.CoastalLowland == 2) then
			AddLocalizedSearchTerm("LOC_COASTAL_LOWLAND_3M_NAME");
		end
		if (data.Submerged) then
			AddLocalizedSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_SUBMERGED");
		end
		if (data.Flooded) then
			AddLocalizedSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_FLOODED");
		end
	end

	return pSearchTerms;
end

-- ===========================================================================
function FetchData(plot)
	-- Get the original plot data
	local data = BASE_FetchData(plot);
	
	data.IsVolcano      = MapFeatureManager.IsVolcano(plot);
	data.VolcanoName    = MapFeatureManager.GetVolcanoName(plot);
	data.Active         = MapFeatureManager.IsActiveVolcano(plot);
	data.Erupting       = MapFeatureManager.IsVolcanoErupting(plot);
	data.Storm          = GameClimate.GetActiveStormTypeAtPlot(plot);
	data.Drought        = GameClimate.GetActiveDroughtTypeAtPlot(plot);
	data.DroughtTurns   = GameClimate.GetDroughtTurnsAtPlot(plot);
	data.CoastalLowland = TerrainManager.GetCoastalLowlandType(plot);
	data.Flooded        = false;
	data.Submerged      = false;
	data.TerritoryName  = nil;
	data.RiverNames	    = { };
	
	local kRivers = RiverManager.GetRiverTypes(plot);
	if kRivers and table.count(kRivers) > 0 then
		for _,eRiver in pairs(kRivers) do
			local szRiverName = RiverManager.GetRiverNameByType(eRiver);
			table.insert(data.RiverNames, szRiverName);
		end
	end

	local kTerritory = Territories.GetTerritoryAt(plot:GetIndex());
	if kTerritory ~= nil then
		data.TerritoryName = kTerritory:GetName();
	end

	if data.CoastalLowland ~= -1 then
		data.Flooded   = TerrainManager.IsFlooded(plot);
		data.Submerged = TerrainManager.IsSubmerged(plot);
	end

	return data;
end

-- ===========================================================================
function PopulateSuggestionData()

	if not g_bSuggestionsInitialized then
		return;
	end

	-- Populate the original search terms
	BASE_PopulateSuggestionData();
	local AddSearchTerm = function(kLocKey)
		local szTerm = Locale.Lookup(kLocKey);
		Search.AddData(SEARCHCONTEXT_SUGGESTIONS, szTerm, szTerm, "");
	end

	for row in GameInfo.RandomEvents() do
		-- It would be nice to have generic storm types as well, e.g. 'Blizzard'
		if row.EffectOperatorType == "STORM" or row.EffectOperatorType == "DROUGHT" then
			AddSearchTerm(row.Name);
		end
	end

	-- XP2 Features, Improvements, etc are already added in BASE_PopulateSuggestionData
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_ERUPTING");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_ACTIVE");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_STORM");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_DROUGHT");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_COASTAL_LOWLAND");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_SUBMERGED");
	AddSearchTerm("LOC_HUD_MAP_SEARCH_TERMS_FLOODED");
end
