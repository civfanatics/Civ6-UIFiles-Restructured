--[[
-- Created by Samuel Batista on Friday Apr 19 2017
-- Copyright (c) Firaxis Games
--]]

include("LuaClass");

------------------------------------------------------------------
-- Class Table
------------------------------------------------------------------
CivicUnlockIcon = LuaClass:Extend()

------------------------------------------------------------------
-- Class Constants
------------------------------------------------------------------
CivicUnlockIcon.DATA_FIELD_CLASS = "CIVIC_UNLOCK_ICON_CLASS";

------------------------------------------------------------------
-- Constructor
------------------------------------------------------------------
function CivicUnlockIcon.new(instance:table)
	self = LuaClass.new(CivicUnlockIcon)
	self.Controls = instance or Controls;
	return self;
end

function CivicUnlockIcon.GetInstance(instanceManager:table, newParent:table)
	local instance = instanceManager:GetInstance(newParent);
	self = instance[CivicUnlockIcon.DATA_FIELD_CLASS];
	if not self then
		self = CivicUnlockIcon.new(instance);
		instance[CivicUnlockIcon.DATA_FIELD_CLASS] = self;
	end
	return self, instance;
end

------------------------------------------------------------------
-- Member Functions
------------------------------------------------------------------
function CivicUnlockIcon:UpdateIcon(icon:string, tooltip:string, onClick:ifunction)
	self.Controls.Icon:SetIcon(icon);
	self.Controls.Top:SetToolTipString(tooltip);

	if onClick then
		self.Controls.Top:RegisterCallback(Mouse.eLClick, onClick);
	else
		self.Controls.Top:ClearCallback(Mouse.eLClick);
	end
end

function CivicUnlockIcon:UpdateNumberedIcon(value:number, icon:string, tooltip:string, onClick:ifunction)
	self.Controls.FontIcon:SetText(icon);
	self.Controls.Top:SetToolTipString(tooltip);
	self.Controls.NumberLabel:SetText(tostring(value));

	if onClick then
		self.Controls.Top:RegisterCallback(Mouse.eLClick, onClick);
	else
		self.Controls.Top:ClearCallback(Mouse.eLClick);
	end
end