--[[
*************************************************************
 * This script is developed by Arturs Sosins aka ar2rsawseen, http://appcodingeasy.com
 * Feel free to distribute and modify code, but keep reference to its creator
 *
 * Gideros Unite framework provides a way to implement Multiplayer games using Gideros Mobile.
 * It uses LuaSocket to establish socket connections and even create server/client instances.
 * It provides the means of device discovery in Local Area Network, and allows to call methods 
 * of other devices throught network
 *
 * For more information, examples and online documentation visit: 
 * http://appcodingeasy.com/Gideros-Mobile/Gideros-Unite-framework-for-multiplayer-games
**************************************************************
]]--

--[[
	HELPING FUNCTIONS
]]--

local function getIP()
	local s = socket.udp()
	s:setpeername("74.125.115.104",80)
	local ip, _ = s:getsockname()
	return ip
end

local function explode(div,str) -- credit: http://richard.warburton.it
	if (div=='') then return false end
	local pos,arr = 0,{}
	-- for each divider found
	for st,sp in function() return string.find(str,div,pos,true) end do
		table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
		pos = sp + 1 -- Jump past current divider
	end
	table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
	return arr
end

--[[
	CLIENT STUFF
]]--

Client = Core.class(EventDispatcher)

function Client:init(config)
	self.conf = {
		ip = nil,
		tcpPort = 5883,
		udpPort = 5884,
		discoveryPort = 5885,
		multicast = "239.192.1.1",
		serverIP = nil,
		connectionType = "both",
		username = nil
	}
	if config then
		--copying configuration
		for key,value in pairs(config) do
			self.conf[key] = value
		end
	end
	
	if self.conf.connectionType ~= "tcp" and self.conf.connectionType ~= "udp" and self.conf.connectionType ~= "both" then
		self.conf.connectionType = "tcp"
	end
	
	--get IP address of active interface
	if(self.conf.ip) then
		self.ip = self.conf.ip
	else
		self.ip = getIP()
	end
	local host = self.conf.username or socket.dns.tohostname(self.ip)
	self.host = host or self.ip
	self.port = self.conf.tcpPort
	self.port2 = self.conf.udpPort
	self.port3 = self.conf.discoveryPort
	
	--store added methods
	self.methods = {}
	
	--store available server
	self.servers = {}
	
	--generate random id
	math.randomseed(os.time())
	self.id = tostring(math.random(os.time()))
	
	--is connected to server
	self.connected = false
	
	if self.conf.serverIP then
		self.servers[1] = {}
		self.servers[1].ip = self.conf.serverIP
		self.servers[1].host = self.conf.serverIP
		self:connect(1)
	end
	
	--create timer for listening
	self.listenTimer = Timer.new(100)
    --setting timer callback
    self.listenTimer:addEventListener(Event.TIMER, Client.ListenStep, self)
	
	self.newServerEvent = Event.new("newServer")
	self.acceptedEvent = Event.new("onAccepted")
	self.connectionClosedEvent = Event.new("onServerClose")
	self.clientClosedEvent = Event.new("onClientClose")
	self.deviceEvent = Event.new("device")
end

function Client:startListening()
	if not self.connected then
		--create udp instance
		self.listen = socket.udp()
	
		--set socket for multicast
		self.listen:setsockname(self.conf.multicast, self.port3)
	
		--check if supports multicast
		local name = self.listen:getsockname()
		if(name)then
			--add interface to multicast
			self.listen:setoption("ip-add-membership" , { multiaddr = self.conf.multicast, interface = self.ip})
		else
			--create udp instance
			self.listen = socket.udp()
			--does not support multicast, but will probably receive broadcast message
			self.listen:setsockname(self.ip, self.port3)
		end
	
		--set timeout so it won't block UI
		self.listen:settimeout(0)
	end
	self.listenTimer:start()
end

