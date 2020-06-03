-- Copyright 2016-2018, Firaxis Games

include("CitySupport");
include("Civ6Common");
include("InstanceManager");
include("SupportFunctions");
include("TabSupport");
include("LeaderIcon");


-- ===========================================================================
--	DEBUG
--	Toggle these for temporary debugging help.
-- ===========================================================================
local m_debugNumResourcesStrategic	:number = 0;			-- (0) number of extra strategics to show for screen testing.
local m_debugNumBonuses				:number = 0;			-- (0) number of extra bonuses to show for screen testing.
local m_debugNumResourcesLuxuries	:number = 0;			-- (0) number of extra luxuries to show for screen testing.

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "ReportScreen"; -- Must be unique (usually the same as the file name)

local DARKEN_CITY_INCOME_AREA_ADDITIONAL_Y		:number = 6;
local DATA_FIELD_SELECTION						:string = "Selection";
local SIZE_HEIGHT_BOTTOM_YIELDS					:number = 135;
local SIZE_HEIGHT_PADDING_BOTTOM_ADJUST			:number = 85;	-- (Total Y - (scroll area + THIS PADDING)) = bottom area
local INDENT_STRING								:string = "        ";
local GOSSIP_ENTRY_CONSTANT						:number = 62;
local GOSSIP_HEADER_SIZE						:number = 230;
local GOSSIP_FILTER_ALL							:string = "ALL";

local REPORT_PAGES	:table = {
	YIELDS		= 1,
	RESOURCES	= 2,
	CITY_STATUS = 3,
	GOSSIP		= 4
}

-- Mapping of unit type to cost.
local UnitCostMap:table = {};
do
	for row in GameInfo.Units() do
		UnitCostMap[row.UnitType] = row.Maintenance;
	end
end

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_simpleIM				:table = InstanceManager:new("SimpleInstance",			"Top",		Controls.Stack);				-- Non-Collapsable, simple
local m_tabIM					:table = InstanceManager:new("TabInstance",				"Button",	Controls.TabContainer);
local m_strategicResourcesIM	:table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.StrategicResources);
local m_bonusResourcesIM		:table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.BonusResources);
local m_luxuryResourcesIM		:table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.LuxuryResources);
local m_groupIM					:table = InstanceManager:new("GroupInstance",			"Top",		Controls.Stack);				-- Collapsable

local m_kTabs:table = nil;
local m_CurrentReportTab:number = 1;

local m_kResourceData		:table = nil;
local m_kCityData			:table = nil;
local m_kCityTotalData		:table = nil;
local m_kUnitData			:table = nil;	-- TODO: Show units by promotion class
local m_kDealData			:table = nil;
local m_uiGroups			:table = nil;	-- Track the groups on-screen for collapse all action.

local m_isCollapsing		:boolean = true;

--Gossip filtering
local m_kGossipInstances:table = {};
local m_groupFilter:string = GOSSIP_FILTER_ALL;
local m_leaderFilter:number = -1;	-- (-1) Indicates Unfilitered by this criteria (PlayerID)
local m_kGossipLog:table = {};
local m_kGossipLogFiltered:table = {};
local m_kGossipFiltersToShow:table = {}; -- GroupType indexed table used to determine which gossip GroupType filters to show
local m_CountPerPage:number = 0;
local m_CurrentGossipPage:number = 0;
local m_MaxPages:number = 0;
local m_uiPaginationInstance:table = {};
local m_uiGossipFilterInstance:table = {};

local m_kGossipGroupTypes:table	= {};

-- ===========================================================================
--	Single exit point for display
-- ===========================================================================
function Close()
	if not ContextPtr:IsHidden() then
		UI.PlaySound("UI_Screen_Close");
	end

	UIManager:DequeuePopup(ContextPtr);
end


-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnCloseButton()
	Close();
end

-- ===========================================================================
--	Single entry point for display
-- ===========================================================================
function Open( tabToOpen:number )
	
	if tabToOpen == nil then
		tabToOpen = REPORT_PAGES.YIELDS;
	end

	UIManager:QueuePopup( ContextPtr, PopupPriority.Medium );
	Controls.ScreenAnimIn:SetToBeginning();
	Controls.ScreenAnimIn:Play();
	UI.PlaySound("UI_Screen_Open");

	m_kCityData, m_kCityTotalData, m_kResourceData, m_kUnitData, m_kDealData = GetData();
	table.sort(m_kCityData, SortCities);
	
	Resize();
	m_kTabs.SelectTab( tabToOpen );
end

-- ===========================================================================
function SortCities(a,b)
	return a.Order < b.Order;
end

-- ===========================================================================
--	LUA Events
--	Opened via the top panel
-- ===========================================================================
function OnTopOpenReportsScreen()
	Open();
end

-- ===========================================================================
--	LUA Events
-- ===========================================================================
function OnOpenCityStatus()
	Open(REPORT_PAGES.CITY_STATUS);
end

-- ===========================================================================
--	LUA Events
-- ===========================================================================
function OnOpenResources()
	Open(REPORT_PAGES.RESOURCES);
end

-- ===========================================================================
--	LUA Events
-- ===========================================================================
function OnOpenGossip()
	Open(REPORT_PAGES.GOSSIP);
end

-- ===========================================================================
--	LUA Events
--	Closed via the top panel
-- ===========================================================================
function OnTopCloseReportsScreen()
	Close();	
end

-- ===========================================================================
--	UI Callback
--	Collapse all the things!
-- ===========================================================================
function OnCollapseAllButton()
	if m_uiGroups == nil or table.count(m_uiGroups) == 0 then
		return;
	end

	for i,instance in ipairs( m_uiGroups ) do
		if instance["isCollapsed"] ~= m_isCollapsing then
			instance["isCollapsed"] = m_isCollapsing;
			instance.CollapseAnim:Reverse();
			RealizeGroup( instance );
		end
	end
	Controls.CollapseAll:LocalizeAndSetText(m_isCollapsing and "LOC_HUD_REPORTS_EXPAND_ALL" or "LOC_HUD_REPORTS_COLLAPSE_ALL");
	m_isCollapsing = not m_isCollapsing;
end

