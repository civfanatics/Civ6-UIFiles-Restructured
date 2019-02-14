-------------------------------------------------
-- Confirm Player Kick
-------------------------------------------------
include( "PopupDialog" );

local g_kickIdx:number = -1;

-------------------------------------------------
-------------------------------------------------
function OnCancel()
    UIManager:PopModal( ContextPtr );
    ContextPtr:CallParentShowHideHandler( true );
    ContextPtr:SetHide( true );
end

-------------------------------------------------
-------------------------------------------------
function OnAccept()
	print("OnAccept: g_kickIdx: " .. tostring(g_kickIdx));
	Network.KickPlayer( g_kickIdx );
	UIManager:PopModal( ContextPtr );
	ContextPtr:CallParentShowHideHandler( true );
	ContextPtr:SetHide( true );
end

----------------------------------------------------------------
-- Input processing
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyUp then
        if wParam == Keys.VK_ESCAPE then
            OnCancel();  
        end
        if wParam == Keys.VK_RETURN then
            OnAccept();  
        end
    end
    return true;
end
ContextPtr:SetInputHandler( InputHandler );

-------------------------------------------------
-------------------------------------------------
function OnSetKickPlayer(playerID, playerName)
	g_kickIdx = playerID;

	m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
	m_kPopupDialog:AddText( Locale.Lookup("LOC_CONFIRM_KICK_PLAYER_DESC", playerName) );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_ACCEPT_BUTTON"), OnAccept, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_CANCEL_BUTTON"), OnCancel );
	m_kPopupDialog:Open();
end

-------------------------------------------------
-------------------------------------------------
function OnMultiplayerPostPlayerDisconnected(iPlayerID)
	-- Cancel out if the target player has disconnected from the game.
	if(ContextPtr:IsHidden() == false) then
		if(g_kickIdx == iPlayerID) then
			OnCancel();
		end
	end
end

-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()
	Events.MultiplayerPostPlayerDisconnected.Add(OnMultiplayerPostPlayerDisconnected);

	LuaEvents.SetKickPlayer.Add(OnSetKickPlayer);

	m_kPopupDialog = PopupDialog:new( "ConfirmKick" );
end
Initialize();


