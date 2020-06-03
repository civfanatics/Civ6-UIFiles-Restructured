
local g_nInstanceCounter = 0;
function OnNotificationPanelInput(pInputStruct)
	local eMsg = pInputStruct:GetMessageType();
	if (eMsg == MouseEvents.LButtonUp or eMsg == MouseEvents.PointerUp) then
		g_nInstanceCounter = g_nInstanceCounter + 1;
		local pInstance = Widgets.NovaTest:ConstructBlueprint("NotificationInstance", Widgets.NotificationScroll);
		pInstance.root.Text:SetText("  " .. g_nInstanceCounter);
		return true;
	end

	return false;
end

function Initialize()

	Widgets.NotificationPanelBG.Input:SetCallback(OnNotificationPanelInput);

end