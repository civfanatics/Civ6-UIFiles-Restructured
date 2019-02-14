-- ===========================================================================
--	Generic VFX triggers
-- ===========================================================================
include("TabSupport");
include("InstanceManager");
include("SupportFunctions");
include("AnimSidePanelSupport");
include("TeamSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

-- ===========================================================================
-- Handle City Added to Map
-- ===========================================================================
function OnCityAddedToMap( ownerPlayerID:number, cityID:number, cityX:number, cityY:number )
    WorldView.PlayEffectAtXY("CITY_CREATED", cityX, cityY);
end

-- ===========================================================================
-- Handle District Added to Map
-- ===========================================================================
function OnDistrictAddedToMap( playerID: number, districtID : number, cityID :number, districtX : number, districtY : number, districtType:number, iEra:number, iCivType:number, percentComplete:number, iAppeal:number, bPillaged:number )

    if (WorldView.HasAssetForDistrict(districtType)) then
		-- Check for a city at the location, they have an underlying district, but we don't want to show an effect for it.
		local pCity : object = CityManager.GetCityAt(districtX, districtY);
		if pCity == nil then
            WorldView.PlayEffectAtXY("DISTRICT_CREATED", districtX, districtY);
        end
    end
end

-- ===========================================================================
-- Handle Building / Wonder Added to Map
-- ===========================================================================
function OnBuildingAddedToMap( plotX:number, plotY:number, buildingType:number, playerType:number, pctComplete:number, bPillaged:number )

    if (WorldView.HasAssetForWonder(buildingType)) then
        WorldView.PlayEffectAtXY("WONDER_CREATED", plotX, plotY);
    else
        WorldView.PlayEffectAtXY("BUILDING_CREATED", plotX, plotY);
    end
end

-- ===========================================================================
function Initialize()

    Events.CityAddedToMap.Add( OnCityAddedToMap );
    Events.DistrictAddedToMap.Add( OnDistrictAddedToMap );
    Events.BuildingAddedToMap.Add( OnBuildingAddedToMap );
end
Initialize();   
