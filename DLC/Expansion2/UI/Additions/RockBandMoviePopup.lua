-- Copyright 2016-2018, Firaxis Games
-- TODO: Use lock system
include("InputSupport");


-- ===========================================================================
--	CONSTANTS / MEMBERS
-- ===========================================================================
local m_isWaitingToShowPopup:boolean = false;
local m_kQueuedPopups		:table	 = {};
local m_kCurrentPopup		:table	 = nil;
local ms_eventID			:number	 = 0;
local m_unitID				:number = 0;
local m_ownerID				:number = -1;
local RELOAD_CACHE_ID:string = "RockBandMoviePopup";

local ROCK_BAND_NAME_GRID_MARGIN:number = 20;
local ROCK_BAND_NAME_GRID_MINIMUM_SIZE:number = 415;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================
-- ===========================================================================
--	Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()

	UI.PlaySound("Stop_RockBand");

	UI.ClearTemporaryPlotVisibility("RockBand");
	
	-- Release our hold on the event
	UI.ReleaseEventID( ms_eventID );
	ms_eventID = 0;
	Input.PopContext();
	UIManager:DequeuePopup( ContextPtr );
	local isNewOneSet = false;
	
	-- Stop the camera animation if it hasn't finished already
	if (m_kCurrentPopup ~= nil) then
		Events.StopAllCameraAnimations();
		Events.UnitStopCinematicAnimation( "IDLE", m_ownerID, m_unitID, m_kCurrentPopup.plotx, m_kCurrentPopup.ploty);
	end

	-- Find first entry in table, display that, then remove it from the internal queue
	for i, entry in ipairs(m_kQueuedPopups) do
		ShowPopup(entry);
		table.remove(m_kQueuedPopups, i);
		isNewOneSet = true;
		break;
	end

	if not isNewOneSet then
		LuaEvents.RockBandMoviePopup_OpenRockBandPopup(m_ownerID, m_kCurrentPopup.unit, m_kCurrentPopup.resultID, m_kCurrentPopup.tourism);		
		m_isWaitingToShowPopup = false;	
		m_kCurrentPopup = nil;
		LuaEvents.RockBandMoviePopup_Closed();	-- Signal other systems (e.g., bulk show UI)
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);		
		UILens.RestoreActiveLens();
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
function ShowPopup( kData:table )

	if(UI.GetInterfaceMode() ~= InterfaceModeTypes.CINEMATIC) then
		UILens.SaveActiveLens();
		UILens.SetActive("Cinematic");
		UI.SetInterfaceMode(InterfaceModeTypes.CINEMATIC);		
	end
	
	UIManager:QueuePopup( ContextPtr, PopupPriority.High );
	Input.PushActiveContext( InputContext.Reveal );

	local pPlot:table = Map.GetPlot(kData.plotx, kData.ploty);
	if pPlot ~= nil then
		local aPlots = pPlot:GetFeature():GetPlots();
		-- Just in case the local player can't see all the plots, temporarily reveal them on the app side
		-- This includes even single plot NWs, as the NW can be completely in mid-fog, if just the underlying map was revealed to the player.
		-- This happens with city state captital reveals, etc.
		UI.AddTemporaryPlotVisibility("RockBand", aPlots, RevealedState.VISIBLE);
	end

	m_isWaitingToShowPopup = true;
	m_kCurrentPopup = kData;
	
	UI.LookAtPlotScreenPosition( kData.plotx, kData.ploty, 0.5, 0.5 );
	Events.PlayCameraAnimationAtHex( "ROCK_BAND_CONCERT_CAMERA", kData.plotx, kData.ploty, 0.0, true );
	Events.UnitPlayCinematicAnimation( "ACTION_1", kData.owner, kData.unit, kData.plotx, kData.ploty);

	Controls.RockBandName:SetText(kData.Name);
	local gridSize:number = Controls.RockBandName:GetSizeX() + ROCK_BAND_NAME_GRID_MARGIN;
	Controls.RockBandNameGrid:SetSizeX(math.max(gridSize, ROCK_BAND_NAME_GRID_MINIMUM_SIZE));
	Controls.RockBandLevel:SetText(kData.rockLevel);
