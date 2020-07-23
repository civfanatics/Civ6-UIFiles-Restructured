----------------------------------------------------------------  
-- Ingame Chat Panel
----------------------------------------------------------------  
include( "SupportFunctions"  );		--TruncateString
include( "PlayerTargetLogic" );
include( "ChatLogic" );
include( "NetConnectionIconLogic" );
include( "NetworkUtilities" );
include( "InstanceManager");

local CHAT_ENTRY_LOG_FADE_TIME	:number = 1; -- The fade time for chat entries that had already faded out
local CHAT_RESIZE_OFFSET		:number = 58;
local PLAYER_LIST_BG_WIDTH		:number = 236;
local PLAYER_LIST_BG_HEIGHT		:number = 195;
local PLAYER_ENTRY_HEIGHT		:number = 46;
local PLAYER_LIST_BG_PADDING	:number = 20;

--KickVote constants
local KICK_VOTE_BG_WIDTH		: number = 236;
local KICK_VOTE_BG_MAX_HEIGHT	: number = 195;
local KICK_VOTE_ENTRY_HEIGHT	: number = 50;
local KICK_VOTE_BG_PADDING		: number = 20;

local m_isDebugging				:boolean= false;	-- set to true to fill with test messages
local m_isExpanded				:boolean= false;	-- Is the chat panel expanded?
local m_ChatInstances			:table	= {};		-- Chat instances on the compressed panel
local m_expandedChatInstances	:table = {};	-- Chat instances on the expanded panel	
local m_playerTarget = { targetType = ChatTargetTypes.CHATTARGET_ALL, targetID = GetNoPlayerTargetID() };
local m_chatTargetEntries		:table = {};		-- Chat target pulldown entries indexed by playerID for compressed panel.
local m_expandedChatTargetEntries :table = {};		-- Chat target pulldown entries indexed by playerID for compressed panel.

local m_isPlayerListVisible		:boolean = false;	-- Is the player list visible?
local m_playerListEntries		:table = {};

local m_isChatPanelFilled		:boolean = false;
local m_isExpandedChatPanelFilled : boolean = false;

-- See below for g_playerListPullData.

local PlayerConnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerKickedChatStr = Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );

--Panel drag resizing variables
local m_StartingMouseX	: number = 45;
local m_StartingMouseY	: number = 45;
local m_ChatStartSizeY  : number = 45;
local m_numEmergencies  : number = 0;
local m_isFirstDrag		: boolean = true;

local m_kickVoteEntryIM : table = InstanceManager:new("VoteKickPlayerEntry", "RootContainer", Controls.KickVoteStack);
local m_kActiveKickVotes	: table = {};

local KICKVOTE_REASONS : table = {};
KICKVOTE_REASONS[KickVoteReasonType.KICKVOTE_AFK] = "LOC_KICK_VOTE_REASON_AFK";
KICKVOTE_REASONS[KickVoteReasonType.KICKVOTE_GRIEFING] = "LOC_KICK_VOTE_REASON_GRIEFING";
KICKVOTE_REASONS[KickVoteReasonType.KICKVOTE_CHEATING] = "LOC_KICK_VOTE_REASON_CHEATING";


------------------------------------------------- 
-- PlayerList Data Functions
-- These have to be defined before g_playerListPullData to work correctly.
-------------------------------------------------
function IsKickPlayerValidPull(iPlayerID :number)
	if(Network.IsGameHost() and iPlayerID ~= Game.GetLocalPlayer() and not GameConfiguration.GetValue("KICK_VOTE")) then
		return true;
	end
	return false;
end

function IsStartKickVoteValidPull(iPlayerID : number)
	if(GameConfiguration.GetValue("KICK_VOTE") and iPlayerID ~= Game.GetLocalPlayer() 
	and not Network.HasKickVotedStarted(iPlayerID) and not Network.HasVotedToKick(iPlayerID))then
		return true;
	end
	return false;
end

-------------------------------------------------
-------------------------------------------------
function IsFriendRequestValidPull(iPlayerID :number)
	local pFriends = Network.GetFriends(Network.GetTransportType());
	if(pFriends and iPlayerID ~= Game.GetLocalPlayer()) then
		local playerNetworkID = PlayerConfigurations[iPlayerID]:GetNetworkIdentifer();
		if(playerNetworkID ~= nil) then
			local numFriends:number = pFriends:GetFriendCount();
			for i:number = 0, numFriends - 1 do
				local friend:table = pFriends:GetFriendByIndex(i);
				if friend.ID == playerNetworkID then
					return false;
				end
			end
			return true;
		end
	end
	return false;
end

-------------------------------------------------
-------------------------------------------------
local g_playerListPullData = {}

if( Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS ) then
	g_playerListPullData = {
		{ name = "PLAYERACTION_KICKPLAYER",		tooltip = "PLAYERACTION_KICKPLAYER_TOOLTIP",	playerAction = "PLAYERACTION_KICKPLAYER",		isValidFunction=IsKickPlayerValidPull},
		{ name = "LOC_PLAYERACTION_STARTKICKVOTE", tooltip = "LOC_PLAYERACTION_STARTKICKVOTE_TOOLTIP", playerAction = "PLAYERACTION_STARTKICKVOTE",		isValidFunction=IsStartKickVoteValidPull},
	};
else
	g_playerListPullData = {
		{ name = "PLAYERACTION_KICKPLAYER",		tooltip = "PLAYERACTION_KICKPLAYER_TOOLTIP",	playerAction = "PLAYERACTION_KICKPLAYER",		isValidFunction=IsKickPlayerValidPull},
		{ name = "PLAYERACTION_FRIENDREQUEST",	tooltip = "PLAYERACTION_FRIENDREQUEST_TOOLTIP",	playerAction = "PLAYERACTION_FRIENDREQUEST",	isValidFunction=IsFriendRequestValidPull},	
		{ name = "LOC_PLAYERACTION_STARTKICKVOTE", tooltip = "LOC_PLAYERACTION_STARTKICKVOTE_TOOLTIP", playerAction = "PLAYERACTION_STARTKICKVOTE",		isValidFunction=IsStartKickVoteValidPull},
	};
end


