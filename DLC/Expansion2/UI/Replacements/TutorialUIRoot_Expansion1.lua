-- ===========================================================================
--	XP1 Extension of base game TutorialUIRoot
-- ===========================================================================

include("TutorialUIRoot");

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
BASE_IsListenerAbleToProcessOnNonPlayerTurn = IsListenerAbleToProcessOnNonPlayerTurn;

-- ===========================================================================
--	OVERRIDE BASE FUNCTIONS
-- ===========================================================================

function IsListenerAbleToProcessOnNonPlayerTurn( listenerName:string )
	local baseResult = BASE_IsListenerAbleToProcessOnNonPlayerTurn( listenerName );

	return baseResult
		or listenerName == "FirstMoment"
		or listenerName == "CommemorationAvailable"
		or listenerName == "GoldenAgeStarted"
		or listenerName == "DarkAgeStarted"
		or listenerName == "DarkAgeEnded"
		or listenerName == "DarkAgeToDarkAge"
		or listenerName == "EraChanged"
		or listenerName == "TransitionBegins"
		or listenerName == "LostLoyaltyToIndependent"
		or listenerName == "WonLoyaltyFromIndependent"
		or listenerName == "LostLoyaltyToIndependentThirdParty"
		or listenerName == "AllianceAvailable"
		or listenerName == "AllianceEnded"
		or listenerName == "EmergencyRequest"
		or listenerName == "TargetEmergencyFailure"
		or listenerName == "TargetEmergencySuccess"
		or listenerName == "EmergencyFailure"
		or listenerName == "EmergencyTrigger"
		or listenerName == "EmergencySuccess"
		or listenerName == "WorldCongressStage3"
		or listenerName == "WorldCongressFinished";
end