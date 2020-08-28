
include("InstanceManager");

-- ===========================================================================
-- Members
-- ===========================================================================
m_ItemIM = InstanceManager:new("ItemInstance",	"Button", Controls.ItemsPanel);

m_Parameter = nil		-- Reference to the parameter being used. 
m_SelectedValues = nil	-- Table of string->boolean that represents checked off items.
m_ItemList = nil;		-- Table of controls for select all/none

local m_bInvertSelection:boolean = false;

-- ===========================================================================
function Close()	
	-- Clear any temporary global variables.
	m_Parameter = nil;
	m_SelectedValues = nil;

	ContextPtr:SetHide(true);
end

-- ===========================================================================
function IsItemSelected(item: table) 
	return m_SelectedValues[item.Value] == true;
end

-- ===========================================================================
function OnBackButton()
	Close();
end

-- ===========================================================================
function OnConfirmChanges()
	-- Generate sorted list from selected values.
	local values = {}
	for k,v in pairs(m_SelectedValues) do
		if(v) then
			table.insert(values, k);
		end
	end

	LuaEvents.MultiSelectWindow_SetParameterValues(m_Parameter.ParameterId, values);
	Close();
end

-- ===========================================================================
function OnItemSelect(item :table, checkBox :table)
	local value = item.Value;
	local selected = not m_SelectedValues[value];

	m_SelectedValues[item.Value] = selected;
	if m_bInvertSelection then
		checkBox:SetCheck(not selected);
	else
		checkBox:SetCheck(selected);
	end
end

-- ===========================================================================
function OnItemFocus(item :table)
	if(item) then
		Controls.FocusedItemName:SetText(item.Name);
		Controls.FocusedItemDescription:LocalizeAndSetText(item.RawDescription);

		if((item.Icon and Controls.FocusedItemIcon:SetIcon(item.Icon)) or Controls.FocusedItemIcon:SetIcon("ICON_" .. item.Value)) then
			Controls.FocusedItemIcon:SetHide(false);
		else
			Controls.FocusedItemIcon:SetHide(true);
		end
	end
end

-- ===========================================================================
function SetAllItems(bState: boolean)
	for _, node in ipairs(m_ItemList) do
		local item:table = node["item"];
		local checkBox:table = node["checkbox"];

		checkBox:SetCheck(bState);
		if m_bInvertSelection then
			m_SelectedValues[item.Value] = not bState;
		else
			m_SelectedValues[item.Value] = bState;
		end
	end
end

-- ===========================================================================
function OnSelectAll()
	SetAllItems(true);
end

-- ===========================================================================
function OnSelectNone()
	SetAllItems(false);
end

-- ===========================================================================
function ParameterInitialize(parameter : table)
	m_Parameter = parameter;
	m_SelectedValues = {};

	if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
		m_bInvertSelection = true;
	else
		m_bInvertSelection = false;
	end

	if(parameter.Value) then
		for i,v in ipairs(parameter.Value) do
			m_SelectedValues[v.Value] = true;
		end
	end

	Controls.TopDescription:SetText(parameter.Description);
	Controls.WindowTitle:SetText(parameter.Name);
	m_ItemIM:ResetInstances();

	m_ItemList = {};
	for i, v in ipairs(parameter.Values) do
		InitializeItem(v);
	end

	OnItemFocus(parameter.Values[1]);
end

-- ===========================================================================
function InitializeItem(item:table)
	local c: table = m_ItemIM:GetInstance();
	c.Name:SetText(item.Name);
	if not item.Icon or not c.Icon:SetIcon(item.Icon) then
		c.Icon:SetIcon("ICON_" .. item.Value);
	end
	c.Button:RegisterCallback( Mouse.eMouseEnter, function() OnItemFocus(item); end );
	c.Button:RegisterCallback( Mouse.eLClick, function() OnItemSelect(item, c.Selected); end );
	c.Selected:RegisterCallback( Mouse.eLClick, function() OnItemSelect(item, c.Selected); end );
	if m_bInvertSelection then
		c.Selected:SetCheck(not IsItemSelected(item));
	else
		c.Selected:SetCheck(IsItemSelected(item));
	end

	local listItem:table = {};
	listItem["item"] = item;
	listItem["checkbox"] = c.Selected;
	table.insert(m_ItemList, listItem);
end

-- ===========================================================================
function OnShutdown()
	Close();
	m_ItemIM:DestroyInstances();
	LuaEvents.MultiSelectWindow_Initialize.Remove( ParameterInitialize );
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then
		local key:number = pInputStruct:GetKey();
		if key == Keys.VK_ESCAPE then
			Close();
		end
	end
	return true;
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );

	local OnMouseEnter = function() UI.PlaySound("Main_Menu_Mouse_Over"); end;

	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnBackButton );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
	Controls.ConfirmButton:RegisterCallback( Mouse.eLClick, OnConfirmChanges );
	Controls.ConfirmButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
	Controls.SelectAllButton:RegisterCallback( Mouse.eLClick, OnSelectAll);
	Controls.SelectAllButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
	Controls.SelectNoneButton:RegisterCallback( Mouse.eLClick, OnSelectNone);
	Controls.SelectNoneButton:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);

	LuaEvents.MultiSelectWindow_Initialize.Add( ParameterInitialize );
end
Initialize();