-- Copyright 2018, Firaxis Games.

-- ===========================================================================
-- INCLUDES
-- ===========================================================================
include("DiplomacyRibbon_Expansion1.lua");
include("GameCapabilities");
include("CongressButton");


-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================
BASE_LateInitialize = LateInitialize;
BASE_UpdateLeaders = UpdateLeaders;
BASE_RealizeSize = RealizeSize;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kCongressButtonIM		:table = nil;
local m_uiCongressButtonInstance:table = nil;
local m_congressButtonWidth		:number = 0;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function UpdateLeaders()
	-- Create and add World Congress button if one was allocated (based on capabilities)
	if m_kCongressButtonIM then
		if Game.GetEras():GetCurrentEra() >= GlobalParameters.WORLD_CONGRESS_INITIAL_ERA then		
			m_kCongressButtonIM:ResetInstances();
			local congressProgButtonClass:table = {};
			kCongressButton, m_uiCongressButtonInstance = CongressButton:GetInstance( m_kCongressButtonIM );
			m_congressButtonWidth = m_uiCongressButtonInstance.Top:GetSizeX();		
		end
	end

	BASE_UpdateLeaders();	
end


-- ===========================================================================
function RealizeSize( additionalElementsWidth:number )			
	BASE_RealizeSize( m_congressButtonWidth );
	--The Congress button takes up one leader slot, so the max num of leaders used to calculate scroll is reduced by one in XP2	
	g_maxNumLeaders = g_maxNumLeaders - 1;
end

-- ===========================================================================
function OnLeaderClicked(playerID : number )
	-- Send an event to open the leader in the diplomacy view (only if they met)
	local pWorldCongress:table = Game.GetWorldCongress();
	local localPlayerID:number = Game.GetLocalPlayer();
	if playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID) then
		if pWorldCongress:IsInSession() then
			LuaEvents.DiplomacyActionView_OpenLite(playerID);
		else
			LuaEvents.DiplomacyRibbon_OpenDiplomacyActionView(playerID);
		end
	end
end

-- ===========================================================================
function LateInitialize()

	BASE_LateInitialize();

	Events.DiplomacyRelationshipChanged.Add( UpdateLeaders ); 
	Events.MultiplayerPlayerConnected.Add(UpdateLeaders);
	Events.MultiplayerPostPlayerDisconnected.Add(UpdateLeaders);
	Events.LocalPlayerChanged.Add(UpdateLeaders);
	Events.PlayerInfoChanged.Add(UpdateLeaders);
	Events.PlayerDefeat.Add(UpdateLeaders);
	Events.PlayerRestored.Add(UpdateLeaders);
	Events.LocalPlayerTurnBegin.Add(UpdateLeaders);

	if HasCapability("CAPABILITY_WORLD_CONGRESS") then
		m_kCongressButtonIM = InstanceManager:new("CongressButton", "Top", Controls.LeaderStack);
	end

	if not XP2_LateInitialize then	-- Only update leaders if this is the last in the call chain.
		UpdateLeaders();
	end
end
