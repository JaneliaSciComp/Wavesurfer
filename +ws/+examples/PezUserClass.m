classdef PezUserClass < ws.UserClass
    properties (Constant)
        TrialSequenceModeOptions = {'all-1' 'all-2' 'alternating' 'random'} ;
    end

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
    end  % properties
    
    properties (Access=protected)
        TrialSequenceMode_ = 'alternating'  % can be 'all-1', 'all-2', 'alternating', or 'random'
        
        BasePosition1X_ = -74  % mm?
        BasePosition1Y_ =  50  % mm?
        BasePosition1Z_ =  64  % mm?
        ToneFrequency1_ = 3000  % Hz
        DeliverPosition1X_ = -73  % mm?
        DeliverPosition1Y_ =  51  % mm?
        DeliverPosition1Z_ =  64  % mm?
        DispenseChannelPosition1_ = -21  % scalar, mm?, the vertical delta from the deliver position to the dispense position

        BasePosition2X_ = -74  % mm?
        BasePosition2Y_ =  50  % mm?
        BasePosition2Z_ =  64  % mm?
        ToneFrequency2_ = 10000  % Hz
        DeliverPosition2X_ = -73  % mm?
        DeliverPosition2Y_ =  60  % mm?
        DeliverPosition2Z_ =  64  % mm?
        DispenseChannelPosition2_ = -30  % scalar, mm?
        
        ToneDuration_ = 1  % s
        ToneDelay_ = 1  % s, the delay between the move to the deliver position and the start of the tone
        DispenseDelay_ = 1  % s, the delay from the end of the tone to the move to the dispense position
        ReturnDelay_ = 0.12  % s, the delay until the post returns to the home position
    end  % properties

    properties (Access=protected, Transient=true)
        PezDispenser_
        TrialSequence_
        Controller_
    end
    
    methods
        function self = PezUserClass()
            % Creates the "user object"
            fprintf('Instantiating an instance of PezUserClass.\n');
        end
        
        function wake(self, rootModel)
            fprintf('Waking an instance of PezUserClass.\n');
            if isa(rootModel, 'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel ,
                self.Controller_ = ws.examples.PezController(self) ;
                   % Don't need to keep a ref, b/c this creates a figure, the callbacks of which
                   % hold references to the controller
            end
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('An instance of PezUserClass is being deleted.\n');
            if ~isempty(self.Controller_) && isvalid(self.Controller_) ,
                delete(self.Controller_) ;
            end
        end
        
        % These methods are called in the frontend process
        function startingRun(self, wsModel)
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            fprintf('About to start a run in PezUserClass.\n');
            sweepCount = wsModel.NSweepsPerRun ;
            if isequal(self.TrialSequenceMode, 'all-1') 
                self.TrialSequence_ = repmat(1, [1 sweepCount]) ;  %#ok<REPMAT>
            elseif isequal(self.TrialSequenceMode, 'all-2') 
                self.TrialSequence_ = repmat(2, [1 sweepCount]) ;
            elseif isequal(self.TrialSequenceMode, 'alternating')
                self.TrialSequence_ = repmat([1 2], [1 ceil(sweepCount/2)]) ;                
            elseif isequal(self.TrialSequenceMode, 'random') 
                self.TrialSequence_ = randi(2, [1 sweepCount]) ;
            else
                error('Unrecognized TrialSequenceMode: %s', self.TrialSequenceMode) ;
            end
            self.PezDispenser_ = ModularClient('COM3') ;
            self.PezDispenser_.open() ;
        end
        
        function completingRun(self,wsModel)  %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
            fprintf('Completed a run in PezUserClass.\n');
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
        end
        
        function stoppingRun(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('User stopped a run in PezUserClass.');
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
        end        
        
        function abortingRun(self,wsModel)  %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
            fprintf('Oh noes!  A run aborted in PezUserClass.\n');
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
        end
        
        function startingSweep(self,wsModel)
            % Called just before each sweep
            fprintf('About to start a sweep in PezUserClass.\n');
            sweepIndex = wsModel.NSweepsCompletedInThisRun + 1 ;
            trialType = self.TrialSequence_(sweepIndex) ;
            %pauseDuration = 0.000 ; % s
            if trialType == 1 ,
                self.PezDispenser_.basePosition('setValue', [self.BasePosition1X self.BasePosition1Y self.BasePosition1Z]) ;
                %pause(pauseDuration) ;
                self.PezDispenser_.toneFrequency('setValue', self.ToneFrequency1) ;
                %pause(pauseDuration) ;
                self.PezDispenser_.deliverPosition('setValue', [self.DeliverPosition1X self.DeliverPosition1Y self.DeliverPosition1Z]) ;
                %pause(pauseDuration) ;
                self.PezDispenser_.dispenseChannelPosition('setValue', self.DispenseChannelPosition1) ;
                %pause(pauseDuration) ;
            else
                self.PezDispenser_.basePosition('setValue', [self.BasePosition2X self.BasePosition2Y self.BasePosition2Z]) ;
                %pause(pauseDuration) ;
                self.PezDispenser_.toneFrequency('setValue', self.ToneFrequency2) ;
                %pause(pauseDuration) ;
                self.PezDispenser_.deliverPosition('setValue', [self.DeliverPosition2X self.DeliverPosition2Y self.DeliverPosition2Z]) ;
                %pause(pauseDuration) ;
                self.PezDispenser_.dispenseChannelPosition('setValue', self.DispenseChannelPosition2) ;
                %pause(pauseDuration) ;
            end
            self.PezDispenser_.toneDuration('setValue', self.ToneDuration) ;            
            %pause(pauseDuration) ;
            self.PezDispenser_.toneDelayMin('setValue', self.ToneDelay) ;            
            %pause(pauseDuration) ;
            self.PezDispenser_.toneDelayMax('setValue', self.ToneDelay) ;            
            %pause(pauseDuration) ;
            self.PezDispenser_.dispenseDelay('setValue', self.DispenseDelay) ;            
            %pause(pauseDuration) ;
            %returnDelay = self.ReturnDelay
            self.PezDispenser_.returnDelayMin('setValue', self.ReturnDelay) ;            
            %pause(pauseDuration) ;
            self.PezDispenser_.returnDelayMax('setValue', self.ReturnDelay) ;            
            %pause(pauseDuration) ;
        end
        
        function completingSweep(self,wsModel)  %#ok<INUSD>
            % Called after each sweep completes
            fprintf('Completed a sweep in PezUserClass.\n');
        end
        
        function stoppingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('User stopped a sweep in PezUserClass.\n');
        end        
        
        function abortingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('Oh noes!  A sweep aborted in PezUserClass.\n');
        end        
        
        function dataAvailable(self, wsModel)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % has been accumulated from the looper.
            %analogData = wsModel.getLatestAIData();
            %digitalData = wsModel.getLatestDIData();  %#ok<NASGU>
            %nScans = size(analogData,1);
            %fprintf('Just read %d scans of data in PezUserClass.\n', nScans);                                    
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self, looper, analogData, digitalData)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            %nScans = size(analogData,1);
            %fprintf('Just acquired %d scans of data in PezUserClass.\n', nScans);                                    
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller)  %#ok<INUSD>
            % Called just before each episode
            fprintf('About to start an episode in PezUserClass.\n');
        end
        
        function completingEpisode(self,refiller)  %#ok<INUSD>
            % Called after each episode completes
            fprintf('Completed an episode in PezUserClass.\n');
        end
        
        function stoppingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('User stopped an episode in PezUserClass.\n');
        end        
        
        function abortingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('Oh noes!  An episode aborted in PezUserClass.\n');
        end
    end  % public methods
        
    methods
        function result = get.TrialSequence(self)
            result = self.TrialSequence_ ;
        end
        
        function result = get.TrialSequenceMode(self)
            result = self.TrialSequenceMode_ ;
        end
        
        function result = get.BasePosition1X(self)
            result = self.BasePosition1X_ ;
        end
        
        function result = get.BasePosition1Y(self)
            result = self.BasePosition1Y_ ;
        end
        
        function result = get.BasePosition1Z(self)
            result = self.BasePosition1Z_ ;
        end
        
        function result = get.ToneFrequency1(self)
            result = self.ToneFrequency1_ ;
        end
        
        function result = get.DeliverPosition1X(self)
            result = self.DeliverPosition1X_ ;
        end
        
        function result = get.DeliverPosition1Y(self)
            result = self.DeliverPosition1Y_ ;
        end
        
        function result = get.DeliverPosition1Z(self)
            result = self.DeliverPosition1Z_ ;
        end
        
        function result = get.DispenseChannelPosition1(self)
            result = self.DispenseChannelPosition1_ ;
        end
        
        function result = get.BasePosition2X(self)
            result = self.BasePosition2X_ ;
        end
        
        function result = get.BasePosition2Y(self)
            result = self.BasePosition2Y_ ;
        end
        
        function result = get.BasePosition2Z(self)
            result = self.BasePosition2Z_ ;
        end
        
        function result = get.ToneFrequency2(self)
            result = self.ToneFrequency2_ ;
        end
        
        function result = get.DeliverPosition2X(self)
            result = self.DeliverPosition2X_ ;
        end
        
        function result = get.DeliverPosition2Y(self)
            result = self.DeliverPosition2Y_ ;
        end
        
        function result = get.DeliverPosition2Z(self)
            result = self.DeliverPosition2Z_ ;
        end
        
        function result = get.DispenseChannelPosition2(self)
            result = self.DispenseChannelPosition2_ ;
        end
        
        function result = get.ToneDuration(self)
            result = self.ToneDuration_ ;
        end
        
        function result = get.ToneDelay(self)
            result = self.ToneDelay_ ;
        end
        
        function result = get.DispenseDelay(self)
            result = self.DispenseDelay_ ;
        end
        
        function result = get.ReturnDelay(self)
            result = self.ReturnDelay_ ;
        end
        
        function set.TrialSequenceMode(self, newValue) 
            if ~any(strcmp(newValue, self.TrialSequenceModeOptions))
                error('ws:invalidPropertyValue', 'TrialSequenceMode must be one of ''all-1'', ''all-2'', ''alternating'', or ''random''') ;
            end
            self.TrialSequenceMode_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end        
                
        function set.BasePosition1X(self, newValue)
            self.checkValue_('BasePosition1X', newValue) ;
            self.BasePosition1X_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.BasePosition1Y(self, newValue)
            self.checkValue_('BasePosition1Y', newValue) ;
            self.BasePosition1Y_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.BasePosition1Z(self, newValue)
            self.checkValue_('BasePosition1Z', newValue) ;
            self.BasePosition1Z_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneFrequency1(self, newValue)
            self.checkValue_('ToneFrequency1', newValue) ;
            self.ToneFrequency1_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1X(self, newValue)
            self.checkValue_('DeliverPosition1X', newValue) ;
            self.DeliverPosition1X_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1Y(self, newValue)
            self.checkValue_('DeliverPosition1Y', newValue) ;
            self.DeliverPosition1Y_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1Z(self, newValue)
            self.checkValue_('DeliverPosition1Z', newValue) ;
            self.DeliverPosition1Z_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseChannelPosition1(self, newValue)
            self.checkValue_('DispenseChannelPosition1', newValue) ;
            self.DispenseChannelPosition1_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.BasePosition2X(self, newValue)
            self.checkValue_('BasePosition2X', newValue) ;
            self.BasePosition2X_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.BasePosition2Y(self, newValue)
            self.checkValue_('BasePosition2Y', newValue) ;
            self.BasePosition2Y_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.BasePosition2Z(self, newValue)
            self.checkValue_('BasePosition2Z', newValue) ;
            self.BasePosition2Z_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneFrequency2(self, newValue)
            self.checkValue_('ToneFrequency2', newValue) ;
            self.ToneFrequency2_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2X(self, newValue)
            self.checkValue_('DeliverPosition2X', newValue) ;
            self.DeliverPosition2X_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2Y(self, newValue)
            self.checkValue_('DeliverPosition2Y', newValue) ;
            self.DeliverPosition2Y_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2Z(self, newValue)
            self.checkValue_('DeliverPosition2Z', newValue) ;
            self.DeliverPosition2Z_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseChannelPosition2(self, newValue)
            self.checkValue_('DispenseChannelPosition2', newValue) ;
            self.DispenseChannelPosition2_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneDuration(self, newValue)
            self.checkValue_('ToneDuration', newValue) ;
            self.ToneDuration_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneDelay(self, newValue)
            self.checkValue_('ToneDelay', newValue) ;
            self.ToneDelay_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseDelay(self, newValue)
            self.checkValue_('DispenseDelay', newValue) ;
            self.DispenseDelay_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ReturnDelay(self, newValue)
            self.checkValue_('ReturnDelay', newValue) ;
            self.ReturnDelay_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
    end  % public methods
    
    methods (Access=protected)
        function tellControllerToUpdateIfPresent_(self)
            if ~isempty(self.Controller_) ,
                self.Controller_.update() ;
            end
        end
        
        function checkValue_(self, propertyName, newValue)  %#ok<INUSL>
            if isequal(propertyName, 'ReturnDelay') ,
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0.1<newValue ) ,
                    error('ws:invalidPropertyValue', 'ReturnDelay property value is invalid') ;
                end                                    
            elseif ~isempty(strfind(propertyName, 'Position')) ,
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && (-100<=newValue) && (newValue<=+100) ) ,
                    error('ws:invalidPropertyValue', 'Position property value is invalid') ;
                end
            elseif ~isempty(strfind(propertyName, 'Duration')) ,
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0<=newValue ) ,
                    error('ws:invalidPropertyValue', 'Duration property value is invalid') ;
                end                    
            elseif ~isempty(strfind(propertyName, 'Delay')) ,
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0<=newValue ) ,
                    error('ws:invalidPropertyValue', 'Delay property value is invalid') ;
                end                    
            elseif ~isempty(strfind(propertyName, 'Frequency')) ,
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0<newValue ) ,
                    error('ws:invalidPropertyValue', 'Frequency property value is invalid') ;
                end                    
            else
                error('Unrecognized property name') ;
            end
        end
    end  % protected methods block
    
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

