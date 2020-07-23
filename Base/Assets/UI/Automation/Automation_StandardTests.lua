----------------------------------------------------------------
-- A set of standard automation tests. 
----------------------------------------------------------------
include("LobbyTypes");

local GAMELISTUPDATE_ADD			:number = 3;
local DEFAULT_AUTOMATION_TURNS		:number = -1;

Tests = {};	-- The table of test routines.


-----------------------------------------------------------------
-- A test to start a new game an autoplay it for a set number of turns.
-----------------------------------------------------------------

function SharedGame_OnSaveComplete()
	-- Signal that the test is complete.  Do not call LuaEvents.AutomationTestComplete() directly.  The Automation system will do that at a safe time.
	Automation.Log("Save complete. Completing current test.");
	Automation.SendTestComplete();
end

-----------------------------------------------------------------
-- Handle the autoplay end for the "PlayGame" and "HostGame" tests
function SharedGame_OnAutoPlayEnd()
	Automation.Log("The autoplay manager has deactivated. (See autoplay.log) Saving game prior to completing current test. ");

	local saveGame = {};
	saveGame.Name = Automation.GenerateSaveName();
	saveGame.Location = SaveLocations.LOCAL_STORAGE;
	saveGame.Type= SaveTypes.SINGLE_PLAYER;
	saveGame.IsAutosave = false;
	saveGame.IsQuicksave = false;

	Network.SaveGame(saveGame);

	-- Saves are not immediate, wait for the completion event.
	Events.SaveComplete.Add( SharedGame_OnSaveComplete );
end

-----------------------------------------------------------------
function UpdatePlayerCounts()

	local defaultPlayers = nil;
	local mapSize = MapConfiguration.GetMapSize();
	local def = GameInfo.Maps[mapSize];
	if (def) then
		defaultPlayers = def.DefaultPlayers;
	end

	if (defaultPlayers ~= nil) then
		MapConfiguration.SetMaxMajorPlayers(defaultPlayers);
		GameConfiguration.SetParticipatingPlayerCount(defaultPlayers + GameConfiguration.GetHiddenPlayerCount());
	end
end

-----------------------------------------------------------------
function GetTrueOrFalse(value)
	if (value ~= nil) then
		local asString = string.upper(tostring(value));
		if (asString == "FALSE") then
			return false;
		elseif (asString == "TRUE") then
			return true;
		elseif (value >= 0) then
			return true;
		end
	end
	return false;
end

-----------------------------------------------------------------
function ReadUserConfigOptions()

	local quickMoves = Automation.GetSetParameter("CurrentTest", "QuickMovement");
	if (quickMoves ~= nil) then		
		UserConfiguration.SetLockedValue("QuickMovement", GetTrueOrFalse(quickMoves));
	end

	local quickCombat = Automation.GetSetParameter("CurrentTest", "QuickCombat");
	if (quickCombat ~= nil) then		
		UserConfiguration.SetLockedValue("QuickCombat", GetTrueOrFalse(quickCombat));
	end

end

-----------------------------------------------------------------
function GetTestLobbyType()
	local lobbyType :number = LobbyTypes.LOBBY_LAN;
	local mpLobbyTypeParam :string = Automation.GetSetParameter("CurrentTest", "MPLobbyType");
	if(mpLobbyTypeParam ~= nil) then
		local paramLobbyType :number = LobbyTypeForMPLobbyType(mpLobbyTypeParam);
		if(paramLobbyType ~= LobbyTypes.LOBBY_NONE) then
			lobbyType = paramLobbyType;
		end
	end
	return lobbyType;
end

-----------------------------------------------------------------
function GetTestServerType()
	local serverType :number = ServerType.SERVER_TYPE_LAN;
	local mpLobbyTypeParam :string = Automation.GetSetParameter("CurrentTest", "MPLobbyType");
	if(mpLobbyTypeParam ~= nil) then
		local paramServerType :number = ServerTypeForMPLobbyType(mpLobbyTypeParam);
		if(paramServerType ~= ServerType.SERVER_TYPE_NONE) then
			serverType = paramServerType;
		end
	end
	return serverType;
