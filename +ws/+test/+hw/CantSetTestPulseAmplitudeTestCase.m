classdef CantSetTestPulseAmplitudeTestCase < matlab.unittest.TestCase
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
        function theTest(self)
            %isCommandLineOnly='--nogui';
            %thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer('--nogui') ;

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addDIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;
            wsModel.addDOChannel() ;

            %
            % Now check that we can still test pulse
            %
            
            % Set up a single electrode
            wsModel.addNewElectrode();
                        
            % Try to set the TP amplitude
            currentAmplitude = wsModel.getTestPulseElectrodeProperty('TestPulseAmplitude') ;
            if currentAmplitude==1 ,
                targetAmplitude=10 ;
            else
                targetAmplitude=1 ;
            end
            wsModel.setTestPulseElectrodeProperty('TestPulseAmplitude', targetAmplitude) ;
            amplitudeAfterSetting = wsModel.getTestPulseElectrodeProperty('TestPulseAmplitude') ;
            
            self.verifyEqual(amplitudeAfterSetting,targetAmplitude) ;                
        end  % function
        
    end  % test methods

 end  % classdef
