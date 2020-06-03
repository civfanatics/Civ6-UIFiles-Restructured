-- ===========================================================================
--	Governor Assignment Chooser side-panel
--	Copyright 2017-2018, Firaxis Games
-- ===========================================================================

include("InstanceManager");
include("SupportFunctions");
include("GovernorSupport");
include("PopupDialog");
include("Colors");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID		:string = "GovernerAssignmentChooser"; -- Must be unique (usually the same as the file name)
local DATA_FIELD_CITY_ID	:string = "CITY_ID"; -- Stores CityID inside instance table (needed to update selection brace)
local DATA_FIELD_OWNER_ID	:string = "OWNER_ID"; -- Stores CityID inside instance table (needed to update selection brace)


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_AssignmentChoiceIM		:table = InstanceManager:new("AssignmentChoiceInstance", "Top", Controls.AssignmentChoiceStack);

local m_GovPromotionIM			:table = InstanceManager:new("PromotionInstance", "Top");

local m_SelectedGovernorID		:number = -1;
local m_SelectedGovernor		:table = nil;
local m_SelectedGovernorDef		:table = nil;

local m_SelectedCityOwner		:number = -1;
local m_SelectedCityID			:number = -1;
local m_isLoadComplete          :boolean = false;


-- ===========================================================================
function Refresh()
	ResizeCityStackPanel();

	if m_SelectedCityID ~= -1 then
		RefreshTopPanel();
		Controls.CitySelectedContainer:SetHide(false);
		Controls.NeedToSelectACityLabel:SetHide(true);
		if Controls.ConfirmAnim:IsStopped() then
			Controls.ConfirmAnim:SetToBeginning();
			Controls.ConfirmAnim:Play();
		end
	else
		Controls.CitySelectedContainer:SetHide(true);
		Controls.NeedToSelectACityLabel:SetHide(false);
		Controls.ConfirmAnim:SetToBeginning();
		Controls.ConfirmAnim:Stop();
	end

	-- Show selector brace only if this city is selected
	for _, instance in ipairs(m_AssignmentChoiceIM.m_AllocatedInstances) do
		instance.SelectorBrace:SetHide(m_SelectedCityID ~= instance.DATA_FIELD_CITY_ID or m_SelectedCityOwner ~= instance.DATA_FIELD_OWNER_ID);
	end
	
	RefreshBottomPanel();
end

-- ===========================================================================
function RefreshTopPanel()
	local localPlayerID:number = Game.GetLocalPlayer();
	local pLocalPlayer:table = Players[localPlayerID];
	local pPlayerGovernors:table = pLocalPlayer:GetGovernors();

	if ( m_SelectedCityID ~= -1 and m_SelectedCityOwner ~= -1 ) then
		local pPlayer:table = Players[m_SelectedCityOwner];
		local selectedCity:table = pPlayer:GetCities():FindID(m_SelectedCityID);
		if selectedCity then
			-- City Name
			if selectedCity:IsCapital() then
				Controls.CapitalIcon:SetHide(false);
				TruncateStringWithTooltip(Controls.CityName, 220, Locale.ToUpper(selectedCity:GetName()));
			else
				Controls.CapitalIcon:SetHide(true);
				TruncateStringWithTooltip(Controls.CityName, 240, Locale.ToUpper(selectedCity:GetName()));
			end
			Controls.CityNameGrid:SetHide(false);

			m_GovPromotionIM:ResetInstances();

			-- Add the selected governor
			AddGovernorInstance(Controls.NewGovernorInst, m_SelectedGovernor, m_SelectedGovernorDef, selectedCity);

			-- Add the current governor or blank governor
			local pCurrentGovernor:table = pPlayerGovernors and pPlayerGovernors:GetAssignedGovernor(selectedCity) or nil;
			if pCurrentGovernor then
				local pCurrentGovernorDef:table = GameInfo.Governors[pCurrentGovernor:GetType()];
				AddGovernorInstance(Controls.OldGovernorInst, pCurrentGovernor, pCurrentGovernorDef, selectedCity, true);
			else
				AddGovernorInstance(Controls.OldGovernorInst, nil, nil, selectedCity, true);
			end
		end
	else
		Controls.CityNameGrid:SetHide(true);
	end
end

