--[[
-- Created by Samuel Batista on 11/30/2017
-- Copyright (c) Firaxis Games
--]]


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local NUM_PAGES = 9;

local INTRO_ILLUSTRATIONS:table = {
	"XP1Intro_Diagram_1",
	"XP1Intro_Diagram_2",
	"XP1Intro_Diagram_3",
	"XP1Intro_Diagram_4",
	"XP1Intro_Diagram_5",
	"XP1Intro_Diagram_6",
	"XP1Intro_Diagram_7",
	"XP1Intro_Diagram_8",
	"XP1Intro_Diagram_9",
};

local INTRO_DESCRIPTIONS:table = {
	"LOC_TUTORIAL_XP1_INTRO_WELCOME",
	"LOC_TUTORIAL_XP1_INTRO_ERAS",
	"LOC_TUTORIAL_XP1_INTRO_AGES",
	"LOC_TUTORIAL_XP1_INTRO_LOYALTY",
	"LOC_TUTORIAL_XP1_INTRO_GOVERNORS",
	"LOC_TUTORIAL_XP1_INTRO_ALLIANCES",
	"LOC_TUTORIAL_XP1_INTRO_EMERGENCIES",
	"LOC_TUTORIAL_XP1_INTRO_CITYBANNER",
	"LOC_TUTORIAL_XP1_INTRO_END",
};

local INTRO_DESCRIPTIONS_DETAILS:table = {
	"",
	"",--"LOC_TUTORIAL_XP1_INTRO_ERAS_DETAILS_1",
	"",--"LOC_TUTORIAL_XP1_INTRO_AGES_DETAILS",
	"",--"LOC_TUTORIAL_XP1_INTRO_LOYALTY_DETAILS",
	"",--"LOC_TUTORIAL_XP1_INTRO_GOVERNORS_DETAILS",
	"",--"LOC_TUTORIAL_XP1_INTRO_EMERGENCIES_DETAILS", --This key was incorrectly named, it actually gives details for Alliances. We cannot rename it currently due to text lock.
	"",
	"",
	"LOC_TUTORIAL_XP1_INTRO_END_DETAILS_1",
};

local NEXT_BUTTON_TEXT = Locale.Lookup("LOC_XP1_INTRO_NEXT");
local CONTINUE_BUTTON_TEXT = Locale.Lookup("LOC_XP1_INTRO_CONTINUE");

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_PageIndex:number = 1;

function Realize()
	Controls.Illustration:SetTexture(INTRO_ILLUSTRATIONS[m_PageIndex]);
	Controls.Description:SetText(Locale.Lookup(INTRO_DESCRIPTIONS[m_PageIndex]));

	-- Show detail screens or hide box if we don't have any for this page
	if INTRO_DESCRIPTIONS_DETAILS[m_PageIndex] ~= "" then
		Controls.FrameDeco:SetHide(false);
		Controls.Description2:SetText(Locale.Lookup(INTRO_DESCRIPTIONS_DETAILS[m_PageIndex]));
	else
		Controls.FrameDeco:SetHide(true);
	end

	Controls.Next:SetText(m_PageIndex == NUM_PAGES and CONTINUE_BUTTON_TEXT or NEXT_BUTTON_TEXT);
	Controls.Previous:SetHide(m_PageIndex == 1);
	Controls.ButtonStack:CalculateSize();
end

function OnShow()
	m_PageIndex = 1;
	Realize();
	ContextPtr:SetHide(false);
end

function OnShowFromMenu()
	OnShow();
	UIManager:QueuePopup(ContextPtr, PopupPriority.Current);
end

function OnClose()
	UIManager:DequeuePopup(ContextPtr);
	ContextPtr:SetHide(true);
end

function OnNext()
	if m_PageIndex >= NUM_PAGES then
		OnClose();
	else
		m_PageIndex = math.min(m_PageIndex + 1, NUM_PAGES);
		Realize();
	end
end

function OnPrevious()
	m_PageIndex = math.max(1, m_PageIndex - 1);
	Realize();
end

function OnLoadGameViewStateDone()

	local hasSeenXP1FeaturesScreen =  Options.GetUserOption("Tutorial", "HasSeenXP1FeaturesScreen");
	local showScreen = (UserConfiguration.TutorialLevel() == TutorialLevel.LEVEL_NEW_TO_XP1  or hasSeenXP1FeaturesScreen == 0);
	if showScreen and Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then
		Options.SetUserOption("Tutorial", "HasSeenXP1FeaturesScreen", 1);
		Options.SaveOptions();
		OnShow();
	end
end

function OnInput( pInputStruct:table )
	local key = pInputStruct:GetKey();
	local type = pInputStruct:GetMessageType();
	if type == KeyEvents.KeyUp and key == Keys.VK_ESCAPE then 
		HideIfVisible();
	end
	return true; -- consume all input
end

function HideIfVisible()
	if ContextPtr:IsVisible() then
		OnClose();
	end
end

function Initialize()
	

	ContextPtr:SetHide(true);
	ContextPtr:SetInputHandler( OnInput, true );

	Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.Next:RegisterCallback(Mouse.eLClick, OnNext);
	Controls.Previous:RegisterCallback(Mouse.eLClick, OnPrevious);
	
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );

	LuaEvents.ExpansionIntro_Show.Add( OnShowFromMenu );
	LuaEvents.DiplomacyActionView_HideIngameUI.Add( HideIfVisible );
end
Initialize();