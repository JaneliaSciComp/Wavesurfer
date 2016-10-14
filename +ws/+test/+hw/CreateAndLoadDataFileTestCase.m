classdef CreateAndLoadDataFileTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
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
            
            wsModel.Acquisition.SampleRate=20000;  % Hz            
            wsModel.Stimulation.IsEnabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.IsEnabled=true;
            %wsModel.Logging.IsEnabled=true;

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
            firstAOChannelName = wsModel.Stimulation.AnalogChannelNames{1} ;
            firstDOChannelName = wsModel.Stimulation.DigitalChannelNames{1} ;
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
            wsModel.Logging.FileBaseName=dataFileBaseName;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.Logging.FileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            absoluteFileName = wsModel.Logging.NextRunAbsoluteFileName ;
            
            pause(1);
            wsModel.record();  % blocking, now
            pause(0.5);

            % Make sure that worked
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
            
            % Try to read the data file
            dataAsStruct = ws.loadDataFile(absoluteFileName) ;
            
            % These should not error, at the least...
            fs = dataAsStruct.header.Acquisition.SampleRate;
            self.verifyEqual(fs, 20000) ;
            analogChannelNames = dataAsStruct.header.Acquisition.AnalogChannelNames;
            self.verifyEqual(length(analogChannelNames),4) ;
            analogChannelScales = dataAsStruct.header.Acquisition.AnalogChannelScales;   %#ok<NASGU> 
            analogChannelUnits = dataAsStruct.header.Acquisition.AnalogChannelUnits;   %#ok<NASGU> 
            digitalChannelNames = dataAsStruct.header.Acquisition.DigitalChannelNames;   %#ok<NASGU>    
            analogData = dataAsStruct.sweep_0003.analogScans ;   %#ok<NASGU>
            digitalData = dataAsStruct.sweep_0003.digitalScans ;   %#ok<NASGU>
            
            % Check some of the stim library parts of the header
            header = dataAsStruct.header ;
            stimulusLibraryHeader = header.Stimulation.StimulusLibrary ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'Stimuli')) ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'Maps')) ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'Sequences')) ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'SelectedOutputableClassName')) ;
            self.verifyTrue(isfield(stimulusLibraryHeader, 'SelectedOutputableIndex')) ;
            
            % Check that some of the triggering info is there
            self.verifyTrue(isfield(header, 'Triggering')) ;
            triggering = header.Triggering ;
            self.verifyTrue(isfield(triggering, 'AcquisitionTriggerScheme')) ;
            self.verifyTrue(isfield(triggering, 'StimulationTriggerScheme')) ;
            
            % Delete the data file
            delete(dataFilePatternAbsolute);
        end  % function
        
    end  % test methods

 end  % classdef
