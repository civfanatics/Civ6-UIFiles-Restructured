-- Copyright 2017-2018, Firaxis Games
include("ActionPanel");

BASE_OnRefresh = OnRefresh;
BASE_LateInitialize = LateInitialize;

local governorAppointmentString:string = Locale.Lookup("LOC_ACTION_PANEL_GOVERNOR_APPOINTMENT");
local governorAppointmentTooltip:string = Locale.Lookup("LOC_ACTION_PANEL_GOVERNOR_APPOINTMENT_TOOLTIP");
local governorOpportunityString:string = Locale.Lookup("LOC_ACTION_PANEL_GOVERNOR_OPPORTUNITY");
local governorOpportunityTooltip:string = Locale.Lookup("LOC_ACTION_PANEL_GOVERNOR_OPPORTUNITY_TOOLTIP");
local governorPromotionString:string = Locale.Lookup("LOC_ACTION_PANEL_GOVERNOR_PROMOTION");
local governorPromotionTooltip:string = Locale.Lookup("LOC_ACTION_PANEL_GOVERNOR_PROMOTION_TOOLTIP");
local considerDisloyalCityString:string = Locale.Lookup("LOC_ACTION_PANEL_CONSIDER_DISLOYAL_CITY");
local considerDisloyalCityTooltip:string = Locale.Lookup("LOC_ACTION_PANEL_CONSIDER_DISLOYAL_CITY_TOOLTIP");
local EmergencyAttentionString:string = Locale.Lookup("LOC_NOTIFICATION_EMERGENCY_NEEDS_ATTENTION_MESSAGE");
local EmergencyAttentionTooltip:string = Locale.Lookup("LOC_NOTIFICATION_EMERGENCY_NEEDS_ATTENTION_SUMMARY");
local commemorationAvailableString:string = Locale.Lookup("LOC_NOTIFICATION_COMMEMORATION_AVAILABLE_MESSAGE");
local commemorationAvailableTooltip:string = Locale.Lookup("LOC_NOTIFICATION_COMMEMORATION_AVAILABLE_SUMMARY");

g_kMessageInfo[EndTurnBlockingTypes.ENDTURN_BLOCKING_GOVERNOR_APPOINTMENT]		= {Message = governorAppointmentString,		ToolTip = governorAppointmentTooltip	, Icon="ICON_NOTIFICATION_GOVERNOR_APPOINTMENT_AVAILABLE"	};
g_kMessageInfo[EndTurnBlockingTypes.ENDTURN_BLOCKING_GOVERNOR_OPPORTUNITY]		= {Message = governorOpportunityString,		ToolTip = governorOpportunityTooltip	, Icon="ICON_NOTIFICATION_GOVERNOR_OPPORTUNITY_AVAILABLE"	};
g_kMessageInfo[EndTurnBlockingTypes.ENDTURN_BLOCKING_GOVERNOR_PROMOTION]		= {Message = governorPromotionString,		ToolTip = governorPromotionTooltip	, Icon="ICON_NOTIFICATION_GOVERNOR_PROMOTION_AVAILABLE"	};
g_kMessageInfo[EndTurnBlockingTypes.ENDTURN_BLOCKING_CONSIDER_DISLOYAL_CITY]	= {Message = considerDisloyalCityString,	ToolTip = considerDisloyalCityTooltip	, Icon="ICON_NOTIFICATION_CONSIDER_DISLOYAL_CITY"			};
g_kMessageInfo[EndTurnBlockingTypes.ENDTURN_BLOCKING_EMERGENCY_NEEDS_ATTENTION]	= {Message = EmergencyAttentionString,	ToolTip = EmergencyAttentionTooltip	, Icon="ICON_NOTIFICATION_TURNBLOCKER_EMERGENCY"			};
g_kMessageInfo[EndTurnBlockingTypes.ENDTURN_BLOCKING_COMMEMORATION_AVAILABLE]	= {Message = commemorationAvailableString,	ToolTip = commemorationAvailableTooltip	, Icon="ICON_NOTIFICATION_COMMEMORATION_AVAILABLE"			};