-- ===========================================================================
--	Populate with all data required for any/all report tabs.
-- ===========================================================================
function GetData()
	local kResources	:table = {};
	local kCityData		:table = {};
	local kCityTotalData:table = {
		Income	= {},
		Expenses= {},
		Net		= {},
		Treasury= {}
	};
	local kUnitData		:table = {};


	kCityTotalData.Income[YieldTypes.CULTURE]	= 0;
	kCityTotalData.Income[YieldTypes.FAITH]		= 0;
	kCityTotalData.Income[YieldTypes.FOOD]		= 0;
	kCityTotalData.Income[YieldTypes.GOLD]		= 0;
	kCityTotalData.Income[YieldTypes.PRODUCTION]= 0;
	kCityTotalData.Income[YieldTypes.SCIENCE]	= 0;
	kCityTotalData.Income["TOURISM"]			= 0;
	kCityTotalData.Expenses[YieldTypes.GOLD]	= 0;
	
	local playerID	:number = Game.GetLocalPlayer();
	if playerID == PlayerTypes.NONE then
		UI.DataError("Unable to get valid playerID for report screen.");
		return;
	end

	local player	:table  = Players[playerID];
	local pCulture	:table	= player:GetCulture();
	local pTreasury	:table	= player:GetTreasury();
	local pReligion	:table	= player:GetReligion();
	local pScience	:table	= player:GetTechs();
	local pResources:table	= player:GetResources();		

	local pCities = player:GetCities();
	for i, pCity in pCities:Members() do	
		local cityName	:string = pCity:GetName();
			
		-- Big calls, obtain city data and add report specific fields to it.
		local data		:table	= GetCityData( pCity );
		data.Resources			= GetCityResourceData( pCity );					-- Add more data (not in CitySupport)			
		data.WorkedTileYields	= GetWorkedTileYieldData( pCity, pCulture );	-- Add more data (not in CitySupport)
		data.Order= i;

		-- Add to totals.
		kCityTotalData.Income[YieldTypes.CULTURE]	= kCityTotalData.Income[YieldTypes.CULTURE] + data.CulturePerTurn;
		kCityTotalData.Income[YieldTypes.FAITH]		= kCityTotalData.Income[YieldTypes.FAITH] + data.FaithPerTurn;
		kCityTotalData.Income[YieldTypes.FOOD]		= kCityTotalData.Income[YieldTypes.FOOD] + data.FoodPerTurn;
		kCityTotalData.Income[YieldTypes.GOLD]		= kCityTotalData.Income[YieldTypes.GOLD] + data.GoldPerTurn;
		kCityTotalData.Income[YieldTypes.PRODUCTION]= kCityTotalData.Income[YieldTypes.PRODUCTION] + data.ProductionPerTurn;
		kCityTotalData.Income[YieldTypes.SCIENCE]	= kCityTotalData.Income[YieldTypes.SCIENCE] + data.SciencePerTurn;
		kCityTotalData.Income["TOURISM"]			= kCityTotalData.Income["TOURISM"] + data.WorkedTileYields["TOURISM"];
			
		table.insert(kCityData, data);

		-- Add outgoing route data
		data.OutgoingRoutes = pCity:GetTrade():GetOutgoingRoutes();
	
		-- Add resources
		if m_debugNumResourcesStrategic > 0 or m_debugNumResourcesLuxuries > 0 or m_debugNumBonuses > 0 then
			for debugRes=1,m_debugNumResourcesStrategic,1 do
				kResources[debugRes] = {
					CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
					Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
					IsStrategic	= true,
					IsLuxury	= false,
					IsBonus		= false,
					Total		= 88
				};
			end
			for debugRes=1,m_debugNumResourcesLuxuries,1 do
				kResources[debugRes] = {
					CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
					Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
					IsStrategic	= false,
					IsLuxury	= true,
					IsBonus		= false,
					Total		= 88
				};
			end
			for debugRes=1,m_debugNumBonuses,1 do
				kResources[debugRes] = {
					CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
					Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
					IsStrategic	= false,
					IsLuxury	= false,
					IsBonus		= true,
					Total		= 88
				};
			end
		end

		for eResourceType,amount in pairs(data.Resources) do
			AddResourceData(kResources, eResourceType, cityName, "LOC_HUD_REPORTS_TRADE_OWNED", amount);
		end
	end



	kCityTotalData.Expenses[YieldTypes.GOLD] = pTreasury:GetTotalMaintenance();

	-- NET = Income - Expense
	kCityTotalData.Net[YieldTypes.GOLD]			= kCityTotalData.Income[YieldTypes.GOLD] - kCityTotalData.Expenses[YieldTypes.GOLD];
	kCityTotalData.Net[YieldTypes.FAITH]		= kCityTotalData.Income[YieldTypes.FAITH];

	-- Treasury
	kCityTotalData.Treasury[YieldTypes.CULTURE]		= Round( pCulture:GetCultureYield(), 0 );
	kCityTotalData.Treasury[YieldTypes.FAITH]		= Round( pReligion:GetFaithBalance(), 0 );
	kCityTotalData.Treasury[YieldTypes.GOLD]		= Round( pTreasury:GetGoldBalance(), 0 );
	kCityTotalData.Treasury[YieldTypes.SCIENCE]		= Round( pScience:GetScienceYield(), 0 );
	kCityTotalData.Treasury["TOURISM"]				= Round( kCityTotalData.Income["TOURISM"], 0 );


	-- Units (TODO: Group units by promotion class and determine total maintenance cost)
	local MaintenanceDiscountPerUnit:number = pTreasury:GetMaintDiscountPerUnit();
	local pUnits :table = player:GetUnits(); 	
	for i, pUnit in pUnits:Members() do
		local pUnitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
		local unitTypeKey = pUnitInfo.UnitType;
		local TotalMaintenanceAfterDiscount:number = 0;
		local unitMaintenance = 0;
		local unitName :string = Locale.Lookup(pUnitInfo.Name);
		local unitMilitaryFormation = pUnit:GetMilitaryFormation();
		unitTypeKey = unitTypeKey .. unitMilitaryFormation;
		if (pUnitInfo.Domain == "DOMAIN_SEA") then
			if (unitMilitaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
				unitName = unitName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX");
				unitMaintenance = UnitManager.GetUnitCorpsMaintenance(pUnitInfo.Hash);
			elseif (unitMilitaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
				unitName = unitName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX");
				unitMaintenance = UnitManager.GetUnitArmyMaintenance(pUnitInfo.Hash);
			else
				unitMaintenance = UnitManager.GetUnitMaintenance(pUnitInfo.Hash);
			end
		else
			if (unitMilitaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
				unitName = unitName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX");
				unitMaintenance = UnitManager.GetUnitCorpsMaintenance(pUnitInfo.Hash);
			elseif (unitMilitaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
				unitName = unitName .. " " .. Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX");
				unitMaintenance = UnitManager.GetUnitArmyMaintenance(pUnitInfo.Hash);
			else
				unitMaintenance = UnitManager.GetUnitMaintenance(pUnitInfo.Hash);
			end
		end

		if (unitMaintenance > 0) then
			TotalMaintenanceAfterDiscount = unitMaintenance - MaintenanceDiscountPerUnit; 
		end
		if TotalMaintenanceAfterDiscount > 0 then
			if kUnitData[unitTypeKey] == nil then
				local UnitEntry:table = {};
				UnitEntry.Name = unitName;
				UnitEntry.Count = 1;
				UnitEntry.Maintenance = TotalMaintenanceAfterDiscount;
				kUnitData[unitTypeKey]= UnitEntry;
			else
				kUnitData[unitTypeKey].Count = kUnitData[unitTypeKey].Count + 1;
				kUnitData[unitTypeKey].Maintenance = kUnitData[unitTypeKey].Maintenance + TotalMaintenanceAfterDiscount;
			end
		end
	end
	
	local kDealData	:table = {};
	local kPlayers	:table = PlayerManager.GetAliveMajors();
	for _, pOtherPlayer in ipairs(kPlayers) do
		local otherID:number = pOtherPlayer:GetID();
		local currentGameTurn = Game.GetCurrentGameTurn();
		if  otherID ~= playerID then			
			
			local pPlayerConfig	:table = PlayerConfigurations[otherID];
			local pDeals		:table = DealManager.GetPlayerDeals(playerID, otherID);
			
			if pDeals ~= nil then
				for i,pDeal in ipairs(pDeals) do
					-- Add outgoing gold deals
					local pOutgoingDeal :table	= pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, playerID);
					if pOutgoingDeal ~= nil then
						for i,pDealItem in ipairs(pOutgoingDeal) do
							local duration		:number = pDealItem:GetDuration();
							local remainingTurns:number = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
							if duration ~= 0 then
								local gold :number = pDealItem:GetAmount();
								table.insert( kDealData, {
									Type		= DealItemTypes.GOLD,
									Amount		= gold,
									Duration	= remainingTurns,
									IsOutgoing	= true,
									PlayerID	= otherID,
									Name		= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
								});						
							end
						end
					end

					-- Add outgoing resource deals
					pOutgoingDeal = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, playerID);
					if pOutgoingDeal ~= nil then
						for i,pDealItem in ipairs(pOutgoingDeal) do
							local duration		:number = pDealItem:GetDuration();
							local remainingTurns:number = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
							if duration ~= 0 then
								local amount		:number = pDealItem:GetAmount();
								local resourceType	:number = pDealItem:GetValueType();
								table.insert( kDealData, {
									Type			= DealItemTypes.RESOURCES,
									ResourceType	= resourceType,
									Amount			= amount,
									Duration		= remainingTurns,
									IsOutgoing		= true,
									PlayerID		= otherID,
									Name			= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
								});
								
								local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. " " .. Locale.Lookup("LOC_REPORTS_NUMBER_OF_TURNS", remainingTurns) .. ")";
								AddResourceData(kResources, resourceType, entryString, "LOC_HUD_REPORTS_TRADE_EXPORTED", -1 * amount);				
							end
						end
					end
					
					-- Add incoming gold deals
					local pIncomingDeal :table = pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, otherID);
					if pIncomingDeal ~= nil then
						for i,pDealItem in ipairs(pIncomingDeal) do
							local duration		:number = pDealItem:GetDuration();
							local remainingTurns:number = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
							if duration ~= 0 then
								local gold :number = pDealItem:GetAmount()
								table.insert( kDealData, {
									Type		= DealItemTypes.GOLD;
									Amount		= gold,
									Duration	= remainingTurns,
									IsOutgoing	= false,
									PlayerID	= otherID,
									Name		= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
								});						
							end
						end
					end

					-- Add incoming resource deals
					pIncomingDeal = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, otherID);
					if pIncomingDeal ~= nil then
						for i,pDealItem in ipairs(pIncomingDeal) do
							local duration		:number = pDealItem:GetDuration();
							if duration ~= 0 then
								local amount		:number = pDealItem:GetAmount();
								local resourceType	:number = pDealItem:GetValueType();
								local remainingTurns:number = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
								table.insert( kDealData, {
									Type			= DealItemTypes.RESOURCES,
									ResourceType	= resourceType,
									Amount			= amount,
									Duration		= remainingTurns,
									IsOutgoing		= false,
									PlayerID		= otherID,
									Name			= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
								});
								
								local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. " " .. Locale.Lookup("LOC_REPORTS_NUMBER_OF_TURNS", remainingTurns) .. ")";
								AddResourceData(kResources, resourceType, entryString, "LOC_HUD_REPORTS_TRADE_IMPORTED", amount);				
							end
						end
					end	
				end							
			end

		end
	end

	-- Add resources provided by city states
	for i, pMinorPlayer in ipairs(PlayerManager.GetAliveMinors()) do
		local pMinorPlayerInfluence:table = pMinorPlayer:GetInfluence();		
		if pMinorPlayerInfluence ~= nil then
			local suzerainID:number = pMinorPlayerInfluence:GetSuzerain();
			if suzerainID == playerID then
				for row in GameInfo.Resources() do
					local resourceAmount:number =  pMinorPlayer:GetResources():GetExportedResourceAmount(row.Index);
					if resourceAmount > 0 then
						local pMinorPlayerConfig:table = PlayerConfigurations[pMinorPlayer:GetID()];
						local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_CITY_STATE") .. " (" .. Locale.Lookup(pMinorPlayerConfig:GetPlayerName()) .. ")";
						AddResourceData(kResources, row.Index, entryString, "LOC_CITY_STATES_SUZERAIN", resourceAmount);
					end
				end
			end
		end
	end

	kResources = AddMiscResourceData(pResources, kResources);

	return kCityData, kCityTotalData, kResources, kUnitData, kDealData;
end

function AddMiscResourceData(pResourceData:table, kResourceTable:table)
	-- Resources not yet accounted for come from other gameplay bonuses
	if pResourceData then
		for row in GameInfo.Resources() do
			local internalResourceAmount:number = pResourceData:GetResourceAmount(row.Index);
			if (internalResourceAmount > 0) then
				if (kResourceTable[row.Index] ~= nil) then
					if (internalResourceAmount > kResourceTable[row.Index].Total) then
						AddResourceData(kResourceTable, row.Index, "LOC_HUD_REPORTS_MISC_RESOURCE_SOURCE", "-", internalResourceAmount - kResourceTable[row.Index].Total);
					end
				else
					AddResourceData(kResourceTable, row.Index, "LOC_HUD_REPORTS_MISC_RESOURCE_SOURCE", "-", internalResourceAmount);
				end
			end
		end
	end
	return kResourceTable;
