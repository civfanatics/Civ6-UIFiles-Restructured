-- ===========================================================================
include( "CitySupport" );

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

MAX_QUEUE_SIZE = 7;

FIELD_CITY_ID		= "cityID";
FIELD_QUEUE_INDEX	= "queueIndex";
FIELD_ICON_TEXTURE	= "iconTexture";

SELECTED_ICON_ALPHA	= 0.2;

-- ===========================================================================
function RefreshCurrentProduction( parentControl:table, playerID:number, cityID:number )
	local pPlayer:table = Players[playerID];

	local pCity:table = pPlayer:GetCities():FindID(cityID);
	if pCity == nil then
		return false;
	end

	local pBuildQueue:table = pCity:GetBuildQueue();
	local productionHash:number = 0;

	local currentProductionHash = pBuildQueue:GetCurrentProductionTypeHash();
	local previousProductionHash = pBuildQueue:GetPreviousProductionTypeHash();

	if( currentProductionHash == 0 and previousProductionHash == 0 ) then
		-- If we have no current or previous production return false
		return false;
	else
		if( currentProductionHash == 0 ) then
			productionHash = previousProductionHash;
			parentControl.CompletedArea:SetHide(false);
			parentControl.CurrentProductionStatus:SetText(Locale.ToUpper("LOC_TECH_KEY_COMPLETED"));
		else
			productionHash = currentProductionHash;
			parentControl.CompletedArea:SetHide(true);
			parentControl.CurrentProductionStatus:SetText("");
		end
	end

	local currentProductionInfo:table = GetProductionInfoOfCity( pCity, productionHash );
	
	if (currentProductionInfo.Icons ~= nil) then
		parentControl.CurrentProductionName:SetText(Locale.Lookup(currentProductionInfo.Name));

		parentControl.CurrentProductionProgress:SetPercent(math.max(currentProductionInfo.PercentComplete, 0));
		parentControl.CurrentProductionProgress:SetShadowPercent(math.max(currentProductionInfo.PercentCompleteNextTurn, 0));
		
		for _,iconName in ipairs(currentProductionInfo.Icons) do
		    if iconName ~= nil and parentControl.ProductionIcon:TrySetIcon(iconName) then
		        parentControl[FIELD_ICON_TEXTURE] = iconName;
		        break;
            end
	    end

		parentControl[FIELD_CITY_ID] = cityID;
		parentControl[FIELD_QUEUE_INDEX] = 0;

		if(currentProductionInfo.Tooltip ~= nil) then
			parentControl.ProductionIcon:SetToolTipString(Locale.Lookup(currentProductionInfo.Tooltip));
		else
			parentControl.ProductionIcon:SetToolTipString();
		end

		local numberOfTurns = currentProductionInfo.Turns;
		if numberOfTurns == -1 then
			numberOfTurns = "999+";
		end;

		parentControl.CurrentProductionCost:SetText("[ICON_Turn]".. numberOfTurns);
		parentControl.CurrentProductionProgressString:SetText("[ICON_Production]"..currentProductionInfo.Progress.." / "..currentProductionInfo.Cost);
	end

	return true;
end

-- ===========================================================================
function CreateQueueInstance( instanceManager:table, parentControl:table, playerID:number, cityID:number, queueIndex:number, queueEntry:table )
	local queueItemInstance:table = instanceManager:GetInstance( parentControl );

	-- SetSelected can override SetDisabled so must be done before hand
	queueItemInstance.Top:SetSelected(false);
	
	-- Hide Corps/Army icons which are only shown when necessary
	queueItemInstance.CorpsMarker:SetHide(true);
	queueItemInstance.ArmyMarker:SetHide(true);

	if queueEntry then
		local kPossibleIcons:table = {};
		local iconTexture:string = "";
		local iconTooltip:string = "";

		if queueEntry.Directive == CityProductionDirectives.TRAIN then
			-- Training a unit, valid table values are
			-- entry.UnitType
			-- entry.MilitaryFormationType
			local pUnitDef:table = GameInfo.Units[queueEntry.UnitType];

			local iconName, prefixOnlyIconName, eraOnlyIconName, fallbackIconName = GetUnitPortraitIconNamesFromDefinition( playerID, pUnitDef );
			kPossibleIcons = {iconName, prefixOnlyIconName, eraOnlyIconName, fallbackIconName};

			local unitName:string = Locale.Lookup(pUnitDef.Name);
			if (queueEntry.MilitaryFormationType == MilitaryFormationTypes.CORPS_FORMATION) then
				if (pUnitDef.Domain == "DOMAIN_SEA") then
					unitName = unitName .. " " .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
				else
					unitName = unitName .. " " .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
				end
				queueItemInstance.CorpsMarker:SetHide(false);
			elseif (queueEntry.MilitaryFormationType == MilitaryFormationTypes.ARMY_FORMATION) then
				if (pUnitDef.Domain == "DOMAIN_SEA") then
					unitName = unitName .. " " .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
				else
					unitName = unitName .. " " .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
				end
				queueItemInstance.ArmyMarker:SetHide(false);
			end
			iconTooltip = Locale.Lookup(unitName);
		elseif queueEntry.Directive == CityProductionDirectives.CONSTRUCT then
			-- Constructing a building, valid table entries are
			-- entry.BuildingType
			local pBuildingDef:table = GameInfo.Buildings[queueEntry.BuildingType];
			kPossibleIcons = {"ICON_" .. pBuildingDef.BuildingType};
			iconTooltip = Locale.Lookup(pBuildingDef.Name);
		elseif queueEntry.Directive == CityProductionDirectives.ZONE then
			-- Constructing a district, valid table entries are
			-- entry.BuildingType
			-- entry.Location - This will be invalid coordinates (-9999, -9999) for everything but the head node
			local pDistrictDef:table = GameInfo.Districts[queueEntry.DistrictType];
			kPossibleIcons = {"ICON_" .. pDistrictDef.DistrictType};
			iconTooltip = Locale.Lookup(pDistrictDef.Name);
		elseif queueEntry.Directive == CityProductionDirectives.PROJECT then
			-- Constructing a project, valid table entries are
			-- entry.ProjectType
			local pProjectDef:table = GameInfo.Projects[queueEntry.ProjectType];
			kPossibleIcons = {"ICON_" .. pProjectDef.ProjectType};
			iconTooltip = Locale.Lookup(pProjectDef.Name);
		end

		for _,iconName in ipairs(kPossibleIcons) do
		    if iconName ~= nil and queueItemInstance.ProductionIcon:TrySetIcon(iconName) then
		        queueItemInstance[FIELD_ICON_TEXTURE] = iconName;
		        break;
            end
	    end

		queueItemInstance.ProductionIcon:SetToolTipString(iconTooltip);
		queueItemInstance.ProductionIcon:SetAlpha(1.0);
		queueItemInstance.ProductionIcon:SetHide(false);
		queueItemInstance.Num:SetHide(true);

		queueItemInstance[FIELD_CITY_ID] = cityID;
		queueItemInstance[FIELD_QUEUE_INDEX] = queueIndex;

		if queueItemInstance.Top:GetConsumeMouseOver() then
			queueItemInstance.Top:SetDisabled(false);
		end
	else
		queueItemInstance.Num:SetHide(false);
		queueItemInstance.ProductionIcon:SetHide(true);
		queueItemInstance[FIELD_CITY_ID] = cityID;
		queueItemInstance[FIELD_QUEUE_INDEX] = -1;
		queueItemInstance[FIELD_ICON_TEXTURE] = "";
		queueItemInstance.Top:SetDisabled(true);
	end

	return queueItemInstance;
