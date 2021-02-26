-- ===========================================================================
--	World Builder Player Editor
-- ===========================================================================

include("InstanceManager");
include("SupportFunctions");
include("TabSupport");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID = "WorldBuilderPlayerEditor";


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local DATA_FIELD_SELECTION						:string = "Selection";

local m_SelectedPlayer = nil;
local m_PlayerEntries      : table = {};
local m_PlayerIndexToEntry : table = {};
local m_CivEntries         : table = {};
local m_LeaderEntries      : table = {};
local m_EraEntries         : table = {};
local m_TechEntries        : table = {};
local m_CivicEntries       : table = {};
local m_CivLevelEntries	   : table = {};
local m_CityEntries		   : table = {};
local m_DistrictEntries	   : table = {};
local m_BuildingEntries	   : table = {};
local m_ViewingTab		   : table = {};
local m_tabs				:table;

local m_groupIM				:table = InstanceManager:new("GroupInstance",			"Top",		Controls.Stack);				-- Collapsable
local m_simpleIM			:table = InstanceManager:new("SimpleInstance",			"Top",		Controls.Stack);				-- Non-Collapsable, simple
local m_tabIM				:table = InstanceManager:new("TabInstance",				"Button",	Controls.TabContainer);
local m_playerInstanceIM	:table = InstanceManager:new("PlayerInstance",			"Button",	Controls.PlayerStack);

local m_uiGroups			:table = nil;	-- Track the groups on-screen for collapse all action.

local m_selectedPlayerEntry :table = nil;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function PlacementSetResults(bStatus: boolean, sStatus: table, name: string)
	local result : string;

	if bStatus then
		UI.PlaySound("UI_WB_Placement_Succeeded");
		result = Locale.Lookup(name) .. " " .. Locale.Lookup("LOC_WORLDBUILDER_BLANK_PLACEMENT_OK");
	else
		if sStatus.NeededDistrict ~= -1 then
			result = Locale.Lookup("LOC_WORLDBUILDER_CREATE_DISTRICT", m_DistrictEntries[sStatus.NeededDistrict+1].Text);
		elseif sStatus.NeededPopulation > 0 then
			result = Locale.Lookup("LOC_WORLDBUILDER_DISTRICT_REQUIRES") .. " " .. sStatus.NeededPopulation .. " " .. Locale.Lookup("LOC_WORLDBUILDER_POPULATION");
		elseif sStatus.bInProgress then
			result=Locale.Lookup("LOC_WORLDBUILDER_IN_PROGRESS");
		elseif sStatus.AlreadyExists then
			result=Locale.Lookup("LOC_WORLDBUILDER_ALREADY_EXISTS");
		elseif sStatus.IsOccupied then
			result=Locale.Lookup("LOC_WORLDBUILDER_OCCUPIED_BY_ENEMY");
		elseif sStatus.DistrictIsPillaged then
			result=Locale.Lookup("LOC_WORLDBUILDER_IS_PILLAGED");
		elseif sStatus.LocationIsContaminated then
			result=Locale.Lookup("LOC_WORLDBUILDER_IS_CONTAMINATED");
		else
			result=Locale.Lookup("LOC_WORLDBUILDER_FAILURE_UNKNOWN");
		end
		UI.PlaySound("UI_WB_Placement_Failed");
	end

	LuaEvents.WorldBuilder_SetPlacementStatus(result);
end

-- ===========================================================================
--
-- ===========================================================================
function AddTabSection( tabs:table, name:string, populateCallback:ifunction, parent )
	local kTab		:table				= m_tabIM:GetInstance(parent);	
	kTab.Button[DATA_FIELD_SELECTION]	= kTab.Selection;

	local callback	:ifunction	= function()
		-- Previous selection
		if tabs.prevSelectedControl ~= nil then
			-- Restore proper color
			tabs.prevSelectedControl:GetTextControl():SetColorByName("ShellOptionText");

			-- Hide selection control
			if tabs.prevSelectedControl[DATA_FIELD_SELECTION] ~= nil then
				tabs.prevSelectedControl[DATA_FIELD_SELECTION]:SetHide(true);
			end
		end

		-- Current selection
		if kTab.Selection then
			kTab.Selection:SetHide(false);
		end
		populateCallback();
	end

	kTab.Button:GetTextControl():SetText( Locale.ToUpper(name) );
	kTab.Button:SetSizeToText( 30, 20 );
    kTab.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	tabs.AddTab( kTab.Button, callback );
end

-- ===========================================================================
function SetTabsDisabled(tabs:table, areDisabled:boolean)
	for i, tabControl in ipairs(tabs.tabControls) do
		if areDisabled then
			tabControl:SetDisabled(true);
			tabControl:GetTextControl():SetColorByName("ShellOptionText");
			tabControl.Selection:SetHide(true);
		else
			tabControl:SetDisabled(false);
		end
	end
end

-- ===========================================================================
--	Instantiate a new collapsable row (group) holder & wire it up.
--	ARGS:	(optional) isCollapsed
--	RETURNS: New group instance
-- ===========================================================================
function NewCollapsibleGroupInstance( isCollapsed:boolean )
	if isCollapsed == nil then
		isCollapsed = false;
	end
	local instance:table = m_groupIM:GetInstance();	
	instance.ContentStack:DestroyAllChildren();
	instance["isCollapsed"]		= isCollapsed;
	instance["CollapsePadding"] = nil;				-- reset any prior collapse padding

	instance.CollapseAnim:SetToBeginning();
	if isCollapsed == false then
		instance.CollapseAnim:SetToEnd();
	end	

	instance.RowHeaderButton:RegisterCallback( Mouse.eLClick, function() OnToggleCollapseGroup(instance); end );			
  	instance.RowHeaderButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	instance.CollapseAnim:RegisterAnimCallback(               function() OnAnimGroupCollapse( instance ); end );

	table.insert( m_uiGroups, instance );

	return instance;
end

-- ===========================================================================
--	Set a group to it's proper collapse/open state
--	Set + - in group row
-- ===========================================================================
function RealizeGroup( instance:table )
	local v :number = (instance["isCollapsed"]==false and instance.RowExpandCheck:GetSizeY() or 0);
	instance.RowExpandCheck:SetTextureOffsetVal(0, v);

	instance.ContentStack:CalculateSize();	
	instance.CollapseScroll:CalculateSize();
	
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	instance.CollapseAnim:SetBeginVal(0, -(groupHeight - instance["CollapsePadding"]));
	instance.CollapseScroll:SetSizeY( groupHeight );				

	instance.Top:ReprocessAnchoring();
end

-- ===========================================================================
--	Callback
--	Expand or contract a group based on its existing state.
-- ===========================================================================
function OnToggleCollapseGroup( instance:table )
	instance["isCollapsed"] = not instance["isCollapsed"];
	instance.CollapseAnim:Reverse();
	RealizeGroup( instance );
end

