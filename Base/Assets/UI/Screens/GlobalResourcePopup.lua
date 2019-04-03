--	Copyright 2019, Firaxis Games

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
}


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kResourceGroupIM	:table = InstanceManager:new( "ResourceGroupStartLabel","Top",	Controls.ResourceStack);
local m_kResourceLineIM		:table = InstanceManager:new( "ResourceLineItem",		"Top",	Controls.ResourceStack);
local m_kEmptyMessageIM		:table = InstanceManager:new( "EmptyMessageInstance",	"Top",	Controls.ResourceStack);
local m_kSpaceIM			:table = InstanceManager:new( "SpaceInstance",			"Space" );
local m_kLeaderInstanceIM	:table = InstanceManager:new( "LeaderInstance",			"Top");
local m_kNoLeaderInstanceIM	:table = InstanceManager:new( "NoLeaderMessageInstance","Top");
local m_kData				:table = nil;
local m_isAddingSpaceForEmptyCivs :boolean = false;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

function SortOrderAmount(a,b)
	if (a.amount==b.amount) then return a.playerID < b.playerID; end
	return a.amount > b.amount;
end

function SortOrderPlayer(a,b) 
	return a.playerID < b.playerID; 
end

function SortOrderSlot(a, b) 
	return a.playerID < b.playerID; 
end

function SortScarcity(a,b)
	return a.total < b.total;
end

function SortName(a,b) 
	return Locale.Lookup(a.name) < Locale.Lookup(b.name); 
end



-- ===========================================================================
function Open()	
	local topPanelSizeY:number = 30;
	x,y = UIManager:GetScreenSizeVal();
	Controls.Main:SetSizeY( y - topPanelSizeY );
	Controls.Main:SetOffsetY( topPanelSizeY * 0.5 );

	m_kData = PopulateData();
	if m_kData then
		-- TODO: Consider storing the selects per player (for hotseat) and realizing on re-open rather than using the defaults.
		RealizeSort("LOC_REPORTS_SORT_SCARCITY", SortScarcity );
		RealizeOrder("LOC_REPORTS_ORDER_AMOUNT", SortOrderAmount );
		View( m_kData );
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
--	Determines data to be displayed.
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
			local kResources:table = GetResourcesForTrade( localPlayerID, iPlayerID );
			for _,kInfo in ipairs(kResources) do
				local kPlayerEntry :table = {
					playerID= iPlayerID,
					amount	= kInfo.Amount,
					isMet	= isMet,
					isSelf	= isSelf
				};

				local type:string = kInfo.Type;

				-- First time resource seen?  Add an entry.
				if kResourceReport[type] == nil then
					local kResourceInfo :table = GameInfo.Resources[type];
					kResourceReport[type]	= {
						name		= kResourceInfo.Name,				-- Unlocalized name
						type		= type,								-- resource type
						class		= kResourceInfo.ResourceClassType,	-- classification of resource
						kOwnerList	= {},								-- List of owners
						isPossessed = false,							-- Any met own this resource?
						total		= 0									-- Total known amount
					};
				end

				-- Mark if this resource is considered possessed by any known players (and therefor visible in the report.)
				if kPlayerEntry.isMet or kPlayerEntry.isSelf then
					kResourceReport[type].isPossessed = true;					
				end

				table.insert(kResourceReport[type].kOwnerList, kPlayerEntry);
				kResourceReport[type].total = kResourceReport[type].total + kPlayerEntry.amount;
			end
		end
	end

	-- Convert to table without key (for later sorting).
	local kData :table = {};
	for k,v in pairs(kResourceReport) do
		table.insert(kData, v);
	end
	return kData;
end



