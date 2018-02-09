-- ===========================================================================
--	Drag and Drop support, common functions
-- ===========================================================================


-- Returns a control from targetControlArray that is the most likely to be the player's intention.
-- Cursor position is the first priority. If the cursor is over multiple targets, the target with the centroid nearest the cursor is used.
-- If the cursor is not over anything, the overlap with draggedControl is used: nOverlapArea / targetControlArea
-- The largest overlap wins.
DragSupport_GetBestOverlappingControl = function( draggedControl:table, targetControlArray:table )
	if ( draggedControl == nil or targetControlArray == nil ) then
		return nil;
	end
	
	local mx:number, my:number = UIManager:GetMousePos();

	local x:number, y:number	= draggedControl:GetScreenOffset();	-- Use sparningly; expensive!
	local w:number, h:number	= draggedControl:GetSizeVal();
	
	local nBestProximity :number = -1; -- cursor vs centroid
	local nBestOverlap :number = 0; -- control vs control
	local tBestInst :table = nil;
	for _,tControl in ipairs(targetControlArray) do
		local tx:number, ty:number	= tControl:GetScreenOffset();	-- Use sparningly; expensive!
		local tw:number, th:number	= tControl:GetSizeVal();

		if ( IsPointInRect( mx, my, tx, ty, tw, th ) ) then
			local nProx = GetProximityFromCentroid( mx, my, tx, ty, tw, th );
			if ( nBestProximity == -1 or nProx < nBestProximity ) then
				nBestProximity = nProx;
				tBestInst = tControl;
			end
		elseif ( nBestProximity == -1 ) then -- overlap tests only relevant as long as there's no cursor proximity.
			local nOverlapRatio :number = GetOverlapRatio( x, y, w, h, tx, ty, tw, th );
			if ( nOverlapRatio > nBestOverlap ) then
				nBestOverlap = nOverlapRatio;
				tBestInst = tControl;
			end
		end

	end
	return tBestInst;
end

-- Distance squared, a simple proximity metric.
function GetProximityFromCentroid( x:number, y:number, tx:number, ty:number, tw:number, th:number )
	local dx :number = x - (tx + tw*0.5);
	local dy :number = y - (ty + th*0.5);
	return dx*dx + dy*dy;
end

function IsPointInRect(x:number, y:number, tx:number, ty:number, tw:number, th:number)
	return x >= tx and y >= ty and x <= tx+tw and y <= ty+th;
end

function GetOverlapRatio( x:number, y:number, w:number, h:number, tx:number, ty:number, tw:number, th:number )
	return (math.max(0, math.min(x+w, tx+tw) - math.max(x, tx)) *
		   math.max(0, math.min(y+h, ty+th) - math.max(y, ty))) / (tw * th);
end

















--------------------------------------------------------------------------------
-- HERE BE DEPRECATED DRAG AND DROP STUFF.  DON'T USE IF YOU WORK AT FIRAXIS. --
--------------------------------------------------------------------------------

-- COPY THIS STRUCT to your local file to use it
hstructure DropAreaStruct
	x		: number
	y		: number
	width	: number
	height	: number
	control	: table
	id		: number	-- (optional, extra info/ID)
end

-- ForgeUI defined structure (not used, as this is passed back from ForgeUI as type "table").
hstructure DragStruct
	GetFlags		: cfunction
	GetControl		: cfunction
	IsDown			: cfunction
	IsDrag			: cfunction
	IsDrop			: cfunction
	GetStartX		: cfunction
	GetStartY		: cfunction
	GetCoordX		: cfunction
	GetCoordY		: cfunction
	GetDeltaX		: cfunction
	GetDeltaY		: cfunction
	GetNormalX		: cfunction
	GetNormalY		: cfunction
	GetNormalDeltaX	: cfunction
	GetNormalDeltaY	: cfunction
end

m_dropOverlapRequired = 0.5;
DragSupport_defaultDropAreaTable = nil;

-- ===========================================================================
--
-- ===========================================================================
function SetDropOverlap( percent:number )
	m_dropOverlapRequired = percent;
end

-- ===========================================================================
--	Scan through droppable areas and return the one that was hit.
--	x,y upper-left corner of a dropped item
--	width,height of the item that was dropped
--	group	(optional) which group of drop areas to check.  If excluded, all
--			dropped areas are checked.
--	RETURN:	nil if no matched drop area, otherwise two tables, si
-- ===========================================================================
function GetDropArea( x:number, y:number, width:number, height:number, group:table )	
	local dropperArea	:number = width * height;

	if group == nil then
		group = DragSupport_defaultDropAreaTable;
		if group == nil then
			return nil;
		end
	end
	
	for i,dropArea in pairs(group) do
		-- Drop area values may have changed (e.g., moved if in an animation control); first make sure struct has latest values.
		dropArea.x, dropArea.y	= dropArea.control:GetScreenOffset();	-- Use sparningly; expensive!
		dropArea.width			= dropArea.control:GetSizeX();
		dropArea.height			= dropArea.control:GetSizeY();
		local intersectArea:number = math.max(0, math.min(x+width, dropArea.x+dropArea.width) - math.max(x, dropArea.x)) * math.max(0, math.min(y+height, dropArea.y+dropArea.height) - math.max(y, dropArea.y));
		if intersectArea>0 and (intersectArea/dropperArea) >= m_dropOverlapRequired then
			return dropArea;
		end
	end
	return nil;
end

-- ===========================================================================
--	Add a drop site for drag-n-drop.
--	control			ForgeUI control that can accept the drop
--	num				(optional) ID of the drop site
--	group			(optional) Groups of drop areas each use their own table, 
--					to track droppable locations.  If no table is specified, 
--					a single, default, table is used.
-- ===========================================================================
function AddDropArea( control:table, num:number, group:table )
	if num == nil then num = -1; end
	if control==nil then
		error("Attempted to add a NIL drop area to #"..tostring(num));
		return;
	end
	-- Create a default table if one isn't defined.
	if group == nil then
		if DragSupport_defaultDropAreaTable == nil then DragSupport_defaultDropAreaTable = {}; end
		group = DragSupport_defaultDropAreaTable;		
	end

	local x,y = control:GetScreenOffset();
	group[num] = hmake DropAreaStruct {
		x		= x,
		y		= y,
		width	= control:GetSizeX(),
		height	= control:GetSizeY(),
		control	= control,
		id		= num
	};
end


-- ===========================================================================
--	Determine if a drag control is overlapping and arbitrary control (not
--	a preset drop area).
--	RETURNS: true if there is overlap
-- ===========================================================================
function IsDragAndDropOverlapped( dragControl:table, targetDropControl:table, optionalOverlapPercent:number )
	if optionalOverlapPercent == nil then
		optionalOverlapPercent = 0.5;
	end

	local x:number,y:number				= dragControl:GetScreenOffset();	-- Use sparningly; expensive!
	local width:number,height:number	= dragControl:GetSizeVal();
	local dropperArea:number			= width * height;
	
	local dropAreaX:number, dropAreaY:number		= targetDropControl:GetScreenOffset();
	local dropAreaWidth:number,dropAreaHeight:number= targetDropControl:GetSizeVal();
	
	local intersectArea:number			= math.max(0, math.min(x+width, dropAreaX + dropAreaWidth) - math.max(x, dropAreaX)) 
										* math.max(0, math.min(y+height, dropAreaY + dropAreaHeight) - math.max(y, dropAreaY));

	return (intersectArea>0 and (intersectArea/dropperArea) >= optionalOverlapPercent);
end
