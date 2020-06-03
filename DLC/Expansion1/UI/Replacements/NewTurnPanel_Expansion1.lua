--[[
-- Copyright (c) 2017 Firaxis Games
--]]
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("NewTurnPanel");

local m_LastShownCountdownTurn:number = -1;

function ShowEraCountdownPanel()
	local eraCountdown = Game.GetEras():GetNextEraCountdown() + 1; -- 0 turns remaining is the last turn, shift by 1 to make sense to non-programmers
	local currentEra = Game.GetEras():GetCurrentEra();
	if (eraCountdown ~= nil and eraCountdown ~= 0 and eraCountdown ~= m_LastShownCountdownTurn and currentEra ~= nil) then
		local currentEraInfo = GameInfo.Eras[currentEra];
		if (currentEraInfo ~= nil) then
			m_LastShownCountdownTurn = eraCountdown;
			Controls.Root:SetHide(true);
			Controls.NewTurnLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_NEW_TURN_PANEL_NEXT_ERA_COUNTDOWN", eraCountdown, currentEraInfo.Name)));
			Controls.Root:SetHide(false);
			RestartAnimations();
		end
	end
end

function Initialize()
	-- Don't show until player clicks start turn
	if GameConfiguration.IsHotseat() then
		LuaEvents.PlayerChange_Close.Add(ShowEraCountdownPanel);
	else
		Events.LocalPlayerTurnBegin.Add(ShowEraCountdownPanel);
	end
end
Initialize();

