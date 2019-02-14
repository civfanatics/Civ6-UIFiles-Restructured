-- ===========================================================================
-- Adjaceny Bonuses for City Districts
-- ===========================================================================
include("InstanceManager");
include("SupportFunctions");


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
local m_HexColoringWaterAvail : number = UILens.CreateLensLayerHash("Hex_Coloring_Water_Availablity");

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
function RealizeInfluenceTiles()

	local isLayerOn:boolean = UILens.IsLayerOn(m_HexColoringWaterAvail);
	if not isLayerOn then
		return;
	end
	
	-- Show information for a district about to be placed
	local plots			:table = Map.GetContinentPlotsLoyalty();		
	for plotID, loyaltyVal in pairs(plots) do
		local kPlot:table =  Map.GetPlotByIndex(plotID);
		if kPlot == nil then
			UI.DataError("Bad plot index; could not get plot #"..tostring(plotID));
		else
			local instance = GetInstanceAt(plotID);
			instance.PlotBonus:SetHide(false);
			instance.BonusText:SetText(loyaltyVal);
			instance.BonusText:SetToolTipString(Locale.Lookup("LOC_SETTLER_LOYALTY_WARNING_TOOLTIP", loyaltyVal));
			instance.PrereqIcon:SetToolTipString(Locale.Lookup("LOC_SETTLER_LOYALTY_WARNING_TOOLTIP", loyaltyVal));
			instance.PrereqIcon:SetHide(false);

			local x,y = instance.BonusText:GetSizeVal();
			instance.PlotBonus:SetSizeVal( x+PADDING_X, y+PADDING_Y );			

            -- apply an adjustment to prevent overlapping resource icons
            instance.PlotBonus:SetOffsetY(-48);
            instance.PrereqIcon:SetOffsetY(-48);

			RealizeIconStack(instance);	
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
	Events.LensLayerOn.Remove( OnLensLayerOn );
	Events.LensLayerOff.Remove( OnLensLayerOff );
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnLensLayerOn( layerNum:number )	
	if not (layerNum==m_HexColoringWaterAvail) then 
		return; 
	end
	RealizeInfluenceTiles();
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
	
	if not (layerNum==m_HexColoringWaterAvail) then 
		return; 
	end

	for key,pInstance in pairs(m_MapIcons) do
		m_PlotBonusIM:ReleaseInstance( pInstance );
		m_MapIcons[key] = nil;
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
	Events.LensLayerOn.Add( OnLensLayerOn );
	Events.LensLayerOff.Add( OnLensLayerOff );
end
Initialize();
