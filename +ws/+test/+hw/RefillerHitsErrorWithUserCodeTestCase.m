classdef RefillerHitsErrorWithUserCodeTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_8_AIs.m.
    
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
            isCommandLineOnly=true ;
            thisDirName=fileparts(mfilename('fullpath'));
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Demo_with_6_AIs_2_DIs_4_AOs_2_DOs.m'), ...
                               isCommandLineOnly);

            %wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.IsEnabled = true ;
            %wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.IsEnabled = true ;
            %wsModel.Logging.IsEnabled=false;

            wsModel.AreSweepsContinuous = true ;

            aTimer = timer('ExecutionMode', 'singleShot', ...
                           'StartDelay', 10, ...
                           'TimerFcn', @(event,arg2)(wsModel.stop()) ) ;
            
            start(aTimer) ;
            wsModel.play() ;  % this throws at present, because the refiller hits an error andd never responds
            stop(aTimer) ;
            delete(aTimer) ;

            wsModel = [] ;  %#ok<NASGU>    % release the WavesurferModel
            
            self.verifyTrue(true) ;            
        end  % function
    end  % test methods

end  % classdef
