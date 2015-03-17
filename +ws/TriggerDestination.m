classdef TriggerDestination < ws.Model & matlab.mixin.Heterogeneous & ws.ni.HasPFIIDAndEdge
    % A class that represents a trigger destination, i.e. a digital input
    % to the daq board that could potentially be used to trigger
    % acquisition, etc.  A trigger destination has a name, a device ID, 
    % a PFI identifier (the zero-based PFI index),
    % and an edge type (rising or falling).  ALT, 2014-05-24
    
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
        function self=TriggerDestination()
            self.Name_ = 'Destination';
            self.DeviceName_ = 'Dev1';
            self.PFIID_ = 0;
            self.Edge_ = ws.ni.TriggerEdge.Rising;            
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
            if isnan(value), return, end            
            self.validatePropArg('Name', value);
            self.Name_ = value;
        end
        
        function set.DeviceName(self, value)
            if isnan(value), return, end
            self.validatePropArg('DeviceName', value);
            self.DeviceName_ = value;
        end
        
        function set.PFIID(self, value)
            if isnan(value), return, end            
            self.validatePropArg('PFIID', value);
            self.PFIID_ = value;
        end
        
        function set.Edge(self, value)
            if isnan(value), return, end            
            self.validatePropArg('Edge', value);
            self.Edge_ = value;
        end        
    end
    
    methods (Access=protected)        
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.TriggerSource.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();

            s.Name=struct('Classes', 'char', ...
                          'Attributes', {{'vector'}}, ...
                          'AllowEmpty', false);
            s.DeviceName=struct('Classes', 'char', ...
                            'Attributes', {{'vector'}}, ...
                            'AllowEmpty', true);
            s.PFIID=struct('Classes', 'numeric', ...
                           'Attributes', {{'scalar', 'integer'}}, ...
                           'AllowEmpty', false);
            s.Edge=struct('Classes', 'ws.ni.TriggerEdge', ...
                          'Attributes', 'scalar', ...
                          'AllowEmpty', false);
        end  % function
    end  % class methods block
    
end
