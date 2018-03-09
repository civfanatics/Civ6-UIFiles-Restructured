-- ===========================================================================
--	INCLUDES
-- ===========================================================================

include("AnimSidePanelSupport");
include("InstanceManager");
include("SupportFunctions");
include("CivilizationIcon");
include("TeamSupport");
include("EraSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local m_ToggleVisibilityAction;
local RELOAD_CACHE_ID:string = "EraProgressPanel"; -- Must be unique (usually the same as the file name)

local ERA_TYPE_DARK_AGE:number		= 1;
local ERA_TYPE_NORMAL_AGE:number	= 2;
local ERA_TYPE_GOLDEN_AGE:number	= 3;
local ERA_TYPE_HEROIC_AGE:number	= 4;

local TEAM_RIBBON_PREFIX:string = "ICON_TEAM_RIBBON_";
local TEAM_RIBBON_SIZE:number = 53;

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_AnimSupport:table; -- AnimSidePanelSupport

local m_EraData:table = {
	PlayerID = -1;
	NextEraMinTurn = 0;
	NextEraMaxTurn = 0;
	CurrentEraName = "";
	CurrentEraIcon = "";
	CurrentEraType = -1;
	NextEraType = -1;
	CurrentEraScore = 0;
	EraRibbonTexture = "";
	EraRibbonText = "";
	AgeName = "";
	ShortAgeName = "";
	AgeEffects = "";
	ScoreBreakdown = {};
	NextEraThreshold = 0;
	DarkAgeThreshold = 0;
	DarkAgeThresholdTooltip = "";
	GoldenAgeThreshold = 0;
	GoldenAgeThresholdTooltip = "";
	FinalEraReached = false;
};

local m_CivilizationIconIM:table = InstanceManager:new("CivilizationIconAge", "CivIconBacking", Controls.CivIconStack);
local m_ScoreBreakdownInstanceManager:table = InstanceManager:new("ScoreBreakdownItem", "TopControl", Controls.ScoreBreakdownStack);

-- ===========================================================================
function GetData()
	local pGameEras:table = Game.GetEras();
	local currentEraIndex:number = pGameEras:GetCurrentEra();
	local currentEraDef:table = GameInfo.Eras[currentEraIndex];
	local currentTurn:number = Game.GetCurrentGameTurn();

	m_EraData.PlayerID = Game.GetLocalPlayer();

	m_EraData.CurrentEraName = Locale.ToUpper(currentEraDef.Name);
	m_EraData.CurrentEraScore = pGameEras:GetPlayerCurrentScore(m_EraData.PlayerID);

	-- Combine previous era scores
	m_EraData.ScoreBreakdown = {};
	local previousScoreBreakdown = pGameEras:GetPlayerPreviousEraScoreBreakdown(m_EraData.PlayerID);
	local previousScoreTotal = 0;
	for i,source in ipairs(previousScoreBreakdown) do
		for sourceString, sourceValue in pairs(source) do
			previousScoreTotal = previousScoreTotal + sourceValue;
		end
	end

	-- Display previous era scores as a single entry
	if previousScoreTotal > 0 then
		local previousScore:table = {};
		previousScore[Locale.Lookup("LOC_ERAS_PREVIOUS_ERA_TOTAL_SCORE")] = previousScoreTotal;
		table.insert(m_EraData.ScoreBreakdown, previousScore);
	end

	-- Add current era breakdown as individual entries
	local currentScoreBreakdown = pGameEras:GetPlayerCurrentEraScoreBreakdown(m_EraData.PlayerID);
	for i,source in ipairs(currentScoreBreakdown) do
		for sourceString, sourceValue in pairs(source) do
			if sourceValue > 0 then
				local currentSource:table = {};
				currentSource[sourceString] = sourceValue;
				table.insert(m_EraData.ScoreBreakdown, currentSource);
			end
		end
	end

	local nextEraCountdown = pGameEras:GetNextEraCountdown() + 1; -- 0 turns remaining is the last turn, shift by 1 to make sense to non-programmers
	if nextEraCountdown > 0 then
		-- If the era countdown has started only show that number
		m_EraData.NextEraMinTurn = nextEraCountdown;
		m_EraData.NextEraMaxTurn = nextEraCountdown;
	else
		local inactiveCountdownLength = GlobalParameters.NEXT_ERA_TURN_COUNTDOWN; -- Even though the countdown has not started yet, account for it in our time estimates
		m_EraData.NextEraMinTurn = pGameEras:GetCurrentEraMinimumEndTurn() - currentTurn;
		if (m_EraData.NextEraMinTurn < inactiveCountdownLength) then
			m_EraData.NextEraMinTurn = inactiveCountdownLength;
		end
		m_EraData.NextEraMaxTurn = pGameEras:GetCurrentEraMaximumEndTurn() - currentTurn;
		if (m_EraData.NextEraMaxTurn < 0) then
			m_EraData.NextEraMaxTurn = 0;
		end
	end

	m_EraData.DarkAgeThreshold = pGameEras:GetPlayerDarkAgeThreshold(m_EraData.PlayerID);
	m_EraData.DarkAgeThresholdTooltip = GetDarkAgeThresholdTooltip(m_EraData.PlayerID);
	m_EraData.GoldenAgeThreshold = pGameEras:GetPlayerGoldenAgeThreshold(m_EraData.PlayerID);
	m_EraData.GoldenAgeThresholdTooltip = GetGoldenAgeThresholdTooltip(m_EraData.PlayerID);

	if (pGameEras:GetCurrentEra() == pGameEras:GetFinalEra()) then
		m_EraData.FinalEraReached = true;
	end

	-- Determine which era we'll currently have next
	if m_EraData.CurrentEraScore >= m_EraData.GoldenAgeThreshold then
		m_EraData.NextEraType = ERA_TYPE_GOLDEN_AGE;
	elseif m_EraData.CurrentEraScore > m_EraData.DarkAgeThreshold then
		m_EraData.NextEraType = ERA_TYPE_NORMAL_AGE;
	else
		m_EraData.NextEraType = ERA_TYPE_DARK_AGE;
	end

	if pGameEras:HasHeroicGoldenAge(m_EraData.PlayerID) then
		-- Heroic
		m_EraData.CurrentEraType = ERA_TYPE_HEROIC_AGE;
		m_EraData.CurrentEraIcon = "[ICON_GLORY_SUPER_GOLDEN_AGE]";
		m_EraData.NextEraThreshold = m_EraData.GoldenAgeThreshold
		m_EraData.EraRibbonTexture = "Controls_AgesBanner_Heroic";
		m_EraData.EraRibbonText = Locale.Lookup("LOC_ERA_REVIEW_HAVE_HEROIC_AGE");
		m_EraData.AgeName = Locale.Lookup("LOC_ERA_PROGRESS_HEROIC_AGE");
		m_EraData.ShortAgeName = Locale.Lookup("LOC_ERAS_HEROIC");
		m_EraData.AgeEffects = Locale.Lookup("LOC_ERA_TT_HAVE_HEROIC_AGE_EFFECT");
	elseif pGameEras:HasGoldenAge(m_EraData.PlayerID) then
		-- Golden
		m_EraData.CurrentEraType = ERA_TYPE_GOLDEN_AGE;
		m_EraData.CurrentEraIcon = "[ICON_GLORY_GOLDEN_AGE]";
		m_EraData.NextEraThreshold = m_EraData.GoldenAgeThreshold
		m_EraData.EraRibbonTexture = "Controls_AgesBanner_Golden";
		m_EraData.EraRibbonText = Locale.Lookup("LOC_ERA_REVIEW_HAVE_GOLDEN_AGE");
		m_EraData.AgeName = Locale.Lookup("LOC_ERA_PROGRESS_GOLDEN_AGE");
		m_EraData.ShortAgeName = Locale.Lookup("LOC_ERAS_GOLDEN");
		m_EraData.AgeEffects = Locale.Lookup("LOC_ERA_TT_HAVE_GOLDEN_AGE_EFFECT");
	elseif pGameEras:HasDarkAge(m_EraData.PlayerID) then
		-- Dark
		m_EraData.CurrentEraType = ERA_TYPE_DARK_AGE;
		m_EraData.CurrentEraIcon = "[ICON_GLORY_DARK_AGE]";
		m_EraData.NextEraThreshold = m_EraData.DarkAgeThreshold
		m_EraData.EraRibbonTexture = "Controls_AgesBanner_Dark";
		m_EraData.EraRibbonText = Locale.Lookup("LOC_ERA_REVIEW_HAVE_DARK_AGE");
		m_EraData.AgeName = Locale.Lookup("LOC_ERA_PROGRESS_DARK_AGE");
		m_EraData.ShortAgeName = Locale.Lookup("LOC_ERAS_DARK");
		m_EraData.AgeEffects = Locale.Lookup("LOC_ERA_TT_HAVE_DARK_AGE_EFFECT");
	else
		-- Normal
		m_EraData.CurrentEraType = ERA_TYPE_NORMAL_AGE;
		m_EraData.CurrentEraIcon = "[ICON_GLORY_NORMAL_AGE]";
		m_EraData.NextEraThreshold = m_EraData.GoldenAgeThreshold
		m_EraData.EraRibbonTexture = "Controls_AgesBanner_Normal";
		m_EraData.EraRibbonText = Locale.Lookup("LOC_ERA_REVIEW_HAVE_NORMAL_AGE");
		m_EraData.AgeName = Locale.Lookup("LOC_ERA_PROGRESS_NORMAL_AGE");
		m_EraData.ShortAgeName = Locale.Lookup("LOC_ERAS_NORMAL");
		m_EraData.AgeEffects = Locale.Lookup("LOC_ERA_TT_HAVE_NORMAL_AGE_EFFECT");
	end

	-- Add dedications to the age effects
	local activeCommemorations = pGameEras:GetPlayerActiveCommemorations(m_EraData.PlayerID);
	for i,activeCommemoration in ipairs(activeCommemorations) do
		local commemorationInfo = GameInfo.CommemorationTypes[activeCommemoration];
		m_EraData.AgeEffects = m_EraData.AgeEffects .. "[NEWLINE][NEWLINE][ICON_BULLET]";
		if (commemorationInfo ~= nil) then
			local bonusText = nil;
			if (pGameEras:HasGoldenAge(m_EraData.PlayerID)) then
				bonusText = Locale.Lookup(commemorationInfo.GoldenAgeBonusDescription);
				if (pGameEras:IsPlayerAlwaysAllowedCommemorationQuest(m_EraData.PlayerID)) then
					bonusText = bonusText .. "[NEWLINE][NEWLINE][ICON_BULLET]" .. Locale.Lookup(commemorationInfo.NormalAgeBonusDescription);
				end
			elseif (pGameEras:HasDarkAge(m_EraData.PlayerID)) then
				bonusText = Locale.Lookup(commemorationInfo.DarkAgeBonusDescription);
			else
				bonusText = Locale.Lookup(commemorationInfo.NormalAgeBonusDescription);
			end
			if (bonusText ~= nil) then
				m_EraData.AgeEffects = m_EraData.AgeEffects .. bonusText;
			end
		end
	end
end

-- ===========================================================================
function Refresh()
	GetData();

	Controls.EraName:SetText(Locale.Lookup("LOC_ERA_PROGRESS_THE_ERA", m_EraData.CurrentEraName));
	Controls.EraScoreValue:SetText(m_EraData.CurrentEraScore);
	
	Controls.TimeToNextEraContainer:SetHide(m_EraData.FinalEraReached);
	if m_EraData.NextEraMinTurn == m_EraData.NextEraMaxTurn then
		Controls.TimeToNextEra:SetText(m_EraData.NextEraMaxTurn);
	else
		Controls.TimeToNextEra:SetText(m_EraData.NextEraMinTurn .. " - " .. m_EraData.NextEraMaxTurn);
	end

	local eraRibbonText:string = m_EraData.ShortAgeName .. " (" .. m_EraData.CurrentEraIcon .. m_EraData.CurrentEraScore .. "/" .. m_EraData.NextEraThreshold .. " )";
	Controls.EraRibbonValue:SetText(eraRibbonText);
	Controls.EraRibbon:SetTexture(m_EraData.EraRibbonTexture);

	PopulateLocalPlayerIcon();

	PopulateCivilizationIcons();

	if m_EraData.NextEraType == ERA_TYPE_GOLDEN_AGE then
		Controls.GoldenCheckmark:SetHide(false);
		Controls.GoldenCheckmark:SetToolTipString(Locale.Lookup("LOC_ERAS_YOU_WILL_EARN_BLANK_AGE_NEXT_ERA", Locale.Lookup("LOC_ERA_PROGRESS_GOLDEN_AGE")));
		Controls.NormalCheckmark:SetHide(true);
		Controls.DarkCheckmark:SetHide(true);
	elseif m_EraData.NextEraType == ERA_TYPE_NORMAL_AGE then
		Controls.GoldenCheckmark:SetHide(true);
		Controls.NormalCheckmark:SetHide(false);
		Controls.NormalCheckmark:SetToolTipString(Locale.Lookup("LOC_ERAS_YOU_WILL_EARN_BLANK_AGE_NEXT_ERA", Locale.Lookup("LOC_ERA_PROGRESS_NORMAL_AGE")));
		Controls.DarkCheckmark:SetHide(true);
	else
		Controls.GoldenCheckmark:SetHide(true);
		Controls.NormalCheckmark:SetHide(true);
		Controls.DarkCheckmark:SetHide(false);
		Controls.DarkCheckmark:SetToolTipString(Locale.Lookup("LOC_ERAS_YOU_WILL_EARN_BLANK_AGE_NEXT_ERA", Locale.Lookup("LOC_ERA_PROGRESS_DARK_AGE")));
	end

	if (m_EraData.FinalEraReached) then
		Controls.ThresholdStack:SetHide(true);
	else
		Controls.DarkThreshold:SetText("0 - " .. (m_EraData.DarkAgeThreshold - 1));
		Controls.DarkThreshold:SetToolTipString(m_EraData.DarkAgeThresholdTooltip);
		Controls.NormalThreshold:SetText(m_EraData.DarkAgeThreshold .. " - " .. (m_EraData.GoldenAgeThreshold - 1));
		Controls.GoldenThreshold:SetText(m_EraData.GoldenAgeThreshold .. "+");
		Controls.GoldenThreshold:SetToolTipString(m_EraData.GoldenAgeThresholdTooltip);
		Controls.ThresholdStack:SetHide(false);
	end

	PopulateScoreBreakdown();

	Controls.EraEffects:SetText(m_EraData.AgeEffects);
end

-- ===========================================================================
function PopulateCivilizationIcons()

	m_CivilizationIconIM:ResetInstances();

	local gameEras:table = Game.GetEras();
	local localPlayer:table = Players[m_EraData.PlayerID];

	local heroicPlayers:table = {};
	local goldenPlayers:table = {};
	local normalPlayers:table = {};
	local darkPlayers:table = {};
	local unmetPlayers:table = {};

	local aPlayers = PlayerManager.GetAliveMajors();
	for _, pPlayer in ipairs(aPlayers) do
		local playerID:number = pPlayer:GetID();
		if(playerID ~= m_EraData.PlayerID) then
			if localPlayer and localPlayer:GetDiplomacy():HasMet(playerID) then
				if gameEras:HasHeroicGoldenAge(playerID) then
					table.insert(heroicPlayers, playerID);
				elseif gameEras:HasGoldenAge(playerID) then
					table.insert(goldenPlayers, playerID);
				elseif gameEras:HasDarkAge(playerID) then
					table.insert(darkPlayers, playerID);
				else
					table.insert(normalPlayers, playerID);
				end
			else
				table.insert(unmetPlayers, playerID);
			end
		end
	end

	for i,playerID in ipairs(heroicPlayers) do
		AddPlayerEraIcon(playerID, "[ICON_GLORY_SUPER_GOLDEN_AGE]");
	end
	for i,playerID in ipairs(goldenPlayers) do
		AddPlayerEraIcon(playerID, "[ICON_GLORY_GOLDEN_AGE]");
	end
	for i,playerID in ipairs(normalPlayers) do
		AddPlayerEraIcon(playerID, "[ICON_GLORY_NORMAL_AGE]");
	end
	for i,playerID in ipairs(darkPlayers) do
		AddPlayerEraIcon(playerID, "[ICON_GLORY_DARK_AGE]");
	end
	for i,playerID in ipairs(unmetPlayers) do
		AddPlayerEraIcon(playerID, "");
	end
end

-- ===========================================================================
function AddPlayerEraIcon(playerID:number, eraIcon:string)
	local civIcon, instance = CivilizationIcon:GetInstance(m_CivilizationIconIM);
	civIcon:UpdateIconFromPlayerID(playerID);
	civIcon:SetLeaderTooltip(playerID);
	civIcon:UpdateLeaderTooltip(playerID);
	instance.EraLabel:SetText(eraIcon);
end

-- ===========================================================================
function PopulateScoreBreakdown()
	m_ScoreBreakdownInstanceManager:ResetInstances();

	local hasAny = false;
	for i,breakdownTable in ipairs(m_EraData.ScoreBreakdown) do
		for scoreSource,scoreValue in pairs(breakdownTable) do
			if (scoreValue ~= 0) then
				local instance = m_ScoreBreakdownInstanceManager:GetInstance();
				TruncateStringWithTooltip(instance.ScoreBreakdownTitle, 350, scoreSource);
				instance.ScoreBreakdownValue:SetText(scoreValue);
				hasAny = true;
			end
		end
	end

	Controls.ScoreBreakdownStack:SetShow(hasAny);
end

-- ===========================================================================
function OnTopContainerSizeChanged()
	ResizeBottomScrollPanel();
end

-- ===========================================================================
function ResizeBottomScrollPanel()
	Controls.BottomScrollPanel:SetSizeY(Controls.BodyContainer:GetSizeY() - Controls.TopContainer:GetSizeY());
end

-- ===========================================================================
function PopulateLocalPlayerIcon()
	local pPlayer:table = Players[m_EraData.PlayerID];
	local pPlayerConfig:table = PlayerConfigurations[m_EraData.PlayerID];

	local backColor, frontColor = UI.GetPlayerColors(m_EraData.PlayerID);
	Controls.CivIndicator:SetColor(backColor);
	Controls.CivIcon:SetColor(frontColor);
	Controls.CivIcon:SetIcon("ICON_"..pPlayerConfig:GetCivilizationTypeName());
	Controls.LeaderPortrait:SetIcon("ICON_"..pPlayerConfig:GetLeaderTypeName());

	-- Set the tooltip
	if(pPlayerConfig ~= nil) then
		local leaderTypeName:string = pPlayerConfig:GetLeaderTypeName();
		if(leaderTypeName ~= nil) then
			local leaderDesc:string = pPlayerConfig:GetLeaderName();
			local civDesc:string = pPlayerConfig:GetCivilizationDescription();
			Controls.PlayerLeaderButton:LocalizeAndSetToolTip("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc);
		end
	end

	-- Team Ribbon
	local teamID:number = pPlayerConfig:GetTeam();
	if #Teams[teamID] > 1 then
		local teamRibbonName:string = TEAM_RIBBON_PREFIX .. tostring(teamID);
		Controls.TeamRibbon:SetIcon(teamRibbonName, TEAM_RIBBON_SIZE);
		Controls.TeamRibbon:SetHide(false);
		Controls.TeamRibbon:SetColor(GetTeamColor(teamID));
	else
		-- Hide team ribbon if team only contains one player
		Controls.TeamRibbon:SetHide(true);
	end
end

-- ===========================================================================
function Open()
	-- Ensure this panel is displayed below PartialScreenHooks
	-- This is done on Open() because LookUpControl can't always find PartialScreens during Initalization
	if ContextPtr:GetParent():GetID() ~= "PartialScreens" then
		local partialScreen:table = ContextPtr:LookUpControl( "/InGame/PartialScreens" );
		ContextPtr:ChangeParent(partialScreen);
		partialScreen:AddChildAtIndex(ContextPtr, 6);
	end

	-- dont show panel if there is no local player
	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID == -1) then
		return
	end

	m_AnimSupport.Show();
	Refresh();
	UI.PlaySound("CityStates_Panel_Open");
	LuaEvents.EraProgressPanel_Open();
end

-- ===========================================================================
function Close()	
    if not ContextPtr:IsHidden() then
        UI.PlaySound("CityStates_Panel_Close");
    end
	m_AnimSupport.Hide();
	LuaEvents.EraProgressPanel_Close();
end

-- ===========================================================================
function OnOpen()
	Open();
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
--	LUA Event
--	Explicit close (from partial screen hooks), part of closing everything,
-- ===========================================================================
function OnCloseAllExcept( contextToStayOpen:string )
	if contextToStayOpen == "EraProgressPanel" then 
		return; 
	end
	Close();
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		Close();
	end
end

-- ===========================================================================
--	Game Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		Close();
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["isHidden"] ~= nil and not contextTable["isHidden"] then			
			Open();
		end
	end
end

-- ===========================================================================
--	Input Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
	if (actionId == m_ToggleVisibilityAction) then
		if(ContextPtr:IsHidden()) then
			Open();
		else
			Close()
		end
	end
end

-- ===========================================================================
function OnPolicyChanged( ePlayer )
	if m_AnimSupport.IsVisible() and ePlayer == Game.GetLocalPlayer() then
		Refresh();
	end
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetHide(true);

	-- Control Events
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.TopContainer:RegisterSizeChanged( OnTopContainerSizeChanged );

	-- Lua Events
	LuaEvents.PartialScreenHooks_OpenEraProgressPanel.Add( OnOpen );
	LuaEvents.PartialScreenHooks_CloseEraProgressPanel.Add( OnClose );
	LuaEvents.PartialScreenHooks_CloseAllExcept.Add( OnCloseAllExcept );

	-- Animation Controller
	m_AnimSupport = CreateScreenAnimation(Controls.SlideAnim, Close);

	-- Rundown / Screen Events
	Events.SystemUpdateUI.Add(m_AnimSupport.OnUpdateUI);
	ContextPtr:SetInputHandler(m_AnimSupport.OnInputHandler, true);

	Controls.Title:SetText(Locale.ToUpper("LOC_ERA_PROGRESS_TITLE"));

	-- Game Engine Events	
	Events.GovernmentPolicyChanged.Add( OnPolicyChanged );
	Events.GovernmentPolicyObsoleted.Add( OnPolicyChanged );
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );

	-- Hot-Reload Events
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

	-- Hot Key Handling
    -- (not for XP1, we're on text lockdown and can't add what this really means)
	m_ToggleVisibilityAction = Input.GetActionId("ToggleEraProgress");
	if m_ToggleVisibilityAction ~= nil then
		Events.InputActionTriggered.Add( OnInputActionTriggered )
	end
end
Initialize();