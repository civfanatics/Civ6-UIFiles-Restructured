-- ===========================================================================
-- World Congress Between Turns
-- ===========================================================================
include("LeaderIcon");
include("InstanceManager");
include("PopupPriorityLoader_", true);

-- ===========================================================================
-- Constants
-- ===========================================================================
local RELOAD_ID:string = "WorldCongressBetweenTurns";

local LOC_PROPOSAL_WAITING:string = Locale.Lookup("LOC_WORLD_CONGRESS_BETWEEN_TURNS_WAITING");
local LOC_PROPOSAL_SUBMITTED:string = Locale.Lookup("LOC_WORLD_CONGRESS_BETWEEN_TURNS_SUBMITTED");
local LOC_PROPOSAL_READY:string = Locale.Lookup("LOC_WORLD_CONGRESS_BETWEEN_TURNS_READY");

local COLOR_WAITING:number = UI.GetColorValue("COLOR_DARK_GREY");
local COLOR_READY:number = UI.GetColorValue("COLOR_GREEN");
local TEXTURE_OFFSET_READY:number = 136;
local TEXTURE_OFFSET_UNREADY:number = 0;
local ANIM_DURATION:number = 0.1;
local POST_ANIM_PAUSE:number = 0.75;

-- ===========================================================================
-- Members
-- ===========================================================================
local m_PlayerIM:table = InstanceManager:new("PlayerInstance", "Top", Controls.PlayersStack);
local m_uiPlayersByID:table = {};
local m_kPlayerStages:table = {};
local m_WorldCongressStage:number = -1;
local m_EventLockID:number = 0;
local m_waitingForAnimation:boolean = false;

-- ===========================================================================
-- Functions
-- ===========================================================================
function OnSlideDone()
	UI.PlaySound("WC_ProposalSubmitted");
end

function OnShow(stageNum:number)
	m_WorldCongressStage = stageNum;

	local localPlayerID:number = Game.GetLocalPlayer();
	if localPlayerID < 0 then return; end -- Account for AutoPlay
	local pDiplomacy:table = Players[localPlayerID]:GetDiplomacy();

	m_PlayerIM:ResetInstances();
	local aPlayers:table = PlayerManager.GetAliveMajors();
	for i, pPlayer in ipairs(aPlayers) do
		local playerID:number = pPlayer:GetID();
		local instance:table = m_PlayerIM:GetInstance();
		local uiLeaderIcon:table = LeaderIcon:AttachInstance(instance.LeaderIcon);
		local pPlayerConfig:table = PlayerConfigurations[playerID];

		if (playerID == localPlayerID or pDiplomacy:HasMet(playerID)) then
			uiLeaderIcon:UpdateIcon("ICON_"..pPlayerConfig:GetLeaderTypeName(), playerID);
		else
			uiLeaderIcon:UpdateIcon("ICON_LEADER_DEFAULT", playerID);
		end

		if m_kPlayerStages[playerID] == nil then
			m_kPlayerStages[playerID] = (playerID == localPlayerID or pPlayer:IsAI()) and math.huge or -1;
		end

		local isReady:boolean = m_kPlayerStages[playerID] > m_WorldCongressStage;
		instance.BG:SetColor(isReady and COLOR_READY or COLOR_WAITING);
		instance.Label:SetText(isReady and LOC_PROPOSAL_SUBMITTED or LOC_PROPOSAL_WAITING);
		m_uiPlayersByID[playerID] = instance;

		instance.AlphaAnim:SetPauseTime(ANIM_DURATION * i);
		instance.SlideAnim:SetPauseTime(ANIM_DURATION * i);
		instance.AlphaAnim:SetToBeginning();
		instance.SlideAnim:SetToBeginning();
		instance.AlphaAnim:Play();
		instance.SlideAnim:Play();
		instance.SlideAnim:RegisterEndCallback(OnSlideDone);
	end

	if not GameConfiguration.IsNetworkMultiplayer() then
		m_waitingForAnimation = true;
		Controls.TimerAnim:RegisterEndCallback(OnTimerAnimEnded);
		Controls.TimerAnim:SetPauseTime((ANIM_DURATION * table.count(aPlayers)) + POST_ANIM_PAUSE);
		Controls.TimerAnim:SetToBeginning();
		Controls.TimerAnim:Play();
	else
		m_waitingForAnimation = false;
	end

	Controls.PlayersStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();
	local offsetX = Controls.PlayersScrollPanel:GetScrollBar():IsVisible() and -372 or -367;
	Controls.PlayersScrollPanel:SetOffsetX(offsetX);

	UIManager:QueuePopup(ContextPtr, PopupPriority.WorldCongressBetweenTurns);
	UpdateCanContinue();