end

-- ===========================================================================
--	kResources	(in) the table to add resources to.
function AddResourceData( kResources:table, eResourceType:number, EntryString:string, ControlString:string, InAmount:number)
	local kResource :table = GameInfo.Resources[eResourceType];

	--Artifacts need to be excluded because while TECHNICALLY a resource, they do nothing to contribute in a way that is relevant to any other resource 
	--or screen. So... exclusion.
	if kResource.ResourceClassType == "RESOURCECLASS_ARTIFACT" then
		return;
	end

	if kResources[eResourceType] == nil then
		kResources[eResourceType] = {
			EntryList	= {},
			Icon		= "[ICON_"..kResource.ResourceType.."]",
			IsStrategic	= kResource.ResourceClassType == "RESOURCECLASS_STRATEGIC",
			IsLuxury	= GameInfo.Resources[eResourceType].ResourceClassType == "RESOURCECLASS_LUXURY",
			IsBonus		= GameInfo.Resources[eResourceType].ResourceClassType == "RESOURCECLASS_BONUS",
			Total		= 0
		};
	end

	if EntryString ~= "" then
		table.insert( kResources[eResourceType].EntryList, 
		{
			EntryText	= EntryString,
			ControlText = ControlString,
			Amount		= InAmount,					
		});
	end

	kResources[eResourceType].Total = kResources[eResourceType].Total + InAmount;
end

-- ===========================================================================
--	Obtain the total resources for a given city.
-- ===========================================================================
function GetCityResourceData( pCity:table )

	-- Loop through all the plots for a given city; tallying the resource amount.
	local kResources : table = {};
	local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(pCity)
	for _, plotID in ipairs(cityPlots) do
		local plot			: table = Map.GetPlotByIndex(plotID)
		local plotX			: number = plot:GetX()
		local plotY			: number = plot:GetY()
		local eResourceType : number = plot:GetResourceType();

		-- TODO: Account for trade/diplomacy resources.
		if eResourceType ~= -1 and Players[pCity:GetOwner()]:GetResources():IsResourceExtractableAt(plot) then
			if kResources[eResourceType] == nil then
				kResources[eResourceType] = 1;
			else
				kResources[eResourceType] = kResources[eResourceType] + 1;
			end
		end
	end
	return kResources;
end

-- ===========================================================================
--	Obtain the yields from the worked plots
-- ===========================================================================
function GetWorkedTileYieldData( pCity:table, pCulture:table )

	-- Loop through all the plots for a given city; tallying the resource amount.
	local kYields : table = {
		YIELD_PRODUCTION= 0,
		YIELD_FOOD		= 0,
		YIELD_GOLD		= 0,
		YIELD_FAITH		= 0,
		YIELD_SCIENCE	= 0,
		YIELD_CULTURE	= 0,
		TOURISM			= 0,
	};
	local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(pCity);
	local pCitizens	: table = pCity:GetCitizens();	
	for _, plotID in ipairs(cityPlots) do		
		local plot	: table = Map.GetPlotByIndex(plotID);
		local x		: number = plot:GetX();
		local y		: number = plot:GetY();
		isPlotWorked = pCitizens:IsPlotWorked(x,y);
		if isPlotWorked then
			for row in GameInfo.Yields() do			
				kYields[row.YieldType] = kYields[row.YieldType] + plot:GetYield(row.Index);				
			end
		end

		-- Support tourism.
		-- Not a common yield, and only exposure from game core is based off
		-- of the plot so the sum is easily shown, but it's not possible to 
		-- show how individual buildings contribute... yet.
		kYields["TOURISM"] = kYields["TOURISM"] + pCulture:GetTourismAt( plotID );
	end
	return kYields;
end



-- ===========================================================================
--	Set a group to it's proper collapse/open state
--	Set + - in group row
-- ===========================================================================
function RealizeGroup( instance:table )
	local v :number = (instance["isCollapsed"]==false and instance.RowExpandCheck:GetSizeY() or 0);
	instance.RowExpandCheck:SetTextureOffsetVal(0, v);

	instance.ContentStack:CalculateSize();	
	instance.CollapseScroll:CalculateSize();
	
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	instance.CollapseAnim:SetBeginVal(0, -(groupHeight - instance["CollapsePadding"]));
	instance.CollapseScroll:SetSizeY( groupHeight );				
end

-- ===========================================================================
--	Callback
--	Expand or contract a group based on its existing state.
-- ===========================================================================
function OnToggleCollapseGroup( instance:table )
	instance["isCollapsed"] = not instance["isCollapsed"];
	instance.CollapseAnim:Reverse();
	RealizeGroup( instance );
end

-- ===========================================================================
--	Toggle a group expanding / collapsing
--	instance,	A group instance.
-- ===========================================================================
function OnAnimGroupCollapse( instance:table)
		-- Helper
	function lerp(y1:number,y2:number,x:number)
		return y1 + (y2-y1)*x;
	end
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	local collapseHeight:number = instance["CollapsePadding"]~=nil and instance["CollapsePadding"] or 0;
	local startY		:number = instance["isCollapsed"]==true  and groupHeight or collapseHeight;
	local endY			:number = instance["isCollapsed"]==false and groupHeight or collapseHeight;
	local progress		:number = instance.CollapseAnim:GetProgress();
	local sizeY			:number = lerp(startY,endY,progress);
		
	instance.CollapseScroll:SetSizeY( sizeY );	

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();			
end


-- ===========================================================================
function SetGroupCollapsePadding( instance:table, amount:number )
	instance["CollapsePadding"] = amount;
end


-- ===========================================================================
function ResetTabForNewPageContent()
	m_uiGroups = {};
	m_simpleIM:ResetInstances();
	m_groupIM:ResetInstances();
	m_isCollapsing = true;
	Controls.CollapseAll:LocalizeAndSetText("LOC_HUD_REPORTS_COLLAPSE_ALL");
	Controls.Scroll:SetScrollValue( 0 );	
	m_kGossipInstances = {};
	m_CurrentGossipPage = 0;
	m_MaxPages = 0;
	m_CountPerPage = 0;
	m_uiPaginationInstance = {};
	m_uiGossipFilterInstance = {};
end


-- ===========================================================================
--	Instantiate a new collapsable row (group) holder & wire it up.
--	ARGS:	(optional) isCollapsed
--	RETURNS: New group instance
-- ===========================================================================
function NewCollapsibleGroupInstance( isCollapsed:boolean )
	if isCollapsed == nil then
		isCollapsed = false;
	end
	local instance:table = m_groupIM:GetInstance();	
	instance.ContentStack:DestroyAllChildren();
	instance["isCollapsed"]		= isCollapsed;
	instance["CollapsePadding"] = nil;				-- reset any prior collapse padding

	instance.CollapseAnim:SetToBeginning();
	if isCollapsed == false then
		instance.CollapseAnim:SetToEnd();
	end	

	instance.RowHeaderButton:RegisterCallback( Mouse.eLClick, function() OnToggleCollapseGroup(instance); end );			
  	instance.RowHeaderButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	instance.CollapseAnim:RegisterAnimCallback(               function() OnAnimGroupCollapse( instance ); end );

	table.insert( m_uiGroups, instance );

	return instance;
end


