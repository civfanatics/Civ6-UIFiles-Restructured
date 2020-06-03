-- ===========================================================================
--	UI for managing and appointing Governors	
-- ===========================================================================

include("InstanceManager");
include("TabSupport");
include("SupportFunctions");
include("Civ6Common");
include("ModalScreen_PlayerYieldsHelper");
include("GovernorSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "GovernorDetailsPanel"; -- Must be unique (usually the same as the file name)

local PROMOTION_X_OFFSET = 110;
local PROMOTION_Y_OFFSET = 147;
local PROMOTION_LINE_Y_OFFSET = 77;
local EXTRA_MIDDLE_PROMOTION_LINE_X_OFFSET = 20;
local PROMOTION_NAME_TRUNCATE_WIDTH = 195;

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_PromotionIM:table = InstanceManager:new("PromotionInstance", "PromotionButton", Controls.PromotionContainer);

local m_ReqLinesLeftIM:table = InstanceManager:new("ReqLinesLeft", "Top", Controls.PromotionLinesContainer);
local m_ReqLinesRightIM:table = InstanceManager:new("ReqLinesRight", "Top", Controls.PromotionLinesContainer);
local m_ReqLinesDownIM:table = InstanceManager:new("ReqLinesDown", "Top", Controls.PromotionLinesContainer);

local m_GovernorIndex:number = -1;

local m_SelectedPromotion:number = -1;

local m_TopPanelConsideredHeight:number = 0;
-- ===========================================================================
function Refresh()
	local localPlayerID:number = Game.GetLocalPlayer();
	if m_GovernorIndex == -1 or localPlayerID==-1 then
		return;
	end

	local pGovernorDef:table = GameInfo.Governors[m_GovernorIndex];	
	local pGovernor:table = GetAppointedGovernor(localPlayerID, m_GovernorIndex);
	local pLocalPlayer:table = Players[localPlayerID];
	local pPlayerGovernors:table = pLocalPlayer:GetGovernors();

	-- Update governor name and title
	Controls.GovernorNameLabel:SetText(Locale.ToUpper(pGovernorDef.Name));
	Controls.GovernorTitleLabel:SetText(Locale.Lookup(pGovernorDef.Title));
	Controls.GovernorBioLabel:SetText(Locale.Lookup(pGovernorDef.Description));

	-- Update governor portrait
	Controls.GovernorPortrait:SetTexture(pGovernorDef.PortraitImageSelected);

	-- Update governor transition strength and identity pressure
	Controls.TransitionStrengthLabel:SetText(pPlayerGovernors:GetTurnsToEstablish(pGovernorDef.Hash));
	Controls.IdentityPressureLabel:SetText(pGovernorDef.IdentityPressure);

	if pGovernor then
		local pAssignedCity:table = pGovernor:GetAssignedCity();
		if pAssignedCity then
			Controls.AssignButtonLabel:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_BUTTON_REASSIGN_GOVERNOR"));
		else
			Controls.AssignButtonLabel:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_BUTTON_ASSIGN_GOVERNOR"));
		end
		Controls.AssignButton:SetVoid1(pGovernorDef.Index);
		Controls.AssignButton:RegisterCallback( Mouse.eLClick, OnAssignGovernor );
		local bCanAssign:boolean = pPlayerGovernors:HasGovernor(pGovernorDef.Hash) and pGovernor:GetNeutralizedTurns() == 0;
		Controls.AssignButton:SetDisabled(not bCanAssign);
	else
		Controls.AssignButtonLabel:SetText(Locale.Lookup("LOC_GOVERNORS_SCREEN_BUTTON_APPOINT_GOVERNOR"));
		Controls.AssignButton:SetVoid1(pGovernorDef.Index);
		Controls.AssignButton:RegisterCallback( Mouse.eLClick, OnAppointGovernor );
		local bCanAppoint:boolean = pPlayerGovernors:CanAppoint();
		Controls.AssignButton:SetDisabled(not bCanAppoint);
	end

	SetGovernorStatus(pGovernorDef, pGovernor);

	-- Define promotion tree matrix used to determine promotion requirement lines
	local promotionTreeMatrix:table = {{}, {}, {}};

	-- Create the promotion button instances and fill the promotion matrix
	m_PromotionIM:ResetInstances();
	for promotionSet in GameInfo.GovernorPromotionSets() do
		if promotionSet.GovernorType == pGovernorDef.GovernorType then
			local promotion = GameInfo.GovernorPromotions[promotionSet.GovernorPromotion];
			if promotion.BaseAbility then
				local iconName:string = "ICON_" .. pGovernorDef.GovernorType .. "_PROMOTION";
				Controls.BaseAbilityIcon:SetIcon(iconName);
				Controls.BaseAbilityLabel:SetText(Locale.Lookup(promotion.Description));
			else
				if promotion.Level ~= 0 then
					local promotionInst:table = m_PromotionIM:GetInstance();
					TruncateStringWithTooltip(promotionInst.PromotionName, PROMOTION_NAME_TRUNCATE_WIDTH, Locale.ToUpper(promotion.Name));
					promotionInst.PromotionDesc:SetText(Locale.Lookup(promotion.Description));

					local xOffset = PROMOTION_X_OFFSET * (promotion.Column);
					-- Subtract 1 from level to discount the BaseAbility which is the only level 0 promotion
					local yOffset = PROMOTION_Y_OFFSET * (promotion.Level - 1);
					promotionInst.PromotionButton:SetOffsetVal(xOffset, yOffset);

					-- Determine if this promotion can currently be earn by this governor due to requirements, etc
					local canEarnPromotion = pPlayerGovernors:CanEarnPromotion(pGovernorDef.Hash, promotion.Hash);

					-- Update button state and callback depending on the promotion state
					if pGovernor and pGovernor:HasPromotion(promotion.Hash) then
						promotionInst.PromotionButton:SetDisabled(true);
						promotionInst.PromotionButton:SetVisState(4);
						promotionInst.PromotionButton:ClearCallback( Mouse.eLClick );
					elseif m_SelectedPromotion == promotion.Index then
						promotionInst.PromotionButton:SetDisabled(false);
						promotionInst.PromotionButton:SetSelected(true);
						promotionInst.PromotionButton:SetVisState(5);
						promotionInst.PromotionButton:SetVoid1(m_GovernorIndex);
						promotionInst.PromotionButton:SetVoid2(promotion.Index);
						promotionInst.PromotionButton:RegisterCallback( Mouse.eLClick, OnPromoteGovernor );
					elseif not canEarnPromotion then
						promotionInst.PromotionButton:SetDisabled(true);
						promotionInst.PromotionButton:SetSelected(false);
						promotionInst.PromotionButton:SetVisState(3);
						promotionInst.PromotionButton:ClearCallback( Mouse.eLClick );
					else
						promotionInst.PromotionButton:SetDisabled(false);
						promotionInst.PromotionButton:SetSelected(false);
						promotionInst.PromotionButton:SetVisState(0);
						promotionInst.PromotionButton:SetVoid1(m_GovernorIndex);
						promotionInst.PromotionButton:SetVoid2(promotion.Index);
						promotionInst.PromotionButton:RegisterCallback( Mouse.eLClick, OnPromoteGovernor );
					end

					-- Insert this promotion into the matrix
					local matrixX = promotion.Column + 1;
					local matrixY = promotion.Level;
					if matrixX >= 1 and matrixX <= 3 and matrixY >= 1 and matrixY <= 3 then
						promotionTreeMatrix[matrixX][matrixY] = promotion;
					end
				end
			end
		end
	end

	m_ReqLinesLeftIM:ResetInstances();
	m_ReqLinesRightIM:ResetInstances();
	m_ReqLinesDownIM:ResetInstances();

	-- Loop through the matrix to determine where we have to display requirement lines
	for x=1,3,1 do
		for y=1,2,1 do
			local promotion = promotionTreeMatrix[x][y];
			if promotion then
				
				local xOffset = PROMOTION_X_OFFSET * (x - 1);
				local yOffset = (PROMOTION_Y_OFFSET * (y - 1)) + PROMOTION_LINE_Y_OFFSET;

				-- Check if we unlock the promotion below us
				local promotionBelow = promotionTreeMatrix[x][y+1]
				if promotionBelow then
					local inst = m_ReqLinesDownIM:GetInstance();
					inst.Top:SetOffsetVal(xOffset, yOffset);
				end

				-- Check if we unlock the promotion to the right of us
				if x < 3 then
					local promotionToRight = promotionTreeMatrix[x+1][y+1];
					if promotionToRight then
						local inst = m_ReqLinesRightIM:GetInstance();
						local adjustedXOffset = x ~= 2 and xOffset or xOffset + EXTRA_MIDDLE_PROMOTION_LINE_X_OFFSET;
						inst.Top:SetOffsetVal(adjustedXOffset, yOffset);
					end
				end

				-- Check if we unlock the promotion to the left of us
				if x > 1 then
					local promotionToLeft = promotionTreeMatrix[x-1][y+1];
					if promotionToLeft then
						local inst = m_ReqLinesLeftIM:GetInstance();
						local adjustedXOffset = x ~= 2 and xOffset or xOffset - EXTRA_MIDDLE_PROMOTION_LINE_X_OFFSET;
						inst.Top:SetOffsetVal(adjustedXOffset, yOffset);
					end
				end
			end
		end
	end

	if m_SelectedPromotion ~= -1 then
		Controls.ConfirmButton:SetHide(false);
		Controls.BackButton:SetHide(true);		
	else
		Controls.ConfirmButton:SetHide(true);
		Controls.BackButton:SetHide(false);
	end
end

-- ===========================================================================
function SetGovernorStatus(governorDef:table, governor:table)
	local status, statusDetails = GetGovernorStatus(governorDef, governor);
	Controls.GovernorStatus:SetText(status);
	Controls.GovernorStatusDetails:SetText(statusDetails);
end

-- ===========================================================================
function OnAppointGovernor( eGovernor:number )
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = eGovernor;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.APPOINT_GOVERNOR, kParameters);
	end
