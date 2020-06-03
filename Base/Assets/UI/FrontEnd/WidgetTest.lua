print("Loading WidgetTest.lua");

function InputCallback(pInputStruct:table, szName:string)
	local eMsg = pInputStruct:GetMessageType();
	if (eMsg == MouseEvents.LButtonUp or eMsg == MouseEvents.PointerUp) then
		local x = pInputStruct:GetX()
		local y = pInputStruct:GetY()
		print("Clicked on widget '" .. szName .. "' (" .. x .. "," .. y .. ")");
		return true;
	end
	
	return false;
end

function Initialize()
    print(StateName .. " Initialized!");
	Widgets.Header:SetAlpha(0.5);
	Widgets.Body2.Image:SetTexture("Controls_WordBubbleLeft");
	--Widgets.Body2.Image:SetSliceTextureCoordinates(30, 10);
	Widgets.Body2.Image:SetAsymmetricSliceTextureCoordinates(30, 10, 56-31, 47-11);

	for i=1,4 do
		local pChild = Widgets.TestRoot:ConstructBlueprint("TestBlueprint", Widgets.Body1);
		pChild.root.Input:SetCallback(function(p) return InputCallback(p, "Body1 Blueprint["..i.."]") end);
		pChild.root.Image:SetTexture("Shell_FlagButton");
		pChild.root.Image:SetAsymmetricSliceTextureCoordinates(4, 0, 50-20, 0);
		pChild.root.Text:SetText("{LOC_GRAMMAR_CIVNAME << {1_CivName}} had their governor in {2_CityName} neutralized by an unknown spy.");
	end
	for i=1,3 do
		local pChild = Widgets.TestRoot:ConstructBlueprint("TestBlueprint", Widgets.Body2);
		pChild.root.Input:SetCallback(function(p) return InputCallback(p, "Body2 Blueprint["..i.."]") end);
		pChild.root.Image:SetTexture("Shell_FlagButton");
		pChild.root.Image:SetAsymmetricSliceTextureCoordinates(4, 0, 50-20, 0);
		pChild.root.Text:SetText("Test[WIP]Test2 [ICON_Tourism][COLOR:COLOR_RED][NEWLINE]escape:\\[ESCAPED]red[ENDCOLOR]red[COLOR:COLOR_RED]red");
	end

	Widgets.Header.Input:SetCallback(function(p) return InputCallback(p, "Header") end);
	Widgets.Index.Input:SetCallback(function(p) return InputCallback(p, "Index") end);
	Widgets.Body1.Input:SetCallback(function(p) return InputCallback(p, "Body1") end);
	Widgets.Body2.Input:SetCallback(function(p) return InputCallback(p, "Body2") end);
end
function Shutdown()
    print(StateName .. "Shutdown!");
end