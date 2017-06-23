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
            currentAmplitude = wsModel.Ephys.TestPulseElectrodeAmplitude ;
            if currentAmplitude==1 ,
                targetAmplitude=10 ;
            else
                targetAmplitude=1 ;
            end
            wsModel.Ephys.TestPulseElectrodeAmplitude = targetAmplitude ;
            amplitudeAfterSetting = wsModel.Ephys.TestPulseElectrodeAmplitude ;
            
            self.verifyEqual(amplitudeAfterSetting,targetAmplitude) ;                
        end  % function

        
        
    end  % test methods

 end  % classdef
