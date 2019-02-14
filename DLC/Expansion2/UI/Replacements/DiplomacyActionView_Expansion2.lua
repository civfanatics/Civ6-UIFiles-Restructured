-- Copyright 2018, Firaxis Games

-- ===========================================================================
--	INCLUDE XP1 Functionality
-- ===========================================================================
include("DiplomacyActionView_Expansion1.lua");


-- ===========================================================================
--	CACHE FUNCTIONS
--	Do not make cache functions local so overriden functions can check these names.
-- ===========================================================================
BASE_Close = Close;
BASE_LateInitialize = LateInitialize;
BASE_OnShow = OnShow;
XP1_PopulateIntelPanels = PopulateIntelPanels;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_uiWorldCongressInfoContext :table = nil;


-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function AddOverviewAgendas(overviewInstance:table)
	GetIntelOverviewAgendas():ResetInstances();
	local overviewAgendasInst:table = GetIntelOverviewAgendas():GetInstance(overviewInstance.IntelOverviewStack);

	GetIntelOverviewAgendaEntries():ResetInstances();

	if (PlayerConfigurations[ms_SelectedPlayerID]:IsHuman()) then
		-- Humans don't have agendas, at least ones we can show
		overviewAgendasInst.Top:SetHide(true);
	else
		overviewAgendasInst.Top:SetHide(false);
		-- What Historical Agenda does the selected player have?
		local leader:string = PlayerConfigurations[ms_SelectedPlayerID]:GetLeaderTypeName();

		local localPlayerDiplomacy = ms_LocalPlayer:GetDiplomacy();
		local iAccessLevel = localPlayerDiplomacy:GetVisibilityOn(ms_SelectedPlayerID);

		-- What randomly assigned agendas does the selected player have? 
		-- Determine whether our Diplomatic Visibility allows us to see random agendas
		local bRevealRandom = false;
		for row in GameInfo.Visibilities() do
			if (row.Index <= iAccessLevel and row.RevealAgendas == true) then
				bRevealRandom = true;
			end
		end
		local kAgendaTypes = {};
		kAgendaTypes = ms_SelectedPlayer:GetAgendasAndVisibilities();
		--GetAgendaTypes() returns ALL of my agendas, including the historical agenda. 
		--To retrieve only the randomly assigned agendas, delete the first entry from the table.  
		local numRandomAgendas = table.count(kAgendaTypes);
		local numHiddenAgendas = 0;
		local numRandomAgendas = 0;
		for i, entry in ipairs(kAgendaTypes) do
			if (entry.Visibility <= iAccessLevel) then
					local randomAgenda = GetIntelOverviewAgendaEntries():GetInstance(overviewAgendasInst.OverviewAgendasStack);
				randomAgenda.Text:LocalizeAndSetText( GameInfo.Agendas[entry.Agenda].Name );
				randomAgenda.Text:LocalizeAndSetToolTip( GameInfo.Agendas[entry.Agenda].Description );
				numRandomAgendas = numRandomAgendas + 1;
			else
				numHiddenAgendas = numHiddenAgendas + 1;
			end
				end
		if ( numHiddenAgendas > 0 ) then
				local hiddenAgenda = GetIntelOverviewAgendaEntries():GetInstance(overviewAgendasInst.OverviewAgendasStack);
                hiddenAgenda.Text:LocalizeAndSetText("LOC_DIPLOMACY_HIDDEN_AGENDAS", numHiddenAgendas, numHiddenAgendas>1 );
                if ( numHiddenAgendas > 1 ) then
                    hiddenAgenda.Text:LocalizeAndSetToolTip("LOC_DIPLOMACY_HIDDEN_AGENDAS_TT");
                else
                    hiddenAgenda.Text:LocalizeAndSetToolTip("LOC_DIPLOMACY_HIDDEN_AGENDAS_TT_LATE");
                end
		elseif (numHiddenAgendas == 0) then
			if (numRandomAgendas == 0) then
				local noRandomAgendas = GetIntelOverviewAgendaEntries():GetInstance(overviewAgendasInst.OverviewAgendasStack);
				noRandomAgendas.Text:LocalizeAndSetText("LOC_DIPLOMACY_RANDOM_AGENDA_NONE");
				noRandomAgendas.Text:SetToolTipString(nil); -- disable tooltip for this one
			end
		end
	end

	return not overviewAgendasInst.Top:IsHidden();
end

