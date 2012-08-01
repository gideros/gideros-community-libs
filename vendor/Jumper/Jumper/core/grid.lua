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

module(...,package.seeall)

local insert = table.insert
local ipairs = ipairs

-- Loads dependancies
local Oo = require (_PACKAGE .. '.third-party.LCS')
local Node = require (_PACKAGE .. '.node')

_M.Oo = nil
_M.Node = nil

--------------------------------------------------------------------
-- Private utilities
-- Creates a list of nodes, given a 2D map
local function buildGrid(map, width, height,walkable)
	local nodes = {}
	local isWalkable
		for y = 1, height do
			nodes[y] = {}
			for x = 1, width do
				isWalkable = (map[y][x] == walkable)
				insert(nodes[y],Node(x,y,isWalkable))
			end
		end
	return nodes
end

-- Checks if a value is within interval [lowerBound,upperBound]
local function within(i,lowerBound,upperBound)
	return (i>= lowerBound and i<= upperBound)
end

---------------------------------------------------------------------

-- Creates a grid class
local Grid = Oo.class { 
	width = nil, height = nil,
	map = nil, nodes = {},
	
	-- Set of vectors used to identify neighbours of a given position <x,y> in a 2D plane
	xOffsets = {-1,0,1,0},
	yOffsets = {0,1,0,-1},
	xDiagonalOffsets = {-1,-1,1,1},
	yDiagonalOffsets = {-1,1,1,-1},
}

-- Custom initializer
function Grid:init(map,walkable)
	self.width = #map[1]
	self.height = #map
	self.map = map
	self.nodes = buildGrid(map, self.width, self.height,walkable)
end

-- Returns the node at a given position
function Grid:getNodeAt(x,y)
	return self.nodes[y] and self.nodes[y][x] or nil
end

-- Checks if node [x,y] exists and is walkable
function Grid:isWalkableAt(x,y)
	return self.nodes[y] and self.nodes[y][x] and self.nodes[y][x].walkable
end

-- Sets Node [x,y] as obstructed or not
function Grid:setWalkableAt(x,y,walkable)
	self.nodes[y][x].walkable = walkable
end

-- Returns the neighbours of a given node on a grid
function Grid:getNeighbours(node,allowDiagonal)
	local x,y = node.x,node.y
	local nx , ny
	local nodes = self.nodes
	local xOffsets = self.xOffsets
	local yOffsets = self.yOffsets
	local xDiagonalOffsets = self.xDiagonalOffsets
	local yDiagonalOffsets = self.yDiagonalOffsets

	local neighbours = {}
	for i in ipairs(xOffsets) do
		nx, ny = x+xOffsets[i],y+yOffsets[i]
		if self:isWalkableAt(nx,ny) then
			insert(neighbours,nodes[ny][nx])
		end
	end
	if not allowDiagonal then
		return neighbours
	end
	for i in ipairs(xDiagonalOffsets) do
		nx, ny = x+xDiagonalOffsets[i],y+yDiagonalOffsets[i]
		if self:isWalkableAt(nx,ny) then
			insert(neighbours,nodes[ny][nx])
		end
	end
	return neighbours
end

-- Resets the grid for a next path computation
function Grid:reset()
	for k,y in ipairs(self.nodes) do
		for x,node in ipairs(y) do
		node.g,node.f,node.h = nil,nil,nil
		node.opened,node.closed = nil,nil
		node.parent = nil
		end
	end
end

return Grid


