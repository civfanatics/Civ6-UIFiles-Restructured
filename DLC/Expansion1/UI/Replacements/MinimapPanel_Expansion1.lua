--[[
-- Created by Kevin Jones, Aug 28, 2017
-- Copyright (c) Firaxis Games
--]]
-- ===========================================================================
-- Base File
-- ===========================================================================
include("MinimapPanel");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_OnToggleLensList = OnToggleLensList;
BASE_SetGovernmentHexes = SetGovernmentHexes;

-- ===========================================================================
-- Members
-- ===========================================================================
local m_ToggleLoyaltyLensId = Input.GetActionId("LensLoyalty");
local m_LensButtonIM:table = InstanceManager:new("LensButtonInstance", "LensButton", Controls.LensToggleStack);

function OnToggleLensList()
	if m_LoyaltyToggle ~= nil then
		if Controls.LensPanel:IsHidden() then
			m_LoyaltyToggle.LensButton:SetCheck(false);
		end
	end
	BASE_OnToggleLensList();
end

function ToggleLoyaltyLens()
	if m_LoyaltyToggle ~= nil then
		if m_LoyaltyToggle.LensButton:IsChecked() then
			UILens.SetActive("Loyalty");
			RefreshInterfaceMode();
		else
			m_shouldCloseLensMenu = false;
			if UI.GetInterfaceMode() == InterfaceModeTypes.VIEW_MODAL_LENS then
				UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
			end
		end
	end
end

function UpdateLoyaltyLens()
	local localPlayer : number = Game.GetLocalPlayer(); 
	local localPlayerVis:table = PlayersVisibility[localPlayer];
	
	UILens.ClearLayerHexes(LensLayers.CULTURAL_IDENTITY_LENS);
	UILens.ClearPressureWaves(LensLayers.CULTURAL_IDENTITY_LENS);

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
							if (wave.pos1 ~= wave.pos2) then
								table.insert(waves, wave);
							end
						end
					end
				end
			end

			UILens.CreatePressureWaves(LensLayers.CULTURAL_IDENTITY_LENS, waves);
			UILens.SetLayerHexesColoredArea(LensLayers.CULTURAL_IDENTITY_LENS, localPlayer, kGainingLoyaltyPositions, kLoyaltyPlayerColor, "LoyaltyFlag_Up");
			UILens.SetLayerHexesColoredArea(LensLayers.CULTURAL_IDENTITY_LENS, localPlayer, kLosingLoyaltyPositions, kLoyaltyPlayerColor, "LoyaltyFlag_Down");
		end 
	end
end

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
						UILens.SetLayerHexesColoredArea( LensLayers.HEX_COLORING_GOVERNMENT, localPlayer, plots, GovernmentColor );
					end
				end
			end
		end 
	end
end

function OnLensLayerOn_Expansion1(layerNum:number)
	if layerNum == LensLayers.CULTURAL_IDENTITY_LENS then
		UpdateLoyaltyLens();
		UI.PlaySound("UI_Lens_Overlay_On");
		UILens.SetDesaturation(1.0);
	end
end

function OnLensLayerOff_Expansion1(layerNum:number)
	if (layerNum == LensLayers.CULTURAL_IDENTITY_LENS) then
		UILens.ClearLayerHexes(LensLayers.CULTURAL_IDENTITY_LENS);
		UI.PlaySound("UI_Lens_Overlay_Off");
		UILens.SetDesaturation(0.0);
	end
end

function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		if not Controls.LensPanel:IsHidden() then
			m_LoyaltyToggle.LensButton:SetCheck(false);
		end
	end
end

-- NOTE: OnInputActionTriggered from MinimapPanel.lua will still be registered and called.
function OnInputActionTriggered_XP1( actionId )
	-- dont show panel if there is no local player
	if (Game.GetLocalPlayer() == -1) then
		return;
	end

	if(actionId == m_ToggleLoyaltyLensId) then
		LensPanelHotkeyControl( m_LoyaltyToggle.LensButton );
		ToggleLoyaltyLens();
		UI.PlaySound("Play_UI_Click");
	end
end

function ToggleLensList( closeIfOpen )
	if Controls.LensPanel:IsHidden() then
		OnToggleLensList();
	elseif closeIfOpen then
		CloseLensList();
		return false;
	end
	return true;
end

function Initialize()
	m_LoyaltyToggle = m_LensButtonIM:GetInstance();

	local pTextButton = m_LoyaltyToggle.LensButton:GetTextButton();
	pTextButton:LocalizeAndSetText("LOC_HUD_CULTURAL_IDENTITY_LENS"); -- TODO expose LocalizeAndSetText for checkbox?

	local pToolTip = Locale.Lookup("LOC_HUD_CULTURAL_IDENTITY_LENS_TOOLTIP");
	m_LoyaltyToggle.LensButton:SetToolTipString(pToolTip);
	
	m_LoyaltyToggle.LensButton:RegisterCallback( Mouse.eLClick, ToggleLoyaltyLens );
	Events.LensLayerOn.Add( OnLensLayerOn_Expansion1 );
	Events.LensLayerOff.Add( OnLensLayerOff_Expansion1 );
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
	Events.InputActionTriggered.Add( OnInputActionTriggered_XP1 );

	

	LuaEvents.OnViewLoyaltyLens.Add(function()
		if ToggleLensList(m_LoyaltyToggle.LensButton:IsChecked()) then
			m_LoyaltyToggle.LensButton:SetCheck(not m_LoyaltyToggle.LensButton:IsChecked());
			ToggleLoyaltyLens();
		end
	end);

	LuaEvents.OnViewReligionLens.Add(function()
		if ToggleLensList(Controls.ReligionLensButton:IsChecked()) then
			Controls.ReligionLensButton:SetCheck(not Controls.ReligionLensButton:IsChecked());
			ToggleReligionLens();
		end
	end);

	-- Listen to our version of this callback
	Controls.LensButton:RegisterCallback( Mouse.eLClick, OnToggleLensList );
end
Initialize();