-- ===========================================================================
--	Build a single row of resources to be realized in the UI.
-- ===========================================================================
function RealizeRow( kResourceData:table, backgroundTexture:string )	

	local kOwnerList	:table = kResourceData.kOwnerList;	
	local uiResourceRow	:table = m_kResourceLineIM:GetInstance();	
	uiResourceRow.ResourceIcon:SetIcon("ICON_" .. kResourceData.type);
	uiResourceRow.Top:SetTexture( backgroundTexture );
	uiResourceRow.ResourceName:SetText(Locale.Lookup(kResourceData.name));

	local kFullOwnerList:table = {};
	

	if m_isAddingSpaceForEmptyCivs then		
		local safe	:number = 0;	--safety
		local lastID:number = -1;
		for i,kPlayer in ipairs(kOwnerList) do
			-- If there is more than a difference of one between ids add spacing.
			while (kPlayer.playerID - lastID) ~= 1 do
				lastID = lastID + 1;
				table.insert(kFullOwnerList, {			-- Create empty slot
					playerID = lastID, 
					isEmpty = true 
				});			
				safe = safe + 1;
				if (safe > 999) then UI.DataError("Infinite or extremely large amount of space being added between civs for report.!"); break; end
			end
			kPlayer.isEmpty  = (not kPlayer.isMet) and (not kPlayer.isSelf);
			table.insert( kFullOwnerList, kPlayer );	-- Copy real player
			lastID = kPlayer.playerID;		
		end
	else	
		-- Copy real player
		for i,kPlayer in ipairs(kOwnerList) do
			table.insert( kFullOwnerList, kPlayer );	
		end
	end


	-- Constants, including temporary instantion to figure out spacing.
	local USE_UNIQUE_LEADER_ICON_STYLE	:boolean = false;
	local uiLeaderInstance	:table = m_kLeaderInstanceIM:GetInstance(uiResourceRow.LeaderStack);
	local emptyWidth		:number= uiLeaderInstance.Top:GetSizeX();
	m_kLeaderInstanceIM:ReleaseInstance( uiLeaderInstance );

	for _,kPlayerEntry in pairs(kFullOwnerList) do
		if (kPlayerEntry.isEmpty and m_isAddingSpaceForEmptyCivs) then
			local uiSpaceInstance	:table = m_kSpaceIM:GetInstance(uiResourceRow.LeaderStack);
			uiSpaceInstance.Space:SetSizeX( emptyWidth );
		elseif kPlayerEntry.isMet or kPlayerEntry.isSelf then
			local uiLeaderInstance	:table = m_kLeaderInstanceIM:GetInstance(uiResourceRow.LeaderStack);
			local leaderName		:string = PlayerConfigurations[kPlayerEntry.playerID]:GetLeaderTypeName();
			local iconName			:string = "ICON_" .. leaderName;	
			local kLeaderIconManager, uiLeaderIcon = LeaderIcon:AttachInstance(uiLeaderInstance.Icon);
			kLeaderIconManager:UpdateIcon(iconName, kPlayerEntry.playerID, USE_UNIQUE_LEADER_ICON_STYLE );
			uiLeaderIcon.SelectButton:RegisterCallback(Mouse.eLClick, function() OnLeaderClicked(kPlayerEntry.playerID); end);
			uiLeaderInstance.AmountLabel:SetText(kPlayerEntry.amount);			
		end
	end
		
	uiResourceRow.LeaderStack:CalculateSize();
	uiResourceRow.MainStack:CalculateSize();
	uiResourceRow.DividerLine:SetSizeY( uiResourceRow.MainStack:GetSizeY() - 20 );

	local colorNameInAtlas:string = kResourceData.class;	-- Color name is same as class.
	uiResourceRow.DividerLine:SetColorByName( colorNameInAtlas );
end

-- ===========================================================================
--	Builds a section header row to be realized in the UI.
-- ===========================================================================
function RealizeHeaderRow( title:string, backgroundTexture:string )
	local uiRow:table = m_kResourceGroupIM:GetInstance();
	local text:string = Locale.Lookup( title );
	uiRow.Name:SetString( text );
	uiRow.Top:SetTexture( backgroundTexture );
end

-- ===========================================================================
--	Add spacing between rows (used between sections),
-- ===========================================================================
function AddRowSpace( pixels:number )
	local uiSpace:table = m_kSpaceIM:GetInstance( Controls.ResourceStack );
	uiSpace.Space:SetSizeY( pixels );
