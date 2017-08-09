classdef StimulusMapTestCase < matlab.unittest.TestCase
    
    properties
        DefaultLibrary
        DefaultMapIndex
        DefaultStimulus1Index
        DefaultStimulus2Index
    end
    
    methods (Test)
        function testContainsStimuli(self)
            self.verifyTrue(self.DefaultLibrary.isStimulusInUseByMap(self.DefaultStimulus1Index, self.DefaultMapIndex), ...
                            'The map does not contain the specified stimulus.');
            self.verifyTrue(self.DefaultLibrary.isStimulusInUseByMap(self.DefaultStimulus2Index, self.DefaultMapIndex), ...
                            'The map does not contain the specified stimulus.');
            
            stimulus3Index = self.DefaultLibrary.addNewStimulus() ;
            self.DefaultLibrary.setItemProperty('ws.Stimulus', stimulus3Index, 'TypeString', 'Chirp') ;
            self.verifyFalse(self.DefaultLibrary.isStimulusInUseByMap(stimulus3Index, self.DefaultMapIndex), ...
                             'The map does contain the specified stimulus, even though it shouldn''t.');
            
            self.verifyTrue(self.DefaultLibrary.isStimulusInUseByMap(self.DefaultStimulus1Index, self.DefaultMapIndex), ...
                            'The map does not contain the specified stimulus.');                        
            self.verifyFalse(self.DefaultLibrary.isStimulusInUseByMap(stimulus3Index, self.DefaultMapIndex), ...
                             'The map does contain the specified stimulus, even though it shouldn''t.');                        
            self.verifyTrue(self.DefaultLibrary.isStimulusInUseByMap(self.DefaultStimulus2Index, self.DefaultMapIndex), ...
                            'The map does not contain the specified stimulus.');
                        
        end
        
        function testGetData(self)
            isChannelAnalog = [true true] ;
            data = self.DefaultLibrary.calculateSignalsForMap(1, 100, {'ch1' 'ch2'}, isChannelAnalog) ;
            self.verifyTrue(all(size(data) == [100 2]), 'Incorrect data size.');
        end
    end
    
    methods (TestMethodSetup)
        function createDefaultMapIndex(self)
            stimulusLibrary = ws.StimulusLibrary();  % no parent
            
%             stimulus1Index.DCOffset = 0;
%             stimulus1Index.Delegate.Period = 0.5;  % s
%             stimulus1Index.Delegate.PulseDuration = 0.25;  % s
            
            stimulus1Index = stimulusLibrary.addNewStimulus();
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'TypeString', 'SquarePulseTrain') ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'DCOffset', 0) ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'Period', 0.5) ;            
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus1Index, 'PulseDuration', 0.25) ;
            
%             stimulus2Index = stimulusLibrary.addNewStimulus('SquarePulseTrain');
%             stimulus2Index.DCOffset = 0;
%             stimulus2Index.Delegate.Period = 0.5;  % s
%             stimulus2Index.Delegate.PulseDuration = 0.25;  % s

            stimulus2Index = stimulusLibrary.addNewStimulus();
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'TypeString', 'SquarePulseTrain') ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'DCOffset', 0) ;
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'Period', 0.5) ;            
            stimulusLibrary.setItemProperty('ws.Stimulus', stimulus2Index, 'PulseDuration', 0.25) ;
            
%             mapIndex = stimulusLibrary.addNewMap();
%             mapIndex.addBinding('ch1', stimulus1Index);
%             mapIndex.addBinding('ch2', stimulus2Index);

            mapIndex = stimulusLibrary.addNewMap() ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusMap', mapIndex) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', 'ch1') ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', stimulus1Index) ;
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusMap', mapIndex) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', 'ch2') ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', stimulus2Index) ;
            
            self.DefaultLibrary = stimulusLibrary ;
            self.DefaultMapIndex = mapIndex;
            self.DefaultStimulus1Index = stimulus1Index;
            self.DefaultStimulus2Index = stimulus2Index;
        end
    end
    
    methods (TestMethodTeardown)
        function removeDefaultMapIndex(self)
            self.DefaultStimulus1Index = [];
            self.DefaultStimulus2Index = [];
            self.DefaultMapIndex = [];
            self.DefaultLibrary=[];
        end
    end
end
