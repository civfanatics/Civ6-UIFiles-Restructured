-- Copyright (c) 2018 Firaxis Games

function GetMetPlayersAndUniqueLeaders()
	local metPlayers:table = {};
	local isUniqueLeader:table = {};
	local aPlayers:table = PlayerManager.GetAliveMajors();
	local pDiplomacy:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
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
			metPlayers[playerID] = playerMet;
		end
	end

	return metPlayers, isUniqueLeader;
end

-- metPlayers parameter is optional, cache the return value from GetMetPlayersAndUniqueLeaders and pass it in as a parameter within loops
function GetPlayerName(playerID:number, metPlayers:table)
	if not metPlayers then metPlayers = GetMetPlayersAndUniqueLeaders(); end

	local localPlayerID:number = Game.GetLocalPlayer();
	local playerMet:boolean = playerID == localPlayerID or metPlayers[playerID];
	local pPlayerConfig:table = PlayerConfigurations[playerID];
	local isHuman:boolean = pPlayerConfig:IsHuman();

	if playerMet or (GameConfiguration.IsAnyMultiplayer() and isHuman) then
		local civName:string = pPlayerConfig:GetCivilizationTypeName();
		local leaderName:string = pPlayerConfig:GetLeaderTypeName();
		local leaderDesc:string = pPlayerConfig:GetLeaderName();
		
		if GameConfiguration.IsAnyMultiplayer() and isHuman then
			if(playerID ~= localPlayerID and not playerMet) then
				return Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER") .. " (" .. pPlayerConfig:GetPlayerName() .. ")", "ICON_LEADER_DEFAULT", "ICON_CIVILIZATION_UNKNOWN";
			else
				return Locale.Lookup(leaderDesc) .. " (" .. pPlayerConfig:GetPlayerName() .. ")", "ICON_"..leaderName, "ICON_" .. civName;
			end
		else
			if(playerID ~= localPlayerID and not playerMet) then
				return "LOC_DIPLOPANEL_UNMET_PLAYER", "ICON_LEADER_DEFAULT", "ICON_CIVILIZATION_UNKNOWN";
			else
				return leaderDesc, "ICON_"..leaderName, "ICON_" .. civName;
			end
		end
	else
		return "LOC_DIPLOPANEL_UNMET_PLAYER", "ICON_LEADER_DEFAULT", "ICON_CIVILIZATION_UNKNOWN";
	end
end