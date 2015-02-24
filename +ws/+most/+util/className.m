function out = className(className,type)
%className - returns the name / related paths of a class
%
% SYNTAX
%     s = className(className)
%     s = className(className,type)
%     
% ARGUMENTS
%     className: object or string specifying a class
%     type:      <optional> one of {'classNameShort','classPrivatePath','packagePrivatePath','classPath'}
%                   if omitted function defaults to 'classNameShort' 
%
% RETURNS
%     out - a string containing the appropriate class name / path

if nargin < 2 || isempty(type)
    type = 'classNameShort';
end

if isobject(className)
    className = class(className);
end

switch type
    case 'classNameShort'
        classNameParts = textscan(className,'%s','Delimiter','.');
        out = classNameParts{1}{end};
    case 'classPrivatePath'
        out = fullfile(fileparts(which(className)),'private');
    case 'packagePrivatePath'
        mc = meta.class.fromName(className);
        containingpack = mc.ContainingPackage;
        if isempty(containingpack)
            out = [];
        else
            p = fileparts(fileparts(which(className)));
            out = fullfile(p,'private');
        end
    case 'classPath'
        out = fileparts(which(className));
    otherwise
        error('ws.most.util.className: Not a valid option: %s',type);
end
end