-- ===========================================================================
function AddGovernorInstance(governorInst:table, governor:table, governorDef:table, city:table, current:boolean)
	if governor and governorDef then
		-- Title
		governorInst.GovernorName:SetText(Locale.Lookup(governorDef.Title));

		-- Governor Icon
		UpdateGovernorIcon(governorInst, governor);

		--This is one area where we do not want the tooltip
		governorInst.GovernorIcon:SetToolTipString("");

		-- Culture Identity Pressure
		governorInst.IdentityPressureContainer:SetHide(true);
		if (city ~= nil and Game.GetLocalPlayer() ~= nil) then
			if (city:GetOwner() == Game.GetLocalPlayer()) then
				governorInst.GovernorIdentityPressure:SetText(governor:GetIdentityPressure());
				governorInst.IdentityPressureContainer:SetHide(false);
			end
		end

		-- PromotionsgovernorInst
		for promotion in GameInfo.GovernorPromotions() do
			if governor:HasPromotion(promotion.Hash) then
				local instance:table = m_GovPromotionIM:GetInstance(governorInst.GovernorPromotionStack);
				if promotion.BaseAbility then
					instance.PromotionIcon:SetIcon("ICON_" .. governorDef.GovernorType .. "_PROMOTION");
				else
					instance.PromotionIcon:SetIcon("ICON_GOVERNOR_GENERIC_PROMOTION");
				end
				instance.PromotionIcon:SetToolTipString(Locale.Lookup(promotion.Description));
			end
		end

		-- Display different data depending on if this is the current governor or not
		if current then
			governorInst.TurnsToEstablishIcon:SetHide(true);
		else
			-- Number of turns to establish
			governorInst.TurnsToEstablish:SetText(governor:GetTurnsToEstablish());
			governorInst.TurnsToEstablishIcon:SetHide(false);
		end
	else
		governorInst.GovernorName:SetText(Locale.Lookup("LOC_GOVERNOR_ASSIGNMENT_NO_GOVERNOR"));
		governorInst.IdentityPressureContainer:SetHide(true);
		governorInst.GovernorIcon:SetHide(true);
		governorInst.TurnsToEstablishIcon:SetHide(true);
	end
end

-- ===========================================================================
function RefreshBottomPanel()
	local localPlayerID:number = Game.GetLocalPlayer();
	local localPlayer:table = Players[localPlayerID];

	-- Reset city instances
	m_AssignmentChoiceIM:ResetInstances();

	-- Add city instances
	local playerCities:table = localPlayer:GetCities();
	for _, city in playerCities:Members() do
		AddCityInstance(city);
	end

	-- handle city state instances for Ambassador governor
	if (m_SelectedGovernor ~= nil and m_SelectedGovernor:IsGovernCityState()) then
		for i, pCityState in ipairs(PlayerManager.GetAliveMinors()) do
			local iPlayer = pCityState:GetID();
			local pPlayerInfluence:table = pCityState:GetInfluence();
			local playerDiplomacy = localPlayer:GetDiplomacy();
			if pPlayerInfluence ~= nil then
				if (pPlayerInfluence:CanReceiveInfluence() and playerDiplomacy:HasMet(iPlayer)) then
					local cityStateCities:table = pCityState:GetCities();
					for _, city in cityStateCities:Members() do
						local bDisabled:boolean = false;
						local sFailureText = "";
						local playerGovernors = localPlayer:GetGovernors();
						local bCanAssign, results = playerGovernors:CanAssignGovernor(m_SelectedGovernorDef.Hash, city, true);
						bDisabled = not bCanAssign;
						if (results ~= nil) then
							local pFailureReasons : table = results[PlayerOperationResults.FAILURE_REASONS];
							if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
								-- Collect them all!
								for i,v in ipairs(pFailureReasons) do
									sFailureText = sFailureText .. "[NEWLINE]" .. Locale.Lookup(v);
								end
							end
						end
						AddCityInstance(city, bDisabled, sFailureText);
					end
				end
			end
		end
	end
	-----
	if (m_SelectedGovernor ~= nil and m_SelectedGovernor:CanAssignToMajorCiv()) then
		for i, pMajor in ipairs(PlayerManager.GetAliveMajors()) do
			local playerDiplomacy = localPlayer:GetDiplomacy();
			if ( playerDiplomacy:HasMet(pMajor:GetID()) ) then
				local pCapital = pMajor:GetCities():GetCapitalCity();
				local bDisabled:boolean = false;
				local sFailureText = "";
				local playerGovernors = localPlayer:GetGovernors();
				if (pCapital ~= nil) then
					local bCanAssign, results = playerGovernors:CanAssignGovernor(m_SelectedGovernorDef.Hash, pCapital, true);
					bDisabled = not bCanAssign;
					if (results ~= nil) then
						local pFailureReasons : table = results[PlayerOperationResults.FAILURE_REASONS];
						if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
							-- Collect them all!
							for i,v in ipairs(pFailureReasons) do
								sFailureText = sFailureText .. "[NEWLINE]" .. Locale.Lookup(v);
							end
						end
					end
					AddCityInstance(pCapital, bDisabled, sFailureText);
				end
			end
		end
	end

	Controls.ConfirmButton:SetDisabled(m_SelectedCityID == -1);
	Controls.AssignmentChoiceScrollPanel:CalculateSize();
