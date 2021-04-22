-- Copyright 2014-2019, Firaxis Games.

--	Hotloading note: The World Tracker button check now positions based on how many hooks are showing.  
--	You'll need to save "LaunchBar" to see the tracker button appear.

include("InstanceManager");
include("TechAndCivicSupport");
include("SupportFunctions");
include("GameCapabilities");

g_TrackedItems = {};		-- Populated by WorldTrackerItems_* scripts;
include("WorldTrackerItem_", true);

-- Include self contained additional tabs
g_ExtraIconData = {};
include("CivicsTreeIconLoader_", true);


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID					:string = "WorldTracker"; -- Must be unique (usually the same as the file name)
local CHAT_COLLAPSED_SIZE				:number = 118;
local CIVIC_RESEARCH_MIN_SIZE			:number = 96;
local MAX_BEFORE_TRUNC_TRACKER			:number = 180;
local MAX_BEFORE_TRUNC_CHECK			:number = 160;
local MAX_BEFORE_TRUNC_TITLE			:number = 225;
local LAUNCH_BAR_PADDING				:number = 50;
local STARTING_TRACKER_OPTIONS_OFFSET	:number = 75;
local WORLD_TRACKER_PANEL_WIDTH			:number = 300;
local MINIMAP_PADDING					:number = 40;

local UNITS_PANEL_MIN_HEIGHT			:number = 85;
local UNITS_PANEL_PADDING				:number = 65;
local TOPBAR_PADDING					:number = 100;

local WORLD_TRACKER_TOP_PADDING			:number = 200;


-- ===========================================================================
--	GLOBALS
-- ===========================================================================
g_TrackedInstances	= {};				-- Any instances created as a result of g_trackedItems

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_hideAll					:boolean = false;
local m_hideChat				:boolean = false;
local m_hideCivics				:boolean = false;
local m_hideResearch			:boolean = false;
local m_hideUnitList			:boolean = true;

local m_dropdownExpanded		:boolean = false;
local m_unreadChatMsgs			:number  = 0;		-- number of chat messages unseen due to the chat panel being hidden.

local m_researchInstance		:table	 = {};		-- Single instance wired up for the currently being researched tech
local m_civicsInstance			:table	 = {};		-- Single instance wired up for the currently being researched civic
local m_unitListInstance		:table	 = {};

local m_unitEntryIM				:table	 = {};

local m_CachedModifiers			:table	 = {};

local m_currentResearchID		:number = -1;
local m_lastResearchCompletedID	:number = -1;
local m_currentCivicID			:number = -1;
local m_lastCivicCompletedID	:number = -1;
local m_minimapSize				:number = 199;
local m_isTrackerAlwaysCollapsed:boolean = false;	-- Once the launch bar extends past the width of the world tracker, we always show the collapsed version of the backing for the tracker element
local m_isDirty					:boolean = false;	-- Note: renamed from "refresh" which is a built in Forge mechanism; this is based on a gamecore event to check not frame update
local m_isMinimapCollapsed		:boolean = false;
local m_startingChatSize		:number = 0;

local m_unitSearchString		:string = "";
local m_remainingRoom			:number = 0;
local m_isUnitListSizeDirty		:boolean = false;
local m_isMinimapInitialized	:boolean = false;

local m_uiCheckBoxes			:table = {Controls.ChatCheck, Controls.CivicsCheck, Controls.ResearchCheck, Controls.UnitCheck};

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--	The following are a accessors for Expansions/MODs so they can obtain status
--	of the common panels but don't have access to toggling them.
-- ===========================================================================
function IsChatHidden()			return m_hideChat;		end
function IsResearchHidden()		return m_hideResearch;	end
function IsCivicsHidden()		return m_hideCivics;	end
function IsUnitListHidden()		return m_hideUnitList;	end

-- ===========================================================================
--	Checks all panels, static and dynamic as to whether or not they are hidden.
--	Returns true if they are. 
-- ===========================================================================
function IsAllPanelsHidden()
	local isHide	:boolean = false;
	local uiChildren:table = Controls.PanelStack:GetChildren();
	for i,uiChild in ipairs(uiChildren) do			
		if uiChild:IsVisible() then
			return false;
		end
	end
	return true;
end

-- ===========================================================================
function RealizeEmptyMessage()	
	-- First a quick check if all native panels are hidden.
	if m_hideChat and m_hideCivics and m_hideResearch and m_hideUnitList then		
		local isAllPanelsHidden:boolean = IsAllPanelsHidden();	-- more expensive iteration
		Controls.EmptyPanel:SetHide( isAllPanelsHidden==false );	
	else
		Controls.EmptyPanel:SetHide(true);
	end
end

-- ===========================================================================
function ToggleDropdown()
	if m_dropdownExpanded then
		m_dropdownExpanded = false;
		Controls.DropdownAnim:Reverse();
		Controls.DropdownAnim:Play();
		UI.PlaySound("Tech_Tray_Slide_Closed");
	else
		UI.PlaySound("Tech_Tray_Slide_Open");
		m_dropdownExpanded = true;
		Controls.DropdownAnim:SetToBeginning();
		Controls.DropdownAnim:Play();
		CheckEnoughRoom();
	end
end