end

-- ===========================================================================
function OnAssignGovernor( eGovernor:number )
	LuaEvents.GovernorAssignmentChooser_RequestAssignment( eGovernor );
	Close();
	LuaEvents.GovernorPanel_AssignDetails();
end

-- ===========================================================================
function OnPromoteGovernor(eGovernor:number, ePromotion:number)
	
	if m_SelectedPromotion == ePromotion then
		m_SelectedPromotion = -1;
	else
		m_SelectedPromotion = ePromotion;
	end

	Refresh();
end

-- ===========================================================================
function OnConfirm()
	ApplyPromotion();
end

-- ===========================================================================
function ApplyPromotion()
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_GOVERNOR_TYPE] = m_GovernorIndex;
		kParameters[PlayerOperations.PARAM_GOVERNOR_PROMOTION_TYPE] = m_SelectedPromotion;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.PROMOTE_GOVERNOR, kParameters);
	end

	m_SelectedPromotion = -1;
end

-- ===========================================================================
function OnBack()
	Close();
	LuaEvents.GovernorPanel_ClosedDetails();
end

-- ===========================================================================
function OnOpenDetails( governorIndex:number )
	m_GovernorIndex = governorIndex;
	Open();
end

-- ===========================================================================
function Open()
	-- Clear promotion queue
	m_SelectedPromotion = -1;
	
	Refresh();
	ContextPtr:SetHide(false);
