classdef February4TestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.utility.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.utility.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (Test)
        function theTest(self)
            wsModel = wavesurfer([],true) ;
            wsModel.Acquisition.addAnalogChannel() ;  % need at least one input channel to do a run
            wsModel.Stimulation.IsEnabled = true ;
            wsModel.Stimulation.addDigitalChannel() ;
            wsModel.Stimulation.addDigitalChannel() ;
            wsModel.Stimulation.IsDigitalChannelTimed(2) = false ;
            wsModel.play() ;
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,1);            
        end  % function

    end  % test methods

 end  % classdef
