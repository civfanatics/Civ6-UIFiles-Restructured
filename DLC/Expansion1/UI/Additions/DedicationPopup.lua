--[[
-- Created by Samuel Batista on Friday Apr 19 2017
-- Copyright (c) Firaxis Games
--]]

include("InstanceManager");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "DedicationPopup"; -- Must be unique (usually the same as the file name)

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_PreviewEraIndex:number = -1;
local m_CurrentEraIndex:number = -1;
local m_SelectedCommemorationTypes:table = {};
local m_CommemorationInstanceManager:table = InstanceManager:new("Commemoration", "TopControl", Controls.CommemorationsStack);

-- ===========================================================================
function OnGameEraChanged(prevEraIndex:number, newEraIndex:number)
	
	m_PreviewEraIndex = prevEraIndex;
	m_CurrentEraIndex = newEraIndex;
	local localPlayerID:number = Game.GetLocalPlayer();

	-- Ignore during first turn, or if playing as an observer
	if	localPlayerID == PlayerTypes.NONE or m_CurrentEraIndex == 0 or
		Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then
		return;
	end

	if m_CurrentEraIndex > 0 then
		local currentEraName:string = GameInfo.Eras[m_CurrentEraIndex].Name;
		local gameEras:table = Game.GetEras();
		local historyManager:table= Game.GetHistoryManager();
		local commemorateChoices:table = gameEras:GetPlayerCommemorateChoices(localPlayerID);

		Controls.Description:SetText(Locale.Lookup("LOC_ERA_COMMEMORATION_POPUP_DEDICATION_SUBHEADER", Locale.Lookup(currentEraName)));

		m_CommemorationInstanceManager:ResetInstances();

		for _,commemorationType in ipairs(commemorateChoices) do
			CreateCommemoration(GameInfo.CommemorationTypes[commemorationType]);
		end

		local selectionsAllowed:number = gameEras:GetPlayerNumAllowedCommemorations(localPlayerID);

		if m_CommemorationInstanceManager.m_iAllocatedInstances > 0 and selectionsAllowed > 0 then
			OnShow();
			m_SelectedCommemorationTypes = {};
			Controls.Confirm:SetDisabled(true);
			Controls.CommemorationsStack:CalculateSize();
			Controls.CommemorationsScroller:CalculateSize();
		else
			OnClose();
		end

		Controls.CommemorationsScroller:SetScrollValue(0);

		-- Update the age achieved label
		if (gameEras:HasHeroicGoldenAge(localPlayerID)) then
			Controls.AgeAchieved:SetText(Locale.Lookup("LOC_DEDICATION_POPUP_HEROIC_AGE_ACHIEVED"));
		elseif (gameEras:HasGoldenAge(localPlayerID)) then
			Controls.AgeAchieved:SetText(Locale.Lookup("LOC_DEDICATION_POPUP_GOLDEN_AGE_ACHIEVED"))
		elseif (gameEras:HasDarkAge(localPlayerID)) then
			Controls.AgeAchieved:SetText(Locale.Lookup("LOC_DEDICATION_POPUP_DARK_AGE_ACHIEVED"))
		else
			Controls.AgeAchieved:SetText(Locale.Lookup("LOC_DEDICATION_POPUP_NORMAL_AGE_ACHIEVED"))
		end
	elseif m_CurrentEraIndex < 0 then
		UI.DataError("Error in PrideCommemorationPopup: Invalid Previous Era.");
		OnClose();
	end

	UpdateConfirmButton(0);
end

-- ===========================================================================
function CreateCommemoration(commemorationInfo:table)
	local instance:table = m_CommemorationInstanceManager:GetInstance();

	-- Commemoration Icon
	local iconName:string = "ICON_" .. commemorationInfo.CommemorationType;
	instance.CommemorationIcon:SetIcon(iconName);

	local categoryText:string = "";
	if (commemorationInfo ~= nil and commemorationInfo.CategoryDescription ~= nil) then
		categoryText = Locale.Lookup(commemorationInfo.CategoryDescription);
	end
	instance.MomentCategory:SetText(categoryText);
	local bonusText:string = "";
	local localPlayerID:number = Game.GetLocalPlayer();
	if (localPlayerID ~= PlayerTypes.NONE) then
		local gameEras:table = Game.GetEras();
		if (gameEras:HasGoldenAge(localPlayerID)) then
			if (commemorationInfo ~= nil and commemorationInfo.GoldenAgeBonusDescription ~= nil) then
				bonusText = Locale.Lookup(commemorationInfo.GoldenAgeBonusDescription);
				if (gameEras:IsPlayerAlwaysAllowedCommemorationQuest(localPlayerID) and commemorationInfo.NormalAgeBonusDescription ~= nil) then
					bonusText = bonusText .. "[NEWLINE]" .. Locale.Lookup(commemorationInfo.NormalAgeBonusDescription);
				end
			end
		elseif (gameEras:HasDarkAge(localPlayerID)) then
			if (commemorationInfo ~= nil and commemorationInfo.DarkAgeBonusDescription ~= nil) then
				bonusText = Locale.Lookup(commemorationInfo.DarkAgeBonusDescription);
			end
		else
			if (commemorationInfo ~= nil and commemorationInfo.NormalAgeBonusDescription ~= nil) then
				bonusText = Locale.Lookup(commemorationInfo.NormalAgeBonusDescription);
			end
		end
	end
	instance.MomentBonuses:SetText(bonusText);
	instance.SelectCheck:SetSelected(false);
	instance.SelectCheck:RegisterCallback(Mouse.eLClick, function() OnCommemorationSelected(instance, commemorationInfo.Index) end);