-- ===========================================================================
function CheckEnoughRoom()
	local availableSpace : number = Controls.WorldTrackerVerticalContainer:GetSizeY();
	if(m_researchInstance.MainPanel:IsVisible())then
		availableSpace = availableSpace - CIVIC_RESEARCH_MIN_SIZE;
	end
	if(m_civicsInstance.MainPanel:IsVisible())then
		availableSpace = availableSpace - CIVIC_RESEARCH_MIN_SIZE;
	end
	if(m_unitListInstance.UnitListMainPanel:IsVisible())then
		availableSpace = availableSpace - CIVIC_RESEARCH_MIN_SIZE;
	end
	if(Controls.ChatPanelContainer:IsVisible())then
		availableSpace = availableSpace - CHAT_COLLAPSED_SIZE;
	end
	if(Controls.OtherContainer:IsVisible())then
		availableSpace = availableSpace - Controls.OtherContainer:GetSizeY();
	end

	if(not Controls.ResearchCheck:IsChecked() and availableSpace < CIVIC_RESEARCH_MIN_SIZE)then
		Controls.ResearchCheck:SetDisabled(true);
		Controls.ResearchCheck:LocalizeAndSetToolTip("LOC_WORLDTRACKER_NO_ROOM");
	else
		Controls.ResearchCheck:SetDisabled(false);
		Controls.ResearchCheck:SetToolTipString("");
	end
	if(not Controls.CivicsCheck:IsChecked() and availableSpace < CIVIC_RESEARCH_MIN_SIZE)then
		Controls.CivicsCheck:SetDisabled(true);
		Controls.CivicsCheck:LocalizeAndSetToolTip("LOC_WORLDTRACKER_NO_ROOM");
	else
		Controls.CivicsCheck:SetDisabled(false);
		Controls.CivicsCheck:SetToolTipString("");
	end
	if(not Controls.UnitCheck:IsChecked() and availableSpace < UNITS_PANEL_MIN_HEIGHT)then
		Controls.UnitCheck:SetDisabled(true);
		Controls.UnitCheck:LocalizeAndSetToolTip("LOC_WORLDTRACKER_NO_ROOM");
	else
		Controls.UnitCheck:SetDisabled(false);
		Controls.UnitCheck:SetToolTipString("");
	end
	if(not Controls.ChatCheck:IsChecked() and availableSpace < CHAT_COLLAPSED_SIZE)then
		Controls.ChatCheck:SetDisabled(true);
		Controls.ChatCheck:LocalizeAndSetToolTip("LOC_WORLDTRACKER_NO_ROOM");
	else
		Controls.ChatCheck:SetDisabled(false);
		Controls.ChatCheck:SetToolTipString("");
	end
end

-- ===========================================================================
function ToggleAll(hideAll:boolean)

	-- Do nothing if value didn't change
	if m_hideAll == hideAll then return; end

	m_hideAll = hideAll;
	
	if(not hideAll) then
		Controls.PanelStack:SetHide(false);
		UI.PlaySound("Tech_Tray_Slide_Open");
	end

	Controls.ToggleAllButton:SetCheck(not m_hideAll);

	if ( not m_isTrackerAlwaysCollapsed) then
		Controls.TrackerHeading:SetHide(hideAll);
		Controls.TrackerHeadingCollapsed:SetHide(not hideAll);
	else
		Controls.TrackerHeading:SetHide(true);
		Controls.TrackerHeadingCollapsed:SetHide(false);
	end

	if( hideAll ) then
		UI.PlaySound("Tech_Tray_Slide_Closed");
		if( m_dropdownExpanded ) then
			Controls.DropdownAnim:SetToBeginning();
			m_dropdownExpanded = false;
		end
	end

	Controls.WorldTrackerAlpha:Reverse();
	Controls.WorldTrackerSlide:Reverse();
	CheckUnreadChatMessageCount();

	LuaEvents.WorldTracker_ToggleCivicPanel(m_hideCivics or m_hideAll);
	LuaEvents.WorldTracker_ToggleResearchPanel(m_hideResearch or m_hideAll);
end

-- ===========================================================================
function OnWorldTrackerAnimationFinished()
	if(m_hideAll) then
		Controls.PanelStack:SetHide(true);
	end
end

-- ===========================================================================
-- When the launch bar is resized, make sure to adjust the world tracker 
-- button position/size to accommodate it
-- ===========================================================================
function OnLaunchBarResized( buttonStackSize: number)
	Controls.TrackerHeading:SetSizeX(buttonStackSize + LAUNCH_BAR_PADDING);
	Controls.TrackerHeadingCollapsed:SetSizeX(buttonStackSize + LAUNCH_BAR_PADDING);
	if( buttonStackSize > WORLD_TRACKER_PANEL_WIDTH - LAUNCH_BAR_PADDING) then
		m_isTrackerAlwaysCollapsed = true;
		Controls.TrackerHeading:SetHide(true);
		Controls.TrackerHeadingCollapsed:SetHide(false);
	else
		m_isTrackerAlwaysCollapsed = false;
		Controls.TrackerHeading:SetHide(m_hideAll);
		Controls.TrackerHeadingCollapsed:SetHide(not m_hideAll);
	end
	Controls.ToggleAllButton:SetOffsetX(buttonStackSize - 7);
end

-- ===========================================================================
function RealizeStack()
	if(m_hideAll) then ToggleAll(true); end
end

-- ===========================================================================
function UpdateResearchPanel( isHideResearch:boolean )

	-- If not an actual player (observer, tuner, etc...) then we're done here...
	local ePlayer		:number = Game.GetLocalPlayer();
	if (ePlayer == PlayerTypes.NONE or ePlayer == PlayerTypes.OBSERVER) then
		return;
	end
	local pPlayerConfig : table = PlayerConfigurations[ePlayer];

	if not HasCapability("CAPABILITY_TECH_CHOOSER") or not pPlayerConfig:IsAlive() then
		isHideResearch = true;
		Controls.ResearchCheck:SetHide(true);
	end
	if isHideResearch ~= nil then
		m_hideResearch = isHideResearch;		
	end
	
	m_researchInstance.MainPanel:SetHide( m_hideResearch );
	Controls.ResearchCheck:SetCheck( not m_hideResearch );
	LuaEvents.WorldTracker_ToggleResearchPanel(m_hideResearch or m_hideAll);
	RealizeEmptyMessage();
	RealizeStack();

	-- Set the technology to show (or -1 if none)...
	local iTech			:number = m_currentResearchID;
	if m_currentResearchID == -1 then 
		iTech = m_lastResearchCompletedID; 
	end
	local pPlayer		:table  = Players[ePlayer];
	local pPlayerTechs	:table	= pPlayer:GetTechs();
	local kTech			:table	= (iTech ~= -1) and GameInfo.Technologies[ iTech ] or nil;
	local kResearchData :table = GetResearchData( ePlayer, pPlayerTechs, kTech );
	if iTech ~= -1 then
		if m_currentResearchID == iTech then
			kResearchData.IsCurrent = true;
		elseif m_lastResearchCompletedID == iTech then
			kResearchData.IsLastCompleted = true;
		end
	end
	
	RealizeCurrentResearch( ePlayer, kResearchData, m_researchInstance);
	
	-- No tech started (or finished)
	if kResearchData == nil then
		m_researchInstance.TitleButton:SetHide( false );
		TruncateStringWithTooltip(m_researchInstance.TitleButton, MAX_BEFORE_TRUNC_TITLE, Locale.ToUpper(Locale.Lookup("LOC_WORLD_TRACKER_CHOOSE_RESEARCH")) );
	end
