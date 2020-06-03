--	World Builder Placement
--	Copyright 2018-2019, Firaxis Games
-- ===========================================================================

include( "WorldBuilderResourceGen" );
include( "InstanceManager" );
include( "Civ6Common" );

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID= "WorldBuilderPlacement";
local NO_RESOURCE	 = -1;						-- Resource Regen variables

local DISTRICT_VALUE_PILLAGED = "Pillaged";

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_MouseOverPlot = nil;
local m_Mode = nil;
local m_TabButtons             : table = {};
local m_TerrainTypeEntries     : table = {};
local m_FeatureTypeEntries     : table = {};
local m_WonderTypeEntries     : table = {};
local m_ContinentTypeEntries   : table = {};
local m_ResourceTypeEntries    : table = {};
local m_ImprovementTypeEntries : table = {};
local m_RouteTypeEntries       : table = {};
local m_DistrictTypeEntries    : table = {};
local m_BuildingTypeEntries    : table = {};
local m_PlayerEntries          : table = {};
local m_ScenarioPlayerEntries  : table = {}; -- Scenario players are players that don't have a random civ and can therefore have cities and units
local m_CityEntries            : table = {};
local m_UnitTypeEntries        : table = {};
local m_GoodyHutTypeEntries	   : table = {};
local m_CivicEntries       	   : table = {};
local m_TechEntries        	   : table = {};
local m_InstanceList       	   : table = {};
local m_ExcludePlots		   : table = {};
local m_BrushSize			   : number = 1;
local m_BrushEnabled		   : boolean = true;
local m_InAnUndoGroup		   : boolean = false;
local m_RegenDelay			   : number = 0;
local m_CoastIndex			   : number = 1;
local m_MouseDownHex		   : number = 1;
local m_MouseDownEdge		   : number = 1;
local m_UndoItemCount		   : number = 0;
local m_bLastMouseWasDown	   : boolean = false;
local m_bDragInProgress		   : boolean = false;
local m_RefreshResDelay		   : number = 0;

-- 19-hex large brush assist table
local m_19HexTable			   : table = 
{
	{ Dir1=DirectionTypes.DIRECTION_NORTHWEST, Dir2=DirectionTypes.DIRECTION_NORTHEAST },
	{ Dir1=DirectionTypes.DIRECTION_NORTHEAST , Dir2=DirectionTypes.DIRECTION_EAST },
	{ Dir1=DirectionTypes.DIRECTION_EAST , Dir2=DirectionTypes.DIRECTION_SOUTHEAST },
	{ Dir1=DirectionTypes.DIRECTION_SOUTHEAST , Dir2=DirectionTypes.DIRECTION_SOUTHWEST },
	{ Dir1=DirectionTypes.DIRECTION_SOUTHWEST , Dir2=DirectionTypes.DIRECTION_WEST },
	{ Dir1=DirectionTypes.DIRECTION_WEST , Dir2=DirectionTypes.DIRECTION_NORTHWEST },
};

local m_itemIM	:table = InstanceManager:new( "ItemInstance", "Button", Controls.ItemsStack );

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--	Create an item icon
-- ===========================================================================
function MakeItem( toolID:number, icon:string, tooltip:string, itemCallback )
	
	local uiItem:table = m_itemIM:GetInstance();	
	if icon then uiItem.Icon:SetIcon( icon ) end;
	if tooltip then uiItem.Button:SetToolTipString( Locale.Lookup(tooltip) ) end;
	uiItem.Button:RegisterCallback( Mouse.eLClick, 
		function() 
			itemCallback( toolID );
		end);
	uiItem.Button:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);

	-- keep track for later
	table.insert(m_InstanceList, uiItem);

	return uiItem;
end

-- ===========================================================================
function PlacementSetResults(bStatus: boolean, sStatus: table, name: string)
	local result : string;

	if bStatus then
		UI.PlaySound("UI_WB_Placement_Succeeded");
		result = Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_OK", name);
	else
		if sStatus.NeededDistrict ~= -1 then
			local distNum : number = -1;
			for idx,entry in pairs(m_DistrictTypeEntries) do
				if entry.Index == (sStatus.NeededDistrict + 1) then
					distNum = idx;
					break;
				end
			end

			if distNum ~= -1 then
				result = Locale.Lookup("LOC_WORLDBUILDER_PLACEMENT_NEEDED", m_DistrictTypeEntries[distNum].Text);
			else
				result=Locale.Lookup("LOC_WORLDBUILDER_FAILURE_UNKNOWN");
			end
		elseif sStatus.NeededPopulation > 0 then
			result = Locale.Lookup("LOC_WORLDBUILDER_DISTRICT_REQUIRES") .. " " .. sStatus.NeededPopulation .. " " .. Locale.Lookup("LOC_WORLDBUILDER_POPULATION");
		elseif sStatus.bInProgress then
			result=Locale.Lookup("LOC_WORLDBUILDER_IN_PROGRESS");
		elseif sStatus.AlreadyExists then
			result=Locale.Lookup("LOC_WORLDBUILDER_ALREADY_EXISTS");
		elseif sStatus.IsOccupied then
			result=Locale.Lookup("LOC_WORLDBUILDER_OCCUPIED_BY_ENEMY");
		elseif sStatus.DistrictIsPillaged then
			result=Locale.Lookup("LOC_WORLDBUILDER_IS_PILLAGED");
		elseif sStatus.LocationIsContaminated then
			result=Locale.Lookup("LOC_WORLDBUILDER_IS_CONTAMINATED");
		elseif sStatus.NeededTech ~= -1 then
			result=Locale.Lookup("LOC_WORLDBUILDER_HIGHER_TECH", m_TechEntries[sStatus.NeededTech+1].Type.Name);
		elseif sStatus.NeededCivic ~= -1 then
			result=Locale.Lookup("LOC_WORLDBUILDER_HIGHER_CIVIC", m_CivicEntries[sStatus.NeededCivic+1].Type.Name);
		else
			result=Locale.Lookup("LOC_WORLDBUILDER_FAILURE_UNKNOWN");
		end
		UI.PlaySound("UI_WB_Placement_Failed");
	end

	LuaEvents.WorldBuilder_SetPlacementStatus(result);
end

-- ===========================================================================
function PlacementValid(plotID, mode)

	if mode == nil then
		return false;
	elseif mode.PlacementValid ~= nil then
		return mode.PlacementValid(plotID)
	else
		return true;
	end
end

