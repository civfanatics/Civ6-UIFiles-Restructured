------------------------------------------------------------------------------
--	Shared logic for discovering what techs and civics unlock.
------------------------------------------------------------------------------

BASE_GetUnlockableItems = GetUnlockableItems;

-- ===========================================================================
--  Returns an array of all possible items unlocked by an optional player id.
-- ===========================================================================
function GetUnlockableItems(playerId)
	
	local unlockables = BASE_GetUnlockableItems(playerId);

	local has_trait = GetTraitMapForPlayer(playerId);		-- Get the trait map for the player (expensive to calculate)
	if (GameInfo.Routes_XP2 ~= nil) then
		for row in GameInfo.Routes_XP2() do
			if(CanEverUnlock(has_trait, row)) then
				local baseTableRow = GameInfo.Routes[row.RouteType];
				if (baseTableRow ~= nil) then
					table.insert(unlockables, {row, row.RouteType, baseTableRow.Name, row.RouteType});
				end
			end
		end
	end

	return unlockables;
end