end

-- ===========================================================================
function Close()
	ContextPtr:SetHide(true);
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
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "governorIndex", m_GovernorIndex);
end

-- ===========================================================================s
function OnGameDebugReturn( context:string, contextTable:table )
	if context ~= RELOAD_CACHE_ID then
		return;
	end

	if contextTable["governorIndex"] then
		m_GovernorIndex = contextTable["governorIndex"];
	end

	if contextTable["isVisible"] and contextTable["isVisible"] == true then
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
		OnBack();
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
-- ===========================================================================
function Initialize()

	-- Start off hidden
	ContextPtr:SetHide(true);
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );

	-- Lua Events
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );

	-- Context Events
	LuaEvents.GovernorDetailsPanel_OpenDetails.Add( OnOpenDetails );

	-- Game Events
	Events.GovernorAppointed.Add( Refresh );
	Events.GovernorAssigned.Add( Refresh );
	Events.GovernorChanged.Add( Refresh );
	Events.GovernorPointsChanged.Add( Refresh );
	Events.GovernorPromoted.Add( Refresh );
	Events.LocalPlayerTurnBegin.Add( Refresh );	
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );

	-- Control Events
	Controls.ConfirmButton:RegisterCallback( Mouse.eLClick, OnConfirm );
	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );

	m_TopPanelConsideredHeight = Controls.Vignette:GetSizeY() - TOP_PANEL_OFFSET;
end
Initialize();
