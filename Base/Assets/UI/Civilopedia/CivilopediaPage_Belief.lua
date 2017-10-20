-- ===========================================================================
--	Civilopedia - Belief Page Layout
-- ===========================================================================

PageLayouts["Belief" ] = function(page)

local sectionId = page.SectionId;
    local pageId = page.PageId;

    SetPageHeader(page.Title);
    SetPageSubHeader(page.Subtitle);

	-- Gather info.
    local belief = GameInfo.Beliefs[pageId];
    if(belief == nil) then
        return;
    end           
    local beliefType = belief.BeliefType;

	local beliefClass;
	if(belief.BeliefClassType) then
		beliefClass = GameInfo.BeliefClasses[belief.BeliefClassType];
	end

	local unlocks = {};
	local unlock_units = {};
	local has_modifier = {};
	for row in GameInfo.BeliefModifiers() do
		if(row.BeliefType == beliefType) then
			has_modifier[row.ModifierID] = true;
		end
	end

	for row in GameInfo.Modifiers() do
		if(has_modifier[row.ModifierId]) then
			local info = GameInfo.DynamicModifiers[row.ModifierType];
			if(info) then
				if(info.EffectType == "EFFECT_ADD_RELIGIOUS_BUILDING") then
					for args in GameInfo.ModifierArguments() do
						if(args.ModifierId == row.ModifierId) then
							if(args.Name == "BuildingType") then
								local info = GameInfo.Buildings[args.Value];
								if(info) then
									table.insert(unlocks, {{"ICON_" .. info.BuildingType, info.Name, info.BuildingType}, info.Name});
								end
							end
						end
					end
				elseif(info.EffectType == "EFFECT_ADJUST_PLAYER_VALID_IMPROVEMENT") then
					for args in GameInfo.ModifierArguments() do
						if(args.ModifierId == row.ModifierId) then
							if(args.Name == "ImprovementType") then
								local info = GameInfo.Improvements[args.Value];
								if(info) then
									table.insert(unlocks, {{"ICON_" .. info.ImprovementType, info.Name, info.ImprovementType}, info.Name});
								end
							end
						end
					end					
				elseif(info.EffectType == "EFFECT_ADD_RELIGIOUS_UNIT") then
					for args in GameInfo.ModifierArguments() do
						if(args.ModifierId == row.ModifierId) then
							if(args.Name == "UnitType") then
								local info = GameInfo.Units[args.Value];
								if(info) then
									table.insert(unlock_units, {{"ICON_" .. info.UnitType, info.Name, info.UnitType}, info.Name});
								end
							end
						end
					end
				end
			end
		end
	end

	-- Right column stats.
	AddPortrait("ICON_" .. beliefType);
	
	if(beliefClass) then
		AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
			s:AddSeparator();
			s:AddHeader("LOC_UI_PEDIA_BELIEF_CLASS");
			s:AddLabel(beliefClass.Name);
			s:AddSeparator();

			if(#unlocks > 0) then
				s:AddHeader("LOC_UI_PEDIA_SPECIAL_INFRASTRUCTURE");
				for i,v in ipairs(unlocks) do
					s:AddIconLabel(v[1], v[2]);
				end
				s:AddSeparator();
			end

			if(#unlock_units > 0) then
				s:AddHeader("LOC_UI_PEDIA_SPECIAL_UNITS");
				for i,v in ipairs(unlock_units) do
					s:AddIconLabel(v[1], v[2]);
				end
				s:AddSeparator();
			end
		end);
	end

	-- Left column
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", belief.Description);
	
	local chapters = GetPageChapters(page.PageLayoutId) or {};
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end