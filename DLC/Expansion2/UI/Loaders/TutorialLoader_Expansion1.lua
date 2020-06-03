-- ===========================================================================
--
--	Tutorial items related to governor system in expansion 1
--
-- ===========================================================================

-- Add to tutorial loaders referenced by TutorialUIRoot
local TutorialLoader = {};
table.insert(g_TutorialLoaders, TutorialLoader);

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_CloseAllPopups = CloseAllPopups;
BASE_RealizeHookVisibility = RealizeHookVisibility;
BASE_OnInputActionTriggered = OnInputActionTriggered;

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
m_CityID = {};

-- ===========================================================================
function OnToggleLoyaltyPanel(pCity)
	if (pCity ~= nil) then
		UI.LookAtPlot(pCity:GetX(), pCity:GetY());
		UI.SelectCity(pCity);
		LuaEvents.CityPanel_ToggleOverviewLoyalty();
	end
end

-- ===========================================================================
function TutorialLoader:Initialize(TutorialCheck:ifunction)
	-- Register game core events
	local pPlayer = Players[Game.GetLocalPlayer()];

	------------------
	Events.GovernorPointsChanged.Add(function(player, iDelta)
		if (pPlayer == nil) then
			return;
		end
		if (iDelta > 0) then
			local playerGovernors = pPlayer:GetGovernors();
			if playerGovernors:CanPromote() then
				TutorialCheck("SecondGovernorAppointment");
			else
				TutorialCheck("FirstGovernorAppointment");
			end
		end
	end);

	------------------
	Events.CivicCompleted.Add(function(player, civic, canceled)
		local localPlayerID = Game.GetLocalPlayer();
		if (player == localPlayerID) then
			local tmpCivic = GameInfo.Civics["CIVIC_FOREIGN_TRADE"];
			if tmpCivic ~= nil and civic == tmpCivic.Index then
				TutorialCheck("GovernorsIntro");
			end

			tmpCivic = GameInfo.Civics["CIVIC_CRAFTSMANSHIP"];
			if tmpCivic ~= nil and civic == tmpCivic.Index then
				TutorialCheck("GovernorsIntro");
			end

			tmpCivic= GameInfo.Civics["CIVIC_STATE_WORKFORCE"]
			if tmpCivic ~= nil and civic == tmpCivic.Index then
				TutorialCheck("UnlockedGovernmentDistrict");
			end
		end
	end);

	------------------
	Events.GovernorAssigned.Add(function(cityOwner, cityID, governorOwner, governorType )
		local ePlayer = Game.GetLocalPlayer();
		if (ePlayer == governorOwner) then
			TutorialCheck("FirstGovernorAssigned");
		end	
	end);

	------------------
	Events.CulturalIdentityConversionOutcomeChanged.Add(function(player, cityID, eOutcome)
		local ePlayer = Game.GetLocalPlayer();
		if (player == ePlayer and Players[ePlayer]:IsMajor() == true) then
			if (eOutcome == IdentityConversionOutcome.LOSING_LOYALTY) then
				m_CityID = { Player = player, CityID = cityID };
				TutorialCheck("CityLosingLoyalty");
			end
		end
	end);

	------------------
	Events.CulturalIdentityCityConverted.Add(function(player, cityID, fromPlayer)
		local ePlayer :number = Game.GetLocalPlayer();
		if ePlayer == PlayerTypes.NONE or ePlayer == PlayerTypes.OBSERVER then return; end

		local bRevealed :boolean = false;
		local pCity		:object = CityManager.GetCity(player, cityID);
		if (pCity ~= nil) then
			local localPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
			if localPlayerVis:IsRevealed(pCity:GetX(), pCity:GetY()) then
				m_CityID = { Player = player, CityID = cityID };
				isRevealed = true;
			end			
		end
		
		if isRevealed then
			if (fromPlayer == ePlayer) then
				if (not Players[player]:IsMajor()) then
					TutorialCheck("LostLoyaltyToIndependent");
				end
			elseif (player == ePlayer) then
				if (not Players[fromPlayer]:IsMajor()) then
					TutorialCheck("WonLoyaltyFromIndependent");
				end
			else
				TutorialCheck("LostLoyaltyToIndependentThirdParty");
			end
		end
	end);

	------------------
	Events.GovDistrictPolicyUnlocked.Add(function(player, policytype)
		local ePlayer = Game.GetLocalPlayer();
		if (player == ePlayer) then
			TutorialCheck("BuiltGovDistrictBuilding");
		end
	end);

	------------------
	Events.DistrictBuildProgressChanged.Add(function(owner, districtID, cityID, x, y, districtType, era, civilization, percentComplete, appeal, isPillaged)
		local localPlayerID = Game.GetLocalPlayer();
		if (owner == localPlayerID) then
			local campus = GameInfo.Districts["DISTRICT_GOVERNMENT"];
			if(campus and percentComplete > 99) then
				local eCampus = campus.Index;		
				if (districtType == eCampus) then
					TutorialCheck("BuiltGovernmentDistrict");
				end
			end
		end
	end);

	------------------
	Events.AllianceAvailable.Add(function( playerID, otherplayerID, eAllianceType )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID or otherplayerID == localPlayerID) then
			TutorialCheck("AllianceAvailable");
		end
	end);

	------------------
	Events.AllianceEnded.Add(function( playerID, otherplayerID, eAllianceType )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID or otherplayerID == localPlayerID) then
			TutorialCheck("AllianceEnded");
		end
	end);

	------------------
	Events.NotificationAdded.Add(function (playerID, notificationID)
		local localPlayer = Game.GetLocalPlayer()

		if playerID == localPlayer then
			local notification = NotificationManager.Find(playerID, notificationID)

			if notification ~= nil then
				local notificationType = notification:GetType()

				local firstMoment = GameInfo.Notifications["NOTIFICATION_PRIDE_MOMENT_RECORDED"]
				if firstMoment ~= nil and notificationType == firstMoment.Hash then
					TutorialCheck("FirstMoment");
				end

				local commemorationAvailable = GameInfo.Notifications["NOTIFICATION_COMMEMORATION_AVAILABLE"]
				if commemorationAvailable ~= nil and notificationType == commemorationAvailable.Hash then
					TutorialCheck("CommemorationAvailable");
				end

				local emergencyAttention = GameInfo.Notifications["NOTIFICATION_EMERGENCY_NEEDS_ATTENTION"]
				if emergencyAttention ~= nil and notificationType == emergencyAttention.Hash then
					TutorialCheck("EmergencyRequest");
				end

				local emergencyFailure = GameInfo.Notifications["NOTIFICATION_EMERGENCY_FAILED"]
				if emergencyFailure ~= nil and notificationType == emergencyFailure.Hash then
					TutorialCheck("EmergencyFailure");
				end

				local emergencySuccess = GameInfo.Notifications["NOTIFICATION_EMERGENCY_SUCCEEDED"]
				if emergencySuccess ~= nil and notificationType == emergencySuccess.Hash then
					TutorialCheck("EmergencySuccess");
				end

				local emergencyTargetSuccess = GameInfo.Notifications["NOTIFICATION_EMERGENCY_FAILED_TARGET"]
				if emergencyTargetSuccess ~= nil and notificationType == emergencyTargetSuccess.Hash then
					TutorialCheck("TargetEmergencySuccess");
				end

				local emergencyTargetFailure = GameInfo.Notifications["NOTIFICATION_EMERGENCY_SUCCEEDED_TARGET"]
				if emergencyTargetFailure ~= nil and notificationType == emergencyTargetFailure.Hash then
					TutorialCheck("TargetEmergencyFailure");
				end
			end
		end	
	end);

	------------------
	Events.PlayerAgeChanged.Add(function( playerID )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("EraChanged");
			
			local gameEras = Game.GetEras();
			local currentEra = Game.GetEras():GetCurrentEra();
			if currentEra > 0 then
				if (gameEras:HasGoldenAge(localPlayerID)) then
					TutorialCheck("GoldenAgeStarted");
				elseif (gameEras:HasDarkAge(localPlayerID)) then
					TutorialCheck("DarkAgeStarted");
				end
			end
		end
	end);

	------------------
	Events.PlayerDarkAgeChanged.Add(function( playerID )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			local gameEras = Game.GetEras();
			local currentEra = Game.GetEras():GetCurrentEra();
			if currentEra > 0 then
				if (gameEras:HasDarkAge(localPlayerID) == false) then
					TutorialCheck("DarkAgeEnded");
				else
					TutorialCheck("DarkAgeToDarkAge");
				end
			end
		end
	end);

	------------------
	Events.PlayerEraTransitionBegins.Add(function( playerID )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("TransitionBegins");
		end
	end);

	------------------
	Events.EmergencyStarted.Add(function( playerID, eTargetPlayer, iTurn)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			TutorialCheck("EmergencyTrigger");
		end
	end);


	------------------
	Events.EmergencyCompleted.Add(function( playerID, eTargetPlayer, iTurn)
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			local crisisData = Game.GetEmergencyManager():GetEmergencyInfoTable(localPlayerID);
			for _, crisis in ipairs(crisisData) do
				if crisis.TargetID == localPlayerID then
					if(crisis.bSuccess == true) then
						TutorialCheck("TargetEmergencyFailure");
					else
						TutorialCheck("TargetEmergencySuccess");
					end
				end
			end
		end
	end);

	------------------
	Events.CityTransfered.Add(function( playerID, city)
		local localPlayerID = Game.GetLocalPlayer();
		m_CityID = { Player = playerID, CityID = city };
		if (playerID == localPlayerID) then
			TutorialCheck("CityCaptured");
		end
	end);

	------------------
	Events.CityInitialized.Add(function( playerID:number, cityID:number )
		local localPlayerID = Game.GetLocalPlayer();
		if (playerID == localPlayerID) then
			local pPlayer = Players[playerID];
			local pPlayerCities:table = pPlayer:GetCities();

			if(pPlayerCities:GetCount() == 2) then
				m_CityID = { Player = playerID, CityID = cityID };
				TutorialCheck("SecondCity");
			end
		end
	end);
