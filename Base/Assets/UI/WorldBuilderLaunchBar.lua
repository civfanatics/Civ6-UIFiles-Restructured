-- ===========================================================================
--	World Builder Launch Bar
-- ===========================================================================

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

function OnOpenPlayerEditor()

	LuaEvents.WorldBuilderLaunchBar_OpenPlayerEditor();

end

-- ===========================================================================
function OnOpenMapEditor()

	LuaEvents.WorldBuilderLaunchBar_OpenMapEditor();

end

-- ===========================================================================
function ChangeModes(status)
Controls.ToggleAdvanced:SetSelected(status);
	WorldBuilder.SetWBAdvancedMode(status);
	Controls.PlayerEditorButton:SetHide(not status);
	Controls.SwitchPopup:SetHide(true);
	UI.PlaySound("Generic_Popup_Close");
	LuaEvents.WorldBuilder_ModeChanged();
end

-- ===========================================================================
function GoBasic()
	ChangeModes(false);
	Controls.ToggleAdvanced:LocalizeAndSetText("LOC_WORLDBUILDER_SWITCH_ADV");
	Controls.ToggleAdvanced:RegisterCallback(Mouse.eLClick, AdvancedToggleClick ); 
end

-- ===========================================================================
function SwitchConfirm()
	ChangeModes(true);
	Controls.ToggleAdvanced:LocalizeAndSetText("LOC_WORLDBUILDER_SWITCH_BASIC");
	Controls.ToggleAdvanced:RegisterCallback(Mouse.eLClick, GoBasic ); 
	Controls.ToggleAdvanced:SetSelected(false);
end

-- ===========================================================================
function SwitchCancel()
	Controls.SwitchPopup:SetHide(true);
	UI.PlaySound("Generic_Popup_Close");
end

-- ===========================================================================
function AdvancedToggleClick()
	Controls.SwitchPopup:SetHide(false);
	UI.PlaySound("Generic_Popup_Appears");
end

-- ===========================================================================
function OnSetPlacementStatus(string)
	Controls.StatusLine:SetText(string);
end

-- ===========================================================================
function OnLaunchMenu()
	LuaEvents.WorldBuilderLaunchBar_OpenInGameMenu();
end

-- ===========================================================================
--	Initialize
-- ===========================================================================
function Initialize()
	Controls.SwitchPopup:SetHide(true);
	Controls.PlayerEditorButton:RegisterCallback( Mouse.eLClick, OnOpenPlayerEditor );
	Controls.MapEditorButton:RegisterCallback( Mouse.eLClick, OnOpenMapEditor );
	Controls.LaunchMenu:RegisterCallback(Mouse.eLClick, OnLaunchMenu);
	Controls.LaunchMenu:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.ToggleAdvanced:RegisterCallback(Mouse.eLClick, AdvancedToggleClick );
	Controls.ToggleAdvanced:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, SwitchConfirm );
	Controls.ConfirmButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.CancelButton:RegisterCallback(Mouse.eLClick, SwitchCancel );
	Controls.CancelButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);

	if not WorldBuilder.GetWBAdvancedMode() then
		Controls.PlayerEditorButton:SetHide(true);
	end

	LuaEvents.WorldBuilder_SetPlacementStatus.Add(OnSetPlacementStatus);

	Controls.StatusLine:SetText(Locale.Lookup("LOC_WORLDBUILDER_STATUS_STARTUP"));
end
Initialize();

