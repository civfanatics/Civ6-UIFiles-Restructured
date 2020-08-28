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

local m_kCityStateGovernors:table = {}

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_GetData = GetData;
BASE_AddCityStateRow = AddCityStateRow;
BASE_AddInfluenceRow = AddInfluenceRow;

-- ===========================================================================
-- MODDING: Hook to add more data to the m_kCityStateGovernors table for expansion
function InitGovernorData()
	local governorData:table =
	{
		Ambassadors = {},
		HasAnyAmbassador = false,
	};
	return governorData;
end

-- ===========================================================================
-- MODDING: Hook to add more data to the m_kCityStateGovernors table for expansion
function AddGovernorData(kGovernorData:table, pAssignedGovernor:table, PlayerID:number)
	kGovernorData.Ambassadors[PlayerID] = true;
	kGovernorData.HasAnyAmbassador = true;
end

-- ===========================================================================
function GetData()
	BASE_GetData();

	m_kCityStateGovernors = {};

	-- Check if any civilizations have assigned an ambassador to any city-state
	for i, pCityState in ipairs(PlayerManager.GetAliveMinors()) do
		local governorData:table = InitGovernorData();

		for j, PlayerID in ipairs(PlayerManager.GetAliveMajorIDs()) do

			local pPlayerGovernors:table = Players[PlayerID]:GetGovernors();
			for i,pCityStateCity in pCityState:GetCities():Members() do

				local pAssignedGovernor:table = pPlayerGovernors ~= nil and pPlayerGovernors:GetAssignedGovernor(pCityStateCity) or nil;
				if pAssignedGovernor ~= nil then
					AddGovernorData(governorData, pAssignedGovernor, PlayerID);
				end
			end
		end

		m_kCityStateGovernors[pCityState:GetID()] = governorData;
	end
end

-- ===========================================================================
function GetGovernorIcon(governorInfo:table)
	return "ICON_GOVERNOR_THE_AMBASSADOR_FILL";
end

-- ===========================================================================
function AddCityStateRow( kCityState:table )
	local kInst:table = BASE_AddCityStateRow( kCityState );

	local cityStateID:number = kCityState.iPlayer;
	local ambassadorData:table = m_kCityStateGovernors[cityStateID];
	if ambassadorData.HasAnyAmbassador then
		kInst.AmbassadorButton:RegisterCallback( Mouse.eLClick, function() OpenSingleViewCityState( kCityState.iPlayer ); OnInfluencedByClick(); end );

		local tooltip = Locale.Lookup("LOC_CITY_STATE_PANEL_HAS_AMBASSADOR_TOOLTIP");
		local localPlayerID:number = Game.GetLocalPlayer();
		local pLocalPlayerDiplomacy:table = Players[localPlayerID]:GetDiplomacy();
		for playerID, playerHasAmbassador in pairs(ambassadorData.Ambassadors) do
			local playerConfig:table = PlayerConfigurations[playerID];
			if (playerID == localPlayerID or pLocalPlayerDiplomacy:HasMet(playerID)) then
				tooltip = tooltip .. Locale.Lookup("LOC_CITY_STATE_PANEL_HAS_AMBASSADOR_TOOLTIP_ENTRY", Locale.Lookup(playerConfig:GetCivilizationDescription()), Locale.Lookup(playerConfig:GetPlayerName()));

				local iconName:string = nil;
				if playerHasAmbassador then
					if m_kCityStateGovernors[cityStateID] ~= nil and m_kCityStateGovernors[cityStateID].AssignedGovernors ~= nil and m_kCityStateGovernors[cityStateID].AssignedGovernors[playerID] ~= nil then
						iconName = GetGovernorIcon(m_kCityStateGovernors[cityStateID].AssignedGovernors[playerID].Image);
					end
				end

				-- if we ended up with nil, then call with nil to get the fallback icon
				if iconName == nil then
					iconName = GetGovernorIcon(nil);
				end

				kInst.AmbassadorButton:SetTexture(IconManager:FindIconAtlas(iconName, 32));
			else
				tooltip = tooltip .. Locale.Lookup("LOC_CITY_STATE_PANEL_HAS_AMBASSADOR_TOOLTIP_ENTRY_UNMET", Locale.Lookup("LOC_LOYALTY_PANEL_UNMET_CIV"));
			end
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
	local localPlayerID:number = Game.GetLocalPlayer();
	local playerHasAmbassador:boolean = m_kCityStateGovernors[cityStateID] and m_kCityStateGovernors[cityStateID].Ambassadors[playerID] or false;
	kItem.AmbassadorIcon:SetHide(not playerHasAmbassador);
	if playerHasAmbassador then
		local iconName:string = nil;
		if m_kCityStateGovernors[cityStateID] ~= nil and m_kCityStateGovernors[cityStateID].AssignedGovernors ~= nil and m_kCityStateGovernors[cityStateID].AssignedGovernors[playerID] ~= nil then
			iconName = GetGovernorIcon(m_kCityStateGovernors[cityStateID].AssignedGovernors[playerID].Image);
		else
			iconName = GetGovernorIcon(nil);
		end
		kItem.AmbassadorIcon:SetIcon(iconName);
	end
	local pLocalPlayerDiplomacy:table = Players[localPlayerID]:GetDiplomacy();
	local playerName:string = Locale.Lookup("LOC_LOYALTY_PANEL_UNMET_CIV");
	if (playerID == localPlayerID or pLocalPlayerDiplomacy:HasMet(playerID)) then
		playerName = playerConfig:GetPlayerName();
	end
	kItem.AmbassadorIcon:SetToolTipString(Locale.Lookup("LOC_CITY_STATE_PANEL_CIV_AMBASSADOR_TOOLTIP", playerName));

	return kItem;
end

