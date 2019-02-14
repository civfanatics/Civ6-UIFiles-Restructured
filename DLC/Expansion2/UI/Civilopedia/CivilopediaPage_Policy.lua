-- ===========================================================================
--	Civilopedia - Policy Page Layout
-- ===========================================================================

PageLayouts["Policy" ] = function(page)
local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local policy = GameInfo.Policies[pageId];
	if(policy == nil) then
		return;
	end

	local policyType = policy.PolicyType;

	local obsolete_policies = {};
	for row in GameInfo.ObsoletePolicies() do
		if(row.PolicyType == policyType) then
			table.insert(obsolete_policies, GameInfo.Policies[row.ObsoletePolicy]);
		end
	end

	local required_government = nil;
	for row in GameInfo.Governments() do
		if(row.PolicyToUnlock == policyType) then
			required_government = row;
			break;
		end
	end

	-- XP 1 Content
	local minEra;
	local maxEra;
	local darkAge;
	if(GameInfo.Policies_XP1) then
		local row = GameInfo.Policies_XP1[policyType];
		if(row) then
			local minEraRow = GameInfo.Eras[row.MinimumGameEra];
			if(minEraRow) then
				minEra = minEraRow.Name;
			end

			local maxEraRow = GameInfo.Eras[row.MaximumGameEra];
			if(maxEraRow) then
				maxEra = maxEraRow.Name;
			end

			darkAge = row.RequiresDarkAge;
		end

	end

	local policy_exclusivegovernments = {};
	for row in GameInfo.Policy_GovernmentExclusives_XP2() do
		if(row.PolicyType == policyType) then
			table.insert(policy_exclusivegovernments, row.GovernmentType);
		end
	end
	
	local policy_unlockedgovernment = {};
	for row in GameInfo.Governments() do
		if(row.PolicyToUnlock == policyType) then
			table.insert(policy_unlockedgovernment, row.GovernmentType);
		end
	end
	
	-- Right Column
	AddPortrait("ICON_" .. policyType);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();

		if(#obsolete_policies > 0) then
			s:AddHeader("LOC_UI_PEDIA_MADE_OBSOLETE_BY");
			for i,v in ipairs(obsolete_policies) do
				s:AddIconLabel({"ICON_" .. v.PolicyType, v.Name, v.PolicyType}, v.Name);
			end
		end
			
		s:AddSeparator();
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(darkAge) then
			s:AddLabel("LOC_UI_PEDIA_REQUIRES_DARK_AGE");
		end

		if(minEra) then
			local t = Locale.Lookup("LOC_UI_PEDIA_MIN_ERA", minEra);
			s:AddLabel(t);
		end

		if(maxEra) then
			local t = Locale.Lookup("LOC_UI_PEDIA_MAX_ERA", maxEra);
			s:AddLabel(t);
		end

		if(policy.PrereqCivic ~= nil) then
			local civic = GameInfo.Civics[policy.PrereqCivic];
			if(civic) then
				s:AddHeader("LOC_CIVIC_NAME");
				s:AddIconLabel({"ICON_" .. civic.CivicType, civic.Name, civic.CivicType}, civic.Name);
			end
		end

		if(policy.PrereqTech ~= nil) then
			local tech = GameInfo.Technologies[policy.PrereqTech];
			if(tech) then
				s:AddHeader("LOC_CIVIC_NAME");
				s:AddIconLabel({"ICON_" .. tech.TechnologyType, tech.Name, tech.TechnologyType}, tech.Name);
			end
		end
		
		if(#policy_exclusivegovernments > 0) then
			s:AddHeader("LOC_GOVERNMENT_NAME");
			for i,v in ipairs(policy_exclusivegovernments) do
				local government = GameInfo.Governments[v];
				s:AddIconLabel({"ICON_" .. government.GovernmentType, government.Name, government.GovernmentType}, government.Name);
			end
		end
		
		if(#policy_unlockedgovernment > 0) then
			if(#policy_exclusivegovernments == 0) then
				s:AddHeader("LOC_GOVERNMENT_NAME");
			end
			s:AddLabel("LOC_UI_PEDIA_REQUIRES_NOT_GOVERNMENT");
			for i,v in ipairs(policy_unlockedgovernment) do
				local government = GameInfo.Governments[v];
				s:AddIconLabel({"ICON_" .. government.GovernmentType, government.Name, government.GovernmentType}, government.Name);
			end
		end
		
		s:AddSeparator();
	end);

	-- Left Column
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", policy.Description);

	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end

	-- If a government is required, duplicate it's chapter data in the policy.
	if(required_government) then
		local pageId = required_government.GovernmentType;
		local chapters = GetPageChapters(page.PageLayoutId);
		for i, chapter in ipairs(chapters) do
			local chapterId = chapter.ChapterId;
			local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
			local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

			AddChapter(chapter_header, chapter_body);
		end
	end
end
