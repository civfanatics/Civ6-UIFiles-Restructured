-- ===========================================================================
-- Diplomacy Trade View Manager
-- ===========================================================================
include( "InstanceManager" );
include( "Colors" );
include( "Civ6Common" ); -- AutoSizeGridButton
include( "SupportFunctions" );
include( "PopupDialog" );
include( "ToolTipHelper_PlayerYields" );
include( "CivilizationIcon" );
include( "GreatWorksSupport" );


-- ===========================================================================
--	Globals
-- ===========================================================================
g_LocalPlayer =	nil;
g_OtherPlayer =	nil;
g_AvailableGroups = {};
g_IconOnlyIM = InstanceManager:new( "IconOnly",  "SelectButton", Controls.IconOnlyContainer );
g_IconAndTextIM	= InstanceManager:new( "IconAndText",  "SelectButton", Controls.IconAndTextContainer );
g_ValueEditDealItemID = -1;		-- The ID of the deal item that is being value edited.
g_ValueEditDealItemControlTable = nil; -- The control table of the deal item that is being edited.

-- These are initialized in CreateGroupTypes
DealItemGroupTypes = nil;
AvailableDealItemGroupTypes = nil;

g_uiMyOffers = {};
g_uiTheirOffers = {};

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local ms_PlayerPanelIM		:table		= InstanceManager:new( "PlayerAvailablePanel",  "Root" );
local ms_LeftRightListIM	:table		= InstanceManager:new( "LeftRightList",  "List", Controls.LeftRightListContainer );
local ms_TopDownListIM		:table		= InstanceManager:new( "TopDownList",  "List", Controls.TopDownListContainer );
local ms_AgreementOptionIM	:table		= InstanceManager:new( "AgreementOptionInstance",  "AgreementOptionButton", Controls.ValueEditStack );
local ms_CityDetailsIM		:table		= InstanceManager:new( "CityIconAndDetails", "CityDetailsContainer", Controls.IconAndTextContainer );
local ms_MinimizedSectionIM :table		= InstanceManager:new( "MinimizedSection","MinimizedSectionContainer" );

local OTHER_PLAYER = 0;
local LOCAL_PLAYER = 1;

ms_OtherPlayerID =	-1;
local ms_OtherPlayerIsHuman = false;

ms_InitiatedByPlayerID = -1;

ms_bIsGift = false;
ms_bIsDemand = false;
local ms_bExiting = false;

local ms_LastIncomingDealProposalAction = DealProposalAction.PENDING;

local m_kPopupDialog			:table; -- Will use custom "popup" since in leader mode the Popup stack is disabled.

local ms_DealGroups = {};

local ms_DealAgreementsGroup = {};

local ms_DefaultOneTimeGoldAmount = 100;

local ms_DefaultMultiTurnGoldAmount = 10;
local ms_DefaultMultiTurnGoldDuration = 30;

local ms_bForceUpdateOnCommit = false;

local ms_bDontUpdateOnBack = false;

local MAX_DEAL_ITEM_EDIT_HEIGHT = 300;

local m_kCollapsedCityDetails : table = {};

--Panel resizing variables
local m_StartingMouseX	: number;
local m_StartingMouseY	: number;
local m_OffersStartSizeY: number;
local m_InvStartSizeY	: number;

local m_MaxDragResizeY : number = 81;
local m_MinDragResizeY : number = 193; -- Will be dynamically set to account for different resolutions

-- ===========================================================================
function SetIconToSize(iconControl, iconName, iconSize)
	if iconSize == nil then
		iconSize = 50;
	end
	local x, y, szIconName, iconSize = IconManager:FindIconAtlasNearestSize(iconName, iconSize, true);
	iconControl:SetTexture(x, y, szIconName);
	iconControl:SetSizeVal(iconSize, iconSize);
end

-- ===========================================================================
function InitializeDealGroups()

	for i = 1, table.count(AvailableDealItemGroupTypes), 1 do
		g_AvailableGroups[i] = {};
	end

	for i = 1, table.count(DealItemGroupTypes), 1 do
		ms_DealGroups[i] = {};
	end

end

-- ===========================================================================
function GetPlayerType(player : table)
	if (player:GetID() == g_LocalPlayer:GetID()) then
		return LOCAL_PLAYER;
	end

	return OTHER_PLAYER;
end

-- ===========================================================================
function GetPlayerOfType(playerType : number)
	if (playerType == LOCAL_PLAYER) then
		return g_LocalPlayer;
	end

	return g_OtherPlayer;
end

-- ===========================================================================
function GetOtherPlayer(player : table)
	if (player ~= nil and player:GetID() == g_OtherPlayer:GetID()) then
		return g_LocalPlayer;
	end

	return g_OtherPlayer;
end

-- ===========================================================================
function SetDefaultLeaderDialogText()
	if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		SetLeaderDialog("LOC_DIPLO_DEMAND_INTRO", "");
	else
		SetLeaderDialog("LOC_DIPLO_DEAL_INTRO", "");
	end
end

