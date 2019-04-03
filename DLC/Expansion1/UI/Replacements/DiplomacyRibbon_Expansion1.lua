-- Copyright 2017-2018, Firaxis Games.

-- Base File
include("DiplomacyRibbon");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_AddLeader = AddLeader;

-- ===========================================================================
function AddLeader(iconName : string, playerID : number, isUniqueLeader: boolean)
	local leaderIcon, instance = BASE_AddLeader(iconName, playerID, isUniqueLeader);

	-- Update relationship pip tool with details about our alliance if we're in one
	local localPlayerDiplomacy:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
	if localPlayerDiplomacy then
		local allianceType = localPlayerDiplomacy:GetAllianceType(playerID);
		if allianceType ~= -1 then
			local allianceName = Locale.Lookup(GameInfo.Alliances[allianceType].Name);
			local allianceLevel = localPlayerDiplomacy:GetAllianceLevel(playerID);
			leaderIcon.Controls.Relationship:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_ALLIANCE_FLAG_TT", allianceName, allianceLevel));
		end
	end
end