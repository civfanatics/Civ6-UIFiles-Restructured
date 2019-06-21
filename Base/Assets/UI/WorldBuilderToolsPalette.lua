-- Worlder Builder: Set of tools that sits in upper left hand corner
-- Copyright 2019, Firaxis Games

include( "InstanceManager" );

-- ===========================================================================
--	CONSTANTS
--	Hotkeys are still a WIP!
-- ===========================================================================
local m_kToolData : table =
{
	{ ID=WorldBuilderModes.PLACE_TERRAIN,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_TERRAIN",         Icon="ICON_WB_TOOL_TERRAIN",	IsAdvanced=false,	PlacementFunc=PlaceTerrain,		Hotkey="1", PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_FEATURES,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_FEATURES",        Icon="ICON_WB_TOOL_FEATURES",	IsAdvanced=false,	PlacementFunc=PlaceFeature,		Hotkey="2", PlacementValid=PlaceFeature_Valid    },
	{ ID=WorldBuilderModes.PLACE_CONTINENTS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CONTINENT",       Icon="ICON_WB_TOOL_CONTINENT",	IsAdvanced=false,	PlacementFunc=PlaceContinent,	Hotkey="3", PlacementValid=PlaceContinent_Valid, OnEntered=OnContinentToolEntered, OnLeft=OnContinentToolLeft, NoMouseOverHighlight=true },
	{ ID=WorldBuilderModes.PLACE_RIVERS,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_RIVERS",          Icon="ICON_WB_TOOL_RIVERS",		IsAdvanced=false,	PlacementFunc=PlaceRiver,		Hotkey="4", PlacementValid=nil,                  NoMouseOverHighlight=true },
	{ ID=WorldBuilderModes.PLACE_CLIFFS,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CLIFFS",          Icon="ICON_WB_TOOL_CLIFFS",		IsAdvanced=false,	PlacementFunc=PlaceCliff,		Hotkey="5", PlacementValid=PlaceCliff_Valid       },
	{ ID=WorldBuilderModes.PLACE_RESOURCES,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_RESOURCES",       Icon="ICON_WB_TOOL_RESOURCES",	IsAdvanced=false,	PlacementFunc=PlaceResource,	Hotkey="6", PlacementValid=PlaceResource_Valid    },
	{ ID=WorldBuilderModes.PLACE_IMPROVEMENTS,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_IMPROVEMENTS",    Icon="ICON_WB_TOOL_IMPROVEMENTS",IsAdvanced=false,	PlacementFunc=PlaceImprovement, Hotkey="7", PlacementValid=PlaceImprovement_Valid },
	{ ID=WorldBuilderModes.PLACE_CITIES,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_CITIES",			Icon="ICON_WB_TOOL_BUILDINGS",	IsAdvanced=true,	PlacementFunc=PlaceCity,        Hotkey="8", PlacementValid=nil                  },
	{ ID=WorldBuilderModes.PLACE_DISTRICTS,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_DISTRICTS",       Icon="ICON_WB_TOOL_DISTRICTS",	IsAdvanced=true,	PlacementFunc=PlaceDistrict,    Hotkey="9", PlacementValid=PlaceDistrict_Valid   },
	{ ID=WorldBuilderModes.PLACE_BUILDINGS,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_BUILDINGS",       Icon="ICON_WB_TOOL_BUILDINGS",	IsAdvanced=true,	PlacementFunc=PlaceBuilding,    Hotkey="0", PlacementValid=PlaceBuilding_Valid   },
	{ ID=WorldBuilderModes.PLACE_UNITS,				Text="LOC_WORLDBUILDER_PLACEMENT_MODE_UNITS",           Icon="ICON_WB_TOOL_UNITS",		IsAdvanced=true,	PlacementFunc=PlaceUnit,        Hotkey="U", PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_ROUTES,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_ROUTES",          Icon="ICON_WB_TOOL_ROUTES",		IsAdvanced=true,	PlacementFunc=PlaceRoute,       Hotkey="R", PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_START_POSITIONS,	Text="LOC_WORLDBUILDER_PLACEMENT_MODE_START_POSITIONS", Icon="ICON_WB_TOOL_START",		IsAdvanced=true,	PlacementFunc=PlaceStartPos,    Hotkey="S", PlacementValid=nil                   },
	{ ID=WorldBuilderModes.PLACE_TERRAIN_OWNER,		Text="LOC_WORLDBUILDER_PLACEMENT_MODE_OWNER",           Icon="ICON_WB_TOOL_OWNER",		IsAdvanced=true,	PlacementFunc=PlaceOwnership,   Hotkey="O", PlacementValid=nil                   },
	{ ID=WorldBuilderModes.SET_VISIBILITY,			Text="LOC_WORLDBUILDER_PLACEMENT_MODE_SET_VISIBILITY",	Icon="ICON_WB_TOOL_VISIBILITY",	IsAdvanced=true,	PlacementFunc=PlaceVisibility,  Hotkey="V", PlacementValid=nil,                  OnEntered=OnVisibilityToolEntered, OnLeft=OnVisibilityToolLeft },
};

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_toolIM	:table = InstanceManager:new( "ToolInstance", "Button", Controls.ToolsStack );
local m_uiTools	:table = {};
local m_kHotkeys:table = {};


-- ===========================================================================
--	Returns true or false if a tool can be used (based on basic/advanced mode)
-- ===========================================================================
function CanUseTool( toolID:number )
	if WorldBuilder.GetWBAdvancedMode() then
		return true;
	end

	-- Basic mode
	for i,kToolData in ipairs(m_kToolData) do
		if kToolData.ID == toolID and kToolData.IsAdvanced==false then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
--	Raise and event for the tool ID that is now active.
-- ===========================================================================
function OnChangeToolFunc( toolID:number, toolName:string )
	LuaEvents.WorldBuilderToolsPalette_ChangeTool( toolID );

	for id,uiTool in pairs(m_uiTools) do
		uiTool.Button:SetDisabled( id == toolID );
		uiTool.Active:SetHide( id ~= toolID );
		if (id == toolID) then
			local name:string = uiTool["tooltip"];
			if name then
				LuaEvents.WorldBuilderToolsPalette_SetTabHeader( Locale.Lookup(name) );
			end
		end
	end
end

-- ===========================================================================
--	Create a tool icon and connect it's art, tooltip, and callback function.
-- ===========================================================================
function MakeTool( toolID:number, icon:string, tooltip:string, isAdvanced:boolean )
	if isAdvanced == nil then isAdvanced = false; end;	
	
	local uiTool:table = isAdvanced and m_toolIM:GetInstance(Controls.AdvancedStack) or m_toolIM:GetInstance();	
	if icon then uiTool.Icon:SetIcon( icon ) end;
	if tooltip then uiTool.Button:SetToolTipString( Locale.Lookup(tooltip) ) end;
	uiTool.Button:RegisterCallback( Mouse.eLClick, 
		function() 
			OnChangeToolFunc( toolID );
		end);
	uiTool.Button:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);

	uiTool["isAdvanced"] = isAdvanced;	--Dynamically add to instance
	uiTool["tooltip"] = tooltip;		--Dynamically add to instance

	return uiTool;
end

-- ===========================================================================
function SetAdvancedMode( isOn:boolean )
	
	local label:string = Locale.Lookup( isOn and "LOC_WORLDBUILDER_BASIC" or "LOC_WORLDBUILDER_ADVANCED" );
	Controls.ToggleAdvanced:SetText( label );
	
	local tooltip:string = Controls.ToggleAdvanced:GetTextControl():IsTextTruncated() and (label.."[NEWLINE]") or "";
	tooltip = tooltip .. Locale.Lookup( isOn and "LOC_WORLDBUILDER_SWITCH_BASIC" or "LOC_WORLDBUILDER_SWITCH_ADV" );
	Controls.ToggleAdvanced:SetToolTipString( tooltip );
	
	Controls.AdvancedTools:SetHide( not isOn );
	WorldBuilder.SetWBAdvancedMode( isOn );
	LuaEvents.WorldBuilder_ModeChanged();

	if isOn then
		m_uiTools[WorldBuilderModes.PLACE_IMPROVEMENTS].Icon:SetIcon("ICON_WB_TOOL_IMPROVEMENTS");
		m_uiTools[WorldBuilderModes.PLACE_IMPROVEMENTS].Button:SetToolTipString(Locale.Lookup("LOC_WORLDBUILDER_PLACEMENT_MODE_IMPROVEMENTS"));
	else
		m_uiTools[WorldBuilderModes.PLACE_IMPROVEMENTS].Icon:SetIcon("ICON_WB_TOOL_GOODY_HUTS");
		m_uiTools[WorldBuilderModes.PLACE_IMPROVEMENTS].Button:SetToolTipString(Locale.Lookup("LOC_WORLDBUILDER_PLACEMENT_MODE_GOODY_HUTS"));
	end
end

-- ===========================================================================
function SwitchConfirm()
	Controls.SwitchPopup:SetHide(true);
	SetAdvancedMode(true);
end

-- ===========================================================================
function SwitchCancel()
	Controls.SwitchPopup:SetHide(true);
	UI.PlaySound("Generic_Popup_Close");
end

-- ===========================================================================
function AdvancedToggleClick()
	if Controls.AdvancedTools:IsHidden() then
		Controls.SwitchPopup:SetHide(false);
		UI.PlaySound("Generic_Popup_Appears");
	else
		SetAdvancedMode(false);
	end
end


-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function KeyDownHandler( key:number )
	return false;
end
function KeyUpHandler( key:number )	
	print(key, Keys["1"], m_kHotkeys[tostring(key)]);
	local toolID:number = m_kHotkeys[tostring(key)];
	if toolID ~= nil then
		if CanUseTool(toolID) then
			OnChangeToolFunc( toolID );
			return true;
		end
	end	
    return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyDown then return KeyDownHandler( pInputStruct:GetKey() ); end
	if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end	
	return false;
end


-- ===========================================================================
function Initialize()
	-- Generate tools from constant table.
	for _,kEntry in ipairs(m_kToolData) do
		m_uiTools[kEntry.ID] = MakeTool( kEntry.ID, kEntry.Icon, kEntry.Text, kEntry.IsAdvanced );
		if kEntry.Hotkey then
			m_kHotkeys[ Locale.ToUpper(Keys[kEntry.Hotkey]) ] = kEntry.ID;
		end
	end

	SetAdvancedMode( false );

	ContextPtr:SetInputHandler( OnInputHandler, true );
	Controls.SwitchPopup:SetHide(true);

	Controls.ToggleAdvanced:RegisterCallback( Mouse.eLClick, AdvancedToggleClick );
	Controls.ToggleAdvanced:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, SwitchConfirm );
	Controls.ConfirmButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CancelButton:RegisterCallback(Mouse.eLClick, SwitchCancel );
	Controls.CancelButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end
Initialize()
