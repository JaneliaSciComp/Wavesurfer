classdef WavesurferModelTestCase < ws.test.StimulusLibraryTestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (Test)
        function testTooLargeStimulus(self)
            % Create an WavesurferModel
            model=ws.WavesurferModel(true);  % true => is the one true wavesurfer
            model.addStarterChannelsAndStimulusLibrary() ;

            % Add a few more channels
            model.addAIChannel() ;
            model.addAIChannel() ;
            
            % Enable stimulation subsystem
            model.Stimulation.IsEnabled=true;

            % Make a too-large pulse stimulus, add to the stimulus library
            model.setStimulusLibraryItemProperty('ws.Stimulus', 1, 'Amplitude', -20) ;

            % attempt to output
            model.play();
            
            % this is successful if no exceptions are thrown            
            self.verifyTrue(true);                        
        end  % function
        
        
        
        function testSavingAndLoadingStimulusLibraryWithinWavesurferModel(self)
            % Create an WavesurferModel
            wsModel = ws.WavesurferModel(true) ;  % true => is the one true wavesurfer

            % Add some more channels
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            
            % Make it so the stim library map durations are not overridden
            % by the WavesurferModel sweep duration, which would mess things up.
            %wsModel.Triggering.AcquisitionUsesASAPTriggering=false;
            wsModel.AreSweepsContinuous = true ;
            wsModel.StimulationUsesAcquisitionTrigger = false ;
            
            % Clear the stim lib within the WavesurferModel
            wsModel.clearStimulusLibrary();

            % Populate the Wavesurfer Stim library
