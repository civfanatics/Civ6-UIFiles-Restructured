--	Copyright 2018, Firaxis Games
include( "FullscreenMapPopup" );

-- ===========================================================================
-- Super functions
-- ===========================================================================
BASE_LateInitialize = LateInitialize;


-- ===========================================================================
--	Game EVENT
-- ===========================================================================
function OnWorldCongressStage1()
	if UIManager:IsInPopupQueue( ContextPtr ) then
		Close();
	end
end

-- ===========================================================================
function LateInitialize()
	BASE_LateInitialize();
	Events.WorldCongressStage1.Add( OnWorldCongressStage1 );
end
