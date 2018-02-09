--[[
-- Last modifed by Samuel Batista on Jun 28 2017
-- Original Author: Samuel Batista
-- Copyright (c) Firaxis Games
--]]

include("PopupDialog");
local m_PopupDialog:table;

-- ===========================================================================
-- PopupDialog functionality
-- ===========================================================================
function OnPopupOpen( uniqueStringName:string, options:table )

	-- If no options were passed in, fill with generic options.
	if options == nil or #options == 0 then
		options = {};
		options[1] = { Type="Text",	Content=TXT_ARE_YOU_SURE};
		options[2] = { Type="Button", Content=TXT_ACCEPT, CommandString=PopupDialog.COMMAND_CONFIRM };
		options[3] = { Type="Button", Content=TXT_CANCEL, CommandString=PopupDialog.COMMAND_CANCEL };
		UI.DataError("Using generic popup because no options were passed in.");
	end

	m_PopupDialog:Reset();
	
	for _, option in ipairs(options) do
		local optionType:string = option.Type;
		if optionType ~= nil then
			if		optionType == "Text"	then m_PopupDialog:AddText( option.Content );
			elseif	optionType == "Button"	then
				-- Make sure to call OnClosePopup so DequeuePopup gets called
				local closeAndCallback:ifunction = function() OnClosePopup(); if option.Callback then option.Callback(); end end
				m_PopupDialog:AddButton( option.Content, closeAndCallback, option.CommandString );
			elseif	optionType == "Count"	then m_PopupDialog:AddCountDown( option.Content, option.Callback );
			elseif	optionType == "Title"	then m_PopupDialog:AddTitle(option.Content);
			else
				UI.DataError("Unhandled type '"..optionType.."' for '"..uniqueStringName.."'");
			end
		else
			UI.DataError( "An option was passed to PopupGeneric without a Type specified for '"..uniqueStringName.."'" );
		end
	end
	
	UIManager:PushModal(ContextPtr);
	m_PopupDialog:Open();
end

function OnClosePopup()
	UIManager:PopModal(ContextPtr);
	if m_PopupDialog:IsOpen() then
		m_PopupDialog:Close();
	end
end

-- ===========================================================================
-- ESC handler
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
	if(m_PopupDialog and m_PopupDialog:IsOpen()) then
		if uiMsg == KeyEvents.KeyUp then
			if wParam == Keys.VK_ESCAPE then -- Try CANCEL. Then DEFAULT. Then give up and close window.
				if ( not m_PopupDialog:ActivateCommand( PopupDialog.COMMAND_CANCEL ) ) then
					if ( not m_PopupDialog:ActivateCommand( PopupDialog.COMMAND_DEFAULT ) ) then
						OnClosePopup();
					end
				end
			elseif wParam == Keys.VK_RETURN then -- Try CONFIRM. Then DEFAULT. Then give up and close window.
				if ( not m_PopupDialog:ActivateCommand( PopupDialog.COMMAND_CONFIRM ) ) then
					if ( not m_PopupDialog:ActivateCommand( PopupDialog.COMMAND_DEFAULT ) ) then
						OnClosePopup();
					end
				end
			end
		end
		return true; -- eat all the input, just in case. popups are blocking!
	end
	return false;
end

-- ===========================================================================
function Initialize()
	m_PopupDialog = PopupDialog:new("InGamePopup");
	ContextPtr:SetInputHandler(InputHandler);
	LuaEvents.OnRaisePopupInGame.Add(OnPopupOpen);
	LuaEvents.Tutorial_TutorialEndHideBulkUI.Add(OnClosePopup);
end
Initialize();
