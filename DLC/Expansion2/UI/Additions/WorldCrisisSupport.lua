-- Copyright 2017-2018, Firaxis Games

-- Ensure <Include File="WorldCrisisInstances"/> is in the xml of any context that includes this script file
include("PlayerSupport");

g_kCrisisManagers = {
	left		= InstanceManager:new("LeftAlignText", "RootStack"),
	center	= InstanceManager:new("CenterAlignText", "Root"),
	large		= InstanceManager:new("CenterAlignLargeText", "Root"),
	solo		= InstanceManager:new("CenterAlignSoloText", "Root")
};

g_kRewardsManagers = {
	left		= InstanceManager:new("LeftAlignText", "RootStack"),
	center	= InstanceManager:new("CenterAlignText", "Root"),
	large		= InstanceManager:new("CenterAlignLargeText", "Root"),
	solo		= InstanceManager:new("CenterAlignSoloText", "Root")
};

-- ===========================================================================
function ResetEmergencyInstances()
	for _, kIM in pairs(g_kCrisisManagers) do
		kIM:ResetInstances();
	end
	for _, kIM in pairs(g_kRewardsManagers) do
		kIM:ResetInstances();
	end
end

-- ===========================================================================
--	This function gets called internally within this file to populate common data
-- ===========================================================================
function ProcessEmergency( kEmergency:table )
	local crisisTargetTitle		:string = Locale.Lookup("LOC_EMERGENCY_TARGET", kEmergency.TargetID >= 0 and GetVisiblePlayerName(kEmergency.TargetID) or "");
	local titleString			:string = kEmergency.TurnsLeft < 0 and kEmergency.CompletedText or Locale.Lookup("LOC_SCORED_COMPETITION_COMPETITION_ONGOING");
	local crisisTrinketTitle	:string = kEmergency.TurnsLeft < 0 and "" or kEmergency.GoalDescription;
	local targetCityName		:string = Locale.ToUpper(kEmergency.TargetCityName ~= "" and Locale.Lookup("LOC_EMERGENCY_TARGET_CITY", kEmergency.TargetCityName)) or "";

	return {
		targetPlayer		= kEmergency.TargetID,
		emergencyType		= kEmergency.EmergencyType,
		crisisSuccess		= kEmergency.bSuccess,
		inputRequired		= not kEmergency.HasBegun,
		participantScores	= kEmergency.ScoresTables,
		titleString			= titleString,
		trinketString		= kEmergency.ShortDescriptionText,
		crisisTargetTitle	= crisisTargetTitle,
		crisisTrinketTitle	= crisisTrinketTitle,
		timeRemaining		= kEmergency.TurnsLeft,
		targetCityName		= targetCityName,
		nameText			= kEmergency.NameText,
		memberTiers			= kEmergency.MemberTiers,		
		crisisDetails		= {},		-- populated by callers of ProcessEmergency
		rewardsDetails		= {}		-- populated by callers of ProcessEmergency
	};
end

-- ===========================================================================
-- Fill out goals, if things have started
-- ===========================================================================
function PopulateEmergencyGoals( kEmergency:table, kCrisisDetails:table )
	table.insert(kCrisisDetails, {align="center", string=Locale.Lookup("LOC_EMERGENCY_COMPLETE_THESE_GOALS"),})
	local kGoals:table = kEmergency.TargetID == Game.GetLocalPlayer() and kEmergency.TargetGoalsTable or kEmergency.GoalsTable
	for dataIndex, line in ipairs(kGoals) do
		if line.Name ~= "" then
			local linevalue :table = {align="left",}
			if line.Completed then
				linevalue["icon"] = bPlayerisTarget and "[ICON_CheckFail]" or "[ICON_Checkmark]"
			else
				linevalue["icon"] = "[ICON_Bolt]"
			end
			linevalue["string"] = line.Name
			table.insert(kCrisisDetails, linevalue)
		end
	end