-- ===========================================================================
--	Toggle a group expanding / collapsing
--	instance,	A group instance.
-- ===========================================================================
function OnAnimGroupCollapse( instance:table)
		-- Helper
	function lerp(y1:number,y2:number,x:number)
		return y1 + (y2-y1)*x;
	end
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	local collapseHeight:number = instance["CollapsePadding"]~=nil and instance["CollapsePadding"] or 0;
	local startY		:number = instance["isCollapsed"]==true  and groupHeight or collapseHeight;
	local endY			:number = instance["isCollapsed"]==false and groupHeight or collapseHeight;
	local progress		:number = instance.CollapseAnim:GetProgress();
	local sizeY			:number = lerp(startY,endY,progress);

	instance.CollapseAnim:SetSizeY( groupHeight );		
	instance.CollapseScroll:SetSizeY( sizeY );	
	instance.ContentStack:ReprocessAnchoring();	
	instance.Top:ReprocessAnchoring()

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();			
end


-- ===========================================================================
function SetGroupCollapsePadding( instance:table, amount:number )
	instance["CollapsePadding"] = amount;
end

-- ===========================================================================
function ResetTabForNewPageContent()
	m_uiGroups = {};
	m_ViewingTab = {};
	m_groupIM:ResetInstances();
	m_simpleIM:ResetInstances();
	Controls.Scroll:SetScrollValue( 0 );	
end

-- ===========================================================================
--	Get the index if the CivEntry that matches the civ type.
--  This can also be one of the special keys, such as RANDOM or UNDEFINED
-- ===========================================================================
function GetCivEntryIndexByType(civType)
	for i, civEntry in ipairs(m_CivEntries) do
		if civEntry ~= nil and civEntry.Type == civType then
			return i;
		end
	end

	return 0;
end

-- ===========================================================================
--	Set the default leader for our indexed civ list from a game info entry
-- ===========================================================================
function SetCivDefaultLeader(civLeaderEntry)
	for _, civEntry in ipairs(m_CivEntries) do
		if civEntry ~= nil and civEntry.Type == civLeaderEntry.CivilizationType then
			civEntry.DefaultLeader = civLeaderEntry.LeaderType;
		end
	end
end

-- ===========================================================================
--	Get the index if the LeaderEntry that matches the leader type.
--  This can also be one of the special keys, such as RANDOM or UNDEFINED
-- ===========================================================================
function GetLeaderEntryIndexByType(leaderType)
	for i, leaderEntry in ipairs(m_LeaderEntries) do
		if leaderEntry ~= nil and leaderEntry.Type == leaderType then
			return i;
		end
	end

	return 0;
end

-- ===========================================================================
--	Get the index if the CivLevelEntry that matches the level type.
-- ===========================================================================
function GetCivLevelEntryIndexByType(civLevelType)
	for i, civLevelEntry in ipairs(m_CivLevelEntries) do
		if civLevelEntry ~= nil and civLevelEntry.Type == civLevelType then
			return i;
		end
	end

	return 0;
end

-- ===========================================================================
--	Get the index of the Civ's era that matches the type.
-- ===========================================================================
function GetCivEraIndexByType(civEraType)
	for i, civEraEntry in ipairs(m_EraEntries) do
		if civEraEntry ~= nil and civEraEntry.Type == civEraType then
			return i;
		end
	end

	return 1;
end

-- ===========================================================================
function UpdateTechTabValues()

	if m_SelectedPlayer ~= nil then

		if (m_ViewingTab.TechInstance ~= nil and m_ViewingTab.TechInstance.TechList ~= nil) then
			for i,techEntry in ipairs(m_TechEntries) do
				local hasTech = WorldBuilder.PlayerManager():PlayerHasTech( m_SelectedPlayer.Index, techEntry.Type.Index );
				m_ViewingTab.TechInstance.TechList:SetEntrySelected( techEntry, hasTech, false );
			end
		end
	end

end

-- ===========================================================================
function UpdateCivicsTabValues()

	if m_SelectedPlayer ~= nil then

		if (m_ViewingTab.CivicsInstance ~= nil and m_ViewingTab.CivicsInstance.CivicsList) then
			for i,civicEntry in ipairs(m_CivicEntries) do
				local hasCivic = WorldBuilder.PlayerManager():PlayerHasCivic( m_SelectedPlayer.Index, civicEntry.Type.Index );
				m_ViewingTab.CivicsInstance.CivicsList:SetEntrySelected( civicEntry, hasCivic, false );
			end
		end
	end

end

-- ===========================================================================
--	Handler for when a player is selected.
-- ===========================================================================
function OnPlayerSelected(entry)
	-- Deselect the previous selected player
	if m_SelectedPlayer then
		if m_SelectedPlayer.playerInstance and m_SelectedPlayer.playerInstance.Button then
			m_SelectedPlayer.playerInstance.Button:SetSelected(false);
		end
	end

	-- Switch to general if we don't have another tab selected
	if entry ~= nil and m_ViewingTab.Name == nil then
		ViewPlayerGeneralPage();
	end

	m_SelectedPlayer = entry;
	local playerSelected = entry ~= nil;

	if playerSelected then

		-- Set button as selected
		if m_SelectedPlayer.playerInstance and m_SelectedPlayer.playerInstance.Button then
			m_SelectedPlayer.playerInstance.Button:SetSelected(true);
		end

		if (m_ViewingTab.Name ~= nil) then
			UpdateGeneralTabValues();
			UpdateTechTabValues();
			UpdateCivicsTabValues();

			if (m_ViewingTab.Name == "Cities") then
				ViewPlayerCitiesPage();				
			end
		end

		SetTabsDisabled(m_tabs, false);
	else
		-- Disable tabs and reset content
		SetTabsDisabled(m_tabs, true);
		ResetTabForNewPageContent();
	end

	if (m_ViewingTab.TechInstance ~= nil and m_ViewingTab.TechInstance.TechList ~= nil) then
		m_ViewingTab.TechInstance.TechList:SetDisabled( not playerSelected );
	end
	if (m_ViewingTab.CivicsInstance ~= nil and m_ViewingTab.CivicsInstance.CivicsList ~= nil) then
		m_ViewingTab.CivicsInstance.CivicsList:SetDisabled( not playerSelected );
	end
end

