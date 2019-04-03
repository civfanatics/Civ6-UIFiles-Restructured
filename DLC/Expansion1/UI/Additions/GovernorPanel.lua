-- Copyright 2017-2018, Firaxis Games
-- UI for managing and appointing Governors	

include("InstanceManager");
include("GameCapabilities"); 
include("TabSupport");
include("SupportFunctions");
include("Civ6Common");
include("ModalScreen_PlayerYieldsHelper");
include("GovernorSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "GovernorPanel"; -- Must be unique (usually the same as the file name)

m_GovernorApptAvailableHash = DB.MakeHash("NOTIFICATION_GOVERNOR_APPOINTMENT_AVAILABLE");
m_GovernorOpportunityAvailableHash = DB.MakeHash("NOTIFICATION_GOVERNOR_OPPORTUNITY_AVAILABLE");
m_GovernorPromotionAvailableHash = DB.MakeHash("NOTIFICATION_GOVERNOR_PROMOTION_AVAILABLE");

local PANEL_MAX_WIDTH = 1890;
local m_TopPanelConsideredHeight:number = 0;

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_governorIM			:table = InstanceManager:new("GovernorInstance",	"Content",	Controls.GovernorInstanceStack);
local m_governorPromotionIM :table = InstanceManager:new("PromotionInstance",	"Button");
local m_TopPanelConsideredHeight:number = 0;

-- Player ID and City ID sent by City Banner to be used to auto select a city when opening the assignment chooser
local m_CityBannerPlayerID:number = -1;
local m_CityBannerCityID:number = -1;

-- ===========================================================================
function Refresh()

	local pPlayer = Players[Game.GetLocalPlayer()];
	if (pPlayer == nil) then
		return;
	end
		
	m_governorPromotionIM:ResetInstances();

	--
	-- display a list of governor candidates
	--
	m_governorIM:ResetInstances();

	local playerGovernors = pPlayer:GetGovernors();
	local governorPointsObtained = playerGovernors:GetGovernorPoints();
	local governorPointsSpent = playerGovernors:GetGovernorPointsSpent();
	local bCanAppoint = playerGovernors:CanAppoint();
	local bCanPromote = playerGovernors:CanPromote();
	local bHasGovernors, tGovernorList = playerGovernors:GetGovernorList();

	Controls.GovernorTitlesAvailable:SetText(Locale.Lookup("LOC_GOVERNOR_GOVERNOR_TITLES_AVAILABLE", governorPointsObtained - governorPointsSpent));
	Controls.GovernorTitlesSpent:SetText(Locale.Lookup("LOC_GOVERNOR_GOVERNOR_TITLES_SPENT", governorPointsSpent));

	-- Add apointed governors
	for i,appointedGovernor in ipairs(tGovernorList) do
		local eGovernorType = appointedGovernor:GetType();
		local governorDef = GameInfo.Governors[eGovernorType];

		AddGovernorAppointed(playerGovernors, appointedGovernor, governorDef, bCanPromote);
	end

	-- Add appointable governors
	for governorDef in GameInfo.Governors() do
		local governorHash = governorDef.Hash;
		if (not playerGovernors:HasGovernor(governorHash)) then
			AddGovernorCandidate(governorDef, bCanAppoint);
		end
	end

	Controls.GovernorInstanceStack:CalculateSize();
	Controls.GovernorInstanceScrollPanel:CalculateSize();

	if Controls.GovernorPanelContainer:GetSizeX() > PANEL_MAX_WIDTH then
		Controls.GovernorPanelContainer:SetSizeX(PANEL_MAX_WIDTH);
	end

	-- From ModalScreen_PlayerYieldsHelper
	if not RefreshYields() then
		Controls.Vignette:SetSizeY(m_TopPanelConsideredHeight);
	end
end

-- ===========================================================================
function AddGovernorShared(governor:table)

	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	local pPlayerGovernors = pLocalPlayer:GetGovernors();
	local turnsToEstablish = pPlayerGovernors:GetTurnsToEstablish(governor.Hash);

	governorInstance = m_governorIM:GetInstance();

	-- Update name, title, and portrait
	governorInstance.GovernorName:SetText(Locale.ToUpper(governor.Name));
	governorInstance.GovernorTitle:SetText(Locale.Lookup(governor.Title));
	governorInstance.GovernorPortrait:SetTexture(governor.PortraitImage);

	-- Update transition strength
	governorInstance.TransitionStrengthLabel:SetText(turnsToEstablish);

	-- Update identity pressure
	governorInstance.IdentityPressureLabel:SetText(governor.IdentityPressure);

	-- Return the governor instance
	return governorInstance;
end

-- ===========================================================================
function AddPromotionInstance( governorInstance:table, governorDefinition:table, promotion:table, hasPromotion:boolean )

	local promotionInstance = {};
	if hasPromotion then
		promotionInstance = m_governorPromotionIM:GetInstance(governorInstance.EarnedPromotionsStack);
	else
		promotionInstance = m_governorPromotionIM:GetInstance(governorInstance.AvailablePromotionsStack);
	end

	local hasModifier = false;
	for row in GameInfo.GovernorPromotionModifiers() do
		if(row.GovernorPromotionType == promotion.GovernorPromotionType) then
			hasModifier = true;
			break;
		end
	end

	local sDescription = "";
	if (not hasModifier) then
		sDescription = sDescription .. "<NOT IMPLEMENTED>";
	end
	local sName:string = Locale.Lookup(promotion.Name);
	sDescription = sName .. ": " .. sDescription .. Locale.Lookup(promotion.Description);

	promotionInstance.PromotionName:SetText(sName);
	promotionInstance.Button:SetToolTipString(sDescription);
	promotionInstance.Button:SetDisabled(true);

	-- If this is our base ability use our governor specific promotion icon
	if promotion.BaseAbility then
		local iconName:string = "ICON_" .. governorDefinition.GovernorType .. "_PROMOTION";
		promotionInstance.PromotionIcon:SetIcon(iconName);
	else
		promotionInstance.PromotionIcon:SetIcon("ICON_GOVERNOR_GENERIC_PROMOTION");
	end

	-- Indicate if we have this promotion using vis states
	if hasPromotion then
		promotionInstance.Button:SetAlpha(1.0);
	else
		promotionInstance.Button:SetAlpha(0.5);
	end
end

-- ===========================================================================
function AddGovernorCandidate(governorDef:table, canAppoint:boolean)

	local governorInstance:table = AddGovernorShared(governorDef);

	-- Add all promotions this governor has
	for promotion in GameInfo.GovernorPromotionSets() do
		if promotion.GovernorType == governorDef.GovernorType then
			local promotionDef = GameInfo.GovernorPromotions[promotion.GovernorPromotion];
			AddPromotionInstance(governorInstance, governorDef, promotionDef, promotion.BaseAbility);
		end
	end

	-- Always use unassigned column/background for governor candidates
	governorInstance.Content:SetTexture("Governors_BackgroundTile_ColumnOff");
	governorInstance.GovernorColumns:SetTexture("Governors_Column_Off");

	governorInstance.AssignButton:SetHide(true);
	governorInstance.AppointButton:SetHide(false);

	if canAppoint then
		governorInstance.AppointButton:SetVoid1( governorDef.Index );
		governorInstance.AppointButton:RegisterCallback( Mouse.eLClick, OnAppointGovernor );
		governorInstance.AppointButton:SetDisabled(false);
		governorInstance.AppointButton:SetToolTipString("");
	else
		governorInstance.AppointButton:SetDisabled(true);
		governorInstance.AppointButton:SetToolTipString(Locale.Lookup("LOC_NO_GOVERNORS_TITLE_AVAILABLE"));

	end

	SetGovernorStatus(governorInstance, governorDef);

	-- Setup details button
	governorInstance.GovernorDetailsButton:SetVoid1(governorDef.Index);
	governorInstance.GovernorDetailsButton:RegisterCallback(Mouse.eLClick, OnNameButton);
	governorInstance.GovernorDetailsButton:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_VIEW_PROMOTIONS"));
	SetButtonTexture(governorInstance.GovernorDetailsButton, "Controls_Button");

	governorInstance.GovernorNeutralizedIndicator:SetHide(true);
	governorInstance.FadeOutOverlay:SetHide(false);
end

-- ===========================================================================
function SetGovernorStatus(governorInstance:table, governorDef:table, governor:table)
	local status, statusDetails = GetGovernorStatus(governorDef, governor);
	governorInstance.GovernorStatus:SetText(status);
	governorInstance.GovernorStatusDetails:SetText(statusDetails);
end

-- ===========================================================================
function AddGovernorAppointed(playerGovernors:table, governor:table, governorDefinition:table, canPromote:boolean)

	local governorInstance:table = AddGovernorShared(governorDefinition);

	-- Add all promotions this governor has
	local hasAllPromotions:boolean = true;
	for promotion in GameInfo.GovernorPromotionSets() do
		if promotion.GovernorType == governorDefinition.GovernorType then
			local promotionDef = GameInfo.GovernorPromotions[promotion.GovernorPromotion];
			local hasPromotion:boolean = governor:HasPromotion(DB.MakeHash(promotion.GovernorPromotion));
			AddPromotionInstance(governorInstance, governorDefinition, promotionDef, hasPromotion);

			if not hasPromotion then
				hasAllPromotions = false;
			end
		end
	end

	governorInstance.AssignButton:SetHide(false);
	governorInstance.AppointButton:SetHide(true);

	-- Update assignment button
	governorInstance.AssignButton:SetDisabled(false);
	governorInstance.AssignButton:RegisterCallback(Mouse.eLClick, function() OnAssignButton(governorDefinition.Index, m_CityBannerPlayerID, m_CityBannerCityID); end);

	SetGovernorStatus(governorInstance, governorDefinition, governor);

	local pAssignedCity:table = governor:GetAssignedCity();
	if pAssignedCity then
		SetButtonTexture(governorInstance.AssignButton, "Controls_Button");
		governorInstance.AssignButton:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_BUTTON_REASSIGN_GOVERNOR"));

		governorInstance.Content:SetTexture("Governors_BackgroundTile_ColumnOn");
		governorInstance.GovernorColumns:SetTexture("Governors_Column_On");
	else
		governorInstance.AssignButton:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_BUTTON_ASSIGN_GOVERNOR"));

		-- If we have cities without any governors highlight the Assign buttons
		if AnyCitiesWithoutAGovernor() then
			SetButtonTexture(governorInstance.AssignButton, "Controls_Confirm");
		else
			SetButtonTexture(governorInstance.AssignButton, "Controls_Button");
		end

		governorInstance.Content:SetTexture("Governors_BackgroundTile_ColumnOff");
		governorInstance.GovernorColumns:SetTexture("Governors_Column_Off");
	end

	-- Setup button to open governor details
	if canPromote and not hasAllPromotions then
		SetButtonTexture(governorInstance.GovernorDetailsButton, "Controls_Confirm");
		governorInstance.GovernorDetailsButton:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_PROMOTE"));
	else
		SetButtonTexture(governorInstance.GovernorDetailsButton, "Controls_Button");
		governorInstance.GovernorDetailsButton:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_VIEW_PROMOTIONS"));
	end
	governorInstance.GovernorDetailsButton:SetVoid1(governorDefinition.Index);
	governorInstance.GovernorDetailsButton:RegisterCallback(Mouse.eLClick, OnNameButton);

	local numOfNeutralizedTurns:number = governor:GetNeutralizedTurns();
	if (numOfNeutralizedTurns > 0) then
		governorInstance.AssignButton:SetDisabled(true);
		governorInstance.GovernorNeutralizedIndicator:SetHide(false);
		governorInstance.FadeOutOverlay:SetHide(false);
	else
		governorInstance.AssignButton:SetDisabled(false);
		governorInstance.GovernorNeutralizedIndicator:SetHide(true);
		governorInstance.FadeOutOverlay:SetHide(true);
	end
end

-- ===========================================================================
function AnyCitiesWithoutAGovernor()
	local pLocalPlayerCities:table = Players[Game.GetLocalPlayer()]:GetCities();
	for i,pCity in pLocalPlayerCities:Members() do
		if pCity:GetAssignedGovernor() == nil then
			return true;
		end
	end

	return false;
end

-- ===========================================================================
function OnNameButton( governorIndex:number )
	LuaEvents.GovernorDetailsPanel_OpenDetails( governorIndex, m_CityBannerPlayerID, m_CityBannerCityID );
	Controls.DetailsPanel:SetHide(false);
end

-- ===========================================================================
function OnAssignButton( governorIndex:number, playerID:number, cityID:number )
	LuaEvents.GovernorAssignmentChooser_RequestAssignment( governorIndex, playerID, cityID );
	Close();
end

-- ===========================================================================
function Close()
	if Controls.DetailsPanel:IsVisible() then
		Controls.DetailsPanel:SetHide(true);
	end

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local localPlayer = Players[localPlayerID];
		if (localPlayer ~= nil and localPlayer:GetGovernors() ~= nil and not localPlayer:GetGovernors():HasTitleBeenConsidered()) then
			localPlayer:GetGovernors():SetTitleConsidered(true);
		end
	end

	if UIManager:DequeuePopup(ContextPtr) then
		UI.PlaySound("UI_Screen_Close");
		LuaEvents.GovernorPanel_Closed();
	end
end

-- ===========================================================================
function Open(playerID:number, cityID:number)
	-- playerID and cityID banner come from selecting a city banner
	-- in other situations they should be nil
	if playerID ~= nil and cityID ~= nil then
		m_CityBannerPlayerID = playerID;
		m_CityBannerCityID = cityID;
	else
		m_CityBannerPlayerID = -1;
		m_CityBannerCityID = -1;
	end

	Refresh();

	Controls.DetailsPanel:SetHide(true);
	if not UIManager:IsInPopupQueue(ContextPtr) then
		-- Queue the screen as a popup, but we want it to render at a desired location in the hierarchy, not on top of everything.
		local kParameters = {};
		kParameters.RenderAtCurrentParent = true;
		kParameters.InputAtCurrentParent = true;
		kParameters.AlwaysVisibleInQueue = true;
		UIManager:QueuePopup(ContextPtr, PopupPriority.Low, kParameters);
		UI.PlaySound("UI_Screen_Open");
	end

	LuaEvents.GovernorAssignmentChooser_Close();
	
	-- From Civ6_styles: FullScreenVignetteConsumer
	Controls.ScreenAnimIn:SetToBeginning();
	Controls.ScreenAnimIn:Play();
	
	LuaEvents.GovernorPanel_Opened();
	ContextPtr:ChangeParent(ContextPtr:LookUpControl("/InGame/Screens"));
end

-- ===========================================================================
function OnGovernorAppointed(playerID, governorID)
	if ContextPtr:IsVisible() and playerID == Game.GetLocalPlayer() then
		Refresh();
		LuaEvents.GovernorAssignmentChooser_RequestAssignment( governorID );
		Close();
	end
end

-- ===========================================================================
function OnAppointGovernor(eGovernor:number)
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = eGovernor;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.APPOINT_GOVERNOR, kParameters);

		Refresh();
	end
