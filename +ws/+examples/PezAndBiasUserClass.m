classdef PezAndBiasUserClass < ws.UserClass
    
    properties (Dependent)
        TrialSequenceMode
        
        BasePosition1  % 3x1, mm
        ToneFrequency1  % Hz
        DeliverPosition1  % 3x1, mm
        DispenseChannelPosition1  % scalar, mm, the vertical delta from the deliver position to the dispense position

        BasePosition2  % 3x1, mm
        ToneFrequency2  % Hz
        DeliverPosition2  % 3x1, mm
        DispenseChannelPosition2  % scalar, mm
        
        ToneDuration  % s
        ToneDelay  % s, the delay between the move to the deliver position and the start of the tone
        DispenseDelay % s, the delay from the end of the tone to the move to the dispense position
        ReturnDelay  % s, the delay until the post returns to the home position
    
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
        
        function result = get.BasePosition1(self)
            result = self.PezUserObject_.BasePosition1 ;
        end
        
        function set.BasePosition1(self, newValue)
            self.PezUserObject_.BasePosition1 = newValue ;
        end
        
        function result = get.BasePosition2(self)
            result = self.PezUserObject_.BasePosition2 ;
        end
        
        function set.BasePosition2(self, newValue)
            self.PezUserObject_.BasePosition2 = newValue ;
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
            
        function result = get.DeliverPosition1(self)
            result = self.PezUserObject_.DeliverPosition1 ;
        end
        
        function set.DeliverPosition1(self, newValue)
            self.PezUserObject_.DeliverPosition1 = newValue ;
        end
            
        function result = get.DeliverPosition2(self)
            result = self.PezUserObject_.DeliverPosition2 ;
        end
        
        function set.DeliverPosition2(self, newValue)
            self.PezUserObject_.DeliverPosition2 = newValue ;
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
        
end  % classdef

