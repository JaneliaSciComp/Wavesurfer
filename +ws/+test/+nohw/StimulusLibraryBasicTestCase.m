classdef StimulusLibraryBasicTestCase < ws.test.StimulusLibraryTestCase
    
    methods (Test)
        function testConstructor(self)
            library = ws.StimulusLibrary();
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEmptyLibrary(library);
        end
        
        function testRemoveStimulus(self)
            library = self.createPopulatedStimulusLibrary();
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEqual(library.NStimuli, 5);
            
            % Safe remove, item that is not referenced.  Should delete one
            % stimulus.
            stimulusIndex = library.indexOfItemWithNameWithinGivenClass('Unreferenced Stimulus', 'ws.Stimulus');
            isInUse=library.isItemInUse('ws.Stimulus', stimulusIndex);
            self.verifyFalse(isInUse);
            if all(~isInUse) ,
                library.deleteItem('ws.Stimulus', stimulusIndex);
            end
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEqual(library.NStimuli, 4);
            
            % Safe remove, item that is in use.  Should not delete
            % anything.
            stimulusIndex = library.indexOfItemWithNameWithinGivenClass('Melvin', 'ws.Stimulus');
            isInUse=library.isItemInUse('ws.Stimulus', stimulusIndex);
            self.verifyTrue(isInUse);
            if all(~isInUse) ,
                library.deleteItem('ws.Stimulus', stimulusIndex);
            end
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEqual(library.NStimuli, 4);

            % Force remove, item that is in use.  Should work.
            stimulusIndex = library.indexOfItemWithNameWithinGivenClass('Melvin', 'ws.Stimulus');
            isInUse=library.isItemInUse('ws.Stimulus', stimulusIndex);
            self.verifyTrue(isInUse);
            library.deleteItem('ws.Stimulus', stimulusIndex);  % Remove it anyway
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEqual(library.NStimuli, 3);
        end
        
        function testRemoveStimulus2(self)
            library = self.createPopulatedStimulusLibrary();
