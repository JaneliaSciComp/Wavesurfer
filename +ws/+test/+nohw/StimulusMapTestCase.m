classdef StimulusMapTestCase < matlab.unittest.TestCase
    
    properties
        DefaultLibrary
        DefaultMap
        DefaultStim1
        DefaultStim2
    end
    
    methods (Test)
        function testContainsStimuli(self)
            self.verifyTrue(self.DefaultMap.containsStimulus(self.DefaultStim1), 'The map does contain the specified stimulus.');
            self.verifyTrue(self.DefaultMap.containsStimulus(self.DefaultStim2), 'The map does contain the specified stimulus.');
            
            st3 = self.DefaultLibrary.addNewStimulus('Chirp');
            %st1 = ws.stimulus.ChirpStimulus();
            self.verifyFalse(self.DefaultMap.containsStimulus(st3), 'The map does not contain the specified stimulus.');
            
            self.verifyEqual(self.DefaultMap.containsStimulus({self.DefaultStim1, st3, self.DefaultStim2, st3, st3}), ...
                [true false true false false], 'Incorrect output for vector containsStimlus.');
        end
        
        function testGetData(self)
            isChannelAnalog = [true true] ;
            data = self.DefaultMap.calculateSignals(100,{'ch1' 'ch2'},isChannelAnalog);
            self.verifyTrue(all(size(data) == [100 2]), 'Incorrect data size.');
        end
    end
    
    methods (TestMethodSetup)
        function createDefaultMap(self)
            stimLib = ws.stimulus.StimulusLibrary();            
            
            st1 = stimLib.addNewStimulus('SquarePulseTrain');
            st1.DCOffset = 0;
            st1.Delegate.Period = 0.5;  % s
            st1.Delegate.PulseDuration = 0.25;  % s
            
            %st2 = ws.stimulus.SquarePulseTrainStimulus('PulseDuration', 0.25, 'Period', 0.5);
            st2 = stimLib.addNewStimulus('SquarePulseTrain');
            st2.DCOffset = 0;
            st2.Delegate.Period = 0.5;  % s
            st2.Delegate.PulseDuration = 0.25;  % s
            
            map = stimLib.addNewMap();
            map.addBinding('ch1', st1);
            map.addBinding('ch2', st2);

            self.DefaultLibrary=stimLib;
            self.DefaultMap = map;
            self.DefaultStim1 = st1;
            self.DefaultStim2 = st2;
        end
    end
    
    methods (TestMethodTeardown)
        function removeDefaultMap(self)
            self.DefaultStim1 = [];
            self.DefaultStim2 = [];
            self.DefaultMap = [];
            self.DefaultLibrary=[];
        end
    end
end