end

-- ===========================================================================
function OnAssignToCity(eGovernor:number, cityID:number)
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = eGovernor;
		kParameters[PlayerOperations.PARAM_CITY_DEST] = cityID;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.ASSIGN_GOVERNOR, kParameters);
	end
end

-- ===========================================================================
function OnPromoteGovernor(eGovernor:number, ePromotion:number)
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = eGovernor;
		kParameters[PlayerOperations.PARAM_GOVERNOR_PROMOTION_TYPE] = ePromotion;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.PROMOTE_GOVERNOR, kParameters);
	end
end


-- ===========================================================================
function OnToggleGovernorPanel(playerID:number, cityID:number)
	if ContextPtr:IsHidden() then
		Open(playerID, cityID);
	else
		Close();
	end
end

-- ===========================================================================
function OnProcessNotification(playerID:number, notificationID:number, activatedByUser:boolean)
	if playerID == Game.GetLocalPlayer() then -- Was it for us?
		local pNotification = NotificationManager.Find(playerID, notificationID);
		if (pNotification) then
			if (pNotification:GetType() == m_GovernorApptAvailableHash or
				pNotification:GetType() == m_GovernorOpportunityAvailableHash or
				pNotification:GetType() == m_GovernorPromotionAvailableHash) then
				-- Open/refresh Governor Panel when we catch a governor notification
				Open();
			end
		end
	end
