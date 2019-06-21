-- Copyright 2017-2018, Firaxis Games.

-- Base File
include("DiplomacyRibbon");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_AddLeader = AddLeader;

-- ===========================================================================
function AddLeader(iconName : string, playerID : number, kProps: table)	
	local leaderIcon, instance = BASE_AddLeader(iconName, playerID, kProps);
	local localPlayerID:number = Game.GetLocalPlayer();

	if localPlayerID == -1 or localPlayerID == 1000 then
		return;
	end

	if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_HUD_RIBBON_RELATIONSHIPS") then
		-- Update relationship pip tool with details about our alliance if we're in one
		local localPlayerDiplomacy:table = Players[localPlayerID]:GetDiplomacy();
		if localPlayerDiplomacy then
			local allianceType = localPlayerDiplomacy:GetAllianceType(playerID);
			if allianceType ~= -1 then
				local allianceName = Locale.Lookup(GameInfo.Alliances[allianceType].Name);
				local allianceLevel = localPlayerDiplomacy:GetAllianceLevel(playerID);
				leaderIcon.Controls.Relationship:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_ALLIANCE_FLAG_TT", allianceName, allianceLevel));
			end
		end
	end
end