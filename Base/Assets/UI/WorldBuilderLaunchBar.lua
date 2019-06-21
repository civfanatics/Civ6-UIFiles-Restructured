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
function OnSetPlacementStatus(string)
	Controls.StatusLine:SetText(string);
end

-- ===========================================================================
function OnLaunchMenu()
	LuaEvents.WorldBuilderLaunchBar_OpenInGameMenu();
end

-- ===========================================================================
function OnAdvancedModeChanged()
	Controls.PlayerEditorButton:SetHide(not WorldBuilder.GetWBAdvancedMode());
end

-- ===========================================================================
--	Initialize
-- ===========================================================================
function Initialize()
	Controls.PlayerEditorButton:RegisterCallback( Mouse.eLClick, OnOpenPlayerEditor );
	Controls.MapEditorButton:RegisterCallback( Mouse.eLClick, OnOpenMapEditor );
	Controls.LaunchMenu:RegisterCallback(Mouse.eLClick, OnLaunchMenu);
	Controls.LaunchMenu:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);

	Controls.PlayerEditorButton:SetHide(not WorldBuilder.GetWBAdvancedMode());

	LuaEvents.WorldBuilder_SetPlacementStatus.Add(OnSetPlacementStatus);
	LuaEvents.WorldBuilder_ModeChanged.Add( OnAdvancedModeChanged );

	Controls.StatusLine:SetText(Locale.Lookup("LOC_WORLDBUILDER_STATUS_STARTUP"));
end
Initialize();