end

-- ===========================================================================
function AddCityInstance( city:table, bDisabled:boolean, sFailureText:string )
	-- Ignore this city if the selected governor is currently assigned to this city
	local pLocalPlayer:table = Players[Game.GetLocalPlayer()];
	local pLocalPlayerGovernors:table = pLocalPlayer:GetGovernors();
	local pCurrentGovernor:table = pLocalPlayerGovernors and pLocalPlayerGovernors:GetAssignedGovernor(city) or nil;
	if pCurrentGovernor and pCurrentGovernor:GetID() == m_SelectedGovernor:GetID() then
		return;
	end

	local cityID:number = city:GetID();
	local cityOwner:number = city:GetOwner();
	local instance:table = m_AssignmentChoiceIM:GetInstance();

	-- Store city ID in instance so we can update selector brace
	instance.DATA_FIELD_CITY_ID = cityID;
	instance.DATA_FIELD_OWNER_ID = cityOwner;

	-- Update name
	if city:IsCapital() and Players[cityOwner]:IsMajor() then
		instance.CapitalIcon:SetHide(false);
		TruncateStringWithTooltip(instance.CityName, 200, Locale.ToUpper(city:GetName()));
	else
		instance.CapitalIcon:SetHide(true);
		TruncateStringWithTooltip(instance.CityName, 220, Locale.ToUpper(city:GetName()));
	end

	-- Get colors
	local backColor:number, frontColor:number = UI.GetPlayerColors(cityOwner);
	local darkerBackColor:number = UI.DarkenLightenColor(backColor,(-85),238);
	local brighterBackColor:number = UI.DarkenLightenColor(backColor,90,255);

	-- Update colors
	instance.BannerBase:SetColor( backColor );
	instance.BannerDarker:SetColor( darkerBackColor );
	instance.BannerLighter:SetColor( brighterBackColor );
	instance.CityName:SetColor( frontColor );

	if (bDisabled == true) then
		instance.Button:SetDisabled(true);
		instance.Button:SetToolTipString(sFailureText);
	else
		instance.Button:SetDisabled(false);
		instance.Button:SetToolTipString("");
	end

	-- Determine if we have a governor in this city
	if pCurrentGovernor then
		UpdateGovernorIcon(instance, pCurrentGovernor);
	else
		instance.GovernorIcon:SetHide(true);
	end

	-- Calculate the current identity pressure and the identity pressure minus the governor
	local identityPressure:number = 0;
	local identityPressureWithoutGovernor:number = 0;
	local pCityCulturalIdentity:table = city:GetCulturalIdentity();
	local identitySourcesBreakdown = pCityCulturalIdentity:GetIdentitySourcesBreakdown();
	for i,source in ipairs(identitySourcesBreakdown) do
		for type,value in pairs(source) do
			-- Add to total
			identityPressure = identityPressure + value;
			
			-- Add to total minus governors
			if type ~= "Governors" then
				identityPressureWithoutGovernor = identityPressureWithoutGovernor + value;
			end
		end
	end

	-- Set the pressure of the current governor and the selected governor if assigned
	if (cityOwner == Game.GetLocalPlayer()) then
		instance.IdentityPressureStack:SetHide(false);
		instance.IdentityPressureBefore:SetText(Locale.Lookup("LOC_GOVERNOR_ASSIGNMENT_PLUS_PRESSURE", identityPressure));
		local selectedGovernorPressure:number = m_SelectedGovernor ~= nil and m_SelectedGovernor:GetIdentityPressure() or 0;
		instance.IdentityPressureAfter:SetText(Locale.Lookup("LOC_GOVERNOR_ASSIGNMENT_PLUS_PRESSURE", identityPressureWithoutGovernor + selectedGovernorPressure));
	else
		instance.IdentityPressureStack:SetHide(true);
	end

	-- Set number of turns till the selected governor would be established
	local turnsToEstablish:number = m_SelectedGovernor:GetTurnsToEstablish();
	instance.EstablishTurns:SetText(turnsToEstablish);

	-- Setup button callback
	instance.Button:SetVoid1(cityOwner);
	instance.Button:SetVoid2(cityID);
	instance.Button:RegisterCallback( Mouse.eLClick, OnSelectCity );
