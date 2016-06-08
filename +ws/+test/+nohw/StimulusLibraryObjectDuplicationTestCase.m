classdef StimulusLibraryObjectDuplicationTestCase < ws.test.StimulusLibraryTestCase
    
    methods (Test)
        function testObjectDuplication(self)           
            % Create a default stimulus library and store the number of
            % objects in it.
            stimulusLibrary = self.createPopulatedStimulusLibrary();
            initialNumberInStimulusLibrary = [length(stimulusLibrary.Stimuli), length(stimulusLibrary.Maps), length(stimulusLibrary.Sequences)];
             
            % Duplicate a stimulus and verify the correct one was
            % duplicated
            originalStimulus = stimulusLibrary.Stimuli{3} ;
            stimulusLibrary.SelectedItem = originalStimulus ;
            stimulusLibrary.duplicateSelectedItem();
            self.verifyTrue(self.checkCorrectOnesWereDuplicated(stimulusLibrary.Stimuli,[3,6]));
            
            % Make sure that changing one doesn't change the other
            newStimulus = stimulusLibrary.SelectedItem ;
            self.verifyNotEqual(originalStimulus,newStimulus) ;  % should not have handle equality
            originalStimulus.Duration = '0.47' ;
            newStimulus.Duration = '0.39' ;
            %self.verifyNotEqual(originalStimulus.Duration,newStimulus.Duration) ;
            self.verifyEqual(originalStimulus.Duration,'0.47') ;
            self.verifyEqual(newStimulus.Duration,'0.39') ;
            originalStimulus.Delegate.Frequency = '9' ;
            newStimulus.Delegate.Frequency = '11' ;
            self.verifyEqual(originalStimulus.Delegate.Frequency,'9') ;
            self.verifyEqual(newStimulus.Delegate.Frequency,'11') ;
            
            % Duplicate a map twice and verify it worked properly
            for i=1:2
                stimulusLibrary.SelectedItem = stimulusLibrary.Maps{2};
                stimulusLibrary.duplicateSelectedItem();
            end
            self.verifyTrue(self.checkCorrectOnesWereDuplicated(stimulusLibrary.Maps,[2,3; 2,4; 3,4]));
            
            % Duplicate a sequence twice and verify it worked properly
            stimulusLibrary.SelectedItem = stimulusLibrary.Sequences{1};
            stimulusLibrary.duplicateSelectedItem();
            self.verifyTrue(self.checkCorrectOnesWereDuplicated(stimulusLibrary.Sequences,[1,3]));
            
            % Verify the final number of objects is as expected
            finalNumberInStimulusLibrary = [length(stimulusLibrary.Stimuli), length(stimulusLibrary.Maps), length(stimulusLibrary.Sequences)];
            self.verifyEqual(initialNumberInStimulusLibrary+[1,2,1],finalNumberInStimulusLibrary);
            
            % Verify that modifying a duplicated object (here, doubling the
            % duration of a duplicated Map) behaves properly; ie, duplicated Map, and
            % Sequence containing duplicated Map should be updated, but  original
            % Map and Sequence containing original Map should be unchanged.
            stimulusLibrary.Sequences{3}.deleteMap(2);
            stimulusLibrary.Sequences{3}.addMap(stimulusLibrary.Maps{4});
            stimulusLibrary.SelectedMap = stimulusLibrary.Maps{4};
            stimulusLibrary.SelectedMap.Duration = 2*stimulusLibrary.Maps{4}.Duration;
            self.verifyEqual(stimulusLibrary.Maps{4}.Duration, 2*stimulusLibrary.Maps{2}.Duration);
            self.verifyTrue(isequal(stimulusLibrary.Maps{4}, stimulusLibrary.Sequences{3}.Maps{2}));
            self.verifyTrue(isequal(stimulusLibrary.Maps{2}, stimulusLibrary.Sequences{1}.Maps{2}));
            
            % Duplicate a stimulus, verify that works
            
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