-- ===========================================================================
function UpdateMouseOverHighlight(plotID, mode, on)

	if not mode.NoMouseOverHighlight then
		local highlight;
		if PlacementValid(plotID, mode) then
			highlight = PlotHighlightTypes.MOVEMENT;
		else
			highlight = PlotHighlightTypes.ATTACK;
		end
		UI.HighlightPlots(highlight, on, { plotID } );

		if m_BrushEnabled and m_BrushSize == 7 then
			local kPlot : table = Map.GetPlotByIndex(plotID);
			local adjPlots : table = Map.GetAdjacentPlots(kPlot:GetX(), kPlot:GetY());

			for i = 1, 6, 1 do
				if adjPlots[i] ~= nil then
					if PlacementValid(adjPlots[i]:GetIndex(), mode) then
						highlight = PlotHighlightTypes.MOVEMENT;
					else
						highlight = PlotHighlightTypes.ATTACK;
					end
					UI.HighlightPlots(highlight, on, { adjPlots[i]:GetIndex() } );
				end
			end
		elseif m_BrushEnabled and m_BrushSize == 19 then
			local kPlot : table = Map.GetPlotByIndex(plotID);
			local adjPlots : table = Map.GetAdjacentPlots(kPlot:GetX(), kPlot:GetY());
			
			for _,direction in pairs(DirectionTypes) do
				if adjPlots[direction] ~= nil then
					local adjPlot1 :table = Map.GetAdjacentPlot(adjPlots[direction]:GetX(), adjPlots[direction]:GetY(), m_19HexTable[direction].Dir1);
					local adjPlot2 :table = Map.GetAdjacentPlot(adjPlots[direction]:GetX(), adjPlots[direction]:GetY(), m_19HexTable[direction].Dir2);

					if adjPlot1 ~= nil then
						table.insert(adjPlots, adjPlot1);
					end
					if adjPlot2 ~= nil then
						table.insert(adjPlots, adjPlot2);
					end
				end
			end

			-- we must now dedupe the plots
			local hash : table = {};
			local dedupe : table = {};

			if adjPlots[1] == nil then
				adjPlots[1] = adjPlots[2];
			end

			for _,v in ipairs(adjPlots) do
				if not hash[v] then
					dedupe[#dedupe+1] = v;
					hash[v] = true;
				end
			end

			for i = 1, #dedupe, 1 do
				if dedupe[i] ~= nil then
					if PlacementValid(dedupe[i]:GetIndex(), mode) then
						highlight = PlotHighlightTypes.MOVEMENT;
					else
						highlight = PlotHighlightTypes.ATTACK;
					end
					UI.HighlightPlots(highlight, on, { dedupe[i]:GetIndex() } );
				end
			end
		end
	end
end

-- ===========================================================================
function ClearMode()

	if m_Mode ~= nil then
		for idx,instance in pairs(m_InstanceList) do
			m_itemIM:ReleaseInstance(instance);
		end

		m_InstanceList = {};

		if m_MouseOverPlot ~= nil then
			UpdateMouseOverHighlight(m_MouseOverPlot, m_Mode, false);
		end
		
		if m_Mode.OnLeft ~= nil then
			m_Mode.OnLeft();
		end

		m_Mode = nil;
	end
end

-- ===========================================================================
function MakeItemGrid(srcTable:table, control:table)
	for idx,entry in pairs(srcTable) do
		MakeItem(idx, "ICON_"..entry.PrimaryKey, Locale.Lookup(entry.Text), 
			function(value)
				control:SetSelectedIndex( value, true );
				for idx,instance in pairs(m_InstanceList) do
					instance.Active:SetHide(idx ~= value);
				end

			end);
	end
	local selIdx:number = control:GetSelectedIndex();
	for idx,instance in pairs(m_InstanceList) do
		instance.Active:SetHide(idx ~= selIdx);
	end

	Controls.ItemsContainer:SetHide(false);
end

-- ===========================================================================
function OnPlacementTypeSelected(mode)

	if mode ~= nil then
		if mode.ID == WorldBuilderModes.PLACE_RIVERS or mode.ID == WorldBuilderModes.PLACE_CLIFFS then
			-- Force grid lines if we're placing rivers or cliffs
			UI.ToggleGrid(true);
		else
			-- Revert to selected option if we're not
			UI.ToggleGrid(UserConfiguration.ShowMapGrid());
		end
	end

	ClearMode();

	m_Mode = mode;
	Controls.TabControl:SelectTab( mode.Tab );

	if mode.ID == WorldBuilderModes.PLACE_TERRAIN then
		MakeItemGrid(m_TerrainTypeEntries, Controls.TerrainPullDown);
	elseif mode.ID == WorldBuilderModes.PLACE_RESOURCES then
		MakeItemGrid(m_ResourceTypeEntries, Controls.ResourcePullDown);
	elseif mode.ID == WorldBuilderModes.PLACE_DISTRICTS then
		MakeItemGrid(m_DistrictTypeEntries, Controls.DistrictPullDown);
	elseif mode.ID == WorldBuilderModes.PLACE_BUILDINGS then
		MakeItemGrid(m_BuildingTypeEntries, Controls.BuildingPullDown);
	elseif mode.ID == WorldBuilderModes.PLACE_FEATURES then
		MakeItemGrid(m_FeatureTypeEntries, Controls.FeaturePullDown);
	elseif mode.ID == WorldBuilderModes.PLACE_WONDERS then
		MakeItemGrid(m_WonderTypeEntries, Controls.WonderPullDown);
	elseif mode.ID == WorldBuilderModes.PLACE_UNITS then
		MakeItemGrid(m_UnitTypeEntries, Controls.UnitPullDown);
	elseif mode.ID == WorldBuilderModes.PLACE_IMPROVEMENTS then
		MakeItemGrid(m_ImprovementTypeEntries, Controls.ImprovementPullDown);
		if not WorldBuilder.GetWBAdvancedMode() then
			Controls.ItemsContainer:SetHide(true);
		end
	else
		Controls.ItemsContainer:SetHide(true);
	end

	if mode.ID == WorldBuilderModes.PLACE_TERRAIN or mode.ID == WorldBuilderModes.PLACE_CONTINENTS then
		Controls.SmallBrushButton:SetDisabled(false);
		Controls.SmallBrushButton:SetColor(1.0, 1.0, 1.0);
		Controls.MediumBrushButton:SetDisabled(false);
		Controls.MediumBrushButton:SetColor(1.0, 1.0, 1.0);
		Controls.LargeBrushButton:SetDisabled(false);
		Controls.LargeBrushButton:SetColor(1.0, 1.0, 1.0);

		if m_BrushSize == 1 then
			Controls.SmallBrushActive:SetHide(false);
			Controls.MediumBrushActive:SetHide(true);
			Controls.LargeBrushActive:SetHide(true);
		elseif m_BrushSize == 7 then
			Controls.SmallBrushActive:SetHide(true);
			Controls.MediumBrushActive:SetHide(false);
			Controls.LargeBrushActive:SetHide(true);
		elseif m_BrushSize == 19 then
			Controls.SmallBrushActive:SetHide(true);
			Controls.MediumBrushActive:SetHide(true);
			Controls.LargeBrushActive:SetHide(false);
		end

		m_BrushEnabled = true;
	else
		-- show brush size as small for now
		Controls.SmallBrushActive:SetHide(false);
		Controls.MediumBrushActive:SetHide(true);
		Controls.LargeBrushActive:SetHide(true);
		Controls.SmallBrushButton:SetDisabled(true);
		Controls.SmallBrushButton:SetColor(0.5, 0.5, 0.5);
		Controls.MediumBrushButton:SetDisabled(true);
		Controls.MediumBrushButton:SetColor(0.5, 0.5, 0.5);
		Controls.LargeBrushButton:SetDisabled(true);
		Controls.LargeBrushButton:SetColor(0.5, 0.5, 0.5);
		m_BrushEnabled = false;
	end
	
	if mode.ID == WorldBuilderModes.PLACE_RESOURCES then
		OnResourceTypeSelected(Controls.ResourcePullDown:GetSelectedEntry());
	end

	if m_MouseOverPlot ~= nil then
		UpdateMouseOverHighlight(m_MouseOverPlot, m_Mode, true);
	end

	if m_Mode.OnEntered ~= nil then
		m_Mode.OnEntered();
	end

	Controls.Root:CalculateSize();
end

-- ===========================================================================
function OnPlotSelected(plotID, edge, lbutton, rbutton)
	if not ContextPtr:IsHidden() then
		if not lbutton then
			m_bDragInProgress = false;
			m_bLastMouseWasDown = false;
			if m_InAnUndoGroup then
				WorldBuilder.EndUndoBlock();
				m_RefreshResDelay = 3;
				m_InAnUndoGroup = false;
			end
		elseif not m_InAnUndoGroup then
   			WorldBuilder.StartUndoBlock();
   			m_InAnUndoGroup = true;
			m_UndoItemCount = 0;
		end

		-- eat false delete for single-click placement
		if not lbutton and not rbutton then
			return;
		end

		-- if this is our first mousedown, store the plot and do nothing
		if lbutton and not m_bLastMouseWasDown and rbutton then
			m_MouseDownHex = plotID;
			m_MouseDownEdge = edge;
			m_bLastMouseWasDown = true;
			m_bDragInProgress = false;
			return;
		elseif lbutton and m_bLastMouseWasDown and not m_bDragInProgress and rbutton then
			m_bDragInProgress = true;
			OnPlotSelected(m_MouseDownHex, m_MouseDownEdge, true);
		end

		local mode = Controls.PlacementPullDown:GetSelectedEntry();
		local kPlot : table = Map.GetPlotByIndex(plotID);
		if m_BrushEnabled and m_BrushSize > 1 then
			mode.PlacementFunc(plotID, edge, lbutton, false);
			m_ExcludePlots = {};
			table.insert(m_ExcludePlots, kPlot);
		else
			m_ExcludePlots = {};
			mode.PlacementFunc(plotID, edge, lbutton, true);
		end

		m_UndoItemCount = m_UndoItemCount + 1;

		-- update the cursor status
		OnPlotMouseOver(plotID);

		if m_BrushEnabled and m_BrushSize == 7 then
			local adjPlots : table = Map.GetAdjacentPlots(kPlot:GetX(), kPlot:GetY());

			for i = 1, 6, 1 do
				if adjPlots[i] ~= nil and PlacementValid(adjPlots[i]:GetIndex(), mode) then
					mode.PlacementFunc(adjPlots[i]:GetIndex(), edge, lbutton, true);
					table.insert(m_ExcludePlots, adjPlots[i]);
					m_UndoItemCount = m_UndoItemCount + 1;
				end
			end
		elseif m_BrushEnabled and m_BrushSize == 19 then
			local adjPlots : table = Map.GetAdjacentPlots(kPlot:GetX(), kPlot:GetY());

			for i = 1, 6, 1 do
				if adjPlots[i] ~= nil and PlacementValid(adjPlots[i]:GetIndex(), mode) then
					mode.PlacementFunc(adjPlots[i]:GetIndex(), edge, lbutton, false);
					table.insert(m_ExcludePlots, adjPlots[i]);
					m_UndoItemCount = m_UndoItemCount + 1;
				end
			end

			local outerPlots : table = {};
			for _,direction in pairs(DirectionTypes) do
				if adjPlots[direction] ~= nil then
					local adjPlot1 :table = Map.GetAdjacentPlot(adjPlots[direction]:GetX(), adjPlots[direction]:GetY(), m_19HexTable[direction].Dir1);
					local adjPlot2 :table = Map.GetAdjacentPlot(adjPlots[direction]:GetX(), adjPlots[direction]:GetY(), m_19HexTable[direction].Dir2);

					if adjPlot1 ~= nil then
						table.insert(outerPlots, adjPlot1);
					end
					if adjPlot2 ~= nil then
						table.insert(outerPlots, adjPlot2);
					end
				end
			end

			for _, plot in pairs(outerPlots) do
				mode.PlacementFunc(plot:GetIndex(), edge, lbutton, true);
				table.insert(m_ExcludePlots, plot);
				m_UndoItemCount = m_UndoItemCount + 1;
			end
		end
	end

	-- break undos up into blocks of 1000 operations
	if m_InAnUndoGroup and m_UndoItemCount >= 800 then
		WorldBuilder.EndUndoBlock();
		WorldBuilder.StartUndoBlock();
		m_UndoItemCount = 0;
	end
end

-- ===========================================================================
function OnPlotMouseOver(plotID)

	if m_Mode ~= nil then
		if m_MouseOverPlot ~= nil then
			UpdateMouseOverHighlight(m_MouseOverPlot, m_Mode, false);
		end

		if plotID ~= nil then
			UpdateMouseOverHighlight(plotID, m_Mode, true);
		end
	end

	m_MouseOverPlot = plotID;
end

-- ===========================================================================
function OnShow()

	local mode = Controls.PlacementPullDown:GetSelectedEntry();
	OnPlacementTypeSelected( mode );

	if UI.GetInterfaceMode() ~= InterfaceModeTypes.WB_SELECT_PLOT then
		UI.SetInterfaceMode( InterfaceModeTypes.WB_SELECT_PLOT );
	end

	LuaEvents.WorldBuilderMapTools_SetTabHeader(Locale.Lookup("LOC_WORLDBUILDER_PLACEMENT_PLACE_PLOT"));
end

-- ===========================================================================
function OnHide()
	ClearMode();
end

-- ===========================================================================
function OnLoadGameViewStateDone()

	UpdatePlayerEntries();
	UpdateCityEntries();

	if not ContextPtr:IsHidden() then
		OnShow();
	end
end

-- ===========================================================================
function OnVisibilityPlayerChanged(entry)
	
	if m_Mode ~= nil and m_Mode.Tab == Controls.PlaceVisibility then
		if entry ~= nil then
			WorldBuilder.SetVisibilityPreviewPlayer(entry.PlayerIndex);
		else
			WorldBuilder.ClearVisibilityPreviewPlayer();
		end
	end 
end

-- ===========================================================================
function OnVisibilityPlayerRevealAll()
	
	local entry = Controls.VisibilityPullDown:GetSelectedEntry();
	if entry ~= nil then
		WorldBuilder.MapManager():SetAllRevealed(true, entry.PlayerIndex);
	end

end

-- ===========================================================================
function UpdatePlayerEntries()

	m_PlayerEntries = {};
	m_ScenarioPlayerEntries = {};
	
	for i = 0, GameDefines.MAX_PLAYERS-1 do 

		local eStatus = WorldBuilder.PlayerManager():GetSlotStatus(i); 
		if eStatus ~= SlotStatus.SS_CLOSED then
			local playerConfig = WorldBuilder.PlayerManager():GetPlayerConfig(i);
			if playerConfig.IsBarbarian == false then	-- Skipping the Barbarian player
				table.insert(m_PlayerEntries, { Text=playerConfig.Name, PlayerIndex=i });
				if playerConfig.Civ ~= nil then
					table.insert(m_ScenarioPlayerEntries, { Text=playerConfig.Name, PlayerIndex=i });
				end
			end
		end
	end
	
	local hasPlayers = m_PlayerEntries[1] ~= nil;
	local hasScenarioPlayers = m_ScenarioPlayerEntries[1] ~= nil;

	Controls.StartPosPlayerPulldown:SetEntries( m_PlayerEntries, hasPlayers and 1 or 0 );
	Controls.CityOwnerPullDown:SetEntries( m_ScenarioPlayerEntries, hasScenarioPlayers and 1 or 0 );
	Controls.UnitOwnerPullDown:SetEntries( m_ScenarioPlayerEntries, hasScenarioPlayers and 1 or 0 );
	Controls.OwnerPullDown:SetEntries( m_ScenarioPlayerEntries, hasScenarioPlayers and 1 or 0 );
	Controls.VisibilityPullDown:SetEntries( m_ScenarioPlayerEntries, hasScenarioPlayers and 1 or 0 );

	if WorldBuilder.GetWBAdvancedMode() then
		m_TabButtons[Controls.PlaceUnit]:SetDisabled( not hasScenarioPlayers );
		m_TabButtons[Controls.PlaceBuilding]:SetDisabled( not hasScenarioPlayers );
		m_TabButtons[Controls.PlaceStartPos]:SetDisabled( not hasPlayers );
		m_TabButtons[Controls.PlaceDistrict]:SetDisabled( not hasScenarioPlayers );
		m_TabButtons[Controls.PlaceVisibility]:SetDisabled( not hasScenarioPlayers );
		m_TabButtons[Controls.PlaceCity]:SetDisabled( not hasScenarioPlayers );
	end

	OnVisibilityPlayerChanged(Controls.VisibilityPullDown:GetSelectedEntry());
end

-- ===========================================================================
function UpdateCityEntries()

	m_CityEntries = {};

	for iPlayer = 0, GameDefines.MAX_PLAYERS-1 do
		local player = Players[iPlayer];
		local cities = player:GetCities();
		if cities ~= nil then
			for iCity, city in cities:Members() do
				table.insert(m_CityEntries, { Text=city:GetName(), PlayerIndex=iPlayer, ID=city:GetID() });
			end
		end
	end

	local hasCities = m_CityEntries[1] ~= nil;
	Controls.OwnerPullDown:SetEntries( m_CityEntries, hasCities and 1 or 0 );
end

-- ===========================================================================
function PlaceTerrainInternal(plot, edge, bAdd, terrIdx, terrText, bSetStatus)
	local bSuccess:boolean = false;

	if bAdd then
		local pkPlot :table = Map.GetPlotByIndex( plot );
		local featureType :number = nil;
		local impType :number = nil;
		local resType :number = nil;

		-- if new terrain is wrong for cliffs, delete any cliffs on this plot
		if terrText == "LOC_TERRAIN_COAST_NAME" or terrText == "LOC_TERRAIN_OCEAN_NAME" then
			WorldBuilder.MapManager():EditCliff(plot, DirectionTypes.DIRECTION_NORTHWEST, false, false);
			WorldBuilder.MapManager():EditCliff(plot, DirectionTypes.DIRECTION_WEST, false, false);
			WorldBuilder.MapManager():EditCliff(plot, DirectionTypes.DIRECTION_SOUTHWEST, false, false);
			WorldBuilder.MapManager():EditCliff(plot, DirectionTypes.DIRECTION_SOUTHEAST, false, false);
			WorldBuilder.MapManager():EditCliff(plot, DirectionTypes.DIRECTION_EAST, false, false);
			WorldBuilder.MapManager():EditCliff(plot, DirectionTypes.DIRECTION_NORTHEAST, false, false);
		end

		if (pkPlot:GetFeatureType() >= 0) then
			featureType = pkPlot:GetFeatureType();
		end
		if (pkPlot:GetImprovementType() >= 0) then
			impType = pkPlot:GetImprovementType();
		end

		bSuccess = WorldBuilder.MapManager():SetTerrainType( plot, terrIdx );

		if not bSetStatus then
			return true;
		end

		local result : string;
		if bSuccess then
			result = Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_OK", terrText);
			UI.PlaySound("UI_WB_Placement_Succeeded");

			-- how about the existing feature?
			if featureType ~= nil and not WorldBuilder.MapManager():CanPlaceFeature( plot, featureType, true ) then
				WorldBuilder.MapManager():SetFeatureType( plot, -1 );
			end

			-- and the existing improvement?
			if impType ~= nil and not WorldBuilder.MapManager():CanPlaceImprovement( plot, impType, Map.GetPlotByIndex(plot):GetOwner(), true ) then
				WorldBuilder.MapManager():SetImprovementType( plot, -1 );
			end

			-- will the existing resource work with the new terrain?
			--if (pkPlot:GetResourceType() > 0) then
				resType = pkPlot:GetResourceType();
			--end

			-- recheck the resource now that the feature has hcchnged
			if resType ~= nil and not WorldBuilder.MapManager():CanPlaceResource( plot, resType, true ) then
				WorldBuilder.MapManager():SetResourceType( plot, -1 );
			end
		else
			result=Locale.Lookup("LOC_WORLDBUILDER_FAILURE_UNKNOWN");
			UI.PlaySound("UI_WB_Placement_Failed");
		end
		LuaEvents.WorldBuilder_SetPlacementStatus(result);
		m_RefreshResDelay = 3;
	end

	return bSuccess;
end

function PlaceTerrain(plot, edge, bAdd, bOuter)
	if bAdd then
		local kPlot : table = Map.GetPlotByIndex(plot);
		local adjPlots : table = Map.GetAdjacentPlots(kPlot:GetX(), kPlot:GetY());
		local terrain : table = Controls.TerrainPullDown:GetSelectedEntry();
		local saveIdx : number = Controls.TerrainPullDown:GetSelectedIndex();
		local coast : table = m_TerrainTypeEntries[m_CoastIndex];

		PlaceTerrainInternal(plot, edge, bAdd, terrain.Type.Index, terrain.Type.Name, true);

		if bOuter then
			for i = 1, 6, 1 do
				if adjPlots[i] ~= nil then
					local bExclude:boolean = false;
					for _,plot in pairs(m_ExcludePlots) do
						if plot:GetIndex() == adjPlots[i]:GetIndex() then
							bExclude = true;
						end
					end

					if not bExclude then
						local curPlotType : string = m_TerrainTypeEntries[adjPlots[i]:GetTerrainType() + 1].Type.Name;

						-- if we're placing an ocean tile, add coast
						if terrain.Text == "LOC_TERRAIN_OCEAN_NAME" then
							-- ocean: neighbor can be ocean or coast
							if curPlotType ~= "LOC_TERRAIN_OCEAN_NAME" and curPlotType ~= "LOC_TERRAIN_COAST_NAME" then
								PlaceTerrainInternal(adjPlots[i]:GetIndex(), edge, bAdd, coast.Type.Index, coast.Type.Name, false);
							end
						elseif terrain.Text ~= "LOC_TERRAIN_COAST_NAME" then
						-- not coast or ocean, so it's land and neighboring ocean tiles must turn to coast
							if curPlotType == "LOC_TERRAIN_OCEAN_NAME" then
								PlaceTerrainInternal(adjPlots[i]:GetIndex(), edge, bAdd, coast.Type.Index, coast.Type.Name, false);
								curPlotType = "LOC_TERRAIN_COAST_NAME";
							end

							-- is this a hills tile?
							if terrain.Text == "LOC_TERRAIN_DESERT_HILLS_NAME" or terrain.Text == "LOC_TERRAIN_GRASS_HILLS_NAME" or terrain.Text == "LOC_TERRAIN_SNOW_HILLS_NAME" or terrain.Text == "LOC_TERRAIN_TUNDRA_HILLS_NAME" or terrain.Text == "LOC_TERRAIN_PLAINS_HILLS_NAME" then
								-- adjcent tile is coast?
								if curPlotType == "LOC_TERRAIN_COAST_NAME" then
									-- add a cliff in that direction
									WorldBuilder.MapManager():EditCliff(plot, i - 1, true, false);
								else
									local adjToDel : number;
									if i > 3 then
										adjToDel = i - 3;
									else
										adjToDel = i + 3;
									end

									WorldBuilder.MapManager():EditCliff(adjPlots[i], adjToDel - 1, false, false);
								end
				   			end	
						end
					end
				end
			end
		end
	end
end

-- ===========================================================================
function PlaceContinent(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.ContinentPullDown:GetSelectedEntry();
		local bStatus:boolean = WorldBuilder.MapManager():SetContinentType( plot, entry.Type.Index );
		if bStatus then
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CONTINENT_PLACED", entry.Text));
			UI.PlaySound("UI_WB_Placement_Succeeded");
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CONTINENT_ERROR", entry.Text));
			UI.PlaySound("UI_WB_Placement_Failed");
		end
	end
end

-- ===========================================================================
function PlaceContinent_Valid(plot)
	local pPlot = Map.GetPlotByIndex(plot);
	return pPlot ~= nil and not pPlot:IsWater();
end

-- ===========================================================================
function PlaceFeature(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.FeaturePullDown:GetSelectedEntry();

		if WorldBuilder.MapManager():CanPlaceFeature( plot, entry.Type.Index ) then
			WorldBuilder.MapManager():SetFeatureType( plot, entry.Type.Index );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_OK", entry.Text));
			UI.PlaySound("UI_WB_Placement_Succeeded");

			-- if new terrain is ice, delete resources
			if entry.PrimaryKey == "FEATURE_ICE" or entry.PrimaryKey == "FEATURE_GEOTHERMAL_FISSURE" then
				if Map.GetPlotByIndex(plot):GetResourceType() ~= -1 then
					WorldBuilder.MapManager():SetResourceType( plot, -1 );
				end
			end

		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_FAILURE_FEATURE"));
			UI.PlaySound("UI_WB_Placement_Failed");
		end
	else
		local featureType:number = Map.GetPlotByIndex(plot):GetFeatureType();
		local bIsWonder:boolean = false;
		if featureType ~= nil and featureType ~= -1 then
			for i,entry in pairs(m_WonderTypeEntries) do
				if entry.Type.Index == featureType then
					bIsWonder = true;
					break;
				end
			end
		end

		if not bIsWonder then
			local terrType:number = Map.GetPlotByIndex(plot):GetTerrainType();
			WorldBuilder.MapManager():SetFeatureType( plot, -1 );
			WorldBuilder.MapManager():SetTerrainType( plot, terrType );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_FEATURE_REMOVED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_FEATURE_TO_REMOVE"));
		end
	end
end

-- ===========================================================================
function PlaceFeature_Valid(plot)
	local entry = Controls.FeaturePullDown:GetSelectedEntry();
	return WorldBuilder.MapManager():CanPlaceFeature( plot, entry.Type.Index );
end

-- ===========================================================================
function PlaceWonder(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.WonderPullDown:GetSelectedEntry();

		if Map.GetFeatureCount(entry.Type.Index) > 0 then
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_ALREADY_EXISTS"));
			UI.PlaySound("UI_WB_Placement_Failed");
			return;
		end

		-- check specifically for distance from another wonder
		if WorldBuilder.MapManager():IsWonderTooClose( plot, entry.Type.Index ) then
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_WONDER_DISTANCE"));
			UI.PlaySound("UI_WB_Placement_Failed");
			return;
		end

		if WorldBuilder.MapManager():CanPlaceFeature( plot, entry.Type.Index ) then
			WorldBuilder.MapManager():SetFeatureType( plot, entry.Type.Index );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_OK", entry.Text));
			UI.PlaySound("UI_WB_Placement_Succeeded");
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_UNIT_ERROR", entry.Text));
			UI.PlaySound("UI_WB_Placement_Failed");
		end
	else
		local featureType:number = Map.GetPlotByIndex(plot):GetFeatureType();
		local bIsWonder:boolean = false;
		if featureType ~= nil and featureType ~= -1 then
			for i,entry in pairs(m_WonderTypeEntries) do
				if entry.Type.Index == featureType then
					bIsWonder = true;
					break;
				end
			end
		end

		if bIsWonder then
			local terrType:number = Map.GetPlotByIndex(plot):GetTerrainType();
			WorldBuilder.MapManager():SetFeatureType( plot, -1 );
			WorldBuilder.MapManager():SetTerrainType( plot, terrType );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_WONDER_REMOVED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_WONDER_TO_REMOVE"));
		end
	end
end

-- ===========================================================================
function PlaceWonder_Valid(plot)
	local entry = Controls.WonderPullDown:GetSelectedEntry();

	if WorldBuilder.MapManager():CanPlaceFeature( plot, entry.Type.Index ) then
		return false;
	end

	-- Enforce having only one NW of a specified type at the UI level.
	if Map.GetFeatureCount(entry.Type.Index) > 0 then
		return false;
	end

	return WorldBuilder.MapManager():CanPlaceFeature( plot, entry.Type.Index );
end

-- ===========================================================================
function PlaceRiver(plot, edge, bAdd)
	local bStatus:boolean, eResult:number = WorldBuilder.MapManager():EditRiver(plot, edge, bAdd, false);
	if bStatus then
		if bAdd then
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_RIVER_PLACED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_RIVER_REMOVED"));
		end
		UI.PlaySound("UI_WB_Placement_Succeeded");
	else
		local resultText;

			if eResult == DB.MakeHash("INVALID_LOCATION") then
				resultText = "LOC_WORLDBUILDER_RIVER_INVALID_LOCATION";
			elseif eResult == DB.MakeHash("JOINING_RIVERS") then
				resultText = "LOC_WORLDBUILDER_RIVER_JOINING_RIVERS";
			elseif eResult == DB.MakeHash("NOT_NEAR_RIVER_OR_WATER") then
				resultText = "LOC_WORLDBUILDER_RIVER_NOT_NEAR_RIVER_OR_WATER";
			elseif eResult == DB.MakeHash("SPLITTING_RIVER") then
				resultText = "LOC_WORLDBUILDER_RIVER_SPLITTING_RIVER";
			end

		if resultText == nil then
			if bAdd then
				resultText = "LOC_WORLDBUILDER_RIVER_ERROR";
			else
				resultText = "LOC_WORLDBUILDER_RIVER_REMOVED_ERROR";
			end
		end

		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup(resultText));

		UI.PlaySound("UI_WB_Placement_Failed");
	end
end

-- ===========================================================================
function PlaceCliff(plot, edge, bAdd)
	local bStatus:boolean = WorldBuilder.MapManager():EditCliff(plot, edge, bAdd, false);
	if bStatus then
		if bAdd then
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CLIFF_PLACED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CLIFF_REMOVED"));
		end
		UI.PlaySound("UI_WB_Placement_Succeeded");
	else
		if bAdd then
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CLIFF_ERROR"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CLIFF_REMOVED_ERROR"));
		end
		UI.PlaySound("UI_WB_Placement_Failed");
	end
end

-- ===========================================================================
function PlaceCliff_Valid(plot)
	local kPlot : table = Map.GetPlotByIndex(plot);
	local curPlotType : string = m_TerrainTypeEntries[kPlot:GetTerrainType() + 1].Type.Name;

	if curPlotType == "LOC_TERRAIN_OCEAN_NAME" then
		return false;
	end
	
	local adjPlots : table = Map.GetAdjacentPlots(kPlot:GetX(), kPlot:GetY());
	for i = 1, 6, 1 do
		if adjPlots[i] ~= nil then
			local adjPlotType : string = m_TerrainTypeEntries[adjPlots[i]:GetTerrainType() + 1].Type.Name;

			if curPlotType ~= "LOC_TERRAIN_COAST_NAME" and adjPlotType == "LOC_TERRAIN_COAST_NAME" then
				return true;
			elseif curPlotType == "LOC_TERRAIN_COAST_NAME" and adjPlotType ~= "LOC_TERRAIN_OCEAN_NAME" and adjPlotType ~= "LOC_TERRAIN_COAST_NAME" then
				return true;
			end
		end
	end

	return false;
end

-- ===========================================================================
function PlaceResource_Valid(plot)
	local entry = Controls.ResourcePullDown:GetSelectedEntry();
	return WorldBuilder.MapManager():CanPlaceResource( plot, entry.Type.Index, true );
end

-- ===========================================================================
function PlaceResource(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.ResourcePullDown:GetSelectedEntry();
		if WorldBuilder.MapManager():CanPlaceResource( plot, entry.Type.Index, true ) then
			local bResult : boolean = true;
			if entry.Class == "RESOURCECLASS_STRATEGIC" then
				bResult = WorldBuilder.MapManager():SetResourceType( plot, entry.Type.Index, Controls.ResourceAmount:GetText() );
			else
				bResult = WorldBuilder.MapManager():SetResourceType( plot, entry.Type.Index, "1" );
			end

			if bResult then
				PlacementSetResults(true, nil, entry.Type.Name);
			else
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_UNIT_ERROR", entry.Type.Name));
			end
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_UNIT_ERROR", entry.Type.Name));
		end
	else
		if Map.GetPlotByIndex(plot):GetResourceType() ~= -1 then
			WorldBuilder.MapManager():SetResourceType( plot, -1 );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_RESOURCE_REMOVED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_RESOURCE_TO_REMOVE"));
		end
	end

	m_RefreshResDelay = 3;
end

-- ===========================================================================
function PlaceCity(plot, edge, bAdd)

	if bAdd then
		local playerEntry = Controls.CityOwnerPullDown:GetSelectedEntry();
		if playerEntry ~= nil then
			WorldBuilder.CityManager():Create(playerEntry.PlayerIndex, plot);
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_PLACEMENT_OK"));
			UI.PlaySound("UI_WB_Placement_Succeeded");
		end
	else
		local pDistrict = CityManager.GetDistrictAt(plot);
		if (pDistrict ~= nil) then
			-- Then its city
			local pCity = pDistrict:GetCity();
			if pCity ~= nil then
				WorldBuilder.CityManager():RemoveAt(plot);
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CITY_REMOVED"));
			else
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CITY_REMOVED_NONE"));
			end
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CITY_REMOVED_NONE"));
		end
	end
end

-- ===========================================================================
function PlaceDistrict(plot, edge, bAdd)
	local bStatus : boolean;
	local sStatus : table;

	if bAdd then
		local ourPlot : table = Map.GetPlotByIndex( plot );
		local hasOwner : boolean = ourPlot:IsOwned();
		local owner : table = hasOwner and WorldBuilder.CityManager():GetPlotOwner( ourPlot ) or nil;
		if owner ~= nil then
			local city = CityManager.GetCity(owner.PlayerID, owner.CityID);
			if city ~= nil then
				local districtEntry = Controls.DistrictPullDown:GetSelectedEntry();
				bStatus, sStatus = WorldBuilder.CityManager():CreateDistrict(city, districtEntry.Type.DistrictType, 100, plot);
				PlacementSetResults(bStatus, sStatus, districtEntry.Text);
			end

		end
	else
		-- Get the district at the plot
		local pDistrict = CityManager.GetDistrictAt(plot);
		if (pDistrict ~= nil) then
			WorldBuilder.CityManager():RemoveDistrict(pDistrict);
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_DISTRICT_REMOVED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_DISTRICT_TO_REMOVE"));
		end
	end
end

-- ===========================================================================
function PlaceDistrict_Valid(plot)
	local ourPlot = Map.GetPlotByIndex( plot );
	local hasOwner : boolean = ourPlot:IsOwned();
    local owner = hasOwner and WorldBuilder.CityManager():GetPlotOwner( ourPlot ) or nil;

	if hasOwner then
		local districtEntry = Controls.DistrictPullDown:GetSelectedEntry();
		local tParameters :table	= {};
		tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Type.Hash;
		local city = CityManager.GetCity(owner.PlayerID, owner.CityID);
		if city ~= nil then
			local tResults :table = CityManager.GetOperationTargets( city, CityOperationTypes.BUILD, tParameters );
			if tResults ~= nil then
				local kPlots		= tResults[CityOperationResults.PLOTS];	 
				if kPlots ~= nil then
					for i, plotId in ipairs(kPlots) do
						if plotId == plot then
							return true;
						end
					end
				end
			end
		end
	end

	return false;
end

-- ===========================================================================
function PlaceBuilding(plot, edge, bAdd)
	local bStatus : boolean;
	local sStatus : table;
	local strStatus;

	if bAdd then
		local ourPlot = Map.GetPlotByIndex( plot );
		local hasOwner : boolean = ourPlot:IsOwned();
		local owner = hasOwner and WorldBuilder.CityManager():GetPlotOwner( ourPlot ) or nil;
		if owner ~= nil then
			local city = CityManager.GetCity(owner.PlayerID, owner.CityID);
			if city ~= nil then
				local buildingEntry = Controls.BuildingPullDown:GetSelectedEntry();
				if buildingEntry ~= nil then
					bStatus, sStatus = WorldBuilder.CityManager():CreateBuilding(city, buildingEntry.Type.BuildingType, 100, plot);
					PlacementSetResults(bStatus, sStatus, buildingEntry.Text);
				end
			end

		end
	else
		-- Get the district at the plot
		local pDistrict = CityManager.GetDistrictAt(plot);
		if (pDistrict ~= nil) then
			-- Then its city
			local pCity = pDistrict:GetCity();
			if pCity ~= nil then
				-- Remove the building from the city
				local buildingEntry = Controls.BuildingPullDown:GetSelectedEntry();
				if buildingEntry ~= nil then
					WorldBuilder.CityManager():RemoveBuilding(pCity, buildingEntry.Type.BuildingType);
					LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_BUILDING_REMOVED"));
				else
					LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_BUILDING_TO_REMOVE"));
				end
			else
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_BUILDING_TO_REMOVE_CITY"));
			end
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_BUILDING_TO_REMOVE_DISTRICT"));
		end
	end
end

-- ===========================================================================
function PlaceBuilding_Valid(plot)
	local ourPlot = Map.GetPlotByIndex( plot );
	local hasOwner : boolean = ourPlot:IsOwned();
    local owner = hasOwner and WorldBuilder.CityManager():GetPlotOwner( ourPlot ) or nil;
	local buildingEntry = Controls.BuildingPullDown:GetSelectedEntry();
	local sConfirmText : string;

	if hasOwner then
		local pCity = CityManager.GetCity(owner.PlayerID, owner.CityID);
		if pCity ~= nil then
			local tParameters :table	= {};
--			local kPlot : table = Map.GetPlotByIndex(plot);
--			tParameters[CityOperationTypes.PARAM_X] = kPlot:GetX();
--			tParameters[CityOperationTypes.PARAM_Y] = kPlot:GetY();
--			tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Type.Hash;

--			local tResults :table = CityManager.GetOperationTargets( pCity, CityOperationTypes.BUILD, tParameters );
--			if (tResults ~= nil and tResults[CityOperationResults.SUCCESS_CONDITIONS] ~= nil) then
--				if (table.count(tResults[CityOperationResults.SUCCESS_CONDITIONS]) == 0) then
--					return true;
--				end
--			elseif (tResults ~= nil) then
--				return true;
--			end
			return true;
		end
	end

	return false;
end

-- ===========================================================================
function PlaceUnit(plot, edge, bAdd)

	if bAdd then
		local playerEntry = Controls.UnitOwnerPullDown:GetSelectedEntry();
		local unitEntry = Controls.UnitPullDown:GetSelectedEntry();
		if playerEntry ~= nil and unitEntry ~= nil then
			local player, ID = WorldBuilder.UnitManager():Create(unitEntry.Type.Index, playerEntry.PlayerIndex, plot);
			if player == nil or ID == nil then
				if unitEntry.Type.Name == "LOC_UNIT_SPY_NAME" then
					LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_UNIT_ERROR_DISTRICT", unitEntry.Type.Name));
				else
					LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_UNIT_ERROR", unitEntry.Type.Name));
				end
				UI.PlaySound("UI_WB_Placement_Failed");
			else
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_UNIT_PLACED"));
				UI.PlaySound("UI_WB_Placement_Succeeded");
			end
		end
	else
		WorldBuilder.UnitManager():RemoveAt(plot);
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_UNIT_REMOVED"));
	end
end

-- ===========================================================================
function PlaceImprovement(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.ImprovementPullDown:GetSelectedEntry();
		local bStatus:boolean = WorldBuilder.MapManager():SetImprovementType( plot, entry.Type.Index, Map.GetPlotByIndex( plot ):GetOwner() );
		if bStatus then
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_OK", entry.Text));
			WorldBuilder.MapManager():SetImprovementPillaged( plot, Controls.ImprovementPillagedCheck:IsChecked() );
			UI.PlaySound("UI_WB_Placement_Succeeded");
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_ERROR", entry.Text));
			UI.PlaySound("UI_WB_Placement_Failed");
		end
	else
		if Map.GetPlotByIndex(plot):GetImprovementType() ~= -1 then
			WorldBuilder.MapManager():SetImprovementType( plot, -1 );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_IMPROVEMENT_REMOVED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_IMPROVEMENT_TO_REMOVE"));
		end
	end
end

-- ===========================================================================
function PlaceImprovement_Valid(plot)
	local entry = Controls.ImprovementPullDown:GetSelectedEntry();
	return WorldBuilder.MapManager():CanPlaceImprovement( plot, entry.Type.Index, Map.GetPlotByIndex(plot):GetOwner(), true );
end

-- ===========================================================================
function PlaceGoodyHut(plot, edge, bAdd)
	if bAdd then
		local entry:table = m_GoodyHutTypeEntries[1];
		local bStatus:boolean = WorldBuilder.MapManager():SetImprovementType( plot, entry.Type.Index, Map.GetPlotByIndex( plot ):GetOwner() );
		if bStatus then
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_OK", entry.Text));
			UI.PlaySound("UI_WB_Placement_Succeeded");
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_ERROR", entry.Text));
			UI.PlaySound("UI_WB_Placement_Failed");
		end
	else
		if Map.GetPlotByIndex(plot):GetImprovementType() ~= -1 then
			WorldBuilder.MapManager():SetImprovementType( plot, -1 );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_GHIMPROVEMENT_REMOVED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_GHIMPROVEMENT_TO_REMOVE"));
		end
	end
end

-- ===========================================================================
function PlaceGoodyHut_Valid(plot)
	local entry:table = m_GoodyHutTypeEntries[1];
	return WorldBuilder.MapManager():CanPlaceImprovement( plot, entry.Type.Index, Map.GetPlotByIndex(plot):GetOwner(), true );
end

-- ===========================================================================
function PlaceRoute(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.RoutePullDown:GetSelectedEntry();
		WorldBuilder.MapManager():SetRouteType( plot, entry.Type.Index, Controls.RoutePillagedCheck:IsChecked() );
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_OK", entry.Text));
		UI.PlaySound("UI_WB_Placement_Succeeded");
	else
		WorldBuilder.MapManager():SetRouteType( plot, RouteTypes.NONE );
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_ROUTE_REMOVED"));
	end
end

-- ===========================================================================
function PlaceStartPos(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.StartPosPlayerPulldown:GetSelectedEntry();
		if entry ~= nil then
			WorldBuilder.PlayerManager():SetPlayerStartingPosition( entry.PlayerIndex, plot );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_START_POS_SET"));
			UI.PlaySound("UI_WB_Placement_Succeeded");
		end
	else
		local prevStartPosPlayer = WorldBuilder.PlayerManager():GetStartPositionPlayer( plot );
		if prevStartPosPlayer ~= -1 then
			WorldBuilder.PlayerManager():ClearPlayerStartingPosition( prevStartPosPlayer );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_SPAWN_REMOVED"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_NO_SPAWN_TO_REMOVE"));
		end
	end
end

-- ===========================================================================
function PlaceOwnership(iPlot, edge, bAdd)

	local plot = Map.GetPlotByIndex( iPlot );
	if bAdd then
		local entry = Controls.OwnerPullDown:GetSelectedEntry();
		if entry ~= nil then
			WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), entry.PlayerIndex, entry.ID );
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_OWNERSHIP_SET"));
			UI.PlaySound("UI_WB_Placement_Succeeded");
		end
	else
		WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), false );
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_OWNERSHIP_REMOVED"));
	end