-- ===========================================================================
function UpdatePlayerEntry(playerEntry)

	local playerConfig = WorldBuilder.PlayerManager():GetPlayerConfig(playerEntry.Index);

	-- Create a player instance if we don't have one yet
	if playerEntry.playerInstance == nil then
		playerEntry.playerInstance = m_playerInstanceIM:GetInstance();
	end

	playerEntry.Config = playerConfig;
	playerEntry.Leader = playerConfig.Leader ~= nil and playerConfig.Leader or Locale.Lookup("LOC_WORLDBUILDER_UNDEFINED");
	playerEntry.Civ    = playerConfig.Civ ~= nil and playerConfig.Civ or Locale.Lookup("LOC_WORLDBUILDER_UNDEFINED");
	playerEntry.CivLevel = playerConfig.CivLevel ~= nil and playerConfig.CivLevel or Locale.Lookup("LOC_WORLDBUILDER_UNDEFINED");
	playerEntry.Era    = playerConfig.Era ~= nil and playerConfig.Era or Locale.Lookup("LOC_WORLDBUILDER_DEFAULT");
	playerEntry.Text   = string.format("%s - %s", playerConfig.IsHuman and Locale.Lookup("LOC_WORLDBUILDER_HUMAN") or Locale.Lookup("LOC_WORLDBUILDER_AI"), Locale.Lookup(playerConfig.Name));
	playerEntry.Gold   = playerConfig.Gold;
	playerEntry.Faith  = playerConfig.Faith;
	playerEntry.IsFullCiv = playerConfig.IsFullCiv;
	
	-- Update name
	if playerEntry.playerInstance.PlayerName ~= nil then
		playerEntry.playerInstance.PlayerName:SetText(playerEntry.Text);
	end

	-- Update button callback
	playerEntry.playerInstance.Button:RegisterCallback( Mouse.eLClick, function() OnPlayerSelected(playerEntry); end);

	-- Update icon if we're a specific civ
	if playerEntry.Civ ~= "UNDEFINED" and playerEntry.Civ ~= "RANDOM" and playerEntry.Civ ~= "RANDOM_POOL1" and playerEntry.Civ ~= "RANDOM_POOL2" then
		playerEntry.playerInstance.CivIcon:SetIcon("ICON_" .. playerConfig.Civ);

		local colorLeader : string = nil;
		for i, leader in ipairs(m_LeaderEntries) do
			if playerEntry.Civ == leader.CivType then
				colorLeader = leader.Type;
				break;
			end
		end

		local backColor : number;
		local frontColor : number;
		if colorLeader ~= nil then
			backColor, frontColor = UI.GetPlayerColorValues(colorLeader, 0);
		else
			backColor, frontColor = UI.GetPlayerColorValues(playerEntry.Leader, 0);
		end
		playerEntry.playerInstance.CivIcon:SetColor(frontColor);
		playerEntry.playerInstance.CivIconBacking:SetColor(backColor);

		local borderOverlay:object = UILens.GetOverlay("CultureBorders");
		if borderOverlay ~= nil then
			borderOverlay:SetBorderColors(playerEntry.Index, backColor, frontColor);
		end
	else
		playerEntry.playerInstance.CivIcon:SetColorByName("White");
		playerEntry.playerInstance.CivIconBacking:SetColorByName("White");
	end

	if playerEntry == m_SelectedPlayer then
		OnPlayerSelected(m_SelectedPlayer);
	end

	Controls.PlayerStack:CalculateSize();
	Controls.PlayerScrollPanel:CalculateSize();
	Controls.PlayerStack:ReprocessAnchoring();
end

-- ===========================================================================
function UpdatePlayerList()

	m_PlayerEntries = {};
	m_PlayerIndexToEntry = {};

	-- Clear out player instances
	m_playerInstanceIM:ResetInstances();

	local selected = 1;
	local entryCount = 0;

	for i = 0, GameDefines.MAX_PLAYERS-1 do 
		local eStatus = WorldBuilder.PlayerManager():GetSlotStatus(i); 
		if eStatus ~= SlotStatus.SS_CLOSED then
			local playerConfig = WorldBuilder.PlayerManager():GetPlayerConfig(i);
			if playerConfig.IsBarbarian == false then	-- Skipping the Barbarian player
				local playerEntry = {};
				playerEntry.Index = i;
				UpdatePlayerEntry(playerEntry);
				table.insert(m_PlayerEntries, playerEntry);
				m_PlayerIndexToEntry[i] = playerEntry;
				entryCount = entryCount + 1;

				if m_SelectedPlayer ~= nil and m_SelectedPlayer.Index == playerEntry.Index then
					selected = entryCount;
				end
			end
		end
	end

	if entryCount == 0 then
		selected = 0;
	end

	OnPlayerSelected( m_selectedPlayerEntry );
end

-- ===========================================================================
function GetSelectedCity()

	if m_SelectedPlayer ~= nil then
		if (m_ViewingTab.SelectedCityID ~= nil) then
			return WorldBuilder.CityManager():GetCity(m_SelectedPlayer.Index, m_ViewingTab.SelectedCityID);
		end			
	end

	return nil;
end

-- ===========================================================================
function UpdatePlayerCityList()

	m_CityEntries = {};

	if (m_SelectedPlayer ~= nil) then
	
		local pPlayer = Players[m_SelectedPlayer.Index];
		if (pPlayer ~= nil) then
			local pPlayerCities = pPlayer:GetCities();
			if (pPlayerCities ~= nil) then
				for iCity, pCity in pPlayerCities:Members() do
					table.insert(m_CityEntries, { Text=pCity:GetName(), Type=pCity:GetID() });
				end
			end
		end
	end

end

-- ===========================================================================
function CalculatePrimaryTabScrollArea()

	Controls.Stack:CalculateSize();
	Controls.Stack:ReprocessAnchoring();
	Controls.Scroll:CalculateSize();

end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewPlayerGeneralPage()	
	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	m_ViewingTab.Name = "General";
	m_ViewingTab.GeneralInstance = {};
	ContextPtr:BuildInstanceForControl( "PlayerGeneralInstance", m_ViewingTab.GeneralInstance, instance.Top ) ;	
	
	InitGeneralTab();
	UpdateGeneralTabValues();

	CalculatePrimaryTabScrollArea();
end

-- ===========================================================================
function InitGeneralTab()
	if m_ViewingTab.GeneralInstance then
		m_ViewingTab.GeneralInstance.CivPullDown:SetEntries( m_CivEntries, 1 );
		m_ViewingTab.GeneralInstance.CivPullDown:SetEntrySelectedCallback( OnCivSelected );

		m_ViewingTab.GeneralInstance.LeaderPullDown:SetEntries( m_LeaderEntries, 1 );
		m_ViewingTab.GeneralInstance.LeaderPullDown:SetEntrySelectedCallback( OnLeaderSelected );

		-- We never want the user to manually select the random leader entry
		for i, leaderEntry in ipairs(m_LeaderEntries) do
			if leaderEntry.Type == "RANDOM" or leaderEntry.Type == "RANDOM_POOL1" or leaderEntry.Type == "RANDOM_POOL2" then
				m_LeaderEntries[i].Button:SetDisabled(true);
				break;
			end
		end

		m_ViewingTab.GeneralInstance.CivLevelPullDown:SetEntries( m_CivLevelEntries, 1 );
		m_ViewingTab.GeneralInstance.CivLevelPullDown:SetEntrySelectedCallback( OnCivLevelSelected );

		m_ViewingTab.GeneralInstance.EraPullDown:SetEntries( m_EraEntries, 1 );
		m_ViewingTab.GeneralInstance.EraPullDown:SetEntrySelectedCallback( OnEraSelected );

		-- Gold/Faith
		m_ViewingTab.GeneralInstance.GoldEdit:RegisterStringChangedCallback( OnGoldEdited );
		m_ViewingTab.GeneralInstance.GoldEdit:SetNumberInput(true);
		m_ViewingTab.GeneralInstance.FaithEdit:RegisterStringChangedCallback( OnFaithEdited );
		m_ViewingTab.GeneralInstance.FaithEdit:SetNumberInput(true);
	end
end