-- ===========================================================================
function ProposeWorkingDeal(bIsAutoPropose : boolean)
	if (bIsAutoPropose == nil) then
		bIsAutoPropose = false;
	end

	if (not DealManager.HasPendingDeal(g_LocalPlayer:GetID(), g_OtherPlayer:GetID())) then
		if (ms_bIsDemand) then
			DealManager.SendWorkingDeal(DealProposalAction.DEMANDED, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		else
			if (bIsAutoPropose) then
				DealManager.SendWorkingDeal(DealProposalAction.INSPECT, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
			else
				DealManager.SendWorkingDeal(DealProposalAction.PROPOSED, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
			end
		end
	end
end

-- ===========================================================================
function RequestEqualizeWorkingDeal()
	if (not DealManager.HasPendingDeal(g_LocalPlayer:GetID(), g_OtherPlayer:GetID())) then
		DealManager.SendWorkingDeal(DealProposalAction.EQUALIZE, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	end
end

-- ===========================================================================
function DealIsEmpty()
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal == nil or pDeal:GetItemCount() == 0) then
		return true;
	end

	return false;
end

-- ===========================================================================
-- Update the proposed working deal.  This is called as items are changed in the deal.
-- It is primarily used to 'auto-propose' the deal when working with an AI.
function UpdateProposedWorkingDeal()
	if (ms_LastIncomingDealProposalAction ~= DealProposalAction.PENDING or IsAutoPropose()) then 

		local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		if (pDeal == nil or pDeal:GetItemCount() == 0 or ms_bIsDemand) then
			-- Is a demand or no items, restart
			ms_LastIncomingDealProposalAction = DealProposalAction.PENDING;
			UpdateDealStatus();
		else
			if (IsAutoPropose()) then
				ProposeWorkingDeal(true);
			end
		end
	end
end

-- ===========================================================================
function UpdateOtherPlayerText(otherPlayerSays)
	local bHide = true;
	if (g_OtherPlayer ~= nil and otherPlayerSays ~= nil) then
		local playerConfig = PlayerConfigurations[g_OtherPlayer:GetID()];
		if (playerConfig ~= nil) then
			-- leader icon
			local otherPlayerController = CivilizationIcon:AttachInstance(Controls.OtherPlayerBubbleIcon);
			otherPlayerController:UpdateIconFromPlayerID(g_OtherPlayer:GetID());

			-- Set the leader name
			local leaderDesc = playerConfig:GetLeaderName();
			Controls.OtherPlayerBubbleName:SetText(Locale.ToUpper(Locale.Lookup("LOC_DIPLOMACY_DEAL_OTHER_PLAYER_SAYS", leaderDesc)));
		end
	end
	-- When we get dialog for what the leaders say during a trade, we can add it here!
end

-- ===========================================================================
function OnToggleCollapseGroup(iconList : table)
	if (iconList.ListStack:IsHidden()) then
		iconList.ListStack:SetHide(false);
	else
		iconList.ListStack:SetHide(true);
	end

	iconList.List:CalculateSize();
end
-- ===========================================================================
function CreateHorizontalGroup(rootStack : table, title : string)
	local iconList = ms_LeftRightListIM:GetInstance(rootStack);
	if (title == nil or title == "") then
		iconList.Title:SetHide(true);		-- No title
	else
		iconList.TitleText:LocalizeAndSetText(title);
	end
	iconList.List:CalculateSize();

	return iconList;
end

-- ===========================================================================
function CreateVerticalGroup(rootStack : table, title : string)
	local iconList = ms_TopDownListIM:GetInstance(rootStack);
	if (title == nil or title == "") then
		iconList.Title:SetHide(true);		-- No title
	else
		iconList.TitleText:LocalizeAndSetText(title);
	end
	iconList.List:CalculateSize();

	return iconList;
end


-- ===========================================================================
function CreatePlayerAvailablePanel(playerType : number, rootControl : table)

	--local playerPanel = ms_PlayerPanelIM:GetInstance(rootControl);

	g_AvailableGroups[AvailableDealItemGroupTypes.GOLD][playerType]				= g_AvailableGroups[AvailableDealItemGroupTypes.FAVOR][playerType];
	g_AvailableGroups[AvailableDealItemGroupTypes.LUXURY_RESOURCES][playerType]	= CreateHorizontalGroup(rootControl, "LOC_DIPLOMACY_DEAL_LUXURY_RESOURCES");
	g_AvailableGroups[AvailableDealItemGroupTypes.STRATEGIC_RESOURCES][playerType] = CreateHorizontalGroup(rootControl, "LOC_DIPLOMACY_DEAL_STRATEGIC_RESOURCES");
	g_AvailableGroups[AvailableDealItemGroupTypes.AGREEMENTS][playerType]			= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_AGREEMENTS");
	g_AvailableGroups[AvailableDealItemGroupTypes.CITIES][playerType]				= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_CITIES");
	g_AvailableGroups[AvailableDealItemGroupTypes.OTHER_PLAYERS][playerType]		= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_OTHER_PLAYERS");
	g_AvailableGroups[AvailableDealItemGroupTypes.GREAT_WORKS][playerType]			= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_GREAT_WORKS");
	g_AvailableGroups[AvailableDealItemGroupTypes.CAPTIVES][playerType]			= CreateVerticalGroup(rootControl, "LOC_DIPLOMACY_DEAL_CAPTIVES");

	rootControl:CalculateSize();

	return playerPanel;
end

-- ===========================================================================
function CreatePlayerDealPanel(playerType : number, rootControl : table)
--This creates the containers for the offer area...
	--ms_DealGroups[DealItemGroupTypes.RESOURCES][playerType]	= CreateHorizontalGroup(rootControl);
	--ms_DealGroups[DealItemGroupTypes.AGREEMENTS][playerType]	= CreateVerticalGroup(rootControl);
	--**********************************************************************
	-- Currently putting them all in the same control.
	ms_DealGroups[DealItemGroupTypes.RESOURCES][playerType] = rootControl;
	ms_DealGroups[DealItemGroupTypes.AGREEMENTS][playerType] = rootControl;
	ms_DealGroups[DealItemGroupTypes.CITIES][playerType] = rootControl;
	ms_DealGroups[DealItemGroupTypes.GREAT_WORKS][playerType] = rootControl;
	ms_DealGroups[DealItemGroupTypes.CAPTIVES][playerType] = rootControl;

end

-- ===========================================================================
function OnValuePulldownCommit(forType)

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		local pDealItem = pDeal:FindItemByID(g_ValueEditDealItemID);
		if (pDealItem ~= nil) then
			pDealItem:SetValueType( forType );
			
			local valueName = pDealItem:GetValueTypeNameID();
			if (g_ValueEditDealItemControlTable ~= nil) then
				-- Keep the text on the icon, that is currently hidden, up to date too.
				g_ValueEditDealItemControlTable.ValueText:LocalizeAndSetText(pDealItem:GetValueTypeNameID(valueName));
			end

			UpdateDealStatus();
			UpdateProposedWorkingDeal();
		end
	end

	Controls.ValueEditPopupBackground:SetHide(true);

end

-- ===========================================================================
function SetValueText(uiIcon, pDealItem)

	if (uiIcon.ValueText ~= nil) then
		local valueName = pDealItem:GetValueTypeNameID();
		if (valueName == nil) then
			if (pDealItem:HasPossibleValues()) then
				valueName = "LOC_DIPLOMACY_DEAL_CLICK_TO_CHANGE_DEAL_PARAMETER";
			end
		end
		if (valueName ~= nil) then
			uiIcon.ValueText:LocalizeAndSetText(valueName);
			uiIcon.ValueText:SetHide(false);
		else
			uiIcon.ValueText:SetHide(true);
		end
	end
end

-- ===========================================================================
function CreatePanels()

	-- Create the Other Player Panels
	CreatePlayerAvailablePanel(OTHER_PLAYER, Controls.TheirInventoryStack);

	-- Create the Local Player Panels
	CreatePlayerAvailablePanel(LOCAL_PLAYER, Controls.MyInventoryStack);

	CreatePlayerDealPanel(OTHER_PLAYER, g_uiTheirOffers);
	CreatePlayerDealPanel(LOCAL_PLAYER, g_uiMyOffers);

	Controls.EqualizeDeal:RegisterCallback( Mouse.eLClick, OnEqualizeDeal );
	Controls.EqualizeDeal:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AcceptDeal:RegisterCallback( Mouse.eLClick, OnProposeOrAcceptDeal );
	Controls.AcceptDeal:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.DemandDeal:RegisterCallback( Mouse.eLClick, OnProposeOrAcceptDeal );
	Controls.DemandDeal:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.RefuseDeal:RegisterCallback(Mouse.eLClick, OnRefuseDeal);
	Controls.RefuseDeal:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ResumeGame:RegisterCallback(Mouse.eLClick, OnResumeGame);
	Controls.ResumeGame:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

end

function CreateGroupTypes()
	AvailableDealItemGroupTypes = {
	    GOLD                    = 1,
	    LUXURY_RESOURCES        = 2,
	    STRATEGIC_RESOURCES			= 3,
	    AGREEMENTS              = 4,
	    CITIES                  = 5,
	    OTHER_PLAYERS           = 6,
	    GREAT_WORKS             = 7,
	    CAPTIVES                = 8,
	};

	DealItemGroupTypes = {
	    GOLD                    = 1,
	    RESOURCES								= 2,
	    AGREEMENTS							= 3,
	    CITIES									= 4,
	    GREAT_WORKS							= 5,
	    CAPTIVES								= 6
	};
end

-- ===========================================================================
-- Find the 'instance' table from the control
function FindIconInstanceFromControl(rootControl : table)

	if (rootControl ~= nil) then
		local controlTable = g_IconOnlyIM:FindInstanceByControl(rootControl);
		if (controlTable == nil) then
			controlTable = g_IconAndTextIM:FindInstanceByControl(rootControl);
		end

		return controlTable;
	end

	return nil;
end

-- ===========================================================================
-- Show or hide the "amount text" or the "Value Text" sub-control of the supplied control instance
function SetHideValueText(controlTable : table, bHide : boolean)

	if (controlTable ~= nil) then
		if (controlTable.AmountText ~= nil) then
			controlTable.AmountText:SetHide(bHide);
		end
		if (controlTable.ValueText ~= nil) then
			controlTable.ValueText:SetHide(bHide);
		end
	end
end

-- ===========================================================================
-- Detach the value edit overlay from anything it is attached to.
function ClearValueEdit()

	SetHideValueText(g_ValueEditDealItemControlTable, false);

	g_ValueEditDealItemControlTable = nil
	g_ValueEditDealItemID = -1;

end

-- ===========================================================================
function UpdateDealStatus()
	local bDealValid = false;
	ClearValueEdit();
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then
		if (pDeal:GetItemCount() > 0) then
			bDealValid = true;
		end
	end

	if (bDealValid) then
		if pDeal:Validate() ~= DealValidationResult.VALID then
			bDealValid = false;
		end
	end

	Controls.EqualizeDeal:SetHide(ms_bIsDemand);

	-- Have we sent out a deal?
	local bHasPendingDeal = DealManager.HasPendingDeal(g_LocalPlayer:GetID(), g_OtherPlayer:GetID());

	if (not bHasPendingDeal and ms_LastIncomingDealProposalAction == DealProposalAction.PENDING) then
		-- We have yet to send out a deal.
		Controls.AcceptDeal:SetHide(true);
		local showDemand = bDealValid and ms_bIsDemand;
		Controls.DemandDeal:SetHide(not showDemand);
	else	
		local cantAccept = (ms_LastIncomingDealProposalAction ~= DealProposalAction.ACCEPTED and ms_LastIncomingDealProposalAction ~= DealProposalAction.PROPOSED and ms_LastIncomingDealProposalAction ~= DealProposalAction.ADJUSTED) or not bDealValid or bHasPendingDeal;
		Controls.AcceptDeal:SetHide(cantAccept);
		if (ms_bIsDemand) then
			if (g_LocalPlayer:GetID() == ms_InitiatedByPlayerID) then
				-- Local human is making a demand
				if (ms_LastIncomingDealProposalAction == DealProposalAction.ACCEPTED) then
					Controls.DemandDeal:SetHide(cantAccept);
					-- The other player has accepted the demand, but we must enact it.
					-- We won't have the human need to press the accept button, just do it and exit.
					OnProposeOrAcceptDeal();
					return;
				else
					Controls.AcceptDeal:SetHide(true);
					Controls.DemandDeal:SetHide(false);
				end
			else
				Controls.DemandDeal:SetHide(true);
			end
		else
			Controls.DemandDeal:SetHide(true);
		end
	end
	-- Hide/show directions if either side has no items
	local itemsFromLocal : number = pDeal:GetItemCount(g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local itemsFromOther : number = pDeal:GetItemCount(g_OtherPlayer:GetID(), g_LocalPlayer:GetID());
	g_uiMyOffers.DirectionsBracket:SetHide( itemsFromLocal > 0);
	g_uiTheirOffers.DirectionsBracket:SetHide( itemsFromOther > 0);

	UpdateProposalButtons(bDealValid);

	ResizeDealAndButtons();
end

-- ===========================================================================
function ResizeDealAndButtons()

	-- Find the widest deal button text and size others to match
	local refuseX, refuseY = AutoSizeGridButton(Controls.RefuseDeal,200,32,10,"1");
	local equalizeX, equalizeY = AutoSizeGridButton(Controls.EqualizeDeal,200,32,10,"1");
	local acceptX, acceptY = AutoSizeGridButton(Controls.AcceptDeal,200,41,10,"1");

	local minX = refuseX;
	if not Controls.EqualizeDeal:IsHidden() and minX < equalizeX then
		minX = equalizeX;
	end
	if not Controls.AcceptDeal:IsHidden() and minX < acceptX then
		minX = acceptX;
	end

	if Controls.RefuseDeal:GetSizeX() < minX then
		Controls.RefuseDeal:SetSizeX(minX);
	end
	if Controls.EqualizeDeal:GetSizeX() < minX then
		Controls.EqualizeDeal:SetSizeX(minX);
	end
	if Controls.AcceptDeal:GetSizeX() < minX then
		Controls.AcceptDeal:SetSizeX(minX);
	end

	Controls.DealOptionsStack:CalculateSize();

	g_uiTheirOffers.OfferStack:CalculateSize();
	Controls.TheirOfferScroll:CalculateSize();

	g_uiMyOffers.OfferStack:CalculateSize();
	Controls.MyOfferScroll:CalculateSize();
end

-- ===========================================================================
-- The Human has ask to have the deal equalized.  Well, what the AI is 
-- willing to take.
function OnEqualizeDeal()
	ClearValueEdit();
	RequestEqualizeWorkingDeal();
end

-- ===========================================================================
-- Propose the deal, if this is the first time, or accept it, if the other player has
-- accepted it.
function OnProposeOrAcceptDeal()

	ClearValueEdit();

	if (ms_LastIncomingDealProposalAction == DealProposalAction.PENDING or
		ms_LastIncomingDealProposalAction == DealProposalAction.REJECTED or 
		ms_LastIncomingDealProposalAction == DealProposalAction.EQUALIZE_FAILED) then
		ProposeWorkingDeal();
		UpdateDealStatus();
		UI.PlaySound("Confirm_Bed_Positive");
	else		
		if (ms_LastIncomingDealProposalAction == DealProposalAction.ACCEPTED or ms_LastIncomingDealProposalAction == DealProposalAction.PROPOSED or ms_LastIncomingDealProposalAction == DealProposalAction.ADJUSTED) then
			-- Any adjustments?
			if (DealManager.AreWorkingDealsEqual(g_LocalPlayer:GetID(), g_OtherPlayer:GetID())) then
				-- Yes, we can accept
				-- if deal will trigger war, prompt user before confirming deal
				local sendDealAndContinue = function() 
					-- Send the deal.  This will also send out a POSITIVE response statement
					DealManager.SendWorkingDeal(DealProposalAction.ACCEPTED, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());		
					OnContinue();
					UI.PlaySound("Confirm_Bed_Positive");
				end;

				local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
				local pJointWarItem = pDeal:FindItemByType(DealItemTypes.AGREEMENTS, DealAgreementTypes.JOINT_WAR);
				if DealAgreementTypes.JOINT_WAR and pJointWarItem then
					local iWarType = pJointWarItem:GetParameterValue("WarType");

					if (iWarType == nil) then iWarType = WarTypes.FORMAL_WAR; end

					local targetPlayerID = pJointWarItem:GetValueType();
					if (targetPlayerID >= 0) then
						LuaEvents.DiplomacyActionView_ConfirmWarDialog(g_LocalPlayer:GetID(), targetPlayerID, iWarType, sendDealAndContinue);
					else
						UI.DataError("Invalid Player ID to declare Joint War to: " .. targetPlayerID);
					end
				else
					local pThirdPartyWarItem = pDeal:FindItemByType(DealItemTypes.AGREEMENTS, DealAgreementTypes.THIRD_PARTY_WAR);
					if (DealAgreementTypes.THIRD_PARTY_WAR and pThirdPartyWarItem) then
						local iWarType = pThirdPartyWarItem:GetParameterValue("WarType");

						if (iWarType == nil) then iWarType = WarTypes.FORMAL_WAR; end

						local targetPlayerID = pThirdPartyWarItem:GetValueType();
						if (targetPlayerID >= 0) then
							LuaEvents.DiplomacyActionView_ConfirmWarDialog(g_LocalPlayer:GetID(), targetPlayerID, iWarType, sendDealAndContinue);
						else
							UI.DataError("Invalid Player ID to declare Third Party War to: " .. targetPlayerID);
						end
					else
						sendDealAndContinue();
					end			
				end	
			else
				-- No, send an adjustment and stay in the deal view.
				DealManager.SendWorkingDeal(DealProposalAction.ADJUSTED, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());		
				UpdateDealStatus();
			end
		end
	end
end

-- ===========================================================================
function OnRefuseDeal(bForceClose)

	if (bForceClose == nil) then
		bForceClose = false;
	end

	local localPlayerID : number = Game.GetLocalPlayer();
	local otherPlayerID : number = g_OtherPlayer:GetID();
	local bHasPendingDeal = DealManager.HasPendingDeal(localPlayerID, otherPlayerID);

	local sessionID = DiplomacyManager.FindOpenSessionID(localPlayerID, otherPlayerID);
	if (sessionID ~= nil) then
		if (not ms_OtherPlayerIsHuman and not bHasPendingDeal) then
			-- Refusing an AI's deal
			ClearValueEdit();

			if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
				-- AI started this, so tell them that we don't want the deal
				if (bForceClose == true) then
					-- Forcing the close, usually because the turn timer expired
					DealManager.SendWorkingDeal(DealProposalAction.REJECTED, localPlayerID, otherPlayerID);
					DiplomacyManager.CloseSession(sessionID);
					StartExitAnimation();
				else
					DiplomacyManager.AddResponse(sessionID, localPlayerID, "NEGATIVE");
				end
			else
				-- Else close the session
				DiplomacyManager.CloseSession(sessionID);
				StartExitAnimation();
			end
		else
			if (ms_OtherPlayerIsHuman) then
				if (bHasPendingDeal) then
					-- Canceling the deal with the other player.
					DealManager.SendWorkingDeal(DealProposalAction.CLOSED, localPlayerID, otherPlayerID);
				else
					if (ms_InitiatedByPlayerID ~= localPlayerID) then
						-- Refusing the deal with the other player.
						DealManager.SendWorkingDeal(DealProposalAction.REJECTED, localPlayerID, otherPlayerID);
					end
				end

				DiplomacyManager.CloseSession(sessionID);
				StartExitAnimation();
			end				
		end
	else
		-- We have lost our session!
		if (not ContextPtr:IsHidden()) then
			if (not ms_bExiting) then
				OnResumeGame();
			end
		end		
	end

end

-- ===========================================================================
function OnResumeGame()

	-- Exiting back to wait for a response
	ClearValueEdit();

	local sessionID = DiplomacyManager.FindOpenSessionID(Game.GetLocalPlayer(), g_OtherPlayer:GetID());
	if (sessionID ~= nil) then
		DiplomacyManager.CloseSession(sessionID);
	end

	-- Start the exit animation, it will call OnContinue when complete
	StartExitAnimation();
end

-- ===========================================================================
function OnExitFadeComplete()
	if(Controls.TradePanelFade:IsReversing()) then
		Controls.TradePanelFade:SetSpeed(2);
		Controls.TradePanelSlide:SetSpeed(2);

		OnContinue();
	end
end
Controls.TradePanelFade:RegisterEndCallback(OnExitFadeComplete);
-- ===========================================================================
-- Change the value number edit by a delta
function OnValueAmountEditDelta(dealItemID:number, delta:number)

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		local pDealItem = pDeal:FindItemByID(dealItemID);
		if (pDealItem ~= nil) then
			local iNewAmount = tonumber(Controls.ValueAmountEditBox:GetText() or 0) + delta;
			iNewAmount = clip(iNewAmount, 1, pDealItem:GetMaxAmount());
			Controls.ValueAmountEditBox:SetText(tostring(iNewAmount));
		end
	end
end

-- ===========================================================================
-- Detach the value edit if it is attached to the control
function DetachValueEdit(itemID: number)

	if (itemID == g_ValueEditDealItemID) then
		ClearValueEdit();
	end

end

-- ===========================================================================
function IsItemValueEditable(itemType: number)
	return itemType == DealItemTypes.GOLD or itemType == DealItemTypes.RESOURCES;
end

-- ===========================================================================
function GetItemTypeIcon(pDealItem: table)
	local itemType = pDealItem:GetType();
	if (itemType == DealItemTypes.GOLD) then
		return "ICON_YIELD_GOLD_5";
	elseif (itemType == DealItemTypes.RESOURCES) then
		local resourceType = pDealItem:GetValueType();
		local resourceDesc = GameInfo.Resources[resourceType];
		return "ICON_" .. resourceDesc.ResourceType;
	end
	return nil;
end

-- ===========================================================================
-- Reattach the value edit overlay to the control set it is editing.
function ReAttachValueEdit()

	if (g_ValueEditDealItemControlTable ~= nil) then

		SetHideValueText(g_ValueEditDealItemControlTable, true);

		-- Display the number in the value edit field
		local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		if (pDeal ~= nil) then

			local pDealItem = pDeal:FindItemByID(g_ValueEditDealItemID);
			if (pDealItem ~= nil) then

				local itemID = pDealItem:GetID();
				local itemType = pDealItem:GetType();
				if (IsItemValueEditable(itemType)) then
					-- Hide/show everything for GOLD and RESOURCE options
					ms_AgreementOptionIM:ResetInstances();
					Controls.ValueEditIconGrid:SetHide(false);
					Controls.ValueAmountEditBoxContainer:SetHide(false);

					local iDuration = pDealItem:GetDuration();

					Controls.ValueEditHeaderLabel:SetText(Locale.Lookup("LOC_DIPLOMACY_DEAL_HOW_MANY"));
			
					if (iDuration == 0) then
						---- One time
						Controls.ValueEditValueText:SetHide(true);
					else
						---- Multi-turn
						Controls.ValueEditValueText:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_FOR_TURNS", iDuration);
						Controls.ValueEditValueText:SetHide(false);
					end

					SetIconToSize(Controls.ValueEditIcon, GetItemTypeIcon(pDealItem));
		
					Controls.ValueEditAmountText:SetText(tostring(pDealItem:GetAmount()));
					Controls.ValueEditAmountText:SetHide(false);

					Controls.ValueAmountEditBox:SetText(tostring(pDealItem:GetAmount()));
					Controls.ValueEditButton:RegisterCallback( Mouse.eLClick, function() OnValueEditButton(itemID); end );
					Controls.ValueAmountEditLeftButton:RegisterCallback( Mouse.eLClick, function() OnValueAmountEditDelta(itemID, -1); end );
					Controls.ValueAmountEditRightButton:RegisterCallback( Mouse.eLClick, function() OnValueAmountEditDelta(itemID, 1); end );
				elseif (itemType == DealItemTypes.AGREEMENTS) then
					local subType = pDealItem:GetSubType();
					local iDuration = pDealItem:GetDuration();

					ShowAgreementOptionPopup(subType, iDuration, pDealItem:GetFromPlayerID());
				else
					-- The value of the item cannot be adjusted so don't show a popup
					return;
				end
			end
		end			

		Controls.ValueEditIconGrid:DoAutoSize();

		ResizeValueEditScrollPanel();

		Controls.ValueEditPopup:DoAutoSize();
		Controls.ValueEditPopupBackground:SetHide(false);
	end

end

-- ===========================================================================
-- Attach the value edit overlay to a control set.
function AttachValueEdit(rootControl : table, dealItemID : number)

	ClearValueEdit();

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		local pDealItem = pDeal:FindItemByID(dealItemID);
		if (pDealItem ~= nil) then
			-- Do we have something to edit?
			if (pDealItem:HasPossibleValues() or pDealItem:HasPossibleAmounts()) then
				-- Yes
				g_ValueEditDealItemControlTable = FindIconInstanceFromControl(rootControl);
				g_ValueEditDealItemID = dealItemID;

				ReAttachValueEdit();
			end
		end
	end

end

-- ===========================================================================
-- Update the deal panel for a player
function UpdateDealPanel(player)
	
	-- If we modify the deal without sending it to the AI then reset the status to PENDING
	ms_LastIncomingDealProposalAction = DealProposalAction.PENDING;

	UpdateDealStatus();

	PopulatePlayerDealPanel(g_uiTheirOffers, g_OtherPlayer);
	PopulatePlayerDealPanel(g_uiMyOffers, g_LocalPlayer);
	
	ResizeDealAndButtons();

end

-- ===========================================================================
function OnClickAvailableOneTimeGold(player, iAddAmount : number)

	if ((ms_bIsDemand == true or ms_bIsGift == true) and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		-- Can't modifiy demand that is not ours
		return;
	end

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		local pPlayerTreasury = player:GetTreasury();
		local bFound = false;
		
		-- Already there?
		local dealItems = pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, player:GetID());
		local pDealItem;
		if (dealItems ~= nil) then
			for i, pDealItem in ipairs(dealItems) do
				if (pDealItem:GetDuration() == 0) then
					-- Already have a one time gold.  Up the amount
					iAddAmount = pDealItem:GetAmount() + iAddAmount;
					iAddAmount = clip(iAddAmount, nil, pDealItem:GetMaxAmount());
					if (iAddAmount ~= pDealItem:GetAmount()) then
						pDealItem:SetAmount(iAddAmount);
						bFound = true;
						break;
					else
						return;		-- No change, just exit
					end
				end
			end
		end

		-- Doesn't exist yet, add it.
		if (not bFound) then

			-- Going to add anything?
			pDealItem = pDeal:AddItemOfType(DealItemTypes.GOLD, player:GetID());
			if (pDealItem ~= nil) then

				-- Set the duration, so the max amount calculation knows what we are doing
				pDealItem:SetDuration(0);

				-- Adjust the gold to our max
				iAddAmount = clip(iAddAmount, nil, pDealItem:GetMaxAmount());
				if (iAddAmount > 0) then
					pDealItem:SetAmount(iAddAmount);
					bFound = true;
				else
					-- It is empty, remove it.
					local itemID = pDealItem:GetID();
					pDeal:RemoveItemByID(itemID);
				end
			end
		end


		if (bFound) then
			UpdateProposedWorkingDeal();
			UpdateDealPanel(player);
		end
	end
end

-- ===========================================================================
function OnClickAvailableMultiTurnGold(player, iAddAmount : number, iDuration : number)

	if ((ms_bIsDemand == true or ms_bIsGift == true) and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		-- Can't modifiy demand that is not ours
		return;
	end

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		local pPlayerTreasury = player:GetTreasury();

		local bFound = false;
		UI.PlaySound("UI_GreatWorks_Put_Down");

		-- Already there?
		local dealItems = pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, player:GetID());
		local pDealItem;
		if (dealItems ~= nil) then
			for i, pDealItem in ipairs(dealItems) do
				if (pDealItem:GetDuration() ~= 0) then
					-- Already have a multi-turn gold.  Up the amount
					iAddAmount = pDealItem:GetAmount() + iAddAmount;
					iAddAmount = clip(iAddAmount, nil, pDealItem:GetMaxAmount());
					if (iAddAmount ~= pDealItem:GetAmount()) then
						pDealItem:SetAmount(iAddAmount);
						bFound = true;
						break;
					else
						return;		-- No change, just exit
					end
				end
			end
		end

		-- Doesn't exist yet, add it.
		if (not bFound) then
			-- Going to add anything?
			pDealItem = pDeal:AddItemOfType(DealItemTypes.GOLD, player:GetID());
			if (pDealItem ~= nil) then

				-- Set the duration, so the max amount calculation knows what we are doing
				pDealItem:SetDuration(iDuration);

				-- Adjust the gold to our max
				iAddAmount = clip(iAddAmount, nil, pDealItem:GetMaxAmount());

				if (iAddAmount > 0) then
					pDealItem:SetAmount(iAddAmount);
					bFound = true;
				else
					-- It is empty, remove it.
					local itemID = pDealItem:GetID();
					pDeal:RemoveItemByID(itemID);
				end
			end
		end

		if (bFound) then
			UpdateProposedWorkingDeal();
			UpdateDealPanel(player);
		end
	end
end

-- ===========================================================================
-- Clip val to be within the range of min and max
function clip(val: number, min: number, max: number)
	if min and val < min then
		val = min;
	elseif max and val > max then
		val = max;
	end
	return val;
end

-- ===========================================================================
-- Check to see if the deal should be auto-proposed.
function IsAutoPropose()
	if (not ms_OtherPlayerIsHuman) then
		local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		pDeal:Validate();
		if (pDeal ~= nil and not ms_bIsDemand and pDeal:IsValid() and not DealManager.HasPendingDeal(g_LocalPlayer:GetID(), g_OtherPlayer:GetID())) then
			local itemsFromLocal : number = pDeal:GetItemCount(g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
			local itemsFromOther : number = pDeal:GetItemCount(g_OtherPlayer:GetID(), g_LocalPlayer:GetID());

			if (itemsFromLocal > 0 or itemsFromOther > 0) then
				return true;
			end
		end
	end
	return false;
end

-- ===========================================================================
-- Check the state of the deal and show/hide the special proposal buttons for a possible gift (not actually possible until XP2)
function UpdateProposalButtonsForGift(itemsFromLocal : number, itemsFromOther : number)
	if (itemsFromLocal == 0 and itemsFromOther > 0) then
		return true;
	end

	return false;
end

-- ===========================================================================
-- Check the state of the deal and show/hide the special proposal buttons
function UpdateProposalButtons(bDealValid)

	local bDealIsPending : boolean = DealManager.HasPendingDeal(g_LocalPlayer:GetID(), g_OtherPlayer:GetID());

	if (bDealValid and (not bDealIsPending or not ms_OtherPlayerIsHuman)) then
		Controls.ResumeGame:SetHide(true);
		local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		Controls.EqualizeDeal:SetHide(ms_bIsDemand);
		if (pDeal ~= nil) then

			local itemsFromLocal : number = pDeal:GetItemCount(g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
			local itemsFromOther : number = pDeal:GetItemCount(g_OtherPlayer:GetID(), g_LocalPlayer:GetID());
			ms_bIsGift = pDeal:IsGift() and itemsFromOther > 0;

			if (not ms_bIsDemand) then
				if (not ms_OtherPlayerIsHuman) then
					-- Dealing with an AI
					if (pDeal:HasUnacceptableItems()) then
						Controls.EqualizeDeal:SetHide(true);
						Controls.AcceptDeal:SetHide(true);
						SetLeaderDialog("LOC_DIPLO_DEAL_UNACCEPTABLE_DEAL", "");
					elseif (itemsFromLocal > 0 and itemsFromOther == 0) then
						-- One way gift?

						if ms_LastIncomingDealProposalAction == DealProposalAction.EQUALIZE_FAILED then
							-- Equalize failed, hide the button, and we can't accept now!
							-- Except... not.
							-- The AI will yield EQUALIZE_FAILED if it would have accepted the gift without modifications.
							-- The AI does not distinguish between 'this gift is fine as is' and 'i would not give you anything for that'.
							Controls.AcceptDeal:SetShow(false);
							Controls.EqualizeDeal:SetShow(false);
							SetLeaderDialog("LOC_DIPLO_DEAL_LEADER_GIFT_EQUALIZE_FAILED", "");
						elseif ms_LastIncomingDealProposalAction == DealProposalAction.REJECTED then
							-- Most likely autoproposed, there's a chance for an equalize. No accept, again.
							Controls.AcceptDeal:SetShow(false);
							Controls.EqualizeDeal:SetShow(true);
							Controls.EqualizeDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_WHAT_WOULD_IT_TAKE");
							Controls.EqualizeDeal:LocalizeAndSetToolTip("LOC_DIPLOMACY_DEAL_WHAT_IT_WILL_TAKE_TOOLTIP");
							SetLeaderDialog("LOC_DIPLO_MAKE_DEAL_AI_REFUSE_DEAL_ANY_ANY", "");
						else
							-- No immediate complaints, I guess we can show both equalize and accept.
							Controls.AcceptDeal:SetShow(true);
							Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_GIFT_DEAL");
							Controls.EqualizeDeal:SetShow(true);
							Controls.EqualizeDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_WHAT_WOULD_YOU_GIVE_ME");
							Controls.EqualizeDeal:LocalizeAndSetToolTip("LOC_DIPLO_DEAL_WHAT_WOULD_YOU_GIVE_ME_TOOLTIP");
							SetLeaderDialog("LOC_DIPLO_DEAL_LEADER_GIFT", "LOC_DIPLO_DEAL_LEADER_GIFT_EFFECT");
						end
					elseif ms_bIsGift then -- Incoming gift
						Controls.EqualizeDeal:SetShow(false);
					else
						if (UpdateProposalButtonsForGift(itemsFromLocal, itemsFromOther)) then
							-- AI was unable to equalize for the requested items so hide the equalize button
							if ms_LastIncomingDealProposalAction == DealProposalAction.EQUALIZE_FAILED then
								Controls.EqualizeDeal:SetHide(true);
								SetLeaderDialog("LOC_DIPLO_DEAL_LEADER_EQUALIZE_FAILED", "");
							else
								Controls.EqualizeDeal:SetHide(false);
								SetLeaderDialog("LOC_DIPLO_DEAL_UNFAIR", "");
							end

							Controls.EqualizeDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_WHAT_WOULD_IT_TAKE");
							Controls.EqualizeDeal:LocalizeAndSetToolTip("LOC_DIPLOMACY_DEAL_WHAT_IT_WILL_TAKE_TOOLTIP");
							Controls.AcceptDeal:SetHide(true); --If either of the above buttons are showing, disable the main accept button

						else	--Something is being offered on both sides
							-- Show equalize button if the accept button is hidden and the AI already hasn't attempted to equalize the deal
							if Controls.AcceptDeal:IsHidden() and ms_LastIncomingDealProposalAction ~= DealProposalAction.EQUALIZE_FAILED then
								Controls.EqualizeDeal:SetHide(false);
								Controls.EqualizeDeal:LocalizeAndSetText("LOC_DIPLOMACY_MAKE_DEAL_EQUITABLE");
								Controls.EqualizeDeal:LocalizeAndSetToolTip("LOC_DIPLOMACY_MAKE_DEAL_EQUITABLE_TOOLTIP");
							else
								Controls.EqualizeDeal:SetHide(true);
								if ms_LastIncomingDealProposalAction == DealProposalAction.PROPOSED then
									SetLeaderDialog("LOC_DIPLO_DEAL_INTRO_AI", "");
								elseif ms_LastIncomingDealProposalAction == DealProposalAction.ACCEPTED then
									SetLeaderDialog("LOC_DIPLO_MAKE_DEAL_AI_ACCEPT_DEAL_ANY_ANY", "");
								elseif ms_LastIncomingDealProposalAction == DealProposalAction.ADJUSTED then
									SetLeaderDialog("LOC_DIPLO_DEAL_LEADER_EQUALIZE_SUCCEEDED", "");
								else
									SetLeaderDialog("LOC_DIPLO_DEAL_LEADER_EQUALIZE_FAILED", "");
								end
							end

							Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_ACCEPT_DEAL");
						end
					end
				else
					-- Dealing with another human

					Controls.EqualizeDeal:SetHide(true);
					Controls.AcceptDeal:SetHide(false);

					if (ms_LastIncomingDealProposalAction == DealProposalAction.PENDING) then
						-- Just starting the deal
						if (itemsFromLocal > 0 and itemsFromOther == 0) then
							-- Is this one way to them?
							g_uiMyOffers.Directions:SetHide(true);
							g_uiTheirOffers.Directions:SetHide(false);
							Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_GIFT_DEAL");
						else
							-- Everything else is a proposal to another human
							g_uiMyOffers.Directions:SetHide(true);
							g_uiTheirOffers.Directions:SetHide(true);
							Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_PROPOSE_DEAL");
						end
						-- Make sure the leader text is set to something appropriate.
						SetDefaultLeaderDialogText();
					else
						g_uiMyOffers.Directions:SetHide(true);
						g_uiTheirOffers.Directions:SetHide(true);
						-- Are the incoming and outgoing deals the same?
						if (DealManager.AreWorkingDealsEqual(g_LocalPlayer:GetID(), g_OtherPlayer:GetID())) then 
							Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_ACCEPT_DEAL");
						else
							Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_PROPOSE_DEAL");
						end
					end
				end
			else
				-- Is a Demand
				if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
					g_uiMyOffers.Directions:SetHide(true);
					g_uiTheirOffers.Directions:SetHide(true);
					SetDefaultLeaderDialogText();
				else
					if (itemsFromOther == 0) then
						g_uiTheirOffers.Directions:SetHide(false);
					else
						g_uiTheirOffers.Directions:SetHide(true);
					end
					-- Demand against another player
					SetLeaderDialog("LOC_DIPLO_DEAL_LEADER_DEMAND", "LOC_DIPLO_DEAL_LEADER_DEMAND_EFFECT");
				end
			end
		else
			-- Make sure the leader text is set to something appropriate.
			SetDefaultLeaderDialogText();
		end
	else															
		--There isn't a valid deal, or we are just viewing a pending deal.
		local bIsViewing : boolean = (bDealIsPending and ms_OtherPlayerIsHuman);

		local itemsFromLocal : number = 0;
		local itemsFromOther : number = 0;

		local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		if (pDeal ~= nil) then
			itemsFromLocal = pDeal:GetItemCount(g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
			itemsFromOther = pDeal:GetItemCount(g_OtherPlayer:GetID(), g_LocalPlayer:GetID());
		end

		g_uiMyOffers.Directions:SetHide( bIsViewing or itemsFromLocal > 0);
		g_uiTheirOffers.Directions:SetHide( bIsViewing or itemsFromOther > 0);
		Controls.EqualizeDeal:SetHide(true);
		Controls.AcceptDeal:SetHide(true);
		Controls.DemandDeal:SetHide(true);

		if (not DealIsEmpty() and not bDealValid) then
			-- Set have the other leader tell them that the deal has invalid items.
			SetLeaderDialog("LOC_DIPLOMACY_DEAL_INVALID", "");
		else
			SetDefaultLeaderDialogText();
		end
			
		Controls.ResumeGame:SetHide(not bIsViewing);
	end

	if (bDealIsPending and ms_OtherPlayerIsHuman) then
		if (ms_bIsDemand) then
			Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_CANCEL_DEMAND");
		elseif ms_bIsGift then -- Incoming gift
			Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_REFUSE_GIFT");
		else
			Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_CANCEL_DEAL");
		end
	else
		-- Did the other player start this or the local player?
		if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
			if (not bDealValid) then
				-- Our changes have made the deal invalid, say cancel instead
				Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_CANCEL_DEAL");
			else
				if (ms_bIsDemand) then
					Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_ACCEPT_DEMAND");
					Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_REFUSE_DEMAND");
				elseif ms_bIsGift then -- Incoming gift
					Controls.AcceptDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_ACCEPT_GIFT");
					Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_REFUSE_GIFT");
				else
					Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_REFUSE_DEAL");
				end
			end
		else
			Controls.RefuseDeal:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_EXIT_DEAL");
		end
	end
	Controls.DealOptionsStack:CalculateSize();

	if (ms_bIsDemand) then
		if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
			-- Demand from the other player and we are responding
			Controls.MyOfferLabel:SetHide(false);
			Controls.TheirOfferLabel:SetHide(true);
			g_uiTheirOffers.OfferStack:SetHide(true);
			g_uiMyOffers.OfferStack:SetHide(false);
		else
			-- Demand from us, to the other player
			Controls.MyOfferLabel:SetHide(true);
			g_uiMyOffers.OfferStack:SetHide(true);
			Controls.TheirOfferLabel:SetHide(false);
			g_uiTheirOffers.OfferStack:SetHide(false);
		end
	else
		Controls.MyOfferLabel:SetHide(false);
		Controls.TheirOfferLabel:SetHide(false);
		g_uiTheirOffers.OfferStack:SetHide(false);
		g_uiMyOffers.OfferStack:SetHide(false);
	end
end

-- ===========================================================================
function PopulateAvailableGold(player : table, iconList : table)

	local availableItemCount : number = 0;

	local eFromPlayerID : number = player:GetID();
	local eToPlayerID : number = GetOtherPlayer(player):GetID();

	local pForDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local possibleResources : table = DealManager.GetPossibleDealItems(eFromPlayerID, eToPlayerID, DealItemTypes.GOLD, pForDeal);
	if (possibleResources ~= nil) then
		for i, entry in ipairs(possibleResources) do
			if (entry.Duration == 0) then
				-- One time gold
				local playerTreasury:table	= player:GetTreasury();
				local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());

				if (not ms_bIsDemand) then
					-- One time gold
					local uiIcon : table = g_IconOnlyIM:GetInstance(iconList.ListStack);
					uiIcon.AmountText:SetHide(false);
					uiIcon.AmountText:SetText(goldBalance);
					uiIcon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
					SetIconToSize(uiIcon.Icon, "ICON_YIELD_GOLD_5");
					uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableOneTimeGold(player, ms_DefaultOneTimeGoldAmount); end );
					uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableOneTimeGold(player, ms_DefaultOneTimeGoldAmount); end );
					uiIcon.RemoveButton:SetHide(true);
					uiIcon.Icon:SetColor(1,1,1);
					availableItemCount = availableItemCount + 1;
				end
			else
				-- Multi-turn gold
				uiIcon = g_IconAndTextIM:GetInstance(iconList.ListStack);
				SetIconToSize(uiIcon.Icon, "ICON_YIELD_GOLD_5");
				uiIcon.IconText:LocalizeAndSetText("LOC_DIPLOMACY_DEAL_GOLD_PER_TURN");
				uiIcon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
				uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableMultiTurnGold(player, ms_DefaultMultiTurnGoldAmount, ms_DefaultMultiTurnGoldDuration); end );
				uiIcon.ValueText:SetHide(true);
				uiIcon.RemoveButton:SetHide(true);
				uiIcon.Icon:SetColor(1,1,1);

				iconList.ListStack:CalculateSize();

				availableItemCount = availableItemCount + 1;
			end
		end
	end

	return availableItemCount;
end

-- ===========================================================================
function OnClickAvailableBasic(itemType, player, valueType)

	if ((ms_bIsDemand == true or ms_bIsGift == true) and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		-- Can't modifiy demand that is not ours
		return;
	end

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		-- Already there?
		local pDealItem = pDeal:FindItemByValueType(itemType, DealItemSubTypes.NONE, valueType, player:GetID());
		if (pDealItem == nil) then
			-- No
			pDealItem = pDeal:AddItemOfType(itemType, player:GetID());
			if (pDealItem ~= nil) then
				pDealItem:SetValueType(valueType);
				UpdateDealPanel(player);
				UpdateProposedWorkingDeal();
			end
		end
	end
end

-- ===========================================================================
function OnClickAvailableResource(player, resourceType)

	if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		-- Can't modifiy demand that is not ours
		return;
	end

	local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		-- Already there?
		local dealItems : table = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, player:GetID());
		local pDealItem : table;
		if (dealItems ~= nil) then
			for i, pDealItem in ipairs(dealItems) do
				if pDealItem:GetValueType() == resourceType then
					-- Check for non-zero duration.  There may already be a one-time transfer of the resource if a city is in the deal.
					if (pDealItem:GetDuration() ~= 0) then
						return;	-- Already in there.
					end
				end
			end
		end

		local pPlayerResources : table = player:GetResources();
		-- Get the total amount of the resource we have. This does not take into account anything already in the deal.
		local amount : number = pPlayerResources:GetResourceAmount( resourceType );
		if (amount > 0) then
				
			pDealItem = pDeal:AddItemOfType(DealItemTypes.RESOURCES, player:GetID());
			if (pDealItem ~= nil) then
				-- Add one
				pDealItem:SetValueType(resourceType);
				pDealItem:SetAmount(1);
				pDealItem:SetDuration(30);	-- Default to this many turns		

				-- After we add the item, test to see if the item is valid, it is possible that we have exceeded the amount of resources we can trade.
				if not pDealItem:IsValid() then
					pDeal:RemoveItemByID(pDealItem:GetID());
					pDealItem = nil;
				else
					UI.PlaySound("UI_GreatWorks_Put_Down");
				end

				UpdateDealPanel(player);
				UpdateProposedWorkingDeal();
			end
		end
	end
end

-- ===========================================================================
function OnClickAvailableAgreement(player, agreementType, agreementTurns)

	if ((ms_bIsDemand == true or ms_bIsGift == true) and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		-- Can't modifiy demand that is not ours
		return;
	end

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		-- Already there?
		local pDealItem = pDeal:FindItemByType(DealItemTypes.AGREEMENTS, agreementType, player:GetID());
		if (pDealItem == nil) then
			if (agreementType == DealAgreementTypes.JOINT_WAR or
				agreementType == DealAgreementTypes.THIRD_PARTY_WAR or
				agreementType == DealAgreementTypes.RESEARCH_AGREEMENT ) then
				ShowAgreementOptionPopup(agreementType, agreementTurns, player:GetID());
			else
				-- No
				pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, player:GetID());
				if (pDealItem ~= nil) then
					pDealItem:SetSubType(agreementType);
					pDealItem:SetDuration(agreementTurns);

					UpdateDealPanel(player);
					UpdateProposedWorkingDeal();
					UI.PlaySound("UI_GreatWorks_Put_Down");
				end
			end
		end
	end
end

-- ===========================================================================
function OnSelectAgreementOption(agreementType, agreementTurns, agreementValue, agreementParameters, fromPlayerId)
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		-- Already there?
		local pDealItem = pDeal:FindItemByType(DealItemTypes.AGREEMENTS, agreementType, fromPlayerId);
		if (pDealItem ~= nil) then
            -- deal manager doesn't update properly unless we delete the deal item
            -- and add a new one.
			if (not pDealItem:IsLocked()) then
                local itemID = pDealItem:GetID();
                DetachValueEdit(itemID);
				pDeal:RemoveItemByID(itemID);
                pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, fromPlayerId);
            end
        else
            pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, fromPlayerId);
		end

        if (pDealItem ~= nil) then
            pDealItem:SetSubType(agreementType);
            pDealItem:SetDuration(agreementTurns);
            pDealItem:SetValueType(agreementValue);

            if (agreementType == DealAgreementTypes.JOINT_WAR or
                agreementType == DealAgreementTypes.THIRD_PARTY_WAR) then
                pDealItem:SetParameterValue("WarType", agreementParameters.WarType);
            end

    		UpdateDealPanel(g_LocalPlayer);
    		UpdateProposedWorkingDeal();
    		UI.PlaySound("UI_GreatWorks_Put_Down");
        end

   		Controls.ValueEditPopupBackground:SetHide(true);
	end
end

-- ===========================================================================
function ShowAgreementOptionPopup(agreementType, agreementTurns, fromPlayerId)

	-- Hide/show everything for AGREEMENTS options
	ms_AgreementOptionIM:ResetInstances();
	Controls.ValueEditIconGrid:SetHide(true);
	Controls.ValueAmountEditBoxContainer:SetHide(true);

    -- don't update when backing out of this
    ms_bDontUpdateOnBack = true;

	if agreementType == DealAgreementTypes.RESEARCH_AGREEMENT then
		Controls.ValueEditHeaderLabel:SetText(Locale.Lookup("LOC_DIPLOMACY_DEAL_SELECT_TECH"));
	elseif agreementType == DealAgreementTypes.ALLIANCE then
		Controls.ValueEditHeaderLabel:SetText(Locale.Lookup("LOC_DIPLOMACY_DEAL_SELECT_ALLIANCE"));
	else
		Controls.ValueEditHeaderLabel:SetText(Locale.Lookup("LOC_DIPLOMACY_DEAL_SELECT_TARGET"));
	end

	local toPlayerId = g_LocalPlayer:GetID();
	if (toPlayerId == fromPlayerId ) then
		toPlayerId = g_OtherPlayer:GetID();
	end
	local pForDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local possibleValues = DealManager.GetPossibleDealItems(fromPlayerId, toPlayerId, DealItemTypes.AGREEMENTS, agreementType, pForDeal);
	if (possibleValues ~= nil) then
		for i, entry in ipairs(possibleValues) do
			local instance:table = ms_AgreementOptionIM:GetInstance();

			local szDisplayName = "";
			local szItemName = Locale.Lookup(entry.ForTypeDisplayName);
			if (entry.SubType == DealAgreementTypes.RESEARCH_AGREEMENT) then
				local eTech = GameInfo.Technologies[entry.ForType].Index;
				local iTurns = 	g_LocalPlayer:GetDiplomacy():ComputeResearchAgreementTurns(g_OtherPlayer, eTech);
				szDisplayName = Locale.Lookup("LOC_DIPLOMACY_DEAL_PARAMETER_WITH_TURNS", szItemName, iTurns);
				instance.AgreementOptionIcon:SetIcon("ICON_" .. entry.ForTypeName);
				instance.AgreementOptionIcon:SetHide(false);
			else
				if (entry.SubType == DealAgreementTypes.JOINT_WAR or
					entry.SubType == DealAgreementTypes.THIRD_PARTY_WAR) then
					szDisplayName = szItemName;

					-- Have a type of war that describes the joint war?
					if entry.Parameters ~= nil then
						if entry.Parameters.WarType ~= nil then
							local warDef = GameInfo.Wars[entry.Parameters.WarType];
							if warDef ~= nil then
								szDisplayName = szDisplayName .. "[newline]" .. Locale.Lookup(warDef.Name);
							end
						end
					end

					instance.AgreementOptionIcon:SetHide(true);
				else
					szDisplayName = szItemName;
					instance.AgreementOptionIcon:SetHide(true);
				end
			end

			instance.AgreementOptionLabel:SetText(szDisplayName);

			if agreementType == DealAgreementTypes.ALLIANCE then
				local allianceLevel:number = g_LocalPlayer:GetDiplomacy():GetAllianceLevel(g_OtherPlayer);
				local allianceData:table = GameInfo.Alliances[entry.ForTypeName];
				local tooltip = Game.GetGameDiplomacy():GetAllianceBenefitsString(allianceData.Index, allianceLevel, true);
				instance.AgreementOptionButton:SetToolTipString(tooltip);
			else
				instance.AgreementOptionButton:SetToolTipString("");
			end

			local agreementValueType = entry.ForType;
			local agreementParameters = entry.Parameters;
			instance.AgreementOptionButton:RegisterCallback(Mouse.eLClick, function()
				OnSelectAgreementOption(agreementType, agreementTurns, agreementValueType, agreementParameters, fromPlayerId);
			end);

			Controls.ValueEditButton:RegisterCallback( Mouse.eLClick, OnAgreementBackButton );
		end
	end

	Controls.ValueEditIconGrid:DoAutoSize();

	ResizeValueEditScrollPanel();

	Controls.ValueEditPopup:DoAutoSize();
	Controls.ValueEditPopupBackground:SetHide(false);
end

-- ===========================================================================
function ResizeValueEditScrollPanel()
	-- Resize scroll panel to a maximum height of five agreement options
	Controls.ValueEditStack:CalculateSize();
	if Controls.ValueEditStack:GetSizeY() > MAX_DEAL_ITEM_EDIT_HEIGHT then
		Controls.ValueEditScrollPanel:SetSizeY(MAX_DEAL_ITEM_EDIT_HEIGHT);
	else
		Controls.ValueEditScrollPanel:SetSizeY(Controls.ValueEditStack:GetSizeY());
	end
	Controls.ValueEditScrollPanel:CalculateSize();
end

-- ===========================================================================
function OnAgreementBackButton()
    if not ms_bDontUpdateOnBack then
        UpdateDealPanel(g_LocalPlayer);
        UpdateProposedWorkingDeal();
    end
    ms_bDontUpdateOnBack = false;
	Controls.ValueEditPopupBackground:SetHide(true);
end

-- ===========================================================================
function OnClickAvailableGreatWork(player, type)

	OnClickAvailableBasic(DealItemTypes.GREATWORK, player, type);
	UI.PlaySound("UI_GreatWorks_Put_Down");

end

-- ===========================================================================
function OnClickAvailableCaptive(player, type)

	OnClickAvailableBasic(DealItemTypes.CAPTIVE, player, type);
	UI.PlaySound("UI_GreatWorks_Put_Down");

end

-- ===========================================================================
function OnClickAvailableCity(player, valueType, subType)

	if ((ms_bIsDemand == true or ms_bIsGift == true) and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		-- Can't modifiy demand that is not ours
		return;
	end

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		-- Already there?
		local pDealItem = pDeal:FindItemByValueType(DealItemTypes.CITIES, subType, valueType, player:GetID());
		if (pDealItem == nil) then
			-- No
			local otherPlayerID = g_OtherPlayer:GetID();
			if (otherPlayerID == player:GetID()) then
				otherPlayerID = g_LocalPlayer:GetID();
			end

			pDealItem = pDeal:AddItemOfType(DealItemTypes.CITIES, player:GetID(), otherPlayerID, subType, valueType);
			if (pDealItem ~= nil) then
				pDealItem:SetSubType(subType);
				pDealItem:SetValueType(valueType);
				if (not pDealItem:IsValid(pDeal)) then
					pDeal:RemoveItemByID(pDealItem:GetID());
				end
				UpdateDealPanel(player);
				UpdateProposedWorkingDeal();
			end
		end
	end

	UI.PlaySound("UI_GreatWorks_Put_Down");

end

-- ===========================================================================
function OnRemoveDealItem(player, itemID)

	if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		-- Can't remove it
		return;
	end

	DetachValueEdit(itemID);

	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if (pDeal ~= nil) then

		local pDealItem = pDeal:FindItemByID(itemID);
		if (pDealItem ~= nil) then
			if (not pDealItem:IsLocked()) then
				if (pDeal:RemoveItemByID(itemID)) then
					UpdateDealPanel(player);
					UpdateProposedWorkingDeal();
					UI.PlaySound("UI_GreatWorks_Pick_Up");
				end
			end
		end
	end
end

-- ===========================================================================
function OnSelectValueDealItem(player, itemID, controlInstance)

	if (ms_bIsDemand == true and ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		-- Can't edit it
		return;
	end

	if (controlInstance ~= nil) then
		AttachValueEdit(controlInstance, itemID);
	end
end

-- ===========================================================================
function OnValueEditButton(itemID)
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	if pDeal then
		local pDealItem = pDeal:FindItemByID(itemID);
		if pDealItem then
			local newAmount:number = tonumber(Controls.ValueAmountEditBox:GetText());
			newAmount = clip(newAmount, 1, pDealItem:GetMaxAmount());

			if (newAmount ~= pDealItem:GetAmount()) then
				local subtype = pDealItem:GetSubType();
				local duration = pDealItem:GetDuration();
				local valueType = pDealItem:GetValueType();
				local fromPlayerId = pDealItem:GetFromPlayerID();
				local type = pDealItem:GetType();
                if (not pDealItem:IsLocked()) then
                    DetachValueEdit(itemID);
                    pDeal:RemoveItemByID(itemID);
                    pDealItem = pDeal:AddItemOfType(type, fromPlayerId);
                    pDealItem:SetSubType(subtype);
                    pDealItem:SetDuration(duration);
                    pDealItem:SetValueType(valueType);
                end

				pDealItem:SetAmount(newAmount);
				ms_bForceUpdateOnCommit = true;
				UpdateProposedWorkingDeal();
			end

			if g_ValueEditDealItemControlTable then
				g_ValueEditDealItemControlTable.AmountText:SetText(newAmount);
				g_ValueEditDealItemControlTable.AmountText:SetHide(false);
			end
			UpdateDealStatus();
			UpdateDealPanel(g_LocalPlayer);
		end
	end

	Controls.ValueEditPopupBackground:SetHide(true);
end

-- ===========================================================================
function PopulateAvailableResources(player : table, iconList : table, className : string)

	local availableItemCount : number = 0;
	local pForDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local possibleResources : table = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.RESOURCES, pForDeal);
	if (possibleResources ~= nil) then
		for i, entry in ipairs(possibleResources) do
	
			local resourceDesc : table = GameInfo.Resources[entry.ForType];
			if (resourceDesc ~= nil) then
				-- Do we have some and is it a luxury item?
				if (entry.MaxAmount > 0 and resourceDesc.ResourceClassType == className ) then
					local uiIcon : table = g_IconOnlyIM:GetInstance(iconList.ListStack);
					SetIconToSize(uiIcon.Icon, "ICON_" .. resourceDesc.ResourceType);
					uiIcon.AmountText:SetText(tostring(entry.MaxAmount));
					uiIcon.AmountText:SetHide(false);
					uiIcon.RemoveButton:SetHide(true);
					uiIcon.Icon:SetColor(1,1,1);

					local resourceType : number = entry.ForType;
					-- What to do when double clicked/tapped.
					uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableResource(player, resourceType); end );
					-- Set a tool tip
					if entry.IsValid then
						uiIcon.SelectButton:LocalizeAndSetToolTip(resourceDesc.Name);
                        uiIcon.SelectButton:SetDisabled(false);
					else
                        local tempstr : string = Locale.Lookup(resourceDesc.Name).."[NEWLINE][COLOR_RED]";
					    if player ~= g_LocalPlayer then
                            tempstr = tempstr .. Locale.Lookup("LOC_DEAL_PLAYER_HAS_NO_CAP_ROOM");
	                        uiIcon.SelectButton:SetToolTipString(tempstr);
						else
                            tempstr = tempstr .. Locale.Lookup("LOC_DEAL_AI_HAS_NO_CAP_ROOM");
	                        uiIcon.SelectButton:SetToolTipString(tempstr);
						end
                        uiIcon.SelectButton:SetDisabled(true);
						uiIcon.Icon:SetColor(0.5, 0.5, 0.5);
					end

					availableItemCount = availableItemCount + 1;
				end
			end
		end

		iconList.ListStack:CalculateSize();
	end

	-- Hide if empty
	iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

	return availableItemCount;
end

-- ===========================================================================
function PopulateAvailableLuxuryResources(player : table, iconList : table)

	local availableItemCount : number = 0;
	availableItemCount = availableItemCount + PopulateAvailableResources(player, iconList, "RESOURCECLASS_LUXURY");
	return availableItemCount;
end

-- ===========================================================================
function PopulateAvailableStrategicResources(player : table, iconList : table)

	local availableItemCount : number = 0;
	availableItemCount = availableItemCount + PopulateAvailableResources(player, iconList, "RESOURCECLASS_STRATEGIC");
	return availableItemCount; 
end

-- ===========================================================================
function PopulateAvailableAgreements(player : table, iconList : table)

	local availableItemCount : number = 0;
	local pForDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local possibleAgreements : table = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.AGREEMENTS, pForDeal);
	local uiMinimizedSection : table = ms_MinimizedSectionIM:GetInstance(iconList.List);

	if (possibleAgreements ~= nil) then
		for i, entry in ipairs(possibleAgreements) do
			local agreementType : number = entry.SubType;

			local agreementDuration : number = entry.Duration;
			local uiIcon : table = g_IconAndTextIM:GetInstance(iconList.ListStack);
			local uiMinimizedIcon : table = g_IconOnlyIM:GetInstance(uiMinimizedSection.MinimizedSectionStack);

			local info: table = GameInfo.DiplomaticActions[ agreementType ];
			if (info ~= nil) then
				SetIconToSize(uiIcon.Icon, "ICON_".. info.DiplomaticActionType, 38);
				SetIconToSize(uiMinimizedIcon.Icon, "ICON_".. info.DiplomaticActionType, 38);
			end
			uiIcon.AmountText:SetHide(true);
			uiIcon.IconText:LocalizeAndSetText(entry.SubTypeName);
			uiIcon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
			uiIcon.ValueText:SetHide(true);
			uiIcon.RemoveButton:SetHide(true);

			uiMinimizedIcon.AmountText:SetHide(true);
			uiMinimizedIcon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
			uiMinimizedIcon.RemoveButton:SetHide(true);
			uiMinimizedIcon.Icon:SetColor(1,1,1);

			-- What to do when double clicked/tapped.
			uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableAgreement(player, agreementType, agreementDuration); end );
			uiMinimizedIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableAgreement(player, agreementType, agreementDuration); end );

			-- Set a tool tip if their is a duration
			local szTooltip : string;
			if (entry.Duration > 0) then
				szTooltip = Locale.Lookup("LOC_DIPLOMACY_DEAL_PARAMETER_WITH_TURNS", entry.SubTypeName, entry.Duration);
				uiIcon.SelectButton:SetToolTipString(szTooltip);
			else
				szTooltip = Locale.Lookup(entry.SubTypeName);
				uiIcon.SelectButton:SetToolTipString(nil);
			end
			uiMinimizedIcon.SelectButton:SetToolTipString(szTooltip);

			availableItemCount = availableItemCount + 1;
		end

		iconList.ListStack:CalculateSize();
	end

	uiMinimizedSection.MinimizedSectionContainer:SetHide(iconList.ListStack:IsVisible());
	iconList.HeaderExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(iconList.ListStack, uiMinimizedSection.MinimizedSectionContainer, iconList.HeaderExpandButton); end);
	iconList.HeaderExpandButton:SetHide(table.count(iconList.ListStack:GetChildren()) == 1);

	-- Hide if empty
	iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

	return availableItemCount;