-- ===========================================================================
--	debug - Create a test page.
-- ===========================================================================
function ViewTestPage()

	ResetTabForNewPageContent();

	local instance:table = NewCollapsibleGroupInstance();	
	instance.RowHeaderButton:SetText( "Test City Icon 1" );
	instance.Top:SetID("foo");
	
	local pHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityIncomeHeaderInstance", pHeaderInstance, instance.ContentStack ) ;	

	local pCityInstance:table = {};
	ContextPtr:BuildInstanceForControl( "CityIncomeInstance", pCityInstance, instance.ContentStack ) ;

	for i=1,3,1 do
		local pLineItemInstance:table = {};
		ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
	end

	local pFooterInstance:table = {};
	ContextPtr:BuildInstanceForControl("CityIncomeFooterInstance", pFooterInstance, instance.ContentStack  );
	
	SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
	RealizeGroup( instance );
	
	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( true );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomYieldTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewYieldsPage()	

	m_CurrentReportTab = REPORT_PAGES.YIELDS;
	ResetTabForNewPageContent();

	local instance:table = nil;
	instance = NewCollapsibleGroupInstance();
	instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_CITY_INCOME") );
	
	local pHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityIncomeHeaderInstance", pHeaderInstance, instance.ContentStack ) ;	

	local goldCityTotal		:number = 0;
	local faithCityTotal	:number = 0;
	local scienceCityTotal	:number = 0;
	local cultureCityTotal	:number = 0;
	local tourismCityTotal	:number = 0;
	

	-- ========== City Income ==========

	function CreatLineItemInstance(cityInstance:table, name:string, production:number, gold:number, food:number, science:number, culture:number, faith:number)
		local lineInstance:table = {};
		ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", lineInstance, cityInstance.LineItemStack );
		TruncateStringWithTooltipClean(lineInstance.LineItemName, 160, name);
		lineInstance.Production:SetText( toPlusMinusNoneString(production));
		lineInstance.Food:SetText( toPlusMinusNoneString(food));
		lineInstance.Gold:SetText( toPlusMinusNoneString(gold));
		lineInstance.Faith:SetText( toPlusMinusNoneString(faith));
		lineInstance.Science:SetText( toPlusMinusNoneString(science));
		lineInstance.Culture:SetText( toPlusMinusNoneString(culture));

		return lineInstance;
	end

	for i,kCityData in ipairs(m_kCityData) do
		local cityName :string = kCityData.CityName;
		local pCityInstance:table = {};
		ContextPtr:BuildInstanceForControl( "CityIncomeInstance", pCityInstance, instance.ContentStack ) ;
		pCityInstance.LineItemStack:DestroyAllChildren();
		TruncateStringWithTooltip(pCityInstance.CityName, 230, Locale.Lookup(kCityData.CityName)); 

		--Great works
		local greatWorks:table = GetGreatWorksForCity(kCityData.City);

		-- Current Production
		local kCurrentProduction:table = kCityData.ProductionQueue[1];
		pCityInstance.CurrentProduction:SetHide( kCurrentProduction == nil );
		if kCurrentProduction ~= nil then
			local tooltip:string = Locale.Lookup(kCurrentProduction.Name);
			if kCurrentProduction.Description ~= nil then
				tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup(kCurrentProduction.Description);
			end
			pCityInstance.CurrentProduction:SetToolTipString( tooltip )

			if kCurrentProduction.Icon then
				pCityInstance.CityBannerBackground:SetHide( false );
				pCityInstance.CurrentProduction:SetIcon( kCurrentProduction.Icon );
				pCityInstance.CityProductionMeter:SetPercent( kCurrentProduction.PercentComplete );
				pCityInstance.CityProductionNextTurn:SetPercent( kCurrentProduction.PercentCompleteNextTurn );			
				pCityInstance.ProductionBorder:SetHide( kCurrentProduction.Type == ProductionType.DISTRICT );
			else
				pCityInstance.CityBannerBackground:SetHide( true );
			end
		end

		pCityInstance.Production:SetText( toPlusMinusString(kCityData.ProductionPerTurn) );
		pCityInstance.Food:SetText( toPlusMinusString(kCityData.FoodPerTurn) );
		pCityInstance.Gold:SetText( toPlusMinusString(kCityData.GoldPerTurn) );
		pCityInstance.Faith:SetText( toPlusMinusString(kCityData.FaithPerTurn) );
		pCityInstance.Science:SetText( toPlusMinusString(kCityData.SciencePerTurn) );
		pCityInstance.Culture:SetText( toPlusMinusString(kCityData.CulturePerTurn) );
		pCityInstance.Tourism:SetText( toPlusMinusString(kCityData.WorkedTileYields["TOURISM"]) );

		-- Add to all cities totals
		goldCityTotal	= goldCityTotal + kCityData.GoldPerTurn;
		faithCityTotal	= faithCityTotal + kCityData.FaithPerTurn;
		scienceCityTotal= scienceCityTotal + kCityData.SciencePerTurn;
		cultureCityTotal= cultureCityTotal + kCityData.CulturePerTurn;
		tourismCityTotal= tourismCityTotal + kCityData.WorkedTileYields["TOURISM"];

		for i,kDistrict in ipairs(kCityData.BuildingsAndDistricts) do			
			--District line item
			local districtInstance = CreatLineItemInstance(	pCityInstance, 
															kDistrict.Name,
															kDistrict.Production,
															kDistrict.Gold,
															kDistrict.Food,
															kDistrict.Science,
															kDistrict.Culture,
															kDistrict.Faith);
			districtInstance.DistrictIcon:SetHide(false);
			districtInstance.DistrictIcon:SetIcon(kDistrict.Icon);

			function HasValidAdjacencyBonus(adjacencyTable:table)
				for _, yield in pairs(adjacencyTable) do
					if yield ~= 0 then
						return true;
					end
				end
				return false;
			end

			--Adjacency
			if HasValidAdjacencyBonus(kDistrict.AdjacencyBonus) then
				CreatLineItemInstance(	pCityInstance,
										INDENT_STRING .. Locale.Lookup("LOC_HUD_REPORTS_ADJACENCY_BONUS"),
										kDistrict.AdjacencyBonus.Production,
										kDistrict.AdjacencyBonus.Gold,
										kDistrict.AdjacencyBonus.Food,
										kDistrict.AdjacencyBonus.Science,
										kDistrict.AdjacencyBonus.Culture,
										kDistrict.AdjacencyBonus.Faith);
			end

			
			for i,kBuilding in ipairs(kDistrict.Buildings) do
				CreatLineItemInstance(	pCityInstance,
										INDENT_STRING ..  kBuilding.Name,
										kBuilding.ProductionPerTurn,
										kBuilding.GoldPerTurn,
										kBuilding.FoodPerTurn,
										kBuilding.SciencePerTurn,
										kBuilding.CulturePerTurn,
										kBuilding.FaithPerTurn);

				--Add great works
				if greatWorks[kBuilding.Type] ~= nil then
					--Add our line items!
					for _, kGreatWork in ipairs(greatWorks[kBuilding.Type]) do
						local pLineItemInstance = CreatLineItemInstance(	pCityInstance, INDENT_STRING .. INDENT_STRING ..  Locale.Lookup(kGreatWork.Name), 0, 0, 0,	0, 0, 0);
						for _, yield in ipairs(kGreatWork.YieldChanges) do
							if (yield.YieldType == "YIELD_FOOD") then
								pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_PRODUCTION") then
								pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_GOLD") then
								pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_SCIENCE") then
								pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_CULTURE") then
								pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_FAITH") then
								pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.YieldChange) );
							end
						end
					end
				end

			end
		end

		-- Display wonder yields
		if kCityData.Wonders then
			for _, wonder in ipairs(kCityData.Wonders) do
				if wonder.Yields[1] ~= nil or greatWorks[wonder.Type] ~= nil then
				-- Assign yields to the line item
					local pLineItemInstance:table = CreatLineItemInstance(pCityInstance, wonder.Name, 0, 0, 0, 0, 0, 0);
					for _, yield in ipairs(wonder.Yields) do
						if (yield.YieldType == "YIELD_FOOD") then
							pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_PRODUCTION") then
							pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_GOLD") then
							pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_SCIENCE") then
							pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_CULTURE") then
							pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_FAITH") then
							pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.YieldChange) );
						end
					end
				end

				--Add great works
				if greatWorks[wonder.Type] ~= nil then
					--Add our line items!
					for _, kGreatWork in ipairs(greatWorks[wonder.Type]) do
						local pLineItemInstance = CreatLineItemInstance(	pCityInstance, INDENT_STRING ..  Locale.Lookup(kGreatWork.Name), 0, 0, 0,	0, 0, 0);
						for _, yield in ipairs(kGreatWork.YieldChanges) do
							if (yield.YieldType == "YIELD_FOOD") then
								pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_PRODUCTION") then
								pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_GOLD") then
								pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_SCIENCE") then
								pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_CULTURE") then
								pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.YieldChange) );
							elseif (yield.YieldType == "YIELD_FAITH") then
								pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.YieldChange) );
							end
						end
					end
				end
			end
		end

		-- Display route yields
		if kCityData.OutgoingRoutes then
			for i,route in ipairs(kCityData.OutgoingRoutes) do
				if route ~= nil then
					if route.OriginYields then
						-- Find destination city
						local pDestPlayer:table = Players[route.DestinationCityPlayer];
						local pDestPlayerCities:table = pDestPlayer:GetCities();
						local pDestCity:table = pDestPlayerCities:FindID(route.DestinationCityID);

						--Assign yields to the line item
						local pLineItemInstance:table = CreatLineItemInstance(pCityInstance, Locale.Lookup("LOC_HUD_REPORTS_TRADE_WITH", Locale.Lookup(pDestCity:GetName())), 0, 0, 0, 0, 0, 0);
						for j,yield in ipairs(route.OriginYields) do
							local yieldInfo = GameInfo.Yields[yield.YieldIndex];
							if yieldInfo then
								if (yieldInfo.YieldType == "YIELD_FOOD") then
									pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_PRODUCTION") then
									pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_GOLD") then
									pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_SCIENCE") then
									pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_CULTURE") then
									pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_FAITH") then
									pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.Amount) );
								end
							end
						end
					end
				end
			end
		end

		--Worked Tiles
		CreatLineItemInstance(	pCityInstance,
								Locale.Lookup("LOC_HUD_REPORTS_WORKED_TILES"),
								kCityData.WorkedTileYields["YIELD_PRODUCTION"],
								kCityData.WorkedTileYields["YIELD_GOLD"],
								kCityData.WorkedTileYields["YIELD_FOOD"],
								kCityData.WorkedTileYields["YIELD_SCIENCE"],
								kCityData.WorkedTileYields["YIELD_CULTURE"],
								kCityData.WorkedTileYields["YIELD_FAITH"]);

		local iYieldPercent = (Round(1 + (kCityData.HappinessNonFoodYieldModifier/100), 2)*.1);
		CreatLineItemInstance(	pCityInstance,
								Locale.Lookup("LOC_HUD_REPORTS_HEADER_AMENITIES"),
								kCityData.WorkedTileYields["YIELD_PRODUCTION"] * iYieldPercent,
								kCityData.WorkedTileYields["YIELD_GOLD"] * iYieldPercent,
								0,
								kCityData.WorkedTileYields["YIELD_SCIENCE"] * iYieldPercent,
								kCityData.WorkedTileYields["YIELD_CULTURE"] * iYieldPercent,
								kCityData.WorkedTileYields["YIELD_FAITH"] * iYieldPercent);

		local populationToCultureScale:number = GameInfo.GlobalParameters["CULTURE_PERCENTAGE_YIELD_PER_POP"].Value / 100;
		CreatLineItemInstance(	pCityInstance,
								Locale.Lookup("LOC_HUD_CITY_POPULATION"),
								0,
								0,
								0,
								0,
								kCityData["Population"] * populationToCultureScale, 
								0);

		pCityInstance.LineItemStack:CalculateSize();
		pCityInstance.Darken:SetSizeY( pCityInstance.LineItemStack:GetSizeY() + DARKEN_CITY_INCOME_AREA_ADDITIONAL_Y );
	end

	local pFooterInstance:table = {};
	ContextPtr:BuildInstanceForControl("CityIncomeFooterInstance", pFooterInstance, instance.ContentStack  );
	pFooterInstance.Gold:SetText( "[Icon_GOLD]"..toPlusMinusString(goldCityTotal) );
	pFooterInstance.Faith:SetText( "[Icon_FAITH]"..toPlusMinusString(faithCityTotal) );
	pFooterInstance.Science:SetText( "[Icon_SCIENCE]"..toPlusMinusString(scienceCityTotal) );
	pFooterInstance.Culture:SetText( "[Icon_CULTURE]"..toPlusMinusString(cultureCityTotal) );
	pFooterInstance.Tourism:SetText( "[Icon_TOURISM]"..toPlusMinusString(tourismCityTotal) );

	SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
	RealizeGroup( instance );


	-- ========== Building Expenses ==========

	instance = NewCollapsibleGroupInstance();
	instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_BUILDING_EXPENSES") );

	local pHeader:table = {};
	ContextPtr:BuildInstanceForControl( "BuildingExpensesHeaderInstance", pHeader, instance.ContentStack ) ;

	local iTotalBuildingMaintenance :number = 0;
	for i,kCityData in ipairs(m_kCityData) do
		local cityName :string = kCityData.CityName;
		for _,kBuilding in ipairs(kCityData.Buildings) do
			if (kBuilding.Maintenance > 0 and kBuilding.isPillaged == false) then
				local pBuildingInstance:table = {};		
				ContextPtr:BuildInstanceForControl( "BuildingExpensesEntryInstance", pBuildingInstance, instance.ContentStack ) ;		
				TruncateStringWithTooltip(pBuildingInstance.CityName, 224, Locale.Lookup(cityName)); 
				pBuildingInstance.BuildingName:SetText( Locale.Lookup(kBuilding.Name) );
				pBuildingInstance.Gold:SetText( "-"..tostring(kBuilding.Maintenance));
				iTotalBuildingMaintenance = iTotalBuildingMaintenance - kBuilding.Maintenance;
			end
		end
		for _,kDistrict in ipairs(kCityData.BuildingsAndDistricts) do
			if (kDistrict.Maintenance > 0 and kDistrict.isPillaged == false and kDistrict.isBuilt == true) then
				local pDistrictInstance:table = {};		
				ContextPtr:BuildInstanceForControl( "BuildingExpensesEntryInstance", pDistrictInstance, instance.ContentStack ) ;		
				TruncateStringWithTooltip(pDistrictInstance.CityName, 224, Locale.Lookup(cityName)); 
				pDistrictInstance.BuildingName:SetText( Locale.Lookup(kDistrict.Name) );
				pDistrictInstance.Gold:SetText( "-"..tostring(kDistrict.Maintenance));
				iTotalBuildingMaintenance = iTotalBuildingMaintenance - kDistrict.Maintenance;
			end
		end
	end
	local pBuildingFooterInstance:table = {};		
	ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pBuildingFooterInstance, instance.ContentStack ) ;		
	pBuildingFooterInstance.Gold:SetText("[ICON_Gold]"..tostring(iTotalBuildingMaintenance) );

	SetGroupCollapsePadding(instance, pBuildingFooterInstance.Top:GetSizeY() );
	RealizeGroup( instance );

	-- ========== Unit Expenses ==========

	if GameCapabilities.HasCapability("CAPABILITY_REPORTS_UNIT_EXPENSES") then 
		instance = NewCollapsibleGroupInstance();
		instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_UNIT_EXPENSES") );

		-- Header
		local pHeader:table = {};
		ContextPtr:BuildInstanceForControl( "UnitExpensesHeaderInstance", pHeader, instance.ContentStack ) ;

		-- Units
		local iTotalUnitMaintenance:number = 0;
		for UnitType,kUnitData in pairs(m_kUnitData) do
			local pUnitInstance:table = {};
			ContextPtr:BuildInstanceForControl( "UnitExpensesEntryInstance", pUnitInstance, instance.ContentStack );
			pUnitInstance.UnitName:SetText(Locale.Lookup( kUnitData.Name ));
			pUnitInstance.UnitCount:SetText(kUnitData.Count);
			pUnitInstance.Gold:SetText("-" .. kUnitData.Maintenance);
			iTotalUnitMaintenance = iTotalUnitMaintenance + kUnitData.Maintenance;
		end

		-- Footer
		local pUnitFooterInstance:table = {};		
		ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pUnitFooterInstance, instance.ContentStack ) ;		
		pUnitFooterInstance.Gold:SetText("[ICON_Gold]-"..tostring(iTotalUnitMaintenance) );

		SetGroupCollapsePadding(instance, pUnitFooterInstance.Top:GetSizeY() );
		RealizeGroup( instance );
	end

	-- ========== Diplomatic Deals Expenses ==========
	
	if GameCapabilities.HasCapability("CAPABILITY_REPORTS_DIPLOMATIC_DEALS") then 
		instance = NewCollapsibleGroupInstance();	
		instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") );

		local pHeader:table = {};
		ContextPtr:BuildInstanceForControl( "DealHeaderInstance", pHeader, instance.ContentStack ) ;

		local iTotalDealGold :number = 0;
		for i,kDeal in ipairs(m_kDealData) do
			if kDeal.Type == DealItemTypes.GOLD then
				local pDealInstance:table = {};		
				ContextPtr:BuildInstanceForControl( "DealEntryInstance", pDealInstance, instance.ContentStack ) ;		

				pDealInstance.Civilization:SetText( kDeal.Name );
				pDealInstance.Duration:SetText( kDeal.Duration );
				if kDeal.IsOutgoing then
					pDealInstance.Gold:SetText( "-"..tostring(kDeal.Amount) );
					iTotalDealGold = iTotalDealGold - kDeal.Amount;
				else
					pDealInstance.Gold:SetText( "+"..tostring(kDeal.Amount) );
					iTotalDealGold = iTotalDealGold + kDeal.Amount;
				end
			end
		end
		local pDealFooterInstance:table = {};		
		ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pDealFooterInstance, instance.ContentStack ) ;		
		pDealFooterInstance.Gold:SetText("[ICON_Gold]"..tostring(iTotalDealGold) );

		SetGroupCollapsePadding(instance, pDealFooterInstance.Top:GetSizeY() );
		RealizeGroup( instance );
	end


	-- ========== TOTALS ==========

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	-- Totals at the bottom [Definitive values]
	local localPlayer = Players[Game.GetLocalPlayer()];
	--Gold
	local playerTreasury:table	= localPlayer:GetTreasury();
	Controls.GoldIncome:SetText( toPlusMinusNoneString( playerTreasury:GetGoldYield() ));
	Controls.GoldExpense:SetText( toPlusMinusNoneString( -playerTreasury:GetTotalMaintenance() ));	-- Flip that value!
	Controls.GoldNet:SetText( toPlusMinusNoneString( playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance() ));
	Controls.GoldBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.GOLD] );

	
	--Faith
	local playerReligion:table	= localPlayer:GetReligion();
	Controls.FaithIncome:SetText( toPlusMinusNoneString(playerReligion:GetFaithYield()));
	Controls.FaithNet:SetText( toPlusMinusNoneString(playerReligion:GetFaithYield()));
	Controls.FaithBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.FAITH] );

	--Science
	local playerTechnology:table	= localPlayer:GetTechs();
	Controls.ScienceIncome:SetText( toPlusMinusNoneString(playerTechnology:GetScienceYield()));
	Controls.ScienceBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.SCIENCE] );
	
	--Culture
	local playerCulture:table	= localPlayer:GetCulture();
	Controls.CultureIncome:SetText(toPlusMinusNoneString(playerCulture:GetCultureYield()));
	Controls.CultureBalance:SetText(m_kCityTotalData.Treasury[YieldTypes.CULTURE] );
	
	--Tourism. We don't talk about this one much.
	Controls.TourismIncome:SetText( toPlusMinusNoneString( m_kCityTotalData.Income["TOURISM"] ));	
	Controls.TourismBalance:SetText( m_kCityTotalData.Treasury["TOURISM"] );
	
	Controls.CollapseAll:SetHide(false);
	Controls.BottomYieldTotals:SetHide( false );
	Controls.BottomYieldTotals:SetSizeY( SIZE_HEIGHT_BOTTOM_YIELDS );
	Controls.BottomResourceTotals:SetHide( true );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomYieldTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );	
