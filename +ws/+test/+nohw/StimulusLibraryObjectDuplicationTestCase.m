classdef StimulusLibraryObjectDuplicationTestCase < ws.test.StimulusLibraryTestCase
    
    methods (Test)
        function testObjectDuplication(self)           
            % Create a default stimulus library and store the number of
            % objects in it.
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            initialNumberInStimulusLibrary = [stimulusLibrary.NStimuli stimulusLibrary.NMaps stimulusLibrary.NSequences] ;
             
            % Duplicate a stimulus and verify the correct one was
            % duplicated
            originalStimulusIndex = 3 ;
            stimulusLibrary.setSelectedItemByClassNameAndIndex('ws.Stimulus', originalStimulusIndex) ;
            stimulusLibrary.duplicateSelectedItem();
            self.verifyTrue(self.checkCorrectOnesWereDuplicated(stimulusLibrary.Stimuli,[3,6]));
            
            % Make sure that changing one doesn't change the other
            newStimulusIndex = stimulusLibrary.SelectedItemIndexWithinClass ;
            self.verifyNotEqual(originalStimulusIndex,newStimulusIndex) ;  % should not have handle equality
            stimulusLibrary.setItemProperty('ws.Stimulus', originalStimulusIndex, 'Duration', '0.47') ;
            stimulusLibrary.setItemProperty('ws.Stimulus', newStimulusIndex, 'Duration', '0.39') ;
            self.verifyEqual(stimulusLibrary.itemProperty('ws.Stimulus', originalStimulusIndex, 'Duration'), '0.47') ;
            self.verifyEqual(stimulusLibrary.itemProperty('ws.Stimulus', newStimulusIndex, 'Duration'), '0.39') ;
%             originalStimulusIndex.Delegate.Frequency = '9' ;
%             newStimulusIndex.Delegate.Frequency = '11' ;
%             self.verifyEqual(originalStimulusIndex.Delegate.Frequency,'9') ;
%             self.verifyEqual(newStimulusIndex.Delegate.Frequency,'11') ;
            stimulusLibrary.setItemProperty('ws.Stimulus', originalStimulusIndex, 'Frequency', '9') ;
            stimulusLibrary.setItemProperty('ws.Stimulus', newStimulusIndex, 'Frequency', '11') ;
            self.verifyEqual(stimulusLibrary.itemProperty('ws.Stimulus', originalStimulusIndex, 'Frequency'), '9') ;
            self.verifyEqual(stimulusLibrary.itemProperty('ws.Stimulus', newStimulusIndex, 'Frequency'), '11') ;
            
            % Duplicate a map twice and verify it worked properly
            for i = 1:2 ,
                %stimulusLibrary.SelectedItem = stimulusLibrary.Maps{2};
                stimulusLibrary.setSelectedItemByClassNameAndIndex('ws.StimulusMap', 2) ;
                stimulusLibrary.duplicateSelectedItem();
            end
            self.verifyTrue(self.checkCorrectOnesWereDuplicated(stimulusLibrary.Maps,[2,3; 2,4; 3,4]));
            
            % Duplicate a sequence and verify it worked properly
            %stimulusLibrary.SelectedItem = stimulusLibrary.Sequences{1};
            stimulusLibrary.setSelectedItemByClassNameAndIndex('ws.StimulusSequence', 1) ;
            stimulusLibrary.duplicateSelectedItem();
            wereCorrectOnesDuplicated = self.checkCorrectOnesWereDuplicated(stimulusLibrary.Sequences,[1 3]) ;
            self.verifyTrue(wereCorrectOnesDuplicated) ;
            
            % Verify the final number of objects is as expected
            finalNumberInStimulusLibrary = [stimulusLibrary.NStimuli stimulusLibrary.NMaps stimulusLibrary.NSequences] ;
            self.verifyEqual(initialNumberInStimulusLibrary+[1 2 1], finalNumberInStimulusLibrary) ;
            
            % Verify that modifying a duplicated object (here, doubling the
            % duration of a duplicated Map) behaves properly; ie, duplicated Map, and
            % Sequence containing duplicated Map should be updated, but  original
            % Map and Sequence containing original Map should be unchanged.
            
            %stimulusLibrary.Sequences{3}.deleteBinding(2);
            stimulusLibrary.deleteItemBinding('ws.StimulusSequence', 3, 2) ;
            %stimulusLibrary.Sequences{3}.addMap(stimulusLibrary.Maps{4});
            bindingIndex = stimulusLibrary.addBindingToItem('ws.StimulusSequence', 3) ;
            stimulusLibrary.setItemBindingProperty('ws.StimulusSequence', 3, bindingIndex, 'IndexOfEachMapInLibrary', 4) ;
            %stimulusLibrary.SelectedMap = stimulusLibrary.Maps{4};
            stimulusLibrary.setSelectedItemByClassNameAndIndex('ws.StimulusMap', 4) ;            
            %stimulusLibrary.SelectedMap.Duration = 2*stimulusLibrary.Maps{4}.Duration;
            stimulusLibrary.setSelectedItemProperty('Duration', 2*stimulusLibrary.selectedItemProperty('Duration')) ;
            self.verifyEqual(stimulusLibrary.Maps{4}.Duration, 2*stimulusLibrary.Maps{2}.Duration) ;
            self.verifyTrue(isequal(stimulusLibrary.Maps{4}, stimulusLibrary.itemBindingTarget('ws.StimulusSequence', 3, 2) ) ) ;
            self.verifyTrue(isequal(stimulusLibrary.Maps{2}, stimulusLibrary.itemBindingTarget('ws.StimulusSequence', 1, 2) ) ) ;                       
        end        
    end
    
    methods (Static)
        function output = checkCorrectOnesWereDuplicated(stimulusLibraryProperty, correctEqualityPairs)
            % Function to check that duplications occur as expected, where
            % correctEqualityPairs lists what should be the
            % correct equal pairs in the list of objects
            actualEqualityPairs = [];
            for i=1:length(stimulusLibraryProperty)
                for j=i+1:length(stimulusLibraryProperty)
                    if ws.test.nohw.StimulusLibraryObjectDuplicationTestCase.checkEqualityExceptName(stimulusLibraryProperty{i},stimulusLibraryProperty{j})
                        actualEqualityPairs = [actualEqualityPairs;i,j] ;  %#ok<AGROW>
                    end
                end
            end
            %actualEqualityPairs;
            output = isequal(actualEqualityPairs, correctEqualityPairs);
        end
        
        function output = checkEqualityExceptName(objectOne, objectTwo)
            % Function to check that two objects are equal except for their
            % names (meaning duplication worked properly)
            fieldsOne = fieldnames(objectOne);
            fieldsTwo = fieldnames(objectTwo);
            if isequal(fieldsOne, fieldsTwo)
                output = true;
                currentFieldIndex = 1;
                while output == true && currentFieldIndex <= length(fieldsOne)
                    if strcmp(fieldsOne{currentFieldIndex},'Name')
                        % If the names are equal, then the duplication
                        % failed
                        if isequal(objectOne.(fieldsOne{currentFieldIndex}), objectTwo.(fieldsOne{currentFieldIndex}))
                            output = false;
                        end
                    else if ~isequal(objectOne.(fieldsOne{currentFieldIndex}), objectTwo.(fieldsOne{currentFieldIndex}))
                            output = false;
                        end
                    end
                    currentFieldIndex = currentFieldIndex+1;                       
                end    
            else
                output = false;
            end
        end        
    end  % static methods
end
