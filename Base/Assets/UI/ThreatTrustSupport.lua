-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local THREAT_TOOLTIPS:table =
{
	[DiplomaticThreatTypes.UNKNOWN_THREAT]	= "LOC_DIPLOMACY_THREAT_UNKNOWN_TT",
	[DiplomaticThreatTypes.NO_THREAT]		= "LOC_DIPLOMACY_THREAT_NEGLIGABLE_TT",
	[DiplomaticThreatTypes.MINOR_THREAT]	= "LOC_DIPLOMACY_THREAT_LOW_TT",
	[DiplomaticThreatTypes.MODERATE_THREAT] = "LOC_DIPLOMACY_THREAT_MODERATE_TT",
	[DiplomaticThreatTypes.MAJOR_THREAT]	= "LOC_DIPLOMACY_THREAT_MAJOR_TT"
}
setmetatable(THREAT_TOOLTIPS, { __index = function(key) UI.DataError("Invalid Threat Tooltip Index: " .. key); return "" end });

local TRUST_TOOLTIPS:table =
{
	[DiplomaticTrustTypes.UNKNOWN_TRUST]	= "LOC_DIPLOMACY_TRUST_UNKNOWN_TT",
	[DiplomaticTrustTypes.NO_TRUST]			= "LOC_DIPLOMACY_TRUST_NO_TRUST_TT",
	[DiplomaticTrustTypes.DISTRUSTED]		= "LOC_DIPLOMACY_TRUST_DISTRUSTED_TT",
	[DiplomaticTrustTypes.LOW_TRUST]		= "LOC_DIPLOMACY_TRUST_LOW_TRUST_TT",
	[DiplomaticTrustTypes.SOME_TRUST]		= "LOC_DIPLOMACY_TRUST_BARELY_KNOWN_TT",
	[DiplomaticTrustTypes.BARELY_KNOWN]		= "LOC_DIPLOMACY_TRUST_SOME_TRUST_TT",
	[DiplomaticTrustTypes.TRUSTED]			= "LOC_DIPLOMACY_TRUST_TRUSTED_TT"
}
setmetatable(TRUST_TOOLTIPS, { __index = function(key) UI.DataError("Invalid Trust Tooltip Index: " .. key); return "" end });

------------------------------------------------------------------------------
function GetThreatStringAndTooltip(playerID:number)
	local threatString:string = "";
	local threatTooltip:string = "";

	local pLocalPlayer:table = Players[Game.GetLocalPlayer()];
	if pLocalPlayer then
		local pLocalPlayerDiploAI:table = pLocalPlayer:GetDiplomaticAI();
		if pLocalPlayerDiploAI then
			threatString = Locale.Lookup(pLocalPlayerDiploAI:GetThreatString(playerID));

			local pOtherPlayerConfig:table = PlayerConfigurations[playerID];
			-- Some of tooltips require the other leaders name. The ones that do not simply ignore the extra param in the Locale.Lookup
			threatTooltip = Locale.Lookup(THREAT_TOOLTIPS[pLocalPlayerDiploAI:GetThreatFrom(playerID)], pOtherPlayerConfig:GetLeaderName());
		end
	end

	return threatString, threatTooltip;
end

------------------------------------------------------------------------------
function GetTrustStringAndTooltip(playerID:number)
	local trustString:string = "";
	local trustTooltip:string = "";

	local pLocalPlayer:table = Players[Game.GetLocalPlayer()];
	if pLocalPlayer then
		local pLocalPlayerDiploAI:table = pLocalPlayer:GetDiplomaticAI();
		if pLocalPlayerDiploAI then
			trustString = Locale.Lookup(pLocalPlayerDiploAI:GetTrustString(playerID));

			local pOtherPlayerConfig:table = PlayerConfigurations[playerID];
			-- Some of tooltips require the other leaders name. The ones that do not simply ignore the extra param in the Locale.Lookup
			trustTooltip = Locale.Lookup(TRUST_TOOLTIPS[pLocalPlayerDiploAI:GetTrustFrom(playerID)], pOtherPlayerConfig:GetLeaderName());
		end
	end

	return trustString, trustTooltip;
end