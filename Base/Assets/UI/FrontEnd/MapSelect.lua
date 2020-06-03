
include("InstanceManager");

-- ===========================================================================
-- Members
-- ===========================================================================
m_mapSelectorIM	=	InstanceManager:new("MapPreviewInstance",	"MapButton", Controls.MapSelectPanel);
m_mapInfoIM =		InstanceManager:new("MapInfoInstance", "MapContainer", Controls.MapInfoPanel);

local m_uiMapInfo		:table = {};
local m_kAllMaps		:table;
local m_selectedMapHash :number;
local m_lastSetMapHash	:number;
local m_selectedMap		:table;

local m_sortType :number = 0;
local m_lastSelectedSort :table;

local DEFAULT_MAP_RAWNAME = "LOC_MAP_CONTINENTS";

-- ===========================================================================
function Close()
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function OnBackButton()
	Close();
end

-- ===========================================================================
function OnSelectMapButton()
	m_lastSetMapHash = m_selectedMapHash;
	LuaEvents.AdvancedSetup_SetMapByHash( m_selectedMapHash );
	Close();
end

-- ===========================================================================
function OnSortButton( num:number, button:table )
	button:SetCheck(true);
	if(m_lastSelectedSort == button)then
		return;
	end
	m_lastSelectedSort = button;
	m_sortType = num;
	PopulateMapSelectPanel();
end

-- ===========================================================================
function OnMapButton(kMapData :table, c :table)
	
	m_uiMapInfo.MapName:SetText(Locale.Lookup(kMapData.RawName));
	m_uiMapInfo.MapDescription:SetText(Locale.Lookup(kMapData.RawDescription));
	m_uiMapInfo.MapImagePreview:SetTexture(kMapData.Texture);
	m_selectedMapHash = kMapData.Hash;	

	c:SetSelected(true);

	if(m_selectedMap == c) then return; end

	if(m_selectedMap ~= nil) then
		m_selectedMap:SetSelected(false);
	end
	m_selectedMap = c;
end

-- ===========================================================================
function LoadMaps(k:table)
	m_kAllMaps = k;
	m_selectedMap = nil;
	m_selectedMapHash = nil;
	PopulateMapSelectPanel();
end

-- ===========================================================================
function PopulateMapSelectPanel()

	if(m_mapSelectorIM ~= nil) then
		m_mapSelectorIM:ResetInstances();
	end
	
	for k, v in pairs(m_kAllMaps) do
		if(m_sortType == 1 and v.IsOfficial) then
			PopulateMapButton(m_kAllMaps[k]);
		elseif(m_sortType == 2 and v.IsWorldBuilder) then
			PopulateMapButton(m_kAllMaps[k]);
		elseif(m_sortType == 0) then
			PopulateMapButton(m_kAllMaps[k]);
		end
	end
end

-- ===========================================================================
function PopulateMapButton(kMapData:table)
	if(kMapData.Texture == nil) then
		kMapData.Texture = "Map_Community";
	end

	local uiMap :table = m_mapSelectorIM:GetInstance();
	uiMap.MapImagePreview:SetTexture(kMapData.Texture);
	uiMap.MapName:SetText(Locale.Lookup(kMapData.RawName));
	uiMap.MapButton:SetToolTipString(Locale.Lookup(kMapData.RawDescription));
	uiMap.MapButton:RegisterCallback( Mouse.eLClick, function() OnMapButton(kMapData, uiMap.MapButton); end );
	uiMap.MapButton:RegisterCallback( Mouse.eLDblClick,function() m_selectedMapHash = kMapData.Hash; OnSelectMapButton(); end);
	uiMap.MapButton:SetSelected(false);

	if(m_selectedMapHash == kMapData.Hash)then
		OnMapButton(kMapData, uiMap.MapButton);
	elseif(m_lastSetMapHash == kMapData.Hash and m_selectedMapHash == nil) then
		OnMapButton(kMapData, uiMap.MapButton);

	--This will only hit true the first time the screen is opened
	elseif(m_selectedMap == nil and m_lastSetMapHash == nil) then
		if(kMapData.RawName == DEFAULT_MAP_RAWNAME) then
			OnMapButton(kMapData, uiMap.MapButton);
		end
	end
end

-- ===========================================================================
function ClearMapData()
	m_lastSetMapHash = nil;
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then
		local key:number = pInputStruct:GetKey();
		if key == Keys.VK_ESCAPE then
			Close();
		end
	end
	return true;
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInputHandler( OnInputHandler, true );

	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnBackButton );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.MapSelectionButton:RegisterCallback( Mouse.eLClick, OnSelectMapButton );
	Controls.MapSelectionButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AllMapsSelector:RegisterCallback( Mouse.eLClick, function() OnSortButton(0, Controls.AllMapsSelector); end );
	Controls.AllMapsButton:RegisterCallback( Mouse.eLClick, function() OnSortButton(0, Controls.AllMapsSelector); end );
	Controls.AllMapsSelector:SetCheck(true);
	Controls.OfficialMapsSelector:RegisterCallback( Mouse.eLClick, function() OnSortButton(1, Controls.OfficialMapsSelector); end );
	Controls.OfficialMapsButton:RegisterCallback( Mouse.eLClick, function() OnSortButton(1, Controls.OfficialMapsSelector); end );
	Controls.WorldBuilderMapsSelector:RegisterCallback( Mouse.eLClick, function() OnSortButton(2, Controls.WorldBuilderMapsSelector); end );
	Controls.WorldBuilderMapsButton:RegisterCallback( Mouse.eLClick, function() OnSortButton(2, Controls.WorldBuilderMapsSelector); end );

	LuaEvents.MapSelect_PopulatedMaps.Add( LoadMaps );
	LuaEvents.MapSelect_ClearMapData.Add( ClearMapData );

	m_uiMapInfo = m_mapInfoIM:GetInstance();
end
Initialize();