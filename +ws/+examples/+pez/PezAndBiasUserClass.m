classdef PezAndBiasUserClass < ws.UserClass
    
    properties (Dependent)
        TrialSequenceMode
        
        BasePosition1X
        BasePosition1Y
        BasePosition1Z
        ToneFrequency1
        DeliverPosition1X
        DeliverPosition1Y
        DeliverPosition1Z
        DispenseChannelPosition1

        BasePosition2X
        BasePosition2Y
        BasePosition2Z
        ToneFrequency2
        DeliverPosition2X
        DeliverPosition2Y
        DeliverPosition2Z
        DispenseChannelPosition2
        
        ToneDuration
        ToneDelay
        DispenseDelay
        ReturnDelay
        
        TrialSequence  % 1 x sweepCount, each element 1 or 2        
    
        CameraCount
    end
    
    properties (Access=protected)
        PezUserObject_
        BiasUserObject_    
    end
    
    methods
        function self = PezAndBiasUserClass()            
            % Creates the "user object"
            self.PezUserObject_ = ws.examples.PezUserClass() ;
            self.BiasUserObject_ = ws.examples.bias.StickShiftBiasUserClass() ;
        end
        
        function wake(self, rootModel)
            self.PezUserObject_.wake(rootModel) ;
            self.BiasUserObject_.wake(rootModel) ;
        end
         
        function delete(self)
            delete(self.PezUserObject_) ;
            delete(self.BiasUserObject_) ;            
        end
        
        % These methods are called in the frontend process
        function willSaveToProtocolFile(self, wsModel)  %#ok<INUSD>
        end
        
        function startingRun(self, wsModel)
            self.PezUserObject_.startingRun(wsModel) ;
            self.BiasUserObject_.startingRun(wsModel) ;
        end
        
        function completingRun(self, wsModel)
            % Called just after each set of sweeps (a.k.a. each
            % "run")
            self.PezUserObject_.completingRun(wsModel) ;
            self.BiasUserObject_.completingRun(wsModel) ;
        end
        
        function stoppingRun(self, wsModel)
            % Called if a sweep goes wrong
            self.PezUserObject_.stoppingRun(wsModel) ;
            self.BiasUserObject_.stoppingRun(wsModel) ;
        end        
        
        function abortingRun(self, wsModel) 
            % Called if a run goes wrong, after the call to
            % abortingSweep()
            self.PezUserObject_.abortingRun(wsModel) ;
            self.BiasUserObject_.abortingRun(wsModel) ;
        end
        
        function startingSweep(self, wsModel)
            % Called just before each sweep
            self.PezUserObject_.startingSweep(wsModel) ;
            self.BiasUserObject_.startingSweep(wsModel) ;
        end
        
        function completingSweep(self, wsModel)
            % Called after each sweep completes
            self.PezUserObject_.completingSweep(wsModel) ;
            self.BiasUserObject_.completingSweep(wsModel) ;
        end
        
        function stoppingSweep(self, wsModel)
            % Called if a sweep goes wrong
            self.PezUserObject_.stoppingSweep(wsModel) ;
            self.BiasUserObject_.stoppingSweep(wsModel) ;
        end        
        
        function abortingSweep(self, wsModel)
            % Called if a sweep goes wrong
            self.PezUserObject_.abortingSweep(wsModel) ;
            self.BiasUserObject_.abortingSweep(wsModel) ;
        end        
        
        function dataAvailable(self, wsModel)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % has been accumulated from the looper.
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self, looper, analogData, digitalData)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller)  %#ok<INUSD>
            % Called just before each episode
        end
        
        function completingEpisode(self,refiller)  %#ok<INUSD>
            % Called after each episode completes
        end
        
        function stoppingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
        end        
        
        function abortingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
        end
        
