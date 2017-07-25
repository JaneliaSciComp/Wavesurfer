classdef UntimedDigitalOutputTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attachedF.  (Can be a
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
        function testWithOneTimedOneUntimed(self)
            isCommandLineOnly='--nogui';
            %thisDirName=fileparts(mfilename('fullpath'));            
            wsModel=wavesurfer(isCommandLineOnly);

            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAIChannel() ;
            wsModel.addAOChannel() ;
            wsModel.addDOChannel() ;
            wsModel.addDOChannel() ;
                           
            wsModel.AcquisitionSampleRate=20000;  % Hz
            wsModel.IsStimulationEnabled=true;
            wsModel.StimulationSampleRate=20000;  % Hz
            wsModel.IsDisplayEnabled=true;
            %wsModel.IsLoggingEnabled=false;
            wsModel.UserClassName='ws.examples.FlipDOFromSweepToSweep';

            nSweeps=5;
            wsModel.NSweepsPerRun=nSweeps;
            wsModel.SweepDuration = 1 ;  % s

%             % Make a pulse stimulus, add to the stimulus library
%             godzilla=wsModel.Stimulation.StimulusLibrary.addNewStimulus('SquarePulse');
%             godzilla.Name='Godzilla';
%             godzilla.Amplitude='1';  % V
%             godzilla.Delay='0.25';
%             godzilla.Duration='3.5';
% 
%             % make a map that puts the just-made pulse out of the first AO channel, add
%             % to stim library
%             map=wsModel.Stimulation.StimulusLibrary.addNewMap();
%             map.Name='Godzilla out first AO';
%             firstDoChannelName=wsModel.DOChannelNames{1};
%             map.addBinding(firstDoChannelName,godzilla);
% 
%             % make the new map the current sequence/map
%             wsModel.Stimulation.StimulusLibrary.SelectedOutputable=map;
            
            pause(1);
            wsModel.play();

%             dtBetweenChecks=1;  % s
%             maxTimeToWait=1.1*wsModel.SweepDuration*nSweeps;  % s
%             nTimesToCheck=ceil(maxTimeToWait/dtBetweenChecks);
%             for i=1:nTimesToCheck ,
%                 pause(dtBetweenChecks);
%                 if wsModel.NSweepsCompletedInThisRun>=nSweeps ,
%                     break
%                 end
%             end                   

            self.verifyEqual(wsModel.NSweepsCompletedInThisRun,nSweeps);            
        end  % function

    end  % test methods

 end  % classdef
