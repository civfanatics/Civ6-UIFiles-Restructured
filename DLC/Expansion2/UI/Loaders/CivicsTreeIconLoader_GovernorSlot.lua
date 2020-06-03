include("InstanceManager");
include("CivicUnlockIcon");

g_ExtraIconData["MODIFIER_PLAYER_ADJUST_GOVERNOR_POINTS"] = {
	IM = InstanceManager:new( "CivicUnlockNumberedInstance", "Top"),
	
	Initialize = function(self:table, rootControl:table, itemData:table)
			local instance = CivicUnlockIcon.GetInstance(self.IM, rootControl);
			instance:UpdateNumberedIcon(1, "[Icon_Governor]", Locale.Lookup("LOC_HUD_CIVICS_TREE_AWARD_GOVERNOR"), itemData.Callback);
		end,

	Reset = function(self)
		self.IM:ResetInstances();
	end,

	Destroy = function(self)
		self.IM:DestroyInstances();
	end

};
