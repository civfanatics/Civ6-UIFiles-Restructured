-- Copyright 2017-2018, Firaxis Games

-- ===========================================================================
-- Base File
-- ===========================================================================
include("CityPanelOverview_Expansion1");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
XP1_HideAll = HideAll;
XP1_View = View;
XP1_LateInitialize = LateInitialize;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_PowerPanel			:table = nil;
local m_PowerButtonInstance :table = nil;
local m_ToolTip				:string = "LOC_HUD_CITY_POWER_TOOLTIP";


-- ===========================================================================
function HideAll()
	XP1_HideAll();
	if m_PowerButtonInstance then
		m_PowerButtonInstance.Button:SetSelected(false);
		m_PowerButtonInstance.Icon:SetColorByName("White");
		if m_PowerPanel then
			m_PowerPanel:SetHide(true);
		end
	end
end

-- ===========================================================================
function View(data)
	XP1_View(data);
	if GetSelectedTabButton() == m_PowerButtonInstance.Button then
		RefreshPowerPanel();
	end
end

-- ===========================================================================
function RefreshPowerPanel()
	LuaEvents.CityPanelTabRefresh();
end

-- ===========================================================================
function OnTogglePowerTab()
	if m_PowerButtonInstance then
		ToggleOverviewTab(m_PowerButtonInstance.Button);
	end
end

-- ===========================================================================
function OnSelectPowerTab()
	HideAll();
			
	-- Context has to be shown before CityPanelTabRefresh to ensure a proper Refresh
	m_PowerPanel:SetHide(false);

	m_PowerButtonInstance.Button:SetSelected(true);
	m_PowerButtonInstance.Icon:SetColorByName("DarkBlue");
	UI.PlaySound("UI_CityPanel_ButtonClick");
	Controls.PanelDynamicTab:SetHide(false);
			
	RefreshPowerPanel();
end

-- ===========================================================================
function LateInitialize()
	XP1_LateInitialize();

	m_PowerPanel = ContextPtr:LoadNewContext("CityPanelPower", Controls.PanelDynamicTab);
	m_PowerPanel:SetSizeX(Controls.PanelDynamicTab:GetSizeX());
	m_PowerPanel:SetSizeY(Controls.PanelDynamicTab:GetSizeY());
	LuaEvents.CityPanel_ToggleOverviewPower.Add( OnTogglePowerTab );

	m_PowerButtonInstance = GetTabButtonInstance();
	m_PowerButtonInstance.Icon:SetIcon("ICON_STAT_POWER");
	m_PowerButtonInstance.Button:SetToolTipString(Locale.Lookup(m_ToolTip));

	AddTab(m_PowerButtonInstance.Button, OnSelectPowerTab );
end
