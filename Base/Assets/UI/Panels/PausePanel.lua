----------------------------------------------------------------------------
-- Ingame Turn Order Panel
----------------------------------------------------------------------------



----------------------------------------------------------------------------
-- Globals
local NO_PLAYER = -1;


----------------------------------------------------------------------------
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

function ClosePausePanel()
	UIManager:DequeuePopup( ContextPtr );
end

function CheckPausedState()
	if(not GameConfiguration.IsPaused()) then
		ClosePausePanel();
		return;
	else
		local pausePlayerID : number = GameConfiguration.GetPausePlayer();
		if(pausePlayerID == NO_PLAYER) then
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


----------------------------------------------------------------------------
-- Event Handlers
function OnGameConfigChanged()
	CheckPausedState();
end

function OnMenu()
    LuaEvents.PausePanel_OpenInGameOptionsMenu();
end

----------------------------------------------------------------------------
-- Initialization
function Initialize()

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
