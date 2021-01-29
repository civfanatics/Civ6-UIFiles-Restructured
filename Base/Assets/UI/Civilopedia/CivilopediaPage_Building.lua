-- ===========================================================================
--	Civilopedia - Building Page Layout
-- ===========================================================================

PageLayouts["Building" ] = function(page)
local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local building = GameInfo.Buildings[pageId];
	if(building == nil) then
		return;
	end

	local buildingType = building.BuildingType;

	local isWonder = building.MaxWorldInstances ~= -1;

	-- Index city-states
	-- City states are always referenced by their civilization type and not leader type
	-- despite game data referencing it that way.
	local city_state_civilizations = {};
	local city_state_leaders = {};
	for row in GameInfo.Civilizations() do
		if(row.StartingCivilizationLevelType == "CIVILIZATION_LEVEL_CITY_STATE") then
			city_state_civilizations[row.CivilizationType] = true;
		end
	end

	for row in GameInfo.CivilizationLeaders() do
		if(city_state_civilizations[row.CivilizationType]) then
			city_state_leaders[row.LeaderType] = row.CivilizationType;
		end
	end

	local unique_to = {};
	if(building.TraitType) then
		local traitType = building.TraitType;
		for row in GameInfo.LeaderTraits() do
			if(row.TraitType == traitType) then
				local leader = GameInfo.Leaders[row.LeaderType];
				if(leader) then
					-- If this is a city state, use the civilization type.
					local city_state_civilization = city_state_leaders[row.LeaderType];
					if(city_state_civilization) then
						local civ = GameInfo.Civilizations[city_state_civilization];
						if(civ) then
							table.insert(unique_to, {"ICON_" .. civ.CivilizationType, civ.Name, civ.CivilizationType});
						end
					else
						table.insert(unique_to, {"ICON_" .. row.LeaderType, leader.Name, row.LeaderType});
					end
				end
			end
		end

		for row in GameInfo.CivilizationTraits() do
			if(row.TraitType == traitType) then
				local civ = GameInfo.Civilizations[row.CivilizationType];
				if(civ) then
					table.insert(unique_to, {"ICON_" .. row.CivilizationType, civ.Name, row.CivilizationType});
				end
			end
		end
	end

	local replaces;			-- building this one replaces.
	local replaced_by = {};	-- buildings replaced by this building.
	for row in GameInfo.BuildingReplaces() do
		if(row.CivUniqueBuildingType == buildingType) then
			local b = GameInfo.Buildings[row.ReplacesBuildingType];
			if(b) then
				replaces = b;
			end
		end
		
		if(row.ReplacesBuildingType == buildingType) then
			local b = GameInfo.Buildings[row.CivUniqueBuildingType];
			if(b) then
				table.insert(replaced_by, b);
			end
		end
	end

	local obsolete_era;
	if(building.ObsoleteEra and building.ObsoleteEra ~= "NO_ERA") then
		obsolete_era = GameInfo.Eras[building.ObsoleteEra];
	end

	local prereq_buildings = {};
	for row in GameInfo.BuildingPrereqs() do
		if(row.Building == buildingType) then
			local b = GameInfo.Buildings[row.PrereqBuilding];
			table.insert(prereq_buildings, b);
		end
	end

	-- Building is only enabled via an "Add Religious Building" modifier.
	local beliefs = {};
	if(building.EnabledByReligion) then
		
		-- Reverse Lookup to determine.
		-- Because of the nature of modifiers and requirements, this may not be entirely accurate.
		local modifiers = {};
	
		-- Generate list of possible modifiers to look out for.
		for row in GameInfo.DynamicModifiers() do
			if(row.EffectType == "EFFECT_ADD_RELIGIOUS_BUILDING") then
				for modifier in GameInfo.Modifiers() do
					if(modifier.ModifierType == row.ModifierType) then
						modifiers[modifier.ModifierId] =  true;
					end
				end
			end
		end
		
		-- Cross reference with modifier arguments to see if this is a modifier that we care about and affects our building.
		local valid_modifiers = {};
		for row in GameInfo.ModifierArguments() do
			if(row.Value == buildingType and modifiers[row.ModifierId] and row.Name == "BuildingType") then
				valid_modifiers[row.ModifierId] = true;
			end
		end
		
		-- Cross reference with known things that may contain the modifier.
		-- For now, EnabledByReligion implies only checking beliefs, but this may be abstracted in a future patch.
		for row in GameInfo.BeliefModifiers() do
			if(valid_modifiers[row.ModifierID]) then
				local belief = GameInfo.Beliefs[row.BeliefType];
				if(belief) then
					table.insert(unique_to, {"ICON_" .. belief.BeliefType, belief.Name, belief.BeliefType});
				end
			end
		end
	end


	-- adjacency requirements
	local adjacency_requirements = {};
	if(building.RequiresRiver or GameInfo.RequiresAdjacentRiver) then
		table.insert(adjacency_requirements, Locale.Lookup("LOC_UI_PEDIA_PLACEMENT_REQUIRES_ADJACENT_RIVER"));
	end

	if(building.AdjacentToMountain) then
		table.insert(adjacency_requirements, Locale.Lookup("LOC_UI_PEDIA_PLACEMENT_REQUIRES_ADJACENT_MOUNTAIN"));
	end
	table.sort(adjacency_requirements, function(a,b) return Locale.Compare(a,b) == -1 end);

	-- Exclusivity
	local exclusive_with = {};
	for row in GameInfo.MutuallyExclusiveBuildings() do
		if(row.Building == buildingType) then
			local exBuilding = GameInfo.Buildings[row.MutuallyExclusiveBuilding];
			table.insert(exclusive_with, exBuilding);
		end
	end

	-- placement requirements
	local placement_requirements = {};
	for row in GameInfo.Building_RequiredFeatures() do
		if(row.BuildingType == buildingType) then
			local feature = GameInfo.Features[row.FeatureType];
			if(feature ~= nil) then
				table.insert(placement_requirements, {Locale.Lookup(feature.Name), feature.FeatureType});
			end
		end
	end

	for row in GameInfo.Building_ValidFeatures() do
		if(row.BuildingType == buildingType) then
			local feature = GameInfo.Features[row.FeatureType];
			if(feature ~= nil) then
				table.insert(placement_requirements, {Locale.Lookup(feature.Name), feature.FeatureType});
			end
		end
	end

	for row in GameInfo.Building_ValidTerrains() do
		if(row.BuildingType == buildingType) then
			local terrain = GameInfo.Terrains[row.TerrainType];
			if(terrain ~= nil) then
				-- Do not list coast as a requirement if we're going to list it further down anyways.
				if(terrain.TerrainType ~= "TERRAIN_COAST" or not(building.Coast or building.MustBeAdjacentLand)) then
					table.insert(placement_requirements, {Locale.Lookup(terrain.Name), terrain.TerrainType});
				end
			end
		end
	end
	table.sort(placement_requirements, function(a,b) return Locale.Compare(a[1],b[1]) == -1 end);

	local additional_placement_requirements = {};
	if(building.MustBeLake) then
		table.insert(additional_placement_requirements, Locale.Lookup("LOC_UI_PEDIA_PLACEMENT_REQUIRES_LAKE"));
	end

	if(building.MustNotBeLake) then
		table.insert(additional_placement_requirements, Locale.Lookup("LOC_UI_PEDIA_PLACEMENT_REQUIRES_NOT_LAKE"));
	end

	if(building.Coast or building.MustBeAdjacentLand) then
		table.insert(additional_placement_requirements, Locale.Lookup("LOC_UI_PEDIA_PLACEMENT_REQUIRES_COAST"));
	end
	
	table.sort(additional_placement_requirements, function(a,b) return Locale.Compare(a,b) == -1 end);

	for i,v in ipairs(additional_placement_requirements) do
		table.insert(placement_requirements, v);
	end

	local stats = {};

	for row in GameInfo.Building_YieldChanges() do
		if(row.BuildingType == buildingType) then
			local yield = GameInfo.Yields[row.YieldType];
			if(yield) then
				table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_YIELD", row.YieldChange, yield.IconString, yield.Name)); 
			end
		end
	end

	for row in GameInfo.Building_YieldDistrictCopies() do
		if(row.BuildingType == buildingType) then
			local from = GameInfo.Yields[row.OldYieldType];
			local to = GameInfo.Yields[row.NewYieldType];

			table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_BUILDING_DISTRICT_COPY", to.IconString, to.Name, from.IconString, from.Name));
		end
	end

	local housing = building.Housing or 0;
	if(housing ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_HOUSING", housing));
	end

	local entertainment = building.Entertainment or 0;
	if(entertainment ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_AMENITY_ENTERTAINMENT", entertainment));
	end

	local citizens = building.CitizenSlots or 0;
	if(citizens ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_CITIZENS", citizens));
	end

	local defense = building.OuterDefenseHitPoints or 0;
	if(defense ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_OUTER_DEFENSE", defense));
	end
	
	for row in GameInfo.Building_GreatPersonPoints() do
		if(row.BuildingType == buildingType) then
			local gpClass = GameInfo.GreatPersonClasses[row.GreatPersonClassType];
			if(gpClass) then
				local greatPersonClassName = gpClass.Name;
				local greatPersonClassIconString = gpClass.IconString;
				table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_GREAT_PERSON_POINTS", row.PointsPerTurn, greatPersonClassIconString, greatPersonClassName));
			end
		end
	end
	
	local citizen_yields = {};
	for row in GameInfo.Building_CitizenYieldChanges() do
		if(row.BuildingType == buildingType) then
			local yield = GameInfo.Yields[row.YieldType];
			if(yield) then
				table.insert(citizen_yields, "[ICON_Bullet] " .. Locale.Lookup("LOC_TYPE_TRAIT_YIELD", row.YieldChange, yield.IconString, yield.Name));
			end
		end
	end

	local cost = tonumber(building.Cost);
	local maintenance = tonumber(building.Maintenance);
	local purchase_cost;
	if(building.PurchaseYield) then
		if(building.PurchaseYield == "YIELD_GOLD") then
			purchase_cost = cost * GlobalParameters.GOLD_PURCHASE_MULTIPLIER * GlobalParameters.GOLD_EQUIVALENT_OTHER_YIELDS;
		else
			purchase_cost = cost *  GlobalParameters.GOLD_EQUIVALENT_OTHER_YIELDS
		end
	end
	
	-- TODO: Migrate these strings to GreatWorkSlotTypes in the database.
	local slotStrings = {
		["GREATWORKSLOT_ART"] = "LOC_TYPE_TRAIT_GREAT_WORKS_ART_SLOTS";
		["GREATWORKSLOT_WRITING"] = "LOC_TYPE_TRAIT_GREAT_WORKS_WRITING_SLOTS";
		["GREATWORKSLOT_MUSIC"] = "LOC_TYPE_TRAIT_GREAT_WORKS_MUSIC_SLOTS";
		["GREATWORKSLOT_RELIC"] = "LOC_TYPE_TRAIT_GREAT_WORKS_RELIC_SLOTS";
		["GREATWORKSLOT_ARTIFACT"] = "LOC_TYPE_TRAIT_GREAT_WORKS_ARTIFACT_SLOTS";
		["GREATWORKSLOT_CATHEDRAL"] = "LOC_TYPE_TRAIT_GREAT_WORKS_CATHEDRAL_SLOTS";
		["GREATWORKSLOT_PALACE"] = "LOC_TYPE_TRAIT_GREAT_WORKS_PALACE_SLOTS";
		["GREATWORKSLOT_PRODUCT"] = "LOC_TYPE_TRAIT_GREAT_WORKS_PRODUCT_SLOTS";
	};

	for row in GameInfo.Building_GreatWorks() do
		if(row.BuildingType == buildingType) then
			local slotType = row.GreatWorkSlotType;
			local key = slotStrings[slotType];
			if(key) then
				table.insert(stats, Locale.Lookup(key, row.NumSlots));
			end
		end
	end

	-- Right Column
	AddPortrait("ICON_" .. buildingType);

	AddQuote(building.Quote, building.QuoteAudio);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();

		if(#unique_to > 0) then
			s:AddHeader("LOC_UI_PEDIA_UNIQUE_TO");
			for _, icon in ipairs(unique_to) do
				s:AddIconLabel(icon, icon[2]);
			end

			s:AddSeparator();
		end

		if(replaces or #replaced_by > 0) then
			if(replaces) then
				s:AddHeader("LOC_UI_PEDIA_REPLACES");
				s:AddIconLabel({"ICON_" .. replaces.BuildingType, replaces.Name, replaces.BuildingType}, replaces.Name);
			end

			if(#replaced_by > 0) then
				s:AddHeader("LOC_UI_PEDIA_REPLACED_BY");
				for _, item in ipairs(replaced_by) do
					s:AddIconLabel({"ICON_" .. item.BuildingType, item.Name, item.BuildingType}, item.Name);
				end
			end
			s:AddSeparator();
		end

		if(obsolete_era) then
			if(isWonder) then
				s:AddHeader("LOC_UI_PEDIA_MADE_REMOVED_IF");
			else
				s:AddHeader("LOC_UI_PEDIA_MADE_OBSOLETE_BY");
			end

			s:AddLabel(obsolete_era.Name);
			s:AddSeparator();
		end

		if(#stats > 0) then
			for _, v in ipairs(stats) do
				s:AddLabel(v);
			end
			s:AddSeparator();
		end
		
		if(#citizen_yields > 0) then
			s:AddHeader("LOC_UI_PEDIA_CITIZEN_YIELDS");
			for i,v in ipairs(citizen_yields) do
				s:AddLabel(v);
			end
			s:AddSeparator();
		end
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(building.PrereqTech or building.PrereqCivic or building.PrereqDistrict or #prereq_buildings > 0) then
			
			if(building.PrereqDistrict ~= nil) then
				local district = GameInfo.Districts[building.PrereqDistrict];
				if(district) then
					s:AddHeader("LOC_DISTRICT_NAME");
					s:AddIconLabel({"ICON_" .. district.DistrictType, district.Name, district.DistrictType}, district.Name);
				end
			end

			if(building.PrereqCivic ~= nil) then
				local civic = GameInfo.Civics[building.PrereqCivic];
				if(civic) then
					s:AddHeader("LOC_CIVIC_NAME");
					s:AddIconLabel({"ICON_" .. civic.CivicType, civic.Name, civic.CivicType}, civic.Name);
				end
			end

			if(building.PrereqTech ~= nil) then
				local technology = GameInfo.Technologies[building.PrereqTech];
				if(technology) then
					s:AddHeader("LOC_TECHNOLOGY_NAME");
					s:AddIconLabel({"ICON_" .. technology.TechnologyType, technology.Name, technology.TechnologyType}, technology.Name);
				end
			end

			if(#prereq_buildings > 1) then
				s:AddHeader("LOC_UI_PEDIA_REQUIRED_BUILDINGS_OR");
			elseif(#prereq_buildings == 1) then
				s:AddHeader("LOC_BUILDING_NAME");
			end

			for i,v in ipairs(prereq_buildings) do
				s:AddIconLabel({"ICON_" .. v.BuildingType, v.Name, v.BuildingType}, v.Name);	
			end
			
			s:AddSeparator();
		end

		if(building.RequiresReligion) then
			s:AddLabel("LOC_UI_PEDIA_REQUIRES_FOUND_RELIGION");
			s:AddSeparator();
		end

		if(#exclusive_with > 0) then
			s:AddHeader("LOC_UI_PEDIA_EXCLUSIVE_WITH");
			for i,v in ipairs(exclusive_with) do
				s:AddIconLabel({"ICON_" .. v.BuildingType, v.Name, v.BuildingType}, v.Name);
			end
			s:AddSeparator();
		end

		if(building.AdjacentDistrict or building.AdjacentImprovement or building.AdjacentResource or #adjacency_requirements > 0) then
			s:AddHeader("LOC_UI_PEDIA_ADJACENCY");
			
			if(building.AdjacentDistrict) then
				local d = GameInfo.Districts[building.AdjacentDistrict];
				if(d) then
					s:AddIconLabel({"ICON_" .. d.DistrictType, d.Name, d.DistrictType}, d.Name);
				end
			end

			if(building.AdjacentImprovement) then
				local improvement = GameInfo.Improvements[building.AdjacentImprovement];
				if(improvement) then
					s:AddIconLabel({"ICON_" .. improvement.ImprovementType, improvement.Name, improvement.ImprovementType}, improvement.Name);
				end
			end

			if(building.AdjacentResource) then
				local r = GameInfo.Resources[building.AdjacentResource];
				if(r) then
					s:AddIconLabel({"ICON_" .. r.ResourceType, r.Name, r.ResourceType}, r.Name);
				end
			end
			
			for i, v in ipairs(adjacency_requirements) do
				local t = type(v);
				if(t == "table") then
					local tName = v[1];
					local tType = v[2];
					s:AddIconLabel({"ICON_" .. tType, tName, tType}, tName);

				elseif(t == "string") then
					s:AddLabel("[ICON_Bullet] " .. v);
				end
			end


			s:AddSeparator();
		end

		if(#placement_requirements > 0) then
			s:AddHeader("LOC_UI_PEDIA_PLACEMENT");

			for i, v in ipairs(placement_requirements) do
				local t = type(v);
				if(t == "table") then
					local tName = v[1];
					local tType = v[2];
					s:AddIconLabel({"ICON_" .. tType, tName, tType}, tName);

				elseif(t == "string") then
					s:AddLabel("[ICON_Bullet] " .. v);
				end
			end

			s:AddSeparator();
		end
		
		if(cost ~= 0) then
			if (not building.MustPurchase) then
				local yield = GameInfo.Yields["YIELD_PRODUCTION"];
				if(yield) then
					s:AddHeader("LOC_UI_PEDIA_PRODUCTION_COST");
					local t = Locale.Lookup("LOC_UI_PEDIA_BASE_COST", cost, yield.IconString, yield.Name);
					s:AddLabel(t);
				end
			end

			if (building.PurchaseYield) then	
				local y = GameInfo.Yields[building.PurchaseYield];
				if(y) then
					s:AddHeader("LOC_UI_PEDIA_PURCHASE_COST");
					local t = Locale.Lookup("LOC_UI_PEDIA_BASE_COST", purchase_cost, y.IconString, y.Name);
					s:AddLabel(t);
				end
			end
		end

		if(maintenance ~= 0) then
			local yield = GameInfo.Yields["YIELD_GOLD"];
			if(yield) then
				s:AddHeader("LOC_UI_PEDIA_MAITENANCE_COST");
				local t = Locale.Lookup("LOC_UI_PEDIA_BASE_COST", tonumber(building.Maintenance), yield.IconString, yield.Name );
				s:AddLabel(t);
			end
		end

		s:AddSeparator();
	end);

	-- Left Column
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", building.Description);
	
	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