-- ===========================================================================
function OnRefresh()

	BASE_OnRefresh();

	local ePlayer = Game.GetLocalPlayer();
	if ePlayer == PlayerTypes.NONE then
		return;
	end

	local gameEras = Game.GetEras();
	local score	= gameEras:GetPlayerCurrentScore(ePlayer);
	local detailsString = Locale.Lookup("LOC_ERA_SCORE_HEADER") .. " " .. score;
	local isFinalEra:boolean = gameEras:GetCurrentEra() == gameEras:GetFinalEra();

	if not isFinalEra then
		detailsString = detailsString .. Locale.Lookup("LOC_DARK_AGE_THRESHOLD_TEXT", gameEras:GetPlayerDarkAgeThreshold(ePlayer));
		detailsString = detailsString .. Locale.Lookup("LOC_GOLDEN_AGE_THRESHOLD_TEXT", gameEras:GetPlayerGoldenAgeThreshold(ePlayer));
	end
	detailsString = detailsString .. "[NEWLINE][NEWLINE]";

	--Set our animation based on our current age
	if gameEras:HasHeroicGoldenAge(ePlayer) then
		Controls.TurnAgeAnimation:SetTexture("ActionPanel_TurnProcessing_Heroic");
		Controls.EndTurnButtonLabel:SetTexture("ActionPanel_TurnBlocker_Heroic");
		Controls.GoldenAgeAnimation:SetHide(false);
		Controls.DarkAgeShadow:SetHide(true);
		--Tooltip setup
		detailsString = detailsString .. Locale.Lookup("LOC_ERA_TT_HAVE_HEROIC_AGE_EFFECT");
	elseif gameEras:HasGoldenAge(ePlayer) then
		Controls.TurnAgeAnimation:SetTexture("ActionPanel_TurnProcessing_Golden");
		Controls.EndTurnButtonLabel:SetTexture("ActionPanel_TurnBlocker_Golden");
		Controls.GoldenAgeAnimation:SetHide(false);
		Controls.DarkAgeShadow:SetHide(true);
		--Tooltip setup
		detailsString = detailsString .. Locale.Lookup("LOC_ERA_TT_HAVE_GOLDEN_AGE_EFFECT");
	elseif gameEras:HasDarkAge(ePlayer) then
		Controls.TurnAgeAnimation:SetTexture("ActionPanel_TurnProcessing_Dark");
		Controls.EndTurnButtonLabel:SetTexture("ActionPanel_TurnBlocker_Dark");
		Controls.DarkAgeShadow:SetHide(false);
		Controls.GoldenAgeAnimation:SetHide(true);
		--Tooltip setup
		detailsString = detailsString .. Locale.Lookup("LOC_ERA_TT_HAVE_DARK_AGE_EFFECT");
	else
		Controls.TurnAgeAnimation:SetTexture("ActionPanel_TurnProcessing");
		Controls.EndTurnButtonLabel:SetTexture("ActionPanel_TurnBlocker");
		Controls.DarkAgeShadow:SetHide(true);
		Controls.GoldenAgeAnimation:SetHide(true);
		--Tooltip setup
		detailsString = detailsString ..Locale.Lookup("LOC_ERA_TT_HAVE_NORMAL_AGE_EFFECT");
	end
	
	--Set our bar state
	local baseline = gameEras:GetPlayerThresholdBaseline(ePlayer);
	local darkAgeThreshold = gameEras:GetPlayerDarkAgeThreshold(ePlayer);
	local goldenAgeThreshold = gameEras:GetPlayerGoldenAgeThreshold(ePlayer);
	local ageIconName = "[ICON_GLORY_NORMAL_AGE]";
	Controls.TurnTimerMeterWarning:SetHide(true);
	Controls.AgeLabelCurrent:SetColorByName("Age_Normal");
	if score >= darkAgeThreshold then
		--We are working towards, or scored Golden age
		ageIconName = gameEras:HasDarkAge(ePlayer) and "[ICON_GLORY_GOLDEN_AGE]" or "[ICON_GLORY_SUPER_GOLDEN_AGE]";
		if score >= goldenAgeThreshold then
			--Just working toward a golden age
			Controls.TurnTimerMeterGolden:SetTexture("ActionPanel_AgeMeterFill_Golden");
			Controls.AgeLabelCurrent:SetColorByName("Age_Golden");
		end
	else
		--Is the age ending? If so, show the red warning
		local eraCountdown = gameEras:GetNextEraCountdown() + 1; -- 0 turns remaining is the last turn, shift by 1 to make sense to non-programmers
		if eraCountdown ~= nil and eraCountdown ~= 0 then
			Controls.TurnTimerMeterWarning:SetHide(false);
			Controls.AgeLabelCurrent:SetColorByName("Age_Warning");
			ageIconName = "[ICON_GLORY_DARK_AGE]";
		end
	end

	Controls.AgeLabelCurrent:SetText(ageIconName .. score .. " ");
	Controls.AgeLabelTotal:SetText(" " .. (score > darkAgeThreshold and goldenAgeThreshold or darkAgeThreshold));
	local normalPercent = 1;
	if ((darkAgeThreshold - baseline) > 0) then -- If this is negative then our baseline is already past the threshold, so show the full meter
		normalPercent = (score - baseline) / (darkAgeThreshold - baseline);
	end
	Controls.TurnTimerMeterNormal:SetPercent(normalPercent);
	local goldenPercent = 1;
	if ((goldenAgeThreshold - darkAgeThreshold) ~= 0) then
		goldenPercent = (score - darkAgeThreshold) / (goldenAgeThreshold - darkAgeThreshold);
	end
	Controls.TurnTimerMeterGolden:SetPercent(goldenPercent);

	Controls.AgeScoreStack:CalculateSize();
	Controls.AgeButtonBG:SetSizeX(Controls.AgeScoreStack:GetSizeX() + 24);

	Controls.TurnAgeAnimation:Play();

	--Are we in the last age
	if isFinalEra then
		Controls.TurnTimerMeterBG:SetHide(true);
		Controls.TurnTimerMeterGolden:SetHide(true);
		Controls.TurnTimerMeterNormal:SetHide(true);
		Controls.TurnTimerMeterWarning:SetHide(true);
		Controls.AgeLabelTotal:SetHide(true);
		Controls.AgeLabelDivider:SetHide(true);
		Controls.AgeLabelCurrent:SetColorByName("Age_Normal");
		if gameEras:HasDarkAge() then
			Controls.AgeLabelCurrent:SetText("[ICON_GLORY_DARK_AGE]" .. score);
		elseif gameEras:HasGoldenAge() then
			Controls.AgeLabelCurrent:SetText("[ICON_GLORY_GOLDEN_AGE]" .. score);
		else
			Controls.AgeLabelCurrent:SetText("[ICON_GLORY_NORMAL_AGE]" .. score);
		end

	end

	--Tooltip
	local activeCommemorations = gameEras:GetPlayerActiveCommemorations(ePlayer);
	for i,activeCommemoration in ipairs(activeCommemorations) do
		local commemorationInfo = GameInfo.CommemorationTypes[activeCommemoration];
		detailsString = detailsString .. "[NEWLINE][NEWLINE][ICON_BULLET]";
		if (commemorationInfo ~= nil) then
			local bonusText = nil;
			if (gameEras:HasGoldenAge(ePlayer)) then
				bonusText = Locale.Lookup(commemorationInfo.GoldenAgeBonusDescription);
				if (gameEras:IsPlayerAlwaysAllowedCommemorationQuest(ePlayer)) then
					bonusText = bonusText .. "[NEWLINE][NEWLINE][ICON_BULLET]" .. Locale.Lookup(commemorationInfo.NormalAgeBonusDescription);
				end
			elseif (gameEras:HasDarkAge(ePlayer)) then
				bonusText = Locale.Lookup(commemorationInfo.DarkAgeBonusDescription);
			else
				bonusText = Locale.Lookup(commemorationInfo.NormalAgeBonusDescription);
			end
			if (bonusText ~= nil) then
				detailsString = detailsString .. bonusText;
			end
		end
	end
	
	Controls.AgeButtonBG:SetToolTipString(detailsString);

	RealizeEraIndicator();
