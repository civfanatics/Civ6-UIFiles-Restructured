-- Modeled after RazeCity.lua

local g_pSelectedCity;

function OnKeepButton()
	local tParameters = {};
	tParameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.KEEP;
	if (CityManager.CanStartCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters)) then
		CityManager.RequestCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters);
	end
	OnClose();
end
function OnRejectButton()
	local tParameters = {};
	tParameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.REJECT;
	if (CityManager.CanStartCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters)) then
		UI.DeselectAllCities();
		CityManager.RequestCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters);
	end
	OnClose();
end

function OnClose()
	ContextPtr:SetHide(true);
end

function OnOpen()
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = Players[localPlayerID];
	if (localPlayer == nil) then
		return;
	end 

	g_pSelectedCity = localPlayer:GetCities():GetNextRebelledCity();

	Controls.PanelHeader:LocalizeAndSetText("LOC_DISLOYAL_CITY_HEADER");
    Controls.CityHeader:LocalizeAndSetText("LOC_DISLOYAL_CITY_NAME_LABEL");
    Controls.CityName:LocalizeAndSetText(g_pSelectedCity:GetName());
    Controls.CityPopulation:LocalizeAndSetText("LOC_DISLOYAL_CITY_POPULATION_LABEL");
    Controls.NumPeople:SetText(tostring(g_pSelectedCity:GetPopulation()));
    Controls.CityDistricts:LocalizeAndSetText("LOC_DISLOYAL_CITY_DISTRICTS_LABEL");
	local iNumDistricts = g_pSelectedCity:GetDistricts():GetNumZonedDistrictsRequiringPopulation();
    Controls.NumDistricts:SetText(tostring(iNumDistricts));

	Controls.KeepButton:LocalizeAndSetText("LOC_DISLOYAL_CITY_CHOOSER_KEEP_BUTTON_LABEL");
	Controls.KeepButton:LocalizeAndSetToolTip("LOC_DISLOYAL_CITY_CHOOSER_KEEP_EXPLANATION");

	Controls.RejectButton:LocalizeAndSetText("LOC_DISLOYAL_CITY_CHOOSER_REFUSE_BUTTON_LABEL");
	Controls.RejectButton:LocalizeAndSetToolTip("LOC_DISLOYAL_CITY_CHOOSER_REFUSE_EXPLANATION");

	Controls.PopupStack:CalculateSize();
	Controls.PopupStack:ReprocessAnchoring();
	Controls.DisloyalCityPanel:ReprocessAnchoring();
	ContextPtr:SetHide(false);
	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupAlphaIn:Play();
	Controls.PopupSlideIn:SetToBeginning();
	Controls.PopupSlideIn:Play();
end

function OnInputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyUp then
        if wParam == Keys.VK_ESCAPE then
            OnClose();
        end
    end
    return true;
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetHide(true);
	ContextPtr:SetInputHandler( OnInputHandler, true );
	Controls.KeepButton:RegisterCallback(Mouse.eLClick, OnKeepButton);
	Controls.RejectButton:RegisterCallback(Mouse.eLClick, OnRejectButton);
	Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, OnClose);
	LuaEvents.NotificationPanel_OpenDisloyalCityChooser.Add(OnOpen);
end
Initialize();