end

-----------------------------------------------------------------
function RestoreUserConfigOptions()

	UserConfiguration.LockValue("QuickMovement", false);
	UserConfiguration.LockValue("QuickCombat", false);

end
-----------------------------------------------------------------

function ApplyHumanPlayersToConfiguration()
	local humanPlayerCount = Automation.GetSetParameter("CurrentTest", "HumanPlayers");

	-- Convert any human slots to AI
	if ( humanPlayerCount == nil or humanPlayerCount == 0) then
		local aHumanIDs = GameConfiguration.GetHumanPlayerIDs();
		for _, id in ipairs(aHumanIDs) do
			PlayerConfigurations[id]:SetSlotStatus(SlotStatus.SS_COMPUTER);
		end
	else
		local neededHumanPlayers = humanPlayerCount - GameConfiguration.GetHumanPlayerCount();
		if neededHumanPlayers > 0 then
			local aAvailableIDs = GameConfiguration.GetAvailablePlayerIDs();
			for _, id in ipairs(aAvailableIDs) do
				PlayerConfigurations[id]:SetSlotStatus(SlotStatus.SS_TAKEN);
				neededHumanPlayers = neededHumanPlayers - 1;
				if neededHumanPlayers == 0 then
					break;
				end
			end
		end
		-- Still need human players? Take them from the AI slots
		if neededHumanPlayers > 0 then
			local aAIIDs = GameConfiguration.GetAIPlayerIDs();
			for _, id in ipairs(aAIIDs) do
				if (PlayerConfigurations[id]:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV) then
					PlayerConfigurations[id]:SetSlotStatus(SlotStatus.SS_TAKEN);
					neededHumanPlayers = neededHumanPlayers - 1;
					if neededHumanPlayers == 0 then
						break;
					end
				end
			end
		end
	end
end

