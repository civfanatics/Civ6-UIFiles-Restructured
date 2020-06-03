-- Copyright 2017-2019, Firaxis Games

-- ===========================================================================
-- Base File
-- ===========================================================================
include("ModalLensPanel");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_OnLensLayerOn = OnLensLayerOn;
BASE_ShowPoliticalLensKey = ShowPoliticalLensKey;

-- ===========================================================================
-- Members
-- ===========================================================================

local m_CulturalIdentityLens : number = UILens.CreateLensLayerHash("Cultural_Identity_Lens");

-- ===========================================================================
function OnLensLayerOn( layerNum:number )
	if layerNum == m_CulturalIdentityLens then
		Controls.LensText:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CULTURAL_IDENTITY_LENS")));
		Controls.KeyPanel:SetHide(true);
	else
		BASE_OnLensLayerOn(layerNum);
	end
end

-- ===========================================================================
function ShowPoliticalLensKey()
	-- add everything normally
	BASE_ShowPoliticalLensKey();

	-- if there are any free cities, add them to the key
	local localPlayer = Players[Game.GetLocalPlayer()];
	local playerDiplomacy:table = localPlayer:GetDiplomacy();
	if playerDiplomacy then
		local players = Game.GetPlayers();
		for i, player in ipairs(players) do
			-- Only show civilizations for players we've met
			local visiblePlayer = (player == localPlayer) or playerDiplomacy:HasMet(player:GetID());
			if visiblePlayer and not player:IsBarbarian() then
				-- Everything but free cities is handled in BASE_ShowPoliticalLensKey
				if player:IsFreeCities() then
					local primaryColor, secondaryColor = UI.GetPlayerColors( player:GetID() );
					local playerConfig:table = PlayerConfigurations[player:GetID()];
					AddKeyEntry(playerConfig:GetPlayerName(), primaryColor);
					Controls.KeyPanel:SetHide(false);
					Controls.KeyScrollPanel:CalculateSize();
					return; -- only need to add it once
				end
			end
		end
	end
end