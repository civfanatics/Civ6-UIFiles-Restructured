-- Copyright 2018, Firaxis Games
-- Grievances Log and other World Congress information to show in Diplomacy View

include("InstanceManager");
include("CivilizationIcon");


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local debug_addFakeValues	:boolean = false;		-- (false) Change to true for fake values
local m_grievanceIM			:table = InstanceManager:new( "GrievanceInstance", "Top", Controls.MainGrievanceTabStack );
local m_kLogEntries			:table = nil;
local SORT_TYPES:table = {
								TURN_ASECENDING = 1,
								TURN_DESCENDING = 2,
								AMOUNT_ASECENDING = 3,
								AMOUNT_DESCENDING = 4
							}
local GRIEVANCE_DIRECTION:table = {
								NO_DIRECTION = 0,
								AGAINST_YOU = 1,
								AGAINST_THEM = -1
							}
local m_sortBy				:number = SORT_TYPES.TURN_DESCENDING;
local m_grievanceTotal:number = 0;
local m_grievancePerTurn:number = 0;
local m_targetPlayer:number = -1;
local m_grievanceDirection:number = NO_DIRECTION;
local m_tooltipString:string = "";
local m_TargetName:string = "";

-- ===========================================================================
function OnRefreshTabs( selectedPlayerID:number )

	local localPlayerID		:number= Game.GetLocalPlayer();
	local kGameDiplomacy	:table = Game.GetGameDiplomacy();
	local kLocalPlayer		:table = Players[localPlayerID];
	local kPlayerDiplomacy	:table = kLocalPlayer:GetDiplomacy();	
	local kSelectedPlayer	:table = Players[selectedPlayerID];
	local kPlayerConfig		:table = PlayerConfigurations[selectedPlayerID];
	local totalGrievances	:number = kPlayerDiplomacy:GetGrievancesAgainst(selectedPlayerID);
	
	m_kLogEntries = kGameDiplomacy:GetGrievanceLogEntries(selectedPlayerID, localPlayerID);
	if kPlayerConfig ~= nil then
		m_TargetName = kPlayerConfig:GetCivilizationShortDescription();
	else
		UI.DataError("Player Config not found for Grievance Tab in Diplomacy, selectedPlayerID = " .. selectedPlayerID .. " assign @tyler.berry");
	end

	if debug_addFakeValues then
		for i=1,20,1 do
			table.insert(m_kLogEntries, 
				{
					Target = 0,
					Initiator = 0,
					Amount = i*13,
					Turn = i*37,
					Description = "Within the Czech Republic, temperatures vary greatly, depending on the elevation. In general, at higher altitudes, the temperatures decrease and precipitation increases."	
				}
			);
		end
		m_grievancePerTurn = 12.3;
		m_grievanceTotal = 207;
		m_grievanceDirection = GRIEVANCE_DIRECTION.AGAINST_YOU;
	end

	if totalGrievances == 0 then
		m_grievanceDirection = GRIEVANCE_DIRECTION.NO_DIRECTION;
	elseif totalGrievances > 0 then
		m_grievanceDirection = GRIEVANCE_DIRECTION.AGAINST_THEM;
	else
		m_grievanceDirection = GRIEVANCE_DIRECTION.AGAINST_YOU;
		totalGrievances = -totalGrievances;
	end
	m_targetPlayer = selectedPlayerID;
	m_grievanceTotal = totalGrievances;
	m_grievancePerTurn = kGameDiplomacy:GetGrievanceChangePerTurn(selectedPlayerID, localPlayerID);
	m_tooltipString = kGameDiplomacy:GetGrievanceChangeTooltip(selectedPlayerID, localPlayerID);

	Realize();
end

