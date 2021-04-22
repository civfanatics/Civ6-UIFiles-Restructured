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
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = Players[localPlayerID];
	if localPlayer == nil then
		return;
	end

	-- Add each players cities to destination list
	local players:table = Game.GetPlayers();
	for i, player in ipairs(players) do
		local diploStateID:number = player:GetDiplomaticAI():GetDiplomaticStateIndex( localPlayerID );
		if diploStateID ~= -1 then
			local disploState:string = GameInfo.DiplomaticStates[diploStateID].StateType;
			if disploState ~= "DIPLO_STATE_ALLIED" then
				if (player:GetID() == localPlayer:GetID() or player:GetTeam() == -1 or localPlayer:GetTeam() == -1 or player:GetTeam() ~= localPlayer:GetTeam()) then
					if (not player:IsFreeCities()) then
						AddPlayerCities(player)
					end
				end
			end
		end
	end

	Controls.DestinationPanel:CalculateInternalSize();
end