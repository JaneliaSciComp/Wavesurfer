function list = structOrObj2List(obj,props)
%STRUCTOROBJ2LIST Convert a struct or object to a string cell array listing all properties/fields
%
% str = structOrObj2List(obj,varname,props)
% obj: (scalar) ML struct or object
% props: (optional cellstr) list of properties to encode. Defaults to all
% properties of obj.
%
% list is returned as:
% {
% prop1
% prop2
% struct.prop1
% struct.prop2
% ... etc
% }

if nargin < 2 || isempty(props)
    props = fieldnames(obj);
end

str = ws.most.util.structOrObj2Assignments(obj,'',props);

C = textscan(str,'%s %*[^\n]');

list = C{1};



% 
% 
% list={};
% 
% if ~isscalar(obj)
%     list = [list sprintf('%s = <nonscalar struct/object>\n',varname)];
%     return;
% end
% 
% for c = 1:numel(props);
%     pname = props{c};
%     val = obj.(pname);
%     if isobject(val) 
%         list = lclNestedObjStructHelper(list,val,pname);
%     elseif isstruct(val)
%         list = lclNestedObjStructHelper(list,val,pname);
%     else
%         list = [list pname];
%     end
% end
% 
% end
% 
% function cell = lclNestedObjStructHelper(cell,val,qualname)
% if ischar(qualname)
%     qualname = {qualname};
% end
% 
% if numel(val) > 1
%     for c = 1:numel(val)
%         cell = [cell strcat(qualname,'.',ws.most.util.structOrObj2List(val(c),qualname))]; %#ok<AGROW>
%     end
% else
%     cell = [cell strcat(qualname,'.',ws.most.util.structOrObj2List(val,qualname))]; 
% end
% end
