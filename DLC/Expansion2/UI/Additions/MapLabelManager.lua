-- ===========================================================================
--	Map Label Manager
--	Controls all the perspective-rendered labels on the map
-- ===========================================================================
include( "InstanceManager" );
include( "SupportFunctions" );
include( "Civ6Common" );

-- ===========================================================================
local HEX_WIDTH         = 64.0;
local POI_OFFSET_Y      = -1 * HEX_WIDTH / 6; -- bottom third
local RELIGION_OFFSET_Y = -1 * HEX_WIDTH / 2;

local CLASS_MOUNTAIN = GameInfo.TerrainClasses["TERRAIN_CLASS_MOUNTAIN"].Index;
local CLASS_DESERT   = GameInfo.TerrainClasses["TERRAIN_CLASS_DESERT"].Index;
local CLASS_WATER    = GameInfo.TerrainClasses["TERRAIN_CLASS_WATER"].Index;

local NATURAL_WONDER_LAYER_HASH = UILens.CreateLensLayerHash("MapLabels_NaturalWonders");
local NATIONAL_PARK_LAYER_HASH  = UILens.CreateLensLayerHash("MapLabels_NationalParks");
local RELIGION_LAYER_HASH       = UILens.CreateLensLayerHash("Hex_Coloring_Religion");

local ColorSet_Main = {
	PrimaryColor   = UI.GetColorValue("COLOR_MAP_LABEL_FILL");
	SecondaryColor = UI.GetColorValue("COLOR_MAP_LABEL_STROKE");
}

local ColorSet_FOW = {
	PrimaryColor   = UI.GetColorValue("COLOR_MAP_LABEL_FILL_FOW");
	SecondaryColor = UI.GetColorValue("COLOR_MAP_LABEL_STROKE_FOW");
}

-- ===========================================================================
local m_TerritoryCache  = { };

local m_LabelManagerMap = { };

local m_TerritoryTracker = { };
local m_RiverTracker     = { };
local m_WonderTracker    = { };

local m_bUpdateNaturalWonderLabels : boolean = false;
local m_bUpdateNationalParkLabels : boolean = false;

local FontParams_MajorRegion = {
	FontSize       = 24.0,
	Kerning        = 4.0,
	WrapMode       = "Wrap",
	TargetWidth    = 3 * HEX_WIDTH,
	Alignment      = "Center",
	ColorSet       = ColorSet_Main,
	FOWColorSet    = ColorSet_Main, -- Major Regions don't use the FOW color
	FontStyle      = "Stroke",
	-- Centered on single, center-most hex
	-- Word wrap at 4 hexes
	-- Vertically centered on hex
	-- If possible, display text label on center of "largest" region of hexes
};

local FontParams_Religion = {
	FontSize       = 18.0,
	Kerning        = 4.0,
	WrapMode       = "Wrap",
	TargetWidth    = 3 * HEX_WIDTH,
	Alignment      = "Center",
	ColorSet       = ColorSet_Main,
	FOWColorSet    = ColorSet_Main, -- Religions don't use the FOW color
	FontStyle      = "Stroke",
	-- Centered on single, center-most hex
	-- Word wrap at 4 hexes
	-- Vertically centered on hex
	-- If possible, display text label on center of "largest" region of hexes
};

-- Same behavior as Major Regions, with smaller text
local FontParams_MinorRegion = {
	FontSize       = 12.0,
	Leading        = 12.0,
	Kerning        = 5.33,
	WrapMode       = "Wrap",
	TargetWidth    = 2 * HEX_WIDTH,
	Alignment      = "Center",
	ColorSet       = ColorSet_Main,
	FOWColorSet    = ColorSet_FOW,
	FontStyle      = "Stroke",
	-- Same behavior as Major Regions, with smaller text
};

