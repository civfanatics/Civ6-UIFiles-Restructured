--[[
-- Created by Keaton VanAuken on Aug 15 2017
-- Copyright (c) Firaxis Games
--]]

local DiplomaticStateIndexToVisState = {};

DiplomaticStateIndexToVisState[DiplomaticStates.ALLIED] = 0;
DiplomaticStateIndexToVisState[DiplomaticStates.DECLARED_FRIEND] = 1;
DiplomaticStateIndexToVisState[DiplomaticStates.FRIENDLY] = 2;
DiplomaticStateIndexToVisState[DiplomaticStates.NEUTRAL] = 3;
DiplomaticStateIndexToVisState[DiplomaticStates.UNFRIENDLY] = 4;
DiplomaticStateIndexToVisState[DiplomaticStates.DENOUNCED] = 5;
DiplomaticStateIndexToVisState[DiplomaticStates.WAR] = 6;

-- ===========================================================================
-- Take the diplomatic state index and convert it to a vis state index for our icons
-- Yes, *currently* the index state is the same, but it is NOT good practice
-- to assume starting position or order of a database item, ever.
function GetVisStateFromDiplomaticState(iState)

	local eStateHash = GameInfo.DiplomaticStates[iState].Hash;
	local iVisState = DiplomaticStateIndexToVisState[eStateHash];

	if (iVisState ~= nil) then
		return iVisState;
	end

	return 0;
end

