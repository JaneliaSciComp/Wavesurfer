classdef StimulusLibraryEncodingTestCase < ws.test.StimulusLibraryTestCase
    methods (Test)
        function testGenerationOfStimulusLibraryParts(self)
            stimulusLibrary=self.createPopulatedStimulusLibrary();            
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts(); %#ok<ASGLU>
            self.verifyTrue(stimulusLibrary.isSelfConsistent());
%             maps=stimulusLibrary.Maps;
%             mapIsLiveAndSelfConsistent= cellfun(@isLiveAndSelfConsistent,maps);
%             self.verifyTrue(all(mapIsLiveAndSelfConsistent));
%             sequences=stimulusLibrary.Sequences;            
%             sequenceIsLiveAndSelfConsistent= cellfun(@isLiveAndSelfConsistent,sequences);            
%             self.verifyTrue(all(sequenceIsLiveAndSelfConsistent));
        end
        
        function testSavingOfTestPulseStimulus(self)
            % create some stimuli, etc.
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            stimuli=stimulusLibrary.Stimuli;
            stimulus=stimuli{2};  % a test pulse

            % make an orpan copy
            orphanStimulus = stimulus.copyGivenParent([]);
            
            % save to disk
            fileName=[tempname() '.mat'];
            save(fileName,'orphanStimulus');
            
            % load back from disk
            s=load(fileName);
            stimulusCheck=s.orphanStimulus;
            
            % check
            self.verifyEqual(orphanStimulus,stimulusCheck);  % test value equality
            self.verifyFalse(orphanStimulus==stimulusCheck);  % test (lack of) identity
        end  % function
        
        function testSavingOfChirpStimulus(self)
            % create some stimuli, etc.
            
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            %stimuli=self.makeExampleStimulusParts();
            stimulus=stimulusLibrary.Stimuli{1}.copyGivenParent([]);  % this is a chirp

            % save to disk
            fileName=[tempname() '.mat'];
            save(fileName,'stimulus');
            
            % load back from disk
            s=load(fileName);
            stimulusCheck=s.stimulus;
            
            % check
            self.verifyEqual(stimulus,stimulusCheck);  % test value equality
            self.verifyFalse(stimulus==stimulusCheck);  % test (lack of) identity
        end  % function
        
        function testCopyingOfStimuli(self)            
            % create some stimuli, etc.
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            stimuli = stimulusLibrary.Stimuli ; 

            % copy
            stimuliCopy = cellfun(@(stimulus)(stimulus.copy()),stimuli,'UniformOutput',false) ;
            
            % check value quality
            isEqualInValue = ws.cellisequal(stimuli,stimuliCopy) ;
            self.verifyTrue(all(isEqualInValue));  % test value equality
            
            % verify lack of identity
            isDistinct=ws.cellne(stimuli,stimuliCopy);  % test identity (i.e. pointer equality)
            self.verifyTrue(all(isDistinct));
            
            % another copy, to make sure no aliasing is going on
            stimuliCopyCopyModded = cellfun(@(stimulus)(stimulus.copy()),stimuliCopy,'UniformOutput',false) ;
            stimuliCopyCopyModded{1}.setAdditionalParameter('InitialFrequency', '45.44323') ;
            
            % 2nd copy should be different from original and 1st copy
            self.verifyTrue(all(ws.cellisequal(stimuli,stimuliCopy)));  % test value equality
            self.verifyFalse(all(ws.cellisequal(stimuli,stimuliCopyCopyModded)));  % test value equality
            self.verifyFalse(all(ws.cellisequal(stimuliCopy,stimuliCopyCopyModded)));  % test value equality
        end  % function
        
