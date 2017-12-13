classdef FastProtocolSpeedTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  (Can be a
    % simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.reset() ;
        end
    end
    
    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Style','Figure')) ;
            ws.reset() ;
        end
    end
    
    methods (Test)
        function testFastProtocolSpeed(self)
            [wsModel, wsController] = wavesurfer() ;            
            % Load 1 cfg file with 6 electrodes into fast protocol
            %fastProtocol = wsModel.FastProtocols{1};
            wsModel.ArePreferencesWritable = false ;            
            thisDirName = fileparts(mfilename('fullpath')) ;
            wsModel.setFastProtocolProperty(1, ...
                                            'ProtocolFileName', ...
                                            fullfile(thisDirName, 'folder_for_fast_protocol_testing/Six Electrodes.cfg')) ;
            %pressedButtonHandle = wsController.Figure.FastProtocolButtons(1) ;
            %wsController.FastProtocolButtonsActuated(pressedButtonHandle) ; % First time loading is always relatively fast
            ws.fakeControlActuationInTestBang(wsController, 'FastProtocolButtons', 1) ;  % 1 means the first button among the FP buttons
            ticId = tic() ;             
            %wsController.FastProtocolButtonsActuated(pressedButtonHandle) ;  % Load it again to check the speed
            ws.fakeControlActuationInTestBang(wsController, 'FastProtocolButtons', 1) ;  % 1 means the first button among the FP buttons
            timeToComplete = toc(ticId)
            
            % Should take less than four seconds if in correct version, and more than 20 seconds if older version
            self.verifyTrue(timeToComplete<4) ;
            
            wsController.quit() ;
        end  % function
        
    end  % test methods
    
end  % classdef
