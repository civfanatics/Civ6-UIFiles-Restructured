-- ===========================================================================
--	Copyright 2018, Firaxis Games
-- ===========================================================================

local m_toggleFullScreenMapId :number 	        = Input.GetActionId("ToggleFSMap");

-- ===========================================================================
function GetMinimapMouseCoords( mousex:number, mousey:number )
	
	-- normalized 0-1, relative to screen
	local width, height = UIManager:GetScreenSizeVal();
	local mapx = mousex / width;
	local mapy = mousey / height;
	
	return mapx, mapy;
end

-- ===========================================================================
function TranslateMinimapToWorld( mapx:number, mapy:number )
	local mapMinX, mapMinY, mapMaxX, mapMaxY = UI.GetMinimapWorldRect();

	-- Clamp coords to minimap.
	mapx = math.min( 1, math.max( 0, mapx ) );
	mapy = math.min( 1, math.max( 0, mapy ) );

	--TODO: max-min probably wont work for rects that cross world wrap! -KS
	local wx = mapMinX + (mapMaxX-mapMinX) * mapx;
	local wy = mapMinY + (mapMaxY-mapMinY) * (1 - mapy);

	return wx, wy;
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then
		local uiKey = pInputStruct:GetKey();
		if uiKey == Keys.VK_ESCAPE then
			Close();
			return true;	-- we did eat the keystroke here
		end
	end

	-- Update tooltip as the mouse is moved over the minimap
	if (uiMsg == MouseEvents.MouseMove or uiMsg == MouseEvents.PointerUpdate) and UI.IsFullscreenMapEnabled() then
		local ePlayer : number = Game.GetLocalPlayer(); 
		local pPlayerVis:table = PlayersVisibility[ePlayer];

		local minix, miniy = GetMinimapMouseCoords( pInputStruct:GetX(), pInputStruct:GetY() );
		if (pPlayerVis ~= nil) then
			local wx, wy = TranslateMinimapToWorld(minix, miniy);
			local plotX, plotY = UI.GetPlotCoordFromWorld(wx, wy);
			local pPlot = Map.GetPlot(plotX, plotY);
			if (pPlot ~= nil) then
				local plotID = Map.GetPlotIndex(plotX, plotY);
				if pPlayerVis:IsRevealed(plotID) then
					local eOwner = pPlot:GetOwner();
					local pPlayerConfig = PlayerConfigurations[eOwner];
					if (pPlayerConfig ~= nil) then
						local szOwnerString = Locale.Lookup(pPlayerConfig:GetCivilizationShortDescription());

						if (szOwnerString == nil or string.len(szOwnerString) == 0) then
							szOwnerString = Locale.Lookup("LOC_TOOLTIP_PLAYER_ID", eOwner);
						end

						local pPlayer = Players[eOwner];
						if(GameConfiguration:IsAnyMultiplayer() and pPlayer:IsHuman()) then
							szOwnerString = szOwnerString .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. ")";
						end

						local szOwner = Locale.Lookup("LOC_HUD_MINIMAP_OWNER_TOOLTIP", szOwnerString);
						Controls.MapProxy:SetToolTipString(szOwner);
					else
						local pTooltipString = Locale.Lookup("LOC_MINIMAP_UNCLAIMED_TOOLTIP");
						Controls.MapProxy:SetToolTipString(pTooltipString);
					end
				else
					local pTooltipString = Locale.Lookup("LOC_MINIMAP_FOG_OF_WAR_TOOLTIP");
					Controls.MapProxy:SetToolTipString(pTooltipString);
				end
			end
		end
	end

	return false;	-- don't eat it here though, or it causes the input actions to break
end

-- ===========================================================================
function Close()
	-- Close may be in response to an event which others are listening too as 
	-- well.  To be safe only switch back the interface mode if it's in the
	-- mode it was switched to at startup.
	if UI.GetInterfaceMode() == InterfaceModeTypes.FULLSCREEN_MAP then
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
	end
end

-- ===========================================================================
function GetPercentMapRevealed()
	local gridWidth, gridHeight = Map.GetGridSize();
	local mapMinX, mapMinY, mapMaxX, mapMaxY = UI.GetMinimapWorldRect();
	local plotMinX, plotMinY = UI.GetPlotCoordFromWorld(mapMinX, mapMinY);
	local plotMaxX, plotMaxY = UI.GetPlotCoordFromWorld(mapMaxX, mapMaxY);

	-- Early out (full exposure).
	if (plotMinX == -1 and plotMaxX == -1) then
		return 1;
	end

	-- Account for horizontal wrap
	if plotMaxX < plotMinX then
		local swapTemp:number = plotMinX;
		plotMinX = plotMaxX;
		plotMaxX = swapTemp;
	end

	-- Compute percent
	local minimapArea	:number = (plotMaxX-plotMinX) * (plotMaxY-plotMinY);
	local fullArea		:number = gridWidth * gridHeight;
	local percent		:number = math.clamp( minimapArea / fullArea, 0, 1);
	return percent;
end

-- ===========================================================================
function OnShow()	
	-- Some math to force edge gradient to be visible when the map isn't 
	-- revealed by much but will quickly fade out as world is explored.
	local revealedPercent:number = GetPercentMapRevealed();
	local alpha:number = math.clamp( 1.2 - (revealedPercent*2),0,1);
	Controls.EdgeGradient:SetAlpha( alpha );
end

-- ===========================================================================
--	Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId:number )
	if (m_toggleFullScreenMapId ~= nil and (actionId == m_toggleFullScreenMapId)) then
        UI.PlaySound("Play_UI_Click");
        if UI.GetInterfaceMode() == InterfaceModeTypes.FULLSCREEN_MAP then
            Close();
		else
			UI.SetInterfaceMode(InterfaceModeTypes.FULLSCREEN_MAP);
        end
    end
end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eOldMode == InterfaceModeTypes.FULLSCREEN_MAP then
		UIManager:DequeuePopup( ContextPtr );
		UI.ShowFullscreenMap( false );
		LuaEvents.FullscreenMap_Closed();
	end
	
	if eNewMode == InterfaceModeTypes.FULLSCREEN_MAP then
		UIManager:QueuePopup( ContextPtr, PopupPriority.MediumHigh );	
		UI.ShowFullscreenMap( true );
		LuaEvents.FullscreenMap_Shown();
	end
end

-- ===========================================================================
function LateInitialize()
end

-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler(OnInputHandler, true);
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, Close);

	Events.InputActionTriggered.Add( OnInputActionTriggered );
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
end
Initialize();
