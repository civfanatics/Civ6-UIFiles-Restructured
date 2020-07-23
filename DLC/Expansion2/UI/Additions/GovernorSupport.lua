
-- ===========================================================================
function GetGovernorAssignmentButtonText(governorTypeIndex:number)
	local assignmentText:string = "";

	local pLocalPlayer:table = Players[Game.GetLocalPlayer()];
	local pPlayerGovernors:table = pLocalPlayer:GetGovernors();
	local pGovernor:table = GetAppointedGovernor(Game.GetLocalPlayer(), governorTypeIndex);

	if pGovernor then
		-- Find out if we're assigned to a city
		local pAssignedCity = pGovernor:GetAssignedCity();
		if pAssignedCity then
			local cityName = Locale.Lookup(pAssignedCity:GetName());
			if pGovernor:IsEstablished() then
				assignmentText = assignmentText .. Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_ESTABLISHED_IN") .. "[NEWLINE]   " .. cityName;
			else
				assignmentText = assignmentText .. Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_TRANSITIONING_TO") .. "[NEWLINE]   " .. cityName;

				local iTurnsOnSite = pGovernor:GetTurnsOnSite();
				local iTurnsToEstablish = pGovernor:GetTurnsToEstablish();
				local iTurnsUntilEstablished = iTurnsToEstablish - iTurnsOnSite;

				assignmentText = assignmentText .. " " .. Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_TRANSITION_TURNS", iTurnsUntilEstablished);
			end
		else
			local iNeutralizedTurns = pGovernor:GetNeutralizedTurns();
			if (iNeutralizedTurns > 0) then
				assignmentText = assignmentText .. Locale.Lookup("LOC_GOVERNORS_GOVERNOR_NEUTRALIZED") .. "[NEWLINE]";
				assignmentText = assignmentText .. Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_TRANSITION_TURNS", iNeutralizedTurns);
			else
				assignmentText = assignmentText .. Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_NEEDS_ASSIGNMENT");
			end
		end
	else
		assignmentText  = Locale.Lookup("LOC_GOVERNORS_SCREEN_BUTTON_ASSIGN_GOVERNOR");
	end

	return assignmentText;
end

-- ===========================================================================
-- Finds the governor in the players governor list
-- Returns nil if the player has not appointed that governor
-- ===========================================================================
function GetAppointedGovernor(playerID:number, governorTypeIndex:number)
	-- Make sure we're looking for a valid governor
	if playerID < 0 or governorTypeIndex < 0 then
		return nil;
	end

	-- Get the player governor list
	local pGovernorDef = GameInfo.Governors[governorTypeIndex];
	local pPlayer:table = Players[playerID];
	local pPlayerGovernors:table = pPlayer:GetGovernors();
	local bHasGovernors, tGovernorList = pPlayerGovernors:GetGovernorList();

	-- Find and return the governor from the governor list
	if pPlayerGovernors:HasGovernor(pGovernorDef.Hash) then
		for i,governor in ipairs(tGovernorList) do
			if governor:GetType() == governorTypeIndex then
				return governor;
			end
		end
	end

	-- Return nil if this player has not appointed that governor
	return nil;
end

-- ===========================================================================
function GetGovernorStatus(governorDef:table, governor:table)
	if governor then
		local numOfNeutralizedTurns:number = governor:GetNeutralizedTurns();
		local pAssignedCity:table = governor:GetAssignedCity();
		if numOfNeutralizedTurns > 0 then
			-- Neutralized
			return Locale.Lookup("LOC_GOVERNORS_SCREEN_NEUTRALIZED"), Locale.Lookup("LOC_GOVERNORS_SCREEN_NEUTRALIZED_TURNS_REMAINING", numOfNeutralizedTurns);
		elseif pAssignedCity then
			local cityName = Locale.Lookup(pAssignedCity:GetName());
			if governor:IsEstablished() then
				-- Established in a city
				return Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_ESTABLISHED_IN"), cityName;
			else
				-- Currently establishing in a city
				return Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_TRANSITIONING_TO"), Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_NAME_WITH_TURNS", cityName, governor:GetTurnsToEstablish() - governor:GetTurnsOnSite());
			end
		else
			return Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_NEEDS_ASSIGNMENT"), "";
		end
	else
		-- If governor is nil we assume we're not appointed yet
		return Locale.Lookup("LOC_GOVERNORS_SCREEN_GOVERNOR_CANDIDATE"), "";
	end
