include( "TopPanel" );

function OnLocalPlayerTurnBegin()
	local eraTable:table = Game.GetEras();
	local localPlayerID:number = Game.GetLocalPlayer();

	if localPlayerID == PlayerTypes.NONE then
		Controls.Backing:SetTexture("TopBar_Bar");
	else
		if eraTable:HasHeroicGoldenAge(localPlayerID) then
			Controls.Backing:SetTexture("TopBar_Bar_Heroic");
		elseif eraTable:HasGoldenAge(localPlayerID) then
			Controls.Backing:SetTexture("TopBar_Bar_Golden");
		elseif eraTable:HasDarkAge(localPlayerID) then
			Controls.Backing:SetTexture("TopBar_Bar_Dark");
		else
			Controls.Backing:SetTexture("TopBar_Bar");
		end
	end
end

function Initialize()
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	OnLocalPlayerTurnBegin();
end
Initialize();