end

-- ===========================================================================
function OnVisibilityToolEntered()
	
	local entry = Controls.VisibilityPullDown:GetSelectedEntry();
	if entry ~= nil then
		WorldBuilder.SetVisibilityPreviewPlayer(entry.PlayerIndex);
	end 
end

-- ===========================================================================
function OnVisibilityToolLeft()
	WorldBuilder.ClearVisibilityPreviewPlayer();
end

-- ===========================================================================
function PlaceVisibility(plot, edge, bAdd)

	local entry = Controls.VisibilityPullDown:GetSelectedEntry();
	if entry ~= nil then
		local bStatus:boolean = WorldBuilder.MapManager():SetRevealed(plot, bAdd, entry.PlayerIndex);
		if bStatus then
			if bAdd then
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_VIS_SET_OK", entry.Text));
			else
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_VIS_CLEAR_OK", entry.Text));
			end
			UI.PlaySound("UI_WB_Placement_Succeeded");
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_VIS_ERROR", entry.Text));
			UI.PlaySound("UI_WB_Placement_Failed");
		end
	end
end

-- ===========================================================================
local m_ContinentPlots : table = {};

-- ===========================================================================
function OnContinentToolEntered()
	if m_Mode ~= nil and m_Mode.Tab == Controls.PlaceContinent then
		LuaEvents.WorldBuilder_ContinentTypeEdited.Add(OnContinentTypeEdited);

		local pOverlay:object = UILens.GetOverlay("Worldbuilder_Continent_Overlay");
		if pOverlay ~= nil then
			pOverlay:ClearAll();
			pOverlay:SetVisible(true);

			for loopNum, entry in pairs(m_ContinentTypeEntries) do
				local ContinentColor:number = UI.GetColorValue("COLOR_" .. entry.Type.PrimaryKey);
				local ContinentPlots = WorldBuilder.MapManager():GetContinentPlots(entry.Type.Index);
				if (table.count(ContinentPlots) > 0) then
					pOverlay:HighlightColoredHexes(ContinentPlots, ContinentColor, 1);
				end
			end
			pOverlay:SetChannelOn(1);
		else
			UI.DataError("Unable to obtain the overlay: WorldBuilder_Continent_Overlay");
		end
	end
