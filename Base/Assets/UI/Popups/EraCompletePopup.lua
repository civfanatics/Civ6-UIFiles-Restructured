-- ===========================================================================
--	EraCompletePopup
--	Full screen message to tell player when the game enters a new era.
--
--	NOTE:	
--	Not using a m_eventID handle from engine to block it's progression as
--	it will fire twice for a local player when starting at a later era.
-- ===========================================================================

include("PopupSupport");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local debugTest:boolean = false;		-- (false) when true run test on hotload
local RELOAD_CACHE_AND_LOCK_ID	:string = "EraCompletePopup";

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_lastShownEraIndex	:number = -1;
local m_isClosing			:boolean = false;


-- ===========================================================================
--	Game Engine EVENT
-- ===========================================================================
function OnEraComplete( playerIndex:number, currentEra:number )

	local localPlayer	:number = Game.GetLocalPlayer();
	local currentTurn	:number = Game.GetCurrentGameTurn();
	local gameStartTurn	:number = GameConfiguration.GetStartTurn();

	-- Check all the reasons why this shouldn't occur and bail if any are true.
	local isInvalidLocalPlayer	:boolean = localPlayer == PlayerTypes.NONE;
	local isSameEra				:boolean = currentEra == m_lastShownEraIndex;	
	local isFirstTurnOfGame		:boolean = currentTurn == gameStartTurn;
	if isInvalidLocalPlayer or isSameEra or isFirstTurnOfGame or localPlayer ~= playerIndex then
		return;	
	end

	m_lastShownEraIndex = currentEra;

	StartEraShow();
end

-- ===========================================================================
function StartEraShow()

	LockPopupSequence(RELOAD_CACHE_AND_LOCK_ID, PopupPriority.High);
	m_isClosing = false;
	
	local eraName :string = GameInfo.Eras[m_lastShownEraIndex].Name;
	Controls.EraCompletedHeader:SetText( Locale.ToUpper(eraName) );
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnShow()
	UI.PlaySound("Pause_TechCivic_Speech");
	UI.PlaySound("UI_Era_Change");
	
	Controls.EraPopupAnimation:SetToBeginning();
	Controls.EraPopupAnimation:Play();

	Controls.HeaderAlpha:SetToBeginning();
	Controls.HeaderAlpha:Play();

	Controls.HeaderSlide:SetBeginVal(0,100);
	Controls.HeaderSlide:SetEndVal(0,0);
	Controls.HeaderSlide:SetToBeginning();
	Controls.HeaderSlide:Play();
end


-- ===========================================================================
function OnEraPopupAnimationEnd()
	if m_isClosing then return; end	-- Already closing, ignore any anim callbacks.

	if Controls.EraPopupAnimation:IsReversing() then
		Close();
	else
		Controls.EraPopupAnimation:Reverse();			-- About to bounce back;
	end	
end

-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal()
	Controls.GradientT:SetSizeX(screenX);
	Controls.GradientB:SetSizeX(screenX);
end

-- ===========================================================================
function Close()
	if not m_isClosing then
		m_isClosing = true;
		UnlockPopupSequence();
		Controls.EraPopupAnimation:Stop();
		Controls.HeaderSlide:Stop();		
	end
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE then
		Close();
		return true;
	end
	return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end 

-- ===========================================================================
--	Resize Handler
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )
  if type == SystemUpdateUI.ScreenResize then
	Resize();
  end
end

-- ===========================================================================
--	LUA Event
--	Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context ~= RELOAD_CACHE_ID then
		return;
	end
	
	m_lastShownEraIndex = contextTable["m_lastShownEraIndex"];
	if (contextTable["isHidden"]==false) then
		StartEraShow()
	end
end


-- ===========================================================================
--	UI Event Handler
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload or debugTest then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_AND_LOCK_ID);				
	end
end

-- ===========================================================================
--	UI Event Handler
-- ===========================================================================
function OnShutdown()
	if IsLocked() then
		UnlockPopupSequence();
	end
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_AND_LOCK_ID, "isHidden", ContextPtr:IsHidden() );
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_AND_LOCK_ID, "m_lastShownEraIndex", m_lastShownEraIndex );
end

-- ===========================================================================
function Initialize()

	if GameConfiguration.IsNetworkMultiplayer() then
		return;
	end

	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );

	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

	Controls.EraPopupAnimation:RegisterEndCallback( OnEraPopupAnimationEnd );

	Events.SystemUpdateUI.Add( OnUpdateUI );	
	Events.PlayerEraChanged.Add( OnEraComplete );
end
Initialize();