local FontParams_River = {
	FontSize       = 12.0,
	Kerning        = 4.0,
	WrapMode       = "Truncate",
	Alignment      = "Center",
	ColorSet       = ColorSet_Main,
	FOWColorSet    = ColorSet_FOW,
	FontStyle      = "Stroke",
	-- Text bent for easy differentiation from adjacent feature labels
    -- Use up bend style if river arcs up. If not possible, choice of whether to use up or down bend can be random.
    -- Vertically centered within middle 1/2 of a hex
    -- Truncate Text (with...)  at 4 hexes wide
    -- Full name visible in tooltip (won't occur with current river names)
	-- Omit "River" from name at this time
	-- Minion Semibold Italic
	-- Same text size as unbent "Region Minor" styles
};

local FontParams_PointOfInterest = {
	FontSize       = 7.0,
	Leading        = 7.0,
	Kerning        = 5.0,
	WrapMode       = "Wrap",
	TargetWidth    = HEX_WIDTH,
	Alignment      = "Center",
	ColorSet       = ColorSet_Main,
	FOWColorSet    = ColorSet_FOW,
	FontStyle      = "Stroke",
--  Centered on single, center-most hex
--  Vertically centered within bottom 1/2 of a hex (aligns center on word wrap)
--  Word wrap two hexes wide
--  Myriad semibold
};

--TODO:
--Set up permission masks in artdef
--Default certain layers on
--Implement following layers:
--  Mountain Ranges
--  Rivers (curved)
--  Deserts

--  Government Names
--  Empire Names
--  City Names

-- ===========================================================================
function CreateLabelManager(szLensLayer, szOverlayName, pRebuildFunction, pUpdateFunction, szFontStyle)
	local pOverlayInstance = UILens.GetOverlay(szOverlayName);
	if (pOverlayInstance ~= nil) then
		local szFontFamily = UIManager:GetFontFamilyFromStyle(szFontStyle);
		pOverlayInstance:SetFontFamily(szFontFamily);
	end

	local pManager = {
		m_szOverlayName   = szOverlayName;
		m_szFontStyle     = szFontStyle;
		m_OverlayInstance = pOverlayInstance;
		m_RebuildFunction = pRebuildFunction;
		m_UpdateFunction  = pUpdateFunction;
	};

	local nLayerHash = UILens.CreateLensLayerHash(szLensLayer);
	m_LabelManagerMap[nLayerHash] = pManager;
	return pManager;
end

-- ===========================================================================
-- TODO make an exposure to get all natural wonders instead of this function
local m_NaturalWonderPlots = { };
function FindNaturalWonders()
	m_NaturalWonderPlots = { }
	local nPlots = Map.GetPlotCount();
	for i = 0,nPlots-1 do
		local pPlot = Map.GetPlotByIndex(i);
		if (pPlot ~= nil and pPlot:IsNaturalWonder()) then
			local pFeature = pPlot:GetFeature();
			local pFeaturePlots = pFeature:GetPlots();
			m_NaturalWonderPlots[pFeaturePlots[1]] = pFeature;
		end
	end
end

-- ===========================================================================
function AddTerritoryLabel(pOverlay, pTerritory)
	local eTerritory = pTerritory:GetID();
	if m_TerritoryTracker[eTerritory] == nil then
		local pInstance = m_TerritoryCache[eTerritory];
		if pInstance == nil then
			-- ERROR?
			return;
		end
	
		local pName = pTerritory:GetName();
		if (pName == nil) then
			return;
		end

		m_TerritoryTracker[eTerritory] = true;
		local szName = Locale.ToUpper(Locale.Lookup(pName));
		
		-- Special case for large bodies of water
		if pTerritory:GetTerrainClass() == CLASS_WATER then
			if (#pInstance.pPlots > 100) then
				-- try to have approximately one label per 100 hexes
				local pPositions = UI.GetRegionClusterPositions( pInstance.pPlots, 100, 100 );
				if pPositions then
					for _,pos in pairs(pPositions) do
						print(szName .. " (" .. pos.x .. ", " .. pos.y .. ")");
						pOverlay:CreateTextAtPos(szName, pos.x, pos.y, FontParams_MinorRegion);
					end

					-- we broke it up into multiple labels, return
					-- otherwise we will fall back to generating a single label at the center
					return;
				end
			end
		end

		local x, y = UI.GetRegionCenter(pInstance.pPlots);
		pOverlay:CreateTextAtPos(szName, x, y, FontParams_MinorRegion);
	end
end

-- ===========================================================================
function UpdateTerritory(pOverlay, iPlotIndex, pTerritorySelector)
	local pTerritory = Territories.GetTerritoryAt(iPlotIndex);
	if pTerritory and pTerritorySelector(pTerritory) then
		AddTerritoryLabel(pOverlay, pTerritory);
	end
end

-- ===========================================================================
function RefreshTerritories(pOverlay, pTerritorySelector)
	pOverlay:ClearAll();
	m_TerritoryTracker = { };
	for eTerritory,pInstance in pairs(m_TerritoryCache) do
		local pTerritory = Territories.GetTerritory(eTerritory);
		if pTerritory and pTerritorySelector(pTerritory) then
			AddTerritoryLabel(pOverlay, pTerritory);
		end
	end
end

-- ===========================================================================
function RefreshNationalParks(pOverlay)
	local eLocalPlayer = Game.GetLocalPlayer(); 
	if eLocalPlayer == -1 then
		return;
	end

	local pLocalPlayerVis = PlayersVisibility[eLocalPlayer];
	local pNationalParks = Game.GetNationalParks():EnumerateNationalParks();

	pOverlay:ClearAll();
	for _,pNationalPark in pairs(pNationalParks) do
		if pLocalPlayerVis:IsRevealed(pNationalPark.Plots[1]) then
			local szName = Locale.ToUpper(pNationalPark.Name);
			local x, y = UI.GetRegionCenter(pNationalPark.Plots);
			pOverlay:CreateTextAtPos(szName, x, y + POI_OFFSET_Y, FontParams_PointOfInterest);
		end
	end
end

-- ===========================================================================
function UpdateNationalParks(pOverlay, iPlotIndex)
	if Game.GetNationalParks():IsNationalPark(iPlotIndex) then
		RefreshNationalParks(pOverlay);
	end
end

-- ===========================================================================
function AddNaturalWonderLabel(pOverlay, pFeature)
	local pFeaturePlots = pFeature:GetPlots();
	local eFeature = pFeature:GetType();
	--local szName = Definitions.GetTypeName(DefinitionTypes.FEATURE, eFeature);
	local info:table = GameInfo.Features[eFeature];
	local szName = Locale.ToUpper(Locale.Lookup(info.Name));
	
	-- hide natural wonder labels if there is a national park label visible at the same location
	-- the national park will be named after the natural wonder it was placed on, so it is redundant
	if UILens.IsLayerOn(NATIONAL_PARK_LAYER_HASH) then
		for _,iPlotIndex in pairs(pFeaturePlots) do
			if Game.GetNationalParks():IsNationalPark(iPlotIndex) then
				print("Omitting feature label: " .. szName);
				return;
			end
		end
	end

	if (m_WonderTracker[eFeature] == nil) then
		m_WonderTracker[eFeature] = true;
		local x, y = UI.GetRegionCenter(pFeaturePlots);
		pOverlay:CreateTextAtPos(szName, x, y + POI_OFFSET_Y, FontParams_PointOfInterest);
	end
end

-- ===========================================================================
function RefreshNaturalWonders(pOverlay)
	pOverlay:ClearAll();
	m_WonderTracker = { };
	for _,pFeature in pairs(m_NaturalWonderPlots) do
		AddNaturalWonderLabel(pOverlay, pFeature);
	end
end

-- ===========================================================================
function UpdateNaturalWonders(pOverlay, iPlotIndex)
	local pPlot = Map.GetPlotByIndex(iPlotIndex);
	if (pPlot ~= nil and pPlot:IsNaturalWonder()) then
		local pFeature = pPlot:GetFeature();
		AddNaturalWonderLabel(pOverlay, pFeature);
	end
end

-- ===========================================================================
function AddRiverLabel(pOverlay, pRiver)
	if m_RiverTracker[pRiver.TypeID] == nil then
		m_RiverTracker[pRiver.TypeID] = true;

		-- approximately one label every 15 edges
		-- 5 edge long labels, with about 10 edges between them, 5+10 = 15
		-- only label rivers with at least 3 edges
		local fLength = pOverlay:GetTextLength(pRiver.Name, FontParams_River);
		local pSegments = UI.CalculateEdgeSplineSegments(pRiver.Edges, 5, 10, 3, fLength);
		if pSegments ~= nil then
			for _,pSegment in pairs(pSegments) do
				pOverlay:CreateTextArc(pRiver.Name, pSegment, FontParams_River);
			end
		end
	end
end

-- ===========================================================================
function RefreshRivers(pOverlay)
	local eLocalPlayer = Game.GetLocalPlayer();
	if eLocalPlayer == -1 then
		return;
	end

	local pLocalPlayerVis = PlayersVisibility[eLocalPlayer];
	local pRivers = RiverManager.EnumerateRivers();
	
	pOverlay:ClearAll();
	m_RiverTracker = { };
	for _,pRiver in pairs(pRivers) do
		AddRiverLabel(pOverlay, pRiver);
	end
end

-- ===========================================================================
function UpdateRivers(pOverlay, iPlotIndex)
	local eLocalPlayer = Game.GetLocalPlayer();
	if eLocalPlayer == -1 then
		return;
	end

	local pRivers = RiverManager.EnumerateRivers(iPlotIndex);
	if pRivers then
		for _,pRiver in pairs(pRivers) do
			AddRiverLabel(pOverlay, pRiver);
		end
	end
end

-- ===========================================================================
function RefreshVolcanoes(pOverlay)
	local eLocalPlayer = Game.GetLocalPlayer(); 
	if eLocalPlayer == -1 then
		return;
	end

	local pLocalPlayerVis = PlayersVisibility[eLocalPlayer];
	local pVolcanoes = MapFeatureManager.GetNamedVolcanoes();
	
	pOverlay:ClearAll();
	for _,pVolcano in pairs(pVolcanoes) do
		if pLocalPlayerVis:IsRevealed(pVolcano.PlotX, pVolcano.PlotY) then
			-- TODO how to handle volcano wonders? what if volcanoes are turned on and wonders are off?
			local szName = Locale.ToUpper(pVolcano.Name);
			local x, y = UI.GridToWorld(pVolcano.PlotX, pVolcano.PlotY);
			pOverlay:CreateTextAtPos(szName, x, y + POI_OFFSET_Y, FontParams_PointOfInterest);
		end
	end
end

-- ===========================================================================
function UpdateVolcanoes(pOverlay, iPlotIndex)
	if MapFeatureManager.IsVolcano(iPlotIndex) then
		RefreshVolcanoes(pOverlay);
	end
end

-- ===========================================================================
function RefreshContinents(pOverlay)
	
	pOverlay:ClearAll();
	local pContinents = Map.GetContinentsInUse();

	for _,iContinent in ipairs(pContinents) do
	
		local pPlots = Map.GetContinentPlots(iContinent);
		local szName = Locale.Lookup( GameInfo.Continents[iContinent].Description );

		local pGroups = UI.PartitionRegions( pPlots );
		for _,pGroup in pairs(pGroups) do
			-- try to have approximately one label per 60 hexes
			-- dont label a region that has less than 8 hexes total
			local pPositions = UI.GetRegionClusterPositions( pGroup, 60, 8 );
			if pPositions then
				for _,pos in pairs(pPositions) do
					local szNameUpper = Locale.ToUpper(szName);
					pOverlay:CreateTextAtPos(szNameUpper, pos.x, pos.y, FontParams_MajorRegion);
				end
			end
		end

	end
end

-- ===========================================================================
function RefreshReligions(pOverlay)
	local eLocalPlayer = Game.GetLocalPlayer(); 
	if eLocalPlayer == -1 then
		return;
	end

	local pLocalPlayerVis = PlayersVisibility[eLocalPlayer];
	if (pLocalPlayerVis == nil) then
		return;
	end
	
	pOverlay:ClearAll();
	local players = Game.GetPlayers();
	for _,pPlayer in ipairs(players) do
		local cities = pPlayer:GetCities();
		for _,pCity in cities:Members() do
			
			local iCityX = pCity:GetX();
			local iCityY = pCity:GetY();
		--	if pLocalPlayerVis:IsRevealed(iCityX, iCityY) then
			
				local pCityReligion = pCity:GetReligion();
				local eMajorityReligion = pCityReligion:GetMajorityReligion();

				if (eMajorityReligion >= 0) then
					local x, y = UI.GridToWorld(iCityX, iCityY);
					local szName = Game.GetReligion():GetName(eMajorityReligion);
					local szLocalizedName = Locale.Lookup( szName );
					pOverlay:CreateTextAtPos(szLocalizedName, x, y + RELIGION_OFFSET_Y, FontParams_Religion);
				end
		--	end
		end
	end

end

-- ===========================================================================
function UpdateVisibleNaturalWonderLabels()
	local pManager = m_LabelManagerMap[NATURAL_WONDER_LAYER_HASH];
	if pManager.m_RebuildFunction and pManager.m_OverlayInstance then
		pManager.m_RebuildFunction(pManager.m_OverlayInstance);
	end
end

-- ===========================================================================
function Refresh()
	for nLayerHash,pManager in pairs(m_LabelManagerMap) do
		pManager.m_OverlayInstance = UILens.GetOverlay(pManager.m_szOverlayName);
		
		if pManager.m_OverlayInstance and pManager.m_szFontStyle then
			local szFontFamily = UIManager:GetFontFamilyFromStyle(pManager.m_szFontStyle);
			pManager.m_OverlayInstance:SetFontFamily(szFontFamily);
		end

		if pManager.m_RebuildFunction and pManager.m_OverlayInstance then
			pManager.m_RebuildFunction(pManager.m_OverlayInstance);
		end
		
		if pManager.m_OverlayInstance then
			local bLayerOn = UILens.IsLayerOn(nLayerHash);
			pManager.m_OverlayInstance:SetVisible(bLayerOn);
		end
	end
end

-- ===========================================================================
function OnLensLayerOn( layerHash:number )
	local pManager = m_LabelManagerMap[layerHash];
	if pManager and pManager.m_OverlayInstance then
		pManager.m_OverlayInstance:SetVisible(true);
	end

	-- If national park labels are shown, we may need to hide some natural wonder labels
	if layerHash == NATIONAL_PARK_LAYER_HASH then
		UpdateVisibleNaturalWonderLabels();
	end
end

-- ===========================================================================
function OnLensLayerOff( layerHash:number )
	local pManager = m_LabelManagerMap[layerHash];
	if pManager and pManager.m_OverlayInstance then
		pManager.m_OverlayInstance:SetVisible(false);
	end
	
	-- If national park labels are hidden, we may need to show some natural wonder labels
	if layerHash == NATIONAL_PARK_LAYER_HASH then
		UpdateVisibleNaturalWonderLabels();
	end
end

-- ===========================================================================
function RefreshTerritoryCache()
	m_TerritoryCache = { }

	local nPlots = Map.GetPlotCount();
	for iPlot = 0,nPlots-1 do
		local pTerritory = Territories.GetTerritoryAt(iPlot);
		if pTerritory then
			local eTerritory = pTerritory:GetID();
			if m_TerritoryCache[eTerritory] then
				-- Add a new plot
				table.insert(m_TerritoryCache[eTerritory].pPlots, iPlot);
			else
				-- Instantiate a new territory
				m_TerritoryCache[eTerritory] = { pPlots = { iPlot } };
			end
		end
	end
end

-- ===========================================================================
function OnPlotVisibilityChanged( x, y, visibilityType )
	if (visibilityType ~= RevealedState.HIDDEN) then
		local iPlot:number = Map.GetPlotIndex(x, y);
		for nLayerHash,pManager in pairs(m_LabelManagerMap) do
			if pManager.m_UpdateFunction and pManager.m_OverlayInstance then
				pManager.m_UpdateFunction(pManager.m_OverlayInstance, iPlot);
			end
		end
	end
end

-- ===========================================================================
function OnNationalParksChanged()
	m_bUpdateNationalParkLabels = true;
end

-- ===========================================================================
function OnCityReligionChanged(playerID: number, cityID : number, eNewReligion : number)
	-- TODO track labels that changed
	local pManager = m_LabelManagerMap[RELIGION_LAYER_HASH];
	if pManager.m_RebuildFunction and pManager.m_OverlayInstance then
		pManager.m_RebuildFunction(pManager.m_OverlayInstance);
	end
end

-- ===========================================================================
function OnFeatureAddedToMap(x: number, y : number)

	local pPlot = Map.GetPlot(x, y);
	if (pPlot ~= nil and pPlot:IsNaturalWonder()) then
		local pFeature = pPlot:GetFeature();
		local pFeaturePlots = pFeature:GetPlots();
		m_NaturalWonderPlots[pFeaturePlots[1]] = pFeature;
		m_bUpdateNaturalWonderLabels = true;
	end
end

-- ===========================================================================
function OnFeatureRemovedFromMap(x: number, y : number)

	local iPlot:number = Map.GetPlotIndex(x, y);
	-- Was that plot in the Natural Wonder Plots list?
	if m_NaturalWonderPlots[iPlot] ~= nil then
		-- Remove it and rebuild
		m_NaturalWonderPlots[iPlot] = nil;
		m_bUpdateNaturalWonderLabels = true;
	end
end

-- ===========================================================================
-- Handle expensive updates when all events are complete.  Prevents redundant updates.
function OnEventPlaybackComplete()
	if m_bUpdateNationalParkLabels == true then
		m_bUpdateNationalParkLabels = false
		local pManager = m_LabelManagerMap[NATIONAL_PARK_LAYER_HASH];
		if pManager.m_RebuildFunction and pManager.m_OverlayInstance then
			pManager.m_RebuildFunction(pManager.m_OverlayInstance);
		end
		-- Need to update the NW labels because they can overlap
		m_bUpdateNaturalWonderLabels = true;
	end
	
	m_bUpdateNaturalWonderLabels = true;

	if m_bUpdateNaturalWonderLabels == true then
		m_bUpdateNaturalWonderLabels = false;
		UpdateVisibleNaturalWonderLabels();
	end		
end
-- ===========================================================================
function OnInit(isHotload : boolean)
	-- If hotloading, rebuild from scratch.
	if isHotload then
		Refresh();
	end
end

-- ===========================================================================
function OnShutdown()
	for _,pManager in pairs(m_LabelManagerMap) do
		if pManager.m_OverlayInstance then
			pManager.m_OverlayInstance:ClearAll();
		end
	end
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	
	CreateLabelManager( "MapLabels_NationalParks",  "MapLabelOverlay_NationalParks",  RefreshNationalParks,  nil,                  "FontNormal18"      ); -- Myriad Semibold
	CreateLabelManager( "MapLabels_NaturalWonders", "MapLabelOverlay_NaturalWonders", RefreshNaturalWonders, UpdateNaturalWonders, "FontNormal18"      ); -- Myriad Semibold
	CreateLabelManager( "MapLabels_Rivers",         "MapLabelOverlay_Rivers",         RefreshRivers,         UpdateRivers,         "FontItalicFlair18" ); -- Minion Italicized
	CreateLabelManager( "MapLabels_Volcanoes",      "MapLabelOverlay_Volcanoes",      RefreshVolcanoes,      UpdateVolcanoes,      "FontNormal18"      ); -- Myriad Semibold

	do
		local CreateTerritoryLabelManager = function(szLensLayer, szOverlayName, pTerritorySelector, szFontStyle)
			local pUpdateFunction = function(pOverlay, iPlotIndex) UpdateTerritory(pOverlay, iPlotIndex, pTerritorySelector); end
			local pRebuildFunction = function(pOverlay) RefreshTerritories(pOverlay, pTerritorySelector); end
			return CreateLabelManager(szLensLayer, szOverlayName, pRebuildFunction, pUpdateFunction, szFontStyle)
		end

		local IsDesert = function(pTerritory) return (pTerritory:GetTerrainClass() == CLASS_DESERT); end
		local IsMountainRange = function(pTerritory) return (pTerritory:GetTerrainClass() == CLASS_MOUNTAIN) end
		local IsLake = function(pTerritory) return (pTerritory:GetTerrainClass() == CLASS_WATER) and pTerritory:IsLake(); end
		local IsOcean = function(pTerritory) return (pTerritory:GetTerrainClass() == CLASS_WATER) and not (pTerritory:IsLake() or pTerritory:IsSea()); end
		local IsSea = function(pTerritory) return (pTerritory:GetTerrainClass() == CLASS_WATER) and pTerritory:IsSea(); end

		CreateTerritoryLabelManager( "MapLabels_Deserts",        "MapLabelOverlay_Deserts",        IsDesert,        "FontFlair16"       ); -- Minion Semibold
		CreateTerritoryLabelManager( "MapLabels_MountainRanges", "MapLabelOverlay_MountainRanges", IsMountainRange, "FontFlair16"       ); -- Minion Semibold
		CreateTerritoryLabelManager( "MapLabels_Lakes",          "MapLabelOverlay_Lakes",          IsLake,          "FontItalicFlair18" ); -- Minion Italicized
		CreateTerritoryLabelManager( "MapLabels_Oceans",         "MapLabelOverlay_Oceans",         IsOcean,         "FontItalicFlair18" ); -- Minion Italicized
		CreateTerritoryLabelManager( "MapLabels_Seas",           "MapLabelOverlay_Seas",           IsSea,           "FontItalicFlair18" ); -- Minion Italicized
	end

	CreateLabelManager( "Hex_Coloring_Continent",   "MapLabelOverlay_Continents",     RefreshContinents,     nil,                  "FontNormal18"      ); -- Myriad Semibold
	CreateLabelManager( "Hex_Coloring_Religion",    "MapLabelOverlay_Religions",      RefreshReligions,      nil,                  "FontNormal18"      ); -- Myriad Semibold

	Events.OverlaySystemInitialized.Add( Refresh );
	Events.LensLayerOn.Add( OnLensLayerOn );
	Events.LensLayerOff.Add( OnLensLayerOff );
	Events.PlotVisibilityChanged.Add( OnPlotVisibilityChanged );
	Events.NationalParkAdded.Add( OnNationalParksChanged );
	Events.NationalParkRemoved.Add( OnNationalParksChanged );
	Events.CityReligionChanged.Add( OnCityReligionChanged );
	Events.FeatureAddedToMap.Add( OnFeatureAddedToMap );
	Events.FeatureRemovedFromMap.Add( OnFeatureRemovedFromMap );

	Events.GameCoreEventPlaybackComplete.Add(OnEventPlaybackComplete);

	--TODO subscribe to other gameplay events that change which labels are visible
	--feature naming, player changing, etc

	FindNaturalWonders();
	RefreshTerritoryCache();
	Refresh();
end
Initialize();
