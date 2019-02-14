-- Copyright 2018, Firaxis Games.

include("LuaClass");
include("SupportFunctions");

-- Class Table
CongressButton = LuaClass:Extend()

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
CongressButton.DATA_FIELD_CLASS = "CONGRESS_BUTTON_CLASS";
local WORLD_CONGRESS_STAGE_1	:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_1");
local WORLD_CONGRESS_STAGE_2	:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_2");
local WORLD_CONGRESS_RESOLUTION	:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_RESOLUTION");


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================
function CongressButton:GetInstance(instanceManager:table, kParent:table)
	local instance :table = instanceManager:GetInstance(kParent);
	return CongressButton:AttachInstance(instance);
end


-- ===========================================================================
function CongressButton:AttachInstance( uiInstance:table )
	self = uiInstance[CongressButton.DATA_FIELD_CLASS];
	if not self then
		self = CongressButton:new(uiInstance);
		uiInstance[CongressButton.DATA_FIELD_CLASS] = self;
	end
	self:Reset();
	self:OnUpdateCongressButton();
	return self, uiInstance;
end

-- ===========================================================================
--	CTOR
-- ===========================================================================
function CongressButton:new( uiInstance:table )	
	self = LuaClass.new( CongressButton )
	self.Controls = uiInstance;
	self.Controls.Button:RegisterCallback(Mouse.eLClick, OnClick );		

	Events.WorldCongressStage1.Add(			function() self:OnWorldCongressStart(); end );
	Events.WorldCongressFinished.Add(		function() self:OnWorldCongressFinished(); end );
	Events.WorldCongressRibbonUpdate.Add(	function() self:OnUpdateCongressButton(); end );
	Events.LocalPlayerTurnBegin.Add(		function() self:OnLocalPlayerTurnBegin(); end );
	Events.LocalPlayerTurnEnd.Add(			function() self:OnLocalPlayerTurnEnd(); end );

	return self;
end

-- ===========================================================================
function CongressButton:Reset()
	self.Controls.ProgressMeter:SetPercent(0.0);
end

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
