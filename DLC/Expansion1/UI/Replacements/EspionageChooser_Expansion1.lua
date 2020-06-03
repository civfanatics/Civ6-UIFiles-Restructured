--[[
-- Created by Keaton VanAuken, Oct 13 2017
-- Copyright (c) Firaxis Games
--]]

-- ===========================================================================
-- Base File
-- ===========================================================================
include("EspionageChooser");

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_RefreshDestinationList = RefreshDestinationList;

-- ===========================================================================
-- Refresh the destination list with all revealed non-city state owned cities
-- ===========================================================================
function RefreshDestinationList()
	local localPlayer = Players[Game.GetLocalPlayer()];

	-- Add each players cities to destination list
	local players:table = Game.GetPlayers();
	for i, player in ipairs(players) do
		if (player:GetID() == localPlayer:GetID() or player:GetTeam() == -1 or localPlayer:GetTeam() == -1 or player:GetTeam() ~= localPlayer:GetTeam()) then
			if (not player:IsFreeCities()) then
				AddPlayerCities(player)
			end
		end
	end

	Controls.DestinationPanel:CalculateInternalSize();
end