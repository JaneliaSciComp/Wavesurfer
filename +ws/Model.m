classdef (Abstract) Model < ws.mixin.Coding & ws.EventBroadcaster
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
            propNamesRaw = listPropertiesForPersistence@ws.mixin.Coding(self) ;            
            propNames=setdiff(propNamesRaw, ...
                              {'Parent_'}) ;
        end  % function 

        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.mixin.Coding(self) ;            
            propNames=setdiff(propNamesRaw, ...
                              {'Parent'}) ;
        end  % function         
    end  % public methods block    
    
    methods         
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end

    methods (Access = protected)
        function setReadiness_(self, newDegreeOfReadinessRaw)
            isReadyBefore=self.IsReady;
            
            self.DegreeOfReadiness_ = ...
                    ws.utility.fif(newDegreeOfReadinessRaw<=1, ...
                                   newDegreeOfReadinessRaw, ...
                                   1);
                        
            isReadyAfter=self.IsReady;
            
            if isReadyAfter ~= isReadyBefore ,
                self.broadcast('UpdateReadiness');
            end            
        end  % function                
        
%         function setParent_(self, newValue)
%             if ws.utility.isASettableValue(newValue) ,
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
