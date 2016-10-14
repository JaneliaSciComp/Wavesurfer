classdef (Abstract) Model < ws.Coding & ws.EventBroadcaster  % & matlab.mixin.SetGet
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
        
        function propNames = listPropertiesForPersistence(self)
            propNamesRaw = listPropertiesForPersistence@ws.Coding(self) ;            
            propNames=setdiff(propNamesRaw, ...
                              {'Parent_'}) ;
        end  % function 

        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Coding(self) ;            
            propNames=setdiff(propNamesRaw, ...
                              {'Parent' 'IsReady'}) ;
        end  % function         
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
        
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
        
        function result = get(self, propertyName) 
            result = self.(propertyName) ;
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end           
    end  % public methods block
    
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
    end  % protected methods block
    
end  % classdef