-- ===========================================================================
function PopulateStatementList( options: table, rootControl: table, isSubList: boolean )
	local buttonIM:table;
	local stackControl:table;
	local selectionText :string = "[SIZE_16]";	-- Resetting the string size for the new button instance
	if (isSubList) then
		buttonIM = g_ActionListIM;
		stackControl = rootControl.SubOptionStack;		
	else
		buttonIM = g_SubActionListIM;
		stackControl = rootControl.OptionStack;
	end
	buttonIM:ResetInstances();

	for _, selection in ipairs(options) do
		local instance		:table		= buttonIM:GetInstance(stackControl);
		local selectionText :string		= selectionText.. Locale.Lookup(selection.Text);
		local callback		:ifunction;
		local tooltipString	:string		= nil;
		if( selection.Key ~= nil) then
			callback	= function() OnSelectInitialDiplomacyStatement( selection.Key ) end;

			local pActionDef = GameInfo.DiplomaticActions[selection.DiplomaticActionType];
			instance.Button:SetToolTipString(GetStatementButtonTooltip(pActionDef));

			-- If costs gold add text
			local iCost = GetGoldCost(selection.Key);
			if iCost > 0 then
				local szGoldString = Locale.Lookup("LOC_DIPLO_CHOICE_GOLD_INFO", iCost);
				selectionText = selectionText .. szGoldString; 
			end

			local pDiploActionData:table = GameInfo.DiplomaticActions_XP2[selection.DiplomaticActionType];
			if pDiploActionData ~= nil then
				local favorCost = pDiploActionData.FavorCost;
				if favorCost ~= nil then
					selectionText = selectionText .. Locale.Lookup("LOC_DIPLO_CHOICE_FAVOR_INFO", favorCost); 
				end
			end

			-- If war statement add warmongering info
			if (IsWarChoice(selection.Key))then
				local eWarType = GetWarType(selection.Key);
				local iWarmongerPoints = ms_LocalPlayer:GetDiplomacy():ComputeDOWWarmongerPoints(ms_SelectedPlayerID, eWarType);
				local szWarmongerString = Locale.Lookup("LOC_DIPLO_CHOICE_GENERATES_GRIEVANCES_INFO", iWarmongerPoints);
				selectionText = selectionText .. szWarmongerString; 

				-- Change callback to prompt first.
				callback = function() 
					LuaEvents.DiplomacyActionView_ConfirmWarDialog(ms_LocalPlayerID, ms_SelectedPlayerID, eWarType);
				end;
			end
			
			--If denounce statement change callback to prompt first.
			if (selection.Key == "CHOICE_DENOUNCE")then
				local szWarmongerString = Locale.Lookup("LOC_DIPLO_CHOICE_GENERATES_GRIEVANCES_INFO", GlobalParameters.GRIEVANCES_FOR_DENOUNCEMENT);
				selectionText = selectionText .. szWarmongerString; 
				local denounceFn = function() OnSelectInitialDiplomacyStatement( selection.Key ); end;
				callback = function() 
					local playerConfig = PlayerConfigurations[ms_SelectedPlayer:GetID()];
					if (playerConfig ~= nil) then

						selectedCivName = playerConfig:GetCivilizationShortDescription();
						m_PopupDialog:Reset();
						m_PopupDialog:AddText(Locale.Lookup("LOC_DENOUNCE_POPUP_BODY", selectedCivName));
						m_PopupDialog:AddButton(Locale.Lookup("LOC_CANCEL"), nil);
						m_PopupDialog:AddButton(Locale.Lookup("LOC_DIPLO_CHOICE_DENOUNCE_NO_GRIEVANCE"), denounceFn, nil, nil, "PopupButtonInstanceRed");
						m_PopupDialog:Open();

					end
				end;
			end

			instance.ButtonText:SetText( selectionText );
			if (selection.IsDisabled == nil or selection.IsDisabled == false) then
	            instance.Button:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				instance.Button:RegisterCallback( Mouse.eLClick, callback );
				instance.ButtonText:SetColor( COLOR_BUTTONTEXT_NORMAL );
				instance.Button:SetDisabled( false );
			else
				instance.ButtonText:SetColor( COLOR_BUTTONTEXT_DISABLED );
				instance.Button:SetDisabled( true );
				if (selection.FailureReasons ~= nil) then
					instance.Button:SetToolTipString(Locale.Lookup(selection.FailureReasons[1]));
				end
			end
			instance.Button:SetDisabled(not g_bIsLocalPlayerTurn or selection.IsDisabled == true);
		else
			callback = selection.Callback;
			instance.ButtonText:SetColor( COLOR_BUTTONTEXT_NORMAL );
			instance.Button:SetDisabled(not g_bIsLocalPlayerTurn);
			if ( selection.ToolTip ~= nil) then
				tooltipString = Locale.Lookup(selection.ToolTip);
				instance.Button:SetToolTipString(tooltipString);
			else
				instance.Button:SetToolTipString(nil);		-- Clear any existing
			end
		end

		local wasTruncated :boolean = TruncateString(instance.ButtonText, MAX_BEFORE_TRUNC_BUTTON_INST, selectionText);
		if wasTruncated then
			local finalTooltipString	:string	= selectionText;
			if tooltipString ~= nil then
				finalTooltipString = finalTooltipString .. "[NEWLINE]" .. tooltipString;
			end
			instance.Button:SetToolTipString( finalTooltipString );
		end

		-- Append tooltip string to the end of the tooltip if it exists in this selection
		if selection.Tooltip then
			local currentTooltipString = instance.Button:GetToolTipString();
			instance.Button:SetToolTipString(currentTooltipString .. Locale.Lookup(selection.Tooltip));
		end

        instance.Button:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		instance.Button:RegisterCallback( Mouse.eLClick, callback );					
	end
	if (isSubList) then
		local instance		:table		= buttonIM:GetInstance(stackControl);
		selectionText	= selectionText.. Locale.Lookup("LOC_CANCEL_BUTTON");
		instance.ButtonText:SetText( selectionText );
		instance.Button:SetToolTipString(nil);
		instance.Button:SetDisabled(false);
		instance.ButtonText:SetColor( COLOR_BUTTONTEXT_NORMAL );
		instance.Button:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		instance.Button:RegisterCallback( Mouse.eLClick, function() ShowOptionStack(false); end );	
	end
	stackControl:CalculateSize();
