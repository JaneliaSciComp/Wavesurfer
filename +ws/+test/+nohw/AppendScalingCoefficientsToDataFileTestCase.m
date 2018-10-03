classdef AppendScalingCoefficientsToDataFileTestCase < matlab.unittest.TestCase
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
        function testAppendingToOlderFile(self)
            thisDirName=fileparts(mfilename('fullpath'));
            inputFileName = fullfile(thisDirName, 'acquired_without_scaling_coeffs_0001.h5') ;
            fakeCoefficients = [ 0 1 0 0 ; ...
                                 0 2 0 0 ; ...
                                 0 3 0 0 ; ...
                                 0 4 0 0 ; ...
                                 0 5 0 0 ; ...
                                 0 6 0 0 ; ...
                                 0 7 0 0 ]' ;          
            outputFileName = [tempname() '.h5'] ;
            ws.appendCalibrationCoefficientsToCopyOfDataFile(inputFileName, fakeCoefficients, outputFileName) ;
            dataFileAsStruct = ws.loadDataFile(outputFileName, 'raw') ;
            delete(outputFileName) ;
            if isfield(dataFileAsStruct.header, 'AIScalingCoefficients') ,
                fakeCoefficientsAsRead = dataFileAsStruct.header.AIScalingCoefficients ;
            else
                fakeCoefficientsAsRead = dataFileAsStruct.header.Acquisition.AnalogScalingCoefficients ;
            end
            self.verifyEqual(fakeCoefficients,fakeCoefficientsAsRead) ;
        end
        
        function testAppendingToManyOlderFiles(self)
            thisDirName=fileparts(mfilename('fullpath'));
            sourceFolderName = fullfile(thisDirName, 'folder_without_scaling_coeffs') ;
            fakeCoefficients = [ 0 1 0 0 ; ...
                                 0 2 0 0 ; ...
                                 0 3 0 0 ; ...
                                 0 4 0 0 ; ...
                                 0 5 0 0 ; ...
                                 0 6 0 0 ; ...
                                 0 7 0 0 ]' ;          
            targetFolderName = tempname() ;
            isDryRun = true ;
            ws.addScalingToHDF5FilesRecursivelyGivenCoeffs(sourceFolderName, fakeCoefficients, targetFolderName, isDryRun) ;
            isDryRun = false ;
            ws.addScalingToHDF5FilesRecursivelyGivenCoeffs(sourceFolderName, fakeCoefficients, targetFolderName, isDryRun) ;            
            
            % Verify
            isAllWell = ws.verifyScalingOfHDF5FilesRecursivelyGivenCoeffs(sourceFolderName, fakeCoefficients, targetFolderName) ;
            self.verifyTrue(isAllWell) ;
        end
    end  % test methods
    
end  % classdef
