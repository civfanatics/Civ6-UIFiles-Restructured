-- Copyright 2019, Firaxis Games
include("InstanceManager");
include("SupportFunctions");

-- ===========================================================================
-- Constants
-- ===========================================================================
local COLOR_YELLOW:number = UI.GetColorValue("COLOR_YELLOW");
local COLOR_GREEN:number = UI.GetColorValueFromHexLiteral(0xFF00FF00);

local COLOR_GREEN_HIGHLIGHT:number = UI.GetColorValueFromHexLiteral(0x6400FF00);
local COLOR_RED_HIGHLIGHT:number = UI.GetColorValueFromHexLiteral(0x640000FF);

local POWER_LENS_HASH:number = UILens.CreateLensLayerHash("Power_Lens");

local TIME_OVERRIDE_TRANSITION_TIME:number = 1.0;

-- ===========================================================================
-- Members
-- ===========================================================================
local m_PowerLabelIM:table = InstanceManager:new("PowerLabelInstance", "Anchor", Controls.PowerLensContainer);

local m_PowerSourceOverlay:object = UILens.GetOverlay("PowerSources");
local m_PowerRangeOverlay:object = UILens.GetOverlay("PowerRange");
local m_PowerCityPlotsOverlay:object = UILens.GetOverlay("PowerCityPlots");

-- ===========================================================================
function RealizePowerOverlay()
	local kPowerRangePlots:table = {};
	local kPowerSourcePlots:table = {};
	local kPoweredCityPlots:table = {};
	local kUnpoweredCityPlots:table = {};

	local pLocalPlayerCities:table = Players[Game.GetLocalPlayer()]:GetCities();
	for _, pCity in pLocalPlayerCities:Members() do
		local pCityPower:table = pCity:GetPower();
	    if pCityPower then
			-- City Power Range
			local kPoweredPlots:table = pCityPower:GetPlotsCoveredByRegionalPower();
			for plotIndex, isPowered in pairs(kPoweredPlots) do
				if isPowered then
					table.insert(kPowerRangePlots, plotIndex);
				end
			end

			-- Power Sources
			local kPlotsProvidingPower:table = pCityPower:GetPlotsProvidingPower();
			for plotIndex, powerString in pairs(kPlotsProvidingPower) do
                table.insert(kPowerSourcePlots, plotIndex);
				CreatePowerLabelInstanceAt(plotIndex, powerString);
            end

			-- Grab powered and unpowered city plots
			local kCityPlots:table = Map.GetCityPlots():GetPurchasedPlots( pCity );
			if pCityPower:IsFullyPowered() then
				if pCityPower:GetRequiredPower() > 0 then
					for i,plotIndex in ipairs(kCityPlots) do
						table.insert(kPoweredCityPlots, plotIndex);
					end
				end
			else
				for i,plotIndex in ipairs(kCityPlots) do
					table.insert(kUnpoweredCityPlots, plotIndex);
				end
			end
		end
	end

	-- Update power source overlay
    m_PowerSourceOverlay:ClearPlotChannel();
    m_PowerSourceOverlay:SetVisible(true);
	m_PowerSourceOverlay:SetBorderColors(0, COLOR_GREEN, COLOR_GREEN);
    m_PowerSourceOverlay:SetPlotChannel(kPowerSourcePlots, 0);

	-- Update power range overlay
	m_PowerRangeOverlay:ClearPlotChannel();
    m_PowerRangeOverlay:SetVisible(true);
	m_PowerRangeOverlay:ShowHighlights(false);
	m_PowerRangeOverlay:ShowBorders(true);

	m_PowerRangeOverlay:SetBorderColors(0, COLOR_YELLOW, COLOR_YELLOW);
    m_PowerRangeOverlay:SetPlotChannel(kPowerRangePlots, 0);

	-- Update city plot power highlighting
	m_PowerCityPlotsOverlay:ClearPlotChannel();
    m_PowerCityPlotsOverlay:SetVisible(true);
	m_PowerCityPlotsOverlay:ShowHighlights(true);
	m_PowerCityPlotsOverlay:ShowBorders(false);

	m_PowerCityPlotsOverlay:SetHighlightColor(1, COLOR_GREEN_HIGHLIGHT);
	m_PowerCityPlotsOverlay:SetPlotChannel(kPoweredCityPlots, 1);

	m_PowerCityPlotsOverlay:SetHighlightColor(2, COLOR_RED_HIGHLIGHT);
    m_PowerCityPlotsOverlay:SetPlotChannel(kUnpoweredCityPlots, 2);

	-- Clear power source plots so their separate border overlay pops more
	if table.count(kPowerSourcePlots) > 0 then
		m_PowerCityPlotsOverlay:ClearPlotChannel(kPowerSourcePlots);
	end
end

-- ===========================================================================
function CreatePowerLabelInstanceAt( plotIndex:number, resourceString:string )
	local pInstance:table = m_PowerLabelIM:GetInstance();
	local worldX:number, worldY:number = UI.GridToWorld( plotIndex );
	pInstance.Anchor:SetWorldPositionVal( worldX, worldY, 0 );
	pInstance.Label:SetText(resourceString);
end

-- ===========================================================================
function ResetInstances()
	m_PowerLabelIM:ResetInstances();
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnLensLayerOn( layerNum:number )	
	if layerNum == POWER_LENS_HASH then
		ResetInstances();
		RealizePowerOverlay();
		UI.EnableTimeOfDayOverride(0, TIME_OVERRIDE_TRANSITION_TIME);
	end
end

-- ===========================================================================
--	Gamecore Event
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
	if layerNum == POWER_LENS_HASH then 
		ResetInstances();
        m_PowerSourceOverlay:SetVisible(false);
		m_PowerRangeOverlay:SetVisible(false);
		m_PowerCityPlotsOverlay:SetVisible(false);
		UI.DisableTimeOfDayOverride(TIME_OVERRIDE_TRANSITION_TIME);
	end
end

-- ===========================================================================
function LateInitialize()
	Events.LensLayerOn.Add( OnLensLayerOn );
	Events.LensLayerOff.Add( OnLensLayerOff );
end

-- ===========================================================================
function OnShutdown( isReload:boolean )
	Events.LensLayerOn.Remove( OnLensLayerOn );
	Events.LensLayerOff.Remove( OnLensLayerOff );
end

-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
end
Initialize();
