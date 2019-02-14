----------------------------------------------------------------  
-- PlayerChange
--
-- Screen used for when the player changes in hotseat mode.
----------------------------------------------------------------  
include("PopupPriorityLoader_", true);

----------------------------------------------------------------  
-- Defines
---------------------------------------------------------------- 


----------------------------------------------------------------  
-- Globals
---------------------------------------------------------------- 
local PopupTitleSuffix = Locale.Lookup( "LOC_PLAYER_CHANGE_POPUP_TITLE_SUFFIX" );
local bPlayerChanging :boolean = false; -- Are we in the "Please Wait" mode?
local bLocalPlayerTurnEnded :boolean = false;
local bLocalPlayerDestroyed :boolean = false;


----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function OnInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_RETURN then
			OnKeyUp_Return();
		elseif wParam == Keys.VK_ESCAPE then
			OnMenu();
		end
	end
	return true; -- Consume all input
end

-- ===========================================================================
function OnKeyUp_Return()
	-- Is the internal dialog box hidden?  If so, we are in Please Wait mode so don't do anything.
	if (not Controls.PopupAlphaIn:IsHidden()) then
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		if(localPlayer ~= nil 
			and localPlayer:GetHotseatPassword() == "") then
			OnOk();
		end
	end
end
-- ===========================================================================
function OnSave()
	UIManager:QueuePopup(Controls.SaveGameMenu, PopupPriority.PlayerChange);	
end

-- ===========================================================================
function OnOk()
	if(GameConfiguration.IsHotseat()) then
		SetPause(false);
	end
	LuaEvents.PlayerChange_Close(Game.GetLocalPlayer());
	UIManager:DequeuePopup( ContextPtr );
	Controls.PopupAlphaIn:SetHide(true);		-- Hide, so they can't click on it!
	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupSlideIn:SetToBeginning();
end

-- ===========================================================================
function OnCancelUpload()
   	UIManager:SetUICursor( 1 );
	UITutorialManager:EnableOverlay( false );	
	UITutorialManager:HideAll();

	UIManager:Log("Shutting down via player change exit-to-main-menu.");
	Events.ExitToMainMenu();
end
	

-- ===========================================================================
function OnMenu()
    LuaEvents.PlayerChange_OpenInGameOptionsMenu();
end

-- ===========================================================================
function OnLocalPlayerTurnBegin()
	bLocalPlayerTurnEnded = false;
	if(GameConfiguration.IsHotseat() == true) then
		-- In hotseat, we show the full player change popup before the player takes their turn.
		-- this tells the UI to display us. ContextPtr is the this pointer for this object.
		bPlayerChanging = false;
		BuildTurnControls();
	end
end

function OnLocalPlayerTurnEnd()
	if not bLocalPlayerDestroyed then	-- Don't show if the local player has died.  We are showing the endgamemenu instead.	
		bLocalPlayerTurnEnded = true;	
		bPlayerChanging = true; 
		-- [TTP 40166] In Hotseat, we have to ensure the game is unpaused in case the local player's turn deactivated before the player clicked Start Turn. 
		-- This was happening during World Congress phases in the past.  It is now just a fallback mechanic just in case.
		if(GameConfiguration.IsHotseat()) then
			SetPause(false);
		end 
		--if(GetNumAliveHumanPlayers() > 1) then
			UIManager:QueuePopup( ContextPtr, PopupPriority.PlayerChange);
		--end
	end
end

function GetNumAliveHumanPlayers()
	local aPlayers = PlayerManager.GetAliveMajors();
	local numAliveHumanPlayers = 0;
	for _, pPlayer in ipairs(aPlayers) do
		if(pPlayer:IsHuman()) then
			numAliveHumanPlayers = numAliveHumanPlayers + 1;
		end
	end

	return numAliveHumanPlayers;
end

