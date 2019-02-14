-- ===========================================================================
-- Adjaceny Bonuses for City Districts
-- ===========================================================================
include("InstanceManager");
include("SupportFunctions");
include("AdjacencyBonusSupport");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local PADDING_X :number = 18;
local PADDING_Y :number = 16;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_PlotBonusIM	:table = InstanceManager:new( "PlotYieldBonusInstance",	"Anchor", Controls.PlotBonusContainer );
local m_MapIcons	:table = {};

local m_UnitsMilitary : number = UILens.CreateLensLayerHash("Units_Military");
local m_DistrictsCampus : number = UILens.CreateLensLayerHash("Districts_Campus");
local m_MovementPath : number = UILens.CreateLensLayerHash("Movement_Path");
local m_MovementZoneOfControl : number = UILens.CreateLensLayerHash("Movement_Zone_Of_Control");
local m_AdjacencyBonusDistricts : number = UILens.CreateLensLayerHash("Adjacency_Bonus_Districts");
local m_EmpireDetails : number = UILens.CreateLensLayerHash("Empire_Details");

-- ===========================================================================
function RealizeIconStack(instance:table)
	instance.IconStack:CalculateSize();
	instance.IconStack:ReprocessAnchoring();
end

-- ===========================================================================
function SetYieldBonus( pInstance:table, type:number, amount:number )
	local yieldInfo = GameInfo.Yields[type];
	if yieldInfo ~= nil then
		local iconName = "ICON_" .. yieldInfo.YieldType;
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName);
		if textureSheet ~= nil then
			pInstance.AdjacencyIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
			RealizeIconStack(instance);
		end
	end
end

-- ===========================================================================
function GetInstanceAt( plotIndex:number )
	local pInstance:table = m_MapIcons[plotIndex];
	if pInstance == nil then
		pInstance = m_PlotBonusIM:GetInstance();
		m_MapIcons[plotIndex] = pInstance;
		local worldX:number, worldY:number = UI.GridToWorld( plotIndex );
		pInstance.Anchor:SetWorldPositionVal( worldX, worldY - 17, 0 );
	end
	return pInstance;
end

-- ===========================================================================
function ReleaseInstanceAt( plotIndex:number)
	local pInstance :table = m_MapIcons[plotIndex];
	if pInstance ~= nil then
		-- m_AdjacentPlotIconIM:ReleaseInstance( pInstance );
		m_MapIcons[plotIndex] = nil;
	end
end



-- ===========================================================================
--	DEBUG Helper
--	Convert a layer number to it's name.
-- ===========================================================================
function LayerToString( layerNum:number )
	local out:string;
	if		layerNum == m_UnitsMilitary			then out = "Units_Military";
	elseif	layerNum == m_DistrictsCampus		then out = "Districts_Campus";
	elseif	layerNum == m_MovementPath			then out = "Movement_Path";
	elseif	layerNum == m_MovementZoneOfControl	then out = "Movement_Zone_Of_Control";
	end
	out = out .. "("..tostring(layerNum)..")";
	return out;
end

-- ===========================================================================
--	Clear all graphics and all district yield icons for all layers.
-- ===========================================================================
function ClearEveything()
	for key,pInstance in pairs(m_MapIcons) do
		m_PlotBonusIM:ReleaseInstance( pInstance );
		m_MapIcons[key]		 = nil;
	end	
end

-- ===========================================================================
function Realize2dArtForDistrictPlacement_AllCities()

	local pLocalPlayer:table = Players[ Game.GetLocalPlayer() ];
	if pLocalPlayer ~= nil then
		for i, pCity in pLocalPlayer:GetCities():Members() do
			Realize2dArtForCityDistricts( pCity );
		end
	end
end

-- ===========================================================================
function Realize2dArtForDistrictPlacement()

	local isLayerOn:boolean = UILens.IsLayerOn(m_AdjacencyBonusDistricts);
	if not isLayerOn then
		return;
	end

	local selectedCity:table = UI.GetHeadSelectedCity();
	if selectedCity == nil then
		return;
	end

	Realize2dArtForCityDistricts( selectedCity );
end

