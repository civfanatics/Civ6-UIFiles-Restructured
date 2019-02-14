-- ===========================================================================--
--  Production Manager
--	Customize and review production queues
--
--	Original Authors: Keaton VanAuken
-- ===========================================================================
include("InstanceManager");
include("Civ6Common");
include("ProductionHelper");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "ProductionManager"; -- Must be unique (usually the same as the file name)

local FIELD_CITY_ID:string			= "cityID";
local FIELD_INSTANCE_MANAGER:string = "queueInstanceManager";
local FIELD_QUEUE_INSTANCES:string	= "queueInstances";

-- ===========================================================================
--  VARIABLES
-- ===========================================================================

local m_CityInstanceIM:table = InstanceManager:new("CityInstance", "CityButton", Controls.CityStack);

local m_SelectedCityInstance:table	= nil;
local m_kSelectedQueueItem:table		= {Parent = nil, Button = nil, Index = -1};

-- ===========================================================================
function Refresh(sortFunc, sortName)
	local pLocalPlayer:table = Players[Game.GetLocalPlayer()];

    m_CityInstanceIM:ResetInstances();

	-- Grab players cities so we can sort easily
	local sortedCities:table = {}
	local pPlayerCities:table = pLocalPlayer:GetCities();
	for i, pCity in pPlayerCities:Members() do
		table.insert(sortedCities, pCity);
	end

	-- Sort
	if sortFunc ~= nil then
		table.sort(sortedCities, sortFunc);
	end

	if sortName ~= nil then
		Controls.FilterPulldown:GetButton():SetText(Locale.Lookup("LOC_PRODUCTION_MANAGER_SORT_BY", Locale.Lookup(sortName)));
	else
		Controls.FilterPulldown:GetButton():SetText(Locale.Lookup("LOC_PRODUCTION_MANAGER_SORT_BY", Locale.Lookup("LOC_PRODUCTION_MANAGER_FILTER_FOUNDING")));
	end

	-- Populate using sorted list
	for _, pCity in ipairs(sortedCities) do
		local cityInstance:table = CreateCityInstance(pCity);
	    RefreshCityInstance(cityInstance, pCity);
	end

	-- Set button of the currently selected city as selected 
	local pSelectedCity	= UI.GetHeadSelectedCity();
	if pSelectedCity then
		SetSelectedCity(pSelectedCity:GetID());
	end
end

-- ===========================================================================
function CreateCityInstance( city:table )
    local cityInstance:table = m_CityInstanceIM:GetInstance();
    cityInstance[FIELD_CITY_ID] = city:GetID();

	-- Create an instance manager for the queue if we need one
	if cityInstance[FIELD_INSTANCE_MANAGER] == nil then
		cityInstance[FIELD_INSTANCE_MANAGER] = InstanceManager:new("ProductionQueueItem", "Top");
	end

    return cityInstance;
end

-- ===========================================================================
function FindCityInstance( cityID:number )
    for i=1, m_CityInstanceIM.m_iCount, 1 do
        local instance:table = m_CityInstanceIM:GetAllocatedInstance(i);
        if instance and instance[FIELD_CITY_ID] == cityID then
            return instance;
        end
    end

    return nil;
end

-- ===========================================================================
function RefreshCityInstance( instance:table, city:table )
	local cityID:number = city:GetID();
	local ownerID:number = city:GetOwner();

    -- Update name and capital icon
	instance.CapitalIcon:SetHide(not city:IsCapital());
    instance.CityName:SetText(Locale.Lookup(city:GetName()));

    -- Update current production
    local hasAnyProduction:boolean = RefreshCurrentProduction(instance, ownerID, cityID);
	if hasAnyProduction then
		instance.CurrentProductionGrid:SetHide(false);
		instance.NoProductionContainer:SetHide(true);
	else
		instance.CurrentProductionGrid:SetHide(true);
		instance.NoProductionContainer:SetHide(false);
	end
	
    -- Update production queue
    instance[FIELD_QUEUE_INSTANCES] = RefreshProductionQueue(instance[FIELD_INSTANCE_MANAGER], instance.QueueStack, ownerID, cityID);

	RefreshQueueButtonStates(instance);

	-- Setup callbacks
	instance.CityButton:RegisterCallback( Mouse.eLClick, function() OnCityInstanceClicked(ownerID, cityID); end );
	instance.TrashButton:RegisterCallback( Mouse.eLClick, OnTrashButtonClicked );
	instance.DarkenButton:RegisterCallback( Mouse.eLClick, DeselectItem );
	instance.DarkenButton:RegisterCallback( Mouse.eRClick, DeselectItem );
