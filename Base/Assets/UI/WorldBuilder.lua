-- ===========================================================================
--	World Builder UI Context
-- ===========================================================================

-- ===========================================================================
--	DATA MEMBERS
-- ===========================================================================
local DefaultMessageHandler = {};

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================
  
DefaultMessageHandler[KeyEvents.KeyUp] =
function( pInputStruct )
	
	local uiKey = pInputStruct:GetKey();
	if uiKey == Keys.VK_ESCAPE then
		if( Controls.TopOptionsMenu:IsHidden() ) then
			UIManager:QueuePopup( Controls.TopOptionsMenu, PopupPriority.Utmost );
			return true;
		end
	elseif uiKey == Keys.Z and pInputStruct:IsControlDown() then
		if pInputStruct:IsShiftDown() then
			if WorldBuilder.CanRedo() then
				WorldBuilder.Redo();
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_REDO"));
			else
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_CANT_REDO"));
			end
		else
			if WorldBuilder.CanUndo() then
				WorldBuilder.Undo();
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_UNDO"));
			else
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_CANT_UNDO"));
			end
		end
	elseif uiKey == Keys.Y and pInputStruct:IsControlDown() then
		if WorldBuilder.CanRedo() then
			WorldBuilder.Redo();
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_REDO"));
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_STATUS_CANT_REDO"));
		end
	elseif uiKey == Keys.VK_F5 then
		-- TODO: Quick save maps in world builder?
	end

	return false;
end

-- ===========================================================================  
function OnLoadGameViewStateDone()
	
end

-- ===========================================================================    
function InputHandler( pInputStruct )

	local uiMsg = pInputStruct:GetMessageType();

	if DefaultMessageHandler[uiMsg] ~= nil then
		return DefaultMessageHandler[uiMsg]( pInputStruct );
	else
		return false;
	end

end

-- ===========================================================================    
function OnShow()

	Controls.WorldViewControls:SetHide( false );

end

-- ===========================================================================    
function OnOpenPlayerEditor()
	LuaEvents.WorldBuilder_ShowPlayerEditor( Controls.WorldBuilderPlayerEditor:IsHidden() );
end

-- ===========================================================================    
function OnOpenMapEditor()
	LuaEvents.WorldBuilder_ShowMapEditor( Controls.WorldBuilderMapEditor:IsHidden() );
end
		   
-- ===========================================================================    
function OnOpenInGameMenu()
UIManager:QueuePopup( Controls.TopOptionsMenu, PopupPriority.Utmost );
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()
	UserConfiguration.ShowMapResources(true);
	UserConfiguration.ShowMapGrid(false);
	UserConfiguration.ShowMapYield(false);

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler( InputHandler, true );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );
	LuaEvents.WorldBuilderLaunchBar_OpenPlayerEditor.Add( OnOpenPlayerEditor );
	LuaEvents.WorldBuilderLaunchBar_OpenMapEditor.Add( OnOpenMapEditor );
	LuaEvents.WorldBuilderLaunchBar_OpenInGameMenu.Add( OnOpenInGameMenu );
end
ContextPtr:SetInitHandler( OnInit );