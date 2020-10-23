--	Copyright 2017-2020 (c) Firaxis Games

-- This file is being included into the base GreatPeoplePopup file using the wildcard include setup in GreatPeoplePopup.lua
-- Refer to the bottom of GreatPeoplePopup.lua to see how that's happening
-- DO NOT include any GreatPeoplePopup files here or it will cause problems
-- include("GreatPeoplePopup");

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
local BASE_GetPatronizeWithGoldTT = GetPatronizeWithGoldTT;
local BASE_GetPatronizeWithFaithTT = GetPatronizeWithFaithTT;

-- ===========================================================================
--	OVERRIDE 
-- ===========================================================================
function GetPatronizeWithGoldTT(kPerson)
	local localPlayer = Players[Game.GetLocalPlayer()];
	if (localPlayer:GetGreatPeoplePoints():IsNoPatronageWith(GameInfo.Yields["YIELD_GOLD"].Index)) then
		return Locale.Lookup("LOC_GREAT_PEOPLE_PATRONAGE_GOLD_OFF");
	end
	return BASE_GetPatronizeWithGoldTT(kPerson);
end

-- ===========================================================================
--	OVERRIDE 
-- ===========================================================================
function GetPatronizeWithFaithTT(kPerson)
	local localPlayer = Players[Game.GetLocalPlayer()];
	if (localPlayer:GetGreatPeoplePoints():IsNoPatronageWith(GameInfo.Yields["YIELD_FAITH"].Index)) then
		return Locale.Lookup("LOC_GREAT_PEOPLE_PATRONAGE_FAITH_OFF");
	end
	return BASE_GetPatronizeWithFaithTT(kPerson);
end