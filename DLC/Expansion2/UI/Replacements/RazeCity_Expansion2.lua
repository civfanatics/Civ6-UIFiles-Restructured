-- Copyright 2018, Firaxis Games
include("RazeCity");

-- ===========================================================================
--	OVERRIDES
-- ===========================================================================

-- ===========================================================================
function OnOpen()
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = Players[localPlayerID];
	if (localPlayer == nil) then
		return;
	end 

	g_pSelectedCity = localPlayer:GetCities():GetNextCapturedCity();

	Controls.PanelHeader:LocalizeAndSetText("LOC_RAZE_CITY_HEADER");
    Controls.CityHeader:LocalizeAndSetText("LOC_RAZE_CITY_NAME_LABEL");
    Controls.CityName:LocalizeAndSetText(g_pSelectedCity:GetName());
    Controls.CityPopulation:LocalizeAndSetText("LOC_RAZE_CITY_POPULATION_LABEL");
    Controls.NumPeople:SetText(tostring(g_pSelectedCity:GetPopulation()));
    Controls.CityDistricts:LocalizeAndSetText("LOC_RAZE_CITY_DISTRICTS_LABEL");
	local iNumDistricts = g_pSelectedCity:GetDistricts():GetNumZonedDistrictsRequiringPopulation();
    Controls.NumDistricts:SetText(tostring(iNumDistricts));

	local szWarmongerString;
	local eOriginalOwner = g_pSelectedCity:GetOriginalOwner();
	local originalOwnerPlayer = Players[eOriginalOwner];
	local eOwnerBeforeOccupation = g_pSelectedCity:GetOwnerBeforeOccupation();
	local eConqueredFrom = g_pSelectedCity:GetJustConqueredFrom();
	local bWipedOut = (originalOwnerPlayer:GetCities():GetCount() < 1);
	local eLastTransferType = g_pSelectedCity:GetLastTransferType();
	local iFavorForLiberation = GlobalParameters.FAVOR_FOR_LIBERATE_PLAYER_CITY;
	local pPlayerConfig = PlayerConfigurations[eOriginalOwner];
	local isMinorCiv = pPlayerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
	if (isMinorCiv) then
		iFavorForLiberation = GlobalParameters.FAVOR_FOR_LIBERATE_CITY_STATE;
	end
	local cities = originalOwnerPlayer:GetCities();
	if (not isMinorCiv and cities:GetCount() == 0) then
		iFavorForLiberation = iFavorForLiberation + GlobalParameters.FAVOR_FOR_REVIVE_PLAYER;
	end

	if (eOriginalOwner ~= eOwnerBeforeOccupation and localPlayer:GetDiplomacy():CanLiberateCityTo(eOriginalOwner) and eOriginalOwner ~= eConqueredFrom) then
		Controls.Button1:LocalizeAndSetText("LOC_RAZE_CITY_LIBERATE_FOUNDER_BUTTON_LABEL", PlayerConfigurations[eOriginalOwner]:GetCivilizationShortDescription());
		szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_LIBERATE_WARMONGER_EXPLANATION", iFavorForLiberation);
		Controls.Button1:LocalizeAndSetToolTip("LOC_RAZE_CITY_LIBERATE_EXPLANATION", szWarmongerString);
		Controls.Button1:SetHide(false);
	else
		Controls.Button1:SetHide(true);
	end

	if (localPlayer:GetDiplomacy():CanLiberateCityTo(eOwnerBeforeOccupation) and eOwnerBeforeOccupation ~= eConqueredFrom) then
		Controls.Button2:LocalizeAndSetText("LOC_RAZE_CITY_LIBERATE_PREWAR_OWNER_BUTTON_LABEL", PlayerConfigurations[eOwnerBeforeOccupation]:GetCivilizationShortDescription());
		szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_LIBERATE_WARMONGER_EXPLANATION", iFavorForLiberation);
		Controls.Button2:LocalizeAndSetToolTip("LOC_RAZE_CITY_LIBERATE_EXPLANATION", szWarmongerString);
		Controls.Button2:SetHide(false);
	else
		Controls.Button2:SetHide(true);
	end

	Controls.Button3:LocalizeAndSetText("LOC_RAZE_CITY_KEEP_BUTTON_LABEL");
	if (eLastTransferType == CityTransferTypes.BY_GIFT) then
		szWarmongerString = Locale.Lookup("LOC_RAZE_CITY_KEEP_EXPLANATION_TRADED");
		Controls.Button3:LocalizeAndSetToolTip(szWarmongerString);
	elseif (Players[eConqueredFrom]:IsFreeCities()) then
		Controls.Button3:LocalizeAndSetToolTip("LOC_XP2_RAZE_CITY_KEEP_FREE_CITY_EXPLANATION");
	elseif (bWipedOut ~= true) then
		local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(g_pSelectedCity, eConqueredFrom, false);
		szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_KEEP_WARMONGER_EXPLANATION", iWarmongerPoints);
		Controls.Button3:LocalizeAndSetToolTip("LOC_RAZE_CITY_KEEP_EXPLANATION", szWarmongerString);
	else
		local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(g_pSelectedCity, eConqueredFrom, false);
		iWarmongerPoints = (iWarmongerPoints * GlobalParameters.WARMONGER_FINAL_MAJOR_CITY_MULTIPLIER) / 100;
		szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_KEEP_LAST_CITY_EXPLANATION", iWarmongerPoints);
		Controls.Button3:LocalizeAndSetToolTip(szWarmongerString);
	end

	Controls.Button4:LocalizeAndSetText("LOC_RAZE_CITY_RAZE_BUTTON_LABEL");
	if (g_pSelectedCity:CanRaze()) then
		if (Players[eConqueredFrom]:IsFreeCities()) then
			Controls.Button4:LocalizeAndSetToolTip("LOC_XP2_RAZE_CITY_RAZE_FREE_CITY_EXPLANATION");
		elseif (bWipedOut ~= true) then
			local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(g_pSelectedCity, eConqueredFrom, true);
			szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_RAZE_WARMONGER_EXPLANATION", iWarmongerPoints);
			Controls.Button4:LocalizeAndSetToolTip("LOC_RAZE_CITY_RAZE_EXPLANATION", szWarmongerString);
		else
			local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(g_pSelectedCity, eConqueredFrom, true);
			szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_RAZE_LAST_CITY_EXPLANATION", iWarmongerPoints);
			Controls.Button4:LocalizeAndSetToolTip(szWarmongerString);
		end
		Controls.Button4:SetDisabled(false);
	else
		Controls.Button4:LocalizeAndSetToolTip("LOC_RAZE_CITY_RAZE_DISABLED_EXPLANATION");
		Controls.Button4:SetDisabled(true);

	end
	
	Controls.PopupStack:CalculateSize();
	
	UIManager:QueuePopup(ContextPtr, PopupPriority.Medium);

	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupAlphaIn:Play();
	Controls.PopupSlideIn:SetToBeginning();
	Controls.PopupSlideIn:Play();	
end