-----------------------------------------------------------------
function ApplyCommonNewGameParametersToConfiguration()
	-- Did they specify a ruleset?
	local ruleSet = Automation.GetSetParameter("CurrentTest", "RuleSet");
	if (ruleSet ~= nil) then
		GameConfiguration.SetRuleSet(ruleSet);
	end

	-- Did they have a map script?
	local mapScript = Automation.GetSetParameter("CurrentTest", "MapScript");
	if (mapScript ~= nil) then		
		MapConfiguration.SetScript(mapScript);
		UpdatePlayerCounts();
	end

	-- Did they have a map size?
	local mapSize = Automation.GetSetParameter("CurrentTest", "MapSize");
	if (mapSize ~= nil) then		
		MapConfiguration.SetMapSize(mapSize);
		UpdatePlayerCounts();
	end

	-- Update the human counts.  Make sure this is after the MapScript and MapSize, that changes counts.
	ApplyHumanPlayersToConfiguration();

	-- Did they have a handicap/difficulty level?
	local handicap = Automation.GetSetParameter("CurrentTest", "Handicap");
	if (handicap == nil) then		
		handicap = Automation.GetSetParameter("CurrentTest", "Difficulty");		-- Letting them use an alias
	end
	if (handicap ~= nil) then		
		GameConfiguration.SetHandicapType(handicap);
	end

	-- Did they have a game speed?
	local gameSpeed = Automation.GetSetParameter("CurrentTest", "GameSpeed");
	if ( gameSpeed ~= nil ) then
		GameConfiguration.SetGameSpeedType(gameSpeed);
	end
	
	-- Did they have a map seed?
	local mapSeed = Automation.GetSetParameter("CurrentTest", "MapSeed");
	if (mapSeed ~= nil) then
		MapConfiguration.SetValue("RANDOM_SEED", mapSeed);
	end

	-- Or a Game Seed?
	local gameSeed = Automation.GetSetParameter("CurrentTest", "GameSeed");
	if (gameSeed ~= nil) then
		GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED", gameSeed);
	end

	-- Or a Start Era?
	local gameStartEra = Automation.GetSetParameter("CurrentTest", "StartEra");
	if (gameStartEra ~= nil) then
		GameConfiguration.SetStartEra(gameStartEra);
	end

	-- Or Max Turns?  This is Max turns for a Score victory, not the number of turns for the test.
	local maxTurns = Automation.GetSetParameter("CurrentTest", "MaxTurns");
	if (maxTurns ~= nil and maxTurns >= 1) then
		GameConfiguration.SetMaxTurns(maxTurns);
		GameConfiguration.SetTurnLimitType(TurnLimitTypes.CUSTOM);
	end

	local all_parameters = Automation.GetParameterSet("CurrentTest");
	if(all_parameters) then

		local tokGameConfiguration = "Game";
		local tokMapConfiguration = "Map";

		for k,v in pairs(all_parameters) do
			-- Apply custom configuration parameters.
			if(k:sub(1, #tokGameConfiguration) == tokGameConfiguration) then
				-- Game.<key> = <value>|#<hashed_value>

				local key = k:sub(#tokGameConfiguration+2);
				if(key and #key > 0) then
					local value = v;

					if(type(v) == "string") then
						if(string.sub(v, 1,1) == "#") then
							value = DB.MakeHash(v:sub(2));
						end
					end
					GameConfiguration.SetValue(key, value);
				end
			elseif(k:sub(1, #tokMapConfiguration) == tokMapConfiguration) then
				-- Map.<key> = <value>|#<hashed_value>

				local key = k:sub(#tokMapConfiguration+2);
				if(key and #key > 0) then
					local value = v;

					if(type(v) == "string") then
						if(string.sub(v, 1,1) == "#") then
							value = DB.MakeHash(v:sub(2));
						end
					end
					MapConfiguration.SetValue(key, value);
				end
			end
		end
	end
end
-----------------------------------------------------------------
Tests["PlayGame"] = {};

-- Startup function for "PlayGame"
Tests["PlayGame"].Run = function()

	-- We must be at the Main Menu to do this test.
	if (not UI.IsInFrontEnd()) then
		-- Exit back to the main menu
		Events.ExitToMainMenu();
		return;
	end

	-- Start a game
	GameConfiguration.SetToDefaults();

	-- Did they want to load a configuration?
	local configurationFile = Automation.GetSetParameter("CurrentTest", "LoadConfiguration");
	if (configurationFile ~= nil) then

		local loadParams = {};

		loadParams.Location = SaveLocations.LOCAL_STORAGE;
		loadParams.Type = SaveTypes.SINGLE_PLAYER;
		loadParams.FileType = SaveFileTypes.GAME_CONFIGURATION;
		loadParams.IsAutosave = false;
		loadParams.IsQuicksave = false;
		loadParams.Directory = SaveDirectories.DEFAULT;

		loadParams.Name = configurationFile;
		
		local configDirectory = Automation.GetSetParameter("CurrentTest", "ConfigurationDirectory");
		if (configDirectory ~= nil) then
			loadParams.Directory = configDirectory;
		end
		local bResult = Network.LoadGame(loadParams, ServerType.SERVER_TYPE_NONE);
		if (bResult == false) then
			Automation.SendTestComplete();
			return
		end
	end
	
	ApplyCommonNewGameParametersToConfiguration();
	
	ReadUserConfigOptions();

	Network.HostGame(ServerType.SERVER_TYPE_NONE);
end

-----------------------------------------------------------------
-- Respond to the Post Game Initialization for "PlayGame"
-- The game has been initialized (or loaded), but the app
-- side terrain generation, etc. has yet to be performed
Tests["PlayGame"].PostGameInitialization = function(bWasLoaded)
	
	LogCurrentPlayers();

	-- Add a handler for when the autoplay ends
	LuaEvents.AutoPlayEnd.Add( SharedGame_OnAutoPlayEnd );

	-- Get the optional Turns parameter from the CurrentTest parameter set
	-- If no turns are specified, we will assume that the auto-play is not active.
	-- A turn count of 0 means no turn limit.
	local turnCount = Automation.GetSetParameter("CurrentTest", "Turns");
	if turnCount ~= nil then
		local observeAs = GetCurrentTestObserver();
		
		AutoplayManager.SetTurns(turnCount);
		AutoplayManager.SetReturnAsPlayer(0);
		AutoplayManager.SetObserveAsPlayer(observeAs);

		AutoplayManager.SetActive(true);
	end

end

-----------------------------------------------------------------
-- Respond to the Game Start for "PlayGame"
-- The player will be able to see the map at this time.
Tests["PlayGame"].GameStarted = function()
	
	local observeAs = GetCurrentTestObserver();
		
	if (Game.GetLocalPlayer() == PlayerTypes.NONE) then
		-- We are starting as PlayerTypes.NONE and are most likely looking at nothing in particular.
		-- Look at who we are going to play.
		StartupObserverCamera(observeAs);
	else
		-- If there is a local player, then we have a human in the game.
		-- This test is complete.
		Automation.SendTestComplete();		
	end

end

-----------------------------------------------------------------
-- Stop handler for "PlayGame"
Tests["PlayGame"].Stop = function()

	-- Clean up anything the test needs to.
	LuaEvents.AutoPlayEnd.RemoveAll();

	Events.SaveComplete.Remove( SharedGame_OnSaveComplete );

	AutoplayManager.SetActive(false);		-- Make sure this is off

	RestoreUserConfigOptions();

end

-----------------------------------------------------------------
-- Test loading a game
-----------------------------------------------------------------
Tests["LoadGame"] = {};

-- Startup function for "LoadGame"
Tests["LoadGame"].Run = function()

	-- We must be at the Main Menu to do this test.
	if (not UI.IsInFrontEnd()) then
		-- Exit back to the main menu
		Events.ExitToMainMenu();
		return;
	end

	local hasLaunched = Automation.GetSetParameter("CurrentTest", "HasLaunched", 0);

	if (hasLaunched ~= 0) then
		-- Have we already launched?  If so, some error happened.
		Automation.SendTestComplete();
	else
		Automation.SetSetParameter("CurrentTest", "HasLaunched", 1);

		local loadGame = {};

		loadGame.Location = SaveLocations.LOCAL_STORAGE;
		loadGame.Type= SaveTypes.SINGLE_PLAYER;
		loadGame.IsAutosave = false;
		loadGame.IsQuicksave = false;
		loadGame.Directory = SaveDirectories.DEFAULT;

		local saveName = Automation.GetSetParameter("CurrentTest", "SaveName");
		if (saveName ~= nil) then
			loadGame.Name = saveName;
		else
			loadGame.Name = Automation.GetLastGeneratedSaveName();
		end
		local saveDirectory = Automation.GetSetParameter("CurrentTest", "SaveDirectory");
		if (saveDirectory ~= nil) then
			loadGame.Directory = saveDirectory;
		end
		
		ReadUserConfigOptions();

		local bResult = Network.LoadGame(loadGame, ServerType.SERVER_TYPE_NONE);
		if (bResult == false) then
			-- Automation.Log("Failed to load " .. tostring(loadGame.Name));
			Automation.SendTestComplete();
		end
	end
end

-----------------------------------------------------------------
-- Handle the autoplay end for the "LoadGame" test
function LoadGame_OnAutoPlayEnd()

	-- Signal that the test is complete.  Do not call LuaEvents.AutomationTestComplete() directly.  The Automation system will do that at a safe time.
	Automation.SendTestComplete();

end

-----------------------------------------------------------------
-- Respond to the Post Game Initialization for "LoadGame"
-- The game has been initialized (or loaded), but the app
-- side terrain generation, etc. has yet to be performed
Tests["LoadGame"].PostGameInitialization = function(bWasLoaded)
	
	-- Add a handler for when the autoplay ends
	LuaEvents.AutoPlayEnd.Add( LoadGame_OnAutoPlayEnd );

	-- Get the optional Turns parameter from the CurrentTest parameter set
	-- If no turns are specified, we will assume that the auto-play is not active.
	-- A turn count of 0 means no turn limit.
	local turnCount = Automation.GetSetParameter("CurrentTest", "Turns");
	if turnCount ~= nil then
		local observeAs = GetCurrentTestObserver();
		
		AutoplayManager.SetTurns(turnCount);
		AutoplayManager.SetReturnAsPlayer(0);
		AutoplayManager.SetObserveAsPlayer(observeAs);

		AutoplayManager.SetActive(true);
	end

end

-----------------------------------------------------------------
-- Respond to the Game Start for "LoadGame"
Tests["LoadGame"].GameStarted = function()
	
	local observeAs = GetCurrentTestObserver();
		
	if (Game.GetLocalPlayer() == PlayerTypes.NONE) then
		-- We are starting as PlayerTypes.NONE and are most likely looking at nothing in particular.
		-- Look at who we are going to play.
		StartupObserverCamera(observeAs);
	else
		-- If there is a local player, then we have a human in the game.
		-- This test is complete.
		Automation.SendTestComplete();		
	end

end

Tests["LoadGame"].Stop = function()

	RestoreUserConfigOptions();

end

-----------------------------------------------------------------
-- Host a multiplayer autoplay game
-----------------------------------------------------------------
Tests["HostGame"] = {};

-- Startup function for "HostGame"
Tests["HostGame"].Run = function()

	-- We must be at the Main Menu to do this test.
	if (not UI.IsInFrontEnd()) then
		-- Exit back to the main menu
		Events.ExitToMainMenu();
		return;
	end

	if(GetTestServerType() == ServerType.SERVER_TYPE_CROSSPLAY) then
		-- When using crossplay, we need to login to EOS before we can host our game.
		Events.CrossPlayLoginStateUpdated.Add(HostGame_OnCrossPlayLoginStateUpdated);
		Network.AttemptConnectionToCrossPlayLobbyService();
		return;
	end

	-- Start hosting now!
	HostAutoplayGame();
end

-----------------------------------------------------------------
-- Respond to the Post Game Initialization for "HostGame"
-- The game has been initialized (or loaded), but the app
-- side terrain generation, etc. has yet to be performed
Tests["HostGame"].PostGameInitialization = function(bWasLoaded)
	LogCurrentPlayers();

	-- Add a handler for when the autoplay ends
	LuaEvents.AutoPlayEnd.Add( SharedGame_OnAutoPlayEnd );

	-- Get the optional Turns parameter from the CurrentTest parameter set
	-- If no turns are specified, we will assume that the auto-play is not active.
	-- A turn count of 0 means no turn limit.
	local turnCount = Automation.GetSetParameter("CurrentTest", "Turns");
	if turnCount ~= nil then
		local observeAs = GetCurrentTestObserver();
		
		AutoplayManager.SetTurns(turnCount);
		AutoplayManager.SetReturnAsPlayer(0);
		AutoplayManager.SetObserveAsPlayer(observeAs);

		AutoplayManager.SetActive(true);
	end

end

-----------------------------------------------------------------
-- Respond to the Game Start for "HostGame"
-- The player will be able to see the map at this time.
Tests["HostGame"].GameStarted = function()
	
	local observeAs = GetCurrentTestObserver();
		
	-- The subscription in Run() is lost on game load.  Resubscribe so it works while ingame.
	Events.MultiplayerGameLastPlayer.Add( HostGame_OnMultiplayerGameLastPlayer );

	if (Game.GetLocalPlayer() == PlayerTypes.NONE) then
		-- We are starting as PlayerTypes.NONE and are most likely looking at nothing in particular.
		-- Look at who we are going to play.
		StartupObserverCamera(observeAs);
	else
		-- If there is a local player, then we have a human in the game.
		-- This test is complete.
		Automation.Log("Completing HostGame test due to there being a local player.");
		Automation.SendTestComplete();		
	end
end

-----------------------------------------------------------------
-- Stop handler for "HostGame"
Tests["HostGame"].Stop = function()

	-- Clean up anything the test needs to.
	LuaEvents.AutoPlayEnd.RemoveAll();

	Events.SaveComplete.Remove( SharedGame_OnSaveComplete );
	Events.MultiplayerGameLastPlayer.Remove( HostGame_OnMultiplayerGameLastPlayer );
	Events.CrossPlayLoginStateUpdated.Remove(HostGame_OnCrossPlayLoginStateUpdated);

	if(AutoplayManager ~= nil) then -- AutoplayManager will not exist if the script didn't get to gameplay.
		AutoplayManager.SetActive(false);		-- Make sure this is off
	end

	RestoreUserConfigOptions();

end

-----------------------------------------------------------------
function HostGame_OnMultiplayerGameLastPlayer()
	local quitParam = Automation.GetSetParameter("CurrentTest", "QuitOnLastPlayer");
	if (quitParam == nil or quitParam == 1) then	
		Automation.Log("Completing HostGame test due to becoming the last player.");
		-- Signal that the test is complete.  Do not call LuaEvents.AutomationTestComplete() directly.  The Automation system will do that at a safe time.
		Automation.SendTestComplete();
	end
end

function HostGame_OnCrossPlayLoginStateUpdated()
	Events.CrossPlayLoginStateUpdated.Remove(HostGame_OnCrossPlayLoginStateUpdated);

	HostAutoplayGame();
end

-----------------------------------------------------------------
function HostAutoplayGame()
	-- Start a game
	GameConfiguration.SetToDefaults();

	-- Did they want to load a configuration?
	local configurationFile = Automation.GetSetParameter("CurrentTest", "LoadConfiguration");
	if (configurationFile ~= nil) then

		local loadParams = {};

		loadParams.Location = SaveLocations.LOCAL_STORAGE;
		loadParams.Type = SaveTypes.NETWORK_MULTIPLAYER;
		loadParams.FileType = SaveFileTypes.GAME_CONFIGURATION;
		loadParams.IsAutosave = false;
		loadParams.IsQuicksave = false;
		loadParams.Directory = SaveDirectories.DEFAULT;

		loadParams.Name = configurationFile;
		
		local configDirectory = Automation.GetSetParameter("CurrentTest", "ConfigurationDirectory");
		if (configDirectory ~= nil) then
			loadParams.Directory = configDirectory;
		end
		local bResult = Network.LoadGame(loadParams, GetTestServerType());
		if (bResult == false) then
			Automation.Log("Completing HostGame test due to LoadGame failure.");
			Automation.SendTestComplete();
			return
		end
	end

	ApplyCommonNewGameParametersToConfiguration();

	local gameName = Automation.GetSetParameter("CurrentTest", "GameName");
	if(gameName == nil) then
		-- KWG: If they loaded a configuration, and they didn't specify a name, we might want to not overwriate the game name automatically if a valid one is there.
		gameName = "autoplay";
	end
	GameConfiguration.SetValue("GAME_NAME", gameName);
	
	ReadUserConfigOptions();

	local saveFileName = Automation.GetSetParameter("CurrentTest", "SaveFile");
	if(saveFileName ~= nil) then
		local saveFileTable = {};
		saveFileTable.Name = saveFileName;
		saveFileTable.Type = SaveTypes.NETWORK_MULTIPLAYER;
		saveFileTable.Directory = SaveDirectories.DEFAULT;

		local saveDirectory = Automation.GetSetParameter("CurrentTest", "SaveDirectory");
		if (saveDirectory ~= nil) then
			saveFileTable.Directory = saveDirectory;
		end

		Automation.Log("Loading save file " .. saveFileName);
		Network.LoadGame(saveFileTable, GetTestServerType());
	else
		Automation.Log("Hosting new lan game.");
		Network.HostGame(GetTestServerType());
	end

	Events.MultiplayerGameLastPlayer.Add( HostGame_OnMultiplayerGameLastPlayer );
end

-----------------------------------------------------------------
-- Join a multiplayer autoplay game
--
-- QuitOnHostMigrate - [True] Should we quit the game and end the test if a host migration occurs?
-----------------------------------------------------------------
Tests["JoinGame"] = {};

-- Startup function for "JoinGame"
Tests["JoinGame"].Run = function()

	-- We must be at the Main Menu to do this test.
	if (not UI.IsInFrontEnd()) then
		-- Exit back to the main menu
		Events.ExitToMainMenu();
		return;
	end

	if(GetTestServerType() == ServerType.SERVER_TYPE_CROSSPLAY) then
		-- When using crossplay, we need to login to EOS before we can join our game.
		Events.CrossPlayLoginStateUpdated.Add(JoinGame_OnCrossPlayLoginStateUpdated);
		Network.AttemptConnectionToCrossPlayLobbyService();
		return;
	end
	
	JoinAutoplayGame();
end

-----------------------------------------------------------------
-- Respond to the Post Game Initialization for "JoinGame"
-- The game has been initialized (or loaded), but the app
-- side terrain generation, etc. has yet to be performed
Tests["JoinGame"].PostGameInitialization = function(bWasLoaded)
	
	LogCurrentPlayers();

	-- Add a handler for when the autoplay ends
	LuaEvents.AutoPlayEnd.Add( SharedGame_OnAutoPlayEnd );

	-- Get the optional Turns parameter from the CurrentTest parameter set
	local turnCount = Automation.GetSetParameter("CurrentTest", "RemainingTurns", DEFAULT_AUTOMATION_TURNS);

	local observeAs = GetCurrentTestObserver();
		
	AutoplayManager.SetTurns(turnCount);
	AutoplayManager.SetReturnAsPlayer(0);
	AutoplayManager.SetObserveAsPlayer(observeAs);

	AutoplayManager.SetActive(true);

end

-----------------------------------------------------------------
-- Respond to the Game Start for "JoinGame"
-- The player will be able to see the map at this time.
Tests["JoinGame"].GameStarted = function()
	
	local observeAs = GetCurrentTestObserver();
		
	if (Game.GetLocalPlayer() == PlayerTypes.NONE) then
		-- We are starting as PlayerTypes.NONE and are most likely looking at nothing in particular.
		-- Look at who we are going to play.
		StartupObserverCamera(observeAs);
	end

	Events.TurnEnd.Add(JoinGame_OnTurnEnd);
	Events.MultiplayerHostMigrated.Add(JoinGame_MultiplayerHostMigrated); -- Re-subscribed because the context gets reloaded as part of the game load.
end

-----------------------------------------------------------------
-- Stop handler for "JoinGame"
Tests["JoinGame"].Stop = function()

	-- Clean up anything the test needs to.
	LuaEvents.AutoPlayEnd.RemoveAll();

	Events.MultiplayerGameListComplete.Remove( JoinGame_OnGameListComplete );
	Events.MultiplayerGameListUpdated.Remove( JoinGame_OnGameListUpdated );
	Events.SaveComplete.Remove( SharedGame_OnSaveComplete );
	Events.TurnEnd.Remove(JoinGame_OnTurnEnd);
	Events.MultiplayerHostMigrated.Remove(JoinGame_MultiplayerHostMigrated);

	if(AutoplayManager ~= nil) then -- AutoplayManager will not exist if the script didn't get to gameplay.
		AutoplayManager.SetActive(false);		-- Make sure this is off
	end

	RestoreUserConfigOptions();

end

-----------------------------------------------------------------
-- Received a game list update while waiting to join a multiplayer game for the "JoinGame" test.
function JoinGame_OnGameListUpdated(eAction, idLobby, eLobbyType, eSearchType)
	if(eLobbyType ~= GetTestLobbyType()) then
		-- This is a game list update for another lobbytype.  This is probably a PlayByCloud turn notification check and should be ignored.
		return;
	end

	if (eAction ~= GAMELISTUPDATE_ADD) then
		return;
	end

	local serverTable = Matchmaking.GetGameListEntry(idLobby);		
	if (serverTable ~= nil) then 
		local serverEntry = serverTable[1];
		local gameName = Automation.GetSetParameter("CurrentTest", "GameName");
		if(gameName == nil) then
			gameName = "autoplay";
		end

		if(serverEntry.serverName == gameName) then
			-- Found our test server, join it!
			Automation.Log("JoinGame Found, joining... GameName: " .. gameName .. ", serverID: " .. tostring(serverEntry.serverID));

			-- Stop listening to game list updates.
			Events.MultiplayerGameListComplete.Remove( JoinGame_OnGameListComplete );
			Events.MultiplayerGameListUpdated.Remove( JoinGame_OnGameListUpdated );

			Network.JoinGame(serverEntry.serverID);
		end
	end
end

-----------------------------------------------------------------
-- Received a game list complete during the "JoinGame" test.
function JoinGame_OnGameListComplete(eLobbyType, eSearchType)

	if(eLobbyType ~= GetTestLobbyType()) then
		-- This is a game list update for another lobbytype.  This is probably a PlayByCloud turn notification check and should be ignored.
		return;
	end

	-- If we are still listening to this event, it means we didn't find our test game while searching.  Refresh until we see our game.
	Matchmaking.RefreshGameList();
end

-----------------------------------------------------------------
function JoinGame_OnTurnEnd(iTurn :number)
	-- Decrement cached "RemainingTurns".  We need to remember this in case the client had to reload due to resyncs.
	local remainingTurns = Automation.GetSetParameter("CurrentTest", "RemainingTurns", DEFAULT_AUTOMATION_TURNS);
	if(remainingTurns ~= nil 
		and remainingTurns >= 0) then -- Don't increment the -1 default (no turn limit).
		remainingTurns = remainingTurns - 1;
		Automation.SetSetParameter("CurrentTest", "RemainingTurns", remainingTurns);
	end
end

-----------------------------------------------------------------
function JoinGame_MultiplayerHostMigrated( newHostID )
	local quitParam = Automation.GetSetParameter("CurrentTest", "QuitOnHostMigrate");
	if (quitParam == nil or quitParam == 1) then	
		Automation.Log("Completing JoinGame test due to host migration.");
		-- Signal that the test is complete.  Do not call LuaEvents.AutomationTestComplete() directly.  The Automation system will do that at a safe time.
		Automation.SendTestComplete();
	end
end

-----------------------------------------------------------------
function JoinGame_OnCrossPlayLoginStateUpdated()
	Events.CrossPlayLoginStateUpdated.Remove(JoinGame_OnCrossPlayLoginStateUpdated);

	JoinAutoplayGame();
end

-----------------------------------------------------------------
function JoinAutoplayGame()
	ReadUserConfigOptions();

	-- Cache the remaining turns of automation.  We need to remember this in case the client had to reload due to resyncs.
	local turnCount = Automation.GetSetParameter("CurrentTest", "Turns", DEFAULT_AUTOMATION_TURNS);
	Automation.SetSetParameter("CurrentTest", "RemainingTurns", turnCount);

	Events.MultiplayerGameListUpdated.Add( JoinGame_OnGameListUpdated );
	Events.MultiplayerGameListComplete.Add( JoinGame_OnGameListComplete );
	Events.MultiplayerHostMigrated.Add(JoinGame_MultiplayerHostMigrated);

	-- initialize and refresh lan games list.
	Matchmaking.InitLobby(GetTestLobbyType());
	Matchmaking.RefreshGameList();

	-- Next step is in JoinGame_OnGameListComplete() or JoinGame_OnGameListUpdated()
end


-----------------------------------------------------------------
-- Include the common support code.
-----------------------------------------------------------------
include ("Automation_StandardTestSupport")


-----------------------------------------------------------------
-- Some common functions for these tests
-----------------------------------------------------------------

-----------------------------------------------------------------
-- Log the current players
function LogCurrentPlayers()

	Automation.Log("Players:");
	local aPlayers = PlayerManager.GetAlive();
	for _, pPlayer in ipairs(aPlayers) do
		local pPlayerConfig = PlayerConfigurations[pPlayer:GetID()];
						
		if pPlayerConfig ~= nil then
			local szName = pPlayerConfig:GetCivilizationShortDescription();
			if (szName == nil or string.len(szName) == 0) then
				szName = pPlayerConfig:GetCivilizationTypeName();
			end
			if (szName == nil or string.len(szName) == 0) then
				szName = tostring(pPlayerConfig:GetCivilizationTypeID());
			end

			Automation.Log( tostring(pPlayer:GetID()) .. ": " .. szName);
		end
	end

end

