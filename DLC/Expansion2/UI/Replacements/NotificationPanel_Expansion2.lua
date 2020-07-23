-- Copyright 2018-2020, Firaxis Games

-- This file is being included into the base NotificationPanel file using the wildcard include setup in NotificationPanel.lua
-- Refer to the bottom of NotificationPanel.lua to see how that's happening
-- DO NOT include any NotificationPanel files here or it will cause problems
--include("NotificationPanel_Expansion1");

-- ===========================================================================
-- LOCALS
-- ===========================================================================
local m_pSpecialSessionNotification = nil;

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
local BASE_RegisterHandlers = RegisterHandlers;

-- ===========================================================================
function OnSpecialSessionWorldCongress( notificationEntry )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			LuaEvents.NotificationPanel_OpenWorldCongressProposeEmergencies();
		end
	end
end

-- ===========================================================================
function OnWorldCongressNotification( notificationEntry )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			LuaEvents.NotificationPanel_ResumeCongress();
		end
	end
end

-- ===========================================================================
function OnWorldCongressResultsNotification( notificationEntry )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			NotificationManager.Dismiss(pNotification:GetPlayerID(), pNotification:GetID());
			LuaEvents.NotificationPanel_OpenWorldCongressResults();
		end
	end
end

-- ===========================================================================
function OnAddSpecialSession( pNotification:table )
	OnDefaultAddNotification( pNotification );
	m_pSpecialSessionNotification = pNotification;
	LuaEvents.WorldCongressPopup_OnSpecialSessionNotificationAdded();
end

-- ===========================================================================
function OnDismissSpecialSession( playerID:number, notificationID:number )
	m_pSpecialSessionNotification = nil;
	OnDefaultDismissNotification( playerID, notificationID );
	LuaEvents.WorldCongressPopup_OnSpecialSessionNotificationDismissed();
end

-- ===========================================================================
function OnDismissSpecialSessionNotification()
	UI.AssertMsg(m_pSpecialSessionNotification ~= nil, "Tried to dismiss special session notification, but it was nil - @sbatista");
	if m_pSpecialSessionNotification then
		OnDismissSpecialSession(m_pSpecialSessionNotification:GetPlayerID(), m_pSpecialSessionNotification:GetID());
	end
end

-- ===========================================================================
function OnCityUnpoweredNotification(notificationEntry)
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification : table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			LookAtNotification( pNotification );
		end
		LuaEvents.CityPanel_ToggleOverviewPower();
	end
end

-- ===========================================================================
function OnGrievancesAgainstYouActivated(notificationEntry)
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			local aggrievingPlayer:number = pNotification:GetValue( "PARAM_PLAYER0" );
			LuaEvents.NotificationPanel_GrievanceTalkToLeader(aggrievingPlayer);
		end
	end
end

-- ===========================================================================
function RegisterHandlers()	
	
	BASE_RegisterHandlers();

	LuaEvents.WorldCongressPopup_DismissSpecialSessionNotification.Add(OnDismissSpecialSessionNotification);
	
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_BLOCKING]			= MakeDefaultHandlers();	
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_NON_BLOCKING]		= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_CAN_BE_CALLED]		= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_EMERGENCY_CAN_BE_CALLED]			= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.NOTIFICATION_GRIEVANCES_AGAINST_YOU]							= MakeDefaultHandlers();


	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_BLOCKING].Add			= OnAddSpecialSession;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_NON_BLOCKING].Add		= OnAddSpecialSession;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_CAN_BE_CALLED].Add	= OnAddSpecialSession;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_EMERGENCY_CAN_BE_CALLED].Add			= OnAddSpecialSession;

	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_BLOCKING].Dismiss			= OnDismissSpecialSession;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_NON_BLOCKING].Dismiss		= OnDismissSpecialSession;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_CAN_BE_CALLED].Dismiss	= OnDismissSpecialSession;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_EMERGENCY_CAN_BE_CALLED].Dismiss			= OnDismissSpecialSession;
	
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_BLOCKING].Activate			= OnSpecialSessionWorldCongress;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_NON_BLOCKING].Activate		= OnSpecialSessionWorldCongress;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_SPECIAL_SESSION_CAN_BE_CALLED].Activate	= OnSpecialSessionWorldCongress;
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_EMERGENCY_CAN_BE_CALLED].Activate			= OnSpecialSessionWorldCongress;

	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_BLOCKING]					= MakeDefaultHandlers();	
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_BLOCKING].Activate			= OnWorldCongressNotification;

	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_RESULTS]					= MakeDefaultHandlers();	
	g_notificationHandlers[NotificationTypes.NOTIFICATION_WORLD_CONGRESS_RESULTS].Activate			= OnWorldCongressResultsNotification;

	g_notificationHandlers[NotificationTypes.CITY_UNPOWERED]										= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.CITY_UNPOWERED].Activate								= OnCityUnpoweredNotification;

	g_notificationHandlers[NotificationTypes.NOTIFICATION_GRIEVANCES_AGAINST_YOU].Activate			= OnGrievancesAgainstYouActivated;

end