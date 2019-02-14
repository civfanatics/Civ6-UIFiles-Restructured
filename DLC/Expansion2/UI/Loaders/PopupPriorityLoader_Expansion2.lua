-- ===========================================================================
--	Initialize PopupPriority values for Expansion 2 functionality
-- ===========================================================================

local counter:number = 0;
function Increment()
	counter = counter + 1;
	return counter;
end

PopupPriority.WorldCongressIntro = PopupPriority.Medium + Increment();
PopupPriority.WorldCongressPopup = PopupPriority.Medium + Increment();
PopupPriority.WorldCongressBetweenTurns = PopupPriority.Medium + Increment();
