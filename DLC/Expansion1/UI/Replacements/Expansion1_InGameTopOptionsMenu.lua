include( "InGameTopOptionsMenu" );

function OnRiseAndFall()
	LuaEvents.ExpansionIntro_Show();
end

function Initialize()
	Controls.RiseAndFall:RegisterCallback( Mouse.eLClick, OnRiseAndFall );
	Controls.RiseAndFall:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end
Initialize();