-------------------------------------------------
-- PlayByCloud Notification Setup Reminder
-------------------------------------------------

-------------------------------------------------
-------------------------------------------------
function OnOptions()
	LuaEvents.PBCNotifyRemind_ShowOptions();
	ContextPtr:SetHide( true );
end

-------------------------------------------------
-------------------------------------------------
function OnAccept()
	ContextPtr:SetHide( true );
end

-------------------------------------------------
-------------------------------------------------
function OnDoNotRemindToggled()
	local newCheckState = Controls.DoNotRemindCheckbox:IsChecked();
	-- Checked means do not show the reminder popup in the future.
	if(newCheckState) then
		Options.SetUserOption("Interface", "PlayByCloudNotifyRemind", 0);
	else
		Options.SetUserOption("Interface", "PlayByCloudNotifyRemind", 1);
	end
	Options.SaveOptions();
end

----------------------------------------------------------------
-- Input processing
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyUp then
        if wParam == Keys.VK_ESCAPE then
            OnAccept();  
        end
        if wParam == Keys.VK_RETURN then
            OnAccept();  
        end
    end
    return true;
end

-------------------------------------------------
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
	if( not bIsHide ) then
	end
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function GetPBCRemindText()
	if( Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS ) then
		return Locale.Lookup("LOC_EPIC_PBC_OVERVIEW_DESC");
	end

	return Locale.Lookup("LOC_PBC_OVERVIEW_DESC");
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function Initialize()
	ContextPtr:SetInputHandler( InputHandler );
	ContextPtr:SetShowHideHandler( ShowHideHandler );

	Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnAccept );
	Controls.OptionsButton:RegisterCallback( Mouse.eLClick, OnOptions );
	Controls.DoNotRemindCheckbox:RegisterCheckHandler( OnDoNotRemindToggled );

	Controls.RemindText:SetText( GetPBCRemindText() );
end
Initialize();

