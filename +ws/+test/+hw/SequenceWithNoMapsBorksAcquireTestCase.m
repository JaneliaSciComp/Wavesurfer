classdef SequenceWithNoMapsBorksAcquireTestCase < matlab.unittest.TestCase
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
            
            % make a map that puts the just-made pulse out of the first AO channel, add
            % to stim library
            mapIndex = wsModel.addNewStimulusMap() ;
            wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name', 'Pulse train out first AO') ;
            firstAOChannelName = wsModel.AOChannelNames{1} ;
            bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', firstAOChannelName) ;
            wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', pulseTrainIndex) ;
            
            % make a sequence, but don't add any maps to it
            sequenceIndex = wsModel.addNewStimulusSequence() ;
            wsModel.setStimulusLibraryItemProperty('ws.StimulusSequence', sequenceIndex, 'Name', 'I am empty!') ;

            % make the new map the current sequence/map
            wsModel.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', sequenceIndex) ;
            
            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.DataFileBaseName=dataFileBaseName;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.DataFileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            pause(1);
            wsModel.record();  % this blocks now

            % Delete the data file
            delete(dataFilePatternAbsolute);
            
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function
    end  % test methods

 end  % classdef
