-- ===========================================================================
--	Civilopedia - Historic Moment Page Layout
-- ===========================================================================

PageLayouts["HistoricMoment" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local moment = GameInfo.Moments[pageId];
	if(moment == nil) then
		return;
	end
	local momentType = moment.MomentType;

	local eraScore = moment.EraScore;
	if (eraScore == nil) then
		eraScore = 0;
	end

	local obsoleteEra;
	if(moment.ObsoleteEra and moment.ObsoleteEra ~= "NO_ERA") then
		local era = GameInfo.Eras[moment.ObsoleteEra];
		if(era) then
			obsoleteEra = era.Name;
		end
	end

	local minEra;
	if(moment.MinimumGameEra) then
		local era = GameInfo.Eras[moment.MinimumGameEra];
		if(era) then
			minEra = era.Name;
		end
	end

	local maxEra;
	if(moment.MaximumGameEra) then
		local era = GameInfo.Eras[moment.MaximumGameEra];
		if(era) then
			maxEra = era.Name;
		end
	end

	-- Get some info!
	AddPortrait("ICON_HISTORIC_MOMENT");

	-- Right Column!
	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();
		if(eraScore ~= nil) then
			local t = Locale.Lookup("LOC_UI_PEDIA_ERA_SCORE", tonumber(eraScore));
			s:AddLabel(t);
			s:AddSeparator();
		end

		if(obsoleteEra) then
			s:AddHeader("LOC_UI_PEDIA_MADE_REMOVED_IF");
			s:AddLabel(obsoleteEra);
			s:AddSeparator();
		end
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(minEra) then
			local t = Locale.Lookup("LOC_UI_PEDIA_MIN_ERA", minEra);
			s:AddLabel(t);
		end

		if(maxEra) then
			local t = Locale.Lookup("LOC_UI_PEDIA_MAX_ERA", maxEra);
			s:AddLabel(t);
		end
	end);


	-- Left Column!
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", moment.Description);

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
