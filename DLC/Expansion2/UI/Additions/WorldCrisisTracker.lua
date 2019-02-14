--	Copyright 2017-2018, Firaxis Games
include("InstanceManager");
include("CivilizationIcon");
include("SupportFunctions");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local COLOR_TARGETED_PRIMARY = RGBAValuesToABGRHex		(	 1,	.176, .207,	1);
local COLOR_TARGETED_SECONDARY = RGBAValuesToABGRHex	( .384, .411, .447, 1);
local COLOR_JOINED_PRIMARY = RGBAValuesToABGRHex		( .835, .835, .835, 1);
local COLOR_JOINED_SECONDARY = RGBAValuesToABGRHex		( .384, .411, .447, 1);
local COLOR_INVITED_PRIMARY = RGBAValuesToABGRHex		( .415, .427, .450, 1);
local COLOR_INVITED_SECONDARY = RGBAValuesToABGRHex		( .415, .427, .450, 1);


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_CrisisIM :table = InstanceManager:new( "CrisisInstance", "RootControl", Controls.CrisisStack);


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-- ===========================================================================
function Realize()
	m_CrisisIM:ResetInstances();
	local playerID = Game.GetLocalPlayer();
	local crisisData = Game.GetEmergencyManager():GetEmergencyInfoTable(playerID);

	for _, crisis in ipairs(crisisData) do
		local crisisInstance:table = m_CrisisIM:GetInstance();

		local MAX_BEFORE_TEXT_TRUNC:number = 200;
		TruncateStringWithTooltip(crisisInstance.CrisisTitle, MAX_BEFORE_TEXT_TRUNC, Locale.ToUpper(Locale.Lookup(crisis.NameText)))
		
		local goalsCompleted:number = 0;
		local goalsTotal:number = 0;
		for _, goal in ipairs(crisis.GoalsTable) do
			goalsTotal = goalsTotal + 1;
			goalsCompleted = goal.Completed and goalsCompleted + 1 or goalsCompleted;
		end

		if ( crisis.HasBegun) then
			local progressString:string = goalsTotal > 0 and "(" .. goalsCompleted .. "/" .. goalsTotal .. ") " or "";
			crisisInstance.CrisisProgress:SetText(crisis.TargetID ~= playerID and (progressString .. crisis.ShortGoalDescription) or ("(" .. goalsTotal - goalsCompleted .. "/" .. goalsTotal .. ") " .. crisis.TargetShortGoalDescription));
		else
			crisisInstance.CrisisProgress:SetText(Locale.Lookup("LOC_EMERGENCY_PENDING_SHORT_DESCRIPTION"));
		end
		crisisInstance.TurnsRemaining:SetText(crisis.TurnsLeft .. "[ICON_Turn]");

		--Register click
		local boxedCrisis:table = crisis;
		crisisInstance.MainPanel:RegisterCallback(Mouse.eLClick, function()
			LuaEvents.WorldCrisisTracker_EmergencyClicked(boxedCrisis.TargetID, boxedCrisis.EmergencyType);
		end);

		--Set target
		local kEmergencyDefinition:table = GameInfo.EmergencyAlliances[boxedCrisis.EmergencyType];
		local kEmergencyMetadata:table = GameInfo.Emergencies_XP2[kEmergencyDefinition.EmergencyType];
		local bIsHostile:boolean = kEmergencyMetadata.Hostile;
		local bNoTarget:boolean = kEmergencyMetadata.NoTarget;

		if bNoTarget then
			crisisInstance.CivilizationTargetIcon.CivIconBacking:SetHide(true);
			crisisInstance.NoTargetIcon:SetHide(false);
			crisisInstance.NoTargetIcon:SetIcon("ICON_" .. GameInfo.EmergencyAlliances[boxedCrisis.EmergencyType].EmergencyType);
		else
			local ownerController = CivilizationIcon:AttachInstance(crisisInstance.CivilizationTargetIcon);
			ownerController:UpdateIconFromPlayerID(crisis.TargetID);
			ownerController:SetLeaderTooltip(crisis.TargetID);
			crisisInstance.CivilizationTargetIcon.CivIconBacking:SetHide(false);
		end

		--Set hostility target
		crisisInstance.TargetIcon:SetShow(bIsHostile);

		--Set completed
		if (crisis.TurnsLeft < 0) then
			local endIcon:string = "EmergenciesPanel_EndFail";
			if (goalsCompleted == goalsTotal and crisis.TargetID ~= playerID) or 
				(crisis.TargetID == playerID and goalsCompleted ~= goalsTotal) or
				(crisis.TargetID == playerID and not bIsHostile) then 
					endIcon = "EmergenciesPanel_EndWin";
			end
			crisisInstance.CompletedBox:SetTexture(endIcon);
			crisisInstance.TurnsRemaining:SetText("");
			crisisInstance.CompletedBox:SetHide(false);
		else
			crisisInstance.CompletedBox:SetHide(true);
		end

		--Set the mode of the crisis
		if crisis.TargetID == playerID then
			if bIsHostile then
				crisisInstance.MainPanel:SetTexture("EmergenciesPanel_Frame_Targeted");
				crisisInstance.CrisisTitle:SetColor(COLOR_TARGETED_PRIMARY);
				crisisInstance.CrisisProgress:SetColor(COLOR_TARGETED_SECONDARY);
			else
				crisisInstance.MainPanel:SetTexture("EmergenciesPanel_Frame_Targeted_Aid");
				crisisInstance.CrisisTitle:SetColor(COLOR_JOINED_PRIMARY);
				crisisInstance.CrisisProgress:SetColor(COLOR_JOINED_SECONDARY);
			end
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

-- ===========================================================================
function OnEmergencyEvent()
	Realize();
end

-- ===========================================================================
--	Initialize
-- ===========================================================================
function Initialize()
	ContextPtr:SetHide(false);
	ContextPtr:SetAutoSize(true);

	--Events
	Events.EmergencyAvailable.Add( OnEmergencyEvent );
	Events.EmergenciesUpdated.Add( OnEmergencyEvent );
	Events.EmergencyRejected.Add( OnEmergencyEvent );
	Events.LocalPlayerChanged.Add( OnEmergencyEvent );
	
	Realize();
end
Initialize();