end

-- ===========================================================================
function OnContinentToolLeft()
	LuaEvents.WorldBuilder_ContinentTypeEdited.Remove(OnContinentTypeEdited);
	local pOverlay:object = UILens.GetOverlay("Worldbuilder_Continent_Overlay");
	if pOverlay ~= nil then
		pOverlay:ClearAll();
		pOverlay:SetVisible(false);
	end
end

-- ===========================================================================
function OnContinentTypeSelected( entry )
end

-- ===========================================================================
function OnContinentTypeEdited( plotID, continentType )
	local pOverlay:object = UILens.GetOverlay("Worldbuilder_Continent_Overlay");
	if pOverlay ~= nil then
		pOverlay:ClearAll();
		pOverlay:SetVisible(true);

		for loopNum, entry in pairs(m_ContinentTypeEntries) do
			local ContinentColor :number = UI.GetColorValue("COLOR_" .. entry.Type.PrimaryKey);
			local ContinentPlots :table = WorldBuilder.MapManager():GetContinentPlots(entry.Type.Index);
			if ContinentColor == nil then
				ContinentColor = UI.GetColorValueFromHexLiteral(0x80c00000);
			end
			if (table.count(ContinentPlots) > 0) then
				pOverlay:HighlightColoredHexes(ContinentPlots, ContinentColor, 1);
			end
		end
	end
