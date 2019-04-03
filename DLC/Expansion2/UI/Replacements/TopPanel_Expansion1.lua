-- Copyright 2018-2019, Firaxis Games
include( "TopPanel" );

-- ===========================================================================
--	OVERRIDES
-- ===========================================================================
BASE_LateInitialize = LateInitialize;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function RealizeEraBacking()
	local kEras			:table = Game.GetEras();
	local localPlayerID	:number = Game.GetLocalPlayer();

	if localPlayerID == PlayerTypes.NONE then
		Controls.Backing:SetTexture("TopBar_Bar");
	else
		local pGameEras:table = Game.GetEras();
		if kEras:HasHeroicGoldenAge(localPlayerID) then
			Controls.Backing:SetTexture("TopBar_Bar_Heroic");
		elseif kEras:HasGoldenAge(localPlayerID) then
			Controls.Backing:SetTexture("TopBar_Bar_Golden");
		elseif kEras:HasDarkAge(localPlayerID) then
			Controls.Backing:SetTexture("TopBar_Bar_Dark");
		else
			Controls.Backing:SetTexture("TopBar_Bar");
		end
	end
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnLocalPlayerTurnBegin()
	RealizeEraBacking();
end

-- ===========================================================================
function LateInitialize()
	BASE_LateInitialize();
	Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin );
	RealizeEraBacking();
	if not XP1_LateInitialize then
		RefreshYields();
	end
end
