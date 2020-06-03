-- Requires InstanceManager
include("SupportFunctions");

---------------------------------------------------------------
-- Globals
----------------------------------------------------------------
g_GraphLegendInstanceManager = InstanceManager:new("GraphLegendInstance", "GraphLegend", Controls.GraphLegendStack);

g_InitialTurn = 0;
g_FinalTurn = 0;
g_GraphData = nil;
g_PlayerInfos = {};
g_PlayerDataSets = {};
g_GraphLegendsByPlayer = {};
g_PlayerGraphColors = {};

g_NumVerticalMarkers = 5;
g_NumHorizontalMarkers = 5;


-- This method will pad the horizontal values if they are too small so that they show up correctly
function ReplayGraphPadHorizontalValues(minTurn, maxTurn)
	local range = maxTurn - minTurn;
	local numHorizontalMarkers = g_NumHorizontalMarkers - 1;
	if(range < numHorizontalMarkers) then
		return (minTurn - (numHorizontalMarkers - range)), maxTurn;
	else
		return minTurn, maxTurn;
	end
end
		
function ReplayGraphDrawGraph()
				
	local graphWidth, graphHeight = Controls.ResultsGraph:GetSizeVal();
	local initialTurn = g_InitialTurn;
	local finalTurn = g_FinalTurn;
	local playerInfos = g_PlayerInfos;
	local graphData = g_GraphData;
		
	local function RefreshVerticalScales(minValue, maxValue)
		local increments = math.floor((maxValue - minValue) / (g_NumVerticalMarkers - 1));
		Controls.ResultsGraph:SetYTickInterval(increments / 4.0);
		Controls.ResultsGraph:SetYNumberInterval(increments);
	end
	
	function DrawGraph(data, pDataSet, minX, maxX)
		turnData = {};
		for i, value in pairs(data) do
			if(value ~= nil and i <= maxX and i >= minX) then
				turnData[i - minX] = value;
			end
		end
		
		pDataSet:Clear();
		for turn = minX, maxX + 1, 1 do
			local y = turnData[turn - minX];
			if (y == nil) then
				pDataSet:BreakLine();
			else
				pDataSet:AddVertex(turn, y);
			end
		end
	end
			
	-- Determine the maximum score for all players
	local maxScore = 0;
	local minScore = nil;

	-- Using pairs here because there may be intentional "holes" in the data.
	if(graphData) then
		for player, turnData in pairs(graphData) do
			-- Ignore barbarian data.
			local playerInfo = Players[player];
			if(playerInfo and not playerInfo:IsBarbarian()) then
				for turn, value in pairs(turnData) do
					if(value > maxScore) then
						maxScore = value;
					end

					if(minScore == nil or value < minScore) then
						minScore = value;
					end
				end
			end
		end
	end

	-- If the data is flat lined, set the range accordingly
	if(minScore == maxScore) then
		minScore = minScore - 10;
		maxScore = maxScore + 10;
	end
	
	Controls.ResultsGraph:DeleteAllDataSets();
	g_PlayerDataSets = {};

	if(minScore ~= nil) then	-- this usually means that there were no values for that dataset.
				
		Controls.NoGraphData:SetHide(true);

		-- Lower minScore by 10% of the range so that we can see the base line.
		minScore = minScore - math.ceil((maxScore - minScore) * 0.1);
				
		--We want a value that is nicely divisible by the number of vertical markers
		local numSegments = g_NumVerticalMarkers - 1;

		local range = maxScore - minScore;

		local newRange = range + numSegments - range % numSegments;		
								
		maxScore = newRange + minScore;
				
		local YScale = graphHeight / (maxScore - minScore);
				
		RefreshVerticalScales(minScore, maxScore);
				
		local minTurn, maxTurn = ReplayGraphPadHorizontalValues(initialTurn, finalTurn);

		Controls.ResultsGraph:SetDomain(minTurn, maxTurn);
		Controls.ResultsGraph:SetRange(minScore, maxScore);
		Controls.ResultsGraph:ShowXNumbers(true);
		Controls.ResultsGraph:ShowYNumbers(true);
			
		for i,v in ipairs(playerInfos) do
			local data = graphData[v.Id];
			if(data) then
				local graphLegend = g_GraphLegendsByPlayer[i];
				local isHidden = not graphLegend.ShowHide:IsChecked();
				local color = g_PlayerGraphColors[i];

				local pDataSet = Controls.ResultsGraph:CreateDataSet(v.Name);
				pDataSet:SetColor(color);
				pDataSet:SetWidth(2.0);
				pDataSet:SetVisible(not isHidden);

				DrawGraph(graphData[v.Id], pDataSet, minTurn, maxTurn);
				g_PlayerDataSets[i] = pDataSet;
			end
		end		
	else
		Controls.ResultsGraph:ShowXNumbers(false);
		Controls.ResultsGraph:ShowYNumbers(false);
		Controls.NoGraphData:SetHide(false);
	end