end

-- ===========================================================================
function UpdateCivicsPanel(hideCivics:boolean)

	-- If not an actual player (observer, tuner, etc...) then we're done here...
	local ePlayer		:number = Game.GetLocalPlayer();
	if (ePlayer == PlayerTypes.NONE or ePlayer == PlayerTypes.OBSERVER) then
		return;
	end
	local pPlayerConfig : table = PlayerConfigurations[ePlayer];

	if not HasCapability("CAPABILITY_CIVICS_CHOOSER") or (localPlayerID ~= PlayerTypes.NONE and not pPlayerConfig:IsAlive()) then
		hideCivics = true;
		Controls.CivicsCheck:SetHide(true);
	end
	if hideCivics ~= nil then
		m_hideCivics = hideCivics;		
	end

	m_civicsInstance.MainPanel:SetHide(m_hideCivics); 
	Controls.CivicsCheck:SetCheck(not m_hideCivics);
	LuaEvents.WorldTracker_ToggleCivicPanel(m_hideCivics or m_hideAll);
	RealizeEmptyMessage();
	RealizeStack();

	-- Set the civic to show (or -1 if none)...
	local iCivic :number = m_currentCivicID;
	if iCivic == -1 then 
		iCivic = m_lastCivicCompletedID; 
	end	
	local pPlayer		:table  = Players[ePlayer];
	local pPlayerCulture:table	= pPlayer:GetCulture();
	local kCivic		:table	= (iCivic ~= -1) and GameInfo.Civics[ iCivic ] or nil;
	local kCivicData	:table = GetCivicData( ePlayer, pPlayerCulture, kCivic );
	if iCivic ~= -1 then
		if m_currentCivicID == iCivic then
			kCivicData.IsCurrent = true;
		elseif m_lastCivicCompletedID == iCivic then
			kCivicData.IsLastCompleted = true;
		end
	end

	for _,iconData in pairs(g_ExtraIconData) do
		iconData:Reset();
	end
	RealizeCurrentCivic( ePlayer, kCivicData, m_civicsInstance, m_CachedModifiers );

	-- No civic started (or finished)
	if kCivicData == nil then
		m_civicsInstance.TitleButton:SetHide( false );
		TruncateStringWithTooltip(m_civicsInstance.TitleButton, MAX_BEFORE_TRUNC_TITLE, Locale.ToUpper(Locale.Lookup("LOC_WORLD_TRACKER_CHOOSE_CIVIC")) );
	else
		TruncateStringWithTooltip(m_civicsInstance.TitleButton, MAX_BEFORE_TRUNC_TITLE, m_civicsInstance.TitleButton:GetText() );
	end
end

-- ===========================================================================
function UpdateUnitListPanel(hideUnitList:boolean)

	-- If not an actual player (observer, tuner, etc...) then we're done here...
	local ePlayer		:number = Game.GetLocalPlayer();
	if (ePlayer == PlayerTypes.NONE or ePlayer == PlayerTypes.OBSERVER) then
		return;
	end
	local pPlayerConfig : table = PlayerConfigurations[ePlayer];

	if not HasCapability("CAPABILITY_UNIT_LIST") or (ePlayer ~= PlayerTypes.NONE and not pPlayerConfig:IsAlive()) then
		hideUnitList = true;
		Controls.CivicsCheck:SetHide(true);
		m_unitListInstance.UnitListMainPanel:SetHide(true);
		return;
	end

	if(hideUnitList ~= nil) then m_hideUnitList = hideUnitList; end
	
	m_unitEntryIM:ResetInstances();

	m_unitListInstance.UnitListMainPanel:SetHide(m_hideUnitList); 
	Controls.UnitCheck:SetCheck(not m_hideUnitList);

	local pPlayer : table = Players[ePlayer];
	local pPlayerUnits : table = pPlayer:GetUnits();
	local numUnits : number = pPlayerUnits:GetCount();

	if(pPlayerUnits:GetCount() > 0)then
		m_unitListInstance.NoUnitsLabel:SetHide(true);
		m_unitListInstance.UnitsSearchBox:LocalizeAndSetToolTip("LOC_WORLDTRACKER_UNITS_SEARCH_TT");

		local militaryUnits : table = {};
		local navalUnits	: table = {};
		local airUnits		: table = {};
		local supportUnits	: table = {};
		local civilianUnits : table = {};
		local tradeUnits	: table = {};

		for i, pUnit in pPlayerUnits:Members() do
			if((m_unitSearchString ~= "" and string.find(Locale.ToUpper(pUnit:GetName()), m_unitSearchString) ~= nil) or m_unitSearchString == "")then
				local pUnitInfo : table = GameInfo.Units[pUnit:GetUnitType()];

				if pUnitInfo.MakeTradeRoute == true then
					table.insert(tradeUnits, pUnit);
				elseif pUnit:GetCombat() == 0 and pUnit:GetRangedCombat() == 0 then
					-- if we have no attack strength we must be civilian
					table.insert(civilianUnits, pUnit);
				elseif pUnitInfo.Domain == "DOMAIN_LAND" then
					table.insert(militaryUnits, pUnit);
				elseif pUnitInfo.Domain == "DOMAIN_SEA" then
					table.insert(navalUnits, pUnit);
				elseif pUnitInfo.Domain == "DOMAIN_AIR" then
					table.insert(airUnits, pUnit);
				end
			end
		end

		-- Alphabetize groups
		local sortFunc = function(a, b) 
			local aType:string = GameInfo.Units[a:GetUnitType()].UnitType;
			local bType:string = GameInfo.Units[b:GetUnitType()].UnitType;
			return aType < bType;
		end
		table.sort(militaryUnits, sortFunc);
		table.sort(navalUnits, sortFunc);
		table.sort(airUnits, sortFunc);
		table.sort(civilianUnits, sortFunc);
		table.sort(tradeUnits, sortFunc);

		-- Add units by sorted groups
		for _, pUnit in ipairs(militaryUnits) do	AddUnitToUnitList( pUnit );	end
		for _, pUnit in ipairs(navalUnits) do 		AddUnitToUnitList( pUnit );	end
		for _, pUnit in ipairs(airUnits) do			AddUnitToUnitList( pUnit );	end	
		for _, pUnit in ipairs(supportUnits) do		AddUnitToUnitList( pUnit );	end
		for _, pUnit in ipairs(civilianUnits) do	AddUnitToUnitList( pUnit );	end
		for _, pUnit in ipairs(tradeUnits) do		AddUnitToUnitList( pUnit );	end
	else
		m_unitListInstance.NoUnitsLabel:SetHide(false);
		m_unitListInstance.UnitsSearchBox:SetDisabled(true);
		m_unitListInstance.UnitsSearchBox:LocalizeAndSetToolTip("LOC_WORLDTRACKER_NO_UNITS");
	end

	RealizeEmptyMessage();
	RealizeStack();
