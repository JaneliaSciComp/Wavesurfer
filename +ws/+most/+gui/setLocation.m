function setLocation(hObj,newLocation)
%SETLOCATION Set new location of HG object, without resizing it
%
%   hObj: A handle-graphics object with 'position' property
%   newLocation: 1x2 array specifying new [left bottom] values for 'position'

validateattributes(newLocation,{'numeric'},{'size' [1 2]});
assert(ishandle(hObj),'Supplied hObj is not a valid HG handle');

set(hObj,get(hObj,'position') .* [0 0 1 1] + [newLocation 0 0]);


end