-- ===========================================================================
function UpdateGeneralTabValues(entry:table)
	if m_ViewingTab.GeneralInstance then
		local playerSelected = m_SelectedPlayer ~= nil;
		local playerInitialized = false;
		if playerSelected then
			playerInitialized = WorldBuilder.PlayerManager():IsPlayerInitialized(m_SelectedPlayer.Index);
		end
		local bIsBarb : boolean = false;

		if m_SelectedPlayer ~= nil then
			if m_SelectedPlayer.Civ == "CIVILIZATION_BARBARIAN" then
				bIsBarb = true;
			end
		end

		m_ViewingTab.GeneralInstance.CivPullDown:SetDisabled( not playerSelected );
		m_ViewingTab.GeneralInstance.EraPullDown:SetDisabled( not playerSelected or not playerInitialized );
		m_ViewingTab.GeneralInstance.GoldEdit:SetDisabled( not playerSelected or not playerInitialized or bIsBarb);
		m_ViewingTab.GeneralInstance.FaithEdit:SetDisabled( not playerSelected or not playerInitialized or bIsBarb);
		m_ViewingTab.GeneralInstance.LeaderPullDown:SetDisabled( not playerSelected or not m_SelectedPlayer.IsFullCiv or m_SelectedPlayer.Civ == -1 );

		if m_SelectedPlayer ~= nil then
			m_ViewingTab.GeneralInstance.CivPullDown:SetSelectedIndex( GetCivEntryIndexByType( m_SelectedPlayer.Civ ), false );
			m_ViewingTab.GeneralInstance.LeaderPullDown:SetSelectedIndex( GetLeaderEntryIndexByType( m_SelectedPlayer.Leader ), false );
			m_ViewingTab.GeneralInstance.CivLevelPullDown:SetSelectedIndex( GetCivLevelEntryIndexByType( m_SelectedPlayer.CivLevel ), false );
			m_ViewingTab.GeneralInstance.EraPullDown:SetSelectedIndex( GetCivEraIndexByType( m_SelectedPlayer.Era ), false );

			local goldText = m_ViewingTab.GeneralInstance.GoldEdit:GetText();
			if goldText == nil or tonumber(goldText) ~= m_SelectedPlayer.Gold then
				m_ViewingTab.GeneralInstance.GoldEdit:SetText( m_SelectedPlayer.Gold );
			end

			local faithText = m_ViewingTab.GeneralInstance.FaithEdit:GetText();
			if faithText == nil or tonumber(faithText) ~= m_SelectedPlayer.Faith then
				m_ViewingTab.GeneralInstance.FaithEdit:SetText( m_SelectedPlayer.Faith );
			end
		end
	end
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewPlayerTechsPage()	
	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	m_ViewingTab.Name = "Techs";
	m_ViewingTab.TechInstance = {};
	ContextPtr:BuildInstanceForControl( "PlayerTechsInstance", m_ViewingTab.TechInstance, instance.Top ) ;	
	
	m_ViewingTab.TechInstance.TechList:SetEntries( m_TechEntries );
	m_ViewingTab.TechInstance.TechList:SetEntrySelectedCallback( OnTechSelected );
	UpdateTechTabValues();

	CalculatePrimaryTabScrollArea();
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewPlayerCivicsPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	m_ViewingTab.Name = "Civics";
	m_ViewingTab.CivicsInstance = {};
	ContextPtr:BuildInstanceForControl( "PlayerCivicsInstance", m_ViewingTab.CivicsInstance, instance.Top ) ;	
	
	m_ViewingTab.CivicsInstance.CivicsList:SetEntries( m_CivicEntries );
	m_ViewingTab.CivicsInstance.CivicsList:SetEntrySelectedCallback( OnCivicSelected );
	UpdateCivicsTabValues();

	CalculatePrimaryTabScrollArea();
end

-- ======================================================================================================================================================
-- City General Tab Functions
-- ======================================================================================================================================================

-- ===========================================================================
function OnCityPopulationEdited()

	if (m_ViewingTab ~= nil and m_ViewingTab.SubTab ~= nil and m_ViewingTab.SubTab.CityGeneralInstance ~= nil) then

		local pCity = GetSelectedCity();
		if (pCity ~= nil) then

			local text = m_ViewingTab.SubTab.CityGeneralInstance.PopulationEdit:GetText();
			if text ~= nil then
				local value = tonumber(text);
				local population = WorldBuilder.CityManager():GetCityValue(pCity, "Population");
				if (population == nil or value ~= population) then
					WorldBuilder.CityManager():SetCityValue(pCity, "Population", value);
				end
			end
		end

	end
end


-- ===========================================================================
function UpdatePlayerCityGeneralPage()

	if (m_ViewingTab ~= nil and m_ViewingTab.SubTab ~= nil and m_ViewingTab.SubTab.CityGeneralInstance ~= nil) then

		local pCity = GetSelectedCity();
		if (pCity ~= nil) then
			m_ViewingTab.SubTab.CityGeneralInstance.PopulationEdit:SetDisabled(false);
			local population = WorldBuilder.CityManager():GetCityValue(pCity, "Population");
			if (population ~= nil) then
				m_ViewingTab.SubTab.CityGeneralInstance.PopulationEdit:SetText(tostring(population));
			end

			-- Update city name header
			m_ViewingTab.SubTab.CityGeneralInstance.SelectedCityName:SetText(Locale.Lookup(pCity:GetName()));
		else
			m_ViewingTab.SubTab.CityGeneralInstance.PopulationEdit:SetDisabled(true);
		end
	end
end

-- ===========================================================================
function ViewPlayerCityGeneralPage()	

	ResetCitySubTabForNewPageContent();
	
	m_ViewingTab.SubTab.CityGeneralInstance = {};

	ContextPtr:BuildInstanceForControl( "CityGeneralInstance", m_ViewingTab.SubTab.CityGeneralInstance, m_ViewingTab.CitiesInstance.Stack ) ;	

	m_ViewingTab.SubTab.CityGeneralInstance.PopulationEdit:RegisterStringChangedCallback( OnCityPopulationEdited );
	m_ViewingTab.SubTab.CityGeneralInstance.PopulationEdit:SetNumberInput(true);

	UpdatePlayerCityGeneralPage();
	
end

-- ======================================================================================================================================================
-- City Districts Tab Functions
-- ======================================================================================================================================================

local ms_SelectDistrictType = nil;
local ms_SelectDistrictTypeHash = nil;

-- ===========================================================================
function UpdateSelectedDistrictInfo()

	local bEnable = false;

	if (m_ViewingTab ~= nil and m_ViewingTab.SubTab ~= nil and m_ViewingTab.SubTab.CityDistrictsInstance ~= nil) then

		if ms_SelectDistrictType ~= nil then
			if m_SelectedPlayer ~= nil then
				local pCity = GetSelectedCity();
				if pCity ~= nil then
					local pCityDistricts = pCity:GetDistricts();
					local pDistrict = pCityDistricts:GetDistrict(ms_SelectDistrictTypeHash);
					if pDistrict ~= nil then
						m_ViewingTab.SubTab.CityDistrictsInstance.PillagedCheckbox:SetSelected(pDistrict:IsPillaged());
--						m_ViewingTab.SubTab.CityDistrictsInstance.GarrisonDamageEdit:SetText( tostring( pDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON) ) );
--						m_ViewingTab.SubTab.CityDistrictsInstance.GarrisonDamageEdit:SetNumberInput(true);
--						m_ViewingTab.SubTab.CityDistrictsInstance.OuterDamageEdit:SetText( tostring( pDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER) ) );
--						m_ViewingTab.SubTab.CityDistrictsInstance.OuterDamageEdit:SetNumberInput(true);
						m_ViewingTab.SubTab.CityDistrictsInstance.SelectedDistrictName:SetText(Locale.Lookup(GameInfo.Districts[ms_SelectDistrictType].Name));
						bEnable = true;
					else
						m_ViewingTab.SubTab.CityDistrictsInstance.SelectedDistrictName:SetText("");
					end
				end
			end
		end

	end

	m_ViewingTab.SubTab.CityDistrictsInstance.PillagedCheckbox:SetEnabled(bEnable);
