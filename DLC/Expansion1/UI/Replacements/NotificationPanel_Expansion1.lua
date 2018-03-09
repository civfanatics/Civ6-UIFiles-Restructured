--[[
-- Copyright (c) 2017 Firaxis Games
--]]
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("NotificationPanel");

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================

function OnConsiderDisloyalCityNotification( notificationEntry )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			LookAtNotification( pNotification );
		end
		LuaEvents.NotificationPanel_OpenDisloyalCityChooser();
	end
end

function OnCityLosingCulturalIdentityNotification( notificationEntry )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			LookAtNotification( pNotification );
		end
		LuaEvents.CityPanel_ToggleOverviewLoyalty();
	end
end

function OnConsiderEmergency( notificationEntry )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			local eEmergencyTarget :number = pNotification:GetValue( "PARAM_PLAYER0" );
			local eEmergencyType :number = pNotification:GetValue( "PARAM_PLAYER1" );
			if (eEmergencyTarget ~= nil and eEmergencyType ~= nil) then
				LuaEvents.EmergencyClicked(eEmergencyTarget, eEmergencyType);
			else
				local eEmergencyTable :table = Game.GetEmergencyManager():GetNextBlockingEmergency(Game.GetLocalPlayer());
				LuaEvents.EmergencyClicked(eEmergencyTable.eTarget, eEmergencyTable.eEmergencyType);
			end
		end
	end
end

function OnCommemorate( notificationEntry )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			local currentEra = Game.GetEras():GetCurrentEra();
			if currentEra <= 0 then
				UI.AssertMsg(false, "Attempting to commemorate first era, this should not happen.");
			else
				LuaEvents.EraReviewPopup_Show(currentEra - 1, currentEra);
			end
		end
	end
end

function OnDedicate( notificationEntry )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry);
		if pNotification ~= nil then
			LuaEvents.PartialScreenHooks_OpenEraProgressPanel();
		end
	end
end

function OnPrideMomentActivate( notificationEntry, notificationID, activatedByUser:boolean )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer() and activatedByUser) then
		if (notificationEntry ~= nil) then
			local handler = notificationEntry.m_kHandlers;
			handler.TryDismiss( notificationEntry );
		end
	end
end

-- Similar to LookAtNotification, but we want to always look at the location and never try to select the city (since the city does not belong to us)
function OnForeignCityBecameFreeCityNotification( notificationEntry, notificationID, activatedByUser:boolean )
	if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
		local pNotification :table = GetActiveNotificationFromEntry(notificationEntry, notificationID);
		if pNotification ~= nil then
			-- Do we have a valid location?
			if pNotification:IsLocationValid() then			
				local x, y = pNotification:GetLocation();	-- Look at it.
				UI.LookAtPlot(x, y);
			end
		end
	end
end

function Initialize()
	g_notificationHandlers[NotificationTypes.CONSIDER_DISLOYAL_CITY]							= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.CONSIDER_DISLOYAL_CITY].Activate					= OnConsiderDisloyalCityNotification;
	g_notificationHandlers[NotificationTypes.CITY_LOSING_CULTURAL_IDENTITY]						= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.CITY_LOSING_CULTURAL_IDENTITY].Activate			= OnCityLosingCulturalIdentityNotification;
	g_notificationHandlers[NotificationTypes.SPY_FABRICATE_SCANDAL]								= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.SPY_ENEMY_FABRICATE_SCANDAL]						= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.SPY_FOMENT_UNREST]									= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.SPY_ENEMY_FOMENT_UNREST]							= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.SPY_NEUTRALIZE_GOVERNOR]							= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.SPY_ENEMY_NEUTRALIZE_GOVERNOR]						= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.EMERGENCY_DECLARED]								= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.EMERGENCY_DECLARED].Activate						= OnConsiderEmergency;
	g_notificationHandlers[NotificationTypes.EMERGENCY_FAILED]									= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.EMERGENCY_SUCCEEDED]								= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.EMERGENCY_NEEDS_ATTENTION]							= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.EMERGENCY_NEEDS_ATTENTION].Activate				= OnConsiderEmergency;
	g_notificationHandlers[NotificationTypes.COMMEMORATION_AVAILABLE]							= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.COMMEMORATION_AVAILABLE].Activate					= OnCommemorate;
	g_notificationHandlers[NotificationTypes.QUEST_RECORDED]									= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.QUEST_RECORDED].Activate							= OnDedicate;
	g_notificationHandlers[NotificationTypes.PRIDE_MOMENT_RECORDED]								= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.PRIDE_MOMENT_RECORDED].Activate					= OnPrideMomentActivate;
	g_notificationHandlers[NotificationTypes.FOREIGN_CITY_BECAME_FREE_CITY]						= MakeDefaultHandlers();
	g_notificationHandlers[NotificationTypes.FOREIGN_CITY_BECAME_FREE_CITY].Activate			= OnForeignCityBecameFreeCityNotification;
end
Initialize();