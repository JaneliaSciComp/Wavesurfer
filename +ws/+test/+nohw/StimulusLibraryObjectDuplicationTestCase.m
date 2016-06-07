classdef StimulusLibraryObjectDuplicationTestCase < ws.test.StimulusLibraryTestCase
    
    methods (Test)
        function testObjectDuplication(self)           
            % Create a default stimulus library and store the number of
            % objects in it.
            stimulusLibrary = self.createPopulatedStimulusLibrary();
            initialNumberInStimulusLibrary = [length(stimulusLibrary.Stimuli), length(stimulusLibrary.Maps), length(stimulusLibrary.Sequences)];
             
            % Duplicate a stimulus and verify the correct one was
            % duplicated
            stimulusLibrary.SelectedItem = stimulusLibrary.Stimuli{3};
            stimulusLibrary.duplicateStimulusLibraryObject();
            self.verifyTrue(self.checkCorrectOnesWereDuplicated(stimulusLibrary.Stimuli,[3,6]));
            
            % Duplicate a map twice and verify it worked properly
            for i=1:2
                stimulusLibrary.SelectedItem = stimulusLibrary.Maps{2};
                stimulusLibrary.duplicateStimulusLibraryObject();
            end
            self.verifyTrue(self.checkCorrectOnesWereDuplicated(stimulusLibrary.Maps,[2,3; 2,4; 3,4]));
            
            % Duplicate a sequence twice and verify it worked properly
            stimulusLibrary.SelectedItem = stimulusLibrary.Sequences{1};
            stimulusLibrary.duplicateStimulusLibraryObject();
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
        end        
    end
    methods (Access = protected)
        function output = checkEqualityExceptName(self,objectOne, objectTwo)
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
        
        function output = checkCorrectOnesWereDuplicated(self,stimulusLibraryProperty, correctEqualityPairs)
            % Function to check that duplications occur as expected, where
            % correctEqualityPairs lists what should be the
            % correct equal pairs in the list of objects
            actualEqualityPairs = [];
            for i=1:length(stimulusLibraryProperty)
                for j=i+1:length(stimulusLibraryProperty)
                    if self.checkEqualityExceptName(stimulusLibraryProperty{i},stimulusLibraryProperty{j})
                        actualEqualityPairs=[actualEqualityPairs;i,j];
                    end
                end
            end
            actualEqualityPairs;
            output = isequal(actualEqualityPairs, correctEqualityPairs);
        end
    end
end
