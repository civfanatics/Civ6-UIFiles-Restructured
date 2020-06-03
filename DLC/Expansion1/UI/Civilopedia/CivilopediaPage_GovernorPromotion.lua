-- ===========================================================================
--	Civilopedia - Governor Promotion Page Layout
-- ===========================================================================

PageLayouts["GovernorPromotion" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local promotion = GameInfo.GovernorPromotions[pageId];
	if(promotion == nil) then
		return;
	end
	local governorPromotionType = promotion.GovernorPromotionType;

	-- Get some info!
	local level = promotion.Level;

	local prereqs = {};
	local leadsto = {};
	for row in GameInfo.GovernorPromotionPrereqs() do
		if(row.GovernorPromotionType == governorPromotionType) then
			local p = GameInfo.GovernorPromotions[row.PrereqGovernorPromotion];
			if(p) then
				table.insert(prereqs, p.Name);
			end
		elseif(row.PrereqGovernorPromotion == governorPromotionType) then
			local p = GameInfo.GovernorPromotions[row.GovernorPromotionType];
			if(p) then
				table.insert(leadsto, p.Name);
			end
		end
	end	

	-- Right Column!
	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();
		local l = tonumber(level);
		local  t;
		if(l < 1) then
			t = Locale.Lookup("LOC_UI_PEDIA_PROMOTION_BASE");
		else
			t = Locale.Lookup("LOC_UI_PEDIA_PROMOTION_LEVEL", tonumber(level));
		end
		
		s:AddLabel(t);
		s:AddSeparator();
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(#prereqs > 0) then
			for i,v in ipairs(prereqs) do
				s:AddLabel("[ICON_Bullet] " .. Locale.Lookup(v));
			end
		end	

		s:AddSeparator();
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_PROGRESSION", function(s)
		s:AddSeparator();

		if(#leadsto > 0) then
			s:AddHeader("LOC_UI_PEDIA_LEADS_TO_GOVERNOR_PROMOTIONS");
			for _, v in ipairs(leadsto) do
				s:AddLabel("[ICON_Bullet] " .. Locale.Lookup(v));
			end
		end
		s:AddSeparator();
	end);


	-- Left Column!
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", promotion.Description);

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
