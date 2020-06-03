-- Copyright 2017-2019, Firaxis Games

-- ===========================================================================
--	Define
-- ===========================================================================
CivicUnlockIcon = {};


-- ===========================================================================
--	Call this to get an instance.
--	It will combine the UI control generated from the passed in instance
--	manager with the functions of this class.
-- ===========================================================================
function CivicUnlockIcon.GetInstance( kIM:table, uiParent:table )
	local ui :table = kIM:GetInstance( uiParent );	
	return CivicUnlockIcon:new( ui );
end

-- ===========================================================================
-- Constructor
-- ===========================================================================
function CivicUnlockIcon.new(self, ui:table)
	local object = setmetatable(ui, {__index = self});
	return object ;
end

-- ===========================================================================
function CivicUnlockIcon:UpdateIcon(icon:string, tooltip:string, onClick:ifunction)
	self.Icon:SetIcon(icon);
	self.Top:SetToolTipString(tooltip);

	if onClick then
		self.Top:RegisterCallback(Mouse.eLClick, onClick);
	else
		self.Top:ClearCallback(Mouse.eLClick);
	end
end

-- ===========================================================================
function CivicUnlockIcon:UpdateNumberedIcon(value:number, icon:string, tooltip:string, onClick:ifunction)
	self.FontIcon:SetText(icon);
	self.Top:SetToolTipString(tooltip);
	self.NumberLabel:SetText(tostring(value));

	if onClick then
		self.Top:RegisterCallback(Mouse.eLClick, onClick);
	else
		self.Top:ClearCallback(Mouse.eLClick);
	end
end