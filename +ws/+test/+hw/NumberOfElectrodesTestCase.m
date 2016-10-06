classdef NumberOfElectrodesTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end
    
    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            delete(findall(0,'Style','Figure')) ;
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end
    
    methods (Test)
        function testCorrectNumberOfElectrodes(self)
            thisDirName=fileparts(mfilename('fullpath'));
            %[wsModel,wsController]=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_with_DO.m'));
            [wsModel,wsController]=wavesurfer() ;

%             % Add the channels
%             wsModel.addAIChannel() ;
%             wsModel.addAIChannel() ;
%             wsModel.addAIChannel() ;
%             wsModel.addAIChannel() ;
%             wsModel.addAOChannel() ;
%             wsModel.addAOChannel() ;
%             wsModel.addDOChannel() ;
            
            % Load a fast protocol with 2 electrodes and one with 6
            % electrodes
            fpOne = wsModel.FastProtocols{1};
            fpOne.ProtocolFileName = fullfile(thisDirName,'folder_for_fast_protocol_testing/Two Electrodes Changed Names.cfg');
            fpTwo = wsModel.FastProtocols{2};
            fpTwo.ProtocolFileName = fullfile(thisDirName,'folder_for_fast_protocol_testing/Six Electrodes.cfg');
            storeNumberOfElectrodesInFigure = zeros(1,2);
            storeNumberOfElectrodesInModel = zeros(1,2);
            
            % Load fast protocol 1 with 2 electrodes, then fast protocol 2 with 6 electrodes
            % Store number of electrodes in figure and manager for
            % comparison
            for i = 1:2 ,
                %pressedButtonHandle = wsController.Figure.FastProtocolButtons(currentButtonIndex);
                try
                    %wsController.FastProtocolButtonsActuated(pressedButtonHandle);
                    wsController.fakeControlActuatedInTest('FastProtocolButtons', i) ;
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
                
                electrodeManagerController = wsController.ElectrodeManagerController ;
                storeNumberOfElectrodesInFigure(i) = length(electrodeManagerController.Figure.LabelEdits);
                storeNumberOfElectrodesInModel(i) = wsModel.Ephys.ElectrodeManager.NElectrodes;
            end
            
            % Compare number of electrodes in figure and model
            self.verifyEqual( storeNumberOfElectrodesInFigure,storeNumberOfElectrodesInModel);
            
            wsController.quit() ;
        end  % function
        
    end  % test methods
    
end  % classdef
