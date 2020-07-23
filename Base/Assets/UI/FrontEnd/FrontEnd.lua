-- ===========================================================================
--
--	Root content for the "Shell" (aka: FrontEnd)
--	All menus are loaded off of here, including the MainMenu.
--
-- ===========================================================================

include("PopupDialog")
include("InputSupport");



-- ===========================================================================
--	Event Handlers
-- ===========================================================================
function OnMultiplayerJoinRoomAttempt()
	--We're attempting to join a lobby room as part of joining multiplayer game.  Show the joining room screen.
	UIManager:QueuePopup(Controls.JoiningRoom, PopupPriority.Current);
end  


-- ===========================================================================
function OnInit()

    -- Inform the user if we're unable to find the their graphics device in the device database
    if(UI.HasUnknownDevice() and Options.GetAppOption("Misc", "AcceptedUnknownDevice") ~= 1) then
    
        local unknownDevicePopupDialog = PopupDialog:new("UnknownGraphicsDevice");
        unknownDevicePopupDialog:ShowOkDialog(Locale.Lookup("LOC_FRONTEND_POPUP_UNKNOWN_DEVICE"), 
            function()
                print("Failed to determine graphics device capabilities. User was informed.");
                Options.SetAppOption("Misc", "AcceptedUnknownDevice", 1);
                Events.UserAcceptsUnknownDevice();
				ClosePopup();
            end
        );
		OpenPopup();
    end

    -- Inform the user if their driver is older than the recommended version 
    if(UI.HasOutdatedDriver() and Options.GetAppOption("Misc", "AcceptedOutdatedDriver") ~= 1) then
    
        local outdatedDriversPopupDialog:table = PopupDialog:new("OutdatedGraphicsDriver");
        outdatedDriversPopupDialog:AddText(Locale.Lookup("LOC_FRONTEND_POPUP_OUTDATED_DRIVER"));
        outdatedDriversPopupDialog:AddButton(Locale.Lookup("LOC_FRONTEND_POPUP_OUTDATED_DRIVER_QUIET"),
            function()
                print("User is running with outdated drivers. User was informed and chose not to be informed again.");
                Options.SetAppOption("Misc", "AcceptedOutdatedDriver", 1);
                Events.UserAcceptsOutdatedDriver();
				ClosePopup();
            end
        );
        outdatedDriversPopupDialog:AddButton(Locale.Lookup("LOC_FRONTEND_POPUP_OUTDATED_DRIVER_LOUD"),
            function()
                print("User is running with outdated drivers. User was informed and wants to keep being informed.");
				ClosePopup();
            end
        );
        outdatedDriversPopupDialog:Open();
		OpenPopup();
    end

end

function OpenPopup()
	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
end

function ClosePopup()
	UIManager:DequeuePopup(ContextPtr);
	-- Front end background is visible on this context, so we should never be hidden
	ContextPtr:SetHide(false);
end

-- ===========================================================================
function OnShutdown()

	if (Controls.BackgroundMovie ~= nil) then
		Controls.BackgroundMovie:Close();
	end

    Events.SystemUpdateUI.Remove( OnUpdateUI );
    Events.MultiplayerJoinRoomAttempt.Remove( OnMultiplayerJoinRoomAttempt );
end

-- ===========================================================================
function OnUpdateUI(type:number, tag:string, iData1:number, iData2:number, strData1:string)
    if type == SystemUpdateUI.ScreenResize then
		--Resize();
		if (Controls.BackgroundMovie ~= nil) then
			Controls.BackgroundMovie:ReprocessAnchoring();
		end
	end
end

-- ===========================================================================
--	
-- ===========================================================================
function Initialize()

	Input.SetActiveContext( InputContext.Shell );

	ContextPtr:SetInputHandler( OnInputHandler, true );
    ContextPtr:SetInitHandler( OnInit );
    ContextPtr:SetShutdown( OnShutdown );

    Events.SystemUpdateUI.Add( OnUpdateUI );

	Events.MultiplayerJoinRoomAttempt.Add( OnMultiplayerJoinRoomAttempt );

	-- Does a main menu exist?
	if Controls.MainMenu ~= nil then	
		UIManager:QueuePopup( Controls.MainMenu, PopupPriority.Low );
	else
		-- No main menu; there better be a test file being shown.
		if Controls.Test == nil then
			UI.DataError("No 'MainMenu' and no 'Test' control found!");			
		end
	end
end
Initialize();
