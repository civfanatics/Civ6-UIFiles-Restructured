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
		Controls.KeyPanel:SetHide(true);
	else
		XP1_OnLensLayerOn(layerNum);
	end
end

function Initialize()
	Events.LensLayerOn.Add( OnLensLayerOn );
end
Initialize();