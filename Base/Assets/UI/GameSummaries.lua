-------------------------------------------------
-- Game Summaries Screen
-------------------------------------------------
include( "InstanceManager" );
include( "SupportFunctions" );
include( "PopupDialog" );

----------------------------------------------------------------   
-- Utilities
----------------------------------------------------------------    
-- Attempt to set a control's icon by enumerating an array.
function SetControlIcon(control, icons)
	if(icons) then
		local s = #icons;
		for i = s, 1, -1 do
			local v = icons[i];
			if(control:TrySetIcon(v)) then
				return true;
			end
		end
	end

	return false;
end


-- Global Constants
g_TabControls = {
	{Controls.OverviewTab, Controls.SelectedOverviewTab, Controls.OverviewTabPanel},
	{Controls.HistoryTab, Controls.SelectedHistoryTab, Controls.HistoryTabPanel},
};

-- Global Variables
g_GamesManager = InstanceManager:new("GameInstance", "Button", Controls.ListingsStack);
g_LeaderProgressManager = InstanceManager:new("LeaderProgressInstance", "Icon", Controls.LeaderProgressStack);
g_VictoryProgressManager = InstanceManager:new("VictoryProgressInstance", "Root", Controls.VictoryProgressStack);

g_HighlightsManager = InstanceManager:new("StatInstance", "Root", Controls.HighlightsStack);
g_StatisticsBlockManager = InstanceManager:new("StatBlockInstance", "RootStack", Controls.StatisticsStack);
g_StatisticsManagers = {};
		
g_AvailableRulesets = nil; 			-- Array of available rulesets.
g_CurrentRuleset = nil; 			-- Currently selected ruleset.
g_Games = nil;						-- List of game history data. 
g_GameListings = nil;				-- List of game history listings.
g_GameListingsSortFunction = nil;	-- Currently selected sort method.
g_SortDirectionReversed = false;	-- Reverse the sort?
g_SelectedGameId = nil;				-- Track currently selected listing.
g_RulesetPlayers = nil;				-- Map of all ruleset playable leaders
g_RulesetTypes = nil;				-- Map of all ruleset types.	
g_RulesetVictories = nil;			-- Map/Array of all ruleset victories.
g_Categories = nil;					-- Sorted array of all statistics categories.
g_Statistics = nil;					-- Sorted array of all statistics.

-- Release cache to free up memory.
function DumpCache()
	g_AvailableRulesets = nil;
	g_CurrentRuleset = nil;
	g_Games = nil;
	g_GameListings = nil;
	g_SelectedGameListingHandle = nil;
	g_RulesetPlayers = nil;
	g_RulesetTypes = nil;
	g_RulesetVictories = nil;
	g_Categories = nil;
	g_Statistics = nil;
end

function DumpInstances()
	for i,v in ipairs(g_StatisticsManagers) do
		v:ResetInstances();
	end
	g_HighlightsManager:ResetInstances();
	g_StatisticsBlockManager:ResetInstances();
	g_StatisticsManagers = {};
	
	g_GamesManager:ResetInstances();
	g_LeaderProgressManager:ResetInstances();
	g_VictoryProgressManager:ResetInstances();
end

