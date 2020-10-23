include( "ToolTipHelper_PlayerYields" );

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
TOP_PANEL_OFFSET = 29;
MIN_SPEC_HEIGHT = 768;



-- ===========================================================================
--	Refresh the yeilds
--	RETURNS: true if screen is taller than minspec height.
-- ===========================================================================
function RefreshYields()
		
	-- This panel should only show at minispec
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	if (screenY > MIN_SPEC_HEIGHT ) then
		Controls.YieldsContainer:SetHide(true);
		return false;
	end

	local ePlayer		:number = Game.GetLocalPlayer();
	local localPlayer	:table= nil;
	if ePlayer ~= -1 then
		localPlayer = Players[ePlayer];
		if localPlayer == nil then
			return false;
		end
	else
		return false;
	end

	local YIELD_PADDING_Y:number	= 12;

	---- SCIENCE ----
	if(GameInfo.GameCapabilities["CAPABILITY_SCIENCE"] ~= nil)then
		local playerTechnology		:table	= localPlayer:GetTechs();
		local currentScienceYield	:number = playerTechnology:GetScienceYield();
		Controls.SciencePerTurn:SetText( FormatValuePerTurn(currentScienceYield) );	

		Controls.ScienceBacking:SetToolTipString( GetScienceTooltip() );
		Controls.ScienceStack:CalculateSize();
		Controls.ScienceBacking:SetSizeX(Controls.ScienceStack:GetSizeX() + YIELD_PADDING_Y);
	else
		Controls.ScienceBacking:SetHide(true);
	end

	---- GOLD ----
	local playerTreasury:table	= localPlayer:GetTreasury();
	local goldYield		:number = playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance();
	local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());
	Controls.GoldBalance:SetText( Locale.ToNumber(goldBalance, "#,###.#") );	
	Controls.GoldPerTurn:SetText( FormatValuePerTurn(goldYield) );	

	Controls.GoldBacking:SetToolTipString( GetGoldTooltip() );

	Controls.GoldStack:CalculateSize();	
	Controls.GoldBacking:SetSizeX(Controls.GoldStack:GetSizeX() + YIELD_PADDING_Y);

	-- Size yields in first column to match largest
	if Controls.GoldBacking:GetSizeX() > Controls.ScienceBacking:GetSizeX() then
		-- Gold is wider so size Science to match
		Controls.ScienceBacking:SetSizeX(Controls.GoldBacking:GetSizeX());
	else
		-- Science is wider so size Gold to match
		Controls.GoldBacking:SetSizeX(Controls.ScienceBacking:GetSizeX());
	end
	
	---- CULTURE----
	if(GameInfo.GameCapabilities["CAPABILITY_CULTURE"] ~= nil)then
		local playerCulture			:table	= localPlayer:GetCulture();
		local currentCultureYield	:number = playerCulture:GetCultureYield();
		Controls.CulturePerTurn:SetText( FormatValuePerTurn(currentCultureYield) );	

		Controls.CultureBacking:SetToolTipString( GetCultureTooltip() );
		Controls.CultureStack:CalculateSize();
		Controls.CultureBacking:SetSizeX(Controls.CultureStack:GetSizeX() + YIELD_PADDING_Y);
	else
		Controls.CultureBacking:SetHide(true);
	end

	---- FAITH ----
	if(GameInfo.GameCapabilities["CAPABILITY_FAITH"] ~= nil)then
		local playerReligion		:table	= localPlayer:GetReligion();
		local faithYield			:number = playerReligion:GetFaithYield();
		local faithBalance			:number = playerReligion:GetFaithBalance();
		Controls.FaithBalance:SetText( Locale.ToNumber(faithBalance, "#,###.#") );	
		Controls.FaithPerTurn:SetText( FormatValuePerTurn(faithYield) );

		Controls.FaithBacking:SetToolTipString( GetFaithTooltip() );

		Controls.FaithStack:CalculateSize();	
		Controls.FaithBacking:SetSizeX(Controls.FaithStack:GetSizeX() + YIELD_PADDING_Y);
	else
		Controls.FaithBacking:SetHide(true);
	end

	-- Size yields in second column to match largest
	if Controls.FaithBacking:GetSizeX() > Controls.CultureBacking:GetSizeX() then
		-- Faith is wider so size Culture to match
		Controls.CultureBacking:SetSizeX(Controls.FaithBacking:GetSizeX());
	else
		-- Culture is wider so size Faith to match
		Controls.FaithBacking:SetSizeX(Controls.CultureBacking:GetSizeX());
	end

	Controls.YieldsContainer:SetHide(false);

	if Controls.ModalScreenClose ~= nil then
		Controls.ModalScreenClose:Reparent();
	end
	return true;
end

-- ===========================================================================
function FormatValuePerTurn( value:number )
	if(value == 0) then
		return Locale.ToNumber(value);
	else
		return Locale.Lookup("{1: number +#,###.#;-#,###.#}", value);
	end
end