%             stimulusLibrary=self.createPopulatedStimulusLibrary();
%             wsModel.Stimulation.StimulusLibrary = stimulusLibrary ;
%             clear stimulusLibrary ;
            %ws.test.StimulusLibraryTestCase.populateStimulusLibraryBang(wsModel.Stimulation.StimulusLibrary) ;  % class method call
            wsModel.populateStimulusLibraryForTesting() ;
            
            % Make a copy of it in the populated state
            stimulusLibraryCopy = wsModel.Stimulation.StimulusLibrary.copyGivenParent([]) ;
            
            % Save the protocol to disk
            protocolSettings = wsModel.encodeForPersistence() ;  %#ok<NASGU>
            fileName = [tempname() '.mat'] ;
            save(fileName, 'protocolSettings') ;

            % Clear the stim library in the model
            wsModel.clearStimulusLibrary() ;
            
            % Restore the protocol (including the stim library)
            s = load(fileName) ;
            protocolSettingsCheck = s.protocolSettings ;
            %wsModel.decodeProperties(protocolSettingsCheck);
            wsModel = ws.Coding.decodeEncodingContainer(protocolSettingsCheck) ;  % this should release the old wsModel object

            % compare the stim library in model to the copy of the
            % populated version
            self.verifyEqual(wsModel.Stimulation.StimulusLibrary,stimulusLibraryCopy) ;
        end  % function
        
        
        
        function testEncodingOfStimulusSource(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            wsModel = ws.WavesurferModel(true);  % true => is the one true wavesurfer
            %wsModel.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            
            % Make it so the stim library map durations are not overridden
            % by the WavesurferModel sweep duration, which would mess things up.
            wsModel.StimulationUsesAcquisitionTrigger = false ;
            
            % Clear the stim lib within the WavesurferModel
            wsModel.clearStimulusLibrary();

            % Populate the Wavesurfer Stim library
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            wsModel.Stimulation.StimulusLibrary.mimic(stimulusLibrary);
            clear stimulusLibrary

            % Enable the stimulation subsystem
            wsModel.Stimulation.IsEnabled = true ;
            
            % Set the Stimulation source
            %wsModel.Stimulation.StimulusLibrary.SelectedOutputable = wsModel.Stimulation.StimulusLibrary.Sequences{2} ;
            wsModel.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', 2) ;
            
            % Get the thing we'll save to disk
            protocolSettings = wsModel.encodeForPersistence() ;  %#ok<NASGU>

            % Check that the stimulusLibrary in protocolSettings is self-consistent
            self.verifyTrue(true);
        end  % function
        
        function testRestorationOfStimulusSource(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            wsModel=ws.WavesurferModel(true);  % true => is the one true wavesurfer
            %wsModel.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            
            % Make it so the stim library map durations are not overridden
            % by the WavesurferModel sweep duration, which would mess things up.
            wsModel.StimulationUsesAcquisitionTrigger = false ;
            
            % Clear the stim lib within the WavesurferModel
            wsModel.Stimulation.StimulusLibrary.clear();

            % Populate the Wavesurfer Stim library
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            wsModel.Stimulation.StimulusLibrary.mimic(stimulusLibrary);
            clear stimulusLibrary

            % Enable the stimulation subsystem
            wsModel.Stimulation.IsEnabled=true;
            
            % Set the Stimulation source
            %wsModel.Stimulation.StimulusLibrary.SelectedOutputable=wsModel.Stimulation.StimulusLibrary.Sequences{2};
            wsModel.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', 2) ;
            
            % Get the current stimulation source name
            selectedOutputableName=wsModel.stimulusLibrarySelectedOutputableProperty('Name') ;            
            
            % Save the protocol to disk
            %protocolSettings=wsModel.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings=wsModel.encodeForPersistence();  %#ok<NASGU>
            fileName=[tempname() '.mat'];
            save(fileName,'protocolSettings');

            % clear the WavesurferModel         
            clear wsModel;
            
            % Restore the protocol (including the stim library)
            s=load(fileName);
            protocolSettingsAsRead=s.protocolSettings;
            %wsModel2.decodeProperties(protocolSettingsCheck);
            wsModelAsDecoded = ws.Coding.decodeEncodingContainer(protocolSettingsAsRead) ;

            % Check the self-consistency of the stim library
            self.verifyTrue(wsModelAsDecoded.Stimulation.StimulusLibrary.isSelfConsistent());
            
            % Get the stimulation source name now
            selectedOutputableNameCheck=wsModelAsDecoded.stimulusLibrarySelectedOutputableProperty('Name') ;  
            
            % compare the stim library in model to the copy of the
            % populated version
            self.verifyEqual(selectedOutputableName,selectedOutputableNameCheck);
        end  % function
        
        function testWhetherDurationIsNotFreeAfterProtocolLoad(self)
            % Create an WavesurferModel
            wsModel = ws.WavesurferModel(true) ;  % true => is the one true wavesurfer

            % Add channels
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            
            % Clear the stim lib within the WavesurferModel
            wsModel.clearStimulusLibrary() ;

            % Populate the Wavesurfer Stim library
            wsModel.populateStimulusLibraryForTesting() ;
            %stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            %wsModel.Stimulation.StimulusLibrary.mimic(stimulusLibrary) ;
            %clear stimulusLibrary
           
            % All map durations should be not free
            %isDurationOverridden= ~[wsModel.Stimulation.StimulusLibrary.Maps.IsDurationFree];
            %isDurationOverridden= ~ws.cellArrayPropertyAsArray(wsModel.Stimulation.StimulusLibrary.Maps,'IsDurationFree') ;
            areDurationsOverridden = wsModel.areStimulusLibraryMapDurationsOverridden() ;
            self.verifyTrue(areDurationsOverridden, 'Not all map durations are overridden') ;
            
            % Save the protocol to disk
            %protocolSettings=wsModel.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings = wsModel.encodeForPersistence() ;  %#ok<NASGU>
            fileName = [tempname() '.mat'] ;
            save(fileName, 'protocolSettings') ;

            % Clear the stim library
            wsModel.clearStimulusLibrary();
            
            % Restore the protocol (including the stim library)
            s=load(fileName);
            protocolSettingsCheck=s.protocolSettings;
            %wsModel.decodeProperties(protocolSettingsCheck);
            wsModel = ws.Coding.decodeEncodingContainer(protocolSettingsCheck) ;

            % All map durations should be not free, again
            %isDurationOverridden= ~[wsModel.Stimulation.StimulusLibrary.Maps.IsDurationFree];
            %isDurationOverridden= ~ws.cellArrayPropertyAsArray(wsModel.Stimulation.StimulusLibrary.Maps,'IsDurationFree') ;
            areDurationsOverridden = wsModel.areStimulusLibraryMapDurationsOverridden() ;
            self.verifyTrue(areDurationsOverridden, 'Not all map durations are overridden');
            %keyboard
        end  % function      
        
        function testSavingAndLoadingSimpleProtocolFile(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            wsModel=ws.WavesurferModel(true);  % true => is the one true wavesurfer
            %wsModel.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            
            % A list of settings
            settings=cell(0,2);
            settings(end+1,:)={'AreSweepsFiniteDuration' true};            
            settings(end+1,:)={'NSweepsPerRun' 11};

            settings(end+1,:)={'Acquisition.SampleRate' 100e6/5001};
            settings(end+1,:)={'Acquisition.Duration' 2.17};
            
            settings(end+1,:)={'Stimulation.IsEnabled' true};
            settings(end+1,:)={'Stimulation.SampleRate' 100e6/4999};
            
            settings(end+1,:)={'Display.IsEnabled' true};
            %settings(end+1,:)={'Display.IsAutoRate' false};
            settings(end+1,:)={'Display.UpdateRate' 9};
            settings(end+1,:)={'Display.IsXSpanSlavedToAcquistionDuration' false};
            settings(end+1,:)={'Display.XSpan' 2.01};
            
            % Set the settings in the wavesurferModel
            nSettings=size(settings,1);
            for i=1:nSettings ,
                propertyName=settings{i,1};
                propertyValue=settings{i,2}; %#ok<NASGU>
                evalString=sprintf('wsModel.%s = propertyValue ;',propertyName);
                eval(evalString);
            end
            
            % Save the protocol to disk, very similar to how
            % WavesurferController does it
            %protocolSettings=wsModel.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings=wsModel.encodeForPersistence();  %#ok<NASGU>
            fileName=[tempname() '.mat'];
            save(fileName,'protocolSettings');
            
            % Delete the WavesurferModel
            clear wsModel
            %clear protocolSettings  % that we have to do this indicates problems elsewhere...
            
            %keyboard
            
            % Create a fresh WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            wsModelCheck=ws.WavesurferModel(true);  % true => is the one true wavesurfer
            %wsModelCheck.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            wsModelCheck.addAIChannel() ;
            wsModelCheck.addAIChannel() ;
            wsModelCheck.addAIChannel() ;
            wsModelCheck.addAOChannel() ;
            
            % Load the settings, very like WavesurferController does
            s=load(fileName);
            protocolSettingsCheck=s.protocolSettings;
            %wsModelCheck.releaseHardwareResources();
            %wsModelCheck.decodeProperties(protocolSettingsCheck);
            wsModelCheck = ws.Coding.decodeEncodingContainer(protocolSettingsCheck) ; %#ok<NASGU>

            % Check that all settings are as set
            for i=1:nSettings ,
                propertyName=settings{i,1};
                propertyValue=settings{i,2};
                %propertyValueCheck=emCheck.(propertyName);
                evalString=sprintf('propertyValueCheck = wsModelCheck.%s ;',propertyName);
                eval(evalString);
%                 if ~isequal(propertyValue,propertyValueCheck) ,
%                     keyboard
%                 end
                self.verifyEqual(propertyValue,propertyValueCheck,sprintf('Problem with: %s',propertyName));
            end            
        end  % function        
        
        function testSavingAndLoadingElectrodeProperties(self)
            % Create an WavesurferModel
            %thisDirName=fileparts(mfilename('fullpath'));
            wsModel=ws.WavesurferModel(true);  % true => is the one true wavesurfer
            %wsModel.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            
            wsModel.Ephys.ElectrodeManager.addNewElectrode();
            
            % A list of settings
            settings=cell(0,2);
            settings(end+1,:)={'Name' 'Hector'};            
            settings(end+1,:)={'VoltageMonitorChannelName' 'foo'};
            settings(end+1,:)={'CurrentMonitorChannelName' 'bar'};
            settings(end+1,:)={'VoltageCommandChannelName' 'oof'};
            settings(end+1,:)={'CurrentCommandChannelName' 'rab'};
            settings(end+1,:)={'Mode' 'cc'};
            settings(end+1,:)={'TestPulseAmplitudeInVC' 3};
            settings(end+1,:)={'TestPulseAmplitudeInCC' 7};
            settings(end+1,:)={'VoltageMonitorScaling' 2};
            settings(end+1,:)={'CurrentMonitorScaling' 5};
            settings(end+1,:)={'VoltageCommandScaling' 8};
            settings(end+1,:)={'CurrentCommandScaling' 9};
%             settings(end+1,:)={'VoltageUnits' ws.SIUnit('uV')};
%             settings(end+1,:)={'CurrentUnits' ws.SIUnit('kA')};
            
            % Set the settings
            electrode=wsModel.Ephys.ElectrodeManager.Electrodes{1}; %#ok<NASGU>
            nSettings=size(settings,1);
            for i=1:nSettings ,
                propertyName=settings{i,1};
                propertyValue=settings{i,2}; %#ok<NASGU>
                evalString=sprintf('electrode.%s = propertyValue ;',propertyName);
                eval(evalString);
            end
            clear electrode  % don't want ref hanging around
            
            % Save the protocol to disk, very similar to how
            % WavesurferController does it
            %protocolSettings=wsModel.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings=wsModel.encodeForPersistence();  %#ok<NASGU>
            fileName=[tempname() '.mat'];
            save(fileName,'protocolSettings');
            
            % Delete the WavesurferModel
            clear wsModel
            %clear protocolSettings  % that we have to do this indicates problems elsewhere...            

%             % Shouldn't have to do this, but...
%             daqSystem = ws.dabs.ni.daqmx.System();
%             ws.deleteIfValidHandle(daqSystem.tasks);

%             % Create a fresh WavesurferModel
%             thisDirName=fileparts(mfilename('fullpath'));
%             emCheck=ws.WavesurferModel();
%             emCheck.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            
            % Load the settings, very like WavesurferController does
            s=load(fileName);
            protocolSettingsCheck=s.protocolSettings;
            %emCheck.decodeProperties(protocolSettingsCheck);
            emCheck = ws.Coding.decodeEncodingContainer(protocolSettingsCheck) ;
            
            % Check that all settings are as set
            electrode=emCheck.Ephys.ElectrodeManager.Electrodes{1};             %#ok<NASGU>
            for i=1:nSettings ,
                propertyName=settings{i,1};
                propertyValue=settings{i,2};
                %propertyValueCheck=emCheck.(propertyName);
                evalString=sprintf('propertyValueCheck = electrode.%s ;',propertyName);
                eval(evalString);
                if ~isequal(propertyValue,propertyValueCheck) ,
                    keyboard
                end
                self.verifyEqual(propertyValue,propertyValueCheck);
            end            
        end  % function
    end  % test methods    
end  % classdef
