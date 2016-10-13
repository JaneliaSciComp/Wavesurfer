classdef CounterTriggerHangTestCase < matlab.unittest.TestCase
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            delete(findall(0,'Type','figure')) ;            
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Type','figure')) ;            
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end

    methods (Test)
        function theTest(self)            
            wsModel = wavesurfer('--nogui') ;
            wsModel.NSweepsPerRun = 3 ;
            wsModel.Stimulation.IsEnabled = true ;
            wsModel.addCounterTrigger() ;
            wsModel.setTriggerProperty('counter', 1, 'RepeatCount', 2) ;
            wsModel.setTriggerProperty('counter', 1, 'Interval', 1.5) ;            
            wsModel.StimulationUsesAcquisitionTrigger = false ;
            wsModel.StimulationTriggerIndex = 2 ;  % this should be the newly-defined counter trigger
            didTimerCallbackFire = false ;            
            
            function timerCallback(source, event)  %#ok<INUSD>
                % The timer callback.  If WS is working properly, the timer
                % will be stopped before this fires at all.
                fprintf('timerCallback() fired.\n') ;
                didTimerCallbackFire = true ;
                wsModel.stop() ;
            end            
            
            timerToStopWavesurfer = timer('ExecutionMode', 'fixedDelay', ...
                                          'TimerFcn',@timerCallback, ...
                                          'StartDelay',20, ...
                                          'Period', 20);  % do this repeatedly in case first is missed
            start(timerToStopWavesurfer) ;
            wsModel.play() ;  % this hangs at present, but if things work properly, this should return after ~ 3 seconds
            stop(timerToStopWavesurfer) ;  % stop the timer
            delete(timerToStopWavesurfer) ;            
            self.verifyFalse(didTimerCallbackFire) ;
        end  % function
    end  % test methods

end  % classdef
