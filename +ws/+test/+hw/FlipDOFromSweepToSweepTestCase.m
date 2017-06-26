classdef FlipDOFromSweepToSweepTestCase < matlab.unittest.TestCase    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.reset() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.reset() ;
        end
    end

    methods (Test)
        function theTest(self)
            wsModel=wavesurfer('--nogui');

            % Want to do multiple sweeps
            wsModel.NSweepsPerRun = 4 ;
            
            % Turn on stimulation 
            wsModel.IsStimulationEnabled = true ;

            % Turn on display, just to test more stuff
            wsModel.IsDisplayEnabled = true ;            
            
            % Add an untimed DO channel
            wsModel.addDOChannel() ;
            wsModel.IsDOChannelTimed = false ;
            
            % Set the user class
            wsModel.UserClassName = 'ws.examples.FlipDOFromSweepToSweep' ;

            % Play, logging warnings
            wsModel.startLoggingWarnings() ;
            wsModel.play() ;  % blocks
            exceptionMaybe = wsModel.stopLoggingWarnings() ;
            
            % If there were warnings, print them now
            if ~isempty(exceptionMaybe) ,
                exception = exceptionMaybe{1} ;
                fprintf('Warning report:\n') ;
                display(exception.getReport()) ;
                causes = exception.cause ;  % a cell array
                if ~isempty(causes) ,
                    firstCause = causes{1} ;
                    fprintf('First cause report:\n') ;
                    display(firstCause.getReport()) ;
                end
            end
            
            % Release the WavesurferModel, even though it's a little stilly
            wsModel.delete() ;
            wsModel = [] ;  %#ok<NASGU>    
            
            self.verifyEmpty(exceptionMaybe, 'wsModel.play() threw one or more warnings') ;
        end  % function
    end  % test methods

end  % classdef