-- Much of hall of fame is read-only and static so it can be cached.
function UpdateGlobalCache()
	DumpCache();

	local gameObjects = HallofFame.GetGameObjects();
	g_GameObjects = {};
	for i,v in ipairs(gameObjects) do
		g_GameObjects[v.ObjectId] = v;
	end

	g_AvailableRulesets = HallofFame.GetAvailableRulesets();	
	if(g_AvailableRulesets and #g_AvailableRulesets > 0) then
		for i,v in ipairs(g_AvailableRulesets) do
			v.DisplayName = Locale.Lookup(v.Name);
		end

		table.sort(g_AvailableRulesets, function(a,b) 
			if(a.SortIndex ~= b.SortIndex) then
				return a.SortIndex < b.SortIndex;
			else
				return Locale.Compare(a.DisplayName, b.DisplayName) == -1;
			end
		end);

		local indexed_categories = {};
		g_Categories = HallofFame.GetStatisticsCategories();
		for i,v in ipairs(g_Categories) do
			indexed_categories[v.Category] = v;
			v.Name = v.Name and Locale.Lookup(v.Name) or "";
		end
		table.sort(g_Categories, function(a,b)
			if(a.SortIndex ~= b.SortIndex) then
				return a.SortIndex < b.SortIndex;
			else
				return Locale.Compare(a.Name,b.Name) == -1;
			end
		end);

		g_Statistics = {};
		local statistics = HallofFame.GetStatistics();
		for i,stat in ipairs(statistics) do
			local cat = indexed_categories[stat.Category];
			if(cat and not cat.IsHidden) then
				stat.Name = Locale.Lookup(stat.Name);
				table.insert(g_Statistics, stat);
			end
		end

		table.sort(g_Statistics, function(a,b)
			if(a.Importance ~= b.Importance) then
				return a.Importance > b.Importance;
			else
				return Locale.Compare(a.Name, b.Name) == -1;
			end
		end);
	else
		g_CurrentRuleset = nil;
	end
end

function UpdateRulesetCache()
	
	local ruleset = g_CurrentRuleset.Ruleset
	local players = HallofFame.GetRulesetPlayableLeaders(ruleset);
	g_RulesetPlayers = {};
	for i,v in ipairs(players) do
		g_RulesetPlayers[v.LeaderType] = v;
	end
	
	g_RulesetTypes = HallofFame.GetRulesetTypes(ruleset);	

	local victoryProgress = HallofFame.GetVictoryProgress(ruleset);
	
	g_RulesetVictories = {};
	for k,v in pairs(victoryProgress) do
	
		-- Localize Name 
		v.Name = Locale.Lookup(v.Name);

		v.Icons = {"ICON_VICTORY_UNIVERSAL"};
		table.insert(v.Icons, "ICON_" .. v.Type);
		table.insert(v.Icons, v.Icon);
		
		-- Store in an array to be sorted.
		table.insert(g_RulesetVictories, v);

		-- Store as id lookup as well.
		g_RulesetVictories[v.Type] = v;
	end
	
	table.sort(g_RulesetVictories, function(a,b)
		return Locale.Compare(a.Name, b.Name) == -1;
	end); 
end

function SelectTab(index)
	for i,v in ipairs(g_TabControls) do
		if(i ~= index) then
			v[1]:SetSelected(false);
			v[2]:SetHide(true);
			v[3]:SetHide(true);
		end
	end
	
	g_TabControls[index][3]:SetHide(false);
	g_TabControls[index][2]:SetHide(false);
	g_TabControls[index][1]:SetSelected(true);
end

function SelectRuleset(index)
	g_CurrentRuleset = g_AvailableRulesets[index];
	Controls.RulesetPullDown:GetButton():SetText(g_CurrentRuleset.DisplayName);
	
	UpdateRulesetCache();

	Overview_PopulateHighlights();
	Overview_PopulateVictoryProgress();
	Overview_PopulateLeaderProgress();
	Overview_PopulateStatistics();
	History_PopulateGames();
end
----------------------------------------------------------------  
function SelectGameListing(gameId)
	g_SelectedGameId = gameId;
	History_RefreshSelectionState();
end

function LoadConfiguration()

end

----------------------------------------------------------------   
-- Populate Methods
----------------------------------------------------------------   
function PopulateAvailableRulesets()
	local rulesets = g_AvailableRulesets or {};
	local comboBox = Controls.RulesetPullDown;
	comboBox:ClearEntries();
	for i, v in ipairs(rulesets) do
		local controlTable = {};
		comboBox:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText(v.DisplayName);
	
		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			SelectRuleset(i);
		end);	
	end

	comboBox:CalculateInternals();
end

