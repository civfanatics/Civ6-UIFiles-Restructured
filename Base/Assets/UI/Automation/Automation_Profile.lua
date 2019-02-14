
local UNIQUE_ERAS = { "ERA_ANCIENT", "ERA_CLASSICAL", "ERA_INDUSTRIAL", "ERA_MODERN" };
local SUMMARY_PATH_BASE = "C:\\Temp\\";
local TEST_SAVE_NAME = "./Empty Map.Civ6Save";

function SetSummaryFile( strFileName ) AutoProfiler.SetFilePath( SUMMARY_PATH_BASE .. strFileName ); end

function ResetView() AssetPreview.ClearLandmarkSystem(); AssetPreview.ClearUnitSystem(); end

function ForEachPassableLandHex( fnPerHex )
	local maptype = Map.GetMapSize();
	local mapx = GameInfo.Maps[maptype].GridWidth;
	local mapy = GameInfo.Maps[maptype].GridHeight;
	local nPlaced = 0;
	local nTotal = 0;
	for y = 0, mapy-1, 1 do
		for x = 0, mapx-1, 1 do
			local plot = Map.GetPlot(x, y);
			if ( not plot:IsImpassable() and not plot:IsWater() ) then
				fnPerHex( x, y );
				nPlaced = nPlaced + 1;
			end
			nTotal = nTotal + 1;
		end
	end
	return nPlaced / nTotal;
end
function ForEachHex( fnPerHex )
	local maptype = Map.GetMapSize();
	local mapx = GameInfo.Maps[maptype].GridWidth;
	local mapy = GameInfo.Maps[maptype].GridHeight;
	for y = 0, mapy-1, 1 do
		for x = 0, mapx-1, 1 do
			fnPerHex( x, y );
		end
	end
	return 1.0;
end

-- ////////////////////////////////////////////////////////////////////////////////
function City_BuildTestList( tTestList )
	table.insert( tTestList, { name = "EMPTY_MAP", prepare = function() AutoProfiler.AddColumn( "FillRatio" ); SetSummaryFile( "cities.csv" ); ResetView(); end; } );

	for tCiv in GameInfo.Civilizations() do
		local strNameCiv = string.sub( tCiv.CivilizationType, 14 ); -- remove "CIVILIZATION_"
		for _, strEra in ipairs(UNIQUE_ERAS) do
			local strNameEra = string.sub( strEra, 5 ); -- remove "ERA_"
			table.insert(tTestList, {
				prepare = function()
						ResetView();
						local fillratio = ForEachPassableLandHex( function(x, y) AssetPreview.SpoofCityAt( x, y, tCiv.Index, GameInfo.Eras[strEra].Index, 22 ); end );
						AutoProfiler.AddColumn( tostring( fillratio ) );
					end,
				name = strNameCiv .. "_" .. strNameEra
			});
		end
	end
end

-- ////////////////////////////////////////////////////////////////////////////////
function District_BuildTestList( tTestList )
	table.insert( tTestList, { name = "EMPTY_MAP", prepare = function() 
			AutoProfiler.AddColumn( "FillRatio" );
			AutoProfiler.AddColumn( "District" );
			AutoProfiler.AddColumn( "State" );
			SetSummaryFile( "districts.csv" );
			ResetView();
			end;
		} );
	
	local nDistricts = AssetPreview.GetDistrictCount();
	for idxDistrict = 0, nDistricts-1, 1 do
		local strDistrictName = string.sub( AssetPreview.GetDistrictName(idxDistrict), 10); -- remove "DISTRICT_"
		
		local PrepareTest = function( strState, props )
			ResetView();
			local fillratio = ForEachPassableLandHex( function(x, y) AssetPreview.SpoofDistrictBaseAt( x, y, props.civ, props.era, props.appeal, 0, strState, idxDistrict, props.index ); end );
			AutoProfiler.AddColumn( tostring( fillratio ) );
			AutoProfiler.AddColumn( strDistrictName );
			AutoProfiler.AddColumn( strState );
		end

		local tDistrictBases = AssetPreview.GetDistrictBaseList(idxDistrict);
		for name,props in pairs(tDistrictBases) do
			if ( not props.hasbldgs ) then -- Bases with buildings never show up in this state, we can save almost 200 tests by skipping it.
				table.insert(tTestList, { name = name, prepare = function() PrepareTest( "Construction", props ); end });
			end
			table.insert(tTestList, { name = name, prepare = function() PrepareTest( "Worked", props ); end });
			table.insert(tTestList, { name = name, prepare = function() PrepareTest( "Pillaged", props ); end });
		end
	end