end

-- ===========================================================================
function ResizeCityStackPanel()
	local newSize:number = Controls.BodyContainer:GetSizeY() - Controls.TopPanel:GetSizeY() - Controls.ConfirmGrid:GetSizeY();
	Controls.BottomGrid:SetSizeY(newSize);
end

-- ===========================================================================
function UpdateGovernorIcon(parentControl:table, pGovernor:table)
	local pGovernorDef:table = GameInfo.Governors[pGovernor:GetType()];

	if pGovernor:IsEstablished() then
		parentControl.GovernorIcon:SetIcon("ICON_" .. pGovernorDef.GovernorType .. "_FILL");
		parentControl.GovernorIcon:SetToolTipString(Locale.Lookup("LOC_GOVERNOR_ASSIGNMENT_IS_ESTABLISHED", Locale.Lookup(pGovernorDef.Name), Locale.Lookup(pGovernorDef.ShortTitle)));
	else
		parentControl.GovernorIcon:SetIcon("ICON_" .. pGovernorDef.GovernorType .. "_SLOT");
		parentControl.GovernorIcon:SetToolTipString(Locale.Lookup("LOC_GOVERNOR_ASSIGNMENT_IS_ESTABLISHING", Locale.Lookup(pGovernorDef.Name), Locale.Lookup(pGovernorDef.ShortTitle)));
	end

	parentControl.GovernorIcon:SetHide(false);
end

-- ===========================================================================
function OnSelectCity( owner:number, cityID:number )
	
	m_SelectedCityOwner = owner;
	m_SelectedCityID = cityID;

	local pCity = CityManager.GetCity(owner, cityID);
	if (pCity ~= nil) then
		UI.LookAtPlot(pCity:GetX(), pCity:GetY());
		UILens.SetActive("Loyalty");	-- May have been turned off by other map selection.
	end

	Refresh();
end

-- ===========================================================================
function OnRequestAssignment( governorIndex:number )

	SetSelectedGovernor(governorIndex);
	m_SelectedCityOwner = -1;
	m_SelectedCityID = -1;

	Open();
end

-- ===========================================================================
function Open()
	-- Queue the screen as a popup, but we want it to render at a desired location in the hierarchy, not on top of everything.
	local kParameters = {};
	kParameters.RenderAtCurrentParent = true;
	kParameters.InputAtCurrentParent = true;
	kParameters.AlwaysVisibleInQueue = true;
	UIManager:QueuePopup(ContextPtr, PopupPriority.Low, kParameters);

	-- Play Open Animation
	Controls.AssignmentChooserSlideAnim:SetToBeginning();
	Controls.AssignmentChooserSlideAnim:Play();

	-- If the governor is already assigned to a city focus on the camera on that city
	local pAssignedCity = m_SelectedGovernor ~= nil and m_SelectedGovernor:GetAssignedCity() or nil;
	if pAssignedCity ~= nil then
		UI.LookAtPlot(pAssignedCity:GetX(), pAssignedCity:GetY());
	end
	UILens.SetActive("Loyalty");

	Refresh();
end

-- ===========================================================================
function Close()
	if UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS then
		if UILens.IsLensActive("Loyalty") then
			UILens.SetActive("Default");
		end
	end
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
function ConfirmedAssignment()
	-- Request assignment
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = m_SelectedGovernorID;
		kParameters[PlayerOperations.PARAM_PLAYER_ONE] = m_SelectedCityOwner;
		kParameters[PlayerOperations.PARAM_CITY_DEST] = m_SelectedCityID;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ASSIGN_GOVERNOR, kParameters);

		Close();
	end
