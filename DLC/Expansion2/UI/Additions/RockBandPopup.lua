--	Copyright 2018, Firaxis Games
-- ===========================================================================
include("Colors");
include("InstanceManager");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID	 :string = "RockBandPopup"; -- Unique name for hotreload
local MAXIMUM_ROCK_TIERS :number = 6;
local TIER_STRINGS		 :table = {
	"LOC_RESULT_AGING_ROCKERS_TIER",
	"LOC_RESULT_CREATIVE_DIFFERENCES_TIER",
	"LOC_RESULT_OPENING_ACT_TIER",
	"LOC_RESULT_RISING_STARS_TIER",
	"LOC_RESULT_HEADLINERS_TIER",
	"LOC_RESULT_LEGENDS_OF_ROCK_TIER"
};


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_resultsID:number = -1;
local m_totalTourism:number = 0;
local m_unitID:number = 0;
local m_ownerID:number = 0;

local m_StarIM:table = InstanceManager:new("StarInstance", "Root", Controls.StarMeter);


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function Open( ownerID:number, unitID:number, resultID:number, totalTourism:number )	
	local kResultData:table = GameInfo.Unit_RockbandResults_XP2[resultID];
	if kResultData ~= nil then
		local pPlayer:table = Players[ownerID];
		local pUnit:table = pPlayer:GetUnits():FindID(unitID);
		if pUnit ~= nil then
			
			--Tier level is equal to a constant minus resultID because Matt set it up
			--to be sequential in the DB, so it isn't passed as data
			local rockTier:number = kResultData.PerformanceStars;
			m_StarIM:ResetInstances();
			for i=1,MAXIMUM_ROCK_TIERS,1 do
				local uiStar:table = m_StarIM:GetInstance();
				if rockTier >= i then
					uiStar.Icon:SetTexture("RB_StarMeter_On");
				else
					uiStar.Icon:SetTexture("RB_StarMeter_Off");
				end
			end

			Controls.TierTitle:SetText(Locale.Lookup(kResultData.Name));
			Controls.TierLevel:SetText(Locale.Lookup(TIER_STRINGS[rockTier]));
			Controls.TierDescription:SetText(Locale.Lookup(kResultData.Description));

			local pRockBand:table = pUnit:GetRockBand();
			local backColor, _ = UI.GetPlayerColors(ownerID);
			Controls.GeneratedTourismIcon:SetColor(UI.DarkenLightenColor(backColor,35,255));
			Controls.TourismTotal:SetText(totalTourism);
			Controls.AlbumsSold:SetText(kResultData.AlbumSales);

			local bCanPromote:boolean = (not pRockBand:IsMaxPromotions()) and kResultData.ExtraPromotion;
			Controls.PromotionLine:SetShow(bCanPromote);
			Controls.PromotionGroup:SetShow(bCanPromote);

			local bCanLevelUp:boolean = (not pRockBand:IsMaxLevel()) and kResultData.GainsLevel;
			Controls.LevelUpLine:SetShow(bCanLevelUp);
			Controls.LevelUpGroup:SetShow(bCanLevelUp);
			Controls.RockBandLevel:SetText(pRockBand:GetRockBandLevel());

			Controls.DiedLine:SetShow(kResultData.Dies);
			Controls.DiedGroup:SetShow(kResultData.Dies);

			m_totalTourism = totalTourism;
			m_resultsID = resultID;
			m_unitID = unitID;
			m_ownerID = ownerID;
			UIManager:QueuePopup(ContextPtr, PopupPriority.Medium);
		end
	else
		UI.DataError("Invalid ResultID for Rock Band recap! ID: " .. resultID .. " was given.");
	end
end

-- ===========================================================================
function OnConcert( ownerID:number, unitID:number, unitX:number, unitY:number, result:number, totalTourism:number )
	local localPlayer:number = Game.GetLocalPlayer();	
	if (localPlayer < 0 or ownerID ~= localPlayer) then
		return;
	end
	Open(ownerID, unitID, result, totalTourism);
end

-- ===========================================================================
--	Actual close function, asserts if already closed
-- ===========================================================================
function Close()
	if not ContextPtr:IsHidden() then
		UI.PlaySound("UI_Screen_Close");
	end
		
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
--	LUA Event, Callback
--	Close this screen
-- ===========================================================================
function OnClose()
	if not ContextPtr:IsHidden() then
		Close();
	end
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp and pInputStruct:GetKey() == Keys.VK_ESCAPE then
		Close();
		return true;
	end
	return false;
end

-- ===========================================================================
function LateInitialize()
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	LuaEvents.RockBandMoviePopup_OpenRockBandPopup.Add(Open);
	-- No wonder popups in multiplayer games, and in single player we rely
	-- on wonder popups to trigger
	if(GameConfiguration.IsAnyMultiplayer()) then
		Events.PostTourismBomb.Add(OnConcert);
	end
end

-- ===========================================================================
--	Hot Reload Related Events
-- ===========================================================================
function OnInit(isReload:boolean)
	LateInitialize();
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "unitID", m_unitID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "ownerID", m_ownerID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "resultsID", m_resultsID);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "totalTourism", m_totalTourism);
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID and not ContextPtr:IsHidden() then
		Open(contextTable["ownerID"], contextTable["unitID"], contextTable["resultsID"], contextTable["totalTourism"]);
	end
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);	
end
Initialize();

