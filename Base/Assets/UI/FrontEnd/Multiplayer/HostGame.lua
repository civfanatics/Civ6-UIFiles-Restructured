-------------------------------------------------
-- Multiplayer Host Game Screen
-------------------------------------------------
include("LobbyTypes");		--MPLobbyTypes
include("ButtonUtilities");
include("InstanceManager");
include("PlayerSetupLogic");
include("PopupDialog");
include("Civ6Common");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local LOC_GAME_SETUP		:string = Locale.Lookup("LOC_MULTIPLAYER_GAME_SETUP");
local LOC_STAGING_ROOM		:string = Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_STAGING_ROOM"));
local RELOAD_CACHE_ID		:string = "HostGame";
--local SCROLL_SIZE_DEFAULT	:number = 620;
--local SCROLL_SIZE_IN_SESSION:number = 662;

-- ===========================================================================
--	Globals
-- ===========================================================================
local m_lobbyModeName:string = MPLobbyTypes.STANDARD_INTERNET;
local m_shellTabIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.ShellTabs);
local m_kPopupDialog:table;

-- ===========================================================================
--	Input Handler
-- ===========================================================================
function OnInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			LuaEvents.Multiplayer_ExitShell();
		end
	end
	return true;
end

-- ===========================================================================
function OnShow()
	
	RebuildPlayerParameters(true);
	GameSetup_RefreshParameters();
	


	-- Hide buttons if we're already in a game
	local isInSession:boolean = Network.IsInSession();
	Controls.ModsButton:SetHide(isInSession);
	Controls.ConfirmButton:SetHide(isInSession);
	
	ShowDefaultButton();
	ShowLoadConfigButton();
	Controls.LoadButton:SetHide(not GameConfiguration.IsHotseat() or isInSession);

	--[[
	local sizeY:number = isInSession and SCROLL_SIZE_IN_SESSION or SCROLL_SIZE_DEFAULT;
	Controls.DecoGrid:SetSizeY(sizeY);
	Controls.DecoBorder:SetSizeY(sizeY + 6);
	Controls.ParametersScrollPanel:SetSizeY(sizeY - 2);
	--]]

	RealizeShellTabs();
end

-- ===========================================================================
function ShowDefaultButton()
	local showDefaultButton = not GameConfiguration.IsSavedGame()
								and not Network.IsInSession();

	Controls.DefaultButton:SetHide(not showDefaultButton);
end

function ShowLoadConfigButton()
	local showLoadConfig = not GameConfiguration.IsSavedGame()
								and not Network.IsInSession();

	Controls.LoadConfigButton:SetHide(not showLoadConfig);
end

-- ===========================================================================
function OnHide( isHide, isInit )
	ReleasePlayerParameters();
	HideGameSetup();
end

