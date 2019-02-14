-- ===========================================================================
--	Initialize PopupPriority values for Civ 6 functionality
-- ===========================================================================

local counter:number = 0;
function Increment()
	counter = counter + 1;
	return counter;
end

PopupPriority.HotSeatBackground = PopupPriority.Utmost + Increment();
PopupPriority.PausePanel = PopupPriority.Utmost + Increment();
PopupPriority.EndGameMenu = PopupPriority.Utmost + Increment(); 
PopupPriority.PlayerChange = PopupPriority.Utmost + Increment();
PopupPriority.InGameTopOptionsMenu = PopupPriority.Utmost + Increment();
