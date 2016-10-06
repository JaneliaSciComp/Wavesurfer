classdef AudioFileOutputTestCase < matlab.unittest.TestCase
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
        function testWithExistingFile(self)
            wsModel=wavesurfer('--nogui');

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;
            
            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.IsEnabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.IsEnabled=true;
            %wsModel.Logging.IsEnabled=false;

            nSweeps=1;
            wsModel.NSweepsPerRun=nSweeps;
            wsModel.SweepDuration = 4 ;  % s

%             % Make a pulse stimulus, add to the stimulus library
%             godzilla=wsModel.Stimulation.StimulusLibrary.addNewStimulus('File');
%             godzilla.Name='Godzilla';
%             godzilla.Amplitude='1';  % V
%             godzilla.Delay='0.25';
%             godzilla.Duration='3.5';
%             thisDirName=fileparts(mfilename('fullpath'));
%             godzillaStimulusAbsoluteFileName = fullfile(thisDirName,'godzilla.wav') ;
%             godzilla.Delegate.FileName=godzillaStimulusAbsoluteFileName;

            % Make a godzilla stimulus, add to the stimulus library
            thisDirName = fileparts(mfilename('fullpath')) ;
            godzillaStimulusAbsoluteFileName = fullfile(thisDirName,'godzilla.wav') ;
            godzillaStimulusIndex = wsModel.addNewStimulus() ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'TypeString', 'File') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Name', 'Godzilla') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Amplitude', '1') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Delay', '0.25') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Duration', '3.5') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'FileName', godzillaStimulusAbsoluteFileName) ;
            
%             % make a map that puts the just-made pulse out of the first AO channel, add
%             % to stim library
%             map = wsModel.Stimulation.StimulusLibrary.addNewMap() ;
%             map.Name='Godzilla out first AO';
%             firstAoChannelName=wsModel.Stimulation.AnalogChannelNames{1};
%             map.addBinding(firstAoChannelName,godzilla);

            % make a map that puts the just-made stimulus out of the first AO channel, add
            % to stim library
            mapIndex = wsModel.addNewStimulusMap() ;
            wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name', 'Godzilla out first AO') ;
            firstAOChannelName = wsModel.Stimulation.AnalogChannelNames{1} ;
            bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', firstAOChannelName) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', godzillaStimulusIndex) ;
            
%             % make the new map the current sequence/map
%             wsModel.Stimulation.StimulusLibrary.SelectedOutputable=map;
            
            % make the new map the current sequence/map
            wsModel.setSelectedOutputableByClassNameAndIndex('ws.StimulusMap', mapIndex) ;
            
            pause(1);
            wsModel.play();

            dtBetweenChecks=1;  % s
            maxTimeToWait=1.1*wsModel.SweepDuration;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
                    break
                end
            end                   

            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function

        function testWithNonexistantFile(self)
            wsModel = wavesurfer('--nogui') ;

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;
            
            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.IsEnabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.IsEnabled=true;
            %wsModel.Logging.IsEnabled=false;

            nSweeps=1;
            wsModel.NSweepsPerRun=nSweeps;
            wsModel.SweepDuration = 4 ;  % s

%             % Make a pulse stimulus, add to the stimulus library
%             godzilla=wsModel.Stimulation.StimulusLibrary.addNewStimulus('File');
%             godzilla.Name='Godzilla';
%             godzilla.Amplitude='1';  % V
%             godzilla.Delay='0.25';
%             godzilla.Duration='3.5';
%             thisDirName=fileparts(mfilename('fullpath'));
%             absoluteFileName = fullfile(thisDirName,'doesnt_exist.wav') ;
%             godzilla.Delegate.FileName=absoluteFileName;

            % Make a godzilla stimulus, add to the stimulus library
            thisDirName = fileparts(mfilename('fullpath')) ;
            godzillaStimulusAbsoluteFileName = fullfile(thisDirName,'godzilla.wav') ;
            godzillaStimulusIndex = wsModel.addNewStimulus() ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'TypeString', 'File') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Name', 'Godzilla') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Amplitude', '1') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Delay', '0.25') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Duration', '3.5') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'FileName', godzillaStimulusAbsoluteFileName) ;
            
%             % make a map that puts the just-made pulse out of the first AO channel, add
%             % to stim library
%             map=wsModel.Stimulation.StimulusLibrary.addNewMap();
%             map.Name='Godzilla out first AO';
%             firstAoChannelName=wsModel.Stimulation.AnalogChannelNames{1};
%             map.addBinding(firstAoChannelName,godzilla);

            % make a map that puts the just-made stimulus out of the first AO channel, add
            % to stim library
            mapIndex = wsModel.addNewStimulusMap() ;
            wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name', 'Godzilla out first AO') ;
            firstAOChannelName = wsModel.Stimulation.AnalogChannelNames{1} ;
            bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', firstAOChannelName) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', godzillaStimulusIndex) ;
            
%             % make the new map the current sequence/map
%             wsModel.Stimulation.StimulusLibrary.SelectedOutputable=map;
            
            % make the new map the current sequence/map
            wsModel.setSelectedOutputableByClassNameAndIndex('ws.StimulusMap', mapIndex) ;
            
            pause(1);
            wsModel.play();  % this should *not* throw an error

            dtBetweenChecks=1;  % s
            maxTimeToWait=1.1*wsModel.SweepDuration;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
                    break
                end
            end                   

            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function

        function testWithTemplateFileName(self)
            wsModel=wavesurfer('--nogui');

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;
            
            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.IsEnabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.IsEnabled=true;
            %wsModel.Logging.IsEnabled=false;

            nSweeps=1;
            wsModel.NSweepsPerRun=nSweeps;
            wsModel.SweepDuration = 4 ;  % s

            % Make a godzilla stimulus, add to the stimulus library
            thisDirName = fileparts(mfilename('fullpath')) ;
            godzillaStimulusAbsoluteFileName = fullfile(thisDirName,'godzilla.wav') ;
            godzillaStimulusIndex = wsModel.addNewStimulus() ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'TypeString', 'File') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Name', 'Godzilla') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Amplitude', '1') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Delay', '0.25') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'Duration', '3.5') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', godzillaStimulusIndex, 'FileName', godzillaStimulusAbsoluteFileName) ;
            
            % Make a map that puts the just-made stimulus out of the first AO channel, add
            % to stim library.
            mapIndex = wsModel.addNewStimulusMap() ;
            wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name', 'Godzilla out first AO') ;
            firstAOChannelName = wsModel.Stimulation.AnalogChannelNames{1} ;
            bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', firstAOChannelName) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', godzillaStimulusIndex) ;
            
            % Make the new map the current sequence/map.
            wsModel.setSelectedOutputableByClassNameAndIndex('ws.StimulusMap', mapIndex) ;
            
            pause(1);
            wsModel.play();

            dtBetweenChecks=1;  % s
            maxTimeToWait=1.1*wsModel.SweepDuration;  % s
            nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
            for i=1:nTimesToCheck ,
                pause(dtBetweenChecks);
                if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
                    break
                end
            end                   

            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function

    end  % test methods

 end  % classdef
