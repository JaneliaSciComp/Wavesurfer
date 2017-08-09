classdef February4TestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.
    
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
            wsModel = wavesurfer('--nogui') ;
            wsModel.addAIChannel() ;  % need at least one input channel to do a run
            wsModel.IsStimulationEnabled = true ;
            wsModel.addDOChannel() ;
            wsModel.addDOChannel() ;
            wsModel.IsDOChannelTimed(2) = false ;
            wsModel.play() ;
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,1);            
        end  % function

    end  % test methods

 end  % classdef
