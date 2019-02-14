-- ===========================================================================
--	HUD Partial Screen Hooks XP2
--	Hooks to buttons in the upper right of the main screen HUD.
--	MyScreen left in as sample to wire up subsequent screens.
-- ===========================================================================


-- ===========================================================================
-- INCLUDE XP1 FILE
-- ===========================================================================
include("PartialScreenHooks_Expansion1");


-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
XP1_IsPartialScreenOpen		= IsPartialScreenOpen;
XP1_LateInitialize			= LateInitialize;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_isMyScreenOpen :boolean = false;

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function IsPartialScreenOpen( optionalScreenName:string )

	if (optionalScreenName == nil or optionalScreenName == "MyScreen") and m_isMyScreenOpen then		
		return true;
	elseif optionalScreenName == "MyScreen" then
		return false;
	end

	return XP1_IsPartialScreenOpen( optionalScreenName );
end


-- ===========================================================================
function OnToggleMyScreen()
	if IsPartialScreenOpen("MyScreen") then
		LuaEvents.PartialScreenHooks_CloseMyScreen();
	else		
		-- If any partial screen is open; close it and then open the Climate screen.
		if IsPartialScreenOpen() then
			LuaEvents.PartialScreenHooks_CloseAllExcept("MyScreen");
		end		
		LuaEvents.PartialScreenHooks_OpenMyScreen();
	end	
end

-- ===========================================================================
function OnMyScreenOpen()
	m_isMyScreenOpen = true;
end

-- ===========================================================================
function OnMyScreenClose()
	m_isMyScreenOpen = false;
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function LateInitialize()
	XP1_LateInitialize();
	LuaEvents.MyScreen_Opened.Add( OnMyScreenOpen );
	LuaEvents.MyScreen_Closed.Add( OnMyScreenClose );
	LuaEvents.PartialScreenHooks_Expansion2_MyScreen.Add( OnToggleMyScreen );
end