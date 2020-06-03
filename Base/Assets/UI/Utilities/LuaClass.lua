-- Copyright 2017-2019, Firaxis Games.

LuaClass = {}

-- ===========================================================================
--	Syntatic sugar for obtaining an object (a table that may have funcs)
--
--	metaTableObject			The table with functions to base this new object
--	optionalExistingObject	If present then instead of a new table, this
--							table will be used to inherent the metaTable.
--
--	EXAMPLES:	m_oFoo = LuaClass:new( fooFunctionsObject, uiInstance );
--				m_oBar = LuaClass:new( barTypeOfFunctions );
-- ===========================================================================
function LuaClass:new( metaTableObject:table, optionalExistingObject:table )
	if metaTableObject == nil then 
		UI.DataAssert("NIL metaTableObject when creating a new LuaClass.");
		metaTableObject = {}; 
	end

	local oNewObject :table = optionalExistingObject and optionalExistingObject or {};
	setmetatable(oNewObject, { __index=metaTableObject } );
	return oNewObject;
end

-- ===========================================================================
function LuaClass:Extend()
	print("LuaClass:Extend() is deprecated!");
	return {};
end