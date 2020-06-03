
-- ===========================================================================
-- Button Handlers
-- ===========================================================================
function OnImportWorldBuilderMap()
	UIManager:DequeuePopup( ContextPtr );	-- make Back from the load screen go directly to the main menu

	GameConfiguration.SetToDefaults();
	GameConfiguration.SetWorldBuilderEditor(true);
	MapConfiguration.SetScript("WBImport.lua");
	local advancedSetup = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/AdvancedSetup" );
	UIManager:QueuePopup(advancedSetup, PopupPriority.Current);
	Controls.SwitchPopup:SetHide(true);
end
Controls.WBAConfirmButton:RegisterCallback( Mouse.eLClick, OnImportWorldBuilderMap ); 
Controls.WBAConfirmButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

function OnCancelImport()
	Controls.SwitchPopup:SetHide(true);

	GameConfiguration.SetWorldBuilderEditor(false);
	UIManager:DequeuePopup( ContextPtr );
end

Controls.WBACancelButton:RegisterCallback( Mouse.eLClick, OnCancelImport );
Controls.WBACancelButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

-------------------------------------------------
-- Input Handler
-------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			OnCancelImport();
		end
	end
	return true;
end
ContextPtr:SetInputHandler( InputHandler );

-- ===========================================================================
function OnShow()
	Controls.SwitchPopup:SetHide(false);
end

ContextPtr:SetShowHandler( OnShow );
Controls.SwitchPopup:SetHide(false);