end

-- ////////////////////////////////////////////////////////////////////////////////
function Building_BuildTestList( tTestList )
	table.insert( tTestList, { name = "EMPTY_MAP", prepare = function()
			AutoProfiler.AddColumn( "FillRatio" );
			AutoProfiler.AddColumn( "District" );
			AutoProfiler.AddColumn( "Building" );
			AutoProfiler.AddColumn( "State" );
			SetSummaryFile( "herobuildings.csv" ); 
			ResetView(); 
			end; 
		} );
	
	local nDistricts = AssetPreview.GetDistrictCount();
	local tBuildingSet = {};
	for idxDistrict = 0, nDistricts-1, 1 do
		local strDistrictName = string.sub( AssetPreview.GetDistrictName(idxDistrict), 10); -- remove "DISTRICT_"
	
		local PrepareTest = function( strState, props )
			ResetView();
			local fillratio = ForEachPassableLandHex(function(x, y) AssetPreview.SpoofBuildingAt( x, y, props.civ, props.era, props.appeal, strState, idxDistrict, props.bldg ); end);
			AutoProfiler.AddColumn( tostring( fillratio ) );
			AutoProfiler.AddColumn(strDistrictName);
			AutoProfiler.AddColumn(string.sub(props.bldgname, 10)); -- remove "BUILDING_"
			AutoProfiler.AddColumn(strState);
		end
		
		local tBuildings = AssetPreview.GetDistrictBuildingList(idxDistrict);
		for name,props in pairs(tBuildings) do
			if ( not tBuildingSet[name] ) then
				tBuildingSet[name] = true;
				table.insert(tTestList, { name = name, prepare = function() PrepareTest("Worked", props); end });
				table.insert(tTestList, { name = name, prepare = function() PrepareTest("Pillaged", props); end });
			end
		end
	end
end

-- ////////////////////////////////////////////////////////////////////////////////
function Landmark_BuildTestList( tTestList )
	table.insert( tTestList, { name = "EMPTY_MAP", prepare = function()
			AutoProfiler.AddColumn( "FillRatio" );
			AutoProfiler.AddColumn( "Landmark" );
			AutoProfiler.AddColumn( "Resource" );
			AutoProfiler.AddColumn( "State" );
			SetSummaryFile( "landmarks.csv" );
			ResetView();
			end;
		} );
	
	local nLandmarks = AssetPreview.GetLandmarkCount();
	for idxLandmark = 0, nLandmarks-1, 1 do
		local strLandmarkName = AssetPreview.GetLandmarkName(idxLandmark);
		
		local PrepareTest = function( strState, props, reshash, resname )
			ResetView();
			local fillratio = ForEachPassableLandHex( function(x, y) AssetPreview.SpoofLandmarkAt( x, y, props.civ, props.era, props.appeal, reshash, strState, idxLandmark, props.variant ); end );
			AutoProfiler.AddColumn( tostring( fillratio ) );
			AutoProfiler.AddColumn( strLandmarkName );
			AutoProfiler.AddColumn( string.gsub( resname, "RESOURCE_", "") );
			AutoProfiler.AddColumn( strState );
		end

		local tLandmarkAssets = AssetPreview.GetLandmarkAssetList(idxLandmark);
		for name,props in pairs(tLandmarkAssets) do
			for reshash,resname in pairs(props.resources) do
				table.insert(tTestList, { name = name, prepare = function() PrepareTest( "Worked", props, reshash, resname ); end });
				table.insert(tTestList, { name = name, prepare = function() PrepareTest( "Unworked", props, reshash, resname ); end });
				table.insert(tTestList, { name = name, prepare = function() PrepareTest( "Pillaged", props, reshash, resname ); end });
			end
		end
	end
