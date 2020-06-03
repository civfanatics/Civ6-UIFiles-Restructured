g_PanelHasFocus = false;

-- ===========================================================================
function OnRiverSelected(params)
	if RiverManager ~= nil and params ~= nil and params.RiverIndex ~= nil then

		local pOverlay:object = UILens.GetOverlay("DebugHexHighlight");
		if pOverlay ~= nil then
			pOverlay:SetChannelOn(0);
			pOverlay:ClearAll();

			if params.Highlight then
				local kRiver = RiverManager.GetRiverByIndex(params.RiverIndex, "plots");
				if kRiver ~= nil and kRiver.Plots ~= nil then			

					if params.Highlight == true and #kRiver.Plots > 0 then
						pOverlay:SetVisible(true);
						local color:number = UI.GetColorValue(1, 1, 1, 0.5);
						pOverlay:HighlightColoredHexes(kRiver.Plots, color, 0);
						local x, y = Map.GetPlotLocation(kRiver.Plots[1]);
						UI.LookAtPlot(x, y);
					else
						pOverlay:SetVisible(false);
					end
				end
			end
		end
	end
end
LuaEvents.WorldBuilderRiverHighlight.Add(OnRiverSelected);