end

-- ===========================================================================
function OnConfirm()
	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= nil) then
		local pCity = CityManager.GetCity(m_SelectedCityOwner, m_SelectedCityID);
		if pCity ~= nil and pCity:GetAssignedGovernor() ~= nil then
			local pAssignedGovernor = pCity:GetAssignedGovernor();
			local governorOwner = pAssignedGovernor:GetOwner();
			if (pAssignedGovernor:GetOwner() == localPlayerID) then
				-- If this city already has an assigned governor popup a popup dialog to confirm the replacement
				local popup:table = PopupDialogInGame:new( "GovernorAssignmentReplaceConfirm" );
				popup:ShowYesNoDialog( Locale.Lookup("LOC_GOVERNOR_ASSIGNMENT_CONFIRM_REPLACEMENT"), function() ConfirmedAssignment(); LuaEvents.GovernorPanel_Open(); end );
			else
				ConfirmedAssignment();
				LuaEvents.GovernorPanel_Close();
			end
		else
			ConfirmedAssignment();
			LuaEvents.GovernorPanel_Close();
		end
	end
end

-- ===========================================================================
function OnCancel()
	Close();

	LuaEvents.GovernorPanel_CancelAssignment();
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload then		
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );	
	end
end

-- =======================================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", ContextPtr:IsVisible());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "governorID", m_SelectedGovernorID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "selectedCityOwner", m_SelectedCityOwner);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "selectedCityID", m_SelectedCityID);
end

-- ===========================================================================
function SetSelectedGovernor( governorID:number )
	m_SelectedGovernorID = governorID;
	m_SelectedGovernorDef = GameInfo.Governors[m_SelectedGovernorID];
	m_SelectedGovernor = GetAppointedGovernor(Game.GetLocalPlayer(), m_SelectedGovernorID);
end

-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context ~= RELOAD_CACHE_ID then
		return;
	end

	if contextTable["governorID"] >= 0 then
		SetSelectedGovernor(contextTable["governorID"]);
	end

	if contextTable["selectedCityOwner"] then
		m_SelectedCityOwner = contextTable["selectedCityOwner"];
	end

	if contextTable["selectedCityID"] then
		m_SelectedCityID = contextTable["selectedCityID"];
	end

	if contextTable["isVisible"] then
		Open();
	end
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function OnInputHandler( pInputStruct:table )

	if ContextPtr:IsHidden() then return; end

	local key = pInputStruct:GetKey();
	local msg = pInputStruct:GetMessageType();
	if msg == KeyEvents.KeyUp and key == Keys.VK_ESCAPE then 
		OnClose();
		return true;
	end;
	return false;
end

-- ===========================================================================
function OnDiploBasePopup_HideUI( shouldHideUI:boolean )
	if shouldHideUI and not 
	ContextPtr:IsHidden() then
		Close();
	end
end


-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnCityAddedToMap( playerID: number, cityID : number, cityX : number, cityY : number )	
	-- Only needs to make a refresh after a city added if it's happening while
	-- game is running.  (Ignore during the load of a save game when map is rebuilt.)
	if not ContextPtr:IsHidden() and m_isLoadComplete then
		Refresh();
	end
end


-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if GameConfiguration.IsHotseat() and ContextPtr:IsVisible() then
		OnCancel();
	end
end


-- ===========================================================================
--	The loading screen has completed
-- ===========================================================================
function OnLoadGameViewStateDone()
    m_isLoadComplete = true;
end


-- ===========================================================================
function Initialize()

	-- Context Callbacks
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );

	-- Control Callbacks
	Controls.ConfirmButton:RegisterCallback( Mouse.eLClick, OnConfirm );
	Controls.ConfirmButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel );
	Controls.Header_CloseButton:RegisterCallback( Mouse.eLClick, OnClose );

	-- Game Events
	Events.CityAddedToMap.Add( OnCityAddedToMap );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );	

	-- Lua Events	
	LuaEvents.DiploBasePopup_HideUI.Add( OnDiploBasePopup_HideUI );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
	LuaEvents.GovernorAssignmentChooser_RequestAssignment.Add( OnRequestAssignment );
	LuaEvents.GovernorAssignmentChooser_Close.Add( OnClose );
end
Initialize();