end

-- ===========================================================================
--	Allow for override.
-- ===========================================================================
function GetStrategicString( kSingleResourceData:table )
	return kSingleResourceData.Icon .. tostring( kSingleResourceData.Total );
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewResourcesPage()	

	m_CurrentReportTab = REPORT_PAGES.RESOURCES;
	ResetTabForNewPageContent();

	local strategicResources:string = "";
	local luxuryResources	:string = "";
	local kBonuses			:table	= {};
	local kLuxuries			:table	= {};
	local kStrategics		:table	= {};
	

	for eResourceType,kSingleResourceData in pairs(m_kResourceData) do

		if next(kSingleResourceData.EntryList) then
			local instance:table = NewCollapsibleGroupInstance();	

			local kResource :table = GameInfo.Resources[eResourceType];
			instance.RowHeaderButton:SetText(  kSingleResourceData.Icon..Locale.Lookup( kResource.Name ) );

			local pHeaderInstance:table = {};
			ContextPtr:BuildInstanceForControl( "ResourcesHeaderInstance", pHeaderInstance, instance.ContentStack ) ;

			local kResourceEntries:table = kSingleResourceData.EntryList;
			for i,kEntry in ipairs(kResourceEntries) do
				local pEntryInstance:table = {};
				ContextPtr:BuildInstanceForControl( "ResourcesEntryInstance", pEntryInstance, instance.ContentStack ) ;
				pEntryInstance.CityName:SetText( Locale.Lookup(kEntry.EntryText) );
				pEntryInstance.Control:SetText( Locale.Lookup(kEntry.ControlText) );
				pEntryInstance.Amount:SetText( (kEntry.Amount<=0) and tostring(kEntry.Amount) or "+"..tostring(kEntry.Amount) );
			end

			local pFooterInstance:table = {};
			ContextPtr:BuildInstanceForControl( "ResourcesFooterInstance", pFooterInstance, instance.ContentStack ) ;
			local valueString:string = tostring(kSingleResourceData.Total);
			if kSingleResourceData.IsStrategic then
				if kSingleResourceData.Total > 0 then
					valueString = "+" .. valueString;
				end
			end
			pFooterInstance.Amount:SetText( valueString );		

			-- Show how many of this resource are being allocated to what cities
			local localPlayerID = Game.GetLocalPlayer();
			local localPlayer = Players[localPlayerID];
			local citiesProvidedTo: table = localPlayer:GetResources():GetResourceAllocationCities(GameInfo.Resources[kResource.ResourceType].Index);
			local numCitiesProvidingTo: number = table.count(citiesProvidedTo);
			if (numCitiesProvidingTo > 0) then
				pFooterInstance.AmenitiesContainer:SetHide(false);
				pFooterInstance.Amenities:SetText("[ICON_Amenities][ICON_GoingTo]" .. Locale.Lookup("LOC_HUD_REPORTS_CITY_AMENITIES", numCitiesProvidingTo));
				local amenitiesTooltip: string = "";
				local playerCities = localPlayer:GetCities();
				for i,city in ipairs(citiesProvidedTo) do
					local cityName = Locale.Lookup(playerCities:FindID(city.CityID):GetName());
					if i ~=1 then
						amenitiesTooltip = amenitiesTooltip.. "[NEWLINE]";
					end
					amenitiesTooltip = amenitiesTooltip.. city.AllocationAmount.." [ICON_".. kResource.ResourceType.."] [Icon_GoingTo] " ..cityName;
				end
				pFooterInstance.Amenities:SetToolTipString(amenitiesTooltip);
			else
				pFooterInstance.AmenitiesContainer:SetHide(true);
			end

			SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
			RealizeGroup( instance );
		end

		if kSingleResourceData.IsStrategic then
			table.insert(kStrategics, GetStrategicString(kSingleResourceData) );
		elseif kSingleResourceData.IsLuxury then					
			table.insert(kLuxuries, kSingleResourceData.Icon .. tostring( kSingleResourceData.Total ) );
		else
			table.insert(kBonuses, kSingleResourceData.Icon .. tostring( kSingleResourceData.Total ) );
		end
	end
	
	m_strategicResourcesIM:ResetInstances();
	for i,v in ipairs(kStrategics) do
		local resourceInstance:table = m_strategicResourcesIM:GetInstance();	
		resourceInstance.Info:SetText( v );
	end
	Controls.StrategicResources:CalculateSize();

	m_bonusResourcesIM:ResetInstances();
	for i,v in ipairs(kBonuses) do
		local resourceInstance:table = m_bonusResourcesIM:GetInstance();	
		resourceInstance.Info:SetText( v );
	end
	Controls.BonusResources:CalculateSize();

	m_luxuryResourcesIM:ResetInstances();
	for i,v in ipairs(kLuxuries) do
		local resourceInstance:table = m_luxuryResourcesIM:GetInstance();	
		resourceInstance.Info:SetText( v );
	end
	
	Controls.LuxuryResources:CalculateSize();
	
	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	Controls.CollapseAll:SetHide(false);
	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( false );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomResourceTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );	
