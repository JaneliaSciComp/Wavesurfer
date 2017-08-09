classdef AIScalingTestCase < matlab.unittest.TestCase
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
            wsModel.setElectrodeProperty(electrodeIndex, 'VoltageMonitorScaling', 10) ;  
                % V/"mV", the stim will be 3.1415 V, so the acquired data should have an amplitude of 0.31415 "mV"
            wsModel.setElectrodeProperty(electrodeIndex, 'CurrentCommandScaling', 1) ;  
                % "pA"/V, the stimulus amplitude in V will be equal to the nominal amplitude in the stim

            voltageMonitorScaleInTrode = wsModel.getElectrodeProperty(electrodeIndex, 'VoltageMonitorScaling') ;
            monitorScaleInAcquisitionSubsystem = wsModel.AIChannelScales ;

            self.verifyEqual(voltageMonitorScaleInTrode, monitorScaleInAcquisitionSubsystem) ;

            amplitudeAsString = '3.1415' ;
            amplitudeAsDouble = str2double(amplitudeAsString) ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', 1, 'Amplitude', amplitudeAsString) ;
            %pulse = wsModel.Stimulation.StimulusLibrary.Stimuli{1} ;
            %pulse.Amplitude = '3.1415' ;

            wsModel.IsStimulationEnabled = true ;

            wsModel.play() ;

            x = wsModel.getAIDataFromCache() ;

            wsModel.delete() ;  % have to do this now
            
            measuredAmplitude = max(x) - min(x) ;

            predictedAmplitude = amplitudeAsDouble/voltageMonitorScaleInTrode ; 

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