-- ===========================================================================
function BuildTurnControls()
	--if(GetNumAliveHumanPlayers() > 1) then
		print("BuildTurnControls: CurrentGameTurn=" .. Game.GetCurrentGameTurn());
		if(GameConfiguration.IsHotseat()) then
			SetPause(true);

			-- Panel title is player's name.
			local localPlayerID = Game.GetLocalPlayer();
			local localPlayer = PlayerConfigurations[localPlayerID];
			--print("Hotseat password=" .. localPlayer:GetHotseatPassword());
			Controls.TitleText:SetText(Locale.ToUpper(localPlayer:GetPlayerName()));
		end

		if(ContextPtr:IsHidden()) then
			UIManager:QueuePopup( ContextPtr, PopupPriority.PlayerChange);
		else
			ShowTurnControls();
		end
	--end
end

-- ===========================================================================
function OnLoadScreenClose()

	-- Have we loaded and the player is active?
	local pPlayer = Players[ Game.GetLocalPlayer() ];
	if (pPlayer ~= nil) then
		if (pPlayer:IsTurnActive()) then
			-- Yes, then show the dialog
			OnLocalPlayerTurnBegin();
			return;
		end
	end
	
	-- No, just show the Please Wait, we will get a turn begin event later.
	bPlayerChanging = true;
	UIManager:QueuePopup( ContextPtr, PopupPriority.PlayerChange);
end

-- ===========================================================================
function OnShow()
	ShowTurnControls();
end

-- ===========================================================================
function ShowTurnControls()
	LuaEvents.PlayerChange_Show();
	if(not bPlayerChanging) then
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		Controls.PlayerChangingText:SetHide(true);
		Controls.PopupAlphaIn:SetHide(false);
		Controls.PasswordEntry:SetText("");
		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupAlphaIn:Play();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupSlideIn:Play();
		if(localPlayer:GetHotseatPassword() == "") then
			Controls.PasswordStack:SetHide(true);
			Controls.OkButton:SetDisabled(false);
		else
			Controls.PasswordStack:SetHide(false);
			Controls.OkButton:SetDisabled(true);
			Controls.PasswordEntry:TakeFocus();
		end

		UpdateBottomButtons();
	else
		-- While in the "Please Wait" mode, hide the controls.
		Controls.PlayerChangingText:SetHide(false);
		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupAlphaIn:SetHide(true);		-- Hide the box, else they can still click on the contents!
	end
end

-- ===========================================================================
function UpdateBottomButtons()
	ShowOkButton();
	ShowSaveButton();

	Controls.BottomButtonsStack:CalculateSize();
	Controls.BottomButtonsStack:ReprocessAnchoring();
end

-- ===========================================================================
function ShowOkButton()
	local showOk = GameConfiguration.IsHotseat();
	Controls.OkButton:SetHide(not showOk);
end

-- ===========================================================================
function ShowSaveButton()
	local showSave = GameConfiguration.IsHotseat();
	Controls.SaveButton:SetHide(not showSave);
end

-- ===========================================================================
-- This function can be called with the same pause state multiple times to the ensure pause state is correct in edge cases.
function SetPause(bNewPause)
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
	if (localPlayerConfig ~= nil) then
		local oldPause = localPlayerConfig:GetWantsPause();
		if(bNewPause ~= oldPause) then
			local bIsTurnActive = Players[localPlayerID]:IsTurnActive();
			if (bIsTurnActive or bNewPause == false) then
				localPlayerConfig:SetWantsPause(bNewPause);
				Network.BroadcastPlayerInfo();
			end
		end
	end
end

-- ===========================================================================
function OnPasswordEntryStringChanged(passwordEditBox)
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = PlayerConfigurations[localPlayerID]; 
	local password = "";

	if(passwordEditBox:GetText() ~= nil) then
		password = passwordEditBox:GetText();
		--print("OnPasswordEntryStringChanged: password=" .. password .. ", localPlayerPassword=" .. localPlayer:GetHotseatPassword());
		if(password == localPlayer:GetHotseatPassword()) then
			Controls.OkButton:SetDisabled(false);
		else
			Controls.OkButton:SetDisabled(true);
		end
	end
