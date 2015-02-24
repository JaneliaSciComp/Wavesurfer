classdef (Abstract=true) HasSettingsStack < handle
    % An abstract class that can be inherited from to give a class the
    % ability to push and pop groups of property settings.
    
    properties (SetAccess=protected)
        SettingsStack=cell(0,1)
    end  % properties
    
    methods
        function pushSettings(self,varargin)
            % Set a group of settings in self, pushing the original values
            % onto the stack as a group of settings.  Arguments should be a
            % list of property-value pairs.
            
            % Sort the varargins into property names and values
            propertyNameList=varargin(1:2:end);
            valueList=varargin(2:2:end);
            % store all the current values of the properties
            nValues=length(valueList);
            for i = 1:nValues
                propertyName=propertyNameList{i};
                oldPVStruct.(propertyName) = self.(propertyName);  % build up a structure with one field per property
            end
            % push current settings onto the stack
            self.SettingsStack{end+1,1} = oldPVStruct;
            % now commit the new values to self
            for i = 1:nValues
                propertyName=propertyNameList{i};
                value=valueList{i};
                self.(propertyName) = value;
            end
        end  % method

        function popSettings(self)
            % Take the top settings group off of the stack, and set the
            % self properties contained therein to the values contained
            % therein.  If the settings stack is empty, does nothing, but
            % does not error.
            if isempty(self.SettingsStack)
                return
            end
            pvStruct = self.SettingsStack{end};
            propertyNames = fieldnames(pvStruct);
            nProperties=length(propertyNames);
            for i = 1:nProperties
                propertyName=propertyNames{i};
                valueToRestore=pvStruct.(propertyName);
                self.(propertyName) = valueToRestore;
            end
            self.SettingsStack=self.SettingsStack(1:end-1,1);
        end  % method
    end  % methods    
    
end  % classdef
