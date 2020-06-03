-- Copyright 2017-2019, Firaxis Games

-- ===========================================================================
-- Base File
-- ===========================================================================
include("MinimapPanel");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_LateInitialize			= LateInitialize;
BASE_OnInputActionTriggered = OnInputActionTriggered;
BASE_OnInterfaceModeChanged = OnInterfaceModeChanged;
BASE_OnLensLayerOn			= OnLensLayerOn;
BASE_OnLensLayerOff			= OnLensLayerOff;
BASE_OnShutdown				= OnShutdown;
BASE_OnToggleLensList		= OnToggleLensList;
BASE_SetGovernmentHexes		= SetGovernmentHexes;

-- ===========================================================================
-- Members
-- ===========================================================================
local m_ToggleLoyaltyLensId		 : number = -1;
local m_CulturalIdentityLens     : number = UILens.CreateLensLayerHash("Cultural_Identity_Lens");
local m_UnknownCivilizationColor : number = UI.GetColorValue("COLOR_LOYALTY_UNKNOWN_CIVILIZATION");


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-- ===========================================================================
function OnToggleLensList()
	if Controls.LensPanel:IsHidden() then
		Controls.LoyaltyLensButton:SetCheck(false);
	else
		Controls.EmpireLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_EMPIRE"));
	end
	BASE_OnToggleLensList();
end

-- ===========================================================================
function ToggleLoyaltyLens()
	if Controls.LoyaltyLensButton:IsChecked() then
		UILens.SetActive("Loyalty");
		RefreshInterfaceMode();
	else
		g_shouldCloseLensMenu = false;
		if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
			UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
		end
	end
end

-- ===========================================================================
function UpdateLoyaltyLens()
	local localPlayer : number = Game.GetLocalPlayer(); 
	local localPlayerVis:table = PlayersVisibility[localPlayer];
	local pLocalPlayerDiplomacy = Players[localPlayer]:GetDiplomacy();
	
	UILens.ClearLayerHexes(m_CulturalIdentityLens);
	UILens.ClearPressureWaves(m_CulturalIdentityLens);

	if (localPlayerVis ~= nil) then
		local players = Game.GetPlayers();
		for i, player in ipairs(players) do
			local cities = players[i]:GetCities();
			local waves:table = {};

			local kLoyaltyPlayerColor = UI.GetPlayerColors(player:GetID());
			local kGainingLoyaltyPositions = {};
			local kLosingLoyaltyPositions = {};

			for _, pCity in cities:Members() do
				local plot = Map.GetPlotIndex(pCity:GetX(), pCity:GetY());
				if localPlayerVis:IsRevealed(plot) then
					local pCulturalIdentity = pCity:GetCulturalIdentity();
					if not pCulturalIdentity:IsAlwaysFullyLoyal() then
						local eOutcome:number = pCulturalIdentity:GetConversionOutcome();
						if eOutcome == IdentityConversionOutcome.GAINING_LOYALTY then
							table.insert(kGainingLoyaltyPositions, plot);
						elseif eOutcome == IdentityConversionOutcome.LOSING_LOYALTY then
							table.insert(kLosingLoyaltyPositions, plot);
						else
							--TODO is there an idle indicator?
						end
					
						local PressureSources = pCulturalIdentity:GetCityIdentityPressures();
						for _,PressureSource in ipairs(PressureSources) do
							local PlayerID = PressureSource.CityOwner;
							local PlayerColor = UI.GetPlayerColors(PlayerID);
							local pSrcCity = CityManager.GetCity(PlayerID, PressureSource.CityID);
							if (pSrcCity ~= nil and PressureSource.IdentityPressureTotal > 0) then
								local wave = {
									pos1  = Map.GetPlotIndex(pSrcCity:GetX(), pSrcCity:GetY());
									pos2  = plot;
									color = PlayerColor;
									speed = PressureSource.IdentityPressureTotal;
									type  = PlayerConfigurations[PlayerID]:GetCivilizationTypeName();
								};

								if PlayerID ~= localPlayer and not pLocalPlayerDiplomacy:HasMet(PlayerID) then
									wave.color = m_UnknownCivilizationColor;
									wave.type  = "CIVILIZATION_UNKNOWN";
								end

								if (wave.pos1 ~= wave.pos2) then
									table.insert(waves, wave);
								end
							end
						end
					end
				end
			end

			UILens.CreatePressureWaves(m_CulturalIdentityLens, waves);
			UILens.SetLayerHexesColoredArea(m_CulturalIdentityLens, localPlayer, kGainingLoyaltyPositions, kLoyaltyPlayerColor, "LoyaltyFlag_Up");
			UILens.SetLayerHexesColoredArea(m_CulturalIdentityLens, localPlayer, kLosingLoyaltyPositions, kLoyaltyPlayerColor, "LoyaltyFlag_Down");
		end 
	end
end

