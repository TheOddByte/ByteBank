--[[
    [Program] ByteBank Client
    @version 1.0, 2014-12-21
    @author TheOddByte
--]]

local path = ".ByteBank-Client"
local public_key = "Keystone"

--# Make sure that the source folder exists
if not fs.exists( path ) then
    fs.makeDir( path )
    local directories = {
        "APIs", "Scripts";
    }
    for _, name in ipairs( directories ) do
        fs.makeDir( path .. "/" .. name )
    end
    --# Download the required APIs and scripts here
end

--# Load the APIs
for _, name in ipairs( fs.list( path .. "/APIs/" ) ) do
    os.loadAPI( path .. "/APIs/" .. name )
end

--# Load the scripts
local SNet = dofile( path .. "/Scripts/SNet" )


local function main()
    local server = SNet.connect( "ByteBank", "server", public_key )
    if not server then
        error( "Failed to connect to server", 0 )
    end
    while true do
        local e = { os.pullEvent() }
        server:handle( unpack( e ) )
    end
end


local ok, err = pcall( main )
if not ok and err ~= "Terminated" then
    -- Crash screen here
end
