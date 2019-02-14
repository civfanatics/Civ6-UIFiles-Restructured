
-- [[ VARIABLES (can be watched in Tuner) ]]
TunerUtilities = {
	navIndex = nil,
	navOptions = nil,
	navSelected = nil,
	selectedControl = nil,
	controlUnderMouse = nil,
	mousePick = false,
}

-- [[ HELPER FUNCTIONS ]]
function TunerUtilities:Stringify(tableOrControl, key)
	if tableOrControl then
		if getmetatable(tableOrControl) then
			local id = tableOrControl:GetID();
			local type = tableOrControl:GetType();
			local context = tableOrControl.GetBaseFileName and tableOrControl:GetBaseFileName() or tableOrControl:GetContext():GetBaseFileName();
			return (key and key or "") .. ";" .. id .. ";" .. type .. ";" .. context;
		elseif #tableOrControl > 0 then
			local results = {};
			for i, v in ipairs(tableOrControl) do
				results[i] = self:Stringify(v, i);
			end
			return results;
		end
	end
end

function TunerUtilities:FromCSV(csv)
	if csv then
		local results = {};
		for v in string.gmatch(csv, "([^,]+)") do
				table.insert(results, v);
		end
		return results;
	end
end

--[[ NAVIGATION ]]
function TunerUtilities:GetNavigationOptions()
	self.navOptions = self.navSelected or UIManager:GetRootContexts();
	if self.navOptions then
		if self.navSelected and self.navSelected.GetChildren then
			self.navOptions = self.navSelected:GetChildren();
		end
		return self:Stringify(self.navOptions);
	end
end

function TunerUtilities:SetNavigationOption(selection)
	if selection and self.navOptions then
		self.navIndex = tonumber(selection);
		self:SetSelectedControl(self.navOptions[self.navIndex]);
	end
end

function TunerUtilities:GetModalNavigationOptions()
	self.modalNavOptions = self.modalNavSelected or UIManager:GetModalContexts();
	if self.modalNavOptions then
		if self.modalNavSelected and self.modalNavSelected.GetChildren then
			self.modalNavOptions = self.modalNavSelected:GetChildren();
		end
		return self:Stringify(self.modalNavOptions);
	end
end

function TunerUtilities:GetPopupNavigationOptions()
	self.popupNavOptions = self.popupNavSelected or UIManager:GetPopupStack();
	if self.popupNavOptions then
		local results = {};
		for i, v in ipairs(self.popupNavOptions) do
			results[i] = i .. ";" .. self.popupNavOptions[i].ID .. ";" .. self.popupNavOptions[i].Priority .. ";" .. self.popupNavOptions[i].Flags;
		end
		return results;
	end
end

function TunerUtilities:NavigateForward()
	self.navSelected = (self.navIndex and self.navOptions) and self.navOptions[self.navIndex] or nil;
	self:SetSelectedControl(self.navSelected);
end

function TunerUtilities:NavigateBackward()
	self.navSelected = self.navSelected and self.navSelected.GetParent and self.navSelected:GetParent() or nil;
	self:SetSelectedControl(self.navSelected);
end

function TunerUtilities:NavigateToRoot()
	self.navSelected = UIManager:GetRootContexts();
end

--[[ SELECTION ]]
function TunerUtilities:SetSelectedControl(control, updateNavSelection)
	if self.selectedControl then
		self.selectedControl:DisableDebugOutline();
	end
	if control then
		control:EnableDebugOutline();
	end
	self.selectedControl = control;
	if control and updateNavSelection then
		self.navSelected = #control:GetChildren() > 0 and control or control:GetParent();
	end
end

function TunerUtilities:GetSelectedControlPath()
	return self.selectedControl and self.selectedControl.GetPath and self.selectedControl:GetPath() or nil;
end

function TunerUtilities:SetSelectedControlPath(path)
	self.navSelected = ContextPtr:LookUpControl(path);
	self:SetSelectedControl(self.navSelected);
end

function TunerUtilities:GetSelectedChildren()
	return self.selectedControl and self:Stringify(self.selectedControl:GetChildren()) or nil;
end

function TunerUtilities:GetMouseOverControls()
	self.mouseOverControls = UIManager:GetMouseOverControls();
	return self:Stringify(self.mouseOverControls);
end

function TunerUtilities:SetMousePick(value)
	self.mousePick = value;
end

function TunerUtilities:GetControlUnderMouse()
	if not self.mousePick then return; end

	local control = UIManager:GetControlUnderMouse(ContextPtr);
	if control ~= self.controlUnderMouse then
		if self.controlUnderMouse then
			self.controlUnderMouse:DisableDebugOutline();
		end
		if control then
			control:EnableDebugOutline();
		end
		self.controlUnderMouse = control;
	end

	return true;
end

--[[ ID ]]
function TunerUtilities:GetSelectedID()
	return self.selectedControl and self.selectedControl:GetID() or nil;
end

--[[ TYPE ]]
function TunerUtilities:GetSelectedType()
	return self.selectedControl and self.selectedControl:GetType() or nil;
end

--[[ VISIBLE ]]
function TunerUtilities:GetSelectedVisible()
	return self.selectedControl and self.selectedControl:IsVisible() or nil;
end
function TunerUtilities:SetSelectedVisible(value)
	if self.selectedControl then self.selectedControl:SetShow(value) end
end

--[[ ENABLE ]]
function TunerUtilities:GetSelectedEnabled()
	return self.selectedControl and self.selectedControl:IsEnabled() or nil;
end

