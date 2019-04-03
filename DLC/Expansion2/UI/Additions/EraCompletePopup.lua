-- ===========================================================================
--	EraCompletePopup
--	Full screen message to tell player when the game enters a new era.
--
--	NOTE:	
--	Not using a m_eventID handle from engine to block it's progression as
--	it will fire twice for a local player when starting at a later era.
-- ===========================================================================

include("PopupManager");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local debugTest:boolean = false;		-- (false) when true run test on hotload
local RELOAD_CACHE_ID	:string = "EraCompletePopup";

local ERA_DECO:table = {
	"Frame_EraRollover_Classical",
	"Frame_EraRollover_Medieval",
	"Frame_EraRollover_Renaissance",
	"Frame_EraRollover_Industrial",
	"Frame_EraRollover_Modern",
	"Frame_EraRollover_Atomic",
	"Frame_EraRollover_Information",
	"Frame_EraRollover_Future",
};

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kPopupMgr			:table	 = ExclusivePopupManager:new("EraCompletePopupXP2");
local m_lastShownEraIndex	:number = -1;
local m_isClosing			:boolean = false;
local m_isLockMode			:boolean = false;	-- Does this lock engine processing during popup.


-- ===========================================================================
--	Game Engine EVENT
-- ===========================================================================
function OnCheckGameEraChanged()

	local localPlayer	:number = Game.GetLocalPlayer();
	local currentEra	:number = Game.GetEras():GetCurrentEra();
	local currentTurn	:number = Game.GetCurrentGameTurn();
	local eraStartTurn	:number = Game.GetEras():GetCurrentEraStartTurn();
	local gameStartTurn	:number = GameConfiguration.GetStartTurn();

	-- Check all the reasons why this shouldn't occur and bail if any are true.
	local isInvalidLocalPlayer	:boolean = localPlayer == PlayerTypes.NONE;
	local isSameEra				:boolean = currentEra == m_lastShownEraIndex;
	local isFirstTurnOfEra		:boolean = currentTurn == eraStartTurn;
	local isFirstTurnOfGame		:boolean = currentTurn == gameStartTurn;
	
	RealizeColorKey(0);
	
	if isInvalidLocalPlayer or isSameEra or (not isFirstTurnOfEra) or isFirstTurnOfGame then
		return;	
	end

	m_lastShownEraIndex = currentEra;

	StartEraShow();
end

-- ===========================================================================
function StartEraShow()
	m_isClosing = false;

	local currentEra	:number = Game.GetEras():GetCurrentEra();
	local kEraData		:table  = GameInfo.Eras[currentEra];
	local newEraName	:string = kEraData.Name;

	if ERA_DECO[currentEra]==nil then
		UI.DataError("EraComplete cannot show; there is no art associated with era #"..tostring(currentEra));
		return;
	end

	-- Early out checks are done; safe to lock.
	if m_isLockMode then		
		m_kPopupMgr:Lock( ContextPtr, PopupPriority.High );
	else
		UIManager:QueuePopup(ContextPtr, PopupPriority.High);
	end	

	Controls.EraCompletedHeader:SetText( Locale.ToUpper(newEraName) );
	Controls.TopDecoImage:SetTexture(ERA_DECO[currentEra] .. "_Top");
	Controls.BottomDecoImage:SetTexture(ERA_DECO[currentEra] .. "_Bottom");

	local eraTable:table = Game.GetEras();
	if eraTable:HasHeroicGoldenAge(localPlayer) then
		Controls.TopDecoFrame:SetTexture("Frame_EraRollover_HeroAge_Top");
		Controls.BottomDecoFrame:SetTexture("Frame_EraRollover_HeroAge_Bottom");
		Controls.FrameL:SetTexture("EraRollover_TextFrame_HeroicAgeL");
		Controls.FrameR:SetTexture("EraRollover_TextFrame_HeroicAgeR");
	elseif eraTable:HasGoldenAge(localPlayer) then
		Controls.TopDecoFrame:SetTexture("Frame_EraRollover_GoldenAge_Top");
		Controls.BottomDecoFrame:SetTexture("Frame_EraRollover_GoldenAge_Bottom");
		Controls.FrameL:SetTexture("EraRollover_TextFrame_GoldenAgeL");
		Controls.FrameR:SetTexture("EraRollover_TextFrame_GoldenAgeR");
	elseif eraTable:HasDarkAge(localPlayer) then
		Controls.TopDecoFrame:SetTexture("Frame_EraRollover_DarkAge_Top");
		Controls.BottomDecoFrame:SetTexture("Frame_EraRollover_DarkAge_Bottom");
		Controls.FrameL:SetTexture("EraRollover_TextFrame_DarkAgeL");
		Controls.FrameR:SetTexture("EraRollover_TextFrame_DarkAgeR");
	else
		Controls.TopDecoFrame:SetTexture("Frame_EraRollover_VanillaAge_Top");
		Controls.BottomDecoFrame:SetTexture("Frame_EraRollover_VanillaAge_Bottom");
		Controls.FrameL:SetTexture("EraRollover_TextFrame_NormalAgeL");
		Controls.FrameR:SetTexture("EraRollover_TextFrame_NormalAgeR");
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnShow()
	UI.PlaySound("Pause_TechCivic_Speech");
	UI.PlaySound("UI_Era_Change");
	
	RealizeColorKey(2.0);

	Controls.EraPopupAnimation:SetToBeginning();
	Controls.EraPopupAnimation:Play();

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
	m_isClosing = true;
	if m_kPopupMgr:IsLocked() then
		m_kPopupMgr:Unlock();
	else
		UIManager:DequeuePopup(ContextPtr);
	end
	Controls.EraPopupAnimation:Stop();
	Controls.HeaderSlide:Stop();		
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
function RealizeColorKey( fadeTime:number )
	local localPlayerID:number = Game.GetLocalPlayer();
	if (localPlayerID ~= nil) then
		local gameEras:table = Game.GetEras();
		if (gameEras ~= nil) then
			if (gameEras:HasGoldenAge(localPlayerID)) then
				Events.EnableColorKey("golden_age_colorkey", .3, fadeTime);
			elseif (gameEras:HasDarkAge(localPlayerID)) then
				Events.EnableColorKey("dark_age_colorkey", .5, fadeTime);
			else
				Events.DisableColorKey( fadeTime );
			end
		end
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
	m_kPopupMgr.FromTable( contextTable["m_kPopupMgr"], ContextPtr );
	if (contextTable["isHidden"]==false) then
		StartEraShow()
	end
end


-- ===========================================================================
--	UI Event Handler
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload or debugTest then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
--	UI Event Handler
-- ===========================================================================
function OnShutdown()
	if m_kPopupMgr:IsLocked() then								
		m_kPopupMgr:Unlock();
	end
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden() );
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_lastShownEraIndex", m_lastShownEraIndex );
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kPopupMgr", m_kPopupMgr.ToTable() );	
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );

	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

	Controls.EraPopupAnimation:RegisterStartCallback( function() print("START EraPopupAnimation"); end ); --??TRON debug
	Controls.EraPopupAnimation:RegisterEndCallback( OnEraPopupAnimationEnd );

	Events.SystemUpdateUI.Add( OnUpdateUI );
	
	RealizeColorKey(0);

	-- Don't show until player clicks start turn
	if GameConfiguration.IsHotseat() then
		LuaEvents.PlayerChange_Close.Add( OnCheckGameEraChanged );
	elseif not GameConfiguration.IsNetworkMultiplayer() then
		Events.LocalPlayerTurnBegin.Add( OnCheckGameEraChanged );
		m_isLockMode = true;
	end

end
Initialize();