end

-- ===========================================================================
function OnPasswordEntryCommit()
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = PlayerConfigurations[localPlayerID]; 
	local password = "";

	if(Controls.PasswordEntry:GetText() ~= nil) then
		password = Controls.PasswordEntry:GetText();
		--print("OnPasswordEntryCommit: password=" .. password .. ", localPlayerPassword=" .. localPlayer:GetHotseatPassword());
		if(password == localPlayer:GetHotseatPassword()) then
			OnOk();
		end
	end
end

-- ===========================================================================
function OnTeamVictory(team, victory, eventID)
	if(not ContextPtr:IsHidden()) then
		UIManager:DequeuePopup(ContextPtr);
		Events.LocalPlayerTurnBegin.Remove(OnLocalPlayerTurnBegin);
		Events.LocalPlayerTurnEnd.Remove(OnLocalPlayerTurnEnd);
		Events.LoadScreenClose.Remove(OnLoadScreenClose);
	end
end

-- ===========================================================================
function OnPlayerDestroyed(playerID)
	local localPlayerID = Game.GetLocalPlayer();
	if(localPlayerID == playerID) then
		bLocalPlayerDestroyed = true;
	end
end


-- ===========================================================================
function OnEndGameMenu_OneMoreTurn()
	print("OnEndGameMenu_OneMoreTurn");
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd);
	Events.LoadScreenClose.Add(OnLoadScreenClose);
end

-- ===========================================================================
function OnEndGameMenu_ViewingPlayerDefeat()
	-- In hotseat, it is possible for a human player to get defeated by an AI civ during the turn processing.
	-- If that happens, the PlayerChange screen needs to hide so the defeat screen can be seen.
	-- The PlayerChange screen will be restored when the defeated player clicks "next player" and ends their turn.
	print("OnEndGameMenu_ViewingPlayerDefeat");
	if(not ContextPtr:IsHidden()) then
		UIManager:DequeuePopup(ContextPtr);
	end
end

-- ===========================================================================
--	INITIALIZE
-- ===========================================================================
function Initialize()

	

	-- NOTE: LuaEvents. are events that only exist inside the Lua system. Nothing native.

	-- When player info is changed, this pulldown needs to know so it can update itself if it becomes invalid.
	-- NOTE: Events.XXX are Engine(App/Civ6) Events. Where XXX is a native event, defined in native. Look for: LUAEVENT_NAMESPACED(LocalMachineEvent, PlayerInfoChanged);
	--Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);
	-- changing to listen for TurnBegin so that on the initial turn, the first player will get this popup screen. this is consistent with Civ V's behavior.
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd);
	Events.LoadScreenClose.Add(OnLoadScreenClose);
	Events.TeamVictory.Add(OnTeamVictory);
	Events.PlayerDestroyed.Add(OnPlayerDestroyed);

	LuaEvents.EndGameMenu_OneMoreTurn.Add(OnEndGameMenu_OneMoreTurn);
	LuaEvents.EndGameMenu_ViewingPlayerDefeat.Add(OnEndGameMenu_ViewingPlayerDefeat);

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler( OnInputHandler );

	Controls.SaveButton:RegisterCallback(Mouse.eLClick, OnSave);
	Controls.OkButton:RegisterCallback(Mouse.eLClick, OnOk);
	Controls.MenuButton:RegisterCallback( Mouse.eLClick, OnMenu );
	Controls.PasswordEntry:RegisterStringChangedCallback(OnPasswordEntryStringChanged);
	Controls.PasswordEntry:RegisterCommitCallback(OnPasswordEntryCommit);
end
-- If not in a hotseat do not register for events.
if GameConfiguration.IsHotseat() then
	Initialize();
end


