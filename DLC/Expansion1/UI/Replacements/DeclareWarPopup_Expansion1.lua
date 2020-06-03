--[[
-- Created by Sam Batista on Aug 03 2017
-- Copyright (c) Firaxis Games
--]]
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("DeclareWarPopup");

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_DeclareWar = DeclareWar;

-- ===========================================================================
--	OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function DeclareWar(eAttackingPlayer:number, eDefendingPlayer:number, eWarType:number)
	if CanDeclareWar(eDefendingPlayer) and eWarType == WarTypes.GOLDEN_AGE_WAR then
		DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_GOLDEN_AGE_WAR");
		return;
	elseif CanDeclareWar(eDefendingPlayer) and eWarType == WarTypes.WAR_OF_RETRIBUTION then
		DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_WAR_OF_RETRIBUTION");
		return;
	elseif CanDeclareWar(eDefendingPlayer) and eWarType == WarTypes.IDEOLOGICAL_WAR then
		DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_IDEOLOGICAL_WAR");
		return;
	end
	return BASE_DeclareWar(eAttackingPlayer, eDefendingPlayer, eWarType);
end