end

-- ===========================================================================
function AddGossipForTarget( targetID:number )
	local bHasGossip = false;

	local kAppendTable:table = Game.GetGossipManager():GetRecentVisibleGossipStrings(0, Game.GetLocalPlayer(), targetID);
	for _, entry in pairs(kAppendTable) do
		table.insert(m_kGossipLog, entry);
		bHasGossip = true;
	end

	return bHasGossip;
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewGossipPage()

	m_CurrentReportTab = REPORT_PAGES.GOSSIP;
	ResetTabForNewPageContent();

	local playerID:number = Game.GetLocalPlayer();
	if playerID == -1 then
		--Observer. No report.
		return;
	end

	--Get our Diplomacy
	local pLocalPlayerDiplomacy:table = Players[playerID]:GetDiplomacy();
	if pLocalPlayerDiplomacy == nil then
		--This is a significant error
		UI.DataError("Diplomacy is nil! Cannot display Gossip Report");
		return;
	end

	--We use simple instances to mask generic content. So we need to ensure there are no
	--leftover children from the last instance.
	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();

	-- Setup Filter Pulldown
	ContextPtr:BuildInstanceForControl("GossipFilterInstance", m_uiGossipFilterInstance, instance.Top);
	m_uiGossipFilterInstance.GroupFilter:RegisterSelectionCallback(function(i:number)
		local type:string = m_kGossipGroupTypes[i];
		m_uiGossipFilterInstance.GroupFilter:GetButton():SetText(Locale.Lookup("LOC_HUD_REPORTS_FILTER_" .. type));
		m_groupFilter = type;
		RefreshGossip();
	end);
	m_uiGossipFilterInstance.GroupFilter:GetButton():SetText(Locale.Lookup("LOC_HUD_REPORTS_FILTER_ALL"));

	ContextPtr:BuildInstanceForControl("GossipPageInstance", m_uiPaginationInstance, instance.Top);

	local pHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "GossipHeaderInstance", pHeaderInstance, instance.Top );	

	--Make our 'All' Filter for players
	local uiAllFilter:table = {};
	m_uiGossipFilterInstance.PlayerFilter:BuildEntry("InstanceOne", uiAllFilter);
	uiAllFilter.LeaderIcon.Portrait:SetIcon("ICON_LEADER_ALL");
	uiAllFilter.LeaderIcon.Portrait:SetHide(false);
	uiAllFilter.LeaderIcon.TeamRibbon:SetHide(true);
	uiAllFilter.Button:SetText(Locale.Lookup("LOC_HUD_REPORTS_PLAYER_FILTER_ALL"));
	uiAllFilter.Button:SetVoid1(-1);
	uiAllFilter.Button:SetSizeX(252);


	--Populate with all of our Gossip and build Player Filter
	m_kGossipLog = {};

	local kAliveLeaders:table = PlayerManager.GetAliveMajorIDs();
	for targetID, kPlayer in pairs(Players) do
		--If we are not ourselves, are a major civ, and we have met these people
		if targetID ~= playerID and kPlayer:IsMajor() and pLocalPlayerDiplomacy:HasMet(targetID) then
			--Append their gossip
			local bHasGossip:boolean = AddGossipForTarget(targetID);

			--If we had gossip, add them as a filter
			if bHasGossip then
				local uiFilter:table = {};
				m_uiGossipFilterInstance.PlayerFilter:BuildEntry("InstanceOne", uiFilter);

				local leaderName:string = PlayerConfigurations[targetID]:GetLeaderTypeName();
				local iconName:string = "ICON_" .. leaderName;
				--Build and update
				local filterLeaderIcon:table = LeaderIcon:AttachInstance(uiFilter.LeaderIcon);
				filterLeaderIcon:UpdateIcon(iconName, targetID, true);
				uiFilter.Button:SetText(Locale.Lookup(PlayerConfigurations[targetID]:GetLeaderName()));
				uiFilter.Button:SetVoid1(targetID);
				uiFilter.Button:SetSizeX(252);

				if(not kPlayer:IsAlive())then
					uiFilter.LeaderIcon.Portrait:SetAlpha(0.25);
					uiFilter.LeaderIcon.Relationship:SetHide(true);
					local leaderTooltip:string = uiFilter.LeaderIcon.Portrait:GetToolTipString();
					leaderTooltip = leaderTooltip.."[NEWLINE]"..Locale.Lookup("LOC_DEFEATED_SUBHEADER");
					uiFilter.LeaderIcon.Portrait:SetToolTipString(leaderTooltip);
				end
			end
		end
	end

	m_uiGossipFilterInstance.PlayerFilter:RegisterSelectionCallback(function(i:number)
		if i == -1 then
			m_uiGossipFilterInstance.LeaderIcon.Portrait:SetIcon("ICON_LEADER_ALL");
			m_uiGossipFilterInstance.LeaderIcon.Portrait:SetHide(false);
			m_uiGossipFilterInstance.LeaderIcon.TeamRibbon:SetHide(true);
			m_uiGossipFilterInstance.LeaderIcon.Relationship:SetHide(true);
			m_uiGossipFilterInstance.PlayerFilter:GetButton():SetText(Locale.Lookup("LOC_HUD_REPORTS_PLAYER_FILTER_ALL"));
			m_uiGossipFilterInstance.LeaderIcon.Portrait:SetAlpha(1);
			m_uiGossipFilterInstance.LeaderIcon.Portrait:SetToolTipString("");
		else
			local leaderName:string = PlayerConfigurations[i]:GetLeaderTypeName();
			local iconName:string = "ICON_" .. leaderName;
			--Build and update
			local filterLeaderIcon:table = LeaderIcon:AttachInstance(m_uiGossipFilterInstance.LeaderIcon);
			filterLeaderIcon:UpdateIcon(iconName, i, true);
			m_uiGossipFilterInstance.PlayerFilter:GetButton():SetText(Locale.Lookup(PlayerConfigurations[i]:GetLeaderName()));

			local leaderIsAlive:boolean = false;
			for k, v in pairs(kAliveLeaders) do
				if(i == v) then
					leaderIsAlive = true;
				end
			end

			if(not leaderIsAlive) then
				local leaderTooltip:string = m_uiGossipFilterInstance.LeaderIcon.Portrait:GetToolTipString();
				leaderTooltip = leaderTooltip.."[NEWLINE]"..Locale.Lookup("LOC_DEFEATED_SUBHEADER");
				m_uiGossipFilterInstance.LeaderIcon.Portrait:SetToolTipString(leaderTooltip);
				m_uiGossipFilterInstance.LeaderIcon.Portrait:SetAlpha(0.25);
				m_uiGossipFilterInstance.LeaderIcon.Relationship:SetHide(true);
			else
				m_uiGossipFilterInstance.LeaderIcon.Portrait:SetAlpha(1);
				m_uiGossipFilterInstance.LeaderIcon.Relationship:SetHide(false);
			end
		end

		m_leaderFilter = i;
		RefreshGossip();
	end);

	m_uiGossipFilterInstance.LeaderIcon.Portrait:SetIcon("ICON_LEADER_ALL");
	m_uiGossipFilterInstance.LeaderIcon.Portrait:SetHide(false);
	m_uiGossipFilterInstance.LeaderIcon.TeamRibbon:SetHide(true);
	m_uiGossipFilterInstance.LeaderIcon.Relationship:SetHide(true);
	m_uiGossipFilterInstance.PlayerFilter:GetButton():SetText(Locale.Lookup("LOC_HUD_REPORTS_PLAYER_FILTER_ALL"));

	m_CountPerPage = math.floor((Controls.Main:GetSizeY() - GOSSIP_HEADER_SIZE) / GOSSIP_ENTRY_CONSTANT);

	--Refresh our sizes
	m_uiGossipFilterInstance.PlayerFilter:CalculateInternals();

	-- Create blank gossip instances to be filled in later
	for i=1, m_CountPerPage, 1 do
		local pGossipInstance:table = {}
		ContextPtr:BuildInstanceForControl( "GossipEntryInstance", pGossipInstance, instance.Top ) ;
		table.insert(m_kGossipInstances, pGossipInstance);
	end

	table.sort(m_kGossipLog, function(a, b) return a[2] > b[2]; end);

	RefreshGossip();

	Controls.CollapseAll:SetHide(true);
	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( true );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 92);