end

-- ===========================================================================
function RefreshProductionQueue( instanceManager:table, parentControl:table, playerID:number, cityID:number )
	local kQueueInstances:table = {};
	local pCity:table = CityManager.GetCity(playerID, cityID);
	local pBuildQueue:table = pCity:GetBuildQueue();

	instanceManager:ResetInstances();

	-- Display queues items after the first which is shown as the current production
	for i = 1, MAX_QUEUE_SIZE do
		local entry = pBuildQueue:GetAt(i);
		local queueInstance:table = CreateQueueInstance( instanceManager, parentControl, playerID, cityID, i, entry );
		queueInstance.Num:SetText( tostring(i+1) );		-- Start at 2

		table.insert(kQueueInstances, queueInstance);
	end

	return kQueueInstances;
end

-- ===========================================================================
function RemoveQueueItem(queueIndex)
	local pSelectedCity = UI.GetHeadSelectedCity();
	local tParameters = {};
	tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_REMOVE_AT;
	tParameters[CityOperationTypes.PARAM_QUEUE_LOCATION] = queueIndex;
	CityManager.RequestOperation(pSelectedCity, CityOperationTypes.BUILD, tParameters);
end

-- ===========================================================================
function SwapQueueItem(sourceIndex, destIndex)
	if sourceIndex >= 0 and destIndex >= 0 then
        local pSelectedCity = UI.GetHeadSelectedCity();
        local tParameters = {};
        tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_SWAP;
        tParameters[CityOperationTypes.PARAM_QUEUE_SOURCE_LOCATION] = sourceIndex;
        tParameters[CityOperationTypes.PARAM_QUEUE_DESTINATION_LOCATION] = destIndex;
        CityManager.RequestOperation(pSelectedCity, CityOperationTypes.BUILD, tParameters);
    end
end

-- ===========================================================================
function MoveQueueItem(itemIndex, moveToIndex)
	if itemIndex >= 0 and moveToIndex >= 0 then
        local pSelectedCity = UI.GetHeadSelectedCity();
        local tParameters = {};
        tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_MOVE_TO;
        tParameters[CityOperationTypes.PARAM_QUEUE_SOURCE_LOCATION] = sourceIndex;
        tParameters[CityOperationTypes.PARAM_QUEUE_DESTINATION_LOCATION] = destIndex;
        CityManager.RequestOperation(pSelectedCity, CityOperationTypes.BUILD, tParameters);
    end
end

-- ===========================================================================
function OnMouseMove()
	if not Controls.MovingIcon:IsHidden() then
		local mouseX:number, mouseY:number = UIManager:GetMousePos();
		local screenWidth:number, screenHeight:number = UIManager:GetScreenSizeVal()
		mouseX = mouseX - (screenWidth - 1024) / 2;
		mouseY = mouseY - (screenHeight - 768) / 2;
		Controls.MovingIcon:SetOffsetVal(mouseX, mouseY);
	end
end

-- ===========================================================================
function EnableMouseIcon( icon:string )
	Controls.MovingIcon:SetIcon(icon);
	Controls.MovingIcon:SetHide(false);
	Controls.MovingIcon:SetOffsetVal(UIManager:GetMousePos());
	ContextPtr:SetUpdate(OnMouseMove);
	OnMouseMove();
end

-- ===========================================================================
function DisableMouseIcon()
	Controls.MovingIcon:SetHide(true);
	ContextPtr:ClearUpdate();
end

-- ===========================================================================
function GetQueueSize( pCity:table )
	if pCity == nil then
		UI.DataError("Attempted to get the build queue size of a NIL city");
		return 0;
	end

	return pCity:GetBuildQueue():GetSize();
end