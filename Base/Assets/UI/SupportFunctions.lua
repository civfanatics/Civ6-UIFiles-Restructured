------------------------------------------------------------------------------
-- Misc Support Functions
------------------------------------------------------------------------------

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local m_strEllipsis = Locale.Lookup("LOC_GENERIC_DOT_DOT_DOT");


-- ===========================================================================
--	Sets a Label or control that contains a label (e.g., GridButton) with
--	a string that, if necessary, will be truncated.
--
--	RETURNS: true if truncated.
-- ===========================================================================
function TruncateString(control, resultSize, longStr, trailingText)

	local textControl = control;

	-- Ensure this has the actual text control
	if control.GetTextControl ~= nil then
		textControl = control:GetTextControl();
		UI.AssertMsg(textControl.SetTruncateWidth ~= nil, "Calling TruncateString with an unsupported control");
	end

	-- TODO if trailingText is ever used, add a way to do it to TextControl
	UI.AssertMsg(trailingText == nil or trailingText == "", "trailingText is not supported");

	if(longStr == nil) then
		longStr = control:GetText();
	end
	
	--TODO a better solution than this function would be ideal
		--calling SetText implicitly truncates if the flag is set
		--a AutoToolTip flag could be made to avoid setting the tooltip from lua
		--trailingText could be added, right now its just an ellipsis but it could be arbitrary
		--this would avoid the weird type shenanigans when truncating TextButtons, TextControls, etc

	if textControl ~= nil then
		textControl:SetTruncateWidth(resultSize);

		if control.SetText ~= nil then
			control:SetText(longStr);
		else
			textControl:SetText(longStr);
		end
	else
		UI.AssertMsg(false, "Attempting to truncate a NIL control");
	end

	if textControl.IsTextTruncated ~= nil then
		return textControl:IsTextTruncated();
	else
		UI.AssertMsg(false, "Calling IsTextTruncated with an unsupported control");
		return true;
	end
end


-- ===========================================================================
--	Same as TruncateString(), but if truncation occurs automatically adds
--	the full text as a tooltip.
-- ===========================================================================
function TruncateStringWithTooltip(control, resultSize, longStr, trailingText)
	local isTruncated = TruncateString( control, resultSize, longStr, trailingText );
	if isTruncated then
		control:SetToolTipString( longStr );
	else
		control:SetToolTipString( nil );
	end
	return isTruncated;
end

-- ===========================================================================
--	Same as TruncateStringWithTooltip(), but removes leading white space
--	before truncation
-- ===========================================================================
function TruncateStringWithTooltipClean(control, resultSize, longStr, trailingText)
	local cleanString = longStr:match("^%s*(.-)%s*$");
	local isTruncated = TruncateString( control, resultSize, longStr, trailingText );
	if isTruncated then
		control:SetToolTipString( cleanString );
	else
		control:SetToolTipString( nil );
	end
	return isTruncated;
end


-- ===========================================================================
--	Performs a truncation based on the control's contents
-- ===========================================================================
function TruncateSelfWithTooltip( control )
	local resultSize = control:GetSizeX();
	local longStr	 = control:GetText();
	return TruncateStringWithTooltip(control, resultSize, longStr);
end


