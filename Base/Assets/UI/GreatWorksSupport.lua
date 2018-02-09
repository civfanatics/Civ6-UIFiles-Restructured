--------------------------------------------------------------------------------
-- Helpers common to UI elements that present Great Works
--------------------------------------------------------------------------------

local YIELD_FONT_ICONS:table = {
	YIELD_FOOD				= "[ICON_FoodLarge]",
	YIELD_PRODUCTION		= "[ICON_ProductionLarge]",
	YIELD_GOLD				= "[ICON_GoldLarge]",
	YIELD_SCIENCE			= "[ICON_ScienceLarge]",
	YIELD_CULTURE			= "[ICON_CultureLarge]",
	YIELD_FAITH				= "[ICON_FaithLarge]",
};

function GreatWorksSupport_GetBasicTooltip( nGreatWorkIndex:number, bIsThemeable:boolean )
	local strTypeName:string;
	local tInstInfo:table = Game.GetGreatWorkDataFromIndex(nGreatWorkIndex);
	local tStaticInfo:table = GameInfo.GreatWorks[tInstInfo.GreatWorkType];
	local strName:string = Locale.Lookup(tStaticInfo.Name);
	local strCreator:string = Locale.Lookup(tInstInfo.CreatorName);
	local strDateCreated:string = Calendar.MakeDateStr(tInstInfo.TurnCreated, GameConfiguration.GetCalendarType(), GameConfiguration.GetGameSpeedType(), false);
	
	local strYields :string = "[ICON_TourismLarge]" .. tostring(tStaticInfo.Tourism);
	for row in GameInfo.GreatWork_YieldChanges() do
		if(row.GreatWorkType == tStaticInfo.GreatWorkType) then
			strYields = YIELD_FONT_ICONS[row.YieldType] .. tostring(row.YieldChange) .. " " .. strYields;
			break;
		end
	end
	
	if tStaticInfo.EraType ~= nil then
		strTypeName = Locale.Lookup("LOC_" .. tStaticInfo.GreatWorkObjectType .. "_" .. tStaticInfo.EraType);
	else
		strTypeName = Locale.Lookup("LOC_" .. tStaticInfo.GreatWorkObjectType);
	end
	
	local bIsArtifact :boolean = tStaticInfo.GreatWorkObjectType == "GREATWORKOBJECT_ARTIFACT";
	
	-- Tooltip localization key structure: LOC_GREAT_WORKS[_ARTIFACT]_TOOLTIP[_THEMABLE]
	local strLocKeyArtifact :string = bIsArtifact and "_ARTIFACT" or "";
	local strLocKeyThemable :string = bIsThemeable and "_THEMABLE" or "";
	local strTooltipLocKey	:string = "LOC_GREAT_WORKS" .. strLocKeyArtifact .. "_TOOLTIP" .. strLocKeyThemable;
	
	local strTooltip :string = Locale.Lookup(strTooltipLocKey, strName, strTypeName, strCreator, strDateCreated, strYields);
	return strTooltip;
end






