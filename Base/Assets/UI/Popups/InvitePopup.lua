include( "InstanceManager");
include( "PopupDialog" );

local m_kPopupDialog:table		= {};

-- ===========================================================================
function AcceptInvite(inviteID)
	local pFriends = Network.GetFriends();
	if (pFriends ~= nil) then
		pFriends:AcceptInvite(inviteID);
	end
	m_kPopupDialog:Close();
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
function DeclineInvite(inviteID)
	local pFriends = Network.GetFriends();
	if (pFriends ~= nil) then
		pFriends:DeclineInvite(inviteID);
	end
	m_kPopupDialog:Close();
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
function IsInGame()
	if(GameConfiguration ~= nil) then
		return GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_LAUNCHED;
	end
	return false;
end

-- ===========================================================================
function OnEpicInvite(inviteID, playerName)
	if( Network.GetInternetTransportType() == TransportType.TRANSPORT_EOS) then

		local popupText:string = "";

		if(playerName ~= nil and playerName ~= "") then
			if( IsInGame() ) then
				popupText = Locale.Lookup("TXT_KEY_EOS_PLAYER_INVITE_TEXT_IN_GAME", playerName);
			else
				popupText = Locale.Lookup("TXT_KEY_EOS_PLAYER_INVITE_TEXT", playerName);
			end
		else
			if( IsInGame() ) then
				popupText = Locale.Lookup("TXT_KEY_EOS_INVITE_TEXT_IN_GAME");
			else
				popupText = Locale.Lookup("TXT_KEY_EOS_INVITE_TEXT");
			end
		end


		m_kPopupDialog:Close();
		m_kPopupDialog:Reset();
		m_kPopupDialog:AddTitle( Locale.Lookup("TXT_KEY_EOS_INVITE_TITLE") );
		m_kPopupDialog:AddText( popupText );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_CANCEL_BUTTON"), function() DeclineInvite(inviteID); end, nil, nil, nil, Keys.PAD_B );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_JOIN_GAME"), function() AcceptInvite(inviteID); end, nil, nil, nil, Keys.PAD_A );
		m_kPopupDialog:Open();
		UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost );
	end
end

-- ===========================================================================
function OnShutdown()
	Events.EOSInviteReceived.Remove( OnEpicInvite );
end

-- ===========================================================================
function OnInit()
	Events.EOSInviteReceived.Add( OnEpicInvite );
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);

	m_kPopupDialog = PopupDialog:new( "LobbyPopupDialog" );
end
Initialize();