end

-- ===========================================================================
function RefreshQueueButtonStates( kInstance:table )
	local pSelectedCity	= UI.GetHeadSelectedCity();
	local bIsSelectedCity:boolean = pSelectedCity ~= nil and pSelectedCity:GetID() == kInstance[FIELD_CITY_ID];

	kInstance.CurrentProductionGrid:SetDisabled(false);
	kInstance.CurrentProductionGrid:RegisterCallback( Mouse.eLClick, function() OnQueueItemClicked(kInstance, kInstance.CurrentProductionGrid); end);
	kInstance.CurrentProductionGrid:RegisterCallback( Mouse.eRClick, function() OnQueueItemRightClicked(kInstance, kInstance.CurrentProductionGrid); end);

	for i,kQueueInstance in ipairs(kInstance[FIELD_QUEUE_INSTANCES]) do
		if kQueueInstance[FIELD_QUEUE_INDEX] ~= -1 then
			kQueueInstance.Top:SetDisabled(false);
			kQueueInstance.Top:RegisterCallback( Mouse.eLClick, function() OnQueueItemClicked(kQueueInstance, kQueueInstance.Top); end);
			kQueueInstance.Top:RegisterCallback( Mouse.eRClick, function() OnQueueItemRightClicked(kQueueInstance, kQueueInstance.Top); end);
		end
	end
end

-- ===========================================================================
function DeselectItem()
	if m_kSelectedQueueItem.Parent ~= nil then
		local kParentControl:table = m_kSelectedQueueItem.Parent;
		if kParentControl.ProductionIcon ~= nil then
			kParentControl.ProductionIcon:SetAlpha(1.0);
		end
	end

	m_kSelectedQueueItem.Parent = nil;
	m_kSelectedQueueItem.Button = nil;
	m_kSelectedQueueItem.Index = -1;

	LuaEvents.ProductionManager_SelectedIndexChanged(m_kSelectedQueueItem.Index);

	DisableMouseIcon();
	HighlightButtons(false);
	ClearDarkenCities();
end

-- ===========================================================================
function SelectItem( kParentControl:table, kButtonControl:table )
	if kParentControl ~= nil and kParentControl[FIELD_QUEUE_INDEX] then
		if kParentControl.ProductionIcon ~= nil then
			kParentControl.ProductionIcon:SetAlpha(SELECTED_ICON_ALPHA);
		end

		m_kSelectedQueueItem.Parent = kParentControl;
		m_kSelectedQueueItem.Button = kButtonControl;
		m_kSelectedQueueItem.Index = kParentControl[FIELD_QUEUE_INDEX];

		-- We selected an item from another city so select that city
		if m_SelectedCityInstance ~= kParentControl then
			m_SelectedCityInstance = FindCityInstance(kParentControl[FIELD_CITY_ID]);
			local pCity:table = CityManager.GetCity(Game.GetLocalPlayer(), kParentControl[FIELD_CITY_ID]);
			UI.SelectCity( pCity );
		end

		LuaEvents.ProductionManager_SelectedIndexChanged(m_kSelectedQueueItem.Index);

		EnableMouseIcon(kParentControl[FIELD_ICON_TEXTURE]);
		HighlightButtons(true);
		DarkenOtherCities();
	end
end

