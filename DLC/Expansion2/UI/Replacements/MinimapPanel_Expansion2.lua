-- Copyright 2018, Firaxis Games

-- ===========================================================================
-- Base File
-- ===========================================================================
include("MinimapPanel_Expansion1");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
XP1_LateInitialize			= LateInitialize;

-- ===========================================================================
-- Members
-- ===========================================================================
local m_MapLabelToggles = { };

-- ===========================================================================
function CreateMapLabelToggle( szLayer, szText, szTooltip, pSetCB )
	local nLayerHash = UILens.CreateLensLayerHash(szLayer);
	local bEnabled = UILens.IsLayerOn(nLayerHash);

	local ToggleFunction = function()
		if UILens.IsLayerOn(nLayerHash) then
			UILens.ToggleLayerOff(nLayerHash);  
            pSetCB(false);
		else
			UILens.ToggleLayerOn(nLayerHash);
            pSetCB(true);
		end
	end

	m_MapLabelToggles[nLayerHash] = CreateMapOptionButton( szText,  szTooltip, ToggleFunction, bEnabled );

	local mapToggle = m_MapLabelToggles[nLayerHash];

	-- Setup a function to 'Restore' the control and option state.
	mapToggle.Restore = function()

		local bState = pSetCB();

		mapToggle.ToggleButton:SetCheck(bState);
		if bState then
			UILens.ToggleLayerOn(nLayerHash);
		else
			UILens.ToggleLayerOff(nLayerHash);
		end
	end

	mapToggle.Restore();

	Controls.MapOptionsStack:CalculateSize();
end

-- ===========================================================================
function OnGovernorPromoted(ePlayer, eGovernor, ePromotion)
	-- The unique Ottoman governor's last promotion can affect loyalty
	local nCulturalIdentityLens = UILens.CreateLensLayerHash("Cultural_Identity_Lens");
	if ePlayer == Game.GetLocalPlayer() and UILens.IsLayerOn(nCulturalIdentityLens) then
		UpdateLoyaltyLens();
	end	
end

-- ===========================================================================
function OnUserOptionsActivated_XP2()
	
	for i, mapOption in pairs(m_MapLabelToggles) do
		if mapOption.Restore ~= nil then
			mapOption.Restore();
		end
	end
end

-- ===========================================================================
function LateInitialize()
	CreateMapLabelToggle( "MapLabels_Deserts",        "LOC_HUD_TOGGLE_DESERT_LABELS",         "LOC_HUD_TOGGLE_DESERT_LABELS_TOOLTIP",           UserConfiguration.ShowMapLabelsDeserts );
	CreateMapLabelToggle( "MapLabels_MountainRanges", "LOC_HUD_TOGGLE_MOUNTAIN_RANGE_LABELS", "LOC_HUD_TOGGLE_MOUNTAIN_RANGE_LABELS_TOOLTIP",   UserConfiguration.ShowMapLabelsMountainRanges );
	CreateMapLabelToggle( "MapLabels_NationalParks",  "LOC_HUD_TOGGLE_NATIONAL_PARK_LABELS",  "LOC_HUD_TOGGLE_NATIONAL_PARK_LABELS_TOOLTIP",    UserConfiguration.ShowMapLabelsNationalParks );
	CreateMapLabelToggle( "MapLabels_NaturalWonders", "LOC_HUD_TOGGLE_NATURAL_WONDER_LABELS", "LOC_HUD_TOGGLE_NATURAL_WONDER_LABELS_TOOLTIP",   UserConfiguration.ShowMapLabelsNaturalWonders );
	CreateMapLabelToggle( "MapLabels_Rivers",         "LOC_HUD_TOGGLE_RIVER_LABELS",          "LOC_HUD_TOGGLE_RIVER_LABELS_TOOLTIP",            UserConfiguration.ShowMapLabelsRivers );
	CreateMapLabelToggle( "MapLabels_Volcanoes",      "LOC_HUD_TOGGLE_VOLCANO_LABELS",        "LOC_HUD_TOGGLE_VOLCANO_LABELS_TOOLTIP",          UserConfiguration.ShowMapLabelsVolcanoes );
	
	Events.GovernorPromoted.Add( OnGovernorPromoted );
	Events.UserOptionsActivated.Add( OnUserOptionsActivated_XP2 );

    -- must be called after we set up our labels to avoid nil reference
	XP1_LateInitialize();
end
