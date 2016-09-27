classdef AIScalingTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1, with
    % AO0 looped back to AI0.
    
    methods (Test)
        function theTest(self)
            wsModel = wavesurfer('--nogui') ;

            wsModel.Ephys.ElectrodeManager.addNewElectrode() ;
            electrode = wsModel.Ephys.ElectrodeManager.Electrodes{1} ;
            electrode.Mode = 'cc' ;
            electrode.VoltageMonitorChannelName = 'AI0' ;
            electrode.CurrentCommandChannelName = 'AO0' ;
            electrode.VoltageMonitorScaling = 10 ;  % V/"mV", the stim will be 3.1415 V, so the acquired data should have an amplitude of 0.31415 "mV"
            electrode.CurrentCommandScaling = 1 ;  % "pA"/V, the stimulus amplitude in V will be equal to the nominal amplitude in the stim

            voltageMonitorScaleInTrode = electrode.VoltageMonitorScaling ;
            monitorScaleInAcquisitionSubsystem = wsModel.Acquisition.AnalogChannelScales ;

            self.verifyEqual(voltageMonitorScaleInTrode, monitorScaleInAcquisitionSubsystem) ;

            amplitudeAsString = '3.1415' ;
            amplitudeAsDouble = str2double(amplitudeAsString) ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', 1, 'Amplitude', amplitudeAsString) ;
            %pulse = wsModel.Stimulation.StimulusLibrary.Stimuli{1} ;
            %pulse.Amplitude = '3.1415' ;

            wsModel.Stimulation.IsEnabled = true ;

            wsModel.play() ;

            x = wsModel.Acquisition.getAnalogDataFromCache() ;

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
