classdef LoadDataFileTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            %ws.reset() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            %ws.reset() ;
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

        function testLoadingTimeSubset(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, 'multiple_sweeps_0001-0010.h5') ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw', 0.25, 0.75) ;
            returnedAcqSamplingRate = dataFileAsStruct.header.AcquisitionSampleRate ;
            self.verifyEqual(returnedAcqSamplingRate,20e3) ;
            returnedStimSamplingRate = dataFileAsStruct.header.StimulationSampleRate ;
            self.verifyEqual(returnedStimSamplingRate,20e3) ;
            data = dataFileAsStruct.sweep_0001.analogScans ;
            self.verifyEqual(length(data),10e3) ;
        end

        function testLoadingTimeSubsetOnOlderFile(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, '30_kHz_sampling_rate_0p913_0001.h5') ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw', 0.25, 0.75) ;
            returnedAcqSamplingRate = dataFileAsStruct.header.Acquisition.SampleRate ;
            self.verifyEqual(returnedAcqSamplingRate,100e6/3333) ;
            returnedStimSamplingRate = dataFileAsStruct.header.Stimulation.SampleRate ;
            self.verifyEqual(returnedStimSamplingRate,100e6/3333) ;
            data = dataFileAsStruct.sweep_0001.analogScans ;
            self.verifyEqual(length(data), round(returnedAcqSamplingRate/2)) ;
        end

        function testLoadingSweepSubset(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, 'multiple_sweeps_0001-0010.h5') ;
            minSweepIndex = 2 ;
            maxSweepIndex = 7 ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw', [], [], minSweepIndex, maxSweepIndex) ;
            returnedAcqSamplingRate = dataFileAsStruct.header.AcquisitionSampleRate ;
            self.verifyEqual(returnedAcqSamplingRate,20e3) ;
            returnedStimSamplingRate = dataFileAsStruct.header.StimulationSampleRate ;
            self.verifyEqual(returnedStimSamplingRate,20e3) ;
            for sweepIndex = 1:10 ,
                if minSweepIndex<=sweepIndex && sweepIndex<=maxSweepIndex ,
                    field_name = sprintf('sweep_%04d', sweepIndex) ;
                    data = dataFileAsStruct.(field_name).analogScans ;
                    self.verifyEqual(length(data),20e3) ;
                else
                    didThrowExpectedException = false ;
                    try                    
                        field_name = sprintf('sweep_%04d', sweepIndex) ;
                        data = dataFileAsStruct.(field_name).analogScans ;
                        self.verifyEqual(length(data),20e3) ;
                    catch me
                        if isequal(me.identifier, 'MATLAB:nonExistentField') ,
                            didThrowExpectedException = true ;
                        else
                            rethrow(me) ;
                        end
                    end
                    self.verifyTrue(didThrowExpectedException) ;
                end
            end
        end       

        function testLoadingTimeAndSweepSubset(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, 'multiple_sweeps_0001-0010.h5') ;
            minSweepIndex = 2 ;
            maxSweepIndex = 7 ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw', 0.3, 0.7, minSweepIndex, maxSweepIndex) ;
            returnedAcqSamplingRate = dataFileAsStruct.header.AcquisitionSampleRate ;
            self.verifyEqual(returnedAcqSamplingRate,20e3) ;
            returnedStimSamplingRate = dataFileAsStruct.header.StimulationSampleRate ;
            self.verifyEqual(returnedStimSamplingRate,20e3) ;
            for sweepIndex = 1:10 ,
                if minSweepIndex<=sweepIndex && sweepIndex<=maxSweepIndex ,
                    field_name = sprintf('sweep_%04d', sweepIndex) ;
                    data = dataFileAsStruct.(field_name).analogScans ;
                    self.verifyEqual(length(data),8e3) ;
                else
                    didThrowExpectedException = false ;
                    try                    
                        field_name = sprintf('sweep_%04d', sweepIndex) ;
                        ignoredData = dataFileAsStruct.(field_name).analogScans ;  %#ok<NASGU>
                    catch me
                        if isequal(me.identifier, 'MATLAB:nonExistentField') ,
                            didThrowExpectedException = true ;
                        else
                            rethrow(me) ;
                        end
                    end
                    self.verifyTrue(didThrowExpectedException) ;
                end
            end
        end       
        
        function testLoadingTimeAndSweepSubsetWithMultipleChannels(self)
            thisDirName=fileparts(mfilename('fullpath'));
            fileName = fullfile(thisDirName, 'multiple_sweeps_multiple_channels_0001-0009.h5') ;
            tMin = 0.2 ;
            tMax = 0.6 ;
            minSweepIndex = 2 ;
            maxSweepIndex = 6 ;            
            channelCount = 2 ;
            dataFileAsStruct = ws.loadDataFile(fileName, 'raw', tMin, tMax, minSweepIndex, maxSweepIndex) ;
            acqSamplingRate = dataFileAsStruct.header.AcquisitionSampleRate ;
            self.verifyEqual(acqSamplingRate,1e3) ;
            stimSampleRate = dataFileAsStruct.header.StimulationSampleRate ;
            self.verifyEqual(stimSampleRate,1e3) ;
            for sweepIndex = 1:10 ,
                if minSweepIndex<=sweepIndex && sweepIndex<=maxSweepIndex ,
                    field_name = sprintf('sweep_%04d', sweepIndex) ;
                    data = dataFileAsStruct.(field_name).analogScans ;
                    self.verifyEqual(size(data), [round(acqSamplingRate*(tMax-tMin)) channelCount]) ;
                else
                    didThrowExpectedException = false ;
                    try                    
                        field_name = sprintf('sweep_%04d', sweepIndex) ;
                        ignoredData = dataFileAsStruct.(field_name).analogScans ;  %#ok<NASGU>
                    catch me
                        if isequal(me.identifier, 'MATLAB:nonExistentField') ,
                            didThrowExpectedException = true ;
                        else
                            rethrow(me) ;
                        end
                    end
                    self.verifyTrue(didThrowExpectedException) ;
                end
            end
        end       
        
        
    end  % test methods

 end  % classdef