end

-- ===========================================================================
function MakeCityToolTip(player : table, cityID : number)
	local pCity = player:GetCities():FindID( cityID );
	if (pCity == nil) then	
		UI.DataError("Unable to find city object to make tooltip for cityID: "..tostring(cityID));
		return "";
	end

	local szToolTip : string = Locale.Lookup("LOC_DEAL_CITY_POPULATION_TOOLTIP", pCity:GetPopulation());
	local districtNames : table = {};
	local pCityDistricts : table = pCity:GetDistricts();
	if (pCityDistricts ~= nil) then

		for i, pDistrict in pCityDistricts:Members() do
			local pDistrictDef = GameInfo.Districts[ pDistrict:GetType() ];
			if (pDistrictDef ~= nil) then
				local districtType:string = pDistrictDef.DistrictType;
				-- Skip the city center and any wonder districts
				if (districtType ~= "DISTRICT_CITY_CENTER" and districtType ~= "DISTRICT_WONDER") then
					local iconAndName : string = Locale.Lookup("[ICON_"..pDistrictDef.PrimaryKey.."]")..Locale.Lookup(pDistrictDef.Name);
					table.insert(districtNames, iconAndName);
				end
			end
		end
	end

	if (#districtNames > 0) then
		szToolTip = szToolTip .."[NEWLINE]  -----------------------" .. "[NEWLINE]" .. Locale.Lookup("LOC_DEAL_CITY_DISTRICTS_TOOLTIP");
		for i, name in ipairs(districtNames) do
			szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup(name);
		end
	end

	-- Add Resources
	local extractedResources = player:GetResources():GetResourcesExtractedByCity( cityID, ResultFormat.SUMMARY );
	if extractedResources ~= nil and #extractedResources > 0 then
		szToolTip = szToolTip .. "[NEWLINE]  -----------------------" .. "[NEWLINE]" .. Locale.Lookup("LOC_DEAL_CITY_RESOURCES_TOOLTIP");
		for i, entry in ipairs(extractedResources) do
			local resourceDesc = GameInfo.Resources[entry.ResourceType];
			if resourceDesc ~= nil then
				szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup(resourceDesc.Name) .. " : " .. tostring(entry.Amount);
			end
		end
	end

	-- Add Great Works
	local cityGreatWorks = player:GetCulture():GetGreatWorksInCity( cityID );
	if cityGreatWorks ~= nil and #cityGreatWorks > 0 then
		szToolTip = szToolTip .. "[NEWLINE]  -----------------------" .. "[NEWLINE]" .. Locale.Lookup("LOC_DEAL_CITY_GREAT_WORKS_TOOLTIP");
		for i, entry in ipairs(cityGreatWorks) do
			local greatWorksDesc = GameInfo.GreatWorks[entry.GreatWorksType];
			if greatWorksDesc ~= nil then
				szToolTip = szToolTip .. "[NEWLINE]" .. Locale.Lookup(greatWorksDesc.Name);
			end
		end
	end

	return szToolTip;	
end

-- ===========================================================================
function PopulateAvailableCities(player : table, iconList : table)

	local availableItemCount : number = 0;
	local pForDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local possibleItems : table = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.CITIES, pForDeal);
	local uiMinimizedSection : table = ms_MinimizedSectionIM:GetInstance(iconList.List);

	if (possibleItems ~= nil) then
		for i, entry in ipairs(possibleItems) do

			local type : number = entry.ForType;
			local subType : number = entry.SubType;
			local uiIcon : table = g_IconAndTextIM:GetInstance(iconList.ListStack);
			local uiMinimizedIcon : table = g_IconOnlyIM:GetInstance(uiMinimizedSection.MinimizedSectionStack);

			SetIconToSize(uiIcon.Icon, "ICON_BUILDINGS", 45);
			SetIconToSize(uiMinimizedIcon.Icon, "ICON_BUILDINGS", 45);

			uiIcon.AmountText:SetHide(true);
			uiIcon.IconText:LocalizeAndSetText(entry.ForTypeName);
			uiIcon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
			uiIcon.ValueText:SetHide(true);
			uiIcon.RemoveButton:SetHide(true);

			uiMinimizedIcon.AmountText:SetHide(true);
			uiMinimizedIcon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
			uiMinimizedIcon.RemoveButton:SetHide(true);
			uiMinimizedIcon.Icon:SetColor(1,1,1);

			-- What to do when double clicked/tapped.
			uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableCity(player, type, subType); end );
			uiMinimizedIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableCity(player, type, subType); end );

			-- Since we're ceding this city make sure to look for this city in the current owners city list
			if entry.SubType == 1 then -- CitySubTypes:CEDE_OCCUPIED
				uiIcon.SelectButton:SetToolTipString( MakeCityToolTip(GetOtherPlayer(player), type) );
				uiMinimizedIcon.SelectButton:SetToolTipString(Locale.Lookup(entry.ForTypeName).."[NEWLINE]"..MakeCityToolTip(GetOtherPlayer(player), type ));
			else
				uiIcon.SelectButton:SetToolTipString( MakeCityToolTip(player, type) );
				uiMinimizedIcon.SelectButton:SetToolTipString(Locale.Lookup(entry.ForTypeName).."[NEWLINE]"..MakeCityToolTip(player, type ));
			end

			availableItemCount = availableItemCount + 1;
		end

		iconList.ListStack:CalculateSize();
	end

	uiMinimizedSection.MinimizedSectionContainer:SetHide(iconList.ListStack:IsVisible());
	iconList.HeaderExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(iconList.ListStack, uiMinimizedSection.MinimizedSectionContainer, iconList.HeaderExpandButton); end);
	iconList.HeaderExpandButton:SetHide(table.count(iconList.ListStack:GetChildren()) == 1);

	-- Hide if empty
	iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

	return availableItemCount;
