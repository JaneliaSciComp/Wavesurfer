function tf = isvalidated(val,classes,attributes)
%ISVALIDATED Provides a logical output to Matlab's 'validateattributes' function/functionality
%   validateattributes() is designeed to throw an error if validation fails. 
%   In some cases, it's useful to return a 
%
%   isvalidated() can be used as an alternative to complex compound binary validations, 
%   e.g. isscalar(x) && isnumeric(x) && x>=0 && round(x)==x can be replaced with
%   isvalidated(x,{'numeric'},{'positive' 'integer' 'scalar'})

try 
    validateattributes(val,classes,attributes);
    tf = true;
catch ME
    if strcmpi(strtok(ME.message),'Expected')
        tf = false;
    else
        ME.rethrow();
    end
end

