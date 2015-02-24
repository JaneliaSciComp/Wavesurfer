classdef UserFunctions < ws.system.Subsystem
    
    properties
        TrialWillStart = '';
        TrialDidComplete = '';
        TrialDidAbort = '';
        ExperimentWillStart = '';
        ExperimentDidComplete = '';
        ExperimentDidAbort = '';
        AbortCallsComplete = true; % If true and the equivalent abort function is empty, complete will be called when abort happens.
    end
    
    methods
        function self = UserFunctions(parent)
            self.CanEnable=true;
            self.Enabled=true;            
            self.Parent=parent;
        end
        
        function set.TrialWillStart(self, value)
            if isfloat(value) && isscalar(value) && isnan(value) ,
                % do nothing
            else
                self.validatePropArg('TrialWillStart', value);
                self.TrialWillStart = value;
            end
            self.broadcast('Update');
        end
        
        function set.TrialDidComplete(self, value)
            if isfloat(value) && isscalar(value) && isnan(value) ,
                % do nothing
            else
                self.validatePropArg('TrialDidComplete', value);
                self.TrialDidComplete = value;
            end
            self.broadcast('Update');
        end
        
        function set.TrialDidAbort(self, value)
            if isfloat(value) && isscalar(value) && isnan(value) ,
                % do nothing
            else
                self.validatePropArg('TrialDidAbort', value);
                self.TrialDidAbort = value;
            end
            self.broadcast('Update');
        end
        
        function set.ExperimentWillStart(self, value)
            if isfloat(value) && isscalar(value) && isnan(value) ,
                % do nothing
            else
                self.validatePropArg('ExperimentWillStart', value);
                self.ExperimentWillStart = value;
            end
            self.broadcast('Update');
        end
        
        function set.ExperimentDidComplete(self, value)
            if isfloat(value) && isscalar(value) && isnan(value) ,
                % do nothing
            else
                self.validatePropArg('ExperimentDidComplete', value);
                self.ExperimentDidComplete = value;
            end
            self.broadcast('Update');
        end
        
        function set.ExperimentDidAbort(self, value)
            if isfloat(value) && isscalar(value) && isnan(value) ,
                % do nothing
            else
                self.validatePropArg('ExperimentDidAbort', value);
                self.ExperimentDidAbort = value;
            end
            self.broadcast('Update');
        end
        
        function invoke(self, eventObj, eventName)
            % Only using ispop assumes the caller won't do something malicious like call
            % invoke with 'AbortCallsComplete' or similar.  Trying to keep the overhead as
            % low as possible to allow as much execution time for the user code itself.
            if isprop(self, eventName)
                % Prevent interruption due to errors in user provided code.
                try
                    if~isempty(self.(eventName))
                        feval(self.(eventName), eventObj, eventName);
                    end
                    
                    if self.AbortCallsComplete && strcmp(eventName, 'TrialDidAbort') && isempty(self.TrialDidAbort) && ~isempty(self.TrialDidComplete)
                        feval(self.TrialDidComplete, eventObj, eventName); % Calls complete, but still passes TrialDidAbort
                    end
                    
                    if self.AbortCallsComplete && strcmp(eventName, 'ExperimentDidAbort') && isempty(self.ExperimentDidAbort) && ~isempty(self.ExperimentDidComplete)
                        feval(self.ExperimentDidComplete, eventObj, eventName); % Calls complete, but still passes TrialDidAbort
                    end
                catch me
                    warning('wavesurfer:userfunction:codeerror', me.message);
                end
            else
                warning('wavesurfer:userfunction:unknownuserfunctionevent', '%s is not a supported user function event.', eventName);
            end
        end
    end
    
%     methods (Access = protected)
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.system.Subsystem(self);
%             
%             self.setPropertyAttributeFeatures('TrialWillStart', 'Classes', {'char', 'function_handle'}, 'Attributes', {}, 'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('TrialDidComplete', 'Classes', {'char', 'function_handle'}, 'Attributes', {}, 'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('TrialDidAbort', 'Classes', {'char', 'function_handle'}, 'Attributes', {}, 'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('ExperimentWillStart', 'Classes', {'char', 'function_handle'}, 'Attributes', {}, 'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('ExperimentDidComplete', 'Classes', {'char', 'function_handle'}, 'Attributes', {}, 'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('ExperimentDidAbort', 'Classes', {'char', 'function_handle'}, 'Attributes', {}, 'AllowEmpty', true);
%             self.setPropertyAttributeFeatures('AbortCallsComplete', 'Classes', {'logical'}, 'Attributes', {'scalar'});
%         end
%     end  % protected methods block
    
    methods (Access=protected)
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods (Access=public)
%         function resetProtocol(self)  % has to be public so WavesurferModel can call it
%             % Clears all aspects of the current protocol (i.e. the stuff
%             % that gets saved/loaded to/from the config file.  Idea here is
%             % to return the protocol properties stored in the model to a
%             % blank slate, so that we're sure no aspects of the old
%             % protocol get carried over when loading a new .cfg file.
%             
%             self.Enabled=true;
%             self.TrialWillStart = '';
%             self.TrialDidComplete = '';
%             self.TrialDidAbort = '';
%             self.ExperimentWillStart = '';
%             self.ExperimentDidComplete = '';
%             self.ExperimentDidAbort = '';
%             self.AbortCallsComplete = true;
%         end  % function
    end % methods
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.system.UserFunctions.propertyAttributes();
        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = ws.system.Subsystem.propertyAttributes();

            s.TrialWillStart = struct( 'Classes', {'char'}, 'AllowEmpty', true);
            s.TrialDidComplete = struct( 'Classes', {'char'}, 'AllowEmpty', true);
            s.TrialDidAbort = struct( 'Classes', {'char'}, 'AllowEmpty', true);
            s.ExperimentWillStart = struct( 'Classes', {'char'}, 'AllowEmpty', true);
            s.ExperimentDidComplete = struct( 'Classes', {'char'}, 'AllowEmpty', true);
            s.ExperimentDidAbort = struct( 'Classes', {'char'}, 'AllowEmpty', true);
            s.AbortCallsComplete = struct( 'Classes', {'logical'}, 'Attributes', {{'scalar'}});
            
        end  % function
    end  % class methods block
    
end  % classdef
