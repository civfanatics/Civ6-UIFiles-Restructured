include("InstanceManager");
include("CivicUnlockIcon");

table.insert(g_ExtraIconData, {

	ModifierType = "MODIFIER_PLAYER_GRANT_INFLUENCE_TOKEN",
	IM = InstanceManager:new( "CivicUnlockNumberedInstance", "Top"),
	
	Initialize = function(self:table, rootControl:table, itemData:table)
		local instance = CivicUnlockIcon.GetInstance(self.IM, rootControl);
		local numValue = tonumber(itemData.ModifierValue);
		instance:UpdateNumberedIcon(
			numValue,
			"[Icon_Envoy]",
			Locale.Lookup("LOC_CIVIC_ENVOY_AWARDED_TOOLTIP", numValue),
			itemData.Callback);
	end,

	Reset = function(self)
		self.IM:ResetInstances();
	end
});