end

-- ===========================================================================
function StartUnitListSizeUpdate()
	m_isUnitListSizeDirty = true;

	--Allow the unit stack to take up it's full size so the auto sizing parent can do it's thing
	m_unitListInstance.UnitStackContainer:SetHide(false);
	m_unitListInstance.UnitStack:ChangeParent(m_unitListInstance.UnitStackContainer); 
	ContextPtr:RequestRefresh();
end

-- ===========================================================================
function UpdateUnitListSize()
	if(not m_isMinimapInitialized)then
		UpdateWorldTrackerSize();
	end

	if(not m_hideUnitList)then
		local unitStackSize : number = m_unitListInstance.UnitStack:GetSizeY();

		Controls.WorldTrackerVerticalContainer:CalculateSize();

		local slotSize : number = m_unitListInstance.UnitListMainPanel:GetParent():GetSizeY();

		if(unitStackSize > slotSize - UNITS_PANEL_PADDING)then
			m_unitListInstance.UnitListScroll:SetSizeY(slotSize - UNITS_PANEL_PADDING);
			m_unitListInstance.UnitStackContainer:SetHide(true);
			m_unitListInstance.UnitListScroll:SetHide(false);
			m_unitListInstance.UnitStack:ChangeParent(m_unitListInstance.UnitListScroll);
		else
			m_unitListInstance.UnitListScroll:SetHide(true);
		end
		m_isUnitListSizeDirty = false;
	end
end

-- ===========================================================================
function UpdateWorldTrackerSize()
	local uiMinimap : table  = ContextPtr:LookUpControl("/InGame/MinimapPanel/MinimapContainer");
	if(uiMinimap ~= nil)then
		local _, screenHeight : number = UIManager:GetScreenSizeVal();
		if(m_isMinimapCollapsed)then
			Controls.WorldTrackerVerticalContainer:SetSizeY(screenHeight - WORLD_TRACKER_TOP_PADDING);
		else
			Controls.WorldTrackerVerticalContainer:SetSizeY(screenHeight - uiMinimap:GetSizeY() - WORLD_TRACKER_TOP_PADDING);
		end
		m_isMinimapInitialized = true;
	else
		m_isMinimapInitialized = false;
	end

	if(not m_unitListInstance.UnitListMainPanel:IsHidden())then
		StartUnitListSizeUpdate()
	end
end

-- ===========================================================================
function AddUnitToUnitList(pUnit:table)
	local uiUnitEntry : table = m_unitEntryIM:GetInstance();

	local formation : number = pUnit:GetMilitaryFormation();
	local suffix : string = "";
	local unitType = pUnit:GetUnitType();
	local unitInfo : table = GameInfo.Units[unitType];
	if (unitInfo.Domain == "DOMAIN_SEA") then
		if (formation == MilitaryFormationTypes.CORPS_FORMATION) then
			suffix = " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX");
		elseif (formation == MilitaryFormationTypes.ARMY_FORMATION) then
			suffix = " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX");
		end
	else
		if (formation == MilitaryFormationTypes.CORPS_FORMATION) then
			suffix = " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX");
		elseif (formation == MilitaryFormationTypes.ARMY_FORMATION) then
			suffix = " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX");
		end
	end

	local name : string = pUnit:GetName();
	local uniqueName : string = Locale.Lookup( name ) .. suffix;

	local tooltip : string = "";
	local pUnitDef = GameInfo.Units[unitType];
	if pUnitDef then
		local unitTypeName:string = pUnitDef.Name;
		if name ~= unitTypeName then
			tooltip = uniqueName .. " " .. Locale.Lookup("LOC_UNIT_UNIT_TYPE_NAME_SUFFIX", unitTypeName);
		end
	end
	uiUnitEntry.Button:SetToolTipString(tooltip);

	uiUnitEntry.Button:SetText( Locale.ToUpper(uniqueName) );
	uiUnitEntry.Button:RegisterCallback(Mouse.eLClick, function() OnUnitEntryClicked(pUnit:GetID()) end);

	UpdateUnitIcon(pUnit, uiUnitEntry);

	-- Update status icon
	local activityType:number = UnitManager.GetActivityType(pUnit);
	if activityType == ActivityTypes.ACTIVITY_SLEEP then
		SetUnitEntryStatusIcon(uiUnitEntry, "ICON_STATS_SLEEP");
		uiUnitEntry.UnitStatusIcon:SetHide(false);
	elseif activityType == ActivityTypes.ACTIVITY_HOLD then
		SetUnitEntryStatusIcon(uiUnitEntry, "ICON_STATS_SKIP");
		uiUnitEntry.UnitStatusIcon:SetHide(false);
	elseif activityType ~= ActivityTypes.ACTIVITY_AWAKE and pUnit:GetFortifyTurns() > 0 then
		SetUnitEntryStatusIcon(uiUnitEntry, "ICON_DEFENSE");
		uiUnitEntry.UnitStatusIcon:SetHide(false);
	else
		uiUnitEntry.UnitStatusIcon:SetHide(true);
	end

	-- Update entry color if unit cannot take any action
	if pUnit:GetMovementMovesRemaining() > 0 then
		uiUnitEntry.Button:GetTextControl():SetColorByName("UnitPanelTextCS");
		uiUnitEntry.UnitTypeIcon:SetColorByName("UnitPanelTextCS");
	else
		uiUnitEntry.Button:GetTextControl():SetColorByName("UnitPanelTextDisabledCS");
		uiUnitEntry.UnitTypeIcon:SetColorByName("UnitPanelTextDisabledCS");
	end
