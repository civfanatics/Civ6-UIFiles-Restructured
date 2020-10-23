-- ===========================================================================
--	Support functions for Units and their associated systems
--	- Unit Abilities
--	- Unit Commands
--	- Unit Stats
-- ===========================================================================
include("SupportFunctions");

-- ===========================================================================
-- Get a Unit Ability description string
function GetUnitAbilityDescription( eUnitAbilityID:number )
	if eUnitAbilityID == nil or eUnitAbilityID == -1 then
		return "";
	end

	local pAbilityDef = GameInfo.UnitAbilities[eUnitAbilityID];
	if pAbilityDef == nil then
		return "";
	end

	-- If the ability def has a set description, use that
	if (pAbilityDef.Description ~= nil and pAbilityDef.Description ~= "") then
		return Locale.Lookup(pAbilityDef.Description);
	end

	-- If no set definition, try to compose it from the ability's associated modifier summaries
	local tSummaries:table = UnitManager.GetAbilitySummaries(pAbilityDef.Index);
	if (tSummaries ~= nil and #tSummaries > 0) then
		return FormatTableAsString(tSummaries);
	end

	-- None
	return "";
end