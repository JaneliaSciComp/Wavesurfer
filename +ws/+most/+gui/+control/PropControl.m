classdef PropControl < handle
    %PROPCONTROL Abstract class encapsulating one or more uicontrols that 
    %represent one or more model properties
    %
    %PropControls are typically instantiated in the opening functions of
    %GUI files.
    
    %% ABSTRACT PROPERTIES
    properties (Abstract,Dependent)
        propNames; %Properties to which this PropControl pertains (determined on initialization)
        hControls; %UIControls to which this PropControl pertains (determined on initialization)
    end
    
    
    %% PUBLIC METHODS
    
    methods (Abstract)
        
        % status: currently, either 'set' or 'revert'. If status is 'set'
        % (the typical case), val is the decoded value for propname. If
        % status is 'revert', the PropControl failed to decode the new
        % value, and the app/appC should revert the PropControl for
        % propname. In this case, val is indeterminate.
        %
        % Moving forward, we could add a status 'no-op' which is like
        % 'revert' except that in this case the app/appC need not revert
        % the PropControl for the given property.
        %
        % The reason a status code is necessary is that some cases, decode
        % may fail for a PropControl and the previous value is
        % inaccessible. An example of this is when the PropertyTable has an
        % 'unencodeable value', which is then edited into an unDEcodeable
        % value. AL 2/3/2011
        %
        % This method should not throw.
        [status propname val] = decodeFcn(obj,hObject,eventdata,handles)
        
        % This method should not throw.
        encodeFcn(obj,propname,newVal)        
    end    
    
    methods
        function init(obj,metadata) %#ok<MANU,INUSD>
            % default implementation does nothing
        end
    end
end
