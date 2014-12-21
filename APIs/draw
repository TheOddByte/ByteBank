--[[
    [API] Draw
    @version 1.0, 2014/06/29
    @author TheOddByte
--]]



local version = "1.0"




function at( x, y, text )
    term.setCursorPos( x, y )
    term.write( text )
end



function setColors( text_color, background )
    if text_color then
        pcall( term.setTextColor, text_color  )
    end
    if background then
        pcall( term.setBackgroundColor, background  )
    end
end


function line( x, y, width, text_color, background, str )
    setColors( text_color, background )
    if str then
        str = str:sub( 1,1 )
    else
        str = " "
    end
    local line = string.rep( str, width )
    at( x, y, line )
end


function box( x, y, width, height, background )
    setColors( nil, background )
    for i = 1, height do
        line( x, (y-1)+i, width, nil, background )
    end
end


function center( y, text, text_color, background )
    setColors( text_color, background )
    local w, h = term.getSize()
    at( math.ceil( (w - #text)/2 ), y, text )
end

function midpoint( x1, x2, y, text, text_color, background )
    setColors( text_color, background )
    at( math.ceil( ((x1+x2)-#text)/2 ), y, text )
end
