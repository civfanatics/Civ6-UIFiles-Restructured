--[[
-- Created by Keaton VanAuken on Aug 15 2017
-- Copyright (c) Firaxis Games
--]]

include("InstanceManager");

local MAX_ALLIANCE_LEVEL:number = 3;

local ms_AllianceDetailsIM:table = InstanceManager:new( "AllianceDetailsInstance", "TopStack" );
local ms_AllianceBonusDescIM:table = InstanceManager:new( "AllianceBonusDescInstance", "Top" );

-- ===========================================================================
function Refresh(selectedPlayerID:number)
	local localPlayerID:number = Game.GetLocalPlayer();
	local localPlayer:table = Players[localPlayerID];
	local localPlayerDiplomacy:table = localPlayer:GetDiplomacy();

	local selectedPlayer:table = Players[selectedPlayerID];

	local allianceLevel:number = localPlayerDiplomacy:GetAllianceLevel(selectedPlayerID);
	
	-- Update alliance progress details
	local turnsThisLevel = localPlayerDiplomacy:GetAllianceTurnsThisLevel(selectedPlayerID);
	local turnsToNextLevel = localPlayerDiplomacy:GetAllianceTurnsToNextLevel(selectedPlayerID);
	Controls.AllianceLevelText:SetText(allianceLevel);
	if turnsThisLevel < turnsToNextLevel then
		Controls.AllianceLevelBar:SetPercent(turnsThisLevel / turnsToNextLevel);
	else
		Controls.AllianceLevelBar:SetPercent(1.0);
	end
	Controls.CurrentPoints:SetText(turnsThisLevel / GlobalParameters.ALLIANCE_POINTS_MULTIPLIER)
	Controls.PointsNeeded:SetText(Locale.Lookup("LOC_DIPLOMACY_ALLIANCE_POINTS_NEEDED", turnsToNextLevel / GlobalParameters.ALLIANCE_POINTS_MULTIPLIER));

	ms_AllianceDetailsIM:ResetInstances();
	ms_AllianceBonusDescIM:ResetInstances();

	local allianceType = localPlayerDiplomacy:GetAllianceType(selectedPlayerID);
	if allianceType ~= -1 and allianceLevel < MAX_ALLIANCE_LEVEL then
		-- Add current alliance details
		AddAllianceDetails(GameInfo.Alliances[allianceType], allianceLevel, Controls.CurrentAllianceDetailsAnchor);

		-- Turns will alliance expiration
		Controls.AllianceExpiresLabel:SetText(Locale.Lookup("LOC_DIPLOACTION_EXPIRES_IN_X_TURNS", localPlayerDiplomacy:GetAllianceTurnsUntilExpiration(selectedPlayerID)));
	
		-- If we currently have an alliance show the possible benefits for the next level of all alliances
		Controls.PossibleAllianceHeader:SetText(Locale.ToUpper("LOC_DIPLOACTION_BENEFITS_NEXT_LEVEL"));
		AddPossibleAllianceDetails(allianceLevel + 1);

		local pointsPerTurn = localPlayerDiplomacy:GetAlliancePointsPerTurn(selectedPlayerID);
		Controls.PointsPerTurn:SetText(Locale.Lookup("LOC_DIPLOMACY_ALLIANCE_POINTS_PER_TURN", pointsPerTurn / GlobalParameters.ALLIANCE_POINTS_MULTIPLIER));
	elseif allianceType ~= -1 and allianceLevel >= MAX_ALLIANCE_LEVEL then
		-- Add current alliance details
		AddAllianceDetails(GameInfo.Alliances[allianceType], allianceLevel, Controls.CurrentAllianceDetailsAnchor);

		-- Turns will alliance expiration
		Controls.AllianceExpiresLabel:SetText(Locale.Lookup("LOC_DIPLOACTION_EXPIRES_IN_X_TURNS", localPlayerDiplomacy:GetAllianceTurnsUntilExpiration(selectedPlayerID)));
	
		-- If we currently have an alliance show the possible benefits for the next level of all alliances
		Controls.PossibleAllianceHeader:SetText(Locale.ToUpper("LOC_DIPLOACTION_BENEFITS_NEXT_LEVEL"));
		AddPossibleAllianceDetails(allianceLevel);

		-- If we're at max alliance level simply display "MAX" instead of showing alliance points
		Controls.CurrentPoints:SetText(Locale.Lookup("LOC_DIPLOMACY_MAX_ALLIANCE_POINTS"));
		Controls.PointsPerTurn:SetText("");
		Controls.PointsNeeded:SetText("");
	else
		-- Use the expire label to tell player they don't have an alliance with this player
		Controls.AllianceExpiresLabel:SetText(Locale.Lookup("LOC_DIPLOACTION_NO_CURRENT_ALLIANCE"));
		
		-- If we don't have an alliance then show possible benefits of alliances at the current level
		Controls.PossibleAllianceHeader:SetText(Locale.ToUpper("LOC_DIPLOACTION_BENEFITS_CURRENT_LEVEL"));
		AddPossibleAllianceDetails(allianceLevel);

		Controls.PointsPerTurn:SetText("");
	end

	-- Inform the player they need to be in an alliance to gain alliance points
	local cityDetailsTooltip:string = localPlayerDiplomacy:GetAlliancePointsTooltip(selectedPlayerID);
	if allianceType == -1 then
		Controls.AlliancePointsContainer:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_NEED_ALLIANCE_TO_GAIN_POINTS_TT", cityDetailsTooltip));
	else
		Controls.AlliancePointsContainer:SetToolTipString(cityDetailsTooltip);
	end