end

-- ===========================================================================
function OnProcessTurnBlocker( pNotification:table)
	if (pNotification ~= nil) then
		if (pNotification:GetPlayerID() ~= Game.GetLocalPlayer()) then
			return;
		end

		local notificationType = pNotification:GetType();

		if (pNotification:GetType() == m_GovernorApptAvailableHash or
			pNotification:GetType() == m_GovernorOpportunityAvailableHash or
			pNotification:GetType() == m_GovernorPromotionAvailableHash) then
			-- Open/refresh Governor Panel when we catch a governor notification
			Open();
		end
	end
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload then		
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );	
	end
end

-- =======================================================================================
--	UI Event
-- =======================================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", ContextPtr:IsVisible());
end

-- ===========================================================================
--	LUA Event
--	Set cached values back after a hotload.
-- ===========================================================================s
function OnGameDebugReturn( context:string, contextTable:table )
	if context ~= RELOAD_CACHE_ID then
		return;
	end

	if contextTable["isVisible"] then
		ContextPtr:SetHide(not contextTable["isVisible"]);
	end

	Refresh();
end

-- ===========================================================================
--	UI Input Event Handler
-- ===========================================================================
function OnInputHandler( pInputStruct:table )

	if ContextPtr:IsHidden() then return; end

	local key = pInputStruct:GetKey();
	local msg = pInputStruct:GetMessageType();
	if msg == KeyEvents.KeyUp and key == Keys.VK_ESCAPE then 
		Close();
		return true;
	end;
	return false;
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if GameConfiguration.IsHotseat() and ContextPtr:IsVisible() then
		Close();
	end
