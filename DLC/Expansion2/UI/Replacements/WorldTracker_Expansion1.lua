-- Copyright 2017-2019, Firaxis Games

include("WorldTracker");
include("AllianceResearchSupport");


-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_LateInitialize = LateInitialize;
BASE_UpdateResearchPanel = UpdateResearchPanel;
BASE_RealizeCurrentResearch = RealizeCurrentResearch;
BASE_ShouldUpdateResearchPanel = ShouldUpdateResearchPanel;
BASE_Subscribe = Subscribe;
BASE_Unsubscribe = Unsubscribe;

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local EMERGENCY_SIZE : number = 44;

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function UpdateResearchPanel( isHideResearch:boolean )
	CalculateAllianceResearchBonus();
	BASE_UpdateResearchPanel(isHideResearch);
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function RealizeCurrentResearch( playerID:number, kData:table, uiControl:table )

	BASE_RealizeCurrentResearch(playerID, kData, uiControl);

	-- If an instance is not passed in, remap to Context's main control table.
	if uiControl == nil then
		uiControl = Controls;
	end

	local showAllianceIcon :boolean = false;
	if kData ~= nil then
		local techID = GameInfo.Technologies[kData.TechType].Index;
		if AllyHasOrIsResearchingTech(techID) then
			uiControl.AllianceIcon:SetToolTipString(GetAllianceIconToolTip());
			uiControl.AllianceIcon:SetColor(GetAllianceIconColor());
			showAllianceIcon = true;
		end
	end
	uiControl.Alliance:SetShow( showAllianceIcon );
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function ShouldUpdateResearchPanel(ePlayer:number, eTech:number)
	return BASE_ShouldUpdateResearchPanel(ePlayer, eTech) or HasMaxLevelResearchAlliance(ePlayer);
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function RealizeEmptyMessage()
	local kCrisisData :table = Game.GetEmergencyManager():GetEmergencyInfoTable(Game.GetLocalPlayer());
	if( IsChatHidden() and IsCivicsHidden() and IsResearchHidden() and next(kCrisisData) == nil) then
		Controls.EmptyPanel:SetHide(false);
	else
		Controls.EmptyPanel:SetHide(true);
	end
end

-- ===========================================================================
function OnSetNumberOfEmergencies(numEmergencies : number)
	if(numEmergencies > 0)then
		Controls.OtherContainer:SetHide(false);
		Controls.OtherContainer:SetSizeY(numEmergencies * EMERGENCY_SIZE)
	else
		Controls.OtherContainer:SetHide(true);
	end
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function Subscribe()
	BASE_Subscribe();

	LuaEvents.WorldTracker_SetEmergencies.Add( OnSetNumberOfEmergencies );
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function Unsubscribe()
	BASE_Unsubscribe();

	LuaEvents.WorldTracker_SetEmergencies.Remove( OnSetNumberOfEmergencies );
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function LateInitialize()
	BASE_LateInitialize();
	
	ContextPtr:LoadNewContext("WorldCrisisTracker", Controls.OtherContainer);
	Controls.TutorialGoals:SetHide(true);
	Controls.PanelStack:CalculateSize();
end
