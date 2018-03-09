-- ===========================================================================
--	EndGameMenu - Expansion1 Changes
-- ===========================================================================
BASE_OnShowHide = OnShowHide;
BASE_OnReplayMovie = OnReplayMovie;

local bWasInHistoricMoments = false;

function OnShowHide( bIsHide, bIsInit )
	BASE_OnShowHide(bIsHide, bIsInit);

	if(bWasInHistoricMoments and not bIsHide) then
		bWasInHistoricMoments = false;
	end
end

function OnReplayMovie()
	if(bWasInHistoricMoments) then return end
	BASE_OnReplayMovie();
end


function OnHistoricMoments()
	bWasInHistoricMoments = true;
	LuaEvents.PrideMoments_OpenFromEndGame(Controls.HistoricMoments);
end
TruncateStringWithTooltip(Controls.HistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_HISTORIAN_BUTTON"));
Controls.HistoricMoments:RegisterCallback( Mouse.eLClick, OnHistoricMoments );
Controls.HistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);