include( "InGameTopOptionsMenu" );

function OnExpansionIntro()
	Controls.PauseWindow:SetHide(true);
	LuaEvents.InGameTopOptionsMenu_ShowExpansionIntro();
end

function Initialize()
	local bWorldBuilder = WorldBuilder and WorldBuilder:IsActive();
	if(bWorldBuilder) then
		Controls.ExpansionNewFeatures:SetHide(true);
	else
		Controls.ExpansionNewFeatures:SetHide(false);
		Controls.ExpansionNewFeatures:RegisterCallback( Mouse.eLClick, OnExpansionIntro );
		Controls.ExpansionNewFeatures:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	end
end
Initialize();