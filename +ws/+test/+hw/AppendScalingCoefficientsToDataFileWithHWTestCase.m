classdef AppendScalingCoefficientsToDataFileWithHWTestCase < matlab.unittest.TestCase
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
        function testAppendingToOlderFileVsGeneratingNewFile(self)
            % Now create a new data file, read it in, and make sure the
            % shape of the scaling coefficients array is correct.  Also do
            % a few checks on the values
            wsModel = wavesurfer('--nogui') ;
            wsModel.PrimaryDeviceName = 'Dev1' ;
            nCoeffs = 4 ;  % this holds for all x-series boards
            nAIChannels = 7 ;
            for i=1:(nAIChannels-1) ,
                wsModel.addAIChannel() ;
            end
            self.verifyEqual(wsModel.NAIChannels, nAIChannels, 'Number of analog channels is wrong') ;
            nInactiveAnalogChannels = 2 ;
            wsModel.IsAIChannelActive(3) = false ;  % shouldn't matter
            wsModel.IsAIChannelActive(5) = false ;
            nActiveAIChannels = nAIChannels - nInactiveAnalogChannels ;
            self.verifyEqual(wsModel.getNActiveAIChannels(), nActiveAIChannels, 'Number of active analog channels is wrong') ;
            wsModel.SweepDuration = 0.1 ;  % sec

            outputFileAbsolutePath = [tempname() '.h5'] ;
            [outputFileDirName, outputFileStem] = fileparts(outputFileAbsolutePath) ;
            wsModel.DataFileLocation = outputFileDirName ;
            wsModel.DataFileBaseName = outputFileStem ;
            wsModel.IsOKToOverwriteDataFile = true ;
            newDataFileAbsolutePath = wsModel.NextRunAbsoluteFileName ;
            wsModel.record() ;  % blocks
            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,1) ;
            wsModel.delete() ; 
            wsModel = [] ;  %#ok<NASGU>

            newDataFileAsStruct = ws.loadDataFile(newDataFileAbsolutePath, 'raw') ;
            delete(newDataFileAbsolutePath) ;
            realCoefficientsAsRead = newDataFileAsStruct.header.AIScalingCoefficients ;
            % Verify that the shape of the coeffs array is correct
            self.verifyEqual( size(realCoefficientsAsRead), [nCoeffs nActiveAIChannels] ) ;

            % For every board I've ever tested the coeffs are the same
            % across channels.  This is likely because all the boards I've
            % tested are sequential-sampling, not simultaneous sampling.
            % Still, I guess I don't want to hard-code that in the test.
            % But let's do some sanity checks of the range of these params.
            termMin = [-0.02 10/2^15*(1-0.1) -1e-13 -1e-17]' ;
            termMax = [+0.02 10/2^15*(1+0.1) +1e-13 +1e-17]' ;
            for i=1:nCoeffs ,
                thisTerm = realCoefficientsAsRead(i,:) ;
                self.verifyTrue( all( (termMin(i)<=thisTerm) & (thisTerm<=termMax(i)) ) ) ;
            end
        end
        
        function testAppendingToManyOlderFiles(self)
            thisDirName=fileparts(mfilename('fullpath'));
            sourceFolderName = fullfile(thisDirName, 'folder_without_scaling_coeffs') ;
            
            % Test with a device name
            deviceName = 'Dev1' ;
            targetFolderName = tempname() ;
            isDryRun = true ;
            ws.addScalingToHDF5FilesRecursively(sourceFolderName, deviceName, targetFolderName, isDryRun) ;
            isDryRun = false ;
            deviceScalingCoefficientsFromDevice = ws.addScalingToHDF5FilesRecursively(sourceFolderName, deviceName, targetFolderName, isDryRun) ; 
            % Verify
            isAllWell = ws.verifyScalingOfHDF5FilesRecursivelyGivenCoeffs(sourceFolderName, deviceScalingCoefficientsFromDevice, targetFolderName) ;
            self.verifyTrue(isAllWell) ;
            
            % Test with a file name by first writing the necessary file
            scalingCoefficientsOutputFileName = [tempname() '.mat'] ;
            targetFolderName = tempname() ;
            ws.writeAnalogScalingCoefficientsToFile(deviceName, scalingCoefficientsOutputFileName);
            deviceScalingCoefficientsFromFile = ws.addScalingToHDF5FilesRecursively(sourceFolderName, scalingCoefficientsOutputFileName, targetFolderName, isDryRun) ;
            % Verify
            isAllWell = ws.verifyScalingOfHDF5FilesRecursivelyGivenCoeffs(sourceFolderName, deviceScalingCoefficientsFromFile, targetFolderName) ;
            self.verifyTrue(isAllWell) ;
            
            % Verify that coefficients written to file are correct
            self.verifyEqual(deviceScalingCoefficientsFromDevice, deviceScalingCoefficientsFromFile);
            
        end
        
        function testAppendingToManyOlderFilesRelativePath(self)
            thisDirName=fileparts(mfilename('fullpath'));
            originalDirName = pwd() ;
            cleanupObject = onCleanup( @()(cd(originalDirName)) ) ;
            cd(thisDirName) ;
            sourceFolderName = fullfile('../+hw/folder_without_scaling_coeffs') ;
            deviceName = 'Dev1' ;
            targetFolderName = tempname() ;
            deviceScalingCoefficients = ws.addScalingToHDF5FilesRecursively(sourceFolderName, deviceName, targetFolderName) ;        
            
            % Verify
            isAllWell = ws.verifyScalingOfHDF5FilesRecursivelyGivenCoeffs(sourceFolderName, deviceScalingCoefficients, targetFolderName) ;
            self.verifyTrue(isAllWell) ;
            %cd(originalDirName) ;
        end
        
        function testAppendingToManyOlderFilesRelativePath2(self)
            thisDirName=fileparts(mfilename('fullpath'));
            sourceFolderAbsolutePath = fullfile(thisDirName, 'folder_without_scaling_coeffs') ;
            deviceName = 'Dev1' ;
            targetFolderAbsolutePath = tempname() ;
            [targetFolderNameParent,targetFolderStem,targetFolderExt] = fileparts(targetFolderAbsolutePath) ;
            targetFolderName = [ targetFolderStem targetFolderExt ] ;
            originalDirName = pwd() ;
            cleanupObject = onCleanup( @()(cd(originalDirName)) ) ;
            cd(targetFolderNameParent) ;
            deviceScalingCoefficients = ws.addScalingToHDF5FilesRecursively(sourceFolderAbsolutePath, deviceName, targetFolderName) ;        
            
            % Verify
            isAllWell = ws.verifyScalingOfHDF5FilesRecursivelyGivenCoeffs(sourceFolderAbsolutePath, deviceScalingCoefficients, targetFolderAbsolutePath) ;
            self.verifyTrue(isAllWell) ;
            %cd(originalDirName) ;
        end
        
    end  % test methods
        
end  % classdef
