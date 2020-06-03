-- Copyright (c) 2018-2019 Firaxis Games

-- ===========================================================================
function GetMetPlayersAndUniqueLeaders()
	local kMetPlayers	:table = {};
	local isUniqueLeader:table = {};
	local aPlayers		:table = PlayerManager.GetAliveMajors();
	local pDiplomacy	:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
	for _, pPlayer in ipairs(aPlayers) do
		local playerID:number = pPlayer:GetID();
		if playerID ~= localPlayerID then
			local playerMet:boolean = pDiplomacy:HasMet(playerID);
			if playerMet then
				if (isUniqueLeader[playerID] == nil) then
					isUniqueLeader[playerID] = true;
				else
					isUniqueLeader[playerID] = false;
				end	
			end
			kMetPlayers[playerID] = playerMet;
		end
	end

	return kMetPlayers, isUniqueLeader;
end


-- ===========================================================================
--	Obtain information about a leader based on their visibility to the 
--	local player.
--
--	ARGS:	playerID,	player ID to look up. May be local player but may
--						not be -1 (NONE) or the observer player.
--
--	Returns:	Localized player name (and user name if MP) or "unmet"
--				Icon for leader or default unknown leader icon
--				Icon for Civ or unknown civ icon
-- ===========================================================================
function GetVisiblePlayerNameAndIcons( playerID:number )
	
	if (playerID == nil) or (playerID == PlayerTypes.NONE) or (playerID == PlayerTypes.OBSERVER) then
		UI.DataError("Invalid player # to obtain visible name. #: ",playerID);
		return Locale.Lookup("LOC_PLAYERNAME_UNKNOWN"), "ICON_LEADER_DEFAULT", "ICON_CIVILIZATION_UNKNOWN";
	end

	local localPlayerID	:number = Game.GetLocalPlayer();
	local pPlayerConfig	:object = PlayerConfigurations[playerID];
	local isMultiplayer	:boolean = GameConfiguration.IsAnyMultiplayer();
	local isHuman		:boolean = pPlayerConfig:IsHuman();
	local isMet			:boolean = (playerID == localPlayerID) or (localPlayerID==-1 or localPlayerID==1000);

	-- If not considered "met" then this is not an observer player, nor the
	-- local player and a proper check needs to be done.
	if (isMet==false) then
		local pDiplomacy :table = Players[localPlayerID]:GetDiplomacy();
		isMet = pDiplomacy:HasMet(playerID);
	end

	-- If still considered unmet, return default values:
	if (isMet==false) and ((isMultiplayer and isHuman)==false) then
		return Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER"), "ICON_LEADER_DEFAULT", "ICON_CIVILIZATION_UNKNOWN";
	end

	local civName		:string = pPlayerConfig:GetCivilizationTypeName();
	local leaderTypeName:string = pPlayerConfig:GetLeaderTypeName();
	local leaderName	:string = pPlayerConfig:GetLeaderName();
		
	if (isMultiplayer and isHuman) then		
		-- It's a human.
		if isMet then
			return Locale.Lookup(leaderName) .. " (" .. pPlayerConfig:GetPlayerName() .. ")", "ICON_"..leaderTypeName, "ICON_" .. civName;
		else
			return Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER") .. " (" .. pPlayerConfig:GetPlayerName() .. ")", "ICON_LEADER_DEFAULT", "ICON_CIVILIZATION_UNKNOWN";
		end
	end

	-- It's the AI/computer.
	if isMet then
		return Locale.Lookup(leaderName), "ICON_"..leaderTypeName, "ICON_" .. civName;			
	end

	return Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER"), "ICON_LEADER_DEFAULT", "ICON_CIVILIZATION_UNKNOWN";
end


-- ===========================================================================
--	Obtain the name of the player based on the visibility with the local player.
-- ===========================================================================
function GetVisiblePlayerName( playerID:number )
	local name:string = GetVisiblePlayerNameAndIcons( playerID );
	return 	name;
end