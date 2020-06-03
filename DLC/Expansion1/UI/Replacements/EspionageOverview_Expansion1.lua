--[[
-- Created by Keaton VanAuken on Nov 29 2017
-- Copyright (c) Firaxis Games
--]]
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("EspionageOverview");

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_RefreshCityActivity = RefreshCityActivity;

-- ===========================================================================
--	OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function RefreshCityActivity()
	BASE_RefreshCityActivity();

	-- Add city-states
	local players:table = Game.GetPlayers();
	for i, player in ipairs(players) do
		if player:IsMinor() then
			AddPlayerCities(player);
		end
	end

	Controls.CityActivityScrollPanel:CalculateSize();
end