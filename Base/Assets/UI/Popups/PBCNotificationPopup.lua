-- ===========================================================================
--	Copyright 2015-2019, Firaxis Games
--
--  Handles logic related to ingame popups for Play By Cloud Notifications.
-- ===========================================================================
include("PopupDialog.lua");

-- ===========================================================================
--	Variables
-- ===========================================================================
local m_kPopupDialog :table;
local m_matchID :number = FireWireTypes.FIREWIRE_INVALID_ID;

-- ===========================================================================
--	Scripting Logic
-- ===========================================================================
function OnJoinMatch()
	Matchmaking.AcceptCloudGameInvite(m_matchID);
	Events.ExitToMainMenu();
end

-- ===========================================================================
--	Event Handlers
-- ===========================================================================
function OnPBCNotificationPopup_ShowYourTurn(matchID :number, matchName :string)
	m_matchID = matchID;

	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_PBC_NOTIFY_POPUP_YOUR_TURN_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_PBC_NOTIFY_POPUP_YOUR_TURN_BODY", matchName));
	m_kPopupDialog:AddConfirmButton( Locale.Lookup("LOC_PBC_NOTIFY_JOIN_MATCH"), OnJoinMatch );
	m_kPopupDialog:AddCancelButton( Locale.Lookup("LOC_CANCEL"), nil );
	m_kPopupDialog:Open();
end

function OnPBCNotificationPopup_ShowUnseenComplete(matchID :number, matchName :string)
	m_matchID = matchID;

	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_PBC_NOTIFY_POPUP_UNSEEN_COMPLETE_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_PBC_NOTIFY_POPUP_UNSEEN_COMPLETE_BODY", matchName));
	m_kPopupDialog:AddConfirmButton( Locale.Lookup("LOC_PBC_NOTIFY_VIEW_RESULTS"), OnJoinMatch );
	m_kPopupDialog:AddCancelButton( Locale.Lookup("LOC_CANCEL"), nil );
	m_kPopupDialog:Open();
end


-- ===========================================================================
--	Initialization
-- ===========================================================================
function Initialize()
	LuaEvents.PBCNotificationPopup_ShowYourTurn.Add(OnPBCNotificationPopup_ShowYourTurn);
	LuaEvents.PBCNotificationPopup_ShowUnseenComplete.Add(OnPBCNotificationPopup_ShowUnseenComplete);

	m_kPopupDialog = PopupDialogInGame:new( "PBCNotifyPopup" );
end

Initialize();
