classdef CreateAndLoadDataFileTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
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

        function testAnalogAndDigital(self)
            wsModel=wavesurfer('--nogui');

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;
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

            absoluteFileName = wsModel.NextRunAbsoluteFileName ;
            
            pause(1);
            wsModel.record();  % blocking, now
            pause(0.5);

            % Make sure that worked
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
            
            % Try to read the data file
            dataAsStruct = ws.loadDataFile(absoluteFileName) ;
            
            % These should not error, at the least...
            fs = dataAsStruct.header.AcquisitionSampleRate;
            self.verifyEqual(fs, 20000) ;
            if isfield(dataAsStruct.header, 'AIChannelNames') ,
                % newer files
                analogChannelNames = dataAsStruct.header.AIChannelNames ;
            else
                % older files
                analogChannelNames = dataAsStruct.header.Acquisition.AnalogChannelNames ;
            end
            self.verifyEqual(length(analogChannelNames),4) ;
            analogChannelScales = dataAsStruct.header.AIChannelScales;   %#ok<NASGU> 
            analogChannelUnits = dataAsStruct.header.AIChannelUnits;   %#ok<NASGU> 
            if isfield(dataAsStruct.header, 'DIChannelNames') ,
                digitalChannelNames = dataAsStruct.header.DIChannelNames;   %#ok<NASGU>
            else
                digitalChannelNames = dataAsStruct.header.Acquisition.DigitalChannelNames;   %#ok<NASGU>
            end
            analogData = dataAsStruct.sweep_0003.analogScans ;   %#ok<NASGU>
            digitalData = dataAsStruct.sweep_0003.digitalScans ;   %#ok<NASGU>
            
            % Check some of the stim library parts of the header
            header = dataAsStruct.header ;
            stimulusLibraryHeader = header.StimulusLibrary ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'Stimuli')) ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'Maps')) ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'Sequences')) ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'SelectedOutputableClassName')) ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'SelectedOutputableIndex')) ;
            
            % Check that some of the triggering info is there
            %self.verifyTrue(isfield(header, 'Triggering')) ;
            %triggering = header.Triggering ;
            self.verifyTrue(isfield(header, 'AcquisitionTriggerIndex')) ;
            self.verifyTrue(isfield(header, 'StimulationTriggerIndex')) ;
            
            % Delete the data file
            delete(dataFilePatternAbsolute);
        end  % function
        
    end  % test methods

 end  % classdef
