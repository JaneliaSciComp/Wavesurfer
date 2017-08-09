classdef LoadDataFileTestCase < matlab.unittest.TestCase
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
            isCommandLineOnly='--nogui';
            %thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(isCommandLineOnly);

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
            fs = dataAsStruct.header.AcquisitionSampleRate;   %#ok<NASGU> % Hz
            analogChannelNames = dataAsStruct.header.AIChannelNames;   %#ok<NASGU> 
            analogChannelScales = dataAsStruct.header.AIChannelScales;   %#ok<NASGU> 
            analogChannelUnits = dataAsStruct.header.AIChannelUnits;   %#ok<NASGU> 
            digitalChannelNames = dataAsStruct.header.DIChannelNames;   %#ok<NASGU>    
            analogData = dataAsStruct.sweep_0003.analogScans ;   %#ok<NASGU>
            %analogDataSize = size(analogData);  %#ok<NOPRT,NASGU>
            digitalData = dataAsStruct.sweep_0003.digitalScans ;   %#ok<NASGU>
            %digitalDataSize = size(digitalData);  %#ok<NOPRT,NASGU>
            %digitalDataClassName = class(digitalData);  %#ok<NASGU,NOPRT>
            
            % Delete the data file
            delete(dataFilePatternAbsolute);
        end  % function

        function testOneDI(self)
            isCommandLineOnly='--nogui';
            wsModel = wavesurfer(isCommandLineOnly) ;

            % Remove the pre-existing channels
            wsModel.IsAIChannelMarkedForDeletion(:) = true ;
            wsModel.deleteMarkedAIChannels() ;
            wsModel.IsAOChannelMarkedForDeletion(:) = true ;
            wsModel.deleteMarkedAOChannels() ;
            
            % Make sure all deleted
            self.verifyEqual(wsModel.NAIChannels, 0) ;            
            self.verifyEqual(wsModel.NAOChannels, 0) ;            
            
            % Add a single DI channel
            wsModel.addDIChannel() ;
                           
            % set the data file name
            thisFileName = mfilename() ;
            [~,dataFileBaseName] = fileparts(thisFileName) ;
            wsModel.DataFileBaseName = dataFileBaseName ;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.DataFileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            absoluteFileName = wsModel.NextRunAbsoluteFileName ;
            
            pause(1);
            wsModel.record();  % blocking, now
            pause(0.5);

            % Make sure that worked
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,1);            
            
            % Try to read the data file
            dataAsStruct = ws.loadDataFile(absoluteFileName) ;
            
            % These should not error, at the least...
            fs = dataAsStruct.header.AcquisitionSampleRate;   %#ok<NASGU> % Hz
%             analogChannelNames = dataAsStruct.header.AIChannelNames;   %#ok<NASGU> 
%             analogChannelScales = dataAsStruct.header.AIChannelScales;   %#ok<NASGU> 
%             analogChannelUnits = dataAsStruct.header.AIChannelUnits;   %#ok<NASGU> 
            digitalChannelNames = dataAsStruct.header.DIChannelNames;   %#ok<NASGU>    
%            analogData = dataAsStruct.sweep_0003.analogScans ;   %#ok<NASGU>
            %analogDataSize = size(analogData);  %#ok<NOPRT,NASGU>
            digitalData = dataAsStruct.sweep_0001.digitalScans ;   %#ok<NASGU>
            %digitalDataSize = size(digitalData);  %#ok<NOPRT,NASGU>
            %digitalDataClassName = class(digitalData);  %#ok<NASGU,NOPRT>
            
            % Delete the data file
            delete(dataFilePatternAbsolute);
        end  % function
        
        
    end  % test methods

 end  % classdef
