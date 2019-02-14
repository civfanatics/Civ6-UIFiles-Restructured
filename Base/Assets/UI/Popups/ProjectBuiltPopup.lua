-- Copyright 2016-2018, Firaxis Games
-- For some projects (not all) play a movie showing off the completion)

include("PopupSupport");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "ProjectBuiltPopup";


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kQueuedPopups		:table = {};	
local m_kCurrentPopup		:table	= nil;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-- ===========================================================================
function OnProjectComplete(playerID:number, cityID:number, projectIndex, buildingIndex:number, locX:number, locY:number, bCanceled:boolean)

	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer == PlayerTypes.NONE) then
		return;	-- Nobody there to watch; just exit.
	end

	-- Ignore project if it's not for this player.
	if (localPlayer ~= playerID) then
		return;	
	end

	-- TEMP (ZBR): Ignore if pause-menu is up; prevents stuck camera bug.
	local uiInGameOptionsMenu:table = ContextPtr:LookUpControl("/InGame/TopOptionsMenu");
	if (uiInGameOptionsMenu and uiInGameOptionsMenu:IsHidden()==false) then
		return;
	end

	local projectInfo = GameInfo.Projects[projectIndex];
	if (projectInfo ~= nil and not bCanceled) then
		local projectType		:string = projectInfo.ProjectType;
		local projectPopupText	:string = projectInfo.PopupText;
		if (projectType ~= nil and projectPopupText ~= nil and projectPopupText ~= "") then
		
			if projectInfo.Description == nil then
				UI.DataError("The field 'Description' has not been initialized for "..projectInfo.ProjectType);
			end

			local kData:table = 
			{
				locX = locX,
				locY = locY,
				Name = projectInfo.Name,
				Description = projectInfo.Description,
				Icon = "ICON_"..projectType,
				projectPopupText = projectPopupText
			};

			if not IsLocked() then
				LockPopupSequence( "ProjectBuiltPopup", PopupPriority.High );
				ShowPopup( kData );
				LuaEvents.ProjectBuiltPopup_Shown();	-- Signal other systems (e.g., bulk hide UI)
			else
				table.insert( m_kQueuedPopups, kData );
			end

		end
	end
end

-- ===========================================================================
function ShowPopup( kData:table )

	UI.PlaySound("Mute_Narrator_Advisor_All");

	Controls.ProjectName:SetText( Locale.ToUpper(kData.Name) );
	Controls.ProjectIcon:SetIcon( kData.Icon );
	if Locale.Lookup(kData.Description) ~= nil then
		Controls.ProjectQuote:SetText(Locale.Lookup(kData.Description));
	end

	-- Hide all the UI if in marketing mode.
	if UI.IsInMarketingMode() then
		ContextPtr:SetHide( true );
		Controls.ForceAutoCloseMarketingMode:SetToBeginning();
		Controls.ForceAutoCloseMarketingMode:Play();
		Controls.ForceAutoCloseMarketingMode:RegisterEndCallback( OnClose );
	else
		ContextPtr:SetHide( false );
	end			
end

-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal()

	Controls.GradientL:SetSizeY(screenY);
	Controls.GradientR:SetSizeY(screenY);
	Controls.GradientT:SetSizeX(screenX);
	Controls.GradientB:SetSizeX(screenX);
	Controls.GradientB2:SetSizeX(screenX);
	Controls.HeaderDropshadow:SetSizeX(screenX);
	Controls.HeaderGrid:SetSizeX(screenX);
end

-- ===========================================================================
--	Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()

	StopSound();

	local isDone:boolean  = true;

	-- Find first entry in table, display that, then remove it from the internal queue
	for i, entry in ipairs(m_kQueuedPopups) do
		ShowPopup(entry);
		table.remove(m_kQueuedPopups, i);
		isDone = false;
		break;
	end

	-- If done, restore engine processing and let the world know.
	if isDone then
		m_kCurrentPopup = nil;		
		LuaEvents.ProjectBuiltPopup_Closed();	-- Signal other systems (e.g., bulk hide UI)
		UnlockPopupSequence();
	end		
end

-- ===========================================================================
function StopSound()
	UI.PlaySound("Stop_Rocket_Launches");
	UI.PlaySound("UnMute_Narrator_Advisor_All");
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kCurrentPopup", m_kCurrentPopup);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_popupSupportEventID", m_popupSupportEventID);	-- In popupsupport
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["isHidden"] ~= nil and contextTable["isHidden"] == false then
			if contextTable["m_kCurrentPopup"] ~= nil then
				m_kCurrentPopup = contextTable["m_kCurrentPopup"];
				ShowPopup(m_kCurrentPopup);
			end
		end
		m_popupSupportEventID = contextTable["m_popupSupportEventID"];
	end
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function KeyHandler( key:number )
    if key == Keys.VK_ESCAPE then
		Close();
		return true;
    end
    return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end 

-- ===========================================================================
function Initialize()	
	if GameConfiguration.IsAnyMultiplayer() then return; end	-- Do not use if a multiplayer mode.

	ContextPtr:SetInputHandler( OnInputHandler, true );
	Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);
	Events.CityProjectCompletedNarrative.Add( OnProjectComplete );	
	Events.SystemUpdateUI.Add( OnUpdateUI );	

	-- Hot-Reload Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
end
Initialize();