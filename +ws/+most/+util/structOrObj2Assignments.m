function str = structOrObj2Assignments(obj,varname,props,numericPrecision,noSpaces)
%STRUCTOROBJ2ASSIGNMENTS Convert a struct or object to a series of
% assignment statements.
%
% str = structOrObj2Assignments(obj,varname,props)
% obj: (scalar) ML struct or object
% varname: (char) base variable name in assignment statements (see below).
% props: (optional cellstr) list of property names to encode. Defaults to all
% properties of obj. Property names can include dot notation for nested object/structure values.
% numericPrecision: (optional integer) specifies max number of digits to use in output string for numeric assignments. (Default value used otherwise)
% noSpaces: (optional bool) specifies to print no spaces (useful for writing to USR files)
%
% str is returned as:
% <varname>.prop1 = value1
% <varname>.prop2 = value2
% <varname>.structProp1 = value3
% <varname>.structProp2 = value4
% ... etc

if nargin < 3 || isempty(props)
    props = fieldnames(obj);
end

if nargin < 4 
    numericPrecision = []; %Use default
end

if nargin < 5 || isempty(noSpaces)
    space = ' ';
elseif noSpaces
    space = '';
end


if ~isscalar(obj)
    str = sprintf('%s = <nonscalar struct/object>\n',varname);
    return;
end

str = [];

if isempty(varname)
    separator = '';
else
    separator = '.';
end

for c = 1:numel(props);
    pname = props{c};        
    
    [base,rem] = strtok(pname,'.');
    
    if isempty(rem)
        val = obj.(pname);
    else
        val = eval(['obj.' pname]);                
    end
        
    qualname = sprintf('%s%s%s',varname,separator,pname);
    if isobject(val) 
        str = lclNestedObjStructHelper(str,val,qualname);
    elseif isstruct(val)
        str = lclNestedObjStructHelper(str,val,qualname);
    else
        str = lclAddPVPair(str,qualname,ws.most.util.toString(val,numericPrecision),space);
    end
end

end

function s = lclAddPVPair(s,pname,strval,space)
s = [s pname space '=' space strval sprintf('\n')];
end

function str = lclNestedObjStructHelper(str,val,qualname)
if numel(val) > 1
    for c = 1:numel(val)
        qualnameidx = sprintf('%s__%d',qualname,c);
        str = [str ws.most.util.structOrObj2Assignments(val(c),qualnameidx)]; %#ok<AGROW>
    end
else
    str = [str ws.most.util.structOrObj2Assignments(val,qualname)]; 
end
end
