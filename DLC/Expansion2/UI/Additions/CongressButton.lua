-- Copyright 2018-2019, Firaxis Games.

include("SupportFunctions");

-- ===========================================================================
--	Class Table
-- ===========================================================================
CongressButton = {
	worldCongressStartFunc = nil,
	worldCongressFinishedFunc = nil,
	updateCongressButtonFunc = nil,
	localPlayerTurnBeginFunc = nil,
	localPlayerTurnEnd = nil
};


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local WORLD_CONGRESS_STAGE_1	:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_1");
local WORLD_CONGRESS_STAGE_2	:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_2");
local WORLD_CONGRESS_RESOLUTION	:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_RESOLUTION");


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================
function CongressButton:GetInstance(instanceManager:table, uiNewParent:table)
	local instance :table = instanceManager:GetInstance(uiNewParent);
	return CongressButton:AttachInstance(instance);
end


-- ===========================================================================
--	Essentially the "new"
-- ===========================================================================
function CongressButton:AttachInstance( instance:table )
	if instance == nil then
		UI.DataError("NIL instance passed into CongressButton:AttachInstance.  Setting the value to the ContextPtr's 'Controls'.");
		instance = Controls;
	end
	setmetatable(instance, {__index = self });
	self.Controls = instance;
	self.Controls.Button:RegisterCallback( Mouse.eLClick, OnClick );		
	self:Reset();
	self:OnUpdateCongressButton();
	
	-- Ensures call is made by "self" and uses colon so "self" is available in the function.
	self.worldCongressStartFunc		= function() self:OnWorldCongressStart(); end;
	self.worldCongressFinishedFunc	= function() self:OnWorldCongressFinished(); end;
	self.updateCongressButtonFunc	= function() self:OnUpdateCongressButton(); end;
	self.localPlayerTurnBeginFunc	= function() self:OnLocalPlayerTurnBegin(); end;
	self.localPlayerTurnEndFunc		= function() self:OnLocalPlayerTurnEnd(); end;


	-- Attach game events
	Events.WorldCongressStage1.Add(			self.worldCongressStartFunc );
	Events.WorldCongressFinished.Add(		self.worldCongressFinishedFunc );
	Events.WorldCongressRibbonUpdate.Add(	self.updateCongressButtonFunc);
	Events.LocalPlayerTurnBegin.Add(		self.localPlayerTurnBeginFunc);
	Events.LocalPlayerTurnEnd.Add(			self.localPlayerTurnEndFunc );

	return instance;
end


-- ===========================================================================
function CongressButton:Reset()
	self.Controls.ProgressMeter:SetPercent(0.0);
end

-- ===========================================================================
--	Instance Manager Callback
-- ===========================================================================
--[[ TODO: Revisit - currently this will result in an event dispatch issue internally
function CongressButton:OnResetting()
	Events.WorldCongressStage1.Remove(			self.worldCongressStartFunc );
	Events.WorldCongressFinished.Remove(		self.worldCongressFinishedFunc );
	Events.WorldCongressRibbonUpdate.Remove(	self.updateCongressButtonFunc);
	Events.LocalPlayerTurnBegin.Remove(			self.localPlayerTurnBeginFunc);
	Events.LocalPlayerTurnEnd.Remove(			self.localPlayerTurnEndFunc );	
end
]]

-- ===========================================================================
--	Game Event
-- ===========================================================================
function CongressButton:OnWorldCongressStart()
	self:OnUpdateCongressButton();
	return self;
end

-- ===========================================================================
--	Game Event
-- ===========================================================================
function CongressButton:OnWorldCongressFinished()
	self:OnUpdateCongressButton();
	return self;
end

-- ===========================================================================
--	Game Event
-- ===========================================================================
function CongressButton:OnUpdateCongressButton()
	if IsInSession() then
		self.Controls.ProgressMeter:SetPercent( 1.0 );
		self.Controls.Button:SetToolTipString( Locale.Lookup("LOC_WORLD_CONGRESS_IS_CURRENTLY_IN_SESSION") );		
	else

		local pCongressMeetingData	:table = Game.GetWorldCongress():GetMeetingStatus();
		local filled				:number = GetMeterPercentage( pCongressMeetingData );
		local turnsLeft				:number = pCongressMeetingData.TurnsLeft + 1;
		local sessionTooltip		:string = Locale.Lookup("LOC_WORLD_CONGRESS_HUD_BAR_TIME_UNTIL_NEXT_SESSION", turnsLeft);

		self.Controls.ProgressMeter:SetPercent( filled );
		self.Controls.Button:SetToolTipString( sessionTooltip );	
	end
	return self;
end

-- ===========================================================================
--	Game Event
-- ===========================================================================
function CongressButton:OnLocalPlayerTurnBegin()
	local playerID :number = Game.GetLocalPlayer();
	if playerID ~= -1 then
		local pPlayer :table = Players[ playerID ];
		if pPlayer:IsHuman() then
			self:OnUpdateCongressButton();
		end
	end
	return self;
end

-- ===========================================================================
--	Game Event
-- ===========================================================================
function CongressButton:OnLocalPlayerTurnEnd()
	local playerID :number = Game.GetLocalPlayer();
	if playerID ~= -1 then
		local pPlayer :table = Players[ playerID ];
		if pPlayer:IsHuman() then
			self:OnUpdateCongressButton();
		end
	end
	return self;
end

-- ===========================================================================
function GetMeterPercentage( pCongressMeetingData:table )	
	return pCongressMeetingData.Percentage/100;
end


-- ===========================================================================
function IsInSession()	
	local turnSegment :number = Game.GetCurrentTurnSegment();
	if turnSegment == WORLD_CONGRESS_STAGE_1 or turnSegment == WORLD_CONGRESS_STAGE_2 or turnSegment == WORLD_CONGRESS_RESOLUTION then
		return true;
	end
	return false;
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnClick()
	if IsInSession() then
		LuaEvents.CongressButton_ResumeCongress();		
	else
		LuaEvents.CongressButton_ShowCongressResults();		
	end
end