--	m_ViewingTab.SubTab.CityDistrictsInstance.GarrisonDamageEdit:SetEnabled(bEnable);
--	m_ViewingTab.SubTab.CityDistrictsInstance.OuterDamageEdit:SetEnabled(bEnable);
end
-- ===========================================================================
function OnDistrictSelected(entry)

	ms_SelectDistrictType = entry.Type.DistrictType;
	ms_SelectDistrictTypeHash = entry.Type.Hash;

	UpdateSelectedDistrictInfo();

end

-- ===========================================================================
function OnDistrictEntryButton(control, entry)

	if control:GetID() == "HasEntry" then
		local wantDistrict = control:IsChecked();

		if wantDistrict == true then
				
			-- Signal we want to go into placement mode.
			-- This is a deferred event because we are not in a good spot at this time.

			if (m_ViewingTab ~= nil and m_ViewingTab.SubTab ~= nil and m_ViewingTab.SubTab.CityDistrictsInstance ~= nil) then

				if m_SelectedPlayer ~= nil then
					local pCity = GetSelectedCity();
					if pCity ~= nil then

						local kParams = {};

						kParams.DistrictType = entry.Type.Hash;
						kParams.PlayerID = m_SelectedPlayer.Index;
						kParams.CityID = pCity:GetID();

						LuaEvents.WorldBuilderModeChangeRequest(WorldBuilderModes.PLACE_DISTRICTS, kParams);
					else
						LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CITY_NEEDED"));
					end
				end
			end
		end
	end

end

-- ===========================================================================
function UpdatePlayerCityDistrictsPage()

	if (m_ViewingTab ~= nil and m_ViewingTab.SubTab ~= nil and m_ViewingTab.SubTab.CityDistrictsInstance ~= nil) then
	
		local pCity = GetSelectedCity();
		local pCityDistricts = nil;

		-- Update city name header
		local cityNameText = Locale.Lookup(pCity:GetName()) .. " " .. Locale.Lookup("LOC_WORLDBUILDER_TAB_DISTRICTS");
		m_ViewingTab.SubTab.CityDistrictsInstance.SelectedCityName:SetText(cityNameText);

		if (pCity ~= nil) then
			pCityDistricts = pCity:GetDistricts();
		end

		for i, entry in ipairs(m_DistrictEntries) do
			local hasDistrict = pCityDistricts ~= nil and pCityDistricts:HasDistrict( entry.Type.Index );
			local controlEntry = m_ViewingTab.SubTab.CityDistrictsInstance.DistrictsList:GetIndexedEntry( i );
			if controlEntry ~= nil and controlEntry.Root ~= nil then
				if controlEntry.Root.HasEntry ~= nil then
					controlEntry.Root.HasEntry:SetCheck(hasDistrict);
				end
			end
		end

		UpdateSelectedDistrictInfo();

	end

end

-- ===========================================================================
function ViewPlayerCityDistrictsPage()	

	ResetCitySubTabForNewPageContent();

	m_ViewingTab.SubTab.CityDistrictsInstance = {};

	ContextPtr:BuildInstanceForControl( "CityDistrictsInstance", m_ViewingTab.SubTab.CityDistrictsInstance, m_ViewingTab.CitiesInstance.Stack ) ;	
	m_ViewingTab.SubTab.CityDistrictsInstance.DistrictsList:SetEntries( m_DistrictEntries, 0 );
	m_ViewingTab.SubTab.CityDistrictsInstance.DistrictsList:SetEntrySelectedCallback( OnDistrictSelected );
	m_ViewingTab.SubTab.CityDistrictsInstance.DistrictsList:SetEntrySubButtonClickedCallback( OnDistrictEntryButton );
	
	ms_SelectDistrictType = nil;
	ms_SelectDistrictTypeHash = nil;

	UpdatePlayerCityDistrictsPage();
end


-- ======================================================================================================================================================
-- City Buildings Tab Functions
-- ======================================================================================================================================================

local ms_SelectBuildingType = nil;
local ms_SelectBuildingTypeHash = nil;

-- ===========================================================================
function UpdateSelectedBuildingInfo()

	local bEnable = false;

	if (m_ViewingTab ~= nil and m_ViewingTab.SubTab ~= nil and m_ViewingTab.SubTab.CityBuildingsInstance ~= nil) then

		if ms_SelectBuildingType ~= nil then
			if m_SelectedPlayer ~= nil then
				local pCity = GetSelectedCity();
				if pCity ~= nil then
					local pCityBuildings = pCity:GetBuildings();
					if pCityBuildings ~= nil then
						
						if pCityBuildings:HasBuilding(ms_SelectBuildingTypeHash) == true then
							m_ViewingTab.SubTab.CityBuildingsInstance.PillagedCheckbox:SetSelected(pCityBuildings:IsPillaged(ms_SelectBuildingTypeHash));
							m_ViewingTab.SubTab.CityBuildingsInstance.SelectedBuildingName:SetText(Locale.Lookup(GameInfo.Buildings[ms_SelectBuildingType].Name));
							bEnable = true;
						else
							m_ViewingTab.SubTab.CityBuildingsInstance.SelectedBuildingName:SetText("");
						end
					end
				end
			end
		end

	end

	m_ViewingTab.SubTab.CityBuildingsInstance.PillagedCheckbox:SetEnabled(bEnable);
end

-- ===========================================================================
function OnBuildingSelected(entry, selected)

	ms_SelectBuildingType = entry.Type.BuildingType;
	ms_SelectBuildingTypeHash = entry.Type.Hash;

	UpdateSelectedBuildingInfo();

end

-- ===========================================================================
function OnBuildingEntryButton(control, entry)

	if control:GetID() == "HasEntry" then
		local hasBuilding = control:IsChecked();

		if hasBuilding == true then
				
			if (entry.Type.RequiresPlacement == true) then
				-- Building requires placement, go into that mode.
				-- This is a deferred event because we are not in a good spot at this time.
				if m_SelectedPlayer ~= nil then
					local pCity = GetSelectedCity();
					if pCity ~= nil then

						local kParams = {};

						kParams.BuildingType = entry.Type.Hash;
						kParams.PlayerID = m_SelectedPlayer.Index;
						kParams.CityID = pCity:GetID();

						LuaEvents.WorldBuilderModeChangeRequest(WorldBuilderModes.PLACE_BUILDINGS, kParams);
					end
				end

			else
				-- Just create it, it will go in its district.
                local pCity = GetSelectedCity();
                if pCity ~= nil then
					bStatus, sStatus = WorldBuilder.CityManager():CreateBuilding(pCity, entry.Type.BuildingType, 100);
					PlacementSetResults(bStatus, sStatus, entry.Text);
					if not bStatus then
						 -- Failed.  Uncheck the box
                        control:SetCheck(false);
					end
				else
					LuaEvents.WorldBuilder_SetPlacementStatus(Locale.Lookup("LOC_WORLDBUILDER_CITY_NEEDED"));
				end
			end

		end
	end
