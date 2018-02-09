-- ===========================================================================
--	World Input
--	Copyright 2015-2016, Firaxis Games
--
--	Handle edge scrolling functionality
--
--	This is separate from WorldInput because it should take precedence over
--  many in-game panels for input, while WorldInput should only take input
--  when no other controls are consuming input

-- ===========================================================================
local PAN_SPEED	 : number = 1;
local m_edgePanX : number = 0;
local m_edgePanY : number = 0;

-- ===========================================================================
function ProcessPan( panX :number, panY :number )
	-- TODO this is no longer incorporated with the
	-- arrow key movement in WorldInput.lua, does
	-- it need to be or is it fine as-is?
	UI.PanMap( panX, panY );
end

-- ===========================================================================
function IsAbleToEdgePan()
	return UserConfiguration.IsEdgePanEnabled() or ( (UI.GetInterfaceMode() == InterfaceModeTypes.SELECTION) and m_isMouseButtonRDown );
end

-- ===========================================================================
function OnMouseBeginPanLeft()
	if IsAbleToEdgePan() then
		m_edgePanX = -PAN_SPEED;
		ProcessPan(m_edgePanX,m_edgePanY);
	end
end

function OnMouseStopPanLeft()
	if not ( m_edgePanX == 0.0 ) then
		m_edgePanX = 0.0;
		ProcessPan(m_edgePanX,m_edgePanY);
	end
end

function OnMouseBeginPanRight()
	if IsAbleToEdgePan() then
		m_edgePanX = PAN_SPEED;
		ProcessPan(m_edgePanX,m_edgePanY);
	end
end

function OnMouseStopPanRight()
	if not ( m_edgePanX == 0.0 ) then
		m_edgePanX = 0;
		ProcessPan(m_edgePanX,m_edgePanY);
	end
end

function OnMouseBeginPanUp()
	if IsAbleToEdgePan() then
		m_edgePanY = PAN_SPEED;
		ProcessPan(m_edgePanX,m_edgePanY);
	end
end

function OnMouseStopPanUp()
	if not ( m_edgePanY == 0.0 ) then
		m_edgePanY = 0;
		ProcessPan(m_edgePanX,m_edgePanY);
	end
end

function OnMouseBeginPanDown()
	if IsAbleToEdgePan() then
		m_edgePanY = -PAN_SPEED;
		ProcessPan(m_edgePanX,m_edgePanY);
	end
end

function OnMouseStopPanDown()
	if not ( m_edgePanY == 0.0 ) then
		m_edgePanY = 0;
		ProcessPan(m_edgePanX,m_edgePanY);
	end
end

-- ===========================================================================
function Initialize()
	Controls.LeftScreenEdge:RegisterMouseEnterCallback( OnMouseBeginPanLeft );
	Controls.LeftScreenEdge:RegisterMouseExitCallback( OnMouseStopPanLeft );
	Controls.RightScreenEdge:RegisterMouseEnterCallback( OnMouseBeginPanRight );
	Controls.RightScreenEdge:RegisterMouseExitCallback( OnMouseStopPanRight );
	Controls.TopScreenEdge:RegisterMouseEnterCallback( OnMouseBeginPanUp );
	Controls.TopScreenEdge:RegisterMouseExitCallback( OnMouseStopPanUp );
	Controls.BottomScreenEdge:RegisterMouseEnterCallback( OnMouseBeginPanDown );
	Controls.BottomScreenEdge:RegisterMouseExitCallback( OnMouseStopPanDown );
end
Initialize();