end

-- ===========================================================================
function PopulateIntelPanels( kTabContainer:table)
	XP1_PopulateIntelPanels( kTabContainer );
	
	AddWorldCongressInfoTab( kTabContainer );
	
	-- Refresh contexts (if this isn't being called from an override.)
	if XP2_PopulateIntelPanels == nil then
		LuaEvents.DiploScene_RefreshTabs(GetSelectedPlayerID());
	end
end

-- ===========================================================================
function AddWorldCongressInfoTab( kTabContainer:table )

	-- Create tab
	local kTabAnchor :table = GetTabAnchor( kTabContainer );
	if m_uiWorldCongressInfoContext == nil then
		m_uiWorldCongressInfoContext = ContextPtr:LoadNewContext("DiplomacyActionView_WorldCongressTab", kTabAnchor.Anchor);
	else
		m_uiWorldCongressInfoContext:ChangeParent( kTabAnchor.Anchor );
	end

	-- Create tab button
	local uiTabButton:table = CreateTabButton();
	uiTabButton.Button:RegisterCallback( Mouse.eLClick, function() ShowPanel(kTabAnchor.Anchor); end );
	uiTabButton.Button:SetToolTipString(Locale.Lookup("LOC_DIPLOACTION_WORLD_CONGRESS_TAB_TOOLTIP"));
	uiTabButton.ButtonIcon:SetIcon("ICON_STAT_GRIEVANCE");

	-- Cache references to the button instance and header text on the panel instance
	kTabAnchor.Anchor.m_ButtonInstance = uiTabButton;
	kTabAnchor.Anchor.m_HeaderText = Locale.ToUpper("LOC_DIPLOACTION_INTEL_REPORT_GRIEVANCES");
end

-- ===========================================================================
function Close()
	BASE_Close();
	local pWorldCongress:table = Game.GetWorldCongress();
	LuaEvents.DiplomacyActionView_HideCongress();
end

-- ===========================================================================
function OnShow()
	BASE_OnShow();
	if Game.GetEras():GetCurrentEra() >= GlobalParameters.WORLD_CONGRESS_INITIAL_ERA then
		Controls.TabBar:SetHide(false);
	else
		Controls.TabBar:SetHide(true);
	end
end

-- ===========================================================================
function OnTalkToLeader( playerID : number )
	local pWorldCongress:table = Game.GetWorldCongress();
	m_LiteMode = pWorldCongress:IsInSession();
	OnOpenDiplomacyActionView( playerID );
end

-- ===========================================================================
function LateInitialize()
	BASE_LateInitialize();
	LuaEvents.WorldCongress_OpenDiplomacyActionViewLite.Add(OnOpenDiplomacyActionViewLite);
	LuaEvents.WorldCongress_OpenDiplomacyActionView.Add(OnOpenDiplomacyActionView);

	local isCongressInSession:boolean = false;
	
	Events.WorldCongressStage1.Add(function() isCongressInSession = true; end);
	Events.WorldCongressStage2.Add(function() isCongressInSession = true; end);
	Events.WorldCongressFinished.Add(function() isCongressInSession = false; end);

	Controls.WCButton:RegisterCallback(Mouse.eLClick, function() 
		OnClose();
		if not isCongressInSession then
			LuaEvents.DiplomacyActionView_ShowCongressResults();
		else
			LuaEvents.DiplomacyActionView_ResumeCongress();
		end
	end);
	Controls.LaunchBacking:SetSizeX(Controls.TabBar:GetSizeX() + 144);
	Controls.LaunchBackingTile:SetSizeX(Controls.TabBar:GetSizeX() + 10);
	Controls.LaunchBarDropShadow:SetSizeX(Controls.TabBar:GetSizeX());
	ContextPtr:SetShowHandler( OnShow );
end