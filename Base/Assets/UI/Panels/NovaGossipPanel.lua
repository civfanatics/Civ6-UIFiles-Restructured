
function OnStatusMessage( message:string, displayTime:number, type:number, subType:number )

	if (type == ReportingStatusTypes.GOSSIP) then

		local pNewInstance = Widgets.NovaGossipPanelRoot:ConstructBlueprint("GossipInstance", Widgets.GossipStack);
		pNewInstance.Root.Input:SetCallback(function() print("GossipInstance consuming input"); return true; end);
		
		local kGossipData:table = GameInfo.Gossips[subType];
		if kGossipData then
		--	uiInstance.Icon:SetIcon("ICON_GOSSIP_"..kGossipData.GroupType);
		--	uiInstance.IconBack:SetIcon("ICON_GOSSIP_"..kGossipData.GroupType);
		else
			UI.DataError("The gossip type '"..tostring(eGossipType).."' could not be found in the database; icon will not be set.");
		end
		
		pNewInstance.Message.Text:SetText( message );

	end

	if (type == ReportingStatusTypes.DEFAULT) then
		--AddDefault( message, displayTime );
	end

	--RealizeMainAreaPosition();
end

function Initialize()
    print(StateName .. " Initialized!");
	Events.StatusMessage.Add( OnStatusMessage );
end