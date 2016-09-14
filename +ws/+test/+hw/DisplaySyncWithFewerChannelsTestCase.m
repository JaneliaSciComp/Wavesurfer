classdef DisplaySyncWithFewerChannelsTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, although can be
    % simulated.
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Type','Figure')) ;
            daqSystem = ws.dabs.ni.daqmx.System() ;
            ws.deleteIfValidHandle(daqSystem.tasks) ;
        end
    end
    
    methods (Test)
        function theTest(self)
            [wsModel,wsController] = wavesurfer() ;

            wsModel.Acquisition.addAnalogChannel() ;
            wsModel.Acquisition.addAnalogChannel() ;

            protocolFileName = fullfile(tempdir(),'three-channels-sdfkjsghdf.cfg') ;
            %wsController.saveProtocolFileGivenFileName(protocolFileName) ;
            wsController.fakeControlActuatedInTest('SaveProtocolGivenFileNameFauxControl', protocolFileName) ;
            
            wsModel.Acquisition.IsAnalogChannelMarkedForDeletion(3) = true ;
            wsModel.deleteMarkedAIChannels() ;

            wsModel.play() ;  % this blocks
            
            %wsController.openProtocolFileGivenFileName(protocolFileName) ;
            try
                source = [] ;
                event = [] ;
                wsController.OpenProtocolGivenFileNameFauxControlActuated(source,event,protocolFileName) ;
            catch exception
                indicesOfWarningPhrase = strfind(exception.identifier,'ws:warningsOccurred') ;
                isWarning = (~isempty(indicesOfWarningPhrase) && indicesOfWarningPhrase(1)==1) ;
                if isWarning ,
                    self.verifyTrue(false, 'Opening the protocol file threw a warning') ;  % will make test fail if opening the protocol threw a warning
                else
                    rethrow(exception) ;
                end
            end
            
            wsController.quit() ;
            wsController = [] ; %#ok<NASGU>
            wsModel = [] ; %#ok<NASGU>
           
            delete(protocolFileName) ;           
            
            self.verifyTrue(true) ;            
        end  % function
        
    end  % test methods

 end  % classdef
