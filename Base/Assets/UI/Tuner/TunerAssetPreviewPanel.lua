g_PanelHasFocus = false;
-------------------------------------------------------------------------------

g_SelectedInstanceID = -1;
g_SortList = true;
g_FilterString = "";
g_MoveIncrement = 1;
g_RotateIncrement = 15;
g_ScaleIncrement = 0.1;
g_AnimStateFrom = "ANY";
g_AnimStateTo = "ANY";
g_AssetState = "";

g_AssetPlacement =
{
	Type = "",
	Scale = 1.0,
	Orientation = 0.0,
	
	Place =
	function(plot, worldX, worldY, worldZ)
		if (g_AssetPlacement.Type ~= "") then
			local id = AssetPreview.Create(g_AssetPlacement.Type, worldX, worldY);
			if (id >= 0) then
				AssetPreview.SetInstanceScale(id, g_AssetPlacement.Scale);
				local orientationRad = g_AssetPlacement.Orientation * 0.01745329251994329576923690768489;
				AssetPreview.SetInstanceOrientation(id, orientationRad);
			end
		end
	end,
	
	Remove =
	function(plot, worldX, worldY, worldZ)
		AssetPreview.DestroyAt(plot);
	end
}
g_AssetMovement =
{
	Place =
	function(plot, worldX, worldY, worldZ)
		if (g_SelectedInstanceID ~= -1) then
			AssetPreview.SetInstancePosition(g_SelectedInstanceID, worldX, worldY);
			AssetPreview.SetInstanceAssetState(g_SelectedInstanceID, g_AssetState);
			AssetPreview.SetInstanceAnimation(g_SelectedInstanceID, g_AnimStateFrom, g_AnimStateTo);
		end
	end,
	
	Remove =
	function(plot, worldX, worldY, worldZ)
		AssetPreview.DestroyAt(plot);
	end
}

g_LandmarkPlacement = 
{
	Type = "Nothing",
	Place = function() print( "Dummy Place" ); end,
	Remove = function( plot, x, y, z )
			AssetPreview.ClearLandmarkAt( plot:GetX(), plot:GetY() );
		end
}

-------------------------------------------------------------------------------
g_PlacementSettings =
{
	Active = false,
	PlacementHandler = g_AssetPlacement
}

-------------------------------------------------------------------------------
function OnLButtonUp( plotX, plotY, worldX, worldY, worldZ )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );

		if (g_PlacementSettings.Active == true and			
			type(g_PlacementSettings) == "table" and
			type(g_PlacementSettings.PlacementHandler) == "table" and
			type(g_PlacementSettings.PlacementHandler.Place) == "function") then
	        
			g_PlacementSettings.PlacementHandler.Place(plot, worldX, worldY, worldZ);
			return; -- Do not change auto-exit the debug mode
		end
	
		LuaEvents.TunerExitDebugMode();
	end
	return;
end

LuaEvents.TunerMapLButtonUp.Add(OnLButtonUp);

-------------------------------------------------------------------------------
function OnRButtonDown( plotX, plotY, worldX, worldY, worldZ )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );

		if (g_PlacementSettings.Active == true and			
			type(g_PlacementSettings) == "table" and
			type(g_PlacementSettings.PlacementHandler) == "table" and
			type(g_PlacementSettings.PlacementHandler.Remove) == "function") then
	        
			g_PlacementSettings.PlacementHandler.Remove(plot, worldX, worldY, worldZ);
			return; -- Do not change auto-exit the debug mode
		end
	
		LuaEvents.TunerExitDebugMode();
	end
	return;
end

LuaEvents.TunerMapRButtonDown.Add(OnRButtonDown);

-------------------------------------------------------------------------------
function OnUIDebugModeEntered()
	if (g_PanelHasFocus == true) then
		g_PlacementSettings.Active = true;
	end
end

LuaEvents.UIDebugModeEntered.Add(OnUIDebugModeEntered);

-- Globals for Landmarks asset visualization
g_SelectedEra = nil;
g_SelectedCiv = nil;
g_SelectedState = "Worked";
g_SelectedAppeal = 0;
g_SelectedPopulation = 0;
g_SelectedDistrictIdx = 0;
g_SelectedDistrictBaseName = nil;
g_SelectedDistrictBldgName = nil;
g_AddCitySpacing = true;


-- Exposure for City panel to be able to spoof different city civilizations without changing panels.
-- (Spoofing is an app-side operation, while the City panel is game-side)
function OnSetCityCiv( x, y, civ )
	AssetPreview.SpoofCityCivAt( x, y, civ );
end
LuaEvents.SetCityCiv.Add( OnSetCityCiv );