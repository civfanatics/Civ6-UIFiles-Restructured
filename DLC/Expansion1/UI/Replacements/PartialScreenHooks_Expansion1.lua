-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("PartialScreenHooks");

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_AddScreenHooks = AddScreenHooks;
BASE_IsPartialScreenOpen = IsPartialScreenOpen;

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local isEraProgressPanelOpen:boolean = false;

-- ===========================================================================
function IsPartialScreenOpen( optionalScreenName:string )
	-- Check EraProgressPanel
	if (optionalScreenName == nil or optionalScreenName == "EraProgressPanel") and isEraProgressPanelOpen then
		return true;
	elseif optionalScreenName == "EraProgressPanel" then
		return false;
	end

	-- Check base game screens
	return BASE_IsPartialScreenOpen(optionalScreenName);
end

-- ===========================================================================
function AddScreenHooks()
	BASE_AddScreenHooks();

	AddScreenHook("LaunchBar_Hook_Era", "LOC_PARTIALSCREEN_ERA_PROGRESS_TOOLTIP", OnToggleEraProgress);
end

-- ===========================================================================
function OnToggleEraProgress()
	if IsPartialScreenOpen("EraProgressPanel") then
		LuaEvents.PartialScreenHooks_CloseEraProgressPanel();
	else		
		if IsPartialScreenOpen() then				-- Only play open sound if no partial screen is open.
			LuaEvents.PartialScreenHooks_CloseAllExcept("EraProgressPanel");
		end		
		LuaEvents.PartialScreenHooks_OpenEraProgressPanel();
	end	
end

-- ===========================================================================
function OnEraProgressPanelOpen()
	isEraProgressPanelOpen = true;
end

-- ===========================================================================
function OnEraProgressPanelClose()
	isEraProgressPanelOpen = false;
end

-- ===========================================================================
function Initialize()
	LuaEvents.EraProgressPanel_Open.Add( OnEraProgressPanelOpen );
	LuaEvents.EraProgressPanel_Close.Add( OnEraProgressPanelClose );
	LuaEvents.PartialScreenHooks_Expansion1_ToggleEraProgress.Add( OnToggleEraProgress );
end
Initialize();