-- ===========================================================================
--	TechTree Replacement
--	Civilization VI, Firaxis Games
-- ===========================================================================
include("TechTree_Expansion1");

-- ===========================================================================
--	Add to base tables
-- ===========================================================================
local BASE_GetCurrentData = GetCurrentData;


-- Add to item status table. Instead of enum use hash of "UNREVEALED"; special case.
ITEM_STATUS["UNREVEALED"] = 0xB87BE593;
STATUS_ART[ITEM_STATUS.UNREVEALED]	= { Name="UNREVEALED",	TextColor0=UI.GetColorValueFromHexLiteral(0xff202726), TextColor1=UI.GetColorValueFromHexLiteral(0x00000000), FillTexture="TechTree_GearButtonTile_Disabled.dds",BGU=0,BGV=(SIZE_NODE_Y*3),	IsButton=false,	BoltOn=false,	IconBacking=PIC_METER_BACK  };
															

-- ===========================================================================
--	Complete override
-- ===========================================================================
function PopulateItemData() -- Note that we are overriding this function without calling its base version. This version requires no parameters.
	
	local kItemDefaults :table = {};		-- Table to return
	
	function GetHash(t)
		local r = GameInfo.Types[t];
		if(r) then
			return r.Hash;
		else
			return 0;
		end
	end

	local techNodes:table = Game.GetTechs():GetActiveTechNodes();
	for _,techNode in ipairs(techNodes) do

		local row:table		= GameInfo.Technologies[techNode.TechType];

		local kEntry:table	= {};
		kEntry.Type			= row.TechnologyType;
		kEntry.Name			= row.Name;
		kEntry.BoostText	= "";
		kEntry.Column		= -1;
		kEntry.Cost			= techNode.Cost;
		kEntry.Description	= row.Description and Locale.Lookup( row.Description );
		kEntry.EraType		= row.EraType;
		kEntry.Hash			= GetHash(kEntry.Type);
		kEntry.Index		= row.Index;
		kEntry.IsBoostable	= false;
		kEntry.Prereqs		= {};				-- IDs for prerequisite item(s)
		kEntry.UITreeRow	= row.UITreeRow;		
		kEntry.Unlocks		= {};				-- Each unlock has: unlockType, iconUnavail, iconAvail, tooltip

		-- Boost?
		for boostRow in GameInfo.Boosts() do
			if boostRow.TechnologyType == kEntry.Type then				
				kEntry.BoostText = Locale.Lookup( boostRow.TriggerDescription );
				kEntry.IsBoostable = true;
				kEntry.BoostAmount = boostRow.Boost;
				break;
			end
		end

		if (table.count(techNode.PrereqTechTypes) > 0) then
			for __,prereqTechType in ipairs(techNode.PrereqTechTypes) do
				local prereqRow:table = GameInfo.Technologies[prereqTechType];
				table.insert( kEntry.Prereqs, prereqRow.TechnologyType );
			end
		end
		-- If no prereqs were found, set item to special tree start value
		if table.count(kEntry.Prereqs) == 0 then
			table.insert(kEntry.Prereqs, PREREQ_ID_TREE_START);
		end

		-- Warn if DB has an out of bounds entry.
		if kEntry.UITreeRow < ROW_MIN or kEntry.UITreeRow > ROW_MAX then
			UI.DataError("UITreeRow for '"..kEntry.Type.."' has an out of bound UITreeRow="..tostring(kEntry.UITreeRow).."  MIN="..tostring(ROW_MIN).."  MAX="..tostring(ROW_MAX));
		end

		AddTechToEra( kEntry );

		-- Save entry into master list.
		kItemDefaults[kEntry.Type] = kEntry;
	end

	return kItemDefaults;
end

-- ===========================================================================
--	Fill out live data from base game and then add IsRevealed to items.
-- ===========================================================================
function GetCurrentData( ePlayer:number, eCompletedTech:number )
	local kData:table = BASE_GetCurrentData(ePlayer, eCompletedTech );

	-- Loop through all items and add an IsRevealed field.
	local playerTechs:table = Players[ePlayer]:GetTechs();
	if (playerTechs ~= nil) then
		for type,item in pairs(g_kItemDefaults) do
			kData[DATA_FIELD_LIVEDATA][type]["IsRevealed"] = playerTechs:IsTechRevealed(item.Index);
		end
	end
	return kData;
end