%         function testSavingOfChannelBinding(self)
%             stimulus1=ws.ChirpStimulus('InitialFrequency',1.4545, ...
%                                                    'FinalFrequency',45.3);  
%             stimulus1.Delay=0.11;
%             stimulus1.Amplitude='6.28';
%             stimulus1.Name='Melvin';
%             
%             stimulus2=ws.SquarePulseStimulus();
%             stimulus2.Delay=0.12;
%             stimulus2.Amplitude='6.29';
%             stimulus2.Name='Bill';
%             
%             stimuli={stimulus1 stimulus2};
%             
%             channelBinding=ws.ChannelBinding('ChannelName', 'ao0', ...
%                                                          'Stimulus', stimulus1, ...
%                                                          'Multiplier', 1);
%             
%             fileName=[tempname() '.mat'];
%             save(fileName,'channelBinding');
%             
%             s=load(fileName);
%             channelBindingCheck=s.channelBinding;
%             channelBindingCheck.revive(stimuli);
%             
%             self.verifyTrue(channelBindingCheck.isLiveAndSelfConsistent());  % test soundness of the restored one            
%             self.verifyEqual(channelBinding,channelBindingCheck);  % test value equality
%             self.verifyFalse(channelBinding==channelBindingCheck);  % test (lack of) identity
%         end  % function
                
        function testSavingOfStimulusMap(self)
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts(); %#ok<NASGU>
            map=stimulusLibrary.Maps{2};
            
            fileName=[tempname() '.mat'];
            save(fileName,'map');
            
            s=load(fileName);
            mapCheck=s.map;
            %mapCheck.revive(stimulusLibrary.Stimuli);
            
            %self.verifyTrue(mapCheck.isLiveAndSelfConsistent());  % test soundness of the restored one
            self.verifyEqual(map,mapCheck);  % test value equality
            self.verifyTrue(all(map~=mapCheck));  % test (lack of) identity
        end  % function

        function testSavingOfStimulusMaps(self)
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts(); %#ok<NASGU>
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            maps=stimulusLibrary.Maps;
            
            fileName=[tempname() '.mat'];
            save(fileName,'maps');
            
            s=load(fileName);
            mapsCheck=s.maps;
            %cellfun(@(map)(map.revive(stimulusLibrary.Stimuli)),mapsCheck);
            %mapsCheck.revive(stimuli);
            
            %isMapLiveAndConsistent=cellfun(@isLiveAndSelfConsistent,mapsCheck);
            %self.verifyTrue(all(isMapLiveAndConsistent));  % test soundness of the restored ones
            self.verifyTrue(all(ws.cellisequal(maps,mapsCheck)));  % test value equality
            self.verifyTrue(all(ws.cellne(maps,mapsCheck)));  % test (lack of) identity
        end  % function
        
        function testSavingOfStimulusSequences(self)
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts(); %#ok<ASGLU>
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            sequences=stimulusLibrary.Sequences;
            
            fileName=[tempname() '.mat'];
            save(fileName,'sequences');
            
            s=load(fileName);
            sequencesCheck=s.sequences;
            %cellfun(@(seq)(seq.revive(stimulusLibrary.Maps)),sequencesCheck);
            
            %self.verifyTrue(all(cellfun(@isLiveAndSelfConsistent,sequencesCheck)));  % test soundness of the restored one
            self.verifyTrue(all(ws.cellisequal(sequences,sequencesCheck)));  % test value equality
            self.verifyTrue(all(ws.cellne(sequences,sequencesCheck)));  % test (lack of) identity
        end  % function
        
        function testSavingOfStimulusLibrary(self)
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts();
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            
            %stimulusLibrary.SelectedOutputable=stimulusLibrary.Sequences{2};            
            stimulusLibrary.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', 2) ;            
            self.verifyTrue(stimulusLibrary.isSelfConsistent()) ;
            
            fileName=[tempname() '.mat'] ;
            save(fileName,'stimulusLibrary') ;
            
            s = load(fileName) ;
            stimulusLibraryCheck = s.stimulusLibrary ;
            
            self.verifyTrue(stimulusLibraryCheck.isSelfConsistent());  % test soundness of the restored one            
            self.verifyEqual(stimulusLibrary.Stimuli,stimulusLibraryCheck.Stimuli);  % test value equality
            self.verifyEqual(stimulusLibrary.Maps,stimulusLibraryCheck.Maps);  % test value equality
            self.verifyEqual(stimulusLibrary.Sequences,stimulusLibraryCheck.Sequences);  % test value equality
            self.verifyEqual(stimulusLibrary.selectedOutputable(),stimulusLibraryCheck.selectedOutputable());  % test value equality
            self.verifyFalse(stimulusLibrary==stimulusLibraryCheck);  % test (lack of) identity
        end  % function        

        function testRestoringSettingsOfStimulusLibrary(self)
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts();
            stimulusLibrary=self.createPopulatedStimulusLibrary() ;
            
            %stimulusLibrary=ws.StimulusLibrary();
            %stimulusLibrary.add(stimuli);
            %stimulusLibrary.add(maps);
            %stimulusLibrary.add(sequences);
            stimulusLibrary.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', 2) ;            
            
            stimulusLibraryCheck = ws.StimulusLibrary([]) ;
            stimulusLibraryCheck.mimic(stimulusLibrary) ;
            
            self.verifyTrue(stimulusLibraryCheck.isSelfConsistent()) ;  % test soundness of the restored one            
            %self.verifyEqual(stimulusLibrary.Stimuli,stimulusLibraryCheck.Stimuli);  % test value equality
            %self.verifyEqual(stimulusLibrary.Maps,stimulusLibraryCheck.Maps);  % test value equality
            %self.verifyEqual(stimulusLibrary.Cycles,stimulusLibraryCheck.Cycles);  % test value equality
            self.verifyEqual(stimulusLibrary, stimulusLibraryCheck) ;  % test value equality
            self.verifyFalse(stimulusLibrary==stimulusLibraryCheck) ;  % test (lack of) identity
        end  % function

        function testCopyingOfStimulusLibrary(self)
            % create some stimuli, etc.
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;

            % create a library
            stimulusLibrary.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', 2) ;            
            
            % copy
            stimulusLibraryCopy = stimulusLibrary.copy() ;
            
            % check
            self.verifyTrue(stimulusLibraryCopy.isSelfConsistent()) ;
            self.verifyEqual(stimulusLibrary,stimulusLibraryCopy) ;  % test value equality
            self.verifyTrue(all(stimulusLibrary~=stimulusLibraryCopy)) ;  % test (lack of) identity
            
            % another copy, to make sure no aliasing is going on
            stimulusLibraryCopyCopy = stimulusLibraryCopy.copy() ;
            %stimulus1 = stimulusLibraryCopyCopy.Stimuli{1};  % should be an alias
            %stimulus1.Delegate.InitialFrequency='45.44323';  % should modify stimulusLibraryCopyCopy
            stimulusLibraryCopyCopy.setItemProperty('ws.Stimulus', 1, 'InitialFrequency', '45.44323') ;
            
            % 2nd copy should be different from original and 1st copy
            self.verifyTrue(stimulusLibraryCopyCopy.isSelfConsistent()) ;
            self.verifyEqual(stimulusLibrary, stimulusLibraryCopy) ;  % test value equality
            self.verifyNotEqual(stimulusLibrary, stimulusLibraryCopyCopy) ;  % test value equality
            self.verifyNotEqual(stimulusLibraryCopy, stimulusLibraryCopyCopy) ;  % test value equality
        end  % function

    end  % test methods

end
