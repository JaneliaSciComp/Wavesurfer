classdef EPCMasterSocketTestCase < matlab.unittest.TestCase
    % To run these tests, need to have EPCMaster/PatchMaster running and
    % set up to accept batch commands.  Can either have a real EPC10
    % attached or be running in demo mode.  Tests only use the first
    % amplifier in the case of multi-amplifier boxes.
    
    methods (Test)
        function testOpening(self)
            ems=ws.EPCMasterSocket();
            self.verifyFalse(ems.IsOpen);
            ems.open();
            self.verifyTrue(ems.IsOpen);
            ems.close();
            self.verifyFalse(ems.IsOpen);
        end
        
        function testReopening(self)
            ems=ws.EPCMasterSocket();
            self.verifyFalse(ems.IsOpen);
            ems.open() ;
            self.verifyTrue(ems.IsOpen);            
            ems.reopen() ;
            self.verifyTrue(ems.IsOpen);
            ems.close();
            self.verifyFalse(ems.IsOpen);
        end
        
        function testModeSettingAndGetting(self)
            ems=ws.EPCMasterSocket();
            ems.open();
            ems.setMode(1,'vc');
            mode=ems.getElectrodeParameter(1,'Mode');  % getMode(1)
            self.verifyEqual(mode,'vc');
            ems.setMode(1,'cc');
            mode=ems.getElectrodeParameter(1,'Mode');  % ems.getMode(1);
            self.verifyEqual(mode,'cc');            
        end
        
        function testVoltageMonitorGainSettingAndGetting(self)
            electrodeIndex=1;
            ems=ws.EPCMasterSocket();          
            ems.open();
            detents=ems.VoltageMonitorGainDetents;
            for i=1:length(detents) ,
                value=detents(i);
                ems.setVoltageMonitorGain(electrodeIndex,value);
                valueCheck=ems.getElectrodeParameter(electrodeIndex,'VoltageMonitorGain');  % ems.getVoltageMonitorGain(electrodeIndex);
                self.verifyEqual(valueCheck,value);
            end
        end

        function testCurrentMonitorNominalGainSettingAndGetting(self)
            electrodeIndex=1;
            ems=ws.EPCMasterSocket();          
            ems.open();
            detents=ems.CurrentMonitorNominalGainDetents;
            ems.setMode(electrodeIndex,'vc');  % has to be in VC to get full range of current monitor gain settings
            for i=1:length(detents) ,
                value=detents(i);
                ems.setCurrentMonitorNominalGain(electrodeIndex,value);
                valueCheck=ems.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain');  % ems.getCurrentMonitorNominalGain(electrodeIndex);
%                 if value~=valueCheck
%                     keyboard
%                 end
                self.verifyEqual(valueCheck,value);
            end
        end

        function testCurrentCommandGainSettingAndGetting(self)
            electrodeIndex=1;
            ems=ws.EPCMasterSocket();          
            ems.open();
            detents=ems.CurrentCommandGainDetents;
            ems.setMode(electrodeIndex,'vc');  % has to be in VC to set this
            for i=1:length(detents) ,
                value=detents(i);
                ems.setCurrentCommandGain(electrodeIndex,value);
                valueCheck=ems.getElectrodeParameter(electrodeIndex,'CurrentCommandGain');  % ems.getCurrentCommandGain(electrodeIndex);
                self.verifyEqual(valueCheck,value);
            end
        end
        
        function testVoltageCommandGainSettingAndGetting(self)
            electrodeIndex=1;
            ems=ws.EPCMasterSocket();          
            ems.open();
            detents=ems.VoltageCommandGainDetents;
            ems.setMode(electrodeIndex,'vc');  % has to be in VC to set this
            for i=1:length(detents) ,
                value=detents(i);
                ems.setVoltageCommandGain(electrodeIndex,value);
                valueCheck=ems.getElectrodeParameter(electrodeIndex,'VoltageCommandGain');  % ems.getVoltageCommandGain(electrodeIndex);
                self.verifyEqual(valueCheck,value);
            end
        end
        
        function testGetModeAndGains(self)
            electrodeIndex=1;
            modeValue='vc';
            ems=ws.EPCMasterSocket();          
            ems.open();
            currentMonitorNominalGainValue=ems.CurrentMonitorNominalGainDetents(1);
            voltageMonitorGainValue=ems.VoltageMonitorGainDetents(1);
            currentCommandGainValue=ems.CurrentCommandGainDetents(1);
            voltageCommandGainValue=ems.VoltageCommandGainDetents(2);
            isCommandEnabledValue=true;
            ems.setMode(electrodeIndex,modeValue);            
            ems.setCurrentMonitorNominalGain(electrodeIndex,currentMonitorNominalGainValue);            
            ems.setVoltageMonitorGain(electrodeIndex,voltageMonitorGainValue);            
            ems.setCurrentCommandGain(electrodeIndex,currentCommandGainValue);            
            ems.setVoltageCommandGain(electrodeIndex,voltageCommandGainValue);            
            ems.setIsCommandEnabled(electrodeIndex,isCommandEnabledValue);            
            [overallError, ...
             perElectrodeErrorsCellArray, ...
             modeCheckCellArray, ...
             currentMonitorRealizedGainCheck, ...
             voltageMonitorGainCheck, ...
             currentCommandGainCheck, ...
             voltageCommandGainCheck, ...
             isCommandEnabledCheckCellArray]= ...
                ems.getModeAndGainsAndIsCommandEnabled(electrodeIndex);
            self.verifyTrue(isempty(overallError));
            self.verifyEqual(length(perElectrodeErrorsCellArray),1);
            perElectrodeError=perElectrodeErrorsCellArray{1};
            self.verifyTrue(isempty(perElectrodeError));            
            self.verifyEqual(length(modeCheckCellArray),1);
            modeCheck=modeCheckCellArray{1};            
            self.verifyEqual(modeCheck,modeValue);
            self.verifyTrue(abs(currentMonitorRealizedGainCheck./currentMonitorNominalGainValue-1)<0.05);  
                % comparing nominal and relaized, so will only approximately match
            self.verifyEqual(voltageMonitorGainCheck,voltageMonitorGainValue);
            self.verifyEqual(currentCommandGainCheck,currentCommandGainValue);
            self.verifyEqual(voltageCommandGainCheck,voltageCommandGainValue);           
            self.verifyEqual(length(isCommandEnabledCheckCellArray),1);
            isCommandEnabledCheck=isCommandEnabledCheckCellArray{1};
            self.verifyEqual(isCommandEnabledCheck,isCommandEnabledValue);            
        end
        
    end  % tests
end