end

-- ===========================================================================
function SetUnitEntryStatusIcon(unitEntry:table, icon:string)
	unitEntry.UnitStatusIcon:SetIcon(icon);
end

-- ===========================================================================
function UpdateUnitIcon(pUnit:table, uiUnitEntry:table)
	local iconInfo:table, iconShadowInfo:table = GetUnitIcon(pUnit, 22, true);
	if iconInfo.textureSheet then
		uiUnitEntry.UnitTypeIcon:SetTexture( iconInfo.textureOffsetX, iconInfo.textureOffsetY, iconInfo.textureSheet );
	end
end

-- ===========================================================================
function OnUnitEntryClicked(unitID:number)
	local playerUnits:table = Players[Game.GetLocalPlayer()]:GetUnits();
	if playerUnits then
		local selectedUnit:table = playerUnits:FindID(unitID);
		if selectedUnit then
			UI.LookAtPlot(selectedUnit:GetX(), selectedUnit:GetY());
			UI.SelectUnit( selectedUnit );
		end
	end
end

-- ===========================================================================
function OnUnitListSearch()
	local searchBoxString : string = m_unitListInstance.UnitsSearchBox:GetText();
	if(searchBoxString == nil)then
		m_unitSearchString = "";
	else
		m_unitSearchString = string.upper(searchBoxString);
	end
	UpdateUnitListPanel();
end

-- ===========================================================================
function UpdateChatPanel(hideChat:boolean)
	m_hideChat = hideChat; 
	Controls.ChatPanelContainer:SetHide(m_hideChat);
	Controls.ChatCheck:SetCheck(not m_hideChat);
	RealizeEmptyMessage();
	RealizeStack();
	CheckUnreadChatMessageCount();
end

-- ===========================================================================
function CheckUnreadChatMessageCount()
	-- Unhiding the chat panel resets the unread chat message count.
	if(not hideAll and not m_hideChat) then
		m_unreadChatMsgs = 0;
		UpdateUnreadChatMsgs();
		LuaEvents.WorldTracker_OnChatShown();
	end
end

-- ===========================================================================
function UpdateUnreadChatMsgs()
	if(GameConfiguration.IsPlayByCloud()) then
		Controls.ChatCheck:GetTextButton():SetText(Locale.Lookup("LOC_PLAY_BY_CLOUD_PANEL"));
	elseif(m_unreadChatMsgs > 0) then
		Controls.ChatCheck:GetTextButton():SetText(Locale.Lookup("LOC_HIDE_CHAT_PANEL_UNREAD_MESSAGES", m_unreadChatMsgs));
	else
		Controls.ChatCheck:GetTextButton():SetText(Locale.Lookup("LOC_HIDE_CHAT_PANEL"));
	end
end

-- ===========================================================================
--	Obtains full refresh and views most current research and civic IDs.
-- ===========================================================================
function Refresh()
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer < 0 then
		ToggleAll(true);
		return;
	end

	UpdateWorldTrackerSize();

	local pPlayerTechs :table = Players[localPlayer]:GetTechs();
	m_currentResearchID = pPlayerTechs:GetResearchingTech();
	
	-- Only reset last completed tech once a new tech has been selected
	if m_currentResearchID >= 0 then	
		m_lastResearchCompletedID = -1;
	end	

	UpdateResearchPanel();

	local pPlayerCulture:table = Players[localPlayer]:GetCulture();
	m_currentCivicID = pPlayerCulture:GetProgressingCivic();

	-- Only reset last completed civic once a new civic has been selected
	if m_currentCivicID >= 0 then	
		m_lastCivicCompletedID = -1;
	end	

	UpdateCivicsPanel();
	UpdateUnitListPanel();

	-- Hide world tracker by default if there are no tracker options enabled
	if IsAllPanelsHidden() then
		ToggleAll(true);
	end
end

-- ===========================================================================
--	GAME EVENT
-- ===========================================================================
function OnLocalPlayerTurnBegin()
	local localPlayer = Game.GetLocalPlayer();
	if localPlayer ~= -1 then
		m_isDirty = true;
	end
end

-- ===========================================================================
--	GAME EVENT
-- ===========================================================================
function OnCityInitialized( playerID:number, cityID:number )
	if playerID == Game.GetLocalPlayer() then	
		m_isDirty = true;
	end
end

-- ===========================================================================
--	GAME EVENT
--	Buildings can change culture/science yield which can effect 
--	"turns to complete" values
-- ===========================================================================
function OnBuildingChanged( plotX:number, plotY:number, buildingIndex:number, playerID:number, cityID:number, iPercentComplete:number )
	if playerID == Game.GetLocalPlayer() then	
		m_isDirty = true; 
	end
end

-- ===========================================================================
--	GAME EVENT
-- ===========================================================================
function OnDirtyCheck()
	if m_isDirty then
		Refresh();
		m_isDirty = false;
	end
end

-- ===========================================================================
--	GAME EVENT
--	A civic item has changed, this may not be the current civic item
--	but an item deeper in the tree that was just boosted by a player action.
-- ===========================================================================
function OnCivicChanged( ePlayer:number, eCivic:number )
	local localPlayer = Game.GetLocalPlayer();
	if localPlayer ~= -1 and localPlayer == ePlayer then		
		ResetOverflowArrow( m_civicsInstance );
		local pPlayerCulture:table = Players[localPlayer]:GetCulture();
		m_currentCivicID = pPlayerCulture:GetProgressingCivic();
		m_lastCivicCompletedID = -1;
		if eCivic == m_currentCivicID then
			UpdateCivicsPanel();
		end
	end