--[[ ALPHA ]]
function TunerUtilities:GetSelectedAlpha()
	return self.selectedControl and self.selectedControl:GetAlpha() or nil;
end
function TunerUtilities:SetSelectedAlpha(value)
	if self.selectedControl then self.selectedControl:SetAlpha(tonumber(value)); end
end

--[[ ANCHOR ]]
function TunerUtilities:GetSelectedAnchor()
	return self.selectedControl and self.selectedControl:GetAnchor() or nil;
end
function TunerUtilities:SetSelectedAnchor(value)
	if self.selectedControl then self.selectedControl:SetAnchor(value); end
end

--[[ OFFSET ]]
function TunerUtilities:GetSelectedOffset()
	return self.selectedControl and (self:GetSelectedOffsetX() .. ',' .. self:GetSelectedOffsetY()) or nil;
end
function TunerUtilities:SetSelectedOffset(value)
	local values = self:FromCSV(value);
	if values and #values == 2 then
		self:SetSelectedOffsetX(values[1]);
		self:SetSelectedOffsetY(values[2]);
	end
end
function TunerUtilities:GetSelectedOffsetX()
	return self.selectedControl and self.selectedControl:GetOffsetX() or nil;
end
function TunerUtilities:SetSelectedOffsetX(value)
	if self.selectedControl then self.selectedControl:SetOffsetX(value); end
end
function TunerUtilities:GetSelectedOffsetY()
	return self.selectedControl and self.selectedControl:GetOffsetY() or nil;
end
function TunerUtilities:SetSelectedOffsetY(value)
	if self.selectedControl then self.selectedControl:SetOffsetY(value); end
end

--[[ SIZE ]]
function TunerUtilities:GetSelectedSize()
	return self.selectedControl and (self:GetSelectedSizeX() .. ',' .. self:GetSelectedSizeY()) or nil;
end
function TunerUtilities:SetSelectedSize(value)
	local values = self:FromCSV(value);
	if values and #values == 2 then
		self:SetSelectedSizeX(values[1]);
		self:SetSelectedSizeY(values[2]);
	end
end
function TunerUtilities:GetSelectedSizeX()
	return self.selectedControl and self.selectedControl:GetSizeX() or nil;
end
	function TunerUtilities:SetSelectedSizeX(value)
	if self.selectedControl then self.selectedControl:SetSizeX(value); end
end
function TunerUtilities:GetSelectedSizeY()
	return self.selectedControl and self.selectedControl:GetSizeY() or nil;
end
function TunerUtilities:SetSelectedSizeY(value)
	if self.selectedControl then self.selectedControl:SetSizeY(value); end
end

--[[ INPUT ]]
function TunerUtilities:GetConsumesAllMouse()
	return self.selectedControl and self.selectedControl:GetConsumeMouseOver() or nil;
end
function TunerUtilities:SetConsumesAllMouse(value)
	if self.selectedControl then self.selectedControl:SetConsumeMouseOver(value); end
end
function TunerUtilities:GetConsumeMouseButton()
	return self.selectedControl and self.selectedControl:GetConsumeMouseButton() or nil;
end
function TunerUtilities:SetConsumeMouseButton(value)
	if self.selectedControl then self.selectedControl:SetConsumeMouseButton(value); end
end
function TunerUtilities:GetConsumeMouseWheel()
	return self.selectedControl and self.selectedControl:GetConsumeMouseWheel() or nil;
end
function TunerUtilities:SetConsumeMouseWheel(value)
	if self.selectedControl then self.selectedControl:SetConsumeMouseWheel(value); end
end

--[[ PARENT ]]
function TunerUtilities:GetParentID()
	return self.selectedControl and self.selectedControl:GetParent() and self.selectedControl:GetParent():GetID() or nil;
end
function TunerUtilities:GetParentType()
	return self.selectedControl and self.selectedControl:GetParent() and self.selectedControl:GetParent():GetType() or nil;
end
function TunerUtilities:GetParentContext()
	if self.selectedControl then
		local parent = self.selectedControl:GetParent();
		if parent then return parent.GetBaseFileName and parent:GetBaseFileName() or parent:GetContext():GetBaseFileName(); end
	end
	return nil;
end

--[[ TEXTURE ]]
function TunerUtilities:GetTexture()
	return self.selectedControl and self.selectedControl.GetTexture and self.selectedControl:GetTexture() or nil;
end
function TunerUtilities:SetTexture(value)
	if self.selectedControl and self.selectedControl.SetTexture then self.selectedControl:SetTexture(value); end
end

--[[ ANIMATION ]]
function TunerUtilities:PlayAnimation()
	if self.selectedControl and self.selectedControl.Play then self.selectedControl:Play(); end
end
function TunerUtilities:ReverseAnimation()
	if self.selectedControl and self.selectedControl.Reverse then self.selectedControl:Reverse(); end
end
function TunerUtilities:ResetAnimation()
	if self.selectedControl and self.selectedControl.SetToBeginning then self.selectedControl:SetToBeginning(); end
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function TunerUtilities.OnInputHandler( pInputStruct:table )
	if ( pInputStruct:GetMessageType() == KeyEvents.KeyUp ) then
		local key:number = pInputStruct:GetKey();
		if ( key == Keys.VK_CAPITAL ) then
			if TunerUtilities.mousePick then
				TunerUtilities:SetSelectedControl(TunerUtilities.controlUnderMouse, true);
			end
			TunerUtilities.mousePick = not TunerUtilities.mousePick;
			return true;
		end
	end

	return false;
end
UIManager:SetGlobalInputHandler( TunerUtilities.OnInputHandler );
