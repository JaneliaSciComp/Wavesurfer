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
            wsModel.IsYokedToScanImage = true ;
            wsModel.play() ;
            wsModel.IsYokedToScanImage = false ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ; 
            wsModel.delete() ;
        end  % function
        
        function testRecordFromWS(self)
            wsModel = wavesurfer('--nogui') ;
            siMockProcess = ws.launchSIMockInOtherProcess() ;
            pause(5) ;  % wait for other process to start
            wsModel.IsYokedToScanImage = true ;
            tempFilePath = tempname() ;
            [tempFolderPath, tempStem] = fileparts(tempFilePath) ;
            wsModel.DataFileLocation = tempFolderPath ;
            wsModel.DataFileBaseName = tempStem ;
            wsModel.IsOKToOverwriteDataFile = true ;
            wsModel.record() ;
            wsModel.IsYokedToScanImage = false ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ; 
            wsModel.delete() ;
        end  % function

        function testSavingAndOpeningOfProtocolFromWS(self)
            wsModel = wavesurfer('--nogui') ;
            siMockProcess = ws.launchSIMockInOtherProcess() ;
            pause(5) ;  % wait for other process to start
            wsModel.IsYokedToScanImage = true ;  
            protocolFilePath = horzcat(tempname(), '.wsp') ;
            wsModel.saveProtocolFileGivenFileName(protocolFilePath) ;
            wsModel.openProtocolFileGivenFileName(protocolFilePath) ;
            wsModel.IsYokedToScanImage = false ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ; 
            wsModel.delete() ;
        end  % function
        
        function testSavingAndOpeningOfUserSettingsFromWS(self)
            wsModel = wavesurfer('--nogui') ;            
            siMockProcess = ws.launchSIMockInOtherProcess() ;            
            pause(5) ;  % wait for other process to start            
            userSettingsFilePath = horzcat(tempname(), '.wsu') ;
            wsModel.saveUserFileGivenFileName(userSettingsFilePath) ;
            wsModel.openUserFileGivenFileName(userSettingsFilePath) ;
            wsModel.IsYokedToScanImage = false ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ;
            wsModel.delete() ;
        end  % function

        function testMessageReceptionFromSI(self)
            wsModel = wavesurfer('--nogui') ;            
            %wsModel.IsYokedToScanImage = true ;            
            % Returns a dotnet System.Diagnostics.Process object
            pathToWavesurferRoot = ws.WavesurferModel.pathNamesThatNeedToBeOnSearchPath() ;
            siMockProcess = System.Diagnostics.Process() ;
            siMockProcess.StartInfo.FileName = 'matlab.exe' ;
            argumentsString = sprintf('-nojvm -nosplash -r "addpath(''%s''); sim = ws.SIMock(); sim.sendLotsOfMessages(); pause(10); quit();', pathToWavesurferRoot) ;
            siMockProcess.StartInfo.Arguments = argumentsString ;
            %process.StartInfo.WindowStyle = ProcessWindowStyle.Maximized;
            siMockProcess.Start();            
            %siMockProcess = ws.launchSIMockInOtherProcessAndSendMessagesBack() ;  %#ok<NASGU>
            pause(20) ;
            %siMockProcess.CloseMainWindow() ;
            
            % Spin-wait to be done
            didPerformAllSweepsAndReturnToIdleness = false ;
            for i=1:10 ,
                if isequal(wsModel.State, 'idle') && wsModel.NextSweepIndex==4 ,
                    didPerformAllSweepsAndReturnToIdleness = true ;
                    break
                end
                pause(2) ;
            end
            self.verifyTrue(didPerformAllSweepsAndReturnToIdleness) ;            
            
            % Spin-wait for disconnect
            didDisconnect = false ;
            for i=1:10 ,
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
            wsModel.IsYokedToScanImage = true ;  % should create a FEC
            fecCountDuring = ws.FileExistenceCheckerManager.getShared().Count ;
            self.verifyEqual(fecCountBefore+1, fecCountDuring) ;
            wsModel.delete() ;
            fecCountAfter = ws.FileExistenceCheckerManager.getShared().Count ;
            self.verifyEqual(fecCountBefore, fecCountAfter) ;
        end  % function
        
    end  % test methods

end  % classdef
