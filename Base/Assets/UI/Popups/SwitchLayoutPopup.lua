-- ===========================================================================
--	Copyright 2020, Firaxis Games
-- ===========================================================================

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID	 :string = "SwitchLayoutPopup"; -- Unique name for hotreload

-- ===========================================================================
function Open()
	UIManager:QueuePopup(ContextPtr, PopupPriority.Current);
end

-- ===========================================================================
function Close()
	if not ContextPtr:IsHidden() then
		UI.PlaySound("UI_Screen_Close");
	end
		
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
function OnClose()
	if not ContextPtr:IsHidden() then
		Close();
	end
end

-- ===========================================================================
function OnPCLayoutButton()
	if not ContextPtr:IsHidden() then
		Input.SetActiveLayout(InputLayoutTypes.PC);
		Close();
	end
end

-- ===========================================================================
function OnConsoleLayoutButton()
	if not ContextPtr:IsHidden() then
		Input.SetActiveLayout(InputLayoutTypes.CONSOLE);
		Close();
	end
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp and pInputStruct:GetKey() == Keys.VK_ESCAPE then
		Close();
		return true;
	end

	return false;
end

-- ===========================================================================
function OnInit(isReload:boolean)
	LateInitialize();
end

-- ===========================================================================
function LateInitialize()
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.PCLayoutButton:RegisterCallback(Mouse.eLClick, OnPCLayoutButton);
	Controls.ConsoleLayoutButton:RegisterCallback(Mouse.eLClick, OnConsoleLayoutButton);

	LuaEvents.SwitchLayoutPopup_OpenSwitchLayoutPopup.Add(Open);
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.SwitchLayoutPopup_OpenSwitchLayoutPopup.Remove(Open);
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShutdown(OnShutdown);
end
Initialize();