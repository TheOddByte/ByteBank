--[[
    [API] SNet
	@version 1.0, 2014-12-18
	@author TheOddByte
	
	
	Special credits to:
	    GravityScore - SHA256
		SquidDev     - AES
		Alex Kloss   - Base64
--]]



local SNet = {}
SNet.__index = SNet



--# Check that all the needed APIs are loaded
assert( hash ~= nil, "hash API needed for this script" )
assert( base64 ~= nil, "base64 API needed for this script" )
assert( AES ~= nil, "AES API needed for this script" )




--# Local functions
local function findModems()
    local modems = {}
    for _, name in ipairs( peripheral.getNames() ) do
	    if peripheral.getType( name ) == "modem" then
		    local modem = peripheral.wrap( name )
			if modem.isWireless() then
			    table.insert( modems, name )
			end
		end
	end
	return #modems > 0 and modems or nil
end


local function isOpen()
    local modems = findModems()
	for _, modem in ipairs( modems ) do
	    if rednet.isOpen( modem ) then
		    return true
		end
	end
	return false
end


local function exists( protocol, hostname )
    local id = rednet.lookup( protocol, hostname )
	return type( id ) == "number" and true, id or false
end


local function encrypt( _data, key )
    local data
    if type( _data ) == "table" then
	    data = {}
	    for k, v in pairs( _data ) do
		    local index = AES.encrypt( key, k )
			local value = AES.encrypt( key, v )
		    data[base64.encode( index )] = base64.encode( value )
		end
	
	elseif type( _data ) == "string" then
	    data = AES.encrypt( key, _data )
		data = base64.encode( data )
	end
	return data
end


local function decrypt( data, key )
    local result = {}
    if type( data ) == "table" then
	    result = {}
	    for k, v in pairs( data ) do
		    local index = base64.decode( k )
			index = AES.decrypt( key, index )
			local value = base64.decode( v )
			value = AES.decrypt( key, value )
		    result[index] = value
		end
	
	elseif type( data ) == "string" then
	    result = base64.decode( data )
		result = AES.decrypt( key, result )
	end
    return result
end






SNet.connect = function( protocol, hostname, server_key )

    --# Make sure there is a modem attached
	if not isOpen() then
	    local modems = findModems()
		if #modems > 0 then
		    rednet.open( modems[1] )
		else
		    error( "No modem attached", 0 )
		end
	end

    local valid, host_id = exists( protocol, hostname )
	if valid then
		local net = {
			isHost   = false;
			key      = hash.sha256( tostring( math.ceil(os.time())*host_id ) );
			id       = host_id;
			protocol = protocol;
			hostname = hostname;
		}
		
		local packet = {
		    ["request"] = "snet.connect";
			["seed"] = tostring( os.time()*math.random() );
		}
		
		net.key = hash.sha256( tostring( packet["seed"]*host_id ) )
		
		--# Share the seed with the server
		rednet.send( host_id, encrypt( packet, server_key ), protocol )
		
		--# Get the response from the server
		local timer, time, timeout = os.startTimer( 1 ), 0, 20
		while true do
		    local e = { os.pullEvent() }
			if e[1] == "rednet_message" and e[2] == host_id and type( e[3] ) == "table" then
			    local packet = decrypt( e[3], net.key )
				if packet["response"] and packet["response"] == "success" then
					return setmetatable( net, SNet )
				end
			
			elseif e[1] == "timer" and e[2] == timer then
			    time = time + 1
				if time == timeout then
			        return nil
				end
			end
		end 
	end
end




SNet.host = function( protocol, hostname, key )

    --# Make sure there is a modem attached
	if not isOpen() then
	    local modems = findModems()
		if #modems > 0 then
		    rednet.open( modems[1] )
		else
		    error( "No modem attached", 0 )
		end
	end
	
    if not exists( protocol, hostname ) then
	    local net = {
		    key         = key;
		    isHost      = true;
		    connections = {};
			protocol    = protocol;
			hostname    = hostname;
		}
		rednet.host( protocol, hostname )
		return setmetatable( net, SNet )
	end
	return nil
end




function SNet:isValidID( id )
    if self.isHost then
	    if self.connections[tostring(id)] then
		    return true;
		end
	else
	    if id == self.id then
		    return true;
		end
	end
	return false
end




function SNet:handle( ... )
    local e = { ... }
	if e[1] == "rednet_message" then
	    if self.isHost then 
		    if self:isValidID( e[2] ) and e[4] == self.protocol then
			    local packet = decrypt( e[3], self.connections[tostring( e[2] )] )
				if packet["request"] and packet["request"] == "snet.disconnect" then
				    self:send( e[2], {
					    ["response"] = "success";
					})
				    self.connections[tostring( e[2] )] = nil
					return nil
				end
		        return e[2], packet
			else
			    if e[4] == self.protocol then
					local packet = decrypt( e[3], self.key )
					if type( packet ) == "table" and packet["request"] and packet["request"] == "snet.connect" then
						self.connections[tostring( e[2] )] = hash.sha256( tostring( tonumber(packet["seed"])*os.getComputerID() ) )
						self:send( e[2],{
						    ["response"] = "success";
						})
						return nil
					end
				end
			end
		else
		    if self:isValidID( e[2] ) then
			    return e[2], decrypt( e[3], self.key )
			end
		end
	else
	    return nil
	end
end

function SNet:ping( id, timeout )
    timeout = type( timeout ) == "number" and timeout or 20
    if self:isValidID( id ) then
	    local packet = {
		    ["request"] = "snet.ping";
		}
		
		local ping, timer = 0, 0
		while true do
			if self.isHost then
				rednet.send( id, encrypt( packet, self.connections[tostring(id)] ), self.protocol )
			else
				rednet.send( id, encrypt( packet, self.key ), self.protocol )
			end
			
			local _id, packet = rednet.receive( protocol, 1 )
			packet = type( packet ) == "table" and decrypt( packet, self.isHost and self.connections[tostring(id)] or self.key )
			if _id == id then
                if packet["response"] and packet["response"] == "snet.pong" then
				    return true, ping
				end
			end
			ping  = ping  + 1
			timer = timer + 1
			if timer == timeout then
			    return false
			end
		end
	end
end


--[[
    @param    Int id
	@param    String message
--]]
function SNet:send( id, message )
    if self:isValidID( id ) then
	    if self.isHost then
            rednet.send( id, encrypt( message, self.connections[tostring(id)] ), self.protocol )
		else
		    rednet.send( id, encrypt( message, self.key ), self.protocol )
		end
	end
end




--[[
    @param    Int timeout
	@return   nil or number, string
--]]
function SNet:receive( timeout )
	if type( timeout ) == "number" then 
	    timeout = os.startTimer(timeout) 
	end
	
	while true do
		local e = { os.pullEvent() }
		if e[1] == "rednet_message" and self:isValidID( e[2] ) and e[4] == self.protocol then
			return e[2], decrypt( e[3], self.key )
		elseif e[1] == "timer" and e[2] == timeout then 
			return nil 
		end
	end
end




function SNet:disconnect()
    self:send( self.id, {
	    ["request"] = "snet.disconnect";
	})
	local time, timeout, id, packet = 0, 30
	repeat
	    id, packet = self:receive( 1 )
		time = time + 1
	until id == self.id and packet["response"] and packet["response"] == "success" or time == timeout
	if time == timeout then
	    return false
	else
	    self = nil
	    return true
	end
end




return SNet