-- ===========================================================================
function Realize2dArtForCityDistricts( pCity:table )

	local districtHash:number	= UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_DISTRICT_TYPE);
	local district				= GameInfo.Districts[districtHash];
	local buildingHash:number	= UI.GetInterfaceModeParameter(CityOperationTypes.PARAM_BUILDING_TYPE);
	local building				= GameInfo.Buildings[buildingHash];

	-- Realizing a district about to be placed?
	if district ~= nil then
		-- Show information for a district about to be placed
		local plots			:table = GetCityRelatedPlotIndexesDistrictsAlternative( pCity, districtHash );		
		for i,plotID in pairs(plots) do
			local kPlot:table =  Map.GetPlotByIndex(plotID);
			if kPlot == nil then
				UI.DataError("Bad plot index; could not get plot #"..tostring(plotID));
			else
				-- All plots that are valid for this district
				if kPlot:CanHaveDistrict(district.Index, pCity:GetOwner(), pCity:GetID()) then
					local yieldBonus:string, yieldTooltip, requirementText:string = GetAdjacentYieldBonusString( district.Index, pCity, kPlot );
					local showIfPurchaseable:boolean = IsShownIfPlotPurchaseable(district.Index, pCity, kPlot);
					if showIfPurchaseable or requirementText ~= nil then
						local instance:table = GetInstanceAt( plotID );
						instance.PlotBonus:SetHide( yieldBonus == "" );
						instance.BonusText:SetText(yieldBonus);
						instance.BonusText:SetToolTipString(yieldTooltip);
						instance.PrereqIcon:SetToolTipString(requirementText);
						instance.PrereqIcon:SetHide( requirementText == nil );
						
						local x,y = instance.BonusText:GetSizeVal();
						instance.PlotBonus:SetSizeVal( x+PADDING_X, y+PADDING_Y );			
						RealizeIconStack(instance);			
					end					
				end
			end
		end
	-- How about a wonder?
	elseif building ~= nil then
		-- Show information for a wonder about to be placed
		local plots			:table = GetCityRelatedPlotIndexesWondersAlternative( pCity, buildingHash );	
		for i,plotID in pairs(plots) do
			local kPlot:table =  Map.GetPlotByIndex(plotID);
			if kPlot == nil then
				UI.DataError("Bad plot index; could not get plot #"..tostring(plotID));
			else
				-- All plots that are valid for this wonder
				if kPlot:CanHaveWonder(building.Index, pCity:GetOwner(), pCity:GetID()) then
					local instance:table = GetInstanceAt( plotID );
					instance.PlotBonus:SetHide(true);
					instance.BonusText:SetText("");
					instance.PrereqIcon:SetHide(true);
						
					local x,y = instance.BonusText:GetSizeVal();
					instance.PlotBonus:SetSizeVal( x+PADDING_X, y+PADDING_Y );			
					RealizeIconStack(instance);			
				end
			end
		end
	-- Just show all districts
	else
		-- Show all existing adjacency bonuses districts
		local plots				:table = {};
		local variations		:table = {};
		local adjacencyYields	:table = {};
		local cityDistricts		:table = pCity:GetDistricts();

		for i, district in cityDistricts:Members() do

			local locX			:number = district:GetX();
			local locY			:number = district:GetY();
			local kPlot			:table  = Map.GetPlot(locX,locY);
			local plotID		:number = kPlot:GetIndex();

			local yieldBonus:string, yieldTooltip:string = GetAdjacentYieldBonusString( district:GetType(), pCity, kPlot );
			local showIfPurchaseable:boolean = IsShownIfPlotPurchaseable(district:GetType(), pCity, kPlot);
			if showIfPurchaseable then
				local instance:table = GetInstanceAt( plotID, m_AdjacencyBonusDistricts );
				instance.PlotBonus:SetHide( yieldBonus == "" );
				instance.BonusText:SetText(yieldBonus);
				instance.BonusText:SetToolTipString(yieldTooltip);
				instance.PrereqIcon:SetHide( true );

				local x,y = instance.BonusText:GetSizeVal();
				instance.PlotBonus:SetSizeVal( x+PADDING_X, y+PADDING_Y );
			end	
		end
	end
end

-- ===========================================================================
--	UI Event
--	Initialize / hotload support
-- ===========================================================================
function OnInit( isHotLoad:boolean )
	if isHotLoad and UILens.IsLayerOn(m_AdjacencyBonusDistricts) then
		Realize2dArtForDistrictPlacement(); 
	end
end

-- ===========================================================================
--	UI Event
--	Handle the UI shutting down.
-- ===========================================================================
function OnShutdown()
	ClearEveything();
	m_PlotBonusIM:DestroyInstances();

	-- Game Events
	Events.CitySelectionChanged.Remove( OnCitySelectionChanged );
	Events.CityMadePurchase.Remove( OnCityMadePurchase );
	Events.LensLayerOn.Remove( OnLensLayerOn );
	Events.LensLayerOff.Remove( OnLensLayerOff );
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnCityMadePurchase(owner:number, cityID:number, plotX:number, plotY:number, purchaseType, objectType)
	if owner ~= Game.GetLocalPlayer() then
		return;
	end
	if UILens.IsLayerOn( m_AdjacencyBonusDistricts ) then
		if purchaseType == EventSubTypes.PLOT then
			ClearEveything();
			Realize2dArtForDistrictPlacement();   
		end
	end
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnCitySelectionChanged(owner:number, ID:number, i:number, j:number, k:number, bSelected:boolean, bEditable:boolean)
	if owner ~= Game.GetLocalPlayer() then
		return;
	end	
	if bSelected and UILens.IsLayerOn(m_AdjacencyBonusDistricts) then
		ClearEveything();
		Realize2dArtForDistrictPlacement();
	end	
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnLensLayerOn( layerNum:number )	
	if layerNum == m_AdjacencyBonusDistricts then 
		Realize2dArtForDistrictPlacement();
	elseif layerNum == m_EmpireDetails then
		Realize2dArtForDistrictPlacement_AllCities();
	end
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
	if layerNum==m_AdjacencyBonusDistricts or layerNum == m_EmpireDetails then 
		for key,pInstance in pairs(m_MapIcons) do
			m_PlotBonusIM:ReleaseInstance( pInstance );
			m_MapIcons[key] = nil;
		end	
	end
end

-- ===========================================================================
function OnInterfaceModeChanged( oldMode:number, newMode:number )
	if newMode == InterfaceModeTypes.DISTRICT_PLACEMENT then
		if UILens.IsLayerOn(m_AdjacencyBonusDistricts) then
			-- Catch refresh of district bonuses if m_AdjacencyBonusDistricts already happens
			-- to be active. Example: Going from Empire lens to District Placement lens
			ClearEveything();
			Realize2dArtForDistrictPlacement();
		end
	end
end

-- ===========================================================================
--	
-- ===========================================================================
function Initialize()
		
	-- UI Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );

	-- Game Events
	Events.CitySelectionChanged.Add( OnCitySelectionChanged );
	Events.CityMadePurchase.Add( OnCityMadePurchase );
	Events.LensLayerOn.Add( OnLensLayerOn );
	Events.LensLayerOff.Add( OnLensLayerOff );
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
end
Initialize();
