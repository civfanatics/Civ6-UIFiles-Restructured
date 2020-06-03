-- Copyright 2017-2019, Firaxis Games
include("ReportScreen_Expansion1");

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_AddResourceData = AddResourceData;

-- ===========================================================================
--	CONSTANTS
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

-- ===========================================================================
--	OVERLOAD
--	Append XP2 maximum and stockpile values to table.
-- ===========================================================================
function AddResourceData( kResources:table, eResourceType:number, EntryString:string, ControlString:string, InAmount:number)
	
	BASE_AddResourceData( kResources, eResourceType, EntryString, ControlString, InAmount);
	if kResources[eResourceType] == nil then
		return;
	end

	local localPlayerID = Game.GetLocalPlayer();
	if localPlayerID == -1 or localPlayerID == 1000 then return; end	-- Observer

	local localPlayer = Players[localPlayerID];
	if localPlayer == nil then
		UI.DataError("Report was unable to obtain local player #"..tostring(localPlayerID));
		return;
	end
	
	-- Add additional XP2 values.
	local pPlayerResources:table =  localPlayer:GetResources();
	kResources[eResourceType].Maximum	= pPlayerResources:GetResourceStockpileCap(eResourceType);
	kResources[eResourceType].Stockpile	= pPlayerResources:GetResourceAmount(eResourceType)
end

-- ===========================================================================
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
--	OVERRIDE
--	Used to show stockpile information in the resources report.
-- ===========================================================================
function GetStrategicString( kSingleResourceData:table )
	return kSingleResourceData.Icon 
		.. " " 
		.. tostring( kSingleResourceData.Stockpile ) 
		.. "/" 
		.. tostring( kSingleResourceData.Maximum );
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