end

-- ===========================================================================
function UpdatePlayerCityBuildingsPage()

	if (m_ViewingTab ~= nil and m_ViewingTab.SubTab ~= nil and m_ViewingTab.SubTab.CityBuildingsInstance ~= nil) then
	
		local pCity = GetSelectedCity();
		local pCityBuildings = nil;
		if (pCity ~= nil) then
			pCityBuildings = pCity:GetBuildings();
		end

		-- Update city name header
		local cityNameText = Locale.Lookup(pCity:GetName()) .. " " .. Locale.Lookup("LOC_WORLDBUILDER_TAB_BUILDINGS");
		m_ViewingTab.SubTab.CityBuildingsInstance.SelectedCityName:SetText(cityNameText);

		for i, entry in ipairs(m_BuildingEntries) do
			local hasBuilding = pCityBuildings ~= nil and pCityBuildings:HasBuilding( entry.Type.Index );

			local controlEntry = m_ViewingTab.SubTab.CityBuildingsInstance.BuildingsList:GetIndexedEntry( i );
			if controlEntry ~= nil and controlEntry.Root ~= nil then
				if controlEntry.Root.HasEntry ~= nil then
					controlEntry.Root.HasEntry:SetCheck(hasBuilding);
				end
			end

		end
	end

end

-- ===========================================================================
function ViewPlayerCityBuildingsPage()	

	ResetCitySubTabForNewPageContent();
	
	m_ViewingTab.SubTab.CityBuildingsInstance = {};

	ContextPtr:BuildInstanceForControl( "CityBuildingsInstance", m_ViewingTab.SubTab.CityBuildingsInstance, m_ViewingTab.CitiesInstance.Stack ) ;	
	m_ViewingTab.SubTab.CityBuildingsInstance.BuildingsList:SetEntries( m_BuildingEntries, 0 );
	m_ViewingTab.SubTab.CityBuildingsInstance.BuildingsList:SetEntrySelectedCallback( OnBuildingSelected );
	m_ViewingTab.SubTab.CityBuildingsInstance.BuildingsList:SetEntrySubButtonClickedCallback( OnBuildingEntryButton );

	ms_SelectBuildingType = nil;
	ms_SelectBuildingTypeHash = nil;

	UpdatePlayerCityBuildingsPage();
end

-- ======================================================================================================================================================
-- City Tab Functions
-- ======================================================================================================================================================

-- ===========================================================================
function ResetCitySubTabForNewPageContent()

	if (m_ViewingTab ~= nil) then
		m_ViewingTab.SubTab = {};

		if (m_ViewingTab.CitiesInstance ~= nil and m_ViewingTab.CitiesInstance.Stack ~= nil) then
			m_ViewingTab.CitiesInstance.Stack:DestroyAllChildren();
		end
	end

end

-- ===========================================================================
function OnSelectedCityChanged()
	if (m_ViewingTab ~= nil) then
		if (m_ViewingTab.SubTab ~= nil) then
			if (m_ViewingTab.SubTab.CityGeneralInstance ~= nil) then
				UpdatePlayerCityGeneralPage();
			elseif (m_ViewingTab.SubTab.CityDistrictsInstance ~= nil) then
				UpdatePlayerCityDistrictsPage();
			elseif (m_ViewingTab.SubTab.CityBuildingsInstance ~= nil) then
				UpdatePlayerCityBuildingsPage();			
			end
		else
			-- Not viewing any sub-tab.  Are we viewing the Cities tab?
			if (m_ViewingTab.Name == "Cities") then
				-- Show the General sub-tab.
				m_ViewingTab.m_subTabs.SelectTab(1);
			end
		end
	end
end


-- ===========================================================================
function OnNewCity()
	if (m_ViewingTab ~= nil) then

		if (m_SelectedPlayer ~= nil) then
			-- Go into city placement mode
			local kParams = {};

			kParams.PlayerID = m_SelectedPlayer.Index;
			LuaEvents.WorldBuilderModeChangeRequest(WorldBuilderModes.PLACE_CITIES, kParams);
		end
	end

end

-- ===========================================================================
function OnRemoveCity()
	if (m_ViewingTab ~= nil) then

		if (m_SelectedPlayer ~= nil) then
			local pCity = GetSelectedCity();
			if (pCity ~= nil) then
				WorldBuilder.CityManager():Remove(pCity);
			end
		end
	end

end

-- ===========================================================================
function OnCityListChange_CitiesPage()
	if m_ViewingTab ~= nil then
		if m_ViewingTab.Name == "Cities" then	

			m_ViewingTab.SelectedCityID = nil;
			m_ViewingTab.CitiesInstance.CityList:SetEntries( m_CityEntries, 0 );
			if m_ViewingTab.CitiesInstance.CityList:HasEntries() then
				m_ViewingTab.CitiesInstance.CityList:SetSelectedIndex( 1, true );
			end

			m_ViewingTab.CitiesInstance.Stack:CalculateSize();
			m_ViewingTab.CitiesInstance.Scroll:CalculateSize();

			OnSelectedCityChanged();
		end
	end
end
-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewPlayerCitiesPage()	

	ResetTabForNewPageContent();

	if (m_SelectedPlayer ~= nil) then
	
		local instance:table = m_simpleIM:GetInstance();	
		instance.Top:DestroyAllChildren();

		m_ViewingTab.Name = "Cities";
		m_ViewingTab.CitiesInstance = {};
		m_ViewingTab.SelectedCityID = nil;
		ContextPtr:BuildInstanceForControl( "CityMainInstance", m_ViewingTab.CitiesInstance, instance.Top ) ;	

		UpdatePlayerCityList();
	
		m_ViewingTab.CitiesInstance.CityList:SetEntrySelectedCallback( OnCitySelected );
		m_ViewingTab.CitiesInstance.CityList:SetEntries( m_CityEntries, 0 );
	
		m_ViewingTab.m_subTabs = CreateTabs( m_ViewingTab.CitiesInstance.TabContainer, 42, 34, UI.GetColorValueFromHexLiteral(0xFF331D05) );
		AddTabSection( m_ViewingTab.m_subTabs, "LOC_WORLDBUILDER_TAB_GENERAL",		ViewPlayerCityGeneralPage, m_ViewingTab.CitiesInstance.TabContainer );
		AddTabSection( m_ViewingTab.m_subTabs, "LOC_WORLDBUILDER_TAB_DISTRICTS",	ViewPlayerCityDistrictsPage, m_ViewingTab.CitiesInstance.TabContainer );
		AddTabSection( m_ViewingTab.m_subTabs, "LOC_WORLDBUILDER_TAB_BUILDINGS",	ViewPlayerCityBuildingsPage, m_ViewingTab.CitiesInstance.TabContainer );
		SetTabsDisabled( m_ViewingTab.m_subTabs, true );

		m_ViewingTab.m_subTabs.CenterAlignTabs(-10);		

		m_ViewingTab.CitiesInstance.Stack:CalculateSize();
		m_ViewingTab.CitiesInstance.Scroll:CalculateSize();

		m_ViewingTab.CitiesInstance.NewCityButton:RegisterCallback( Mouse.eLClick, OnNewCity );
		m_ViewingTab.CitiesInstance.RemoveCityButton:RegisterCallback( Mouse.eLClick, OnRemoveCity );

		local xOffset, yOffset = m_ViewingTab.CitiesInstance.Scroll:GetParentRelativeOffset();
		m_ViewingTab.CitiesInstance.Scroll:SetSizeY( Controls.TabsContainer:GetSizeY() - yOffset );

		CalculatePrimaryTabScrollArea();

		if m_ViewingTab.CitiesInstance.CityList:HasEntries() then
			m_ViewingTab.CitiesInstance.CityList:SetSelectedIndex( 1, true );
		end
	end
