
-- ===========================================================================
-- Button Handlers
-- ===========================================================================
function OnNewWorldBuilderMap()

	GameConfiguration.SetToDefaults();
	GameConfiguration.SetWorldBuilderEditor(true);
	local advancedSetup = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/AdvancedSetup" );
	UIManager:QueuePopup(advancedSetup, PopupPriority.Current);
end
Controls.NewWorldBuilderMap:RegisterCallback( Mouse.eLClick, OnNewWorldBuilderMap );
Controls.NewWorldBuilderMap:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

function OnImportWorldBuilderMap()

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
end

Controls.WBACancelButton:RegisterCallback( Mouse.eLClick, OnCancelImport );
Controls.WBACancelButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);


function OnImportWarn()
	Controls.SwitchPopup:SetHide(false);
end
Controls.ImportWorldBuilderMap:RegisterCallback( Mouse.eLClick, OnImportWarn );
Controls.ImportWorldBuilderMap:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);



-- ===========================================================================
function OnLoadWorldBuilderMap()
	GameConfiguration.SetToDefaults();
	LuaEvents.MainMenu_SetLoadGameServerType(ServerType.SERVER_TYPE_NONE);
	GameConfiguration.SetWorldBuilderEditor(true);
	local loadGameMenu = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/LoadGameMenu" );
	UIManager:QueuePopup(loadGameMenu, PopupPriority.Current);	
end
Controls.LoadWorldBuilderMap:RegisterCallback( Mouse.eLClick, OnLoadWorldBuilderMap );
Controls.LoadWorldBuilderMap:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function BackButtonClick()
	GameConfiguration.SetWorldBuilderEditor(false);
	UIManager:DequeuePopup( ContextPtr );
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, BackButtonClick );
Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);


-------------------------------------------------
-- Input Handler
-------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			if Controls.SwitchPopup:IsHidden() then
				BackButtonClick();
			else
				Controls.SwitchPopup:SetHide(true);
			end
		end
	end
	return true;
end
ContextPtr:SetInputHandler( InputHandler );
Controls.SwitchPopup:SetHide(true);