end

-- ===========================================================================
function PopulateAvailableOtherPlayers(player : table, iconList : table)

	local availableItemCount : number = 0;
	-- Hide if empty
	iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

	return availableItemCount;
end

-- ===========================================================================
function PopulateAvailableGreatWorks(player : table, iconList : table)

	local availableItemCount : number = 0;
	local pForDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local possibleItems : table = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.GREATWORK, pForDeal);
	local uiMinimizedSection : table = ms_MinimizedSectionIM:GetInstance(iconList.List);

	if (possibleItems ~= nil) then
		for i, entry in ipairs(possibleItems) do
			local greatWorkDesc : table = GameInfo.GreatWorks[entry.ForTypeDescriptionID];
			if (greatWorkDesc ~= nil) then
				local type : number = entry.ForType;
				local uiIcon : table = g_IconAndTextIM:GetInstance(iconList.ListStack);
				local uiMinimizedIcon : table = g_IconOnlyIM:GetInstance(uiMinimizedSection.MinimizedSectionStack);

				SetIconToSize(uiIcon.Icon, "ICON_" .. greatWorkDesc.GreatWorkType, 45);
				SetIconToSize(uiMinimizedIcon.Icon, "ICON_" .. greatWorkDesc.GreatWorkType, 45);

				uiIcon.AmountText:SetHide(true);
				uiIcon.IconText:LocalizeAndSetText(entry.ForTypeName);
				uiIcon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
				uiIcon.ValueText:SetHide(true);
				uiIcon.RemoveButton:SetHide(true);

				uiMinimizedIcon.AmountText:SetHide(true);
				uiMinimizedIcon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
				uiMinimizedIcon.RemoveButton:SetHide(true);
				uiMinimizedIcon.Icon:SetColor(1,1,1);

				-- What to do when double clicked/tapped.
				uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableGreatWork(player, type); end );
				uiMinimizedIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableGreatWork(player, type); end );
				-- Set a tool tip
				
				local greatWorkTooltip : string = GreatWorksSupport_GetBasicTooltip(entry.ForType, false);
				uiIcon.SelectButton:SetToolTipString(greatWorkTooltip);

				local minimizedTooltip : string = Locale.Lookup(entry.ForTypeName) .. "[NEWLINE]"..greatWorkTooltip;
				uiMinimizedIcon.SelectButton:SetToolTipString(minimizedTooltip);

				availableItemCount = availableItemCount + 1;
			end
		end

		iconList.ListStack:CalculateSize();
	end

	uiMinimizedSection.MinimizedSectionContainer:SetHide(iconList.ListStack:IsVisible());
	iconList.HeaderExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(iconList.ListStack, uiMinimizedSection.MinimizedSectionContainer, iconList.HeaderExpandButton); end);
	iconList.HeaderExpandButton:SetHide( table.count(iconList.ListStack:GetChildren()) == 1 );

	-- Hide if empty
	iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

	return availableItemCount;