end

-- ===========================================================================
function RefreshGossip()
	m_kGossipLogFiltered = FilterGossip(m_kGossipLog);
	
	m_MaxPages = math.ceil(table.count(m_kGossipLogFiltered) / m_CountPerPage);
	m_CurrentGossipPage = 1;

	UpdatePageInstance();

	-- Only show gossip filters for types currently being shown
	m_uiGossipFilterInstance.GroupFilter:ClearEntries();
	for i, type in pairs(m_kGossipGroupTypes) do
		if type == GOSSIP_FILTER_ALL or m_kGossipFiltersToShow[type] then
			local uiFilter:table = {};
			m_uiGossipFilterInstance.GroupFilter:BuildEntry("InstanceOne", uiFilter);
			uiFilter.Button:SetText(Locale.Lookup("LOC_HUD_REPORTS_FILTER_" .. type));
			uiFilter.Button:SetVoid1(i);
			uiFilter.Button:SetSizeX(252);
		end
	end
	m_uiGossipFilterInstance.GroupFilter:CalculateInternals();

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();
end

-- ===========================================================================
--	Navigation Callback for Gossip Report
-- ===========================================================================
function NavCallback(page:number)
	m_CurrentGossipPage = page;
	UpdatePageInstance();
end

-- ===========================================================================
--	Pagination Widget
-- ===========================================================================
function UpdatePageInstance()
	--If we are low enough, we do not need jump to on the left
	m_uiPaginationInstance.LeftJumpStack:SetHide( m_CurrentGossipPage < 4 );
	m_uiPaginationInstance.FirstButton:SetVoid1( 1 );
	m_uiPaginationInstance.FirstButton:RegisterCallback( Mouse.eLClick, NavCallback );
	m_uiPaginationInstance.FirstButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	--Same for the right, but for max pages
	m_uiPaginationInstance.RightJumpStack:SetHide( (m_MaxPages - m_CurrentGossipPage) < 3 );
	m_uiPaginationInstance.LastButton:SetVoid1( m_MaxPages );
	m_uiPaginationInstance.LastButton:RegisterCallback( Mouse.eLClick, NavCallback );
	m_uiPaginationInstance.LastButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	m_uiPaginationInstance.LastButton:SetText(m_MaxPages);


	--Set up our main nav buttons
	if m_CurrentGossipPage - 2 > 0 then
		m_uiPaginationInstance.Button1:SetHide(false);
		m_uiPaginationInstance.Button1:SetText(m_CurrentGossipPage - 2);
		m_uiPaginationInstance.Button1:SetVoid1(m_CurrentGossipPage - 2);
		m_uiPaginationInstance.Button1:RegisterCallback(Mouse.eLClick, NavCallback);
		m_uiPaginationInstance.Button1:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	else
		m_uiPaginationInstance.Button1:SetHide(true);
	end

	if m_CurrentGossipPage - 1 > 0 then
		m_uiPaginationInstance.Button2:SetHide(false);
		m_uiPaginationInstance.Button2:SetText(m_CurrentGossipPage - 1);
		m_uiPaginationInstance.Button2:SetVoid1(m_CurrentGossipPage - 1);
		m_uiPaginationInstance.Button2:RegisterCallback(Mouse.eLClick, NavCallback);
		m_uiPaginationInstance.Button2:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	else
		m_uiPaginationInstance.Button2:SetHide(true);
	end

	if m_CurrentGossipPage > 0 then
		m_uiPaginationInstance.Button3:SetHide(false);
		m_uiPaginationInstance.Button3:SetSelected(true);
		m_uiPaginationInstance.Button3:SetText(m_CurrentGossipPage);
		m_uiPaginationInstance.Button3:SetVoid1(m_CurrentGossipPage);
		m_uiPaginationInstance.Button3:RegisterCallback(Mouse.eLClick, NavCallback);
		m_uiPaginationInstance.Button3:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	else
		--This is a fail case
		UI.DataError("Current Page is 0! Gossip Reports, UpdatePageInstance.");
	end

	if m_CurrentGossipPage + 1 <= m_MaxPages then
		m_uiPaginationInstance.Button4:SetHide(false);
		m_uiPaginationInstance.Button4:SetText(m_CurrentGossipPage + 1);
		m_uiPaginationInstance.Button4:SetVoid1(m_CurrentGossipPage + 1);
		m_uiPaginationInstance.Button4:RegisterCallback(Mouse.eLClick, NavCallback);
		m_uiPaginationInstance.Button4:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	else
		m_uiPaginationInstance.Button4:SetHide(true);
	end

	if m_CurrentGossipPage + 2 <= m_MaxPages then
		m_uiPaginationInstance.Button5:SetHide(false);
		m_uiPaginationInstance.Button5:SetText(m_CurrentGossipPage + 2);
		m_uiPaginationInstance.Button5:SetVoid1(m_CurrentGossipPage + 2);
		m_uiPaginationInstance.Button5:RegisterCallback(Mouse.eLClick, NavCallback);
		m_uiPaginationInstance.Button5:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	else
		m_uiPaginationInstance.Button5:SetHide(true);
	end

	--Set up our static buttons
	m_uiPaginationInstance.LeftArrow:SetDisabled(m_CurrentGossipPage == 1);
	m_uiPaginationInstance.LeftArrow:SetVoid1(m_CurrentGossipPage - 1);
	m_uiPaginationInstance.LeftArrow:RegisterCallback(Mouse.eLClick, NavCallback);
	m_uiPaginationInstance.LeftArrow:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	m_uiPaginationInstance.RightArrow:SetDisabled(m_CurrentGossipPage >= m_MaxPages);
	m_uiPaginationInstance.RightArrow:SetVoid1(m_CurrentGossipPage + 1);
	m_uiPaginationInstance.RightArrow:RegisterCallback(Mouse.eLClick, NavCallback);
	m_uiPaginationInstance.RightArrow:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	local kAliveLeaders:table = PlayerManager.GetAliveMajorIDs();
	local kGroupFiltersToShow:table = {};
	for i=1, m_CountPerPage, 1 do
		local pageIndex:number = i + ((m_CurrentGossipPage - 1) * m_CountPerPage);
		if pageIndex <= table.count(m_kGossipLogFiltered) then
			local kGossipEntry:table = m_kGossipLogFiltered[pageIndex];
			local leaderName:string = PlayerConfigurations[kGossipEntry[4]]:GetLeaderTypeName();
			local iconName:string = "ICON_" .. leaderName;
			local pGossipInstance:table = m_kGossipInstances[i];

			pGossipInstance.Top:SetHide(false);

			local kGossipData:table = GameInfo.Gossips[kGossipEntry[3]];
			
			--Build and update
			local gossipLeaderIcon:table = LeaderIcon:AttachInstance(pGossipInstance.Leader);
			gossipLeaderIcon:UpdateIcon(iconName, kGossipEntry[4], true);
			
			pGossipInstance.Date:SetText(kGossipEntry[2]);
			pGossipInstance.Icon:SetIcon("ICON_GOSSIP_" .. kGossipData.GroupType);
			pGossipInstance.Description:SetText(kGossipEntry[1]);

			local leaderIsAlive:boolean = false;
			for k, v in pairs(kAliveLeaders) do
				if(kGossipEntry[4] == v) then
					leaderIsAlive = true;
				end
			end

			if(not leaderIsAlive) then
				pGossipInstance.Leader.Portrait:SetAlpha(0.25);
				pGossipInstance.Leader.Relationship:SetHide(true);
				local leaderTooltip:string = pGossipInstance.Leader.Portrait:GetToolTipString();
				leaderTooltip = leaderTooltip.."[NEWLINE]"..Locale.Lookup("LOC_DEFEATED_SUBHEADER");
				pGossipInstance.Leader.Portrait:SetToolTipString(leaderTooltip);
			else
				pGossipInstance.Leader.Portrait:SetAlpha(1);
				pGossipInstance.Leader.Relationship:SetHide(false);
			end

		else
			if i <= table.count(m_kGossipInstances) then
				m_kGossipInstances[i].Top:SetHide(true);
			end
		end
	end
