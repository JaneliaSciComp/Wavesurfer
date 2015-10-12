classdef CantSetTestPulseAmplitudeTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_WS_Test_with_DO.m.
    
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
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Demo_with_4_AIs_2_DIs_2_AOs_2_DOs.m'), ...
                               isCommandLineOnly);

            %
            % Now check that we can still test pulse
            %
            
            % Set up a single electrode
            wsModel.Ephys.ElectrodeManager.addNewElectrode();
                        
            % Try to set the TP amplitude
            currentAmplitude = wsModel.Ephys.TestPulser.Amplitude ;
            if currentAmplitude==1 ,
                targetAmplitude=10 ;
            else
                targetAmplitude=1 ;
            end
            wsModel.Ephys.TestPulser.Amplitude = targetAmplitude ;
            amplitudeAfterSetting = wsModel.Ephys.TestPulser.Amplitude ;
            
            self.verifyEqual(amplitudeAfterSetting,targetAmplitude) ;                
        end  % function

        
        
    end  % test methods

 end  % classdef
