classdef WavesurferModelTestCase < ws.test.StimulusLibraryTestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)  Also, the MDF must be on
    % the path, and be named Machine_Data_File_WS_Test.m.
    
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
        function testTooLargeStimulus(self)
            % Create an WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            model=ws.WavesurferModel();
            model.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            % Enable stimulation subsystem
            model.Stimulation.Enabled=true;

            % Make a too-large pulse stimulus, add to the stimulus library
            pulse=model.Stimulation.StimulusLibrary.addNewStimulus('SquarePulseTrain');
            pulse.Name='Pulse';
            pulse.Amplitude= -20;  % V, too big
            pulse.Delay=0.25;
            pulse.Delegate.PulseDuration='0.5';
            pulse.Delegate.Period='1';

            % make a map that puts the just-made pulse out of the first AO channel, add
            % to stim library
            map=model.Stimulation.StimulusLibrary.addNewMap();
            map.Name='Pulse out first channel';
            firstAoChannelName=model.Stimulation.AnalogChannelNames{1};
            map.addBinding(firstAoChannelName,pulse);

            % make the new map the current sequence/map
            model.Stimulation.StimulusLibrary.SelectedOutputable=map;

            % attempt to output
            model.start();
            
            % wait for task to finish
            pause(3);
            
            % this is successful if no exceptions are thrown            
            self.verifyTrue(true);                        
        end  % function
        
        function testSavingAndLoadingStimulusLibraryWithinWavesurferModel(self)
            % Create an WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            em=ws.WavesurferModel();
            em.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            % Make it so the stim library map durations are not overridden
            % by the WavesurferModel trial duration, which would mess things up.
            em.Triggering.AcquisitionUsesASAPTriggering=false;
            em.Triggering.StimulationUsesAcquisitionTriggerScheme=false;
            
            % Clear the stim lib within the WavesurferModel
            em.Stimulation.StimulusLibrary.clear();

            % Populate the Wavesurfer Stim library
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            %[stimuli,maps,cycles]=self.makeExampleStimulusParts();            
            %em.Stimulation.StimulusLibrary.add(stimuli);
            %em.Stimulation.StimulusLibrary.add(maps);
            %em.Stimulation.StimulusLibrary.add(cycles);
            %clear stimuli maps sequences;  % don't want these references to em internals hanging around            
            em.Stimulation.StimulusLibrary.mimic(stimulusLibrary);
            clear stimulusLibrary;
            
            % Make a copy of it in the populated state
            stimulusLibraryCopy=em.Stimulation.StimulusLibrary.clone();
            
            % Save the protocol to disk
            %protocolSettings=em.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings=em.encodeForFileType('cfg');  %#ok<NASGU>
            fileName=[tempname() '.mat'];
            save(fileName,'protocolSettings');

            % Clear the stim library in the model
            em.Stimulation.StimulusLibrary.clear();
            
            % Restore the protocol (including the stim library)
            s=load(fileName);
            protocolSettingsCheck=s.protocolSettings;
            em.decodeProperties(protocolSettingsCheck);

            % compare the stim library in model to the copy of the
            % populated version
            self.verifyEqual(em.Stimulation.StimulusLibrary,stimulusLibraryCopy);
        end  % function
        
        function testEncodingOfStimulusSource(self)
            % Create an WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            em=ws.WavesurferModel();
            em.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            % Make it so the stim library map durations are not overridden
            % by the WavesurferModel trial duration, which would mess things up.
            em.Triggering.StimulationUsesAcquisitionTriggerScheme=false;
            
            % Clear the stim lib within the WavesurferModel
            em.Stimulation.StimulusLibrary.clear();

            % Populate the Wavesurfer Stim library
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            em.Stimulation.StimulusLibrary.mimic(stimulusLibrary);
            clear stimulusLibrary

            % Enable the stimulation subsystem
            em.Stimulation.Enabled=true;
            
            % Set the Stimulation source
            em.Stimulation.StimulusLibrary.SelectedOutputable=em.Stimulation.StimulusLibrary.Sequences{2};
            
            % Get the thing we'll save to disk
            %protocolSettings=em.encodeConfigurablePropertiesForFileType('cfg');
            protocolSettings=em.encodeForFileType('cfg');

            % Check that the stimulusLibrary in protocolSettings is self-consistent
            self.verifyTrue(protocolSettings.encoding.Stimulation.encoding.StimulusLibrary_.isSelfConsistent());
        end  % function
        
        function testRestorationOfStimulusSource(self)
            % Create an WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            wsModel=ws.WavesurferModel();
            wsModel.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            % Make it so the stim library map durations are not overridden
            % by the WavesurferModel trial duration, which would mess things up.
            wsModel.Triggering.StimulationUsesAcquisitionTriggerScheme=false;
            
            % Clear the stim lib within the WavesurferModel
            wsModel.Stimulation.StimulusLibrary.clear();

            % Populate the Wavesurfer Stim library
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            wsModel.Stimulation.StimulusLibrary.mimic(stimulusLibrary);
            clear stimulusLibrary

            % Enable the stimulation subsystem
            wsModel.Stimulation.Enabled=true;
            
            % Set the Stimulation source
            wsModel.Stimulation.StimulusLibrary.SelectedOutputable=wsModel.Stimulation.StimulusLibrary.Sequences{2};
            
            % Get the current stimulation source name
            value=wsModel.Stimulation.StimulusLibrary.SelectedOutputable.Name;            
            
            % Save the protocol to disk
            %protocolSettings=em.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings=wsModel.encodeForFileType('cfg');  %#ok<NASGU>
            fileName=[tempname() '.mat'];
            save(fileName,'protocolSettings');

            % clear the WavesurferModel         
            clear wsModel;
            %pause(1);
            
            %tasks=ws.dabs.ni.daqmx.System().tasks
            %keyboard
            %clear tasks