-- ===========================================================================
function ScrollToSelectedCity()
	for i=1, m_CityInstanceIM.m_iCount, 1 do
        local instance:table = m_CityInstanceIM:GetAllocatedInstance(i);
        if instance and instance == m_SelectedCityInstance then
			local iScrollToPixel:number = 0;
			if i > 1 then
				iScrollToPixel = (i * instance.CityButton:GetSizeY()) + ((i - 1) * 2);
			end
			local iDesiredScroll:number = iScrollToPixel / Controls.CityStack:GetSizeY();
			Controls.CityStackScroll:SetScrollValue(iDesiredScroll);
			return;
        end
    end
end

-- ===========================================================================
function OnTrashButtonClicked()
	if m_kSelectedQueueItem.Index ~= -1 then
		RemoveQueueItem(m_kSelectedQueueItem.Index);
	end
end

-- ===========================================================================
function DarkenOtherCities()
    for i=1, m_CityInstanceIM.m_iCount, 1 do
        local instance:table = m_CityInstanceIM:GetAllocatedInstance(i);
        if instance and instance ~= m_SelectedCityInstance then
			instance.DarkenBox:SetHide(false);
        end
    end
end

-- ===========================================================================
function ClearDarkenCities()
    for i=1, m_CityInstanceIM.m_iCount, 1 do
        local instance:table = m_CityInstanceIM:GetAllocatedInstance(i);
        if instance then
			instance.DarkenBox:SetHide(true);
        end
    end
end

-- ===========================================================================
function HighlightButtons( bShouldHighlight:boolean )
	if m_SelectedCityInstance ~= nil then
		m_SelectedCityInstance.CurrentProductionGrid:SetSelected(bShouldHighlight);

		local kQueueInstance_IM = m_SelectedCityInstance[FIELD_INSTANCE_MANAGER];
		for i=1, kQueueInstance_IM.m_iCount, 1 do
			local instance:table = kQueueInstance_IM:GetAllocatedInstance(i);
			if instance then
				if instance[FIELD_QUEUE_INDEX] ~= -1 then
					instance.Top:SetSelected(bShouldHighlight);
				end
			end
		end

		m_SelectedCityInstance.TrashButton:SetSelected(bShouldHighlight);
		m_SelectedCityInstance.TrashButton:SetDisabled(not bShouldHighlight);
	end
end

-- ===========================================================================
function OnQueueItemClicked( kParentControl:table, kButtonControl:table )
	-- Prevent interaction with completed items
	if kParentControl.CompletedArea and not kParentControl.CompletedArea:IsHidden() then
		return;
	end

	if kParentControl[FIELD_QUEUE_INDEX] == m_kSelectedQueueItem.Index then
		-- This item is already selected so just unselect it
		DeselectItem();
		return;
	elseif m_kSelectedQueueItem.Index == -1 then
		-- Nothing else is selected so select this item
		SelectItem(kParentControl, kButtonControl);
		return;
	else
		-- Swap currently selected item with this item
		if kParentControl ~= nil and kParentControl[FIELD_QUEUE_INDEX] then
			SwapQueueItem(kParentControl[FIELD_QUEUE_INDEX], m_kSelectedQueueItem.Index);
			return;
		end
	end

	-- Unselect current selection if action isn't consumed
	DeselectItem();
end

-- ===========================================================================
function OnQueueItemRightClicked( kParentControl:table, kButtonControl:table )
	if kParentControl[FIELD_QUEUE_INDEX] ~= -1 then
		-- We selected an item from another city so select that city
		if m_SelectedCityInstance ~= kParentControl then
			m_SelectedCityInstance = FindCityInstance(kParentControl[FIELD_CITY_ID]);
			local pCity:table = CityManager.GetCity(Game.GetLocalPlayer(), kParentControl[FIELD_CITY_ID]);
			UI.SelectCity( pCity );
		end

		RemoveQueueItem(kParentControl[FIELD_QUEUE_INDEX]);
	end
end

-- ===========================================================================
function SetupFilters()
	AddFilter("LOC_PRODUCTION_MANAGER_FILTER_FOUNDING"); -- Founding requires no sort function since the default order is by founding
	AddFilter("LOC_PRODUCTION_MANAGER_FILTER_NAME", function(a, b) return Locale.Lookup(a:GetName()) < Locale.Lookup(b:GetName()); end);
	AddFilter("LOC_PRODUCTION_MANAGER_FILTER_POPULATION", function(a, b) return a:GetPopulation() > b:GetPopulation(); end);

	Controls.FilterPulldown:CalculateInternals();
