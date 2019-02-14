-- Common functions for contexts that use the popup system.

include("InputSupport");


-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_popupSupportEventID	:number	 = 0;
local m_popupSupportName	:string;
local m_popupSupportPriority:number;


-- ===========================================================================
--	Performs engine lock for a series of popups to be shown.
--	name		Name of the popup being added (for debugging only)
--	priority	What popup priority to put the popup on the queue.
--	kParameters	(optional) Popup paramters.
--	RETURNS true if lock was obtained
-- ===========================================================================
function LockPopupSequence( name:string, priority:number, kParameters:table )
	if name==nil or name=="" then
		name = "Misisng Name Argument";
		UI.DataAssert("Attempt to LockPopupSequence() but no name passed in!");
	end
	m_popupSupportName = name;
	if m_popupSupportEventID ~= 0 then
		UI.DataAssert("Attempt to re-lock '"..m_popupSupportName.."' but it's already locked.  This should only happen once per batch.");
		return false;
	end
	m_popupSupportPriority = priority;
	m_popupSupportEventID = UI.ReferenceCurrentEvent();	
	print("LockPopupSequence []   LOCK: "..m_popupSupportName..", id: "..tostring(m_popupSupportEventID)..", priority:"..tostring(m_popupSupportPriority));
	if m_popupSupportEventID == 0 then
		UI.DataAssert("Attempt to lock '"..m_popupSupportName.."' but no locking even was returned from engine.");
		return false;
	end

	Input.PushActiveContext( InputContext.Reveal );
	if priority == nil then priority = PopupPriority.Current; end
	UIManager:QueuePopup( ContextPtr, priority, kParameters);

	return true;
end

-- ===========================================================================
function UnlockPopupSequence()
	if m_popupSupportEventID == 0 then
		UI.DataAssert("Attempt to unlock '"..m_popupSupportName.."' but it's already unlocked!");		
		if ContextPtr:IsHidden() then	-- Only leave early if this is already hidden.
			return;
		end
	end
	print("UnlockPopupSequence }{ unlock: "..m_popupSupportName..", id: "..tostring(m_popupSupportEventID)..", priority:"..tostring(m_popupSupportPriority));
	UIManager:DequeuePopup( ContextPtr );
	Input.PopContext();
	UI.ReleaseEventID( m_popupSupportEventID );	-- Release engine hold.
	m_popupSupportEventID = 0;		
end

-- ===========================================================================
function IsLocked()
	return (m_popupSupportEventID ~= 0);
end
