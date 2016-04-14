function result = setBackgroundColorViaHtml(text,color)
    if isinteger(color) ,
        colorAsInteger = double(color) ;
    else
        colorAsInteger = round(255*color) ;  % scale to 0-255
    end
    
    colorAsHtmlHexCode = fprintf('#%02x%02x%02x',colorAsInteger) ;
    result = sprintf('<html><table border=0 width=400 bgcolor=%s><tr><td>%s</td></tr></table></html>', colorAsHtmlHexCode, text) ;
end

