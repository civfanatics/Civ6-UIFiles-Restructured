--	DeclareWarPopup
--	Triggered by walking into enemy territory. WorldInput.lua - MoveUnitToPlot
include( "InstanceManager" );
include( "DiplomacyStatementSupport" );
include( "SupportFunctions" );				--DarkenLightenColor
include( "Colors" );


--	******************************************************************************************************
--	GLOBALS
--	******************************************************************************************************
g_ConsequenceItemIM = InstanceManager:new( "ConsequenceItem",  "Root" );

--	******************************************************************************************************
--	CONSTANTS
--	******************************************************************************************************
local MIN_HEIGHT = 200;
local CONSEQUENCE_TYPES = {WARMONGER = 1, DEFENSIVE_PACT = 2, CITY_STATE = 3, TRADE_ROUTE = 4, DEALS = 5 };

--	******************************************************************************************************
--	MEMBERS
--	******************************************************************************************************
local m_TargetCivIM:table = InstanceManager:new( "TargetCivilization", "Root", Controls.Targets);

--	******************************************************************************************************
--	FUNCTIONS
--	******************************************************************************************************
function OnClose()
	Controls.ConsequencesStack:SetHide(true);
	Controls.WarmongerContainer:SetHide(true);
	Controls.DefensivePactContainer:SetHide(true);
	Controls.CityStateContainer:SetHide(true);
	Controls.TradeRouteContainer:SetHide(true);
	Controls.DealsContainer:SetHide(true);
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function CanDeclareWar(eDefendingPlayer:number)
	local pPlayerConfig:table = PlayerConfigurations[eDefendingPlayer];
	return pPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
