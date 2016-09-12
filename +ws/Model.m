classdef (Abstract) Model < ws.Coding & ws.EventBroadcaster & matlab.mixin.SetGet
    properties (Dependent = true, SetAccess=immutable, Transient=true)
        Parent  
        IsReady  % true <=> figure is showing the normal (as opposed to waiting) cursor
    end
    
    properties (Access = protected)
        Parent_
    end
    
    properties (Access = protected, Transient=true)
        DegreeOfReadiness_ = 1
    end

    events
        Update  % Means that any dependent views need to update themselves
        UpdateReadiness
    end
    
    methods
        function self = Model(parent,varargin)
            %self@ws.most.Model(varargin{:});
            if isempty(parent) ,
                parent = [] ;
            elseif ~(isscalar(parent) && isa(parent,'ws.Model')) ,
                error('ws:parentMustBeAWSModel', ...
                      'Parent must be a scalar ws.Model') ;
            end
            
            self.Parent_ = parent ;
        end  % function
        
        function delete(self)
            self.Parent_ = [] ;  % likely not needed
        end
        
        function out = get.Parent(self)
            out = self.Parent_ ;
        end
        
        function mimic(self,other)
            % mimic function that disables, then re-enables broadcasts for
            % speed
            
            % Disable broadcasts for speed
            self.disableBroadcasts();
            self.mimic@ws.Coding(other);
            
            % Re-enable broadcasts
            self.enableBroadcastsMaybe();
            
            % Broadcast update
            self.broadcast('Update');
        end

        function do(self, methodName, varargin)
            % This is intended to be the usual way of calling model
            % methods.  For instance, a call to a ws.Controller
            % controlActuated() method should generally result in a single
            % call to .do() on it's model object, and zero direct calls to
            % model methods.  This gives us a
            % good way to implement functionality that is common to all
            % model method calls, when they are called as the main "thing"
            % the user wanted to accomplish.  For instance, we start
            % warning logging near the beginning of the .do() method, and turn
            % it off near the end.  That way we don't have to do it for
            % each model method, and we only do it once per user command.
            self.startWarningLogging_() ;
            self.(methodName)(varargin{:}) ;
            warningExceptionMaybe = self.stopWarningLogging_() ;
            if ~isempty(warningExceptionMaybe) ,
                warningException = warningExceptionMaybe{1} ;
                throw(warningException) ;
            end
        end
        
%         function set.Parent(self, newValue)
%             self.setParent_(newValue) ;
%         end
        
%         function isValid=isPropertyArgumentValid(self, propertyName, newValue)
%             % Function to check if a property value is valid.  Differs from
%             % ws.most.Model::validatePropArg() in that it simply returns false
%             % if the value is invalid, rather than throwing an exception.
%             % This is often useful in controllers, when I typically just
%             % want to silently reject invalid values.  Using this method allows the
%             % PostSet event to fire even after a rejected change, so that the view can 
%             % be updated to reflect the original value, not the invalid one the user 
%             % just entered.
%             try
%                 self.validatePropArg(propertyName,newValue);
%             catch exception
%                 if isequal(exception.identifier,'most:Model:invalidPropVal') ,
%                     isValid=false;
%                     return
%                 else
%                     rethrow(exception);
%                 end
%             end
%             % If we get here, no exception was raised
%             isValid=true;
%         end  % function
        
        function changeReadiness(self,delta)
            if ~( isnumeric(delta) && isscalar(delta) && (delta==-1 || delta==0 || delta==+1 || (isinf(delta) && delta>0) ) ),
                return
            end
                    
            newDegreeOfReadinessRaw = self.DegreeOfReadiness_ + delta ;
            self.setReadiness_(newDegreeOfReadinessRaw) ;
        end  % function        
        
        function resetReadiness(self)
            % Used during error handling to reset model back to the ready
            % state.
            self.setReadiness_(1) ;
        end  % function        
        
        function value=get.IsReady(self)
            value=(self.DegreeOfReadiness_>0);
        end               
    end  % methods block    
    
    methods         
        function propNames = listPropertiesForPersistence(self)
            propNamesRaw = listPropertiesForPersistence@ws.Coding(self) ;            
            propNames=setdiff(propNamesRaw, ...
                              {'Parent_'}) ;
        end  % function 

        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Coding(self) ;            
            propNames=setdiff(propNamesRaw, ...
                              {'Parent'}) ;
        end  % function         
    end  % public methods block    
    
    methods         
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end

    methods
        function root = getRoot(self)
            % Go up the parentage tree to find the root model object
            if isempty(self.Parent) || ~isvalid(self.Parent) ,
                root = self ;
            else
                root = self.Parent.getRoot() ;
            end                
        end
        
        function result = isRootIdleSensuLato(self)
            root = self.getRoot() ;
            if isprop(root,'State') ,
                state = root.State ;
                result = isequal(state,'idle') || isequal(state,'no_device') ; 
            else
                result = true;  % if the root doesn't have a State, then we'll assume it's not running/test-pulsing
            end
        end
    end
    
    methods (Access = protected)
        function setReadiness_(self, newDegreeOfReadinessRaw)
            isReadyBefore=self.IsReady;
            
            self.DegreeOfReadiness_ = ...
                    ws.fif(newDegreeOfReadinessRaw<=1, ...
                                   newDegreeOfReadinessRaw, ...
                                   1);
                        
            isReadyAfter=self.IsReady;
            
            if isReadyAfter ~= isReadyBefore ,
                self.broadcast('UpdateReadiness');
            end            
        end  % function                
        
%         function setParent_(self, newValue)
%             if ws.isASettableValue(newValue) ,
%                 if isempty(newValue) ,
%                     self.Parent_ = [] ;
%                 elseif isscalar(newValue) && isa(newValue,'ws.Model') ,
%                     self.Parent_ = newValue ;
%                 else
%                     error('most:Model:invalidPropVal', ...
%                           'Parent must be empty or be a scalar ws.Model') ;
%                 end
%             end
%             self.broadcast('Update');                       
%         end
        
%         function defineDefaultPropertyTags_(self)
%             % These are all hidden, but the way ws.Coding now works, they
%             % would nevertheless be including in cfg & usr files.  So we
%             % explicitly exclude them.
% %             self.setPropertyTags('mdlPropAttributes', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('mdlHeaderExcludeProps', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('mdlVerbose', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('mdlInitialized', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('mdlApplyingPropSet', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('hController', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('mdlHParent', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('mdlDependsOnListeners', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('mdlSubModelClasses', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('Parent_', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'*'});
%         end  % function
    end    
    
end  % classdef