%             library=ws.StimulusLibrary([]);  % no parent
%             
%             stimulus1=library.addNewStimulus('Chirp');
%             stimulus1.Delay=0.11;
%             stimulus1.Amplitude='6.28';
%             stimulus1.Name='Melvin';
%             stimulus1.Delegate.InitialFrequency = 1.4545 ;
%             stimulus1.Delegate.FinalFrequency = 45.3 ;
%             
%             stimulus2=library.addNewStimulus('SquarePulse');
%             stimulus2.Delay=0.12;
%             stimulus2.Amplitude='6.29';
%             stimulus2.Name='Bill';
%             
%             stimulusMap1=library.addNewMap();
%             stimulusMap1.Name = 'Lucy the Map' ;
%             stimulusMap1.Duration = 1.01 ;
%             stimulusMap1.addBinding('ao0',stimulus1,1.01);
%             stimulusMap1.addBinding('ao1',stimulus2,1.02);
            
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEqual(library.NStimuli, 5) ;
            
            % Delete the first stimulus
            library.deleteItem('ws.Stimulus', 1) ;
            [isSelfConsistent,err] = library.isSelfConsistent() ;
            if isSelfConsistent ,
                message = '' ;
            else
                message = err.message ;
            end
            self.verifyTrue(isSelfConsistent,message) ;
            self.verifyEqual(library.NStimuli, 4) ;
        end
        
        function testRemoveMap(self)
            library = self.createPopulatedStimulusLibrary();
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEqual(library.NStimuli, 5);
            
            % Force remove, item that is in use.  Should work.
            mapIndex = 1 ;
            isInUse=library.isItemInUse('ws.StimulusMap', mapIndex);
            self.verifyTrue(isInUse);
            library.deleteItem('ws.StimulusMap', mapIndex);  % Remove it anyway
            self.verifyTrue(library.isSelfConsistent()) ;
        end  % function
        
        function testRemoveSequence(self)
            library = self.createPopulatedStimulusLibrary();
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEqual(library.NSequences, 2, 'Wrong number of initial cycles.');
            
            % Remove cycle.  Should work.
            sequenceIndex = library.indexOfItemWithNameWithinGivenClass('Cyclotron', 'ws.StimulusSequence');
            library.deleteItem('ws.StimulusSequence', sequenceIndex);
            self.verifyTrue(library.isSelfConsistent()) ;
            self.verifyEqual(library.NSequences, 1);
        end  % function
        
        function testRemovalOfSelectedOutputable(self)
            library = ws.StimulusLibrary() ;
            outputChannelNames = {'ao0' 'ao1'} ;
            library.setToSimpleLibraryWithUnitPulse(outputChannelNames) ;
            self.verifyTrue(library.isSelfConsistent()) ;
            sequenceIndex = library.addNewSequence() ;  % the simple lib has no sequences in it
            self.verifyTrue(library.isSelfConsistent()) ;
            % There should be one cycle (with no maps in it) and one map.
            library.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', sequenceIndex) ;
            %library.SelectedOutputable = library.Sequences{sequenceIndex} ;
            self.verifyTrue(library.isSelfConsistent()) ;
            library.deleteItem('ws.StimulusSequence', sequenceIndex) ;  % this should cause the map (the only other outputable) to be selected
            self.verifyTrue(library.isSelfConsistent()) ;
            %self.verifyTrue(library.SelectedOutputable==library.Maps{1}) ;
            self.verifyTrue(isequal(library.SelectedOutputableClassName, 'ws.StimulusMap')) ;
            self.verifyTrue(isequal(library.SelectedOutputableIndex, 1)) ;
        end  % function
        
        function testRemoveEverything(self)
            library = self.createPopulatedStimulusLibrary();
            self.verifyTrue(library.isSelfConsistent()) ;
            
            % Remove all the sequences
            nSequencesLeft = library.NSequences ;
            while nSequencesLeft>0 ,
                library.deleteItem('ws.StimulusSequence', nSequencesLeft) ;
                self.verifyTrue(library.isSelfConsistent()) ;
                nSequencesLeft = library.NSequences ;                
            end
            
            % Remove all the maps
            nMapsLeft = library.NMaps ;
            while nMapsLeft>0 ,
                library.deleteItem('ws.StimulusMap', nMapsLeft) ;
                self.verifyTrue(library.isSelfConsistent()) ;
                nMapsLeft = library.NMaps ;                
            end
            
            % Remove all the stimuli
            nStimuliLeft = library.NStimuli ;
            while nStimuliLeft>0 ,
                library.deleteItem('ws.Stimulus', nStimuliLeft) ;
                self.verifyTrue(library.isSelfConsistent()) ;
                nStimuliLeft = library.NStimuli ;
            end            
        end  % function
        
        function testRemoveEverythingInOtherOrder(self)
            library = self.createPopulatedStimulusLibrary();
            self.verifyTrue(library.isSelfConsistent()) ;
            
            % Remove all the sequences
            nSequencesLeft = library.NSequences ;
            while nSequencesLeft>0 ,
                library.deleteItem('ws.StimulusSequence', 1) ;
                self.verifyTrue(library.isSelfConsistent()) ;
                nSequencesLeft = library.NSequences ;                
            end
            
            % Remove all the maps
            nMapsLeft = library.NMaps ;
            while nMapsLeft>0 ,
                library.deleteItem('ws.StimulusMap', 1) ;
                self.verifyTrue(library.isSelfConsistent()) ;
                nMapsLeft = library.NMaps ;                
            end
            
            % Remove all the stimuli
            nStimuliLeft = library.NStimuli ;
            while nStimuliLeft>0 ,
                library.deleteItem('ws.Stimulus', 1) ;
                self.verifyTrue(library.isSelfConsistent()) ;
                nStimuliLeft = library.NStimuli ;
            end            
        end  % function
    end  % test methods
    
    methods (Access = protected)
        function verifyEmptyLibrary(self, library)
            self.verifyTrue(library.isEmpty(), 'The library is not empty') ;
%             self.verifyEmpty(library.Sequences, 'The ''Sequences'' property should be empty.');
%             self.verifyEmpty(library.Maps, 'The ''Maps'' property should be empty.');
%             self.verifyEmpty(library.Stimuli, 'The ''Stimuli'' property should be empty.');
        end        
    end
end