end

-- ===========================================================================
function AddPossibleAllianceDetails(levelToShow:number)
	for alliance in GameInfo.Alliances() do
		-- Ignore ALLIANCE_TEAMUP since it has no modifiers
		if alliance.AllianceType ~= "ALLIANCE_TEAMUP" then
			AddAllianceDetails(alliance, levelToShow, Controls.PossibleAllianceStack);
		end
	end
end

-- ===========================================================================
function AddAllianceDetails(allianceDefinition, allianceLevel, parentControl)
	local allianceDetailsInst:table = ms_AllianceDetailsIM:GetInstance(parentControl);

	allianceDetailsInst.AllianceType:SetText(Locale.Lookup(allianceDefinition.Name));
	allianceDetailsInst.AllianceLevel:SetText(Locale.Lookup("LOC_DIPLOACTION_ALLIANCE_LEVEL", allianceLevel));

	local modifierData:table = GetAllianceModifiersFromDB(allianceDefinition.AllianceType, allianceLevel);
	for i, modifier in ipairs(modifierData) do
		local bonusDescInst:table = ms_AllianceBonusDescIM:GetInstance(allianceDetailsInst.AllianceBonusDescStack);
		bonusDescInst.BonusDescription:SetText(Locale.Lookup(modifier));
	end
end

-- ===========================================================================
function GetAllianceModifiersFromDB(allianceType, allianceLevel)
	local modifiers:table = {};

	local q = DB.Query("SELECT ModifierID, LevelRequirement from AllianceEffects WHERE AllianceType = ?", allianceType);
	for i, modifier in ipairs(q) do
		-- Add modifiers with level requirements less than or equal to the alliance level
		if modifier.LevelRequirement <= allianceLevel then
			local modifierText = DB.Query("SELECT Text from ModifierStrings where ModifierID = ? and Context = 'Summary'", modifier.ModifierID);
			if modifierText and modifierText[1] then
				table.insert(modifiers, modifierText[1].Text);
			end
		end
	end

	return modifiers;
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetAutoSize(true);

	LuaEvents.DiploScene_RefreshTabs.Add(Refresh);
end
Initialize();