-- Copyright 2017-2018, Firaxis Games

-- ===========================================================================
--	Does the game rules have a capability enabled?
-- ===========================================================================
function HasCapability(c)
	return GameInfo.GameCapabilities[c] ~= nil;
end

-- ===========================================================================
--	Does a certain player have a trait.
--	traitName	The trait to look up
--	playerId	(optional) The player's ID to check, if NIL assumes local player
--	RETURNS: true if leader or civ has the trait.
-- ===========================================================================
function HasTrait( traitName:string, playerId:number )
	if playerId == nil then playerId = Game.GetLocalPlayer(); end
	if playerId == -1 then return false; end	-- Autoplay.
	
	local config :table = PlayerConfigurations[playerId];
	if(config ~= nil) then
		local leaderType:string = config:GetLeaderTypeName();
		local civType	:string = config:GetCivilizationTypeName();
		if leaderType then
			for row in GameInfo.LeaderTraits() do
				if row.LeaderType==leaderType and row.TraitType == traitName then
					return true;
				end
			end
		end
		if civType then
			for row in GameInfo.CivilizationTraits() do
				if row.CivilizationType== civType then
					if row.TraitType == traitName then
						return true;
					end
				end
			end
		end
	end
	return false;
end