%             % Clear the daq system (Shouldn't have to do this!!!)
%             daqSystem = ws.dabs.ni.daqmx.System();
%             ws.utility.deleteIfValidHandle(daqSystem.tasks);

            % Make a new WavesurferModel
            wsModel2=ws.WavesurferModel();
            wsModel2.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            % Restore the protocol (including the stim library)
            s=load(fileName);
            protocolSettingsCheck=s.protocolSettings;
            wsModel2.decodeProperties(protocolSettingsCheck);

            % Check the self-consistency of the stim library
            self.verifyTrue(wsModel2.Stimulation.StimulusLibrary.isSelfConsistent());
            
            % Get the stimulation source name now
            valueCheck=wsModel2.Stimulation.StimulusLibrary.SelectedOutputable.Name;            
            
            % compare the stim library in model to the copy of the
            % populated version
            self.verifyEqual(value,valueCheck);
        end  % function
        
        function testWhetherDurationIsNotFreeAfterProtocolLoad(self)
            % Create an WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            em=ws.WavesurferModel();
            em.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            % Clear the stim lib within the WavesurferModel
            em.Stimulation.StimulusLibrary.clear();

            % Populate the Wavesurfer Stim library
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            em.Stimulation.StimulusLibrary.mimic(stimulusLibrary);
            clear stimulusLibrary
           
            % All map durations should be not free
            %isDurationOverridden= ~[em.Stimulation.StimulusLibrary.Maps.IsDurationFree];
            isDurationOverridden= ~ws.most.idioms.cellArrayPropertyAsArray(em.Stimulation.StimulusLibrary.Maps,'IsDurationFree');
            self.verifyTrue(all(isDurationOverridden));
            
            % Save the protocol to disk
            %protocolSettings=em.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings=em.encodeForFileType('cfg');  %#ok<NASGU>
            fileName=[tempname() '.mat'];
            save(fileName,'protocolSettings');

            % Clear the stim library
            em.Stimulation.StimulusLibrary.clear();
            
            % Restore the protocol (including the stim library)
            s=load(fileName);
            protocolSettingsCheck=s.protocolSettings;
            em.decodeProperties(protocolSettingsCheck);

            % All map durations should be not free, again
            %isDurationOverridden= ~[em.Stimulation.StimulusLibrary.Maps.IsDurationFree];
            isDurationOverridden= ~ws.most.idioms.cellArrayPropertyAsArray(em.Stimulation.StimulusLibrary.Maps,'IsDurationFree');
            self.verifyTrue(all(isDurationOverridden));
            %keyboard
        end  % function      
        
        function testSavingAndLoadingSimpleProtocolFile(self)
            % Create an WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            wsModel=ws.WavesurferModel();
            wsModel.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            % A list of settings
            settings=cell(0,2);
            settings(end+1,:)={'IsTrialBased' true};            
            settings(end+1,:)={'ExperimentTrialCount' 11};

            settings(end+1,:)={'Acquisition.SampleRate' 19979};
            settings(end+1,:)={'Acquisition.Duration' 2.17};
            
            settings(end+1,:)={'Stimulation.Enabled' true};
            settings(end+1,:)={'Stimulation.SampleRate' 18979};
            
            settings(end+1,:)={'Display.Enabled' true};
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
            %protocolSettings=em.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings=wsModel.encodeForFileType('cfg');  %#ok<NASGU>
            fileName=[tempname() '.mat'];
            save(fileName,'protocolSettings');
            
            % Delete the WavesurferModel
            clear wsModel
            %clear protocolSettings  % that we have to do this indicates problems elsewhere...
            
            %keyboard
            
            % Create a fresh WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            wsModelCheck=ws.WavesurferModel();
            wsModelCheck.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
            
            % Load the settings, very like WavesurferController does
            s=load(fileName);
            protocolSettingsCheck=s.protocolSettings;
            %wsModelCheck.releaseHardwareResources();
            wsModelCheck.decodeProperties(protocolSettingsCheck);
            
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
            thisDirName=fileparts(mfilename('fullpath'));
            em=ws.WavesurferModel();
            em.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            
            em.Ephys.ElectrodeManager.addNewElectrode();
            
            % A list of settings
            settings=cell(0,2);
            settings(end+1,:)={'Name' 'Hector'};            
            settings(end+1,:)={'VoltageMonitorChannelName' 'foo'};
            settings(end+1,:)={'CurrentMonitorChannelName' 'bar'};
            settings(end+1,:)={'VoltageCommandChannelName' 'oof'};
            settings(end+1,:)={'CurrentCommandChannelName' 'rab'};
            settings(end+1,:)={'Mode' ws.ElectrodeMode.CC};
            settings(end+1,:)={'TestPulseAmplitudeInVC' ws.utility.DoubleString(3)};
            settings(end+1,:)={'TestPulseAmplitudeInCC' ws.utility.DoubleString(7)};
            settings(end+1,:)={'VoltageMonitorScaling' 2};
            settings(end+1,:)={'CurrentMonitorScaling' 5};
            settings(end+1,:)={'VoltageCommandScaling' 8};
            settings(end+1,:)={'CurrentCommandScaling' 9};
%             settings(end+1,:)={'VoltageUnits' ws.utility.SIUnit('uV')};
%             settings(end+1,:)={'CurrentUnits' ws.utility.SIUnit('kA')};
            
            % Set the settings
            electrode=em.Ephys.ElectrodeManager.Electrodes{1}; %#ok<NASGU>
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
            %protocolSettings=em.encodeConfigurablePropertiesForFileType('cfg');  %#ok<NASGU>
            protocolSettings=em.encodeForFileType('cfg');  %#ok<NASGU>
            fileName=[tempname() '.mat'];
            save(fileName,'protocolSettings');
            
            % Delete the WavesurferModel
            clear em
            %clear protocolSettings  % that we have to do this indicates problems elsewhere...            

%             % Shouldn't have to do this, but...
%             daqSystem = ws.dabs.ni.daqmx.System();
%             ws.utility.deleteIfValidHandle(daqSystem.tasks);

            % Create a fresh WavesurferModel
            thisDirName=fileparts(mfilename('fullpath'));
            emCheck=ws.WavesurferModel();
            emCheck.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));           
            
            % Load the settings, very like WavesurferController does
            s=load(fileName);
            protocolSettingsCheck=s.protocolSettings;
            emCheck.decodeProperties(protocolSettingsCheck);
            
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