end

-- ===========================================================================
function OnShow()

	UpdatePlayerList();
end

-- ===========================================================================
function OnLoadGameViewStateDone()

	if not ContextPtr:IsHidden() then
		OnShow();
	end 

end

-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE and not ContextPtr:IsHidden() then
		ContextPtr:SetHide(true);
		LuaEvents.WorldBuilder_ShowPlayerEditor(false);
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
function OnClose()
	ContextPtr:SetHide(true);
	LuaEvents.WorldBuilder_ShowPlayerEditor(false);
end

-- ===========================================================================
function OnPlayerAdded()
	
	UpdatePlayerList();
end

-- ===========================================================================
function OnPlayerRemoved(index)

	UpdatePlayerList();
end

-- ===========================================================================
function OnPlayerEdited(index)
	local playerEntry = m_PlayerIndexToEntry[index];
	if playerEntry ~= nil then
		for plotIndex = 0, Map.GetPlotCount()-1, 1 do
			local plot = Map.GetPlotByIndex(plotIndex);
			local owner = plot:GetOwner();

			WorldBuilder.UnitManager():RemoveAt(plot);

			if owner ~= nil and owner == playerEntry.Index then
				WorldBuilder.MapManager():SetImprovementType( plot, -1 );
				WorldBuilder.CityManager():RemoveAt(plot);
			end
		end

		UpdatePlayerEntry(playerEntry);
		UI.RefreshColorSet();
		UI.RebuildColorDB();
	end
end

-- ===========================================================================
function OnPlayerTechEdited(player, tech, progress)

	if (m_ViewingTab.TechInstance ~= nil and m_ViewingTab.TechInstance.TechList ~= nil) then
		if m_SelectedPlayer ~= nil and m_SelectedPlayer.Index == player then
			for i,techEntry in ipairs(m_TechEntries) do
				if techEntry.Type.Index == tech then
					local hasTech = WorldBuilder.PlayerManager():PlayerHasTech( player, tech );
					m_ViewingTab.TechInstance.TechList:SetEntrySelected( techEntry, hasTech, false );
					break;
				end
			end
		end
	end
end

-- ===========================================================================
function OnPlayerCivicEdited(player, civic, progress)

	if (m_ViewingTab.CivicsInstance ~= nil and m_ViewingTab.CivicsInstance.CivicsList ~= nil) then
		if m_SelectedPlayer ~= nil and m_SelectedPlayer.Index == player then
			for i,civicEntry in ipairs(m_CivicEntries) do
				if civicEntry.Type.Index == civic then
					local hasCivic = WorldBuilder.PlayerManager():PlayerHasCivic( player, civic );
					m_ViewingTab.CivicsInstance.CivicsList:SetEntrySelected( civicEntry, hasCivic, false );
					break;
				end
			end
		end
	end
end

-- ===========================================================================
function OnAddPlayer()

	local player = WorldBuilder.PlayerManager():AddPlayer(false);
	if player ~= -1 then
		OnPlayerSelected(m_PlayerIndexToEntry[player]);
	end
end

-- ===========================================================================
function OnAddAIPlayer()

	local player = WorldBuilder.PlayerManager():AddPlayer(true);
	if player ~= -1 then
		OnPlayerSelected(m_PlayerIndexToEntry[player]);
	end
end

-- ===========================================================================
function OnRemovePlayer()

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():UninitializePlayer(m_SelectedPlayer.Index);
	end
end

-- ===========================================================================
function OnCivSelected(entry)

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():SetPlayerLeader(m_SelectedPlayer.Index, entry.DefaultLeader, entry.Type, m_SelectedPlayer.CivLevel);
	end
end

-- ===========================================================================
function OnLeaderSelected(entry)

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():SetPlayerLeader(m_SelectedPlayer.Index, entry.Type, m_SelectedPlayer.Civ, m_SelectedPlayer.CivLevel);
	end
end

-- ===========================================================================
function OnCivLevelSelected(entry)

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():SetPlayerLeader(m_SelectedPlayer.Index, m_SelectedPlayer.Leader, m_SelectedPlayer.Civ, entry.Type);
	end
end

-- ===========================================================================
function OnEraSelected(entry)

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():SetPlayerEra(m_SelectedPlayer.Index, entry.Type);
	end
end

-- ===========================================================================
function OnTechSelected(entry, selected)

	if m_SelectedPlayer ~= nil then
		local progress = selected and 100 or -1;
		WorldBuilder.PlayerManager():SetPlayerHasTech(m_SelectedPlayer.Index, entry.Type.Index, progress);
	end
end

-- ===========================================================================
function OnCivicSelected(entry, selected)

	if m_SelectedPlayer ~= nil then
		local progress = selected and 100 or -1;
		WorldBuilder.PlayerManager():SetPlayerHasCivic(m_SelectedPlayer.Index, entry.Type.Index, progress);
	end
end

-- ===========================================================================
function OnGoldEdited()
	if m_ViewingTab.GeneralInstance and m_ViewingTab.GeneralInstance.GoldEdit then
		local text = m_ViewingTab.GeneralInstance.GoldEdit:GetText();
		if m_SelectedPlayer ~= nil and text ~= nil then
			local gold = tonumber(text);
			if gold ~= m_SelectedPlayer.Gold then
				WorldBuilder.PlayerManager():SetPlayerGold(m_SelectedPlayer.Index, gold);
			end
		end
	end
end

-- ===========================================================================
function OnFaithEdited()
	if m_ViewingTab.GeneralInstance and m_ViewingTab.GeneralInstance.FaithEdit then
		local text = m_ViewingTab.GeneralInstance.FaithEdit:GetText();
		if m_SelectedPlayer ~= nil and text ~= nil then
			local faith = tonumber(text);
			if faith ~= m_SelectedPlayer.Faith then
				WorldBuilder.PlayerManager():SetPlayerFaith(m_SelectedPlayer.Index, faith);
			end
		end
	end
end

-- ===========================================================================
function OnCitySelected(entry)

	if m_SelectedPlayer ~= nil then
		m_ViewingTab.SelectedCityID = entry.Type;
		SetTabsDisabled( m_ViewingTab.m_subTabs, false );
	else
		m_ViewingTab.SelectedCityID = nil;
		SetTabsDisabled( m_ViewingTab.m_subTabs, true );
	end

	OnSelectedCityChanged();
end

-- ===========================================================================
function OnShowPlayerEditor(bShow)
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
function OnShowMapEditor(bShow)
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function OnCityAddedToMap()
	if ContextPtr:IsVisible() then
		UpdatePlayerCityList();
		OnCityListChange_CitiesPage();
	end
