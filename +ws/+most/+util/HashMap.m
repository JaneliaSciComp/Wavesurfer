classdef HashMap < handle
    %HashMap Implemention of a Map without the type constraints of containers.Map.
    %
    %   The HashMap class is simple and standard Map/Dictionary class.  It
    %   supplements MATLAB's built in containers.Map class which is severly limited
    %   in the types supported as values and keys.
    %
    %   Any variable type may be specified for values and keys.  In addition, there
    %   are properties to control ownership of objects that are added to the Map
    %   (e.g., is the Map responsible for deleting any objects remaining in the Map
    %   when the Map is deleted), and what to return when a requested key is not in
    %   the Map (e.g., standard empty, [], or the output of the class empty
    %   function, foo.bar.empty()).
    %
    %   HashMap also supports extending arrays of objects as values with the add()
    %   method.  map.add(key, newvalue) sets the value as newvalue for the key if
    %   the key has not been set, or extends the existing value by adding newvalue
    %   to the array.
    %
    %   See also containers.Map.
    
    properties
        DeletesValues = false;
        ReturnsEmptyAsClass = false;
    end
    
    properties (Access = private)
        prvKeyType;
        prvValType;
        prvMap;
    end
    
    methods
        function self = HashMap(keyType, valType, varargin)
            narginchk(2, 6);
            
            pvArgs = ws.most.util.filterPVArgs(varargin, {'DeletesValues', 'ReturnsEmptyAsClass'}, {});
            
            prop = pvArgs(1:2:end);
            vals = pvArgs(2:2:end);
            
            for idx = 1:length(prop)
                self.(prop{idx}) = vals{idx};
            end
            
            self.prvMap = struct([]);
            self.prvKeyType = keyType;
            self.prvValType = valType;
        end
        
        function delete(self)
            if self.DeletesValues
                self.prvDeleteContents();
            end
            
            self.prvMap = [];
        end
        
        function add(self, key, value)
            existing = self.get(key);
            existing = [existing, value];
            self.put(key, existing);
        end
        
        function clear(self, varargin)
            if (nargin > 1 && varargin{1}) || self.DeletesValues
                self.prvDeleteContents();
            end
            
            self.prvMap = struct([]);
        end
        
        function out = clone(self)
            out = ws.most.util.HashMap();
            out.prvMap = self.prvMap;
        end
        
        function out = containskey(self, key)
            validateattributes(key, {self.prvKeyType}, {});
            if isobject(key)
                out = ~isempty(self.prvMap) && ~isempty(find(cellfun(@(x)x==key, {self.prvMap.key}), 1));
            else
                out = ~isempty(self.prvMap) && ismember(key, {self.prvMap.key}, 'legacy');
            end
        end
        
        function out = containsvalue(self, value)
            validateattributes(value, {self.prvValType}, {});
            out = ~isempty(self.prvMap) && ismember(value, {self.prvMap.value}, 'legacy');
        end
        
        function out = get(self, key)
            validateattributes(key, {self.prvKeyType}, {});
            idx = self.prvIndexOfKey(key);
            if isempty(idx)
                out = self.prvEmptyValue();
            else
                out = self.prvMap(idx).value;
            end
        end
        
        function out = isempty(self)
            out = isempty(self.prvMap);
        end
        
        function out = keyset(self)
            if ~isempty(self.prvMap)
                out = {self.prvMap.key};
                try
                    cell2mat(out);
                catch %#ok<CTCH>
                end
            else
                out = [];
            end
        end
        
        function out = put(self, key, value)
            validateattributes(key, {self.prvKeyType}, {});
            validateattributes(value, {self.prvValType}, {});
            
            idx = self.prvIndexOfKey(key);
            
            if isempty(idx)
                idx = numel(self.prvMap) + 1;
                out = self.prvEmptyValue();
            else
                out = self.prvMap(idx).value;
            end
            
            self.prvMap(idx).key = key;
            self.prvMap(idx).value = value;
        end
        
        function varargout = remove(self, key)
            validateattributes(key, {self.prvKeyType}, {});
            
            idx = self.prvIndexOfKey(key);
            
            if isempty(idx)
                if nargout > 0
                    varargout{1} = self.prvEmptyValue();
                end
            else
                if nargout > 0
                    varargout{1} = self.prvMap(idx).value;
                elseif self.DeletesValues
                end
                self.prvMap(idx) = [];
            end
        end
        
        function out = count(self)
            out = size(self.prvMap, 2);
        end
        
        function out = values(self)
            if ~isempty(self.prvMap)
                out = {self.prvMap.value};
                try
                    cell2mat(out)
                catch %#ok<CTCH>
                end
            else
                out = {};
            end
        end
    end
    
    methods ( Access = private)
        function out = prvIndexOfKey(self, key)
            if isempty(self.prvMap)
                out = [];
            else
                if ischar(key)
                    out = find(cellfun(@(x)strcmp(x, key), {self.prvMap.key}), 1);
                else
                    out = find(cellfun(@(x)key == x, {self.prvMap.key}), 1);
                end
            end
        end
        
        function out = prvEmptyValue(self)
            if self.ReturnsEmptyAsClass
                switch self.prvValType
                    case 'char'
                        out = '';
                    case 'cell'
                        out = cell(0, 1);
                    otherwise
                        try
                            out = eval([self.prvValType '.empty()']);
                        catch %#ok<CTCH>
                            out = [];
                        end
                end
            else
                out = [];
            end
        end
        
        function prvDeleteContents(self, idx)
            if ~isempty(self.prvMap)
                if nargin == 1
                    cellfun(@nst_delete_if_can, self.values());
                else
                    nst_delete_if_can(self.prvMap(idx).value);
                end
            end
            
            function nst_delete_if_can(object)
                try
                    delete(object)
                catch %#ok<CTCH>
                end
            end
        end
    end
end