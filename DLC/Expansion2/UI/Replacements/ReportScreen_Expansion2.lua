-- Copyright 2017-2018, 2017 Firaxis Games
include("ReportScreen_Expansion1");

-- ===========================================================================
-- Constants
-- ===========================================================================
local SIZE_HEIGHT_PADDING_BOTTOM_ADJUST			:number = 85;	-- (Total Y - (scroll area + THIS PADDING)) = bottom area


-- ===========================================================================
-- Override base game
-- ===========================================================================
function AppendXP2ResourceData(kResourceData:table)
	local playerID:number = Game.GetLocalPlayer();
	if playerID == PlayerTypes.NONE then
		UI.DataError("Unable to get valid playerID for ReportScreen_Expansion2.");
		return;
	end

	local player:table  = Players[playerID];

	local pResources:table	= player:GetResources();
	if pResources then
		for row in GameInfo.Resources() do
			local resourceHash:number = row.Hash;
			local resourceUnitCostPerTurn:number = pResources:GetUnitResourceDemandPerTurn(resourceHash);
			local resourcePowerCostPerTurn:number = pResources:GetPowerResourceDemandPerTurn(resourceHash);
			local reservedCostForProduction:number = pResources:GetReservedResourceAmount(resourceHash);
			local miscResourceTotal:number = pResources:GetResourceAmount(resourceHash);
			local importResources:number = pResources:GetResourceImportPerTurn(resourceHash);
			
			if resourceUnitCostPerTurn > 0 then
				AddResourceData(kResourceData, row.Index, "LOC_PRODUCTION_PANEL_UNITS_TOOLTIP", "-", -resourceUnitCostPerTurn);
			end

			if resourcePowerCostPerTurn > 0 then
				AddResourceData(kResourceData, row.Index, "LOC_UI_PEDIA_POWER_COST", "-", -resourcePowerCostPerTurn);
			end

			if reservedCostForProduction > 0 then
				AddResourceData(kResourceData, row.Index, "LOC_RESOURCE_REPORTS_ITEM_IN_RESERVE", "-", -reservedCostForProduction);
			end

			if kResourceData[row.Index] == nil and miscResourceTotal > 0 then
				local titleString:string = importResources > 0 and "LOC_RESOURCE_REPORTS_CITY_STATES" or "LOC_HUD_REPORTS_MISC_RESOURCE_SOURCE";
				AddResourceData(kResourceData, row.Index, titleString, "-", miscResourceTotal);
			elseif importResources > 0 then
				AddResourceData(kResourceData, row.Index, "LOC_RESOURCE_REPORTS_CITY_STATES", "-", importResources);
			end

		end
	end

	return kResourceData;
end

