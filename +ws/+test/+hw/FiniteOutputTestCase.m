classdef FiniteOutputTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1 (can be simulated, though).
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.clearDuringTests
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.clearDuringTests
        end
    end

    methods (Test)        
        function testAnalogSingleDevice(self)
            taskName = 'Finite Analog Output Task' ;
            primaryDeviceName = 'Dev1' ;
            isPrimaryDeviceAPXIDevice = false ;
            deviceNamePerChannel = { 'Dev1' 'Dev1' } ;
            terminalIDPerChannel = [0 1] ;
            sampleRate = 20000 ;  % Hz
            keystoneTaskType = '' ;
            keystoneTaskDevice = 'Dev1' ;
            triggerDeviceNameIfKeystoneAndPrimary = '' ;
            triggerPFIIDIfKeystoneAndPrimary = [] ;
            triggerEdgeIfKeystoneAndPrimary = 'rising' ;
            theTask = ws.AOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, deviceNamePerChannel, terminalIDPerChannel, ...
                                sampleRate, ...
                                keystoneTaskType, keystoneTaskDevice, ...
                                triggerDeviceNameIfKeystoneAndPrimary, triggerPFIIDIfKeystoneAndPrimary, triggerEdgeIfKeystoneAndPrimary) ;
            
            T = 1 ;  % s
            dt = 1/sampleRate ;  % s
            t = (0:dt:(T-dt))' ;
            x = 5*sin(2*pi*10*t) ;  % V
            y = 5*cos(2*pi*10*t) ;  % V
            data = [x y] ;
            
            theTask.setChannelData(data) ;
            theTask.start() ;
            pause(1.1*T) ;
            theTask.stop() ;
            theTask = [] ; %#ok<NASGU>

            self.verifyTrue(true);
        end  % function

        function testAnalogMultipleDevices(self)
            taskName = 'Finite Analog Output Task' ;
            primaryDeviceName = 'Dev1' ;
            isPrimaryDeviceAPXIDevice = false ;
            deviceNamePerChannel = { 'Dev1' 'Dev2' } ;
            terminalIDPerChannel = [0 0] ;
            sampleRate = 20000 ;  % Hz
            keystoneTaskType = '' ;
            keystoneTaskDevice = 'Dev1' ;
            triggerDeviceNameIfKeystoneAndPrimary = '' ;
            triggerPFIIDIfKeystoneAndPrimary = [] ;
            triggerEdgeIfKeystoneAndPrimary = 'rising' ;
            theTask = ws.AOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, deviceNamePerChannel, terminalIDPerChannel, ...
                                sampleRate, ...
                                keystoneTaskType, keystoneTaskDevice, ...
                                triggerDeviceNameIfKeystoneAndPrimary, triggerPFIIDIfKeystoneAndPrimary, triggerEdgeIfKeystoneAndPrimary) ;
            
            T = 1 ;  % s
            dt = 1/sampleRate ;  % s
            t = (0:dt:(T-dt))' ;
            x = 5*sin(2*pi*10*t) ;  % V
            y = 5*cos(2*pi*10*t) ;  % V
            data = [x y] ;
            
            theTask.setChannelData(data) ;
            theTask.start() ;
            pause(1.1*T) ;
            theTask.stop() ;
            theTask = [] ; %#ok<NASGU>

            self.verifyTrue(true);
        end  % function

        function testDigital(self)
            taskName = 'Finite Digital Output Task' ;
            primaryDeviceName = 'Dev1' ;
            isPrimaryDeviceAPXIDevice = false ;
            terminalIDs = [0 1] ;
            sampleRate = 20000 ;  % Hz            
            keystoneTask = '' ;
            triggerDeviceNameIfKeystone = '' ;
            triggerPFIIDIfKeystone = [] ;
            triggerEdgeIfKeystone = 'rising' ;
            theTask = ws.DOTask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, terminalIDs, ...
                                sampleRate, ...
                                keystoneTask, triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone) ;
            
            T = 1 ;  % s
            dt = 1/sampleRate ;  % s
            t = (0:dt:(T-dt))' ;
            x = logical(sin(2*pi*10*t)>0) ;  % V
            y = logical(cos(2*pi*10*t)>0) ;  % V
            data = [x y] ;
            
            theTask.setChannelData(data) ;
            theTask.start() ;
            pause(1.1*T) ;
            theTask.stop() ;
            theTask = [] ; %#ok<NASGU>

            self.verifyTrue(true);
        end  % function
    
    end  % test methods

end  % classdef
