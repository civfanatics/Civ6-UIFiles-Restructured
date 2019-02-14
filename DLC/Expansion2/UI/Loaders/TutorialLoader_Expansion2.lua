
-- ===========================================================================
--
--	Tutorial items related to expansion 2
--
-- ===========================================================================

-- Add to tutorial loaders referenced by TutorialUIRoot
local TutorialLoader = {};
table.insert(g_TutorialLoaders, TutorialLoader);

-- Map of checks to run when a given Tech is unlocked
local m_TechUnlockedCheckMap : table = {};
m_TechUnlockedCheckMap["TECH_ELECTRICITY"] = { 
	"UnlockedCleanPowerTech",	-- Hydroelectric Dam Building
	"UnlockedDirtyPowerTech",	-- Fossil Fuel Plant Building
	-- NOTE: though Clean and Dirty advisor texts conflict, in normal play the tech tree
	--	layout prevents these from triggering on the same tech. Both hooks are maintained 
	--	for abnormal play conditions such as Advanced Start.
};
m_TechUnlockedCheckMap["TECH_INDUSTRIALIZATION"] = { 
	"UnlockedDirtyPowerTech",	-- Coal Plant Building
};
m_TechUnlockedCheckMap["TECH_NUCLEAR_FISSION"] = { 
	"UnlockedDirtyPowerTech",	-- Nuclear Plant Building
};
m_TechUnlockedCheckMap["TECH_SYNTHETIC_MATERIALS"] = { 
	"UnlockedCleanPowerTech",	-- Geothermal Plant Improvement
};
m_TechUnlockedCheckMap["TECH_SATELLITES"] = { 
	"UnlockedCleanPowerTech",	-- Solar Plant Improvement
};
m_TechUnlockedCheckMap["TECH_COMPOSITES"] = { 
	"UnlockedCleanPowerTech",	-- Wind Farm Improvement
};
m_TechUnlockedCheckMap["TECH_SEASTEADS"] = { 
	"UnlockedCleanPowerTech",	-- Offshore Wind Farm Improvement
};
m_TechUnlockedCheckMap["TECH_STEAM_POWER"] = {
	"UnlockedCanalsTech",
	"UnlockedRailroadsTech",
};
m_TechUnlockedCheckMap["TECH_CHEMISTRY"] = {
	"UnlockedMountainRouteTech",
};
m_TechUnlockedCheckMap["TECH_BUTTRESS"] = {
	"UnlockedDamsTech",
};

-- Map of checks to run when a given Civic is unlocked
local m_CivicUnlockedCheckMap : table = {};

m_CivicUnlockedCheckMap["CIVIC_COLD_WAR"] = {
	"RockBandAvailable",
};

