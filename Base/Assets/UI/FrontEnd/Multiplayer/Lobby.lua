-- ===========================================================================
-- Internet Lobby Screen
-- ===========================================================================
include( "InstanceManager" );	--InstanceManager
include("LobbyTypes");		--MPLobbyTypes
include("NetworkUtilities");
include("ButtonUtilities");
include( "Civ6Common" ); -- AutoSizeGridButton
include( "PopupDialog" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID :string = "Lobby";


-- ===========================================================================
-- Globals
-- ===========================================================================

--[[ UINETTODO - Hook up game server game settings properties.		
-- Hard coded DLC packages to ignore.
local DlcGuidsToIgnore = {
 "{8871E748-29A4-4910-8C57-8C99E32D0167}",
};
--]]

-- Listing Box Buttons
local m_shellTabIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.ShellTabs);
local g_FriendsIM = InstanceManager:new( "FriendInstance", "RootContainer", Controls.FriendsStack );
local g_GridLinesIM = InstanceManager:new( "HorizontalGridLine", "Control", Controls.GridContainer );
local g_InstanceManager = InstanceManager:new( "ListingButtonInstance", "Button", Controls.ListingStack );
local g_InstanceList = {};
local g_TabInstances = {};	-- indexed by browser mode ID
local m_kPopupDialog:table;
local m_joinCodeText :string = "";	-- The current join code entered in the Join Code popup.

local LIST_LOBBIES				:number = 0;
local LIST_SERVERS				:number = 1;
local LIST_INVITES				:number = 2;

-- PlayByCloud Specific Browse Modes
local LIST_PUBLIC_GAMES			:number = 0;
local LIST_PERSONAL_GAMES		:number = 1;	-- Active PlayByCloud games the local player is in.
local LIST_COMPLETED_GAMES		:number = 2;	-- Completed PlayByCloud games that the local player was in.

local SEARCH_INTERNET			:number = 0;	-- Internet Servers/Lobbies
local SEARCH_LAN				:number = 1;	-- LAN Servers/Lobbies
local SEARCH_FRIENDS			:number = 2;
local SEARCH_FAVORITES			:number = 3;
local SEARCH_HISTORY			:number = 4;
local SEARCH_CROSSPLAY			:number = 5;

local GAMELISTUPDATE_CLEAR		:number = 1;
local GAMELISTUPDATE_COMPLETE	:number = 2;
local GAMELISTUPDATE_ADD		:number = 3;
local GAMELISTUPDATE_UPDATE		:number = 4;
local GAMELISTUPDATE_REMOVE		:number = 5;
local GAMELISTUPDATE_ERROR		:number = 6;

local GRID_LINE_WIDTH			:number = 1020;
local GRID_LINE_HEIGHT			:number = 30;
local NUM_COLUMNS				:number = 6;
local FRIEND_HEIGHT				:number = 46;
local FRIENDS_BG_WIDTH			:number = 236;
local FRIENDS_BG_HEIGHT			:number = 342;
local FRIENDS_BG_PADDING		:number = 20;
-- Current size range for PlayByCloud game list requests.  IE, the max number of games returned per request.
local PLAYBYCLOUD_LIST_RANGE	:number = 50;

-- Game List Scroll Position Override Defines
-- Used for setting the scroll position when refreshing between game list range offsets.
local SCROLL_NONE				:number = 0;
local SCROLL_UP					:number = 1;
local SCROLL_DOWN				:number = 2;

-- GameListRoot Offset and Size (with and without shell tabs)
local GAME_LIST_OFFSET_Y		:number = 52;
local GAME_LIST_TABS_OFFSET_Y	:number = 87;
local GAME_LIST_SIZE_Y			:number = 723;
local GAME_LIST_TABS_SIZE_Y		:number = 688;	
local LIST_PANEL_SIZE_Y			:number = 628;
local LIST_PANEL_TABS_SIZE_Y	:number = 598;
local LIST_BAR_SIZE_Y			:number = 570;
local LIST_TABS_BAR_SIZE_Y		:number = 570;
local GAME_GRID_SIZE_Y			:number = 714;
local GAME_GRID_TABS_SIZE_Y		:number = 684;

local m_shouldShowFriends		:boolean = true;
local m_firstTimeShow			:boolean = true;	-- Is this the first time this context has been shown?
local m_hasCloudUnseenComplete	:boolean = false; -- Do we have completed PlayByCloud games that we haven't seen yet?
local m_lobbyModeName			:string = MPLobbyTypes.STANDARD_INTERNET;
local m_browserMode				:number = LIST_PERSONAL_GAMES;-- Current PlayByCloud browser mode.
local m_browserOffset			:number = 0;
local m_nextListID				:number = 0;
local m_inPBCGames				:boolean = true;		-- Are we known to currently be in PlayByCloud games?

local ColorSet_Default			:string = "ServerText";
local ColorSet_Faded			:string = "ServerTextFaded";
local ColorSet_VersionMismatch	:string = "ServerTextVersionMismatch";
local ColorSet_ModGreen			:string = "ModStatusGreenCS";
local ColorSet_ModYellow		:string = "ModStatusYellowCS";
local ColorSet_ModRed			:string = "ModStatusRedCS";
local ColorString_ModGreen		:string = "[color:ModStatusGreen]";
local ColorString_ModYellow		:string = "[color:ModStatusYellow]";
local ColorString_ModRed		:string = "[color:Civ6Red]";
local JOINCODE_EDITBOX_COMMAND	:string	= "JoinCodeEditBox";

local DEFAULT_RULE_SET:string = Locale.Lookup("LOC_MULTIPLAYER_STANDARD_GAME");
local DEFAULT_GAME_SPEED:string = Locale.Lookup("LOC_GAMESPEED_STANDARD_NAME");
local gameStartedTooltip:string = Locale.Lookup("LOC_LOBBY_GAME_STARTED_TOOLTIP");
local gameLoadingSaveTooltip:string = Locale.Lookup("LOC_LOBBY_GAME_LOADING_SAVE_TOOLTIP");
local gameYourTurnTooltip:string = Locale.Lookup("LOC_LOBBY_GAME_YOUR_TURN_TOOLTIP");
local gameGameReadyTooltip:string = Locale.Lookup("LOC_LOBBY_GAME_GAME_READY_TOOLTIP");
local gameUnseenCompleteTooltip:string = Locale.Lookup("LOC_LOBBY_GAME_UNSEEN_COMPLETE_TOOLTIP");
local playByCloudJoinsDisabled:string = "[color:Civ6Red]You can not join PlayByCloud games while in a debug build.[ENDCOLOR]";
local joinDisabledVersionMismatch:string = Locale.Lookup("LOC_LOBBY_JOIN_DISABLED_VERSION_MISMATCH_TOOLTIP");
local LOC_LOBBY_MY_GAMES					:string = Locale.Lookup("LOC_LOBBY_MY_GAMES");
local LOC_LOBBY_MY_GAMES_TT					:string = Locale.Lookup("LOC_LOBBY_MY_GAMES_TT");
local LOC_LOBBY_OPEN_GAMES					:string = Locale.Lookup("LOC_LOBBY_OPEN_GAMES");
local LOC_LOBBY_OPEN_GAMES_TT				:string = Locale.Lookup("LOC_LOBBY_OPEN_GAMES_TT");
local LOC_LOBBY_COMPLETED_GAMES				:string = Locale.Lookup("LOC_LOBBY_COMPLETED_GAMES");
local LOC_LOBBY_COMPLETED_GAMES_TT			:string = Locale.Lookup("LOC_LOBBY_COMPLETED_GAMES_TT");
local LOC_LOBBY_COMPLETED_GAMES_UNSEEN		:string = Locale.Lookup("LOC_LOBBY_COMPLETED_GAMES_UNSEEN");
local LOC_LOBBY_COMPLETED_GAMES_UNSEEN_TT	:string = Locale.Lookup("LOC_LOBBY_COMPLETED_GAMES_UNSEEN_TT");
local LOC_MULTIPLAYER_JOIN_GAME				:string = Locale.Lookup("LOC_MULTIPLAYER_JOIN_GAME");
local LOC_MULTIPLAYER_JOIN_GAME_TT			:string = Locale.Lookup("LOC_MULTIPLAYER_JOIN_GAME_TT");
local LOC_MULTIPLAYER_PLAY_GAME				:string = Locale.Lookup("LOC_MULTIPLAYER_PLAY_GAME");
local LOC_MULTIPLAYER_PLAY_GAME_TT			:string = Locale.Lookup("LOC_MULTIPLAYER_PLAY_GAME_TT");
													  
