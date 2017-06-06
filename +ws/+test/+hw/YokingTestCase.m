classdef YokingTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)
    
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
        function testPlayFromWS(self)
            wsModel = wavesurfer('--nogui') ;
            siMockProcess = ws.launchSIMockInOtherProcess() ;
            pause(5) ;  % wait for other process to start
            wsModel.IsYokedToScanImage = true ;
            wsModel.play() ;
            wsModel.IsYokedToScanImage = false ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ; 
        end  % function
        
        function testRecordFromWS(self)
            wsModel = wavesurfer('--nogui') ;
            siMockProcess = ws.launchSIMockInOtherProcess() ;
            pause(5) ;  % wait for other process to start
            wsModel.IsYokedToScanImage = true ;
            tempFilePath = tempname() ;
            [tempFolderPath, tempStem] = fileparts(tempFilePath) ;
            wsModel.Logging.FileLocation = tempFolderPath ;
            wsModel.Logging.FileBaseName = tempStem ;
            wsModel.Logging.IsOKToOverwrite = true ;
            wsModel.record() ;
            wsModel.IsYokedToScanImage = false ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ; 
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
        end  % function
        
        function testSavingAndOpeningOfUserSettingsFromWS(self)
            wsModel = wavesurfer('--nogui') ;            
            siMockProcess = ws.launchSIMockInOtherProcess() ;            
            pause(5) ;  % wait for other process to start            
            wsModel.IsYokedToScanImage = true ;            
            userSettingsFilePath = horzcat(tempname(), '.wsu') ;
            wsModel.saveUserFileGivenFileName(userSettingsFilePath) ;
            wsModel.openUserFileGivenFileName(userSettingsFilePath) ;
            wsModel.IsYokedToScanImage = false ;
            siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ;
        end  % function

        function testRecordMessageReceptionFromSI(self)
            wsModel = wavesurfer('--nogui') ;            
            wsModel.IsYokedToScanImage = true ;            
            pathToWavesurferRoot = ws.WavesurferModel.pathNamesThatNeedToBeOnSearchPath() ;
            process = System.Diagnostics.Process() ;
            process.StartInfo.FileName = 'matlab.exe' ;
            argumentsString = sprintf('-nojvm -nosplash -r "addpath(''%s''); sim = ws.SIMock(); sim.sendRecord(); pause(10); quit();', pathToWavesurferRoot) ;
            process.StartInfo.Arguments = argumentsString ;
            %process.StartInfo.WindowStyle = ProcessWindowStyle.Maximized;
            process.Start();
            %siMockProcess = ws.launchSIMockInOtherProcessAndSendMessagesBack() ;  %#ok<NASGU>
            pause(20) ;
            %process.CloseMainWindow() ;
            self.verifyTrue(true) ;
        end  % function                
        
        function testMessageReceptionFromSI(self)
            wsModel = wavesurfer('--nogui') ;            
            wsModel.IsYokedToScanImage = true ;            
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
            self.verifyTrue(true) ;
        end  % function                
        
        function testLightMessageReceptionFromSI(self)
            wsModel = wavesurfer('--nogui') ;            
            wsModel.IsYokedToScanImage = true ;            
            % Returns a dotnet System.Diagnostics.Process object
            pathToWavesurferRoot = ws.WavesurferModel.pathNamesThatNeedToBeOnSearchPath() ;
            siMockProcess = System.Diagnostics.Process() ;
            siMockProcess.StartInfo.FileName = 'matlab.exe' ;
            argumentsString = sprintf('-nojvm -nosplash -r "addpath(''%s''); sim = ws.SIMock(); sim.sendSomeMessages(); pause(10); quit();', pathToWavesurferRoot) ;
            siMockProcess.StartInfo.Arguments = argumentsString ;
            %process.StartInfo.WindowStyle = ProcessWindowStyle.Maximized;
            siMockProcess.Start();            
            %siMockProcess = ws.launchSIMockInOtherProcessAndSendMessagesBack() ;  %#ok<NASGU>
            pause(20) ;
            %siMockProcess.CloseMainWindow() ;
            self.verifyTrue(true) ;
        end  % function                
        
    end  % test methods

end  % classdef
