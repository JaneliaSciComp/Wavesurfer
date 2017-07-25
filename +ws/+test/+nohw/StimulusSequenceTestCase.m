classdef StimulusSequenceTestCase < matlab.unittest.TestCase
    
    properties
        DefaultLibrary
        DefaultSequenceIndex
        DefaultMap1Index
        DefaultMap2Index
    end
    
    methods (Test)
        function testContainsElement(self)
%             self.verifyTrue(self.DefaultSequenceIndex.containsMap(self.DefaultMap1Index), ...
%                             'The sequence does contain the specified element.');
%             self.verifyTrue(self.DefaultSequenceIndex.containsMap(self.DefaultMap2Index), ...
%                             'The sequence does contain the specified element.');                        
            self.verifyTrue(self.DefaultLibrary.isMapInUseBySequence(self.DefaultMap1Index, self.DefaultSequenceIndex), ...
                            'The sequence does not contain the specified map.');
            self.verifyTrue(self.DefaultLibrary.isMapInUseBySequence(self.DefaultMap2Index, self.DefaultSequenceIndex), ...
                            'The sequence does not contain the specified map.');            
                        
            map3Index = self.DefaultLibrary.addNewMap();
%             self.verifyFalse(self.DefaultSequenceIndex.containsMap(map3Index), 'The sequence does not contain the specified element.');
            self.verifyFalse(self.DefaultLibrary.isMapInUseBySequence(map3Index, self.DefaultSequenceIndex), ...
                             'The sequence does contain the specified map, even though it shouldn''t.');
        end
    end
    
    methods (TestMethodSetup)
        function createDefaultSequence(self)
            stimulusLibrary = ws.StimulusLibrary();  % no parent
            
            stimulus1Index = stimulusLibrary.addNewStimulus();
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'TypeString', 'SquarePulseTrain') ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'DCOffset', 0) ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'Period', 0.5) ;            
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'PulseDuration', 0.25) ;
            
            stimulus2Index = stimulusLibrary.addNewStimulus();
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'TypeString', 'SquarePulseTrain') ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'DCOffset', 0) ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'Period', 0.5) ;            
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'PulseDuration', 0.25) ;
            
%             stimulus3Index = stimulusLibrary.addNewStimulus('SquarePulse');
%             stimulus3Index.Duration=0.30;
%             stimulus3Index.Amplitude=0.75;
%             stimulus3Index.DCOffset = 0;

            stimulus3Index = stimulusLibrary.addNewStimulus();
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'TypeString', 'SquarePulse') ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'Duration', 0.3) ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'Amplitude', 0.75) ;            
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'DCOffset', 0) ;           
            
%             map1Index = library.addNewMap();
%             map1Index.addBinding('ch1', stimulus1Index);
%             map1Index.addBinding('ch2', stimulus2Index);
%             map1Index.addBinding('ch3', stimulus3Index);
            
            map1Index = stimulusLibrary.addNewMap() ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusMap', map1Index) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map1Index, bindingIndex, 'ChannelName', 'ch1') ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map1Index, bindingIndex, 'IndexOfEachStimulusInLibrary', stimulus1Index) ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusMap', map1Index) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map1Index, bindingIndex, 'ChannelName', 'ch2') ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map1Index, bindingIndex, 'IndexOfEachStimulusInLibrary', stimulus2Index) ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusMap', map1Index) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map1Index, bindingIndex, 'ChannelName', 'ch3') ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map1Index, bindingIndex, 'IndexOfEachStimulusInLibrary', stimulus3Index) ;
            
%             map2Index = stimulusLibrary.addNewMap();
%             map2Index.addBinding('ch1', stimulus2Index);
%             map2Index.addBinding('ch2', stimulus3Index);
%             map2Index.addBinding('ch3', stimulus1Index);

            map2Index = stimulusLibrary.addNewMap() ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusMap', map2Index) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map2Index, bindingIndex, 'ChannelName', 'ch1') ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map2Index, bindingIndex, 'IndexOfEachStimulusInLibrary', stimulus2Index) ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusMap', map2Index) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map2Index, bindingIndex, 'ChannelName', 'ch2') ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map2Index, bindingIndex, 'IndexOfEachStimulusInLibrary', stimulus3Index) ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusMap', map2Index) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map2Index, bindingIndex, 'ChannelName', 'ch3') ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', map2Index, bindingIndex, 'IndexOfEachStimulusInLibrary', stimulus1Index) ;
            
%             sequenceIndex = stimulusLibrary.addNewSequence();
%             sequenceIndex.addMap(map1Index);
%             sequenceIndex.addMap(map2Index);
           
            sequenceIndex = stimulusLibrary.addNewSequence();
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusSequence', sequenceIndex) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusSequence', sequenceIndex, bindingIndex, 'IndexOfEachMapInLibrary', map1Index) ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusSequence', sequenceIndex) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusSequence', sequenceIndex, bindingIndex, 'IndexOfEachMapInLibrary', map2Index) ;
            
            self.DefaultLibrary = stimulusLibrary ;
            self.DefaultSequenceIndex = sequenceIndex ;
            self.DefaultMap1Index = map1Index ;
            self.DefaultMap2Index = map2Index ;
        end
    end
    
    methods (TestMethodTeardown)
        function removeDefaultSequence(self)
            self.DefaultMap1Index = [];
            self.DefaultMap2Index = [];
            self.DefaultSequenceIndex = [];
            self.DefaultLibrary=[];
        end
    end
end
