classdef LoadDataFileTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
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

        function testAnalogAndDigital(self)
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Demo_with_4_AIs_2_DIs_2_AOs_2_DOs.m'), ...
                               isCommandLineOnly);

            wsModel.Acquisition.SampleRate=20000;  % Hz
            wsModel.Stimulation.Enabled=true;
            wsModel.Stimulation.SampleRate=20000;  % Hz
            wsModel.Display.Enabled=true;
            wsModel.Logging.Enabled=true;

            nTrials=3;
            wsModel.ExperimentTrialCount=nTrials;

            % Make a pulse stimulus, add to the stimulus library
            pulse=wsModel.Stimulation.StimulusLibrary.addNewStimulus('SquarePulseTrain');
            pulse.Name='Pulse';
            pulse.Amplitude='4.4';  % V
            pulse.Delay='0.1';
            pulse.Delegate.PulseDuration='0.8';
            pulse.Delegate.Period='1';

            % make a map that puts the just-made pulse out of the first AO channel, add
            % to stim library
            map=wsModel.Stimulation.StimulusLibrary.addNewMap();
            map.Name='Pulse out first AO, DO';
            firstAOChannelName=wsModel.Stimulation.AnalogChannelNames{1};
            map.addBinding(firstAOChannelName,pulse);
            firstDOChannelName=wsModel.Stimulation.DigitalChannelNames{1};
            map.addBinding(firstDOChannelName,pulse);

            % make the new map the current sequence/map
            wsModel.Stimulation.StimulusLibrary.SelectedOutputable=map;
            
            % set the data file name
            thisFileName=mfilename();
            [~,dataFileBaseName]=fileparts(thisFileName);
            wsModel.Logging.FileBaseName=dataFileBaseName;

            % delete any preexisting data files
            dataDirNameAbsolute=wsModel.Logging.FileLocation;
            dataFilePatternAbsolute=fullfile(dataDirNameAbsolute,[dataFileBaseName '*']);
            delete(dataFilePatternAbsolute);

            absoluteFileName = wsModel.Logging.NextTrialSetAbsoluteFileName ;
            
            pause(1);
            wsModel.start();  % blocking, now
            pause(0.5);

            % Make sure that worked
            self.verifyEqual(wsModel.ExperimentCompletedTrialCount,nTrials);            
            
            % Try to read the data file
            dataAsStruct = ws.loadDataFile(absoluteFileName) ;
            
            % These should not error, at the least...
            fs = dataAsStruct.header.Acquisition.SampleRate;   %#ok<NASGU> % Hz
            analogChannelNames = dataAsStruct.header.Acquisition.AnalogChannelNames;   %#ok<NASGU> 
            analogChannelScales = dataAsStruct.header.Acquisition.AnalogChannelScales;   %#ok<NASGU> 
            analogChannelUnits = dataAsStruct.header.Acquisition.AnalogChannelUnits;   %#ok<NASGU> 
            digitalChannelNames = dataAsStruct.header.Acquisition.DigitalChannelNames;   %#ok<NASGU>    
            analogData = dataAsStruct.trial_0003.analogScans ;   %#ok<NASGU>
            %analogDataSize = size(analogData);  %#ok<NOPRT,NASGU>
            digitalData = dataAsStruct.trial_0003.digitalScans ;   %#ok<NASGU>
            %digitalDataSize = size(digitalData);  %#ok<NOPRT,NASGU>
            %digitalDataClassName = class(digitalData);  %#ok<NASGU,NOPRT>
            
            % Delete the data file
            delete(dataFilePatternAbsolute);
        end  % function
        
    end  % test methods

 end  % classdef
