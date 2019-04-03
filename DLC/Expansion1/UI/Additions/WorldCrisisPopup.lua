-- Copyright 2017-2018, Firaxis Games
include("InstanceManager");
include("LeaderIcon");
include("CivilizationIcon");


-- ===========================================================================
--	DEBUG
-- ===========================================================================
local debugForceRaiseCrisis = false;			-- (false) when true forces a crisis popup to occur.


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "WorldCrisisPopup";

local m_targetPlayerID	:number = -1;
local m_emergencyType	:number = -1;
local m_isAnswerRequired:boolean = false;

local m_LeaderIM:table = InstanceManager:new("LeaderIcon45", "SelectButton", Controls.LeaderIconStack);
local m_kCrisisManagers:table = {
	left		= InstanceManager:new("LeftAlignText", "RootStack", Controls.CrisisDetailsStack),
	center		= InstanceManager:new("CenterAlignText", "Root", Controls.CrisisDetailsStack),
	large		= InstanceManager:new("CenterAlignLargeText", "Root", Controls.CrisisDetailsStack),
	solo		= InstanceManager:new("CenterAlignSoloText", "Root", Controls.CrisisDetailsStack)
};
local m_kRewardsManagers:table = {
	left		= InstanceManager:new("LeftAlignText", "RootStack", Controls.RewardsDetailsStack),
	center		= InstanceManager:new("CenterAlignText", "Root", Controls.RewardsDetailsStack),
	large		= InstanceManager:new("CenterAlignLargeText", "Root", Controls.RewardsDetailsStack),
	solo		= InstanceManager:new("CenterAlignSoloText", "Root", Controls.RewardsDetailsStack)
};



-- ===========================================================================
function OnCrisisReceived(targetPlayerID, emergencyType)
	
	m_targetPlayerID = targetPlayerID;
	m_emergencyType = emergencyType;
	local crisisData:table = FetchData( emergencyType );
	if (not crisisData) then
		return
	end
	--Clear the stacks
	m_kCrisisManagers.left:ResetInstances();
	m_kCrisisManagers.center:ResetInstances();
	m_kCrisisManagers.large:ResetInstances();
	m_kCrisisManagers.solo:ResetInstances();
	m_kRewardsManagers.left:ResetInstances();
	m_kRewardsManagers.center:ResetInstances();
	m_kRewardsManagers.large:ResetInstances();
	m_kRewardsManagers.solo:ResetInstances();

	--Set the icon for the emergency
	Controls.TitleIcon:SetIcon("ICON_" .. GameInfo.EmergencyAlliances[emergencyType].EmergencyType);

	--Do we need input?
	Controls.JoinButton:SetHide(not crisisData.inputRequired);
	Controls.RejectButton:SetHide(not crisisData.inputRequired);
	Controls.OKButton:SetHide(crisisData.inputRequired);
	m_isAnswerRequired = crisisData.inputRequired;

	--Title and subtitles
	Controls.TitleString:SetText(crisisData.titleString);
	Controls.TrinketString:SetText(crisisData.trinketString);
	Controls.CrisisTargetTitle:SetText(Locale.ToUpper(crisisData.crisisTargetTitle));
	Controls.CrisisTrinketTitle:SetText(crisisData.crisisTrinketTitle);

	--Populate our initial data block
	PopulateDynamicStack(m_kCrisisManagers, crisisData.crisisDetails);
	Controls.CrisisDetailsStack:CalculateSize();

	--Turns remaining
	local bgSuffix = "_BG3";
	if (crisisData.timeRemaining > 0) then
		if (crisisData.timeRemaining == 1) then
			Controls.CrisisDuration:SetText(Locale.Lookup("LOC_EMERGENCY_NO_TURNS_REMAINING"));
		else
			Controls.CrisisDuration:SetText(Locale.Lookup("LOC_EMERGENCY_TURNS_REMAINING", crisisData.timeRemaining));
		end
        UI.PlaySound("ScoredCompetition_open");
	else
		Controls.CrisisDuration:SetText(Locale.Lookup("LOC_EMERGENCY_TURNS_OVER"));
        UI.PlaySound("ScoredCompetition_close");

		--Set alternate backgrounds if the emergency is over
		local isTarget :boolean = Game.GetLocalPlayer() == m_targetPlayerID;
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
	if crisisData.targetPlayer >= 0 then
		local localDiplomacy:table =  Players[crisisData.targetPlayer]:GetDiplomacy();
		local leaderName:string = PlayerConfigurations[crisisData.targetPlayer]:GetLeaderTypeName();
		local iconName:string = "ICON_" .. leaderName;

		--Build and update
		local ownerLeader = LeaderIcon:AttachInstance(Controls.LeaderTargetIcon);
		ownerLeader:UpdateIcon(iconName, crisisData.targetPlayer, true);

		local ownerController = CivilizationIcon:AttachInstance(Controls.CivilizationTargetIcon);
		ownerController:UpdateIconFromPlayerID(crisisData.targetPlayer);
	end
	Controls.LeaderIconContainer:SetHide(crisisData.targetPlayer < 0);
	Controls.CivilizationIconContainer:SetHide(crisisData.targetPlayer < 0);

	--Populate our bottom block of data
	PopulateDynamicStack(m_kRewardsManagers, crisisData.rewardsDetails);
	Controls.RewardsDetailsStack:CalculateSize();

	PopulateLeaderBar(crisisData.participantPlayers);
	UIManager:QueuePopup(ContextPtr, PopupPriority.Low);