end

-- ===========================================================================
-- Fill out the ways the player can gain score
-- ===========================================================================
function PopulateHowToScore( kEmergency:table, kCrisisDetails:table )
	table.insert(kCrisisDetails, {align="center", string= Locale.Lookup("LOC_EMERGENCY_SCORE_HOW_TO")})
	for dataIndex, line in ipairs(kEmergency.ScoreSourcesTable) do
		local linevalue :table = {align="left",}
		linevalue["icon"] = "[ICON_Bolt]"
		linevalue["string"] = line
		table.insert(kCrisisDetails, linevalue)
	end
end

-- ===========================================================================
-- Gets participants of an kEmergency sorted by their Score
-- ===========================================================================
function GetSortedParticipants( kEmergency:table )
	local kParticipants:table = {}
	for _, playerID in ipairs(kEmergency.MemberIDs) do
		local score :number = 0;
		if playerID ~= -1 then
			score = kEmergency.ScoresTables[playerID];
		end
		table.insert(kParticipants, {
			PlayerID = playerID,
			Score = score,
		});
	end
	table.sort(kParticipants, 
		function(kA, kB)					
			return kA.Score > kB.Score 
		end);
	local sortedResults :table = {};
	for _, kParticipant in ipairs(kParticipants) do
		table.insert(sortedResults, kParticipant.PlayerID);
	end
	return sortedResults;
end

-- ===========================================================================
-- Fill out temporary buffs
-- ===========================================================================
function PopulateBuffsAndExtraBuffs( kEmergency:table, kCrisisDetails:table )
	local EmergencyXP2Def:table = GameInfo.Emergencies_XP2[kEmergency.EmergencyType];
	-- Fill out temporary buffs
	if next(kEmergency.BuffsText) ~= nil then
		table.insert(kCrisisDetails, {align="center", string= EmergencyXP2Def.Hostile and Locale.Lookup("LOC_EMERGENCY_BUFFS_EXPLANATION") or Locale.Lookup("LOC_EMERGENCY_COMPETITION_BUFFS_EXPLANATION"),})
		for dataIndex, line in ipairs(kEmergency.BuffsText) do
			local linevalue :table = {align="left",}
			linevalue["string"] = line
			linevalue["icon"] = "[ICON_Bolt]"
			table.insert(kCrisisDetails, linevalue)
		end
	end
	if (kEmergency.ExtraBuffs ~= "") then
		table.insert(kCrisisDetails, {align="left", string=kEmergency.ExtraBuffs,})
	end
end

