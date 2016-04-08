function result = getDefaultUIControlBackgroundColor()
    try
        isAppThemed = ws.winapi.IsAppThemed() ;
    catch me  %#ok<NASGU>
        % is anything at all goes wrong, ignore it and proceed as
        % if isAppThemed were true---it's not worth throwing an
        % error for something so trivial
        isAppThemed = true ;
    end
    if isAppThemed ,
        result = get(0,'defaultUIControlBackgroundColor') ;
    else
        result = [212 208 200]/255 ;  % classic windows background color
    end
end
