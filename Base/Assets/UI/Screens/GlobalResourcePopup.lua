--	Copyright 2019, Firaxis Games
-- TODO: Future patch add sorting/filtering

-- ===========================================================================
include("InstanceManager");
include("LeaderIcon");

-- ===========================================================================
--	DEBUG
-- ===========================================================================
local m_debugData:boolean = false;

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID	:string = "GlobalResourcePopup"; -- Unique name for hotreload
local ASSETS			:table = {
	strategic={
		BackgroundTexture = "Controls_LineItem_Strategic",
		HeaderRowTitle = "LOC_REPORTS_STRATEGIC_RESOURCES",	
		ResourceClass  = "RESOURCECLASS_STRATEGIC",
		EmptyText      = "LOC_REPORTS_CIVS_NO_STRATEGIC_RESOURCES";
	},
	luxury={
		BackgroundTexture = "Controls_LineItem_Luxury",
		HeaderRowTitle = "LOC_REPORTS_LUXURY_RESOURCES",	
		ResourceClass  = "RESOURCECLASS_LUXURY",
		EmptyText      = "LOC_REPORTS_CIVS_NO_LUXURY_RESOURCES";
	}
};


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kResourceGroupIM	:table = InstanceManager:new( "ResourceGroupStartLabel","Top",	Controls.ResourceStack);
local m_kResourceLineIM		:table = InstanceManager:new( "ResourceLineItem",		"Top",	Controls.ResourceStack);
local m_kSpaceIM			:table = InstanceManager:new( "SpaceInstance",			"Space",Controls.ResourceStack);
local m_kEmptyMessageIM		:table = InstanceManager:new( "EmptyMessageInstance",	"Top",	Controls.ResourceStack);
local m_kLeaderInstanceIM	:table = InstanceManager:new( "LeaderInstance",			"Top");
local m_kNoLeaderInstanceIM	:table = InstanceManager:new( "NoLeaderMessageInstance","Top");

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function Open()	
	local topPanelSizeY:number = 30;
	x,y = UIManager:GetScreenSizeVal();
	Controls.Main:SetSizeY( y - topPanelSizeY );
	Controls.Main:SetOffsetY( topPanelSizeY * 0.5 );

	local kData:table = PopulateData();
	if kData then
		View( kData );
		UIManager:QueuePopup( ContextPtr, PopupPriority.Medium );
	end
end


-- ===========================================================================
function IsAliveMajorCiv( pPlayer:table)
	for _, pMajor in ipairs(PlayerManager.GetAliveMajors()) do
		if pMajor == pPlayer then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
function ShouldPlayerBeAdded( pPlayer:table )
	if pPlayer == nil			then return false; end
	if pPlayer:IsBarbarian()	then return false; end
	if pPlayer.IsFreeCities and pPlayer:IsFreeCities()	then return false; end		-- Not avail in base game.
	if IsAliveMajorCiv(pPlayer)== false then return false; end
	return true;
end

-- ===========================================================================
--	Resources a player has is not the same as what is available for trade.
-- ===========================================================================
function GetResourcesForTrade( localPlayerID:number, otherPlayerID:number ) 
	local kResources		:table = {};	
	
	if localPlayerID == otherPlayerID then
		-- For the local player, enumerate all the resources they have.
		local pPlayer :table = Players[localPlayerID];
		for row in GameInfo.Resources() do
			local amount:number = pPlayer:GetResources():GetResourceAmount(row.Index);
			if amount > 0 then						
				table.insert( kResources, {
					Type	= row.ResourceType,
					Amount	= amount
				});
			end
		end
	else
		-- For other players, use deal manager to see what the local player can trade for.
		local pForDeal			:table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, localPlayerID, otherPlayerID);
		local possibleResources	:table = DealManager.GetPossibleDealItems(otherPlayerID, otherPlayerID, DealItemTypes.RESOURCES, pForDeal);
		if possibleResources ~= nil then
			for i, entry in ipairs(possibleResources) do
				local resourceDesc = GameInfo.Resources[entry.ForType];
				if resourceDesc ~= nil and entry.MaxAmount > 0 then
					table.insert( kResources, {
						Type	= resourceDesc.ResourceType,
						Amount	= entry.MaxAmount
					});
				end
			end
		end
	end

	return kResources;
end

-- ===========================================================================
function PopulateData()	

	local localPlayerID:number = Game.GetLocalPlayer();
	if localPlayerID == -1 then
		return nil;
	end

	local pDiplomacy:table =  Players[localPlayerID]:GetDiplomacy();
	if pDiplomacy == nil then
		UI.DataError("GlobalResourcePopup is unable to obtain the diplomacy object for player #'"..tostring(localPlayerID).."'");
		return;
	end
	
	-- Build list
	local kResourceReport	:table = {};
	local pAllPlayerIDs		:table = PlayerManager.GetAliveIDs();	
	for _,iPlayerID in ipairs(pAllPlayerIDs) do
		local pPlayer	:table = Players[iPlayerID];
		if ShouldPlayerBeAdded(pPlayer) then			
			local isMet		:boolean = pDiplomacy:HasMet(iPlayerID);
			local isSelf	:boolean = (iPlayerID == localPlayerID);
			local kResources:table = GetResourcesForTrade( localPlayerID, iPlayerID);
			for _,kInfo in ipairs(kResources) do
				local kPlayerEntry :table = {
					playerID	= iPlayerID,
					playerAmount= kInfo.Amount,
					isMet		= isMet,
					isSelf		= isSelf
				};
				if kResourceReport[kInfo.Type] == nil then
					kResourceReport[kInfo.Type]	= {};
				end
				table.insert(kResourceReport[kInfo.Type], kPlayerEntry);
			end
		end
	end

	--Sort by highest amount of resources
	for type,kOwnerList in pairs( kResourceReport ) do
		table.sort(kOwnerList, function(a, b) return a.playerAmount > b.playerAmount; end);				
		kResourceReport[type] = kOwnerList;		
	end

	return kResourceReport;
