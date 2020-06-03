-- Copyright 2017-2019, Firaxis Games.

-- Base File
include("DiplomacyRibbon");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_AddLeader = AddLeader;

-- ===========================================================================
function AddLeader(iconName : string, playerID : number, kProps: table)	
	local oLeaderIcon	:object = BASE_AddLeader(iconName, playerID, kProps);
	local localPlayerID	:number = Game.GetLocalPlayer();

	if localPlayerID == PlayerTypes.NONE or localPlayerID == PlayerTypes.OBSERVER then
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
				oLeaderIcon.Controls.Relationship:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_ALLIANCE_FLAG_TT", allianceName, allianceLevel));
			end
		end
	end

	return oLeaderIcon;
end