-- ===========================================================================
-- Fill out rewards for completing the kEmergency
-- ===========================================================================
function PopulateRewards( kEmergency:table, rewardsDetails:table )
	local EmergencyXP2Def:table = GameInfo.Emergencies_XP2[kEmergency.EmergencyType];

	if (kEmergency.bSuccess or kEmergency.TurnsLeft >= 0 or not kEmergency.HasBegun) then
		if (next(kEmergency.MemberRewardsTextFirst) ~= nil
			or next(kEmergency.MemberRewardsTextTop) ~= nil
			or next(kEmergency.MemberRewardsTextBottom) ~= nil
			or next(kEmergency.MemberRewardsTextExtra) ~= nil )
			and (kEmergency.bSuccess or kEmergency.TurnsLeft >= 0) then
			if (EmergencyXP2Def.Hostile == true) then
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_EMERGENCY_MEMBER_REWARDS_HOSTILE_EXPLANATION"),})
			else
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_EMERGENCY_REWARD_NON_HOSTILE_DESCRIPTION"),})
			end
		end
	
		if next(kEmergency.MemberRewardsTextFirst) ~= nil then
			if EmergencyXP2Def.Hostile then
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_SCORED_COMPETITION_MEMBER_TIER_TITLE"),})
			else
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_SCORED_COMPETITION_GOLD_TIER_TITLE"),})
			end
		
			for dataIndex, line in ipairs(kEmergency.MemberRewardsTextFirst) do
				local linevalue :table = {align="left",}
				linevalue["string"] = line
				linevalue["icon"] = "[ICON_Bolt]"
				table.insert(rewardsDetails, linevalue)
			end
		end
	
		if next(kEmergency.MemberRewardsTextTop) ~= nil then
			if EmergencyXP2Def.Hostile then
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_SCORED_COMPETITION_TARGET_TIER_TITLE"),})
			else
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_SCORED_COMPETITION_SILVER_TIER_TITLE"),})
			end
		
			for dataIndex, line in ipairs(kEmergency.MemberRewardsTextTop) do
				local linevalue :table = {align="left",}
				linevalue["string"] = line
				linevalue["icon"] = "[ICON_Bolt]"
				table.insert(rewardsDetails, linevalue)
			end
		end
	
		if next(kEmergency.MemberRewardsTextBottom) ~= nil then
			if EmergencyXP2Def.Hostile then
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_SCORED_COMPETITION_NO_TIER_TITLE_NONE"),})
			else
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_SCORED_COMPETITION_BRONZE_TIER_TITLE"),})
			end
		
			for dataIndex, line in ipairs(kEmergency.MemberRewardsTextBottom) do
				local linevalue :table = {align="left",}
				linevalue["string"] = line
				linevalue["icon"] = "[ICON_Bolt]"
				table.insert(rewardsDetails, linevalue)
			end
		end

		if next(kEmergency.MemberRewardsTextExtra) ~= nil then
			if (next(kEmergency.MemberRewardsTextBottom) ~= nil or next(kEmergency.MemberRewardsTextTop) ~= nil or next(kEmergency.MemberRewardsTextFirst) ~= nil) then
				table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_EMERGENCY_REWARD_EXTRA_EFFECTS_DESCRIPTION"),})
			end
		
			for dataIndex, line in ipairs(kEmergency.MemberRewardsTextExtra) do
				local linevalue :table = {align="left",}
				linevalue["string"] = line
				linevalue["icon"] = "[ICON_Bolt]"
				table.insert(rewardsDetails, linevalue)
			end
		end
		
		-- If we don't have any bottom tier rewards, we only show the "Players with no score" rather than "players in the bottom 50% and no score"
		if next(kEmergency.MemberRewardsTextBottom) ~= nil then
			table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_SCORED_COMPETITION_NO_TIER_TITLE_BOTTOM"),})
		else
			table.insert(rewardsDetails, {align="center", string=Locale.Lookup("LOC_SCORED_COMPETITION_NO_TIER_TITLE_NONE"),})
		end
	end

	if (kEmergency.ExtraRewards ~= "") and (kEmergency.bSuccess or kEmergency.TurnsLeft >= 0) then
		table.insert(rewardsDetails, {align="left", string=kEmergency.ExtraRewards,})
	end 
	if (EmergencyXP2Def.Hostile == true) then
		if next(kEmergency.TargetRewardsText) ~= nil and (not kEmergency.bSuccess or kEmergency.TurnsLeft >= 0 or not kEmergency.HasBegun)  then
			table.insert(rewardsDetails, {align="center", string=Locale.Lookup( (kEmergency.TurnsLeft >= 0 or not kEmergency.HasBegun )and "LOC_EMERGENCY_TARGET_REWARDS_EXPLANATION" or "LOC_EMERGENCY_TARGET_HAS_WON_REWARDS"),})
			for dataIndex, line in ipairs(kEmergency.TargetRewardsText) do
				local linevalue :table = {align="left",}
				linevalue["string"] = line
				linevalue["icon"] = "[ICON_Bolt]"
				table.insert(rewardsDetails, linevalue)
			end
		end
	end
end