-------------------------------------------------
-- Restore Default Settings Button Handler
-------------------------------------------------
function OnDefaultButton()
	print("Resetting Setup Parameters");

	-- Get the game name since we wish to persist this.
	local gameMode = GameModeTypeForMPLobbyType(m_lobbyModeName);
	local gameName = GameConfiguration.GetValue("GAME_NAME");
	GameConfiguration.SetToDefaults(gameMode);
	GameConfiguration.RegenerateSeeds();

	-- Kludge:  SetToDefaults assigns the ruleset to be standard.
	-- Clear this value so that the setup parameters code can guess the best 
	-- default.
	GameConfiguration.SetValue("RULESET", nil);
	
	-- Only assign GAME_NAME if the value is valid.
	if(gameName and #gameName > 0) then
		GameConfiguration.SetValue("GAME_NAME", gameName);
	end
	return GameSetup_RefreshParameters();
end

-------------------------------------------------------------------------------
-- Event Listeners
-------------------------------------------------------------------------------
Events.FinishedGameplayContentConfigure.Add(function(result)
	if(ContextPtr and not ContextPtr:IsHidden() and result.Success) then
		GameSetup_RefreshParameters();
	end
end);

-------------------------------------------------
-- Mods Setting Button Handler
-- TODO: Remove this, and place contents mods screen into the ParametersStack (in the SecondaryParametersStack, or in its own ModsStack)
-------------------------------------------------
function ModsButtonClick()
	UIManager:QueuePopup(Controls.ModsMenu, PopupPriority.Current);	
end


-- ===========================================================================
--	Host Game Button Handler
-- ===========================================================================
function OnConfirmClick()
	-- UINETTODO - Need to be able to support coming straight to this screen as a dedicated server
	--SERVER_TYPE_STEAM_DEDICATED,	// Steam Game Server, host does not play.

	local serverType = ServerTypeForMPLobbyType(m_lobbyModeName);
	print("OnConfirmClick() m_lobbyModeName: " .. tostring(m_lobbyModeName) .. " serverType: " .. tostring(serverType));
	
	-- GAME_NAME must not be empty.
	local gameName = GameConfiguration.GetValue("GAME_NAME");	
	if(gameName == nil or #gameName == 0) then
		GameConfiguration.SetToDefaultGameName();
	end

	Network.HostGame(serverType);	
end

-------------------------------------------------
-- Load Configuration Button Handler
-------------------------------------------------
function OnLoadConfig()
	local serverType = ServerTypeForMPLobbyType(m_lobbyModeName);
	LuaEvents.HostGame_SetLoadGameServerType(serverType);
	local kParameters = {};
	kParameters.FileType = SaveFileTypes.GAME_CONFIGURATION;
	UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current, kParameters);
end

-------------------------------------------------
-- Load Configuration Button Handler
-------------------------------------------------
function OnSaveConfig()
	local kParameters = {};
	kParameters.FileType = SaveFileTypes.GAME_CONFIGURATION;
	UIManager:QueuePopup(Controls.SaveGameMenu, PopupPriority.Current, kParameters);
end

function OnAbandoned(eReason)
	if (not ContextPtr:IsHidden()) then

		-- We need to CheckLeaveGame before triggering the reason popup because the reason popup hides the host game screen.
		-- and would block the leave game incorrectly.  This fixes TTP 22192.  See CheckLeaveGame() in stagingroom.lua.
		CheckLeaveGame();

		if (eReason == KickReason.KICK_HOST) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_KICKED", "LOC_GAME_ABANDONED_KICKED_TITLE" );
		elseif (eReason == KickReason.KICK_NO_HOST) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_HOST_LOSTED", "LOC_GAME_ABANDONED_HOST_LOSTED_TITLE" );
		elseif (eReason == KickReason.KICK_NO_ROOM) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_ROOM_FULL", "LOC_GAME_ABANDONED_ROOM_FULL_TITLE" );
		elseif (eReason == KickReason.KICK_VERSION_MISMATCH) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_VERSION_MISMATCH", "LOC_GAME_ABANDONED_VERSION_MISMATCH_TITLE" );
		elseif (eReason == KickReason.KICK_MOD_ERROR) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_MOD_ERROR", "LOC_GAME_ABANDONED_MOD_ERROR_TITLE" );
		elseif (eReason == KickReason.KICK_MOD_MISSING) then
			local modMissingErrorStr = Modding.GetLastModErrorString();
			LuaEvents.MultiplayerPopup( modMissingErrorStr, "LOC_GAME_ABANDONED_MOD_MISSING_TITLE" );
		elseif (eReason == KickReason.KICK_MATCH_DELETED) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_MATCH_DELETED", "LOC_GAME_ABANDONED_MATCH_DELETED_TITLE" );
		else
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_CONNECTION_LOST", "LOC_GAME_ABANDONED_CONNECTION_LOST_TITLE");
		end
		LuaEvents.Multiplayer_ExitShell();
	end
end

function CheckLeaveGame()
	-- Leave the network session if we're in a state where the host game should be triggering the exit.
	if not ContextPtr:IsHidden()	-- If the screen is not visible, this exit might be part of a general UI state change (like Multiplayer_ExitShell)
									-- and should not trigger a game exit.
		and Network.IsInSession()	-- Still in a network session.
		and not Network.IsInGameStartedState() then -- Don't trigger leave game if we're being used as an ingame screen. Worldview is handling this instead.
		Network.LeaveGame();
	end
end

-- ===========================================================================
-- Event Handler: LeaveGameComplete
-- ===========================================================================
function OnLeaveGameComplete()
	-- We just left the game, we shouldn't be open anymore.
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
-- Event Handler: BeforeMultiplayerInviteProcessing
-- ===========================================================================
function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
-- Event Handler: ChangeMPLobbyMode
-- ===========================================================================
function OnChangeMPLobbyMode(newLobbyMode)
	m_lobbyModeName = newLobbyMode;
end

-- ===========================================================================
function RealizeShellTabs()
	m_shellTabIM:ResetInstances();

	local gameSetup:table = m_shellTabIM:GetInstance();
	gameSetup.Button:SetText(LOC_GAME_SETUP);
	gameSetup.SelectedButton:SetText(LOC_GAME_SETUP);
	gameSetup.Selected:SetHide(false);

	AutoSizeGridButton(gameSetup.Button,250,32,10,"H");
	AutoSizeGridButton(gameSetup.SelectedButton,250,32,20,"H");
	gameSetup.TopControl:SetSizeX(gameSetup.Button:GetSizeX());

	if Network.IsInSession() then
		local stagingRoom:table = m_shellTabIM:GetInstance();
		stagingRoom.Button:SetText(LOC_STAGING_ROOM);
		stagingRoom.SelectedButton:SetText(LOC_STAGING_ROOM);
		stagingRoom.Button:RegisterCallback( Mouse.eLClick, function() LuaEvents.HostGame_ShowStagingRoom() end );
		stagingRoom.Selected:SetHide(true);

		AutoSizeGridButton(stagingRoom.Button,250,32,20,"H");
		AutoSizeGridButton(stagingRoom.SelectedButton,250,32,20,"H");
		stagingRoom.TopControl:SetSizeX(stagingRoom.Button:GetSizeX());
	end

	Controls.ShellTabs:CalculateSize();
	Controls.ShellTabs:ReprocessAnchoring();
end

-------------------------------------------------
-- Leave the screen
-------------------------------------------------
function HandleExitRequest()
	-- Check to see if the screen needs to also leave the network session.
	CheckLeaveGame();

	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function OnRaiseHostGame()
	-- "Raise" means the host game screen is being shown for a fresh game.  Game configuration need to be defaulted.
	local gameMode = GameModeTypeForMPLobbyType(m_lobbyModeName);
	GameConfiguration.SetToDefaults(gameMode);

	-- Kludge:  SetToDefaults assigns the ruleset to be standard.
	-- Clear this value so that the setup parameters code can guess the best 
	-- default.
	GameConfiguration.SetValue("RULESET", nil);

	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
end

-- ===========================================================================
function OnEnsureHostGame()
	-- "Ensure" means the host game screen needs to be shown for a game in progress (don't default game configuration).
	if ContextPtr:IsHidden() then
		UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
	end
end

-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );
	end
end

-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
end

-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == RELOAD_CACHE_ID and contextTable["isHidden"] == false then
		UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
	end	
end

-- ===========================================================================
-- Load Game Button Handler
-- ===========================================================================
function LoadButtonClick()
	local serverType = ServerTypeForMPLobbyType(m_lobbyModeName);
	LuaEvents.HostGame_SetLoadGameServerType(serverType);
	UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current);	