end

-- ===========================================================================
function OnCityRemovedFromMap()
	if ContextPtr:IsVisible() then
		UpdatePlayerCityList();
		OnCityListChange_CitiesPage();
	end
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.WorldBuilder_PlayerAddedRemove( OnPlayerAdded );
	LuaEvents.WorldBuilder_PlayerRemovedRemove( OnPlayerRemoved );
	LuaEvents.WorldBuilder_PlayerEditedRemove( OnPlayerEdited );
	LuaEvents.WorldBuilder_PlayerTechEditedRemove( OnPlayerTechEdited );
	LuaEvents.WorldBuilder_PlayerCivicEditedRemove( OnPlayerCivicEdited );
	LuaEvents.WorldBuilder_ShowPlayerEditorRemove( OnShowPlayerEditor );
	LuaEvents.WorldBuilder_ShowMapEditorRemove( OnShowMapEditor );

	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "IsVisible", ContextPtr:IsVisible());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "SelectedPlayer", m_SelectedPlayer);

	if ContextPtr:IsVisible() then
		Input.PopContext();
	end
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	-- Title
	Controls.ModalScreenTitle:SetText( Locale.ToUpper(Locale.Lookup("LOC_WORLD_BUILDER_PLAYER_EDITOR_TT")) );

	ContextPtr:SetInputHandler( OnInputHandler, true );

	-- EraPullDown
	table.insert(m_EraEntries, { Text="LOC_WORLDBUILDER_DEFAULT", Type="DEFAULT" });
	for type in GameInfo.Eras() do
		table.insert(m_EraEntries, { Text=type.Name, Type=type.EraType });
	end

	-- CivLevelPullDown
	for type in GameInfo.CivilizationLevels() do
		local name = type.Name ~= nil and type.Name or type.CivilizationLevelType;
		table.insert(m_CivLevelEntries, { Text="LOC_WORLDBUILDER_"..name, Type=type.CivilizationLevelType });
	end

	-- CivPullDown
	
	-- Intialize the m_CivEntries table.  This must use a simple index for the key, the pull down control will access it directly.
	-- The first two entries are special
	-- Fill in the civs
	for type in GameInfo.Civilizations() do
		table.insert(m_CivEntries, { Text=type.Name, Type=type.CivilizationType, DefaultLeader=-1 });
	end
	table.sort(m_CivEntries, function(a, b)
		return Locale.Lookup(a.Text) < Locale.Lookup(b.Text);
	end );
	table.insert(m_CivEntries, 1, { Text="LOC_WORLDBUILDER_RANDOM", Type="RANDOM", DefaultLeader="RANDOM" });
	table.insert(m_CivEntries, 2, { Text="LOC_WORLDBUILDER_ANY", Type="UNDEFINED", DefaultLeader="UNDEFINED" });


	-- Set default leaders
	for entry in GameInfo.CivilizationLeaders() do
		local civ = GameInfo.Civilizations[entry.CivilizationType];
		if civ ~= nil then
			SetCivDefaultLeader(entry);
		end
	end

	-- LeaderPullDown
	for type in GameInfo.Leaders() do
		if type.Name ~= "LOC_EMPTY" then
			if type.CivilizationCollection[1] ~= nil then
				table.insert(m_LeaderEntries, { Text=type.Name, Type=type.LeaderType, CivType=type.CivilizationCollection[1].CivilizationType });
			else
				table.insert(m_LeaderEntries, { Text=type.Name, Type=type.LeaderType, CivType=nil });
			end
		end
	end
	table.sort(m_LeaderEntries, function(a, b)
		return Locale.Lookup(a.Text) < Locale.Lookup(b.Text);
	end );
	table.insert(m_LeaderEntries, 1, { Text="LOC_WORLDBUILDER_RANDOM", Type="RANDOM" });
	table.insert(m_LeaderEntries, 2, { Text="LOC_WORLDBUILDER_ANY", Type="UNDEFINED" });

	-- TechList
	for type in GameInfo.Technologies() do
		table.insert(m_TechEntries, { Text=type.Name, Type=type });
	end
	table.sort(m_TechEntries, function(a, b)
		  return Locale.Lookup(a.Text) < Locale.Lookup(b.Text);
	end );

	-- CivicsList
	for type in GameInfo.Civics() do
		table.insert(m_CivicEntries, { Text=type.Name, Type=type });
	end
	table.sort(m_CivicEntries, function(a, b)
		  return Locale.Lookup(a.Text) < Locale.Lookup(b.Text);
	end );

	-- District list
	for type in GameInfo.Districts() do
		if type.DistrictType ~= "DISTRICT_WONDER" then
			table.insert(m_DistrictEntries, { Text=type.Name, Type=type });
		end
	end
	table.sort(m_DistrictEntries, function(a, b)
		return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );

	-- Building list
	for type in GameInfo.Buildings() do
		if type.RequiresPlacement ~= true then
			if type.InternalOnly == nil or type.InternalOnly == false then
				table.insert(m_BuildingEntries, { Text=type.Name, Type=type });
			end
		end
	end
	table.sort(m_BuildingEntries, function(a, b)
		return Locale.Lookup(a.Type.Name) < Locale.Lookup(b.Type.Name);
	end );

	m_tabs = CreateTabs( Controls.TabContainer, 42, 34, UI.GetColorValueFromHexLiteral(0xFF331D05) );
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_GENERAL",		ViewPlayerGeneralPage, Controls.TabContainer );
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_TECHS",		ViewPlayerTechsPage, Controls.TabContainer );
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_CIVICS",		ViewPlayerCivicsPage, Controls.TabContainer );
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_CITIES",		ViewPlayerCitiesPage, Controls.TabContainer );
	SetTabsDisabled(m_tabs, true);

	m_tabs.CenterAlignTabs(-10);		

	-- Add/Remove Players
	Controls.NewPlayerButton:RegisterCallback( Mouse.eLClick, OnAddPlayer );
	Controls.NewAIPlayerButton:RegisterCallback( Mouse.eLClick, OnAddAIPlayer );
	Controls.RemovePlayerButton:RegisterCallback( Mouse.eLClick, OnRemovePlayer );

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetShutdown( OnShutdown );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );
	Events.CityAddedToMap.Add( OnCityAddedToMap );
	Events.CityRemovedFromMap.Add( OnCityRemovedFromMap );
	Controls.ModalScreenClose:RegisterCallback( Mouse.eLClick, OnClose );
	LuaEvents.WorldBuilder_PlayerAdded.Add( OnPlayerAdded );
	LuaEvents.WorldBuilder_PlayerRemoved.Add( OnPlayerRemoved );
	LuaEvents.WorldBuilder_PlayerEdited.Add( OnPlayerEdited );
	LuaEvents.WorldBuilder_PlayerTechEdited.Add( OnPlayerTechEdited );
	LuaEvents.WorldBuilder_PlayerCivicEdited.Add( OnPlayerCivicEdited );
	LuaEvents.WorldBuilder_ShowPlayerEditor.Add( OnShowPlayerEditor );
	LuaEvents.WorldBuilder_ShowMapEditor.Add( OnShowMapEditor );
end
ContextPtr:SetInitHandler( OnInit );