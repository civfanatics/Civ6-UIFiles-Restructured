-- ===========================================================================
--	Civilopedia - Resource Page Layout
-- ===========================================================================

PageLayouts["Resource" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local resource = GameInfo.Resources[pageId];
	if(resource == nil) then
		return;
	end
	local resourceType = resource.ResourceType;

	local resourceClasses = {
		RESOURCECLASS_BONUS = "LOC_RESOURCECLASS_BONUS_NAME",
		RESOURCECLASS_LUXURY = "LOC_RESOURCECLASS_LUXURY_NAME",
		RESOURCECLASS_STRATEGIC = "LOC_RESOURCECLASS_STRATEGIC_NAME",
		RESOURCECLASS_ARTIFACT = "LOC_RESOURCECLASS_ARTIFACT_NAME",
	}

	local resource_class = resourceClasses[resource.ResourceClassType];

	-- Get some info!
	local yield_changes = {};
	for row in GameInfo.Resource_YieldChanges() do
		if(row.ResourceType == resourceType) then
			local change = yield_changes[row.YieldType] or 0;
			yield_changes[row.YieldType] = change + row.YieldChange;
		end
	end

	for row in GameInfo.Yields() do
		local change = yield_changes[row.YieldType];
		if(change ~= nil) then
			table.insert(yield_changes, {change, row.IconString, Locale.Lookup(row.Name)}); 
		end
	end

	local improvements = {};
	for row in GameInfo.Improvement_ValidResources() do
		if(row.ResourceType == resourceType) then
			local improvement = GameInfo.Improvements[row.ImprovementType];
			if(improvement) then
				table.insert(improvements, {{improvement.Icon, improvement.Name, improvement.ImprovementType}, Locale.Lookup(improvement.Name)});
			end
			
		end
	end
	table.sort(improvements, function(a,b) return Locale.Compare(a[2],b[2]) < 0; end);

	local harvests = {};
	for row in GameInfo.Resource_Harvests() do
		if(row.ResourceType == resourceType) then
			table.insert(harvests, row);
		end
	end
	
	local buildings = {};
	for row in GameInfo.Buildings_XP2() do
		if(row.ResourceTypeConvertedToPower == resourceType) then
			if(row.BuildingType ~= nil) then
				local building = GameInfo.Buildings[row.BuildingType];
				if(building) then
					table.insert(buildings, {{"ICON_" .. building.BuildingType , building.Name, building.BuildingType}, Locale.Lookup(building.Name)});
				end
			end
		end
	end
	table.sort(buildings, function(a,b) return Locale.Compare(a[2],b[2]) < 0; end);
	
	local unique_projects = {};
	local projects = {};
	for row in GameInfo.Projects() do
		if(row.PrereqResource == resourceType) then
			local projectType = row.ProjectType;
			if(projectType ~= nil) then
				local project = GameInfo.Projects[projectType];
				if(project) then
					table.insert(projects, {{"ICON_" .. projectType, project.Name, projectType}, Locale.Lookup(project.Name)});
					unique_projects[projectType] = true;
				end
			end
		end
	end
	
	for row in GameInfo.Project_ResourceCosts() do
		if(row.ResourceType == resourceType) then
			local projectType = row.ProjectType;
			if(projectType ~= nil) then
				local project = GameInfo.Projects[projectType];
				if(project and not unique_projects[projectType]) then
					table.insert(projects, {{"ICON_" .. projectType, project.Name, projectType}, Locale.Lookup(project.Name)});
					unique_projects[projectType] = true;
				end
			end
		end
	end
	table.sort(projects, function(a,b) return Locale.Compare(a[2],b[2]) < 0; end);
	
	local routes = {};
	for row in GameInfo.Route_ResourceCosts() do
		if(row.ResourceType == resourceType) then
			if(row.RouteType ~= nil) then
				local route = GameInfo.Routes[row.RouteType];
				if(route) then
					table.insert(routes, {{"ICON_" .. route.RouteType, route.Name, route.RouteType}, Locale.Lookup(route.Name)});
				end
			end
		end
	end
	table.sort(routes, function(a,b) return Locale.Compare(a[2],b[2]) < 0; end);
	
	local unique_units = {}; -- used for dupe checking.
	local units = {};
	for row in GameInfo.Units() do
		if(row.StrategicResource == resourceType) then
			if(row.UnitType ~= nil) then
				local unit = GameInfo.Units[row.UnitType];
				if(unit) then
					unique_units[unit.UnitType] = true;
					table.insert(units, {{"ICON_" .. unit.UnitType, unit.Name, unit.UnitType}, Locale.Lookup(unit.Name)});
				end
			end
		end
	end
	
	for row in GameInfo.Units_XP2() do
		if(row.ResourceMaintenanceType == resourceType) then
			local unitType = row.UnitType;
			if(unitType ~= nil) then
				local unit = GameInfo.Units[unitType];
				if(unit and not unique_units[unitType]) then
					table.insert(units, {{"ICON_" .. unitType, unit.Name, unitType}, Locale.Lookup(unit.Name)});
				end
			end
		end
	end

	table.sort(units, function(a,b) return Locale.Compare(a[2],b[2]) < 0; end);


	-- Woo boy.  Let me explain what's about  to happen.
	-- A few of the resources are created on the fly by great people as a modifier effect.
	-- We want to display these great people of greatness on the side-bar because we're great like that.
	-- To do this... 
	-- Catalogue all modifiers that contain our effect "EFFECT_GRANT_FREE_RESOURCE_IN_CITY" 
	-- Find out all instances of modifiers of those type that has our resource in question as the ResourceType argument.
	-- Find out what great people possess such modifiers
	-- PROFIT.
	local creators = {};
	local has_any_modifiers = false;
	local has_modifier = {};
	local is_resource_modifier = {};
	for row in GameInfo.DynamicModifiers() do
		if(row.EffectType== "EFFECT_GRANT_FREE_RESOURCE_IN_CITY") then
			is_resource_modifier[row.ModifierType] = true;
		end
	end

	for row in GameInfo.Modifiers() do
		if(is_resource_modifier[row.ModifierType]) then
			for args in GameInfo.ModifierArguments() do
				if(args.ModifierId == row.ModifierId) then
					if(args.Name == "ResourceType" and args.Value == resourceType) then
						has_any_modifiers = true;
						has_modifier[row.ModifierId] = true;
					end
				end
			end
		end
	end

	if(has_any_modifiers) then
		for row in GameInfo.GreatPersonIndividualActionModifiers() do
			if(has_modifier[row.ModifierId]) then
				local t = row.GreatPersonIndividualType
				local greatPerson = GameInfo.GreatPersonIndividuals[t];
				if(greatPerson) then
					
					local gpClass = GameInfo.GreatPersonClasses[greatPerson.GreatPersonClassType];
			
					if(gpClass and gpClass.UnitType) then
						local gpUnit = GameInfo.Units[gpClass.UnitType];
						if(gpUnit) then
							local name = greatPerson.Name;

							table.insert(creators, {{"ICON_" .. gpUnit.UnitType, name, t}, name});
						end	
					end
				end
			end
		end
	end




	-- Now to the right!
	AddPortrait("ICON_" .. resourceType);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();
	
		if(resource_class) then
			s:AddHeader(resource_class);
		end

		if(#yield_changes > 0) then
			for _, v in ipairs(yield_changes) do
				s:AddLabel(Locale.Lookup("LOC_TYPE_TRAIT_YIELD", v[1], v[2], v[3]));
			end
		end

		if(resource.Happiness > 0) then
			s:AddLabel(Locale.Lookup("LOC_TYPE_TRAIT_HAPPINESS", resource.Happiness));
		end

		local kConsumption:table = GameInfo.Resource_Consumption[resource.ResourceType];
		if (kConsumption ~= nil) then
			if (kConsumption.Accumulate) then
				local iExtraction = kConsumption.ImprovedExtractionRate;
				if (iExtraction > 0) then
					local resourceIcon = "[ICON_" .. resource.ResourceType .. "]";
					s:AddLabel(Locale.Lookup("LOC_RESOURCE_ACCUMULATION_WHEN_IMPROVED", iExtraction, resourceIcon, resource.Name));
				end
			end
		end

		s:AddSeparator();
	end);
	
	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		local unlockedBy;
		if(resource.PrereqTech) then
			local tech = GameInfo.Technologies[resource.PrereqTech];
			if(tech) then
				unlockedBy = {
					Icon = "ICON_" .. tech.TechnologyType,
					Name = tech.Name,
					PediaKey = tech.TechnologyType
				};
			end
		end

		if(resource.PrereqCivic) then
			local civic = GameInfo.Civics[resource.PrereqCivic];
			if(civic) then
				unlockedBy = {
					Icon = "ICON_" .. civic.CivicType,
					Name = civic.Name,
					PediaKey = civic.CivicType
				};
			end
		end

		if(unlockedBy) then
			s:AddHeader("LOC_UI_PEDIA_UNLOCKED_BY");
			s:AddIconLabel({unlockedBy.Icon, unlockedBy.Name, unlockedBy.PediaKey}, unlockedBy.Name);
			s:AddSeparator();
		end

		-- HAX! OMG LAZY DEVELOPER HAX
		if(resourceType == "RESOURCE_CLOVES" or resourceType == "RESOURCE_CINNAMON") then
			local zanzibar = GameInfo.Civilizations["CIVILIZATION_ZANZIBAR"];
			if(zanzibar) then
				s:AddHeader("LOC_UI_PEDIA_SUZERAIN");

				s:AddIconLabel({"ICON_CIVILIZATION_ZANZIBAR", zanzibar.Name, zanzibar.CivilizationType}, zanzibar.Name);

				s:AddSeparator();
			end
		end
		
		if(#creators > 0) then
			s:AddHeader("LOC_UI_PEDIA_CREATED_BY");
			for i,v in ipairs(creators) do
				s:AddIconLabel(v[1], v[2]);
			end
			s:AddSeparator();
		end
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_USAGE", function(s)
		s:AddSeparator();

		if(#improvements > 0) then
			s:AddHeader("LOC_UI_PEDIA_IMPROVED_BY");
			for i,v in ipairs(improvements) do
				s:AddIconLabel(v[1], v[2]);
			end
			s:AddSeparator();
		end
		
		if(#harvests > 0) then
			s:AddHeader("LOC_UI_PEDIA_HARVEST");
			for i,v in ipairs(harvests) do
				local yield = GameInfo.Yields[v.YieldType];
				if(yield) then
					s:AddLabel(Locale.Lookup("LOC_TYPE_TRAIT_YIELD", v.Amount, yield.IconString, yield.Name));
					if(v.PrereqTech) then
						local tech = GameInfo.Technologies[v.PrereqTech];
						if(tech) then
							s:AddIconLabel({"ICON_" .. tech.TechnologyType, tech.Name, tech.TechnologyType}, Locale.Lookup("LOC_UI_PEDIA_REQUIRES", tech.Name));
						end
					end
				end	
			end
			s:AddSeparator();	
		end
		
		if(#buildings > 0) then
			s:AddHeader(Locale.Lookup("LOC_UI_PEDIA_RESOURCES_BUILDINGS", #buildings));
			for i,v in ipairs(buildings) do
				s:AddIconLabel(v[1], v[2]);
			end
			s:AddSeparator();
		end
		
		if(#projects > 0) then
			s:AddHeader(Locale.Lookup("LOC_UI_PEDIA_RESOURCES_PROJECTS", #projects));
			for i,v in ipairs(projects) do
				s:AddIconLabel(v[1], v[2]);
			end
			s:AddSeparator();
		end
		
		if(#routes > 0) then
			s:AddHeader(Locale.Lookup("LOC_UI_PEDIA_RESOURCES_ROUTES", #routes));
			for i,v in ipairs(routes) do
				s:AddIconLabel(v[1], v[2]);
			end
			s:AddSeparator();
		end
		
		if(#units > 0) then
			s:AddHeader(Locale.Lookup("LOC_UI_PEDIA_RESOURCES_UNITS", #units));
			for i,v in ipairs(units) do
				s:AddIconLabel(v[1], v[2]);
			end
			s:AddSeparator();
		end

	end);

	-- Left Column!
	local chapters = GetPageChapters(page.PageLayoutId);
	if(chapters) then
		for i, chapter in ipairs(chapters) do
			local chapterId = chapter.ChapterId;
			local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
			local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

			AddChapter(chapter_header, chapter_body);
		end
	end
end