function Client:ListenStep()
	if(not self.connected)then
		repeat
			--get all data
			local data, ip, port = self.listen:receivefrom()
			--if there is any data
			if data then
				--get parameters
				local id, cmd, params = data:match("^(%S*) (%S*) (.*)")
				--check if sender not itself
				if self.id ~= id and cmd == 'unite' then
					if self.servers[id] == nil then
						local h = explode(" ", params)
						local host = h[1]
						self.servers[id] = {}
						self.servers[id].ip = ip
						self.servers[id].host = host
						--add new server
						self.newServerEvent.data = {id = id, ip = ip, host = host}
						self:dispatchEvent(self.newServerEvent)
					end
				end
			end
		until not data
	end
	if self.tcp then
		repeat
			local data, err = self.tcp:receive()
			if data then 
				local id, cmd, params = data:match("^(%S*) (%S*) (.*)")
				if self.id ~= id then
					if cmd == 'accept' then
						--server accepted us, so we are connected
						self.connected = true
						if self.listen then
							self.listen:close()
							self.listen = nil
						end
						self.servers = {}
						self:dispatchEvent(self.acceptedEvent)
					elseif cmd == 'closed' then
						local p = explode(" ", params)
						self.clientClosedEvent.data = {id = p[1]}
						self:dispatchEvent(self.clientClosedEvent)
					elseif cmd == 'device' then
						local p = explode(" ", params)
						self.deviceEvent.data = {id = p[1], ip = p[2], host = p[3]}
						self:dispatchEvent(self.deviceEvent)
					elseif(self.methods[cmd]) then
						local p = explode(" ", params)
						if p then
							p[#p] = id
							if self.methods[cmd].scope then
								self.methods[cmd].method(self.methods[cmd].scope, unpack(p))
							else
								self.methods[cmd].method(unpack(p))
							end
						else
							if self.methods[cmd].scope then
								self.methods[cmd].method(self.methods[cmd].scope, id)
							else
								self.methods[cmd].method(id)
							end
						end
					end
				end
			end
		until not data
	end
	if self.udp then
		repeat
			local data, ip, port = self.udp:receivefrom()
			if data then 
				local id, cmd, params = data:match("^(%S*) (%S*) (.*)")
				if self.id ~= id then
					if cmd == 'accept' then
						--server accepted us, so we are connected
						self.connected = true
						if self.listen then
							self.listen:close()
							self.listen = nil
						end
						self.servers = {}
						self:dispatchEvent(self.acceptedEvent)
					elseif cmd == 'closed' then
						local p = explode(" ", params)
						self.clientClosedEvent.data = {id = p[1]}
						self:dispatchEvent(self.clientClosedEvent)
					elseif(self.methods[cmd]) then
						local p = explode(" ", params)
						if p then
							p[#p] = id
							if self.methods[cmd].scope then
								self.methods[cmd].method(self.methods[cmd].scope, unpack(p))
							else
								self.methods[cmd].method(unpack(p))
							end
						else
							if self.methods[cmd].scope then
								self.methods[cmd].method(self.methods[cmd].scope, id)
							else
								self.methods[cmd].method(id)
							end
						end
					end
				end
			end
		until not data
	end
end

function Client:stopListening()
	self.listenTimer:stop()
	if self.listen then
		self.listen:close()
		self.listen = nil
	end
end

function Client:connect(id)
	if self.servers[id] then
		self.serverIP = self.servers[id].ip
		if self.conf.connectionType == "tcp" or self.conf.connectionType == "both" then
			--connect to server
			--self.tcp = socket.connect(self.servers[id].ip, self.port)
			self.tcp = socket.tcp()
			local _, err = self.tcp:connect(self.servers[id].ip, self.port)
			--set timeout so it won't block UI
			self.tcp:settimeout(0)
		end
		if self.conf.connectionType == "udp" or self.conf.connectionType == "both" then
			--connect to server
			self.udp = socket.udp()
			self.udp:setsockname(self.ip, self.port2)
			--set timeout so it won't block UI
			self.udp:settimeout(0)
		end
		local msg = string.format("%s %s %s %s", self.id, 'join', self.host, "\n")
		self:sendMsg(msg)
	else
		error("Error: There is no server with id: "..id, 2)
	end
end

function Client:sendMsg(msg, type)
	if type == nil then
		if self.conf.connectionType == "both" then
			type = "tcp"
		else
			type = self.conf.connectionType
		end
	end
	if type == "tcp" then
		local byte, err = self.tcp:send(msg)
		if err == "closed" then
			self:dispatchEvent(self.connectionClosedEvent)
		end
	else
		assert(self.udp:sendto(msg, self.serverIP, self.port2))
	end
end

function Client:addMethod(name, method, scope, type)
	self.methods[name] = {}
	self.methods[name].method = method
	self.methods[name].scope = scope
	if self.conf.connectionType == "both" then
		if type == "tcp" then
			self.methods[name].type = "tcp"
		else
			self.methods[name].type = "udp"
		end
	else
		self.methods[name].type = self.conf.connectionType
	end
end

function Client:callMethod(...)
	local msg = self.id.." "..table.concat(arg, " ").." \n"
	self:sendMsg(msg, self.methods[arg[1]].type)
end

function Client:callMethodOf(...)
	local id = arg[#arg]
	arg[#arg] = nil
	local msg = self.id.." proxy "..id.." "..table.concat(arg, " ").." \n"
	self:sendMsg(msg, self.methods[arg[1]].type)
end

function Client:getDevices()
	local msg = string.format("%s %s %s", self.id, 'devices', "\n")
	self:sendMsg(msg)
end

function Client:close()
	self:stopListening()
	if self.tcp then
		self.tcp:close()
		self.tcp = nil
	end
	if self.udp then
		self.udp:close()
		self.udp = nil
	end
	self = nil
end

--[[
	SERVER STUFF
]]--

Server = Core.class(EventDispatcher)

function Server:init(config)
	self.conf = {
		ip = nil,
		tcpPort = 5883,
		udpPort = 5884,
		discoveryPort = 5885,
		multicast = "239.192.1.1",
		maxClients = 0,
		connectionType = "both",
		username = nil
	}
	if config then
		--copying configuration
		for key,value in pairs(config) do
			self.conf[key] = value
		end
	end
	
	if self.conf.connectionType ~= "tcp" and self.conf.connectionType ~= "udp" and self.conf.connectionType ~= "both" then
		self.conf.connectionType = "tcp"
	end
	
	--get IP address of active interface
	if(self.conf.ip) then
		self.ip = self.conf.ip
	else
		self.ip = getIP()
	end
	self.port = self.conf.tcpPort
	self.port2 = self.conf.udpPort
	self.port3 = self.conf.discoveryPort
	local host = self.conf.username or socket.dns.tohostname(self.ip)
	self.host = host or self.ip
	
	--store added methods
	self.methods = {}
	
	--store clients
	self.clients = {}
	self.clientsMap = {}
	self.clientsIds = {}
	
	--client count
	self.clientCount = 0
	
	--temporary client list
	self.tempClients = {}
	
	--if game is not started, still accepts new connections
	self.gameStarted = false
	
	--generate random id
	math.randomseed(os.time())
	self.id = tostring(math.random(os.time()))
	
	if self.conf.connectionType == "tcp" or self.conf.connectionType == "both" then
		self.tcp = assert(socket.bind(self.ip, self.port))
		self.tcp:settimeout(0)
	end
	if self.conf.connectionType == "udp" or self.conf.connectionType == "both" then
		self.udp = socket.udp()
		self.udp:setsockname(self.ip, self.port2)
		--set timeout so it won't block UI
		self.udp:settimeout(0)
	end

	--create broadcast timer
	self.broadcastTimer = Timer.new(100)
    --setting timer callback
    self.broadcastTimer:addEventListener(Event.TIMER, Server.broadcastStep, self)
	
	--create timer for listening
	self.listenTimer = Timer.new(100)
    --setting timer callback
    self.listenTimer:addEventListener(Event.TIMER, Server.ListenStep, self)
	
	--new client event
	self.newClientEvent = Event.new("newClient")
	self.connectionClosedEvent = Event.new("onClientClose")
	self.deviceEvent = Event.new("device")
end

function Server:startBroadcast()
	--create udp instance
	self.listen = socket.udp()
	
	--set socket for ip
	self.listen:setsockname(self.ip, self.port3)
	
	self.gameStarted = false
	
	--set timeout so it won't block UI
	self.listen:settimeout(0)
	
	self.broadcastTimer:start()
end

function Server:broadcastStep()
	--create message
	local msg = string.format("%s %s %s %s", self.id, 'unite', self.host, "\n")
	
	--send to multicast group
	assert(self.listen:sendto(msg, self.conf.multicast, self.port3))
	
	--enable broadcast
	self.listen:setoption('broadcast', true)
	--self.listen:setoption('dontroute', true)
	--broadcast message
	assert(self.listen:sendto(msg, "255.255.255.255", self.port3))
	--disable broadcast
	self.listen:setoption('broadcast', false)
	--self.listen:setoption('dontroute', false)
	
	--listen for clients
	self:ListenStep()
end

function Server:stopBroadcast()
	self.broadcastTimer:stop()
	self.gameStarted = true
	if self.listen then
		self.listen:close()
		self.listen = nil
	end
end

function Server:addMethod(name, method, scope, type)
	self.methods[name] = {}
	self.methods[name].method = method
	self.methods[name].scope = scope
	if self.conf.connectionType == "both" then
		if type == "tcp" then
			self.methods[name].type = "tcp"
		else
			self.methods[name].type = "udp"
		end
	else
		self.methods[name].type = self.conf.connectionType
	end
end

function Server:callMethod(...)
	local msg = self.id.." "..table.concat(arg, " ").." \n"
	self:sendMsg(msg, self.methods[arg[1]].type)
end

function Server:callMethodOf(...)
	local to = arg[#arg]
	if self.clientsMap[to] then
		to = self.clientsMap[to].id
	end
	arg[#arg] = nil
	local msg = self.id.." "..table.concat(arg, " ").." \n"
	self:sendMsgTo(msg, to, self.methods[arg[1]].type)
end

function Server:sendMsg(msg, type, exclude)
	if type == nil then
		if self.conf.connectionType == "both" then
			type = "tcp"
		else
			type = self.conf.connectionType
		end
	end
	local sender
	if type == "tcp" then
		if self.clientsMap[exclude] then
			sender = self.clientsMap[exclude].id
		end
		for i = 1, #self.clients do
			if sender ~= i then
				self:sendMsgTo(msg, i, type)
			end
		end
	else
		for i, val in pairs(self.clientsMap) do
			if sender ~= i and (self.conf.connectionType == "both" or i == val.id) then
				self:sendMsgTo(msg, i, type)
			end
		end
	end
end

function Server:sendMsgTo(msg, to, type)
	if type == nil then
		if self.conf.connectionType == "both" then
			type = "tcp"
		else
			type = self.conf.connectionType
		end
	end
	if type == "tcp" then
		local byte, err = self.clients[to]:send(msg)
		if err == "closed" then
			local id = self.clientsIds[to]
			local client = self.clientsMap[id]
			if client.connected then
				client.connected = false
				self.newClientEvent.data = {id = client.id, ip = client.ip, host = client.host}
				self:dispatchEvent(self.connectionClosedEvent)
				local msg = string.format("%s %s %s %s", self.id, 'closed', id, "\n")
				self:sendMsg(msg, id)
			end
		end
	else
		local client = self.clientsMap[to]
		assert(self.udp:sendto(msg, client.ip, self.port2))
	end
end

function Server:startListening()
	self.listenTimer:start()
end

function Server:ListenStep()
	if not self.gameStarted then
		if self.tcp then
			repeat
				--if maximal clients set and reached that limit
				if self.conf.maxClients > 0 and self.clientCount >= self.conf.maxClients then
					--do not accept any new connections
					break
				end
				local client = self.tcp:accept()
				if client then
					client:settimeout(0)
					self.tempClients[#self.tempClients+1] = client
				end
			until not client
			local ready, none, err = socket.select(self.tempClients, self.tempClients, 0)
			if err == nil then
				for i = 1, #ready do
					local client = ready[i]
					repeat
						local data, err = client:receive()
						if data then 
							local id, cmd, params = data:match("^(%S*) (%S*) (.*)")
							if cmd == 'join' and self.clientsMap[id] == nil then
								local h = explode(" ", params)
								--get info about client
								local ip = client:getpeername()
								local host = h[1]
								--someone wants to join server
								local clientID = #self.clients + 1
								--store client's ID
								self.clientsMap[id] = {}
								self.clientsMap[id].id = clientID
								self.clientsMap[id].ip = ip
								self.clientsMap[id].host = host
								self.clientsIds[clientID] = id
								--store client
								self.clients[clientID] = client
								--add new server
								self.newClientEvent.data = {id = id, ip = ip, host = host}
								self:dispatchEvent(self.newClientEvent)
							end
						end
					until not data
				end
			end
		end
	end
	
	if self.tcp then
		local ready, none, err = socket.select(self.clients, self.clients, 0)
		if ready then
			for i = 1, #ready do
				local client = ready[i]
				repeat
					-- receive the line
					local data, err = client:receive()
					-- if there was no error, send it back to the client
					if data then 
						local id, cmd, params = data:match("^(%S*) (%S*) (.*)")
						if cmd == "proxy" then
							local p = explode(" ", params)
							local targetId = p[1]
							table.remove(p,1)
							if targetId == self.id then
								local realCmd = p[1]
								table.remove(p,1)
								if #p > 0 then
									p[#p] = id
									if self.methods[realCmd].scope then
										self.methods[realCmd].method(self.methods[realCmd].scope, unpack(p))
									else
										self.methods[realCmd].method(unpack(p))
									end
								else
									if self.methods[realCmd].scope then
										self.methods[realCmd].method(self.methods[realCmd].scope, id)
									else
										self.methods[realCmd].method(id)
									end
								end
							else
								p[#p] = nil
								local msg = id.." "..table.concat(p, " ").." \n"
								self:sendMsgTo(msg, self.clientMaps[targetId].id, "tcp")
							end
						elseif cmd == "devices" then
							local t = {}
							t.id = self.id
							t.ip = self.ip
							t.host = self.host
							local msg = self.id.." device "..table.concat(t, " ").." \n"
							self:sendMsgTo(msg, self.clientsMap[id].id, "tcp")
							for i, val in pairs(self.clientsMap) do
								if i ~= id and val.connected then
									local t = {}
									t.id = i
									t.ip = val.ip
									t.host = val.host
									local msg = self.id.." device "..table.concat(t, " ").." \n"
									self:sendMsgTo(msg, self.clientsMap[id].id, "tcp")
								end
							end
						elseif(self.methods[cmd]) then
							local p = explode(" ", params)
							if p then
								p[#p] = id
								if self.methods[cmd].scope then
									self.methods[cmd].method(self.methods[cmd].scope, unpack(p))
								else
									self.methods[cmd].method(unpack(p))
								end
							else
								if self.methods[cmd].scope then
									self.methods[cmd].method(self.methods[cmd].scope, id)
								else
									self.methods[cmd].method(id)
								end
							end
							self:sendMsg(data.."\n", "tcp", id)
						end
					end
				until not data
			end
		end
	end
	
	if self.udp then
		repeat
			-- receive the line
			local data, ip, port = self.udp:receivefrom()
			-- if there was no error, send it back to the client
			if data then 
				local id, cmd, params = data:match("^(%S*) (%S*) (.*)")
				if cmd == 'join' and self.clientsMap[id] == nil then
					local h = explode(" ", params)
					local host = h[1]
					--store client's ID
					self.clientsMap[id] = {}
					self.clientsMap[id].id = id
					self.clientsMap[id].ip = ip
					self.clientsMap[id].host = host
					self.clientsIds[id] = id
					--add new server
					self.newClientEvent.data = {id = id, ip = ip, host = host}
					self:dispatchEvent(self.newClientEvent)
				elseif cmd == "proxy" then
					local p = explode(" ", params)
					local targetId = p[1]
					table.remove(p,1)
					if targetId == self.id then
						local realCmd = p[1]
						table.remove(p,1)
						if #p > 0 then
							p[#p] = id
							if self.methods[realCmd].scope then
								self.methods[realCmd].method(self.methods[realCmd].scope, unpack(p))
							else
								self.methods[realCmd].method(unpack(p))
							end
						else
							if self.methods[realCmd].scope then
								self.methods[realCmd].method(self.methods[realCmd].scope, id)
							else
								self.methods[realCmd].method(id)
							end
						end
					else
						p[#p] = nil
						local msg = id.." "..table.concat(p, " ").." \n"
						self:sendMsgTo(msg, self.clientMaps[targetId].id, "udp")
					end
				elseif cmd == "devices" then
					for i, val in pairs(self.clientsMap) do
						if val.connected then
							local t = {}
							t.id = i
							t.ip = val.ip
							t.host = val.host
							local msg = id.." device "..table.concat(t, " ").." \n"
							self:sendMsgTo(msg, self.clientsMap[id].id, "udp")
						end
					end
				elseif(self.methods[cmd]) then
					local p = explode(" ", params)
					if p then
						p[#p] = id
						if self.methods[cmd].scope then
							self.methods[cmd].method(self.methods[cmd].scope, unpack(p))
						else
							self.methods[cmd].method(unpack(p))
						end
					else
						if self.methods[cmd].scope then
							self.methods[cmd].method(self.methods[cmd].scope, id)
						else
							self.methods[cmd].method(id)
						end
					end
				end
				if cmd ~= "proxy" then
					self:sendMsg(data.."\n", "udp", id)
				end
			end
		until not data
	end
end

function Server:accept(id)
	if self.clientsMap[id] then
		self.clientsMap[id].connected = true
		local msg = string.format("%s %s %s", self.id, 'accept', "\n")
		self:sendMsgTo(msg, self.clientsMap[id].id)
	else
		error("Error: There is no client with id: "..id, 2)
	end
end

function Server:stopListening()
	self.listenTimer:stop()
end

function Server:getDevices()
	for i, val in pairs(self.clientsMap) do
		if val.connected then
			local t = {}
			t.id = i
			t.ip = val.ip
			t.host = val.host
			self.deviceEvent.data = t
			self:dispatchEvent(self.deviceEvent)
		end
	end
end

function Server:close()
	self:stopBroadcast()
	self:stopListening()
	for i = 1, #self.clients do
		self.clients[i]:close()
	end
	self.clients = nil
	if self.tcp then
		self.tcp:close()
	end
	if self.udp then
		self.udp:close()
	end
	self = nil
end