classdef StimulusLibraryTestCase < matlab.unittest.TestCase    
    methods (Static)
        function stimulusLibrary = createPopulatedStimulusLibrary()
            stimulusLibrary = ws.StimulusLibrary() ;  % no parent
            stimulusLibrary.populateForTesting() ;
            %ws.test.StimulusLibraryTestCase.populateStimulusLibraryBang(stimulusLibrary) ;
        end  % function        
        
%         function populateStimulusLibraryBang(stimulusLibrary)
% %             stimulusLibrary=ws.StimulusLibrary([]);  % no parent
%             
% %             stimulus1=stimulusLibrary.addNewStimulus('Chirp');
% %             stimulus1.Delay=0.11;
% %             stimulus1.Amplitude='6.28';
% %             stimulus1.Name='Melvin';
% %             stimulus1.Delegate.InitialFrequency = 1.4545 ;
% %             stimulus1.Delegate.FinalFrequency = 45.3 ;
%             
%             stimulus1Index = stimulusLibrary.addNewStimulus() ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'TypeString', 'Chirp') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'Name', 'Melvin') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'Amplitude', '6.28') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'Delay', 0.11) ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'InitialFrequency', 1.4545) ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'FinalFrequency', 45.3) ;            
%             
% %             stimulus2=stimulusLibrary.addNewStimulus('SquarePulse');
% %             stimulus2.Delay=0.12;
% %             stimulus2.Amplitude='6.29';
% %             stimulus2.Name='Bill';
%             
%             stimulus2Index = stimulusLibrary.addNewStimulus() ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'TypeString', 'SquarePulse') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'Name', 'Bill') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'Amplitude', '6.29') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'Delay', 0.12) ;
%             
% %             stimulus3=stimulusLibrary.addNewStimulus('Sine');
% %             stimulus3.Delay=0.4;
% %             stimulus3.Amplitude='-2.98';
% %             stimulus3.Name='Elmer';
% %             stimulus3.Delegate.Frequency = 1.47 ;
%             
%             stimulus3Index = stimulusLibrary.addNewStimulus() ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'TypeString', 'Sine') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'Name', 'Elmer') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'Amplitude', '-2.98') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'Delay', 0.4) ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'Frequency', 1.47) ;
% 
% %             stimulus4=stimulusLibrary.addNewStimulus('Ramp');
% %             stimulus4.Delay=0.151;
% %             stimulus4.Amplitude='i';
% %             stimulus4.Name='Foghorn Leghorn';
%             
%             stimulus4Index = stimulusLibrary.addNewStimulus() ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus4Index, 'TypeString', 'Ramp') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus4Index, 'Name', 'Foghorn Leghorn') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus4Index, 'Amplitude', 'i') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus4Index, 'Delay', 0.151) ;
% 
% %             stimulus5=stimulusLibrary.addNewStimulus('Ramp');
% %             stimulus5.Delay=0.171;
% %             stimulus5.Amplitude=-9;
% %             stimulus5.Name='Unreferenced Stimulus';
%             
%             stimulus5Index = stimulusLibrary.addNewStimulus() ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus5Index, 'TypeString', 'Ramp') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus5Index, 'Name', 'Unreferenced Stimulus') ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus5Index, 'Amplitude', -9) ;
%             stimulusLibrary.setItemProperty('ws.Stimulus', stimulus5Index, 'Delay', 0.171) ;
%             
% %             stimulusMap1=stimulusLibrary.addNewMap();
% %             stimulusMap1.Name = 'Lucy the Map' ;
% %             stimulusMap1.Duration = 1.01 ;
% %             stimulusMap1.addBinding('ao0',stimulus1,1.01);
% %             stimulusMap1.addBinding('ao1',stimulus2,1.02);
% 
%             stimulusMap1Index = stimulusLibrary.addNewMap() ;
%             stimulusLibrary.setItemProperty('ws.StimulusMap', stimulusMap1Index, 'Name', 'Lucy the Map') ;
%             binding1Index = stimulusLibrary.addBindingToItem('ws.StimulusMap', stimulusMap1Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding1Index, 'ChannelName', 'ao0') ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding1Index, 'IndexOfEachStimulusInLibrary', stimulus1Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding1Index, 'Multiplier', 1.01) ;
%             binding2Index = stimulusLibrary.addBindingToItem('ws.StimulusMap', stimulusMap1Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding2Index, 'ChannelName', 'ao1') ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding2Index, 'IndexOfEachStimulusInLibrary', stimulus2Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap1Index, binding2Index, 'Multiplier', 1.02) ;
%             
% %             stimulusMap2=stimulusLibrary.addNewMap();
% %             stimulusMap2.Name = 'Linus the Map' ;
% %             stimulusMap2.Duration = 2.04 ;            
% %             stimulusMap2.addBinding('ao0',stimulus3,2.01);
% %             stimulusMap2.addBinding('ao1',stimulus4,2.02);
%             
%             stimulusMap2Index = stimulusLibrary.addNewMap() ;
%             stimulusLibrary.setItemProperty('ws.StimulusMap', stimulusMap2Index, 'Name', 'Linus the Map') ;
%             binding1Index = stimulusLibrary.addBindingToItem('ws.StimulusMap', stimulusMap2Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding1Index, 'ChannelName', 'ao0') ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding1Index, 'IndexOfEachStimulusInLibrary', stimulus3Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding1Index, 'Multiplier', 2.01) ;
%             binding2Index = stimulusLibrary.addBindingToItem('ws.StimulusMap', stimulusMap2Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding2Index, 'ChannelName', 'ao1') ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding2Index, 'IndexOfEachStimulusInLibrary', stimulus4Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusMap', stimulusMap2Index, binding2Index, 'Multiplier', 2.02) ;
% 
% %             stimulusSequence=stimulusLibrary.addNewSequence();
% %             stimulusSequence.Name = 'Cyclotron' ;
% %             stimulusSequence.addMap(stimulusMap1);
% %             stimulusSequence.addMap(stimulusMap2);            
% 
%             sequence1Index = stimulusLibrary.addNewSequence() ;
%             stimulusLibrary.setItemProperty('ws.StimulusSequence', sequence1Index, 'Name', 'Cyclotron') ;
%             binding1Index = stimulusLibrary.addBindingToItem('ws.StimulusSequence', sequence1Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusSequence', sequence1Index, binding1Index, 'IndexOfEachMapInLibrary', stimulusMap1Index) ;
%             binding2Index = stimulusLibrary.addBindingToItem('ws.StimulusSequence', sequence1Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusSequence', sequence1Index, binding2Index, 'IndexOfEachMapInLibrary', stimulusMap2Index) ;
% 
% %             stimulusSequence2=stimulusLibrary.addNewSequence();
% %             stimulusSequence2.Name = 'Megatron' ;
% %             stimulusSequence2.addMap(stimulusMap2);
% %             stimulusSequence2.addMap(stimulusMap1);            
%             
%             sequence2Index = stimulusLibrary.addNewSequence() ;
%             stimulusLibrary.setItemProperty('ws.StimulusSequence', sequence2Index, 'Name', 'Megatron') ;
%             binding1Index = stimulusLibrary.addBindingToItem('ws.StimulusSequence', sequence2Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusSequence', sequence2Index, binding1Index, 'IndexOfEachMapInLibrary', stimulusMap2Index) ;
%             binding2Index = stimulusLibrary.addBindingToItem('ws.StimulusSequence', sequence2Index) ;
%             stimulusLibrary.setItemBindingProperty('ws.StimulusSequence', sequence2Index, binding2Index, 'IndexOfEachMapInLibrary', stimulusMap1Index) ;
%         end  % function        
    end  % static methods block
end  % classdef
