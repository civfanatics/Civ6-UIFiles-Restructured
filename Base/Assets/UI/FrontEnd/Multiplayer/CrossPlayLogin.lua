-------------------------------------------------
-- CrossPlay Login
-------------------------------------------------

include( "InstanceManager" )
include( "LobbyTypes" );		--MPLobbyTypes

-- ===========================================================================
--	DEFINES
-- ===========================================================================

local SIZE_DIALOG_ART_SPACE_Y = 128+30+30;	-- For resizing based on contents

local DIALOG_MESSAGE			= 1;

-- ===========================================================================
--	MEMBERS
-- ===========================================================================

local m_MessageDialogManager			= InstanceManager:new( "CrossPlayMessageDialogInstance", 	"Dialog",	Controls.CrossPlayBG );

local m_currentDialogID		= DIALOG_MESSAGE;
local m_currentDialog		= nil;
local m_currentDialogData	= nil;

local m_bESCEnabled			= true;
local m_cancelFunction		= nil

-- ===========================================================================
--	Leave CrossPlay
-- ===========================================================================
function LeaveCrossPlayDialogs()
	UIManager:DequeuePopup( ContextPtr );

	-- Clear dialogs
	DestroyDialogIfExists( m_MessageDialogManager );

	m_currentDialogID	= 0;
	m_currentDialog		= nil;
	m_currentDialogData	= nil;

	m_bESCEnabled		= true;
	m_cancelFunction	= nil;
end

-- ===========================================================================
--	Helper Functions
-- ===========================================================================
function ClosePreviousMenu()
	if m_currentDialog ~= nil then
		LeaveCrossPlayDialogs();
	end
end

function GoToCrossPlayLobby()
	if m_currentDialog ~= nil then
		LeaveCrossPlayDialogs();
	end
	LuaEvents.EnterCrossPlayLobby();
end

-- ===========================================================================
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp 
	then
		if (wParam == Keys.VK_ESCAPE and m_bESCEnabled == true) then
			if( m_cancelFunction ~= nil ) then
				m_cancelFunction();
			else
				UI.PlaySound("Play_UI_Click");
				LeaveCrossPlayDialogs();
			end
		end
	end
	return true;
end
ContextPtr:SetInputHandler( InputHandler );


-- ===========================================================================
-- ===========================================================================
function DestroyDialogIfExists( dialogManager )
	if (dialogManager) then
		dialogManager:ResetInstances();
	end
end

-- ===========================================================================
-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )	
	if( bIsHide ) then
		return;
	end

	if( gCurrentDialogID == nil ) then
		gCurrentDialogID = DIALOG_MESSAGE;
	end

	if ( m_currentDialogID == DIALOG_MESSAGE )			then CreateMessageDialog();			end

end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-- ===========================================================================
-- ===========================================================================
function CreateMessageDialog()
	local instance = m_MessageDialogManager:GetInstance();

	local szFullText:string = Locale.Lookup(m_currentDialogData.message);
	
	instance.Message:SetText( szFullText );

	m_cancelFunction = function()

		UI.PlaySound("Play_UI_Click");
		LeaveCrossPlayDialogs();

	end

	instance.OkButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	instance.OkButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	m_bESCEnabled = true;
	m_currentDialog = instance;
end

-- ===========================================================================
function ShowMessageDialog( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_MESSAGE;
	m_currentDialogData = dialogData;

	local CrossPlayPanel =  ContextPtr:LookUpControl( "/FrontEnd/MainMenu/CrossPlay" );

	if(CrossPlayPanel ~= nil) then
		UIManager:QueuePopup( CrossPlayPanel, PopupPriority.Current );
	end
end

-- ===========================================================================
--	External events
-- ===========================================================================
function OnStartCrossPlay()

	if(Network.IsUserLoggedIntoCrossPlayLobbyService()) then
		GoToCrossPlayLobby();
	else
		Network.AttemptConnectionToCrossPlayLobbyService();
	end

end
LuaEvents.StartCrossPlay.Add( OnStartCrossPlay );

-- ===========================================================================
function OnCrossPlayLoginStateUpdated(bLoggedIn)
	if( bLoggedIn ) then
		GoToCrossPlayLobby();
	else
		ClosePreviousMenu();
	end
end
Events.CrossPlayLoginStateUpdated.Add(OnCrossPlayLoginStateUpdated)

-- ===========================================================================
function OnCrossPlayDisplayMessage(szMessageTxtKey, szAdditionalText)

	local dialogData = {};
	dialogData.message = Locale.Lookup(szMessageTxtKey);

	ShowMessageDialog(dialogData);
		
end
Events.CrossPlayDisplayMessage.Add(OnCrossPlayDisplayMessage)

