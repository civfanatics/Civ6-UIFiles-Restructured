-- ===========================================================================
--	Civilopedia - Government Page Layout
-- ===========================================================================

PageLayouts["Government" ] = function(page)
local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local government = GameInfo.Governments[pageId];
	if(government == nil) then
		return;
	end

	local governmentType = government.GovernmentType;

	local policy_exclusivegovernments = {};
	for row in GameInfo.Policy_GovernmentExclusives_XP2() do
		if(row.GovernmentType == governmentType) then
			table.insert(policy_exclusivegovernments, row.PolicyType);
		end
	end
	
	-- Right Column
	-- AddPortrait("ICON_" .. governmentType);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(government.PrereqCivic ~= nil) then
			local civic = GameInfo.Civics[government.PrereqCivic];
			if(civic) then
				s:AddHeader("LOC_CIVIC_NAME");
				s:AddIconLabel({"ICON_" .. civic.CivicType, civic.Name, civic.CivicType}, civic.Name);
			end
		end
		
		if(#policy_exclusivegovernments > 0) then
			s:AddHeader("LOC_UI_PEDIA_MADE_EXCLUSIVE_GOVENMENT");
			for i,v in ipairs(policy_exclusivegovernments) do
				local policy = GameInfo.Policies[v];
				s:AddIconLabel({"ICON_" .. policy.PolicyType, policy.Name, policy.PolicyType}, policy.Name);
			end
		end
		
		s:AddSeparator();
	end);

	-- Left Column
	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
