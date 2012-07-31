local function falseButtons(elem)
	local num = elem:getNumChildren()
	if num > 0 then
		for i = 1, num do
			local sprite = elem:getChildAt(i)
			if sprite.upState and sprite.downState then
				sprite.focus = false
			else
				falseButtons(sprite)
			end
		end
	end
end

AceSlide = Core.class(Sprite)

function AceSlide:init(config)
	--configuration options
	self.conf = {
		orientation = "horizontal",
		spacing = 100,
		speed = 3,
		unfocusedAlpha = 0.75,
		easing = nil,
		allowDrag = true,
		dragOffset = 2
	}
	
	self.total = 1
	self.cur = 1
	self.coord = {}
	self.scrH = application:getContentHeight()
	self.scrW = application:getContentWidth()
	self.offset = 0
	if config then
		--copying configuration
		for key,value in pairs(config) do
			self.conf[key]= value
		end
	end
end

function AceSlide:findClosest(current)
	local closest = self.cur
	local distance = 100000000
	for i = 1, #self.coord do
		if i ~= self.cur then
			local newdist = math.abs(self.coord[i]-current)
			if distance > newdist then
				distance = newdist
				closest = i
			end
		end
	end
	
	return closest
end

function AceSlide:onMouseDown(event)
	if self:hitTestPoint(event.x, event.y) then
		self.isFocus = true
		self.x0 = event.x
		self.y0 = event.y
		self.startX = event.x
		self.startY = event.y
		--event:stopPropagation()
	end
end

function AceSlide:onMouseMove(event)
	if self.isFocus then
		if(self.conf.orientation == "horizontal") then
			local dx = event.x - self.x0
			self:setX(self:getX() + dx)
			self.x0 = event.x
		else
			local dy = event.y - self.y0
			self:setY(self:getY() + dy)
			self.y0 = event.y
		end
		event:stopPropagation()
	end
end

function AceSlide:onMouseUp(event)
	if self.isFocus then
		if(self.conf.orientation == "horizontal") then
			if(self.x0 - self.startX < -self.conf.dragOffset or self.x0 - self.startX > self.conf.dragOffset) then
				if self.x0 - self.startX < -self.conf.dragOffset and self.cur == self.total then
					self:gotoItem(self.cur)
				elseif self.x0 - self.startX > self.conf.dragOffset and self.cur == 1 then
					self:gotoItem(self.cur)
				else
					self:gotoItem(self:findClosest(self:getX()))
				end
				falseButtons(self)
				event:stopPropagation()
			else
				self:gotoItem(self.cur)
			end
		else
			if(self.y0 - self.startY < -self.conf.dragOffset or self.y0 - self.startY > self.conf.dragOffset) then
				if self.y0 - self.startY < -self.conf.dragOffset and self.cur == self.total then
					self:gotoItem(self.cur)
				elseif self.y0 - self.startY > self.conf.dragOffset and self.cur == 1 then
					self:gotoItem(self.cur)
				else
					self:gotoItem(self:findClosest(self:getY()))
				end
				falseButtons(self)
				event:stopPropagation()
			else
				self:gotoItem(self.cur)
			end
		end
		self.isFocus = false
	end
end

function AceSlide:add(elem, selected)
	if self.conf.allowDrag then
		elem:addEventListener(Event.MOUSE_DOWN, self.onMouseDown, self)
		elem:addEventListener(Event.MOUSE_MOVE, self.onMouseMove, self)
		elem:addEventListener(Event.MOUSE_UP, self.onMouseUp, self)
	end
	self:addChild(elem)
	self.total = self:getNumChildren()
	if selected then
		self.cur = self.total
	end
end

