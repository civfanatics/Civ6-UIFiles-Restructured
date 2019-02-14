-- Image/tinting Color values referebced by LUA
-- Common format is 0xBBGGRRAA (BB blue, GG green, RR red, AA alpha)
-- Text colors should not be defined here, those go in the color atlas and/or DB!

COLORS =
{
	METER_HP_GOOD			= 0xFF4BE810,
	METER_HP_OK				= 0xFF2DFFF8,
	METER_HP_BAD			= 0xFF0101F5,

	METER_HP_GOOD_SHADOW	= 0x994BE810,
	METER_HP_OK_SHADOW		= 0x992DFFF8,
	METER_HP_BAD_SHADOW		= 0x990101F5,

	BUTTONTEXT_SELECTED		= 0xFF291F10,
	BUTTONTEXT_NORMAL		= 0xFFC9DAE7,
	BUTTONTEXT_DISABLED		= 0xFF90999F,

	DEBUG					= 0x1020ff80
}



-- ===========================================================================
--	Transforms a ABGR color by some amount
--	ARGS:	hexColor	Hex color value (0xAAGGBBRR)
--			amt			(0-255) the amount to darken or lighten the color
--			alpha		(0-255) amount of opacity
--	RETURNS:	transformed color (0xAAGGBBRR)
-- ===========================================================================
function DarkenLightenColor( hexColor:number, amt:number, alpha:number )

	if hexColor == nil then
		UI.DataError("Setting color to white after receiving NIL hexColor for DarkenLightenColor(nil,"..tostring(amount)..","..tostring(alpha)..")");
	end

	-- Handle cases where hexColor may be nil.
	hexColor = hexColor or 0xFFFFFFFF;

	--Parse the a,g,b,r hex values from the string
	local hexString :string = string.format("%x",hexColor);
	local b = string.sub(hexString,3,4);
	local g = string.sub(hexString,5,6);
	local r = string.sub(hexString,7,8);
	b = tonumber(b,16);
	g = tonumber(g,16);
	r = tonumber(r,16);

	if (b == nil) then b = 0; end
	if (g == nil) then g = 0; end
	if (r == nil) then r = 0; end

	local a = string.format("%x",alpha);
	if (string.len(a)==1) then
			a = "0"..a;
	end

	b = b + amt;
	if (b < 0 or b == 0) then
		b = "00";
	elseif (b > 255 or b == 255) then
		b = "FF";
	else
		b = string.format("%x",b);
		if (string.len(b)==1) then
			b = "0"..b;
		end
	end

	g = g + amt;
	if (g < 0 or g == 0) then
		g = "00";
	elseif (g > 255 or g == 255) then
		g = "FF";
	else
		g = string.format("%x",g);
		if (string.len(g)==1) then
			g = "0"..g;
		end
	end

	r = r + amt;
	if (r < 0 or r == 0) then
		r = "00";
	elseif (r > 255 or r == 255) then
		r = "FF";
	else
		r = string.format("%x",r);
		if (string.len(r)==1) then
			r = "0"..r;
		end
	end

	hexString = a..b..g..r; 
	return tonumber(hexString,16);
end