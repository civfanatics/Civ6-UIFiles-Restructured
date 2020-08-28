-- ===========================================================================
--	Civilopedia - Improvement Page Layout
-- ===========================================================================

PageLayouts["Improvement" ] = function(page)
local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local improvement = GameInfo.Improvements[pageId];
	if(improvement == nil) then
		return;
	end

	local improvementType = improvement.ImprovementType;

	local stats = {};
	
	for row in GameInfo.Improvement_YieldChanges() do
		if(row.ImprovementType == improvementType and row.YieldChange ~= 0) then
			local yield = GameInfo.Yields[row.YieldType];
			if(yield) then
				table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_YIELD",row.YieldChange, yield.IconString, yield.Name));
			end
		end
	end

	local housing = 0;

	if(tonumber(improvement.TilesRequired) > 0) then
		housing = tonumber(improvement.Housing)/tonumber(improvement.TilesRequired);
	end

	if(housing ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_HOUSING", housing));
	end

	local airSlots = improvement.AirSlots or 0;
	if(airSlots ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_AIRSLOTS", airSlots));
	end

	local citizenSlots = improvement.CitizenSlots or 0;
	if(citizenSlots ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_CITIZENSLOTS", citizenSlots));
	end
	
	local weaponSlots = improvement.WeaponSlots or 0;
	if(weaponSlots ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_WEAPONSLOTS", weaponSlots));
	end
	
	local appeal = tonumber(improvement.Appeal) or 0;
	if(appeal ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_APPEAL", appeal));
	end

	for row in GameInfo.Improvement_BonusYieldChanges() do
		if(row.ImprovementType == improvementType and row.BonusYieldChange ~= 0) then
			local yield = GameInfo.Yields[row.YieldType];
			if(yield) then

				local item;
				if(row.PrereqCivic) then
					item = GameInfo.Civics[row.PrereqCivic];
				else
					item = GameInfo.Technologies[row.PrereqTech];
				end

				if(item) then
					table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_BONUS_YIELD", row.BonusYieldChange, yield.IconString, yield.Name, item.Name));
				end
			end
		end
	end
	
	for row in GameInfo.Improvement_Tourism() do
		if(row.ImprovementType == improvementType and row.Improvement_Tourism ~= 0) then
			local yield;
			if(row.TourismSource == "TOURISMSOURCE_CULTURE") then
				yield = GameInfo.Yields["YIELD_CULTURE"];
			elseif(row.TourismSource == "TOURISMSOURCE_GOLD") then
				yield = GameInfo.Yields["YIELD_GOLD"];
			elseif(row.TourismSource == "TOURISMSOURCE_FAITH") then
				yield = GameInfo.Yields["YIELD_FAITH"];
			elseif(row.TourismSource == "TOURISMSOURCE_FOOD") then
				yield = GameInfo.Yields["YIELD_FOOD"];
			elseif(row.TourismSource == "TOURISMSOURCE_PRODUCTION") then
				yield = GameInfo.Yields["YIELD_PRODUCTION"];
			elseif(row.TourismSource == "TOURISMSOURCE_SCIENCE") then
				yield = GameInfo.Yields["YIELD_SCIENCE"];
			
			end
		
			local item;
			if(row.PrereqCivic) then
				item = GameInfo.Civics[row.PrereqCivic];
			else
				item = GameInfo.Technologies[row.PrereqTech];
			end
			
			if(item) then
				if(yield) then
					table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_TOURISM_BONUS_YIELD", row.ScalingFactor, yield.IconString, yield.Name, item.Name));
				elseif (row.TourismSource == "TOURISMSOURCE_APPEAL") then
					table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_TOURISM_BONUS_APPEAL", row.ScalingFactor, item.Name));
				end
			else
				if(yield) then
					table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_TOURISM_BONUS_YIELD_NO_REQUIREMENT", row.ScalingFactor, yield.IconString, yield.Name));
				elseif (row.TourismSource == "TOURISMSOURCE_APPEAL") then
					table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_TOURISM_BONUS_APPEAL_NO_REQUIREMENT", row.ScalingFactor));
				end
			end
		end
	end

	local unique_to_map = {};
	if(improvement.TraitType) then
		local traitType = improvement.TraitType;

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

		for row in GameInfo.LeaderTraits() do
			if(row.TraitType == traitType) then
				local leader = GameInfo.Leaders[row.LeaderType];
				if(leader) then
					-- If this is a city state, use the civilization type.
					local city_state_civilization = city_state_leaders[row.LeaderType];
					if(city_state_civilization) then
						local civ = GameInfo.Civilizations[city_state_civilization];
						if(civ) then
							unique_to_map[civ.CivilizationType] = {"ICON_" .. civ.CivilizationType, civ.Name, civ.CivilizationType};
						end
					else
						unique_to_map[row.LeaderType] = {"ICON_" .. row.LeaderType, leader.Name, row.LeaderType};
					end
				end
			end
		end

		for row in GameInfo.CivilizationTraits() do
			if(row.TraitType == traitType) then
				local civ = GameInfo.Civilizations[row.CivilizationType];
				if(civ) then
					unique_to_map[row.CivilizationType] = {"ICON_" .. row.CivilizationType, civ.Name, row.CivilizationType};
				end
			end
		end
	end

	-- If the only units that can build the improvement are unique units, then treat this as a unique improvement.
	local built_by_unique = true;
	local built_by = {};
	for row in GameInfo.Improvement_ValidBuildUnits() do
		if(row.ImprovementType == improvementType) then
			local unit = GameInfo.Units[row.UnitType];
			if(unit) then
				if(unit.TraitType == nil) then
					built_by_unique = false;
				end

				table.insert(built_by, unit);
			end
		end
	end
	table.sort(built_by, function(a,b) return Locale.Compare(Locale.Lookup(a.Name), Locale.Lookup(b.Name)) == -1; end);
	
	if(built_by_unique) then
		for i, unit in ipairs(built_by) do
			local traitType = unit.TraitType;
			for row in GameInfo.LeaderTraits() do
				if(row.TraitType == traitType) then
					local leader = GameInfo.Leaders[row.LeaderType];
					if(leader) then
						-- If this is a city state, use the civilization type.
						local city_state_civilization = city_state_leaders[row.LeaderType];
						if(city_state_civilization) then
							local civ = GameInfo.Civilizations[city_state_civilization];
							if(civ) then
								unique_to_map[civ.CivilizationType] = {"ICON_" .. civ.CivilizationType, civ.Name, civ.CivilizationType};
							end
						else
							unique_to_map[row.LeaderType] = {"ICON_" .. row.LeaderType, leader.Name, row.LeaderType};
						end
					end
				end
			end

			for row in GameInfo.CivilizationTraits() do
				if(row.TraitType == traitType) then
					local civ = GameInfo.Civilizations[row.CivilizationType];
					if(civ) then
						unique_to_map[row.CivilizationType] = {"ICON_" .. row.CivilizationType, civ.Name, row.CivilizationType}
					end
				end
			end
		end		
	end

	-- Many beliefs unlock improvements using modifiers.
	-- Search for a specific effect type in belief modifiers to see if any refer to this improvement.
	local unlock_modifiers = {};
	for row in GameInfo.Modifiers() do
		local info = GameInfo.DynamicModifiers[row.ModifierType];
		if(info) then
			if(info.EffectType == "EFFECT_ADJUST_PLAYER_VALID_IMPROVEMENT") then
				for args in GameInfo.ModifierArguments() do
					if(args.ModifierId == row.ModifierId) then
						if(args.Name == "ImprovementType" and args.Value == improvementType) then
							unlock_modifiers[row.ModifierId] = true;
						end
					end
				end
			end
		end
	end

	local beliefs = {};
	for row in GameInfo.BeliefModifiers() do
		if(unlock_modifiers[row.ModifierID]) then
			beliefs[row.BeliefType] = true;
		end
	end

	for k,_ in pairs(beliefs) do
		local belief = GameInfo.Beliefs[k];
		if(belief) then
			unique_to_map[belief.BeliefType] = {"ICON_" .. belief.BeliefType, belief.Name, belief.BeliefType}
		end
	end

	-- Generate list of adjacency bonuses.
	local adjacency_yields = {};
	local has_bonus = {};
	for row in GameInfo.Improvement_Adjacencies() do
		if(row.ImprovementType == improvementType) then
			has_bonus[row.YieldChangeId] = true;
		end
	end

	for row in GameInfo.Adjacency_YieldChanges() do
		if(has_bonus[row.ID]) then
			
			local object;
			if(row.OtherDistrictAdjacent) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_DISTRICT";
			elseif(row.AdjacentResource) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_RESOURCE";
			elseif(row.AdjacentSeaResource) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_SEA_RESOURCE";
			elseif(row.AdjacentResourceClass ~= "NO_RESOURCECLASS") then
				if(row.AdjacentResourceClass == "RESOURCECLASS_BONUS") then
					object = "LOC_TOOLTIP_BONUS_RESOURCE";
				elseif(row.AdjacentResourceClass == "RESOURCECLASS_LUXURY") then
					object = "LOC_TOOLTIP_LUXURY_RESOURCE";
				elseif(row.AdjacentResourceClass == "RESOURCECLASS_STRATEGIC") then
					object = "LOC_TOOLTIP_BONUS_STRATEGIC";
				else
					object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_RESOURCE_CLASS";
				end
			elseif(row.AdjacentRiver) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_RIVER";
			elseif(row.AdjacentWonder) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_WONDER";
			elseif(row.AdjacentNaturalWonder) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_NATURAL_WONDER";
			elseif(row.AdjacentTerrain) then
				local terrain = GameInfo.Terrains[row.AdjacentTerrain];
				if(terrain) then
					object = terrain.Name;
				end
			elseif(row.AdjacentFeature) then
				local feature = GameInfo.Features[row.AdjacentFeature];
				if(feature) then
					object = feature.Name;
				end
			elseif(row.AdjacentImprovement) then
				local improvement = GameInfo.Improvements[row.AdjacentImprovement];
				if(improvement) then
					object = improvement.Name;
				end
			elseif(row.AdjacentDistrict) then		
				local district = GameInfo.Districts[row.AdjacentDistrict];
				if(district) then
					object = district.Name;
				end
			end

			local yield = GameInfo.Yields[row.YieldType];

			if(object and yield) then

				local key = (row.TilesRequired > 1) and "LOC_TYPE_TRAIT_ADJACENT_BONUS_PER" or "LOC_TYPE_TRAIT_ADJACENT_BONUS";

				local value = Locale.Lookup(key, row.YieldChange, yield.IconString, yield.Name, row.TilesRequired, object);

				if(row.PrereqCivic or row.PrereqTech) then
					local item;
					if(row.PrereqCivic) then
						item = GameInfo.Civics[row.PrereqCivic];
					else
						item = GameInfo.Technologies[row.PrereqTech];
					end

					if(item) then
						local text = Locale.Lookup("LOC_TYPE_TRAIT_ADJACENT_BONUS_REQUIRES_TECH_OR_CIVIC", item.Name);
						value = value .. "  " .. text;
					end
				end

				if(row.ObsoleteCivic or row.ObsoleteTech) then
					local item;
					if(row.ObsoleteCivic) then
						item = GameInfo.Civics[row.ObsoleteCivic];
					else
						item = GameInfo.Technologies[row.ObsoleteTech];
					end
				
					if(item) then
						local text = Locale.Lookup("LOC_TYPE_TRAIT_ADJACENT_BONUS_OBSOLETE_WITH_TECH_OR_CIVIC", item.Name);
						value = value .. "  " .. text;
					end
				end

				table.insert(adjacency_yields, value);
			end		
		end
	end
	
	local pillageAwards = improvement.PlunderType or NO_PLUNDER;
	if(pillageAwards ~= nil and  pillageAwards ~= "NO_PLUNDER") then
		if(pillageAwards == "PLUNDER_CULTURE") then
			local culture = GameInfo.Yields["YIELD_CULTURE"];
			table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_PILLAGE_AWARD", culture.IconString, culture.Name));
		elseif (pillageAwards == "PLUNDER_SCIENCE") then
			local science = GameInfo.Yields["YIELD_SCIENCE"];
			table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_PILLAGE_AWARD", science.IconString, science.Name));
		elseif (pillageAwards == "PLUNDER_FAITH") then
			local faith = GameInfo.Yields["YIELD_FAITH"];
			table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_PILLAGE_AWARD", faith.IconString, faith.Name));
		elseif (pillageAwards == "PLUNDER_GOLD") then
			local gold = GameInfo.Yields["YIELD_GOLD"];
			table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_PILLAGE_AWARD", gold.IconString, gold.Name));
		elseif (pillageAwards == "PLUNDER_HEAL") then
			local faith = GameInfo.Yields["YIELD_FAITH"];
			table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_PILLAGE_AWARD_NO_ICON", "LOC_TYPE_TRAIT_PILLAGE_AWARD_HEALING"));
		end
	end

	-- placement requirements
	local placement_requirements = {};
	for row in GameInfo.Improvement_ValidFeatures() do
		if(row.ImprovementType == improvementType) then
			local feature = GameInfo.Features[row.FeatureType];
			if(feature ~= nil) then
				table.insert(placement_requirements, {Locale.Lookup(feature.Name), feature.FeatureType});
			end
		end
	end

	for row in GameInfo.Improvement_ValidResources() do
		if(row.ImprovementType == improvementType) then
			local resource = GameInfo.Resources[row.ResourceType];
			if(resource ~= nil) then
				table.insert(placement_requirements, {Locale.Lookup(resource.Name), resource.ResourceType});
			end
		end
	end

	for row in GameInfo.Improvement_ValidTerrains() do
		if(row.ImprovementType == improvementType) then
			local terrain = GameInfo.Terrains[row.TerrainType];
			if(terrain ~= nil) then
				table.insert(placement_requirements, {Locale.Lookup(terrain.Name), terrain.TerrainType});
			end
		end
	end
	table.sort(placement_requirements, function(a,b) return Locale.Compare(a[1],b[1]) == -1 end);

	local unique_to = {};
	for k,v in pairs(unique_to_map) do
		table.insert(unique_to, v);
	end


	-- Right Column
	AddPortrait(improvement.Icon);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();

		if(#unique_to > 0) then		
			s:AddHeader("LOC_UI_PEDIA_UNIQUE_TO");
			for _, icon in ipairs(unique_to) do
				s:AddIconLabel(icon, icon[2]);
			end

			s:AddSeparator();
		end
			
		if(#stats > 0) then
			for _, v in ipairs(stats) do
				s:AddLabel(v);
			end
			s:AddSeparator();
		end

		if(#adjacency_yields > 0) then
			s:AddHeader("LOC_UI_PEDIA_ADJACENCY_BONUS");
			for i,v in ipairs(adjacency_yields) do
				s:AddLabel(v);
			end
			s:AddSeparator();
		end		
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(improvement.PrereqCivic ~= nil or improvement.PrereqTech ~= nil) then
			if(improvement.PrereqCivic ~= nil) then
				local civic = GameInfo.Civics[improvement.PrereqCivic];
				if(civic) then
					s:AddHeader("LOC_CIVIC_NAME");
					s:AddIconLabel({"ICON_" .. civic.CivicType, civic.Name, civic.CivicType}, civic.Name);
				end
			end

			if(improvement.PrereqTech ~= nil) then
				local technology = GameInfo.Technologies[improvement.PrereqTech];
				if(technology) then
					s:AddHeader("LOC_TECHNOLOGY_NAME");
					s:AddIconLabel({"ICON_" .. technology.TechnologyType, technology.Name, technology.TechnologyType}, technology.Name);
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
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_USAGE", function(s)
		s:AddSeparator();

		if(#built_by > 0) then
			s:AddHeader("LOC_UI_PEDIA_BUILT_BY");
			for i,v in ipairs(built_by) do
				s:AddIconLabel({"ICON_" .. v.UnitType, v.Name, v.UnitType}, v.Name);
			end
		end

		s:AddSeparator();
	end);

	-- Left Column
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", improvement.Description);

	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