function AceSlide:addButton(image, image_pushed, callback, selected)
	local button_default = Bitmap.new(Texture.new(image))
	local button_pushed = Bitmap.new(Texture.new(image_pushed))
 
	local button = Button.new(button_default, button_pushed)	
	button:addEventListener("click", callback)
	if self.conf.allowDrag then
		button:addEventListener(Event.MOUSE_DOWN, self.onMouseDown, self)
		button:addEventListener(Event.MOUSE_MOVE, self.onMouseMove, self)
		button:addEventListener(Event.MOUSE_UP, self.onMouseUp, self)
	end
	self:addChild(button)
	
	self.total = self:getNumChildren()
	if selected then
		self.cur = self.total
	end
end

function AceSlide:applyToAll(callback)
	for i = 1, self.total do
		callback(self:getChildAt(i))
	end
end

function AceSlide:show()
	local last = 0
	for i = 1, self:getNumChildren() do
		if i == 1 then
			local sprite = self:getChildAt(i)
			sprite:setAlpha(self.conf.unfocusedAlpha)
			self.coord[i] = last
			if(self.conf.orientation == "horizontal") then
				last = (self.scrW/2)-(sprite:getWidth()/2)
				self.offset = last
				sprite:setPosition(last, (self.scrH/2)-(sprite:getHeight()/2))
				last = last + sprite:getWidth() + self.conf.spacing
			else
				last = (self.scrH/2)-(sprite:getHeight()/2)
				self.offset = last
				sprite:setPosition((self.scrW/2)-(sprite:getWidth()/2), last)
				last = last + sprite:getHeight() + self.conf.spacing
			end
		else
			local sprite = self:getChildAt(i)
			sprite:setAlpha(self.conf.unfocusedAlpha)
			self.coord[i] = -(last-self.offset)
			if(self.conf.orientation == "horizontal") then
				sprite:setPosition(last, (self.scrH/2)-(sprite:getHeight()/2))
				last = last + sprite:getWidth() + self.conf.spacing
			else
				sprite:setPosition((self.scrW/2)-(sprite:getWidth()/2), last)
				last = last + sprite:getHeight() + self.conf.spacing
			end
		end
	end
	--dirty little fix
	local fix = Sprite.new()
	self:addChild(fix)
	if self.conf.allowDrag then
		fix:addEventListener(Event.MOUSE_DOWN, self.onMouseDown, self)
		fix:addEventListener(Event.MOUSE_MOVE, self.onMouseMove, self)
		fix:addEventListener(Event.MOUSE_UP, self.onMouseUp, self)
	end
	self:getChildAt(self.cur):setAlpha(1)
	self:jumptoItem(self.cur)
end

function AceSlide:gotoItem(ind)
	local target = self.coord[ind]
	local curpos
	if(self.conf.orientation == "horizontal") then
		curpos = self:getX()
	else
		curpos = self:getY()
	end
	local switchTime = (self.conf.speed*math.abs(curpos-target))+1
	local animate = {}
	if(self.conf.orientation == "horizontal") then
		animate.x = target
	else
		animate.y = target
	end
	self:getChildAt(self.cur):setAlpha(self.conf.unfocusedAlpha)
	self.cur = ind
	function self:tweenEnd()
		self:getChildAt(self.cur):setAlpha(1)
	end
	local tween = GTween.new(self, switchTime/1000, animate, {delay = 0, ease = self.conf.easing})
	tween.dispatchEvents = true
	tween:addEventListener("complete", self.tweenEnd, self)
end

function AceSlide:jumptoItem(ind)
	if(self.conf.orientation == "horizontal") then
		self:setPosition(self.coord[ind],0)
	else
		self:setPosition(0,self.coord[ind])
	end
end

function AceSlide:nextItem()
	if self.cur ~= self.total then
		self:gotoItem(self.cur + 1)
	else
		self:gotoItem(self.total)
	end
end

function AceSlide:prevItem()
	if self.cur ~= 1 then
		self:gotoItem(self.cur - 1)
	else
		self:gotoItem(1)
	end
end

function AceSlide:firstItem()
	self:gotoItem(1)
end

function AceSlide:lastItem()
	self:gotoItem(self.total)
end