end
		
function ReplayGraphRefresh() 
		
	local graphWidth, graphHeight = Controls.ResultsGraph:GetSizeVal();
	local initialTurn = g_InitialTurn;
	local finalTurn = g_FinalTurn;
		
	local function RefreshHorizontalScales()
		local minTurn, maxTurn = ReplayGraphPadHorizontalValues(initialTurn, finalTurn);
		local turnIncrements = math.floor((maxTurn - minTurn) / (g_NumHorizontalMarkers - 1));
		Controls.ResultsGraph:SetXTickInterval(turnIncrements / 4.0);
		Controls.ResultsGraph:SetXNumberInterval(turnIncrements);
	end
			
	local function RefreshCivilizations()
			
		local colorDistances = {};
		local pow = math.pow;
		function ColorDistance(color1, color2)
			
			local distance = nil;
			local colorDistanceTable = colorDistances[color1];
			if(colorDistanceTable == nil) then
				colorDistanceTable = {
					[color1] = 0;	--We can assume the distance of a color to itself is 0.
				};
				
				colorDistances[color1] = colorDistanceTable
			end
			
			local distance = colorDistanceTable[color2];
			if(distance == nil) then
				local c1 = {UI.GetColorChannels(color1)};
				local c2 = {UI.GetColorChannels(color2)};

				local r2 = pow(c1[1] - c2[1], 2);
				local g2 = pow(c1[2] - c2[2], 2);
				local b2 = pow(c1[3] - c2[3], 2);	
				
				distance = r2 + g2 + b2;
				colorDistanceTable[color2] = distance;
			end
			
			return distance;
		end
				
		local colorNotUnique = {};
		local colorBlack = UI.GetColorValue("COLOR_BLACK");
		local function IsUniqueColor(color, unique_cache)
		
			if(unique_cache[color]) then
				return false;
			end
			
			local blackThreshold = 5000;
			local differenceThreshold = 3000;
					
			local distanceAgainstBlack = ColorDistance(color, colorBlack);
			if(distanceAgainstBlack > blackThreshold) then
				for i, v in pairs(g_PlayerGraphColors) do
					local distanceAgainstOtherPlayer = ColorDistance(color, v);
					if(distanceAgainstOtherPlayer < differenceThreshold) then
						-- Return false if the color is too close to a color that's already being used
						unique_cache[color] = true;
						return false;
					end
				end

				-- Return true if the color is far enough away from black and other colors being used
				unique_cache[color] = true;	
				return true;
			end
			
			-- Return false if color is too close to black
			unique_cache[color] = true;
			return false;
		end
					
		local function DetermineGraphColor(primaryColor, secondaryColor, unique_cache)

			if(IsUniqueColor(primaryColor, unique_cache)) then
				return primaryColor;
			elseif(IsUniqueColor(secondaryColor, unique_cache)) then
				return secondaryColor;
			else
				local colors = UI.GetColors();

				for i, color in ipairs(colors) do
					local value = color[2];

					local r,g,b,a = UI.GetColorChannels(value);

					if a == 255 then
						-- Ensure we only use unique and opaque colors
						if(IsUniqueColor(value, unique_cache)) then
							return color;
						end
					end
				end
			end
										
			return primaryColor;
		end

		local unique_color_cache = {};
		g_PlayerGraphColors = {};
		g_GraphLegendInstanceManager:ResetInstances();
		for i, player in ipairs(g_PlayerInfos) do
					
			local civ = GameInfo.Civilizations[player.Civilization];
					
			local graphLegendInstance = g_GraphLegendInstanceManager:GetInstance();
					
			--IconHookup( civ.PortraitIndex, 32, civ.IconAtlas, graphLegendInstance.LegendIcon );
			local color = DetermineGraphColor(player.PrimaryColor, player.SecondaryColor, unique_color_cache);
			g_PlayerGraphColors[i] = color;
		
			graphLegendInstance.LegendIcon:SetColor(color);
							
			if(player.Name ~= nil) then
				TruncateStringWithTooltip(graphLegendInstance.LegendName, graphLegendInstance.GraphLegend:GetSizeX() - 52, Locale.Lookup(player.Name));
			end	
					
			-- Default city states to be unchecked.
			local checked = not player.IsMinor;
				
			graphLegendInstance.ShowHide:SetCheck(checked);
					
			graphLegendInstance.ShowHide:RegisterCheckHandler( function(bCheck)
				local pDataSet = g_PlayerDataSets[i];
				if(pDataSet) then
					pDataSet:SetVisible(bCheck);
				end
			end);
			
			g_GraphLegendsByPlayer[i] = graphLegendInstance;
		end
	end
			
	RefreshCivilizations();
	RefreshHorizontalScales();
			
	Controls.GraphLegendStack:CalculateSize();
	Controls.GraphLegendStack:ReprocessAnchoring();
	Controls.GraphLegendScrollPanel:CalculateInternalSize();

