classdef SwitchToTestPulserTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on the current path, 
    % and be named Machine_Data_File_WS_Test_with_DO.m.
    
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

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;                                 
                           
            wsModel.AcquisitionSampleRate=20000;  % Hz
            wsModel.IsStimulationEnabled=true;
            wsModel.StimulationSampleRate=20000;  % Hz
            wsModel.IsDisplayEnabled=true;
            %wsModel.IsLoggingEnabled=true;

            nSweeps=1;
            wsModel.NSweepsPerRun=nSweeps;

            % Make a pulse stimulus, add to the stimulus library
            pulseTrainIndex = wsModel.addNewStimulus() ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'TypeString', 'SquarePulseTrain') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Name', 'Pulse Train') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Amplitude', '4.4') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Delay', '0.1') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'PulseDuration', '0.8') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Period', '1') ;            
            
            % Make a map that puts the just-made pulse out of the first AO channel and the first DO channel, add
            % to stim library
            mapIndex = wsModel.addNewStimulusMap() ;
            wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name', 'Pulse train out first AO, DO') ;
            firstAOChannelName = wsModel.AOChannelNames{1} ;
            firstDOChannelName = wsModel.DOChannelNames{1} ;
            bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', firstAOChannelName) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', pulseTrainIndex) ;
            binding2Index = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, binding2Index, 'ChannelName', firstDOChannelName) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, binding2Index, 'IndexOfEachStimulusInLibrary', pulseTrainIndex) ;
            
            % Make the new map the current sequence/map
            wsModel.setSelectedOutputableByClassNameAndIndex('ws.StimulusMap', mapIndex) ;
            
            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.DataFileBaseName=dataFileBaseName;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.DataFileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            pause(1);
            wsModel.record();

%             dtBetweenChecks=1;  % s
%             maxTimeToWait=2.5*nSweeps;  % s
%             nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
%             for i=1:nTimesToCheck ,
%                 pause(dtBetweenChecks);
%                 if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
%                     break
%                 end
%             end                   

            % Delete the data file
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
            
            %
            % Now check that we can still test pulse
            %
            
            % Set up a single electrode
            electrodeIndex = wsModel.addNewElectrode() ;

            %electrode = wsModel.Ephys.ElectrodeManager.Electrodes{electrodeIndex};
            %electrode.VoltageMonitorChannelName = 'V1' ;
            %electrode.CurrentCommandChannelName = 'Cmd1' ;
            %electrode.Mode = 'cc' ;            
            wsModel.setElectrodeProperty(electrodeIndex, 'Mode', 'cc') ;
            wsModel.setElectrodeProperty(electrodeIndex, 'MonitorChannelName', 'V1') ;
            wsModel.setElectrodeProperty(electrodeIndex, 'CommandChannelName', 'Cmd1') ;
            
            % Start test pulsing
            wsModel.startTestPulsing();
            
            % Wait a bit then stop
            pause(3);
            wsModel.stopTestPulsing();
            
            % If that doesn't throw, we count that as success
            self.verifyTrue(true);            
        end  % function

        
        
    end  % test methods

 end  % classdef
