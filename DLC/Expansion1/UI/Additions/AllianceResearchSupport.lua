-- ===========================================================================
-- This file contains functions to help determine if a player gets a 
-- research boost from being in a research alliance.
--
-- It's used in:
--
--  TechTree_Expansion1
--  WorldTracker_Expansion1
--  ResearchChooser_Expansion1
-- ===========================================================================

local m_AllyPlayerTechs = nil;
local m_AllyPlayerCurrentTech = -1;
local m_HasAllianceResearchBonus = false;

local MAX_ALLIANCE_LEVEL = 3;
local COLOR_ACTIVE = { r = 1, g = 1, b = 1, a = 1 };
local COLOR_INACTIVE = { r = 0.6, g = 0.6, b = 0.6, a = 1 };
local ALLIANCE_ICON_TT = Locale.Lookup("LOC_TECH_TREE_ALLIANCE_TT");
local ALLIANCE_ICON_BONUS_TT = Locale.Lookup("LOC_TECH_TREE_ALLIANCE_BONUS_TT");

function CalculateAllianceResearchBonus()
	m_AllyPlayerTechs = nil;
	m_AllyPlayerCurrentTech = -1;
	m_HasAllianceResearchBonus = false;

	local majorPlayers = PlayerManager.GetAliveMajors();
	for _, player in ipairs(majorPlayers) do
		if HasMaxLevelResearchAlliance(player:GetID()) then
			local localPlayer = Players[Game.GetLocalPlayer()];
			local localPlayerTechs = localPlayer:GetTechs();
			local localCurrentTech = localPlayerTechs:GetResearchingTech();

			m_AllyPlayerTechs = player:GetTechs();
			m_AllyPlayerCurrentTech = m_AllyPlayerTechs:GetResearchingTech();

			m_HasAllianceResearchBonus = localCurrentTech == m_AllyPlayerCurrentTech or
				localPlayerTechs:HasTech(m_AllyPlayerCurrentTech) or
				m_AllyPlayerTechs:HasTech(localCurrentTech);

			break;
		end
	end
end

function HasMaxLevelResearchAlliance(playerID)
	local localPlayerID = Game.GetLocalPlayer();
	
	if playerID ~= localPlayerID then
		local localPlayer = Players[localPlayerID];
		local localPlayerDiplomacy = localPlayer:GetDiplomacy();
		local allianceLevel = localPlayerDiplomacy:GetAllianceLevel(playerID);

		if allianceLevel == MAX_ALLIANCE_LEVEL then
			local allianceType = localPlayerDiplomacy:GetAllianceType(playerID);

			-- If the player we're allied with changes their current research we need to refresh our tech list
			if allianceType ~= -1 and GameInfo.Alliances[allianceType].AllianceType == "ALLIANCE_RESEARCH" then
				return true;
			end
		end
	end
	return false;
end

function AllyHasOrIsResearchingTech(techID)
	if m_AllyPlayerTechs then
		return techID == m_AllyPlayerCurrentTech or m_AllyPlayerTechs:HasTech(techID);
	end
	return false;
end

function GetAllianceIconColor()
	return m_HasAllianceResearchBonus and COLOR_ACTIVE or COLOR_INACTIVE;
end

function GetAllianceIconToolTip()
	return m_HasAllianceResearchBonus and ALLIANCE_ICON_BONUS_TT or ALLIANCE_ICON_TT;
end
