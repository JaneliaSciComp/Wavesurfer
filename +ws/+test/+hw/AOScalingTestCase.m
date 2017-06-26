classdef AOScalingTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1, with
    % AO0 looped back to AI0.
    
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

            electrodeIndex = wsModel.addNewElectrode() ;
            wsModel.setElectrodeProperty(electrodeIndex, 'Mode', 'cc') ;
            wsModel.setElectrodeProperty(electrodeIndex, 'VoltageMonitorChannelName', 'AI0') ;
            wsModel.setElectrodeProperty(electrodeIndex, 'CurrentCommandChannelName', 'AO0') ;
            wsModel.setElectrodeProperty(electrodeIndex, 'VoltageMonitorScaling', 1) ;  
            wsModel.setElectrodeProperty(electrodeIndex, 'CurrentCommandScaling', 10) ;  
            
            currentCommandScaleInTrode = wsModel.getElectrodeProperty(electrodeIndex, 'CurrentCommandScaling') ;
            commandScaleInStimulationSubsystem = wsModel.AOChannelScales ;

            self.verifyEqual(currentCommandScaleInTrode, commandScaleInStimulationSubsystem) ;

            amplitudeAsString = '3.1415' ;
            amplitudeAsDouble = str2double(amplitudeAsString) ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', 1, 'Amplitude', amplitudeAsString) ;

            wsModel.IsStimulationEnabled = true ;

            wsModel.play() ;

            x = wsModel.getAIDataFromCache() ;

            wsModel.delete() ;
            
            measuredAmplitude = max(x) - min(x) ;

            predictedAmplitude = amplitudeAsDouble/currentCommandScaleInTrode ;

            measuredAmplitudeIsCorrect = (log(measuredAmplitude/predictedAmplitude)<0.05) ;

            if measuredAmplitudeIsCorrect ,
                fprintf('Measured amplitude is correct.\n') ;
            else
                fprintf('Measured amplitude is wrong!  It''s %g, should be %g.\n', measuredAmplitude, predictedAmplitude) ;
            end
            
            self.verifyTrue(measuredAmplitudeIsCorrect) ;
            
        end  % function
        
    end  % test methods

 end  % classdef
