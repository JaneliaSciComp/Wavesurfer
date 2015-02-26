classdef StimulusLibraryBasicTestCase < ws.test.StimulusLibraryTestCase
    
    methods (Test)
        function testConstructor(self)
            stimLib = ws.stimulus.StimulusLibrary();
            self.verifyEmptyLibrary(stimLib);
        end
        
        function testRemoveStimulus(self)
            stimLib = self.createPopulatedStimulusLibrary();
            self.verifyEqual(numel(stimLib.Stimuli), 5);
            
            % Safe remove, item that is not referenced.  Should work.
            stimulus = stimLib.stimulusWithName('Unreferenced Stimulus');
            isInUse=stimLib.isInUse(stimulus);
            self.verifyFalse(isInUse);
            if all(~isInUse) ,
                stimLib.deleteItems({stimulus});
            end
            self.verifyEqual(numel(stimLib.Stimuli), 4);
            
            % Safe remove, item that is in use.  Should fail.
            stimulus = stimLib.stimulusWithName('Melvin');
            isInUse=stimLib.isInUse(stimulus);
            self.verifyTrue(isInUse);
            if all(~isInUse) ,
                stimLib.deleteItems({stimulus});
            end
            self.verifyEqual(numel(stimLib.Stimuli), 4);

            % Force remove, item that is in use.  Should work.
            stimulus = stimLib.stimulusWithName('Melvin');
            isInUse=stimLib.isInUse(stimulus);
            self.verifyTrue(isInUse);
            stimLib.deleteItems({stimulus});  % Remove it anyway
            self.verifyEqual(numel(stimLib.Stimuli), 3);
        end
        
        function testRemoveSequence(self)
            stimLib = self.createPopulatedStimulusLibrary();
            self.verifyEqual(numel(stimLib.Sequences), 2, 'Wrong number of initial cycles.');
            
            % Remove cycle.  Should work.
            sequence = stimLib.sequenceWithName('Cyclotron');
            stimLib.deleteItems({sequence});
            self.verifyEqual(numel(stimLib.Sequences), 1);
        end
        
        function testRemovalOfSelectedOutputable(self)
            stimLib = ws.stimulus.StimulusLibrary();
            outputChannelNames={'ao0' 'ao1'};
            stimLib.setToSimpleLibraryWithUnitPulse(outputChannelNames);
            stimLib.addNewSequence();  % the simple lib has no sequences in it
            % There should be one cycle (with no maps in it) and one map.
            stimLib.SelectedOutputable=stimLib.Sequences{1};
            stimLib.deleteItems(stimLib.Sequences(1));  % this should cause the map (the only other outputable) to be selected
            self.verifyTrue(stimLib.SelectedOutputable==stimLib.Maps{1});
        end
        
    end  % test methods
    
    methods (Access = protected)
        function verifyEmptyLibrary(self, stimLib)
            self.verifyEmpty(stimLib.Sequences, 'The ''Sequences'' property should be empty.');
            self.verifyEmpty(stimLib.Maps, 'The ''Maps'' property should be empty.');
            self.verifyEmpty(stimLib.Stimuli, 'The ''Stimuli'' property should be empty.');
        end        
    end
end
