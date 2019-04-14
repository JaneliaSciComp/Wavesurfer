classdef NumberOfElectrodesTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached.  
    % (Can be a simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            ws.clearDuringTests
        end
    end

    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            ws.clearDuringTests
        end
    end
    
    methods (Test)
        function testCorrectNumberOfElectrodes(self)
            thisDirName=fileparts(mfilename('fullpath'));
            [wsModel, wsController] = wavesurfer('--noprefs') ;

            % Load a fast protocol with 2 electrodes and one with 6
            % electrodes
            wsModel.setFastProtocolProperty(1, ...
                                            'ProtocolFileName', ...
                                            fullfile(thisDirName,'folder_for_fast_protocol_testing/Two Electrodes Changed Names.wsp') ) ;
            wsModel.setFastProtocolProperty(2, ...
                                            'ProtocolFileName', ...
                                            fullfile(thisDirName,'folder_for_fast_protocol_testing/Six Electrodes.wsp') ) ;
                                        
            % Load fast protocol 1 with 2 electrodes, then fast protocol 2 with 6 electrodes
            % Store number of electrodes in figure and manager for
            % comparison
            storeNumberOfElectrodesInFigure = zeros(1,2);
            storeNumberOfElectrodesInModel = zeros(1,2);            
            for i = 1:2 ,
                try
                    ws.fakeControlActuationInTestBang(wsController, 'FastProtocolButtons', i) ;
                catch exception
                    % If just warnings, print them but proceed.  Otherwise,
                    % rethrow.
                    indicesOfWarningPhrase = strfind(exception.identifier,'ws:warningsOccurred') ;
                    isWarning = (~isempty(indicesOfWarningPhrase) && indicesOfWarningPhrase(1)==1) ;
                    if isWarning ,
                        disp(exception.getReport()) ;
                    else
                        rethrow(exception) ;
                    end
                end
                
                % % Make the electrode manager visible so the updates actually do something
                % wsModel.IsElectrodeManagerFigureVisible = true ;            
                
                electrodeManagerController = wsController.ElectrodeManagerController ;
                storeNumberOfElectrodesInFigure(i) = length(electrodeManagerController.LabelEdits);
                storeNumberOfElectrodesInModel(i) = wsModel.ElectrodeCount ;
            end
            
            % Compare number of electrodes in figure and model
            self.verifyEqual(storeNumberOfElectrodesInFigure, storeNumberOfElectrodesInModel) ;
            
            wsController.quit() ;
        end  % function
        
        function testDimensionsOfGain(self)
            wsModel = wavesurfer('--nogui', '--noprefs') ;
            gainOrResistanceWithNiceUnits = wsModel.getGainOrResistancePerTestPulseElectrodeWithNiceUnits() ;
            self.verifyEmpty(gainOrResistanceWithNiceUnits) ;
            wsModel.addNewElectrode() ;
            gainOrResistanceWithNiceUnits = wsModel.getGainOrResistancePerTestPulseElectrodeWithNiceUnits() ;
            self.verifyLength(gainOrResistanceWithNiceUnits, 1) ;
            delete(wsModel) ;
        end
    end  % test methods
    
end  % classdef
