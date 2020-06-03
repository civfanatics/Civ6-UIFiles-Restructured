-- Copyright 2017-2018, Firaxis Games

include("InstanceManager");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "DedicationPopup"; -- Must be unique (usually the same as the file name)

local HEROIC_AGE:number = 1;
local GOLDEN_AGE:number = 2;
local DARK_AGE:number = 3;
local NORMAL_AGE:number = 4;

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_CurrentAge:number = -1;
local m_PreviewEraIndex:number = -1;
local m_CurrentEraIndex:number = -1;
local m_SelectedCommemorationTypes:table = {};
local m_CommemorationInstanceManager:table = InstanceManager:new("Commemoration", "SelectCheck", Controls.CommemorationsStack);

-- ===========================================================================
function OnGameEraChanged(prevEraIndex:number, newEraIndex:number)
	
	m_PreviewEraIndex = prevEraIndex;
	m_CurrentEraIndex = newEraIndex;
	local localPlayerID:number = Game.GetLocalPlayer();
	local gameEras:table = Game.GetEras();

	-- Ignore during first turn, or if playing as an observer
	if	localPlayerID == PlayerTypes.NONE or m_CurrentEraIndex == 0 or
		Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then
		return;
	end

	-- Determine the age type
	if (gameEras:HasHeroicGoldenAge(localPlayerID)) then
		m_CurrentAge = HEROIC_AGE;
	elseif (gameEras:HasGoldenAge(localPlayerID)) then
		m_CurrentAge = GOLDEN_AGE;
	elseif (gameEras:HasDarkAge(localPlayerID)) then
		m_CurrentAge = DARK_AGE;
	else
		m_CurrentAge = NORMAL_AGE;
	end

	if m_CurrentEraIndex > 0 then
		local currentEraName:string = GameInfo.Eras[m_CurrentEraIndex].Name;
		local historyManager:table= Game.GetHistoryManager();
		local commemorateChoices:table = gameEras:GetPlayerCommemorateChoices(localPlayerID);

		Controls.Title:SetText(Locale.ToUpper(Locale.Lookup("LOC_ERA_COMMEMORATION_POPUP_DEDICATION_SUBHEADER", Locale.Lookup(currentEraName))));

		m_CommemorationInstanceManager:ResetInstances();

		for _,commemorationType in ipairs(commemorateChoices) do
			CreateCommemoration(GameInfo.CommemorationTypes[commemorationType]);
		end

		local selectionsAllowed:number = gameEras:GetPlayerNumAllowedCommemorations(localPlayerID);

		if m_CommemorationInstanceManager.m_iAllocatedInstances > 0 and selectionsAllowed > 0 then
			ShowPopup();
			m_SelectedCommemorationTypes = {};
			Controls.Confirm:SetDisabled(true);
			Controls.CommemorationsStack:CalculateSize();
			Controls.CommemorationsScroller:CalculateSize();
		else
			OnClose();
		end

		Controls.CommemorationsScroller:SetScrollValue(0);

		-- Update control styles
		if m_CurrentAge == HEROIC_AGE then
			Controls.AgeAchieved:SetText(Locale.ToUpper(Locale.Lookup("LOC_DEDICATION_POPUP_HEROIC_AGE_ACHIEVED")));
			Controls.PopupBackground:SetTexture("Ages_ParchmentHeroic");
			Controls.PopupFrame:SetTexture("Ages_FrameHeroic");
			Controls.HeroicFrameGlow:SetHide(false);
		elseif m_CurrentAge == GOLDEN_AGE then
			Controls.AgeAchieved:SetText(Locale.ToUpper(Locale.Lookup("LOC_DEDICATION_POPUP_GOLDEN_AGE_ACHIEVED")));
			Controls.PopupBackground:SetTexture("Ages_ParchmentGolden");
			Controls.PopupFrame:SetTexture("Ages_FrameGolden");
			Controls.HeroicFrameGlow:SetHide(true);
		elseif m_CurrentAge == DARK_AGE then
			Controls.AgeAchieved:SetText(Locale.ToUpper(Locale.Lookup("LOC_DEDICATION_POPUP_DARK_AGE_ACHIEVED")));
			Controls.PopupBackground:SetTexture("Ages_ParchmentDark");
			Controls.PopupFrame:SetTexture("Ages_FrameDark");
			Controls.HeroicFrameGlow:SetHide(true);
		else
			Controls.AgeAchieved:SetText(Locale.ToUpper(Locale.Lookup("LOC_DEDICATION_POPUP_NORMAL_AGE_ACHIEVED")));
			Controls.PopupBackground:SetTexture("Ages_ParchmentNormal");
			Controls.PopupFrame:SetTexture("Ages_FrameNormal");
			Controls.HeroicFrameGlow:SetHide(true);
		end
	elseif m_CurrentEraIndex < 0 then
		UI.DataError("DedicationPopup has an invalid current era index: "..tostring(m_CurrentEraIndex));
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
	instance.MomentCategory:SetText(Locale.ToUpper(categoryText));
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

	if m_CurrentAge == HEROIC_AGE then
		instance.SelectCheck:SetTexture("Ages_ButtonComHeroic");
	elseif m_CurrentAge == GOLDEN_AGE then
		instance.SelectCheck:SetTexture("Ages_ButtonComGolden");
	elseif m_CurrentAge == DARK_AGE then
		instance.SelectCheck:SetTexture("Ages_ButtonComDark");
	else
		instance.SelectCheck:SetTexture("Ages_ButtonComNormal");
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
function ShowPopup()
	UIManager:QueuePopup(ContextPtr, PopupPriority.MediumHigh);
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
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_PreviewEraIndex", m_PreviewEraIndex);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_CurrentEraIndex", m_CurrentEraIndex);
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

		m_PreviewEraIndex = contextTable["m_PreviewEraIndex"];
		m_CurrentEraIndex = contextTable["m_CurrentEraIndex"];

		if m_CurrentEraIndex >= 0 then
			OnGameEraChanged(m_PreviewEraIndex, m_CurrentEraIndex);
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

	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.Confirm:RegisterCallback(Mouse.eLClick, OnConfirm);

	-- Lua Events
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.EraReviewPopup_MakeDedication.Add(OnGameEraChanged);
end
Initialize();