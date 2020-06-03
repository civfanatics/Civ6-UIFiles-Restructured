
-- ===========================================================================
function GetGoldenAgeThresholdTooltip(playerID:number)
	local pGameEras:table = Game.GetEras();

	local previousEraScore:number = pGameEras:GetPlayerThresholdBaseline(playerID);

	local goldenAgeThresholdTooltip:string = previousEraScore .. " : " .. Locale.Lookup("LOC_ERA_REVIEW_POPUP_THRESHOLD_BASELINE");
	local goldenAgeThresholdBreakdown:table = pGameEras:GetPlayerGoldenAgeThresholdBreakdown(playerID);
	for _,source in ipairs(goldenAgeThresholdBreakdown) do
		for sourceString,sourceValue in pairs(source) do
			local sourceValuePrefix = "[NEWLINE]+";
			if (sourceValue < 0) then
				sourceValuePrefix = "[NEWLINE]";
			end
			goldenAgeThresholdTooltip = goldenAgeThresholdTooltip .. sourceValuePrefix .. sourceValue .. " : " .. sourceString;
		end
	end

	return goldenAgeThresholdTooltip;
end

-- ===========================================================================
function GetDarkAgeThresholdTooltip(playerID:number)
	local pGameEras:table = Game.GetEras();

	local previousEraScore:number = pGameEras:GetPlayerThresholdBaseline(playerID);

	local darkAgeThresholdTooltip:string = previousEraScore .. " : " .. Locale.Lookup("LOC_ERA_REVIEW_POPUP_THRESHOLD_BASELINE");
	local darkAgeThresholdBreakdown:table = pGameEras:GetPlayerDarkAgeThresholdBreakdown(playerID);
	for _,source in ipairs(darkAgeThresholdBreakdown) do
		for sourceString,sourceValue in pairs(source) do
			local sourceValuePrefix = "[NEWLINE]+";
			if (sourceValue < 0) then
				sourceValuePrefix = "[NEWLINE]";
			end
			darkAgeThresholdTooltip = darkAgeThresholdTooltip .. sourceValuePrefix .. sourceValue .. " : " .. sourceString;
		end
	end

	return darkAgeThresholdTooltip;	
end