end

-- ===========================================================================
function OnGovernorAssigned(cityPlayer, cityID, ePlayer, eGovernor)

	if ContextPtr:IsVisible() and ePlayer == Game.GetLocalPlayer() then
		Refresh();
	end
end

-- ===========================================================================
function OnGovernorChanged(ePlayer, eGovernor)

	if ContextPtr:IsVisible() and ePlayer == Game.GetLocalPlayer() then
		Refresh();
	end	
end

-- ===========================================================================
function OnGovernorPointsChanged(ePlayer, iPointDelta)

	if ContextPtr:IsVisible() and ePlayer == Game.GetLocalPlayer() then
		Refresh();
	end	
end

-- ===========================================================================
function OnGovernorPromoted(ePlayer, eGovernor, ePromotion)

	if ContextPtr:IsVisible() and ePlayer == Game.GetLocalPlayer() then
		Refresh();
	end	
end

-- ===========================================================================
function OnLocalPlayerTurnBegin()

	if ContextPtr:IsVisible() then
		Refresh();
	end	
end

-- ===========================================================================
function Initialize()

	-- Start off hidden
	ContextPtr:SetHide(true);
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );

	-- Lua Events
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );

	-- GAME EVENTS --
	Events.GovernorAppointed.Add( OnGovernorAppointed );
	Events.GovernorAssigned.Add( OnGovernorAssigned );
	Events.GovernorChanged.Add( OnGovernorChanged );
	Events.GovernorPointsChanged.Add( OnGovernorPointsChanged );
	Events.GovernorPromoted.Add( OnGovernorPromoted );
	Events.NotificationActivated.Add(OnProcessNotification);
	Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin );	
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );	


	-- UI EVENTS --
	LuaEvents.GovernorPanel_Toggle.Add( OnToggleGovernorPanel );
	LuaEvents.GovernorPanel_Close.Add( Close );
	LuaEvents.GovernorPanel_Open.Add( Open );
	LuaEvents.GovernorPanel_CancelAssignment.Add( Open );
	LuaEvents.GovernorPanel_ClosedDetails.Add( Open );
	LuaEvents.GovernorPanel_AssignDetails.Add( Close );

	LuaEvents.ActionPanel_ActivateNotification.Add(	OnProcessTurnBlocker );

	Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, Close);

	m_TopPanelConsideredHeight = Controls.Vignette:GetSizeY() - TOP_PANEL_OFFSET;
	
	Refresh();
end
if HasCapability("CAPABILITY_GOVERNORS") then
	Initialize();
end

