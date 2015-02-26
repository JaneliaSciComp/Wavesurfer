function s = toString(v,numericPrecision)
%TOSTRING Convert a MATLAB array to a string
% s = toString(v)
%   numericPrecision: <Default=15> Maximum number of digits to encode into string for numeric values
%
% Unsupported inputs v are returned as '<unencodeable value>'. Notably,
% structs are not supported because at the moment structs are processed
% with structOrObj2Assignments.
%
% At moment - only vector cell arrays of uniform type (string, logical, numeric) are encodeable

s = '<unencodeable value>';

if nargin < 2 || isempty(numericPrecision)
    numericPrecision = 6;
end

if iscell(v)
    if isempty(v)
        s = '{}';
    elseif isvector(v)
        if iscellstr(v)
            v = strrep(v,'''','''''');
            if size(v,1) > 1 % col vector
                list = sprintf('''%s'';',v{:});
            else
                list = sprintf('''%s'' ',v{:});
            end
            list = list(1:end-1);
            s = ['{' list '}'];
        elseif all(cellfun(@isnumeric,v(:))) || all(cellfun(@islogical,v(:)))
            strv = cellfun(@(x)mat2str(x,numericPrecision),v,'UniformOutput',false);
            if size(v,1)>1 % col vector
                list = sprintf('%s;',strv{:});
            else
                list = sprintf('%s ',strv{:});
            end
            list = list(1:end-1);
            s = ['{' list '}'];
        end
    end
elseif ischar(v)
    if strfind(v,'''')
       v =  ['$' strrep(v,'''','''''')];
    end
    s = ['''' v ''''];
elseif isnumeric(v) || islogical(v)
    if ndims(v) > 2
        s = ws.most.util.array2Str(v);
    else
        s = mat2str(v,numericPrecision);
    end
elseif isa(v,'containers.Map')
    s = ws.most.util.map2str(v);
end

end
