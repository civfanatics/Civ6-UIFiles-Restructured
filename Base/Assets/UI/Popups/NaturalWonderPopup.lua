-- Copyright 2016-2018, Firaxis Games
-- Popup for Natural Wonders

include("PopupSupport");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "NaturalWonderPopup";


-- ===========================================================================
--	CONSTANTS / MEMBERS
-- ===========================================================================
local m_kQueuedPopups	:table	 = {};
local m_kCurrentPopup	:table	 = nil;
local m_eCurrentFeature	:number  = -1;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-- ===========================================================================
--	Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()

	UI.ClearTemporaryPlotVisibility("NaturalWonder");	
	UI.PlaySound("Stop_Speech_NaturalWonders");	
	
	-- Stop the camera animation if it hasn't finished already
	if (m_kCurrentPopup ~= nil) then
		Events.StopAllCameraAnimations();
	end

	local isDone:boolean  = true;

	-- Find first entry in table, display that, then remove it from the internal queue
	for i, entry in ipairs(m_kQueuedPopups) do
		ShowPopup(entry);
		table.remove(m_kQueuedPopups, i);
		isDone = false;
		break;
	end

	-- If done, restore engine processing and let the world know.
	if isDone then
		m_eCurrentFeature = -1;
		m_kCurrentPopup = nil;		
		LuaEvents.NaturalWonderPopup_Closed();	-- Signal other systems (e.g., bulk show UI)
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);		
		UILens.RestoreActiveLens();
		UnlockPopupSequence();		
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

	-- Only call once to preserve whatever lens was on before showing scene
	if(UI.GetInterfaceMode() ~= InterfaceModeTypes.CINEMATIC) then
		UILens.SaveActiveLens();
		UILens.SetActive("Cinematic");
		UI.SetInterfaceMode(InterfaceModeTypes.CINEMATIC);		
	end

	local pPlot = Map.GetPlot(kData.plotx, kData.ploty);
	if pPlot ~= nil then
		local aPlots = pPlot:GetFeature():GetPlots();
		-- Just in case the local player can't see all the plots, temporarily reveal them on the app side
		-- This includes even single plot NWs, as the NW can be completely in mid-fog, if just the underlying map was revealed to the player.
		-- This happens with city state captital reveals, etc.
		UI.AddTemporaryPlotVisibility("NaturalWonder", aPlots, RevealedState.VISIBLE);
	end

	m_eCurrentFeature = kData.Feature;
	m_kCurrentPopup = kData;
	
	UI.OnNaturalWonderRevealed(kData.plotx, kData.ploty);

	if(kData.QuoteAudio) then
		UI.PlaySound(kData.QuoteAudio);
	end

	Controls.WonderName:SetText( kData.Name );
	Controls.WonderQuoteContainer:SetHide( kData.Quote == nil );
	Controls.WonderIcon:SetIcon( "ICON_".. kData.TypeName);
	if kData.Quote ~= nil then
		Controls.WonderQuote:SetText( kData.Quote );
	end
	if kData.Description ~= nil then
		Controls.WonderIcon:SetToolTipString( kData.Description );
	end
	Controls.QuoteContainer:DoAutoSize();
end

-- ===========================================================================
--	Game EVENT
-- ===========================================================================
function OnNaturalWonderRevealed( plotx:number, ploty:number, eFeature:number, isFirstToFind:boolean )
	local localPlayer = Game.GetLocalPlayer();	
	if (localPlayer < 0) then
		return;	-- autoplay
	end

	if not Players[localPlayer]:IsHuman() then 
		return;
	end

	-- Only human players and NO hotseat
	local info:table = GameInfo.Features[eFeature];
	if info ~= nil then

		local quote :string = nil;
		if info.Quote ~= nil then
			quote = Locale.Lookup(info.Quote);
		end

		local description :string = nil;
		if info.Description ~= nil then
			description = Locale.Lookup(info.Description);
		end
			
		local kData:table = { 			
			Feature		= eFeature,
			Name		= Locale.ToUpper(Locale.Lookup(info.Name)),
			Quote		= quote,
			QuoteAudio	= info.QuoteAudio,
			Description	= description,
			TypeName	= info.FeatureType,
			plotx		= plotx,
			ploty		= ploty
		}

		-- Add to queue if already showing a popup
		if not IsLocked() then								
			LockPopupSequence( "NaturalWonder", PopupPriority.High );
			ShowPopup( kData );
			LuaEvents.NaturalWonderPopup_Shown();	-- Signal other systems (e.g., bulk hide UI)
		else		
			
			-- Prevent DUPES when bulk showing; only happen during force reveal?
			for _,kExistingData in ipairs(m_kQueuedPopups) do
				if kExistingData.Feature == eFeature then
					return;		-- Already have a popup for this feature queued then just leave.
				end
			end
			if m_eCurrentFeature ~= eFeature then
				table.insert(m_kQueuedPopups, kData);	
			end
		end
			
	end
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if IsLocked() then
		m_kQueuedPopups = {};	-- Ensure queue is empty to close immediately.
		Close();
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
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kCurrentPopup", m_kCurrentPopup);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_popupSupportEventID", m_popupSupportEventID);	-- In popupsupport
	if not ContextPtr:IsHidden() then
		UILens.RestoreActiveLens();
	end
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["isHidden"] ~= nil and contextTable["isHidden"] == false then
			UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
			if contextTable["m_kCurrentPopup"] ~= nil then
				m_kCurrentPopup = contextTable["m_kCurrentPopup"];
				ShowPopup(m_kCurrentPopup);
			end
		end
		m_popupSupportEventID = contextTable["m_popupSupportEventID"];
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
	if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end

-- ===========================================================================
--	Initialize the context
-- ===========================================================================
function Initialize()

	-- Because these popup movies lock the engine until complete; disable 
	-- them if playing in any type of multiplayer game.
	if GameConfiguration.IsAnyMultiplayer() or GameConfiguration.IsHotseat() then
		return;
	end

	ContextPtr:SetInputHandler( OnInputHander, true );
	Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);
	
	Events.NaturalWonderRevealed.Add( OnNaturalWonderRevealed );
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );	
	Events.CameraAnimationStopped.Add( OnCameraAnimationStopped );
	Events.CameraAnimationNotFound.Add( OnCameraAnimationNotFound );

	-- Hot-Reload Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );

end
Initialize();
