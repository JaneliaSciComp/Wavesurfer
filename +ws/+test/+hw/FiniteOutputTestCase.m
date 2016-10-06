classdef FiniteOutputTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1 (can be simulated, though).
    
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
        function testAnalog(self)
            taskName = 'Finite Analog Output Task' ;
            deviceNames = { 'Dev1' 'Dev1' } ;
            terminalIDs = [0 1] ;
            %channelNames = { 'ao0' 'ao1' } ;
            fs=20000;  % Hz
            isChannelInTask = true(size(terminalIDs)) ;
            theTask = ws.FiniteOutputTask('analog', taskName, deviceNames, terminalIDs, isChannelInTask, fs);
            %theTask.SampleRate = fs ;
            
            T = 1 ;  % s
            dt=1/fs;  % s
            t=(0:dt:(T-dt))';
            x=5*sin(2*pi*10*t);  % V
            y=5*cos(2*pi*10*t);  % V
            data=[x y];
            
            theTask.arm();
            theTask.ChannelData = data ;  % this should be OK to do after arming
            theTask.start();
            pause(1.1*T);
            theTask.stop();
            theTask.disarm();
            theTask=[]; %#ok<NASGU>

            self.verifyTrue(true);
        end  % function

        function testDigital(self)
            taskName = 'Finite Digital Output Task' ;
            deviceNames = { 'Dev1' 'Dev1' } ;
            terminalIDs = [0 1] ;
            %channelNames = { 'do0' 'do1' } ;
            isChannelInTask = true(size(terminalIDs)) ;
            fs=20000;  % Hz            
            theTask = ws.FiniteOutputTask('digital', taskName, deviceNames, terminalIDs, isChannelInTask, fs);
            %theTask.SampleRate = fs ;
            
            T = 1 ;  % s
            dt=1/fs;  % s
            t=(0:dt:(T-dt))';
            x=logical(sin(2*pi*10*t)>0);  % V
            y=logical(cos(2*pi*10*t)>0);  % V
            data=[x y];
            
            theTask.arm();
            theTask.ChannelData = data ;  % this should be OK to do after arming
            theTask.start();
            pause(1.1*T);
            theTask.stop();
            theTask.disarm();
            theTask=[]; %#ok<NASGU>

            self.verifyTrue(true);
        end  % function
    
    end  % test methods

end  % classdef
