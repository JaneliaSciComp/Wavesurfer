classdef MulticlampCommanderSocket < ws.Model % & ws.Mimic
    % Represents a "socket" for talking to one or more Axon Multiclamp
    % Commander instances.
        
    properties (Dependent=true, SetAccess=immutable)
        IsOpen  % true iff a connection to the Multiclamp Commander program(s) have been established, and hasn't failed yet       
    end
    
    properties (Dependent=true, SetAccess=immutable)
        %IsOpen  % true iff a connection to the EpcMaster program has been established, and hasn't failed yet        
        NElectrodes
    end

    properties  (Access=protected)
        ElectrodeIDs_ = zeros(0,1)
    end
    
    methods
        function self = MulticlampCommanderSocket()
            %self@ws.Model() ;
            %self.IsOpen_=false;
        end  % function
        
        function delete(self)
            self.close();
        end
        
        function err=open(self)
            % Attempt to get MCC (the application) into a state where
            % it's ready to communicate.
            % Returns an exception if this fails at any stage, otherwise
            % returns [].
            % Consumers don't generally need to call this at all, because all
            % the methods do an open() if IsOpen is false.
            
            % Fallback
            err=[];
            
            % If there's already a live connection, declare success
            if self.IsOpen ,
                return
            end
            
            % Establish a connection to the EPCMaster program
            self.updateElectrodeList_();
            
            % If get here, all is well
        end
        
        function self=close(self)
            ws.axon.MulticlampTelegraph('stop');
            self.ElectrodeIDs_ = zeros(0,1) ;
        end  % function
        
        function self=reopen(self)
            % Close the connection, then open it.
            self.close();
            self.open();
        end
        
        function mimic(self,other)
            self.ElectrodeIDs_ = other.ElectrodeIDs_ ;
        end
        
        %%
        function value=get.IsOpen(self)
            value=~isempty(self.ElectrodeIDs_) ;
        end  % function
        
        %%
        function value=get.NElectrodes(self)
            value=length(self.ElectrodeIDs_);
        end  % function
        
        %%
        function value=getElectrodeParameter(self,electrodeIndex,parameterName)
            methodName=sprintf('get%s',parameterName);
            value=self.(methodName)(electrodeIndex);
        end
        
        function [electrodeState,err]=getElectrodeState(self,electrodeIndex)
            err=self.checkIfOpenAndValidElectrodeIndex_(electrodeIndex);                        
            if isempty(err) ,
                electrodeID=self.ElectrodeIDs_(electrodeIndex);
                %electrodeState=ws.dabs.axon.MulticlampTelegraph('getElectrode',electrodeID);
                %ws.dabs.axon.MulticlampTelegraph('requestElectrodeState',electrodeID)
                %ws.sleep(0.05);  % Wait a bit for response (how short can we make this?)
                %electrodeState=ws.dabs.axon.MulticlampTelegraph('collectElectrodeState',electrodeID);
                electrodeState=ws.axon.MulticlampTelegraph('getElectrodeState',electrodeID);
                if isempty(electrodeState) ,
                    errorId='MulticlampCommanderSocket:NoResponseToElectrodeStateRequest';
                    errorMessage=sprintf('No response to request for state of Axon electrode %d.',electrodeIndex);
                    err=MException(errorId,errorMessage);
                else
                    err=[];
                end
            else
                electrodeState=[];
            end               
        end

        function [mode,err]=getMode(self,electrodeIndex)
            err=self.checkIfOpenAndValidElectrodeIndex_(electrodeIndex);
            if isempty(err) ,
                [electrodeState,err]=self.getElectrodeState(self,electrodeIndex);
                if isempty(err)
                    [mode,err]=ws.MulticlampCommanderSocket.modeFromElectrodeState(electrodeState);
                else
                    mode=[];
                end
            else
                mode=[];
            end
        end  % function

        function [value,err]=getCurrentMonitorNominalGain(self,electrodeIndex)
            % Returns the nominal current monitor gain, in V/pA
            err=self.checkIfOpenAndValidElectrodeIndex_(electrodeIndex);
            if isempty(err) ,
                [electrodeState,err]=self.getElectrodeState(self,electrodeIndex);
                if isempty(err)
                    [value,err]=ws.MulticlampCommanderSocket.currentMonitorGainFromElectrodeState(electrodeState);
                else
                    value=nan;
                end
            else
                value=nan;
            end               
        end  % function

        function [value,err]=getCurrentMonitorRealizedGain(self,electrodeIndex)            
            % Returns the realized current monitor gain, in V/pA
            [value,err]=self.getCurrentMonitorNominalGain(electrodeIndex);  % no distinction between nominal and real current monitor gain in Axon
        end  % function            

        function [value,err]=getVoltageMonitorGain(self,electrodeIndex)
            % Returns the current voltage gain, in V/mV
            err=self.checkIfOpenAndValidElectrodeIndex_(electrodeIndex);
            if isempty(err) ,
                [electrodeState,err]=self.getElectrodeState(self,electrodeIndex);
                if isempty(err)
                    [value,err]=ws.MulticlampCommanderSocket.voltageMonitorGainFromElectrodeState(electrodeState);
                else
                    value=nan;
                end
            else
                value=nan;
            end
        end  % function

        function [value,err]=getIsCommandEnabled(self,electrodeIndex)
            % Returns whether the external command is enabled.  If the
            % hardware doesn't support setting this, returns true.  Returns
            % the empty matrix if there's a problem getting the value from
            % the hardware.
            err=self.checkIfOpenAndValidElectrodeIndex_(electrodeIndex);
            if isempty(err) ,
                [electrodeState,err]=self.getElectrodeState(self,electrodeIndex);
                if isempty(err)
                    value=(electrodeState.ExtCmdSens~=0);
                else
                    value=[];
                end
            else
                value=[];
            end
        end  % function            

        function [value,err]=getCurrentCommandGain(self,electrodeIndex)
            err=self.checkIfOpenAndValidElectrodeIndex_(electrodeIndex);
            if isempty(err) ,
                [electrodeState,err]=self.getElectrodeState(self,electrodeIndex);
                if isempty(err)
                    [value,err] = ws.MulticlampCommanderSocket.currentCommandGainFromElectrodeState(electrodeState);
                else
                    value=nan;
                end
            else
                value=nan;
            end
        end  % function            

        function [value,err]=getVoltageCommandGain(self,electrodeIndex)
            % Returns the command voltage gain, in mV/V
            err=self.checkIfOpenAndValidElectrodeIndex_(electrodeIndex);
            if isempty(err) ,
                [electrodeState,err]=self.getElectrodeState(self,electrodeIndex);
                if isempty(err)
                    [value,err]=ws.MulticlampCommanderSocket.voltageCommandGainFromElectrodeState(electrodeState);
                else
                    value=nan;
                end
            else
                value=nan;
            end                
        end  % function
        
        function [overallError,perElectrodeErrors,modes,currentMonitorGains,voltageMonitorGains,currentCommandGains,voltageCommandGains,isCommandEnabled]=...
            getModeAndGainsAndIsCommandEnabled(self,electrodeIndices)
        
            nArgumentElectrodes=length(electrodeIndices); 
            overallError=[]; %#ok<NASGU>
            perElectrodeErrors=cell(nArgumentElectrodes,1);
            modes=cell(nArgumentElectrodes,1);
            currentMonitorGains=nan(nArgumentElectrodes,1);
            voltageMonitorGains=nan(nArgumentElectrodes,1);
            currentCommandGains=nan(nArgumentElectrodes,1);
            voltageCommandGains=nan(nArgumentElectrodes,1);
            isCommandEnabled=cell(nArgumentElectrodes,1);

            % Open if necessary
            overallError=self.open();
            if ~isempty(overallError) ,
                return
            end
            
            nAxonElectrodes=length(self.ElectrodeIDs_);
            for i=1:nArgumentElectrodes ,
                electrodeIndex=electrodeIndices(i);
                if ( 1<=electrodeIndex && electrodeIndex<=nAxonElectrodes ) ,
                    [electrodeState,thisError]=self.getElectrodeState(electrodeIndex);
                    if isempty(electrodeState) ,
                        perElectrodeErrors{i}=thisError;
                    else
                        [modes{i},modeError] = ws.MulticlampCommanderSocket.modeFromElectrodeState(electrodeState);
                        [currentMonitorGains(i),currentMonitorError] = ws.MulticlampCommanderSocket.currentMonitorGainFromElectrodeState(electrodeState);
                        [voltageMonitorGains(i),voltageMonitorError] = ws.MulticlampCommanderSocket.voltageMonitorGainFromElectrodeState(electrodeState);
                        [currentCommandGains(i),currentCommandError] = ws.MulticlampCommanderSocket.currentCommandGainFromElectrodeState(electrodeState);
                        [voltageCommandGains(i),voltageCommandError] = ws.MulticlampCommanderSocket.voltageCommandGainFromElectrodeState(electrodeState);
                        %isCommandEnabled{i} = (electrodeState.ExtCmdSens~=0);  
                        thisMode=modes{i};
                        isCommandEnabled{i} = ~isequal(thisMode,'i_equals_zero') ; 
                            % This should always be true, b/c it's
                            % not really an independent parameter for an
                            % Axon amp (actually, it should be false for
                            % I=0 mode, b/c that mode effectively overrides
                            % the current command gain setting.
                        if ~isempty(modeError) ,
                            perElectrodeErrors{i} = modeError;
                        elseif ~isempty(currentMonitorError) ,
                            perElectrodeErrors{i} = currentMonitorError;
                        elseif ~isempty(voltageMonitorError) ,
                            perElectrodeErrors{i} = voltageMonitorError;
                        elseif ~isempty(currentCommandError) ,
                            perElectrodeErrors{i} = currentCommandError;
                        elseif ~isempty(voltageCommandError) ,
                            perElectrodeErrors{i} = voltageCommandError;
                        end
                    end
                else
                    errorId='MulticlampCommanderSocket:InvalidElectrodeIndex';
                    errorMessage=sprintf('Invalid electrode index (%d) for Multiclamp Commander',electrodeIndex);
                    perElectrodeErrors{i}=MException(errorId,errorMessage);
                end
            end
        end  % function            
    end  % public methods

    methods (Access=protected)
        function updateElectrodeList_(self)
            % Update the list of electrode IDs that we know about
            electrodeIDs=ws.axon.MulticlampTelegraph('getAllElectrodeIDs');
            sortedElectrodeIDs=ws.MulticlampCommanderSocket.sortElectrodeIDs(electrodeIDs);
            self.ElectrodeIDs_ = sortedElectrodeIDs;  % want them ordered reliably
        end  % function        
    end  % protected methods
    
    methods (Static=true)  % public class methods
        function units=unitsFromUnitsString(unitsAsString)
            % Convert a units string of the kind produced by
            % ws.dabs.axon.MulticlampTelegraph().
            units=unitsAsString ;
        end  % function

        function [targetNumber,err]=convertToVoltsPerPicoamp(sourceNumber,sourceUnits)
            err = [] ;
            switch sourceUnits ,
                case 'V/A',                     
                    scale = 1e-12 ;
                case 'V/mA', 
                    scale = 1e-9 ;
                case 'V/uA',
                    scale = 1e-6 ;
                case 'V/nA',
                    scale = 1e-3 ;
                case 'V/pA',
                    scale = 1 ;
                otherwise
                    scale=NaN;
                    errorId='MulticlampCommanderSocket:unableToConvertToTargetUnits';
                    errorMessage='Unable to convert source quantity to target units.';
                    err=MException(errorId,errorMessage);
            end
            targetNumber = scale * sourceNumber ;
        end  % function

        function [targetNumber,err]=convertToVoltsPerMillivolt(sourceNumber,sourceUnits)
            err = [] ;
            switch sourceUnits ,
                case 'V/V',                     
                    scale = 1e-3 ;
                case 'V/mV', 
                    scale = 1 ;
                case 'V/uV',
                    scale = 1e3 ;
                otherwise
                    scale=NaN;
                    errorId='MulticlampCommanderSocket:unableToConvertToTargetUnits';
                    errorMessage='Unable to convert source quantity to target units.';
                    err=MException(errorId,errorMessage);
            end
            targetNumber = scale * sourceNumber ;
        end  % function

        function [value,err]=modeFromElectrodeState(electrodeState)
            % Returns the current mode as a string
            operatingModeString=electrodeState.OperatingMode;
            switch operatingModeString ,
                case 'V-Clamp' ,
                    value='vc';
                    err=[];
                case 'I-Clamp' ,
                    value='cc';
                    err=[];
                case 'I = 0' ,
                    value='i_equals_zero';
                    err=[];
                otherwise
                    %value='vc';  % fallback
                    value=[];
                    errorId='MulticlampCommanderSocket:electrodeInUnknownMode';
                    errorMessage='Electrode is in an unknown mode.';
                    err=error(errorId,errorMessage);
            end
        end  % function
        
        function [value,err]=currentMonitorGainFromElectrodeState(electrodeState)
            % Returns the current monitor gain, in V/pA
            if isequal(electrodeState.OperatingMode,'V-Clamp') ,
                if isequal(electrodeState.ScaledOutSignal,'Im') ,
                    rawScaleFactor=electrodeState.ScaleFactor*electrodeState.Alpha;
                    rawUnits=electrodeState.ScaleFactorUnits;
                    %rawUnits=ws.MulticlampCommanderSocket.unitsFromUnitsString(rawUnitsAsString);
                    %targetUnits=ws.SIUnit('V')/ws.SIUnit('pA');
                    [value,err]=ws.MulticlampCommanderSocket.convertToVoltsPerPicoamp(rawScaleFactor,rawUnits);
                else
                    value=nan;
                    errorId='MulticlampCommanderSocket:notConfiguredToOutputMembraneCurrent';
                    errorMessage='Multiclamp Commander is not configured to output membrane current.';
                    err=MException(errorId,errorMessage);                    
                end
            else
                value=nan;
                err=[];  % this is not an error, it's part of normal operation
            end
        end  % function
        
        function [value,err]=voltageMonitorGainFromElectrodeState(electrodeState)
            % Returns the current monitor gain, in V/mV
            if isequal(electrodeState.OperatingMode,'I-Clamp') || isequal(electrodeState.OperatingMode,'I = 0') ,
                if isequal(electrodeState.ScaledOutSignal,'Vm') ,
                    rawScaleFactor = electrodeState.ScaleFactor * electrodeState.Alpha ;
                    rawUnits=electrodeState.ScaleFactorUnits;
                    %rawUnits=ws.MulticlampCommanderSocket.unitsFromUnitsString(rawUnitsAsString);
                    %targetUnits=ws.SIUnit('V')/ws.SIUnit('mV');
                    %[value,err]=ws.MulticlampCommanderSocket.numberForTargetUnits(targetUnits,rawScaleFactor,rawUnits);
                    [value,err]=ws.MulticlampCommanderSocket.convertToVoltsPerMillivolt(rawScaleFactor,rawUnits);
                else
                    value=nan;                    
                    errorId='MulticlampCommanderSocket:notConfiguredToOutputMembranePotential';
                    errorMessage='Multiclamp Commander is not configured to output membrane potential.';
                    err=MException(errorId,errorMessage);
                end
            else
                value=nan;
                err=[];  % this is not an error, it's part of normal operation
            end
        end  % function
        
        function [value,err]=currentCommandGainFromElectrodeState(electrodeState)
            % Returns the current command gain, in pA/V
            % This one doesn't really need an error output, but we'll leave
            % it for consistentcy.
            if isequal(electrodeState.OperatingMode,'I-Clamp') || isequal(electrodeState.OperatingMode,'I = 0') ,
                rawScaleFactor=electrodeState.ExtCmdSens;
                value = 1e12 * rawScaleFactor ;  % convert x A/V => y pA/V
                %rawUnits=ws.SIUnit('A')/ws.SIUnit('V');
                %targetUnits=ws.SIUnit('pA')/ws.SIUnit('V');
                %[value,err]=ws.MulticlampCommanderSocket.numberForTargetUnits(targetUnits,rawScaleFactor,rawUnits);
                err=[];
            else
                value=nan;
                err=[];  % this is not an error, it's part of normal operation
            end
        end  % function
        
        function [value,err]=voltageCommandGainFromElectrodeState(electrodeState)
            % Returns the voltage command gain, in mV/V
            % This one doesn't really need an error output, but we'll leave
            % it for consistentcy.
            if isequal(electrodeState.OperatingMode,'V-Clamp') ,
                rawScaleFactor=electrodeState.ExtCmdSens;
                value = 1e3 * rawScaleFactor ;  % convert x V/V => y mV/V
                %rawUnits=ws.SIUnit('V')/ws.SIUnit('V');
                %targetUnits=ws.SIUnit('mV')/ws.SIUnit('V');
                %[value,err]=ws.MulticlampCommanderSocket.numberForTargetUnits(targetUnits,rawScaleFactor,rawUnits);
                err = [] ;
            else
                value = nan ;
                err = [] ;  % this is not an error, it's part of normal operation
            end
        end  % function

        function aOrB=multiclampAOrBFromElectrodeID(electrodeID)
            % Using a heurisitic, determine if the given electrodeID is for
            % a 700A or 700B.
            %
            % The electrodeID is an unsigned 32-bit int.  For 700A, the
            % channel ID (either 1 or 2) is stored in the high byte.  For a 700B, the
            % channel ID is stored in the high nibble of the high byte.
            % So for a 700A, the high nibble should always be 0, but for a
            % 700B it should be 1 or 2.
            id=uint32(electrodeID);
            highNibbleOfHighByte=bitshift(id,-28);
            if highNibbleOfHighByte==0 ,
                aOrB='A';
            else
                aOrB='B';
            end
        end  % function

        function electrodeIDStruct=electrodeIDStructFromElectrodeID(electrodeID)
            temp=cell(size(electrodeID));
            electrodeIDStruct=struct('aOrB',temp, ...
                                     'comPortID',temp, ...
                                     'axoBusID',temp, ...
                                     'serialNumber',temp, ...
                                     'terminalID',temp);
            for i=1:numel(electrodeID) ,
                id=uint32(electrodeID(i));                
                aOrB=ws.MulticlampCommanderSocket.multiclampAOrBFromElectrodeID(id);
                if isequal(aOrB,'A') ,
                    % 700A
                    terminalID=uint16(bitshift(id,-16));
                    axoBusID=uint8(bitand(bitshift(id,-8),255));
                    comPortID=uint8(bitand(id,255));
                    serialNumber=[];
                else
                    % 700B
                    serialNumber=uint32(bitand(id,268435455));  % 268435455==2^28-1
                    terminalID=uint8(bitshift(id,-28));
                    axoBusID=[];
                    comPortID=[];
                end
                electrodeIDStruct(i)=struct('aOrB',aOrB, ...
                                            'comPortID',comPortID, ...
                                            'axoBusID',axoBusID, ...
                                            'serialNumber',serialNumber, ...
                                            'terminalID',terminalID);
            end
        end  % function

        function electrodeID=electrodeIDFromElectrodeIDStruct(electrodeIDStruct)
            electrodeID=zeros(size(electrodeIDStruct),'uint32');
            for i=1:numel(electrodeIDStruct) ,
                s=electrodeIDStruct(i);
                if isequal(s.aOrB,'A') ,
                    % 700A
                    electrodeID(i)=bitor(bitshift(uint32(s.terminalID),16), ...
                                         bitor(bitshift(uint32(s.axoBusID),8), ...
                                               uint32(s.comPortID))) ;
                else
                    % 700B
                    electrodeID(i)=bitor(s.serialNumber, ...
                                         bitshift(uint32(s.terminalID),28)) ;
                end
            end
        end  % function
        
        function sorted = sortElectrodeIDStructs(s)
            % Sort electrodeIDStructs as we want them to be sorted.
            % This relies on sort() doing a stable sort.
            sorted=s;  
            
            % Sort by terminalID
            terminalID=uint16([sorted.terminalID]);
            [~,i]=sort(terminalID);
            sorted=sorted(i);

            % Sort by serialNumber
            serialNumber={sorted.serialNumber};
            serialNumber=cellfun(@(c)(ws.fif(isempty(c),-inf,c)),serialNumber);  % 700As have serialNumber == -inf, so they are left on left end
            [~,i]=sort(serialNumber);
            sorted=sorted(i);
            
            % Sort by axoBusID
            axoBusID={sorted.axoBusID};
            axoBusID=cellfun(@(c)(ws.fif(isempty(c),+inf,c)),axoBusID);  % 700Bs have axoBusID == inf, so they are left on right end
            [~,i]=sort(axoBusID);
            sorted=sorted(i);
            
            % Sort by com port
            comPortID={sorted.comPortID};
            comPortID=cellfun(@(c)(ws.fif(isempty(c),+inf,c)),comPortID);  % 700Bs have comPortID == inf, so they are left on right end
            [~,i]=sort(comPortID);
            sorted=sorted(i);            
        end  % function
        
        function sortedElectrodeIDs=sortElectrodeIDs(electrodeIDs)
            electrodeIDStructs=ws.MulticlampCommanderSocket.electrodeIDStructFromElectrodeID(electrodeIDs);
            sortedElectrodeIDStructs=ws.MulticlampCommanderSocket.sortElectrodeIDStructs(electrodeIDStructs);
            sortedElectrodeIDs=ws.MulticlampCommanderSocket.electrodeIDFromElectrodeIDStruct(sortedElectrodeIDStructs);
        end  % function
    end  % public class methods

    methods (Access=protected)
        function err=checkIfOpenAndValidElectrodeIndex_(self,electrodeIndex)
            % What it says on the tin.  Returns an MException if not open or invalid trode
            % index.  If returns [], all is well.
            
            if ~self.IsOpen ,                
                errorId='MulticlampCommanderSocket:SocketNotOpen';
                errorMessage='Couldn''t perform operation because MulticlampCommanderSocket not open.';
                error(errorId,errorMessage);
            end

            nElectrodes=length(self.ElectrodeIDs_);
            if ( 1<=electrodeIndex && electrodeIndex<=nElectrodes ) ,
                err=[];
            else
                errorId='MulticlampCommanderSocket:InvalidElectrodeIndex';
                errorMessage='Invalid electrode index';
                err=error(errorId,errorMessage);
            end
        end  % function
    end
    
    methods
        function out = getPropertyValue_(self, name)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to encode private/protected variables, or do
            % some other kind of transformation on encoding, this method can be overridden.
            out = self.(name);
        end
        
        function setPropertyValue_(self, name, value)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to decode private/protected variables, or do
            % some other kind of transformation on decoding, this method can be overridden.
            self.(name) = value;
        end        
    end  % protected methods    
    
    methods
        % These are intended for getting/setting *public* properties.
        % I.e. they are for general use, not restricted to special cases like
        % encoding or ugly hacks.
        function result = get(self, propertyName) 
            result = self.(propertyName) ;
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end           
    end  % public methods block            
    
    
end  % classdef
