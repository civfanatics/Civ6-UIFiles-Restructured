--[[
-- Created by Keaton VanAuken on Aug 25 2017
-- Copyright (c) Firaxis Games
--]]

include("InstanceManager");

local ms_EmergencyRowEntryIM:table = InstanceManager:new( "EmergencyRowEntryInstance", "EmergencyRowEntryTop" );

-- ===========================================================================
function Refresh(selectedPlayerID:number)
	local localPlayerID:number = Game.GetLocalPlayer();

	ms_EmergencyRowEntryIM:ResetInstances();

	local crisisData = Game.GetEmergencyManager():GetEmergencyInfoTable(localPlayerID);
	for _, crisis in ipairs(crisisData) do
		if crisis.HasBegun then
			-- Determine if the selected player is participating in this emergency
			local selectedPlayerIsParticipating = false;
			if crisis.TargetID == selectedPlayerID then
				-- We are the target
				selectedPlayerIsParticipating = true;
			else
				for i, memberID in ipairs(crisis.MemberIDs) do
					if memberID == selectedPlayerID then
						-- We are a member
						selectedPlayerIsParticipating = true;
					end
				end
			end
		
			-- Only show emergencies that the selected player is participating in 
			if selectedPlayerIsParticipating then
				-- Show emergencies that target the local player
				if crisis.TargetID == localPlayerID or crisis.TargetID == selectedPlayerID then
					AddEmergencyRowEntry(crisis);
				else
					-- Show emergencies that involve the local player
					for i, memberID in ipairs(crisis.MemberIDs) do
						if memberID == localPlayerID then
							AddEmergencyRowEntry(crisis);
						end
					end
				end
			end
		end
	end
end

-- ===========================================================================
function AddEmergencyRowEntry( crisis:table )
	local entryInst:table = ms_EmergencyRowEntryIM:GetInstance( Controls.EmergencyStack );
	entryInst.EmergencyName:SetText(crisis.NameText);
	entryInst.EmergencyRowEntryTop:SetToolTipString(crisis.DescriptionText);
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetAutoSize(true);

	LuaEvents.DiploScene_RefreshOverviewRows.Add(Refresh);
end
Initialize();