g_SelectedServerID = nil;
g_Listings = {};

-- Sort Option Data
-- Contains all possible buttons which alter the listings sort order.
g_SortOptions = {
	{
		Button = Controls.SortbyName,
		Column = "ServerName",
		DefaultDirection = "asc",
		CurrentDirection = "asc",
	},
	{
		Button = Controls.SortbyRuleSet,
		Column = "RuleSet",
		DefaultDirection = "asc",
		CurrentDirection = "asc",
	},
	{
		Button = Controls.SortbyMapName,
		Column = "MapName",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.SortbyGameSpeed,
		Column = "GameSpeed",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.SortbyPlayers,
		Column = "MembersSort",
		DefaultDirection = "desc",
		CurrentDirection = nil,
		SortType = "numeric",
	},
	{
		Button = Controls.SortbyModsHosted,
		Column = "DLCSort",
		DefaultDirection = "desc",
		CurrentDirection = nil,
		SortType = "numeric",
	},
	-- Special sort type for offset scrolling
	{
		Button = nil,
		Column = "ListID",
		DefaultDirection = "asc",
		CurrentDirection = nil,
		SortType = "numeric",
	},
};

g_SortFunction = nil;

-------------------------------------------------
-- Helper Functions
-------------------------------------------------
function IsUsingPlayByCloudGameList()
	if (m_lobbyModeName == MPLobbyTypes.PLAYBYCLOUD) then
		return true;
	end 
	return false;
end

function IsUsingInternetGameList()
	if (m_lobbyModeName == MPLobbyTypes.STANDARD_INTERNET 
		or m_lobbyModeName == MPLobbyTypes.PITBOSS_INTERNET
		or m_lobbyModeName == MPLobbyTypes.PITBOSS_LAN) then
		return true;
	else
		return false;
	end
end

function IsUsingCrossPlayGameList()
	if (m_lobbyModeName == MPLobbyTypes.CROSSPLAY_INTERNET) then
		return true;
	end
	return false;
end

function IsUsingPitbossGameList()
	if (m_lobbyModeName == MPLobbyTypes.PITBOSS_INTERNET
		or m_lobbyModeName == MPLobbyTypes.PITBOSS_LAN) then
		return true;
	else
		return false;
	end
end

-- Performs game version mismatch check. Returns false if the check failed.
-- NOTE: PlayByCloud always passes this check so cloud games can automatically transition to latest version using save compatibility. 
function CheckServerVersion(serverID)
	if(IsUsingPlayByCloudGameList()) then
		return true;
	end

	local localGameVersion :string = UI.GetAppVersion();
	local serverListing = GetServerListing(serverID);
	if(serverListing ~= nil 
		and (serverListing.GameVersion == nil or serverListing.GameVersion ~= localGameVersion)) then
		return false;
	end
	
	return true;
end

function IsPlayByCloudJoinsDisabled()
	local joiningDisabled :boolean = false;
	return joiningDisabled;
end

function IsOffsetScrolling()
	return IsUsingPlayByCloudGameList();
end

function SetBrowserMode(browserMode :number)
	m_browserMode = browserMode;
	Matchmaking.SetBrowseMode(m_browserMode);
end

function SetBrowserOffset(browserOffset :number)
	m_browserOffset = browserOffset;
	m_browserOffset = math.max(m_browserOffset, 0); 
	m_nextListID = m_browserOffset;
	Matchmaking.SetBrowseOffset(m_browserOffset);
end

-- Are the game list updates commited as a batch update or do they trickle in over time?
function IsGameListBatchUpdating()
	-- PlayByCloud uses batch updates.
	if(IsUsingPlayByCloudGameList()) then
		return true;
	end
	return false;
end

function RebuildGameList()
	ClearGameList();
	SetBrowserOffset(0);
	if(IsUsingPlayByCloudGameList()) then
		FiraxisLive.ClearCloudGames(m_browserMode); -- PlayByCloud - We are intentionally requesting a full refresh, clear the cached cloud game data so we will get a fresh list.
	end
	Matchmaking.RefreshGameList();
end

function ClearGameList()
	-- Clear existing game list
	g_Listings = {};
	g_SelectedServerID = nil;
	Controls.JoinGameButton:SetDisabled(true);
	g_InstanceManager:ResetInstances();
	g_InstanceList = {};
	UpdateRefreshButton();
end

function GetCloudNotifyString(cloudNotify)
	if(cloudNotify == CloudNotifyTypes.CLOUDNOTIFY_YOURTURN) then
		return gameYourTurnTooltip;
	elseif(cloudNotify == CloudNotifyTypes.CLOUDNOTIFY_GAMEREADY) then
		return gameGameReadyTooltip;
	end
	UI.DataError("GetCloudNotifyString error: unhandled CloudNotifyType.  @assign bolson");
	return "UNHANDLED CLOUD NOTIFY TYPE";
end

function SetCloudUnseenComplete(haveCompletedGame :boolean)
	if(m_hasCloudUnseenComplete ~= haveCompletedGame) then
		m_hasCloudUnseenComplete = haveCompletedGame;
		if (not ContextPtr:IsHidden()) then
			RealizeShellTabs()
		end
	end
end

-------------------------------------------------
-- Server Listing Button Handler (Dynamic)
-------------------------------------------------
function ServerListingButtonClick()
	if ( g_InstanceList ~= nil ) then
		for i,v in pairs( g_InstanceList ) do -- Iterating over the entire list solves some issues with stale information.
			v.Selected:SetHide( true );
		end
	end

	if(IsPlayByCloudJoinsDisabled()) then
		return;
	end

	if g_SelectedServerID and g_SelectedServerID >= 0 then
		-- Version mismatch check. 
		if(not CheckServerVersion(g_SelectedServerID)) then
			return;
		end

		local bSuccess, bPending = Network.JoinGame( g_SelectedServerID );
		if(not bSuccess) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_JOIN_FAILED", "LOC_GAME_ABANDONED_JOIN_FAILED_TITLE" );
		end
	end
end


-------------------------------------------------
-- Host Game Button Handler
-------------------------------------------------
function OnHostButtonClick()
	LuaEvents.Lobby_RaiseHostGame();
end


-------------------------------------------------
function UpdateRefreshButton()
	if (Matchmaking.IsRefreshingGameList()) then
		Controls.RefreshButton:LocalizeAndSetText("LOC_MULTIPLAYER_STOP_REFRESH_GAME_LIST");
		Controls.RefreshButton:LocalizeAndSetToolTip("LOC_MULTIPLAYER_STOP_REFRESH_GAME_LIST_TT");
	else
		Controls.RefreshButton:LocalizeAndSetText("LOC_MULTIPLAYER_REFRESH_GAME_LIST");
		Controls.RefreshButton:LocalizeAndSetToolTip("LOC_MULTIPLAYER_REFRESH_GAME_LIST_TT");
	end
	Controls.RefreshButton:SetSizeToText(40,22);
