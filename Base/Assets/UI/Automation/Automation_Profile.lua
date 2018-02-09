
local UNIQUE_ERAS = { "ERA_ANCIENT", "ERA_CLASSICAL", "ERA_INDUSTRIAL", "ERA_MODERN" };
local m_TestList = {};
local m_CurrentTestIndex = 1;

local m_CurrentEra = nil;
local m_CurrentCiv = nil;

function BuildTestList()
	m_TestList = {};
	for tCiv in GameInfo.Civilizations() do
		local strNameCiv = string.gsub( tCiv.CivilizationType, "CIVILIZATION_", "" );
		for _, strEra in ipairs(UNIQUE_ERAS) do
			local strNameEra = string.gsub( strEra, "ERA_", "" );
			table.insert(m_TestList, {
				civ = tCiv.Index,
				era = GameInfo.Eras[strEra].Index,
				zoom = 1,
				name = strNameCiv .. "_" .. strNameEra-- .. "_FAR",
			});
			--table.insert(m_TestList, {
			--	civ = tCiv.Index,
			--	era = GameInfo.Eras[strEra].Index,
			--	zoom = 0,
			--	name = strNameCiv .. "_" .. strNameEra .. "_NEAR",
			--});
		end
	end
	m_CurrentTestIndex = 1;
end

function FillMapWith( civIndex, eraIndex )
	if ( m_CurrentEra == eraIndex and m_CurrentCiv == eraIndex ) then
		return; -- No changes necessary!
	end
	AssetPreview.ClearLandmarkSystem();
	local maptype = Map.GetMapSize();
	local mapx = GameInfo.Maps[maptype].GridWidth;
	local mapy = GameInfo.Maps[maptype].GridHeight;
	for y = 0, mapy-1, 1 do
		for x = 0, mapx-1, 1 do
			local plot = Map.GetPlot(x, y);
			if ( not plot:IsImpassable() and not plot:IsWater() ) then
				AssetPreview.PlaceCityAt( x, y, civIndex, eraIndex, 22 );
			end
		end
	end
	m_CurrentEra = eraIndex;
	m_CurrentCiv = eraIndex;
end

function StartNextTest()
	if ( m_CurrentTestIndex <= #m_TestList ) then
		local test = m_TestList[m_CurrentTestIndex];
		print("==================== Starting Benchmark: " .. test.name .. " ====================\n");
		FillMapWith(test.civ, test.era);
		AutoProfiler.SetCameraZoom(test.zoom);
		AutoProfiler.Start(test.name);
		m_CurrentTestIndex = m_CurrentTestIndex + 1;
	end
end

function OnGameLoad()
	AutoProfiler.SetAutomated( true );
	-- This is a two-minute test.
	-- 2.5s should leave enough time for the framerate to settle, though I'd prefer 3s.
	-- The tradeoff is better map coverage vs more time to reach a steady-state framerate.
	AutoProfiler.SetNumLookAtPositions( 48 );
	AutoProfiler.SetLookAtLingerSeconds( 2.5 );
	AutoProfiler.SetCameraPanSpeed( 0 );
	AutoProfiler.SetAutoStartEnabled( true );
	AutoProfiler.RunCommand( "toggle vfx" );
	AutoProfiler.RunCommand( "toggle clutter" );

	
	BuildTestList();
	AssetPreview.ClearLandmarkSystem();
	AutoProfiler.Start("BASELINE_EMPTY_MAP");
end
LuaEvents.AutomationGameStarted.Add( OnGameLoad );

function OnFinished()
	StartNextTest();
end
LuaEvents.AutoProfilerBenchmarkFinished.Add( OnFinished );




