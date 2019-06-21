-- ===========================================================================
--	Reports List
--
--	Listing of reports screens.
-- ===========================================================================

include("InstanceManager");
include("Civ6Common");
include("GameCapabilities");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local BACKGROUND_SIZE_PADDING:number = 54;

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_ReportButtonIM	:table = InstanceManager:new("ReportButtonInstance", "Button");


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function Close()
    if not ContextPtr:IsHidden() then
        UI.PlaySound("CityStates_Panel_Close");
    end
	ContextPtr:SetHide(true);
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnOpen()
	Controls.EmpireReportsStack:CalculateSize();
	Controls.GlobalReportsStack:CalculateSize();
	Controls.MainStack:CalculateSize();
	Controls.Background:SetSizeY(Controls.MainStack:GetSizeY() + BACKGROUND_SIZE_PADDING);
	ContextPtr:SetHide(false);
end

-- ===========================================================================
--	LUA Event
--	Explicit close (from partial screen hooks), part of closing everything,
-- ===========================================================================
function OnCloseAllExcept( contextToStayOpen:string )
	if contextToStayOpen == ContextPtr:GetID() then return; end
	Close();
end

-- ===========================================================================
function OnRaiseCityStatusReport()
	LuaEvents.ReportsList_OpenCityStatus();
end

-- ===========================================================================
function OnRaiseYieldsReport()
	LuaEvents.ReportsList_OpenYields();
end

-- ===========================================================================
function OnRaiseResourcesReport()
	LuaEvents.ReportsList_OpenResources();
end

-- ===========================================================================
function OnRaiseGlobalResourcesReport()
	LuaEvents.GlobalReportsList_OpenResources();
end

-- ===========================================================================
function OnRaiseGossipReport()
	LuaEvents.ReportsList_OpenGossip();
end

-- ===========================================================================
function AddReport( name:string, callback:ifunction, parentControl:table )
	local buttonInst:table = m_ReportButtonIM:GetInstance(parentControl);
	local label:string = Locale.Lookup(name);
	buttonInst.Button:SetText( label );
	buttonInst.Button:RegisterCallback(Mouse.eLClick, callback );
end

-- ===========================================================================
function LateInitialize()	
	m_ReportButtonIM:ResetInstances();
	AddReport("LOC_PARTIALSCREEN_REPORTS_YIELDS",			OnRaiseYieldsReport,			Controls.EmpireReportsStack );
	AddReport("LOC_PARTIALSCREEN_REPORTS_RESOURCES",		OnRaiseResourcesReport,			Controls.EmpireReportsStack );
	AddReport("LOC_PARTIALSCREEN_REPORTS_CITY_STATUS",		OnRaiseCityStatusReport,		Controls.EmpireReportsStack );
	if GameCapabilities.HasCapability("CAPABILITY_GOSSIP_REPORT") then
		AddReport("LOC_PARTIALSCREEN_REPORTS_GOSSIP",			OnRaiseGossipReport,		Controls.EmpireReportsStack );
	end
	
	
	-- Only add global resources if this game mode allows trade.
	if (HasCapability("CAPABILITY_DIPLOMACY_DEALS")) then
		AddReport("LOC_PARTIALSCREEN_REPORTS_RESOURCES",	OnRaiseGlobalResourcesReport,	Controls.GlobalReportsStack );		
	end
	Controls.GlobalTitle:SetHide( not HasCapability("CAPABILITY_DIPLOMACY_DEALS"));
end

-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		local uiKey = pInputStruct:GetKey();
		if uiKey == Keys.VK_ESCAPE then
			Close();
			return true;
		end		
	end
	return false;
end

-- ===========================================================================
--	Initialize
-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	
	LuaEvents.PartialScreenHooks_OpenReportsList.Add( OnOpen );
	LuaEvents.PartialScreenHooks_CloseAllExcept.Add( OnCloseAllExcept );
	LuaEvents.PartialScreenHooks_CloseReportsList.Add( OnClose );
end
Initialize();
