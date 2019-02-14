

local m_friendProfile = { name ="LOC_FRIEND_ACTION_PROFILE",	tooltip = "LOC_FRIEND_ACTION_PROFILE_TT",	action = "profile" };
local m_friendChat =	{ name ="LOC_FRIEND_ACTION_CHAT",		tooltip = "LOC_FRIEND_ACTION_CHAT_TT",		action = "chat" };
local m_friendInvite =	{ name = "LOC_FRIEND_ACTION_INVITE",	tooltip = "LOC_FRIEND_ACTION_INVITE_TT",	action = "invite" };

function DefaultFriendsSortFunction(a:table,b:table)
	if not a.PlayingCiv and b.PlayingCiv then
		return false;
	elseif a.PlayingCiv and not b.PlayingCiv then
		return true;
	end
	return false;
	end

function FlippedFriendsSortFunction(a:table,b:table)
	if a.PlayingCiv and not b.PlayingCiv then
		return false;
	elseif not a.PlayingCiv and b.PlayingCiv then
		return true;
	end
	return false;
end

function GetFriendsList(sortFunction:ifunction)
	
	local friends:table = {};
	local pFriends = Network.GetFriends();
	if pFriends ~= nil then
		local numFriends:number = pFriends:GetFriendCount();
		for i:number = 0, numFriends - 1 do
			local friend:table = pFriends:GetFriendByIndex(i);
			if friend.IsOnline then
				friend.RichPresence = Locale.Lookup(pFriends:GetRichPresence(friend.ID, "civPresence"));
				friend.PlayingCiv = friend.RichPresence ~= nil and friend.RichPresence ~= "";
				table.insert(friends, friend);
			end
		end

		if sortFunction then
			table.sort(friends, sortFunction);
		else
			table.sort(friends, DefaultFriendsSortFunction);
		end
	end

	return friends;
end

function OnFriendPulldownCallback(friendID:string, actionType:string)
	local pFriends = Network.GetFriends();
	if pFriends ~= nil then
		if actionType == "profile" then
			pFriends:ActivateGameOverlayToUser(friendID);
		elseif actionType == "chat" then
			pFriends:ActivateGameOverlayToChat(friendID);
		elseif actionType == "invite" then
			pFriends:InviteUserToGame(friendID);
		end
	end
end

function BuildFriendActionList(actionList:table, allowInvites:boolean)

	if allowInvites and Network.HasSingleFriendInvite() then
		table.insert(actionList, m_friendInvite);
	end

	if Network.CanViewFriendProfile() then
		table.insert(actionList, m_friendProfile);
	end

	if Network.CanShowFriendChatWindow() then
		table.insert(actionList, m_friendChat);
	end
end

function PopulateFriendsInstance(instance:table, friendData:table, friendActions:table, pulldownClickedCallback:ifunction)
	local friendID:string = friendData.ID;
	local friendStatus:string = friendData.PlayingCiv and friendData.RichPresence or "LOC_PRESENCE_ONLINE";
	local hasActions:boolean = (friendActions ~= nil) and (#friendActions > 0);

	instance.PlayerName:SetText(friendData.PlayerName);
	instance.PlayerStatus:SetText(Locale.Lookup(friendStatus));
	instance.OnlineIndicator:SetHide(not friendData.PlayingCiv);

	instance.Simple_PlayerName:SetText(friendData.PlayerName);
	instance.Simple_PlayerStatus:SetText(Locale.Lookup(friendStatus));
	instance.Simple_OnlineIndicator:SetHide(not friendData.PlayingCiv);

	instance.FriendPulldown:SetHide(not hasActions);
	instance.FriendBox:SetHide(hasActions);

	instance.FriendPulldown:ClearEntries();
	if hasActions then
		for _, action in ipairs(friendActions) do
			controlTable = {};
			local actionType:string = action.action;
			instance.FriendPulldown:BuildEntry("InstanceOne", controlTable);
			controlTable.Button:LocalizeAndSetText(action.name);
			controlTable.Button:LocalizeAndSetToolTip(action.tooltip);
			controlTable.Button:RegisterCallback(Mouse.eLClick, function() 
				OnFriendPulldownCallback(friendID, actionType);
				if pulldownClickedCallback ~= nil then
					pulldownClickedCallback(friendID, actionType);
				end
			end);
		end
		
		instance.FriendPulldown:CalculateInternals();
	end
end