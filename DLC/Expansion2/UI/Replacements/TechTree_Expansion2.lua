-- ===========================================================================
--	TechTree Replacement
--	Civilization VI, Firaxis Games
-- ===========================================================================
include("TechTree_Expansion1");

-- ===========================================================================
--	Can a tech be searched; true if revealed.
-- ===========================================================================
function IsSearchable(techType)
	local kData:table = GetLiveData();
	return kData[techType]["IsRevealed"];
end
