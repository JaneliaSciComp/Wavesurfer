classdef DeleteStimulusTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            delete(findall(0,'Style','Figure'))
            ws.reset() ;
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Style','Figure'))
            ws.reset() ;
        end
    end

    methods (Test)        
        function theTest(self)
            wsModel = wavesurfer('--nogui') ;
            doomedStimulusIndex = wsModel.addNewStimulus() ;  % this is now the 2nd stimulus
            %doomedStimulus = wsModel.Stimulation.StimulusLibrary.Stimuli{1} ;
            %wsModel.Stimulation.StimulusLibrary.deleteItem(doomedStimulus) ;
            wsModel.deleteStimulusLibraryItem('ws.Stimulus', doomedStimulusIndex) ;
            %doomedStimulus2 = wsModel.Stimulation.StimulusLibrary.Stimuli{1} ;
            doomedStimulus2Index = 1 ;
            wsModel.isStimulusLibraryItemInUse('ws.Stimulus', doomedStimulus2Index) ;
            self.verifyTrue(true) ;
        end
    end  % test methods

 end  % classdef
