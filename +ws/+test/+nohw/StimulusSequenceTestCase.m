classdef StimulusSequenceTestCase < matlab.unittest.TestCase
    
    properties
        DefaultLibrary
        DefaultSequence
        DefaultMap1
        DefaultMap2
    end
    
    methods (Test)
        function testContainsElement(self)
            self.verifyTrue(self.DefaultSequence.containsMap(self.DefaultMap1), 'The sequence does contain the specified element.');
            self.verifyTrue(self.DefaultSequence.containsMap(self.DefaultMap2), 'The sequence does contain the specified element.');
            
            map3 = self.DefaultLibrary.addNewMap();
            self.verifyFalse(self.DefaultSequence.containsMap(map3), 'The sequence does not contain the specified element.');
        end
    end
    
    methods (TestMethodSetup)
        function createDefaultSequence(self)
            stimLib = ws.stimulus.StimulusLibrary([]);  % no parent
            
            %st1 = ws.stimulus.SquarePulseTrainStimulus('PulseDuration', 0.25, 'Period', 0.5);
            st1 = stimLib.addNewStimulus('SquarePulseTrain');
            st1.DCOffset = 0;
            st1.Delegate.Period = 0.5;  % s
            st1.Delegate.PulseDuration = 0.25;  % s
            
            %st2 = ws.stimulus.SquarePulseTrainStimulus('PulseDuration', 0.25, 'Period', 0.5);
            st2 = stimLib.addNewStimulus('SquarePulseTrain');
            st2.DCOffset = 0;
            st2.Delegate.Period = 0.5;  % s
            st2.Delegate.PulseDuration = 0.25;  % s
            
            st3 = stimLib.addNewStimulus('SquarePulse');
            st3.Duration=0.30;
            st3.Amplitude=0.75;
            st3.DCOffset = 0;
            
            map1 = stimLib.addNewMap();
            map1.addBinding('ch1', st1);
            map1.addBinding('ch2', st2);
            map1.addBinding('ch3', st3);
            
            map2 = stimLib.addNewMap();
            map2.addBinding('ch1', st2);
            map2.addBinding('ch2', st3);
            map2.addBinding('ch3', st1);
            
            sequence = stimLib.addNewSequence();
            sequence.addMap(map1);
            sequence.addMap(map2);
           
            self.DefaultLibrary=stimLib;
            self.DefaultSequence = sequence;
            self.DefaultMap1 = map1;
            self.DefaultMap2 = map2;
        end
    end
    
    methods (TestMethodTeardown)
        function removeDefaultSequence(self)
            self.DefaultMap1 = [];
            self.DefaultMap2 = [];
            self.DefaultSequence = [];
            self.DefaultLibrary=[];
        end
    end
end
