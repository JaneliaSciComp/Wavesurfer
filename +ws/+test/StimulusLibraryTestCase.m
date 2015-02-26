classdef StimulusLibraryTestCase < matlab.unittest.TestCase
    
    methods
        function stimulusLibrary=createPopulatedStimulusLibrary(self)
            stimulusLibrary=ws.stimulus.StimulusLibrary();            
            
            stimulus1=stimulusLibrary.addNewStimulus('Chirp');
            %stimulus1=ws.stimulus.ChirpStimulus('InitialFrequency',1.4545, ...
            %                                       'FinalFrequency',45.3);  
            stimulus1.Delay=0.11;
            stimulus1.Amplitude='6.28';
            stimulus1.Name='Melvin';
            stimulus1.Delegate.InitialFrequency = 1.4545 ;
            stimulus1.Delegate.FinalFrequency = 45.3 ;
            
            stimulus2=stimulusLibrary.addNewStimulus('SquarePulse');
            % stimulus2=ws.stimulus.SquarePulseStimulus();
            stimulus2.Delay=0.12;
            stimulus2.Amplitude='6.29';
            stimulus2.Name='Bill';
            
            stimulus3=stimulusLibrary.addNewStimulus('Sine');
            %stimulus3=ws.stimulus.SineStimulus('Frequency',1.47);
            stimulus3.Delay=0.4;
            stimulus3.Amplitude='-2.98';
            stimulus3.Name='Elmer';
            stimulus3.Delegate.Frequency = 1.47 ;
            
            stimulus4=stimulusLibrary.addNewStimulus('Ramp');
            %stimulus4=ws.stimulus.RampStimulus();
            stimulus4.Delay=0.151;
            stimulus4.Amplitude='i';
            stimulus4.Name='Foghorn Leghorn';
            
            stimulus5=stimulusLibrary.addNewStimulus('Ramp');
            %stimulus5=ws.stimulus.RampStimulus();
            stimulus5.Delay=0.171;
            stimulus5.Amplitude=-9;
            stimulus5.Name='Unreferenced Stimulus';
            
            %stimuli={stimulus1 stimulus2 stimulus3 stimulus4 stimulus5};

            %stimulusMap1=ws.stimulus.StimulusMap('Name','Lucy the Map', 'Duration', 1.01);
            stimulusMap1=stimulusLibrary.addNewMap();
            stimulusMap1.Name = 'Lucy the Map' ;
            stimulusMap1.Duration = 1.01 ;
            stimulusMap1.addBinding('ao0',stimulus1,1.01);
            stimulusMap1.addBinding('ao1',stimulus2,1.02);

            %stimulusMap2=ws.stimulus.StimulusMap('Name','Linus the Map', 'Duration', 2.04);
            stimulusMap2=stimulusLibrary.addNewMap();
            stimulusMap2.Name = 'Linus the Map' ;
            stimulusMap2.Duration = 2.04 ;            
            stimulusMap2.addBinding('ao0',stimulus3,2.01);
            stimulusMap2.addBinding('ao1',stimulus4,2.02);
            
            %maps={stimulusMap1 stimulusMap2};
            
            %stimulusSequence=ws.stimulus.StimulusSequence('Name','Cyclotron');
            stimulusSequence=stimulusLibrary.addNewSequence();
            stimulusSequence.Name = 'Cyclotron' ;
            self.verifyTrue(stimulusSequence.isLiveAndSelfConsistent());
            stimulusSequence.addMap(stimulusMap1);
            self.verifyTrue(stimulusSequence.isLiveAndSelfConsistent());
            stimulusSequence.addMap(stimulusMap2);            
            self.verifyTrue(stimulusSequence.isLiveAndSelfConsistent());

            %stimulusSequence2=ws.stimulus.StimulusSequence('Name','Megatron');
            stimulusSequence2=stimulusLibrary.addNewSequence();
            stimulusSequence2.Name = 'Megatron' ;
            self.verifyTrue(stimulusSequence.isLiveAndSelfConsistent());
            stimulusSequence2.addMap(stimulusMap2);
            self.verifyTrue(stimulusSequence.isLiveAndSelfConsistent());
            stimulusSequence2.addMap(stimulusMap1);            
            self.verifyTrue(stimulusSequence.isLiveAndSelfConsistent());
            
            %cycles={stimulusSequence stimulusSequence2};
            
            %stimulusLibrary=ws.stimulus.StimulusLibrary();
            %stimulusLibrary.add(stimuli);            
            %stimulusLibrary.add(maps);
            %stimulusLibrary.add(cycles);
        end
    end

end