end

-- ===========================================================================
--
-- ===========================================================================
function OnRockBandConcert( ownerID:number, unitID:number, unitX:number, unitY:number, result:number, totalTourism:number )
	local localPlayer:number = Game.GetLocalPlayer();	
	if (localPlayer < 0 or ownerID ~= localPlayer) then
		return;	-- autoplay
	end

	-- No Rockband popups in multiplayer games.
	if(GameConfiguration.IsAnyMultiplayer()) then
		return;
	end

	-- Only human players and NO hotseat
	local pPlayer:table = Players[localPlayer];
	if pPlayer:IsHuman() and not GameConfiguration.IsHotseat() then
		local pUnit:table = pPlayer:GetUnits():FindID(unitID);
		if pUnit ~= nil then
			local pRockBand:table = pUnit:GetRockBand();			
			local kData:table = { 
				Name		= Locale.ToUpper(pUnit:GetName()),
				plotx		= unitX,
				ploty		= unitY,
				rockLevel	= pRockBand:GetRockBandLevel(),
				tourism		= totalTourism,
				resultID	= result,
				unit		= unitID,
				owner		= ownerID
			}

			-- Add to queue if already showing a popup
			if not m_isWaitingToShowPopup then				
				ms_eventID = UI.ReferenceCurrentEvent();
				ShowPopup( kData );
				LuaEvents.RockBandMoviePopup_Shown();	-- Signal other systems (e.g., bulk hide UI)
			end

			m_ownerID = ownerID;
			m_unitID = unitID;
		end	
	end
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if (not ContextPtr:IsHidden()) and GameConfiguration.IsHotseat() then
		OnClose();
	end
end

-- ===========================================================================
function OnCameraAnimationStopped(name : string)
	if (m_kCurrentPopup ~= nil) then
		UI.LookAtPlot(m_kCurrentPopup.plotx, m_kCurrentPopup.ploty, 0.0, 0.0, true);
	end
end

-- ===========================================================================
function OnCameraAnimationNotFound()
	if (m_kCurrentPopup ~= nil) then
		-- this will play if the animation doesnt exist
		UI.LookAtPlot(m_kCurrentPopup.plotx, m_kCurrentPopup.ploty);
	end
end

-- ===========================================================================
--	Native Input / ESC support
-- ===========================================================================
function KeyHandler( key:number )
    if key == Keys.VK_ESCAPE then
		Close();
		return true;
    end
    return false;
end
function OnInputHander( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if (uiMsg == KeyEvents.KeyUp) then 
		return KeyHandler( pInputStruct:GetKey() ); 
	end;
	if (uiMsg == MouseEvents.LButtonUp) then 
		Close();
		return true;
	end
	return false;
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_ownerID", m_ownerID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_unitID", m_unitID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "ms_eventID", ms_eventID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "kData", kData);
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID and not ContextPtr:IsHidden() then
		ms_eventID = contextTable["ms_eventID"];
		local kData :table = contextTable["KData"];
		ShowPopup( KData );
		m_ownerID = contextTable["m_ownerID"];
		m_unitID = contextTable["m_unitID"];
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
--	Initialize the context
-- ===========================================================================
function Initialize()

	ContextPtr:SetInputHandler( OnInputHander, true );
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);

	Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);	
	Controls.ScreenConsumer:RegisterCallback(Mouse.eRClick, OnClose);	

	Events.PostTourismBomb.Add(OnRockBandConcert);
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );	

	Events.CameraAnimationStopped.Add( OnCameraAnimationStopped );
	Events.CameraAnimationNotFound.Add( OnCameraAnimationNotFound );
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);	
end
Initialize();