end

-- ===========================================================================
function PopulateAvailableCaptives(player : table, iconList : table)

	local availableItemCount : number = 0;

	local pForDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local possibleItems : table = DealManager.GetPossibleDealItems(player:GetID(), GetOtherPlayer(player):GetID(), DealItemTypes.CAPTIVE, pForDeal);
	local uiMinimizedSection : table = ms_MinimizedSectionIM:GetInstance(iconList.List);

	if (possibleItems ~= nil) then
		for i, entry in ipairs(possibleItems) do

			local type : number = entry.ForType;
			local uiIcon : table = g_IconAndTextIM:GetInstance(iconList.ListStack);
			local uiMinimizedIcon : table = g_IconOnlyIM:GetInstance(uiMinimizedSection.MinimizedSectionStack);

			SetIconToSize(uiIcon.Icon, "ICON_UNIT_SPY");
			SetIconToSize(uiMinimizedIcon.Icon, "ICON_UNIT_SPY");

			uiIcon.AmountText:SetHide(true);
			if (entry.ForTypeName ~= nil ) then
				uiIcon.IconText:LocalizeAndSetText(entry.ForTypeName);
				uiMinimizedIcon.SelectButton:LocalizeAndSetToolTip(entry.ForTypeName);
			end
			uiIcon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
			uiIcon.ValueText:SetHide(true);
			uiIcon.RemoveButton:SetHide(true);

			uiMinimizedIcon.AmountText:SetHide(true);
			uiMinimizedIcon.SelectButton:SetDisabled( not entry.IsValid and entry.ValidationResult ~= DealValidationResult.MISSING_DEPENDENCY );	-- Hide if invalid, unless it is just missing a dependency, the user will update that when it is added to the deal.
			uiMinimizedIcon.RemoveButton:SetHide(true);
			uiMinimizedIcon.Icon:SetColor(1,1,1);

			-- What to do when double clicked/tapped.
			uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableCaptive(player, type); end );
			uiMinimizedIcon.SelectButton:RegisterCallback( Mouse.eLClick, function() OnClickAvailableCaptive(player, type); end );

			uiIcon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.

			availableItemCount = availableItemCount + 1;
		end

		iconList.ListStack:CalculateSize();
	end

	uiMinimizedSection.MinimizedSectionContainer:SetHide(iconList.ListStack:IsVisible());
	iconList.HeaderExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(iconList.ListStack, uiMinimizedSection.MinimizedSectionContainer, iconList.HeaderExpandButton); end);
	iconList.HeaderExpandButton:SetHide( table.count(iconList.ListStack:GetChildren()) == 1 );

	-- Hide if empty
	iconList.GetTopControl():SetHide( iconList.ListStack:GetSizeX()==0 );

	return availableItemCount;
