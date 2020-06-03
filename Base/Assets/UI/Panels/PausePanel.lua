-- Copyright 2016-2019, Firaxis Games
-- (Multiplayer) Pause Panel
include("PopupPriorityLoader_", true);


-- ===========================================================================
-- Internal Functions
function OpenPausePanel()
	if(ContextPtr:IsHidden() == true) then
		UIManager:QueuePopup(ContextPtr, PopupPriority.PausePanel);	

		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupAlphaIn:Play();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupSlideIn:Play();
	end
end 


-- ===========================================================================
function ClosePausePanel()
	UIManager:DequeuePopup( ContextPtr );
end


-- ===========================================================================
function CheckPausedState()
	if(not GameConfiguration.IsPaused()) then
		ClosePausePanel();
		return;
	else
		local pausePlayerID : number = GameConfiguration.GetPausePlayer();
		if (pausePlayerID ==  PlayerTypes.OBSERVER or pausePlayerID == PlayerTypes.NONE) then
			ClosePausePanel();
			return;
		end

		-- Get pause player
		local pausePlayer = PlayerConfigurations[pausePlayerID];
		local pausePlayerName : string = pausePlayer:GetPlayerName();
		Controls.WaitingLabel:LocalizeAndSetText("LOC_GAME_PAUSED_BY", pausePlayerName);

		OpenPausePanel();		
	end
end


-- ===========================================================================
--	Event
-- ===========================================================================
function OnGameConfigChanged()
	CheckPausedState();
end


-- ===========================================================================
--	Event
-- ===========================================================================
function OnMenu()
    LuaEvents.PausePanel_OpenInGameOptionsMenu();
end

-- ===========================================================================
--	Callback
-- ===========================================================================
function OnShutdown()
	Events.GameConfigChanged.Remove(CheckPausedState);
	Events.PlayerInfoChanged.Remove(CheckPausedState);
	Events.LoadScreenClose.Remove(CheckPausedState);
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetShutdown( OnShutdown );

	if(not GameConfiguration.IsHotseat() and not WorldBuilder.IsActive()) then
		CheckPausedState();

		Events.GameConfigChanged.Add(CheckPausedState);
		Events.PlayerInfoChanged.Add(CheckPausedState);
		Events.LoadScreenClose.Add(CheckPausedState);

		Controls.PauseStack:CalculateSize();
	else
		ContextPtr:SetHide(true);
	end
end
Initialize();