end
-- ===========================================================================
function DeclareWar(eAttackingPlayer:number, eDefendingPlayer:number, eWarType:number)
	
	if CanDeclareWar(eDefendingPlayer) then

		if (eWarType == WarTypes.SURPRISE_WAR) then 
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_SURPRISE_WAR");
			
		elseif (eWarType == WarTypes.FORMAL_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_FORMAL_WAR");
				
		elseif (eWarType == WarTypes.HOLY_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_HOLY_WAR");
				
		elseif (eWarType == WarTypes.LIBERATION_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_LIBERATION_WAR");
			
		elseif (eWarType == WarTypes.RECONQUEST_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_RECONQUEST_WAR");
			
		elseif (eWarType == WarTypes.PROTECTORATE_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_PROTECTORATE_WAR");
			
		elseif (eWarType == WarTypes.COLONIAL_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_COLONIAL_WAR");
			
		elseif (eWarType == WarTypes.TERRITORIAL_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_TERRITORIAL_WAR");

		else
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_SURPRISE_WAR");
		end

	else
		local parameters :table = {};
		parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = eAttackingPlayer;
		parameters[ PlayerOperations.PARAM_PLAYER_TWO ] = eDefendingPlayer;
		UI.RequestPlayerOperation(eAttackingPlayer, PlayerOperations.DIPLOMACY_DECLARE_WAR, parameters);
		UI.PlaySound("Notification_War_Declared");
	end
end

-- This is necessary to maintain backwards compatibility since the signature for the OnShow function changed
function OnShowSingleTarget(eAttackingPlayer:number, eDefendingPlayer:number, eWarType:number, confirmCallbackFn)
	OnShow(eAttackingPlayer, {eDefendingPlayer}, eWarType, confirmCallbackFn);
end

function OnShow(eAttackingPlayer:number, kDefendingPlayers:table, eWarType:number, confirmCallbackFn)

	local pAttacker = Players[eAttackingPlayer];

	-- By default, confirming will do the DeclareWar function we define here. But client could pass in a custom function to call instead (ex. WMDs and ICBMs, which declare war differently).
	if (confirmCallbackFn == nil) then
		confirmCallbackFn = function()
			for i, eDefendingPlayer in ipairs(kDefendingPlayers) do
				DeclareWar(eAttackingPlayer, eDefendingPlayer, eWarType);
			end
		end
	end
	
	-- Populate targets
	local iWarmongerPoints = -1;
	m_TargetCivIM:ResetInstances();
	
--for i=1, 3 do -- DEBUG
	for i, eDefendingPlayer in ipairs(kDefendingPlayers) do
		local kParams = {};
		kParams.WarState = eWarType;
		bSuccess, tResults = DiplomacyManager.TestAction(eFromPlayer, eDefendingPlayer, DiplomacyActionTypes.SET_WAR_STATE, kParams);

		local tmp = pAttacker:GetDiplomacy():ComputeDOWWarmongerPoints(eDefendingPlayer, kParams.WarState);
		iWarmongerPoints = math.min(tmp, iWarmongerPoints); -- These are negative, pick the worst penalty and go with it

		PopulateTargetInstance(m_TargetCivIM:GetInstance(), eDefendingPlayer);
	end
--end -- END DEBUG

	Controls.WarConfirmAlpha:SetToBeginning();
	Controls.WarConfirmAlpha:Play();
	Controls.WarConfirmSlide:SetToBeginning();
	Controls.WarConfirmSlide:Play();
	Controls.Yes:RegisterCallback(Mouse.eLClick, function() confirmCallbackFn(); OnClose(); end);
	Controls.Message:SetText(Locale.Lookup("LOC_DIPLO_WARNING_DECLARE_WAR_FROM_UNIT_ATTACK_INFO_MULTIPLE"));

	-- Populate warmonger consequences
	g_ConsequenceItemIM:ResetInstances();
	local consequenceItem = g_ConsequenceItemIM:GetInstance(Controls.WarmongerStack);
	local szWarmongerLevel = pAttacker:GetDiplomacy():GetWarmongerLevel(-iWarmongerPoints);
	consequenceItem.Text:SetText(Locale.Lookup("LOC_DIPLO_CHOICE_WARMONGER_INFO", szWarmongerLevel));

	-- Calculate size
	Controls.Targets:CalculateSize();
	Controls.Contents:CalculateSize();

	-- Show
	Controls.Window:SetSizeY(MIN_HEIGHT + Controls.Contents:GetSizeY() + 10);
	Controls.WarmongerContainer:SetHide(false);
	Controls.ConsequencesStack:SetHide(false);
	ContextPtr:SetHide(false);
	Resize();
end

function PopulateTargetInstance(controls, ePlayer)
	
	local playerName : string;
	local pPlayerCfg = PlayerConfigurations[ePlayer];
	if(GameConfiguration.IsAnyMultiplayer() and pPlayerCfg:IsHuman()) then
		playerName = Locale.Lookup( pPlayerCfg:GetCivilizationShortDescription() ) .. " (" .. pPlayerCfg:GetPlayerName() .. ")";
	else
		playerName = pPlayerCfg:GetCivilizationShortDescription();
	end
	
	local iconName = "ICON_"..pPlayerCfg:GetCivilizationTypeName();

	local backColor, frontColor = UI.GetPlayerColors( ePlayer );
	local darkerBackColor = UI.DarkenLightenColor(backColor,(-85),238);
	local brighterBackColor = UI.DarkenLightenColor(backColor,90,255);
	controls.CivIcon:SetIcon(iconName);
	controls.CircleBacking:SetColor(backColor);
	controls.CircleDarker:SetColor(darkerBackColor);
	controls.CircleLighter:SetColor(brighterBackColor);
	controls.CivIcon:SetColor(frontColor);
	
	if controls.TargetName then
		controls.TargetName:SetText(Locale.Lookup(playerName));
	end

	controls.PulseAnim:SetToBeginning();
	controls.PulseAnim:Play();

	return playerName;
end

--	Handle screen resize/ dynamic popup height
function Resize()
	Controls.DropShadow:SetSizeY(Controls.Window:GetSizeY()+50);
	Controls.DropShadow:ReprocessAnchoring();
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE then
		OnClose();
		return true;
	end

	return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end

function Initialize()
	ContextPtr:SetInputHandler( OnInputHandler, true );
	Controls.No:RegisterCallback( Mouse.eLClick, OnClose );
	LuaEvents.DiplomacyActionView_ConfirmWarDialog.Add(OnShowSingleTarget);
	LuaEvents.CityStates_ConfirmWarDialog.Add(OnShowSingleTarget);
	LuaEvents.Civ6Common_ConfirmWarDialog.Add(OnShowSingleTarget);
	-- below is wrapped in an anonymous function so it can be overriden in expansion content
	LuaEvents.WorldInput_ConfirmWarDialog.Add(function(eAttackingPlayer:number, kDefendingPlayers:table, eWarType:number, confirmCallbackFn) OnShow(eAttackingPlayer, kDefendingPlayers, eWarType, confirmCallbackFn) end);
	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.LocalPlayerTurnEnd.Add( OnClose );
	Resize();
end
Initialize();