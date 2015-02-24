classdef Model < ws.most.Model & ws.mixin.Coding & ws.EventBroadcaster
    events
        Update  % Means that any dependent views need to update themselves
    end
    
    methods
        function self = Model(varargin)        
            self = self@ws.most.Model(varargin{:});
        end  % function
        
        function isValid=isPropertyArgumentValid(self, propertyName, newValue)
            % Function to check if a property value is valid.  Differs from
            % ws.most.Model::validatePropArg() in that it simply returns false
            % if the value is invalid, rather than throwing an exception.
            % This is often useful in controllers, when I typically just
            % want to silently reject invalid values.  Using this method allows the
            % PostSet event to fire even after a rejected change, so that the view can 
            % be updated to reflect the original value, not the invalid one the user 
            % just entered.
            try
                self.validatePropArg(propertyName,newValue);
            catch exception
                if isequal(exception.identifier,'most:Model:invalidPropVal') ,
                    isValid=false;
                    return
                else
                    rethrow(exception);
                end
            end
            % If we get here, no exception was raised
            isValid=true;
        end  % function
    end  % methods block    
    
    methods (Access = protected)
        function defineDefaultPropertyTags(self)
            % These are all hidden, but the way ws.Coding now works, they
            % would nevertheless be including in cfg & usr files.  So we
            % explicitly exclude them.
            self.setPropertyTags('mdlPropAttributes', 'ExcludeFromFileTypes', {'*'});
            self.setPropertyTags('mdlHeaderExcludeProps', 'ExcludeFromFileTypes', {'*'});
            self.setPropertyTags('mdlVerbose', 'ExcludeFromFileTypes', {'*'});
            self.setPropertyTags('mdlInitialized', 'ExcludeFromFileTypes', {'*'});
            self.setPropertyTags('mdlApplyingPropSet', 'ExcludeFromFileTypes', {'*'});
            self.setPropertyTags('hController', 'ExcludeFromFileTypes', {'*'});
            self.setPropertyTags('mdlHParent', 'ExcludeFromFileTypes', {'*'});
            self.setPropertyTags('mdlDependsOnListeners', 'ExcludeFromFileTypes', {'*'});
            self.setPropertyTags('mdlSubModelClasses', 'ExcludeFromFileTypes', {'*'});
        end  % function
    end    
    
end  % classdef
