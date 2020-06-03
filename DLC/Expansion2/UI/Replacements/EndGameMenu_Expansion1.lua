include("GameCapabilities");

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
	LuaEvents.EndGameMenu_OpenHistoricMoments(Controls.HistoricMoments);
end

function OnExportHistoricMoments()
	 local path, filename = Game.GetHistoryManager():WritePrideMomentInfo();

	 if (not m_kPopupDialog:IsOpen()) then
		m_kPopupDialog:AddTitle(Locale.ToUpper("LOC_END_GAME_MENU_EXPORT_HISTORIAN_BUTTON"));
		m_kPopupDialog:AddText(path);
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_OK_BUTTON"), nil);
		m_kPopupDialog:Open();
	end
end

TruncateStringWithTooltip(Controls.HistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_HISTORIAN_BUTTON"));
Controls.HistoricMoments:RegisterCallback( Mouse.eLClick, OnHistoricMoments );
Controls.HistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

TruncateStringWithTooltip(Controls.ExportHistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_EXPORT_HISTORIAN_BUTTON"));
Controls.ExportHistoricMoments:RegisterCallback( Mouse.eLClick, OnExportHistoricMoments );
Controls.ExportHistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);


if HasCapability("CAPABILITY_HISTORIC_MOMENTS") then
	TruncateStringWithTooltip(Controls.HistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_HISTORIAN_BUTTON"));
	Controls.HistoricMoments:RegisterCallback( Mouse.eLClick, OnHistoricMoments );
	Controls.HistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	TruncateStringWithTooltip(Controls.ExportHistoricMoments, MAX_BUTTON_SIZE, Locale.Lookup("LOC_END_GAME_MENU_EXPORT_HISTORIAN_BUTTON"));
	Controls.ExportHistoricMoments:RegisterCallback( Mouse.eLClick, OnExportHistoricMoments );
	Controls.ExportHistoricMoments:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
else
	Controls.HistoricMoments:SetHide(true);
	Controls.ExportHistoricMoments:SetHide(true);
end