%         % This is is so "value = this.propertyName" works
%         function result = subsref(self, subscriptingStructure)
%             % self.BiasUserObject has only one gettable property, so this is easy to
%             % route.
%             if isequal(subscriptingStructure.type,'.') ,
%                 propertyName = subscriptingStructure.subs ;                
%             else
%                 error('Only supports dot-style subscripting') ;
%             end
%             if isequal(propertyName, 'cameraCount') ,
%                 result = self.BiasUserObject_.cameraCount ;
%             else
%                 result = self.PezUserObject_.(propertyName) ;
%             end
%         end
%         
%         % This is is so "this.propertyName = newValue" works
%         function self = subsasgn(self, subscriptingStructure, newValue)
%             % an instance of StickShiftBiasUserClass has no settable properties
%             if isequal(subscriptingStructure.type,'.') ,
%                 propertyName = subscriptingStructure.subs ;                
%             else
%                 error('Only supports dot-style subscripting') ;
%             end
%             self.PezUserObject_.(propertyName) = newValue ;
%         end        
        
%         function result = get.PropertyName(self)
%             result = self.PezUserObject_.PropertyName ;
%         end
%         
%         function set.PropertyName(self, newValue)
%             self.PezUserObject_.PropertyName = newValue ;
%         end
        
        function result = get.TrialSequenceMode(self)
            result = self.PezUserObject_.TrialSequenceMode ;
        end
        
        function set.TrialSequenceMode(self, newValue)
            self.PezUserObject_.TrialSequenceMode = newValue ;
        end
        
        function result = get.BasePosition1X(self)
            result = self.PezUserObject_.BasePosition1X ;
        end
        
        function result = get.BasePosition1Y(self)
            result = self.PezUserObject_.BasePosition1Y ;
        end
        
        function result = get.BasePosition1Z(self)
            result = self.PezUserObject_.BasePosition1Z ;
        end
        
        function set.BasePosition1X(self, newValue)
            self.PezUserObject_.BasePosition1X = newValue ;
        end
        
        function set.BasePosition1Y(self, newValue)
            self.PezUserObject_.BasePosition1Z = newValue ;
        end
        
        function set.BasePosition1Z(self, newValue)
            self.PezUserObject_.BasePosition1Z = newValue ;
        end
        
        function result = get.BasePosition2X(self)
            result = self.PezUserObject_.BasePosition2X ;
        end
        
        function result = get.BasePosition2Y(self)
            result = self.PezUserObject_.BasePosition2Y ;
        end
        
        function result = get.BasePosition2Z(self)
            result = self.PezUserObject_.BasePosition2Z ;
        end
        
        function set.BasePosition2X(self, newValue)
            self.PezUserObject_.BasePosition2X = newValue ;
        end
            
        function set.BasePosition2Y(self, newValue)
            self.PezUserObject_.BasePosition2Y = newValue ;
        end
            
        function set.BasePosition2Z(self, newValue)
            self.PezUserObject_.BasePosition2Z = newValue ;
        end
            
        function result = get.ToneFrequency1(self)
            result = self.PezUserObject_.ToneFrequency1 ;
        end
        
        function set.ToneFrequency1(self, newValue)
            self.PezUserObject_.ToneFrequency1 = newValue ;
        end
            
        function result = get.ToneFrequency2(self)
            result = self.PezUserObject_.ToneFrequency2 ;
        end
        
        function set.ToneFrequency2(self, newValue)
            self.PezUserObject_.ToneFrequency2 = newValue ;
        end
            
        function result = get.DeliverPosition1X(self)
            result = self.PezUserObject_.DeliverPosition1X ;
        end
        
        function result = get.DeliverPosition1Y(self)
            result = self.PezUserObject_.DeliverPosition1Y ;
        end
        
        function result = get.DeliverPosition1Z(self)
            result = self.PezUserObject_.DeliverPosition1Z ;
        end
        
        function set.DeliverPosition1X(self, newValue)
            self.PezUserObject_.DeliverPosition1X = newValue ;
        end
            
        function set.DeliverPosition1Y(self, newValue)
            self.PezUserObject_.DeliverPosition1Y = newValue ;
        end
            
        function set.DeliverPosition1Z(self, newValue)
            self.PezUserObject_.DeliverPosition1Z = newValue ;
        end
            
        function result = get.DeliverPosition2X(self)
            result = self.PezUserObject_.DeliverPosition2X ;
        end
        
        function result = get.DeliverPosition2Y(self)
            result = self.PezUserObject_.DeliverPosition2Y ;
        end
        
        function result = get.DeliverPosition2Z(self)
            result = self.PezUserObject_.DeliverPosition2Z ;
        end
        
        function set.DeliverPosition2X(self, newValue)
            self.PezUserObject_.DeliverPosition2X = newValue ;
        end
            
        function set.DeliverPosition2Y(self, newValue)
            self.PezUserObject_.DeliverPosition2Y = newValue ;
        end
            
        function set.DeliverPosition2Z(self, newValue)
            self.PezUserObject_.DeliverPosition2Z = newValue ;
        end
            
        function result = get.DispenseChannelPosition1(self)
            result = self.PezUserObject_.DispenseChannelPosition1 ;
        end
        
        function set.DispenseChannelPosition1(self, newValue)
            self.PezUserObject_.DispenseChannelPosition1 = newValue ;
        end
            
        function result = get.DispenseChannelPosition2(self)
            result = self.PezUserObject_.DispenseChannelPosition2 ;
        end
        
        function set.DispenseChannelPosition2(self, newValue)
            self.PezUserObject_.DispenseChannelPosition2 = newValue ;
        end
            
        function result = get.ToneDuration(self)
            result = self.PezUserObject_.ToneDuration ;
        end
        
        function set.ToneDuration(self, newValue)
            self.PezUserObject_.ToneDuration = newValue ;
        end
            
        function result = get.ToneDelay(self)
            result = self.PezUserObject_.ToneDelay ;
        end
        
        function set.ToneDelay(self, newValue)
            self.PezUserObject_.ToneDelay = newValue ;
        end
            
        function result = get.DispenseDelay(self)
            result = self.PezUserObject_.DispenseDelay ;
        end
        
        function set.DispenseDelay(self, newValue)
            self.PezUserObject_.DispenseDelay = newValue ;
        end
            
        function result = get.ReturnDelay(self)
            result = self.PezUserObject_.ReturnDelay ;
        end
        
        function set.ReturnDelay(self, newValue)
            self.PezUserObject_.ReturnDelay = newValue ;
        end
            
        function result = get.TrialSequence(self)
            result = self.PezUserObject_.TrialSequence ;
        end
        
        function result = get.CameraCount(self)
            result = self.BiasUserObject_.cameraCount ;
        end        
    end  % methods
        
    methods (Access = protected)
        function out = getPropertyValue_(self, name)
            % This allows public access to private properties in certain limited
            % circumstances, like persisting.
            out = self.(name);
        end
        
        function setPropertyValue_(self, name, value)
            % This allows public access to private properties in certain limited
            % circumstances, like persisting.
            self.(name) = value;
        end
    end  % protected
    
    methods 
        function mimic(self, other)
            % Need to override the default mimic method, 
            
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence() ;
            
            % Set each property to the corresponding one, taking special care for some
            for i = 1:length(propertyNames) ,
                thisPropertyName = propertyNames{i} ;
                if isprop(other, thisPropertyName) ,
                    if isequal(thisPropertyName, 'PezUserObject_') || isequal(thisPropertyName, 'BiasUserObject_')
                        source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination                    
                        target = self.(thisPropertyName) ;
                        if ~isempty(target)
                            target.delete() ;  % want to explicitly delete the old one                     
                        end
                        className = class(source) ;
                        newTarget = feval(className) ;
                        if ~isempty(source) ,
                            newTarget.mimic(source) ;
                        end
                        self.setPropertyValue_(thisPropertyName, newTarget) ;                        
                    else
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end
                end
            end
            
            % Do sanity-checking on persisted state
            self.sanitizePersistedState_() ;
            
            % Make sure the transient state is consistent with
            % the non-transient state
            self.synchronizeTransientStateToPersistedState_() ;            
        end  % function
    end
    
end  % classdef

