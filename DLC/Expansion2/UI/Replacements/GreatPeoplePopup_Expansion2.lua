--	Copyright 2019-2020 (c) Firaxis Games

-- This file is being included into the base GreatPeoplePopup file using the wildcard include setup in GreatPeoplePopup.lua
-- Refer to the bottom of GreatPeoplePopup.lua to see how that's happening
-- DO NOT include any GreatPeoplePopup files here or it will cause problems
-- include("GreatPeoplePopup_Expansion1");

-- ===========================================================================
-- OVERRIDE
-- ===========================================================================
function IsReadOnly()
	local pWorldCongress:table = Game.GetWorldCongress();
	return pWorldCongress:IsInSession();
end