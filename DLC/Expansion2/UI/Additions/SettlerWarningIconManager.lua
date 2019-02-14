-- ===========================================================================
-- Settler Warning Icon Manager for Floods and Volcanos
-- ===========================================================================
include("InstanceManager");
include("SupportFunctions");

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_WarningInstancesIM:table = InstanceManager:new("WarningInstance", "Anchor", Controls.PlotWarningContainer);
local m_IconInstancesIM:table = InstanceManager:new("IconInstance", "Icon");

local m_HexColoringWaterAvail = UILens.CreateLensLayerHash("Hex_Coloring_Water_Availablity");
local m_AdjacencyBonusDistricts = UILens.CreateLensLayerHash("Adjacency_Bonus_Districts");

-- ===========================================================================
function GetWarningInstanceAt( pInstance:table, plotIndex:number, icon:string, tooltip:string )
	if pInstance == nil then
		-- Check if we're passed in an existing instance in case multiple warnings need to be stacked for the same tile
		pInstance = m_WarningInstancesIM:GetInstance();
		local worldX:number, worldY:number = UI.GridToWorld( plotIndex );
		pInstance.Anchor:SetWorldPositionVal( worldX, worldY, 0 );
	end

	local pIconInstance:table = m_IconInstancesIM:GetInstance(pInstance.IconStack);
	pIconInstance.Icon:SetIcon(icon);
	pIconInstance.Icon:SetToolTipString(Locale.Lookup(tooltip));

	return pInstance;
end

-- ===========================================================================
function ResetInstances()
	m_WarningInstancesIM:ResetInstances();
	m_IconInstancesIM:ResetInstances();
end

-- ===========================================================================
function RealizeWarningTiles()
	for i, ContinentID in ipairs(Map.GetContinentsInUse()) do
		ProcessPlots(Map.GetVisibleContinentPlots(ContinentID));
	end
end

-- ===========================================================================
function ProcessPlots(plots:table)
	if plots == nil then
		return;
	end

	for i,plotID in ipairs(plots) do
		local kPlot:table = Map.GetPlotByIndex(plotID);
		if kPlot == nil then
			UI.DataError("Bad plot index; could not get plot #"..tostring(plotID));
        else
			local pInstance:table = nil;
            if RiverManager.CanBeFlooded(kPlot) then
				-- Show river flood warning
				pInstance = GetWarningInstanceAt(pInstance, plotID, "ICON_ENVIRONMENTAL_EFFECTS_FLOODED", "LOC_FLOOD_WARNING_ICON_TOOLTIP");
            end
			if MapFeatureManager.CanSufferEruption(kPlot) then
				-- Show volcano warning
				pInstance = GetWarningInstanceAt(pInstance, plotID, "ICON_ENVIRONMENTAL_EFFECTS_VOLCANO", "LOC_VOLCANO_WARNING_ICON_TOOLTIP");
            end
			if not TerrainManager.IsProtected(kPlot) then
				-- Determine if we need to show a coastal flood warning
				local eCoastalLowlandType:number = TerrainManager.GetCoastalLowlandType(kPlot);
				if eCoastalLowlandType > -1 then
					local typeRow:table = GameInfo.CoastalLowlands[eCoastalLowlandType];
					if typeRow then
						local icon:string = "ICON_ENVIRONMENTAL_EFFECTS_" .. typeRow.CoastalLowlandType;
						pInstance = GetWarningInstanceAt(pInstance, plotID, icon, typeRow.Description);
					end
				end
			end
		end
	end
end

-- ===========================================================================
function ShouldAffectWarningIcons( layerNum:number )
	if layerNum==m_HexColoringWaterAvail or layerNum==m_AdjacencyBonusDistricts then 
		return true;
	else
		return false;
	end
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnLensLayerOn( layerNum:number )	
	if not ShouldAffectWarningIcons( layerNum ) then 
		return; 
	end

    ResetInstances();
	RealizeWarningTiles();
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
	if not ShouldAffectWarningIcons( layerNum ) then 
		return; 
	end

	ResetInstances();
end

-- ===========================================================================
--	
-- ===========================================================================
function Initialize()
	-- Game Events
	Events.LensLayerOn.Add( OnLensLayerOn );
	Events.LensLayerOff.Add( OnLensLayerOff );
end
Initialize();
