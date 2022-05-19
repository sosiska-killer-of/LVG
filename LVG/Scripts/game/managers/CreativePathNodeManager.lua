CreativePathNodeManager = class( nil )

function CreativePathNodeManager.sv_onCreate( self )
	self.cellWaypoints = {}
	self.foreignConnections = {}
end

local function GetForeignConnectionsKey( id, x, y )
	return id..","..x..","..y
end

function CreativePathNodeManager.sv_connectForeignNodesToCell( self, x, y )
	local waypoints = sm.cell.getNodesByTag( x, y, "WAYPOINT" )
	if #waypoints == 0 then
		return
	end
	
	local pathNodes = self.cellWaypoints[CellKey(x,y)]
	assert(pathNodes)
	
	for _, waypoint in ipairs( waypoints ) do

		local id = waypoint.params.connections.id
		assert( sm.exists( pathNodes[id] ) )

		if waypoint.params.connections.ccount then
			local key = GetForeignConnectionsKey( id, x, y )
			local foreignConnections = self.foreignConnections[key]
			if foreignConnections then

				for idx, connection in reverse_ipairs( foreignConnections ) do
					if sm.exists( connection.pathnode ) then
						connection.pathnode:connect( pathNodes[id], connection.actions, connection.conditions )
						waypoint.params.connections.ccount = waypoint.params.connections.ccount - 1
						table.remove( foreignConnections, idx )
					end
				end

				if #foreignConnections == 0 then
					self.foreignConnections[key] = nil
				end
			end

		end
	end
end

function CreativePathNodeManager.sv_loadPathNodesOnCell( self, x, y )

	-- Get all waypoint nodes
	local waypoints = sm.cell.getNodesByTag( x, y, "WAYPOINT" )
	if #waypoints == 0 then
		return
	end

	-- Create pathnodes
	local pathNodes = {}
	for _, waypoint in ipairs( waypoints ) do
		assert( waypoint.params.connections, "Waypoint nodes expected to have the CONNECTION tag aswell" )
		pathNodes[waypoint.params.connections.id] = sm.pathNode.createPathNode( waypoint.position, waypoint.scale.x )
	end
	self.cellWaypoints[CellKey(x,y)] = pathNodes

	local foreignCells = {}

	-- Itterate pathnodes
	for _,waypoint in ipairs( waypoints ) do
		local id = waypoint.params.connections.id
		assert( sm.exists( pathNodes[id] ) )

		-- For each other node connected to this node
		for _,other in ipairs( waypoint.params.connections.otherIds ) do

			if (type(other) == "table") then
				if pathNodes[other.id] then -- Node exist in cell, connect
					assert( sm.exists( pathNodes[other.id] ) )
					pathNodes[id]:connect( pathNodes[other.id], other.actions, other.conditions )
				else -- Node dosent exist in this cell

					-- Add myself to the foreign connections
					local key = GetForeignConnectionsKey( other.id, x + other.cell[1], y + other.cell[2] )
					if self.foreignConnections[key] == nil then
						self.foreignConnections[key] = {}
					end
					table.insert( self.foreignConnections[key], { pathnode = pathNodes[id], actions = other.actions, conditions = other.conditions } )

					-- Mark foreign cell
					local foreignCell = CellKey(x + other.cell[1], y + other.cell[2])
					if self.cellWaypoints[foreignCell] then
						foreignCells[foreignCell] = { x = x + other.cell[1], y = y + other.cell[2] }
					end
				end
			else
				assert( pathNodes[other] )
				pathNodes[id]:connect( pathNodes[other] )
			end			
		end

		-- Connect foreign nodes to me
		if waypoint.params.connections.ccount then
			local key = GetForeignConnectionsKey( id, x, y )
			local foreignConnections = self.foreignConnections[key]
			if foreignConnections then
				
				for idx, connection in reverse_ipairs( foreignConnections ) do
					if sm.exists( connection.pathnode ) then
						connection.pathnode:connect( pathNodes[id], connection.actions, connection.conditions )
						waypoint.params.connections.ccount = waypoint.params.connections.ccount - 1
						table.remove( foreignConnections, idx )
					end
				end

				if #foreignConnections == 0 then
					self.foreignConnections[key] = nil
				end
			end
		end

	end

	-- Connect nodes in this cell to previously loaded cells
	for _, v in pairs( foreignCells ) do
		self:sv_connectForeignNodesToCell( v.x, v.y )
	end

end
