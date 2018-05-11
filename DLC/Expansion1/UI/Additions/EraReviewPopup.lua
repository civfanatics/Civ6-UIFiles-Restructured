--[[
-- Created by Samuel Batista on Friday Apr 19 2017
-- Copyright (c) Firaxis Games
--]]

include("ControlsManager");
include("InstanceManager");
include("SupportFunctions");
include("CivilizationIcon");
include("TeamSupport");
include("EraSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "EraReviewPopup"; -- Must be unique (usually the same as the file name)
local DEFAULT_HEADER_HEIGHT:number = 220;
local DEFAULT_CONTENTS_HEIGHT:number = 349;

local ERA_ILLUSTRATIONS:table = {
	"Moment_EraEntry_Classical",
	"Moment_EraEntry_Medieval",
	"Moment_EraEntry_Renaissance",
	"Moment_EraEntry_Industrial",
	"Moment_EraEntry_Modern",
	"Moment_EraEntry_Atomic",
	"Moment_EraEntry_Information",
};

local TEAM_RIBBON_PREFIX:string = "ICON_TEAM_RIBBON_";
local TEAM_RIBBON_SIZE:number = 53;

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_LocalPlayerID:number = -1;
local m_PreviousEraIndex:number = -1;
local m_CurrentEraIndex:number = -1;

local m_CivilizationIconIM:table = InstanceManager:new("CivilizationIconAge", "CivIconBacking", Controls.CivIconStack);

function OnGameEraChanged(prevEraIndex:number, newEraIndex:number)
	--If prevEra is -1 we just started a fresh game
	if prevEraIndex == -1 then
		return;
	end

	m_LocalPlayerID = Game.GetLocalPlayer();
	if m_LocalPlayerID < 0 then return; end

	m_PreviousEraIndex = prevEraIndex;
	m_CurrentEraIndex = newEraIndex;

	Controls.Title:SetText(Locale.ToUpper(Locale.Lookup("LOC_ERA_REVIEW_POPUP_TITLE", GameInfo.Eras[m_CurrentEraIndex].Name)));
	Controls.EraImage:SetTexture(ERA_ILLUSTRATIONS[m_CurrentEraIndex]);

	local gameEras:table = Game.GetEras();
	local score	= gameEras:GetPlayerCurrentScore(m_LocalPlayerID);
	local prevGoldenAgeThreshold = gameEras:GetPlayerPreviousGoldenAgeThreshold(m_LocalPlayerID);

	if gameEras:HasHeroicGoldenAge(m_LocalPlayerID) then
		Controls.EraRibbon:SetTexture("Ages_BannerLongHeroic");
		Controls.Background:SetTexture("Ages_ParchmentHeroic");
		Controls.WindowFrame:SetTexture("Ages_FrameHeroic");
		Controls.EraRibbonText:SetColorByName("Black");
		Controls.EraRibbonValue:SetColorByName("Black");
		Controls.HeroicFlare:SetHide(false);
		Controls.EraRibbonValue:SetText(Locale.Lookup("LOC_ERAS_HEROIC") .. " [ICON_GLORY_SUPER_GOLDEN_AGE]");
		Controls.EraEffects:SetText(Locale.Lookup("LOC_ERA_REVIEW_HAVE_HEROIC_AGE_EFFECT"));
	elseif gameEras:HasGoldenAge(m_LocalPlayerID) then
		Controls.EraRibbon:SetTexture("Ages_BannerLongGolden");
		Controls.Background:SetTexture("Ages_ParchmentGolden");
		Controls.WindowFrame:SetTexture("Ages_FrameGolden");
		Controls.EraRibbonText:SetColorByName("White_Black");
		Controls.EraRibbonValue:SetColorByName("White_Black");
		Controls.HeroicFlare:SetHide(true);
		Controls.EraRibbonValue:SetText(Locale.Lookup("LOC_ERAS_GOLDEN") .. " [ICON_GLORY_GOLDEN_AGE]");
		Controls.EraEffects:SetText(Locale.Lookup("LOC_ERA_REVIEW_HAVE_GOLDEN_AGE_EFFECT"));
	elseif gameEras:HasDarkAge(m_LocalPlayerID) then
		Controls.EraRibbon:SetTexture("Ages_BannerLongDark");
		Controls.Background:SetTexture("Ages_ParchmentDark");
		Controls.WindowFrame:SetTexture("Ages_FrameDark");
		Controls.EraRibbonText:SetColorByName("White_Black");
		Controls.EraRibbonValue:SetColorByName("White_Black");
		Controls.HeroicFlare:SetHide(true);
		Controls.EraRibbonValue:SetText(Locale.Lookup("LOC_ERAS_DARK") .. " [ICON_GLORY_DARK_AGE]");
		Controls.EraEffects:SetText(Locale.Lookup("LOC_ERA_REVIEW_HAVE_DARK_AGE_EFFECT"));
	else
		Controls.EraRibbon:SetTexture("Ages_BannerLongNormal");
		Controls.Background:SetTexture("Ages_ParchmentNormal");
		Controls.WindowFrame:SetTexture("Ages_FrameNormal");
		Controls.EraRibbonText:SetColorByName("White_Black");
		Controls.EraRibbonValue:SetColorByName("White_Black");
		Controls.HeroicFlare:SetHide(true);
		Controls.EraRibbonValue:SetText(Locale.Lookup("LOC_ERAS_NORMAL") .. " [ICON_GLORY_NORMAL_AGE]");
		Controls.EraEffects:SetText(Locale.Lookup("LOC_ERA_REVIEW_HAVE_NORMAL_AGE_EFFECT"));
	end

	PopulateLocalPlayerIcon();
	PopulateCivilizationIcons();

	OnShow();
end

-- Largely copied from DiplomacyRibbon.lua
function PopulateLocalPlayerIcon()

	local pPlayer:table = Players[m_LocalPlayerID];
	local pPlayerConfig:table = PlayerConfigurations[m_LocalPlayerID];

	local backColor, frontColor = UI.GetPlayerColors(m_LocalPlayerID);
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

-- Largely copied from WorldRankings.lua
function PopulateCivilizationIcons()

	m_CivilizationIconIM:ResetInstances();

	local gameEras:table = Game.GetEras();
	local localPlayer:table = Players[m_LocalPlayerID];

	local heroicPlayers:table = {};
	local goldenPlayers:table = {};
	local normalPlayers:table = {};
	local darkPlayers:table = {};
	local unmetPlayers:table = {};

	local aPlayers = PlayerManager.GetAliveMajors();
	for _, pPlayer in ipairs(aPlayers) do
		local playerID:number = pPlayer:GetID();
		if(playerID ~= m_LocalPlayerID) then
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

function sortBreakdown(a,b) 
	local _, aVal = next(a);
	local _, bVal = next(b);
	local result = aVal > bVal;
	return result;
end

function sortBreakdownInverse(a,b)
	local _, aVal = next(a);
	local _, bVal = next(b);
	local result = aVal < bVal;
	return result;
end

function OnShow()
	UIManager:QueuePopup(ContextPtr, PopupPriority.High);
end

function OnClose()
	UIManager:DequeuePopup(ContextPtr);
end

function OnContinue()
	UIManager:DequeuePopup(ContextPtr);
	LuaEvents.DedicationPopup_Show(m_PreviousEraIndex, m_CurrentEraIndex);
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload then		
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);	
	end
end
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_PreviousEraIndex", m_PreviousEraIndex);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_CurrentEraIndex", m_CurrentEraIndex);
end
function OnGameDebugReturn(context:string, reloadState:table)
	if context == RELOAD_CACHE_ID then
		if not reloadState.isHidden then
			OnGameEraChanged(reloadState.m_PreviousEraIndex, reloadState.m_CurrentEraIndex);
		end
	end
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	if ( pInputStruct:GetMessageType() == KeyEvents.KeyUp ) then
		local key:number = pInputStruct:GetKey();
		if ( key == Keys.VK_ESCAPE ) then
			OnClose();
		end
	end
	-- Intercept all input while on this screen (is modal)
	return true;
end

function Initialize()
	--OnGameEraChanged(0, 1); -- DEBUG
	ContextPtr:SetHide(true); -- PRODUCTION

	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );

	Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.Continue:RegisterCallback(Mouse.eLClick, OnContinue);

	LuaEvents.EraReviewPopup_Show.Add(OnGameEraChanged);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
end
Initialize();