end

-- ===========================================================================
function TutorialLoader:CreateTutorialItems(AddToListener:ifunction)

	-- First, delete deprecated items.
	TutorialItem.RemoveItem("RESEARCH_AGREEMENTS_UNLOCKED");

	-- Local player scout unit added to map
	local item:TutorialItem = TutorialItem:new("GOVERNORS_INTRO");
	item:SetRaiseEvents("GovernorsIntro");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_GOVERNOR_INTRO");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_GOVERNOR_INTRO")
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_GOVERNOR_INTRO")
		end);
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("GOVERNORS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_GOVERNOR_INTRO")
		end)
	item:SetIsDoneFunction(
		function()
			return false
		end);
	AddToListener("GovernorsIntro", item);

	-- ===========================================================================
	item = TutorialItem:new("FIRST_GOVERNOR_APPOINTMENT");
	item:SetRaiseEvents("FirstGovernorAppointment");
	item:SetTutorialLevel(TutorialLevel.LEVEL_EXPERIENCED_PLAYER);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_FIRST_GOVERNOR_POINT");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_FIRST_GOVERNOR_POINT");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function( advisorInfo )
			LuaEvents.GovernorPanel_Toggle();
			UI.PlaySound("Stop_LOC_TUTORIAL_FIRST_GOVERNOR_POINT")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("GOVERNORS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_FIRST_GOVERNOR_POINT")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("FirstGovernorAppointment", item);

	-- ===========================================================================
	item = TutorialItem:new("FIRST_GOVERNOR_ASSIGNED_TO_CITY");
	item:SetRaiseEvents("FirstGovernorAssigned");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_FIRST_GOVERNOR_ASSIGNMENT");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_FIRST_GOVERNOR_ASSIGNMENT");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_FIRST_GOVERNOR_ASSIGNMENT")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("GOVERNORS");
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
			UI.PlaySound("Stop_LOC_TUTORIAL_FIRST_GOVERNOR_ASSIGNMENT");
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("FirstGovernorAssigned", item);

	-- ===========================================================================
	item = TutorialItem:new("SECOND_GOVERNOR_APPOINTMENT");
	item:SetRaiseEvents("SecondGovernorAppointment");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_SECOND_GOVERNOR_POINT");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_SECOND_GOVERNOR_POINT");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_SECOND_GOVERNOR_POINT")
			LuaEvents.GovernorPanel_Toggle();
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("GOVERNORS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_SECOND_GOVERNOR_POINT")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("SecondGovernorAppointment", item);

	-- ===========================================================================
	item = TutorialItem:new("LOSING_LOYALTY");
	item:SetRaiseEvents("CityLosingLoyalty");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CITY_LOSING_LOYALTY");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_CITY_LOSING_LOYALTY");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
            UI.PlaySound("Stop_LOC_TUTORIAL_CITY_LOSING_LOYALTY")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo);
			if (m_CityID ~= nil) then
				local pCity = CityManager.GetCity(m_CityID.Player, m_CityID.CityID);
				if (pCity ~= nil) then
					OnToggleLoyaltyPanel(pCity);
				end
			end
			UI.PlaySound("Stop_LOC_TUTORIAL_CITY_LOSING_LOYALTY")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("CityLosingLoyalty", item);

	-- ===========================================================================
	item = TutorialItem:new("LOST_LOYALTY_TO_INDEPENDENT");
	item:SetRaiseEvents("LostLoyaltyToIndependent");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CITY_LOST_LOYALTY_TO_INDEPENDENT");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_CITY_LOST_LOYALTY_TO_INDEPENDENT");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_CITY_LOST_LOYALTY_TO_INDEPENDENT")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo);
			UI.PlaySound("Stop_LOC_TUTORIAL_CITY_LOST_LOYALTY_TO_INDEPENDENT");
			if (m_CityID ~= nil) then
				local pCity = CityManager.GetCity(m_CityID.Player, m_CityID.CityID);
				if (pCity ~= nil) then
					UI.LookAtPlot(pCity:GetX(), pCity:GetY());
				end
			end
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("LostLoyaltyToIndependent", item);

	-- ===========================================================================
	item = TutorialItem:new("WON_LOYALTY_FROM_INDEPENDENT");
	item:SetRaiseEvents("WonLoyaltyFromIndependent");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CITY_WON_LOYALTY_FROM_INDEPENDENT");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_CITY_WON_LOYALTY_FROM_INDEPENDENT");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_CITY_WON_LOYALTY_FROM_INDEPENDENT")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			if (m_CityID ~= nil) then
				local pCity = CityManager.GetCity(m_CityID.Player, m_CityID.CityID);
				if (pCity ~= nil) then
					UI.LookAtPlot(pCity:GetX(), pCity:GetY());
				end
			end
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_CITY_WON_LOYALTY_FROM_INDEPENDENT")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("WonLoyaltyFromIndependent", item);

	-- ===========================================================================
	item = TutorialItem:new("LOST_LOYALTY_TO_INDEPENDENT_THIRD_PARTY");
	item:SetRaiseEvents("LostLoyaltyToIndependentThirdParty");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CITY_LOST_LOYALTY_TO_INDEPENDENT_THIRD_PARTY");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_CITY_LOST_LOYALTY_TO_INDEPENDENT_THIRD_PARTY");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_CITY_LOST_LOYALTY_TO_INDEPENDENT_THIRD_PARTY")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo);
			UI.PlaySound("Stop_LOC_TUTORIAL_CITY_LOST_LOYALTY_TO_INDEPENDENT_THIRD_PARTY");
			if (m_CityID ~= nil) then
				local pCity = CityManager.GetCity(m_CityID.Player, m_CityID.CityID);
				if (pCity ~= nil) then
					UI.LookAtPlot(pCity:GetX(), pCity:GetY());
				end
			end
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("LostLoyaltyToIndependentThirdParty", item);

	-- ===========================================================================
	item = TutorialItem:new("UNLOCKED_GOVERNMENT_DISTRICT");
	item:SetRaiseEvents("UnlockedGovernmentDistrict");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_GOV_DISTRICT_1a");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_GOV_DISTRICT_1a");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_GOV_DISTRICT_1a")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("DISTRICTS", "DISTRICT_GOVERNMENT")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_GOV_DISTRICT_1a")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("UnlockedGovernmentDistrict", item);

	-- ===========================================================================
	item = TutorialItem:new("BUILT_GOVERNMENT_DISTRICT");
	item:SetRaiseEvents("BuiltGovernmentDistrict");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_GOV_DISTRICT_2a");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_GOV_DISTRICT_2a");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_GOV_DISTRICT_2a")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("DISTRICTS", "DISTRICT_GOVERNMENT")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_GOV_DISTRICT_2a")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("BuiltGovernmentDistrict", item);

	-- ===========================================================================
	item = TutorialItem:new("GOV_DISTRICT_UNLOCKED_POLICY");
	item:SetRaiseEvents("BuiltGovDistrictBuilding");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_GOV_DISTRICT_3c");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_GOV_DISTRICT_3c");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_GOV_DISTRICT_3c")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.Advisor_GovernmentOpenPolicies();
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_GOV_DISTRICT_2a")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("BuiltGovDistrictBuilding", item);

	-- ===========================================================================
	item = TutorialItem:new("ALLIANCE_AVAILABLE");
	item:SetRaiseEvents("AllianceAvailable");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_ALLIANCES_1");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_ALLIANCES_1");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_ALLIANCES_1")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "ALLIANCES_1")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_GOV_DISTRICT_2a")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("AllianceAvailable", item);

	-- ===========================================================================
	item = TutorialItem:new("ALLIANCE_ENDED");
	item:SetRaiseEvents("AllianceEnded");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_ALLIANCES_2");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_ALLIANCES_2");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_ALLIANCES_2")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("AllianceEnded", item);
	
	-- ===========================================================================
	item = TutorialItem:new("CITY_CAPTURED");
	item:SetRaiseEvents("CityCaptured");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_CONQUERED_CITY_LOYALTY");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_CONQUERED_CITY_LOYALTY");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_CONQUERED_CITY_LOYALTY")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo);
			UI.PlaySound("Stop_LOC_TUTORIAL_CONQUERED_CITY_LOYALTY");
			if (m_CityID ~= nil) then
				local pCity = CityManager.GetCity(m_CityID.Player, m_CityID.CityID);
				if (pCity ~= nil) then
					UI.LookAtPlot(pCity:GetX(), pCity:GetY());
				end
			end
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("CityCaptured", item);

	-- ===========================================================================
	item = TutorialItem:new("EMERGENCY_REQUEST");
	item:SetRaiseEvents("EmergencyRequest");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EMERGENCY_1");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_EMERGENCY_1");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_EMERGENCY_1")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("EmergencyRequest", item);

	-- ===========================================================================
	item = TutorialItem:new("EMERGENCY_TRIGGER");
	item:SetRaiseEvents("EmergencyTrigger");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EMERGENCY_4");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_EMERGENCY_4");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_EMERGENCY_4")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("EmergencyTrigger", item);

	-- ===========================================================================
	item = TutorialItem:new("EMERGENCY_SUCCESS");
	item:SetRaiseEvents("EmergencySuccess");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EMERGENCY_2");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_EMERGENCY_2");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_EMERGENCY_2")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("EmergencySuccess", item);

	-- ===========================================================================
	item = TutorialItem:new("EMERGENCY_FAILURE");
	item:SetRaiseEvents("EmergencyFailure");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EMERGENCY_3");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_EMERGENCY_3");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_EMERGENCY_3")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("EmergencyFailure", item);

	-- ===========================================================================
	item = TutorialItem:new("TARGET_EMERGENCY_SUCCESS");
	item:SetRaiseEvents("TargetEmergencySuccess");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EMERGENCY_5");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_EMERGENCY_5");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_EMERGENCY_5")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("TargetEmergencySuccess", item);

	-- ===========================================================================
	item = TutorialItem:new("TARGET_EMERGENCY_FAILURE");
	item:SetRaiseEvents("TargetEmergencyFailure");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_EMERGENCY_6");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_EMERGENCY_6");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_EMERGENCY_6")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("TargetEmergencyFailure", item);

	-- ===========================================================================
	item = TutorialItem:new("FIRST_MOMENT");
	item:SetRaiseEvents("FirstMoment");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_PRIDE_MOMENT_TRIGGERED");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_PRIDE_MOMENT_TRIGGERED");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_PRIDE_MOMENT_TRIGGERED")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.Advisor_ToggleTimeline(true)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_PRIDE_MOMENT_TRIGGERED")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("FirstMoment", item);

	-- ===========================================================================
	item = TutorialItem:new("COMMEMORATION_AVAILABLE");
	item:SetRaiseEvents("CommemorationAvailable");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_PRIDE_MOMENT_COMMEMORATION");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_PRIDE_MOMENT_COMMEMORATION");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_PRIDE_MOMENT_COMMEMORATION")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("CommemorationAvailable", item);

	-- ===========================================================================		
	item = TutorialItem:new("SECOND_CITY");
	item:SetRaiseEvents("SecondCity");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_LOYALTY_PRESSURE");
	item:SetAdvisorAudio("Play_ADVISOR_LINE_FTUE_GENERAL_1");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_ADVISOR_LINE_FTUE_GENERAL_1")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			if (m_CityID ~= nil) then
				local pCity = CityManager.GetCity(m_CityID.Player, m_CityID.CityID);
				if (pCity ~= nil) then
					OnToggleLoyaltyPanel(pCity);
				end
			end
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_FTUE_GENERAL_1")
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("SecondCity", item);

	-- ===========================================================================		
	item = TutorialItem:new("GOLDEN_AGE_STARTED");
	item:SetRaiseEvents("GoldenAgeStarted");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_ENTER_GOLDEN_AGE");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_ENTER_GOLDEN_AGE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_ENTER_GOLDEN_AGE")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_ENTER_GOLDEN_AGE")
			LuaEvents.EraReviewPopup_Show();
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("GoldenAgeStarted", item);

	-- ===========================================================================		
	item = TutorialItem:new("DARK_AGE_STARTED");
	item:SetRaiseEvents("DarkAgeStarted");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_ENTER_DARK_AGE");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_ENTER_DARK_AGE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_ENTER_DARK_AGE")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_ENTER_DARK_AGE")
			LuaEvents.EraReviewPopup_Show();
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("DarkAgeStarted", item);

	-- ===========================================================================		
	item = TutorialItem:new("DARK_AGE_ENDED");
	item:SetRaiseEvents("DarkAgeEnded");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_OVERCOME_DARK_AGE");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_OVERCOME_DARK_AGE");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_OVERCOME_DARK_AGE")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_OVERCOME_DARK_AGE")
			LuaEvents.EraReviewPopup_Show();
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("DarkAgeEnded", item);

	-- ===========================================================================		
	item = TutorialItem:new("DARK_AGE_TO_DARK_AGE");
	item:SetRaiseEvents("DarkAgeToDarkAge");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_DARK_AGE_TO_DARK_AGE"); --"Our people still await your command"
	item:SetAdvisorAudio("Play_ADVISOR_LINE_FTUE_2092");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_ADVISOR_LINE_FTUE_2092")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_OVERCOME_DARK_AGE")
			LuaEvents.EraReviewPopup_Show();
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("DarkAgeToDarkAge", item);

	-- ===========================================================================		
	item = TutorialItem:new("ERA_CHANGED");
	item:SetRaiseEvents("EraChanged");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_GAME_ERA_CHANGED");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_GAME_ERA_CHANGED");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_GAME_ERA_CHANGED")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("EraChanged", item);

	-- ===========================================================================		
	item = TutorialItem:new("TRANSITION_BEGINS");
	item:SetRaiseEvents("TransitionBegins");
	item:SetTutorialLevel(TutorialLevel.LEVEL_NEW_TO_XP1);
	item:SetIsEndOfChain(true);
	item:SetIsQueueable(true);
	item:SetShowPortrait(true);
	item:SetAdvisorMessage("LOC_TUTORIAL_GAME_ERA_CHANGING_SOON");
	item:SetAdvisorAudio("Play_LOC_TUTORIAL_GAME_ERA_CHANGING_SOON");
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_CONTINUE",
		function( advisorInfo )
			UI.PlaySound("Stop_LOC_TUTORIAL_GAME_ERA_CHANGING_SOON")
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
		end );
	item:AddAdvisorButton("LOC_ADVISOR_BUTTON_TAKE_ME_THERE",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_LOC_TUTORIAL_GAME_ERA_CHANGING_SOON")
			LuaEvents.PartialScreenHooks_Expansion1_ToggleEraProgress();
		end);
	item:SetIsDoneFunction(
		function()
			return false;
		end );
	AddToListener("TransitionBegins", item);
end

