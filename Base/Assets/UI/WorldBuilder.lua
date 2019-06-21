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
			OnOpenInGameMenu();
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
--	Hide (or Show) all the contexts part of the BULK group.
--	Simplified version compared to InGame (no reference counting)
-- ===========================================================================
function BulkHide( isHide:boolean, debugWho:string )

	-- Do the bulk hiding/showing	
	local kGroups:table = {"WorldViewControls", "HUD"};
	for i,group in ipairs(kGroups) do
		local pContext :table = ContextPtr:LookUpControl("/WorldBuilder/"..group);
		if pContext == nil then
			UI.DataError("WorldBuilder is unable to BulkHide("..isHide..") '/WorldBuilder/"..group.."' because the Context doesn't exist.");
		else
			pContext:SetHide(isHide);
		end
	end
end
function OnFullscreenMapShown()			BulkHide( true, "FullscreenMap" );	end	
function OnFullscreenMapClosed()		BulkHide(false, "FullscreenMap" );	end	


-- ===========================================================================    
function OnShutdown()
	Events.LoadGameViewStateDone.Remove( OnLoadGameViewStateDone );
	
	LuaEvents.FullscreenMap_Shown.Remove( OnFullscreenMapShown );
	LuaEvents.FullscreenMap_Closed.Remove(	OnFullscreenMapClosed );
	LuaEvents.WorldBuilderLaunchBar_OpenPlayerEditor.Remove( OnOpenPlayerEditor );
	LuaEvents.WorldBuilderLaunchBar_OpenMapEditor.Remove( OnOpenMapEditor );
	LuaEvents.WorldBuilderLaunchBar_OpenInGameMenu.Remove( OnOpenInGameMenu );
end

-- ===========================================================================
function OnInit()
	UserConfiguration.ShowMapResources(true);
	UserConfiguration.ShowMapGrid(false);
	UserConfiguration.ShowMapYield(false);
end

-- ===========================================================================
function Initialize()

	-- Register for events
	ContextPtr:SetInputHandler( InputHandler, true );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInitHandler( OnInit );

	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );

	LuaEvents.FullscreenMap_Shown.Add( OnFullscreenMapShown );
	LuaEvents.FullscreenMap_Closed.Add(	OnFullscreenMapClosed );
	LuaEvents.WorldBuilderLaunchBar_OpenPlayerEditor.Add( OnOpenPlayerEditor );
	LuaEvents.WorldBuilderLaunchBar_OpenMapEditor.Add( OnOpenMapEditor );
	LuaEvents.WorldBuilderLaunchBar_OpenInGameMenu.Add( OnOpenInGameMenu );

end
Initialize();
