-- Copyright 2019, Firaxis Games
-- Support for (unit) portraits.

-- ===========================================================================
function GetUnitPortraitPrefix( playerID:number )
	local iconPrefix:string = "ICON_";

	-- Add civilization ethnicity
	local playerConfig:table = PlayerConfigurations[playerID];
	local civ:table = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()];
	if civ then
		-- Barbarians don't have an ethnicity field so make sure it exists
		if civ.Ethnicity and civ.Ethnicity ~= "ETHNICITY_EURO" then
			iconPrefix = iconPrefix .. civ.Ethnicity .. "_";
		end
	end

	return iconPrefix;
end

-- ===========================================================================
function GetUnitPortraitEraSuffix( playerID:number )
	-- Era system changed between BASE and XP1

	-- XP1+...
	if Game.GetEras ~= nil then		
		local pGameEras :table = Game.GetEras();
		local eraName	:string = GameInfo.Eras[ pGameEras:GetCurrentEra() ].EraType;
		return "_PORTRAIT_" .. eraName;
	end

	-- BASE
	local pPlayer = Players[playerID];
	if pPlayer ~= nil then
		local eraIndex = pPlayer:GetEra() + 1;
		for row:table in GameInfo.Eras() do
			if row.ChronologyIndex == eraIndex then
				return "_" .. row.EraType;
			end
		end
	else
		UI.DataError("PortraitSupport could not find a suffix for Player ID '"..tostring(playerID));
	end

	return "";
end

-- ===========================================================================
function GetGreatPersonGenderSuffix( pUnit:table )
	local pGreatPerson :table = pUnit:GetGreatPerson();	
	if pGreatPerson and pGreatPerson:IsGreatPerson() then
		local greatPersonDetails = GameInfo.GreatPersonIndividuals[pGreatPerson:GetIndividual()];
		if greatPersonDetails.Gender == "F" then	-- female?
			return "_F";
		end
	end
	return "";
end


-- ===========================================================================
--	Obtain potential names for a unit portrait.
--	RETURNS:
--
--
--
-- ===========================================================================
function GetUnitPortraitIconNames( pUnit:table )
	if pUnit == nil then
		UI.DataError("Unable to GetUnitPortrait() for a NIL unit.");
		return;
	end

	local playerID		:number = pUnit:GetOwner();
	local pUnitDef		:table = GameInfo.Units[pUnit:GetUnitType()];
	local prefix		:string = GetUnitPortraitPrefix( playerID )..pUnitDef.UnitType;
	local suffix		:string = GetUnitPortraitEraSuffix( playerID )
	local genderSuffix	:string = GetGreatPersonGenderSuffix( pUnit );

	local iconName				:string = prefix ..suffix;
	local prefixOnlyIconName	:string = prefix .."_PORTRAIT";
	local eraOnlyIconName		:string = "ICON_"..pUnitDef.UnitType..suffix..genderSuffix;
	local fallbackIconName		:string = "ICON_"..pUnitDef.UnitType.."_PORTRAIT"..genderSuffix;

	return iconName, prefixOnlyIconName, eraOnlyIconName, fallbackIconName;
end


-- ===========================================================================
--	Obtain potential names for a unit portrait based on a definition and player.
--	RETURNS:
--
--
--
-- ===========================================================================
function GetUnitPortraitIconNamesFromDefinition( playerID:number, pUnitDef:table )
	local prefix		:string = GetUnitPortraitPrefix( playerID )..pUnitDef.UnitType;
	local suffix		:string = GetUnitPortraitEraSuffix( playerID )

	local iconName				:string = prefix ..suffix;
	local prefixOnlyIconName	:string = prefix .."_PORTRAIT";
	local eraOnlyIconName		:string = "ICON_"..pUnitDef.UnitType..suffix;
	local fallbackIconName		:string = "ICON_"..pUnitDef.UnitType.."_PORTRAIT";

	return iconName, prefixOnlyIconName, eraOnlyIconName, fallbackIconName;	
end
