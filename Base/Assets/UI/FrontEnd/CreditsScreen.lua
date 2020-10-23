-- ===========================================================================
--	Credits
--
--	Format: [#]Text
--	Where # is  1: Major title
--				2: Minor title
--				3: Heading
--				4: Name
--				i: Image
-- ===========================================================================
include( "InstanceManager" );


-- ===========================================================================
--	Variables
-- ===========================================================================
local m_BlankIM		:table = InstanceManager:new("BlankInstance",		"Top",	Controls.CreditsList);
local m_EntryIM		:table = InstanceManager:new("EntryInstance",		"Text", Controls.CreditsList);
local m_HeadingIM	:table = InstanceManager:new("HeadingInstance",		"Text", Controls.CreditsList);
local m_ImageIM		:table = InstanceManager:new("ImageInstance",		"Image",Controls.CreditsList);
local m_MajorTitleIM:table = InstanceManager:new("MajorTitleInstance",	"Text", Controls.CreditsList);
local m_MinorTitleIM:table = InstanceManager:new("MinorTitleInstance",	"Text", Controls.CreditsList);
local m_TurboMode   :boolean = false;

CreditsData = nil;
CreditsIndex = 1;

-- ===========================================================================
function OnClose()

	-- Stop the scrolling to prevent callbacks while the screen is closed.
	Controls.SlideAnim:Stop();

	-- Cleanup instances.
	removeEntries();

	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function OnCreditScrollComplete()
	if ContextPtr:IsVisible() and CreditsData ~= nil then
		CreditsIndex = CreditsIndex + 1;
		if(CreditsIndex > #CreditsData) then
			CreditsIndex = 1;
		end

		DisplayCredits(CreditsIndex);
	end
end
-- ===========================================================================
--	Key Down Processing
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
    
	if uiMsg == KeyEvents.KeyDown then
		local key:number = pInputStruct:GetKey();
		-- "T"urbo mode... for debugging.
		if key == Keys.T and pInputStruct:IsShiftDown() and pInputStruct:IsAltDown() then
			m_TurboMode = true;
			Controls.SlideAnim:SetSpeed(0.05);
		end

		-- "R"everse (fast)... more debugging.
		if key == Keys.R and pInputStruct:IsShiftDown() and pInputStruct:IsAltDown() then
			Controls.SlideAnim:SetSpeed( -0.004 );
		end
	end
	
	if uiMsg == KeyEvents.KeyUp then
		local key:number = pInputStruct:GetKey();
        if( key == Keys.VK_RETURN or key == Keys.VK_ESCAPE ) then
			OnClose();
        end

		-- Allow for pausing via spacebar
		if key == Keys.VK_SPACE then
			if Controls.SlideAnim:IsStopped() then
				Controls.SlideAnim:Play();
			else
 				Controls.SlideAnim:Stop();
			end
		end

		if key == Keys.T then
            if m_TurboMode then
                Controls.SlideAnim:SetSpeed(0.0015);
                m_TurboMode = false;
            end
		end

    end
    return true;
end


-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
	if type == SystemUpdateUI.ScreenResize then
		Resize();
	end
end


-- ===========================================================================
-- ===========================================================================
function OnShow()

	CreditsData = DB.ConfigurationQuery("SELECT * FROM Credits ORDER BY SortOrder ASC");
	if(CreditsData and #CreditsData > 0) then
		local choice = Controls.CreditsChoice;
		if(#CreditsData == 1) then
			choice:SetHide(true);
		else
			choice:ClearEntries();
			for i,v in ipairs(CreditsData) do
				local entry = {};
				choice:BuildEntry( "InstanceOne", entry );
				entry.Button:SetText(Locale.Lookup(v.DisplayName));
				entry.Button:RegisterCallback(Mouse.eLClick, function()	
					DisplayCredits(i);
				end);
			end
			choice:CalculateInternals();
			choice:SetHide(false);
		end

		DisplayCredits(1);
	end

    m_TurboMode = false;
end

-- ===========================================================================
function Resize()
	Controls.BackButton:ReprocessAnchoring();	
	Controls.InitialSpace:ReprocessAnchoring();
	Controls.CreditsList:CalculateSize();
	Controls.MajorScroll:CalculateSize();
	ContextPtr:ReprocessAnchoring();
end

-- ===========================================================================
function DisplayCredits(creditsIndex)
	CreditsIndex = creditsIndex;
	local credits = CreditsData[CreditsIndex];

	-- Update the drop-down to reflect the current selection.
	local button = Controls.CreditsChoice:GetButton();
	button:LocalizeAndSetText(credits.DisplayName);

	removeEntries();
	if(credits) then
		removeEntries();
		local initialSpaceSize1 = -Controls.InitialSpace:GetSizeY();
		Controls.SlideAnim:SetRelativeEndVal(0, 0);
   		Controls.SlideAnim:SetToBeginning();
		Controls.CreditsList:CalculateSize();		
		Controls.MajorScroll:CalculateInternalSize();

		generateCredits(credits.Credits);
			
		Controls.CreditsList:CalculateSize();		
		Controls.CreditsList:ReprocessAnchoring();		
		Controls.MajorScroll:CalculateInternalSize();

		Resize();

		local sizeY = -Controls.CreditsList:GetSizeY();
		Controls.SlideAnim:SetRelativeEndVal(0, sizeY );
   		Controls.SlideAnim:SetToBeginning();
   		Controls.SlideAnim:Play();

		local speed = math.abs(65/sizeY);
		Controls.SlideAnim:SetSpeed(speed);
	end
end

----------------------------------------------------------------        
---------------------------------------------------------------- 
function removeEntries()
	m_BlankIM:DestroyInstances();
	m_MajorTitleIM:DestroyInstances();
	m_MinorTitleIM:DestroyInstances();
	m_HeadingIM:DestroyInstances();
	m_ImageIM:DestroyInstances();
	m_EntryIM:DestroyInstances();
end
----------------------------------------------------------------        
---------------------------------------------------------------- 
function generateCredits(creditsKey)
	if Locale.HasTextKey(creditsKey) then
		local creditsFile:string  = Locale.Lookup(creditsKey);
		
		if creditsFile then		
			local creditsTable:table = makeTable(creditsFile);
			if creditsTable then
				generateEntries(creditsTable);
			end
		end
	end
end

----------------------------------------------------------------        
---------------------------------------------------------------- 
function generateEntries(creditsTable)
	--print each line out, with header information formatting string
	for key,currentLine in ipairs(creditsTable) do	

		local indexOpen		:number = 1;  --currentLine.find("\[");	
		if indexOpen ~= nil and indexOpen > 0 then
			local creditHeader	:string = string.upper( string.sub(currentLine, indexOpen+1, indexOpen+1) );
			local creditLine	:string = string.sub(currentLine, 4);

			if creditLine == "" then
				local blankInstance = m_BlankIM:GetInstance();
			elseif creditHeader == "1" then	
				local majorTitle = m_MajorTitleIM:GetInstance();
				majorTitle.Text:SetText( Locale.ToUpper(creditLine) );	-- Make upp for small caps action
			elseif creditHeader == "2" then	
				local minorTitle = m_MinorTitleIM:GetInstance();
				minorTitle.Text:SetText( Locale.ToUpper(creditLine) );	-- Make upp for small caps action
			elseif creditHeader == "3" then	
				local heading = m_HeadingIM:GetInstance();
				heading.Text:SetText(creditLine);
			elseif creditHeader == "I" then
				local entry = m_ImageIM:GetInstance();
				entry.Image:SetTexture(creditLine);
			else
				-- Default (formally "4")
				local entry = m_EntryIM:GetInstance();
				entry.Text:SetText(creditLine);
			end
		end
	end		
end
----------------------------------------------------------------        
---------------------------------------------------------------- 
function makeTable(creditsFile)
	
	local i = 0;
	local prev_i = 1;
	local t = {};
	while true do
		local nChars = 1;
		local crlf = string.find(creditsFile, "\r\n", i+1, true)
		if (crlf ~= nil) then
			-- handle CRLF line ending
			nChars = 2;
			i = crlf;
		else
			-- handle LF line ending
			i = string.find(creditsFile, "\n", i+1, true)
		end

		if i == nil then 
			local line :string = string.sub(creditsFile, prev_i);		
			table.insert(t, line);
			break;
		end

		local line :string = string.sub(creditsFile, prev_i, i - 1);		
		table.insert(t, line);
		prev_i = i + nChars;				-- past linefeed/newline 		
	end
	
	return t;
	
end


-- ===========================================================================
--	Initialize
-- ===========================================================================
function Initialize()

	ContextPtr:SetShowHandler( OnShow );	
	ContextPtr:SetInputHandler( OnInputHandler, true );

	Events.SystemUpdateUI.Add( OnUpdateUI );

	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnClose );
	Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.SlideAnim:RegisterEndCallback( OnCreditScrollComplete );
	
end
Initialize();