-- ===========================================================================
function Realize()
	local kSortedEntries	:table = {};

	for i,kEntry in ipairs(m_kLogEntries) do
		table.insert(kSortedEntries,kEntry);
	end

	if m_sortBy == SORT_TYPES.TURN_DESCENDING then
		table.sort(kSortedEntries, function(a,b) return a.Turn > b.Turn; end);
	elseif m_sortBy ==  SORT_TYPES.AMOUNT_DESCENDING then
		table.sort(kSortedEntries, function(a,b) return a.Amount < b.Amount; end);
	elseif m_sortBy ==  SORT_TYPES.AMOUNT_ASECENDING then
		table.sort(kSortedEntries, function(a,b) return a.Amount > b.Amount; end);
	else
		table.sort(kSortedEntries, function(a,b) return a.Turn < b.Turn; end);
	end

	m_grievanceIM:ResetInstances();

	local isEmpty:boolean = (table.count(kSortedEntries)==0);
	local grievanceDescriptorKey:string = "LOC_GRIEVANCE_LOG_DESCRIPTION";
	Controls.ListHeader:SetHide( isEmpty );
	Controls.NoGrievances:SetHide( not isEmpty );
	Controls.AgainstYouValue:SetColorByName("White");
	Controls.AgainstYouPerTurn:SetColorByName("White");
	
	if m_grievanceDirection == GRIEVANCE_DIRECTION.AGAINST_THEM then
		Controls.AgainstYouValue:SetText("0");
		Controls.AgainstYouPerTurn:SetHide(true);
		Controls.AgainstYouIcon:SetHide(true);
		Controls.AgainstThemIcon:SetHide(false);
		Controls.AgainstThemValue:SetText(m_grievanceTotal);
		Controls.AgainstThemPerTurn:SetHide(false);
		Controls.AgainstThemPerTurn:SetText(Locale.Lookup("{1: number +#,###.#;-#,###.#}", m_grievancePerTurn));
		Controls.GrievanceDescription:SetText(Locale.Lookup("LOC_GRIEVANCE_LOG_DESCRIPTION_POSITIVE", m_TargetName, m_grievanceTotal));	
		Controls.WorldFavorite:SetText(Locale.Lookup("LOC_GRIEVANCE_LOG_WORLD_FAVORS_YOU"));
		Controls.AgainstThemPerTurn:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_GRIEVANCES_WITH_THEM_SIMPLE", m_grievanceTotal) .. "[NEWLINE][NEWLINE]" .. m_tooltipString);
	elseif m_grievanceDirection == GRIEVANCE_DIRECTION.AGAINST_YOU then
		Controls.AgainstThemValue:SetText("0");
		Controls.AgainstThemPerTurn:SetHide(true);
		Controls.AgainstThemIcon:SetHide(true);
		Controls.AgainstYouIcon:SetHide(false);
		Controls.AgainstYouValue:SetColorByName("Red");
		Controls.AgainstYouPerTurn:SetColorByName("Red");
		Controls.AgainstYouValue:SetText(m_grievanceTotal);
		Controls.AgainstYouPerTurn:SetHide(false);
		Controls.AgainstYouPerTurn:SetText(Locale.Lookup("{1: number +#,###.#;-#,###.#}", m_grievancePerTurn));
		Controls.GrievanceDescription:SetText(Locale.Lookup("LOC_GRIEVANCE_LOG_DESCRIPTION_NEGATIVE", m_TargetName, m_grievanceTotal));	
		Controls.WorldFavorite:SetText(Locale.Lookup("LOC_GRIEVANCE_LOG_WORLD_FAVORS", m_TargetName));
		Controls.AgainstYouPerTurn:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_GRIEVANCES_WITH_US_SIMPLE", m_grievanceTotal) .. "[NEWLINE][NEWLINE]" .. m_tooltipString);
	else
		Controls.AgainstYouIcon:SetHide(true);
		Controls.AgainstThemIcon:SetHide(true);
		Controls.AgainstThemPerTurn:SetHide(true);
		Controls.AgainstYouPerTurn:SetHide(true);
		Controls.AgainstThemPerTurn:SetText("0");
		Controls.AgainstYouPerTurn:SetText("0");
		Controls.AgainstYouValue:SetText("0");
		Controls.AgainstThemValue:SetText("0");	
		Controls.GrievanceDescription:SetText(Locale.Lookup("LOC_GRIEVANCE_LOG_DESCRIPTION_DEFAULT", m_TargetName, m_grievanceTotal));	
		Controls.WorldFavorite:SetText(Locale.Lookup("LOC_GRIEVANCE_LOG_WORLD_FAVORS_NONE"));
		Controls.AgainstThemPerTurn:SetToolTipType();
		Controls.AgainstThemPerTurn:ClearToolTipCallback();
		Controls.AgainstYouPerTurn:SetToolTipType();
		Controls.AgainstYouPerTurn:ClearToolTipCallback();
	end

	local uiGrievance :table = nil;
	local localPlayerID		:number= Game.GetLocalPlayer();
	for i,kEvent in ipairs( kSortedEntries ) do
		uiGrievance = m_grievanceIM:GetInstance();
		uiGrievance.Amount:SetText( tostring( kEvent["Amount"] ));
		uiGrievance.Amount:SetColorByName(kEvent["Initiator"] == localPlayerID and "Red" or "White");
		uiGrievance.Turn:SetText( "[ICON_Turn]" .. tostring( kEvent["Turn"] ));
		uiGrievance.Description:SetText( tostring( kEvent["Description"] ));
		local civIconManager:table = CivilizationIcon:AttachInstance(uiGrievance.Initiator);
		civIconManager:UpdateIconFromPlayerID(kEvent["Initiator"]);
	end
end

-- ===========================================================================
function OnChangeSortByTurn()
	if m_sortBy == SORT_TYPES.TURN_DESCENDING then
		m_sortBy = SORT_TYPES.TURN_ASECENDING;
	else
		m_sortBy = SORT_TYPES.TURN_DESCENDING;	
	end
	Realize();
end

-- ===========================================================================
function OnChangeSortByAmount()
	if m_sortBy == SORT_TYPES.AMOUNT_DESCENDING then
		m_sortBy = SORT_TYPES.AMOUNT_ASECENDING;
	else
		m_sortBy = SORT_TYPES.AMOUNT_DESCENDING;	
	end
	Realize();
end

-- ===========================================================================
function Initialize()		
	Controls.TurnTextButton:RegisterCallback( Mouse.eLClick, OnChangeSortByTurn )
	Controls.GrievanceTextButton:RegisterCallback( Mouse.eLClick, OnChangeSortByAmount )
	
	LuaEvents.DiploScene_RefreshTabs.Add( OnRefreshTabs );

	ContextPtr:SetAutoSize(true);
end
Initialize();