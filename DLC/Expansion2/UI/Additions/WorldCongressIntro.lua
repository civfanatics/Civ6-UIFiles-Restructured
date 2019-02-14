--[[
-- Created by Tyler Berry on Friday Aug 10 2018
-- Copyright (c) Firaxis Games
--]]
include("SupportFunctions");
include("PopupPriorityLoader_", true);

-- ===========================================================================
-- Constants
-- ===========================================================================
local RELOAD_CACHE_ID:string = "WorldCongressIntro";

local WORLD_CONGRESS_STAGE_1:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_1");
local WORLD_CONGRESS_STAGE_2:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_2");
local WORLD_CONGRESS_RESOLUTION:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_RESOLUTION");

-- ===========================================================================
--	OnClose: Closes the popup
-- ===========================================================================
function OnClose()
	UIManager:DequeuePopup(ContextPtr);
	LuaEvents.WorldCongressIntro_ShowWorldCongress();
end

-- ===========================================================================
--	OnOpen: Opens the popup 
-- ===========================================================================
function OnOpen(stageNum:number)

	UI.PlaySound("WC_Open");
	Controls.Title:LocalizeAndSetText(stageNum == 1 and "LOC_WORLD_CONGRESS_INTRO_TITLE" or "LOC_SPECIAL_CONGRESS_INTRO_TITLE");
	Controls.Body1:LocalizeAndSetText(stageNum == 1 and "LOC_WORLD_CONGRESS_INTRO_BODY_1" or "LOC_SPECIAL_CONGRESS_INTRO_BODY_1");
	Controls.Body2:LocalizeAndSetText(stageNum == 1 and "LOC_WORLD_CONGRESS_INTRO_BODY_2" or "LOC_SPECIAL_CONGRESS_INTRO_BODY_2");

	--TODO: Flash animation stuff
	UIManager:QueuePopup(ContextPtr, PopupPriority.WorldCongressIntro, { AlwaysVisibleInQueue = true });
end

-- ===========================================================================
--	OnGameDebugReturn: Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		--Handle reloads
		if contextTable["IsHidden"] ~= nil and not contextTable["IsHidden"] then
			--Load stuff
			OnOpen();
		end
	end
end

-- ===========================================================================
--	OnInit: Reload support
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
--	OnShutdown: Reload support
-- ===========================================================================
function OnShutdown()
	--Setup reload variables
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "IsHidden", ContextPtr:IsHidden());
end

-- ===========================================================================
-- Consume all input except Continue keys
-- ===========================================================================
function OnInputActionTriggered( actionId:number )
    if ContextPtr:IsHidden() then
       return;
    end

    if actionId == Input.GetActionId("EndTurn") then
		OnClose();
	end
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
    if ContextPtr:IsHidden() then
       return false;
    end

	local uiMsg = pInputStruct:GetMessageType();
	local key = pInputStruct:GetKey();
	if uiMsg == KeyEvents.KeyUp and (key == Keys.VK_ESCAPE or key == Keys.VK_RETURN) then
		OnClose();
	end
	return true;
end

-- ===========================================================================
-- Update Turn Timers
-- ===========================================================================
function OnTurnTimerUpdated(elapsedTime :number, maxTurnTime :number)
	if ContextPtr:IsHidden() then return; end
	if maxTurnTime <= 0 then
		Controls.AcceptButton:SetText(Locale.Lookup("LOC_WORLD_CONGRESS_INTRO_ACCEPT"));
	else
		Controls.AcceptButton:SetText(Locale.Lookup("LOC_WORLD_CONGRESS_INTRO_ACCEPT") .. " (" .. SoftRound(maxTurnTime - elapsedTime) .. Locale.Lookup("LOC_TIME_SECONDS") .. " )");
	end
end

-- ===========================================================================
--	The load screen has closed.  Check to see if we have to restore our state
-- ===========================================================================
function OnLoadScreenClose()
	local turnSegment = Game.GetCurrentTurnSegment();
	if turnSegment == WORLD_CONGRESS_STAGE_1 then
		OnOpen(1);
	elseif turnSegment == WORLD_CONGRESS_STAGE_2 then
		OnOpen(2);
	end
end

-- ===========================================================================
--	Initialize
-- ===========================================================================
function Initialize()
	ContextPtr:SetHide(true); -- PRODUCTION
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler(OnInputHandler, true);

	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

	Events.InputActionTriggered.Add( OnInputActionTriggered );
	Events.TurnTimerUpdated.Add( OnTurnTimerUpdated );
	Events.LoadScreenClose.Add( OnLoadScreenClose );

	Events.WorldCongressStage1.Add(function() OnOpen(1); end);
	Events.WorldCongressStage2.Add(function() OnOpen(2); end);

	Controls.AcceptButton:RegisterCallback(Mouse.eLClick, OnClose);
end
Initialize();