-- ===========================================================================
function Refresh(selectedPlayerID:number)
	local localPlayerID:number = Game.GetLocalPlayer();
	local localPlayer:table = Players[localPlayerID];
	local localPlayerDiplomacy:table = localPlayer:GetDiplomacy();

	local selectedPlayer:table = Players[selectedPlayerID];

	-- Relationship Status
	-- Get the selected player's Diplomactic AI
	local selectedPlayerDiplomaticAI = selectedPlayer:GetDiplomaticAI();
	-- What do they think of us?
	local iState :number = selectedPlayerDiplomaticAI:GetDiplomaticStateIndex(localPlayerID);
	local relationshipString:string = Locale.Lookup(GameInfo.DiplomaticStates[iState].Name);
	-- Add team name to relationship text for our own teams
	if localPlayer:GetTeam() == selectedPlayer:GetTeam() then
		relationshipString = "(" .. Locale.Lookup("LOC_WORLD_RANKINGS_TEAM", localPlayer:GetTeam()) .. ") " .. relationshipString;
	end

    if(localPlayerDiplomacy:IsPromiseMade(selectedPlayer:GetID(), PromiseTypes.DONT_SETTLE_NEAR_ME)) then
        relationshipString = relationshipString .. "[NEWLINE]" .. Locale.Lookup("LOC_DIPLOACTION_KEEP_PROMISE_DONT_SETTLE_TOO_NEAR_NAME");
    end
    if(localPlayerDiplomacy:IsPromiseMade(selectedPlayer:GetID(), PromiseTypes.DONT_SPY_ON_ME)) then
        relationshipString = relationshipString .. ",[NEWLINE]" .. Locale.Lookup("LOC_DIPLOACTION_KEEP_PROMISE_DONT_SPY_NAME") .. " ";
    end
    if(localPlayerDiplomacy:IsPromiseMade(selectedPlayer:GetID(), PromiseTypes.DONT_DIG_UP_MY_ARTIFACTS)) then
        relationshipString = relationshipString .. ",[NEWLINE]" .. Locale.Lookup("LOC_DIPLOACTION_KEEP_PROMISE_DONT_DIG_ARTIFACTS_NAME") .. " ";
    end
    if(localPlayerDiplomacy:IsPromiseMade(selectedPlayer:GetID(), PromiseTypes.DONT_CONVERT_MY_CITIES)) then
        relationshipString = relationshipString .. ",[NEWLINE]" .. Locale.Lookup("LOC_DIPLOACTION_KEEP_PROMISE_DONT_CONVERT_NAME") .. " ";
    end

	Controls.RelationshipText:SetText( relationshipString );

	local localPlayerDiplomacy = localPlayer:GetDiplomacy();

	if (GameInfo.DiplomaticStates[iState].StateType == "DIPLO_STATE_DENOUNCED") then
		local szDenounceTooltip;
		local iRemainingTurns;
		local iOurDenounceTurn = localPlayerDiplomacy:GetDenounceTurn(selectedPlayerID);
		local iTheirDenounceTurn = selectedPlayer:GetDiplomacy():GetDenounceTurn(localPlayerID);
		local iPlayerOrderAdjustment = 0;
		if (iTheirDenounceTurn >= iOurDenounceTurn) then
			if (selectedPlayerID > localPlayerID) then
				iPlayerOrderAdjustment = 1;
			end
		else
			if (localPlayerID > selectedPlayerID) then
				iPlayerOrderAdjustment = 1;
			end
		end
		print ("Adjustment: " .. tostring(iPlayerOrderAdjustment));
		if (iOurDenounceTurn >= iTheirDenounceTurn) then  
			iRemainingTurns = 1 + iOurDenounceTurn + Game.GetGameDiplomacy():GetDenounceTimeLimit() - Game.GetCurrentGameTurn() + iPlayerOrderAdjustment;
			szDenounceTooltip = Locale.Lookup("LOC_DIPLOMACY_DENOUNCED_TOOLTIP", PlayerConfigurations[localPlayerID]:GetCivilizationShortDescription(), PlayerConfigurations[selectedPlayerID]:GetCivilizationShortDescription());
		else
			iRemainingTurns = 1 + iTheirDenounceTurn + Game.GetGameDiplomacy():GetDenounceTimeLimit() - Game.GetCurrentGameTurn() + iPlayerOrderAdjustment;
			szDenounceTooltip = Locale.Lookup("LOC_DIPLOMACY_DENOUNCED_TOOLTIP", PlayerConfigurations[selectedPlayerID]:GetCivilizationShortDescription(), PlayerConfigurations[localPlayerID]:GetCivilizationShortDescription());
		end
		szDenounceTooltip = szDenounceTooltip .. " [" .. Locale.Lookup("LOC_ESPIONAGEPOPUP_TURNS_REMAINING", iRemainingTurns) .. "]";
		Controls.RelationshipText:SetToolTipString(szDenounceTooltip);
	elseif (GameInfo.DiplomaticStates[iState].StateType == "DIPLO_STATE_DECLARED_FRIEND") then
		local szFriendTooltip;
		local iFriendshipTurn = localPlayerDiplomacy:GetDeclaredFriendshipTurn(selectedPlayerID);
		local iRemainingTurns = iFriendshipTurn + Game.GetGameDiplomacy():GetDenounceTimeLimit() - Game.GetCurrentGameTurn();
		szFriendTooltip = Locale.Lookup("LOC_DIPLOMACY_DECLARED_FRIENDSHIP_TOOLTIP", PlayerConfigurations[localPlayerID]:GetCivilizationShortDescription(), PlayerConfigurations[selectedPlayerID]:GetCivilizationShortDescription(), iRemainingTurns);
		Controls.RelationshipText:SetToolTipString(szFriendTooltip);
	else
		Controls.RelationshipText:SetToolTipString(nil);
	end
	Controls.RelationshipIcon:SetVisState(GetVisStateFromDiplomaticState(iState));

	-- Show alliance information if we have an alliance
	local allianceType = localPlayerDiplomacy:GetAllianceType(selectedPlayerID);
	if allianceType ~= -1 then
        Controls.RelationshipText:SetToolTipString(Locale.Lookup("LOC_DIPLOACTION_EXPIRES_IN_X_TURNS", localPlayerDiplomacy:GetAllianceTurnsUntilExpiration(selectedPlayerID)));

		-- Alliance Type
		local iAllianceType = GameInfo.Alliances[allianceType];
		Controls.AllianceTypeText:SetText(Locale.Lookup(iAllianceType.Name));

		-- Alliance Level
		local allianceLevel:number = localPlayerDiplomacy:GetAllianceLevel(selectedPlayerID);
		Controls.AllianceLevelText:SetText(Locale.Lookup("LOC_DIPLOACTION_ALLIANCE_LEVEL", allianceLevel));

		Controls.AllianceTypeContainer:SetHide(false);
		Controls.AllianceLevelContainer:SetHide(false);
	else
		Controls.AllianceTypeContainer:SetHide(true);
		Controls.AllianceLevelContainer:SetHide(true);
	end

	Controls.AllianceStack:CalculateSize();
end

-- ===========================================================================
function Initialize()
	-- Set this context to autosize
	ContextPtr:SetAutoSize(true);

	LuaEvents.DiploScene_RefreshOverviewRows.Add(Refresh);
end
Initialize();