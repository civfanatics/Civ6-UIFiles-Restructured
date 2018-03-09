--[[
-- Created by Tyler Berry, Aug 14 2017
-- Copyright (c) Firaxis Games
--]]
-- ===========================================================================
-- Base File
-- ===========================================================================
include("LaunchBar");

-- ===========================================================================
--	CONSTANTS: Keep these in sync with PrideMoments.lua
-- ===========================================================================
local MIN_INTEREST_LEVEL:number = 1; 
local PRIDE_MOMENT_HASH:number = DB.MakeHash("NOTIFICATION_PRIDE_MOMENT_RECORDED");

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_GovernorsInstance = {};
local m_GovernorsInstancePip = {};

local m_HistorianInstance = {};
local m_HistorianInstancePip = {};
local m_isGovernorPanelOpen:boolean = false;
local m_isHistoricMomentsOpen:boolean = false;

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_CloseAllPopups = CloseAllPopups;
BASE_OnInputActionTriggered = OnInputActionTriggered;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================
function OnProcessNotification(playerID:number, notificationID:number, activatedByUser:boolean)
	if playerID == Game.GetLocalPlayer() then -- Was it for us?
		local pNotification = NotificationManager.Find(playerID, notificationID);
		if pNotification and pNotification:GetType() == PRIDE_MOMENT_HASH then
			RealizeHookVisibility();
		end
	end
end

-- ===========================================================================
--	Input Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
	BASE_OnInputActionTriggered( actionId );

	-- Always available, so advanced players can plan their acquisitions
	if ( actionId == Input.GetActionId("ToggleGovernors") ) then
		ToggleGovernors();
	end
	
	-- Always available, so players can see the new feature compared to the base game
	if ( actionId == Input.GetActionId("ToggleTimeline") ) then
		ToggleHistoricMoments();
	end
end

function CloseAllPopups()
	BASE_CloseAllPopups();
	LuaEvents.GovernorPanel_Close();
	LuaEvents.HistoricMoments_Close();
end

-- ===========================================================================
function ToggleGovernors()
	if not m_isGovernorPanelOpen then
		CloseAllPopups();
	end
	LuaEvents.GovernorPanel_Toggle();
end

-- ===========================================================================
function ToggleHistoricMoments()
	if not m_isHistoricMomentsOpen then
		CloseAllPopups();
	end
	LuaEvents.PrideMoments_ToggleTimeline();	
end

function OnGovernorPanelOpened()
	m_isGovernorPanelOpen = true;
	OnOpen();
end

function OnGovernorPanelClosed()
	m_isGovernorPanelOpen = false;
	OnClose();
end

function OnHistoricMomentsOpened()
	m_isHistoricMomentsOpen = true;
	OnOpen();
end

function OnHistoricMomentsClosed()
	m_isHistoricMomentsOpen = false;
	OnClose();
end

-- ===========================================================================
function Initialize()
	Events.CivicCompleted.Add(RealizeHookVisibility);
	Events.NotificationActivated.Add(OnProcessNotification);

	ContextPtr:BuildInstanceForControl("LaunchBarItem", m_GovernorsInstance, Controls.ButtonStack );
	m_GovernorsInstance.LaunchItemButton:RegisterCallback(Mouse.eLClick, ToggleGovernors);
	m_GovernorsInstance.LaunchItemButton:SetTexture("LaunchBar_Hook_GovernorsButton");
	m_GovernorsInstance.LaunchItemButton:SetToolTipString(Locale.Lookup("LOC_HUD_LAUNCHBAR_GOVERNOR_BUTTON"));
	m_GovernorsInstance.LaunchItemIcon:SetTexture("LaunchBar_Hook_Governors");

	-- Add a pin to the stack for each new item
	ContextPtr:BuildInstanceForControl( "LaunchBarPinInstance", m_GovernorsInstancePip, Controls.ButtonStack );

	ContextPtr:BuildInstanceForControl("LaunchBarItem", m_HistorianInstance, Controls.ButtonStack );
	m_HistorianInstance.LaunchItemButton:RegisterCallback(Mouse.eLClick, ToggleHistoricMoments);
	m_HistorianInstance.LaunchItemButton:SetTexture("LaunchBar_Hook_TimelineButton");
	m_HistorianInstance.LaunchItemButton:SetToolTipString(Locale.Lookup("LOC_HUD_LAUNCHBAR_HISTORIAN_BUTTON"));
	m_HistorianInstance.LaunchItemIcon:SetTexture("LaunchBar_Hook_Timeline");
	
	-- Add a pin to the stack for each new item
	ContextPtr:BuildInstanceForControl( "LaunchBarPinInstance", m_HistorianInstancePip, Controls.ButtonStack );

	LuaEvents.GovernorPanel_Opened.Add( OnGovernorPanelOpened );
	LuaEvents.GovernorPanel_Closed.Add( OnGovernorPanelClosed );	
	LuaEvents.HistoricMoments_Opened.Add( OnHistoricMomentsOpened );
	LuaEvents.HistoricMoments_Closed.Add( OnHistoricMomentsClosed );	

	RefreshView();
end
Initialize();