end

-- ===========================================================================
function AnyCitiesWithoutAGovernor()
	local pLocalPlayerCities:table = Players[Game.GetLocalPlayer()]:GetCities();
	for i,pCity in pLocalPlayerCities:Members() do
		if pCity:GetAssignedGovernor() == nil then
			return true;
		end
	end

	return false;
end

-- ===========================================================================
function IsCannotAssign(governorDef:table)
	if (governorDef ~= nil) then
		if (GameInfo.GovernorsCannotAssign ~= nil) then
			for row in GameInfo.GovernorsCannotAssign() do
				if (row ~= nil) then
					if (row.GovernorType == governorDef.GovernorType) then
						return row.CannotAssign;
					end
				end
			end
		end
	end

	return false;
end

-- ===========================================================================
function IsPromotionHidden(governorPromotionHash:number, playerID:number, governorTypeIndex:number)
	local promotionDef:table = GameInfo.GovernorPromotions[governorPromotionHash];
	if (playerID ~= -1 and promotionDef ~= nil) then
		local hiddenWithoutPrereq:boolean = false;
		if (GameInfo.GovernorPromotionConditions ~= nil) then
			for row in GameInfo.GovernorPromotionConditions() do
				if (row.GovernorPromotionType == promotionDef.GovernorPromotionType) then
					hiddenWithoutPrereq = row.HiddenWithoutPrereqs;
				end
			end
		end

		if (hiddenWithoutPrereq) then
			if (not HasPromotionPrerequisites(governorPromotionHash, playerID, governorTypeIndex)) then
				return true;
			end
		end
	end
	return false;
end

-- ===========================================================================
function GetPromotionHiddenName(governorPromotionHash:number)
	local s:string = Locale.Lookup("LOC_GOVERNOR_PROMOTION_UNKNOWN_NAME");
	if (s == "LOC_GOVERNOR_PROMOTION_UNKNOWN_NAME") then
		s = "?";
	end
	return s;
end

-- ===========================================================================
function GetPromotionHiddenDescription(governorPromotionHash:number)
	local s:string = Locale.Lookup("LOC_GOVERNOR_PROMOTION_UNKNOWN_DESCRIPTION");
	if (s == "LOC_GOVERNOR_PROMOTION_UNKNOWN_DESCRIPTION") then
		s = "?";
	end
	return s;
end

-- ===========================================================================
function HasPromotionPrerequisites(governorPromotionHash:number, playerID:number, governorTypeIndex:number)
	local promotionDef:table = GameInfo.GovernorPromotions[governorPromotionHash];
	local governorInstance:table = GetAppointedGovernor(playerID, governorTypeIndex);
	if (promotionDef ~= nil and governorInstance ~= nil) then
		for row in GameInfo.GovernorPromotionPrereqs() do
			if (row.GovernorPromotionType == promotionDef.GovernorPromotionType) then
				local prereqPromotionDef:table = GameInfo.GovernorPromotions[row.PrereqGovernorPromotion];
				if (prereqPromotionDef ~= nil and not governorInstance:HasPromotion(prereqPromotionDef.Hash)) then
					return false;
				end
			end
		end
		return true;
	end
	return false;
end

-- ===========================================================================
function SetButtonTexture(control:table, texture:string)
	control:SetTexture(texture);
	control:SetVisState(0); -- Workaround for VisState breaking when switching textures
end