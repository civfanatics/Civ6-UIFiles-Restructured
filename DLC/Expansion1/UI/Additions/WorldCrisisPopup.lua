--[[
-- Created by Tyler Berry on Friday July 26 2017
-- Copyright (c) Firaxis Games
--]]

include("InstanceManager");
include("LeaderIcon");
include("CivilizationIcon");

--------------------------------------------------------------------------------
--Members for reject
--------------------------------------------------------------------------------
local m_TargetID = -1;
local m_EmergencyType = -1;
local m_RequiresAnswer = 0;

--------------------------------------------------------------------------------
--Instance Managers
--------------------------------------------------------------------------------
local m_LeaderInstManager:table = InstanceManager:new("LeaderIcon45", "SelectButton", Controls.LeaderIconStack);
local m_CrisisManagers:table = {
	left		= InstanceManager:new("LeftAlignText", "RootStack", Controls.CrisisDetailsStack),
	center		= InstanceManager:new("CenterAlignText", "Root", Controls.CrisisDetailsStack),
	large		= InstanceManager:new("CenterAlignLargeText", "Root", Controls.CrisisDetailsStack),
	solo		= InstanceManager:new("CenterAlignSoloText", "Root", Controls.CrisisDetailsStack)
};
local m_RewardsManagers:table = {
	left		= InstanceManager:new("LeftAlignText", "RootStack", Controls.RewardsDetailsStack),
	center		= InstanceManager:new("CenterAlignText", "Root", Controls.RewardsDetailsStack),
	large		= InstanceManager:new("CenterAlignLargeText", "Root", Controls.RewardsDetailsStack),
	solo		= InstanceManager:new("CenterAlignSoloText", "Root", Controls.RewardsDetailsStack)
};

function OnCrisisReceived(playerTarget, emergencyType)
	m_TargetID = playerTarget;
	m_EmergencyType = emergencyType;
	local crisisData:table = FetchData(playerTarget, emergencyType);
	if (not crisisData) then
		return
	end
	--Clear the stacks
	m_CrisisManagers.left:ResetInstances();
	m_CrisisManagers.center:ResetInstances();
	m_CrisisManagers.large:ResetInstances();
	m_CrisisManagers.solo:ResetInstances();
	m_RewardsManagers.left:ResetInstances();
	m_RewardsManagers.center:ResetInstances();
	m_RewardsManagers.large:ResetInstances();
	m_RewardsManagers.solo:ResetInstances();

	--Set the icon for the emergency
	Controls.TitleIcon:SetIcon("ICON_" .. GameInfo.EmergencyAlliances[emergencyType].EmergencyType);

	--Do we need input?
	Controls.JoinButton:SetHide(not crisisData.inputRequired);
	Controls.RejectButton:SetHide(not crisisData.inputRequired);
	Controls.OKButton:SetHide(crisisData.inputRequired);
	m_RequiresAnswer = crisisData.inputRequired;

	--Title and subtitles
	Controls.TitleString:SetText(crisisData.titleString);
	Controls.TrinketString:SetText(crisisData.trinketString);
	Controls.CrisisTargetTitle:SetText(Locale.ToUpper(crisisData.crisisTargetTitle));
	Controls.CrisisTrinketTitle:SetText(crisisData.crisisTrinketTitle);

	--Populate our initial data block
	PopulateDynamicStack(m_CrisisManagers, crisisData.crisisDetails);
	Controls.CrisisDetailsStack:CalculateSize();

	--Turns remaining
	local bgSuffix = "_BG3";
	if (crisisData.timeRemaining > 0) then
		if (crisisData.timeRemaining == 1) then
			Controls.CrisisDuration:SetText(Locale.Lookup("LOC_EMERGENCY_NO_TURNS_REMAINING"));
		else
			Controls.CrisisDuration:SetText(Locale.Lookup("LOC_EMERGENCY_TURNS_REMAINING", crisisData.timeRemaining));
		end
        UI.PlaySound("Emergency_Start");
	else
		Controls.CrisisDuration:SetText(Locale.Lookup("LOC_EMERGENCY_TURNS_OVER"));
        UI.PlaySound("Emergency_End");

		--Set alternate backgrounds if the emergency is over
		local isTarget = Game.GetLocalPlayer() == m_TargetID;
		if (not crisisData.crisisSuccess and isTarget) or (crisisData.crisisSuccess and not isTarget) then
			--Good news
			bgSuffix = "_BG2";
		else
			--Bad news
			bgSuffix = "_BG1";
		end
	end

	--Background
	Controls.CrisisBG:SetTexture(GameInfo.EmergencyAlliances[emergencyType].EmergencyType .. bgSuffix);

	--Target assignment
	local ownerController = CivilizationIcon:AttachInstance(Controls.CivilizationTargetIcon);
	ownerController:UpdateIconFromPlayerID(crisisData.targetPlayer);

	local localDiplomacy:table =  Players[crisisData.targetPlayer]:GetDiplomacy();
	local leaderName:string = PlayerConfigurations[crisisData.targetPlayer]:GetLeaderTypeName();
	local iconName:string = "ICON_" .. leaderName;

	--Build and update
	local ownerLeader = LeaderIcon:AttachInstance(Controls.LeaderTargetIcon);
	ownerLeader:UpdateIcon(iconName, crisisData.targetPlayer, true);

	--Populate our bottom block of data
	PopulateDynamicStack(m_RewardsManagers, crisisData.rewardsDetails);
	Controls.RewardsDetailsStack:CalculateSize();

	PopulateLeaderBar(crisisData.participantPlayers);
	UIManager:QueuePopup(ContextPtr, PopupPriority.High);
