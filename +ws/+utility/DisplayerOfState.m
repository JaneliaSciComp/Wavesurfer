classdef DisplayerOfState < handle & matlab.mixin.CustomDisplay
    % A mixin class that when you display it at the command line, displays
    % the values in all of its independent properties, regardless of
    % their GetAcccess attribute.  So basically it shows you the internal
    % state of the object.  I find this is usually what I want to see when
    % at the command line, especially when debugging.
    
    methods (Access = protected)
        function propertyGroups=getPropertyGroups(self)
            propertyNameList=ws.most.util.findPropertiesSuchThat(self,'Dependent',false);
            propertyGroups=matlab.mixin.util.PropertyGroup(propertyNameList);
        end  % function
    end  % methods
end
