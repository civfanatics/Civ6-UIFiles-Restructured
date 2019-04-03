Relationship =
{
	m_kValidAIRelationships = {
		"DIPLO_STATE_ALLIED",
		"DIPLO_STATE_DECLARED_FRIEND",
		"DIPLO_STATE_DENOUNCED",
		"DIPLO_STATE_WAR",
		"DIPLO_STATE_UNFRIENDLY",
		"DIPLO_STATE_FRIENDLY"
	},

	m_kValidHumanRelationships = {
		"DIPLO_STATE_ALLIED",
		"DIPLO_STATE_DECLARED_FRIEND",
		"DIPLO_STATE_DENOUNCED",
		"DIPLO_STATE_WAR"
	},

	-- ===========================================================================
	IsValidWithAI = function( relationshipType:string )
		for _, type:string in ipairs(Relationship.m_kValidAIRelationships) do
			if relationshipType == type then
				return true;
			end
		end
		return false;
	end,

	-- ===========================================================================
	IsValidWithHuman = function( relationshipType:string )
		for _, type:string in ipairs(Relationship.m_kValidHumanRelationships) do
			if relationshipType == type then
				return true;
			end
		end
		return false;
	end
}



