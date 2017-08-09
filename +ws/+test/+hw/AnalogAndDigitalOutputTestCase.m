classdef AnalogAndDigitalOutputTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)
    
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
        function testAnalogOnly(self)
            wsModel=wavesurfer('--nogui') ;

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

            nSweeps=3;
            wsModel.NSweepsPerRun=nSweeps;

            % Make a pulse stimulus, add to the stimulus library
            pulseTrainIndex = wsModel.addNewStimulus() ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'TypeString', 'SquarePulseTrain') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Name', 'Pulse Train') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Amplitude', '4.4') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Delay', '0.1') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'PulseDuration', '0.8') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Period', '1') ;            
            
            % make a map that puts the just-made pulse out of the first AO channel, add
            % to stim library
            mapIndex = wsModel.addNewStimulusMap() ;
            wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name', 'Pulse train out first AO') ;
            firstAOChannelName = wsModel.AOChannelNames{1} ;
            bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', firstAOChannelName) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', pulseTrainIndex) ;
            
            % make the new map the current sequence/map
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
            wsModel.record();  % this now blocks...            

            % Delete the data file
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function

        function testDigitalOnly(self)
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

            nSweeps=3;
            wsModel.NSweepsPerRun=nSweeps;

%             % Make a pulse stimulus, add to the stimulus library
%             pulse=wsModel.Stimulation.StimulusLibrary.addNewStimulus('SquarePulseTrain');
%             pulse.Name='Pulse';
%             pulse.Amplitude='1';  % logical
%             pulse.Delay='0.17';
%             pulse.Duration='0.3';
%             pulse.Delegate.PulseDuration='0.05';
%             pulse.Delegate.Period='0.1';

            % Make a pulse stimulus, add to the stimulus library
            pulseTrainIndex = wsModel.addNewStimulus() ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'TypeString', 'SquarePulseTrain') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Name', 'Pulse Train') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Amplitude', '1') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Delay', '0.1') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'PulseDuration', '0.8') ;
            wsModel.setStimulusLibraryItemProperty('ws.Stimulus', pulseTrainIndex, 'Period', '1') ;            

%             % make a map that puts the just-made pulse out of the first AO channel, add
%             % to stim library
%             map=wsModel.Stimulation.StimulusLibrary.addNewMap();
%             map.Name='Pulse out first DO';
%             firstDOChannelName=wsModel.DOChannelNames{1};
%             map.addBinding(firstDOChannelName,pulse);

            % make a map that puts the just-made pulse out of the first DO channel, add
            % to stim library
            mapIndex = wsModel.addNewStimulusMap() ;
            wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name', 'Pulse train out first DO') ;
            firstDOChannelName = wsModel.DOChannelNames{1} ;
            bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', firstDOChannelName) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', pulseTrainIndex) ;

%             % make the new map the current sequence/map
%             wsModel.Stimulation.StimulusLibrary.SelectedOutputable=map;
            
            % make the new map the current sequence/map
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
        end  % function

        function testAnalogAndDigital(self)
            wsModel=wavesurfer('--nogui') ;

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

            nSweeps=3;
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

            % Delete the data file
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function
    end  % test methods
 end  % classdef
