include("CityStates_Expansion1");

-- ===========================================================================
-- Variables
-- ===========================================================================

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_GetSuzerainBonusText = GetSuzerainBonusText;

-- ===========================================================================
function GetSuzerainBonusText(playerID:number)
	local leader	:string = PlayerConfigurations[playerID]:GetLeaderTypeName();
	local leaderInfo:table	= GameInfo.Leaders[leader];
	local player = Players[playerID];
	if leaderInfo == nil then
		UI.DataError("GetSuzerainBonusText, cannot determine the type of city state suzerain bonus for player #: "..tostring(playerID) );
		return "UNKNOWN";
	end

	local text		:string = "";
	
	-- Unique Bonus
	for leaderTraitPairInfo in GameInfo.LeaderTraits() do
		if (leader ~= nil and leader == leaderTraitPairInfo.LeaderType) then
			local traitInfo : table = GameInfo.Traits[leaderTraitPairInfo.TraitType];
			if (traitInfo ~= nil) then
				local name = PlayerConfigurations[playerID]:GetCivilizationShortDescription();
				text = text .. "[COLOR:SuzerainDark]" .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_UNIQUE_BONUS", name) .. "[ENDCOLOR] ";
				if (player ~= nil) then
					if (player:GetInfluence():IsSuzerainUniqueBonusDisabled()) then
						text = text .. " [COLOR:Civ6Red]" .. Locale.Lookup("LOC_CITY_STATE_PANEL_UNIQUE_SUZERAIN_BONUS_DISABLED") .. "[ENDCOLOR] ";
					end
				end
				if traitInfo.Description ~= nil then
					text = text .. Locale.Lookup(traitInfo.Description);
				end
			end
		end
	end	

	-- Diplomatic Bonus
	text = text .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_DIPLOMATIC_BONUS");
	
	local comma_separator = Locale.Lookup("LOC_GRAMMAR_COMMA_SEPARATOR");

	-- Resources Available
	local resourceIcons	:string = "";
	if (player ~= nil) then
		for resourceInfo in GameInfo.Resources() do
			local resource = resourceInfo.Index;
			-- Include exports and accumulated resources, so we see what another player is getting if suzerain
			if (player:GetResources():HasResource(resource) or player:GetResources():HasExportedResource(resource) or player:GetResources():GetResourceAccumulationPerTurn(resource) > 0) then
				local amount = player:GetResources():GetResourceAccumulationPerTurn(resource); -- Accumulated resources (strategics)
				if (amount == 0) then
					amount = player:GetResources():GetResourceAmount(resource) + player:GetResources():GetExportedResourceAmount(resource); -- "Access" resources (luxuries, bonuses)
				end
				if (resourceIcons ~= "") then
					resourceIcons = resourceIcons .. comma_separator;
				end
				resourceIcons = resourceIcons .. amount .. " [ICON_" .. resourceInfo.ResourceType .. "] " .. Locale.Lookup(resourceInfo.Name);
			end
		end
	end
	if (resourceIcons ~= "") then
		text = text .. " " .. resourceIcons;
	else
		text = text .. " " .. Locale.Lookup("LOC_CITY_STATES_SUZERAIN_NO_RESOURCES_AVAILABLE");
	end

	return text;
end