end

function PopulateDynamicStack(instManagers:table, data:table)
	--Spit in our complex strings based on the model we built
	for _, line in ipairs(data) do
		local inst;
		if line.align == "left" then
			inst = instManagers.left:GetInstance();
		elseif line.align == "center" then
			inst = instManagers.center:GetInstance();
		elseif line.align == "large" then
			inst = instManagers.large:GetInstance();
		elseif line.align == "solo" then
			--We add two empty lines with a single space in them to force the 'solo' alignment to be centered on
			--the X and Y axis
			for i=0, 3, 1 do 
				local tmp = instManagers.left:GetInstance();
				tmp.Root:SetText(" ");
				tmp.IconString:SetText("");
			end
			inst = instManagers.solo:GetInstance();
		end
		
		if line.icon then
			inst.IconString:SetText(line.icon);
		end
		inst.Root:SetText(line.string);
	end
end

function PopulateLeaderBar(participantPlayers:table)
	m_LeaderInstManager:ResetInstances();
	
	--Add our leaders
	local isUniqueLeader:table = {};
	local localPlayerID:number = Game.GetLocalPlayer();
	local localDiplomacy:table =  Players[localPlayerID]:GetDiplomacy();

	for _, currPlayerID in ipairs(participantPlayers) do
		local leaderName:string = PlayerConfigurations[currPlayerID]:GetLeaderTypeName();
		local iconName:string = "ICON_" .. leaderName;
		local playerMet:boolean = localDiplomacy:HasMet(currPlayerID);
		if (playerMet) then
			if (isUniqueLeader[leaderName] == nil) then
				isUniqueLeader[leaderName] = true;
			else
				isUniqueLeader[leaderName] = false;
			end	
		elseif currPlayerID ~= localPlayerID then
			iconName = "ICON_LEADER_DEFAULT";
		end

		--Build and update
		local leaderIcon = LeaderIcon:GetInstance(m_LeaderInstManager);
		leaderIcon:UpdateIcon(iconName, currPlayerID, isUniqueLeader[leaderName]);
	end
end