function AddResourceData( kResources:table, eResourceType:number, EntryString:string, ControlString:string, InAmount:number)
	local kResource :table = GameInfo.Resources[eResourceType];

	--Artifacts need to be excluded because while TECHNICALLY a resource, they do nothing to contribute in a way that is relevant to any other resource 
	--or screen. So... exclusion.
	if kResource.ResourceClassType == "RESOURCECLASS_ARTIFACT" then
		return;
	end

	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = Players[localPlayerID];
	if localPlayer then
		local pPlayerResources:table	=  localPlayer:GetResources();
		if pPlayerResources then
			if kResources[eResourceType] == nil then
				kResources[eResourceType] = {
					EntryList	= {},
					Icon		= "[ICON_"..kResource.ResourceType.."]",
					IsStrategic	= kResource.ResourceClassType == "RESOURCECLASS_STRATEGIC",
					IsLuxury	= GameInfo.Resources[eResourceType].ResourceClassType == "RESOURCECLASS_LUXURY",
					IsBonus		= GameInfo.Resources[eResourceType].ResourceClassType == "RESOURCECLASS_BONUS",
					Total		= 0,
					Maximum		= pPlayerResources:GetResourceStockpileCap(eResourceType),
					Stockpile   = pPlayerResources:GetResourceAmount(eResourceType)
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
	end
end

function AddMiscResourceData(pResourceData:table, kResourceTable:table)
	--Append our resource entries before we continue
	kResourceTable = AppendXP2ResourceData(kResourceTable);

	-- Resources not yet accounted for come from other gameplay bonuses
	if pResourceData then
		for row in GameInfo.Resources() do
			local internalResourceAmount:number = pResourceData:GetResourceAmount(row.Index);
			local resourceUnitConsumptionPerTurn:number = -pResourceData:GetUnitResourceDemandPerTurn(row.ResourceType);
			local resourcePowerConsumptionPerTurn:number = -pResourceData:GetPowerResourceDemandPerTurn(row.ResourceType);
			local resourceAccumulationPerTurn:number = pResourceData:GetResourceAccumulationPerTurn(row.ResourceType);
			local resourceDelta:number = resourceUnitConsumptionPerTurn + resourcePowerConsumptionPerTurn + resourceAccumulationPerTurn;
			if (row.ResourceClassType == "RESOURCECLASS_STRATEGIC") then
				internalResourceAmount = resourceDelta;
			end
			if (internalResourceAmount > 0 or internalResourceAmount < 0) then
				if (kResourceTable[row.Index] ~= nil) then
					if (internalResourceAmount > kResourceTable[row.Index].Total) then
						AddResourceData(kResourceTable, row.Index, "LOC_HUD_REPORTS_MISC_RESOURCE_SOURCE", "-", internalResourceAmount - kResourceTable[row.Index].Total);
					end
				else
					AddResourceData(kResourceTable, row.Index, "LOC_HUD_REPORTS_MISC_RESOURCE_SOURCE", "-", internalResourceAmount);
				end
			end

			--Stockpile only?
			if pResourceData:GetResourceAmount(row.ResourceType) > 0 then
				AddResourceData(kResourceTable, row.Index, "", "", 0);
			end

		end
	end

	return kResourceTable;
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewResourcesPage()	

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
			table.insert(kStrategics, kSingleResourceData.Icon .. " " .. tostring( kSingleResourceData.Stockpile ) .. "/" .. tostring(kSingleResourceData.Maximum));
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
	Controls.StrategicGrid:ReprocessAnchoring();

	m_bonusResourcesIM:ResetInstances();
	for i,v in ipairs(kBonuses) do
		local resourceInstance:table = m_bonusResourcesIM:GetInstance();	
		resourceInstance.Info:SetText( v );
	end
	Controls.BonusResources:CalculateSize();
	Controls.BonusGrid:ReprocessAnchoring();

	m_luxuryResourcesIM:ResetInstances();
	for i,v in ipairs(kLuxuries) do
		local resourceInstance:table = m_luxuryResourcesIM:GetInstance();	
		resourceInstance.Info:SetText( v );
	end
	
	Controls.LuxuryResources:CalculateSize();
	Controls.LuxuryResources:ReprocessAnchoring();
	Controls.LuxuryGrid:ReprocessAnchoring();
	
	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	Controls.CollapseAll:SetHide(false);
	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( false );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomResourceTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );	
end

-- ===========================================================================
function GetCityResourceData( pCity:table )
	-- Loop through all the plots for a given city; tallying the resource amount.
	local kResources : table = {};
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = Players[localPlayerID];
	if localPlayer then
		local pPlayerResources:table = localPlayer:GetResources();
		if pPlayerResources then
			local kExtractedResources = pPlayerResources:GetResourcesExtractedByCity( pCity:GetID(), ResultFormat.SUMMARY );
			if kExtractedResources ~= nil and table.count(kExtractedResources) > 0 then
				for i, entry in ipairs(kExtractedResources) do
					if entry.Amount > 0 then
						kResources[entry.ResourceType] = entry.Amount;
					end
				end
			end
		end
	end
	return kResources;
end