end

-- ===========================================================================
--	Filter Callbacks
-- ===========================================================================
function FilterGossip( kGossip:table )
	local kFilteredGossip:table = {};

	m_kGossipFiltersToShow = {};

	local gossipGroupType:string = m_groupFilter;
	for i, kEntry in ipairs(kGossip) do
		local kGossipData:table = GameInfo.Gossips[kEntry[3]];
		if (m_leaderFilter == -1 or kEntry[4] == m_leaderFilter) and (m_groupFilter == GOSSIP_FILTER_ALL or gossipGroupType == kGossipData.GroupType) then
			table.insert(kFilteredGossip, kEntry);
			m_kGossipFiltersToShow[kGossipData.GroupType] = true;
		end
	end

	return kFilteredGossip;
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewCityStatusPage()	

	m_CurrentReportTab = REPORT_PAGES.CITY_STATUS;
	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	local pHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityStatusHeaderInstance", pHeaderInstance, instance.Top ) ;

	for i,kCityData in ipairs(m_kCityData) do
		CreateCityStatusInstance(instance, kCityData);
	end

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	Controls.CollapseAll:SetHide(true);
	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( true );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88);
end

-- ===========================================================================
function CreateCityStatusInstance( kParentInstance:table, kCityData:table )
	local cityName :string = kCityData.CityName;
	local pCityInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityStatusEntryInstance", pCityInstance, kParentInstance.Top ) ;	
	TruncateStringWithTooltip(pCityInstance.CityName, 130, Locale.Lookup(kCityData.CityName)); 
	pCityInstance.Population:SetText( tostring(kCityData.Population) );

	if kCityData.HousingMultiplier == 0 or kCityData.Occupied then
		status = "LOC_HUD_REPORTS_STATUS_HALTED";
	elseif kCityData.HousingMultiplier <= 0.5 then
		status = "LOC_HUD_REPORTS_STATUS_SLOWED";
	else
		if kCityData.HappinessGrowthModifier > 0 then
			status = "LOC_HUD_REPORTS_STATUS_ACCELERATED";
		else
			status = "LOC_HUD_REPORTS_STATUS_NORMAL";
		end
	end
	pCityInstance.GrowthRateStatus:SetText( Locale.Lookup(status) );

	pCityInstance.Housing:SetText( tostring(kCityData.Housing) );
	pCityInstance.Amenities:SetText( tostring(kCityData.AmenitiesNum).." / "..tostring(kCityData.AmenitiesRequiredNum) );

	local happinessText:string = Locale.Lookup( GameInfo.Happinesses[kCityData.Happiness].Name );
	pCityInstance.CitizenHappiness:SetText( happinessText );

	local warWearyValue:number = kCityData.AmenitiesLostFromWarWeariness;
	pCityInstance.WarWeariness:SetText( (warWearyValue==0) and "0" or "-"..tostring(warWearyValue) );

	local statusText:string = kCityData.IsUnderSiege and Locale.Lookup("LOC_HUD_REPORTS_STATUS_UNDER_SEIGE") or Locale.Lookup("LOC_HUD_REPORTS_STATUS_NORMAL");
	TruncateStringWithTooltip(pCityInstance.Status, 80, statusText); 

	pCityInstance.Strength:SetText( tostring(kCityData.Defense) );
	pCityInstance.Damage:SetText( tostring(kCityData.Damage) );
end

-- ===========================================================================
--
-- ===========================================================================
function AddTabSection( name:string, populateCallback:ifunction )
	local kTab		:table				= m_tabIM:GetInstance();	
	kTab.Button[DATA_FIELD_SELECTION]	= kTab.Selection;

	local callback	:ifunction	= function()
		if m_kTabs.prevSelectedControl ~= nil then
			m_kTabs.prevSelectedControl[DATA_FIELD_SELECTION]:SetHide(true);
		end
		kTab.Selection:SetHide(false);
		populateCallback();
	end

	kTab.Button:GetTextControl():SetText( Locale.Lookup(name) );
	kTab.Button:SetSizeToText( 40, 20 );
    kTab.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	m_kTabs.AddTab( kTab.Button, callback );
end


-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		local uiKey = pInputStruct:GetKey();
		if uiKey == Keys.VK_ESCAPE then
			if ContextPtr:IsHidden()==false then
				Close();
				return true;
			end
		end		
	end
	return false;
end


-- ===========================================================================
function Resize()
	local topPanelSizeY:number = 30;

	x,y = UIManager:GetScreenSizeVal();
	Controls.Main:SetSizeY( y - topPanelSizeY );
	Controls.Main:SetOffsetY( topPanelSizeY * 0.5 );
end

-- ===========================================================================
--	Game Event Callback
-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		OnCloseButton();
	end
end

-- ===========================================================================
function LateInitialize()

	RefreshGroupTypes();

	m_kTabs = CreateTabs( Controls.TabContainer, 42, 34, UI.GetColorValueFromHexLiteral(0xFF331D05) );
	--AddTabSection( "Test",								ViewTestPage );			--TRONSTER debug
	--AddTabSection( "Test2",								ViewTestPage );			--TRONSTER debug
	AddTabSection( "LOC_HUD_REPORTS_TAB_YIELDS",		ViewYieldsPage );
	AddTabSection( "LOC_HUD_REPORTS_TAB_RESOURCES",		ViewResourcesPage );
	AddTabSection( "LOC_HUD_REPORTS_TAB_CITY_STATUS",	ViewCityStatusPage );
	if GameCapabilities.HasCapability("CAPABILITY_GOSSIP_REPORT") then
		AddTabSection( "LOC_HUD_REPORTS_TAB_GOSSIP",		ViewGossipPage );
	end

	m_kTabs.SameSizedTabs(50);
	m_kTabs.CenterAlignTabs(-10);
	
	m_kTabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow);	
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();
	if isReload then	
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);	
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "currentReportTab", m_CurrentReportTab );

	-- Unregister Events
	LuaEvents.GameDebug_Return.Remove(OnGameDebugReturn);
	LuaEvents.TopPanel_OpenReportsScreen.Remove( OnTopOpenReportsScreen );
	LuaEvents.TopPanel_CloseReportsScreen.Remove( OnTopCloseReportsScreen );
	LuaEvents.ReportsList_OpenCityStatus.Remove( OnOpenCityStatus );
	LuaEvents.ReportsList_OpenResources.Remove( OnOpenResources );
	LuaEvents.ReportsList_OpenYields.Remove( OnTopOpenReportsScreen );
	if GameCapabilities.HasCapability("CAPABILITY_GOSSIP_REPORT") then
		LuaEvents.ReportsList_OpenGossip.Remove( OnOpenGossip );
	end

	Events.LocalPlayerTurnEnd.Remove( OnLocalPlayerTurnEnd );
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if not ContextPtr:IsHidden() and contextTable["currentReportTab"] ~= nil then			
			Open(contextTable["currentReportTab"]);
		end
	end
end

-- ===========================================================================
function RefreshGroupTypes()
	-- Skip if we've already cached group types
	if table.count(m_kGossipGroupTypes) > 0 then
		return;
	end

	-- Use type keyed table to prevent duplicate groups
	local kTypeKeyed:table = {};
	for row in GameInfo.Gossips() do
		if row.GroupType ~= nil and kTypeKeyed[row.GroupType] == nil then
			kTypeKeyed[row.GroupType] = true;
		end
	end

	-- Move types to index keyed table
	for type,_ in pairs(kTypeKeyed) do
		table.insert(m_kGossipGroupTypes, type);
	end

	-- Alphabetize
	table.sort(m_kGossipGroupTypes, function(a, b) return a < b; end);

	-- Add "ALL" option to the front of the filter types
	table.insert(m_kGossipGroupTypes, 1, GOSSIP_FILTER_ALL);
end

-- ===========================================================================
function Initialize()

	-- Context Callbacks
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );

	-- UI Callbacks
	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnCloseButton );
	Controls.CloseButton:RegisterCallback(	Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CollapseAll:RegisterCallback( Mouse.eLClick, OnCollapseAllButton );
	Controls.CollapseAll:RegisterCallback(	Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	
	-- Events
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.TopPanel_OpenReportsScreen.Add( OnTopOpenReportsScreen );
	LuaEvents.TopPanel_CloseReportsScreen.Add( OnTopCloseReportsScreen );
	LuaEvents.ReportsList_OpenCityStatus.Add( OnOpenCityStatus );
	LuaEvents.ReportsList_OpenResources.Add( OnOpenResources );
	LuaEvents.ReportsList_OpenYields.Add( OnTopOpenReportsScreen );
	if GameCapabilities.HasCapability("CAPABILITY_GOSSIP_REPORT") then
		LuaEvents.ReportsList_OpenGossip.Add( OnOpenGossip );
	end

	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
end
Initialize();
