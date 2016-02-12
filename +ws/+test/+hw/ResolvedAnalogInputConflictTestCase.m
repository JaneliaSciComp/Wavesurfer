classdef ResolvedAnalogInputConflictTestCase < matlab.unittest.TestCase
    
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
        function theTest(self)
            protocolOrMDFFileName = [] ;
            isCommandLineOnly = true ;             
            wsModel=wavesurfer(protocolOrMDFFileName, isCommandLineOnly) ;

            wsModel.Acquisition.addAnalogChannel() ;
            wsModel.Acquisition.addAnalogChannel() ;
            wsModel.Acquisition.setSingleAnalogTerminalID(2,0) ;  % this introduces a conflict
            try
                wsModel.play() ;
            catch me
                if isequal(me.identifier, 'wavesurfer:looperDidntGetReady') ,
                    % we expect this error, so ignore it
                else
                    rethrow(me) ;
                end
            end
            wsModel.Acquisition.setSingleAnalogTerminalID(2,1) ;  % this resolves the conflict
            wsModel.play() ;  % this errors, even though it shouldn't...
        end  % function
    end  % test methods

end  % classdef
