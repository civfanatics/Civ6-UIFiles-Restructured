g_SelectedUnitID = -1;
-------------------------------------------------------------------------------
function GetSelectedUnit()
	if (g_SelectedUnitID >= 0) then
		local pPlayer = Players[0];
		if pPlayer ~= nil then
			local pUnit = pPlayer:GetUnits():FindID(g_SelectedUnitID);
			return pUnit;
		end
	end
	return nil;
end
-------------------------------------------------------------------------------
print("Heroes Panel Loaded");