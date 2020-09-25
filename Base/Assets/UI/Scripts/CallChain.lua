-- ===========================================================================
--	Dynamic Call Chain
--	Copyright 2020, Firaxis Games
--
--	Support building a list of functions (with the same name) and using
--	rules determine how they are called.
--
--	USAGE:	
--			-- Setup
--			myCaller = DynamicCaller:new("myFuncName");
--			myCaller.AddCaller("base", myFunc);							-- In base file
--			myCaller.AddCaller("xp1", myFunc, {Before="base"} );		-- In XP1 include file
--			myCaller.AddCaller("xp2", myFunc, {After={"base","xp1"}} )	-- In XP2 file (run before either base or XP1 runs)
--
--			-- Make ordered calls
--			func = myCaller:GetFirstCall("myFuncName");
--			while( func ) do
--				func();
--				func = myCaller:GetNextCall("myFuncName");
--			end
--			
-- ===========================================================================
print("Dynamic Call chain included by '"..where(1).."'.");



-- ===========================================================================
--	Class Table
-- ===========================================================================
DynamicCaller = {
	m_kDynamicCalls		= {};	-- Unordered blob of information to make calls
	m_kChainOrders		= {};	-- Cached calling chains
	m_kInProgressCalls	= {};	-- Track current fileid for a give call	
	m_functionName		= nil;	-- (optional if debug isn't used) specify the function name
}



-- ===========================================================================
--	Constructor
--	functionName,	Optional function name.  If not supplied it will be 
--					inferred from the Add() call (if "debug" object is 
--					compiled into the build).
-- ===========================================================================
function DynamicCaller.new(self , functionName:string)
	local o = {};
	setmetatable(o, self);
	self.__index = self;

	o.m_kDynamicCalls	= {};
	o.m_kChainOrders	= {};
	o.m_kInProgressCalls= {};
	o.m_functionName	= functionName;

	return o;
end


-- ===========================================================================
--	fileid			Name of the file context for this dynamic call (e.g., "base","xp1","sukrit")
--	func			The actual function.
--	kRequirements	An optional table with "Before" and "After" requirements
--					which represent ids of functions that need to run before
--					and after the function call.
-- ===========================================================================
function DynamicCaller:AddCall( fileid:string, func:ifunction, kRequirements:table  )
	kRequirements		= kRequirements or {};

	-- Allow auto-wrapping if a single before/after id is passed in.
	if kRequirements.Before and type(kRequirements.Before) == "string" then
		kRequirements.Before = {kRequirements.Before};		
	end
	local kBefore:table	= kRequirements.Before or {};

	if kRequirements.After and type(kRequirements.After) == "string" then
		kRequirements.After = {kRequirements.After};		
	end
	local kAfter:table	= kRequirements.After or {};

	-- Get object's function name or attempt to determine via debug system.
	local funcName		:string= "";
	if self.m_functionName then 
		funcName = self.m_functionName;
	elseif (debug) then
		funcName = debug.getinfo( func, 'n').name;	-- Extract the name of the function as a string
	else
		UI.DataError("Unable to determine the function name for AddCall('"..fileid.."'...");
		return;
	end	
	
	-- Grab (or make) call table.
	local kCallTable 	:table = self.m_kDynamicCalls[funcName] or {};
	local kCall			:table = kCallTable[fileid];
	if kCall ~= nil then
		UI.DataError("Setting dynamic call '"..funcName.."' for file context '"..fileid.."' but it's already been set by that context. (Copy/Paste error for the file context id?)");
		return;
	end

	kCall = {Func=func, Before=kBefore, After=kAfter}; 	-- Set values;
	
	-- Set new call into table.
	kCallTable[fileid] = kCall;
	self.m_kDynamicCalls[funcName] = kCallTable;	
end


-- ===========================================================================
--	Helper: Is a string in a simple list table (array).
-- ===========================================================================
function DynamicCaller:IsInList( value:string, kList:table )
    for _,v in ipairs(kList) do
        if v == value then return true; end
    end
    return false;
end

-- ===========================================================================
--	Helper: remove string from list table (array).
-- ===========================================================================
function DynamicCaller:RemoveFromList( value:string, kList:table )    
	for i,v in ipairs(kList) do
        if v == value then table.remove( kList, i ); return kList; end
    end
	return kList;
end

-- ===========================================================================
--	Helper: Build a table of indexes (keyed by value) for each item in a table.
-- ===========================================================================
function DynamicCaller:GetIndexTable( kTable:table )
	local kIndexes:table = {};
	for i,id in ipairs(kTable) do
		kIndexes[id] = i;
	end
	return kIndexes;
end

-- ===========================================================================
--	Helper:	Pop the highest indexed string from an ordered list based on if it
--			is found with a "pop" list. 
--	RET:	String is returned as well as removed from the "pop" list.
-- ===========================================================================
function DynamicCaller:PopHighestInList( kOrdered:table, kPopList:table )
	local kIndexes	:table = self:GetIndexTable( kOrdered );	
	local count		:number = table.count( kIndexes );
	for i=count,1,-1 do
		if self:IsInList(kOrdered[i], kPopList) then
			self:RemoveFromList( kOrdered[i], kPopList );
			return kOrdered[i];
		end
	end
end

-- ===========================================================================
--	For each item walk as far from start to end (left to right) to add an
--	item to the ordered list.  For the new item, check both its rules and
--	any rules of an existing placed item.  If it goes to far, then send it
--	backwards to the front and stop when either at the start or another rule
--	stops its movement.
--
--	WARNING: Circular references will not be found but infinite calls also
--	cannot happen. 
--	TODO: Figure a check out for circular references. 
--
-- kCallTable, 	A table with each key being an id and value being a table
--				holding: {Func=..., Before={}, After={}}
-- Ret: An ordered array of ids representing the order in which function calls
--		should be made.
-- ===========================================================================
function DynamicCaller:BuildCallChainOrder( kCallTable:table )
	local kOrdered		: table = {};
	local kEvaluateBack	: table = {};	-- ids to evaluate one more time, moving backwards.

	-- For each item in call table.
	for id,kCall in pairs(kCallTable) do
		local count	:number = table.count(kOrdered);				
		local index :number = 1;
		local isErrorBreak	:boolean = false;	--Use to early break out of nested for loops
		local isMoveBack	:boolean = false;

		
		-- For each item that has already been added to the ordered list.
		for idx	:number = 1,count,1 do
			local existingid :string = kOrdered[idx];	-- Already placed id.
			if id == existingid then
				UI.DataAssert("Two calls were added with the same id '"..id.."'.  This may result in an unstable callchain order.")
				isErrorBreak = true;
				break;
			end			
			
			-- Check this new item's list to see if it needs to be relative to what is placed.
			if self:IsInList(existingid, kCall.After) then
				isMoveBack = true;
				break;
			end

			-- If new item doesn't reference the existing item, then look at the existing item's rule.
			local kExistingItemCall:table = kCallTable[existingid];
			if self:IsInList(id, kExistingItemCall.Before) then
				isMoveBack = true;
				break;
			end

			index = idx + 1; -- Moving ahead
		end

		-- Sent backwards, keep going until reaching start or rules stops it.
		if isMoveBack then
			for idx	:number = index,1,-1 do
				local existingid :string = kOrdered[idx];	-- Already placed id.

				-- Check this new item's list to see if it needs to be relative to what is placed.
				if self:IsInList(existingid, kCall.Before) then
					break;
				end

				-- If new item doesn't reference the existing item, then look at the existing item's rule.
				local kExistingItemCall:table = kCallTable[existingid];
				if self:IsInList(id, kExistingItemCall.After) then
					break;
				end
				index = idx;
			end
		else
			-- If it made it to the very end, it will need to be evaluated one more time as there might be rules to apply against items added aftrer this.
			if isErrorBreak==false then
				table.insert(kEvaluateBack, id);
			end
		end

		-- Only add item if an error did not occur for this item.
		if isErrorBreak==false then						
			table.insert(kOrdered, index, id);
		end
	end

	-- Ordered list is filled out but one more evaluation is needed for
	-- any items that traveled all the way to the "end" of the list and
	-- yet more items were added after it.  
	
	-- These items now need to make one more attempt to go back to the
	-- front of the list, stopping once a before/after rule prevents
	-- it from moving.
	
	-- Loop through back evaluation items from highest index to lowest index.
	id = self:PopHighestInList( kOrdered, kEvaluateBack );
	while (id ~= nil) do 
	
		local kIndexes	:table = self:GetIndexTable( kOrdered );	-- May change each evaluation.
		local count		:number = kIndexes[id];				-- Count is the current position
		local index		:number = count;					-- Start at current position (may go down to 1)
		local kCall		:table  = kCallTable[id];

		for idx	:number = count-1,1,-1 do
			local existingid :string = kOrdered[idx];	-- Already placed id.

			-- If the prior item needs to be before this one, its done.
			if self:IsInList(existingid, kCall.Before) then
				break;
			end

			-- If this id needs to be after the prior item, its done.
			local kExistingItemCall:table = kCallTable[existingid];
			if self:IsInList(id, kExistingItemCall.After) then
				break;
			end

			index = idx;	-- Adjust locationl; now one index further towards start.
		end

		table.insert(kOrdered, index, table.remove(kOrdered, kIndexes[id]));	-- Swap to potentially new, earlier position.

		id = self:PopHighestInList( kOrdered, kEvaluateBack );
	end

	return kOrdered;
end


-- ===========================================================================
--	funcName,	The name of the function to get the first call for.
--	RET:	The first function in the call chain or nil if there is none.
-- ===========================================================================
function DynamicCaller:GetFirstCall( funcName:string )

	local kCallTable 	:table = self.m_kDynamicCalls[funcName];
	if kCallTable == nil then
		UI.DataAssert("The dynamic call function for '"..funcName.."' but that doesn't exist in the dynamic function table.  Either it forgot to be added, or was never intended to be a dynamic function.");
		return nil;
	end

	-- Attempt to grab chain order from the cache, if none exists then
	-- build the chain order and save it in the cache.
	local kChainOrder:table = self.m_kChainOrders[funcName];
	if kChainOrder == nil then
		kChainOrder = self:BuildCallChainOrder(kCallTable);		-- e.g, {"base", "xp1", "xp2"} 
		self.m_kChainOrders[funcName] = kChainOrder;
	end

	-- If chain order is still nil, there is no chain.
	if kChainOrder == nil then
		return nil;
	end

	local firstid:string = kChainOrder[1];
	self.m_kInProgressCalls[funcName] = firstid;
	return kCallTable[firstid].Func;
end


-- ===========================================================================
function DynamicCaller:GetNextCall( funcName:string )
	local kChainOrder	:table = self.m_kChainOrders[funcName];
	local fileid 		:string = self.m_kInProgressCalls[funcName];

	-- Check environment has a call chain.
	if kChainOrder == nil then
		UI.DataError("Attempt to get next call for function '"..funcName.."' from context '"..fileid.."' but there is no callchain!  Did you check for nil when calling GetFristDynamicCall()?");
		return nil;
	end

	-- TODO: Is better to error here or auto call the first in the list?
	if fileid == nil then 		
		-- UI.DataError("Attempt to get next call for function '"..funcName.."' but there is no stored fileid from the first call to GetFirstCall().  Was it called?");
		-- return nil;
		return self:GetFirstCall( funcName );
	end
	
	local kCallTable 	:table = self.m_kDynamicCalls[funcName];
	if kCallTable == nil then
		UI.DataAssert("Unable to get the next call for function '"..funcName.."', it doesn't exist in the call table.");
		return nil;
	end

	-- Loop through until end.
	local isGrabNext:boolean = false;
	for _,id in ipairs(kChainOrder) do
		if isGrabNext then			
			self.m_kInProgressCalls[funcName] = id;
			return kCallTable[id].Func;
		end

		-- If the fileid passed in matches the current one in the chain, it
		-- means the next id in chain is the one 
		if id==fileid then
			isGrabNext = true;
		end
	end

	self.m_kInProgressCalls[funcName] = nil;
	return nil;
end


-- ===========================================================================
--	Debug: Print out a specific call chain.
-- ===========================================================================
function DynamicCaller:PrintCallChain( funcName:string )
	local kCallChain:table = self.m_kChainOrders[funcName];
	if kCallChain == nil then
		print( "Chain '"..funcName.."': doe not exist; may need to be generated via GetFirstCall()");
		return;
	end
	print( "Chain '"..funcName.."': ", unpack(kCallChain) );
end

-- ===========================================================================
--	Debug: Print out all the call chains.
-- ===========================================================================
function DynamicCaller:PrintAllCallChains()
	print("Printing ALL the dynamic call chains:");
	for funcName,_ in pairs(self.m_kDynamicCalls) do
		self:PrintCallChain( funcName );
	end
end

-- ===========================================================================
--	Debug: Print out all the call chains.
-- ===========================================================================
function DynamicCaller:PrintDynamicCallRules()
	for funcName,kCallTable in pairs(self.m_kDynamicCalls) do
		print("Dynamic call rules for '"..funcName.."':");
		for id,kRules in pairs(kCallTable) do
			local before:string = table.concat(kRules.Before,",") or "";
			local after	:string = table.concat(kRules.After,",") or "";
			print("  '"..id.."' before:{"..before.."}   after:{"..after.."}   func: ", kRules.Func);
		end
	end
end




-- ===========================================================================
--
--	USE CASE
--
-- ===========================================================================

-- Any order, may change based on run
function TestCase1_NoOrder()	
	local oCaller :object = DynamicCaller:new("foo");	

	function foo() print("a"); end
	local a = foo;
	function foo() print("b"); end
	local b = foo;
	function foo() print("c"); end
	local c = foo;
	
	oCaller:AddCall( "a", a );	
	oCaller:AddCall( "b", b );
	oCaller:AddCall( "c", c );
	
	oCaller:PrintDynamicCallRules();	

	local f = oCaller:GetFirstCall("foo");
	oCaller:PrintAllCallChains();
	while( f ) do
		f();
		f = oCaller:GetNextCall("foo");
	end
end


-- Order based on what is support to run before it
function TestCase2_BeforeOrder()
	local oCaller :object = DynamicCaller:new();
	function foo() print("a"); end
	oCaller:AddCall("a", foo);

	function foo() print("b"); end
	oCaller:AddCall("b", foo, {Before={"a"}} );
	
	function foo() print("c"); end	
	oCaller:AddCall("c", foo, {Before={"b"}} );		

	local f = oCaller:GetFirstCall("foo");
	oCaller:PrintCallChain("foo");
	while( f ) do
		f();
		f = oCaller:GetNextCall("foo");
	end
end

-- Order based on what is support to run before it (added in opposit order)
function TestCase3_BeforeOrder()
	local oCaller :object = DynamicCaller:new();
	function foo() print("c"); end	
	oCaller:AddCall("c", foo, {Before={"b"}} );		

	function foo() print("b"); end
	oCaller:AddCall("b", foo, {Before={"a"}} );

	function foo() print("a"); end
	oCaller:AddCall("a", foo);
	
	local f = oCaller:GetFirstCall("foo");
	oCaller:PrintCallChain("foo");
	while( f ) do
		f();
		f = oCaller:GetNextCall("foo");
	end
end

function TestCase4_AfterOrder()
	local oCaller :object = DynamicCaller:new();
	function foo() print("a"); end	
	oCaller:AddCall("a", foo, {After={"b"}} );
	function foo() print("b"); end	
	oCaller:AddCall("b", foo, {After={"c"}} );
	function foo() print("c"); end	
	oCaller:AddCall("c", foo );
	
	local f = oCaller:GetFirstCall("foo");
	oCaller:PrintCallChain("foo");
	while( f ) do
		f();
		f = oCaller:GetNextCall("foo");
	end
end


-- Same as after order but in reverse adding
function TestCase5_AfterOrder()
	local oCaller :object = DynamicCaller:new();
	function foo() print("c"); end	
	oCaller:AddCall("c", foo );
	function foo() print("b"); end	
	oCaller:AddCall("b", foo, {After={"c"}} );
	function foo() print("a"); end	
	oCaller:AddCall("a", foo, {After={"b"}} );
	
	local f = oCaller:GetFirstCall("foo");
	oCaller:PrintCallChain("foo");
	while( f ) do
		f();
		f = oCaller:GetNextCall("foo");
	end
end

-- Same as after order but in reverse adding
function TestCase6_NeedReorder()
	local oCaller :object = DynamicCaller:new();	
	function foo() print("a"); end	
	oCaller:AddCall("a", foo );
	function foo() print("c"); end	
	oCaller:AddCall("c", foo);
	function foo() print("b"); end	
	oCaller:AddCall("b", foo, {Before={"a"}, After={"c"} } );
	
	local f = oCaller:GetFirstCall("foo");
	oCaller:PrintCallChain("foo");
	while( f ) do
		f();
		f = oCaller:GetNextCall("foo");
	end
end


function TestCase7_ComplexOrder()
	local oCaller :object = DynamicCaller:new();	

	function foo() print("a"); end		
	oCaller:AddCall("a", foo );

	function foo() print("b"); end	
	oCaller:AddCall("b", foo, {Before="a"} );	

	function foo() print("c"); end	
	oCaller:AddCall("c", foo, {Before={"a","b"}, After="d"} );

	function foo() print("d"); end	
	oCaller:AddCall("d", foo, {Before="a",After={"c"}} );

	function foo() print("e"); end	
	oCaller:AddCall("e", foo, {Before={"a","d"}} );

	oCaller:PrintDynamicCallRules();

	local f = oCaller:GetFirstCall("foo");
	oCaller:PrintCallChain("foo");
	while( f ) do
		f();
		f = oCaller:GetNextCall("foo");
	end
end


-- Uncomment to test any
--TestCase1_NoOrder();
--TestCase2_BeforeOrder();
--TestCase3_BeforeOrder();
--TestCase4_AfterOrder();
--TestCase5_AfterOrder();
--TestCase6_NeedReorder();
--TestCase7_ComplexOrder();
