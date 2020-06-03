-- Copyright 2017-2018, Firaxis Games

include("InstanceManager");
include("LeaderIcon");
include("CivilizationIcon");
include("WorldCrisisSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "WorldCrisisPopup";

local TIER_REWARD_STRINGS:table = {};
TIER_REWARD_STRINGS[1] = "LOC_SCORED_COMPETITION_YOU_EARNED_GOLD";
TIER_REWARD_STRINGS[2] = "LOC_SCORED_COMPETITION_YOU_EARNED_SILVER";
TIER_REWARD_STRINGS[3] = "LOC_SCORED_COMPETITION_YOU_EARNED_BRONZE";

local TIER_RIM_NAMES:table = {};
TIER_RIM_NAMES[1] = {rim="Controls_CircleRim40_Gold", arrow="Controls_YouArrowSmall_Gold"};
TIER_RIM_NAMES[2] = {rim="Controls_CircleRim40_Silver", arrow="Controls_YouArrowSmall_Silver"};
TIER_RIM_NAMES[3] = {rim="Controls_CircleRim40_Bronze", arrow="Controls_YouArrowSmall_Bronze"};
TIER_RIM_NAMES[4] = {rim="Controls_CircleRim40_None", arrow="Controls_YouArrowSmall_None"};

local BG_PREFIX:string = "XP2_BG_";

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_targetPlayerID	:number = -1;
local m_emergencyType	:number = -1;
local m_isAnswerRequired:boolean = false;
local m_LeaderIM		:table = InstanceManager:new("LeaderButton", "Root", Controls.LeaderIconStack);


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-- ===========================================================================
--	Game Event
-- ===========================================================================
function OnEmergencyAvailable( targetPlayerID:number, emergencyType:number, startingTurn:number )

	local localPlayerID	:number = Game.GetLocalPlayer();
	if localPlayerID == -1 then return; end -- Autoplay		

	m_targetPlayerID = targetPlayerID;
	m_emergencyType = emergencyType;

	local kData				:table = nil;	
	local bPlayerisTarget	:boolean = localPlayerID == m_targetPlayerID;
	local kEmergencyInfo	:table = Game.GetEmergencyManager():GetEmergencyInfoTable(localPlayerID);
	
	if kEmergencyInfo == nil then
		UI.DataError("No emeregency data for local player "..tostring(localPlayerID).." but EmergencyAvailable was raised.  Assign @tyler.berry");
		return;
	end	

	if kEmergencyInfo and table.count(kEmergencyInfo) > 0 then
		for _, kEmergency in ipairs(kEmergencyInfo) do
			if kEmergency.EmergencyType == emergencyType and kEmergency.TargetID == m_targetPlayerID then
				kData = ProcessEmergency_WorldCrisisPopup(kEmergency, localPlayerID);
				break;
			end
		end
	end
	
	if kData then
		ShowEmergency( kData );
	else
		UI.DataError("Failed to find emergency data for target "..tostring(targetPlayerID)..", emergency " .. tostring(emergencyType) .. ".  Assign @tyler.berry");
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnShowEmergency( kData: table )
	if kData == nil then
		UI.DataError("No data was passed to OnShowEmergency()");
		return;
	end
	ShowEmergency( kData );
end

-- ===========================================================================
function ShowEmergency( kData: table )

	local localPlayerID:number = Game.GetLocalPlayer();
	local emergencyType:number = kData.emergencyType;

	--Clear the stacks
	ResetEmergencyInstances();

	--Do we need input?
	Controls.JoinButton:SetHide(not kData.inputRequired);
	Controls.RejectButton:SetHide(not kData.inputRequired);
	Controls.OKButton:SetHide(kData.inputRequired);
	m_isAnswerRequired = kData.inputRequired;

	--Only show target if we are hostile
	Controls.TargetIcon:SetShow(GameInfo.Emergencies_XP2[emergencyType].Hostile);

	--Title and subtitles
	Controls.TitleString:SetText(Locale.Lookup(kData.titleString));
	Controls.TrinketString:SetText(kData.trinketString);
	Controls.CrisisTargetTitle2:SetText(kData.targetCityName);
	Controls.CrisisTargetTitle2:SetHide(kData.targetCityName == "");
	Controls.CrisisTrinketTitle:SetText(kData.crisisTrinketTitle);
	Controls.CrisisTrinketTitle:SetHide(kData.crisisTrinketTitle == "");

	--Populate our initial data block
	PopulateWorldCrisisText(g_kCrisisManagers, kData.crisisDetails, Controls.CrisisDetailsStack, true);

	--Turns remaining
	local bgColor:string = "Emergency_Default";
	if (kData.timeRemaining > 0) then
		if (kData.timeRemaining == 1) then
			Controls.CrisisDuration:SetText(Locale.Lookup("LOC_EMERGENCY_NO_TURNS_REMAINING"));
		else
			Controls.CrisisDuration:SetText(Locale.Lookup("LOC_EMERGENCY_TURNS_REMAINING", kData.timeRemaining));
		end
		bgColor = "Emergency_In_Progress";
		Controls.VictorStack:SetHide(true);
		Controls.CrisisDetailsStack:SetHide(false);
	else
		Controls.VictorStack:SetHide(false);
		Controls.CrisisDetailsStack:SetHide(true);
		if GameInfo.Emergencies_XP2[emergencyType].Hostile then
			local isTarget :boolean =  localPlayerID == m_targetPlayerID;
			if (not kData.crisisSuccess and isTarget) then
				Controls.VictorTitle:SetText(Locale.Lookup("LOC_SCORED_COMPETITION_YOU_WIN"));
				Controls.VictorTier:SetText(Locale.Lookup("LOC_SCORED_COMPETITION_YOU_EARNED_TARGET"));
				bgColor = "Emergency_Gold";
			elseif not kData.crisisSuccess then
				Controls.VictorTitle:SetText(Locale.Lookup("LOC_SCORED_COMPETITION_TARGET_WINS"));
				Controls.VictorTier:SetText(Locale.Lookup("LOC_SCORED_COMPETITION_YOU_EARNED_NONE"));
				bgColor = "Emergency_Failed";
			else
				Controls.VictorTitle:SetText(Locale.Lookup("LOC_SCORED_COMPETITION_MEMBERS_WIN"));
				Controls.VictorTier:SetText(Locale.Lookup(isTarget and "LOC_SCORED_COMPETITION_YOU_EARNED_NONE" or "LOC_SCORED_COMPETITION_YOU_EARNED_MEMBER"));
				bgColor = isTarget and "Emergency_Gold" or "Emergency_Failed";
			end
		else
			for playerTierID:number,tierValue:number in pairs(kData.memberTiers) do
				local bIsLocalPlayer:boolean = playerTierID == localPlayerID;
				--Find first place
				if tierValue == 1 then
					if bIsLocalPlayer then
						Controls.VictorTitle:SetText(Locale.Lookup("LOC_SCORED_COMPETITION_YOU_WIN"));
					else
						local winnerName:string = GetVisiblePlayerName(playerTierID);
						Controls.VictorTitle:SetText(Locale.Lookup("LOC_SCORED_COMPETITION_LEADER_WINS", winnerName));
					end
				end
			
				if bIsLocalPlayer then
					Controls.VictorTier:SetText(Locale.Lookup(tierValue > 0 and TIER_REWARD_STRINGS[tierValue] or "LOC_SCORED_COMPETITION_YOU_EARNED_NONE"));
					if tierValue == 1 then
						bgColor = "Emergency_Gold";
					elseif tierValue == 2 then
						bgColor = "Emergency_Silver";
					elseif tierValue == 3 then
						bgColor = "Emergency_Bronze"
					end
				end
			end
		end
	end

	if GameInfo.Emergencies_XP2[emergencyType].Hostile then
		--Give "first place" to all members who earned points in non-ranked emergency
		for playerTierID:number,tierValue:number in pairs(kData.memberTiers) do
			if(tierValue > 1) then 
				kData.memberTiers[playerTierID] = 1;
			end
		end
	end

	--Background
	Controls.CrisisBG:SetTexture(BG_PREFIX .. GameInfo.EmergencyAlliances[emergencyType].EmergencyType);
	Controls.CrisisBG:SetColorByName(bgColor);

	--Place in the competition
	Controls.PlayerPlaceLabel:SetHide(kData.targetPlayer == localPlayerID);
	Controls.PlayerPlaceLabel:SetText(kData.placeString);

	--Target assignment
	if kData.targetPlayer >= 0 then
		local localDiplomacy:table =  Players[kData.targetPlayer]:GetDiplomacy();
		local leaderName:string = PlayerConfigurations[kData.targetPlayer]:GetLeaderTypeName();
		local iconName:string = "ICON_" .. leaderName;

		--Build and update
		local ownerLeader = LeaderIcon:AttachInstance(Controls.LeaderTargetIcon);
		ownerLeader:UpdateIcon(iconName, kData.targetPlayer, true);
		Controls.LeaderTargetIcon.Relationship:SetHide(true);
		Controls.CrisisTargetTitle:SetText(Locale.ToUpper(kData.crisisTargetTitle));
		Controls.NoTargetIcon:SetHide(true);
		Controls.CivilizationIconContainer:SetHide(false);
	else
		Controls.CrisisTargetTitle:LocalizeAndSetText(Locale.ToUpper(kData.nameText));	
		Controls.CivilizationIconContainer:SetHide(true);
		Controls.NoTargetIcon:SetIcon("ICON_" .. GameInfo.EmergencyAlliances[emergencyType].EmergencyType);
		Controls.NoTargetIcon:SetHide(false);
	end

	--Assign our Member list
	if GameInfo.Emergencies_XP2[emergencyType].Hostile then
		Controls.MemberLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_EMERGENCY_PARTICIPANTS")));
	else
		Controls.MemberLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_EMERGENCY_COMPETING_PARTICIPANTS")));
	end

	--Populate our bottom block of data
	PopulateWorldCrisisText(g_kRewardsManagers, kData.rewardsDetails, Controls.RewardsDetailsStack, true);
	PopulateLeaderBar(kData.participantPlayers, kData.participantScores, kData.memberTiers);

	UIManager:QueuePopup(ContextPtr, PopupPriority.Low, { DelayShow = true });
end

-- ===========================================================================
function OnShow()
	Controls.AnimSoundOnShow:SetToBeginning();	
	Controls.SlideOnShow:SetToBeginning();
	Controls.AnimSoundOnShow:Play();	
	Controls.SlideOnShow:Play();	
	UI.PlaySound("ScoredCompetition_open");
end

-- ===========================================================================
function PopulateLeaderBar( kParticipantPlayers:table, kParticipantScores:table, kMemberTiers:table)
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
			local uiLeaderInstance:table = m_LeaderIM:GetInstance();
			local kLeaderIconManager, uiLeaderIcon = LeaderIcon:AttachInstance(uiLeaderInstance.Icon);
			kLeaderIconManager:UpdateIcon(iconName, playerID, isUniqueLeader[leaderName]);
			uiLeaderInstance.ScoreLabel:SetText(kParticipantScores[playerID]);
			uiLeaderInstance.YouIndicator:SetHide(playerID ~= localPlayerID);
			uiLeaderInstance.Icon.YouIndicator:SetHide(false);
			
			local tierIndex:number = kMemberTiers[playerID];
			if tierIndex > 0 then
				uiLeaderInstance.Icon.YouIndicator:SetTexture(TIER_RIM_NAMES[tierIndex].rim);
				uiLeaderInstance.YouIndicator:SetTexture(TIER_RIM_NAMES[tierIndex].arrow);
			else
				uiLeaderInstance.Icon.YouIndicator:SetTexture(TIER_RIM_NAMES[4].rim);
				uiLeaderInstance.YouIndicator:SetTexture(TIER_RIM_NAMES[4].arrow);
			end
		end
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnDoneCloseAnim()
	if Controls.SlideOnShow:IsReversing() then
		UIManager:DequeuePopup(ContextPtr);
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
	local offsetx = Controls.SlideOnShow:GetOffsetX();
	if(offsetx ~= 0) then
		Controls.SlideOnShow:SetToEnd();
	end
	Controls.SlideOnShow:Reverse();	
	UI.PlaySound("ScoredCompetition_close");
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
--	UI Callback
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
--	UI Callback
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
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", not ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_targetPlayerID", m_targetPlayerID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_emergencyType", m_emergencyType);
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context ~= RELOAD_CACHE_ID then
		return;
	end
		
	if contextTable["isVisible"] then
		local targetPlayer	:number = contextTable["m_targetPlayerID"];
		local emergencyType :number = contextTable["m_emergencyType"]
		OnEmergencyAvailable(targetPlayer, emergencyType);
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
	ContextPtr:SetShowHandler(OnShow);
	ContextPtr:SetShutdown(OnShutdown);

	Controls.JoinButton:RegisterCallback( Mouse.eLClick, OnJoinClicked );
	Controls.RejectButton:RegisterCallback( Mouse.eLClick, OnRejectClicked );
	Controls.OKButton:RegisterCallback( Mouse.eLClick, OnClose );
	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );
	Controls.SlideOnShow:RegisterEndCallback( OnDoneCloseAnim );

	Events.EmergencyAvailable.Add(OnEmergencyAvailable);
	
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);	
	LuaEvents.WorldCongress_ShowEmergency.Add( OnEmergencyAvailable );
	LuaEvents.WorldCrisisTracker_EmergencyClicked.Add( OnEmergencyAvailable );
	LuaEvents.NotificationPanel_EmergencyClicked.Add( OnEmergencyAvailable );
	LuaEvents.DiploScene_SceneOpened.Add(OnClose);
end
Initialize();