end

-- ////////////////////////////////////////////////////////////////////////////////
function Unit_BuildTestList( tTestList )
	table.insert( tTestList, { name = "EMPTY_MAP", prepare = function() 
			AutoProfiler.AddColumn( "FillRatio" );
			AutoProfiler.AddColumn( "Unit" );
			AutoProfiler.AddColumn( "Culture" );
			SetSummaryFile( "units.csv" );
			ResetView();
			end;
		} );
	
	local tUnits = AssetPreview.GetUnitList();
	for strName,props in pairs(tUnits) do
		local strPrintableName = string.gsub( strName, "UNIT_", "" );
		
		local PrepareTest = function( strCulture, nCultureHash )
			ResetView();
			local fillratio = ForEachHex( function(x, y) AssetPreview.SpoofUnitAt( x, y, nCultureHash, props.hash); end );
			AutoProfiler.AddColumn( tostring( fillratio ) );
			AutoProfiler.AddColumn( strPrintableName );
			AutoProfiler.AddColumn( strCulture );
		end

		for strCultName,nCultHash in pairs(props.cultures) do
			table.insert(tTestList, { name = strName .. "_" .. strCultName, prepare = function() PrepareTest( strCultName, nCultHash ); end });
		end
	end
end



local m_TestList = {};
local m_CurrentTestIndex = 1;

function OnGameLoad()
	Automation.SetAutoStartEnabled( true );
	AutoProfiler.SetLookAtCount( 20 );
	AutoProfiler.SetLookAtFrames( 100 );
	AutoProfiler.SetCameraZoom( 1 );
	AutoProfiler.SetGPUStallThreshold( 1 );
	AutoProfiler.SetWaitForTerrain( false );
	AutoProfiler.RunCommand( "toggle vfx" );
	AutoProfiler.RunCommand( "toggle clutter" );
	AutoProfiler.RunCommand( "toggle terrain update" );
	AutoProfiler.RunCommand( "toggle ui" );
	
	print( "==================== Preparing tests ====================");
	local prev = 0;

	Unit_BuildTestList(m_TestList);
	print( "  - Added " .. tostring( #m_TestList - prev ) .. " Unit tests" );
	prev = #m_TestList;

	Landmark_BuildTestList(m_TestList);
	print( "  - Added " .. tostring( #m_TestList - prev ) .. " Landmark tests" );
	prev = #m_TestList;

	Building_BuildTestList(m_TestList);
	print( "  - Added " .. tostring( #m_TestList - prev ) .. " HeroBuilding tests" );
	prev = #m_TestList;

	District_BuildTestList(m_TestList);
	print( "  - Added " .. tostring( #m_TestList - prev ) .. " District tests" );
	prev = #m_TestList;

	City_BuildTestList(m_TestList);
	print( "  - Added " .. tostring( #m_TestList - prev ) .. " CitySet tests" );

	m_CurrentTestIndex = 1;
	print( "==================== Running " .. tostring( #m_TestList ) .. " tests ====================");
	OnBenchmarkFinished(); -- Start the first test! The others will follow.
end
LuaEvents.AutomationGameStarted.Add( OnGameLoad );

function OnBenchmarkFinished()
	-- Start next test, if there are any left
	if ( m_CurrentTestIndex <= #m_TestList ) then
		local test = m_TestList[m_CurrentTestIndex];
		m_CurrentTestIndex = m_CurrentTestIndex + 1;

		print("==================== Starting Benchmark: " .. test.name .. " ====================");
		test.prepare();
		AutoProfiler.SetTestName(test.name);
		AutoProfiler.Start();
	end
end
LuaEvents.AutoProfilerBenchmarkFinished.Add( OnBenchmarkFinished );

function OnMainMenu()
	Network.LoadGame(TEST_SAVE_NAME, ServerType.SERVER_TYPE_NONE);
	LuaEvents.AutomationMainMenuStarted.Remove( OnMainMenu );
end
LuaEvents.AutomationMainMenuStarted.Add( OnMainMenu );


