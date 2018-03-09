--[[
-- Created by Tyler Berry, Aug 17 2017
-- Copyright (c) Firaxis Games
--]]
include("InstanceManager");
include("CivilizationIcon");

-- ===========================================================================
-- Constants
-- ===========================================================================
local COLOR_TARGETED_PRIMARY = RGBAValuesToABGRHex		(	 1,	.176, .207,	1);
local COLOR_TARGETED_SECONDARY = RGBAValuesToABGRHex	( .384, .411, .447, 1);
local COLOR_JOINED_PRIMARY = RGBAValuesToABGRHex		( .835, .835, .835, 1);
local COLOR_JOINED_SECONDARY = RGBAValuesToABGRHex		( .384, .411, .447, 1);
local COLOR_INVITED_PRIMARY = RGBAValuesToABGRHex		( .415, .427, .450, 1);
local COLOR_INVITED_SECONDARY = RGBAValuesToABGRHex		( .415, .427, .450, 1);


-- ===========================================================================
-- Instant Managers
-- ===========================================================================
local m_CrisisInstManager = InstanceManager:new( "CrisisInstance", "RootControl", Controls.CrisisStack);

function OnTurnBegin()
	m_CrisisInstManager:ResetInstances();
	local playerID = Game.GetLocalPlayer();
	local crisisData = Game.GetEmergencyManager():GetEmergencyInfoTable(playerID);

	--TODO: Test this and fill with living data
	for _, crisis in ipairs(crisisData) do
		local crisisInstance:table = m_CrisisInstManager:GetInstance();
		crisisInstance.CrisisTitle:SetText(Locale.ToUpper(crisis.NameText));
		
		local goalsCompleted:number = 0;
		local goalsTotal:number = 0;
		for _, goal in ipairs(crisis.GoalsTable) do
			goalsTotal = goalsTotal + 1;
			goalsCompleted = goal.Completed and goalsCompleted + 1 or goalsCompleted;
		end

		if ( crisis.HasBegun) then
			crisisInstance.CrisisProgress:SetText(crisis.TargetID ~= playerID and ("(" .. goalsCompleted .. "/" .. goalsTotal .. ") " .. crisis.ShortGoalDescription) or ("[" .. goalsTotal - goalsCompleted .. "/" .. goalsTotal .. "] " .. crisis.TargetShortGoalDescription));
		else
			crisisInstance.CrisisProgress:SetText(Locale.Lookup("LOC_EMERGENCY_PENDING_SHORT_DESCRIPTION"));
		end
		crisisInstance.TurnsRemaining:SetText(crisis.TurnsLeft .. "[ICON_Turn]");

		--Register click
		local boxedCrisis:table = crisis;
		crisisInstance.MainPanel:RegisterCallback(Mouse.eLClick, function()
			LuaEvents.EmergencyClicked(boxedCrisis.TargetID, boxedCrisis.EmergencyType);
		end);

		--Set target
		local ownerController = CivilizationIcon:AttachInstance(crisisInstance.CivilizationTargetIcon);
		ownerController:UpdateIconFromPlayerID(crisis.TargetID);
		ownerController:SetLeaderTooltip(crisis.TargetID);

		--Set completed
		if (crisis.TurnsLeft < 0) then
			crisisInstance.CompletedBox:SetTexture(((goalsCompleted == goalsTotal and crisis.TargetID ~= playerID) or (crisis.TargetID == playerID and goalsCompleted ~= goalsTotal)) and "EmergenciesPanel_EndWin" or "EmergenciesPanel_EndFail");
			crisisInstance.TurnsRemaining:SetText("");
			crisisInstance.CompletedBox:SetHide(false);
		else
			crisisInstance.CompletedBox:SetHide(true);
		end

		--Set the mode of the crisis
		if crisis.TargetID == playerID then
			crisisInstance.MainPanel:SetTexture("EmergenciesPanel_Frame_Targeted");
			crisisInstance.CrisisTitle:SetColor(COLOR_TARGETED_PRIMARY);
			crisisInstance.CrisisProgress:SetColor(COLOR_TARGETED_SECONDARY);
		elseif crisis.HasBegun then
			crisisInstance.MainPanel:SetTexture("EmergenciesPanel_Frame_Joined");
			crisisInstance.CrisisTitle:SetColor(COLOR_JOINED_PRIMARY);
			crisisInstance.CrisisProgress:SetColor(COLOR_JOINED_SECONDARY);
		else
			crisisInstance.MainPanel:SetTexture("EmergenciesPanel_Frame_Invited");
			crisisInstance.CrisisTitle:SetColor(COLOR_INVITED_PRIMARY);
			crisisInstance.CrisisProgress:SetColor(COLOR_INVITED_SECONDARY);
		end
	end
end

function Initialize()
	ContextPtr:SetHide(false);
	ContextPtr:SetAutoSize(true);

	--Events
	Events.EmergencyAvailable.Add(OnTurnBegin);
	Events.EmergenciesUpdated.Add(OnTurnBegin);
	Events.EmergencyRejected.Add(OnTurnBegin);
	Events.LocalPlayerChanged.Add(OnTurnBegin);
	OnTurnBegin();
end
Initialize();