end

-- ===========================================================================
function OnResourceTypeSelected( entry )
	if entry.Class == "RESOURCECLASS_STRATEGIC" and not IsExpansion2Active() then
		Controls.ResourceAmountStack:SetHide(false);
	else
		Controls.ResourceAmountStack:SetHide(true);
	end
end

-- ===========================================================================
--	Placement Modes
-- ===========================================================================
local m_PlacementModes : table =
{
	{ ID=WorldBuilderModes.PLACE_TERRAIN,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_TERRAIN",         Tab=Controls.PlaceTerrain,      PlacementFunc=PlaceTerrain,     PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_FEATURES,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_FEATURES",        Tab=Controls.PlaceFeatures,     PlacementFunc=PlaceFeature,     PlacementValid=PlaceFeature_Valid    },
	{ ID=WorldBuilderModes.PLACE_WONDERS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_WONDERS",         Tab=Controls.PlaceWonders,      PlacementFunc=PlaceWonder,      PlacementValid=PlaceWonder_Valid    },
	{ ID=WorldBuilderModes.PLACE_CONTINENTS,	Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CONTINENT",       Tab=Controls.PlaceContinent,    PlacementFunc=PlaceContinent,   PlacementValid=PlaceContinent_Valid, OnEntered=OnContinentToolEntered, OnLeft=OnContinentToolLeft },
	{ ID=WorldBuilderModes.PLACE_RIVERS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_RIVERS",          Tab=Controls.PlaceRivers,       PlacementFunc=PlaceRiver,       PlacementValid=nil,                  NoMouseOverHighlight=true },
	{ ID=WorldBuilderModes.PLACE_CLIFFS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CLIFFS",          Tab=Controls.PlaceCliffs,       PlacementFunc=PlaceCliff,       PlacementValid=PlaceCliff_Valid       },
	{ ID=WorldBuilderModes.PLACE_RESOURCES,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_RESOURCES",       Tab=Controls.PlaceResources,    PlacementFunc=PlaceResource,    PlacementValid=PlaceResource_Valid    },
	{ ID=WorldBuilderModes.PLACE_CITIES,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CITIES",            Tab=Controls.PlaceCity,         PlacementFunc=PlaceCity,        PlacementValid=nil                  },
	{ ID=WorldBuilderModes.PLACE_DISTRICTS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_DISTRICTS",        Tab=Controls.PlaceDistrict,     PlacementFunc=PlaceDistrict,    PlacementValid=PlaceDistrict_Valid   },
	{ ID=WorldBuilderModes.PLACE_BUILDINGS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_BUILDINGS",        Tab=Controls.PlaceBuilding,     PlacementFunc=PlaceBuilding,    PlacementValid=PlaceBuilding_Valid   },
	{ ID=WorldBuilderModes.PLACE_UNITS,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_UNITS",            Tab=Controls.PlaceUnit,         PlacementFunc=PlaceUnit,        PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_IMPROVEMENTS,	Text="LOC_WORLDBUILDER_PLACEMENT_MODE_IMPROVEMENTS",    Tab=Controls.PlaceImprovements, PlacementFunc=PlaceImprovement, PlacementValid=PlaceImprovement_Valid },
	{ ID=WorldBuilderModes.PLACE_ROUTES,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_ROUTES",          Tab=Controls.PlaceRoutes,       PlacementFunc=PlaceRoute,       PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_START_POSITIONS, Text="LOC_WORLDBUILDER_PLACEMENT_MODE_START_POSITIONS",  Tab=Controls.PlaceStartPos,     PlacementFunc=PlaceStartPos,    PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_TERRAIN_OWNER,	Text="LOC_WORLDBUILDER_PLACEMENT_MODE_OWNER",           Tab=Controls.PlaceOwnership,    PlacementFunc=PlaceOwnership,   PlacementValid=nil                   },
	{ ID=WorldBuilderModes.SET_VISIBILITY,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_SET_VISIBILITY",	Tab=Controls.PlaceVisibility,   PlacementFunc=PlaceVisibility,  PlacementValid=nil,                  OnEntered=OnVisibilityToolEntered, OnLeft=OnVisibilityToolLeft },
};

local m_BasicPlacementModes : table =
{
	{ ID=WorldBuilderModes.PLACE_TERRAIN,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_TERRAIN",         Tab=Controls.PlaceTerrain,      PlacementFunc=PlaceTerrain,     PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_FEATURES,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_FEATURES",        Tab=Controls.PlaceFeatures,     PlacementFunc=PlaceFeature,     PlacementValid=PlaceFeature_Valid    },
	{ ID=WorldBuilderModes.PLACE_WONDERS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_WONDERS",         Tab=Controls.PlaceWonders,      PlacementFunc=PlaceWonder,      PlacementValid=PlaceWonder_Valid    },
	{ ID=WorldBuilderModes.PLACE_CONTINENTS,	Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CONTINENT",       Tab=Controls.PlaceContinent,    PlacementFunc=PlaceContinent,   PlacementValid=PlaceContinent_Valid, OnEntered=OnContinentToolEntered, OnLeft=OnContinentToolLeft },
	{ ID=WorldBuilderModes.PLACE_RIVERS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_RIVERS",          Tab=Controls.PlaceRivers,       PlacementFunc=PlaceRiver,       PlacementValid=nil,                  NoMouseOverHighlight=true },
	{ ID=WorldBuilderModes.PLACE_CLIFFS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CLIFFS",          Tab=Controls.PlaceCliffs,       PlacementFunc=PlaceCliff,       PlacementValid=PlaceCliff_Valid       },
	{ ID=WorldBuilderModes.PLACE_RESOURCES,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_RESOURCES",       Tab=Controls.PlaceResources,    PlacementFunc=PlaceResource,    PlacementValid=PlaceResource_Valid    },
	{ ID=WorldBuilderModes.PLACE_CITIES,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CITIES",            Tab=Controls.PlaceCity,         PlacementFunc=PlaceCity,        PlacementValid=nil                  },
	{ ID=WorldBuilderModes.PLACE_DISTRICTS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_DISTRICTS",        Tab=Controls.PlaceDistrict,     PlacementFunc=PlaceDistrict,    PlacementValid=PlaceDistrict_Valid   },
	{ ID=WorldBuilderModes.PLACE_BUILDINGS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_BUILDINGS",        Tab=Controls.PlaceBuilding,     PlacementFunc=PlaceBuilding,    PlacementValid=PlaceBuilding_Valid   },
	{ ID=WorldBuilderModes.PLACE_UNITS,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_UNITS",            Tab=Controls.PlaceUnit,         PlacementFunc=PlaceUnit,        PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_IMPROVEMENTS,	Text="LOC_WORLDBUILDER_PLACEMENT_MODE_GOODY_HUTS",		Tab=Controls.PlaceGoodyHuts,	PlacementFunc=PlaceGoodyHut,	PlacementValid=PlaceGoodyHut_Valid },
	{ ID=WorldBuilderModes.PLACE_ROUTES,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_ROUTES",          Tab=Controls.PlaceRoutes,       PlacementFunc=PlaceRoute,       PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_START_POSITIONS, Text="LOC_WORLDBUILDER_PLACEMENT_MODE_START_POSITIONS",  Tab=Controls.PlaceStartPos,     PlacementFunc=PlaceStartPos,    PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_TERRAIN_OWNER,	Text="LOC_WORLDBUILDER_PLACEMENT_MODE_OWNER",           Tab=Controls.PlaceOwnership,    PlacementFunc=PlaceOwnership,   PlacementValid=nil                   },
	{ ID=WorldBuilderModes.SET_VISIBILITY,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_SET_VISIBILITY",	Tab=Controls.PlaceVisibility,   PlacementFunc=PlaceVisibility,  PlacementValid=nil,                  OnEntered=OnVisibilityToolEntered, OnLeft=OnVisibilityToolLeft },
};

local m_PlacementModesByID = {};

-- ==========================================================================
function SelectPlacementTab()
	-- Make sure this tab is visibile
	if not ContextPtr:IsVisible() then
		-- Get our parent tab container.
		local pParent = ContextPtr:GetParentByType("TabControl");
		if pParent ~= nil then
			pParent:SelectTabByID(ContextPtr:GetID());
		end
	end
end

local ms_eNextMode = WorldBuilderModes.INVALID;
local ms_kNextModeParams = nil;

-- ===========================================================================
function OnWorldBuilderModeChangeRequest(eMode, kParams)

	-- Store the request, then send out an event to handle it.
	-- Doing this in a deferred way prevents any issue with changing modes at a 'bad' time, such as
	-- while handling a UI control callback.  However, it does mean that we must be careful
	-- because there will be time for anything to happen btween the time we send the event and it getting handled.

	ms_eNextMode = eMode;
	ms_kNextModeParams = kParams;

	Events.WorldBuilderSignal(WorldBuilderSignals.MODE_CHANGE);
end

-- ===========================================================================
function SelectMode(id)
	for i,entry in ipairs(m_PlacementModes) do
		if entry.ID == id then
			Controls.PlacementPullDown:SetSelectedIndex(i, true);
			break;
		end
	end
end

-- ===========================================================================
--	LuaEvent
-- ===========================================================================
function OnToolSelectMode( worldBuilderModeId:number )	
	SelectPlacementTab();
	SelectMode( worldBuilderModeId );
end

-- ===========================================================================
function SelectDistrictType(typeHash)

	for i,entry in ipairs(m_DistrictTypeEntries) do
		if entry.Type.Hash == typeHash then
			Controls.DistrictPullDown:SetSelectedIndex(i, true);
			break;
		end
	end

end

-- ===========================================================================
function SelectBuildingType(typeHash)

	for i,entry in ipairs(m_DistrictTypeEntries) do
		if entry.Type.Hash == typeHash then
			Controls.BuildingPullDown:SetSelectedIndex(i, true);
			break;
		end
	end

end

-- ===========================================================================
function SelectCityOwner(playerIndex)
	for i, entry in pairs(m_ScenarioPlayerEntries) do
		if playerIndex == entry.PlayerIndex then
			Controls.CityOwnerPullDown:SetSelectedIndex(i, true);
			break;
		end
	end
end

-- ===========================================================================
function OnWorldBuilderSignal(eType)

	if (eType == WorldBuilderSignals.MODE_CHANGE) then

		local eMode = ms_eNextMode;
		local kParams = ms_kNextModeParams;

		-- Remove the reference now, in case the mode change triggers another mode change.
		ms_eNextMode = WorldBuilderModes.INVALID;
		ms_kNextModeParams = nil;

		-- Hide UI
		LuaEvents.WorldBuilder_ShowPlayerEditor( false );

		-- Make sure this tab is visible
		SelectPlacementTab();

		-- Switch
		if eMode == WorldBuilderModes.PLACE_DISTRICTS then
			-- Select the mode
			SelectMode(eMode);
			-- Select the mode's sub-items
			SelectDistrictType(kParams.DistrictType);
		elseif eMode == WorldBuilderModes.PLACE_BUILDINGS then
			-- Select the mode
			SelectMode(eMode);
			-- Select the mode's sub-items
			SelectBuildingType(kParams.BuildingType);
		elseif eMode == WorldBuilderModes.PLACE_CITIES then
			-- Select the mode
			SelectMode(eMode);
			-- Select the mode's sub-items
			SelectCityOwner(kParams.PlayerID);
		end

	end
		
end

-- ===========================================================================
function OnUpdate(deltaTime:number)
	if m_RegenDelay > 0 then
		m_RegenDelay = m_RegenDelay - deltaTime;

		if m_RegenDelay <= 0 then
			m_RegenDelay = 0;

			-- and run the generate
			local resourcesConfig = MapConfiguration.GetValue("resources");
			local args = {
				resources = resourcesConfig,
			};
			local resGen = WorldBuilderResourceGenerator.Create(args);
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_RESOURCES_SCATTERED"));
			WorldBuilder.EndUndoBlock();
			LuaEvents.WorldBuilder_PaintOpCompleted();
			Controls.GenResourcesActive:SetHide(true);
		end
	end

	if m_RefreshResDelay > 0 then
		m_RefreshResDelay = m_RefreshResDelay - deltaTime;

		if m_RefreshResDelay <= 0 then
			m_RefreshResDelay = 0;

			LuaEvents.WorldBuilder_PaintOpCompleted();
		end
	end
end

-- ===========================================================================
function OnRegenResources()
	WorldBuilder.StartUndoBlock();
	for plotIndex = 0, Map.GetPlotCount()-1, 1 do
		local plot = Map.GetPlotByIndex(plotIndex);
		WorldBuilder.MapManager():SetResourceType(plot, NO_RESOURCE);
	end
	WorldBuilder.EndUndoBlock();
	m_RefreshResDelay = 3;
	LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_RESOURCES_CLEARED"));
end

-- ===========================================================================
function OnGenResources()
	Controls.GenResourcesActive:SetHide(false);
	WorldBuilder.StartUndoBlock();
	for plotIndex = 0, Map.GetPlotCount()-1, 1 do
		local plot = Map.GetPlotByIndex(plotIndex);
		WorldBuilder.MapManager():SetResourceType(plot, NO_RESOURCE);
	end

	m_RegenDelay = 5;
end

-- ===========================================================================
function OnAdvancedModeChanged()
	if not WorldBuilder.GetWBAdvancedMode() then
		Controls.PlacementPullDown:SetEntries( m_BasicPlacementModes, 1 );
		for i,tabEntry in ipairs(m_BasicPlacementModes) do
			m_TabButtons[tabEntry.Tab] = tabEntry.Button;
		end

		for i,entry in ipairs(m_BasicPlacementModes) do
			m_PlacementModesByID[entry.ID] = entry;
		end

		if m_Mode.ID == WorldBuilderModes.PLACE_IMPROVEMENTS then
			Controls.ItemsContainer:SetHide(true);
		end
	else
		Controls.PlacementPullDown:SetEntries( m_PlacementModes, 1 );
		for i,tabEntry in ipairs(m_PlacementModes) do
			m_TabButtons[tabEntry.Tab] = tabEntry.Button;
		end

		for i,entry in ipairs(m_PlacementModes) do
			m_PlacementModesByID[entry.ID] = entry;
		end

		if m_Mode.ID == WorldBuilderModes.PLACE_IMPROVEMENTS then
			Controls.ItemsContainer:SetHide(false);
		end
	end
	Controls.PlacementPullDown:SetEntrySelectedCallback( OnPlacementTypeSelected );

	UpdatePlayerEntries();
	UpdateCityEntries();
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.WorldInput_WBSelectPlot.Remove( OnPlotSelected );
	LuaEvents.WorldInput_WBMouseOverPlot.Remove( OnPlotMouseOver );
	LuaEvents.WorldBuilderModeChangeRequest.Remove( OnWorldBuilderModeChangeRequest );
	LuaEvents.WorldBuilder_PlayerAdded.Remove( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_PlayerRemoved.Remove( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_PlayerEdited.Remove( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_ModeChanged.Remove( OnAdvancedModeChanged );
	LuaEvents.WorldBuilderToolsPalette_ChangeTool.Remove( OnToolSelectMode );
	LuaEvents.WorldBuilder_ExitFSMap.Remove( OnShow );

	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "IsVisible", ContextPtr:IsVisible());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "MouseOverPlot", m_MouseOverlot);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "BrushSize", m_BrushSize);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "BrushEnabled", m_BrushEnabled);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "InUndo", m_InAnUndoGroup);
end

-- ===========================================================================
function OnUndo()
	if WorldBuilder.CanUndo() then
		WorldBuilder.Undo();
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_UNDO"));
	else
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_CANT_UNDO"));
	end
end

-- ===========================================================================
function OnRedo()
	if WorldBuilder.CanRedo() then
		WorldBuilder.Redo();
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_REDO"));
	else
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_CANT_REDO"));
	end
end

-- ===========================================================================
function OnExitFSMap()
	local pParent = ContextPtr:GetParentByType("TabControl");
	if pParent ~= nil then
		local selID : string = pParent:GetSelectedTabID();
		if selID == "WorldBuilderPlacement" then
			OnShow();
		end
	end
end

-- ===========================================================================
function OnDistrictAddedToMap( playerID:number, districtID:number, cityID:number, districtX:number, districtY:number, districtType:number, percentComplete:number )
	if m_Mode ~= nil and m_Mode.ID == WorldBuilderModes.PLACE_DISTRICTS then
		local pDistrict:table = Players[playerID]:GetDistricts():FindID(districtID);
		if pDistrict ~= nil then
			WorldBuilder.CityManager():SetDistrictValue(pDistrict, DISTRICT_VALUE_PILLAGED, Controls.DistrictPillagedCheck:IsChecked());
		end
	end
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()
	local idx : number = 1;

	-- TechList
	for type in GameInfo.Technologies() do
		table.insert(m_TechEntries, { Text=type.Name, Type=type, PrimaryKey=type.PrimaryKey });
	end

	-- CivicsList
	for type in GameInfo.Civics() do
		table.insert(m_CivicEntries, { Text=type.Name, Type=type, PrimaryKey=type.PrimaryKey });
	end

	-- PlacementPullDown
	if not WorldBuilder.GetWBAdvancedMode() then
		Controls.PlacementPullDown:SetEntries( m_BasicPlacementModes, 1 );
	else
		Controls.PlacementPullDown:SetEntries( m_PlacementModes, 1 );
	end
	Controls.PlacementPullDown:SetEntrySelectedCallback( OnPlacementTypeSelected );

	-- Track Tab Buttons
	for i,tabEntry in ipairs(m_PlacementModes) do
		m_TabButtons[tabEntry.Tab] = tabEntry.Button;
	end

	for i,entry in ipairs(m_PlacementModes) do
		m_PlacementModesByID[entry.ID] = entry;
	end

	-- TerrainPullDown
	idx = 1;
	for type in GameInfo.Terrains() do
		table.insert(m_TerrainTypeEntries, { Text=type.Name, Type=type, PrimaryKey=type.PrimaryKey });
		if type.Name == "LOC_TERRAIN_COAST_NAME" then
			m_CoastIndex = idx;
		end
		idx = idx + 1;
	end
	Controls.TerrainPullDown:SetEntries( m_TerrainTypeEntries, 1 );
	Controls.TerrainPullDown:SetHide(true);

	-- FeaturePullDown
	idx = 1;
	for type in GameInfo.Features() do
		if type.NaturalWonder then
			table.insert(m_WonderTypeEntries, { Text=type.Name, Type=type, Index = idx, PrimaryKey=type.PrimaryKey, NaturalWonder=type.NaturalWonder });
		else
			table.insert(m_FeatureTypeEntries, { Text=type.Name, Type=type, Index = idx, PrimaryKey=type.PrimaryKey, NaturalWonder=type.NaturalWonder });
		end
		idx = idx + 1;
	end
	table.sort(m_FeatureTypeEntries, function(a, b)
		  return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );
	Controls.FeaturePullDown:SetEntries( m_FeatureTypeEntries, 1 );
	Controls.FeaturePullDown:SetHide(true);
	table.sort(m_WonderTypeEntries, function(a, b)
		  return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );
	Controls.WonderPullDown:SetEntries( m_WonderTypeEntries, 1 );
	Controls.WonderPullDown:SetHide(true);

	-- ContinentPullDown
	for type in GameInfo.Continents() do
		table.insert(m_ContinentTypeEntries, { Text=type.Description, Type=type, PrimaryKey=type.PrimaryKey });
	end
	Controls.ContinentPullDown:SetEntries( m_ContinentTypeEntries, 1 );
	Controls.ContinentPullDown:SetEntrySelectedCallback( OnContinentTypeSelected );

	-- ResourcePullDown
	idx = 1;
	for type in GameInfo.Resources() do
		if WorldBuilder.MapManager():IsImprovementPlaceable(type.Index) then
			table.insert(m_ResourceTypeEntries, { Text=type.Name, Type=type, Class=type.ResourceClassType, Index=idx, PrimaryKey=type.PrimaryKey });
		end
		idx = idx + 1;
	end
	table.sort(m_ResourceTypeEntries, function(a, b)
		return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );	
	Controls.ResourcePullDown:SetEntries( m_ResourceTypeEntries, 1 );
	Controls.ResourcePullDown:SetEntrySelectedCallback( OnResourceTypeSelected );
	Controls.ResourcePullDown:SetHide(true);

	-- UnitPullDown
	for type in GameInfo.Units() do
		table.insert(m_UnitTypeEntries, { Text=type.Name, Type=type, PrimaryKey=type.PrimaryKey });
	end
	table.sort(m_UnitTypeEntries, function(a, b)
		return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );	
	Controls.UnitPullDown:SetEntries( m_UnitTypeEntries, 1 );
	Controls.UnitPullDown:SetHide(true);

	-- ImprovementPullDown
	idx = 1;
	for type in GameInfo.Improvements() do
		table.insert(m_ImprovementTypeEntries, { Text=type.Name, Type=type, Index=idx, PrimaryKey=type.PrimaryKey });
		if type.ImprovementType == "IMPROVEMENT_GOODY_HUT" then
			table.insert(m_GoodyHutTypeEntries, { Text=type.Name, Type=type, Index=idx, PrimaryKey=type.PrimaryKey });
		end
		idx = idx + 1;
	end
	table.sort(m_ImprovementTypeEntries, function(a, b)
		return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );	
	Controls.ImprovementPullDown:SetEntries( m_ImprovementTypeEntries, 1 );
	Controls.ImprovementPullDown:SetHide(true);

	-- RoutePullDown
	for type in GameInfo.Routes() do
		table.insert(m_RouteTypeEntries, { Text=type.Name, Type=type, PrimaryKey=type.PrimaryKey });
	end
	Controls.RoutePullDown:SetEntries( m_RouteTypeEntries, 1 );

	-- DistrictPullDown
	idx = 1;
	for type in GameInfo.Districts() do
		if type.RequiresPlacement == true then
			table.insert(m_DistrictTypeEntries, { Text=type.Name, Type=type, Index=idx, PrimaryKey=type.PrimaryKey });
		end
		idx = idx + 1;
	end
	table.sort(m_DistrictTypeEntries, function(a, b)
		return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );
	Controls.DistrictPullDown:SetEntries( m_DistrictTypeEntries, 1 );
	Controls.DistrictPullDown:SetHide(true);

	-- BuildingPullDown
	idx = 1;
	for type in GameInfo.Buildings() do
		if type.RequiresPlacement ~= true then
			if type.InternalOnly == nil or type.InternalOnly == false then 
				table.insert(m_BuildingTypeEntries, { Text=type.Name, Type=type, Index=idx, PrimaryKey=type.PrimaryKey });
			end
			idx = idx + 1;
		end
    end
	table.sort(m_BuildingTypeEntries, function(a, b)
		return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );

	Controls.BuildingPullDown:SetEntries( m_BuildingTypeEntries, 1 );
	Controls.BuildingPullDown:SetHide(true);

	-- VisibilityPullDown
	Controls.VisibilityPullDown:SetEntrySelectedCallback( OnVisibilityPlayerChanged );
	Controls.VisibilityRevealAllButton:RegisterCallback( Mouse.eLClick, OnVisibilityPlayerRevealAll );

	-- Brush size
	Controls.SmallBrushButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.SmallBrushButton:RegisterCallback( Mouse.eLClick, function()
		m_BrushSize = 1; 
		Controls.SmallBrushActive:SetHide(false);
		Controls.MediumBrushActive:SetHide(true);
		Controls.LargeBrushActive:SetHide(true);
		end);
	Controls.MediumBrushButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.MediumBrushButton:RegisterCallback( Mouse.eLClick, function()
		m_BrushSize = 7; 
		Controls.SmallBrushActive:SetHide(true);
		Controls.MediumBrushActive:SetHide(false);
		Controls.LargeBrushActive:SetHide(true);
		end);
	Controls.LargeBrushButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.LargeBrushButton:RegisterCallback( Mouse.eLClick, function()
		m_BrushSize = 19; 
		Controls.SmallBrushActive:SetHide(true);
		Controls.MediumBrushActive:SetHide(true);
		Controls.LargeBrushActive:SetHide(false);
		end);

	m_BrushSize = 1; 
	Controls.SmallBrushActive:SetHide(false);
	Controls.MediumBrushActive:SetHide(true);
	Controls.LargeBrushActive:SetHide(true);

	-- Clear and Generate Resources Buttons
	Controls.RegenResourcesButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.RegenResourcesButton:RegisterCallback(Mouse.eLClick, OnRegenResources);
	Controls.GenResourcesButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.GenResourcesButton:RegisterCallback(Mouse.eLClick, OnGenResources);

	-- Undo and Redo buttons
	Controls.UndoButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.UndoButton:RegisterCallback(Mouse.eLClick, OnUndo);
	Controls.RedoButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.RedoButton:RegisterCallback(Mouse.eLClick, OnRedo);

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );
	ContextPtr:SetShutdown( OnShutdown );

	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );

	Events.CityAddedToMap.Add( UpdateCityEntries );
	Events.CityRemovedFromMap.Add( UpdateCityEntries );
	Events.DistrictAddedToMap.Add( OnDistrictAddedToMap );

	Events.WorldBuilderSignal.Add( OnWorldBuilderSignal );

	LuaEvents.WorldInput_WBSelectPlot.Add( OnPlotSelected );
	LuaEvents.WorldInput_WBMouseOverPlot.Add( OnPlotMouseOver );
	LuaEvents.WorldBuilderModeChangeRequest.Add( OnWorldBuilderModeChangeRequest );
	LuaEvents.WorldBuilder_PlayerAdded.Add( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_PlayerRemoved.Add( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_PlayerEdited.Add( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_ModeChanged.Add( OnAdvancedModeChanged );
	LuaEvents.WorldBuilderToolsPalette_ChangeTool.Add( OnToolSelectMode );
	LuaEvents.WorldBuilder_ExitFSMap.Add( OnExitFSMap );

	OnPlacementTypeSelected(m_PlacementModes[1]);
	Controls.PlacementPullDown:SetHide(true);

	ContextPtr:SetUpdate(OnUpdate);
end

ContextPtr:SetInitHandler( OnInit );