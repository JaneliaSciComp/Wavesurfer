classdef YokingTestCase < matlab.unittest.TestCase
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
        function testPlayFromWS(self)
            wsModel = wavesurfer('--nogui') ;
            siMockProcess = ws.launchSIMockInOtherProcess() ;
            pause(5) ;  % wait for other process to start
            wsModel.setIsYokedToScanImageForTesting_(true) ;
            wsModel.play() ;
            wsModel.setIsYokedToScanImageForTesting_(false) ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ; 
            wsModel.delete() ;
        end  % function
        
        function testRecordFromWS(self)
            wsModel = wavesurfer('--nogui') ;
            siMockProcess = ws.launchSIMockInOtherProcess() ;
            pause(5) ;  % wait for other process to start
            wsModel.setIsYokedToScanImageForTesting_(true) ;
            tempFilePath = tempname() ;
            [tempFolderPath, tempStem] = fileparts(tempFilePath) ;
            wsModel.DataFileLocation = tempFolderPath ;
            wsModel.DataFileBaseName = tempStem ;
            wsModel.IsOKToOverwriteDataFile = true ;
            wsModel.record() ;
            wsModel.setIsYokedToScanImageForTesting_(false) ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ; 
            wsModel.delete() ;
        end  % function

        function testSavingAndOpeningOfProtocolFromWS(self)
            wsModel = wavesurfer('--nogui') ;
            wsModel.ArePreferencesWritable = false ;
            siMockProcess = ws.launchSIMockInOtherProcess() ;
            pause(5) ;  % wait for other process to start
            wsModel.setIsYokedToScanImageForTesting_(true) ;  
            protocolFilePath = horzcat(tempname(), '.wsp') ;
            wsModel.saveProtocolFileGivenFileName(protocolFilePath) ;
            wsModel.openProtocolFileGivenFileName(protocolFilePath) ;
            wsModel.setIsYokedToScanImageForTesting_(false) ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ; 
            wsModel.delete() ;
        end  % function
        
        function testSavingAndOpeningOfUserSettingsFromWS(self)
            wsModel = wavesurfer('--nogui') ;            
            wsModel.ArePreferencesWritable = false ;
            siMockProcess = ws.launchSIMockInOtherProcess() ;            
            pause(5) ;  % wait for other process to start            
            userSettingsFilePath = horzcat(tempname(), '.wsu') ;
            wsModel.saveUserFileGivenFileName(userSettingsFilePath) ;
            wsModel.openUserFileGivenFileName(userSettingsFilePath) ;
            wsModel.setIsYokedToScanImageForTesting_(false) ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ;
            wsModel.delete() ;
        end  % function

        function testMessageReceptionFromSI(self)
            wsModel = wavesurfer('--nogui') ;            
            %wsModel.setIsYokedToScanImageForTesting_(true) ;            
            % Returns a dotnet System.Diagnostics.Process object
            pathToWavesurferRoot = ws.WavesurferModel.pathNamesThatNeedToBeOnSearchPath() ;
            args = System.Environment.GetCommandLineArgs;
            path_to_exe = char(args(1)) ;
            siMockProcess = System.Diagnostics.Process() ;
            siMockProcess.StartInfo.FileName = path_to_exe ;  % want same matlab we're runnning in, not some other installed version
            argumentsString = sprintf('-nojvm -nosplash -r "addpath(''%s''); sim = ws.SIMock(); sim.sendLotsOfMessages(); pause(10); quit();', pathToWavesurferRoot) ;
            siMockProcess.StartInfo.Arguments = argumentsString ;
            %process.StartInfo.WindowStyle = ProcessWindowStyle.Maximized;
            siMockProcess.Start();            
            %siMockProcess = ws.launchSIMockInOtherProcessAndSendMessagesBack() ;  %#ok<NASGU>
            pause(20) ;
            %siMockProcess.CloseMainWindow() ;
            
            % Wait to be done with the first run
            didPerformFirstRunAndReturnToIdleness = false ;
            for i=1:100 ,
                if isequal(wsModel.State, 'idle') && wsModel.NRunsCompleted>=1 ,
                    didPerformFirstRunAndReturnToIdleness = true ;
                    break
                end
                pause(2) ;
            end
            self.verifyTrue(didPerformFirstRunAndReturnToIdleness) ;            
            
            % Wait to be done with the second run
            didPerformSecondRunAndReturnToIdleness = false ;
            for i=1:100 ,
                if isequal(wsModel.State, 'idle') && wsModel.NRunsCompleted>=2 ,
                    didPerformSecondRunAndReturnToIdleness = true ;
                    break
                end
                pause(2) ;
            end
            self.verifyTrue(didPerformSecondRunAndReturnToIdleness) ;            
            
            % Wait for disconnect
            didDisconnect = false ;
            for i=1:100 ,
                if ~wsModel.IsYokedToScanImage ,
                    didDisconnect = true ;
                    break
                end
                pause(2) ;
            end            
            self.verifyTrue(didDisconnect) ;            
            
            % Check that a few things are as we set them
            self.verifyTrue(wsModel.DoIncludeDateInDataFileName) ;
            self.verifyTrue(wsModel.DoIncludeSessionIndexInDataFileName) ;
            self.verifyEqual(wsModel.SessionIndex, 7) ;
            wsModel.delete() ;
        end  % function
        
        function testFECDeleting(self)
            fecCountBefore = ws.FileExistenceCheckerManager.getShared().Count ;
            wsModel = wavesurfer('--nogui') ;
            wsModel.setIsYokedToScanImageForTesting_(true) ;  % should create a FEC
            fecCountDuring = ws.FileExistenceCheckerManager.getShared().Count ;
            self.verifyEqual(fecCountBefore+1, fecCountDuring) ;
            wsModel.delete() ;
            fecCountAfter = ws.FileExistenceCheckerManager.getShared().Count ;
            self.verifyEqual(fecCountBefore, fecCountAfter) ;
        end  % function
        
    end  % test methods

end  % classdef