end

-------------------------------------------------
-- Refresh Game List Button Handler
-------------------------------------------------
function OnRefreshButtonClick()
	if (Matchmaking.IsRefreshingGameList()) then
		Matchmaking.StopRefreshingGameList();
		UpdateRefreshButton();
	else
		RebuildGameList();
	end	
end

-------------------------------------------------
-- Friends Button Handler
-------------------------------------------------
function OnFriendsButtonClick()
	Controls.FriendsCheck:SetCheck(not Controls.FriendsCheck:IsChecked()); 
	OnFriendsListToggled();
end

-------------------------------------------------
-- Join Code Button Handler
-------------------------------------------------
function OnJoinCodeButtonClick()
	m_joinCodeText = "";
	m_kPopupDialog:Close();
	m_kPopupDialog:AddTitle( Locale.Lookup("LOC_JOIN_CODE_POPUP_TITLE") );
	m_kPopupDialog:AddText( Locale.Lookup("LOC_JOIN_CODE_POPUP_TEXT"));
	m_kPopupDialog:AddEditBox( Locale.Lookup("LOC_JOIN_CODE_POPUP_EDITBOX"), nil, OnJoinCodeStringChange, JOINCODE_EDITBOX_COMMAND );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_CANCEL_BUTTON"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_JOIN_GAME"), OnJoinCodeOK );
	m_kPopupDialog:Open();
end

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function OnBackButtonClick()
	Close();
end


----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function OnInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			Close();
		end
	end
	return true;
end		

-- is this game list search type usable by the current browser state?
function IsCurrentSearchType(eSearchType)
	-- When browsing PlayByCloud games, filter based on the current browser mode.  This allows for parallel game list requests used when
	-- check for PBC new turns and completed games.
	if(IsUsingPlayByCloudGameList()
		and m_browserMode ~= eSearchType) then
		return false;	
	end

	-- When browsing CrossPlay, only let the CrossPlay games show
	if(IsUsingCrossPlayGameList()) then
		return (eSearchType == LobbyTypes.LOBBY_CROSSPLAY);
	end

	return true;
end			

-------------------------------------------------
-- Event Handler: MultiplayerGameListClear
-------------------------------------------------
function OnGameListClear(eSearchType)
	if(ContextPtr:IsVisible()) then
		if(not IsCurrentSearchType(eSearchType)) then
			return;
		end

		UpdateRefreshButton();
	end
end

-------------------------------------------------
-- Event Handler: MultiplayerGameListComplete
-------------------------------------------------
function OnGameListComplete(eLobbyType, eSearchType)
	if(ContextPtr:IsVisible()) then
		if(not IsCurrentSearchType(eSearchType)) then
			return;
		end

		UpdateRefreshButton();

		if(IsGameListBatchUpdating()) then
			-- Batch update of game list is complete.  We need to display it now.
			SortAndDisplayListings(true);
		end
	end
end



-------------------------------------------------
-- Event Handler: MultiplayerGameListUpdated
-------------------------------------------------
function OnGameListUpdated(eAction, idLobby, eLobbyType, eSearchType)
	if(ContextPtr:IsVisible()) then
		if(not IsCurrentSearchType(eSearchType)) then
			return;
		end

		if (eAction == GAMELISTUPDATE_ADD) then
			local serverTable = Matchmaking.GetGameListEntry(idLobby);		
			if (serverTable ~= nil) then 
				AddServer( serverTable[1] );
				bUpdate = true;
			end
		else
			if (eAction == GAMELISTUPDATE_REMOVE) then
				RemoveServer( idLobby );
				if (g_SelectedServerID == idLobby) then
					g_SelectedServerID = nil;
				end
				bUpdate = true;
			end
		end
		-- NETTODO - The performance of resorting and displaying the entire list for every new game list entry is TERRIBLE!  This needs to be reworked.
		if (not IsGameListBatchUpdating()
			and bUpdate) then
			SortAndDisplayListings(true);
		end
	end
end

-------------------------------------------------
-- Event Handler: BeforeMultiplayerInviteProcessing
-------------------------------------------------
function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end

-------------------------------------------------
-- Event Handler: CloudTurnCheckComplete
-------------------------------------------------
function OnCloudTurnCheckComplete(notifyType :number, turnGameName :string, inGames :boolean, notifyMatchID :number)
	m_inPBCGames = inGames;
end

-------------------------------------------------
-- Event Handler: CloudUnseenCompleteCheckComplete
-------------------------------------------------
function OnCloudUnseenCompleteCheckComplete(haveCompletedGame :boolean, gameName :string, matchID :number)
	SetCloudUnseenComplete(haveCompletedGame);
end

-------------------------------------------------
-- Event Handler: OnJoinGameComplete
-------------------------------------------------
function OnJoinGameComplete()
	-- When we joined into a PlayByCloud match, activate m_inPBCGames.  We know we are in a match now and we don't want to wait for the next cloud notify check.
	if(GameConfiguration.IsPlayByCloud() == true) then
		m_inPBCGames = true;
	end
end


-------------------------------------------------
-- Event Handler: ChangeMPLobbyMode
-------------------------------------------------
function OnChangeMPLobbyMode(newLobbyMode)
	print("OnChangeMPLobbyMode: " .. tostring(newLobbyMode));	--debug
	m_lobbyModeName = newLobbyMode;
end

-------------------------------------------------
-------------------------------------------------
function SelectGame( serverID )

	-- Reset the selection state of all the listings.
	if ( g_InstanceList ~= nil ) then
		for i,v in pairs( g_InstanceList ) do -- Iterating over the entire list solves some issues with stale information.
			v.Selected:SetHide( true );
		end
	end

	local listItem = g_InstanceList[ serverID ];
	if ( serverID ~= nil and listItem ~= nil ) then
		Controls.JoinGameButton:SetDisabled(false);

		listItem.Selected:SetHide(false);
		listItem.Selected:SetToBeginning();
		listItem.Selected:Play();
	else
		Controls.JoinGameButton:SetDisabled(false);
		if listItem ~= nil then
			listItem.Selected:SetHide(true);
		end
	end

	-- If this is a completed PlayByCloud game, set it as seen because we selected it.
	if(m_lobbyModeName == MPLobbyTypes.PLAYBYCLOUD and m_browserMode == LIST_COMPLETED_GAMES) then
		local serverListing = GetServerListing(serverID);
		if(serverListing ~= nil 
			and serverListing.UnseenComplete ~= nil 
			and serverListing.UnseenComplete == true) then
			Network.SetCompletedGameSeen(serverID);

			-- Set and refresh UnseenComplete in the UI.
			serverListing.UnseenComplete = false;
			SortAndDisplayListings(false);
			CheckAllSeenCompletedGames(); -- Handle the case where this unseen change means we have seen all previously unseen games.
		end
	end

	-- Set Join/Play state and default tooltip.
	if(m_lobbyModeName == MPLobbyTypes.PLAYBYCLOUD and m_browserMode == LIST_PERSONAL_GAMES) then
		Controls.JoinGameButton:SetText(LOC_MULTIPLAYER_PLAY_GAME);
		Controls.JoinGameButton:SetToolTipString(LOC_MULTIPLAYER_PLAY_GAME_TT);
	else
		Controls.JoinGameButton:SetText(LOC_MULTIPLAYER_JOIN_GAME);
		Controls.JoinGameButton:SetToolTipString(LOC_MULTIPLAYER_JOIN_GAME_TT);
	end

	-- Set disabled state and reasoning tooltip
	if(IsPlayByCloudJoinsDisabled()) then
		Controls.JoinGameButton:SetDisabled(true);
		Controls.JoinGameButton:SetToolTipString(playByCloudJoinsDisabled);
	elseif(not CheckServerVersion(serverID)) then
		Controls.JoinGameButton:SetDisabled(true);
		Controls.JoinGameButton:SetToolTipString(joinDisabledVersionMismatch);
	end
	
	Controls.BottomButtons:CalculateSize();

	g_SelectedServerID = serverID;
