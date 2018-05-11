-- ===========================================================================
--	EraCompletePopup
--	Full screen message to tell player when the game enters a new era.
--
--	NOTE:	currently not using m_eventID since when starting a game at a later
--			era, this will fire twice for the local player, once the era before
--			and then once again after... and when this is on it will queue
--			them back-to-back
-- ===========================================================================

include( "PopupDialog" );

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local ERA_DECO:table = {
	"Frame_EraRollover_Classical",
	"Frame_EraRollover_Medieval",
	"Frame_EraRollover_Renaissance",
	"Frame_EraRollover_Industrial",
	"Frame_EraRollover_Modern",
	"Frame_EraRollover_Atomic",
	"Frame_EraRollover_Information",
};

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_LastShownEraIndex:number = -1;

-- ===========================================================================
--	Game Engine EVENT
-- ===========================================================================
function CheckGameEraChanged()

	local localPlayer:number = Game.GetLocalPlayer();

	local currentEra:number = Game.GetEras():GetCurrentEra();
	local currentTurn:number = Game.GetCurrentGameTurn();

	local eraStartTurn:number = Game.GetEras():GetCurrentEraStartTurn();
	local gameStartTurn:number = GameConfiguration.GetStartTurn();

	if localPlayer == PlayerTypes.NONE or
		currentEra == m_LastShownEraIndex or
		currentTurn ~= eraStartTurn or
		currentTurn == gameStartTurn then
		return;	
	else
		m_LastShownEraIndex = currentEra;
		local newEraName:string = GameInfo.Eras[currentEra].Name;
		-- Bring back if blocking; see header note: m_eventID = ReferenceCurrentGameCoreEvent();
		Controls.EraCompletedHeader:SetText( Locale.ToUpper(Locale.Lookup(newEraName)) );
		UIManager:QueuePopup( ContextPtr, PopupPriority.High );
	end

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
function OnShow()
	UI.PlaySound("Pause_TechCivic_Speech");
	UI.PlaySound("UI_Era_Change");

	--print("OnShow","-", "-", Controls.EraCompletedHeader:GetText(), Controls.EraCompletedHeader:IsHidden() );	--debug

	local localPlayerID:number = Game.GetLocalPlayer();
	if (localPlayerID ~= nil) then
		local gameEras:table = Game.GetEras();
		if (gameEras ~= nil) then
			if (gameEras:HasGoldenAge(localPlayerID)) then
				Events.EnableColorKey("golden_age_colorkey", 0.6, 2);
			elseif (gameEras:HasDarkAge(localPlayerID)) then
				Events.EnableColorKey("dark_age_colorkey", 0.8, 2);
			else
				Events.DisableColorKey(2);
			end
		end
	end

	Controls.EraPopupAnimation:SetToBeginning();
	Controls.EraPopupAnimation:Play();
	

	Controls.HeaderSlide:SetBeginVal(0,100);
	Controls.HeaderSlide:SetEndVal(0,0);
	Controls.HeaderSlide:SetToBeginning();
	Controls.HeaderSlide:Play();


end

-- ===========================================================================
function OnHeaderAnimationComplete()
	--Outro animation deprecated
end

-- ===========================================================================
function OnEraPopupAnimationEnd()
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
	Controls.GradientT:ReprocessAnchoring();
	Controls.GradientB:ReprocessAnchoring();
	Controls.EraCompletedHeader:ReprocessAnchoring();
end

-- ===========================================================================
function Close()
	-- Bring back if blocking; see header note:  ReleaseGameCoreEvent( m_eventID );
	UIManager:DequeuePopup( ContextPtr );
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
function Initialize()
	local localPlayerID:number = Game.GetLocalPlayer();
	if (localPlayerID ~= nil) then
		local gameEras:table = Game.GetEras();
		if (gameEras ~= nil) then
			if (gameEras:HasGoldenAge(localPlayerID)) then
				Events.EnableColorKey("golden_age_colorkey", 0.6, 0);
			elseif (gameEras:HasDarkAge(localPlayerID)) then
				Events.EnableColorKey("dark_age_colorkey", 0.8, 0);
			else
				Events.DisableColorKey(0);
			end
		end
	end

	ContextPtr:SetHide(true);
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler( OnShow );

	Controls.EraPopupAnimation:RegisterStartCallback( function() print("START EraPopupAnimation"); end ); --??TRON debug
	Controls.EraPopupAnimation:RegisterEndCallback( OnEraPopupAnimationEnd );
	Controls.HeaderSlide:RegisterEndCallback( OnHeaderAnimationComplete );

	Events.SystemUpdateUI.Add( OnUpdateUI );

	-- Don't show until player clicks start turn
	if GameConfiguration.IsHotseat() then
		LuaEvents.PlayerChange_Close.Add(CheckGameEraChanged);
	elseif not GameConfiguration.IsNetworkMultiplayer() then
		Events.LocalPlayerTurnBegin.Add(CheckGameEraChanged);
	end

	-- DEBUG
	--CheckGameEraChanged(0, 1);
end
Initialize();