-- ===========================================================================
function TutorialLoader:Initialize(TutorialCheck:ifunction)	
	-- Register game core events
	local iPlayerID : number = Game.GetLocalPlayer();
	if (iPlayerID < 0) then
		return;
	end

	local pPlayer = Players[iPlayerID];
	local pPlayerConfig : table = PlayerConfigurations[iPlayerID]

	-- Update Lookup Tables --

	-- Techs and Civics for Information Era can trigger 'FutureEraImminent'
	for row in GameInfo.Technologies() do
		if (row.EraType == "ERA_INFORMATION") then
			local checkTable : table = m_TechUnlockedCheckMap[row.TechnologyType] or {};
			table.insert(checkTable, "FutureEraImminent");
			m_TechUnlockedCheckMap[row.TechnologyType] = checkTable;
		end
	end
	for row in GameInfo.Civics() do
		if (row.EraType == "ERA_INFORMATION") then
			local checkTable : table = m_CivicUnlockedCheckMap[row.CivicType] or {};
			table.insert(checkTable, "FutureEraImminent");
			m_CivicUnlockedCheckMap[row.CivicType] = checkTable;
		end
	end

	-- Cache prereq techs for Buildings that require Power
	for row in GameInfo.Buildings_XP2() do
		if (row.RequiredPower ~= nil and row.RequiredPower > 0) then
			local sPrereqTech : string = GameInfo.Buildings[row.BuildingType].PrereqTech;
			if (sPrereqTech ~= nil) then
				local checkTable : table = m_TechUnlockedCheckMap[sPrereqTech] or {};
				table.insert(checkTable, "FirstPowerRequiredBuildable");
				m_TechUnlockedCheckMap[sPrereqTech] = checkTable;
			end
		end
	end

	-- Cache Civ-unique items
	local sLeaderName : string = pPlayerConfig:GetLeaderTypeName();
	if (sLeaderName == "LEADER_PACHACUTI") then
		-- Qhapaq Nan (unique mountain route)
		local checkTable : table = m_CivicUnlockedCheckMap["CIVIC_FOREIGN_TRADE"] or {};
		table.insert(checkTable, "UnlockedQhpaqNan");
		m_CivicUnlockedCheckMap["CIVIC_FOREIGN_TRADE"] = checkTable;
	end

	------------------
	Events.EmergencyStarted.Add(function( playerID, eTargetPlayer, iTurn)
		local isHostile: boolean = GameInfo.Emergencies_XP2[eTargetPlayer].Hostile;
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID ~= localPlayerID) then 
			if (isHostile) then
				TutorialCheck("EmergencyTriggerHostile");
			else
				TutorialCheck("EmergencyTriggerNonHostile");
			end
		end
	end);

	------------------
	Events.WorldCongressStage1.Add(function( playerID:number )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("IntroToWorldCongress");
		end
	end);

	------------------
	Events.WorldCongressStage2.Add(function( playerID:number )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("WorldCongressStage2");
		end
	end);

	------------------
	Events.WorldCongressSpecialSessionBeingCalled.Add(function( playerID:number )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("WorldCongressSpecialIncomingCanPropose");
		end
	end);

	------------------
	Events.WorldCongressEmergencyReady.Add(function( playerID:number )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("WorldCongressEmergencyAvailable");
		end
	end);

	------------------
	Events.WorldCongressFinished.Add(function()
		TutorialCheck("WorldCongressFinished");
	end);

	------------------
	Events.GameEraChanged.Add(function(prevEraIndex:number, newEraIndex:number)
		if (newEraIndex == GameInfo.GlobalParameters["WORLD_CONGRESS_INITIAL_ERA"]) then
			TutorialCheck("WorldCongressInitialEra");
		end
	end);
	
	------------------
	Events.CityPowerChanged.Add(function(playerID:number, cityID:number)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then

			local pCity = CityManager.GetCity(player, cityID);
			if (pCity ~= nil) then
				if (pCity:GetPower():IsFullyPowered() == false) then
					m_CityID = { Player = playerID, City = cityID };
					TutorialCheck("CityUnpowered");
				end
			end
		end
	end);

	----------------------
	Events.PlayerResourceChanged.Add(function(playerID:number, resourceID:number)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID and resourceID >= 0) then
			if (GameInfo.Resources[resourceID].ResourceClassType == "RESOURCECLASS_STRATEGIC") then
				TutorialCheck("FirstStrategicResourceEarned");
			end
		end
	end);

	----------------------
	Events.UnitAddedToMap.Add(function(playerID:number, unitID:number, plotX:number, plotY:number)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			local unitType : string = GetUnitType(playerID, unitID)
			if (GameInfo.Units_XP2[unitType] ~= nil) then
				if (GameInfo.Units_XP2[unitType].ResourceMaintenanceAmount > 0) then
					TutorialCheck("UnitRequiresFuelBuilt");
				end
			end			
		end
	end);

	----------------------
	--Events.BuildingAddedToMap.Add(function( plotX:number, plotY:number, buildingID:number )		
		--local plotOwner:number = Map.GetPlot( plotX, plotY ):GetOwner();
		--if (plotOwner == Game.GetLocalPlayer()) then
			----Add as necessary
		--end
	--end);

	------------------
	Events.CityProjectCompleted.Add(function(playerID:number, cityID:number, projectID:number)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			if (projectID == GameInfo.Projects["PROJECT_LAUNCH_MARS_BASE"].Index) then
				TutorialCheck("ExoplanetProjectAvailable");
			elseif (projectID == GameInfo.Projects["PROJECT_LAUNCH_EXOPLANET_EXPEDITION"].Index) then
				TutorialCheck("ExoplanetSupportProjectsAvailable");
			end
		end
	end);

	------------------
	-- Tech Unlocked checks
	LuaEvents.TechCivicCompletedPopup_TechShown.Add(function(playerID:number, techType:string)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then						
			-- Run any checks stored in the Tech Unlocked map			
			if (m_TechUnlockedCheckMap[techType] ~= nil) then
				for _, sCheckFunction : string in pairs(m_TechUnlockedCheckMap[techType]) do
					if (sCheckFunction ~= nil) then
						TutorialCheck(sCheckFunction);
					end
				end
			end
		end
	end);

	------------------
	-- Civic Unlocked checks
	LuaEvents.TechCivicCompletedPopup_CivicShown.Add(function(playerID:number, civicType:string)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then			
			-- Run any checks stored in the Civic Unlocked map
			if (m_CivicUnlockedCheckMap[civicType] ~= nil) then
				for _, sCheckFunction : string in pairs(m_CivicUnlockedCheckMap[civicType]) do
					if (sCheckFunction ~= nil) then
						TutorialCheck(sCheckFunction);
					end
				end
			end
		end
	end);

	------------------
	-- Environmental Reveals
	Events.FloodplainRevealed.Add(function(locX:number, locY:number, playerID:number)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("RevealFirstFloodplain");
		end
	end);

	Events.VolcanoRevealed.Add(function(locX:number, locY:number, playerID:number)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("RevealFirstVolcano");
		end
	end);

	Events.GeothermalFissureRevealed.Add(function(locX:number, locY:number, playerID:number)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("RevealFirstGeothermalFissure");
		end
	end);

	Events.PowerGeneratedFromResource.Add(function(playerID:number, eResource:number)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("ConsumeFirstPowerResource");
		end
	end);

	Events.CityInitialized.Add(function( playerID:number, cityID:number )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			local pPlayer = Players[playerID];
			local pPlayerCities:table = pPlayer:GetCities();

			if(pPlayerCities:GetCount() >= 2) then
				local pCity = CityManager.GetCity(playerID, cityID);
				if (pCity ~= nil) then

					local kCityPlots:table = Map.GetCityPlots():GetPurchasedPlots(pCity);
					if (kCityPlots ~= nil) then
						for _,plotID in pairs(kCityPlots) do

							local kPlot:table =  Map.GetPlotByIndex(plotID);
							if(kPlot ~= nil) then

								local eCoastalLowlandType:number = TerrainManager.GetCoastalLowlandType(kPlot);
								if eCoastalLowlandType > -1 then
									TutorialCheck("CoastalLowlands");
								end
							end
						end
					end
				end
			end
		end
	end);

	------------------
	Events.PlayerTurnActivated.Add(function( playerID:number, isFirstTimeThisTurn:boolean )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID and isFirstTimeThisTurn) then
			local iSize = GameClimate.GetNumStorms();
			for i = 0, iSize - 1,  1 do
				local kStorms:table = GameClimate.GetStormByID(i);
				if (kStorms ~= nil) then
					for index,storm in pairs(kStorms) do
						if(storm) then
							if(GameClimate.IsStormRevealed(index, playerID)) then
								TutorialCheck("FirstStormReveal");
							end
						end
					end
				end
			end

			-- Climate change occurred?
			if (GameClimate.GetClimateChangeForLastSeaLevelEvent() ~= -1) then
				TutorialCheck("FirstClimateChange");
			end
		end
	end);

	------------------
	-- Direct Lua Call listeners
	-- S.S TEMPORARILY COMMENTING THIS OUT.  GameEvents is no longer accessible via UI threads to avoid soft locks.
	--GameEvents.AdvisorNegativeResourceRate.Add(function( playerID:number, resourceID:number)
		--local localPlayerID = Game.GetLocalPlayer();
		--if (playerID == localPlayerID) then
			--TutorialCheck("NegativeResourceRate");
		--end
	--end);