end

-- Checks to see if all completed PBC games have been seen.  If so, update the m_hasCloudUnseenComplete and the completed games shelltab.
function CheckAllSeenCompletedGames()
	for _,listServer in ipairs(g_Listings) do
		if(listServer.UnseenComplete ~= nil and listServer.UnseenComplete == true) then
			-- There is still a unseen completed game.  We are done.
			return;
		end
	end

	-- All the current completed games have been seen. Remove the unseen notification from the shelltab.
	SetCloudUnseenComplete(false);
end

-------------------------------------------------
-------------------------------------------------
function SelectAndJoinGame( serverID )
	SelectGame(serverID);
	ServerListingButtonClick();
end

-------------------------------------------------
-------------------------------------------------
function AddServer(serverEntry)

	-- Check if server is already in the listings.
	for _,listServer in ipairs(g_Listings) do
		if(serverEntry.serverID == listServer.ServerID) then
			return;
		end
	end

	local rulesetName;
	
	-- Try to look up bundled text.
	if(serverEntry.RuleSetName) then
		rulesetName = Locale.Lookup(serverEntry.RuleSetName);
	end


	-- Fall-back to unknown.
	if(rulesetName == nil or #rulesetName == 0) then
		rulesetName = Locale.Lookup("LOC_MULTIPLAYER_UNKNOWN");
	end


	-- Try to look up bundled text.
	local gameSpeedName;
	if(serverEntry.GameSpeedName) then
		gameSpeedName = Locale.Lookup(serverEntry.GameSpeedName);
	end

	local mapName = Locale.Lookup(serverEntry.MapName);


	-- TODO: This needs to be modified to not reference GameInfo.
	-- GameInfo should only be used in-game.
	-- The map size name should instead be included as part of the server data.
	local mapSizeName = serverEntry.MapSizeName;
	if(mapSizeName == nil) then
		local mapSizeInfo = GameInfo.Maps[serverEntry.MapSize];
		if(mapSizeInfo) then
			mapSizeName = Locale.Lookup(mapSizeInfo.Name);
		end
	end

	if(mapSizeName == nil) then
		mapSizeName = Locale.Lookup("LOC_MULTIPLAYER_UNKNOWN_MAP_SIZE");
	end

	-- Fall-back to unknown.
	if(gameSpeedName == nil or #gameSpeedName == 0) then
		gameSpeedName = Locale.Lookup("LOC_MULTIPLAYER_UNKNOWN");
	end
	
	local listing = {
		Initialized = serverEntry.Initialized,
		ServerID = serverEntry.serverID,
		ServerName = serverEntry.serverName,
		GameVersion = serverEntry.GameVersion,
		MembersLabelCaption = serverEntry.numPlayers .. "/" .. serverEntry.maxPlayers,
		MembersLabelToolTip = ParseServerPlayers(serverEntry.Players),
		MembersSort = serverEntry.numPlayers,
		MapName = mapName,
		MapSize = serverEntry.MapSize,
		RuleSet = serverEntry.RuleSet,
		RuleSetName = rulesetName,
		GameSpeed = serverEntry.GameSpeed,
		GameSpeedName = gameSpeedName,
		EnabledMods = serverEntry.EnabledMods,
		EnabledGameModeNames = serverEntry.EnabledGameModeNames,
		MapSizeName = mapSizeName,
		GameStarted = serverEntry.GameStarted,
		SavedGame = serverEntry.SavedGame,
		CloudTurnPlayerName = serverEntry.CloudTurnPlayerName,
		ListID = m_nextListID
	};

	--Increment listID
	m_nextListID = m_nextListID + 1;

	if(m_lobbyModeName == MPLobbyTypes.PLAYBYCLOUD) then
		if(m_browserMode == LIST_PERSONAL_GAMES) then
			listing.CloudNotify = Network.CheckServerForCloudNotifications(listing.ServerID);
		elseif(m_browserMode == LIST_COMPLETED_GAMES) then
			listing.UnseenComplete = Network.CheckServerForUnseenComplete(listing.ServerID);
		end
	end
				
	-- Don't add servers that have an invalid Initialized value.  
	-- Steam lobbies briefly don't have meta data between getting created and getting their meta data from the game host.
	if(listing.Initialized ~= nil and listing.Initialized ~= FireWireTypes.FIREWIRE_INVALID_ID) then
		table.insert(g_Listings, listing);
	end
end

-------------------------------------------------
-------------------------------------------------
function RemoveServer(serverID) 

	local index = nil;
	repeat
		index = nil;
		for i,v in ipairs(g_Listings) do
			if(v.ServerID == serverID) then
				index = i;
				break;
			end
		end
		if(index ~= nil) then
			table.remove(g_Listings, index);
		end
	until(index == nil);
	
end

function ParseServerPlayers(playerList)
	-- replace comma separation with new lines.
	parsedPlayers = string.gsub(playerList, ", ", "[NEWLINE]"); 
	-- remove the unique network id that is post-script to each player's name. Example : "razorace@5868795"
	return string.gsub(parsedPlayers, "@(.-)%[NEWLINE%]", "[NEWLINE]");
end

-------------------------------------------------
-------------------------------------------------
function GetServerListing(serverID)
	for _,listServer in ipairs(g_Listings) do
		if(listServer.ServerID == serverID) then
			return listServer;
		end
	end

	return nil;
end

-------------------------------------------------
-------------------------------------------------
function GetFirstGameListID()
	local firstListID = FireWireTypes.FIREWIRE_INVALID_ID;
	for _,listServer in ipairs(g_Listings) do
		if(firstListID < 0 or listServer.ListID < firstListID) then
			firstListID = listServer.ListID;
		end
	end
	return firstListID;
end

-------------------------------------------------
-------------------------------------------------
function GetLastGameListID()
	local lastListID = FireWireTypes.FIREWIRE_INVALID_ID;
	for _,listServer in ipairs(g_Listings) do
		if(lastListID < 0 or listServer.ListID > lastListID) then
			lastListID = listServer.ListID;
		end
	end
	return lastListID;
end

-------------------------------------------------
-------------------------------------------------
function UpdateGameList() 
	-- Get the Current Server List
	local serverTable = Matchmaking.GetGameList();
		
	-- Display Each Server
	if serverTable then
		for i,v in ipairs( serverTable ) do
			AddServer( v );
		end
	end
	--[[
	for i=1,100 do 
		AddServer({
			serverID = i,
			serverName = "Server Name " .. i,
			numPlayers = i,
			maxPlayers = i,
			Players = "",
			MembersSort = i,
			MapName = "Map Name " .. i,
			MapSize = "MAPSIZE_STANDARD",
			RuleSet = "Rule Set " .. i,
			GameSpeed = "Game Speed " .. i,
			EnabledMods = "Mods " .. i
		});
	end
	--]]
	
	SortAndDisplayListings(true);
	SetupGridLines(table.count(g_Listings));
end

-------------------------------------------------
-------------------------------------------------
function UpdateFriendsList()

	if ContextPtr:IsHidden() then return; end

	g_FriendsIM:ResetInstances();

	local friends : table;
	friends = GetFriendsList(FlippedFriendsSortFunction);

	if table.count(friends) == 0 then
		Controls.Friends:SetHide(true);
		return;
	end
	Controls.Friends:SetHide(not m_shouldShowFriends);

	-- Build the dropdown for the friend list.
	local friendActions:table = {};
	local allowInvites:boolean = false;
	BuildFriendActionList(friendActions, allowInvites);
	-- end Build

	-- DEBUG
	--for i = 1, 9 do
	-- /DEBUG

	for _, friend in pairs(friends) do
		local instance:table = g_FriendsIM:GetInstance();
		PopulateFriendsInstance(instance, friend, friendActions);
	end
	-- DEBUG
	--end
	-- /DEBUG

	Controls.FriendsStack:CalculateSize();
	Controls.FriendsScrollPanel:CalculateSize();
	Controls.FriendsScrollPanel:GetScrollBar():SetAndCall(0);

	if Controls.FriendsScrollPanel:GetScrollBar():IsHidden() then
		Controls.FriendsBackground:SetSizeVal(FRIENDS_BG_WIDTH, table.count(friends) * FRIEND_HEIGHT + FRIENDS_BG_PADDING);
	else
		Controls.FriendsBackground:SetSizeVal(FRIENDS_BG_WIDTH + 10, FRIENDS_BG_HEIGHT);
	end
end

-- ===========================================================================
function SortAndDisplayListings(resetSelection:boolean)

	-- When using offset scrolling, the existing game list has already been sorted by the backend. 
	-- Having the UI re-sort the data would only make the data look unsorted when offset scrolling.
	if(not IsOffsetScrolling()) then
		table.sort(g_Listings, g_SortFunction);
	end

	g_InstanceManager:ResetInstances();
	g_InstanceList = {};
	
	for _, listing in ipairs(g_Listings) do
		local controlTable = g_InstanceManager:GetInstance();
		local serverID = listing.ServerID;
		local textColor = ColorSet_Default;
		local rowTooltip = "";
		local gameName = listing.ServerName;
		local localGameVersion :string = UI.GetAppVersion();
		g_InstanceList[serverID] = controlTable;

		-- Row color and tooltip is determined by game state.
		if(not CheckServerVersion(serverID)) then
		  -- Version mismatch
			textColor = ColorSet_VersionMismatch;
			if(rowTooltip ~= "") then
				rowTooltip = rowTooltip .. "[NEWLINE][NEWLINE]";
			end

			local serverGameVersion = "";
			if(listing.GameVersion ~= nil and #listing.GameVersion > 0) then
				serverGameVersion = listing.GameVersion;
			end
			rowTooltip = rowTooltip .. Locale.Lookup("LOC_LOBBY_GAME_VERSION_MISMATCH_TOOLTIP", serverGameVersion, localGameVersion);
		elseif(listing.SavedGame == 1
			and (not IsUsingPlayByCloudGameList() or m_browserMode == LIST_PUBLIC_GAMES)) then	-- In PlayByCloud, only show Loading-Saved status while on the open list.
																								-- (Knowing a PBC game is loading a save after joining it is not very helpful...)
			textColor = ColorSet_Faded;
			rowTooltip = gameLoadingSaveTooltip;
		elseif(listing.GameStarted == 1 
			and not IsUsingPlayByCloudGameList()) then	-- Don't use Game-is-Started tagging in PlayByCloud
														-- Any started game is not shown in the open games list and
														-- we want the player's personal/completed games to show as not faded.
			textColor = ColorSet_Faded;
			rowTooltip = gameStartedTooltip;
		end

		-- PlayByCloud Only - If it is your turn in this game, provide some UI feedback.
		if(listing.CloudNotify ~= nil and listing.CloudNotify ~= CloudNotifyTypes.CLOUDNOTIFY_NONE) then
			local cloudNotifyText = GetCloudNotifyString(listing.CloudNotify);
			if(rowTooltip ~= "") then
				rowTooltip = rowTooltip .. "[NEWLINE][NEWLINE]";
			end
			rowTooltip = rowTooltip .. cloudNotifyText;

			gameName = Locale.Lookup("LOC_LOBBY_GAME_NAME_YOUR_TURN", gameName);
		elseif(listing.UnseenComplete ~= nil and listing.UnseenComplete == true) then
			if(rowTooltip ~= "") then
				rowTooltip = rowTooltip .. "[NEWLINE][NEWLINE]";
			end
			rowTooltip = rowTooltip .. gameUnseenCompleteTooltip;

			gameName = Locale.Lookup("LOC_LOBBY_GAME_NAME_UNSEEN_COMPLETE", gameName);
		elseif(listing.CloudTurnPlayerName ~= nil and listing.CloudTurnPlayerName ~= "") then
			-- If it not your turn, display the name of the player who's turn it is.
			if(rowTooltip ~= "") then
				rowTooltip = rowTooltip .. "[NEWLINE][NEWLINE]";
			end

			local turnPlayerStr :string = Locale.Lookup("LOC_LOBBY_GAME_CLOUD_PLAYER_TURN_TOOLTIP", listing.CloudTurnPlayerName);
			rowTooltip = rowTooltip .. turnPlayerStr;
		end
		
		if(IsPlayByCloudJoinsDisabled()) then
			if(rowTooltip ~= "") then
				rowTooltip = rowTooltip .. "[NEWLINE][NEWLINE]";
			end
			rowTooltip = rowTooltip .. playByCloudJoinsDisabled;
		end
		
		controlTable.ServerNameLabel:SetText(gameName);
		controlTable.ServerNameLabel:SetColorByName(textColor);
		controlTable.ServerNameLabel:SetToolTipString(rowTooltip);
		controlTable.MembersLabel:SetText( listing.MembersLabelCaption);
		controlTable.MembersLabel:SetToolTipString(listing.MembersLabelToolTip);
		controlTable.MembersLabel:SetColorByName(textColor);

		-- RuleSet Info
		if (listing.RuleSetName) then
			controlTable.RuleSetBoxLabel:SetText(listing.RuleSetName);
		else
			controlTable.RuleSetBoxLabel:LocalizeAndSetText("LOC_MULTIPLAYER_UNKNOWN");
		end
		controlTable.RuleSetBoxLabel:SetColorByName(textColor);
		controlTable.RuleSetBoxLabel:SetToolTipString(rowTooltip);
		
		-- Map Type info	
		controlTable.ServerMapTypeLabel:LocalizeAndSetText(listing.MapName);
		controlTable.ServerMapTypeLabel:LocalizeAndSetToolTip(listing.MapSizeName);
		controlTable.ServerMapTypeLabel:SetColorByName(textColor);
		controlTable.ServerMapTypeLabel:SetToolTipString(rowTooltip);

		-- Game Speed
		if (listing.GameSpeedName) then
			controlTable.GameSpeedLabel:SetText(listing.GameSpeedName);
		else
			controlTable.GameSpeedLabel:LocalizeAndSetText("LOC_MULTIPLAYER_UNKNOWN");
		end
		controlTable.GameSpeedLabel:SetColorByName(textColor);
		controlTable.GameSpeedLabel:SetToolTipString(rowTooltip);

		-- Mod Info
		local hasMods = listing.EnabledMods ~= nil;
		local hasOfficialMods = false;
		local hasCommunityMods = false;
		local missingOfficial = false;

		if(hasMods) then
			
			local needsDownload = false;
			local officialModNames = {};
			local communityModNames = {};
				
			local mods = Modding.GetModsFromConfigurationString(listing.EnabledMods);
			if(mods) then
				for i,v in ipairs(mods) do
					
					local modIcon:string = nil;

					-- Check if mod is installed
					if(Modding.GetModHandle(v.ModId)) then
						local ownershipCheck : boolean = Modding.IsJoinGameAllowed(v.ModId);
						if(ownershipCheck == true) then
							modIcon = "[ICON_CheckSuccess]";
						else
							missingOfficial = true;
							modIcon = "[ICON_CheckFail]";
						end
					-- Mod isn't installed but is downloadable from Steam.
					elseif(v.SubscriptionId and #v.SubscriptionId > 0) then
						needsDownload = true;
						modIcon = "[ICON_DownloadContent]";
					-- Mod isn't installed and is not downloadable from Steam.
					else
						modIcon = "[ICON_CheckFail]";
					end
					
					if(Modding.IsModOfficial(v.ModId)) then
						table.insert(officialModNames, {v.Name, modIcon});
					else
						table.insert(communityModNames, {v.Name, modIcon});
					end
				end
			end

			SortAndColorizeMods(officialModNames);
			SortAndColorizeMods(communityModNames);

			if #officialModNames > 0 then
				hasOfficialMods = true;
				local ToolTipPrefix = Locale.Lookup("LOC_MULTIPLAYER_LOBBY_MODS_OFFICIAL") .. "[NEWLINE][NEWLINE]";
				controlTable.ModsOfficial:SetToolTipString(ToolTipPrefix .. table.concat(officialModNames, "[NEWLINE]"));
				controlTable.ModsOfficial:SetTexture(missingOfficial and "OfficialContent_Missing_Icon" or "OfficialContent_Owned");
			end

			if #communityModNames > 0 then
				hasCommunityMods = true;
				local ToolTipPrefix = Locale.Lookup("LOC_MULTIPLAYER_LOBBY_MODS_COMMUNITY") .. "[NEWLINE][NEWLINE]";
				controlTable.ModsCommunity:SetToolTipString(ToolTipPrefix .. table.concat(communityModNames, "[NEWLINE]"));
				controlTable.ModsCommunity:SetTexture(needsDownload and "CommunityContent_Missing" or "CommunityContent_Owned");
			end
		end

		-- Game Mode Info
		local hasGameModes : boolean = listing.EnabledGameModeNames ~= nil;

		if(hasGameModes)then
			local gameModes = Modding.GetGameModesFromConfigurationString(listing.EnabledGameModeNames);
			if(gameModes)then
				local ToolTipPrefix = Locale.Lookup("LOC_MULTIPLAYER_LOBBY_GAMEMODES_OFFICIAL") .. "[NEWLINE][NEWLINE]";
				local gameModeNames : string = "";
				for i,v in pairs(gameModes) do
					gameModeNames = gameModeNames .. "   " .. v.Name .. "[NEWLINE]";
				end
				if(gameModeNames ~= "")then
					local officialContentTooltip = controlTable.ModsOfficial:GetToolTipString();
					controlTable.ModsOfficial:SetToolTipString(ToolTipPrefix .. gameModeNames .. "[NEWLINE]" .. officialContentTooltip)
				end
			end
		end

		controlTable.ModsOfficial:SetHide(not hasOfficialMods);
		controlTable.ModsCommunity:SetHide(not hasCommunityMods);

		-- Enable the Button's Event Handler
		controlTable.Button:SetVoid1( serverID ); -- List ID
		controlTable.Button:RegisterCallback( Mouse.eLClick, SelectGame );
		controlTable.Button:RegisterCallback( Mouse.eLDblClick, SelectAndJoinGame );

		if resetSelection then
			controlTable.Selected:SetHide( true );
		end
	end
	
	Controls.ListingScrollPanel:CalculateInternalSize();

	local listWidth:number = Controls.ListingScrollPanel:GetScrollBar():IsHidden() and 1024 or 1004;
	Controls.ListingScrollPanel:SetSizeX(listWidth);

	-- Adjust horizontal grid lines
	listWidth = listWidth - 5;
	for _, instance in ipairs(g_GridLinesIM.m_AllocatedInstances) do
		instance.Control:SetEndX(listWidth);
	end

	-- Adjust vertical grid lines
	Controls.ListingStack:CalculateSize();
	local gridLineHeight:number = math.max(Controls.ListingStack:GetSizeY(), Controls.ListingScrollPanel:GetSizeY());
	for i = 1, NUM_COLUMNS do
		Controls["GridLine_" .. i]:SetEndY(gridLineHeight);
	end
	
	Controls.GridContainer:SetSizeY(gridLineHeight);
end

function SortAndColorizeMods(modNames)
	if #modNames > 0 then
		-- Sort mods.
		table.sort(modNames, function(a,b) return Locale.Compare(a[1], b[1]) == -1; end);

		-- Colorize.
		for i,v in ipairs(modNames) do
			if(v[2]) then
				modNames[i] = v[2] .. " " .. v[1];
			else
				modNames[i] = v[1];
			end
		end
	end
end

-- ===========================================================================
--	Leave the Lobby
-- ===========================================================================
function Close()
	m_kPopupDialog:Close(); -- [TTP 43100] Close any popup dialogs so they won't still be around if the player comes back to the lobby.

	Network.LeaveGame();
	UIManager:DequeuePopup( ContextPtr );
	
	-- Reset the selection state of all the listings.
	if ( g_InstanceList ~= nil ) then
		for i,v in pairs( g_InstanceList ) do -- Iterating over the entire list solves some issues with stale information.
			v.Selected:SetHide( true );
		end
	end
end

-- ===========================================================================
function AdjustScreenSize()
	local _, screenY:number = UIManager:GetScreenSizeVal();	

	local gameListY	:number = 0;
	Controls.ListingScrollPanel:CalculateSize();
	Controls.MainWindow:SetSizeY( screenY- (Controls.LogoContainer:GetSizeY() + Controls.LogoContainer:GetOffsetY()));

	local HEIGHT_SHELL_TABS :number = 40;	-- Approx height (this is the row that includes the join button)

	-- Account for whether or not there is a navigation bar above the list.
	if IsJoinCodeAllowed() then 
		Controls.GameListRoot:SetSizeY( Controls.MainWindow:GetSizeY() - (Controls.BottomButtons:GetSizeY() + Controls.TopNavigationPanel:GetSizeY() + HEIGHT_SHELL_TABS));
		gameListY = Controls.GameListRoot:GetSizeY();		
		Controls.GameListGrid:SetSizeY( gameListY );
		Controls.GameListRoot:SetOffsetY(GAME_LIST_TABS_OFFSET_Y);
	else
		Controls.GameListRoot:SetSizeY( Controls.MainWindow:GetSizeY() - (Controls.BottomButtons:GetSizeY() + Controls.TopNavigationPanel:GetSizeY() ));
		gameListY = Controls.GameListRoot:GetSizeY();		
		Controls.GameListGrid:SetSizeY( gameListY );				
		
		Controls.GameListRoot:SetOffsetY(GAME_LIST_OFFSET_Y);
		Controls.FriendsButton:SetSizeX(Controls.FriendsCheck:GetSizeX() + 20);
	end

	local HEIGHT_BOTTOM_NAVIGATION :number = 60;
	local HEIGHT_SCROLLBAR_BUTTONS :number = 30;
	Controls.ListingScrollPanel:SetSizeY( gameListY - HEIGHT_BOTTOM_NAVIGATION );
	Controls.ListingScrollPanelBar:SetSizeY( gameListY - (HEIGHT_BOTTOM_NAVIGATION + HEIGHT_SCROLLBAR_BUTTONS) );
end

-- ===========================================================================
function OnUpdateUI( type )
	if( type == SystemUpdateUI.ScreenResize ) then
		AdjustScreenSize();
	end
end

-- ===========================================================================
-- Event Handler: MultiplayerGameLaunched
-- ===========================================================================
function OnGameLaunched()
	--UIManager:DequeuePopup( ContextPtr );
end


-- ===========================================================================
-- Event Handler: Load Game Button Handler
-- ===========================================================================
function OnLoadButtonClick()
	local serverType = ServerTypeForMPLobbyType(m_lobbyModeName);
	local gameMode = GameModeTypeForMPLobbyType(m_lobbyModeName);
	-- Load game screen needs valid ServerType and GameMode.
	LuaEvents.HostGame_SetLoadGameServerType(serverType);
	GameConfiguration.SetToDefaults(gameMode);
	UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current);	
	--LuaEvents.Lobby_ShowLoadScreen();
end

-- ===========================================================================
function OnJoinCodeStringChange(editBox :table)
	m_joinCodeText = editBox:GetText();
end

-- ===========================================================================
function OnJoinCodeCommit(joinCodeString)
	m_kPopupDialog:Close(); -- Close popup dialog.
	if(joinCodeString ~= nil and joinCodeString ~= "") then
		local bSuccess, bPending = Network.JoinGameByJoinCode(joinCodeString);
		if(not bSuccess) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_JOIN_FAILED", "LOC_GAME_ABANDONED_JOIN_FAILED_TITLE" );
		end
	end
end

-- ===========================================================================
function OnJoinCodeOK()
	OnJoinCodeCommit(m_joinCodeText);
end

-- ===========================================================================
function OnListingScrollUpEnd()
	if(ContextPtr:IsVisible()) then
		if(IsOffsetScrolling() and not Matchmaking.IsRefreshingGameList()) then
			local firstListID = GetFirstGameListID();
			if(firstListID > 0) then -- We can only scroll up if we are not already at the very top of the list.
				-- New offset should be one list range before the first listID, if possible
				SetBrowserOffset(firstListID - PLAYBYCLOUD_LIST_RANGE);
				Matchmaking.RefreshGameList();
			end
		end
	end
end

-- ===========================================================================
function OnListingScrollDownEnd()
	if(ContextPtr:IsVisible()) then
		if(IsOffsetScrolling() and not Matchmaking.IsGameListAtEnd() and not Matchmaking.IsRefreshingGameList()) then
			-- new offset should be the one past the last listID we have.
			local lastListID = GetLastGameListID();
			SetBrowserOffset(lastListID+1);
			Matchmaking.RefreshGameList();
		end
	end
end

-- ===========================================================================
-- Sorting Support
-- ===========================================================================
function AlphabeticalSortFunction(field, direction, secondarySort)
	if(direction == "asc") then
		return function(a,b)
			local va = (a ~= nil and a[field] ~= nil) and a[field] or "";
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or "";
			
			if(secondarySort ~= nil and va == vb) then
				return secondarySort(a,b);
			else
				return Locale.Compare(va, vb) == -1;
			end
		end
	elseif(direction == "desc") then
		return function(a,b)
			local va = (a ~= nil and a[field] ~= nil) and a[field] or "";
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or "";
			
			if(secondarySort ~= nil and va == vb) then
				return secondarySort(a,b);
			else
				return Locale.Compare(va, vb) == 1;
			end
		end
	end
end

-- ===========================================================================
function NumericSortFunction(field, direction, secondarySort)
	if(direction == "asc") then
		return function(a,b)
			local va = (a ~= nil and a[field] ~= nil) and a[field] or -1;
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or -1;
			
			if(secondarySort ~= nil and tonumber(va) == tonumber(vb)) then
				return secondarySort(a,b);
			else
				return tonumber(va) < tonumber(vb);
			end
		end
	elseif(direction == "desc") then
		return function(a,b)
			local va = (a ~= nil and a[field] ~= nil) and a[field] or -1;
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or -1;

			if(secondarySort ~= nil and tonumber(va) == tonumber(vb)) then
				return secondarySort(a,b);
			else
				return tonumber(vb) < tonumber(va);
			end
		end
	end
end

-- ===========================================================================
function GetSortFunction(sortOptions)
	local orderBy = nil;
	for i,v in ipairs(sortOptions) do
		if(v.CurrentDirection ~= nil) then
			local secondarySort = nil;
			if(v.SecondaryColumn ~= nil) then
				if(v.SecondarySortType == "numeric") then
					secondarySort = NumericSortFunction(v.SecondaryColumn, v.SecondaryDirection)
				else
					secondarySort = AlphabeticalSortFunction(v.SecondaryColumn, v.SecondaryDirection);
				end
			end
		
			if(v.SortType == "numeric") then
				return NumericSortFunction(v.Column, v.CurrentDirection, secondarySort);
			else
				return AlphabeticalSortFunction(v.Column, v.CurrentDirection, secondarySort);
			end
		end
	end
	
	return nil;
end

-- ===========================================================================
-- Updates the sort option structure
function UpdateSortOptionState(sortOptions, selectedOption)
	-- Current behavior is to only have 1 sort option enabled at a time 
	-- though the rest of the structure is built to support multiple in the future.
	-- If a sort option was selected that wasn't already selected, use the default 
	-- direction.  Otherwise, toggle to the other direction.
	for i,v in ipairs(sortOptions) do
		if(v == selectedOption) then
			if(v.CurrentDirection == nil) then			
				v.CurrentDirection = v.DefaultDirection;
			else
				if(v.CurrentDirection == "asc") then
					v.CurrentDirection = "desc";
				else
					v.CurrentDirection = "asc";
				end
			end
		else
			v.CurrentDirection = nil;
		end
	end
end

-- ===========================================================================
-- Registers the sort option controls click events
-- ===========================================================================
function RegisterSortOptions()
	-- UI based sorting is disabled while using offset scrolling.  
	-- The game list feeder itself must do the sorting or the results won't make any sense when offset scrolling.
	local sortDisabled : boolean = IsOffsetScrolling();

	for i,v in ipairs(g_SortOptions) do
		if(v.Button ~= nil) then
			v.Button:RegisterCallback(Mouse.eLClick, function() SortOptionSelected(v); end);
			v.Button:SetDisabled(sortDisabled);
		end
	end

	g_SortFunction = GetSortFunction(g_SortOptions);

	if(IsOffsetScrolling()) then
		for i,v in ipairs(g_SortOptions) do
			if(v.Column == "ListID") then
				SortOptionSelected(v);
			end
		end
	end
end

-- ===========================================================================
-- Callback for when sort options are selected.
-- ===========================================================================
function SortOptionSelected(option)
	local sortOptions = g_SortOptions;
	UpdateSortOptionState(sortOptions, option);
	g_SortFunction = GetSortFunction(sortOptions);
	
	SortAndDisplayListings(false);
end

-- ===========================================================================
function SetupGridLines(numServers:number)
	local nextY:number = GRID_LINE_HEIGHT;
	local gridSize:number = Controls.GridContainer:GetSizeY();
	local numLines:number = math.max(numServers, gridSize / GRID_LINE_HEIGHT);
	g_GridLinesIM:ResetInstances();
	for i:number = 1, numLines do
		g_GridLinesIM:GetInstance().Control:SetOffsetY(nextY);
		nextY = nextY + GRID_LINE_HEIGHT;
	end
end

-- ===========================================================================
function OnShow()
	-- You should not be in a network session when showing the lobby screen because the lobby screen
	-- reconfigures the network system's lobby object.  This will corrupt your network lobby object.
	if Network.IsInSession() then
		UI.DataError("Showing lobby but currently in a game.  This could corrupt your lobby.  @assign bolson");
	end
	
	-- Initialize network lobby for lobby mode.
	Matchmaking.InitLobby(LobbyTypeForMPLobbyType(m_lobbyModeName));

	-- Set default game list filter.
	-- PLAYBYCLOUD uses Matchmaking.SetBrowseMode().
	-- Steam Lobby (Internet) uses Matchmaking.SetGameListType().
	if (m_lobbyModeName == MPLobbyTypes.PLAYBYCLOUD) then
		if(m_inPBCGames) then
			SetBrowserMode(LIST_PERSONAL_GAMES);
		else
			SetBrowserMode(LIST_PUBLIC_GAMES);
		end
	elseif (m_lobbyModeName == MPLobbyTypes.PITBOSS_INTERNET) then
		Matchmaking.SetGameListType( LIST_SERVERS, SEARCH_INTERNET );
	elseif (m_lobbyModeName == MPLobbyTypes.PITBOSS_LAN) then 
		Matchmaking.SetGameListType( LIST_SERVERS, SEARCH_LAN );
	elseif (m_lobbyModeName == MPLobbyTypes.CROSSPLAY_INTERNET) then 
		Matchmaking.SetGameListType( LIST_LOBBIES, SEARCH_CROSSPLAY );
	else
		Matchmaking.SetGameListType( LIST_LOBBIES, SEARCH_INTERNET );
	end

	RealizeShellTabs();

	UpdateGameList();
	RebuildGameList();
		
	if IsUsingPlayByCloudGameList() then
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_CLOUD_LOBBY");
	elseif IsUsingPitbossGameList() then
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_PITBOSS_LOBBY");
	elseif IsUsingInternetGameList() then
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_INTERNET_LOBBY");
	elseif IsUsingCrossPlayGameList() then
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_CROSSPLAY_LOBBY");
	else
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_LAN_LOBBY");
	end

	UpdateFriendsList();

	local pFriends = Network.GetFriends();
	if (pFriends ~= nil) then
		pFriends:SetRichPresence("civPresence", "LOC_PRESENCE_IN_SHELL");
	end

	if(IsUsingPlayByCloudGameList()) then
		-- Display PlayByCloud Notification Setup Reminder if no notification methods are set.
		local remindNotify = Options.GetUserOption("Interface", "PlayByCloudNotifyRemind");
		if(m_firstTimeShow and remindNotify ~= nil and remindNotify == 1) then
			Controls.PBCNotifyRemind:SetHide(false);
		end	
	end

	m_firstTimeShow = false;
end

-- ===========================================================================
function OnHide()
	ClearGameList();
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
function OnFriendsListToggled()
	m_shouldShowFriends = Controls.FriendsCheck:IsChecked();
	Controls.Friends:SetHide(not m_shouldShowFriends);
	UpdateFriendsList();
end

-- ===========================================================================
function OnBrowserModeClicked(browserMode :number)
	SetBrowserMode(browserMode); 

	-- Updated selected state
	FilterTabsSetSelected(g_TabInstances[browserMode]);

	RebuildGameList();
end

-- ===========================================================================
function FilterTabsSetSelected(shellTabControl :table)
	for i,v in ipairs( g_TabInstances ) do
		local isSelected = shellTabControl == v;
		v.Selected:SetHide(not isSelected);
	end
end

-- ===========================================================================
function AddShellTab(browserModeType :number, buttonText :string, buttonTooltip :string)
	local newTab:table = m_shellTabIM:GetInstance();
	newTab.Button:SetText(buttonText);
	newTab.Button:SetToolTipString(buttonTooltip);
	newTab.SelectedButton:SetText(buttonText);
	newTab.SelectedButton:SetToolTipString(buttonTooltip);
	newTab.Button:SetVoid1(browserModeType);
	newTab.Button:RegisterCallback( Mouse.eLClick, OnBrowserModeClicked );

	AutoSizeGridButton(newTab.Button,200,32,10,"H");
	AutoSizeGridButton(newTab.SelectedButton,200,32,20,"H");
	newTab.TopControl:SetSizeX(newTab.Button:GetSizeX());
	g_TabInstances[browserModeType] = newTab;
end

-- ===========================================================================
--	Can join codes be used in the current lobby system?
-- ===========================================================================
function IsJoinCodeAllowed()
	local pbcMode			:boolean = IsUsingPlayByCloudGameList();
	local crossPlayMode		:boolean = IsUsingCrossPlayGameList();
	local eosAllowed		:boolean = (Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS) and IsUsingInternetGameList();
	return pbcMode or crossPlayMode or eosAllowed;
end

-- ===========================================================================
function RealizeShellTabs()
	m_shellTabIM:ResetInstances();
	g_TabInstances = {};

	if IsUsingPlayByCloudGameList() then
		AddShellTab(LIST_PERSONAL_GAMES, LOC_LOBBY_MY_GAMES, LOC_LOBBY_MY_GAMES_TT);
		AddShellTab(LIST_PUBLIC_GAMES, LOC_LOBBY_OPEN_GAMES, LOC_LOBBY_OPEN_GAMES_TT);

		if(m_hasCloudUnseenComplete == true) then
			AddShellTab(LIST_COMPLETED_GAMES, LOC_LOBBY_COMPLETED_GAMES_UNSEEN, LOC_LOBBY_COMPLETED_GAMES_UNSEEN_TT);
		else
			AddShellTab(LIST_COMPLETED_GAMES, LOC_LOBBY_COMPLETED_GAMES, LOC_LOBBY_COMPLETED_GAMES_TT);
		end

		-- Set the current browser mode tab as selected.
		FilterTabsSetSelected(g_TabInstances[m_browserMode]); 
	end

	Controls.JoinCodeButton:SetHide( IsJoinCodeAllowed()==false );
	
	AdjustScreenSize();
	AutoSizeGridButton(Controls.JoinCodeButton,200,32,10,"H");
	Controls.ShellTabs:CalculateSize();
end

-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()
	
	-- Setup initial grid lines, grid is refreshed anytime servers are updated
	SetupGridLines(0);

	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler(OnInputHandler);
	ContextPtr:SetShowHandler(OnShow);
	ContextPtr:SetHideHandler(OnHide);

	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBackButtonClick );
	Controls.HostButton:RegisterCallback( Mouse.eLClick, OnHostButtonClick );
	Controls.JoinGameButton:RegisterCallback( Mouse.eLClick, ServerListingButtonClick );		-- set up join game callback
	Controls.LoadGameButton:RegisterCallback( Mouse.eLClick, OnLoadButtonClick );
	Controls.JoinCodeButton:RegisterCallback( Mouse.eLClick, OnJoinCodeButtonClick );
	Controls.RefreshButton:RegisterCallback( Mouse.eLClick, OnRefreshButtonClick );
	Controls.FriendsButton:RegisterCallback( Mouse.eLClick, OnFriendsButtonClick );
	Controls.FriendsCheck:RegisterCheckHandler( OnFriendsListToggled );
	Controls.ListingScrollPanel:RegisterUpEndCallback( OnListingScrollUpEnd );
	Controls.ListingScrollPanel:RegisterDownEndCallback( OnListingScrollDownEnd );
	
	Events.SteamFriendsStatusUpdated.Add( UpdateFriendsList );
	Events.SteamFriendsPresenceUpdated.Add( UpdateFriendsList );
	Events.MultiplayerGameLaunched.Add( OnGameLaunched );
	Events.MultiplayerGameListClear.Add( OnGameListClear );
	Events.MultiplayerGameListComplete.Add( OnGameListComplete );
	Events.MultiplayerGameListUpdated.Add( OnGameListUpdated );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );
	Events.CloudTurnCheckComplete.Add( OnCloudTurnCheckComplete );
	Events.CloudUnseenCompleteCheckComplete.Add( OnCloudUnseenCompleteCheckComplete );
	Events.MultiplayerJoinGameComplete.Add( OnJoinGameComplete);
	Events.SystemUpdateUI.Add( OnUpdateUI );
	
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.ChangeMPLobbyMode.Add( OnChangeMPLobbyMode );
	
	ResizeButtonToText(Controls.RefreshButton);
	ResizeButtonToText(Controls.BackButton);
	RegisterSortOptions();
	AdjustScreenSize();

	-- Custom popup setup	
	m_kPopupDialog = PopupDialog:new( "LobbyPopupDialog" );
	m_kPopupDialog:SetInstanceNames(nil, nil, nil, nil, nil, nil, nil, nil, nil, Controls.LobbyPopupEditboxInstance);
end
Initialize();

