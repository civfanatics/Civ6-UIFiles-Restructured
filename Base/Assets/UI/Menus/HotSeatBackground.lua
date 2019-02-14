-- ===========================================================================
--	HotSeatBackground
-- ===========================================================================
include("PopupPriorityLoader_", true);

-- ===========================================================================
--	Helper: don't want the background up during endgame screen or viewing
--	content like the history timeline will be blocked.
-- ===========================================================================
function IsEndGamePopupShowing()
	local isEndGame:boolean = false;
	local pGameContext :table = ContextPtr:LookUpControl("/InGame/EndGameMenu");
	if pGameContext then
		isEndGame = UIManager:IsInPopupQueue(pGameContext);	
	end
	return isEndGame;
end

-- ===========================================================================
function OnRequestHide()
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
function OnRequestShow()
	if ContextPtr:IsHidden() and not IsEndGamePopupShowing() then
		UIManager:QueuePopup(ContextPtr, PopupPriority.HotSeatBackground, { AlwaysVisibleInQueue = true });
	end
end

-- ===========================================================================
function Initialize()
	if GameConfiguration.IsAnyMultiplayer() then
		Controls.HotseatBackground:SetTexture("LEADER_HOJO_BACKGROUND");
	end

	LuaEvents.PlayerChange_Close.Add( OnRequestHide );
	LuaEvents.PlayerChange_Show.Add( OnRequestShow );
end
Initialize();