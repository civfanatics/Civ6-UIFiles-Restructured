-- Copyright 2017-2019, Firaxis Games

-- ===========================================================================
-- Base File
-- ===========================================================================
include("ModalLensPanel_Expansion1");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
XP1_OnLensLayerOn = OnLensLayerOn;

-- ===========================================================================
-- Constants
-- ===========================================================================

local POWER_LENS_HASH:number = UILens.CreateLensLayerHash("Power_Lens");

-- ===========================================================================
function OnLensLayerOn( layerNum:number )
	if layerNum == POWER_LENS_HASH then
		Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_POWER_LENS")));
		ShowPowerLensKey();
	else
		XP1_OnLensLayerOn(layerNum);
	end
end

--============================================================================
function ShowPowerLensKey()
	ResetKeyStackIM();

	AddKeyEntry("LOC_POWER_LENS_KEY_POWER_SOURCE", UI.GetColorValue("COLOR_STANDARD_GREEN_MD"), nil, nil, true);
	AddKeyEntry("LOC_POWER_LENS_KEY_FULLY_POWERED", UI.GetColorValue("COLOR_STANDARD_GREEN_MD"));
	AddKeyEntry("LOC_POWER_LENS_KEY_UNDERPOWERED", UI.GetColorValue("COLOR_STANDARD_RED_MD"));
	AddKeyEntry("LOC_POWER_LENS_KEY_POWER_RANGE", UI.GetColorValue("COLOR_YELLOW"), nil, nil, true);

	Controls.KeyPanel:SetHide(false);
	Controls.KeyScrollPanel:CalculateSize();
end