-- ===========================================================================
--	Truncate string based on # of characters
--	(Most useful when having to truncate a string *in* a tooltip.
-- ===========================================================================
function TruncateStringByLength( textString, textLen )
	if ( Locale.Length(textString) > textLen ) then
		return Locale.SubString(textString, 1, textLen) .. m_strEllipsis;
	end
	return textString;
end

-- ===========================================================================
-- Support for shifts
-- ===========================================================================
local g_supportFunctions_shiftTable = {};
g_supportFunctions_shiftTable[0] = 1;
g_supportFunctions_shiftTable[1] = 2;
g_supportFunctions_shiftTable[2] = 4;
g_supportFunctions_shiftTable[3] = 8;
g_supportFunctions_shiftTable[4] = 16;
g_supportFunctions_shiftTable[5] = 32;
g_supportFunctions_shiftTable[6] = 64;
g_supportFunctions_shiftTable[7] = 128;
g_supportFunctions_shiftTable[8] = 256;
g_supportFunctions_shiftTable[9] = 512;
g_supportFunctions_shiftTable[10] = 1024;
g_supportFunctions_shiftTable[11] = 2048;
g_supportFunctions_shiftTable[12] = 4096;
g_supportFunctions_shiftTable[13] = 8192;
g_supportFunctions_shiftTable[14] = 16384;
g_supportFunctions_shiftTable[15] = 32768;
g_supportFunctions_shiftTable[16] = 65536;
g_supportFunctions_shiftTable[17] = 131072;
g_supportFunctions_shiftTable[18] = 262144;
g_supportFunctions_shiftTable[19] = 524288;
g_supportFunctions_shiftTable[20] = 1048576;
g_supportFunctions_shiftTable[21] = 2097152;
g_supportFunctions_shiftTable[22] = 4194304;
g_supportFunctions_shiftTable[23] = 8388608;
g_supportFunctions_shiftTable[24] = 16777216;



-- ===========================================================================
--	Bit Helper function
--	Converts a number into a table of bits.
-- ===========================================================================
function numberToBitsTable( value:number )
	if value < 0 then
		return numberToBitsTable( bitNot(math.abs(value))+1 );	-- Recurse
	end

	local kReturn	:table = {};
	local i			:number = 1;
	while value > 0 do
		local digit:number = math.fmod(value, 2);
		if digit == 1 then
			kReturn[i] = 1;
		else
			kReturn[i] = 0;
		end
		value = (value - digit) * 0.5;
		i = i + 1;
	end

	return kReturn;
end

-- ===========================================================================
--	Bit Helper function
--	Converts a table of bits into it's corresponding number.
-- ===========================================================================
function bitsTableToNumber( kTable:table )
	local bits	:number = table.count(kTable);
	local n		:number = 0;
	local power :number = 1;
	for i = 1, bits,1 do
		n = n + kTable[i] * power;
		power = power * 2;
	end
	return n;
end

-- ===========================================================================
--	Bitwise not (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function bitNot( value:number )
	local kBits:table	= numberToBitsTable(value);
	local size:number	= math.max(table.getn(kBits), 32)
	for i = 1, size do
		if(kBits[i] == 1) then 
			kBits[i] = 0
		else
			kBits[i] = 1
		end
	end
	return bitsTableToNumber(kBits);
 end

 -- ===========================================================================
--	Bitwise or (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
 local function bitOr( na:number, nb:number)
	local ka :table = numberToBitsTable(na);
	local kb :table = numberToBitsTable(nb);

	-- Make sure both are the same size; pad with 0's if necessary.
	while table.count(ka) < table.count(kb) do ka[table.count(ka)+1] = 0; end
	while table.count(kb) < table.count(ka) do kb[table.count(kb)+1] = 0; end

	local kResult	:table	= {};
	local digits	:number = table.count(ka);
	for i:number = 1, digits, 1 do
		kResult[i] = (ka[i]==1 or kb[i]==1) and 1 or 0;
	end 
	return bitsTableToNumber( kResult );
end


-- ===========================================================================
-- Left shift (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function lshift( value, shift )
	return math.floor(value) * g_supportFunctions_shiftTable[shift];
end

-- ===========================================================================
-- Right shift (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function rshift( value:number, shift:number )
	local highBit:number = 0;

	if value < 0 then	
		value	= bitNot(math.abs(value)) + 1;
		highBit = 0x80000000;
	end

	for i=1, shift, 1 do
		value = bitOr( math.floor(value*0.5), highBit );
	end
	return math.floor(value);	
end


-- ===========================================================================
--	Determine if string is IP4, IP6, or invalid
--
--	Based off of: 
--	http://stackoverflow.com/questions/10975935/lua-function-check-if-ipv4-or-ipv6-or-string
--
--	Returns: 4 if IP4, 6 if IP6, or 0 if not valid
-- ===========================================================================
function GetIPType( ip )

    if ip == nil or type(ip) ~= "string" then
        return 0;
    end

    -- Check for IPv4 format, 4 chunks between 0 and 255 (e.g., 1.11.111.111)
    local chunks = {ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
    if (table.count(chunks) == 4) then
        for _,v in pairs(chunks) do
            if (tonumber(v) < 0 or tonumber(v) > 255) then
                return 0;
            end
        end
        return 4;	-- This is IP4
    end

	-- Check for ipv6 format, should be 8 'chunks' of numbers/letters without trailing chars
	local chunks = {ip:match(("([a-fA-F0-9]*):"):rep(8):gsub(":$","$"))}
	if table.count(chunks) == 8 then
		for _,v in pairs(chunks) do
			if table.count(v) > 0 and tonumber(v, 16) > 65535 then 
				return 0;
			end
		end
		return 6;	-- This is IP6
	end
	return 0;
end




-- ===========================================================================
--	LUA Helper function
-- ===========================================================================
function RemoveTableEntry( T:table, key:string, theValue )
	local pos = nil;
	for i,v in ipairs(T) do
		if (v[key]==theValue) then
			pos=i;	
			break;
		end
	end
	if(pos ~= nil) then
		table.remove(T, pos);
		return true;
	end
	return false;
end

-- ===========================================================================
--	LUA Helper function
-- ===========================================================================
-- Using Fisher-Yates algorithm
function ShuffleTable(tbl : table)
	if table == nil then return nil end;
	local size = #tbl;
	for i = size, 1, -1 do
		local rand = Game.GetRandNum(size, "Support: Shuffle Table") + 1;
		tbl[i], tbl[rand] = tbl[rand], tbl[i]
	end
	return tbl;
end

-- ===========================================================================
--	orderedPairs()
--	Allows an ordered iteratation of the pairs in a table.  Use like pairs().
--	Original version from: http://lua-users.org/wiki/SortedIteration
-- ===========================================================================
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end
function orderedNext(t, state)
    -- Equivalent of the next function, but returns the keys in the alphabetic order. 
	-- Using a temporary ordered key table that is stored in the table being iterated.
    key = nil;
    if state == nil then
        -- Is first time; generate the index.
        t.__orderedIndex = __genOrderedIndex( t );
        key = t.__orderedIndex[1];
    else
        -- Fetch next value.
        for i = 1,table.count(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1];
            end
        end
    end

    if key then
        return key, t[key];
	else
		t.__orderedIndex = nil;		-- No more value to return, cleanup.
    end    
end
function orderedPairs(t)    
    return orderedNext, t, nil;
end


-- ===========================================================================
--	Split()
--	Allows splitting a string (tokenizing) into an array based on a delimeter.
--	Original version from: http://lua-users.org/wiki/SplitJoin
--	RETURNS: Table of tokenized strings
-- ===========================================================================
function Split(str:string, delim:string, maxNb:number)
	-- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str };
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0;    -- No limit
    end
    local result:table = {};
    local pat	:string = "(.-)" .. delim .. "()";
    local nb	:number = 0;
    local lastPos:number;
    for part, pos in string.gmatch(str, pat) do
        nb = nb + 1;
        result[nb] = part;
        lastPos = pos;
        if nb == maxNb then 
			break;
		end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos);
    end
    return result;
end


-- ===========================================================================
--	Clamp()
--	Returns the value passed, only changing if it's above or below the min/max
-- ===========================================================================
function Clamp( value:number, min:number, max:number )
	if value < min then 
		return min;
	elseif value > max then
		return max;
	else
		return value;
	end
end

-- ===========================================================================
--	SoftRound()
--	Rounds the passed in parameter with no decimal places.
-- ===========================================================================
function SoftRound(x)
	if(x >= 0) then
		return math.floor(x+0.5);
	else
		return math.ceil(x-0.5);
	end
end


-- ===========================================================================
--	Round()
--	Rounds a number to X decimal places.
--	Original version from: http://lua-users.org/wiki/SimpleRound
-- ===========================================================================
function Round(num:number, idp:number)
  local mult:number = 10^(idp or 0);
  return math.floor(num * mult + 0.5) / mult;
end


-- ===========================================================================
--	RandRange()
--	Returns a value between min and max (inclusive) using gamecore synced RNG.
-- ===========================================================================
function RandRange(min:number, max:number, logString:string)
	logString = logString or "Support: Rand Range";
	if (Game.GetRandNum ~= nil) then
		return Game.GetRandNum(max - min, logString) + min;
	else
		return min;
	end
end

-- ===========================================================================
--	Triangular()
--	Returns the triangular number for n.
-- ===========================================================================
function Triangular(iN : number)
	-- Pos only
	iN = math.abs(iN);
	-- Whole numbers only
	iN = Round(iN);
	return iN * (iN + 1) / 2;
end


-- ===========================================================================
--	Convert polar coordiantes to Cartesian plane.
--	ARGS: 	r		radius
--			phi		angle in degrees (90 is facing down, 0 is pointing right)
--			ratio	y-axis to x-axis to "squash" the circle if desired
--
--	Unwrapped Circle:	local x = r * math.cos( math.rad(phi) );
--						local y = r * math.sin( math.rad(phi) );
--						return x,y;
-- ===========================================================================
function PolarToCartesian( r:number, phi:number )
	return r * math.cos( math.rad(phi) ), r * math.sin( math.rad(phi) );
end
function PolarToRatioCartesian( r:number, phi:number, ratio:number )
	return r * math.cos( math.rad(phi) ), r * math.sin( math.rad(phi) ) * ratio;
end

-- ===========================================================================
--	Recursively duplicate (deep copy)
--	Original from: http://lua-users.org/wiki/CopyTable
-- ===========================================================================
function DeepCopy( orig )
    local orig_type = type(orig);
    local copy;
    if orig_type == 'table' then
        copy = {};
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value);
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)));
    else -- number, string, boolean, etc
        copy = orig;
    end
    return copy;