end

-- ===========================================================================
function AddEmptyMessage( message:string )
	local uiEmptyMessage:table = m_kEmptyMessageIM:GetInstance();
	uiEmptyMessage.Text:SetText( message );
end

-- ===========================================================================
function RealizeSection( section:string, kData:table )
	local backgroundTexture :string = ASSETS[section].BackgroundTexture;
	local headerRowTitle	:string = ASSETS[section].HeaderRowTitle;
	local resourceClass		:string = ASSETS[section].ResourceClass;
	local emptyText			:string = ASSETS[section].EmptyText;
	local isAnyBuilt		:boolean = false;

	RealizeHeaderRow(headerRowTitle, backgroundTexture);

	for _,kResourceData in ipairs(kData) do
		if (table.count(kResourceData.kOwnerList) > 0) and kResourceData.isPossessed then
			if (kResourceData.class == resourceClass) then
				RealizeRow( kResourceData, backgroundTexture );
				isAnyBuilt = true;				
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

	RealizeSection("strategic", kData);
	AddRowSpace(20);
	RealizeSection("luxury", kData);
end


-- ===========================================================================
function RealizeSort(name:string, sortFunc:ifunction)
	Controls.SortPulldown:GetButton():SetText( Locale.Lookup(name) );			
	table.sort(m_kData, sortFunc );	
end

-- ===========================================================================
--	Which order to display each resource row.
-- ===========================================================================
function AddSortOption( name:string, sortFunc:ifunction )
	local uiInstance:table = {};       
	Controls.SortPulldown:BuildEntry( "SortItemInstance", uiInstance );
	uiInstance.DescriptionText:SetText( Locale.Lookup(name) );
	uiInstance.Button:RegisterCallback( Mouse.eLClick, 
		function() 
			RealizeSort( name, sortFunc ); 
			View( m_kData );
		end
	);
end

-- ===========================================================================
function RealizeOrder(name:string, sortFunc:ifunction)
	m_isAddingSpaceForEmptyCivs = (name == "LOC_REPORTS_ORDER_PLAYER_SLOT");	--kluge :'(
	Controls.OrderPulldown:GetButton():SetText( Locale.Lookup(name) );
	for _,kResourceData in pairs(m_kData) do
		local kOwnerList:table = kResourceData.kOwnerList;
		table.sort(kOwnerList, sortFunc );
	end
end

-- ===========================================================================
--	How items within a row are ordered.  (Essentially sorting on the row
-- ===========================================================================
function AddOrderOption( name:string, sortFunc:ifunction )
	local uiInstance:table = {};       
	Controls.OrderPulldown:BuildEntry( "OrderItemInstance", uiInstance );
	uiInstance.DescriptionText:SetText( Locale.Lookup(name) );
	uiInstance.Button:RegisterCallback( Mouse.eLClick, 
		function() 
			RealizeOrder(name, sortFunc);
			View( m_kData );
		end
	);
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
	
	AddSortOption("LOC_REPORTS_SORT_SCARCITY", SortScarcity );
	AddSortOption("LOC_REPORTS_SORT_NAME", SortName );
	Controls.SortPulldown:CalculateInternals();

	AddOrderOption("LOC_REPORTS_ORDER_AMOUNT", SortOrderAmount );
	AddOrderOption("LOC_REPORTS_ORDER_PLAYER", SortOrderPlayer );
	AddOrderOption("LOC_REPORTS_ORDER_PLAYER_SLOT", SortOrderSlot );
	Controls.OrderPulldown:CalculateInternals();

	Controls.SortPulldown:GetButton():SetText( Locale.Lookup("LOC_REPORTS_SORT_SCARCITY") );			
	Controls.OrderPulldown:GetButton():SetText( Locale.Lookup("LOC_REPORTS_ORDER_AMOUNT") );			
end

-- ===========================================================================
--	Context Callback 
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