function Overview_PopulateHighlights()
	-- Clear instances.
	g_HighlightsManager:ResetInstances();
	
	--local stats = HallofFame.GetRulesetHighlights(g_CurrentRuleset.Value, 10) or {};
	--
	--if(#stats == 0) then
		--Controls.Highlights:SetHide(true);
		--return;
	--end
	--
	--Controls.Highlights:SetHide(false);
	--
	---- Process Data
	--for i,v in ipairs(stats) do
		--v.Name = Locale.Lookup(v.Name);
		--if(v.ValueType) then
			--local t = g_RulesetTypes[v.ValueType];
			--if(t) then
				--v.ValueIcon = t.Icon or ("ICON_" .. t.Type);
				--v.DisplayValue = Locale.Lookup(t.Name);
			--end
		--elseif(v.ValueObjectId) then
			--local o = g_GameObjects[v.ValueObjectId];
			--if(o) then
				--v.ValueIcon = o.Icon or v.ValueIcon;
				--v.DisplayValue = Locale.Lookup(o.Name);
			--end
		--elseif(v.ValueString) then
			--v.DisplayValue = Locale.Lookup(v.ValueString);
		--elseif(v.ValueNumeric) then
			--v.DisplayValue = Locale.ToNumber(v.ValueNumeric, "###,###");
		--end	
--
		--if(v.Annotation) then
			--v.Annotation = Locale.Lookup(v.Annotation, {Name = "Amount", Value = v.ValueNumeric});
		--end			
	--end
		--
	---- sort stats (Importance Desc, Name)
	--table.sort(stats, function(a,b)
		--if(a.Importance ~= b.Importance) then
			--return a.Importance > b.Importance;
		--else
			--return Locale.Compare(a.Name, b.Name) == -1;
		--end
	--end);
	--
	--for _,stat in ipairs(stats) do
		--if(stat.DisplayValue) then
			--local instance = g_HighlightsManager:GetInstance();
					--
			--if(stat.Icon and instance.TitleIcon:TrySetIcon(stat.Icon)) then
				--instance.TitleIcon:SetHide(false);
			--else
				--instance.TitleIcon:SetHide(true);
			--end
			--instance.TitleCaption:LocalizeAndSetText(stat.Name);
			--
			--if(stat.ValueIcon and instance.ValueIcon:TrySetIcon(stat.ValueIcon)) then
				--instance.ValueIcon:SetHide(false);
			--else
				--instance.ValueIcon:SetHide(true);
			--end
			--
			--instance.ValueCaption:SetText(stat.DisplayValue);
			--if(stat.Annotation) then
				--instance.Annotation:LocalizeAndSetText(stat.Annotation);
				--instance.Annotation:SetHide(false);
			--else
				--instance.Annotation:SetHide(true);
			--end
			--
			--instance.AnnotationStack:CalculateSize();
			--instance.AnnotationStack:ReprocessAnchoring();
			--instance.TitleStack:CalculateSize();
			--instance.TitleStack:ReprocessAnchoring();
			--instance.ValueStack:CalculateSize();
			--instance.ValueStack:ReprocessAnchoring();
		--end
	--end
	
	Controls.HighlightsStack:CalculateSize();
	Controls.HighlightsStack:ReprocessAnchoring();
end

function Overview_PopulateVictoryProgress()
	g_VictoryProgressManager:ResetInstances();
	for i, v in ipairs(g_RulesetVictories) do
		if(not v.Hidden) then
			local instance = g_VictoryProgressManager:GetInstance();
		
			local tooltip = v.Name;
		
			if(tonumber(v.Count) > 0) then
				tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_GAMESUMMARY_VICTORYPROGRESS_COUNT", v.Count);	
				instance.Icon:SetColor(1,1,1,1);
				instance.Root:SetColor(1,1,1,1);
			else
				instance.Icon:SetColor(1,1,1,0.25);
				instance.Root:SetColor(1,1,1,0.25);
			end
		
			if(v.MostRecentLeaderType ~= nil) then
				local player = g_RulesetPlayers[v.MostRecentLeaderType];
				if(player) then
					tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_GAMESUMMARY_VICTORYPROGRESS_LEADER", player.LeaderName);
				end
			end

			SetControlIcon(instance.Icon, v.Icons)
			instance.Icon:SetToolTipString(tooltip);
		end
	end
end

function Overview_PopulateLeaderProgress()
	local leaderProgress = HallofFame.GetLeaderProgress(g_CurrentRuleset.Ruleset);
	
	local leaders = {};
	for k,v in pairs(leaderProgress) do
	
		-- Pre-translate for sorting.
		local player = g_RulesetPlayers[k];
		v.LeaderName = Locale.Lookup(player.LeaderName);
		v.LeaderIcon = player.LeaderIcon or ("ICON_" .. v.LeaderType);
		
		-- Insert into an array for sorting.
		table.insert(leaders, v);
	end
	
	table.sort(leaders, function(a,b)
		return Locale.Compare(a.LeaderName, b.LeaderName) == -1;
	end);
	
	g_LeaderProgressManager:ResetInstances();
	for i, v in ipairs(leaders) do
		local instance = g_LeaderProgressManager:GetInstance();
		
		local tooltip = v.LeaderName;
		if(v.MostRecentVictoryType ~= nil) then
			tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_GAMESUMMARY_LEADERPROGRESS_WINCOUNT", v.VictoryCount, v.PlayCount);

			local victory = g_RulesetVictories[v.MostRecentVictoryType];
			if(victory) then
				tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_GAMESUMMARY_LEADERPROGRESS_VICTORY", victory.Name);
			end
			instance.Icon:SetColor(1,1,1,1);
		else
			if(tonumber(v.PlayCount) > 0) then
				tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_GAMESUMMARY_LEADERPROGRESS_PLAYCOUNT", v.PlayCount);
				instance.Icon:SetColor(1,1,1,0.50);
	
			else
				instance.Icon:SetColor(1,1,1,0.25);
			end
		end
		
		instance.Icon:SetIcon(v.LeaderIcon);
		instance.Icon:SetToolTipString(tooltip);
	end
end

function Overview_PopulateStatistics()
	-- Clear statistics instances.
	for i,v in ipairs(g_StatisticsManagers) do
		v:ResetInstances();
	end
	g_StatisticsBlockManager:ResetInstances();
	g_StatisticsManagers = {};
	
	
	local indexed_datapoints = {};
	local datapoints = HallofFame.GetRulesetDataPoints(g_CurrentRuleset.Ruleset);
	for i,v in ipairs(datapoints) do
		indexed_datapoints[v.DataPoint] = v;
	end

	-- Faster variant of table.insert
	local AppendItem = function(t, i)
		if(i ~= nil) then
			local s = #t;
			t[s + 1] = i;
		end
	end

	local statistics_by_category = {};
	for i,stat in ipairs(g_Statistics) do		
		local dp = indexed_datapoints[stat.DataPoint];
		if(dp) then
			local icons = {stat.ValueIconDefault};

			local v = {
				Name = stat.Name,
				Icon = stat.Icon,
				
				-- Array of icons to try using (in reverse-order for quick appending).
				ValueIcons = icons
			};

			-- Based on the kind of value the icon and display value will be updated.
			if(dp.ValueType) then
				local t = g_RulesetTypes[dp.ValueType];
				if(t) then
					AppendItem(icons, t.Icon);
					v.DisplayValue = Locale.Lookup(t.Name);
				end
			elseif(dp.ValueObjectId) then
				local o = g_GameObjects[dp.ValueObjectId];
				if(o) then
					AppendItem(icons, o.Icon);
					v.DisplayValue = o.Name and Locale.Lookup(o.Name);
				end
			elseif(dp.ValueString) then
				v.DisplayValue = Locale.Lookup(dp.ValueString);
			elseif(dp.ValueNumeric) then
				v.DisplayValue = Locale.ToNumber(dp.ValueNumeric, "###,###");
			end	
			
			-- Override icon
			AppendItem(icons, stat.ValueIconOverride);

			if(stat.Annotation) then
				v.Annotation = Locale.Lookup(stat.Annotation, {Name = "Amount", Value = dp.ValueNumeric});
			end
			
			if(v.DisplayValue) then
				local s = statistics_by_category[stat.Category];
				if(s == nil) then 
					s = {};
					statistics_by_category[stat.Category] = s;
				end

				table.insert(s, v);
			end
		end
	end
	
	for i,cat in ipairs(g_Categories) do
		local stats = statistics_by_category[cat.Category];

		if(not cat.IsHidden and stats and #stats > 0) then
			local cat_instance = g_StatisticsBlockManager:GetInstance();
			cat_instance.StatsTitle:SetText(cat.Name);
			
			local statsManager = InstanceManager:new("StatInstance", "Root", cat_instance.StatisticsStack);
			table.insert(g_StatisticsManagers, statsManager);
			
			for _,stat in ipairs(stats) do
				if(stat.DisplayValue) then
					local stat_instance = statsManager:GetInstance();
							
					if(stat.Icon and stat_instance.TitleIcon:TrySetIcon(stat.Icon)) then
						stat_instance.TitleIcon:SetHide(false);
					else
						stat_instance.TitleIcon:SetHide(true);
					end
					stat_instance.TitleCaption:LocalizeAndSetText(stat.Name);

					if(SetControlIcon(stat_instance.ValueIcon, stat.ValueIcons)) then
						stat_instance.ValueIcon:SetHide(false);
					else
						stat_instance.ValueIcon:SetHide(true);
					end
									
					stat_instance.ValueCaption:SetText(stat.DisplayValue);
					if(stat.Annotation) then
						stat_instance.Annotation:LocalizeAndSetText(stat.Annotation);
						stat_instance.Annotation:SetHide(false);
					else
						stat_instance.Annotation:SetHide(true);
					end
					
					stat_instance.AnnotationStack:CalculateSize();
					stat_instance.AnnotationStack:ReprocessAnchoring();
					stat_instance.TitleStack:CalculateSize();
					stat_instance.TitleStack:ReprocessAnchoring();
					stat_instance.ValueStack:CalculateSize();
					stat_instance.ValueStack:ReprocessAnchoring();
				end

			end
			
			cat_instance.StatisticsStack:CalculateSize();
			cat_instance.StatisticsStack:ReprocessAnchoring();
			cat_instance.RootStack:CalculateSize();
			cat_instance.RootStack:ReprocessAnchoring();
		end
	end
	
	Controls.StatisticsStack:CalculateSize();
	Controls.StatisticsStack:ReprocessAnchoring();
end

function History_PopulateGames()
	local games = HallofFame.GetGames(g_CurrentRuleset.Ruleset);
	g_Games = games;

	-- Pre-process to make it sortable.
	for i,v in ipairs(games) do
		for player_index, p in ipairs(v.Players) do
			if(p.IsMajor) then
				local player = g_RulesetPlayers[p.LeaderType];
				local fgColor, bgColor = UI.GetPlayerColorValues(p.LeaderType, 0);
				
				if(player) then
					p.LeaderName = p.LeaderName or player.LeaderName;
					p.CivilizationName = p.CivilizationName or player.CivilizationName;
					p.LeaderIcon = player.LeaderIcon or ("ICON_" .. player.LeaderType);
					p.CivilizationIcon= player.CivilizationIcon or ("ICON_" .. player.CivilizationType);
					p.fgColor = fgColor;
					p.bgColor = bgColor;
				end
				
				if(p.IsLocal and v.MyPlayer == nil) then
					v.Score = p.Score;
					v.MyPlayer = player_index;				
					v.MyVictory = (v.VictorTeamId ~= nil) and (v.VictorTeamId == p.TeamId);
					v.MyLeaderName = p.LeaderName;
					if(v.MyVictory) then
						v.VictorLeaderName = v.MyLeaderName;
						break;
					end
				end

				if(v.VictorTeamId ~= nil and p.TeamId == v.VictorTeamId and v.VictorLeaderName == nil) then
					v.VictorLeaderName = p.LeaderName;
				end
			end
		end
	end
	
	table.sort(games, g_GameListingsSortFunction or History_SortByScore);

	-- Should we reverse the list?
	if(g_SortDirectionReversed) then
		local i, j = 1, #games;

		while i < j do
			games[i], games[j] = games[j], games[i]

			i = i + 1
			j = j - 1
		end
	end

	g_SelectedGameId = nil;
	g_GameListings = {};
	g_GamesManager:ResetInstances();
	for i,v in ipairs(games) do
		local instance = g_GamesManager:GetInstance();

		local gameSpeed = g_RulesetTypes[v.GameSpeedType];
		local startEra = g_RulesetTypes[v.StartEraType];

		instance.Score:SetText(v.Score);
		instance.Turns:LocalizeAndSetText("LOC_GAMESUMMARY_TURNS", v.TurnCount);

        instance.Button:RegisterCallback( Mouse.eLDblClick, function()
            UI.PlaySound("Main_Menu_Mouse_Over");
            OnGameDetailsClicked(g_SelectedGameId) 
        end);

		if(gameSpeed) then
			instance.GameSpeedIcon:SetIcon(gameSpeed.Icon or ("ICON_" .. gameSpeed.Type));
			instance.GameSpeedIcon:SetHide(false);
		else
			instance.GameSpeedIcon:SetHide(true);
		end

		
		if(v.MyPlayer ~= nil) then
			local myPlayer = v.Players[v.MyPlayer];

			local myPlayerDifficulty = g_RulesetTypes[myPlayer.DifficultyType];
			if(myPlayerDifficulty) then
				instance.PlayerDifficultyIcon:SetIcon(myPlayerDifficulty.Icon or ("ICON_" .. myPlayerDifficulty.Type));
				instance.PlayerDifficultyIcon:SetHide(false);
			else
				-- TODO: Populate with an "unknown difficulty" icon/tooltip.
				instance.PlayerDifficultyIcon:SetHide(true);
			end
			
			instance.PlayerLeaderIcon:SetIcon(myPlayer.LeaderIcon or "ICON_LEADER_DEFAULT");
			instance.PlayerLeaderName:LocalizeAndSetText(myPlayer.LeaderName);
			instance.PlayerCivilizationIcon:SetIcon(myPlayer.CivilizationIcon or "ICON_CIVILIZATION_UNKNOWN");
			instance.PlayerCivilizationIcon:SetColor(myPlayer.bgColor);
			instance.PlayerCivilizationIconBG:SetColor(myPlayer.fgColor);
			instance.PlayerCivilizationName:LocalizeAndSetText(myPlayer.CivilizationName or "");
		end
		
		if(v.VictorTeamId) then		
			local victory = g_RulesetVictories[v.VictoryType];				
			local myVictory = v.MyVictory or false;

			if(victory and not victory.Hidden) then
				instance.VictoryName:LocalizeAndSetText(victory.Name);
				instance.VictoryName:SetHide(false);
			else
				instance.VictoryName:SetHide(true);
			end

			instance.VictoryIcon:SetHide(not SetControlIcon(instance.VictoryIcon, victory.Icons));

			local victor = v.VictorLeaderName or "LOC_TEAM_UNKNOWN_NAME";
			instance.VictorName:LocalizeAndSetText((myVictory) and "LOC_GAMESUMMARY_YOU" or victor);
			
			instance.VictoryOrDefeat:LocalizeAndSetText((myVictory) and "LOC_GAMESUMMARY_VICTORY" or "LOC_GAMESUMMARY_DEFEAT");
		else
			instance.VictoryOrDefeat:LocalizeAndSetText("LOC_GAMESUMMARY_DEFEAT");
			instance.VictoryIcon:SetIcon("ICON_DEFEAT_GENERIC");
			instance.VictorName:LocalizeAndSetText("LOC_GAMESUMMARY_NOBODY_WON");
			instance.VictoryName:SetText(nil);
		end
		
		if(startEra) then
			instance.StartEra:LocalizeAndSetText("LOC_GAMESUMMARY_ERA_STARTED", startEra.Name);
			instance.StartEra:SetHide(false);
		else
			instance.StartEra:SetHide(true);
		end

		instance.LastPlayed:LocalizeAndSetText("LOC_GAMESUMMARY_LAST_PLAYED", v.LastPlayed);
		
		local h = v.GameId;
		instance.Button:RegisterCallback(Mouse.eLClick, function()
			SelectGameListing(h);
		end);
			
		table.insert(g_GameListings, {v.GameId, instance});
	end

	Controls.ListingsStack:CalculateSize();
	Controls.ListingsStack:ReprocessAnchoring();
	Controls.Listings:CalculateInternalSize();
	
	History_RefreshSelectionState();
end

function History_RefreshSelectionState()
	for i,v in ipairs(g_GameListings or {}) do
		if(v[1] == g_SelectedGameId) then
			v[2].Button:SetSelected(true);
		else
			v[2].Button:SetSelected(false);
		end
	end
	
	Controls.DeleteGame:SetDisabled(g_SelectedGameId == nil);
	Controls.ViewGameDetails:SetDisabled(g_SelectedGameId == nil);
end
		

function History_SortByScore(a,b)
	-- Score(d), LastPlayed(d), GameId
	local aScore = a.Score or -1;
	local bScore = b.Score or -1;

	if(aScore ~= bScore) then
		return aScore > bScore;
	elseif(a.LastPlayed ~= b.LastPlayed) then
		return a.LastPlayed > b.LastPlayed
	else
		return a.GameId < b.GameId;
	end

end

function History_SortByLeader(a,b)
	-- LeaderName(d), Score(d), LastPlayed(d), GameId
	local aScore = a.Score or -1;
	local bScore = b.Score or -1;

	local aLeader = a.MyLeaderName;
	local bLeader = b.MyLeaderName;
	
	if(aLeader ~= bLeader) then
		return Locale.Compare(aLeader, bLeader) == -1;
	elseif(aScore ~= bScore) then
		return aScore > bScore;
	elseif(a.LastPlayed ~= b.LastPlayed) then
		return a.LastPlayed > b.LastPlayed;
	else
		return a.GameId < b.GameId;
	end
end

function History_SortByResult(a,b)	
	-- Victory, Score(d), LastPlayed(d), GameId
	-- Defeat, Score(d), LastPlayed(d), GameId
	local aScore = a.Score or -1;
	local bScore = b.Score or -1;

	local aVictory = a.MyVictory;
	local bVictory = b.MyVictory;

	if(aVictory ~= bVictory) then
		return aVictory;
	elseif(aScore ~= bScore) then
		return aScore > bScore;
	elseif(a.LastPlayed ~= b.LastPlayed) then
		return a.LastPlayed > b.LastPlayed;
	else
		return a.GameId < b.GameId;
	end
end

function History_SortByVictor(a,b)
	-- You, Score(d), LastPlayed(d), GameId
	-- LeaderName, Score(d), LastPlayed(d), GameId
	-- Nobody, Score(d), LastPlayed(d), GameId
	local aScore = a.Score or -1;
	local bScore = b.Score or -1;

	local aYou = a.MyVictory;
	local bYou = b.MyVictory

	local aLeader = a.VictorLeaderName or nil;
	local bLeader = b.VictorLeaderName or nil;

	if(aYou ~= bYou) then
		return aYou;
	elseif(aLeader ~= bLeader) then
		if(aLeader ~= nil and bLeader ~= nil) then
			return Locale.Compare(aLeader, bLeader) == -1;
		else
			return aLeader ~= nil;
		end
	elseif(aScore ~= bScore) then
		return aScore > bScore;
	elseif(a.LastPlayed ~= b.LastPlayed) then
		return a.LastPlayed > b.LastPlayed;
	else
		return a.GameId < b.GameId;
	end		
end

function History_SortByLastPlayed(a,b)
	-- LastPlayed(d), Score(d), GameId
	local aScore = a.Score or -1;
	local bScore = b.Score or -1;

	if(a.LastPlayed ~= b.LastPlayed) then
		return a.LastPlayed > b.LastPlayed;
	elseif(aScore ~= bScore) then
		return aScore > bScore;
	else
		return a.GameId < b.GameId;
	end
end

----------------------------------------------------------------   
-- Generic Handlers
----------------------------------------------------------------   
function HandleExitRequest()
	UIManager:DequeuePopup( ContextPtr );
end

----------------------------------------------------------------   
-- Event Handlers
----------------------------------------------------------------  
function OnGameDetailsClicked(id)
	local kParameters = {};
	kParameters.GameId = id
	UIManager:QueuePopup(Controls.GameDetails, PopupPriority.Current, kParameters);
end

function OnDeleteGame()
	local gameId = g_SelectedGameId;
	local selected_ruleset = g_CurrentRuleset.Ruleset;

	HallofFame.DeleteGame(gameId);

	UpdateGlobalCache();
	History_RefreshSelectionState();
	PopulateAvailableRulesets();

	local ruleset_index = 1;
	for i,v in ipairs(g_AvailableRulesets) do
		if(v.Ruleset == selected_ruleset) then
			ruleset_index = i;
		end
	end

	SelectRuleset(ruleset_index);
end
----------------------------------------------------------------  
function OnShow()
	UpdateGlobalCache();
	
	History_RefreshSelectionState();
	PopulateAvailableRulesets();
	SelectRuleset(1);
	SelectTab(1);
end	

function OnHide()
	DumpInstances();
	DumpCache();
end
----------------------------------------------------------------  
function PostInit()
	if(not ContextPtr:IsHidden()) then
		OnShow();
	end
end

----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
	if (uiMsg == KeyEvents.KeyUp) then
		if (wParam == Keys.VK_ESCAPE) then
			HandleExitRequest();
			return true;
		end
	end
end



----------------------------------------------------------------   
-- Initializer
----------------------------------------------------------------    
function Initialize()
	ContextPtr:SetInputHandler( InputHandler );
	g_PopupDialog = PopupDialog:new( "GameSummaries" );
	
	Controls.OverviewTab:RegisterCallback(Mouse.eLClick, function() 
		UI.PlaySound("Main_Menu_Mouse_Over");
		OnOverviewTabClicked() 
	end);
	
	Controls.HistoryTab:RegisterCallback(Mouse.eLClick, function() 
		UI.PlaySound("Main_Menu_Mouse_Over");
		OnHistoryTabClicked() 
	end);
	
	for i,v in ipairs(g_TabControls) do
		v[1]:RegisterCallback( Mouse.eLClick, function()
			UI.PlaySound("Main_Menu_Mouse_Over");
			SelectTab(i);
		end);
	end
	
	Controls.DeleteGame:RegisterCallback(Mouse.eLClick, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
		g_PopupDialog:Reset();
		g_PopupDialog:AddText(Locale.Lookup("LOC_GAMESUMMARY_DELETE_GAME_PROMPT"));
		g_PopupDialog:AddButton(Locale.Lookup("LOC_CANCEL"), nil);
		g_PopupDialog:AddButton(Locale.Lookup("LOC_YES"), function() OnDeleteGame(g_SelectedGameId) end, nil, nil, "PopupButtonInstanceRed");
		g_PopupDialog:Open();
	end);

	Controls.ViewGameDetails:RegisterCallback(Mouse.eLClick, function() 
		UI.PlaySound("Main_Menu_Mouse_Over");
		OnGameDetailsClicked(g_SelectedGameId) 
	end);
	
	Controls.ReplayGame:SetDisabled(true);

	-- Apply standard functionality when sorting.
	function HandleColumnSort(func)
		return function()
			UI.PlaySound("Main_Menu_Mouse_Over");
			if g_GameListingsSortFunction == func then
				g_SortDirectionReversed = not g_SortDirectionReversed;
			else
				g_SortDirectionReversed = false;
			end
			g_GameListingsSortFunction = func;
			History_PopulateGames();
		end;
	end

	Controls.ScoreColumn:RegisterCallback( Mouse.eLClick, HandleColumnSort(History_SortByScore));
	Controls.YouColumn:RegisterCallback( Mouse.eLClick, HandleColumnSort(History_SortByLeader));	
	Controls.ResultsColumn:RegisterCallback( Mouse.eLClick, HandleColumnSort(History_SortByResult));
	Controls.VictoryColumn:RegisterCallback( Mouse.eLClick, HandleColumnSort(History_SortByVictor));
	Controls.SettingsColumn:RegisterCallback( Mouse.eLClick, HandleColumnSort(History_SortByLastPlayed));

	Controls.CloseButton:RegisterCallback( Mouse.eLClick, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
		HandleExitRequest();
	end);
	
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );
	ContextPtr:SetPostInit(PostInit);	
end

Initialize();