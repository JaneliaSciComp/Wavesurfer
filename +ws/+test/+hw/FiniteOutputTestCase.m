classdef FiniteOutputTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, as Dev1 (can be simulated, though).
    
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
        function testAnalog(self)
            taskName = 'Finite Analog Output Task' ;
            physicalChannelNames = { 'Dev1/ao0' 'Dev1/ao1' } ;
            channelNames = { 'ao0' 'ao1' } ;
            theTask = ws.ni.FiniteOutputTask([],'analog', taskName, physicalChannelNames, channelNames);
            fs=20000;  % Hz
            theTask.SampleRate = fs ;
            
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
            physicalChannelNames = { 'Dev1/line0' 'Dev1/line1' } ;
            channelNames = { 'do0' 'do1' } ;
            theTask = ws.ni.FiniteOutputTask([],'digital', taskName, physicalChannelNames, channelNames);
            fs=20000;  % Hz
            theTask.SampleRate = fs ;
            
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
