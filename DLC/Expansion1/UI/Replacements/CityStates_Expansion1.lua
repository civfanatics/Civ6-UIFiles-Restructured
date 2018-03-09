--[[
-- Created by Keaton VanAuken, Nov 13 2017
-- Copyright (c) Firaxis Games
--]]

-- ===========================================================================
-- Base File
-- ===========================================================================
include("CityStates");

-- ===========================================================================
-- Variables
-- ===========================================================================

local m_CityStateGovernors:table = {}

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_GetData = GetData;
BASE_AddCityStateRow = AddCityStateRow;
BASE_AddInfluenceRow = AddInfluenceRow;

-- ===========================================================================
function GetData()
	BASE_GetData();

	m_CityStateGovernors = {};

	-- Check if any civilizations have assigned an ambassador to any city-state
	for i, pCityState in ipairs(PlayerManager.GetAliveMinors()) do
		local governorData:table = {
			Ambassadors = {},
			HasAnyAmbassador = false,
		};

		for j, PlayerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
			
			local pPlayerGovernors:table = Players[PlayerID]:GetGovernors();
			for i,pCityStateCity in pCityState:GetCities():Members() do
				
				local pAssignedGovernor:table = pPlayerGovernors ~= nil and pPlayerGovernors:GetAssignedGovernor(pCityStateCity) or nil;
				if pAssignedGovernor ~= nil then
					governorData.Ambassadors[PlayerID] = true;
					governorData.HasAnyAmbassador = true;
				end
			end
		end

		m_CityStateGovernors[pCityState:GetID()] = governorData;
	end
end

-- ===========================================================================
function AddCityStateRow( kCityState:table )
	local kInst:table = BASE_AddCityStateRow( kCityState );
	
	local ambassadorData:table = m_CityStateGovernors[kCityState.iPlayer];
	if ambassadorData.HasAnyAmbassador then
		kInst.AmbassadorButton:RegisterCallback( Mouse.eLClick, function() OpenSingleViewCityState( kCityState.iPlayer ); OnInfluencedByClick(); end );
		
		local tooltip = Locale.Lookup("LOC_CITY_STATE_PANEL_HAS_AMBASSADOR_TOOLTIP");
		for playerID, playerHasAmbassador in pairs(ambassadorData.Ambassadors) do
			local playerConfig = PlayerConfigurations[playerID];
			tooltip = tooltip .. Locale.Lookup("LOC_CITY_STATE_PANEL_HAS_AMBASSADOR_TOOLTIP_ENTRY", Locale.Lookup(playerConfig:GetCivilizationDescription()), Locale.Lookup(playerConfig:GetPlayerName()));
		end
		kInst.AmbassadorButton:SetToolTipString(tooltip);
		
		kInst.AmbassadorButton:SetHide(false);
	else
		kInst.AmbassadorButton:SetHide(true);
	end

	return kInst;
end

-- ===========================================================================
function AddInfluenceRow(cityStateID:number, playerID:number, influence:number, largestInfluence:number)
	local kItem:table = BASE_AddInfluenceRow(cityStateID, playerID, influence, largestInfluence);

	local playerConfig:table = PlayerConfigurations[playerID];
	local playerHasAmbassador:boolean = m_CityStateGovernors[cityStateID] and m_CityStateGovernors[cityStateID].Ambassadors[playerID] or false;
	kItem.AmbassadorIcon:SetHide(not playerHasAmbassador);
	kItem.AmbassadorIcon:SetToolTipString(Locale.Lookup("LOC_CITY_STATE_PANEL_CIV_AMBASSADOR_TOOLTIP", playerConfig:GetPlayerName()));

	return kItem;
end