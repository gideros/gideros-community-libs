Gestures = Core.class(EventDispatcher)

--some helping internal functions

local function optCosDist(gestureV, inputV)
	local a = 0
	local b = 0
	for i = 1, #gestureV, 2 do
		a = a + gestureV[i]*inputV[i] + gestureV[i+1]*inputV[i+1]
		b = b + gestureV[i]*inputV[i+1] - gestureV[i+1]*inputV[i]
	end
	local angle = math.atan2(b,a)
	return math.acos(a*math.cos(angle) + b*math.sin(angle))
end

--local distance [PROTACTOR]
local function Distance(u, v) 
	local x = (u.x - v.x) 
	local y = (u.y - v.y)
	return math.sqrt((x*x)+(y*y))
end

local function pathLength(points, n)
	local distance = 0;
	for i=2,n do
		distance = distance + Distance(points[i-1], points[i]);
	end
	return distance
 
end

local function resample(points, n, conf)
	local subLength = pathLength(points, n)/(conf.points-1)
	local distance = 0
	local newpoints = {}
	local elem ={}
	elem.x = points[1].x
	elem.y = points[1].y
	table.insert(newpoints,elem)--first point
	--until last point
	local i = 2
	while (i <= #points and #newpoints < conf.points-1)   do
		local subdist = Distance(points[i-1], points[i])
		if((distance + subdist) >= subLength) then
		local elem2 = {}
			elem2.x = points[i-1].x + ((subLength - distance)/subdist)*(points[i].x - points[i-1].x)
			elem2.y = points[i-1].y + ((subLength - distance)/subdist)*(points[i].y - points[i-1].y)
			table.insert(newpoints, elem2)--add point
			table.insert(points, i, elem2)
			distance = 0
		else
		distance = distance + subdist;
		end
		i = i + 1
	end
	local elem3 = {}
	--adding last point
	elem3.x = points[#points].x
	elem3.y = points[#points].y
	table.insert(newpoints, elem3)

	return newpoints
end

local function centroid(points)
	local center = {}
	center.x = 0
	center.y=0
	local minx = points[1].x
	local maxx = points[1].x
	local miny = points[1].y
	local maxy = points[1].y
	
	for i=2,#points do
		center.x = center.x + points[i].x
		center.y = center.y + points[i].y
	end
	center.x = center.x/#points
	center.y = center.y/#points
	return center
end

local function translate(points,center)
	for i=1,#points do
		points[i].x = points[i].x - center.x
		points[i].y = points[i].y - center.y
	end
	return points
end

local function vectorize(points, sensit)
	local center = {}
	local vector = {}
	center = centroid(points)
	points = translate(points, center)
	
	--local lenkis2 = math.atan(points[1].x/points[1].y)
	local lenkis = math.atan2(points[1].x, points[1].y)
	local delta = lenkis
	if sensit then
		local base = (math.pi/4)*math.floor((lenkis+(math.pi/8))*(4/math.pi))
		delta = base-lenkis
	end
	local summa = 0
	for i=1, #points do
		local newx = points[i].x*math.cos(delta) - points[i].y*math.sin(delta)
		local newy = points[i].x*math.sin(delta) + points[i].y*math.cos(delta)
		table.insert(vector, newx)
		table.insert(vector, newy)
		summa = summa + newx*newx + newy*newy
	end
	
	local magnitude = math.sqrt(summa)
	for i=1, #vector do
		vector[i] = vector[i]/magnitude
	end
	return vector
end

--initialize
function Gestures:init(config)
	-- Settings
	self.conf = {
		debug = true,
		draw = true,
		drawColor = 0xff0000,
		drawWidth = 5,
		autoTrack = true,
		scope = stage,
		allowRotation = true,
		inverseShape = false,
		points = 33
	}
	self.gestures = {}
	
	if config then
		--copying configuration
		for key,value in pairs(config) do
			self.conf[key] = value
		end
	end
	
	if self.conf.draw then
		self.draw = Shape.new()
		self.conf.scope:addChild(self.draw)
	end
	
	if self.conf.autoTrack or self.conf.draw then
		self.conf.scope:addEventListener(Event.MOUSE_DOWN, self.Down, self)
		self.conf.scope:addEventListener(Event.MOUSE_MOVE, self.Move, self)
		self.conf.scope:addEventListener(Event.MOUSE_UP, self.Up, self)
	end
	
	if self.conf.autoTrack then
		self:debug("autotrack enabled")
		self.tracking = true
	end
	
	self:reset()
	self:debug("ready")
end

function Gestures:debug(text)
	if self.conf.debug then
		print(text)
	end
end

function Gestures:pauseTracking()
	self.tracking = false
end

function Gestures:resumeTracking()
	self.tracking = true
end

function Gestures:addGesture(name, points, callback)
	
	if(self.conf.inverseShape) then
		self:debug("Inversing shape")
		local inverse = {}
		for i = #points, 1, -1 do
			table.insert(inverse, points[i])
		end
		local gesture = {}
		gesture.name = name
		gesture.callback = callback
		local map = resample(inverse, #inverse, self.conf)
		gesture.map = vectorize(map, self.conf.allowRotation)
		table.insert(self.gestures,gesture)
	end
	
	local gesture = {}
	gesture.name = name
	gesture.callback = callback
	local map = resample(points, #points, self.conf)
	gesture.map = vectorize(map, self.conf.allowRotation)
	table.insert(self.gestures,gesture)
	
	self:debug("added "..name)
end

function Gestures:resolve(points)
	if(#points>1) then
		self:reset()
		local map = resample(points,#points, self.conf)
		local ivect = vectorize(map, self.conf.allowRotation)
		
		local maxScore = 0
		local match = "none"
		for i=1, #self.gestures  do
			local dist = optCosDist(self.gestures[i].map,ivect)
			local score = 1/dist
			self:debug(self.gestures[i].name..": "..score.." score")
			if(score > maxScore) then
				maxScore = score
				match = self.gestures[i]
			end
		end
		if(match.callback) then
			match.callback(match.name)
		end
		self:debug(match.name)
	end
end

function Gestures:reset()
	self.points = {}
end

--gesture auto tracking
--mouse down
function Gestures:Down(event)
	self:reset()
	if self.conf.draw then
		self.draw:clear()
		self.draw:setLineStyle(self.conf.drawWidth, self.conf.drawColor)
		self.draw.lastX = event.x
		self.draw.lastY = event.y
	end
	if self.conf.autoTrack and self.tracking then
		local point = {}
		point.x = event.x
		point.y = event.y
		table.insert(self.points,point)
		self:debug("start tracking")
	end
end
--mouse move
function Gestures:Move(event)
	if self.conf.draw then
		self.draw:beginPath()
		self.draw:moveTo(self.draw.lastX, self.draw.lastY)
		self.draw:lineTo(event.x, event.y)
		self.draw:endPath()
		self.draw.lastX = event.x
		self.draw.lastY = event.y
	end
	if self.conf.autoTrack and self.tracking then
		local point = {}
		point.x = event.x
		point.y = event.y
		table.insert(self.points,point)
	end
end
--mouse up
function Gestures:Up(event)
	if self.conf.autoTrack and self.tracking then
		self:debug("end tracking, points: "..#self.points)
		self:resolve(self.points)
	end
end
