-- ===========================================================================
--	CivicsTree Replacement
--	Civilization VI, Firaxis Games
-- ===========================================================================
include("CivicsTree");

-- ===========================================================================
--	Can a civic be searched; true if revealed.
-- ===========================================================================
function IsSearchable(civicType)
	local kData:table = GetLiveData();
	return kData[civicType]["IsRevealed"];
end