end

-- ===========================================================================
--	GAME EVENT
-- ===========================================================================
function OnCivicCompleted( ePlayer:number, eCivic:number )
	local localPlayer = Game.GetLocalPlayer();
	if localPlayer ~= -1 and localPlayer == ePlayer then
		m_currentCivicID = -1;
		m_lastCivicCompletedID = eCivic;		
		UpdateCivicsPanel();
	end
end

-- ===========================================================================
--	GAME EVENT
-- ===========================================================================
function OnCultureYieldChanged( ePlayer:number )
	local localPlayer = Game.GetLocalPlayer();
	if localPlayer ~= -1 and localPlayer == ePlayer then
		UpdateCivicsPanel();
	end
end

-- ===========================================================================
--	GAME EVENT
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		ContextPtr:SetHide(true); 
	end
	if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		ContextPtr:SetHide(false);
	end
end

-- ===========================================================================
--	GAME EVENT
--	A research item has changed, this may not be the current researched item
--	but an item deeper in the tree that was just boosted by a player action.
-- ===========================================================================
function OnResearchChanged( ePlayer:number, eTech:number )
	if ShouldUpdateResearchPanel(ePlayer, eTech) then
		ResetOverflowArrow( m_researchInstance );
		UpdateResearchPanel();
	end
end

-- ===========================================================================
--	This function was separated so behavior can be modified in mods/expasions
-- ===========================================================================
function ShouldUpdateResearchPanel(ePlayer:number, eTech:number)
	local localPlayer = Game.GetLocalPlayer();
	
	if localPlayer ~= -1 and localPlayer == ePlayer then
		local pPlayerTechs :table = Players[localPlayer]:GetTechs();
		m_currentResearchID = pPlayerTechs:GetResearchingTech();
		
		-- Only reset last completed tech once a new tech has been selected
		if m_currentResearchID >= 0 then	
			m_lastResearchCompletedID = -1;
		end

		if eTech == m_currentResearchID then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
function OnResearchCompleted( ePlayer:number, eTech:number )
	if (ePlayer == Game.GetLocalPlayer()) then
		m_currentResearchID = -1;
		m_lastResearchCompletedID = eTech;
		UpdateResearchPanel();
	end
end

-- ===========================================================================
function OnUpdateDueToCity(ePlayer:number, cityID:number, plotX:number, plotY:number)
	if (ePlayer == Game.GetLocalPlayer()) then
		UpdateResearchPanel();
		UpdateCivicsPanel();
	end
end

-- ===========================================================================
function OnResearchYieldChanged( ePlayer:number )
	local localPlayer = Game.GetLocalPlayer();
	if localPlayer ~= -1 and localPlayer == ePlayer then
		UpdateResearchPanel();
	end
end


-- ===========================================================================
function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	-- If the chat panels are hidden, indicate there are unread messages waiting on the world tracker panel toggler.
	if(m_hideAll or m_hideChat) then
		m_unreadChatMsgs = m_unreadChatMsgs + 1;
		UpdateUnreadChatMsgs();
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInit(isReload:boolean)	
	LateInitialize();
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	else		
		Refresh();	-- Standard refresh.
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnShutdown()
	Unsubscribe();

	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentResearchID",		m_currentResearchID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_lastResearchCompletedID",	m_lastResearchCompletedID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentCivicID",			m_currentCivicID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_lastCivicCompletedID",		m_lastCivicCompletedID);	
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)	
	if context == RELOAD_CACHE_ID then
		m_currentResearchID			= contextTable["m_currentResearchID"];
		m_lastResearchCompletedID	= contextTable["m_lastResearchCompletedID"];
		m_currentCivicID			= contextTable["m_currentCivicID"];
		m_lastCivicCompletedID		= contextTable["m_lastCivicCompletedID"];

		if m_currentResearchID == nil		then m_currentResearchID = -1; end
		if m_lastResearchCompletedID == nil then m_lastResearchCompletedID = -1; end
		if m_currentCivicID == nil			then m_currentCivicID = -1; end
		if m_lastCivicCompletedID == nil	then m_lastCivicCompletedID = -1; end

		-- Don't call refresh, use cached data from last hotload.
		UpdateResearchPanel();
		UpdateCivicsPanel();
		UpdateUnitListPanel();
	end
end

-- ===========================================================================
function OnTutorialGoalsShowing()
	Controls.TutorialGoals:SetHide(false);
	RealizeStack();
end

-- ===========================================================================
function OnTutorialGoalsHiding()
	RealizeStack();
end

-- ===========================================================================
function Tutorial_ShowFullTracker()
	Controls.ToggleAllButton:SetHide(true);
	Controls.ToggleDropdownButton:SetHide(true);
	UpdateCivicsPanel(false);
	UpdateResearchPanel(false);
	ToggleAll(false);
end

-- ===========================================================================
function Tutorial_ShowTrackerOptions()
	Controls.ToggleAllButton:SetHide(false);
	Controls.ToggleDropdownButton:SetHide(false);
end

-- ===========================================================================
function OnSetMinimapCollapsed(isMinimapCollapsed:boolean)
	m_isMinimapCollapsed = isMinimapCollapsed;
	CheckEnoughRoom();
	UpdateWorldTrackerSize();
end

-- ===========================================================================
function OnUnitAddedToMap(playerID:number, unitID:number)
	if UI.IsInGame() == false then
		return;
	end
	if(playerID == Game.GetLocalPlayer())then
		UpdateUnitListPanel();
		StartUnitListSizeUpdate();
	end
end

-- ===========================================================================
function OnUnitMovementPointsChanged(playerID:number, unitID:number)
	if(playerID == Game.GetLocalPlayer())then
		UpdateUnitListPanel();
	end
end

-- ===========================================================================
function OnUnitRemovedFromMap(playerID:number, unitID:number)
	if(playerID == Game.GetLocalPlayer())then
		UpdateUnitListPanel();
		StartUnitListSizeUpdate();
	end
end

-- ===========================================================================
function OnUnitOperationDeactivated(playerID:number)
	--Update UnitList in case we put one of our units to sleep
	if(playerID == Game.GetLocalPlayer()) then
		UpdateUnitListPanel();
	end