end

-- ===========================================================================
-- Set the era rotation and tooltip.
-- ===========================================================================
function RealizeEraIndicator()
	local displayEra:number = 1;
	if (Game ~= nil and Game.GetEras() ~= nil) then
		displayEra = Game.GetEras():GetCurrentEra() + 1; -- Engine is 0 Based
	else
		UI.DataError("Unable to obtain eras from Game object while realizing ActionPanel.");
		return;
	end
	
	local gameEras :table = Game.GetEras();
	for _,kEra in pairs(g_kEras) do
		if kEra.Index == displayEra then
			local description:string = Locale.Lookup("LOC_GAME_ERA_DESC", kEra.Description );
			local turnsTill :number = gameEras:GetNextEraCountdown() + 1;	-- 0 turns remaining is the last turn, shift by 1 to make sense to non-programmers
			if turnsTill > 0 then
				 description = description .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_GLORY_HUD_ERA_ENDS_IN", turnsTill);
			end
			Controls.EraToolTipArea1:SetToolTipString( description );
			Controls.EraToolTipArea2:SetToolTipString( description );
			Controls.EraIndicator:Rotate( kEra.Degree + 90 );	-- 0 degree in art points "left"
			break;
		end		
	end
end

-- ===========================================================================
function OnAgeButtonClicked()
	LuaEvents.PartialScreenHooks_Expansion1_ToggleEraProgress();
end

-- ===========================================================================
function LateInitialize()
	BASE_LateInitialize();
	Controls.AgeButtonBG:RegisterCallback( Mouse.eLClick, OnAgeButtonClicked )
	ContextPtr:SetRefreshHandler(OnRefresh);
end