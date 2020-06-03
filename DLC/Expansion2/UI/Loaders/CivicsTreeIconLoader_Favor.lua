include("InstanceManager");
include("CivicUnlockIcon");

g_ExtraIconData["MODIFIER_PLAYER_ADD_FAVOR"] = {
	IM = InstanceManager:new( "CivicUnlockNumberedInstance", "Top"),
	
	Initialize = function(self:table, rootControl:table, itemData:table)
			local instance = CivicUnlockIcon.GetInstance(self.IM, rootControl);
			local numValue = tonumber(itemData.ModifierValue);
			instance:UpdateNumberedIcon(numValue, "[ICON_FAVOR]", Locale.Lookup("LOC_HUD_CIVICS_TREE_AWARD_FAVOR", numValue), itemData.Callback);
		end,

	Reset = function(self)
		self.IM:ResetInstances();
	end,

	Destroy = function(self)
		self.IM:DestroyInstances();
	end


};
