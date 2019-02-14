-- Copyright 2018, Firaxis Games
include("GovernmentScreen_Expansion1");

-- ===========================================================================
--	OVERRIDE
--	RETURNS: true if policy is available to the player at this time.
-- ===========================================================================
function IsPolicyAvailable( kPlayerCulture:table, policyHash:number )
	local isPolicyObtainable	:boolean = not kPlayerCulture:IsPolicyBanned( policyHash );
	local isSlottable			:boolean = kPlayerCulture:CanPolicyBeSlotted( policyHash );
	local isRelevant			:boolean = not kPlayerCulture:IsPolicyObsolete( policyHash );
	
	return isPolicyObtainable and isSlottable and isRelevant;
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function GetGovernmentStatsText(governmentType:string)
	local text:string = "";
	local governmentInfo:table = GameInfo.Governments[governmentType];
	if (governmentInfo ~= nil) then
		for governmentXP2Info in GameInfo.Governments_XP2() do
			if (governmentXP2Info ~= nil and governmentXP2Info.GovernmentType == governmentType) then
				text = text .. "[ICON_FAVOR]" .. governmentXP2Info.Favor;
				break;	
			end
		end
		text = text .. "[ICON_Envoy]" .. governmentInfo.InfluenceTokensPerThreshold;
	end
	return text;
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function GetGovernmentStatsTooltip(governmentType:string)
	local text:string = "";
	local governmentInfo:table = GameInfo.Governments[governmentType];
	if (governmentInfo ~= nil) then
		for governmentXP2Info in GameInfo.Governments_XP2() do
			if (governmentXP2Info ~= nil and governmentXP2Info.GovernmentType == governmentType) then
				text = text .. Locale.Lookup("LOC_GOVT_FAVOR_PER_TURN", governmentXP2Info.Favor) .. "[NEWLINE][NEWLINE]";
				break;	
			end
		end
		text = text .. Locale.Lookup("LOC_GOVT_INFLUENCE_POINTS_TOWARDS_ENVOYS", governmentInfo.InfluencePointsPerTurn, governmentInfo.InfluencePointsThreshold, governmentInfo.InfluenceTokensPerThreshold);
	end
	return text;
end