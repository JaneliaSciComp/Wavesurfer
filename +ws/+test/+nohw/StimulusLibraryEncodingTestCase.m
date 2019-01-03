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
        
        function testEncodingOfTestPulseStimulus(self)
            % create some stimuli, etc.
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            stimuli=stimulusLibrary.Stimuli;  % This makes copies of all the stimuli
            stimulus=stimuli{2};  % a test pulse

            % make an orpan copy
            orphanStimulus = ws.copy(stimulus);
            
            % encode
            encodedOrphanStimulus = ws.encodeAnythingForPersistence(orphanStimulus) ;
            %fileName=[tempname() '.mat'];
            %save(fileName,'orphanStimulus');
            
            % decode
            %s=load(fileName);
            stimulusCheck = ws.decodeEncodingContainer(encodedOrphanStimulus) ;
            
            % check
            self.verifyEqual(orphanStimulus,stimulusCheck);  % test value equality
            self.verifyFalse(orphanStimulus==stimulusCheck);  % test (lack of) identity
        end  % function
        
        function testEncodingOfChirpStimulus(self)
            % create some stimuli, etc.
            
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            %stimuli=self.makeExampleStimulusParts();
            stimulus = ws.copy(stimulusLibrary.Stimuli{1}) ;  % this is a chirp

            % encode
            encodedStimulus = ws.encodeAnythingForPersistence(stimulus) ;
            
            % decode
            stimulusCheck = ws.decodeEncodingContainer(encodedStimulus) ;
            
            % check
            self.verifyEqual(stimulus, stimulusCheck) ;  % test value equality
            self.verifyFalse(stimulus==stimulusCheck) ;  % test (lack of) identity
        end  % function

        function testCopyingOfStimulusDelegate(self)            
            csd = ws.ChirpStimulusDelegate() ;
            csd.InitialFrequency = '42' ;
            csd2 = ws.copy(csd) ;
            %csd2.InitialFrequency
            %shouldBeTrue = isequal(csd, csd2)
            self.verifyTrue(isequal(csd, csd2)) ;
        end  % function
        
        function testSettingOfStimulusAdditionalParameter(self)            
            stimulus = ws.Stimulus() ;
            stimulus.TypeString = 'Chirp' ;            
            valueAsSet = '45.44323' ;
            stimulus.setAdditionalParameter('InitialFrequency', valueAsSet) ;
            valueAsGotten = stimulus.getAdditionalParameter('InitialFrequency') ;
            self.verifyEqual(valueAsSet, valueAsGotten) ;
        end  % function
        
        function testCopyingOfStimulus(self)            
            % create some stimuli, etc.
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            stimulus = stimulusLibrary.Stimuli{1} ; 

            % copy
            stimulusCopy = ws.copy(stimulus) ;
            
            % check value quality
            isEqualInValue = isequal(stimulus, stimulusCopy) ;
            self.verifyTrue(isEqualInValue);  % test value equality
            
            % verify lack of identity
            isDistinct = (stimulus ~= stimulusCopy) ;  % test identity (i.e. pointer equality)
            self.verifyTrue(isDistinct);
            
            % another copy, to make sure no aliasing is going on
            stimulusCopyCopyModded = ws.copy(stimulusCopy) ;
            stimulusCopyCopyModded.setAdditionalParameter('InitialFrequency', '45.44323') ;
            
            % 2nd copy should be different from original and 1st copy
            self.verifyTrue(isequal(stimulus, stimulusCopy)) ;  % test value equality
            self.verifyFalse(isequal(stimulus,stimulusCopyCopyModded)) ;  % test value equality
            self.verifyFalse(isequal(stimulusCopy,stimulusCopyCopyModded)) ;  % test value equality
        end  % function
        
        function testCopyingOfStimuli(self)            
            % create some stimuli, etc.
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            stimuli = stimulusLibrary.Stimuli ; 

            % copy
            stimuliCopy = cellfun(@ws.copy,stimuli,'UniformOutput',false) ;
            
            % check value quality
            isEqualInValue = ws.cellisequal(stimuli, stimuliCopy) ;
            self.verifyTrue(all(isEqualInValue));  % test value equality
            
            % verify lack of identity
            isDistinct=ws.cellne(stimuli,stimuliCopy);  % test identity (i.e. pointer equality)
            self.verifyTrue(all(isDistinct));
            
            % another copy, to make sure no aliasing is going on
            stimuliCopyCopyModded = cellfun(@ws.copy,stimuliCopy,'UniformOutput',false) ;
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
                
        function testEncodingOfStimulusMap(self)
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts(); %#ok<NASGU>
            map=stimulusLibrary.Maps{2};  % a copy            
            encodedMap = ws.encodeAnythingForPersistence(map) ;            
            mapCheck = ws.decodeEncodingContainer(encodedMap) ;
            self.verifyEqual(map,mapCheck);  % test value equality
            self.verifyTrue(all(map~=mapCheck));  % test (lack of) identity
        end  % function

        function testSavingOfStimulusMaps(self)
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts(); %#ok<NASGU>
            stimulusLibrary=self.createPopulatedStimulusLibrary();
            maps=stimulusLibrary.Maps;
            encodedMaps = ws.encodeAnythingForPersistence(maps) ;
            mapsCheck = ws.decodeEncodingContainer(encodedMaps) ;
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
            encoded = ws.encodeAnythingForPersistence(sequences) ;
            sequencesCheck = ws.decodeEncodingContainer(encoded) ;
            self.verifyTrue(all(ws.cellisequal(sequences,sequencesCheck)));  % test value equality
            self.verifyTrue(all(ws.cellne(sequences,sequencesCheck)));  % test (lack of) identity
        end  % function
        
        function testSavingOfStimulusLibrary(self)
            %[stimuli,maps,sequences]=self.makeExampleStimulusParts();
            stimulusLibrary = self.createPopulatedStimulusLibrary() ;
            
            %stimulusLibrary.SelectedOutputable=stimulusLibrary.Sequences{2};            
            stimulusLibrary.setSelectedOutputableByClassNameAndIndex('ws.StimulusSequence', 2) ;            
            self.verifyTrue(stimulusLibrary.isSelfConsistent()) ;
            
            encodedStimulusLibrary = ws.encodeAnythingForPersistence(stimulusLibrary) ;
            stimulusLibraryCheck = ws.decodeEncodingContainer(encodedStimulusLibrary) ;
            
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
            
            stimulusLibraryCheck = ws.StimulusLibrary() ;
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
            stimulusLibraryCopy = ws.copy(stimulusLibrary) ;
            
            % check
            self.verifyTrue(stimulusLibraryCopy.isSelfConsistent()) ;
            self.verifyEqual(stimulusLibrary,stimulusLibraryCopy) ;  % test value equality
            self.verifyTrue(all(stimulusLibrary~=stimulusLibraryCopy)) ;  % test (lack of) identity
            
            % another copy, to make sure no aliasing is going on
            stimulusLibraryCopyCopy = ws.copy(stimulusLibraryCopy) ;
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