end

-- ===========================================================================
function OnCommemorationSelected(selectedInstance:table, commemorationType:number)
	-- How many are we allowed to select?
	local selectionsAllowed:number = Game.GetEras():GetPlayerNumAllowedCommemorations(Game.GetLocalPlayer());
	local selectionsMade:number = 0;
	for _,instance in ipairs(m_CommemorationInstanceManager.m_AllocatedInstances) do
		if (instance.SelectCheck:IsSelected()) then
			selectionsMade = selectionsMade + 1;
		end
	end

	-- Have we already selected this one?
	local alreadySelected:boolean = false;
	for i,selectedCommemorationType in ipairs(m_SelectedCommemorationTypes) do
		if (selectedCommemorationType == commemorationType) then
			alreadySelected = true;
			selectedInstance.SelectCheck:SetSelected(false);
			table.remove(m_SelectedCommemorationTypes, i);
			selectionsMade = selectionsMade - 1;
		end
	end

	if (not alreadySelected) then
		if (selectionsMade >= selectionsAllowed) then
			-- At capacity, so first clear our old selections
			for _,instance in ipairs(m_CommemorationInstanceManager.m_AllocatedInstances) do
				instance.SelectCheck:SetSelected(false);
			end
			m_SelectedCommemorationTypes = {};
			selectionsMade = 0;
		end
		-- Make our new selection
		selectedInstance.SelectCheck:SetSelected(true);	
		table.insert(m_SelectedCommemorationTypes, commemorationType);
		selectionsMade = selectionsMade + 1;
	end

	UpdateConfirmButton(selectionsMade);
end

-- ===========================================================================
function UpdateConfirmButton(currentlySelected:number)
	local selectionsAllowed:number = Game.GetEras():GetPlayerNumAllowedCommemorations(Game.GetLocalPlayer());
	Controls.Confirm:SetDisabled(currentlySelected ~= selectionsAllowed);
end

-- ===========================================================================
function OnConfirm()
    UI.PlaySound("Confirm_Dedication");

    OnClose();

	for i,selectedCommemorationType in ipairs(m_SelectedCommemorationTypes) do
		local kParameters:table = {};
		kParameters[PlayerOperations.PARAM_COMMEMORATION_TYPE] = selectedCommemorationType;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.COMMEMORATE, kParameters);
	end

end

-- ===========================================================================
function OnShow()
	UIManager:QueuePopup(ContextPtr, PopupPriority.High);
end

-- ===========================================================================
function OnClose()
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload then		
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );	
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", not ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "prevEraIndex", m_PreviewEraIndex);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "nextEraIndex", m_CurrentEraIndex);
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["isVisible"] ~= nil then			
			ContextPtr:SetHide(not contextTable["isVisible"]);
		end
		if contextTable["prevEraIndex"]	~= nil and contextTable["nextEraIndex"]	~= nil then
			OnGameEraChanged(contextTable["prevEraIndex"], contextTable["nextEraIndex"]);
		end
	end
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	if ( pInputStruct:GetMessageType() == KeyEvents.KeyUp ) then
		local key:number = pInputStruct:GetKey();
		if ( key == Keys.VK_ESCAPE ) then
			OnClose();
		end
	end
	-- Intercept all input while on this screen (is modal)
	return true;
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetHide(true); -- PRODUCTION
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );

	Controls.ModalBG:SetHide(true);
	Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.Confirm:RegisterCallback(Mouse.eLClick, OnConfirm);

	-- Lua Events
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.DedicationPopup_Show.Add(OnGameEraChanged);

	Controls.ModalScreenTitle:SetText(Locale.ToUpper("LOC_ERA_COMMEMORATION_POPUP_DEDICATION"));
end
Initialize();