-- ===========================================================================
--	Complete override
--	Hide node content which is not revealed (has not been discovered)
-- ===========================================================================
function PopulateNode(uiNode, playerTechData)
	local item		:table = g_kItemDefaults[uiNode.Type];						-- static item data
	local live		:table = playerTechData[DATA_FIELD_LIVEDATA][uiNode.Type];	-- live (changing) data
	local status	:number = live.IsRevealed and live.Status or ITEM_STATUS.UNREVEALED;
	local artInfo	:table = STATUS_ART[status];							-- art/styles for this state

	if(status == ITEM_STATUS.RESEARCHED) then
		for _,prereqId in pairs(item.Prereqs) do
			if(prereqId ~= PREREQ_ID_TREE_START) then
				local prereq		:table = g_kItemDefaults[prereqId];
				local previousRow	:number = prereq.UITreeRow;
				local previousColumn:number = g_kEras[prereq.EraType].PriorColumns;

				for lineNum,line in pairs(g_uiConnectorSets[item.Type..","..prereqId]) do
					if(lineNum == 1 or lineNum == 5) then
						line:SetTexture("Controls_TreePathEW");
					end
					if( lineNum == 3) then
						line:SetTexture("Controls_TreePathNS");
					end

					if(lineNum == 2)then
						if previousRow < item.UITreeRow  then
							line:SetTexture("Controls_TreePathSE");
						else
							line:SetTexture("Controls_TreePathNE");
						end
					end

					if(lineNum == 4)then
						if previousRow < item.UITreeRow  then
							line:SetTexture("Controls_TreePathES");
						else
							line:SetTexture("Controls_TreePathEN");
						end
					end
				end
			end
		end
	end

	uiNode.NodeName:SetColor( artInfo.TextColor0, 0 );
	uiNode.NodeName:SetColor( artInfo.TextColor1, 1 );
		
	uiNode.UnlockStack:SetHide( status==ITEM_STATUS.UNREVEALED );	-- Show/hide unlockables based on revealed status.

	local nodeName :string = (status==ITEM_STATUS.UNREVEALED) and Locale.Lookup("LOC_TECH_TREE_UNREVEALED_TECH") or Locale.Lookup(item.Name);
	if debugShowIDWithName then
		uiNode.NodeName:SetText( tostring(item.Index).."  ".. nodeName);	-- Debug output
	else
		uiNode.NodeName:SetText( Locale.ToUpper( nodeName ));				-- Normal output
	end

	if live.Turns > 0 then 
		uiNode.Turns:SetHide( false );
		uiNode.Turns:SetColor( artInfo.TextColor0, 0 );
		uiNode.Turns:SetColor( artInfo.TextColor1, 1 );
		uiNode.Turns:SetText( Locale.Lookup("LOC_TECH_TREE_TURNS",live.Turns) );
	else
		uiNode.Turns:SetHide( true );
	end

	if item.IsBoostable and status ~= ITEM_STATUS.RESEARCHED and status ~= ITEM_STATUS.UNREVEALED then			
		uiNode.BoostIcon:SetHide( false );
		uiNode.BoostText:SetHide( false );
		uiNode.BoostText:SetColor( artInfo.TextColor0, 0 );
		uiNode.BoostText:SetColor( artInfo.TextColor1, 1 );

		local boostText:string;
		if live.IsBoosted then
			boostText = TXT_BOOSTED.." "..item.BoostText;
			uiNode.BoostIcon:SetTexture( PIC_BOOST_ON );
			uiNode.BoostMeter:SetHide( true );
			uiNode.BoostedBack:SetHide( false );
		else
			boostText = TXT_TO_BOOST.." "..item.BoostText;
			uiNode.BoostedBack:SetHide( true );
			uiNode.BoostIcon:SetTexture( PIC_BOOST_OFF );
			uiNode.BoostMeter:SetHide( false );
			local boostAmount = (item.BoostAmount*.01) + (live.Progress/ live.Cost);
			uiNode.BoostMeter:SetPercent( boostAmount );
		end
		TruncateStringWithTooltip(uiNode.BoostText, MAX_BEFORE_TRUNC_TO_BOOST, boostText); 
	else
		uiNode.BoostIcon:SetHide( true );
		uiNode.BoostText:SetHide( true );
		uiNode.BoostedBack:SetHide( true );
		uiNode.BoostMeter:SetHide( true );
	end
	
	if status == ITEM_STATUS.CURRENT then
		uiNode.GearAnim:SetHide( false );
	else 
		uiNode.GearAnim:SetHide( true );
	end

	if live.Progress > 0 then
		uiNode.ProgressMeter:SetHide( false );			
		uiNode.ProgressMeter:SetPercent(live.Progress / live.Cost);
	else
		uiNode.ProgressMeter:SetHide( true );			
	end

	-- Show/Hide Recommended Icon
	if live.IsRecommended and live.AdvisorType ~= nil then
		uiNode.RecommendedIcon:SetIcon(live.AdvisorType);
		uiNode.RecommendedIcon:SetHide(false);
	else
		uiNode.RecommendedIcon:SetHide(true);
	end

	-- Set art and tool tip for icon area
	if status == ITEM_STATUS.UNREVEALED then
		uiNode.NodeButton:SetToolTipString(Locale.Lookup("LOC_TECH_TREE_UNREVEALED_TOOLTIP"));	
		uiNode.Icon:SetIcon("ICON_TECH_UNREVEALED");
		uiNode.IconBacking:SetHide(true);
		uiNode.BoostMeter:SetColor(UI.GetColorValueFromHexLiteral(0x66ffffff));
		uiNode.BoostIcon:SetColor(UI.GetColorValueFromHexLiteral(0x66000000));
	else
		
		uiNode.NodeButton:SetToolTipString(ToolTipHelper.GetToolTip(item.Type, Game.GetLocalPlayer()));

		if(uiNode.Type ~= nil) then
			local iconName :string = DATA_ICON_PREFIX .. uiNode.Type;
			if (artInfo.Name == "BLOCKED") then
				uiNode.IconBacking:SetHide(true);
				iconName = iconName .. "_FOW";
				uiNode.BoostMeter:SetColor(UI.GetColorValueFromHexLiteral(0x66ffffff));
				uiNode.BoostIcon:SetColor(UI.GetColorValueFromHexLiteral(0x66000000));
			else
				uiNode.IconBacking:SetHide(false);
				iconName = iconName;
				uiNode.BoostMeter:SetColor(UI.GetColorValue("COLOR_WHITE"));
				uiNode.BoostIcon:SetColor(UI.GetColorValue("COLOR_WHITE"));
			end
			local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName, 42);	
			if (textureOffsetX ~= nil) then
				uiNode.Icon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
			end
		end
	end
	
	if artInfo.IsButton then
		uiNode.OtherStates:SetHide( true );
		uiNode.NodeButton:SetTextureOffsetVal( artInfo.BGU, artInfo.BGV );
	else
		uiNode.OtherStates:SetHide( false );
		uiNode.OtherStates:SetTextureOffsetVal( artInfo.BGU, artInfo.BGV );
	end

	if artInfo.FillTexture ~= nil then
		uiNode.FillTexture:SetHide( false );
		uiNode.FillTexture:SetTexture( artInfo.FillTexture );
	else
		uiNode.FillTexture:SetHide( true );
	end

	if artInfo.BoltOn then
		uiNode.Bolt:SetTexture(PIC_BOLT_ON);
	else
		uiNode.Bolt:SetTexture(PIC_BOLT_OFF);
	end

	uiNode.IconBacking:SetTexture(artInfo.IconBacking);

	-- Darken items not making it past filter.
	local currentFilter:table = playerTechData[DATA_FIELD_UIOPTIONS].filter;
	if currentFilter == nil or currentFilter.Func == nil or currentFilter.Func( item.Type ) then
		uiNode.FilteredOut:SetHide( true );
	else
		uiNode.FilteredOut:SetHide( false );
	end

	-- Civilopedia: Only show if revealed tech; only wire up handlers if not in an on-rails tutorial.
	function OpenPedia()		
		if live.IsRevealed then
			LuaEvents.OpenCivilopedia(uiNode.Type); 
		end
	end	
	if IsTutorialRunning()==false then
		uiNode.NodeButton:RegisterCallback( Mouse.eRClick, OpenPedia);
		uiNode.OtherStates:RegisterCallback( Mouse.eRClick,OpenPedia);
	end

	UpdateAllianceIcon(uiNode);
end

-- ===========================================================================
--	Can a tech be searched; true if revealed.
-- ===========================================================================
function IsSearchable(techType)
	local kData:table = GetLiveData();
	return kData[techType]["IsRevealed"];
end