end

function SetCurrentGraphDataSet(dataSetType)
	local initialTurn = g_InitialTurn;
	local finalTurn = g_FinalTurn;
	local dataSetIndex;
	local count = GameSummary.GetDataSetCount();
	for i = 0, count - 1, 1 do
		local name = GameSummary.GetDataSetName(i);
		if(name == dataSetType) then
			dataSetIndex = i;
			dataSetDisplayName = GameSummary.GetDataSetDisplayName(i);
			break;
		end
	end
	
	if(dataSetIndex) then
		local graphDataSetPulldownButton = Controls.GraphDataSetPulldown:GetButton();
		graphDataSetPulldownButton:LocalizeAndSetText(dataSetDisplayName);

		g_GraphData = GameSummary.CoalesceDataSet(dataSetIndex, initialTurn, finalTurn);
		
		--Debug Data, for when you wanna debug.
		--g_GraphData = {
			--[0] = {1,2,3,4,5,6,7,8,9,10},
			--[1] = {10,9,8,7,6,5,4,2,1},
			--[2] = {1,2,3,4,5,6,7,8,9,10},
			--[3] = {1,2,3,4,5,6,7,8,9,10},
			--[4] = {1,2,3,4,5,6,7,8,9,10},
			--[5] = {1,2,3,4,5,6,7,8,9,10},
		--};
		
		ReplayGraphDrawGraph();
	end	
end

----------------------------------------------------------------
-- Static Initialization
----------------------------------------------------------------
local function RefreshGraphDataSets()		
	local graphDataSetPulldown = Controls.GraphDataSetPulldown;
	graphDataSetPulldown:ClearEntries();
	
	local count = GameSummary.GetDataSetCount();
	local dataSets = {};
	for i = 0, count - 1, 1 do
		if(GameSummary.GetDataSetVisible(i) and GameSummary.HasDataSetValues(i)) then
			local name = GameSummary.GetDataSetName(i);
			local displayName = GameSummary.GetDataSetDisplayName(i);
			table.insert(dataSets, {i, name, Locale.Lookup(displayName)});
		end
	end
	table.sort(dataSets, function(a,b) return Locale.Compare(a[3], b[3]) == -1; end);
	
	for i,v in ipairs(dataSets) do
		local controlTable = {};
		graphDataSetPulldown:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText(v[3]);

		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			SetCurrentGraphDataSet(v[2]);
		end);
	end
	graphDataSetPulldown:CalculateInternals();

	if(#dataSets > 0) then
		SetCurrentGraphDataSet(dataSets[1][2]);
	end
end

function ReplayInitialize()
	g_InitialTurn = GameConfiguration.GetStartTurn();
	g_FinalTurn = Game.GetCurrentGameTurn();
	
	-- Populate Player Info
	g_PlayerInfos = {};	

	for player_num = 0, 63 do -- GameDefines.MAX_CIV_PLAYERS - 1 do
		local player = Players[player_num];
		local playerConfig = PlayerConfigurations[player_num];
		if(player and playerConfig and playerConfig:IsParticipant() and player:WasEverAlive() and not player:IsBarbarian() and not player:IsFreeCities()) then

			local primary, secondary = UI.GetPlayerColors(player:GetID());
		
			local playerInfo = {
				Id = player:GetID(),
				PrimaryColor = primary,
				SecondaryColor = secondary,
				Name = playerConfig:GetPlayerName(),
				Civilization = playerConfig:GetCivilizationTypeName(),
				IsMinor = not player:IsMajor(),
			};
					
			table.insert(g_PlayerInfos, playerInfo);
		end	
	end

	ReplayGraphRefresh();
	RefreshGraphDataSets();
end

function ReplayShutdown()
	g_GraphData = nil;
	g_PlayerInfos = {};
	g_PlayerDataSets = {};
	g_GraphLegendsByPlayer = {};
	g_PlayerGraphColors = {};

	g_GraphLegendInstanceManager:ResetInstances();
	Controls.ResultsGraph:DeleteAllDataSets();
end