end

-- ===========================================================================
function PopulatePlayerAvailablePanel(rootControl : table, player : table)

	local availableItemCount : number = 0;

	if (player ~= nil) then
	
		local playerType : number = GetPlayerType(player);
		if (ms_bIsDemand and player:GetID() == ms_InitiatedByPlayerID) then
			-- This is a demand, so hide all the demanding player's items
			for i = 1, table.count(AvailableDealItemGroupTypes), 1 do
				g_AvailableGroups[i][playerType].GetTopControl():SetHide(true);
			end
		else
			g_AvailableGroups[AvailableDealItemGroupTypes.GOLD][playerType].GetTopControl():SetHide(false);

			availableItemCount = availableItemCount + PopulateAvailableGold(player, g_AvailableGroups[AvailableDealItemGroupTypes.GOLD][playerType]);
			availableItemCount = availableItemCount + PopulateAvailableLuxuryResources(player, g_AvailableGroups[AvailableDealItemGroupTypes.LUXURY_RESOURCES][playerType]);
			availableItemCount = availableItemCount + PopulateAvailableStrategicResources(player, g_AvailableGroups[AvailableDealItemGroupTypes.STRATEGIC_RESOURCES][playerType]);

			if (not ms_bIsDemand) then
				availableItemCount = availableItemCount + PopulateAvailableAgreements(player, g_AvailableGroups[AvailableDealItemGroupTypes.AGREEMENTS][playerType]);
			else
				g_AvailableGroups[AvailableDealItemGroupTypes.AGREEMENTS][playerType].GetTopControl():SetHide(true);
			end

			availableItemCount = availableItemCount + PopulateAvailableCities(player, g_AvailableGroups[AvailableDealItemGroupTypes.CITIES][playerType]);

			if (not ms_bIsDemand) then
				availableItemCount = availableItemCount + PopulateAvailableOtherPlayers(player, g_AvailableGroups[AvailableDealItemGroupTypes.OTHER_PLAYERS][playerType]);
			else
				g_AvailableGroups[AvailableDealItemGroupTypes.OTHER_PLAYERS][playerType].GetTopControl():SetHide(false);
			end

			availableItemCount = availableItemCount + PopulateAvailableGreatWorks(player, g_AvailableGroups[AvailableDealItemGroupTypes.GREAT_WORKS][playerType]);
			availableItemCount = availableItemCount + PopulateAvailableCaptives(player, g_AvailableGroups[AvailableDealItemGroupTypes.CAPTIVES][playerType]);

		end

		rootControl:CalculateSize();

	end

	return availableItemCount; 
end

-- ===========================================================================
function PopulateDealBasic(player : table, iconList : table, populateType : number, iconName : string)

	local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local playerType : number = GetPlayerType(player);
	if (pDeal ~= nil) then
	g_IconAndTextIM:ReleaseInstanceByParent(iconList.CaptivesDealsStack);
	g_IconOnlyIM:ReleaseInstanceByParent(iconList.MinimizedCaptivesDealsStack);
		
		local pDealItem : table;
		for pDealItem in pDeal:Items() do
			local type : number = pDealItem:GetType();
			if (pDealItem:GetFromPlayerID() == player:GetID()) then
				local iDuration : number = pDealItem:GetDuration();
				local dealItemID : number = pDealItem:GetID();
				
				if (type == populateType) then
					local uiIcon : table = g_IconAndTextIM:GetInstance(iconList.CaptivesDealsStack);
					SetIconToSize(uiIcon.Icon, iconName);
					uiIcon.AmountText:SetHide(true);

					local uiMinimizedIcon : table = g_IconOnlyIM:GetInstance(iconList.MinimizedCaptivesDealsStack);
					SetIconToSize(uiMinimizedIcon.Icon, iconName);
					uiMinimizedIcon.AmountText:SetHide(true);

					local typeName : string = pDealItem:GetValueTypeNameID();
					if (typeName ~= nil) then
						uiIcon.IconText:LocalizeAndSetText(typeName);
					end

					-- Show/hide unacceptable item notification
					uiIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());
					uiIcon.RemoveButton:SetHide(false);
				
					uiIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end)
					uiIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
					uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );

					uiIcon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
					uiIcon.SelectButton:SetDisabled(false);

					uiMinimizedIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());
					uiMinimizedIcon.RemoveButton:SetHide(false);

					uiMinimizedIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end)
					uiMinimizedIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
					uiMinimizedIcon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );

					uiMinimizedIcon.SelectButton:SetToolTipString(Locale.Lookup(typeName));		-- We recycle the entries, so make sure this is clear.
					uiMinimizedIcon.SelectButton:SetDisabled(false);
					uiMinimizedIcon.Icon:SetColor(1,1,1);
				end
			end
		end

		local itemCount : number = table.count(iconList.CaptivesDealsStack:GetChildren());

		if(itemCount <= 1 and iconList.CaptivesDealsStack:IsHidden())then
			OnDealsHeaderCollapseButton(iconList.CaptivesDealsStack, iconList.MinimizedCaptivesDealsStack, iconList.CaptivesDealsExpandButton);
		end

		iconList.CaptivesDealsExpandButton:SetHide(not (itemCount > 1));
		iconList.CaptivesDealsGrid:SetHide(itemCount == 0);
		iconList.CaptivesDealsHeader:SetHide(itemCount == 0);

		iconList.OfferStack:CalculateSize();

	end

end

-- ===========================================================================
function GetParentItemTransferToolTip(parentDealItem)
	local szToolTip = "";

	-- If it is from a city, put the city name in the tool tip.
	if (parentDealItem:GetType() == DealItemTypes.CITIES) then

		local cityTypeName = parentDealItem:GetValueTypeNameID();
		if (cityTypeName ~= nil) then
			local cityName = Locale.Lookup(cityTypeName);
			local szTransfer = Locale.Lookup("LOC_DEAL_ITEM_TRANSFERRED_WITH_CITY_TOOLTIP", cityName);

			szToolTip = "[NEWLINE]" .. szTransfer;
		end
	end

	return szToolTip;
end
-- ===========================================================================
function PopulateDealResources(player : table, iconList : table)
	local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local playerType : number = GetPlayerType(player);
	if (pDeal ~= nil) then
		g_IconOnlyIM:ReleaseInstanceByParent(iconList.OneTimeDealsStack);
		g_IconOnlyIM:ReleaseInstanceByParent(iconList.For30TurnsDealsStack);

		local pDealItem : table;
		for pDealItem in pDeal:Items() do

			local type : number = pDealItem:GetType();
			if (pDealItem:GetFromPlayerID() == player:GetID()) then
				local iDuration : number = pDealItem:GetDuration();
				local dealItemID : number = pDealItem:GetID();
				-- Gold?
				if (type == DealItemTypes.GOLD) then
					local uiIcon : table;
					if (iDuration == 0) then
						-- One time
						uiIcon = g_IconOnlyIM:GetInstance(iconList.OneTimeDealsStack);
					else
						-- Multi-turn
						uiIcon = g_IconOnlyIM:GetInstance(iconList.For30TurnsDealsStack);

					end
					SetIconToSize(uiIcon.Icon, "ICON_YIELD_GOLD_5");
					uiIcon.AmountText:SetText(tostring(pDealItem:GetAmount()));
					uiIcon.AmountText:SetHide(false);
					uiIcon.Icon:SetColor(1,1,1);

					-- Show/hide unacceptable item notification
					uiIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());
					uiIcon.RemoveButton:SetHide(false);
				
					uiIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end)
					uiIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
					uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
					uiIcon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.
					uiIcon.SelectButton:SetDisabled(false);
					if (dealItemID == g_ValueEditDealItemID) then
						g_ValueEditDealItemControlTable = uiIcon;
					end
				else
					if (type == DealItemTypes.RESOURCES) then

						local resourceType :number = pDealItem:GetValueType();
						local uiIcon : table;
						if (iDuration == 0) then
							-- One time
							uiIcon = g_IconOnlyIM:GetInstance(iconList.OneTimeDealsStack);
						else
							-- Multi-turn
							uiIcon = g_IconOnlyIM:GetInstance(iconList.For30TurnsDealsStack);
						end
						local resourceDesc : table = GameInfo.Resources[resourceType];
						SetIconToSize(uiIcon.Icon, "ICON_" .. resourceDesc.ResourceType);
						uiIcon.AmountText:SetText(tostring(pDealItem:GetAmount()));
						uiIcon.AmountText:SetHide(false);
						uiIcon.Icon:SetColor(1,1,1);

						-- Show/hide unacceptable item notification
						uiIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

						local szToolTip : string = Locale.Lookup(resourceDesc.Name);

						local parentDealItem : table = pDeal:GetItemParent(pDealItem);

						if parentDealItem == nil then
							-- No parent, the user can click on the item to change it.
							uiIcon.RemoveButton:SetHide(false);
				
							uiIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end)
							uiIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
							uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
							uiIcon.SelectButton:SetDisabled(false);
						else
							uiIcon.SelectButton:ClearCallback( Mouse.eRClick );		-- Clear, we are re-using control instances
							uiIcon.SelectButton:ClearCallback( Mouse.eLClick );

							szToolTip = szToolTip .. GetParentItemTransferToolTip(parentDealItem);
						end

						-- Set a tool tip
						uiIcon.SelectButton:SetToolTipString(szToolTip);

						-- KWG: Make a way for the icon manager to have categories, so the API is like this
						-- uiIcon.Icon:SetTexture(IconManager:FindIconAtlasForType(IconTypes.RESOURCE, resourceType));

						if (dealItemID == g_ValueEditDealItemID) then
							g_ValueEditDealItemControlTable = uiIcon;
						end
					end --end else if the item isn't gold
				end -- end for each item in dael
			end -- end if deal
		end

		iconList.OneTimeDealsHeader:SetHide(table.count(iconList.OneTimeDealsStack:GetChildren()) == 0);
		iconList.For30TurnsDealsHeader:SetHide(table.count(iconList.For30TurnsDealsStack:GetChildren()) == 0);

		iconList.OfferStack:CalculateSize();

	end

end

-- ===========================================================================
function PopulateDealAgreements(player : table, iconList : table)

	local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local playerType : number = GetPlayerType(player);
	if (pDeal ~= nil) then
		g_IconAndTextIM:ReleaseInstanceByParent(iconList.AgreementDealsStack);
		g_IconOnlyIM:ReleaseInstanceByParent(iconList.MinimizedAgreementDealsStack);
		local pDealItem : table;
		for pDealItem in pDeal:Items() do

			local type : number = pDealItem:GetType();
			if (pDealItem:GetFromPlayerID() == player:GetID()) then
				local dealItemID : number = pDealItem:GetID();
				-- Agreement?
				if (type == DealItemTypes.AGREEMENTS) then
					local uiMinimizedIcon : table = g_IconOnlyIM:GetInstance(iconList.MinimizedAgreementDealsStack);
					local uiIcon : table = g_IconAndTextIM:GetInstance(iconList.AgreementDealsStack);
					local info: table = GameInfo.DiplomaticActions[ pDealItem:GetSubType() ];
					if (info ~= nil) then
						SetIconToSize(uiIcon.Icon, "ICON_".. info.DiplomaticActionType, 38);
						SetIconToSize(uiMinimizedIcon.Icon, "ICON_".. info.DiplomaticActionType, 38);
					end

					uiIcon.AmountText:SetHide(true);
					uiMinimizedIcon.AmountText:SetHide(true);
					uiMinimizedIcon.Icon:SetColor(1,1,1);

					local subTypeDisplayName : string = pDealItem:GetSubTypeNameID();
					if (subTypeDisplayName ~= nil) then
						uiIcon.IconText:LocalizeAndSetText(subTypeDisplayName);
						-- For alliances, it's useful to show the alliance type in the tooltip for the minimized version
						if pDealItem:GetSubType() == DealAgreementTypes.ALLIANCE and pDealItem:GetValueTypeNameID() ~= nil then
							local toolTip : string = Locale.Lookup(subTypeDisplayName).."[NEWLINE]"..Locale.Lookup(pDealItem:GetValueTypeNameID());
							uiMinimizedIcon.SelectButton:SetToolTipString(toolTip);
						else
							uiMinimizedIcon.SelectButton:SetToolTipString(Locale.Lookup(subTypeDisplayName));
						end
					end
					uiIcon.SelectButton:SetToolTipString(nil);		-- We recycle the entries, so make sure this is clear.

					-- Show/hide unacceptable item notification
					uiIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());
					uiMinimizedIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());
					
					if(pDealItem:IsLocked())then
						uiIcon.RemoveButton:SetHide(true);
						uiIcon.SelectButton:ClearCallback(Mouse.eRClick);

						uiMinimizedIcon.RemoveButton:SetHide(true);
						uiMinimizedIcon.SelectButton:ClearCallback(Mouse.eRClick);
					else
						uiIcon.RemoveButton:SetHide(false);
						uiIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
						uiIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);

						uiMinimizedIcon.RemoveButton:SetHide(false);
						uiMinimizedIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
						uiMinimizedIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
					end

					-- Populate the value pulldown
					SetValueText(uiIcon, pDealItem);

					local toolTip : string = uiMinimizedIcon.SelectButton:GetToolTipString();
					if(info.DiplomaticActionType == "DIPLOACTION_JOINT_WAR")then
						toolTip = toolTip .. "[NEWLINE]" .. Locale.Lookup(pDealItem:GetValueTypeNameID());
						uiMinimizedIcon.SelectButton:SetToolTipString(toolTip);
					end

					if(info.DiplomaticActionType == "DIPLOACTION_JOINT_WAR" and pDealItem:GetFromPlayerID() == g_OtherPlayer:GetID()) then
						uiIcon.SelectButton:SetDisabled(true);
						uiIcon.SelectButton:SetToolTipString(Locale.Lookup("LOC_JOINT_WAR_CANNOT_EDIT_THEIRS_TOOLTIP"));
						uiMinimizedIcon.SelectButton:SetDisabled(true);
						
						toolTip = toolTip .. "[NEWLINE]" .. Locale.Lookup("LOC_JOINT_WAR_CANNOT_EDIT_THEIRS_TOOLTIP");
						uiMinimizedIcon.SelectButton:SetToolTipString(toolTip);
					else
						uiIcon.SelectButton:SetDisabled(false);
						uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );

						uiMinimizedIcon.SelectButton:SetDisabled(false);
						uiMinimizedIcon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
					end
				end
			end
		end

		local itemCount : number = table.count(iconList.AgreementDealsStack:GetChildren());

		if(itemCount <= 1 and iconList.AgreementDealsStack:IsHidden())then
			OnDealsHeaderCollapseButton(iconList.AgreementDealsStack, iconList.MinimizedAgreementDealsStack, iconList.AgreementDealsExpandButton);
		end

		iconList.AgreementDealsExpandButton:SetHide(not (itemCount > 1));
		iconList.AgreementDealsGrid:SetHide(itemCount == 0);
		iconList.AgreementDealsHeader:SetHide(itemCount == 0);
		iconList.OfferStack:CalculateSize();

	end

