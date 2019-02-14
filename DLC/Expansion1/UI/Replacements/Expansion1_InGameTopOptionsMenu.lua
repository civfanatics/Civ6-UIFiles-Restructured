include( "InGameTopOptionsMenu" );

function OnExpansionIntro()
	Controls.PauseWindow:SetHide(true);
	LuaEvents.InGameTopOptionsMenu_ShowExpansionIntro();
end

function Initialize()
	Controls.ExpansionNewFeatures:RegisterCallback( Mouse.eLClick, OnExpansionIntro );
	Controls.ExpansionNewFeatures:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end
Initialize();