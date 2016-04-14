classdef LoadDataFileTestCase < matlab.unittest.TestCase
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
        
        function testLoadingOlderFileWithFunnySamplingRate(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, '30_kHz_sampling_rate_0p912_0001.h5') ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw') ;  % conversion to scaled data would fail for these files
            % The nominal sampling rate was 30000, but the returned
            % sampling rate should be ~30003 Hz, to make (100 Mhz)/fs an
            % integer.
            returnedAcqSamplingRate = dataFileAsStruct.header.Acquisition.SampleRate ;
            nTimebaseTicksPerAcqSample = 100e6/returnedAcqSamplingRate ;  % should be exactly 3333
            self.verifyEqual(nTimebaseTicksPerAcqSample,3333) ;
            returnedStimSamplingRate = dataFileAsStruct.header.Stimulation.SampleRate ;
            nTimebaseTicksPerStimSample = 100e6/returnedStimSamplingRate ;  % should be exactly 3333
            self.verifyEqual(nTimebaseTicksPerStimSample,3333) ;
        end
        
        function testLoadingNewerFileWithFunnySamplingRate(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, '30_kHz_sampling_rate_0p913_0001.h5') ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw') ;
            % The requested sampling rate was 30000, but this version of WS
            % coerces that in the UI to an acheivable rate, which should be
            % ~30003 Hz, to make (100 Mhz)/fs an integer.
            returnedAcqSamplingRate = dataFileAsStruct.header.Acquisition.SampleRate ;
            nTimebaseTicksPerAcqSample = 100e6/returnedAcqSamplingRate ;  % should be exactly 3333
            self.verifyEqual(nTimebaseTicksPerAcqSample,3333) ;
            returnedStimSamplingRate = dataFileAsStruct.header.Stimulation.SampleRate ;
            nTimebaseTicksPerStimSample = 100e6/returnedStimSamplingRate ;  % should be exactly 3333
            self.verifyEqual(nTimebaseTicksPerStimSample,3333) ;
        end
        
        function testLoadingOlderFileWithFunnierSamplingRate(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, '29997_Hz_sampling_rate_0p912_0001.h5') ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw') ;
            % The nominal sampling rate was 29997, but the returned
            % sampling rate should be 100e6/3333 for acq, and 100e6/3334
            % for stim.
            returnedAcqSamplingRate = dataFileAsStruct.header.Acquisition.SampleRate ;
            nTimebaseTicksPerAcqSample = 100e6/returnedAcqSamplingRate ;  % should be exactly 3333
            self.verifyEqual(nTimebaseTicksPerAcqSample,3333) ;
            returnedStimSamplingRate = dataFileAsStruct.header.Stimulation.SampleRate ;
            nTimebaseTicksPerStimSample = 100e6/returnedStimSamplingRate ;  % should be exactly 3333
            self.verifyEqual(nTimebaseTicksPerStimSample,3334) ;
        end
        
        function testLoadingNewerFileWithFunnierSamplingRate(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, '29997_Hz_sampling_rate_0p913_0001.h5') ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw') ;
            % The nominal sampling rate was 29997, but the returned
            % sampling rate should be 100e6/3333 for both acq and stim.
            returnedAcqSamplingRate = dataFileAsStruct.header.Acquisition.SampleRate ;
            nTimebaseTicksPerAcqSample = 100e6/returnedAcqSamplingRate ;  % should be exactly 3333
            self.verifyEqual(nTimebaseTicksPerAcqSample,3333) ;
            returnedStimSamplingRate = dataFileAsStruct.header.Stimulation.SampleRate ;
            nTimebaseTicksPerStimSample = 100e6/returnedStimSamplingRate ;  % should be exactly 3333
            self.verifyEqual(nTimebaseTicksPerStimSample,3333) ;
        end
        
    end  % test methods

 end  % classdef
