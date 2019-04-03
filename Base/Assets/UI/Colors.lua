-- Image/tinting Color values referebced by LUA
-- Common format is 0xBBGGRRAA (BB blue, GG green, RR red, AA alpha)
-- Text colors should not be defined here, those go in the color atlas and/or DB!
COLORS =
{
	METER_HP_GOOD			= UI.GetColorValueFromHexLiteral(0xFF4BE810),
	METER_HP_OK				= UI.GetColorValueFromHexLiteral(0xFF2DFFF8),
	METER_HP_BAD			= UI.GetColorValueFromHexLiteral(0xFF0101F5),

	METER_HP_GOOD_SHADOW	= UI.GetColorValueFromHexLiteral(0x994BE810),
	METER_HP_OK_SHADOW		= UI.GetColorValueFromHexLiteral(0x992DFFF8),
	METER_HP_BAD_SHADOW		= UI.GetColorValueFromHexLiteral(0x990101F5),

	BUTTONTEXT_SELECTED		= UI.GetColorValueFromHexLiteral(0xFF291F10),
	BUTTONTEXT_NORMAL		= UI.GetColorValueFromHexLiteral(0xFFC9DAE7),
	BUTTONTEXT_DISABLED		= UI.GetColorValueFromHexLiteral(0xFF90999F),

	DEBUG					= UI.GetColorValueFromHexLiteral(0x1020ff80)
}

-- ===========================================================================
--	Transforms a ABGR color by some amount
--	ARGS:	hexColor	Hex color value (0xAAGGBBRR)
--			amt			(0-255) the amount to darken or lighten the color
--			alpha		(0-255) amount of opacity
--	RETURNS:	transformed color (0xAAGGBBRR)
-- ===========================================================================
function DarkenLightenColor( hexColor:number, amt:number, alpha:number )
	print("Global DarkenLightenColor has been deprecated.  Use UI.DarkenLightenColor instead.");
	return UI.DarkenLightenColor(hexColor, amt, alpha);
end

-- ===========================================================================
-- Convert a set of values (red, green, blue, alpha) into a single hex value.
-- Values are from 0.0 to 1.0
-- return math.floor(value is a single, unsigned uint as ABGR
-- ===========================================================================
function RGBAValuesToABGRHex( red, green, blue, alpha )
	print("Global RGBAValuesToABGRHex has been deprecated.  Use UI.GetColorValue instead.");
	return UI.GetColorValue(red, green, blue, alpha);
end