end

-- ===========================================================================
function PopulateDealGreatWorks(player : table, iconList : table)

	local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local playerType : number = GetPlayerType(player);
	if (pDeal ~= nil) then
		g_IconAndTextIM:ReleaseInstanceByParent(iconList.GreatWorksDealsStack);
		g_IconOnlyIM:ReleaseInstanceByParent(iconList.MinimizedGreatWorksDealsStack);
		local pDealItem : table;
		for pDealItem in pDeal:Items() do

			local type = pDealItem:GetType();
			if (pDealItem:GetFromPlayerID() == player:GetID()) then
				local iDuration : number = pDealItem:GetDuration();
				local dealItemID : number = pDealItem:GetID();
				
				if (type == DealItemTypes.GREATWORK) then
					local uiIcon : table = g_IconAndTextIM:GetInstance(iconList.GreatWorksDealsStack);
					local uiMinimizedIcon : table = g_IconOnlyIM:GetInstance(iconList.MinimizedGreatWorksDealsStack);

					local typeID : string = pDealItem:GetValueTypeID();
					SetIconToSize(uiIcon.Icon, "ICON_" .. typeID, 45);
					SetIconToSize(uiMinimizedIcon.Icon, "ICON_" .. typeID, 45);

					uiIcon.AmountText:SetHide(true);
					uiMinimizedIcon.AmountText:SetHide(true);
					uiMinimizedIcon.Icon:SetColor(1,1,1);

					local typeName : string = pDealItem:GetValueTypeNameID();

					local strTooltip :string = "";

					if (typeName ~= nil) then
						uiIcon.IconText:LocalizeAndSetText(typeName);
						strTooltip = Locale.Lookup( GreatWorksSupport_GetBasicTooltip(pDealItem:GetValueType(), false) );
					else
						uiIcon.IconText:SetText(nil);
					end

					uiIcon.ValueText:SetHide(true);
					
					-- Show/hide unacceptable item notification
					uiIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());
					uiMinimizedIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

					local parentDealItem : table = pDeal:GetItemParent(pDealItem);

					if parentDealItem == nil then
						-- No parent, we can remove independently
						uiIcon.RemoveButton:SetHide(false);
						uiIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
						uiIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
						uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
						uiIcon.SelectButton:SetDisabled(false);

						uiMinimizedIcon.RemoveButton:SetHide(false);
						uiMinimizedIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
						uiMinimizedIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
						uiMinimizedIcon.SelectButton:SetDisabled(false);
					else
						uiIcon.SelectButton:ClearCallback( Mouse.eRClick );
						uiIcon.SelectButton:ClearCallback( Mouse.eLClick );

						uiMinimizedIcon.SelectButton:ClearCallback( Mouse.eRClick );
						uiMinimizedIcon.SelectButton:ClearCallback( Mouse.eLClick );

						-- Add on to the tool tip to show why it is there.
						strTooltip = strTooltip .. GetParentItemTransferToolTip(parentDealItem);
					end

					uiIcon.SelectButton:SetToolTipString(strTooltip);
					uiMinimizedIcon.SelectButton:SetToolTipString(strTooltip);
				end
			end
		end

		local itemCount : number = table.count(iconList.GreatWorksDealsStack:GetChildren());

		if(itemCount <= 1 and iconList.GreatWorksDealsStack:IsHidden())then
			OnDealsHeaderCollapseButton(iconList.GreatWorksDealsStack, iconList.MinimizedGreatWorksDealsStack, iconList.GreatWorksDealsExpandButton);
		end

		iconList.GreatWorksDealsExpandButton:SetHide(not (itemCount > 1));
		iconList.GreatWorksDealsGrid:SetHide(itemCount == 0);
		iconList.GreatWorksDealsHeader:SetHide(itemCount == 0);
		iconList.OfferStack:CalculateSize();

	end

end

-- ===========================================================================
function PopulateDealCaptives(player : table, iconList : table)

	PopulateDealBasic(player, iconList, DealItemTypes.CAPTIVE, "ICON_UNIT_SPY");

end

