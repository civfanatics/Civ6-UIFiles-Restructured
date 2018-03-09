-- ===========================================================================
--	Civilopedia - Governor Page Layout
-- ===========================================================================

PageLayouts["Governor" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local governor = GameInfo.Governors[pageId];
	if(governor == nil) then
		return;
	end
	local governorType = governor.GovernorType;

	-- Get some info!
	local titles = {};
	for row in GameInfo.GovernorPromotions() do
		if(row.GovernorType == governorType) then
			table.insert(titles, Locale.Lookup(row.Name));
		end
	end
	table.sort(titles);

	-- Right Column!
	AddTallImageNoScale(governor.PortraitImage);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		if(#titles > 0) then
			s:AddHeader("LOC_UI_PEDIA_TITLES");
			for _, title in ipairs(titles) do
				s:AddLabel("[ICON_BULLET]" .. title, title.GovernorPromotionType);
			end

			s:AddSeparator();
		end
	end);

	-- Left Column!
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", governor.Description);

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
