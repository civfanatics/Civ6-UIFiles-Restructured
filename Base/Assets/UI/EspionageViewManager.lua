
-- ===========================================================================
--	Class Table
-- ===========================================================================
EspionageViewManager = {
	m_kEspionageViewCity = nil;
}

-- ===========================================================================
-- Static-style initialization functions
-- ===========================================================================
function EspionageViewManager:CreateManager()
	local oNewManager:object = {};
	setmetatable(oNewManager, {__index = EspionageViewManager });
	return oNewManager;
end

-- ===========================================================================
function EspionageViewManager:SetEspionageViewCity( ownerID:number, cityID:number )
	local pOwner:table = Players[ownerID];
	if pOwner ~= nil then
		self.m_kEspionageViewCity = pOwner:GetCities():FindID(cityID);
	end
end

-- ===========================================================================
function EspionageViewManager:GetEspionageViewCity()
	return self.m_kEspionageViewCity;
end

-- ===========================================================================
function EspionageViewManager:ClearEspionageViewCity()
	self.m_kEspionageViewCity = nil;
end

-- ===========================================================================
function EspionageViewManager:IsEspionageView()
	return self.m_kEspionageViewCity ~= nil and UI.GetHeadSelectedCity() == nil;
end