function OnClose()
	if (not m_RequiresAnswer) then
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_OTHER_PLAYER] = m_TargetID;
		kParameters[PlayerOperations.PARAM_EMERGENCY_TYPE] = m_EmergencyType;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ACCEPT_EMERGENCY, kParameters);
	end
	UIManager:DequeuePopup(ContextPtr);
end

function OnJoinClicked()
	-- Send a command saying that we've seen this emergency
	local kParameters:table = {};
	kParameters[PlayerOperations.PARAM_OTHER_PLAYER] = m_TargetID;
	kParameters[PlayerOperations.PARAM_EMERGENCY_TYPE] = m_EmergencyType;
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ACCEPT_EMERGENCY, kParameters);

	OnClose();
end

function OnRejectClicked()
	-- Send a command saying we reject it
	local kParameters:table = {};
	kParameters[PlayerOperations.PARAM_OTHER_PLAYER] = m_TargetID;
	kParameters[PlayerOperations.PARAM_EMERGENCY_TYPE] = m_EmergencyType;
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.REJECT_EMERGENCY, kParameters);

	OnClose();
end

function FetchData(playerTarget, emergencyType)
	--TODO: Follow this data model to provide for the emergency popuP
	local localPlayerID:number = Game.GetLocalPlayer();
	local bPlayerisTarget:boolean = localPlayerID == playerTarget;
	local cachedData:table = Game.GetEmergencyManager():GetEmergencyInfoTable(localPlayerID);
	if (cachedData[0] == nil ) then
		return nil
	end
	
	local cachedValue = nil;
	for _, emergency in ipairs(cachedData) do
		if emergency.EmergencyType == emergencyType and emergency.TargetID == playerTarget then
			cachedValue = emergency;
		end
	end
	
	if cachedValue == nil then
		return nil;
	end

	local crisisDetails: table = {};
	-- Fill out goals, if things have started
	if (cachedValue.TurnsLeft < 0) then
		table.insert(crisisDetails, {align="solo", string=Locale.ToUpper(Locale.Lookup(cachedValue.bSuccess and "LOC_EMERGENCY_COMPLETE_MEMBERS_WIN" or "LOC_EMERGENCY_COMPLETE_TARGET_WIN")),})
	else
		if next(cachedValue.GoalsTable) ~= nil then
			table.insert(crisisDetails, {align="center", string=Locale.Lookup("LOC_EMERGENCY_COMPLETE_THESE_GOALS"),})
			local GoalsTable : table = bPlayerisTarget and cachedValue.TargetGoalsTable or cachedValue.GoalsTable
			for dataIndex, line in ipairs(GoalsTable) do
				if line.Name ~= "" then
					local linevalue :table = {align="left",}
					if line.Completed then
						linevalue["icon"] = bPlayerisTarget and "[ICON_CheckFail]" or "[ICON_Checkmark]"
					else
						linevalue["icon"] = "[ICON_Bolt]"
					end
					linevalue["string"] = line.Name
					table.insert(crisisDetails, linevalue)
				end
			end
		else
			table.insert(crisisDetails, {align="left", string=Locale.Lookup("LOC_EMERGENCY_PENDING_EXPLANATION", cachedValue.TentativeDescription),})
		end
	end
	if (cachedValue.TurnsLeft >= 0) then
		-- Fill out temporary buffs
		if next(cachedValue.BuffsText) ~= nill then
			table.insert(crisisDetails, {align="center", string=Locale.Lookup("LOC_EMERGENCY_BUFFS_EXPLANATION"),})
			for dataIndex, line in ipairs(cachedValue.BuffsText) do
				local linevalue :table = {align="left",}
				linevalue["string"] = line
				linevalue["icon"] = "[ICON_Bolt]"
				table.insert(crisisDetails, linevalue)
			end
		end
		if (cachedValue.ExtraBuffs ~= "") then
			table.insert(crisisDetails, {align="left", string=cachedValue.ExtraBuffs,})
		end 
	end

	local rewardsDetails : table = {};

	if next(cachedValue.MemberRewardsText) ~= {} and (cachedValue.bSuccess or cachedValue.TurnsLeft >= 0) then
		table.insert(rewardsDetails, {align="center", string=Locale.Lookup(cachedValue.TurnsLeft >= 0 and "LOC_EMERGENCY_MEMBER_REWARDS_EXPLANATION" or "LOC_EMERGENCY_MEMBERS_HAVE_WON_REWARDS"),})
		for dataIndex, line in ipairs(cachedValue.MemberRewardsText) do
			local linevalue :table = {align="left",}
			linevalue["string"] = line
			linevalue["icon"] = "[ICON_Bolt]"
			table.insert(rewardsDetails, linevalue)
		end
	end
	if (cachedValue.ExtraRewards ~= "") and (cachedValue.bSuccess or cachedValue.TurnsLeft >= 0) then
		table.insert(rewardsDetails, {align="left", string=cachedValue.ExtraRewards,})
	end 
	if next(cachedValue.TargetRewardsText) ~= {} and (not cachedValue.bSuccess or cachedValue.TurnsLeft >= 0)  then
		table.insert(rewardsDetails, {align="center", string=Locale.Lookup(cachedValue.TurnsLeft >= 0 and "LOC_EMERGENCY_TARGET_REWARDS_EXPLANATION" or "LOC_EMERGENCY_TARGET_HAS_WON_REWARDS"),})
		for dataIndex, line in ipairs(cachedValue.TargetRewardsText) do
			local linevalue :table = {align="left",}
			linevalue["string"] = line
			linevalue["icon"] = "[ICON_Bolt]"
			table.insert(rewardsDetails, linevalue)
		end
	end

	local crisisData:table = {
		targetPlayer			= cachedValue.TargetID,
		emergencyType			= cachedValue.EmergencyType,
		crisisSuccess			= cachedValue.bSuccess,
		inputRequired			= not cachedValue.HasBegun,
		participantPlayers		= cachedValue.MemberIDs,
		titleString				= Locale.ToUpper(Locale.Lookup(cachedValue.HasBegun and (cachedValue.TurnsLeft< 0 and "LOC_EMERGENCY_COMPLETED" or "LOC_EMERGENCY_ONGOING") or 
												"LOC_EMERGENCY_PENDING", cachedValue.NameText)),
		trinketString			= cachedValue.DescriptionText,
		crisisTargetTitle		= Locale.Lookup("LOC_EMERGENCY_TARGET", cachedValue.HasBegun and cachedValue.TargetCityName or PlayerConfigurations[cachedValue.TargetID]:GetLeaderName()),
		crisisTrinketTitle		= cachedValue.TurnsLeft < 0 and "" or cachedValue.GoalDescription,
		crisisDetails			= crisisDetails,
		timeRemaining			= cachedValue.TurnsLeft,
		rewardsDetails			= rewardsDetails,
	};

	return crisisData;
end

-- ===========================================================================
--	UI Input Event Handler
-- ===========================================================================
function OnInputHandler( pInputStruct:table )

	if ContextPtr:IsHidden() then return; end

	local key = pInputStruct:GetKey();
	local msg = pInputStruct:GetMessageType();
	if msg == KeyEvents.KeyUp and key == Keys.VK_ESCAPE then 
		OnClose();
	end

	return true; -- consume all input
end

function Initialize()
	--OnCrisisReceived(); -- DEBUG
	ContextPtr:SetHide(true); -- PRODUCTION

	ContextPtr:SetInputHandler( OnInputHandler, true );

	Controls.JoinButton:RegisterCallback(Mouse.eLClick, OnJoinClicked);
	Controls.RejectButton:RegisterCallback(Mouse.eLClick, OnRejectClicked);
	Controls.OKButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	Events.EmergencyAvailable.Add(OnCrisisReceived);
	LuaEvents.EmergencyClicked.Add(OnCrisisReceived);
end
Initialize();