end

-- ===========================================================================
function OnUnitOperationStarted(ownerID : number, unitID : number, operationID : number)
	if(ownerID == Game.GetLocalPlayer() and (operationID == UnitOperationTypes.FORTIFY or operationID == UnitOperationTypes.ALERT))then
		UpdateUnitListPanel();
	end
end

-- ===========================================================================
function OnUnitCommandStarted(playerID:number, unitID:number, hCommand:number)
    if (hCommand == UnitCommandTypes.WAKE and playerID == Game.GetLocalPlayer()) then
        UpdateUnitListPanel();
	end
end

-- ===========================================================================
--	Add any UI from tracked items that are loaded.
--	Items are expected to be tables with the following fields:
--		Name			localization key for the title name of panel
--		InstanceType	the instance (in XML) to create for the control
--		SelectFunc		if instance has "IconButton" the callback when pressed
-- ===========================================================================
function AttachDynamicUI()
	for i,kData in ipairs(g_TrackedItems) do
		local uiInstance:table = {};
		ContextPtr:BuildInstanceForControl( kData.InstanceType, uiInstance, Controls.WorldTrackerVerticalContainer );
		if uiInstance.IconButton then
			uiInstance.IconButton:RegisterCallback(Mouse.eLClick, function() kData.SelectFunc() end);
		end
		table.insert(g_TrackedInstances, uiInstance);

		if(uiInstance.TitleButton) then
			uiInstance.TitleButton:LocalizeAndSetText(kData.Name);
		end
	end
end

-- ===========================================================================
function OnForceHide()
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function OnForceShow()
	ContextPtr:SetHide(false);
end

-- ===========================================================================
function OnStartObserverMode()
	UpdateResearchPanel();
	UpdateCivicsPanel();
end

-- ===========================================================================
function OnRefresh()
	ContextPtr:ClearRequestRefresh();
	if(not m_isMinimapInitialized)then
		UpdateWorldTrackerSize();
	elseif(m_isUnitListSizeDirty)then
		UpdateUnitListSize();
	end
end

-- ===========================================================================
function OnLoadGameViewStateDone()
	m_isDirty =true;
	OnDirtyCheck();
end

-- ===========================================================================
function OnChatPanelContainerSizeChanged()
	LuaEvents.WorldTracker_ChatContainerSizeChanged(Controls.ChatPanelContainer:GetSizeY());
end

-- ===========================================================================
-- FOR OVERRIDE
-- ===========================================================================
function GetMinimapPadding()
	return MINIMAP_PADDING;
end

function GetTopBarPadding()
	return TOPBAR_PADDING;
end

-- ===========================================================================
function Subscribe()
	Events.CityInitialized.Add(OnCityInitialized);
	Events.BuildingChanged.Add(OnBuildingChanged);
	Events.CivicChanged.Add(OnCivicChanged);
	Events.CivicCompleted.Add(OnCivicCompleted);
	Events.CultureYieldChanged.Add(OnCultureYieldChanged);
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	Events.ResearchChanged.Add(OnResearchChanged);
	Events.ResearchCompleted.Add(OnResearchCompleted);
	Events.ResearchYieldChanged.Add(OnResearchYieldChanged);
	Events.GameCoreEventPublishComplete.Add( OnDirtyCheck ); --This event is raised directly after a series of gamecore events.
	Events.CityWorkerChanged.Add( OnUpdateDueToCity );
	Events.CityFocusChanged.Add( OnUpdateDueToCity );
	Events.UnitAddedToMap.Add( OnUnitAddedToMap );
	Events.UnitCommandStarted.Add( OnUnitCommandStarted );
	Events.UnitMovementPointsChanged.Add( OnUnitMovementPointsChanged );
	Events.UnitOperationDeactivated.Add( OnUnitOperationDeactivated );
	Events.UnitOperationStarted.Add( OnUnitOperationStarted );
	Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );
	Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);

	LuaEvents.LaunchBar_Resize.Add(OnLaunchBarResized);
	
	LuaEvents.CivicChooser_ForceHideWorldTracker.Add(	OnForceHide );
	LuaEvents.CivicChooser_RestoreWorldTracker.Add(		OnForceShow);
	LuaEvents.EndGameMenu_StartObserverMode.Add(		OnStartObserverMode );
	LuaEvents.ResearchChooser_ForceHideWorldTracker.Add(OnForceHide);
	LuaEvents.ResearchChooser_RestoreWorldTracker.Add(	OnForceShow);
	LuaEvents.Tutorial_ForceHideWorldTracker.Add(		OnForceHide);
	LuaEvents.Tutorial_RestoreWorldTracker.Add(			Tutorial_ShowFullTracker);
	LuaEvents.Tutorial_EndTutorialRestrictions.Add(		Tutorial_ShowTrackerOptions);
	LuaEvents.TutorialGoals_Showing.Add(				OnTutorialGoalsShowing );
	LuaEvents.TutorialGoals_Hiding.Add(					OnTutorialGoalsHiding );
	LuaEvents.WorldTracker_OnSetMinimapCollapsed.Add(	OnSetMinimapCollapsed );
end

