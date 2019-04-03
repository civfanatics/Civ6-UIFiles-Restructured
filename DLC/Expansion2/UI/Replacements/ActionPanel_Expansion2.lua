-- Copyright 2018-2019, Firaxis Games

-- ===========================================================================
-- INCLUDES
-- ===========================================================================
include("ActionPanel_Expansion1.lua");

-- ===========================================================================
--	Overrides
-- ===========================================================================
XP1_AllowAutoEndTurn_Expansion = AllowAutoEndTurn_Expansion;
XP1_LateInitialize = LateInitialize;
XP1_OnTurnBegin = OnTurnBegin;


-- ===========================================================================
--	GLOBALS (mix-ins)
-- ===========================================================================
g_kMessageInfo[EndTurnBlockingTypes.ENDTURN_BLOCKING_WORLD_CONGRESS_LOOK]		= {Message = specialSessionLookString,		ToolTip = specialSessionLookTooltip	, Icon="ICON_NOTIFICATION_WORLD_CONGRESS"	};
g_kMessageInfo[EndTurnBlockingTypes.ENDTURN_BLOCKING_WORLD_CONGRESS_SESSION]	= {Message = congressBlockingString,		ToolTip = congressBlockingTooltip	, Icon="ICON_NOTIFICATION_WORLD_CONGRESS"	};


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local specialSessionLookString	:string = Locale.Lookup("LOC_ACTION_PANEL_WORLD_CONGRESS_SPECIAL_SESSION");
local specialSessionLookTooltip	:string = Locale.Lookup("LOC_ACTION_PANEL_WORLD_CONGRESS_SPECIAL_SESSION_TOOLTIP");
local congressBlockingString	:string = Locale.Lookup("LOC_RESUME_CONGRESS");
local congressBlockingTooltip	:string = Locale.Lookup("LOC_RESUME_CONGRESS");


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_CongressIsInSession		:boolean = false;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function OnTurnBegin()
	local pWorldCongress:table = Game.GetWorldCongress();
	m_CongressIsInSession = pWorldCongress:IsInSession();
	XP1_OnTurnBegin();
end

-- ===========================================================================
function AllowAutoEndTurn_Expansion()
	-- Disable AutoEndTurn while World Congress is in session.
	if m_CongressIsInSession then
		return false;
	end
	return true;
end


-- ===========================================================================
function LateInitialize()
	local pWorldCongress:table = Game.GetWorldCongress();
	m_CongressIsInSession = pWorldCongress:IsInSession();

	XP1_LateInitialize();
end