end

-- ===========================================================================
function AddFilter( name:string, sortFunc )
	local controlTable:table = {};       
	Controls.FilterPulldown:BuildEntry( "FilterItemInstance", controlTable );
	controlTable.DescriptionText:SetText(Locale.Lookup(name));
	controlTable.Button:RegisterCallback(Mouse.eLClick, function() Refresh(sortFunc, name); end);
end

-- ===========================================================================
function SetSelectedCity( cityID:number )
    for i=1, m_CityInstanceIM.m_iCount, 1 do
        local instance:table = m_CityInstanceIM:GetAllocatedInstance(i);
        if instance and instance[FIELD_CITY_ID] == cityID then
            instance.CityButton:SetSelected(true);
			m_SelectedCityInstance = instance;
		else
			instance.CityButton:SetSelected(false);
        end
		RefreshQueueButtonStates(instance)
    end
end

-- ===========================================================================
function OnCityInstanceClicked( playerID:number, cityID:number )
	local pCity:table = CityManager.GetCity(playerID, cityID);
	UI.SelectCity( pCity );
end

-- ===========================================================================
function Close()
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function Open()
	Refresh();
	ContextPtr:SetHide(false);
end

-- ===========================================================================
function OnOpen()
	Open();
	ScrollToSelectedCity();
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
function OnToggle()
	if ContextPtr:IsHidden() then
		Open();
	else
		Close();
	end
end

-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );		
	end

	SetupFilters();
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["isHidden"] ~= nil then
			if contextTable["isHidden"] == true then
				Close();
			else
				Open();
			end
		end
	end
end

-- ===========================================================================
function OnCityProductionQueueChanged(playerID, cityID, changeType, queueIndex)
    if (ContextPtr ~= nil and ContextPtr:IsHidden()) or playerID ~= Game.GetLocalPlayer() then
		return;
	end
	
	local pCityInstance:table = FindCityInstance(cityID);
	if pCityInstance ~= nil then
		local pCity:table = CityManager.GetCity(playerID, cityID);
		if pCity ~= nil then
			RefreshCityInstance(pCityInstance, pCity);
		end
	end

	DeselectItem();
end

-- ===========================================================================
function OnCitySelectionChanged( owner:number, cityID:number, i, j, k, isSelected:boolean, isEditable:boolean)
    if (ContextPtr ~= nil and ContextPtr:IsHidden()) or owner ~= Game.GetLocalPlayer() then
		return;
	end

	SetSelectedCity(cityID);
end

-- ===========================================================================
function OnUnitSelectionChanged( playerID : number, unitID : number, hexI : number, hexJ : number, hexK : number, bSelected : boolean, bEditable : boolean )
	local localPlayerID:number = Game.GetLocalPlayer();
	if playerID == localPlayerID then
		-- If a unit is selected and this is showing; hide it.
		local pSelectedUnit:table = UI.GetHeadSelectedUnit();
		if pSelectedUnit ~= nil and not ContextPtr:IsHidden() then 
			Close();
		end
	end
end

-- ===========================================================================
function OnProductionClicked()
	if m_kSelectedQueueItem.Index ~= -1 then
		DeselectItem();
	end
end

-- ===========================================================================
function OnCancelManagerSelection()
	DeselectItem();
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );

    Events.CityProductionQueueChanged.Add( OnCityProductionQueueChanged );
	Events.CitySelectionChanged.Add( OnCitySelectionChanged );
	Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );

	LuaEvents.ProductionPanel_ToggleManager.Add( OnToggle );
	LuaEvents.ProductionPanel_OpenManager.Add( OnOpen );
	LuaEvents.ProductionPanel_CloseManager.Add( OnClose );
	LuaEvents.ProductionPanel_ProductionClicked.Add( OnProductionClicked );
	LuaEvents.ProductionPanel_CancelManagerSelection.Add( OnCancelManagerSelection );
end
Initialize();

