classdef PezUserClass < ws.UserClass
    properties
        TrialSequenceMode = 'all 1'  % can also be 'all-1', 'all-2', 'alternating'
        
        BasePosition1  % 3x1, mm
        ToneFrequency1  % Hz
        DeliverPosition1  % 3x1, mm

        BasePosition2  % 3x1, mm
        ToneFrequency2  % Hz
        DeliverPosition2  % 3x1, mm
        
        ToneDuration  % s
        ToneDelay  % s, the delay between the end of the tone and the movement to the deliver position
        ReturnDelay  % s, the delay until the post returns to the home position
    end  % properties

    properties (SetAccess=private)
        TrialSequence  % 1 x sweepCount, each element 1 or 2
    end

    properties (Access=protected, Transient=true)
        PezDispenser_
    end
    
    methods
        function self = PezUserClass()
            % Creates the "user object"
            fprintf('Instantiating an instance of PezUserClass.\n');
        end
        
        function wake(self, rootModel)  %#ok<INUSL>
            fprintf('Waking an instance of PezUserClass.\n');
            if isa(rootModel, 'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel ,
            end
        end
         
        function delete(self)  %#ok<INUSD>
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('An instance of PezUserClass is being deleted.\n');
        end
        
        % These methods are called in the frontend process
        function startingRun(self, wsModel)
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            fprintf('About to start a run in PezUserClass.\n');
            sweepCount = wsModel.NSweepsPerRun ;
            if isequal(self.TrialSequenceMode, 'all-1') 
                self.TrialSequence = repmat(1, [1 sweepCount]) ;  %#ok<REPMAT>
            elseif isequal(self.TrialSequenceMode, 'all-2') 
                self.TrialSequence = repmat(2, [1 sweepCount]) ;
            elseif isequal(self.TrialSequenceMode, 'alternating')
                self.TrialSequence = repmat([1 2], [1 ceil(sweepCount/2)]) ;                
            elseif isequal(self.TrialSequenceMode, 'random') 
                self.TrialSequence = randi(2, [1 sweepCount]) ;
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
            trialType = self.TrialSequence(sweepIndex) ;
            if trialType == 1 ,
                self.PezDispenser_.basePosition('setValue', self.BasePosition1) ;
                self.PezDispenser_.toneFrequency('setValue', self.ToneFrequency1) ;
                self.PezDispenser_.deliverPosition('setValue', self.DeliverPosition1) ;
            else
                self.PezDispenser_.basePosition('setValue', self.BasePosition2) ;
                self.PezDispenser_.toneFrequency('setValue', self.ToneFrequency2) ;
                self.PezDispenser_.deliverPosition('setValue', self.DeliverPosition2) ;
            end
            self.PezDispenser_.toneDuration('setValue', self.ToneDuration) ;            
            self.PezDispenser_.toneDelayMin('setValue', self.ToneDelay) ;            
            self.PezDispenser_.toneDelayMax('setValue', self.ToneDelay) ;            
            self.PezDispenser_.returnDelayMin('setValue', self.ReturnDelay) ;            
            self.PezDispenser_.returnDelayMax('setValue', self.ReturnDelay) ;            
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
    end  % methods
    
end  % classdef

