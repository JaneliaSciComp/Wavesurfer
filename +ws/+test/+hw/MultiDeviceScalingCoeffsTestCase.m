classdef MultiDeviceScalingCoeffsTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI DAQ attached, as Dev1, and one as
    % Dev2.  And both need to be not-synchronous-sampling devices.
    
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
            wsModel = wavesurfer('--nogui') ;

            % Add four more AI channels
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;

            % Set the device, terminal for each channel
            wsModel.setSingleAIChannelDeviceName(1, 'Dev1') ;
            wsModel.setSingleAIChannelTerminalID(1, 0) ;
            wsModel.setSingleAIChannelDeviceName(2, 'Dev2') ;
            wsModel.setSingleAIChannelTerminalID(2, 0) ;
            wsModel.setSingleAIChannelDeviceName(3, 'Dev2') ;
            wsModel.setSingleAIChannelTerminalID(3, 1) ;
            wsModel.setSingleAIChannelDeviceName(4, 'Dev1') ;
            wsModel.setSingleAIChannelTerminalID(4, 1) ;
            wsModel.setSingleAIChannelDeviceName(5, 'Dev2') ;
            wsModel.setSingleAIChannelTerminalID(5, 2) ;
            
            % Play, so the scaling coeffs get set
            wsModel.play() ;
            
            % Get the scaling coeffs
            scalingCoefficients = wsModel.AIScalingCoefficients ;
            
            % All the Dev1 coeffs should be equal, and all the Dev2 coeffs
            isDev1 = logical([1 0 0 1 0]) ;
            isDev2 = ~isDev1 ;
            dev1ScalingCoefficients = scalingCoefficients(:,isDev1) ;
            dev2ScalingCoefficients = scalingCoefficients(:,isDev2) ;

            % Make sure things are the right size
            self.verifySize(dev1ScalingCoefficients, [4 2]) ;
            self.verifySize(dev2ScalingCoefficients, [4 3]) ;            
            
            % Make sure all columns are identical
            % Technically, this depends on both devices being not-synchronous-sampling
            % devices.  But most devices are this way.
            self.verifyTrue(all(all(diff(dev1ScalingCoefficients,[],2)==0))) ;
            self.verifyTrue(all(all(diff(dev2ScalingCoefficients,[],2)==0))) ;
        end  % function        
    end  % test methods
end  % classdef
