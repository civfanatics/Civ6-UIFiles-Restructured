------------------------------------------------------------------------------
--	Common LUA support functions for helping with user actions
------------------------------------------------------------------------------

-- ===========================================================================
function IsLocalPlayerTurnActive()
	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer ~= -1) then
		local pPlayer = Players[localPlayer];
		if pPlayer ~= nil and pPlayer:IsTurnActive() then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
function CanLocalPlayerSaveGame()
	if UI.HasFeature("Saving") then
		-- World Builder doesn't rely on having a valid local player
		if WorldBuilder:IsActive() then
			return true;
		end

		local localPlayerID = Game.GetLocalPlayer();
		if(localPlayerID == PlayerTypes.NONE or not PlayerConfigurations[localPlayerID]:IsAlive()) then
			return false;
		elseif GameConfiguration.IsNetworkMultiplayer() or IsLocalPlayerTurnActive() then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
function CanLocalPlayerLoadGame()
	if UI.HasFeature("Loading") then
		if IsLocalPlayerTurnActive() 
			and not GameConfiguration.IsNetworkMultiplayer() then -- Mechanically, players have to load multiplayer games from the front end.
			return true;
		end
	end
	return false;
end

-- ===========================================================================
function CanLocalPlayerChangeOptions()
	if UI.HasFeature("Options") then
		return true;
	end
	return false;
end
