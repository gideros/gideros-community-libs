--[[
Copyright (c) 2012 Roland Yonaba

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

local _VERSION = "1.0"

module(...,package.seeall)

local insert = table.insert
local ipairs = ipairs
local max, abs = math.max, math.abs
local assert = assert

-- Loads dependancies
local Heuristic = require (_PACKAGE .. '.core.heuristics')
local Grid = require (_PACKAGE ..'.core.grid')
local Heap = require (_PACKAGE .. '.core.third-party.binary_heap')
local Oo = require (_PACKAGE .. '.core.third-party.LCS')

_M.Heuristic = nil
_M.Grid = nil
_M.Heap = nil
_M.Oo = nil

-- Local helpers, these routines will stay private
-- As they are internally used by the main public class

-- Performs a traceback from the goal node to the start node
-- Only happens when the path was found
local function traceBackPath(self)
	local sx,sy = self.startNode.x,self.startNode.y
	local x,y
	local grid = self.grid
	local path = {{x = self.endNode.x, y = self.endNode.y}}
	local node

	while true do
		x,y = path[1].x,path[1].y
		node = grid:getNodeAt(x,y)
		if node.parent then
			x,y = node.parent.x,node.parent.y
			insert(path,1,{x = x, y = y})
		else
			return path
		end
	end

	return nil
end

--[[
	Looks for the neighbours of a given node.
	Returns its natural neighbours plus forced neighbours when the given
	node has no parent (generally occurs with the starting node).
	Otherwise, based on the direction of move from the parent, returns
	neighbours while pruning directions which will lead to symmetric paths.

	Tweak : In case diagonal moves are forbidden, when the given node has no
	parent, we return straight neighbours (up, down, left and right).
	Otherwise, we add left and right node (perpendicular to the direction
	of move) in the neighbours list.
--]]
local function findNeighbours(self,node)
	local grid = self.grid
	local parent = node.parent
	local neighbours = {}
	local _neighbours
	local x,y = node.x,node.y
	local px,py,dx,dy

	if parent then
	-- Node have a parent, we will prune some neighbours
	px,py = parent.x,parent.y

	-- Gets the direction of move
	dx = (x-px)/max(abs(x-px),1)
	dy = (y-py)/max(abs(y-py),1)

		-- Diagonal move case
		if dx~=0 and dy~=0 then
			-- Natural neighbours
			if grid:isWalkableAt(x,y+dy) then insert(neighbours,{x = x, y = y+dy }) end
			if grid:isWalkableAt(x+dx,y) then insert(neighbours,{x = x+dx, y = y}) end
			if grid:isWalkableAt(x,y+dy) or grid:isWalkableAt(x+dx,y) then insert(neighbours,{x = x+dx, y = y+dy}) end
			-- Forced neighbours
			if (not grid:isWalkableAt(x-dx,y)) and grid:isWalkableAt(x,y+dy) then insert(neighbours,{x = x-dx, y = y+dy}) end
			if (not grid:isWalkableAt(x,y-dy)) and grid:isWalkableAt(x+dx,y) then insert(neighbours,{x = x+dx, y = y-dy}) end
		else
			-- Move along Y-axis case
			if dx==0 then
				if grid:isWalkableAt(x,y+dy) then
					-- Natural neighbour is ahead along Y
					if grid:isWalkableAt(x,y+dy) then insert(neighbours,{x = x, y = y +dy}) end
					-- Forced neighbours are left and right ahead along Y
					if (not grid:isWalkableAt(x+1,y)) then insert(neighbours,{x = x+1, y = y+dy}) end
					if (not grid:isWalkableAt(x-1,y)) then insert(neighbours,{x = x-1, y = y+dy}) end
				end
				--Tweak : In case diagonal moves are forbidden
				if not self.allowDiagonal then
					if grid:isWalkableAt(x,y+dy) then insert(neighbours,{x = x, y = y+dy}) end					
					if grid:isWalkableAt(x+1,y) then insert(neighbours,{x = x+1, y = y}) end
					if grid:isWalkableAt(x-1,y) then insert(neighbours,{x = x-1, y = y}) end					
				end
			else
			-- Move along X-axis case
				if grid:isWalkableAt(x+dx,y) then
					-- Natural neighbour is ahead along X
					if grid:isWalkableAt(x+dx,y) then insert(neighbours,{x = x+dx, y = y}) end
					-- Forced neighbours are up and down ahead along X
					if (not grid:isWalkableAt(x,y+1)) then insert(neighbours,{x = x+dx, y = y+1}) end
					if (not grid:isWalkableAt(x,y-1)) then insert(neighbours,{x = x+dx, y = y-1}) end
				end
				--Tweak : In case diagonal moves are forbidden
				if not self.allowDiagonal then
					if grid:isWalkableAt(x+dx,y) then insert(neighbours,{x = x+dx, y = y}) end					
					if grid:isWalkableAt(x,y+1) then insert(neighbours,{x = x, y = y+1}) end
					if grid:isWalkableAt(x,y-1) then insert(neighbours,{x = x, y = y-1}) end
					
				end
			end
		end
	else
	-- Node do not have parent, we return all neighbouring nodes
	_neighbours = grid:getNeighbours(node,self.allowDiagonal)
		for i,_neighbour in ipairs(_neighbours) do insert(neighbours,_neighbour) end
	end
	return neighbours
end



--[[
	Searches for a jump point (or a turning point) in a specific direction.
	This is a generic translation of the algorithm 2 in the paper:
		http://users.cecs.anu.edu.au/~dharabor/data/papers/harabor-grastien-aaai11.pdf
	The current node, to be examined happens to be a jump point if near a forced node
	ahead, in the direction of move.

	Tweak : In case diagonal moves are forbidden, when lateral nodes (perpendicular to
	the direction of moves are walkable, we force them to be turning points in other
	to perform a straight move.
--]]
local function jump(self,x,y,px,py)
	local grid = self.grid
	local dx, dy = x - px,y - py
	local jx,jy

	-- If the node to be examined is unwalkable, return nil
	if not grid:isWalkableAt(x,y) then return nil  end

	-- If the node to be examined is the endNode, return this node
	if grid:getNodeAt(x,y) == self.endNode then return {x = x, y = y} end

	-- Diagonal search case
	if dx~=0 and dy~=0 then
		-- Current node is a jump point if one of his leftside/rightside neighbours ahead is forced
		if (grid:isWalkableAt(x-dx,y+dy) and (not grid:isWalkableAt(x-dx,y))) or
		   (grid:isWalkableAt(x+dx,y-dy) and (not grid:isWalkableAt(x,y-dy))) then
			return {x = x, y = y}
		end
	else
		-- Search along X-axis case
		if dx~=0 then
			if self.allowDiagonal then
				-- Current node is a jump point if one of his upside/downside neighbours is forced
				if (grid:isWalkableAt(x+dx,y+1) and (not grid:isWalkableAt(x,y+1))) or
				   (grid:isWalkableAt(x+dx,y-1) and (not grid:isWalkableAt(x,y-1))) then
					return {x = x, y = y}
				end
			else
				-- Tweak : in case diagonal moves are forbidden
				if grid:isWalkableAt(x,y+1) or grid:isWalkableAt(x,y-1) then return {x = x,y = y} end
			end
		else
		-- Search along Y-axis case
			-- Current node is a jump point if one of his leftside/rightside neighbours is forced
			if self.allowDiagonal then
				if (grid:isWalkableAt(x+1,y+dy) and (not grid:isWalkableAt(x+1,y))) or
				   (grid:isWalkableAt(x-1,y+dy) and (not grid:isWalkableAt(x-1,y))) then
					return {x = x, y = y}
				end
			else
				-- Tweak : in case diagonal moves are forbidden
				if grid:isWalkableAt(x+1,y) or grid:isWalkableAt(x-1,y) then return {x = x,y = y} end
			end
		end
	end

	-- Diagonal search case
	if dx~=0 and dy~=0 then
		-- Is there a jump point from the current node ahead along X-axis ?
		jx = jump(self,x+dx,y,x,y)
		-- Is there a jump point from the current node ahead along Y-axis ?
		jy = jump(self,x,y+dy,x,y)
		-- If so, the current node is a jump point
		if jx or jy then return {x = x, y = y} end
	end

	-- Recursive search for a jump point diagonally
	if grid:isWalkableAt(x+dx,y) or grid:isWalkableAt(x,y+dy) then return jump(self,x+dx,y+dy,x,y) end
end

--[[
	Searches for successors of a given node in the direction of each of its neighbours.
	This is a generic translation of the algorithm 1 in the paper:
		http://users.cecs.anu.edu.au/~dharabor/data/papers/harabor-grastien-aaai11.pdf

	Tweak : In case a jump point was found, and this node happened to be diagonal to the
	node currently expanded, we skip this jump point in other to cancel any diagonal move.
--]]
local function identifySuccessors(self,node)
	local grid = self.grid
	local heuristic = self.heuristic
	local openList = self.openList
	local endX,endY = self.endNode.x,self.endNode.y

	local x,y = node.x,node.y
	local jumpPoint,jx,jy,jumpNode

	-- Gets the valid neighbours of the given node
	-- Looks for a jump point in the direction of each neighbour
	local neighbours = findNeighbours(self,node)
	for i,neighbour in ipairs(neighbours) do
		jumpPoint = jump(self,neighbour.x,neighbour.y,x,y)
			-- Tweak : in case a diagonal jump point was found while diagonal moves are forbidden, skip it.
			if jumpPoint and not self.allowDiagonal then
				if ((jumpPoint.x~=x) and (jumpPoint.y~=y)) then return end
			end
		if jumpPoint then
		jx,jy = jumpPoint.x,jumpPoint.y
		jumpNode = grid:getNodeAt(jx,jy)
			-- Update the jump node using heuristics and move it in the closed list
			if not jumpNode.closed then
			dist = Heuristic.EUCLIDIAN(jx-x,jy-y)
			ng = node.g + dist
				if not jumpNode.opened or ng < jumpNode.g then
				jumpNode.g = ng
				jumpNode.h = jumpNode.h or (heuristic(jx-endX,jy-endY))
				jumpNode.f = jumpNode.g+jumpNode.h
				jumpNode.parent = node
					if not jumpNode.opened then
						openList:insert(jumpNode)
						jumpNode.opened = true
					else
						openList:heap()
					end
				end
			end
		end
	end
end

-- Jump Point Search Class
local JPS = Oo.class {
	heuristic = nil, -- heuristic used
	startNode = nil, -- startNode
	endNode = nil, -- endNode
	grid = nil, -- internal grid
	allowDiagonal = true, -- By default, allows diagonal moves
}

-- Custom initializer (walkable, allowDiagonal,heuristic are both optional)
function JPS:init(map,walkable,allowDiagonal,heuristic)
	self.walkable = walkable or 0
	self.grid = Grid(map,self.walkable)
	self.allowDiagonal = allowDiagonal
	self.heuristic = heuristic or Heuristic.MANHATTAN
	self._heuristicName = MANHATTAN
end

-- Changes the heuristic
function JPS:setHeuristic(distanceName)
	assert(Heuristic[distanceName],'Not a valid heuristic name!')
	self.heuristic = Heuristic[distanceName]
	self._heuristicName = distanceName
end

-- Gets the name of the heuristic currently used, as a string
function JPS:getHeuristic()
	return Heuristic[self._heuristicName]
end

-- Enables or disables diagonal moves
function JPS:setDiagonalMoves(bool)
	assert(type(bool) == 'boolean','Argument must be a boolean')
	self.allowDiagonal = bool
end

-- Checks whether diagonal moves are enabled or not
function JPS:getDiagonalMoves()
	return self.allowDiagonal
end

--[[
	Main search fuction. Requires a start x,y and an end x,y coordinates.
	StartNode and endNode must be walkable.
	Returns the path when found, otherwise nil.
--]]
function JPS:searchPath(startX,startY,endX,endY)
	local grid = self.grid
	self.openList = Heap()
	self.startNode = grid:getNodeAt(startX,startY)
	self.endNode = grid:getNodeAt(endX,endY)
	local openList = self.openList
	local startNode, endNode = self.startNode,self.endNode
	local node

	grid:reset()

	-- Moves the start node in the openList
	startNode.g, startNode.f = 0,0
	openList:insert(startNode)
	startNode.opened = true

	while not openList:empty() do
		-- Pops the lowest-F node, moves it in the closed list
		node = openList:pop()
		node.closed = true
			-- If the popped node is the endNode, traceback and return the path and the path cost
			if node == endNode then	return traceBackPath(self),endNode.f end
		-- Else, identify successors of the popped node
		identifySuccessors(self,node)
	end

	-- No path found, return nil
	return nil
end

--[[
	Naive path smoother helper. As the path returned with JPS algorithm
	consists of straight lines, they maybe some holes inside. This function
	alters the given path, inserting missing nodes.
--]]
function JPS:smooth(path)
	local path = path
	local i = 2
	local xi,yi,dx,dy
	local N = #path

	while true do
	xi,yi = path[i].x,path[i].y
	dx,dy = xi-path[i-1].x,yi-path[i-1].y
		if (abs(dx) > 1 or abs(dy) > 1) then
		incrX = dx/max(abs(dx),1)
		incrY = dy/max(abs(dy),1)
		insert(path,i,{x = path[i-1].x+incrX,y = path[i-1].y+incrY})
		N = N+1
		else i=i+1
		end
		if i>N then break end
	end
	return path
end

-- Returns a pointer to the internal grid
function JPS:getGrid()
	return self.grid
end

return JPS