end

-- ===========================================================================
--	Build a single row of resources
--	RETURNS: true if conditions exist to build a row, false otherwise.
-- ===========================================================================
function BuildRow( kResourceInfo:table, kOwnerList:table, backgroundTexture:string )	
	local isPossessed :boolean = false;	
	for _,kPlayerEntry in pairs(kOwnerList) do
		if kPlayerEntry.isMet or kPlayerEntry.isSelf then
			isPossessed = true;			
			break;
		end
	end	
	if isPossessed == false then	-- No one has the resource?  Ignore it.
		return false;
	end
	
	local uiResourceRow	:table = m_kResourceLineIM:GetInstance();	
	uiResourceRow.ResourceIcon:SetIcon("ICON_" .. kResourceInfo.ResourceType);
	uiResourceRow.Top:SetTexture( backgroundTexture );
	uiResourceRow.ResourceName:SetText(Locale.Lookup(kResourceInfo.Name));

	local USE_UNIQUE_LEADER_ICON_STYLE	:boolean = false;
		
	for _,kPlayerEntry in pairs(kOwnerList) do
		if kPlayerEntry.isMet or kPlayerEntry.isSelf then
				local uiLeaderInstance	:table = m_kLeaderInstanceIM:GetInstance(uiResourceRow.LeaderStack);
			local leaderName		:string = PlayerConfigurations[kPlayerEntry.playerID]:GetLeaderTypeName();
			local iconName			:string = "ICON_" .. leaderName;	
			local kLeaderIconManager, uiLeaderIcon = LeaderIcon:AttachInstance(uiLeaderInstance.Icon);
			kLeaderIconManager:UpdateIcon(iconName, kPlayerEntry.playerID, USE_UNIQUE_LEADER_ICON_STYLE );
			uiLeaderIcon.SelectButton:RegisterCallback(Mouse.eLClick, function() OnLeaderClicked(kPlayerEntry.playerID); end);
			uiLeaderInstance.AmountLabel:SetText(kPlayerEntry.playerAmount);			
		end
	end
		
	uiResourceRow.LeaderStack:CalculateSize();
	uiResourceRow.MainStack:CalculateSize();
	uiResourceRow.DividerLine:SetSizeY( uiResourceRow.MainStack:GetSizeY() - 20 );

	local colorNameInAtlas:string = kResourceInfo.ResourceClassType;	-- Color name is same as class.
	uiResourceRow.DividerLine:SetColorByName( colorNameInAtlas );

	return true;
end

-- ===========================================================================
function BuildHeaderRow( title:string, backgroundTexture:string )
	local uiRow:table = m_kResourceGroupIM:GetInstance();
	local text:string = Locale.Lookup( title );
	uiRow.Name:SetString( text );
	uiRow.Top:SetTexture( backgroundTexture );
end

-- ===========================================================================
function AddSpace( pixels:number )
	local uiSpace:table = m_kSpaceIM:GetInstance();
	uiSpace.Space:SetSizeY( pixels );
end

-- ===========================================================================
function AddEmptyMessage( message:string )
	local uiEmptyMessage:table = m_kEmptyMessageIM:GetInstance();
	uiEmptyMessage.Text:SetText( message );
end

-- ===========================================================================
function BuildSection( section:string, kData:table )
	local backgroundTexture :string = ASSETS[section].BackgroundTexture;
	local headerRowTitle	:string = ASSETS[section].HeaderRowTitle;
	local resourceClass		:string = ASSETS[section].ResourceClass;
	local emptyText			:string = ASSETS[section].EmptyText;
	local isAnyBuilt		:boolean = false;
	BuildHeaderRow(headerRowTitle, backgroundTexture);

	for resourceType,kOwnerList in pairs(kData) do
		if (table.count(kOwnerList) > 0) then
			local kResourceInfo = GameInfo.Resources[resourceType];
			if (kResourceInfo.ResourceClassType == resourceClass) then
				if BuildRow(kResourceInfo, kOwnerList, backgroundTexture) then
					isAnyBuilt = true;
				end
			end
		end
	end	

	if isAnyBuilt==false then
		AddEmptyMessage( Locale.Lookup(emptyText) );
	end
end

-- ===========================================================================
function View( kData:table )

	m_kResourceGroupIM:ResetInstances();
	m_kSpaceIM:ResetInstances();
	m_kEmptyMessageIM:ResetInstances();
	m_kResourceLineIM:ResetInstances();
	m_kLeaderInstanceIM:ResetInstances();	
	m_kNoLeaderInstanceIM:ResetInstances();	

	BuildSection("strategic", kData);
	AddSpace(30);
	BuildSection("luxury", kData);
end

-- ===========================================================================
function OnLeaderClicked(playerID:number)
	-- Send an event to open the leader in the diplomacy view (only if they met)
	local localPlayerID:number = Game.GetLocalPlayer();
	if playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID) then
		LuaEvents.DiplomacyRibbon_OpenDiplomacyActionView( playerID );
		Close();
	end
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
	-- Lua Events
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.GlobalReportsList_OpenResources.Add(Open);
	Controls.CloseButton:RegisterCallback( Mouse.eLClick, Close);
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
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", not ContextPtr:IsHidden());
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context ~= RELOAD_CACHE_ID then return; end
	if contextTable["isVisible"] then
		Open();
	end
end

-- ===========================================================================
function Initialize()
	-- UI Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );
end
Initialize();
