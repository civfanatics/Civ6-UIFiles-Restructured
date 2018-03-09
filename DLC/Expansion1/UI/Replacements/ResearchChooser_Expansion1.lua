-- ===========================================================================
--	ResearchChooser Replacement
--	Civilization VI, Firaxis Games
-- ===========================================================================
include("ResearchChooser");
include("AllianceResearchSupport");

-- ===========================================================================
--	LOCAL VARS / CONSTS
-- ===========================================================================
local MAX_ALLIANCE_LEVEL = 3;

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_View = View;
BASE_AddAvailableResearch = AddAvailableResearch;
BASE_RealizeCurrentResearch = RealizeCurrentResearch;
BASE_ShouldRefreshWhenResearchChanges = ShouldRefreshWhenResearchChanges;

-- ===========================================================================
--	OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function View( playerID:number, kData:table )
	CalculateAllianceResearchBonus();
	BASE_View(playerID, kData);
end

function RealizeCurrentResearch( playerID:number, kData:table, kControl:table )
	BASE_RealizeCurrentResearch(playerID, kData, kControl);

	if kControl == nil then
		kControl = Controls;
	end

	local showAllianceIcon = false;
	if kData then
		local techID = GameInfo.Technologies[kData.TechType].Index;
		if AllyHasOrIsResearchingTech(techID) then
			kControl.AllianceIcon:SetToolTipString(GetAllianceIconToolTip());
			kControl.AllianceIcon:SetColor(GetAllianceIconColor());
			showAllianceIcon = true;
		end
	end
	kControl.Alliance:SetShow(showAllianceIcon);
end

function AddAvailableResearch( playerID:number, kData:table )
	local kControl = BASE_AddAvailableResearch(playerID, kData);

	if kData then
		local techID = GameInfo.Technologies[kData.TechType].Index;
		if AllyHasOrIsResearchingTech(techID) then
			kControl.AllianceIcon:SetToolTipString(GetAllianceIconToolTip());
			kControl.AllianceIcon:SetColor(GetAllianceIconColor());
			kControl.Alliance:SetHide(false);
		else
			kControl.Alliance:SetHide(true);
		end
	end
end

function ShouldRefreshWhenResearchChanges(ePlayer:number)
	return BASE_ShouldRefreshWhenResearchChanges(ePlayer) or HasMaxLevelResearchAlliance(ePlayer);
end