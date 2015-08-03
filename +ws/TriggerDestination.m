classdef TriggerDestination < ws.Model %& ws.ni.HasPFIIDAndEdge  % & matlab.mixin.Heterogeneous  (was second in list)
    % A class that represents a trigger destination, i.e. a digital input
    % to the daq board that could potentially be used to trigger
    % acquisition, etc.  A trigger destination has a name, a device ID, 
    % a PFI identifier (the zero-based PFI index),
    % and an edge type (rising or falling).  ALT, 2014-05-24
    
    properties (Constant=true)
        IsInternal = false
    end
    
    properties (Dependent=true)
        Name
        DeviceName  % the NI device ID string, e.g. 'Dev1'
        PFIID  
            % If the destination is user-defined, this indicates the PFI
            % line to be used as an input. If the destination is automatic,
            % this indicates the PFI line to be used as an _output_.
        Edge
            % Whether rising edges or falling edges constitute a trigger
            % event.
    end
    
    properties (Access=protected)
        Name_
        DeviceName_
        PFIID_
        Edge_
    end
    
    methods
        function self=TriggerDestination(parent)
            self@ws.Model(parent) ;
            self.Name_ = 'Destination';
            self.DeviceName_ = 'Dev1';
            self.PFIID_ = 0;
            self.Edge_ = 'DAQmx_Val_Rising';            
        end
        
        function value=get.Name(self)
            value=self.Name_;
        end
        
        function value=get.DeviceName(self)
            value=self.DeviceName_;
        end
                
        function value=get.PFIID(self)
            value=self.PFIID_;
        end
        
        function value=get.Edge(self)
            value=self.Edge_;
        end
        
        function set.Name(self, value)
            if ws.utility.isASettableValue(value) ,
                if ws.utility.isString(value) && ~isempty(value) ,
                    self.Name_ = value ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'Name must be a nonempty string');                  
                end                    
            end
            self.broadcast('Update');            
        end
        
        function set.DeviceName(self, value)
            if ws.utility.isASettableValue(value) ,
                if ws.utility.isString(value) ,
                    self.DeviceName_ = value ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'DeviceName must be a string');                  
                end                    
            end
            self.broadcast('Update');            
        end
        
        function set.PFIID(self, value)
            if ws.utility.isASettableValue(value) ,
                if isnumeric(value) && isscalar(value) && isreal(value) && value==round(value) && value>=0 ,
                    value = double(value) ;
                    self.PFIID_ = value ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'PFIID must be a (scalar) nonnegative integer');                  
                end                    
            end
            self.broadcast('Update');            
        end
        
        function set.Edge(self, value)
            if ws.utility.isASettableValue(value) ,
                if ws.isAnEdgeType(value) ,
                    self.Edge_ = value;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'Edge must be ''DAQmx_Val_Rising'' or ''DAQmx_Val_Falling''');                  
                end                                        
            end
            self.broadcast('Update');            
        end  % function 
    end  % methods
    
    methods (Access=protected)        
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct();        
        mdlHeaderExcludeProps = {};
    end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
% 
%             s.Name=struct('Classes', 'char', ...
%                           'Attributes', {{'vector'}}, ...
%                           'AllowEmpty', false);
%             s.DeviceName=struct('Classes', 'char', ...
%                             'Attributes', {{'vector'}}, ...
%                             'AllowEmpty', true);
%             s.PFIID=struct('Classes', 'numeric', ...
%                            'Attributes', {{'scalar', 'integer'}}, ...
%                            'AllowEmpty', false);
%         end  % function
%     end  % class methods block
    
end  % classdef