end

-- ===========================================================================
--	Recursively compare two tables (ignoring metatable)
--  Original from: https://stackoverflow.com/questions/25922437/how-can-i-deep-compare-2-lua-tables-which-may-or-may-not-have-tables-as-keys
--	ARGS:	table1		table one
--			table2		table two
--	RETURNS:	true if tables have the same content, false otherwise
-- ===========================================================================
function DeepCompare( table1, table2 )
   local avoid_loops = {}

   local function recurse(t1, t2)      
	  -- Compare value types
      if type(t1) ~= type(t2) then return false; end
      
	  -- Compare simple values
      if type(t1) ~= "table" then return (t1 == t2); end
      
      -- First, let's avoid looping forever.
      if avoid_loops[t1] then return avoid_loops[t1] == t2; end
      avoid_loops[t1] = t2;

      -- Copy keys from t2
      local t2keys = {}
      local t2tablekeys = {}
      for k, _ in pairs(t2) do
         if type(k) == "table" then table.insert(t2tablekeys, k); end
         t2keys[k] = true;
      end

      -- Iterate keys from t1
      for k1, v1 in pairs(t1) do
         local v2 = t2[k1]
         if type(k1) == "table" then
            -- if key is a table, we need to find an equivalent one.
            local ok = false
            for i, tk in ipairs(t2tablekeys) do
               if DeepCompare(k1, tk) and recurse(v1, t2[tk]) then
                  table.remove(t2tablekeys, i)
                  t2keys[tk] = nil
                  ok = true
                  break;
               end
            end
            if not ok then return false; end
         else
            -- t1 has a key which t2 doesn't have, fail.
            if v2 == nil then return false; end
            t2keys[k1] = nil
            if not recurse(v1, v2) then return false; end
         end
      end
      -- if t2 has a key which t1 doesn't have, fail.
      if next(t2keys) then return false; end
      return true;
   end

   return recurse(table1, table2);
end