-- ===========================================================================
function Unsubscribe()
	Events.CityInitialized.Remove(OnCityInitialized);
	Events.BuildingChanged.Remove(OnBuildingChanged);
	Events.CivicChanged.Remove(OnCivicChanged);
	Events.CivicCompleted.Remove(OnCivicCompleted);
	Events.CultureYieldChanged.Remove(OnCultureYieldChanged);
	Events.InterfaceModeChanged.Remove( OnInterfaceModeChanged );
	Events.LocalPlayerTurnBegin.Remove(OnLocalPlayerTurnBegin);
	Events.MultiplayerChat.Remove( OnMultiplayerChat );
	Events.ResearchChanged.Remove(OnResearchChanged);
	Events.ResearchCompleted.Remove(OnResearchCompleted);
	Events.ResearchYieldChanged.Remove(OnResearchYieldChanged);
	Events.GameCoreEventPublishComplete.Remove( OnDirtyCheck ); --This event is raised directly after a series of gamecore events.
	Events.CityWorkerChanged.Remove( OnUpdateDueToCity );
	Events.CityFocusChanged.Remove( OnUpdateDueToCity );
	Events.UnitAddedToMap.Remove( OnUnitAddedToMap );
	Events.UnitCommandStarted.Remove( OnUnitCommandStarted );
	Events.UnitMovementPointsChanged.Remove( OnUnitMovementPointsChanged );
	Events.UnitOperationDeactivated.Remove( OnUnitOperationDeactivated );
	Events.UnitOperationStarted.Remove( OnUnitOperationStarted );
	Events.UnitRemovedFromMap.Remove( OnUnitRemovedFromMap );
	Events.LoadGameViewStateDone.Remove(OnLoadGameViewStateDone);

	LuaEvents.LaunchBar_Resize.Remove(OnLaunchBarResized);
	
	LuaEvents.CivicChooser_ForceHideWorldTracker.Remove(	OnForceHide );
	LuaEvents.CivicChooser_RestoreWorldTracker.Remove(		OnForceShow);
	LuaEvents.EndGameMenu_StartObserverMode.Remove(			OnStartObserverMode );
	LuaEvents.ResearchChooser_ForceHideWorldTracker.Remove(	OnForceHide);
	LuaEvents.ResearchChooser_RestoreWorldTracker.Remove(	OnForceShow);
	LuaEvents.Tutorial_ForceHideWorldTracker.Remove(		OnForceHide);
	LuaEvents.Tutorial_RestoreWorldTracker.Remove(			Tutorial_ShowFullTracker);
	LuaEvents.Tutorial_EndTutorialRestrictions.Remove(		Tutorial_ShowTrackerOptions);
	LuaEvents.TutorialGoals_Showing.Remove(					OnTutorialGoalsShowing );
	LuaEvents.TutorialGoals_Hiding.Remove(					OnTutorialGoalsHiding );
	LuaEvents.WorldTracker_OnSetMinimapCollapsed.Remove(	OnSetMinimapCollapsed );
end

-- ===========================================================================
function LateInitialize()

	Subscribe();

	-- InitChatPanel
	if(UI.HasFeature("Chat") 
		and (GameConfiguration.IsNetworkMultiplayer() or GameConfiguration.IsPlayByCloud()) ) then
		UpdateChatPanel(false);
	else
		UpdateChatPanel(true);
		Controls.ChatCheck:SetHide(true);
	end

	UpdateUnreadChatMsgs();
	AttachDynamicUI();
	UpdateWorldTrackerSize();
end

-- ===========================================================================
function Initialize()
	
	if not GameCapabilities.HasCapability("CAPABILITY_WORLD_TRACKER") then
		ContextPtr:SetHide(true);
		return;
	end

	ContextPtr:SetRefreshHandler( OnRefresh );	
	
	m_CachedModifiers = TechAndCivicSupport_BuildCivicModifierCache();

	-- Create semi-dynamic instances; hack: change parent back to self for ordering:
	ContextPtr:BuildInstanceForControl( "ResearchInstance", m_researchInstance, Controls.WorldTrackerVerticalContainer );
	ContextPtr:BuildInstanceForControl( "CivicInstance",	m_civicsInstance,	Controls.WorldTrackerVerticalContainer );
	Controls.OtherContainer:ChangeParent( Controls.WorldTrackerVerticalContainer );
	ContextPtr:BuildInstanceForControl( "UnitListInstance", m_unitListInstance, Controls.WorldTrackerVerticalContainer );

	m_researchInstance.IconButton:RegisterCallback(	Mouse.eLClick,	function() LuaEvents.WorldTracker_OpenChooseResearch(); end);
	m_civicsInstance.IconButton:RegisterCallback(	Mouse.eLClick,	function() LuaEvents.WorldTracker_OpenChooseCivic(); end);

	m_unitEntryIM = InstanceManager:new( "UnitListEntry", "Button", m_unitListInstance.UnitStack);

	Controls.ChatPanelContainer:ChangeParent( Controls.WorldTrackerVerticalContainer );
	Controls.TutorialGoals:ChangeParent( Controls.WorldTrackerVerticalContainer );	

	-- Handle any text overflows with truncation and tooltip
	local fullString :string = Controls.WorldTracker:GetText();
	Controls.DropdownScroll:SetOffsetY(Controls.WorldTrackerHeader:GetSizeY() + STARTING_TRACKER_OPTIONS_OFFSET);	
	
	-- Hot-reload events
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	
	Controls.ChatCheck:SetCheck(true);
	Controls.CivicsCheck:SetCheck(true);
	Controls.ResearchCheck:SetCheck(true);
	Controls.ToggleAllButton:SetCheck(true);

	Controls.ChatCheck:RegisterCheckHandler(						function() UpdateChatPanel(not m_hideChat);
																			   StartUnitListSizeUpdate();
																			   CheckEnoughRoom();
																			   end);
	Controls.CivicsCheck:RegisterCheckHandler(						function() UpdateCivicsPanel(not m_hideCivics);
																			   StartUnitListSizeUpdate();
																			   CheckEnoughRoom();
																			   end);
	Controls.ResearchCheck:RegisterCheckHandler(					function() UpdateResearchPanel(not m_hideResearch);
																			   StartUnitListSizeUpdate();
																			   CheckEnoughRoom();
																			   end);
	Controls.UnitCheck:RegisterCheckHandler(						function() UpdateUnitListPanel(not m_hideUnitList); 
																			   StartUnitListSizeUpdate();
																			   CheckEnoughRoom();
																			   end);
	Controls.ToggleAllButton:RegisterCheckHandler(					function() ToggleAll(not Controls.ToggleAllButton:IsChecked()) end);
	Controls.ToggleDropdownButton:RegisterCallback(	Mouse.eLClick, ToggleDropdown);
	Controls.WorldTrackerAlpha:RegisterEndCallback( OnWorldTrackerAnimationFinished );
	m_unitListInstance.UnitsSearchBox:RegisterStringChangedCallback( OnUnitListSearch );
	Controls.ChatPanelContainer:RegisterSizeChanged(OnChatPanelContainerSizeChanged);
end
Initialize();