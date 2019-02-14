--[[
-- Created by Keaton VanAuken on Aug 25 2017
-- Copyright (c) Firaxis Games
--]]

include("InstanceManager");

local ms_EmergencyTabEntryIM:table = InstanceManager:new( "EmergencyTabEntryInstance", "EmergencyTabEntryTop" );

-- ===========================================================================
function Refresh(selectedPlayerID:number)
	local localPlayerID:number = Game.GetLocalPlayer();

	ms_EmergencyTabEntryIM:ResetInstances();

	local crisisData = Game.GetEmergencyManager():GetEmergencyInfoTable(localPlayerID);
	local foundTargeted = 0;
	local foundParticipating = 0;
	for _, crisis in ipairs(crisisData) do
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
			if crisis.TargetID == localPlayerID then
				AddEmergencyTabEntry(crisis, Controls.EmergencyTargetingYouStack);
				foundTargeted = foundTargeted + 1;
			else
				-- Show emergencies that involve the local player
				for i, memberID in ipairs(crisis.MemberIDs) do
					if memberID == localPlayerID then
						AddEmergencyTabEntry(crisis, Controls.EmergencyParticipatingYouStack);
						foundParticipating = foundParticipating + 1;
					end
				end
			end
		end

		Controls.EmergencyParticipatingYouStack:SetHide(foundParticipating == 0);
		Controls.EmergencyTargetingYouStack:SetHide(foundTargeted == 0);

	end
end

-- ===========================================================================
function AddEmergencyTabEntry( crisis:table, parentControl:table )
	local entryInst:table = ms_EmergencyTabEntryIM:GetInstance( parentControl );
	entryInst.EmergencyNameLabel:LocalizeAndSetText(crisis.NameText);
	entryInst.EmergencyGoalsLabel:SetText(crisis.GoalDescription);

	-- If TurnsLeft < 0 emergency is completed so label it as such
	if crisis.TurnsLeft >= 0 then
		entryInst.EmergencyTurnsIcon:SetHide(false);
		entryInst.EmergencyTurnsLabel:SetText(crisis.TurnsLeft);
	else
		entryInst.EmergencyTurnsIcon:SetHide(true);
		entryInst.EmergencyTurnsLabel:SetText(Locale.Lookup("LOC_EMERGENCY_TAB_COMPLETED"));
	end
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetAutoSize(true);

	LuaEvents.DiploScene_RefreshTabs.Add(Refresh);
end
Initialize();