end

-- ===========================================================================
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

-- ===========================================================================
function PopulateLeaderBar(kParticipantPlayers:table)
	m_LeaderIM:ResetInstances();
	
	--Add our leaders
	local isUniqueLeader:table = {};
	local localPlayerID:number = Game.GetLocalPlayer();
	local localDiplomacy:table =  Players[localPlayerID]:GetDiplomacy();

	for _, playerID in ipairs(kParticipantPlayers) do
		if playerID ~= -1 then
			local leaderName:string = PlayerConfigurations[playerID]:GetLeaderTypeName();
			local iconName:string = "ICON_" .. leaderName;
			local playerMet:boolean = localDiplomacy:HasMet(playerID);
			if (playerMet) then
				if (isUniqueLeader[leaderName] == nil) then
					isUniqueLeader[leaderName] = true;
				else
					isUniqueLeader[leaderName] = false;
				end	
			elseif playerID ~= localPlayerID then
				iconName = "ICON_LEADER_DEFAULT";
			end

			--Build and update
			local leaderIcon = LeaderIcon:GetInstance(m_LeaderIM);
			leaderIcon:UpdateIcon(iconName, playerID, isUniqueLeader[leaderName]);
		end
	end
end


-- ===========================================================================
function Close()
	if (not m_isAnswerRequired) then
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_OTHER_PLAYER] = m_targetPlayerID;
		kParameters[PlayerOperations.PARAM_EMERGENCY_TYPE] = m_emergencyType;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ACCEPT_EMERGENCY, kParameters);
	end
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
function OnJoinClicked()
	-- Send a command saying that we've seen this emergency
	local kParameters:table = {};
	kParameters[PlayerOperations.PARAM_OTHER_PLAYER] = m_targetPlayerID;
	kParameters[PlayerOperations.PARAM_EMERGENCY_TYPE] = m_emergencyType;
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ACCEPT_EMERGENCY, kParameters);

	Close();
end

-- ===========================================================================
function OnRejectClicked()
	-- Send a command saying we reject it
	local kParameters:table = {};
	kParameters[PlayerOperations.PARAM_OTHER_PLAYER] = m_targetPlayerID;
	kParameters[PlayerOperations.PARAM_EMERGENCY_TYPE] = m_emergencyType;
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.REJECT_EMERGENCY, kParameters);

	Close();
end

-- ===========================================================================
function FetchData( emergencyType )
	--TODO: Follow this data model to provide for the emergency popuP
	local localPlayerID:number = Game.GetLocalPlayer();
	local bPlayerisTarget:boolean = localPlayerID == m_targetPlayerID;
	local cachedData:table = Game.GetEmergencyManager():GetEmergencyInfoTable(localPlayerID);
	if (cachedData[0] == nil ) then
		return nil
	end
	
	local cachedValue = nil;
	for _, emergency in ipairs(cachedData) do
		if emergency.EmergencyType == emergencyType and emergency.TargetID == m_targetPlayerID then
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

	local leaderName:string = GameConfiguration.IsAnyMultiplayer() and PlayerConfigurations[cachedValue.TargetID]:GetPlayerName() or PlayerConfigurations[cachedValue.TargetID]:GetLeaderName();
	local crisisData:table = {
		targetPlayer			= cachedValue.TargetID,
		emergencyType			= cachedValue.EmergencyType,
		crisisSuccess			= cachedValue.bSuccess,
		inputRequired			= not cachedValue.HasBegun,
		participantPlayers		= cachedValue.MemberIDs,
		titleString				= Locale.ToUpper(Locale.Lookup(cachedValue.HasBegun and (cachedValue.TurnsLeft< 0 and "LOC_EMERGENCY_COMPLETED" or "LOC_EMERGENCY_ONGOING") or 
												"LOC_EMERGENCY_PENDING", cachedValue.NameText)),
		trinketString			= cachedValue.DescriptionText,
		crisisTargetTitle		= Locale.Lookup("LOC_EMERGENCY_TARGET", cachedValue.HasBegun and cachedValue.TargetCityName or leaderName),
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
		Close();
	end

	return true; -- consume all input
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_targetPlayerID", m_targetPlayerID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_emergencyType", m_emergencyType);
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		local targetPlayer = nil;
		local emergencyType = nil;
		
		if contextTable["m_targetPlayerID"] ~= nil then			
			targetPlayer = contextTable["m_targetPlayerID"];
		end
		
		if contextTable["m_emergencyType"] ~= nil then			
			emergencyType = contextTable["m_emergencyType"];
		end
		
		if targetPlayer and emergencyType then
			OnCrisisReceived(targetPlayer, emergencyType);
		end
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShutdown(OnShutdown);

	Controls.JoinButton:RegisterCallback(Mouse.eLClick, OnJoinClicked);
	Controls.RejectButton:RegisterCallback(Mouse.eLClick, OnRejectClicked);
	Controls.OKButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	
	Events.EmergencyAvailable.Add(OnCrisisReceived);
	
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);	
	LuaEvents.NotificationPanel_EmergencyClicked.Add( OnCrisisReceived );
	LuaEvents.WorldCrisisTracker_EmergencyClicked.Add( OnCrisisReceived );
	LuaEvents.DiploScene_SceneOpened.Add(OnClose);

	if debugForceRaiseCrisis then
		OnCrisisReceived();
	end
end
Initialize();