%         function testWavesurferModelAliasing(self) %#ok<MANU>
%             % Create an WavesurferModel
%             thisDirName=fileparts(mfilename('fullpath'));
%             em=ws.WavesurferModel();
%             em.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
%             
%             % Save the protocol to disk, very similar to how
%             % WavesurferController does it
%             protocolSettings=em.encodeConfigurablePropertiesForFileType('cfg'); 
%             
%             % Delete the WavesurferModel
%             %clear em  % at this point, the WavesurferModel destructor should be called...
%             %clear protocolSettings  % that we have to do this indicates problems elsewhere...
%             
%             % Create a fresh WavesurferModel (this will fail if em has not been
%             % garbage collected b/c of aliasing)
%             [isAliasing,pathToAlias]=ws.utility.checkForAliasing(em,protocolSettings)
%             
%             keyboard
%             clear em
%             sl=protocolSettings.Stimulation.StimulusLibrary
%             sl.SelectedItemClassName=''
%             sl.SelectedSequence=[]
%             sl.SelectedMap=[]
%             sl.SelectedStimulus=[]
%             sl.SelectedOutputable=[]
%             for j=length(sl.Sequences):-1:1
%                 sl.deleteItem(sl.Sequences{j});
%             end
%             for j=length(sl.Maps):-1:1
%                 sl.deleteItem(sl.Maps{j});
%             end
%             for j=length(sl.Stimuli):-1:1
%                 sl.deleteItem(sl.Stimuli{j});
%             end            
%             
% %             thisDirName=fileparts(mfilename('fullpath'));
% %             emCheck=ws.WavesurferModel();
% %             emCheck.initializeFromMDFFileName(fullfile(thisDirName,'Machine_Data_File_WS_Test.m'));
%         end  % function
        
    end  % test methods    

 end  % classdef
