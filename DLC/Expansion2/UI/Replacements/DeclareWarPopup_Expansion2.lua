--[[
-- Created by Sam Batista on Aug 03 2017
-- Copyright (c) Firaxis Games
--]]
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("DeclareWarPopup_Expansion1");

BASE_OnShow = OnShow;

-- ===========================================================================
--	OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function OnShow(eAttackingPlayer:number, kDefendingPlayers:table, eWarType:number, confirmCallbackFn)
	BASE_OnShow(eAttackingPlayer, kDefendingPlayers, eWarType, confirmCallbackFn);
	
	local pAttacker = Players[eAttackingPlayer];
	local iWarmongerPoints = 0;	
	local bFoundMajorPowerDefender = false;
	local eDefendingMinor = -1;
	for i, eDefendingPlayer in ipairs(kDefendingPlayers) do
		local kParams = {};
		kParams.WarState = eWarType;
		bSuccess, tResults = DiplomacyManager.TestAction(eFromPlayer, eDefendingPlayer, DiplomacyActionTypes.SET_WAR_STATE, kParams);

		local tmp = pAttacker:GetDiplomacy():ComputeDOWWarmongerPoints(eDefendingPlayer, kParams.WarState);
		iWarmongerPoints = math.max(tmp, iWarmongerPoints); -- Pick the worst penalty and go with it

		if (Players[eDefendingPlayer]:IsMajor()) then
		    bFoundMajorPowerDefender = true;
		else
		    eDefendingMinor = eDefendingPlayer;
		end
	end
	
	local szString = "LOC_DIPLO_CHOICE_GENERATES_GRIEVANCES_INFO";
	if (bFoundMajorPowerDefender == false) then
		local pMinorPlayerInfluence:table = Players[eDefendingMinor]:GetInfluence();		
		if (pMinorPlayerInfluence:GetSuzerain() ~= eAttackingPlayer and pMinorPlayerInfluence:GetSuzerain() ~= -1) then
		   szString = "LOC_DIPLO_CHOICE_GENERATES_GRIEVANCES_INFO_SUZERAIN";
		   iWarmongerPoints = GlobalParameters.GRIEVANCES_SUZERAIN_CITY_STATE_DOW;
		else
			iWarmongerPoints = 0;

			-- Some other power beside the declarer have envoys here?
			local majorPlayers = PlayerManager.GetAliveMajors();
			for _, player in ipairs(majorPlayers) do
				if (player:GetID() ~= eAttackingPlayer and pMinorPlayerInfluence:GetTokensReceived(player:GetID()) > 0) then
					szString = "LOC_DIPLO_CHOICE_GENERATES_GRIEVANCES_INFO_ENVOYS_PRESENT";
					iWarmongerPoints = GlobalParameters.GRIEVANCES_HAVE_ENVOYS_CITY_STATE_DOW;
					break;
				end
			end
		end
	end

	g_ConsequenceItemIM:ResetInstances();
	local consequenceItem = g_ConsequenceItemIM:GetInstance(Controls.WarmongerStack);
	consequenceItem.Text:SetText(Locale.Lookup(szString, iWarmongerPoints));
end