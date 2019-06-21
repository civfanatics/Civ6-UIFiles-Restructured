-- ===========================================================================
function OnSetTabHeader( header:string )
	Controls.TabHeader:SetText(header);
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()
	LuaEvents.WorldBuilderMapTools_SetTabHeader.Add( OnSetTabHeader );
	LuaEvents.WorldBuilderToolsPalette_SetTabHeader.Add( OnSetTabHeader );
	Controls.SelectTab_WorldBuilderPlacement:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.SelectTab_WorldBuilderPlotEditor:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end
ContextPtr:SetInitHandler( OnInit );
