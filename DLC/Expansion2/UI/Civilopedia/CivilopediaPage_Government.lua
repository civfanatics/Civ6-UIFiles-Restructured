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
	
	
	local stats = {};
	
	for row in GameInfo.Governments_XP2() do
		if(row.GovernmentType == governmentType and row.Favor > 0) then
			table.insert(stats, Locale.Lookup("LOC_UI_PEDIA_TRAIT_FAVOR", row.Favor));
		end
	end

	for row in GameInfo.Governments() do
		if(row.GovernmentType == governmentType and row.OtherGovernmentIntolerance ~= 0) then
			table.insert(stats, Locale.Lookup("LOC_UI_PEDIA_TRAIT_INTOLERANCE", row.OtherGovernmentIntolerance));
		end
	end

	for row in GameInfo.Government_SlotCounts() do
		if(row.GovernmentType == governmentType) then
			table.insert(stats, Locale.Lookup("LOC_UI_PEDIA_TRAIT_SLOT_TYPE", row.NumSlots, GameInfo.GovernmentSlots[row.GovernmentSlotType].Name));
		end
	end

	
	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();

		if(#stats > 0) then
			for _, v in ipairs(stats) do
				s:AddLabel(v);
			end
			s:AddSeparator();
		end
	end);
	
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
	if((government.InherentBonusDesc ~= nil and government.AccumulatedBonusShortDesc ~= nil) or BonusType=="NO_GOVERNMENTBONUS") then
		AddHeader("LOC_UI_PEDIA_DESCRIPTION");
		AddHeaderBody("LOC_GOVERNMENT_INHERENT_BONUS",  government.InherentBonusDesc);
		AddHeaderBody("LOC_GOVERNMENT_ACCUMULATED_BONUS",  government.AccumulatedBonusShortDesc);
	end
	
	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