-- ===========================================================================
function SetGovernmentHexes()
	-- add everything else normally
	BASE_SetGovernmentHexes();

	-- set any free cities to use the correct color
	local localPlayer : number = Game.GetLocalPlayer(); 
	local localPlayerVis:table = PlayersVisibility[localPlayer];
	if (localPlayerVis ~= nil) then
		local players = Game.GetPlayers();
		for i, player in ipairs(players) do
			local cities = players[i]:GetCities();
			local culture = player:GetCulture();
			local governmentId :number = culture:GetCurrentGovernment();

			if player:IsFreeCities() then
				local GovernmentColor = UI.GetColorValue("COLOR_GOVERNMENT_FREE_CITIES");
				for _, pCity in cities:Members() do
					local plots:table = Map.GetCityPlots():GetPurchasedPlots(pCity);
					
					if(table.count(plots) > 0) then
						UILens.SetLayerHexesColoredArea( m_HexColoringGovernment, localPlayer, plots, GovernmentColor );
					end
				end
			end
		end 
	end
end

-- ===========================================================================
-- override
-- ===========================================================================
function SetContinentHexes() 
	GetContinentsCache();
	local localPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
	if (localPlayerVis ~= nil) then
		local kContinentColors:table = {};
		for loopNum, ContinentID in ipairs(g_ContinentsCache) do
			local visibleContinentPlots:table = Map.GetVisibleContinentPlots(ContinentID);
			local ContinentColor:number = UI.GetColorValue("COLOR_" .. GameInfo.Continents[ loopNum-1 ].ContinentType);
			if(table.count(visibleContinentPlots) > 0) then
				UILens.SetLayerHexesColoredArea( g_HexColoringContinent, loopNum-1, visibleContinentPlots, ContinentColor );		
				kContinentColors[ContinentID] = ContinentColor;
			end
		end
		LuaEvents.MinimapPanel_AddContinentColorPair( kContinentColors );
	end
end

-- ===========================================================================
function OnLensLayerOn(layerNum:number)
	if layerNum == m_CulturalIdentityLens then
		UpdateLoyaltyLens();
		UI.PlaySound("UI_Lens_Overlay_On");
		UILens.SetDesaturation(1.0);
	else 
		BASE_OnLensLayerOn( layerNum );
	end
end

-- ===========================================================================
function OnLensLayerOff(layerNum:number)
	if (layerNum == m_CulturalIdentityLens) then
		UILens.ClearLayerHexes(m_CulturalIdentityLens);
		UI.PlaySound("UI_Lens_Overlay_Off");
		UILens.SetDesaturation(0.0);
	else 
		BASE_OnLensLayerOff( layerNum );
	end
end

-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		if not Controls.LensPanel:IsHidden() then
			Controls.LoyaltyLensButton:SetCheck(false);
		end
	end

	BASE_OnInterfaceModeChanged(eOldMode, eNewMode);
end

-- ===========================================================================
-- NOTE: OnInputActionTriggered from MinimapPanel.lua will still be registered and called.
function OnInputActionTriggered( actionId )
	-- dont show panel if there is no local player
	if (Game.GetLocalPlayer() == -1) then
		return;
	end

	if(actionId == m_ToggleLoyaltyLensId) then
		LensPanelHotkeyControl( Controls.LoyaltyLensButton );
		ToggleLoyaltyLens();
		UI.PlaySound("Play_UI_Click");
	else
		BASE_OnInputActionTriggered( actionId );
	end
end

-- ===========================================================================
function ToggleLensList( closeIfOpen )
	if Controls.LensPanel:IsHidden() then
		OnToggleLensList();
	elseif closeIfOpen then
		CloseLensList();
		return false;
	end
	return true;
end

-- ===========================================================================
function OnShutdown()	
	m_GeographyLabelToggle = nil;
	BASE_OnShutdown();
end

-- ===========================================================================
function LateInitialize()

	BASE_LateInitialize();

	if GameCapabilities.HasCapability("CAPABILITY_LENS_TOGGLING_UI") then
		m_ToggleLoyaltyLensId = Input.GetActionId("LensLoyalty");	
		Controls.LoyaltyLensButton:RegisterCallback(Mouse.eLClick, ToggleLoyaltyLens);
		LuaEvents.OnViewLoyaltyLens.Add(function()
			if ToggleLensList(Controls.LoyaltyLensButton:IsChecked()) then
				Controls.LoyaltyLensButton:SetCheck(not Controls.LoyaltyLensButton:IsChecked());
				ToggleLoyaltyLens();
			end
		end);
	end

	LuaEvents.OnViewReligionLens.Add(function()
		if ToggleLensList(Controls.ReligionLensButton:IsChecked()) then
			Controls.ReligionLensButton:SetCheck(not Controls.ReligionLensButton:IsChecked());
			ToggleReligionLens();
		end
	end);

	Controls.LoyaltyLensButton:SetHide(not GameCapabilities.HasCapability("CAPABILITY_LENS_LOYALTY"));
end
