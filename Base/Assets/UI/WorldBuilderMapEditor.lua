-- ===========================================================================
--	World Builder Player Editor
-- ===========================================================================

include("InstanceManager");
include("SupportFunctions");
include("TabSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local DATA_FIELD_SELECTION			:string = "Selection";

local FIRST_CUSTOM_TEXT_FIELD_INDEX	:number = 5;

-- ===========================================================================
--	DATA MEMBERS
-- ===========================================================================

local m_ViewingTab		   : table = {};
local m_tabs				:table;

local m_simpleIM			:table = InstanceManager:new("SimpleInstance",			"Top",		Controls.Stack);				-- Non-Collapsable, simple
local m_tabIM			   : table = InstanceManager:new("TabInstance",				"Button",	Controls.TabContainer);

local m_LanguageEntries		: table = {};
local m_CurLanguageSel		: number = 1;
local m_TextEntries			: table = {};

local m_ReferenceMapName	: string = nil;

local m_ItemAnnotations :table = 
{
	{ "LOC_WORLDBUILDER_MAPEDIT_MODTITLE" }, { "LOC_WORLDBUILDER_MAPEDIT_MODDESC" }, { "LOC_WORLDBUILDER_MAPEDIT_MAPTITLE" }, { "LOC_WORLDBUILDER_MAPEDIT_MAPDESC" },
};

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--
-- ===========================================================================
function AddTabSection( tabs:table, name:string, populateCallback:ifunction, parent )
	local kTab		:table				= m_tabIM:GetInstance(parent);	
	kTab.Button[DATA_FIELD_SELECTION]	= kTab.Selection;

	local callback	:ifunction	= function()
		if tabs.prevSelectedControl ~= nil then
			-- Restore proper color
			tabs.prevSelectedControl:GetTextControl():SetColorByName("ShellOptionText");

			tabs.prevSelectedControl[DATA_FIELD_SELECTION]:SetHide(true);
		end
		kTab.Selection:SetHide(false);
		populateCallback();
	end

	kTab.Button:GetTextControl():SetText( Locale.Lookup(name) );
	kTab.Button:SetSizeToText( 40, 20 );
    kTab.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	tabs.AddTab( kTab.Button, callback );
end

-- ===========================================================================
function ResetTabForNewPageContent()
	m_uiGroups = {};
	m_ViewingTab = {};
	m_simpleIM:ResetInstances();
	Controls.Scroll:SetScrollValue( 0 );	
end

-- ===========================================================================
function CalculatePrimaryTabScrollArea()

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	local xOffset, yOffset = Controls.Scroll:GetParentRelativeOffset();
	Controls.Scroll:SetSizeY( Controls.TabsContainer:GetSizeY() - yOffset );
end

-- ===========================================================================
function RefreshAnnotations()
	for i, entry in ipairs(m_TextEntries) do
		local controlEntry = m_ViewingTab.TextInstance.KeyStringList:GetIndexedEntry( i );
		local toolTip : string;
		if controlEntry ~= nil then
			if controlEntry.Root.Button ~= nil then
				if i < 5 then
					TruncateString(controlEntry.Root.Annotation, controlEntry.Root.Button:GetSizeX()-20, Locale.Lookup(m_ItemAnnotations[i][1]), "");
					toolTip = Locale.Lookup(m_ItemAnnotations[i][1]);
				else
					TruncateString(controlEntry.Root.Annotation, controlEntry.Root.Button:GetSizeX()-20, Locale.Lookup("LOC_WORLDBUILDER_MAPEDIT_ADDLDATA"), "");
					toolTip = Locale.Lookup("LOC_WORLDBUILDER_MAPEDIT_ADDLDATA");
				end

				-- Set button text as 
				TruncateString(controlEntry.Root.Button, controlEntry.Root.Button:GetSizeX()-30, entry.Text, "");
				if entry.Text ~= nil then
					toolTip = toolTip.."[NEWLINE]"..entry.Text;
				end

				controlEntry.Root.Button:SetToolTipString(toolTip);
			end
		end
	end
end

-- ===========================================================================
function ChangeRemoveStatus(selected)
	if selected < FIRST_CUSTOM_TEXT_FIELD_INDEX then
		m_ViewingTab.TextInstance.RemoveText:SetDisabled(true);
		m_ViewingTab.TextInstance.RemoveText:SetColor(0.5,0.5,0.5);
	else
		m_ViewingTab.TextInstance.RemoveText:SetDisabled(false);
		m_ViewingTab.TextInstance.RemoveText:SetColor(1.0,1.0,1.0);
	end
end

-- ===========================================================================
function PopulateTextEntries(forLanguage)

	m_TextEntries = {};

	local iIndex = 1;
	local selected = 1;

	while true do

		local key, text = WorldBuilder.ModManager():GetKeyStringPairByIndex(iIndex, forLanguage);
		if key == nil then 
			break;
		end

		table.insert(m_TextEntries, { Key = key, Text = text, Index = iIndex, ForLanguage = forLanguage });

		iIndex = iIndex + 1;
	end
	
	selected = m_ViewingTab.TextInstance.TextStringEditBox:GetVoid1();
	if selected == 0 then
		selected = 1;
	end

	m_ViewingTab.TextInstance.KeyStringList:SetEntries( m_TextEntries, selected );
	ChangeRemoveStatus(selected);
	RefreshAnnotations();

	-- Manually call selection callback since SetEntries does not trigger it
	OnKeyStringListSelection(m_TextEntries[selected]);
end

-- ===========================================================================
function UpdateTextEntries()

	if (m_ViewingTab ~= nil and m_ViewingTab.TextInstance ~= nil) then
		
		local selectedLanguageEntry = m_LanguageEntries[ m_ViewingTab.TextInstance.LanguagePullDown:GetSelectedIndex() ];
		if selectedLanguageEntry ~= nil then

			m_TextEntries = {};

			local iIndex = 1;

			while true do

				local key, text = WorldBuilder.ModManager():GetKeyStringPairByIndex(iIndex, selectedLanguageEntry.Type);
				if key == nil then 
					break;
				end

				table.insert(m_TextEntries, { Key = key, Text = text, Index = iIndex, ForLanguage = selectedLanguageEntry.Type });

				iIndex = iIndex + 1;
			end
			
			if iIndex == 1 then
				selected = 0;
			end

			m_ViewingTab.TextInstance.KeyStringList:SetEntries( m_TextEntries, selected );
			ChangeRemoveStatus(selected);
			RefreshAnnotations();
		end
	end
end

-- ===========================================================================
function OnCommitTextKey(text, control)

	local i = control:GetVoid1();
	local controlEntry = m_ViewingTab.TextInstance.KeyStringList:GetIndexedEntry( i );
	if controlEntry ~= nil then
		controlEntry.Key = text;
		WorldBuilder.ModManager():SetKeyStringPairByIndex(controlEntry.Index, controlEntry.Key, controlEntry.Text, controlEntry.ForLanguage);		
		m_TextEntries[controlEntry.Index].Key = text;
		ChangeRemoveStatus(i);
		RefreshAnnotations();
	end
end

-- ===========================================================================
function OnChangedTextKey(ctrl)
	local str = ctrl:GetText();
	OnCommitTextKey(str, ctrl);
end

-- ===========================================================================
function OnCommitTextString(text, control)

	local i = control:GetVoid1();
	local controlEntry = m_ViewingTab.TextInstance.KeyStringList:GetIndexedEntry( i );
	if controlEntry ~= nil then
		controlEntry.Text = text;
		WorldBuilder.ModManager():SetKeyStringPairByIndex(controlEntry.Index, controlEntry.Key, controlEntry.Text, controlEntry.ForLanguage);
		m_TextEntries[controlEntry.Index].Text = text;
		ChangeRemoveStatus(i);
		RefreshAnnotations();
	end
end

-- ===========================================================================
function OnChangedTextString(ctrl)
	local str = ctrl:GetText();
	OnCommitTextString(str, ctrl);
end

-- ===========================================================================
function UpdateTextPage()

	if (m_ViewingTab ~= nil and m_ViewingTab.TextInstance ~= nil) then
		
		local selectedLanguageEntry = m_LanguageEntries[ m_ViewingTab.TextInstance.LanguagePullDown:GetSelectedIndex() ];
		if selectedLanguageEntry ~= nil then

			PopulateTextEntries(selectedLanguageEntry.Type);
		end
	end

end

-- ===========================================================================
function OnTextLanguageSelection(entry)
	local selectedLanguageEntry = m_LanguageEntries[ m_ViewingTab.TextInstance.LanguagePullDown:GetSelectedIndex() ];
	local curLang = Locale.GetCurrentLanguage();
	if selectedLanguageEntry ~= nil then
		for i=1,4 do
			local key, text = WorldBuilder.ModManager():GetKeyStringPairByIndex(i, selectedLanguageEntry.Type);
			-- if we don't have entries for this language, copy the current English ones
			if key == nil or text == nil then
				key,text = WorldBuilder.ModManager():GetKeyStringPairByIndex(i, curLang.Type);
				WorldBuilder.ModManager():SetString(key, text, selectedLanguageEntry.Type);
			end
		end
		UpdateTextPage();
	end
end

-- ===========================================================================
function OnKeyStringListSelection(entry)
	if entry ~= nil then
		if m_ViewingTab.TextInstance ~= nil then
			-- Set text tag and callback
			if m_ViewingTab.TextInstance.TextTagEditBox ~= nil then 
				-- must set void1 before SetText, because SetText triggers the Commit callback, which expects void1 to be valid!
				m_ViewingTab.TextInstance.TextTagEditBox:SetVoid1(entry.Index);
				m_ViewingTab.TextInstance.TextTagEditBox:SetText(entry.Key);
				m_ViewingTab.TextInstance.TextTagEditBox:SetMaxCharacters(64);

				-- Allow custom text tags to be edited outside of advance mode
				if WorldBuilder.GetWBAdvancedMode() or entry.Index >= FIRST_CUSTOM_TEXT_FIELD_INDEX then
					m_ViewingTab.TextInstance.TextTagEditBox:SetDisabled(false);
					m_ViewingTab.TextInstance.TextTagEditBox:RegisterCommitCallback(OnCommitTextKey);
					m_ViewingTab.TextInstance.TextTagEditBox:RegisterStringChangedCallback(OnChangedTextKey);
					m_ViewingTab.TextInstance.TextTagEditGrid:SetColor(1.0,1.0,1.0,1.0);
				else
					m_ViewingTab.TextInstance.TextTagEditBox:SetDisabled(true);
					-- Alpha out the color of the background to indicate it cannot be edited
					m_ViewingTab.TextInstance.TextTagEditGrid:SetColor(1.0,1.0,1.0,0.0);
				end

			end

			-- Set text string and callback
			if m_ViewingTab.TextInstance.TextStringEditBox ~= nil then
				-- must set void1 before SetText, because SetText triggers the Commit callback, which expects void1 to be valid!
				m_ViewingTab.TextInstance.TextStringEditBox:SetVoid1(entry.Index);
				m_ViewingTab.TextInstance.TextStringEditBox:SetText(entry.Text);
				m_ViewingTab.TextInstance.TextStringEditBox:RegisterCommitCallback(OnCommitTextString);						
				m_ViewingTab.TextInstance.TextStringEditBox:RegisterStringChangedCallback(OnChangedTextString);
				m_ViewingTab.TextInstance.TextStringEditBox:SetMaxCharacters(64);
			end
		end
	end
end

-- ===========================================================================
function OnAddText()
	if (m_ViewingTab ~= nil and m_ViewingTab.TextInstance ~= nil) then

		local selectedLanguageEntry = m_LanguageEntries[ m_ViewingTab.TextInstance.LanguagePullDown:GetSelectedIndex() ];
		if selectedLanguageEntry ~= nil then

			local iIndex = 1;
			while true do
				local key, text = WorldBuilder.ModManager():GetKeyStringPairByIndex(iIndex, selectedLanguageEntry.Type);
				if key == nil then 
					break;
				end
				iIndex = iIndex + 1;
			end

			WorldBuilder.ModManager():SetString(Locale.Lookup("LOC_WORLDBUILDER_MAPEDIT_DUMMYID").." "..iIndex, Locale.Lookup("LOC_WORLDBUILDER_MAPEDIT_DUMMYTEXT"), selectedLanguageEntry.Type);

			UpdateTextPage();	-- This is overkill/inefficient
		end
	end
end

-- ===========================================================================
function OnRemoveText()
	if (m_ViewingTab ~= nil and m_ViewingTab.TextInstance ~= nil) then
		local iSelectedIndex:number = m_ViewingTab.TextInstance.KeyStringList:GetSelectedIndex();
		if iSelectedIndex ~= nil then
			local kEntryToRemove:table = m_TextEntries[ iSelectedIndex ];
			if kEntryToRemove ~= nil then

				WorldBuilder.ModManager():RemoveString(kEntryToRemove.Key, kEntryToRemove.ForLanguage);		
				
				UpdateTextPage();	-- This is overkill/inefficient

				-- Select the previous index in the list
				m_ViewingTab.TextInstance.KeyStringList:SetSelectedIndex(iSelectedIndex-1, true);
			end
		end
	end
end

-- ===========================================================================
function ViewMapTextPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();

	m_ViewingTab.Name = "Text";
	m_ViewingTab.TextInstance = {};
	ContextPtr:BuildInstanceForControl( "TextInstance", m_ViewingTab.TextInstance, instance.Top ) ;	

	-- Initialize Controls
	m_ViewingTab.TextInstance.LanguagePullDown:SetEntrySelectedCallback( OnTextLanguageSelection );
	m_ViewingTab.TextInstance.LanguagePullDown:SetEntries( m_LanguageEntries, 1 );
	m_ViewingTab.TextInstance.LanguagePullDown:SetSelectedIndex( m_CurLanguageSel, false );
	m_ViewingTab.TextInstance.KeyStringList:SetEntrySelectedCallback( OnKeyStringListSelection );
	m_ViewingTab.TextInstance.AddText:RegisterCallback( Mouse.eLClick, OnAddText );
	m_ViewingTab.TextInstance.RemoveText:RegisterCallback( Mouse.eLClick, OnRemoveText );

	UpdateTextPage();

	CalculatePrimaryTabScrollArea();

end

-- ===========================================================================
function UpdateModPage()
	if (m_ViewingTab ~= nil and m_ViewingTab.ModInstance ~= nil) then
		
	end
end

-- ===========================================================================
function OnModCheckboxButton()
	if (m_ViewingTab ~= nil and m_ViewingTab.GeneralInstance ~= nil) then
		local newIsSelected :boolean = not m_ViewingTab.GeneralInstance.IsModCheckbox:IsSelected();

		m_ViewingTab.GeneralInstance.IsModCheckbox:SetSelected(newIsSelected);
		WorldBuilder.SetMod( newIsSelected );
	end	
end

-- ===========================================================================
function ViewMapModPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();

	m_ViewingTab.Name = "Mod";
	m_ViewingTab.ModInstance = {};
	ContextPtr:BuildInstanceForControl( "ModInstance", m_ViewingTab.ModInstance, instance.Top );

	UpdateModPage();

	CalculatePrimaryTabScrollArea();

end

-- ===========================================================================
function OnMapScriptEdited( text, control )
	
	WorldBuilder.ConfigurationManager():SetMapValue("MapScript", text);

end

-- ===========================================================================
function OnMapReferenceEdited( text, control )
	StrategicView_ClearReferenceMap();
	local bResult : boolean = StrategicView_SetReferenceMap(text);
	if bResult then
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_REFERENCE_MAP_LOADED"));
	else
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_REFERENCE_MAP_NOT_FOUND"));
	end
	m_ReferenceMapName = text;
end

-- ===========================================================================
function OnMapReferenceAlphaEdited( text, control )
	if text == nil then
		LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_REFERENCE_ALPHA_BAD_2"));
	else
		local refAlpha : number = tonumber(text);
		if refAlpha ~= nil then
			if (refAlpha >= 0.0 and refAlpha <= 1.0) then
				StrategicView_SetReferenceMapAlpha(refAlpha);
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_REFERENCE_ALPHA_SET"));
			else
				LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_REFERENCE_ALPHA_BAD"));
			end
		else
			LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_REFERENCE_ALPHA_BAD_2"));
		end
	end
end

-- ===========================================================================
function OnRulesetEdited( text, control )
	
	WorldBuilder.ConfigurationManager():SetMapValue("Ruleset", text);

end

-- ===========================================================================
function OnGenerateID()
	local newID :string = WorldBuilder.GenerateID();
	WorldBuilder.SetID(newID);
	if (m_ViewingTab ~= nil and m_ViewingTab.GeneralInstance ~= nil) then
		m_ViewingTab.GeneralInstance.IDEdit:SetText( WorldBuilder.GetID() );
	end
end

-- ===========================================================================
function UpdateGeneralPage()	

	if (m_ViewingTab ~= nil and m_ViewingTab.GeneralInstance ~= nil) then
		
		local isMod = WorldBuilder.IsMod();
		m_ViewingTab.GeneralInstance.IsModCheckbox:SetSelected(isMod);

		if WorldBuilder.GetWBAdvancedMode() then
			m_ViewingTab.GeneralInstance.IsModCheckbox:SetHide(false);

			m_ViewingTab.GeneralInstance.RulesetEdit:SetDisabled(false);
			m_ViewingTab.GeneralInstance.MapScriptEdit:SetDisabled(false);
		else
			m_ViewingTab.GeneralInstance.IsModCheckbox:SetHide(true);
			
			m_ViewingTab.GeneralInstance.RulesetEdit:SetDisabled(true);
			m_ViewingTab.GeneralInstance.MapScriptEdit:SetDisabled(true);
		end
	
		m_ViewingTab.GeneralInstance.IDEdit:SetDisabled(true);
		m_ViewingTab.GeneralInstance.IDEdit:SetText( WorldBuilder.GetID() );
		local attribs = WorldBuilder.ConfigurationManager():GetMapValues();
		m_ViewingTab.GeneralInstance.WidthLabel:SetText( tostring( attribs.Width ) );
		m_ViewingTab.GeneralInstance.HeightLabel:SetText( tostring( attribs.Height ) );
		m_ViewingTab.GeneralInstance.RulesetEdit:SetText( tostring( attribs.Ruleset ) );
		m_ViewingTab.GeneralInstance.MapScriptEdit:SetText( tostring( attribs.MapScript ) );
		local refAlpha : number = StrategicView_GetReferenceMapAlpha();
		if refAlpha == nil then
			refAlpha = 0.5;
			StrategicView_SetReferenceMapAlpha(0.5);
		else
			if refAlpha < 0.0 or refAlpha > 1.0 then
				refAlpha = 0.5;
				StrategicView_SetReferenceMapAlpha(0.5);
			end
		end
		m_ViewingTab.GeneralInstance.MapReferenceAlphaEdit:SetText( tostring(refAlpha) );
		if m_ReferenceMapName ~= nil then
			m_ViewingTab.GeneralInstance.MapReferenceEdit:SetText( m_ReferenceMapName );
		end
		m_ViewingTab.GeneralInstance.MapReferenceEdit:SetDisabled(false);
		m_ViewingTab.GeneralInstance.MapReferenceAlphaEdit:SetDisabled(false);
	end

end

-- ===========================================================================
function ViewMapGeneralPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	m_ViewingTab.Name = "General";
	m_ViewingTab.GeneralInstance = {};
	ContextPtr:BuildInstanceForControl( "GeneralInstance", m_ViewingTab.GeneralInstance, instance.Top ) ;	

	m_ViewingTab.GeneralInstance.IsModCheckbox:RegisterCallback( Mouse.eLClick, OnModCheckboxButton );
	m_ViewingTab.GeneralInstance.GenerateNewIDButton:RegisterCallback(Mouse.eLClick, OnGenerateID);
	m_ViewingTab.GeneralInstance.MapScriptEdit:RegisterCommitCallback( OnMapScriptEdited );
	m_ViewingTab.GeneralInstance.RulesetEdit:RegisterCommitCallback( OnRulesetEdited );
	m_ViewingTab.GeneralInstance.MapReferenceEdit:RegisterCommitCallback( OnMapReferenceEdited );
	m_ViewingTab.GeneralInstance.MapReferenceAlphaEdit:RegisterCommitCallback( OnMapReferenceAlphaEdited );

	UpdateGeneralPage();

	CalculatePrimaryTabScrollArea();
end

-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE and not ContextPtr:IsHidden() then
		ContextPtr:SetHide(true);
		LuaEvents.WorldBuilder_ShowMapEditor(false);
		return true;
	end

	return false;
end

function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();

	if uiMsg == KeyEvents.KeyUp then 
		return KeyHandler( pInputStruct:GetKey() ); 
	end;

	return false;
end

-- ===========================================================================
function OnShow()

	if m_tabs.selectedControl == nil then
		m_tabs.SelectTab(1);
	end

	if (m_ViewingTab ~= nil and m_ViewingTab.GeneralInstance ~= nil) then
		if WorldBuilder.GetWBAdvancedMode() then
			--m_ViewingTab.GeneralInstance.GenerateNewIDButton:SetHide(false);
		else
			--m_ViewingTab.GeneralInstance.GenerateNewIDButton:SetHide(true);
		end
	end
end

-- ===========================================================================
function OnClose()
	ContextPtr:SetHide(true);
	LuaEvents.WorldBuilder_ShowMapEditor(false);
end

-- ===========================================================================
function OnShowPlayerEditor(bShow)
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function OnShowMapEditor(bShow)
	if bShow == nil or bShow == true then
		if ContextPtr:IsHidden() then
			ContextPtr:SetHide(false);
		end
	else
		if not ContextPtr:IsHidden() then
			ContextPtr:SetHide(true);
		end
	end
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.WorldBuilder_ShowPlayerEditor.Remove( OnShowPlayerEditor );
	LuaEvents.WorldBuilder_ShowMapEditor.Remove( OnShowMapEditor );
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	-- Title
	Controls.ModalScreenTitle:SetText( Locale.ToUpper("LOC_WORLDBUILDER_MAP_EDITOR") );

	ContextPtr:SetInputHandler( OnInputHandler, true );

	m_tabs = CreateTabs( Controls.TabContainer, 42, 34, UI.GetColorValueFromHexLiteral(0xFF331D05) );
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_GENERAL", ViewMapGeneralPage, Controls.TabContainer );
	if WorldBuilder.GetWBAdvancedMode() then
		AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_MOD", ViewMapModPage, Controls.TabContainer );
	end
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_TEXT", ViewMapTextPage, Controls.TabContainer );

	m_tabs.SameSizedTabs(50);
	m_tabs.CenterAlignTabs(-10);		

	-- Langauges we can edit.  These should come from a data file.
	local languages = Locale.GetLanguages();
	m_CurLanguageSel = 1;
	local curLang = Locale.GetCurrentLanguage();
	for i, v in ipairs(languages) do
		table.insert(m_LanguageEntries, { Text=Locale.Lookup("{1: title}", v.Name), Type=v.Locale });
		if curLang.Type == v.Locale then
			m_CurLanguageSel = i;
		end
	end

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetShutdown( OnShutdown );

	Controls.ModalScreenClose:RegisterCallback( Mouse.eLClick, OnClose );

	LuaEvents.WorldBuilder_ShowPlayerEditor.Add( OnShowPlayerEditor );
	LuaEvents.WorldBuilder_ShowMapEditor.Add( OnShowMapEditor );

	local pFriends = Network.GetFriends();
	if (pFriends ~= nil) then
		pFriends:SetRichPresence("civPresence", "LOC_PRESENCE_WORLD_BUILDER");
	end
end
ContextPtr:SetInitHandler( OnInit );