
-- ===========================================================================
function GetLoyaltyPressureIconTooltip(loyaltyPerTurn:number, playerID:number)
	local loyaltyPressureIconTooltip:string = "";

	local pPlayerConfig:table = PlayerConfigurations[playerID];

	if loyaltyPerTurn > 0 then
		loyaltyPressureIconTooltip = Locale.Lookup("LOC_LOYALTY_IS_RISING_BY_X_TT", pPlayerConfig:GetCivilizationDescription(), Round(loyaltyPerTurn, 1));
	elseif loyaltyPerTurn < 0 then
		loyaltyPressureIconTooltip = Locale.Lookup("LOC_LOYALTY_IS_DROPPING_BY_X_TT", pPlayerConfig:GetCivilizationDescription(), Round(loyaltyPerTurn, 1))
	else
		loyaltyPressureIconTooltip = Locale.Lookup("LOC_LOYALTY_IS_NOT_CHANGING_TT", pPlayerConfig:GetCivilizationDescription());
	end

	return loyaltyPressureIconTooltip;
end

-- ===========================================================================
function GetLoyaltyStatusTooltip(city:table)
	local tooltip:string = "";
	
	local isLoyaltyRising:boolean = false;
	local isLoyaltyFalling:boolean = false;
	local pCulturalIdentity:table = city:GetCulturalIdentity();
	if pCulturalIdentity then
		local conversionOutcome:number = pCulturalIdentity:GetConversionOutcome();
		local turnsToConversion:number = pCulturalIdentity:GetTurnsToConversion();
		if conversionOutcome == IdentityConversionOutcome.GAINING_LOYALTY then
			isLoyaltyRising = true;
			if (turnsToConversion > 0) then
				tooltip = tooltip .. Locale.Lookup("LOC_HUD_CITY_GAINING_LOYALTY", turnsToConversion);
			else
				tooltip = tooltip .. Locale.Lookup("LOC_HUD_CITY_FULL_LOYALTY");
			end
		elseif conversionOutcome == IdentityConversionOutcome.LOSING_LOYALTY then
			isLoyaltyFalling = true;
			tooltip = tooltip .. Locale.Lookup("LOC_HUD_CITY_LOSING_LOYALTY", turnsToConversion);
		else
			tooltip = tooltip .. Locale.Lookup("LOC_HUD_CITY_STABLE_LOYALTY");
		end
	end

	return tooltip, isLoyaltyRising, isLoyaltyFalling;
end