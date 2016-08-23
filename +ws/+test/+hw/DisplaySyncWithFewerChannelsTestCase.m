classdef DisplaySyncWithFewerChannelsTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, although can be
    % simulated.
    
    methods (Test)
        function theTest(self)
            isCommandLineOnly = false ;
            [wsModel,wsController] = wavesurfer([],isCommandLineOnly) ;

            wsModel.Acquisition.addAnalogChannel() ;
            wsModel.Acquisition.addAnalogChannel() ;

            protocolFileName = fullfile(tempdir(),'three-channels-sdfkjsghdf.cfg') ;
            wsController.saveProtocolFileGivenFileName(protocolFileName) ;

            wsModel.Acquisition.IsAnalogChannelMarkedForDeletion(3) = true ;
            wsModel.deleteMarkedAIChannels() ;

            wsModel.play() ;  % this blocks

            inv([1 1; 1 1+1e-16]) ;  % this sets lastwarn() to a known state
            
            wsController.openProtocolFileGivenFileName(protocolFileName) ;

            [~, msgid] = lastwarn() ;
            
            if isequal(msgid, 'MATLAB:callback:error') ,
                self.verifyTrue(false, 'Opening the protocol file threw a warning') ;  % will make test fail if opening the protocol threw a warning
            end
            
            wsController.quit() ;
            wsController = [] ; %#ok<NASGU>
            wsModel = [] ; %#ok<NASGU>
           
            delete(protocolFileName) ;           
            
            self.verifyTrue(true) ;            
        end  % function
        
    end  % test methods

 end  % classdef