end

-- ===========================================================================
function ReleaseEventLock()
	if m_EventLockID ~= 0 then
		UI.ReleaseEventID(m_EventLockID);
		m_EventLockID= 0;
	end
end

-- ===========================================================================
function OnTimerAnimEnded()
	ReleaseEventLock();
	m_waitingForAnimation = false;
end

-- ===========================================================================
function OnHide()
	if ContextPtr:IsVisible() then
		ReleaseEventLock();
		m_waitingForAnimation = false;
		UIManager:DequeuePopup(ContextPtr);
	end
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if Game.GetLocalPlayer() < 0 or not ContextPtr:IsVisible() then
		return;
	end

	if m_waitingForAnimation == true then
		-- We are still wating for the animation to finish, don't let the event playback continue
		-- Note, we won't do this in multiplayer
		if m_EventLockID == 0 then	-- If we are already waiting, don't try and get it again.
			m_EventLockID = UI.ReferenceCurrentEvent();
		end
	end
end

-- ===========================================================================
function OnRemotePlayerTurnEnd(playerID:number)
	if playerID < 0 or not ContextPtr:IsVisible() then
		return;
	end

	m_kPlayerStages[playerID] = math.huge;
	
	local instance:table = m_uiPlayersByID[playerID];
	if instance then
		instance.BG:SetColor(COLOR_READY);
		instance.Label:SetText(LOC_PROPOSAL_SUBMITTED);
		UpdateCanContinue();
	end
end

-- ===========================================================================
function UpdateCanContinue()
	local canContinue:boolean = true;
	for _, playerStage in ipairs(m_kPlayerStages) do
		if playerStage <= m_WorldCongressStage then canContinue = false; break; end
	end
	Controls.Status:SetText(canContinue and LOC_PROPOSAL_READY or LOC_PROPOSAL_WAITING);
end

-- ===========================================================================
function OnWorldCongressStageChange(playerID:number, stageNum:number)
	-- Account for Autoplay
	if playerID == Game.GetLocalPlayer() then --Problematic check? -sbatista
		m_kPlayerStages = {};
		m_uiPlayersByID = {};
	end
end

-- ===========================================================================
--	Input
-- ===========================================================================
function KeyHandler( key:number )
	if (key == Keys.VK_ESCAPE or key == Keys.VK_ENTER) then
		OnHide();
		return true;
	end
	return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end

-- ===========================================================================
--	Hot Reload
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == RELOAD_ID and contextTable then
		if contextTable["IsVisible"] then
			OnShow(contextTable["WorldCongressStage"]);
		end
	end
end
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_ID, "IsVisible", ContextPtr:IsVisible());
	LuaEvents.GameDebug_AddValue(RELOAD_ID, "WorldCongressStage", m_WorldCongressStage);
end
function OnContextInitialize( isHotload:boolean )
	if isHotload then
		LuaEvents.GameDebug_GetValues(RELOAD_ID);
	end
end

-- ===========================================================================
--	Init
-- ===========================================================================
function Initialize()

	ContextPtr:SetInitHandler(OnContextInitialize);
	ContextPtr:SetInputHandler(OnInputHandler, true);
	ContextPtr:SetShutdown(OnShutdown);
	
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.WorldCongressPopup_ShowWorldCongressBetweenTurns.Add(OnShow);
	LuaEvents.WorldCongressPopup_HideWorldCongressBetweenTurns.Add(OnHide);
	
	Events.PreTurnBegin.Add(OnHide);
	Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd);
	Events.RemotePlayerTurnEnd.Add(OnRemotePlayerTurnEnd);
	Events.WorldCongressStage1.Add(function(i) OnWorldCongressStageChange(i, 1); end);
	Events.WorldCongressStage2.Add(function(i) OnWorldCongressStageChange(i, 2); end);

	Controls.HideButton:RegisterCallback(Mouse.eLClick, OnHide);
end
if GameCapabilities.HasCapability("CAPABILITY_WORLD_CONGRESS") then
	Initialize();
end

--[[DEBUG, DO NOT SUBMIT]]
--OnShow(1);