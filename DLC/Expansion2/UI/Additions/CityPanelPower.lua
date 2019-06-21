include("InstanceManager");
include("SupportFunctions");
include("EspionageViewManager");

local m_kPowerBreakdownIM:table = InstanceManager:new( "PowerLineInstance",	"Top");

local m_kEspionageViewManager = EspionageViewManager:CreateManager();

-- ===========================================================================
function OnRefresh()
	if ContextPtr:IsHidden() then
		return;
	end
	
	local pCity = UI.GetHeadSelectedCity();
	if (pCity == nil) then
		pCity = m_kEspionageViewManager:GetEspionageViewCity();
		if pCity == nil then
			return;
		end
	else
		m_kEspionageViewManager:ClearEspionageViewCity();
	end

	local playerID = pCity:GetOwner();
	local pPlayer = Players[playerID];
	if (pPlayer == nil) then
		return;
	end

	if pPlayer == nil or pCity == nil then
		return;
	end

	local pCityPower = pCity:GetPower();
	if pCityPower == nil then
		return;
	end
	
	-- Status
	local freePower:number = pCityPower:GetFreePower();
	local temporaryPower:number = pCityPower:GetTemporaryPower();
	local currentPower:number = freePower + temporaryPower;
	local requiredPower:number = pCityPower:GetRequiredPower();
	local powerStatusName:string = "LOC_POWER_STATUS_POWERED_NAME";
	local powerStatusDescription:string = "LOC_POWER_STATUS_POWERED_DESCRIPTION";
	if (requiredPower == 0) then
		powerStatusName = "LOC_POWER_STATUS_NO_POWER_NEEDED_NAME";
		powerStatusDescription = "LOC_POWER_STATUS_NO_POWER_NEEDED_DESCRIPTION";
	elseif (not pCityPower:IsFullyPowered()) then
		powerStatusName = "LOC_POWER_STATUS_UNPOWERED_NAME";
		powerStatusDescription = "LOC_POWER_STATUS_UNPOWERED_DESCRIPTION";
	elseif (pCityPower:IsFullyPoweredByActiveProject()) then
		currentPower = requiredPower;
	end
	Controls.ConsumingPowerLabel:SetText(Locale.Lookup("LOC_POWER_PANEL_CONSUMED", Round(currentPower, 1)));
	Controls.RequiredPowerLabel:SetText(Locale.Lookup("LOC_POWER_PANEL_REQUIRED", Round(requiredPower, 1)));
	Controls.PowerStatusNameLabel:SetText(Locale.Lookup(powerStatusName));

	-- Status Effects
	Controls.PowerStatusDescriptionLabel:SetText(Locale.Lookup(powerStatusDescription));
	Controls.PowerStatusDescriptionBox:SetSizeY(Controls.PowerStatusDescriptionLabel:GetSizeY() + 15);

	-- Breakdown
	m_kPowerBreakdownIM:ResetInstances();
	-----Consumed 
	local freePowerBreakdown:table = pCityPower:GetFreePowerSources();
	local temporaryPowerBreakdown:table = pCityPower:GetTemporaryPowerSources();
	local somethingToShow:boolean = false;
	for _,innerTable in ipairs(freePowerBreakdown) do
		somethingToShow = true;
		local scoreSource, scoreValue = next(innerTable);
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.ConsumedPowerBreakdownStack);
		lineInstance.LineTitle:SetText(scoreSource);
		lineInstance.LineValue:SetText("[ICON_Power]" .. Round(scoreValue, 1));
	end
	for _,innerTable in ipairs(temporaryPowerBreakdown) do
		somethingToShow = true;
		local scoreSource, scoreValue = next(innerTable);
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.ConsumedPowerBreakdownStack);
		lineInstance.LineTitle:SetText(scoreSource);
		lineInstance.LineValue:SetText("[ICON_Power]" .. Round(scoreValue, 1));
	end
	Controls.ConsumedPowerBreakdownStack:CalculateSize();
	Controls.ConsumedBreakdownBox:SetSizeY(Controls.ConsumedPowerBreakdownStack:GetSizeY() + 15);
	Controls.ConsumedBreakdownBox:SetHide(not somethingToShow);
	Controls.ConsumedTitle:SetHide(not somethingToShow);
	-----Required
	local requiredPowerBreakdown:table = pCityPower:GetRequiredPowerSources();
	local somethingToShow:boolean = false;
	for _,innerTable in ipairs(requiredPowerBreakdown) do
		somethingToShow = true;
		local scoreSource, scoreValue = next(innerTable);
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.RequiredPowerBreakdownStack);
		lineInstance.LineTitle:SetText(scoreSource);
		lineInstance.LineValue:SetText("[ICON_Power]" .. Round(scoreValue, 1));
	end
	Controls.RequiredPowerBreakdownStack:CalculateSize();
	Controls.RequiredBreakdownBox:SetSizeY(Controls.RequiredPowerBreakdownStack:GetSizeY() + 15);
	Controls.RequiredBreakdownBox:SetHide(not somethingToShow);
	Controls.RequiredTitle:SetHide(not somethingToShow);
	-----Generated
	local generatedPowerBreakdown:table = pCityPower:GetGeneratedPowerSources();
	local somethingToShow:boolean = false;
	for _,innerTable in ipairs(generatedPowerBreakdown) do
		somethingToShow = true;
		local scoreSource, scoreValue = next(innerTable);
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.GeneratedPowerBreakdownStack);
		lineInstance.LineTitle:SetText(scoreSource);
		lineInstance.LineValue:SetText("[ICON_Power]" .. Round(scoreValue, 1));
		lineInstance.LineValue:SetColorByName("White");
	end
	Controls.GeneratedPowerBreakdownStack:CalculateSize();
	Controls.GeneratedBreakdownBox:SetSizeY(Controls.GeneratedPowerBreakdownStack:GetSizeY() + 15);
	Controls.GeneratedBreakdownBox:SetHide(not somethingToShow);
	Controls.GeneratedTitle:SetHide(not somethingToShow);

	-- Advisor
	if m_kEspionageViewManager:IsEspionageView() then
		Controls.PowerAdvisor:SetHide(true);
	else
		Controls.PowerAdvice:SetText(pCity:GetPowerAdvice());
		Controls.PowerAdvisor:SetHide(false);
	end

	Controls.TabStack:CalculateSize();
end

-- ===========================================================================
function OnShowEnemyCityOverview( ownerID:number, cityID:number)
	m_kEspionageViewManager:SetEspionageViewCity( ownerID, cityID );
	OnRefresh();
end

-- ===========================================================================
function OnTabStackSizeChanged()
	-- Manually resize the context to fit the child stack
	ContextPtr:SetSizeX(Controls.TabStack:GetSizeX());
	ContextPtr:SetSizeY(Controls.TabStack:GetSizeY());
end

-- ===========================================================================
function OnTogglePowerPanel(pCity:table)
	if (pCity ~= nil) then
		UI.LookAtPlot(pCity:GetX(), pCity:GetY());
		UI.SelectCity(pCity);
		LuaEvents.CityPanel_ToggleOverviewPower();
	end
end

-- ===========================================================================
function Initialize()
	LuaEvents.CityPanelTabRefresh.Add(OnRefresh);
	Events.CitySelectionChanged.Add( OnRefresh );

	LuaEvents.CityBannerManager_ShowEnemyCityOverview.Add( OnShowEnemyCityOverview );

	Controls.TabStack:RegisterSizeChanged( OnTabStackSizeChanged );
end
Initialize();