-- ===========================================================================
--	This function gets called from WorldCrisisPopup
-- ===========================================================================
function ProcessEmergency_WorldCrisisPopup( kEmergency:table )
	local kResult:table = ProcessEmergency(kEmergency);

	-- Fill out goals, if things have started
	if next(kEmergency.GoalsTable) then
		PopulateEmergencyGoals(kEmergency, kResult.crisisDetails);
	end

	if next(kEmergency.ScoresTables) then
		kResult.participantPlayers = GetSortedParticipants(kEmergency);
	end

	-- Fill out the ways the player can gain score
	if (kEmergency.TurnsLeft < 0) then
		-- This looks like a bug? -sbatista
	else
		if next(kEmergency.ScoreSourcesTable) then
			local teamPosition = 0
			for i, playerType in ipairs(kResult.participantPlayers) do
				if playerType == Game.GetLocalPlayer() then
					teamPosition = i
				end
			end
			if (teamPosition <= 0) then
				teamPosition = 1;
			end

			if Game.GetLocalPlayer() ~= kEmergency.TargetID then
				kResult.placeString = Locale.Lookup("LOC_WORLD_RANKINGS_OTHER_PLACE_SIMPLE", "LOC_WORLD_RANKINGS_" .. teamPosition .. "_PLACE");
				PopulateHowToScore(kEmergency, kResult.crisisDetails);
			end
		end
	end

	if (kEmergency.TurnsLeft >= 0) then
		PopulateBuffsAndExtraBuffs(kEmergency, kResult.crisisDetails);
	end

	-- Fill out reward details
	PopulateRewards(kEmergency, kResult.rewardsDetails);
	return kResult;
end

-- ===========================================================================
--	This function gets called from WorldCongressPopup
-- ===========================================================================
function ProcessEmergency_WorldCongressPopup( kEmergency:table )
	local kResult:table = ProcessEmergency(kEmergency);

	-- Fill out goals, if things have started
	if next(kEmergency.GoalsTable) then
		PopulateEmergencyGoals(kEmergency, kResult.crisisDetails);
	end

	-- Fill out the ways the player can gain score
	if next(kEmergency.ScoreSourcesTable) then
		PopulateHowToScore(kEmergency, kResult.crisisDetails);
	end

	-- Fill out temporary buffs
	PopulateBuffsAndExtraBuffs(kEmergency, kResult.crisisDetails);

	-- Fill out reward details
	PopulateRewards(kEmergency, kResult.rewardsDetails);
	return kResult;
end

-- ===========================================================================
function PopulateWorldCrisisText( instManagers:table, data:table, parentControl:table )
	InternalPopulateWorldCrisisText(instManagers, data, parentControl);
end

-- ===========================================================================
function PopulateWorldCrisisTextWithSoloNewlines( instManagers:table, data:table, parentControl:table )
	InternalPopulateWorldCrisisText(instManagers, data, parentControl, { SoloNewLines = true });
end

-- ===========================================================================
function InternalPopulateWorldCrisisText( instManagers:table, data:table, parentControl:table, kParameters:table )
	--Spit in our complex strings based on the model we built
	for _, line in ipairs(data) do
		local inst;
		if line.align == "left" then
			inst = instManagers.left:GetInstance(parentControl);
		elseif line.align == "center" then
			inst = instManagers.center:GetInstance(parentControl);
		elseif line.align == "large" then
			inst = instManagers.large:GetInstance(parentControl);
		elseif line.align == "solo" then
			if kParameters and kParameters.SoloNewLines then
				-- Add two empty lines with a single space in them to force the 'solo' alignment to be centered on the X and Y axis
				for i=0, 3, 1 do
					local tmp = instManagers.left:GetInstance(parentControl);
					tmp.Root:SetText(" ");
					tmp.IconString:SetText("");
				end
			end
			inst = instManagers.solo:GetInstance(parentControl);
		end
		
		if line.icon then
			inst.IconString:SetText(line.icon);
		end
		inst.Root:SetText(line.string);
	end
end