-------------------------------------------------
-- OnChat
-------------------------------------------------
function OnChat( fromPlayer, toPlayer, text, eTargetType, playSounds :boolean )
	
	if(m_isExpandedChatPanelFilled and Controls.ExpandedChatEntryStack:GetSizeY() < Controls.ExpandedChatLogPanel:GetSizeY())then
		m_isExpandedChatPanelFilled = false;
	end
	
	local pPlayerConfig :table	= PlayerConfigurations[fromPlayer];
	local playerName	:string = Locale.Lookup(pPlayerConfig:GetPlayerName()); 

	-- Selecting chat text color based on eTargetType	
	local chatColor :string = "[color:ChatMessage_Global]";
	if(eTargetType == ChatTargetTypes.CHATTARGET_TEAM) then
		chatColor = "[color:ChatMessage_Team]";
	elseif(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		chatColor = "[color:ChatMessage_Whisper]";  
	end
	
	local chatString	:string = "[color:ChatPlayerName]" .. playerName;

	-- When whispering, include the whisperee's name as well.
	if(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		local pTargetConfig :table	= PlayerConfigurations[toPlayer];
		if(pTargetConfig ~= nil) then
			local targetName = Locale.Lookup(pTargetConfig:GetPlayerName());
			chatString = chatString .. " [" .. targetName .. "]";
		end
	end

	-- When a map pin is sent, parse and build button
	if(string.find(text, "%[pin:%d+,%d+%]")) then
		-- parse the string
		local pinStr = string.sub(text, string.find(text, "%[pin:%d+,%d+%]"));
		local pinPlayerIDStr = string.sub(pinStr, string.find(pinStr, "%d+"));
		local comma = string.find(pinStr, ",");
		local pinIDStr = string.sub(pinStr, string.find(pinStr, "%d+", comma));
		
		local pinPlayerID = tonumber(pinPlayerIDStr);
		local pinID = tonumber(pinIDStr);

		-- Only build button if valid pin
		-- TODO: player can only send own/team pins. ??PEP
		if(GetMapPinConfig(pinPlayerID, pinID) ~= nil) then
			chatString = chatString .. ": [ENDCOLOR]";
			AddMapPinChatEntry(pinPlayerID, pinID, chatString, Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
			AddMapPinChatEntry(pinPlayerID, pinID, chatString, Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);
			return;
		end
	end

	-- Ensure text parsed properly
	text = ParseChatText(text);

	chatString			= chatString .. ": [ENDCOLOR]" .. chatColor .. text .. "[ENDCOLOR]"; 

	AddChatEntry( chatString, Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
	AddChatEntry( chatString, Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);

	if(playSounds and fromPlayer ~= Network.GetLocalPlayerID()) then
		UI.PlaySound("Play_MP_Chat_Message_Received");
	end

	if fromPlayer ~= Network.GetLocalPlayerID() then
		local isHidden
		LuaEvents.ChatPanel_OnChatReceived(fromPlayer, ContextPtr:GetParent():IsHidden());
	end

	--Ensure the chat panels begin to auto scroll when they are first filled
	if( not m_isChatPanelFilled )then
		if(Controls.ChatEntryStack:GetSizeY() > Controls.ChatLogPanel:GetSizeY())then
			m_isChatPanelFilled = true;
			Controls.ChatLogPanel:SetScrollValue(1);
		end
	end

	if( not m_isExpandedChatPanelFilled )then
		if(Controls.ExpandedChatEntryStack:GetSizeY() > Controls.ExpandedChatLogPanel:GetSizeY())then
			m_isExpandedChatPanelFilled = true;
			Controls.ExpandedChatLogPanel:SetScrollValue(1);
		end
	end
end

function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	OnChat(fromPlayer, toPlayer, text, eTargetType, true);
end


function OnKickVoteStarted(targetPlayerID : number, fromPlayerID : number, reason : number)
	BuildPlayerList();
	local pPlayerConfig = PlayerConfigurations[targetPlayerID];
	local playerName : string = pPlayerConfig:GetPlayerName();
	local chatString : string = Locale.Lookup("LOC_KICK_VOTE_STARTED_CHAT_ENTRY", playerName, KICKVOTE_REASONS[reason])

	AddChatEntry(chatString, Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
	AddChatEntry(chatString, Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);

	local localPlayerID = Game.GetLocalPlayer();
	if(localPlayerID ~= targetPlayerID and localPlayerID ~= fromPlayerID)then
		local kickVoteEntry : table = m_kickVoteEntryIM:GetInstance();
		kickVoteEntry.KickPayerTitle:LocalizeAndSetText("LOC_KICK_VOTE_LABEL", playerName);
		kickVoteEntry.VoteYesButton:LocalizeAndSetToolTip("LOC_KICK_VOTE_YES_BUTTON_TOOLTIP", playerName);
		kickVoteEntry.VoteNoButton:LocalizeAndSetToolTip("LOC_KICK_VOTE_NO_BUTTON_TOOLTIP", playerName);
		kickVoteEntry.VoteYesButton:RegisterCallback(Mouse.eLClick, function() OnVoteKickYesButton(targetPlayerID, kickVoteEntry) end);
		kickVoteEntry.VoteNoButton:RegisterCallback(Mouse.eLClick, function() OnVoteKickNoButton(targetPlayerID, kickVoteEntry) end);
		UI.PlaySound("Play_MP_Chat_KickNotify");
		RealizeKickVotePanel();
		local kickVoteEntryData : table = {
			Instance = kickVoteEntry,
			TargetPlayerID = targetPlayerID 
			};
		table.insert(m_kActiveKickVotes, kickVoteEntryData);
	end
	
end

function OnKickVoteComplete(targetPlayerID :number, kickResult :number)

	for k, v in ipairs(m_kActiveKickVotes)do
		if(v.TargetPlayerID == targetPlayerID)then
			m_kickVoteEntryIM:ReleaseInstance(v.Instance);
			table.remove(m_kActiveKickVotes, k);
		end
	end
	
	local pPlayerConfig = PlayerConfigurations[targetPlayerID];
	local playerName : string = pPlayerConfig:GetPlayerName();
	local locKey :string = "LOC_KICK_VOTE_FAILED_CHAT_ENTRY";
	if(kickResult == KickVoteResultType.KICKVOTERESULT_VOTE_PASSED) then
		locKey = "LOC_KICK_VOTE_SUCCEEDED_CHAT_ENTRY";
	elseif(kickResult == KickVoteResultType.KICKVOTERESULT_TIME_ELAPSED) then
		locKey = "LOC_KICK_VOTE_TIME_ELAPSED_CHAT_ENTRY";
	elseif(kickResult == KickVoteResultType.KICKVOTERESULT_VOTED_NO_KICK) then
		locKey = "LOC_KICK_VOTE_FAILED_CHAT_ENTRY";
	elseif(kickResult == KickVoteResultType.KICKVOTERESULT_NOT_ENOUGH_PLAYERS) then
		locKey = "LOC_KICK_VOTE_NOT_ENOUGH_PLAYERS_CHAT_ENTRY";
	end

	local chatString : string = Locale.Lookup(locKey, playerName);
	AddChatEntry(chatString, Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
	AddChatEntry(chatString, Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);
	RealizeKickVotePanel();
	BuildPlayerList();
end

function OnVoteKickYesButton(targetPlayerID : number, kickVoteEntry : table)
	m_kickVoteEntryIM:ReleaseInstance(kickVoteEntry);
	for k, v in ipairs(m_kActiveKickVotes)do
		if(v.TargetPlayerID == targetPlayerID)then
			table.remove(m_kActiveKickVotes, k);
		end
	end
	Network.KickVote(targetPlayerID, true);
	RealizeKickVotePanel();
end

function OnVoteKickNoButton(targetPlayerID : number, kickVoteEntry : table)
	m_kickVoteEntryIM:ReleaseInstance(kickVoteEntry);
	for k, v in ipairs(m_kActiveKickVotes)do
		if(v.TargetPlayerID == targetPlayerID)then
			table.remove(m_kActiveKickVotes, k);
		end
	end
	Network.KickVote(targetPlayerID, false);
	RealizeKickVotePanel();
end

function RealizeKickVotePanel()
	local children : table = Controls.KickVoteStack:GetChildren();
	local numChildren : number = 0;
	for k, v in ipairs(children)do
		if(not v:IsHidden())then
			numChildren = numChildren + 1;
		end
	end
	
	if(numChildren > 0)then
		Controls.KickVotePanel:SetHide(false);
		local sizeY : number = numChildren * KICK_VOTE_ENTRY_HEIGHT + KICK_VOTE_BG_PADDING;
		if(sizeY > KICK_VOTE_BG_MAX_HEIGHT) then sizeY = KICK_VOTE_BG_MAX_HEIGHT end;
		Controls.KickVoteBackground:SetSizeY(sizeY);
	else
		Controls.KickVotePanel:SetHide(true);
	end
end

--------------------------------------------------- 
-- SendChat
-------------------------------------------------
function SendChat( text )
    if( string.len( text ) > 0 ) then
		-- Parse text for possible chat commands
		local parsedText :string;
		local chatTargetChanged :boolean = false;
		local printHelp :boolean = false;
		parsedText, chatTargetChanged, printHelp = ParseInputChatString(text, m_playerTarget);
		if(chatTargetChanged) then
			ValidatePlayerTarget(m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ChatEntry, m_playerTarget);
			UpdatePlayerTargetIcon(Controls.ChatIcon, m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ExpandedChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ExpandedChatEntry, m_playerTarget);
			UpdatePlayerTargetIcon(Controls.ExpandedChatIcon, m_playerTarget);
			PlayerTargetChanged(m_playerTarget);
		end

		if(printHelp) then
			ChatPrintHelp(Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
			ChatPrintHelp(Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);
		end

		if(parsedText ~= "") then
			-- m_playerTarget uses PlayerTargetLogic values and needs to be converted 
			local chatTarget :table ={};
			PlayerTargetToChatTarget(m_playerTarget, chatTarget);
			Network.SendChat( parsedText, chatTarget.targetType, chatTarget.targetID );
		end
		UI.PlaySound("Play_MP_Chat_Message_Sent");
    end
    Controls.ChatEntry:ClearString();
	Controls.ExpandedChatEntry:ClearString();
end


-------------------------------------------------
-- ParseChatText - ensures icon tags parsed properly
-------------------------------------------------
function ParseChatText(text)
	startIdx, endIdx = string.find(string.upper(text), "%[ICON_");
	if(startIdx == nil) then
		return text;
	else
		for i = endIdx + 1, string.len(text) do
			character = string.sub(text, i, i);
			if(character=="]") then
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text,i + 1));
			elseif(character==" ") then
				text = string.gsub(text, " ", "]", 1);
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text, i + 1));
			elseif (character=="[") then
				return string.sub(text, 1, i - 1) .. "]" .. ParseChatText(string.sub(text, i));
			end
		end
		return text.."]";
	end
	return text;
end


-------------------------------------------------
-------------------------------------------------
function OnOpenExpandedPanel()		
    UI.PlaySound("Tech_Tray_Slide_Open");
	m_isExpanded = true;
	Controls.ChatPanel:SetHide(true);
	Controls.ChatPanelBG:SetHide(true);
	Controls.ExpandedChatPanel:SetHide(false);
	Controls.ExpandedChatPanelBG:SetHide(false);
	Controls.PlayerListPanel:SetHide(not m_isPlayerListVisible);
	
	LuaEvents.ChatPanel_OpenExpandedPanels();
end

-------------------------------------------------
-------------------------------------------------
function OnCloseExpandedPanel()
    UI.PlaySound("Tech_Tray_Slide_Closed");
	m_isExpanded = false;
	Controls.ChatPanel:SetHide(false);
	Controls.ChatPanelBG:SetHide(false);
	Controls.ExpandedChatPanel:SetHide(true);
	Controls.ExpandedChatPanelBG:SetHide(true);
	Controls.PlayerListPanel:SetHide(true);

	LuaEvents.ChatPanel_CloseExpandedPanels();
end

-------------------------------------------------
-------------------------------------------------
function OnDragResizer()
	if m_numEmergencies < 1 then --Disabling drag resize when emergencies are present
		if m_isFirstDrag then
			OnResetChatButton(); --Ensures the mouse offset is set properly. Needed on the initial drag and when research/civic gets toggled on/off.
			m_isFirstDrag = false;
		end

		local mouseX	: number, mouseY : number = UIManager:GetMousePos();
		--How far has the mouse traveled while dragging?
		local yDiff		: number = mouseY - m_StartingMouseY;
		Controls.ResetChatButton:SetHide(false);
		LuaEvents.WorldTracker_OnScreenResize();
		yDiff = math.clamp(yDiff, 0, Controls.ExpandedChatPanel:GetSizeY()-(m_ChatStartSizeY));
		Controls.ChatPanel:SetSizeY(m_ChatStartSizeY + yDiff);
		Controls.ChatPanelBG:SetSizeY(m_ChatStartSizeY + yDiff);
		Controls.ChatEntryStack:SetSizeY(m_ChatStartSizeY + yDiff);
		Controls.ChatLogPanel:SetSizeY(Controls.ChatEntryStack:GetSizeY() - CHAT_RESIZE_OFFSET);
		if (Controls.ChatPanel:GetSizeY() <= m_ChatStartSizeY) then
			OnResetChatButton();
		end
		Controls.ChatEntryStack:CalculateSize();
		LuaEvents.Tutorial_DisableMapDrag(true); --Disable map drag when resizing. Re-enabled in InputHandler();

		if(Controls.ChatEntryStack:GetSizeY() > Controls.ChatLogPanel:GetSizeY())then
			if(not m_isChatPanelFilled)then
				m_isChatPanelFilled = true;
				Controls.ChatLogPanel:SetScrollValue(1);
			end
		else
			m_isChatPanelFilled = false;
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function OnSetNumberOfEmergencies( numEmergencies:number )
	m_numEmergencies = numEmergencies;
	--Disabling drag resize when emergencies are present
	if m_numEmergencies > 0 then
		Controls.DragButton:SetHide(true);
	else
		Controls.DragButton:SetHide(false);
	end
end

-------------------------------------------------
-------------------------------------------------
function OnChatPanelRefresh()
	if m_numEmergencies < 1 then
		LuaEvents.WorldTracker_OnScreenResize();
		if ((Controls.ExpandedChatPanel:GetSizeY() - m_ChatStartSizeY) < Controls.ChatPanel:GetSizeY()) then
			Controls.ChatPanel:SetSizeY(Controls.ExpandedChatPanel:GetSizeY() );
			Controls.ChatPanelBG:SetSizeY(Controls.ExpandedChatPanel:GetSizeY() );
			Controls.ChatEntryStack:SetSizeY(Controls.ChatPanel:GetSizeY());
			Controls.ChatLogPanel:SetSizeY(Controls.ChatEntryStack:GetSizeY() - CHAT_RESIZE_OFFSET);
			Controls.ChatEntryStack:CalculateSize();
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function OnResetDraggedChatPanel()
	Controls.ResetChatButton:SetHide(true);
	Controls.ChatPanel:SetSizeY(m_ChatStartSizeY);
	Controls.ChatPanelBG:SetSizeY(m_ChatStartSizeY);
	Controls.ChatEntryStack:SetSizeY(m_ChatStartSizeY);
	Controls.ChatLogPanel:SetSizeY(Controls.ChatEntryStack:GetSizeY() - CHAT_RESIZE_OFFSET);
	Controls.ChatEntryStack:CalculateSize();
	m_isFirstDrag = true;  --Ensures the mouse offset is set properly. Needed on the initial drag and when research/civic gets toggled on/off.
end

-------------------------------------------------
-------------------------------------------------
function OnResetChatButton()
	Controls.ResetChatButton:SetHide(true);
	Controls.ChatPanel:SetSizeY(m_ChatStartSizeY);
	Controls.ChatPanelBG:SetSizeY(m_ChatStartSizeY);
	Controls.ChatEntryStack:SetSizeY(m_ChatStartSizeY);
	Controls.ChatLogPanel:SetSizeY(Controls.ChatEntryStack:GetSizeY() - CHAT_RESIZE_OFFSET);
	Controls.ChatEntryStack:CalculateSize();
	m_StartingMouseX, m_StartingMouseY = Controls.DragButton:GetScreenOffset();
	m_StartingMouseY = m_StartingMouseY + 24;
end

-------------------------------------------------
-------------------------------------------------
function SetExpandedPanelSize( chatSize:number )
	Controls.ExpandedChatPanel:SetSizeY(chatSize - 1);
	Controls.ExpandedChatPanelBG:SetSizeY(chatSize);
end

------------------------------------------------- 
-- Map Pin Chat Buttons
-------------------------------------------------
function AddMapPinChatEntry(pinPlayerID :number, pinID :number, playerName :string, chatEntryStack :table, chatInstances :table, chatLogPanel :table)
	local BUTTON_TEXT_PADDING:number = 12;
	local CHAT_ENTRY_LIMIT:number = 1000;
	local instance = {};
	ContextPtr:BuildInstanceForControl("MapPinChatEntry", instance, chatEntryStack);

	-- limit chat log
	local newChatEntry = { ChatControl = instance; };
	table.insert( chatInstances, newChatEntry );
	local numChatInstances:number = table.count(chatInstances);
	if( numChatInstances > CHAT_ENTRY_LIMIT) then
		chatEntryStack:ReleaseChild( chatInstances[ 1 ].ChatControl.ChatRoot );
		table.remove( chatInstances, 1 );
	end

	instance.PlayerString:SetText(playerName);
	local mapPinCfg = GetMapPinConfig(pinPlayerID, pinID);
	if(mapPinCfg:GetName() ~= nil) then
		instance.MapPinButton:SetText(mapPinCfg:GetName());
	else
		instance.MapPinButton:SetText(Locale.Lookup("LOC_MAP_PIN_DEFAULT_NAME", mapPinCfg:GetID()));
	end
	instance.MapPinButton:SetOffsetVal(instance.PlayerString:GetSizeX(), 0);
	instance.MapPinButton:SetSizeX(instance.MapPinButton:GetTextControl():GetSizeX()+BUTTON_TEXT_PADDING);

	local hexX :number = mapPinCfg:GetHexX();
	local hexY :number = mapPinCfg:GetHexY();
	instance.MapPinButton:RegisterCallback(Mouse.eLClick,
		function()
			UI.LookAtPlot(hexX, hexY);		
		end
	);

	chatEntryStack:CalculateSize();
	chatEntryStack:ReprocessAnchoring();
	chatLogPanel:CalculateInternalSize();
	chatLogPanel:ReprocessAnchoring();
end

-------------------------------------------------
-------------------------------------------------
function PlayerTargetChanged(newPlayerTarget)
	LuaEvents.ChatPanel_PlayerTargetChanged(newPlayerTarget);
end

-------------------------------------------------
-------------------------------------------------
function OnSendPinToChat(playerID, pinID)
	local mapPinStr :string = "[pin:" .. playerID .. "," .. pinID .. "]";
	SendChat(mapPinStr);
end

-------------------------------------------------
-------------------------------------------------
function OnMapPinPopup_RequestChatPlayerTarget()
	-- MapPinPopup requested our chat player target data.  Send it now.
	PlayerTargetChanged(m_playerTarget);
end

------------------------------------------------- 
------------------------------------------------- 
function GetMapPinConfig(iPlayerID :number, mapPinID :number)
	local playerCfg :table = PlayerConfigurations[iPlayerID];
	if(playerCfg ~= nil) then
		local playerMapPins :table = playerCfg:GetMapPins();
		if(playerMapPins ~= nil) then
			return playerMapPins[mapPinID];
		end
	end
	return nil;
end

------------------------------------------------- 
------------------------------------------------- 
function OnClickToCopy(instance)
	local sText:string = instance.JoinCodeText:GetText();
	UIManager:SetClipboardString(sText);
end

------------------------------------------------- 
-- PlayerList Scripting
-------------------------------------------------
function TogglePlayerListPanel()
	m_isPlayerListVisible = not m_isPlayerListVisible;
	Controls.ShowPlayerListCheck:SetCheck(m_isPlayerListVisible);
	Controls.PBCShowPlayerListCheck:SetCheck(m_isPlayerListVisible);
	Controls.PlayerListPanel:SetHide(not m_isPlayerListVisible);
	if(m_isPlayerListVisible) then
		UI.PlaySound("Tech_Tray_Slide_Open");
	else
		UI.PlaySound("Tech_Tray_Slide_Closed");
	end
end

-------------------------------------------------
-------------------------------------------------
function UpdatePlayerEntry(iPlayerID :number)
	local playerEntry :table = m_playerListEntries[iPlayerID];
	local pPlayerConfig :table = PlayerConfigurations[iPlayerID];
	local entryChanged :boolean = false;
	if(pPlayerConfig ~= nil and (pPlayerConfig:IsAlive() or(GameConfiguration.IsNetworkMultiplayer() and Network.IsPlayerConnected(iPlayerID) and pPlayerConfig:GetSlotStatus() == 4))) then

		-- Create playerEntry if it does not exist.
		if(playerEntry == nil) then
			playerEntry = {};
			ContextPtr:BuildInstanceForControl( "PlayerListEntry", playerEntry, Controls.PlayerListStack);
			m_playerListEntries[iPlayerID] = playerEntry;
			entryChanged = true;
		end

		playerEntry.PlayerName:SetText(pPlayerConfig:GetSlotName()); 
		
		UpdateNetConnectionIcon(iPlayerID, playerEntry.ConnectionIcon);
		UpdateNetConnectionLabel(iPlayerID, playerEntry.ConnectionLabel);
		
		local numEntries:number = PopulatePlayerPull(iPlayerID, playerEntry.PlayerListPull, g_playerListPullData);
		playerEntry.PlayerListPull:SetDisabled(numEntries == 0 or iPlayerID == Game.GetLocalPlayer());

		if iPlayerID == Network.GetGameHostPlayerID() then
			local connectionText:string = playerEntry.ConnectionLabel:GetText();
			connectionText = "[ICON_Host] " .. connectionText;
			playerEntry.ConnectionLabel:SetText(connectionText);
		end
	else
		-- playerEntry should not exist for this player.  Delete it if it exists.
		if(playerEntry ~= nil) then
			Controls.PlayerListStack:DestroyChild(playerEntry);
			m_playerListEntries[iPlayerID] = nil;
			playerEntry = nil;
			entryChanged = true;
		end
	end

	if(entryChanged == true) then
		Controls.PlayerListStack:CalculateSize();
		Controls.PlayerListStack:ReprocessAnchoring();
	end
end

-------------------------------------------------
-------------------------------------------------
function OnPlayerListPull(iPlayerID :number, iPlayerListDataID :number)
	local playerListData = g_playerListPullData[iPlayerListDataID];
	if(playerListData ~= nil) then
		if(playerListData.playerAction == "PLAYERACTION_STARTKICKVOTE")then
			UIManager:PushModal(Controls.ConfirmKick, true);
			Controls.ConfirmKick:SetSizeVal(UIManager:GetScreenSizeVal());
			local pPlayerConfig = PlayerConfigurations[iPlayerID];
			if(pPlayerConfig ~= nil) then
				local playerName = pPlayerConfig:GetPlayerName();
				LuaEvents.StartKickVote(iPlayerID, playerName);
			end
		elseif(playerListData.playerAction == "PLAYERACTION_KICKPLAYER") then
			UIManager:PushModal(Controls.ConfirmKick, true);
			Controls.ConfirmKick:SetSizeVal(UIManager:GetScreenSizeVal());
			local pPlayerConfig = PlayerConfigurations[iPlayerID];
			if(pPlayerConfig ~= nil) then
				local playerName = pPlayerConfig:GetPlayerName();
				LuaEvents.SetKickPlayer(iPlayerID, playerName);
			end
		elseif(playerListData.playerAction == "PLAYERACTION_FRIENDREQUEST") then
			local pFriends = Network.GetFriends(Network.GetTransportType());
			if(pFriends ~= nil) then
				pFriends:ActivateGameOverlayToFriendRequest(iPlayerID);
			end
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function PopulatePlayerPull(iPlayerID :number, pullDown :table, playerListPullData :table)
	pullDown:ClearEntries();
	local numEntries:number = 0;

	for i, pair in ipairs(playerListPullData) do
		if(pair.isValidFunction == nil or pair.isValidFunction(iPlayerID)) then
			local controlTable:table = {};
			pullDown:BuildEntry( "InstanceOne", controlTable );
				
			controlTable.Button:LocalizeAndSetText( pair.name );
			controlTable.Button:LocalizeAndSetToolTip( pair.tooltip );
			controlTable.Button:SetVoids( iPlayerID, i);	
			numEntries = numEntries + 1;
		end
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( OnPlayerListPull );
	return numEntries;
end

-- ===========================================================================
--	Can join codes be used in the current game?
-- ===========================================================================
function IsJoinCodeAllowed()
	local crossPlayMode		:boolean = (Network.GetTransportType() == TransportType.TRANSPORT_EOS);
	local eosAllowed		:boolean = (Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS) and GameConfiguration.IsInternetMultiplayer();
	return crossPlayMode or eosAllowed;
end

-- ===========================================================================
function GetInviteTT()
	if( Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS ) then
		return Locale.Lookup("LOC_EPIC_INVITE_BUTTON_TT");
	end

	return Locale.Lookup("LOC_INVITE_BUTTON_TT");
end

-------------------------------------------------
-------------------------------------------------
function BuildPlayerList()
	m_playerListEntries = {};
	Controls.PlayerListStack:DestroyAllChildren();

	-- Call GetplayerEntry on each human player to initially create the entries.
	local numPlayers:number = 0;
	local kInUsePlayerIDs : table = GameConfiguration.GetInUsePlayerIDs();
	for i, iPlayer in ipairs(kInUsePlayerIDs) do	
		local pPlayerConfig = PlayerConfigurations[iPlayer];
		if(pPlayerConfig ~= nil and pPlayerConfig:IsHuman() and not Network.IsPlayerKicked(iPlayer)) then
			UpdatePlayerEntry(iPlayer);
			numPlayers = numPlayers + 1;
		elseif(pPlayerConfig ~= nil and pPlayerConfig:GetSlotStatus() == 4 and GameConfiguration.IsNetworkMultiplayer() and Network.IsPlayerConnected(iPlayer))then
			UpdatePlayerEntry(iPlayer);
			numPlayers = numPlayers + 1;
		end
	end

	local inviteButtonContainer:table = nil;
	if CanInviteFriends(true) then
		inviteButtonContainer = {};
		ContextPtr:BuildInstanceForControl("InvitePlayerListEntry", inviteButtonContainer, Controls.PlayerListStack);
		inviteButtonContainer.InviteButton:RegisterCallback(Mouse.eLClick, OnInviteButton);
		inviteButtonContainer.InviteButton:SetToolTipString(GetInviteTT());
	end

	local joinCodeContainer:table = nil;
	local joinCodeAllowed = IsJoinCodeAllowed();
	if joinCodeAllowed == true then
		joinCodeContainer = {};
		ContextPtr:BuildInstanceForControl("JoinCodeEntry", joinCodeContainer, Controls.PlayerListStack);
		
		local joinCode :string = Network.GetJoinCode();
		joinCodeContainer.JoinCodeText:RegisterCallback(Mouse.eLClick, function() OnClickToCopy(joinCodeContainer) end);
		if joinCode ~= nil and joinCode ~= "" then
			joinCodeContainer.JoinCodeText:SetText(joinCode);
		else
			joinCodeContainer.JoinCodeText:SetText("---");			-- Better than showing nothing?
		end
	end

	Controls.PlayerListStack:CalculateSize();
	Controls.PlayerListScroll:CalculateInternalSize();

	if Controls.PlayerListScroll:GetScrollBar():IsHidden() then

		local additionalY:number = 0;

		if inviteButtonContainer ~= nil then
			additionalY = additionalY + inviteButtonContainer.InviteButton:GetSizeY();
		end

		if joinCodeContainer ~= nil then
			additionalY = additionalY + joinCodeContainer.JoinCodeLabel:GetSizeY();
		end

		Controls.PlayerListBackground:SetSizeVal(PLAYER_LIST_BG_WIDTH, numPlayers * PLAYER_ENTRY_HEIGHT + PLAYER_LIST_BG_PADDING + additionalY);
	else
		Controls.PlayerListBackground:SetSizeVal(PLAYER_LIST_BG_WIDTH + 10, PLAYER_LIST_BG_HEIGHT);
	end
end

-------------------------------------------------
-- OnInviteButton
-------------------------------------------------
function OnInviteButton()
	local pFriends = Network.GetFriends(Network.GetTransportType());
	if pFriends ~= nil then
		pFriends:ActivateInviteOverlay();
	end
end

------------------------------------------------- 
-- External Event Handlers
-------------------------------------------------
function OnMultplayerPlayerConnected( playerID )
	if(GameConfiguration.IsNetworkMultiplayer()) then
		OnChat( playerID, -1, PlayerConnectedChatStr, false );
		UI.PlaySound("Play_MP_Player_Connect");
		BuildPlayerList();
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerPrePlayerDisconnected( playerID )
	local playerCfg = PlayerConfigurations[playerID];
	if( GameConfiguration.IsNetworkMultiplayer() and playerCfg:IsHuman()) then
		if(Network.IsPlayerKicked(playerID)) then
			OnChat( playerID, -1, PlayerKickedChatStr, false );
		else
	   		OnChat( playerID, -1, PlayerDisconnectedChatStr, false );
		end
		UI.PlaySound("Play_MP_Player_Disconnect");
		BuildPlayerList();
	end
end

-------------------------------------------------
-------------------------------------------------
function OnChatPanelPlayerInfoChanged(playerID :number)
	PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ChatPull, Controls.ChatEntry, Controls.ChatIcon, m_chatTargetEntries, m_playerTarget, false);
	PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ExpandedChatPull, Controls.ExpandedChatEntry, Controls.ExpandedChatIcon, m_expandedChatTargetEntries, m_playerTarget, false);
	BuildPlayerList(); -- Player connection status might have changed.
end

-------------------------------------------------
-------------------------------------------------
function OnChatPanelGameConfigChanged()
	-- Kick Voting option might have affected the available player options.  Rebuild the player list.
	BuildPlayerList();
end

-------------------------------------------------
-------------------------------------------------
function OnMultiplayerHostMigrated()
	-- Rebuild the player list so the game host icon is correct.
	-- The MultiplayerHostMigrated does not indicate the old/new host pair so it is not possible to do a targeted update.
	BuildPlayerList();
end

-------------------------------------------------
-------------------------------------------------
function OnMultiplayerMatchHostMigrated(newHostPlayerID: number, oldHostPlayerID: number)
	if(newHostPlayerID ~= FireWireTypes.FIREWIRE_INVALID_ID) then
		UpdatePlayerEntry(newHostPlayerID);
	end

	if(oldHostPlayerID ~= FireWireTypes.FIREWIRE_INVALID_ID) then
		UpdatePlayerEntry(oldHostPlayerID);
	end
end

-------------------------------------------------
-------------------------------------------------
function OnMultiplayerPingTimesChanged()
	for playerID, playerEntry in pairs( m_playerListEntries ) do
		UpdateNetConnectionIcon(playerID, playerEntry.ConnectionIcon);
	end
end

-------------------------------------------------
-------------------------------------------------
function OnEventUpdateChatPlayer(playerID :number)
	if(ContextPtr:IsHidden() == false) then
		UpdatePlayerEntry(playerID);
	end
end

-------------------------------------------------
-- ShowHideHandler
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
	if(not bIsHide) then 
		PopulateTargetPull(Controls.ChatPull, Controls.ChatEntry, Controls.ChatIcon, m_chatTargetEntries, m_playerTarget, false, OnCollapsedChatPulldownChanged);
		PopulateTargetPull(Controls.ExpandedChatPull, Controls.ExpandedChatEntry, Controls.ExpandedChatIcon, m_expandedChatTargetEntries, m_playerTarget, false, OnExpandedChatPulldownChanged);
		LuaEvents.ChatPanel_OnShown();
		PlayerTargetChanged(m_playerTarget); -- Communicate starting player target so map pin screen can filter its Send To Chat button.
	end	
end

function OnCollapsedChatPulldownChanged(newTargetType :number, newTargetID :number, tooltipText:string)
	local textControl:table = Controls.ChatPull:GetButton():GetTextControl();
	if tooltipText == nil then
		local text:string = textControl:GetText();
		Controls.ChatPull:SetToolTipString(text);
		OnExpandedChatPulldownChanged(newTargetType, newTargetID, text);
	else
		Controls.ChatPull:SetToolTipString(tooltipText);
	end
	PlayerTargetChanged(m_playerTarget);
end
function OnExpandedChatPulldownChanged(newTargetType :number, newTargetID :number, tooltipText:string)
	local textControl:table = Controls.ExpandedChatPull:GetButton():GetTextControl();
	if tooltipText == nil then
		local text:string = textControl:GetText();
		Controls.ExpandedChatPull:SetToolTipString(text);
		OnCollapsedChatPulldownChanged(newTargetType, newTargetID, text);
	else
		Controls.ExpandedChatPull:SetToolTipString(tooltipText);
	end
	PlayerTargetChanged(m_playerTarget);
end

-------------------------------------------------
-------------------------------------------------
function InputHandler( pInputStruct)
	local uiMsg = pInputStruct:GetMessageType();

	if (uiMsg == MouseEvents.LButtonUp or msg == MouseEvents.PointerUp) then
		LuaEvents.Tutorial_DisableMapDrag(false); --Re-enables map drag after releasing the drag resize button which disables map drag
	end
	
	if(uiMsg == KeyEvents.KeyUp) then
		local chatHasFocus:boolean = Controls.ChatEntry:HasFocus();
		local expandedChatHasFocus:boolean = Controls.ExpandedChatEntry:HasFocus();
		return chatHasFocus or expandedChatHasFocus;
	end
	
	return false;
end

function AdjustScreenSize()
	Controls.ShowPlayerListButton:SetSizeX(Controls.ShowPlayerListCheck:GetSizeX() + 20);
	Controls.PBCShowPlayerListButton:SetSizeX(Controls.PBCShowPlayerListCheck:GetSizeX() + 20);
	LuaEvents.WorldTracker_OnScreenResize();
	ContextPtr:RequestRefresh();
end

-------------------------------------------------
-------------------------------------------------
function OnUpdateUI( type )
	if( type == SystemUpdateUI.ScreenResize ) then
		AdjustScreenSize();
	end
end

function SetDefaultPanelMode()
	if(GameConfiguration.IsPlayByCloud()) then  
		Controls.ChatPanel:SetHide(true);
		Controls.ChatPanelBG:SetHide(true);
		Controls.ExpandedChatPanel:SetHide(true);
		Controls.ExpandedChatPanelBG:SetHide(true);
		Controls.PlayByCloudPanel:SetHide(false);
		Controls.PlayByCloudPanelBG:SetHide(false);
	else
		Controls.ChatPanel:SetHide(false);
		Controls.ChatPanelBG:SetHide(false);
		Controls.ExpandedChatPanel:SetHide(true);
		Controls.ExpandedChatPanelBG:SetHide(true);
		Controls.PlayByCloudPanel:SetHide(true);
		Controls.PlayByCloudPanelBG:SetHide(true);
	end
end

-- ===========================================================================
function OnRefresh()
	ContextPtr:ClearRequestRefresh();
	if(m_isExpandedChatPanelFilled and Controls.ExpandedChatEntryStack:GetSizeY() < Controls.ExpandedChatLogPanel:GetSizeY())then
		m_isExpandedChatPanelFilled = false;
	elseif(not m_isExpandedChatPanelFilled and Controls.ExpandedChatEntryStack:GetSizeY() > Controls.ExpandedChatLogPanel:GetSizeY())then
		m_isExpandedChatPanelFilled = true;
		Controls.ExpandedChatLogPanel:SetScrollValue(1);
	end
	if(m_isChatPanelFilled and Controls.ChatEntryStack:GetSizeY() < Controls.ChatLogPanel:GetSizeY())then
		m_isChatPanelFilled = false;
	elseif(not isChatPanelFilled and Controls.ChatEntryStack:GetSizeY() > Controls.ChatLogPanel:GetSizeY())then
		m_isChatPanelFilled = true;
		Controls.ChatLogPanel:SetScrollValue(1);
	end
end

-- ===========================================================================
function OnShutdown()

	Events.MultiplayerHostMigrated.Remove(OnMultiplayerHostMigrated);
	Events.MultiplayerMatchHostMigrated.Remove(OnMultiplayerMatchHostMigrated);
	Events.MultiplayerPlayerConnected.Remove( OnMultplayerPlayerConnected );
	Events.MultiplayerPrePlayerDisconnected.Remove( OnMultiplayerPrePlayerDisconnected );
	-- Update net connection icons whenever pings have changed.
	Events.MultiplayerPingTimesChanged.Remove(OnMultiplayerPingTimesChanged);
	Events.MultiplayerSnapshotRequested.Remove(OnEventUpdateChatPlayer);
	Events.MultiplayerSnapshotProcessed.Remove(OnEventUpdateChatPlayer);
	Events.MultiplayerChat.Remove( OnMultiplayerChat );
	-- When player info is changed, this pulldown needs to know so it can update itself if it becomes invalid.
	Events.PlayerInfoChanged.Remove(OnChatPanelPlayerInfoChanged);
	Events.SystemUpdateUI.Remove( OnUpdateUI );

	LuaEvents.ChatPanel_OnChatPanelRefresh.Remove( OnChatPanelRefresh );
	LuaEvents.ChatPanel_OnResetDraggedChatPanel.Remove( OnResetDraggedChatPanel );
	LuaEvents.ChatPanel_SetChatPanelSize.Remove( SetExpandedPanelSize );
	LuaEvents.MapPinPopup_SendPinToChat.Remove( OnSendPinToChat );
	LuaEvents.MapPinPopup_RequestChatPlayerTarget.Remove( OnMapPinPopup_RequestChatPlayerTarget );
	LuaEvents.WorldTracker_SetEmergencies.Remove( OnSetNumberOfEmergencies );

end

-- ===========================================================================
function Initialize()

	ContextPtr:SetRefreshHandler( OnRefresh );	

	Controls.ChatEntry:RegisterCommitCallback( SendChat );
	Controls.ContractButton:RegisterCallback(Mouse.eLClick, OnCloseExpandedPanel);
	Controls.ExpandButton:RegisterCallback(Mouse.eLClick, OnOpenExpandedPanel);
	Controls.ExpandedChatEntry:RegisterCommitCallback( SendChat );
	Controls.PBCShowPlayerListCheck:RegisterCallback(Mouse.eLClick, TogglePlayerListPanel);
	Controls.PBCShowPlayerListButton:RegisterCallback(Mouse.eLClick, TogglePlayerListPanel);
	Controls.ShowPlayerListCheck:RegisterCallback(Mouse.eLClick, TogglePlayerListPanel);
	Controls.ShowPlayerListButton:RegisterCallback(Mouse.eLClick, TogglePlayerListPanel);
	
	ContextPtr:SetShowHideHandler( ShowHideHandler );
	
	Events.MultiplayerHostMigrated.Add(OnMultiplayerHostMigrated);
	Events.MultiplayerMatchHostMigrated.Add(OnMultiplayerMatchHostMigrated);
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
	-- Update net connection icons whenever pings have changed.
	Events.MultiplayerPingTimesChanged.Add(OnMultiplayerPingTimesChanged);
	Events.MultiplayerSnapshotRequested.Add(OnEventUpdateChatPlayer);
	Events.MultiplayerSnapshotProcessed.Add(OnEventUpdateChatPlayer);
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	-- When player info is changed, this pulldown needs to know so it can update itself if it becomes invalid.
	Events.PlayerInfoChanged.Add(OnChatPanelPlayerInfoChanged);
	Events.GameConfigChanged.Add(OnChatPanelGameConfigChanged);
	Events.SystemUpdateUI.Add( OnUpdateUI );

	Events.KickVoteStarted.Add(OnKickVoteStarted);
	Events.KickVoteComplete.Add(OnKickVoteComplete);

	LuaEvents.ChatPanel_OnChatPanelRefresh.Add( OnChatPanelRefresh );
	LuaEvents.ChatPanel_OnResetDraggedChatPanel.Add( OnResetDraggedChatPanel );
	LuaEvents.ChatPanel_SetChatPanelSize.Add( SetExpandedPanelSize );
	LuaEvents.MapPinPopup_SendPinToChat.Add( OnSendPinToChat );
	LuaEvents.MapPinPopup_RequestChatPlayerTarget.Add( OnMapPinPopup_RequestChatPlayerTarget );
	LuaEvents.WorldTracker_SetEmergencies.Add( OnSetNumberOfEmergencies );

	BuildPlayerList();

	if ( m_isDebugging ) then
		for i=1,20,1 do
			Network.SendChat( "Test message #"..tostring(i), -1, -1 );
		end
	end	

	ChatPrintHelpHint(Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
	ChatPrintHelpHint(Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);

	-- Keep both edit boxes in-sync
	Controls.ChatEntry:RegisterStringChangedCallback(
		function(pControl:table)
			local text:string = Controls.ChatEntry:GetText();
			if Controls.ExpandedChatEntry:GetText() ~= text then
				Controls.ExpandedChatEntry:SetText( text );
			end
		end);
	Controls.ExpandedChatEntry:RegisterStringChangedCallback(
		function(pControl:table)
			local text:string = Controls.ExpandedChatEntry:GetText();
			if Controls.ChatEntry:GetText() ~= text then
				Controls.ChatEntry:SetText(text);
			end
		end);
	Controls.DragSizer:RegisterCallback( Drag.eDrag, OnDragResizer);
	Controls.ResetChatButton:RegisterCallback( Mouse.eLClick, OnResetChatButton );

	ContextPtr:SetInputHandler(InputHandler, true);
	ContextPtr:SetShutdown( OnShutdown );

	SetDefaultPanelMode();
	AdjustScreenSize();
	--Chat panel drag resizing init.
	m_ChatStartSizeY = Controls.ChatPanel:GetSizeY();
	m_StartingMouseX, m_StartingMouseY = Controls.DragButton:GetScreenOffset();

	--This option requires a restart after changing, so we only need to check it at initialize
	local replaceDragWithClick : number = Options.GetUserOption("Interface", "ReplaceDragWithClick");
	if(replaceDragWithClick == 1)then
		Controls.DragButton:LocalizeAndSetToolTip("LOC_CLICK_TO_RESIZE");
	end
	
	m_isChatPanelFilled = false;
	m_isExpandedChatPanelFilled = false;
end
Initialize()
