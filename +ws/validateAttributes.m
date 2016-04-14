function val = validateAttributes(val,varargin)
%VALIDATEATTRIBUTES Mimic of built-in function 
% val = validateAttributes(val,p1,v1,...)
%
% The validateAttributes mimic exists largely to "expand the repertoire" of
% the built-in validateattributes. Additional Classes, Attributes, etc have
% been added.
%
% In addition, this function on certain occassions performs type conversion
% and returns the converted value on the left-hand side. The idea is that
% in many cases validateAttributes is used to check input argument
% arguments, which often end up being converted to a consistent
% type/format.
%
% Accepted P-V input arguments:
% 
% 'Classes' (cellstr)
% This is as in the built-in function, with additional available options
% 'cellstr', 'string', 'binaryflex', 'binarylogical', 'binarynumeric'.
% 'cellstr' and 'string' are as named; also, 'cellstr' accepts a single
% string value, which it converts to a scalar cellstr. 'binaryflex' checks
% for either logical or binary-numeric values. 'binarylogical' and
% 'binarynumeric' are like 'binaryflex', except that
% mimics.validateAttributes performs type conversion of the value to
% logical or double, respectively.
%
% 'Attributes' (cellstr)
% This is as in the built-in function, with expanded functionality for the
% 'size' option, and additional options 'nonscalar', 'numel', and 'range'.
%
% 'size' now accepts a scalar value, indicating expectation of a vector
% argument with the given number of elements. 'nonscalar' is as named.
% 'numel' is identical to 'size', except it can only be used with a scalar
% argument. 'range' is a shorthand for using the '>=' and '<=' built-in
% options. It accepts a numeric, two-element argument, with the attributes
% {... 'range' rangeVal ...} being equivalent to {... '>=' rangeVal(1) '<='
% rangeVal(2) ...}.
%
% 'AllowEmptyDouble' (scalar logical)
% If true, mimics.validateAttributes accepts a 0x0 empty double value (aka
% []), regardless of other conditions. The idea is to accept [] as "no
% value" or "NULL value".
%
% 'Options' (cell array or numeric array)
% If a cell array, this attribute specifies a list of acceptable options
% for the value. The cell array of options must either be a cell array of
% numeric arrays, or a cellstr.
%
% If a numeric array, this attribute may be a column vector, or 2D array
% value. In the case of a 2D array, the rows of this attribute specifies
% acceptable options for a row-vector-valued or 2d-array-valued input. In
% the case of a 2d-array-valued input, all rows must match one of the
% available options.
%
% 'List' (Integer scalar/array, [], Inf, or string member of {'vector'
% 'fullvector'}.
% This attribute specifies that the value is a cell array where each
% element must satisfy the other specified constraints. The size of the
% cell array is constrained by the value of the 'List' specification. If
% List is a scalar, the cell array must be a vector with the specified
% number of elements. If it is an array, size() of the cell array must
% equal the specified array. If List is empty, any cell array size is
% allowed, including empty. If List is inf, any non-empty cell array is
% allowed. If 'vector', then any vector (including empty) is allowed; if
% 'fullvector', any nonempty vector is allowed.
%
% See also validateattributes.

% TODO: 
%  * 'numel' attribute has been added in R2011. Make changes accordingly to use it.
%  * Support remaining arguments (argument 4 onwards) of built-in validateattributes
%  * Handle case of 'integer' attribute when infinite values are allowed -- requires two-pass of validateattributes() call
%  * Wrap in 'AllowEmptyDouble' & 'List' as custom attributes rather than separate from the Classes/Attributes. This makes it more of an extension-type mimic.
%  
%

assert(mod(numel(varargin),2)==0,'P-V arguments must come in pairs.');

VALIDPROPS = {
    'Classes'
    'Attributes'
    'AllowEmpty'
    'AllowEmptyDouble'
    'Options'
    'List'
    };

args = ws.filterPVArgs(varargin,VALIDPROPS);
props = args(1:2:end);
vals = args(2:2:end);
args = cell2struct(vals(:),props(:),1);

args = zlclValidateArgs(args);

if isfield(args,'List') && ~isempty(args.List)
    assert(iscell(val),'most:mimics:validateAttributes:invalidListVal',...
        'Expected value to be a cell array.');
    zlclCheckListSize(val,args.List);
    for c = 1:numel(val)
        val{c} = zlclValidateValue(val{c},args);
    end    
else
    val = zlclValidateValue(val,args);
end

end

% PostConditions
% * s.Options, if present, is either a cell vector or a numeric array. If a
%   cell vector, Options must be a cellstr or cell array of numerics.
% * s.Classes is a cellstr.
% * s.Attributes is a cell array.
% * s.AllowEmptyDouble is a scalar logical.
% * s.List is a valid List specification (if present).
function s = zlclValidateArgs(s)

INVALID_ARG_EID = 'most:mimics:validateAttributes:invalidArgs';

if isfield(s,'Options') && ~isempty(s.Options)
    v = s.Options;
    if iscell(v)
        assert(isvector(v) || isempty(v),INVALID_ARG_EID,...
            '''Options'' cell array must be a vector.');
        assert(iscellstr(v) || all(cellfun(@isnumeric,v)),INVALID_ARG_EID,...
            '''Options'' cell array must be either a cellstr or cell array of numerics.');
    elseif isnumeric(v)
        assert(ismatrix(v),INVALID_ARG_EID,...
            '''Options'' numeric array must be a 2D matrix.');
    else
        assert(false,INVALID_ARG_EID,...
            '''Options'' must be either a cell array or numeric array of options.');
    end
end

if ~isfield(s,'AllowEmptyDouble')
    s.AllowEmptyDouble = false;
end
assert(isscalar(s.AllowEmptyDouble) && islogical(s.AllowEmptyDouble),...
    INVALID_ARG_EID,'''AllowEmptyDouble'' must be a scalar logical.');

if ~isfield(s,'AllowEmpty')
    s.AllowEmpty = false;
end
assert(isscalar(s.AllowEmpty) && (islogical(s.AllowEmpty) || (isnumeric(s.AllowEmpty) && (s.AllowEmpty==0 || s.AllowEmpty==1)))  , ...
       INVALID_ARG_EID,'''AllowEmpty'' must be a scalar logical.');

if ~isfield(s,'Classes')
    s.Classes = {};
end
if ischar(s.Classes)
    s.Classes = cellstr(s.Classes);
end
assert(iscellstr(s.Classes),INVALID_ARG_EID,...
    '''Classes'' must be a string or cellstring.');

if ~isfield(s,'Attributes')
    s.Attributes = {};
end
assert(iscell(s.Attributes),INVALID_ARG_EID,'''Attributes'' must be a cell array.');

if isfield(s,'List') && ~isempty(s.List)
    listVal = s.List;
    if isempty(listVal)
    elseif isnumeric(listVal)
    elseif ischar(listVal)
        assert(any(strcmpi(listVal,{'vector' 'fullvector'})), ...
            INVALID_ARG_EID,'Invalid ''List'' specification.');
    else
        assert(false,INVALID_ARG_EID,'Invalid ''List'' specification.');
    end
end

end

function val = zlclValidateValue(val,s)

% Shortcircuit: AllowEmptyDouble
if s.AllowEmptyDouble && ws.isEmptyDouble(val) 
    return;
end

% Shortcircuit: AllowEmpty
if s.AllowEmpty && isempty(val)
    return;
end

% Shortcircuit: cell-array options
if isfield(s,'Options') && ~isempty(s.Options)
    optionsData = s.Options;
    if iscell(optionsData)
        cls = zlclValidateCellOptions(val,optionsData);
        if ~isempty(s.Attributes) && any(cellfun(@(x)ischar(x), optionsData))
            warning('most:mimics:validateAttributes:cellArrayOptions', ...
                    'Attributes are ignored when options are specified as a cellstr.');
            s.Attributes = {};
        end
        if isempty(s.Classes)
            s.Classes = {cls}; % builtin validateattributes requires some class specification
        end
    else % numeric options
        zlclValidateNumOptions(val,optionsData);
        if isempty(s.Classes)
            s.Classes = {'numeric'}; % builtin validateattributes requires some class specification
        end
    end
end

classes = s.Classes(:)';
attributes = s.Attributes(:)';

info = struct();
info.convertFcn = [];
[val, classes, attributes, info] = zlclProcessClasses(val,classes,attributes,info);
attributes = zlclProcessAttributes(val,attributes);

% Call builtin
validateattributes(val,classes,attributes);

% Type conversion
if ~isempty(info.convertFcn)
    val = info.convertFcn(val);
end

end

function [val, classes, attributes, info] = zlclProcessClasses(val,classes,attributes,info)

if isempty(classes)
    return;
end

EID = 'most:mimics:validateAttributes:classError';

% string
tfString = strcmpi(classes,'string');
if any(tfString)    
    if ws.isString(val)
        % ok, it's a string
        classes(tfString) = {'char'}; % replace 'string' with 'char' for builtin validateAttributes
    elseif all(tfString)
        % It's not a string, and that was the only option for classes
        assert(false,EID,'Expected a string value.');
    else
        % The value is not a string, but other classes are possible.
        classes(tfString) = {'char'};
    end
end

% cellstring
tfCellstr = strcmpi(classes,'cellstr');
tfCell = strcmpi(classes,'cell');
if any(tfCellstr)
    if ws.isString(val)
        val = cellstr(val);
    end
    if all(tfCellstr)
        assert(iscellstr(val),EID,'Expected value to be a cellstr.');
        classes(tfCellstr) = {'cell'}; % for builtin etc
    elseif any(tfCell)
        % At least one 'cellstr' and one 'cell' class arg. You can't be a 
        % cellstr without being a cell, so cellstrness is moot.
        classes(tfCellstr) = {'cell'};
    else
        % At least one 'cellstr' and other arg (not 'cell').
        if iscellstr(val)
            % cellstr requirement is met
            classes(tfCellstr) = {'cell'};
        else
            % it's not a cellstr, but there is still at least one other
            % class to check
            classes(:,tfCellstr) = [];
        end
    end
end

% binaryflex, binarylogical, binarynumeric
lowerClasses = lower(classes);
tfBnry = ismember(lowerClasses,{'binaryflex' 'binarylogical' 'binarynumeric'});
if all(tfBnry)
    % if nnz(tfBnry)>1, this is dumb b/c the multiple binary specifications
    % are redundant/conflicting.
    if ismember('binarylogical',lowerClasses)
        info.convertFcn = @logical;
    elseif ismember('binarynumeric',lowerClasses)
        info.convertFcn = @double;
    end
    classes = {'numeric' 'logical'};
    attributes = [attributes {'binary'}];    
elseif any(tfBnry)
    error(EID,'''binary*'' classes cannot be mixed with other classes.');
end

end

function attributes = zlclProcessAttributes(val,attributes)

    EID = 'most:mimics:validateAttributes:attributeError';

    % nonscalar
    tfNonscalar = cellfun(@(x)ischar(x) && strcmpi(x,'nonscalar'),attributes);
    if any(tfNonscalar)
        assert(~isscalar(val),EID,'Expected a nonscalar value.');
        attributes(:,tfNonscalar) = [];
    end
    
    % size/numel
    idx = 1;
    while idx<numel(attributes)
        att = attributes{idx};
        
        tfScalarSizeOrNumel = false;
        if ischar(att)
            if strcmpi(att,'numel')
                tfScalarSizeOrNumel = true;
            elseif strcmpi(att,'size')
                tfScalarSizeOrNumel = isscalar(attributes{idx+1});
            end
        end
        
        if tfScalarSizeOrNumel
            attVal = attributes{idx+1};
            try
                validateattributes(attVal,{'numeric'},{'scalar' 'integer' 'nonnegative'});
            catch %#ok<CTCH>
                error(EID,'Invalid ''numel'' or scalar ''size'' specification.');
            end
            assert(numel(val)==attVal,EID,'Expected value with %d elements.',attVal);
            attributes(:,[idx idx+1]) = [];
            
            % elements of attributes deleted; don't change idx
        else
            idx = idx+1;
        end
    end
    
    % range
    idx = 1;
    while idx<numel(attributes)
        att = attributes{idx};
        if strcmpi(att,'range')
            attVal = attributes{idx+1};
            assert(isnumeric(attVal) && numel(attVal)==2,EID,...
                '''Range'' specification must be a two-element numeric vector.');
            rangeArgs = {'>=' attVal(1) '<=' attVal(2)};
            attributes = [attributes(1:idx-1) rangeArgs attributes(idx+2:end)];
            idx = idx + 4;
        else
            idx = idx + 1;
        end        
    end
end

function zlclCheckListSize(val,listVal)

    EID = 'most:mimics:validateAttributes:badListSize';
    
    if isempty(listVal)
        % val can take any size
    elseif isnumeric(listVal)
        if isscalar(listVal) && isinf(listVal)
            assert(~isempty(val),EID,'Expected value to be a nonempty cell array.');
        elseif isscalar(listVal) && ~isinf(listVal)
            assert(isvector(val) && numel(val)==listVal,EID,...
                'Expected value to be a cell vector with %d elements.',listVal);
        else
            assert(isequal(size(val),listVal),EID,...
                'Expected value to be a cell array of size %s.',mat2str(listVal));
        end
    elseif ischar(listVal)
        switch lower(listVal)
            case 'vector'
                assert(isvector(val),EID,'Expected value to be a cell vector.');                
            case 'fullvector'
                assert(isvector(val) && ~isempty(val),EID,...
                    'Expected value to be a nonempty cell vector.');
            otherwise
                assert(false); % impossible
        end
    else
        assert(false,EID,'Invalid ''List'' specification.');
    end
end

function cls = zlclValidateCellOptions(val,options)
EID = 'most:mimics:validateAttributes:valNotAnOption';
EMSG = 'Value is not in the list of allowed options.';

if iscellstr(options)
    assert(ws.isString(val) && ismember(val,options),EID,EMSG);
    cls = 'char';
else % cell array of numerics
    assert(isnumeric(val) && any(cellfun(@(x)isequaln(val,x),options)),...
        EID,EMSG);
    cls = 'numeric';
end
end

function zlclValidateNumOptions(val,options)
EID = 'most:mimics:validateAttributes:valNotAnOption';
EMSG = 'Value is not in the list of allowed options.';

if isvector(options) && iscolumn(options) %TODO: Why do we restrict columns array to being a column vector? At least if we do, should give a better error to the poor developer!
    assert(isscalar(val) && isnumeric(val) && ismember(val,options),EID,EMSG);
elseif ismatrix(options)  %2-d Array whose rows specify vector options for the value
    assert(isnumeric(val) && size(val,2) == size(options,2) && all(ismember(val,options,'rows')),...
        EID,EMSG);
end
end
    
