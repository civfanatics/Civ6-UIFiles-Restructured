--include( "CallChain");

function Initialize()	
	print("Test.LUA loaded!");

	-- Uncomment callchain test case to try it out:
	--[[
	TestCase1_NoOrder();
	TestCase2_BeforeOrder();
	TestCase3_BeforeOrder();
	TestCase4_AfterOrder();
	TestCase5_AfterOrder();
	TestCase6_NeedReorder();
	TestCase7_ComplexOrder();
	]]
	
	--[[
	local oCaller :object = DynamicCaller:new();	
	function foo() print("base"); end		
	oCaller:AddCall("base", foo );
	function foo() print("xp1"); end	
	oCaller:AddCall("xp1", foo, {Before="base"} );	
	
	function foo() print("xp2"); end	
	oCaller:AddCall("xp2", foo, {Before={"base","xp1"}, After="stk-dlc4"} );
	
	function foo() print("stk-dlc4"); end	
	oCaller:AddCall("stk-dlc4", foo, {Before="base"} );
	
	function foo() print("lazymod"); end	
	oCaller:AddCall("lazymod", foo, {After="base"} );
	
	oCaller:PrintDynamicCallRules();
	local f = oCaller:GetFirstCall("foo");
	oCaller:PrintCallChain("foo");
	while( f ) do
		f();
		f = oCaller:GetNextCall("foo");
	end
	]]
	
	--Controls.foo:SetText(Locale.Lookup("LOC_SAVE_AT_MAXIMUM_CLOUD_SAVES_TOOLTIP"));
	--Controls.foo:LocalizeAndSetText("LOC_SAVE_AT_MAXIMUM_CLOUD_SAVES_TOOLTIP");
	
	--[[ test countdown
	local outdatedDriversPopupDialog:table = PopupDialog:new("OutdatedGraphicsDriver");
	outdatedDriversPopupDialog:AddText(Locale.Lookup("LOC_FRONTEND_POPUP_OUTDATED_DRIVER"));
	outdatedDriversPopupDialog:AddCountDown( 15, function() print("yay!"); end );
	outdatedDriversPopupDialog:AddButton(Locale.Lookup("LOC_FRONTEND_POPUP_OUTDATED_DRIVER_QUIET"));
	outdatedDriversPopupDialog:Open();
	]]

	--[[ 
	Controls.s:AddChildAtIndex( Controls.d, 1 );
	Controls.s:CalculateSize();
	]]

	--print("ldexp: ",math.ldexp(2,3));

end
Initialize();
