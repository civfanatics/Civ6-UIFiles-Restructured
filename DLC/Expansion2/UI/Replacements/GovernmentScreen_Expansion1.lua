-- Copyright 2018, Firaxis Games
include("GovernmentScreen");

BASE_GetPolicyBGTexture = GetPolicyBGTexture;
BASE_PopulateLivePlayerData = PopulateLivePlayerData;
BASE_RealizeFilterTabs = RealizeFilterTabs;

-- ===========================================================================
function FilterDarkPolicies(policy)
    local policyDef = GameInfo.Policies_XP1[policy.PolicyHash];
    if policyDef ~= nil and policyDef.RequiresDarkAge then
        return true;
    end
    return false;
end

-- ===========================================================================
function GetPolicyBGTexture(policyType)
	local expansionPolicy = GameInfo.Policies_XP1[policyType];
	if expansionPolicy and expansionPolicy.RequiresDarkAge then
		return "Governments_DarkCard";
	end
	return BASE_GetPolicyBGTexture(policyType);
end

-- ===========================================================================
function PopulateLivePlayerData( ePlayer:number )
	
	if ePlayer == -1 then
		return;
	end

	BASE_PopulateLivePlayerData(ePlayer);

	if(ePlayer == Game.GetLocalPlayer() and m_kUnlockedPolicies) then
		local eraTable:table = Game.GetEras();
		if eraTable:HasDarkAge(ePlayer) and Game.GetCurrentGameTurn() == eraTable:GetCurrentEraStartTurn() then
			for policyType, isUnlocked in pairs(m_kUnlockedPolicies) do
				if isUnlocked then
					local expansionPolicy = GameInfo.Policies_XP1[policyType];
					if expansionPolicy and expansionPolicy.RequiresDarkAge then
						m_kNewPoliciesThisTurn[policyType] = true;
					end
				end
			end
		end
	end 
end

-- ===========================================================================
function RealizeFilterTabs()
    BASE_RealizeFilterTabs();
    CreatePolicyTabButton("LOC_GOVT_FILTER_DARK", FilterDarkPolicies);
end
