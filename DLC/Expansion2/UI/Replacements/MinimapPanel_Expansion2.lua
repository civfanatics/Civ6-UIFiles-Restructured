-- Copyright 2018-2019, Firaxis Games

-- ===========================================================================
-- Base File
-- ===========================================================================
include("MinimapPanel_Expansion1");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
XP1_LateInitialize			= LateInitialize;
XP1_OnToggleLensList		= OnToggleLensList;
XP1_OnInterfaceModeChanged	= OnInterfaceModeChanged;

-- ===========================================================================
-- Members
-- ===========================================================================
local m_MapLabelToggles = { };

-- ===========================================================================
function OnToggleLensList()
	if Controls.LensPanel:IsHidden() then
		Controls.PowerLensButton:SetCheck(false);
	end
	XP1_OnToggleLensList();
end

-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		if not Controls.LensPanel:IsHidden() then
			Controls.PowerLensButton:SetCheck(false);
		end
	end

	XP1_OnInterfaceModeChanged(eOldMode, eNewMode);
end

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
function TogglePowerLens()
	if Controls.PowerLensButton:IsChecked() then
		UILens.SetActive("Power");
		RefreshInterfaceMode();
	else
		g_shouldCloseLensMenu = false;
		if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
			UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
		end
	end
end

-- ===========================================================================
function LateInitialize()
	CreateMapLabelToggle( "MapLabels_Deserts",        "LOC_HUD_TOGGLE_DESERT_LABELS",         "LOC_HUD_TOGGLE_DESERT_LABELS_TOOLTIP",           UserConfiguration.ShowMapLabelsDeserts );
	CreateMapLabelToggle( "MapLabels_MountainRanges", "LOC_HUD_TOGGLE_MOUNTAIN_RANGE_LABELS", "LOC_HUD_TOGGLE_MOUNTAIN_RANGE_LABELS_TOOLTIP",   UserConfiguration.ShowMapLabelsMountainRanges );
	CreateMapLabelToggle( "MapLabels_Lakes",          "LOC_HUD_TOGGLE_LAKE_LABELS",           "LOC_HUD_TOGGLE_LAKE_LABELS_TOOLTIP",             UserConfiguration.ShowMapLabelsLakes );
	CreateMapLabelToggle( "MapLabels_Oceans",         "LOC_HUD_TOGGLE_OCEAN_LABELS",          "LOC_HUD_TOGGLE_OCEAN_LABELS_TOOLTIP",            UserConfiguration.ShowMapLabelsOceans );
	CreateMapLabelToggle( "MapLabels_Seas",           "LOC_HUD_TOGGLE_SEA_LABELS",            "LOC_HUD_TOGGLE_SEA_LABELS_TOOLTIP",              UserConfiguration.ShowMapLabelsSeas );
	CreateMapLabelToggle( "MapLabels_NationalParks",  "LOC_HUD_TOGGLE_NATIONAL_PARK_LABELS",  "LOC_HUD_TOGGLE_NATIONAL_PARK_LABELS_TOOLTIP",    UserConfiguration.ShowMapLabelsNationalParks );
	CreateMapLabelToggle( "MapLabels_NaturalWonders", "LOC_HUD_TOGGLE_NATURAL_WONDER_LABELS", "LOC_HUD_TOGGLE_NATURAL_WONDER_LABELS_TOOLTIP",   UserConfiguration.ShowMapLabelsNaturalWonders );
	CreateMapLabelToggle( "MapLabels_Rivers",         "LOC_HUD_TOGGLE_RIVER_LABELS",          "LOC_HUD_TOGGLE_RIVER_LABELS_TOOLTIP",            UserConfiguration.ShowMapLabelsRivers );
	CreateMapLabelToggle( "MapLabels_Volcanoes",      "LOC_HUD_TOGGLE_VOLCANO_LABELS",        "LOC_HUD_TOGGLE_VOLCANO_LABELS_TOOLTIP",          UserConfiguration.ShowMapLabelsVolcanoes );
	
	Events.GovernorPromoted.Add( OnGovernorPromoted );
	Events.UserOptionsActivated.Add( OnUserOptionsActivated_XP2 );

	Controls.PowerLensButton:RegisterCallback(Mouse.eLClick, TogglePowerLens);
	LuaEvents.OnViewPowerLens.Add(function()
		if ToggleLensList(Controls.PowerLensButton:IsChecked()) then
			Controls.PowerLensButton:SetCheck(not Controls.PowerLensButton:IsChecked());
			TogglePowerLens();
		end
	end);

	Controls.PowerLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_POWER"));

    -- must be called after we set up our labels to avoid nil reference
	XP1_LateInitialize();
end