end

function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY()) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
	Resize();
  end
end

function OnExitGame()
	LuaEvents.Multiplayer_ExitShell();
end

function OnExitGameAskAreYouSure()
	if Network.IsInSession() then
		if (not m_kPopupDialog:IsOpen()) then
			m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_WARNING"));
			m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
			m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnExitGame, nil, nil, "PopupButtonInstanceRed" );
			m_kPopupDialog:Open();
		end
	else
		OnExitGame();
	end
end

-- ===========================================================================
function Initialize()
	
	Events.SystemUpdateUI.Add(OnUpdateUI);

	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler(OnInputHandler);
	ContextPtr:SetShowHandler(OnShow);
	ContextPtr:SetHideHandler(OnHide);

	Controls.DefaultButton:RegisterCallback( Mouse.eLClick, OnDefaultButton);
	Controls.LoadConfigButton:RegisterCallback( Mouse.eLClick, OnLoadConfig);
	Controls.SaveConfigButton:RegisterCallback( Mouse.eLClick, OnSaveConfig);
	Controls.ConfirmButton:RegisterCallback( Mouse.eLClick, OnConfirmClick );
	Controls.ModsButton:RegisterCallback( Mouse.eLClick, ModsButtonClick );

	Events.MultiplayerGameAbandoned.Add( OnAbandoned );
	Events.LeaveGameComplete.Add( OnLeaveGameComplete );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );
	
	LuaEvents.ChangeMPLobbyMode.Add( OnChangeMPLobbyMode );
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.Lobby_RaiseHostGame.Add( OnRaiseHostGame );
	LuaEvents.MainMenu_RaiseHostGame.Add( OnRaiseHostGame );
	LuaEvents.Multiplayer_ExitShell.Add( HandleExitRequest );
	LuaEvents.StagingRoom_EnsureHostGame.Add( OnEnsureHostGame );
	LuaEvents.Mods_UpdateHostGameSettings.Add(GameSetup_RefreshParameters);		-- TODO: Remove when mods are managed by this screen

	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnExitGameAskAreYouSure);
	Controls.LoadButton:RegisterCallback( Mouse.eLClick, LoadButtonClick );

	ResizeButtonToText( Controls.DefaultButton );
	ResizeButtonToText( Controls.BackButton );
	Resize();

	-- Custom popup setup	
	m_kPopupDialog = PopupDialog:new( "InGameTopOptionsMenu" );
end
Initialize();