-- ===========================================================================
function PopulateDealCities(player : table, iconList : table)

	local pDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
	local playerType : number = GetPlayerType(player);
	if (pDeal ~= nil) then

		ms_CityDetailsIM:ReleaseInstanceByParent(iconList.CityDealsStack);
		g_IconOnlyIM:ReleaseInstanceByParent(iconList.MinimizedCityDealsStack);

		local pDealItem : table;
		for pDealItem in pDeal:Items() do

			local type : number = pDealItem:GetType();
			if (pDealItem:GetFromPlayerID() == player:GetID()) then
				local dealItemID : number = pDealItem:GetID();
				
				if (type == DealItemTypes.CITIES) then
					local uiMinimizedIcon : table = g_IconOnlyIM:GetInstance(iconList.MinimizedCityDealsStack);
					SetIconToSize(uiMinimizedIcon.Icon, "ICON_BUILDINGS");

					local uiIcon : table = ms_CityDetailsIM:GetInstance(iconList.CityDealsStack);
					SetIconToSize(uiIcon.Icon, "ICON_BUILDINGS");
					uiIcon.AmountText:SetHide(true);
					local typeName : string = pDealItem:GetValueTypeNameID();
					if (typeName ~= nil) then
						uiIcon.IconText:LocalizeAndSetText(typeName);
					end

					-- Show/hide unacceptable item notification
					uiIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());
					uiMinimizedIcon.UnacceptableIcon:SetHide(not pDealItem:IsUnacceptable());

					if(pDealItem:IsLocked())then
						uiIcon.RemoveButton:SetHide(true);
						uiIcon.SelectButton:ClearCallback(Mouse.eRClick);

						uiMinimizedIcon.RemoveButton:SetHide(true);
						uiMinimizedIcon.SelectButton:ClearCallback(Mouse.eRClick);
					else
						uiIcon.RemoveButton:SetHide(false);
						uiIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealCity(typeName, player, dealItemID, self); end);
						uiIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealCity(typeName, player, dealItemID, self); end);

						uiMinimizedIcon.RemoveButton:SetHide(false);
						uiMinimizedIcon.SelectButton:RegisterCallback(Mouse.eRClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
					end

					uiIcon.SelectButton:RegisterCallback( Mouse.eLClick, function(void1, void2, self) OnSelectValueDealItem(player, dealItemID, self); end );
					uiIcon.SelectButton:SetDisabled(false);
					
					
					
					uiMinimizedIcon.RemoveButton:RegisterCallback(Mouse.eLClick, function(void1, void2, self) OnRemoveDealItem(player, dealItemID, self); end);
					uiMinimizedIcon.SelectButton:SetDisabled(false);
					uiMinimizedIcon.Icon:SetColor(1,1,1);

					uiIcon.SelectButton:SetToolTipString( MakeCityToolTip(player, pDealItem:GetValueType() ) );
					uiMinimizedIcon.SelectButton:SetToolTipString(Locale.Lookup(typeName).."[NEWLINE]"..MakeCityToolTip(player, pDealItem:GetValueType() ));
					local hasChildDealItems : boolean = false;

					--Check if this city comes with dependants (resources or great works)
					for pChildDealItem in pDeal:Items() do
						if (pDeal:GetItemParent(pChildDealItem) == pDealItem) then
							hasChildDealItems = true;
							local type : number = pChildDealItem:GetType();
							local childIcon : table = g_IconOnlyIM:GetInstance(uiIcon.CityDetailsStack);

							if(type == DealItemTypes.RESOURCES)then
								childIcon.AmountText:SetText(tostring(pChildDealItem:GetAmount()));
								childIcon.AmountText:SetHide(false);
								
								local resourceDescription : table = GameInfo.Resources[pChildDealItem:GetValueType()];
								SetIconToSize(childIcon.Icon, "ICON_" .. resourceDescription.ResourceType);
								
								local childToolTip : string = Locale.Lookup(resourceDescription.Name);
								childIcon.SelectButton:SetToolTipString(childToolTip);

							elseif(type == DealItemTypes.GREATWORK) then
								childIcon.AmountText:SetHide(true);

								local childToolTip : string = Locale.Lookup(GreatWorksSupport_GetBasicTooltip(pChildDealItem:GetValueType(), false))
								childIcon.SelectButton:SetToolTipString(childToolTip);

								local childTypeID : string = pChildDealItem:GetValueTypeID();
								SetIconToSize(childIcon.Icon, "ICON_"..childTypeID,45);
							end
						end
					end
					uiIcon.CollapseButton:RegisterCallback(Mouse.eLClick, function() OnCityDetailsCollapse(uiIcon.CityDetails, typeName, uiIcon.CollapseButton); end);
					uiIcon.CollapseButton:SetHide(not hasChildDealItems);
					if(m_kCollapsedCityDetails[typeName])then
						uiIcon.CityDetails:SetHide(false);
					end
				end
			end
		end

		local itemCount : number = table.count(iconList.CityDealsStack:GetChildren());

		if(itemCount <= 1 and iconList.CityDealsStack:IsHidden())then
			OnDealsHeaderCollapseButton(iconList.CityDealsStack, iconList.MinimizedCityDealsStack, iconList.CityDealsExpandButton);
		end

		iconList.CityDealsHeader:SetHide(itemCount == 0);
		iconList.CityDealsExpandButton:SetHide(not (itemCount > 1));
		iconList.CityDealsGrid:SetHide(itemCount == 0);
		iconList.OfferStack:CalculateSize();
	end


end

-- ===========================================================================
function PopulatePlayerDealPanel(rootControl : table, player : table)

	if (player ~= nil) then
		
		local playerType : number = GetPlayerType(player);
		PopulateDealResources(player, ms_DealGroups[DealItemGroupTypes.RESOURCES][playerType]);
		PopulateDealAgreements(player, ms_DealGroups[DealItemGroupTypes.AGREEMENTS][playerType]);
		PopulateDealCaptives(player, ms_DealGroups[DealItemGroupTypes.CAPTIVES][playerType]);
		PopulateDealGreatWorks(player, ms_DealGroups[DealItemGroupTypes.GREAT_WORKS][playerType]);
		PopulateDealCities(player, ms_DealGroups[DealItemGroupTypes.CITIES][playerType]);

		rootControl.OfferStack:CalculateSize();
	end
end

-- ===========================================================================
function HandleESC()
	-- Were we just viewing the deal?
	if ( m_kPopupDialog:IsOpen()) then
			m_kPopupDialog:Close();
	elseif (not Controls.ResumeGame:IsHidden()) then
		OnResumeGame();
	else
		OnRefuseDeal();
	end
end

-- ===========================================================================
--	INPUT Handlings
--	If this context is visible, it will get a crack at the input.
-- ===========================================================================
function KeyHandler( key:number )
	if (key == Keys.VK_ESCAPE) then 
		HandleESC();			
		return true; 
	end

	return false;
end

-- ===========================================================================
function InputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		return KeyHandler( pInputStruct:GetKey() ); 
	end
	if (uiMsg == MouseEvents.LButtonUp or
		uiMsg == MouseEvents.RButtonUp or
		uiMsg == MouseEvents.MButtonUp or
		uiMsg == MouseEvents.PointerUp) then 
		ClearValueEdit();
	end

	return false;
end

-- ===========================================================================
--	Handle a request to be shown, this should only be called by
--  the diplomacy statement handler.
-- ===========================================================================

function OnShowMakeDeal(otherPlayerID)
	ms_OtherPlayerID = otherPlayerID;
	ms_bIsDemand = false;
	ContextPtr:SetHide( false );
end
LuaEvents.DiploPopup_ShowMakeDeal.Add(OnShowMakeDeal);

-- ===========================================================================
--	Handle a request to be shown, this should only be called by
--  the diplomacy statement handler.
-- ===========================================================================

function OnShowMakeDemand(otherPlayerID)
	ms_OtherPlayerID = otherPlayerID;
	ms_bIsDemand = true;
	ContextPtr:SetHide( false );
end
LuaEvents.DiploPopup_ShowMakeDemand.Add(OnShowMakeDemand);

-- ===========================================================================
--	Handle a request to be hidden, this should only be called by
--  the diplomacy statement handler.
-- ===========================================================================

function OnHideDeal(otherPlayerID)
	OnContinue();
end
LuaEvents.DiploPopup_HideDeal.Add(OnHideDeal);

-- ===========================================================================
-- The other player has updated the deal
function OnDiplomacyIncomingDeal(eFromPlayer, eToPlayer, eAction)
	if (eFromPlayer == ms_OtherPlayerID) then
		local pDeal = DealManager.GetWorkingDeal(DealDirection.INCOMING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		if (pDeal ~= nil) then
			ms_bIsGift = pDeal:IsGift();

			-- Copy the deal to our OUTGOING deal back to the other player, in case we want to make modifications
			DealManager.CopyIncomingToOutgoingWorkingDeal(g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
			ms_LastIncomingDealProposalAction = eAction;

			PopulatePlayerDealPanel(g_uiTheirOffers, g_OtherPlayer);
			PopulatePlayerDealPanel(g_uiMyOffers, g_LocalPlayer);
			UpdateDealStatus();
		end
	end
end
Events.DiplomacyIncomingDeal.Add(OnDiplomacyIncomingDeal);

-- ===========================================================================
--	Handle a deal changing, usually from an incoming statement.
-- ===========================================================================

function OnDealUpdated(otherPlayerID, eAction, szText)
	if (not ContextPtr:IsHidden()) then
		-- Display some updated text.
		if (szText ~= nil and szText ~= "") then
			SetLeaderDialog(szText, "");
		end			
		-- Update deal and possible override text from szText
		OnDiplomacyIncomingDeal( otherPlayerID, Game.GetLocalPlayer(), eAction); 
	end
end
LuaEvents.DiploPopup_DealUpdated.Add(OnDealUpdated);

-- ===========================================================================
function SetLeaderDialog(leaderDialog:string, leaderEffect:string)
	-- Update dialog
	Controls.LeaderDialog:LocalizeAndSetText(leaderDialog);

	-- Add parentheses to the effect text unless the text is ""
	if leaderEffect ~= "" then
		leaderEffect = "(" .. Locale.Lookup(leaderEffect) .. ")";
	end
	Controls.LeaderEffect:SetText(leaderEffect);

	-- Recenter text
	Controls.LeaderDialogStack:CalculateSize();
end

-- ===========================================================================
function StartExitAnimation()
	-- Start the exit animation, it will call OnContinue when complete
	ms_bExiting = true;
	Controls.YieldSlide:Reverse();
	Controls.YieldAlpha:Reverse();
	Controls.TradePanelFade:Reverse();
	Controls.TradePanelSlide:Reverse();
	Controls.TradePanelFade:SetSpeed(5);
	Controls.TradePanelSlide:SetSpeed(5);
	UI.PlaySound("UI_Diplomacy_Menu_Change");
end

-- ===========================================================================
function OnContinue()
	ContextPtr:SetHide( true );
end

-- ===========================================================================
--	Functions for setting the data in the yield area
-- ===========================================================================

function FormatValuePerTurn( value:number )
	return Locale.ToNumber(value, "+#,###.#;-#,###.#");
end

function RefreshYields()

	local ePlayer		:number = Game.GetLocalPlayer();
	local localPlayer	:table= nil;
	if ePlayer ~= -1 then
		localPlayer = Players[ePlayer];
		if localPlayer == nil then
			return;
		end
	else
		return;
	end

	---- SCIENCE ----
	local playerTechnology		:table	= localPlayer:GetTechs();
	local currentScienceYield	:number = playerTechnology:GetScienceYield();
	Controls.SciencePerTurn:SetText( FormatValuePerTurn(currentScienceYield) );	
	Controls.ScienceBacking:SetToolTipString( GetScienceTooltip() );
	Controls.ScienceStack:CalculateSize();
	
	---- CULTURE----
	local playerCulture			:table	= localPlayer:GetCulture();
	local currentCultureYield	:number = playerCulture:GetCultureYield();
	Controls.CulturePerTurn:SetText( FormatValuePerTurn(currentCultureYield) );	
	Controls.CultureBacking:SetToolTipString( GetCultureTooltip() );
	Controls.CultureStack:CalculateSize();

	---- GOLD ----
	local playerTreasury:table	= localPlayer:GetTreasury();
	local goldYield		:number = playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance();
	local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());
	Controls.GoldBalance:SetText( Locale.ToNumber(goldBalance, "#,###.#"));	
	Controls.GoldPerTurn:SetText( FormatValuePerTurn(goldYield) );	
	Controls.GoldBacking:SetToolTipString(GetGoldTooltip());
	Controls.GoldStack:CalculateSize();	
	
	---- FAITH ----
	local playerReligion		:table	= localPlayer:GetReligion();
	local faithYield			:number = playerReligion:GetFaithYield();
	local faithBalance			:number = playerReligion:GetFaithBalance();
	Controls.FaithBalance:SetText( Locale.ToNumber(faithBalance, "#,###.#"));	
	Controls.FaithPerTurn:SetText( FormatValuePerTurn(faithYield) );
	Controls.FaithBacking:SetToolTipString( GetFaithTooltip() );
	Controls.FaithStack:CalculateSize();	
	if (faithYield == 0) then
		Controls.FaithBacking:SetHide(true);
	else
		Controls.FaithBacking:SetHide(false);
	end
	
	Controls.YieldStack:CalculateSize();
end

-- ===========================================================================
function OnRemoveDealCity(name : string, player : table, itemID : number)
	m_kCollapsedCityDetails[name] = nil;
	OnRemoveDealItem(player, itemID);
end

-- ===========================================================================
function OnCityDetailsCollapse(control : table, name : string, button : table)
	control:SetHide(not control:IsHidden());
	if(control:IsHidden()) then
		m_kCollapsedCityDetails[name] = nil;
		button:LocalizeAndSetToolTip("LOC_DIPLO_DEAL_EXPAND_CITY_INFO");
	else
		m_kCollapsedCityDetails[name] = true;
		button:LocalizeAndSetToolTip("LOC_DIPLO_DEAL_COLLAPSE_CITY_INFO");
	end
end

-- ===========================================================================
function OnDealsHeaderCollapseButton(control : table, minimizedControl : table, button : table)
	if(control["isCollapsed"] == nil) then
		control["isCollapsed"] = false;
	end
	control["isCollapsed"] = not control["isCollapsed"];
	control:SetHide(control["isCollapsed"]);
	minimizedControl:SetHide(not control["isCollapsed"]);
	control:CalculateSize();
	if(control["isCollapsed"]) then
		button:SetTexture("Controls_CategoryExpand");
		button:LocalizeAndSetToolTip("LOC_DIPLO_DEAL_EXPAND_CATEGORY");
	else
		button:SetTexture("Controls_CategoryCollapse");
		button:LocalizeAndSetToolTip("LOC_DIPLO_DEAL_COLLAPSE_CATEGORY");
	end
end

-- ===========================================================================
function OnDragResizer()
	local mouseX : number, mouseY : number = UIManager:GetMousePos();

	--How far has the mouse traveled while dragging?
	local yDiff : number = m_StartingMouseY - mouseY;
	yDiff = math.clamp(yDiff, m_MinDragResizeY, m_MaxDragResizeY);

	Controls.OfferColumns:SetSizeY(m_OffersStartSizeY - yDiff);
	Controls.InventoryColumns:SetSizeY(m_InvStartSizeY + yDiff);
	Controls.DragButton:SetOffsetY((m_InvStartSizeY + yDiff) - 20);
end

-- ===========================================================================
function OnShow()
	RefreshYields();
	Controls.YieldAlpha:SetToBeginning();
	Controls.YieldAlpha:Play();
	Controls.YieldSlide:SetToBeginning();
	Controls.YieldSlide:Play();
	Controls.TradePanelFade:SetToBeginning();
	Controls.TradePanelFade:Play();
	Controls.TradePanelSlide:SetToBeginning();
	Controls.TradePanelSlide:Play();
	Controls.LeaderDialogFade:SetToBeginning();
	Controls.LeaderDialogFade:Play();
	Controls.LeaderDialogSlide:SetToBeginning();
	Controls.LeaderDialogSlide:Play();
	Controls.ValueEditPopupBackground:SetHide(true);

	g_IconOnlyIM:ResetInstances();
	g_IconAndTextIM:ResetInstances();
	ms_MinimizedSectionIM:ResetInstances();

	--Reset the cityDetails states to closed
	m_kCollapsedCityDetails = {};

	ms_bExiting = false;

	if (Game.GetLocalPlayer() == -1) then
		return;
	end

	-- For hotload testing, force the other player to be valid
	if (ms_OtherPlayerID == -1) then
		local playerID = 0
		for playerID = 0, GameDefines.MAX_PLAYERS-1, 1 do
			if (playerID ~= Game.GetLocalPlayer() and Players[playerID]:IsAlive()) then
				ms_OtherPlayerID = playerID;
				break;
			end
		end
	end

	-- Set up some globals for easy access
	g_LocalPlayer = Players[Game.GetLocalPlayer()];
	g_OtherPlayer = Players[ms_OtherPlayerID];
	ms_OtherPlayerIsHuman = g_OtherPlayer:IsHuman();

	local sessionID = DiplomacyManager.FindOpenSessionID(Game.GetLocalPlayer(), g_OtherPlayer:GetID());
	if (sessionID ~= nil) then
		local sessionInfo = DiplomacyManager.GetSessionInfo(sessionID);
		ms_InitiatedByPlayerID = sessionInfo.FromPlayer;
	end

	-- Did the AI start this or the human?
	if (ms_InitiatedByPlayerID == ms_OtherPlayerID) then
		ms_LastIncomingDealProposalAction = DealProposalAction.PROPOSED;
		
		local pDeal = DealManager.GetWorkingDeal(DealDirection.INCOMING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		ms_bIsGift = pDeal:IsGift();

		DealManager.CopyIncomingToOutgoingWorkingDeal(g_LocalPlayer:GetID(), g_OtherPlayer:GetID());

		local pDeal = DealManager.GetWorkingDeal(DealDirection.INCOMING, g_LocalPlayer:GetID(), g_OtherPlayer:GetID());
		ms_bIsGift = pDeal:IsGift();
	else
		ms_LastIncomingDealProposalAction = DealProposalAction.PENDING;
		-- We are NOT clearing the current outgoing deal. This allows other screens to pre-populate the deal.
	end

	UpdateOtherPlayerText(1);
	SetDefaultLeaderDialogText();

	local availableItemCount : number = 0;
	-- Available content to trade.  Shouldn't change during the session, but it might, especially in multiplayer.
	availableItemCount = availableItemCount + PopulatePlayerAvailablePanel(Controls.MyInventoryStack, g_LocalPlayer);
	availableItemCount = availableItemCount + PopulatePlayerAvailablePanel(Controls.TheirInventoryStack, g_OtherPlayer);

	Controls.MyInventoryScroll:CalculateSize();
	Controls.TheirInventoryScroll:CalculateSize();

	m_kPopupDialog:Close(); -- Close and reset the popup in case it's open

	if (availableItemCount == 0) then
		if (ms_bIsDemand) then
			m_kPopupDialog:AddText(Locale.Lookup("LOC_DIPLO_DEMAND_NO_AVAILABLE_ITEMS"));
			m_kPopupDialog:AddTitle( Locale.ToUpper(Locale.Lookup("LOC_DIPLO_CHOICE_MAKE_DEMAND")))
			m_kPopupDialog:AddButton( Locale.Lookup("LOC_OK_BUTTON"), OnRefuseDeal);
		else
			m_kPopupDialog:AddText(	  Locale.Lookup("LOC_DIPLO_DEAL_NO_AVAILABLE_ITEMS"));
			m_kPopupDialog:AddTitle( Locale.ToUpper(Locale.Lookup("LOC_DIPLO_CHOICE_MAKE_DEAL")))
			m_kPopupDialog:AddButton( Locale.Lookup("LOC_OK_BUTTON"), OnRefuseDeal);
		end
		m_kPopupDialog:Open();
	end

	PopulatePlayerDealPanel(g_uiTheirOffers, g_OtherPlayer);
	PopulatePlayerDealPanel(g_uiMyOffers, g_LocalPlayer);
	UpdateDealStatus();

	-- We may be coming into this screen with a deal already set, which needs to be sent to the AI for inspection. Check that.
	-- Don't send AI proposals for inspection or they will think the player was the creator of the deal
	if (IsAutoPropose() and (ms_InitiatedByPlayerID ~= ms_OtherPlayerID or ms_OtherPlayerIsHuman)) then
		ProposeWorkingDeal(true);
	end

	Controls.MyOfferScroll:CalculateSize();
	Controls.TheirOfferScroll:CalculateSize();

	LuaEvents.DiploBasePopup_HideUI(true);
	TTManager:ClearCurrent();	-- Clear any tool tips raised;

	Controls.DealOptionsStack:CalculateSize();
end

----------------------------------------------------------------    
function OnHide()
	LuaEvents.DiploBasePopup_HideUI(false);
end

-- ===========================================================================
--	Context CTOR
-- ===========================================================================
function OnInit( isHotload )
	LateInitialize();

	if (isHotload and not ContextPtr:IsHidden()) then
		OnShow();
	end
end

-- ===========================================================================
--	Context DESTRUCTOR
--	Not called when screen is dismissed, only if the whole context is removed!
-- ===========================================================================
function OnShutdown()

end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if (not ContextPtr:IsHidden()) then
		-- Were we just viewing the deal?
		if (not Controls.ResumeGame:IsHidden()) then
			OnResumeGame();
		else
			OnRefuseDeal(true);
		end
		OnContinue();
	end
end

-- ===========================================================================
function OnPlayerDefeat( player, defeat, eventID)
	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer and localPlayer >= 0) then		-- Check to see if there is any local player
		-- Was it the local player?
		if (localPlayer == player) then
			OnLocalPlayerTurnEnd();
		end
	end
end

-- ===========================================================================
function OnTeamVictory(team, victory, eventID)

	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer and localPlayer >= 0) then		-- Check to see if there is any local player
		OnLocalPlayerTurnEnd();
	end
end

-- ===========================================================================
--	Engine Event
-- ===========================================================================
function OnUserRequestClose()
	-- Is this showing; if so then it needs to raise dialog to handle close
	if (not ContextPtr:IsHidden()) then
		m_kPopupDialog:Reset();
		m_kPopupDialog:AddText(Locale.Lookup("LOC_CONFIRM_EXIT_TXT"));
		m_kPopupDialog:AddButton(Locale.Lookup("LOC_YES"), OnQuitYes, nil, nil, "PopupButtonInstanceRed");
		m_kPopupDialog:AddButton(Locale.Lookup("LOC_NO"), nil);
		m_kPopupDialog:Open();
	end
end
function OnQuitYes()
	Events.UserConfirmedClose();
end

-- ===========================================================================
function LateInitialize()
	CreateGroupTypes();
	InitializeDealGroups();
	CreatePanels();
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( InputHandler, true );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );

	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
	Events.PlayerDefeat.Add( OnPlayerDefeat );
	Events.TeamVictory.Add( OnTeamVictory );

	Events.UserRequestClose.Add( OnUserRequestClose );

	m_kPopupDialog = PopupDialog:new( "DiplomacyDealView" );

	ContextPtr:BuildInstanceForControl("MyOffers", g_uiMyOffers, Controls.MyOfferScroll);
	ContextPtr:BuildInstanceForControl("TheirOffers", g_uiTheirOffers, Controls.TheirOfferScroll);

	g_uiMyOffers.CityDealsExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(g_uiMyOffers.CityDealsStack, g_uiMyOffers.MinimizedCityDealsStack, g_uiMyOffers.CityDealsExpandButton); end);
	g_uiTheirOffers.CityDealsExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(g_uiTheirOffers.CityDealsStack, g_uiTheirOffers.MinimizedCityDealsStack, g_uiTheirOffers.CityDealsExpandButton); end);

	g_uiMyOffers.GreatWorksDealsExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(g_uiMyOffers.GreatWorksDealsStack, g_uiMyOffers.MinimizedGreatWorksDealsStack, g_uiMyOffers.GreatWorksDealsExpandButton); end);
	g_uiTheirOffers.GreatWorksDealsExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(g_uiTheirOffers.GreatWorksDealsStack, g_uiTheirOffers.MinimizedGreatWorksDealsStack, g_uiTheirOffers.GreatWorksDealsExpandButton); end);

	g_uiMyOffers.AgreementDealsExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(g_uiMyOffers.AgreementDealsStack, g_uiMyOffers.MinimizedAgreementDealsStack, g_uiMyOffers.AgreementDealsExpandButton); end);
	g_uiTheirOffers.AgreementDealsExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(g_uiTheirOffers.AgreementDealsStack, g_uiTheirOffers.MinimizedAgreementDealsStack, g_uiTheirOffers.AgreementDealsExpandButton); end);

	g_uiMyOffers.CaptivesDealsExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(g_uiMyOffers.CaptivesDealsStack, g_uiMyOffers.MinimizedCaptivesDealsStack, g_uiMyOffers.CaptivesDealsExpandButton); end);
	g_uiTheirOffers.CaptivesDealsExpandButton:RegisterCallback(Mouse.eLClick, function() OnDealsHeaderCollapseButton(g_uiTheirOffers.CaptivesDealsStack, g_uiTheirOffers.MinimizedCaptivesDealsStack, g_uiTheirOffers.CaptivesDealsExpandButton); end);

	m_OffersStartSizeY = Controls.OfferColumns:GetSizeY();
	m_InvStartSizeY = Controls.InventoryColumns:GetSizeY();

	Controls.DragButton:SetOffsetY(m_InvStartSizeY - 20);

	m_StartingMouseX, m_StartingMouseY = Controls.DragButton:GetScreenOffset();
	m_StartingMouseY = m_StartingMouseY + 24;
	m_MinDragResizeY = m_MinDragResizeY - m_InvStartSizeY;

	Controls.DragSizer:RegisterCallback(Drag.eDrag, function() OnDragResizer(); end);

	--This option requires a restart after changing, so we only need to check it at initialize
	local replaceDragWithClick : number = Options.GetUserOption("Interface", "ReplaceDragWithClick");
	if(replaceDragWithClick == 1)then
		Controls.DragButton:LocalizeAndSetToolTip("LOC_DIPLOMACY_DRAG_BUTTON_CLICK_TOOLTIP");
	end
end

Initialize();