end

-- ===========================================================================
function TutorialLoader:CreateTutorialItems(AddToListener:ifunction)

	-- ===========================================================================		
	item = TutorialItem:new("REVEAL_FIRST_FLOODPLAIN");
	item:SetRaiseEvents("RevealFirstFloodplain");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_FLOODPLAIN_REVEAL");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_FIRST_FLOODPLAIN");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_FIRST_FLOODPLAIN");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "ENVIRONMENTAL_EFFECTS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_FIRST_FLOODPLAIN");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("RevealFirstFloodplain", item);

	-- ===========================================================================		
	item = TutorialItem:new("REVEAL_FIRST_VOLCANO");
	item:SetRaiseEvents("RevealFirstVolcano");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_VOLCANO_REVEAL");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_REVEAL_FIRST_VOLCANO_QUIET");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_REVEAL_FIRST_VOLCANO_QUIET");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "ENVIRONMENTAL_EFFECTS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_REVEAL_FIRST_VOLCANO_QUIET");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("RevealFirstVolcano", item);

	-- ===========================================================================		
	item = TutorialItem:new("REVEAL_FIRST_GEOTHERMAL_FISSURE");
	item:SetRaiseEvents("RevealFirstGeothermalFissure");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_GEOTHERMAL_REVEAL");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_FIRST_GEOTHERMAL_FISSURE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_FIRST_GEOTHERMAL_FISSURE");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "ENVIRONMENTAL_EFFECTS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_FIRST_GEOTHERMAL_FISSURE");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("RevealFirstGeothermalFissure", item);

	-- ===========================================================================		
	item = TutorialItem:new("FIRST_CLIMATE_CHANGE");
	item:SetRaiseEvents("FirstClimateChange");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_FIRST_CLIMATE_CHANGE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_FIRST_CLIMATE_CHANGE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_FIRST_CLIMATE_CHANGE");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "ENVIRONMENTAL_EFFECTS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_FIRST_CLIMATE_CHANGE");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("FirstClimateChange", item);
	
		-- ===========================================================================		
	item = TutorialItem:new("CONSUME_FIRST_POWER_RESOURCE");
	item:SetRaiseEvents("ConsumeFirstPowerResource");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CONSUME_POWER_RESOURCE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_CONSUME_FIRST_POWER_SOURCE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_CONSUME_FIRST_POWER_SOURCE");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "POWER")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_CONSUME_FIRST_POWER_SOURCE");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("ConsumeFirstPowerResource", item);

	-- ===========================================================================		
	item = TutorialItem:new("FIRST_STORM_REVEAL");
	item:SetRaiseEvents("FirstStormReveal");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_STORM_REVEAL");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_FIRST_STORM_NOTIFICATION");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_FIRST_STORM_NOTIFICATION");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "ENVIRONMENTAL_EFFECTS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_FIRST_STORM_NOTIFICATION");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("FirstStormReveal", item);

	-- ===========================================================================
	item = TutorialItem:new("EMERGENCY_TRIGGER_HOSTILE");
	item:SetRaiseEvents("EmergencyTriggerHostile");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EMERGENCY_1_XP2");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_EMERGENCY_4")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("EmergencyTriggerHostile", item);

	-- ===========================================================================
	item = TutorialItem:new("EMERGENCY_TRIGGER_NON_HOSTILE");
	item:SetRaiseEvents("EmergencyTriggerNonHostile");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_SCORED_COMPETITION_BEGUN");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_EMERGENCY_4")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("EmergencyTriggerNonHostile", item);

	-- ===========================================================================		
	item = TutorialItem:new("INTRO_TO_WORLD_CONGRESS");
	item:SetRaiseEvents("IntroToWorldCongress");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	--item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		--function(advisorInfo)
			--LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			--UI.PlaySound("Stop_LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS")
		--end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("IntroToWorldCongress", item);

	-- ===========================================================================		
	item = TutorialItem:new("WORLD_CONGRESS_STAGE_2");
	item:SetRaiseEvents("WorldCongressStage2");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_WORLD_CONGRESS_STAGE_2");
	--item:SetAdvisorAudio("Play_LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			--UI.PlaySound("Stop_LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	--item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		--function(advisorInfo)
			--LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			--UI.PlaySound("Stop_LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS")
		--end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("WorldCongressStage2", item);

	-- ===========================================================================		
	item = TutorialItem:new("WORLD_CONGRESS_EMERGENCY_AVAILABLE");
	item:SetRaiseEvents("WorldCongressEmergencyAvailable");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_INTERVENTION_AVAILABLE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("WorldCongressEmergencyAvailable", item);

	-- ===========================================================================		
	item = TutorialItem:new("WORLD_CONGRESS_SPECIAL_SESSION_AND_EMERGENCY_AVAILABLE");
	item:SetRaiseEvents("WorldCongressSpecialIncomingCanPropose");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_INTERVENTION_PROPOSED_AND_WE_CAN_ADD");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("WorldCongressSpecialIncomingCanPropose", item);

	-- ===========================================================================		
	item = TutorialItem:new("WORLD_CONGRESS_OVER");
	item:SetRaiseEvents("WorldCongressFinished");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_WORLD_CONGRESS_STAGE_OVER");
	--item:SetAdvisorAudio("Play_LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			--UI.PlaySound("Stop_LOC_TUTORIAL_INTRO_TO_WORLD_CONGRESS")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("WorldCongressFinished", item);

	-- ===========================================================================		
	item = TutorialItem:new("WORLD_CONGRESS_INITIAL_ERA");
	item:SetRaiseEvents("WorldCongressInitialEra");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_WORLD_CONGRESS_CONVENE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_WORLD_CONGRESS_AVALIABLE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_WORLD_CONGRESS_AVALIABLE")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "WORLD_CONGRESS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_WORLD_CONGRESS_AVALIABLE")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("WorldCongressInitialEra", item);

	-- ===========================================================================
	item = TutorialItem:new("CITY_UNPOWERED");
	item:SetRaiseEvents("CityUnpowered");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CITY_POWER_SHORTAGE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_POWER_SHORTAGE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_POWER_SHORTAGE");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo);
			UI.PlaySound("Stop_LOC_ADVISOR_POWER_SHORTAGE");
			if (m_CityID ~= nil) then
				local pCity = CityManager.GetCity(m_CityID.Player, m_CityID.City);
				if (pCity ~= nil) then
					UI.SelectCity(pCity);
					UI.LookAtPlot(pCity:GetX(), pCity:GetY());
				end
			end
		end);	
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("CityUnpowered", item);

	-- ===========================================================================
	item = TutorialItem:new("EXOPLANET_PROJECT_AVAILABLE");
	item:SetRaiseEvents("ExoplanetProjectAvailable");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EXOPLANET_PROJECT_AVAILABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_NEW_SCIENCE_VICTORY");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_NEW_SCIENCE_VICTORY");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("WONDERS", "PROJECT_LAUNCH_EXOPLANET_EXPEDITION")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_NEW_SCIENCE_VICTORY");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("ExoplanetProjectAvailable", item);

	-- ===========================================================================
	item = TutorialItem:new("EXOPLANET_SUPPORT_PROJECTS_AVAILABLE");
	item:SetRaiseEvents("ExoplanetSupportProjectsAvailable");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EXOPLANET_SUPPORT_PROJECT_AVAILABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_WIN_SCIENCE_VICTORY_FASTER");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_WIN_SCIENCE_VICTORY_FASTER");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("WONDERS", "PROJECT_LAUNCH_EXOPLANET_EXPEDITION")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_WIN_SCIENCE_VICTORY_FASTER");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("ExoplanetSupportProjectsAvailable", item);

	-- ===========================================================================
	item = TutorialItem:new("UNLOCKED_CANALS_TECH");
	item:SetRaiseEvents("UnlockedCanalsTech");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CANAL_TECHNOLOGY_UNLOCK");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_TECH_FOR_CANALS");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_TECH_FOR_CANALS");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("DISTRICTS", "DISTRICT_CANAL")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_TECH_FOR_CANALS");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnlockedCanalsTech", item);

	-- ===========================================================================
	item = TutorialItem:new("UNLOCKED_DAMS_TECH");
	item:SetRaiseEvents("UnlockedDamsTech");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_DAM_TECHNOLOGY_UNLOCK");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_TECH_FOR_DAMS");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_TECH_FOR_DAMS");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("DISTRICTS", "DISTRICT_DAM")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_TECH_FOR_DAMS");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnlockedDamsTech", item);

	-- ===========================================================================
	item = TutorialItem:new("UNLOCKED_RAILROADS_TECH");
	item:SetRaiseEvents("UnlockedRailroadsTech");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_BUILD_RAILROAD_AVAILABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_RAILROADS_AVALIABLE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_RAILROADS_AVALIABLE");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("IMPROVEMENTS", "ROUTE_RAILROAD")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_RAILROADS_AVALIABLE");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnlockedRailroadsTech", item);

	-- ===========================================================================
	item = TutorialItem:new("UNLOCKED_MOUNTAIN_ROUTE_TECH");
	item:SetRaiseEvents("UnlockedMountainRouteTech");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_BUILD_ROUTE_MOUNTAIN_AVAILABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_MOUNTAIN_PATHS_AVALIABLE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_MOUNTAIN_PATHS_AVALIABLE");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("IMPROVEMENTS", "IMPROVEMENT_MOUNTAIN_TUNNEL")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_MOUNTAIN_PATHS_AVALIABLE");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnlockedMountainRouteTech", item);

	-- ===========================================================================
	item = TutorialItem:new("UNLOCKED_QHAPAQ_NAN");
	item:SetRaiseEvents("UnlockedQhpaqNan");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_BUILD_ROUTE_MOUNTAIN_AVAILABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_MOUNTAIN_PATHS_AVALIABLE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_MOUNTAIN_PATHS_AVALIABLE");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("IMPROVEMENTS", "IMPROVEMENT_MOUNTAIN_ROAD")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_MOUNTAIN_PATHS_AVALIABLE");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnlockedQhpaqNan", item);

	-- ===========================================================================
	item = TutorialItem:new("UNLOCKED_DIRTY_POWER_CHECK");
	item:SetRaiseEvents("UnlockedDirtyPowerTech");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_DIRTY_POWER_AVAILABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_POWER_SUPPLY_DIRTY");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_POWER_SUPPLY_DIRTY");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "POWER")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_POWER_SUPPLY_DIRTY");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnlockedDirtyPowerTech", item);

	-- ===========================================================================
	item = TutorialItem:new("UNLOCKED_CLEAN_POWER_CHECK");
	item:SetRaiseEvents("UnlockedCleanPowerTech");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CLEAN_POWER_AVAILABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_POWER_SUPPLY_CLEAN");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_POWER_SUPPLY_CLEAN");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "POWER")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_POWER_SUPPLY_CLEAN");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnlockedCleanPowerTech", item);

	-- ===========================================================================
	item = TutorialItem:new("FUTURE_ERA_IMMINENT");
	item:SetRaiseEvents("FutureEraImminent");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_FUTURE_ERA_IMMINENT");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_HIDDEN_RESEARCH_PATH");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_HIDDEN_RESEARCH_PATH");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("FutureEraImminent", item);

	-- ===========================================================================
	item = TutorialItem:new("FIRST_POWER_REQUIRED_BUILDABLE");
	item:SetRaiseEvents("FirstPowerRequiredBuildable");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_POWER_REQUIRED_BUILDABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_POWER_AS_A_REQUIRMENT");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_POWER_AS_A_REQUIRMENT");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "POWER")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_POWER_AS_A_REQUIRMENT");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("FirstPowerRequiredBuildable", item);

	-- ===========================================================================
	item = TutorialItem:new("UNIT_REQUIRES_FUEL_BUILT");
	item:SetRaiseEvents("UnitRequiresFuelBuilt");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_UNIT_REQUIRES_FUEL_BUILT");
	item:SetAdvisorAudio("Play_ADVISOR_LINE_FTUE_GENERAL_1");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_ADVISOR_LINE_FTUE_GENERAL_1");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CONSUMEABLE_RESOURCES")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_FTUE_GENERAL_1");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnitRequiresFuelBuilt", item);

	-- ===========================================================================
	item = TutorialItem:new("NEGATIVE_RESOURCE_RATE");
	item:SetRaiseEvents("NegativeResourceRate");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_NEGATIVE_RESOURCE_RATE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_RESOURCE_SHORTGE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_RESOURCE_SHORTGE");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CONSUMEABLE_RESOURCES")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_RESOURCE_SHORTGE");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("NegativeResourceRate", item);

	-- ===========================================================================
	item = TutorialItem:new("STRATEGIC_RESOURCE_EARNED");
	item:SetRaiseEvents("FirstStrategicResourceEarned");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_STRATEGIC_RESOURCE_AVAILABLE");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_STOCKPILING_STRATEGIC_RESOURCES");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_STOCKPILING_STRATEGIC_RESOURCES");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CONSUMEABLE_RESOURCES")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_STOCKPILING_STRATEGIC_RESOURCES");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("FirstStrategicResourceEarned", item);

-- ===========================================================================
	item = TutorialItem:new("ROCK_BAND_AVAILABLE");
	item:SetRaiseEvents("RockBandAvailable");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_BUILD_ROCKBAND_AVAILABLE");
	item:SetAdvisorAudio("Play_ADVISOR_LINE_FTUE_GENERAL_1");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_ADVISOR_LINE_FTUE_GENERAL_1");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNITS", "UNIT_ROCK_BAND")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_ROCKBAND_AVAILABLE");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("RockBandAvailable", item);

-- ===========================================================================
	item = TutorialItem:new("COASTAL_LOWLANDS");
	item:SetRaiseEvents("CoastalLowlands");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_BUILD_COASTAL_LOWLANDS");
	item:SetAdvisorAudio("Play_LOC_ADVISOR_COASTAL_FLOODING_LENS");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_ADVISOR_COASTAL_FLOODING_LENS");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "GLOBAL_TEMPERATURE")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_ADVISOR_COASTAL_FLOODING_LENS");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("CoastalLowlands", item);
end
