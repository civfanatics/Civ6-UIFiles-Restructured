-- ===========================================================================
--	Input Support
--	Includes globals and utility functions for hot keys.
-- ===========================================================================

-- Action Contexts
InputContext = 
{
	Universal		= 0,
	Startup			= 0x0001,	-- Start movie, EULA, etc...
	Shell			= 0x0002,	-- Main menu, options, credits...
	Loading			= 0x0004,	-- Loading (no actions)
	Ready			= 0x0008,	-- Loading complete, only action is going into game
	World			= 0x0010,	-- Main in-game world
	Diplomacy		= 0x0020,	-- Talking with leader
	GameOptions		= 0x0040,	-- In-game options menu (aka: Pause Menu)	
	EndGame			= 0x0080,	-- Win/Defeat
	Popup			= 0x0100,	-- Popup with limited option(s)
	Reveal			= 0x0200,	-- On full-screen reveal (e.g., wonder, disaster, etc...)
	FullscreenMap	= 0x0400,	-- On full-screen map state
	Tutorial		= 0x1000	-- On rails tutorial	
}
