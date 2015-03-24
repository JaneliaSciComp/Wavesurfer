classdef EPCMasterSocket < handle
    % Represents a "socket" for talking to Heka EPCMaster or PatchMaster.
    
    %%
    properties (SetAccess=protected, Hidden=true)
        %ModeDetents={ws.ElectrodeMode.VC ws.ElectrodeMode.CC}';
        CurrentMonitorNominalGainDetents= 1e-3*[ ...
            0.005 ...
            0.010 ...
            0.020 ...
            0.050 ...
            0.100 ...
            0.200 ...
            0.5 ...
            1.0 ...
            2.0 ...
            5.0 ...
            10 ...
            20 ...
            50 ...
            100 ...
            200 ...
            500 ...
            1000 ...
            2000 ]';  % V/pA
        VoltageMonitorGainDetents= [ ...
            0.010 0.100]';  % V/mV
        CurrentCommandGainDetents= [ ...
            100 1000 10e3 100e3]';  % pA/V
        VoltageCommandGainDetents= [ ...
            0 10 20]';  % mV/V (the hardware allows for a (largely) arbitrary setting, but these are convenient values for testing)
    end
    
    %%
    properties  (Access=protected)
        NextCommandIndex_  % Each command has to have an index.  EPCMaster keeps track of this index, and will ignore commands with an index <= the 
                           % index of a command it has previously responded to.
        IsOpen_  % true iff a connection to the EpcMaster program has been established, and hasn't failed yet       
        HasCommandOnOffSwitch_  % true iff the EPC is a model that has an explicit on/off switch for the external command
    end
    
    %%
    properties (Dependent=true, SetAccess=immutable)
        IsOpen  % true iff a connection to the EpcMaster program has been established, and hasn't failed yet        
        %NextCommandIndex
        HasCommandOnOffSwitch
    end
    
    %%
    properties (Constant=true, Hidden=true)
        EPCMasterDirName_='C:/Program Files (x86)/HEKA/EpcMaster';
        CommandFileName_='C:/Program Files (x86)/HEKA/EpcMaster/E9Batch.In';
        ResponseFileName_='C:/Program Files (x86)/HEKA/EpcMaster/E9Batch.Out';        
    end
    
    %% Some properties that are read-only
    properties (GetAccess=public, SetAccess=immutable, Hidden=true)
        CurrentMonitorNominalGainDetentsWithSpaceHolders
    end    
    
    methods
        %%
        function self=EPCMasterSocket()
            self.CurrentMonitorNominalGainDetentsWithSpaceHolders = ...
                self.computeCurrentMonitorNominalGainDetentsWithSpaceHolders_();
            self.IsOpen_=false;
            %self.CommandFileID_=[];
            self.NextCommandIndex_=1;
            self.HasCommandOnOffSwitch_=[];
        end  % function
        
        %%
        function delete(self)
            self.close();
        end
        
        %%
        function err=open(self)
            % Attempt to get EPCMaster (the application) into a state where
            % it's ready to receive new commands, and we've established a few things about what the hardware's capabilities are.
            % *Returns* an exception if this fails at any stage.
            % Users of EPCMasterSocket don't normally need to call this
            % directly, because all the methods automatically open the
            % connection if it's not already open.
            
            % If there's already a live connection, declare success
            if self.IsOpen ,
                err=[];
                return
            end
            
            % Establish a connection to the EPCMaster program
            err=self.establishConnection_();  % this will *return* an exception if unable to make a connection
            if ~isempty(err),
                return
            end
            
            % Probe to determine how we need to interface with the hardware
            [hasCommandOnOffSwitch,err]=self.probeForHasCommandOnOffSwitch_();
            if isempty(err) ,
                self.HasCommandOnOffSwitch_=hasCommandOnOffSwitch;
            else
                return
            end
            
            % If get here, all is well
            self.IsOpen_=true;
            err=[];
        end
        
        %%
        function close(self)
            import ws.utility.*
            self.IsOpen_=false;
            self.HasCommandOnOffSwitch_=[];
            if exist(self.CommandFileName_,'file') ,
                deleteFileWithoutWarning(self.CommandFileName_)
            end            
            if exist(self.ResponseFileName_,'file') ,
                deleteFileWithoutWarning(self.ResponseFileName_)
            end            
        end  % function        

        %%
        function self=reopen(self)
            % Close the connection, then open it.
            self.close();
            self.open();
        end        
        
        %%
        function value=get.IsOpen(self)
            value=self.IsOpen_;
        end  % function
        
        %%
        function mimic(self,other) %#ok<INUSD>
            % EPCMasterSocket's state is all concerned with the state of
            % the connection to hardware, so nothing to do here.
        end
        
%         %%
%         function value=get.NextCommandIndex(self)
%             value=self.NextCommandIndex_;
%         end  % function
        
        %%
        function value=get.HasCommandOnOffSwitch(self)
            value=self.HasCommandOnOffSwitch_;
        end  % function
        
        %%
        function [value,err]=getElectrodeParameter(self,electrodeIndex,parameterName)
            err=[];
            
            switch parameterName ,
                case 'Mode' ,
                    commandTemplate='GetEpcParams-%d Mode';
                case 'CurrentMonitorNominalGain' ,
                    commandTemplate='GetEpcParams-%d Gain';
                case 'CurrentMonitorRealizedGain' ,
                    commandTemplate='GetEpcParams-%d RealGain';
                case 'VoltageMonitorGain' ,
                    commandTemplate='GetEpcParams-%d VmonGain';
                case 'IsCommandEnabled' ,
                    commandTemplate='Get E TestDacToStim%d';
                case 'CurrentCommandGain' ,
                    commandTemplate='GetEpcParams-%d CCGain';
                case 'VoltageCommandGain' ,
                    commandTemplate='GetEpcParams-%d ExtStim';
                otherwise ,
                    errorId='EPCMasterSocket:InvalidParameter';
                    errorMessage='No such parameter';
                    err=MException(errorId,errorMessage);                    
            end
            
            if isempty(err) ,
                err=self.open();  % does nothing if already open
                if isempty(err) ,
                    commandString=sprintf(commandTemplate,electrodeIndex);
                    [responseString,err]=self.issueCommandAndGetResponse(commandString);
                    if isempty(err) ,
                        methodName=sprintf('parse%sResponse',parameterName);
                        [value,err]=ws.EPCMasterSocket.(methodName)(responseString);
                    else
                        value=[];
                    end
                else
                    value=[];
                end
            else
                value=[];
            end
        end
        
        %%
        function err=setElectrodeParameter(self,electrodeIndex,parameterName,newValue)
            methodName=sprintf('set%s',parameterName);
            err=self.(methodName)(electrodeIndex,newValue);
        end
        
%         %%
%         function [mode,err]=getMode(self,electrodeIndex)
%             err=self.open();  % does nothing if already open
%             if isempty(err) ,
%                 commandString=sprintf('GetEpcParams-%d Mode',electrodeIndex);
%                 [responseString,err]=self.issueCommandAndGetResponse(commandString);
%                 if isempty(err) ,
%                     [mode,err]=ws.EPCMasterSocket.parseModeResponse(responseString);
%                 else
%                     mode=[];
%                 end
%             else
%                 mode=[];
%             end
%         end  % function

        %%
        function err=setMode(self,electrodeIndex,newMode)
            import ws.utility.*
            
            err=[]; %#ok<NASGU>
            if ~(isequal(newMode,ws.ElectrodeMode.VC) || isequal(newMode,ws.ElectrodeMode.CC)) ,
                errorId='EPCMasterSocket:InvalidMode';
                errorMessage='Couldn''t set mode because given value is not valid.';
                err=MException(errorId,errorMessage);
                return
            end
            
            % Open if necessary
            err=self.open();
            if ~isempty(err) ,
                return
            end
            
            commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
            [responseString1,err]=self.issueCommandAndGetResponse(commandString1); %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return
            end              
            newModeIndex=fif(isequal(newMode,ws.ElectrodeMode.CC),4,3);
              % 4 == Current clamp
              % 3 == Whole cell
            commandString2=sprintf('Set E Mode %d',newModeIndex);
            [responseString2,err]=self.issueCommandAndGetResponse(commandString2); %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            %sleep(0.1);  % wait a bit for that to go through (50 ms is too short for it to work reliably)
            if ~isempty(err) ,
                return
            end
            
            % Check that that worked
            newModeCheck=self.getElectrodeParameter(electrodeIndex,'Mode');
            if ~isequal(newMode,newModeCheck) ,
                errorId='EPCMasterSocket:SettingModeDidntStick';
                errorMessage='Setting amplifier mode didn''t stick, for unknown reason';
                err=MException(errorId,errorMessage);
                return
            end
        end  % function

        %%
        function [overallError,perElectrodeErrors,modes,currentMonitorGains,voltageMonitorGains,currentCommandGains,voltageCommandGains,isCommandEnabled]=...
            getModeAndGainsAndIsCommandEnabled(self,electrodeIndices)
            % Note that the current monitor gain returned by this is the
            % _realized_ gain, not the nominal gain
        
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
            
            nArgumentElectrodes=length(electrodeIndices);
            hasCommandOnOffSwitch=self.HasCommandOnOffSwitch_;
            nParametersToGetPerElectrode=5+double(hasCommandOnOffSwitch);
            commands=cell(nParametersToGetPerElectrode*nArgumentElectrodes,1);
            for i=1:nArgumentElectrodes ,
                electrodeIndex=electrodeIndices(i);
                if hasCommandOnOffSwitch ,
                    commandsForThisElectrode= ...
                        {sprintf('GetEpcParams-%d Mode',electrodeIndex) ; ...
                         sprintf('GetEpcParams-%d RealGain',electrodeIndex) ; ...
                         sprintf('GetEpcParams-%d VmonGain',electrodeIndex) ; ...
                         sprintf('GetEpcParams-%d CCGain',electrodeIndex) ; ...
                         sprintf('GetEpcParams-%d ExtStim',electrodeIndex) ; ...
                         sprintf('Get E TestDacToStim%d',electrodeIndex) };
                else
                    commandsForThisElectrode= ...
                        {sprintf('GetEpcParams-%d Mode',electrodeIndex) ; ...
                         sprintf('GetEpcParams-%d RealGain',electrodeIndex) ; ...
                         sprintf('GetEpcParams-%d VmonGain',electrodeIndex) ; ...
                         sprintf('GetEpcParams-%d CCGain',electrodeIndex) ; ...
                         sprintf('GetEpcParams-%d ExtStim',electrodeIndex)};
                end                 
                commands(nParametersToGetPerElectrode*(i-1)+1:nParametersToGetPerElectrode*(i-1)+nParametersToGetPerElectrode)=commandsForThisElectrode;
            end
            %tic
            [commandIndex,overallError]=self.issueCommands(commands);
            if ~isempty(overallError) ,
                return
            end
            %toc
            %tic
            [responseStrings,overallError]=self.getResponseStrings(commandIndex);
            %toc
            if ~isempty(overallError) ,
                return
            end
            if length(responseStrings)<nParametersToGetPerElectrode*nArgumentElectrodes ,
                errorId='EPCMasterSocket:UnableToReadResponseFileToGetResponseStrings';
                errorMessage='Unable to read EPCMaster response file to get all response strings';
                overallError=MException(errorId,errorMessage);
                return
            end
            %tic
%             modes=cell(nArgumentElectrodes,1);
%             currentMonitorGains=zeros(nArgumentElectrodes,1);
%             voltageMonitorGains=zeros(nArgumentElectrodes,1);
%             currentCommandGains=zeros(nArgumentElectrodes,1);
%             voltageCommandGains=zeros(nArgumentElectrodes,1);
%             isCommandEnabled=true(nArgumentElectrodes,1);
%             try
            for i=1:nArgumentElectrodes ,
                modes{i}=ws.EPCMasterSocket.parseModeResponse(responseStrings{nParametersToGetPerElectrode*(i-1)+1});
                currentMonitorGains(i)=ws.EPCMasterSocket.parseCurrentMonitorRealizedGainResponse(responseStrings{nParametersToGetPerElectrode*(i-1)+2});
                voltageMonitorGains(i)=ws.EPCMasterSocket.parseVoltageMonitorGainResponse(responseStrings{nParametersToGetPerElectrode*(i-1)+3});
                currentCommandGains(i)=ws.EPCMasterSocket.parseCurrentCommandGainResponse(responseStrings{nParametersToGetPerElectrode*(i-1)+4});
                voltageCommandGains(i)=ws.EPCMasterSocket.parseVoltageCommandGainResponse(responseStrings{nParametersToGetPerElectrode*(i-1)+5});
                if hasCommandOnOffSwitch ,
                    isCommandEnabled{i}=ws.EPCMasterSocket.parseIsCommandEnabledResponse(responseStrings{nParametersToGetPerElectrode*(i-1)+6});
                else
                    isCommandEnabled{i}=true;
                end
            end
%             catch me
%                 if ~isempty(strfind(me.identifier,'EPCMasterSocket')) ,
%                     errorId='EPCMasterSocket:UnableToGetModeAndOrGains';
%                     errorMessage='Unable to get the mode and/or gain and/or command enablement for at least one Heka electrode';
%                     error(errorId,errorMessage);
%                 else
%                     rethrow(me);
%                 end
%             end
            
            %toc
            %fprintf('About to exit getModeAndGains.\n');
        end  % function            

%         %%
%         function [value,err]=getCurrentMonitorNominalGain(self,electrodeIndex)
%             % Returns the current monitor gain, in V/pA
%             err=self.open();  % does nothing if already open
%             if isempty(err) ,
%                 commandString=sprintf('GetEpcParams-%d Gain',electrodeIndex);
%                 [responseString,err]=self.issueCommandAndGetResponseString(commandString);
%                 try
%                     value=ws.EPCMasterSocket.parseCurrentMonitorNominalGainResponse(responseString);
%                 catch me
%                     if isequal(me.identifier,'EPCMasterSocket:UnableToParseCurrentMonitorNominalGainResponseString');
%                         errorId='EPCMasterSocket:UnableToGetCurrentMonitorNominalGain';
%                         errorMessage='Unable to get the nominal current monitor gain for the electrode';
%                         error(errorId,errorMessage);
%                     else
%                         rethrow(me);
%                     end
%                 end
%             end
%             
%         end  % function            

%         %%
%         function value=getCurrentMonitorRealizedGain(self,electrodeIndex)
%             % Returns the current monitor gain, in V/pA
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if ~self.IsOpen_ ,
%                 errorId='EPCMasterSocket:SocketNotOpen';
%                 errorMessage='Couldn''t get mode because EPCMasterSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             %commandIndex=self.issueCommand('GetEpcParams-1 RealGain');
%             commandString=sprintf('GetEpcParams-%d RealGain',electrodeIndex);
%             commandIndex=self.issueCommand(commandString);
%             responseString=self.getResponseString(commandIndex);
%             try
%                 value=ws.EPCMasterSocket.parseCurrentMonitorRealizedGainResponse(responseString);
%             catch me
%                 if isequal(me.identifier,'EPCMasterSocket:UnableToParseCurrentMonitorRealizedGainResponseString');
%                     errorId='EPCMasterSocket:UnableToGetCurrentMonitorRealizedGain';
%                     errorMessage='Unable to get the current monitor gain for the electrode';
%                     error(errorId,errorMessage);
%                 else
%                     rethrow(me);
%                 end
%             end
%         end  % function            

        %%
        function err=setCurrentMonitorNominalGain(self,electrodeIndex,newWantedValue)
            err=[]; %#ok<NASGU>
            
            if newWantedValue<=0 ,
                errorId='EPCMasterSocket:InvalidValue';
                errorMessage='Couldn''t set current monitor nominal gain because given value is not valid.';
                err=MException(errorId,errorMessage);
                return
            end
            
            % Open if necessary
            err=self.open();
            if ~isempty(err) ,
                return
            end
            
            commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
            [responseString1,err]=self.issueCommandAndGetResponse(commandString1);   %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return
            end

            [newValueDetent,iDetent]= ...
                ws.EPCMasterSocket.findClosestDetent(newWantedValue,self.CurrentMonitorNominalGainDetentsWithSpaceHolders);
            commandString2=sprintf('Set E Gain %d',iDetent-1);  % needs to be zero-based
            [responseString2,err]=self.issueCommandAndGetResponse(commandString2);   %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return
            end
            
            % Check that that worked
            newValueDetentCheck=self.getElectrodeParameter(electrodeIndex,'CurrentMonitorNominalGain');
            if abs(newValueDetentCheck./newValueDetent-1)>0.001 ,
                errorId='EPCMasterSocket:SettingModeDidntStick';
                errorMessage='Setting amplifier current monitor gain didn''t stick, for unknown reason';
                error(errorId,errorMessage);
            end
        end  % function            

%         %%
%         function value=getVoltageMonitorGain(self,electrodeIndex)
%             % Returns the current voltage gain, in V/mV
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if ~self.IsOpen_ ,
%                 errorId='EPCMasterSocket:SocketNotOpen';
%                 errorMessage='Couldn''t get mode because EPCMasterSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             % commandIndex=self.issueCommand('GetEpcParams-1 VmonGain');
%             commandString=sprintf('GetEpcParams-%d VmonGain',electrodeIndex);
%             commandIndex=self.issueCommand(commandString);
%             responseString=self.getResponseString(commandIndex);
%             try
%                 value=ws.EPCMasterSocket.parseVoltageMonitorGainResponse(responseString);
%             catch me
%                 if isequal(me.identifier,'EPCMasterSocket:UnableToParseVoltageMonitorGainResponseString');
%                     errorId='EPCMasterSocket:UnableToGetVoltageMonitorGain';
%                     errorMessage='Unable to get the voltage monitor gain for the electrode';
%                     error(errorId,errorMessage);
%                 else
%                     rethrow(me);
%                 end
%             end
%         end  % function            

        %%
        function err=setVoltageMonitorGain(self,electrodeIndex,newWantedValue)
            err=[]; %#ok<NASGU>
            if newWantedValue<=0 ,
                errorId='EPCMasterSocket:invalidValue';
                errorMessage='Couldn''t set voltage monitor gain: illegal value.';
                err=MException(errorId,errorMessage);                
                return
            end
            
            % Open if necessary
            err=self.open();
            if ~isempty(err) ,
                return            
            end
            
            commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
            [responseString1,err]=self.issueCommandAndGetResponse(commandString1);   %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return            
            end

            [newValueDetent,iDetent]=ws.EPCMasterSocket.findClosestDetent(newWantedValue,self.VoltageMonitorGainDetents); 
            commandString2=sprintf('Set E VmonX100 %d',iDetent-1);  % needs to be zero-based
            [responseString2,err]=self.issueCommandAndGetResponse(commandString2);   %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return            
            end
            
            % Check that that worked
            newValueDetentCheck=self.getElectrodeParameter(electrodeIndex,'VoltageMonitorGain');
            if abs(newValueDetentCheck./newValueDetent-1)>0.001 ,
                errorId='EPCMasterSocket:SettingModeDidntStick';
                errorMessage='Setting amplifier voltage monitor gain didn''t stick, for unknown reason';
                error(errorId,errorMessage);
            end
        end  % function            

        %%
%         function value=getIsCommandEnabled(self,electrodeIndex)
%             % Returns whether the external command is enabled.  If the
%             % hardware doesn't support setting this, always returns true.
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if ~self.HasCommandOnOffSwitch_ ,
%                 value=true;
%                 return
%             end
%             if ~self.IsOpen_ ,
%                 errorId='EPCMasterSocket:SocketNotOpen';
%                 errorMessage='Couldn''t get mode because EPCMasterSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             % commandIndex=self.issueCommand('GetEpcParams-1 VmonGain');
%             commandString=sprintf('Get E TestDacToStim%d',electrodeIndex);
%             commandIndex=self.issueCommand(commandString);
%             responseString=self.getResponseString(commandIndex);
%             try
%                 value=ws.EPCMasterSocket.parseIsCommandEnabledResponse(responseString);
%             catch me
%                 if isequal(me.identifier,'EPCMasterSocket:UnableToParseIsCommandEnabledResponseString') ,
%                     errorId='EPCMasterSocket:UnableToGetIsCommandEnabled';
%                     errorMessage='Unable to get the external command enabled setting for the electrode';
%                     error(errorId,errorMessage);
%                 else
%                     rethrow(me);
%                 end
%             end
%         end  % function            

        %%
        function err=setIsCommandEnabled(self,electrodeIndex,newWantedValue)
            import ws.utility.*
            if ~isscalar(newWantedValue) ,
                errorId='EPCMasterSocket:InvalidValue';
                errorMessage='Couldn''t set IsCommandEnabled because given value is not a scalar.';
                err=MException(errorId,errorMessage);
                return
            end
            if isnumeric(newWantedValue) ,
                newWantedValue=logical(newWantedValue>0);
            end
            if ~islogical(newWantedValue) ,
                errorId='EPCMasterSocket:InvalidValue';
                errorMessage='Couldn''t set IsCommandEnabled because given value is not logical nor convertable to logical.';
                err=MException(errorId,errorMessage);
                return
            end
            
            % Open if necessary
            err=self.open();
            if ~isempty(err) ,
                return            
            end
            
            commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
            [responseString1,err]=self.issueCommandAndGetResponse(commandString1); %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return            
            end

            % For some models, have to explicitly turn on/off the external
            % command
            if self.HasCommandOnOffSwitch_ ,
                selectionIndex=fif(newWantedValue==0,0,2);
                commandString2=sprintf('Set E TestDacToStim%d %d',electrodeIndex,selectionIndex);
                [responseString2,err]=self.issueCommandAndGetResponse(commandString2);  %#ok<ASGLU>
                if ~isempty(err) ,
                    return
                end                
            end              
        end  % function            

        %%
%         function value=getCurrentCommandGain(self,electrodeIndex)
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             % Returns the current command gain, in pA/V
%             if ~self.IsOpen_ ,
%                 errorId='EPCMasterSocket:SocketNotOpen';
%                 errorMessage='Couldn''t get mode because EPCMasterSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             % commandIndex=self.issueCommand('GetEpcParams-1 CCGain');
%             commandString=sprintf('GetEpcParams-%d CCGain',electrodeIndex);
%             commandIndex=self.issueCommand(commandString);
%             responseString=self.getResponseString(commandIndex);
%             try
%                 value=ws.EPCMasterSocket.parseCurrentCommandGainResponse(responseString);
%             catch me
%                 if isequal(me.identifier,'EPCMasterSocket:UnableToParseCurrentCommandGainResponseString');
%                     errorId='EPCMasterSocket:UnableToGetCurrentCommandGain';
%                     errorMessage='Unable to get the current command gain for the electrode';
%                     error(errorId,errorMessage);
%                 else
%                     rethrow(me);
%                 end
%             end
%         end  % function

        %%
        function err=setCurrentCommandGain(self,electrodeIndex,newWantedValue)
            import ws.utility.*

            if newWantedValue<=0 ,
                errorId='EPCMasterSocket:invalidValue';
                errorMessage='Couldn''t set current command gain: illegal value.';
                err=MException(errorId,errorMessage);                
                return
            end
            
            % Open if necessary
            err=self.open();
            if ~isempty(err) ,
                return            
            end
            
            commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
            [responseString1,err]=self.issueCommandAndGetResponse(commandString1); %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return            
            end

%             % For some models, have to explicitly turn on/off the external
%             % command
%             if self.HasCommandOnOffSwitch_ ,
%                 selectionIndex=fif(newWantedValue==0,0,2);
%                 commandString2=sprintf('Set E TestDacToStim%d %d',electrodeIndex,selectionIndex);
%                 responseString2=self.issueCommandAndGetResponse(commandString2); %#ok<NASGU>
%             end
              
            % Set the value
            [newValueDetent,iDetent]=ws.EPCMasterSocket.findClosestDetent(newWantedValue,self.CurrentCommandGainDetents); 
            commandString2=sprintf('Set E CCGain %d',iDetent-1);  % needs to be zero-based
            [responseString2,err]=self.issueCommandAndGetResponse(commandString2);    %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return            
            end
            
            % Check that that worked
            newValueDetentCheck=self.getElectrodeParameter(electrodeIndex,'CurrentCommandGain');
            if abs(newValueDetentCheck./newValueDetent-1)>0.001 ,
                errorId='EPCMasterSocket:SettingModeDidntStick';
                errorMessage='Setting amplifier current monitor gain didn''t stick, for unknown reason';
                error(errorId,errorMessage);
            end
        end  % function            

%         %%
%         function value=getVoltageCommandGain(self,electrodeIndex)
%             % Returns the command voltage gain, in mV/V
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if ~self.IsOpen_ ,
%                 errorId='EPCMasterSocket:SocketNotOpen';
%                 errorMessage='Couldn''t get mode because EPCMasterSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             % commandIndex=self.issueCommand('GetEpcParams-1 ExtStim');
%             commandString=sprintf('GetEpcParams-%d ExtStim',electrodeIndex);
%             commandIndex=self.issueCommand(commandString);
%             responseString=self.getResponseString(commandIndex);
%             try
%                 value=ws.EPCMasterSocket.parseVoltageCommandGainResponse(responseString);
%             catch me
%                 if isequal(me.identifier,'EPCMasterSocket:UnableToParseVoltageCommandGainResponseString');
%                     errorId='EPCMasterSocket:UnableToGetVoltageCommandGain';
%                     errorMessage='Unable to get the voltage command gain for the electrode';
%                     error(errorId,errorMessage);
%                 else
%                     rethrow(me);
%                 end
%             end
%         end  % function

        %%
        function err=setVoltageCommandGain(self,electrodeIndex,newValue)
            import ws.utility.*
            % newValue should be in mV/V

            % Unlike the others, can set this to zero, meaning "turn off
            % external voltage command"
            % can also make it negative
%             if ~isscalar(newValue) ,
%                 return
%             end
            
            % Open if necessary
            err=self.open();
            if ~isempty(err) ,
                return            
            end
            
            commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
            [responseString1,err]=self.issueCommandAndGetResponse(commandString1); %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return            
            end

            % For some models, have to explicitly turn on/off the external
            % command
            if self.HasCommandOnOffSwitch_ ,
                selectionIndex=fif(newValue==0,0,2);
                commandString2=sprintf('Set E TestDacToStim%d %d',electrodeIndex,selectionIndex);
                [responseString2,err]=self.issueCommandAndGetResponse(commandString2); %#ok<ASGLU>
                if ~isempty(err) ,
                    return
                end
            end
            
            newValueNativeUnits=1e-3*newValue;  % mV/V => mV/mV
            commandString3=sprintf('Set E ExtScale %g',newValueNativeUnits);
            [responseString3,err]=self.issueCommandAndGetResponse(commandString3); %#ok<ASGLU>
              % Don't really need the response, but this ensures that we at
              % least wait long enough for it to emerge before giving
              % another command
            if ~isempty(err) ,
                return            
            end
            
            % Check that that worked
            newValueCheck=self.getElectrodeParameter(electrodeIndex,'VoltageCommandGain');
            if ((newValue==0) && (newValueCheck~=0)) || abs(newValue./newValueCheck-1)>0.001 ,
                errorId='EPCMasterSocket:SettingModeDidntStick';
                errorMessage='Setting amplifier current monitor gain didn''t stick, for unknown reason';
                error(errorId,errorMessage);
            end
        end  % function            

        %%
        function err=setUIEnablement(self,newValueRaw)
            % Set whether the EPCMaster UI is enabled.  true==enabled.
            import ws.utility.*
            
            err=[]; %#ok<NASGU>
            
            newValue=logical(newValueRaw);
            if ~isscalar(newValue) ,
                errorId='EPCMasterSocket:InvalidValue';
                errorMessage='Couldn''t set UI enablement because given value is not a scalar.';
                err=MException(errorId,errorMessage);
                return
            end
            
            % Open if necessary
            err=self.open();
            if ~isempty(err) ,
                return            
            end
            
            %commandIndex=self.issueCommand('GetEpcParams-1 RealGain');
            commandString=fif(newValue,'EnableUserActions','DisableUserActions');
            commandIndex=self.issueCommand(commandString);
            [responseString,err]=self.getResponseString(commandIndex); %#ok<ASGLU>
              % this last is mainly just to throw an exception if it
              % definitely failed.
            if ~isempty(err) ,
                return            
            end
        end  % function            

        %%
        function [responseString,err]=issueCommandAndGetResponse(self,commandString)
            [commandIndex,err]=self.issueCommand(commandString);
            if isempty(err) ,
                [responseString,err]=self.getResponseString(commandIndex);
            else
                responseString=[];
            end
        end
            
        %%
        function [commandIndex,err]=issueCommand(self,commandString)
            % Open the command file, and clear the current contents (if
            % any)
            err=[];
            commandFileId=fopen(self.CommandFileName_,'w+');  % open for writing.  Create if doesn't exist, discard contents if already exists.
            if commandFileId<0 ,
                % Couldn't open command file
                errorId='EPCMasterSocket:CouldNotOpenCommandFile';
                errorMessage='Could not open command file';
                err=MException(errorId,errorMessage);
                return
            end            
            commandIndex=self.NextCommandIndex_;
            self.NextCommandIndex_=self.NextCommandIndex_+1;
            %fprintf('About to issue command "%s" with command index %d\n',commandString,commandIndex);
            fprintf(commandFileId,'-%08d\n',commandIndex);
            fprintf(commandFileId,'%s\n\n',commandString);
            % Overwrite the initial - with a +
            fseek(commandFileId,0,'bof');
            fprintf(commandFileId,'+');              
            fclose(commandFileId);
        end
    
        %%
        function [commandIndex,err]=issueCommands(self,commandStrings)
            % Open the command file, and clear the current contents (if
            % any)
            
            % fallback values
            commandIndex=[];
            err=[];
            
            commandFileId=fopen(self.CommandFileName_,'w+');  % open for writing.  Create if doesn't exist, discard contents if already exists.
            if commandFileId<0 ,
                % Couldn't open command file
                errorId='EPCMasterSocket:CouldNotOpenCommandFile';
                errorMessage='Could not open command file';
                err=MException(errorId,errorMessage);
                return
            end            
            commandIndex=self.NextCommandIndex_;
            self.NextCommandIndex_=self.NextCommandIndex_+1;
            fprintf(commandFileId,'-%08d\n',commandIndex);
            for i=1:length(commandStrings)
                fprintf(commandFileId,'%s\n',commandStrings{i});
            end
            fprintf(commandFileId,'\n');            
            % Overwrite the initial - with a +
            fseek(commandFileId,0,'bof');
            fprintf(commandFileId,'+');              
            fclose(commandFileId);
        end
    
        %%
        function [responseString,err]=getResponseString(self,commandIndex)
            import ws.utility.*
            
            % fallback return values
            responseString='';
            err=[];
            
            % Try to open the file
            responseFileId=fopen(self.ResponseFileName_,'r');
            if responseFileId<0 ,
                % Couldn't open response file
                errorId='EPCMasterSocket:CouldNotOpenResponseFile';
                errorMessage='Couldn''t get response because couldn''t open response file';
                err=MException(errorId,errorMessage);
                return
            end
            
            maximumWaitTime=1;  % s
            dt=0.005;
            nIterations=round(maximumWaitTime/dt);
            wasResponseGenerated=false;
            for i=1:nIterations ,
                [responseIndex,err]=ws.EPCMasterSocket.getResponseIndex_(responseFileId);
                if isempty(err) ,
                    success=true;
                else
                    id=err.identifier;
                    if isequal(id,'EPCMasterSocket:UnableToReadResponseFileToGetResponseIndex') || ...
                       isequal(id,'EPCMasterSocket:InvalidIndexInResponse') ,
                        % this was a failure, but one that will perhaps
                        % resolve itself later
                        success=false;
                    else
                        % this seems like a "real" error
                        return
                        %rethrow(me);
                    end
                end
                if success ,
                    % We used to do a special check for
                    % responseIndex>commandIndex and throw if that
                    % happened, but that turned out to be
                    % counterproductive.  Sometimes you read an old
                    % response file from a previous EPCMasterSocket
                    % session, just because EPCMaster hasn't yet written
                    % the response to your latest command.  With the old
                    % code, that would throw.  With the new code, we just
                    % wait longer to see if the response file appears.
                    if responseIndex==commandIndex ,
                        wasResponseGenerated=true;
                        break
                    else
                        % wait longer
                        sleep(dt);
%                     else
%                         % the response index is somehow greater than the
%                         % command index we're looking for
%                         fclose(responseFileId);
%                         errorId='EPCMasterSocket:ResponseIndexTooHigh';
%                         errorMessage='The response index is greater than the command index already';
%                         error(errorId,errorMessage);
                    end
                else
                    sleep(dt);
                end
            end
            
            if ~wasResponseGenerated ,
                fclose(responseFileId);
                errorId='EPCMasterSocket:NoReponse';
                errorMessage='EPCMaster did not respond to a command within the timeout interval';
                err=MException(errorId,errorMessage);
                return
            end
            
            responseString=fgetl(responseFileId);
            fclose(responseFileId);
            if isnumeric(responseString) ,
                responseString='';  % Some commands don't have a response beyond just generating a response file with the line containing the response index
                % errorId='EPCMasterSocket:UnableToReadResponseFileToGetResponseString';
                % errorMessage='Unable to read EPCMaster response file to get response string';
                % error(errorId,errorMessage);
            end
        end  % function

        %%
        function [responseStrings,err]=getResponseStrings(self,commandIndex)
            import ws.utility.*
            
            % Fallback values
            responseStrings={};
            err=[];
            
            %fprintf('Just entered getResponseStrings()\n');
            %commandIndex
            responseFileId=fopen(self.ResponseFileName_,'r');
            if responseFileId<0 ,
                % Couldn't open response file
                errorId='EPCMasterSocket:CouldNotOpenResponseFile';
                errorMessage='Couldn''t get response because couldn''t open response file';
                err=MException(errorId,errorMessage);
                return
            end
            
            %tStart=tic();
            maximumWaitTime=1;  % s
            dt=0.005;
            nIterations=round(maximumWaitTime/dt);
            wasResponseGenerated=false;
            for i=1:nIterations ,
                [responseIndex,err]=ws.EPCMasterSocket.getResponseIndex_(responseFileId);
                if isempty(err)
                    success=true;
                else
                    id=err.identifier;
                    if isequal(id,'EPCMasterSocket:UnableToReadResponseFileToGetResponseIndex') || ...
                       isequal(id,'EPCMasterSocket:InvalidIndexInResponse') ,
                        % this was a failure, but one that will perhaps
                        % resolve itself later
                        success=false;
                    else
                        % this seems like a "real" error
                        return
                        %rethrow(me);
                    end
                end
                % success
                if success ,
                    if responseIndex==commandIndex ,
                        wasResponseGenerated=true;
                        break
                    else
                        % wait longer
                        sleep(dt);
                    end
%                     elseif responseIndex==commandIndex ,
%                     else
%                         % the response index is somehow greater than the
%                         % command index we're looking for
%                         fclose(responseFileId);
%                         errorId='EPCMasterSocket:ResponseIndexTooHigh';
%                         errorMessage='The response index is greater than the command index already';
%                         error(errorId,errorMessage);
%                     end
                else
                    sleep(dt);
                end
            end
            % toc(tStart)
            
            if ~wasResponseGenerated ,
                fclose(responseFileId);
                errorId='EPCMasterSocket:NoReponse';
                errorMessage='EPCMaster did not respond to a command within the timeout interval';
                err=MException(errorId,errorMessage);
                return
            end
            
            %tStart=tic();
            responseStrings=cell(1,0);
            i=1;
            atEndOfFile=false;
            while ~atEndOfFile ,
                thisLine=fgetl(responseFileId);
                if isnumeric(thisLine)
                    atEndOfFile=true;
                else
                    responseStrings{1,i}=thisLine;
                    i=i+1;
                end
            end                
            %toc(tStart)
            %tStart=tic();
            fclose(responseFileId);
            %toc(tStart)
            %fprintf('About to exit getResponseStrings()\n');
        end  % function

    end  % public methods
        
    methods (Access=protected)
        %%
        function err=establishConnection_(self)
            % Attempt to establish a connection with EPCMaster.  Throw an
            % exception if unable to do this.

            % To establish a connection, we:
            %   1) Attempt to delete any pre-existing command and response
            %      files.
            %   2) Write a blank command file.
            %   3) Write a command file containing the "acknowledge"
            %      command.
            %
            % Ideally, EPCMaster responds to the "acknowledge" command in a timely fashion, and
            % we're done.  Step 2 is necessary because in certain
            % conditions EPCMaster seems to respond to the creation of the
            % command file, but not actually try to read the command from
            % it and respond to it appropriately.
            
            import ws.utility.*

            % Default return value
            err=[];
            
            % try to delete any pre-existing command, response files
            if exist(self.CommandFileName_,'file') ,
                deleteFileWithoutWarning(self.CommandFileName_)
            end            
            if exist(self.ResponseFileName_,'file') ,
                deleteFileWithoutWarning(self.ResponseFileName_)
            end
            
            % Verify the existance of the directory in which the command, response
            % files live
            doesEPCMasterDirExist=exist(self.EPCMasterDirName_,'file');
            if ~doesEPCMasterDirExist ,
                err=MException('EPCMasterSocket:EPCMasterDirectoryMissing', ...
                               'Unable to open connection to EPCMaster because EPCMaster directory is missing.');
                return
            end

            % See whether if a response file exists right now.
            responseFileExistedBefore=logical(exist(self.ResponseFileName_,'file'));
            
            % Blank the command file --- If EPCMaster is listening, and
            % this causes the command file to be created, it will modify
            % the response file.
            thisError=self.blankTheCommandFile_();
            if ~isempty(thisError) ,
                err=MException('EPCMasterSocket:CouldNotOpenCommandFileToBlank', ...
                               'Unable to open connection to EPCMaster because unable to open the command file to blank it');
                return
            end

            % Get the mod time for the command file
            if ~exist(self.CommandFileName_,'file') ,
                err=MException('EPCMasterSocket:CommandFileMissingAfterBlanking', ...
                               'Unable to open connection to EPCMaster because the command file was missing after blanking it');
                return
            end                
            commandFileModificationTime=fileModificationTime(self.CommandFileName_);
            if isempty(commandFileModificationTime) ,
                err=MException('EPCMasterSocket:UnableToGetModificationTimeOfBlankedCommandFile', ...
                               'Unable to open connection to EPCMaster because unable to get modification time of the command file after blanking it');
                return
            end
            
            % Look at the response file
            if exist(self.ResponseFileName_,'file') ,
                responseFileExistedAfter=true;
                responseFileModificationTimeAfter=fileModificationTime(self.ResponseFileName_);
                if isempty(responseFileModificationTimeAfter) ,
                    err=MException('EPCMasterSocket:UnableToGetResponseModificationTime', ...
                                   'Unable to open connection to EPCMaster because unable to get modification time on response file after issuing blank command');
                    return
                end
            else
                responseFileExistedAfter=false;
                responseFileModificationTimeAfter=-inf;
            end
            
            % Determine whether the EPCMaster app responded
            epcMasterRespondedToBlankingCommandFile = ...
                (~responseFileExistedBefore && responseFileExistedAfter) ...
                || ...
                (responseFileExistedBefore && responseFileExistedAfter && (commandFileModificationTime<=responseFileModificationTimeAfter) ) ; %#ok<NASGU>
            
            % We don't actually care whether EPCMaster responded to the
            % command file, because in either case we just proceed to see
            % if it responds to a proper command.
            
            % We try writing a test command
            % and seeing if we get a response...
            % If successful, this will also reset the command counter in
            % EPCMaster, which is generally good.
            self.issueCommand('acknowledged');  % as called from the constructor, this will have command index 1
            
            % Get the modification date on the command file.
            if exist(self.CommandFileName_,'file') ,
                commandFileModificationTime=fileModificationTime(self.CommandFileName_);
                if isempty(commandFileModificationTime),
                    err=MException('EPCMasterSocket:UnableToGetCommandModificationTime', ...
                                   'Unable to open connection to EPCMaster because unable to get modification time on command file after issuing test command');
                    return
                end
            else
                % Apparently unable to write command file...
                err=MException('EPCMasterSocket:UnableToWriteToCommandFile', ...
                               'Unable to open connection to EPCMaster because unable to write to command file');
                return
            end
            
            % After (perhaps) a delay, a response file should appear.
            maximumWaitTime=1;  % s
            dt=0.005;
            nIterations=round(maximumWaitTime/dt);
            wasResponseGenerated=false;
            for i=1:nIterations ,
                if exist(self.ResponseFileName_,'file') ,
                    % Check that the response file was changed after the command
                    % file mode date
                    responseFileModificationTime=fileModificationTime(self.ResponseFileName_);
                    if ~isempty(responseFileModificationTime) && commandFileModificationTime<=responseFileModificationTime ,
                        wasResponseGenerated=true;
                        break
                    else
                        sleep(dt);
                    end
                else
                    sleep(dt);
                end
            end
            
            % Check that the response file was changed after the command
            % file mode date
            if ~wasResponseGenerated ,
                err=MException('EPCMasterSocket:UnableToWriteToCommandFile', ...
                               'Unable to open connection to EPCMaster because no response to test command');
                return
            end
        end  % function
        
        %%
        function [hasCommandOnOffSwitch,err]=probeForHasCommandOnOffSwitch_(self)
            [responseString,err]=self.issueCommandAndGetResponse('Get E TestDacToStim1');  % may throw, which we don't catch here
            if isempty(err)
                hasCommandOnOffSwitch=isempty(strfind(responseString,'error'));
            else
                hasCommandOnOffSwitch=[];
            end
%             if hasCommandOnOffSwitch , 
%                 self.CurrentCommandGainDetents=[0 100 1000 10e3 100e3]';  % pA/V
%             end
        end
        
        %%
        function err=blankTheCommandFile_(self)
            % Open the command file, and clear the current contents (if
            % any)
            commandFileId=fopen(self.CommandFileName_,'w+');  % open for writing.  Create if doesn't exist, discard contents if already exists.
            if commandFileId<0 ,
                % Couldn't open command file
                err=MException('EPCMasterSocket:CouldNotOpenCommandFileToBlank', ...
                               'Unable to open command file in order to blank it');
            else
                fclose(commandFileId);
                err=[];
            end
        end  % function
        
        %%
        function result=computeCurrentMonitorNominalGainDetentsWithSpaceHolders_(self)
            result=inf(length(self.CurrentMonitorNominalGainDetents)+2,1);
            result(1:6)=self.CurrentMonitorNominalGainDetents(1:6);
            result(8:13)=self.CurrentMonitorNominalGainDetents(7:12);
            result(15:end)=self.CurrentMonitorNominalGainDetents(13:end);
        end
        
    end  % protected methods
    
    methods (Static=true)  % public class methods
        %%
        function [mode,err]=parseModeResponse(responseString)
            % The response should look like 'GetEpcParams-1 VC'
            % Returns either an ws.ElectrodeMode scalar, or empty if
            % there is a problem during parsing
            responseStringTokens=strsplit(responseString);
            if length(responseStringTokens)>=2 && any(strcmp(responseStringTokens(2),{'VC' 'CC'})) ,
                mode=ws.ElectrodeMode.fromTitleString(responseStringTokens{2});
                err=[];
            else
                mode=[];
                errorId='EPCMasterSocket:UnableToParseModeResponseString';
                errorMessage='Unable to parse mode response string';
                err=MException(errorId,errorMessage);
            end
        end  % function

        %%
        function [gain,err]=parseCurrentMonitorRealizedGainResponse(responseString)
            % The response should look like 'GetEpcParams-1 1.00000E+10',
            % with that gain in V/A.  We convert to V/pA.
            % Returns nan if there's a problem during parsing.
            % TODO_ALT: Deal with possibility that user wants to use nA, or
            % whatever.
            responseStringTokens=strsplit(responseString);
            if length(responseStringTokens)>=2 ,
                gainAsString=responseStringTokens{2};
                gainInOhms=str2double(gainAsString);  % V/A
                if isfinite(gainInOhms) ,
                    gain=1e-12*gainInOhms;  % V/A -> V/pA
                    err=[];
                else                    
                    gain=nan;
                    errorId='EPCMasterSocket:UnableToParseCurrentMonitorRealizedGainResponseString';
                    errorMessage='Unable to parse current monitor realized gain response string';
                    err=MException(errorId,errorMessage);
                end
            else
                gain=nan;
                errorId='EPCMasterSocket:UnableToParseCurrentMonitorRealizedGainResponseString';
                errorMessage='Unable to parse current monitor realized gain response string';
                err=MException(errorId,errorMessage);
            end
        end  % function

        %%
        function [gain,err]=parseCurrentMonitorNominalGainResponse(responseString)
            % The response should look like 'GetEpcParams-1 0.020mV/pA',
            % with that gain in mV/pA (obviously).  We convert to V/pA.
            % TODO_ALT: Deal with possibility that user wants to use nA, or
            % whatever.
            responseStringTokens=strsplit(responseString);
            if length(responseStringTokens)>=2 ,
                gainWithUnitsAsString=responseStringTokens{2};
                gainAsString=gainWithUnitsAsString(1:end-5);
                gainInNativeUnits=str2double(gainAsString);  % mV/pA
                if isfinite(gainInNativeUnits) ,
                    gain=1e-3*gainInNativeUnits;  % mV/pA -> V/pA
                    err=[];
                else
                    gain=nan;
                    errorId='EPCMasterSocket:UnableToParseCurrentMonitorNominalGainResponseString';
                    errorMessage='Unable to parse current monitor nominal gain response string';
                    err=MException(errorId,errorMessage);
                end
            else
                gain=nan;
                errorId='EPCMasterSocket:UnableToParseCurrentMonitorNominalGainResponseString';
                errorMessage='Unable to parse current monitor nominal gain response string';
                err=MException(errorId,errorMessage);
            end
        end  % function                

        %%
        function [gain,err]=parseVoltageMonitorGainResponse(responseString)
            % The response should look like 'GetEpcParams-1 VmonX10' or 'GetEpcParams-1 VmonX100',
            % with that gain in mV/mV.  We convert to V/mV.
            responseStringTokens=strsplit(responseString);
            if length(responseStringTokens)>=2 ,
                gainAsVmonXString=responseStringTokens{2};
                gainAsString=gainAsVmonXString(6:end);
                gainPure=str2double(gainAsString);  % mV/mV
                if isfinite(gainPure) ,
                    gain=1e-3*gainPure;  % mV/mV -> V/mV
                    err=[];
                else                    
                    gain=nan;
                    errorId='EPCMasterSocket:UnableToParseResponseString';
                    errorMessage='Unable to parse response string';
                    err=MException(errorId,errorMessage);
                end                            
            else                
                gain=nan;
                errorId='EPCMasterSocket:UnableToParseResponseString';
                errorMessage='Unable to parse response string';
                err=MException(errorId,errorMessage);
            end
        end  % function

        %%
        function [gain,err]=parseCurrentCommandGainResponse(responseString)
            % The response should look like 'GetEpcParams-1 CC0.1pA' [sic], 
            % with that gain in pA/mV.  We convert to pA/V.
            % TODO_ALT: Deal with possibility that user wants to use nA, or
            % whatever.
            responseStringTokens=strsplit(responseString);
            if length(responseStringTokens)>=2 ,
                gainAsCCString=responseStringTokens{2};
                gainAsString=gainAsCCString(3:end-2);
                gainRaw=str2double(gainAsString);  % pA/mV
                if isfinite(gainRaw) ,
                    gain=1e3*gainRaw;  % pA/mV -> pA/V
                    err=[];
                else                    
                    gain=nan;
                    errorId='EPCMasterSocket:UnableToParseResponseString';
                    errorMessage='Unable to parse response string';
                    err=MException(errorId,errorMessage);
                end            
            else                                
                gain=nan;
                errorId='EPCMasterSocket:UnableToParseResponseString';
                errorMessage='Unable to parse response string';
                err=MException(errorId,errorMessage);
            end
        end  % function
        
        %%
        function [gain,err]=parseVoltageCommandGainResponse(responseString)
            % The response should look like 'GetEpcParams-1 0.100',
            % with that gain in mV/mV.  We convert to mV/V.
            responseStringTokens=strsplit(responseString);
            if length(responseStringTokens)>=2 ,
                gainPureAsString=responseStringTokens{2};
                gainPure=str2double(gainPureAsString);  % mV/mV
                if isfinite(gainPure) ,
                    gain=1e3*gainPure;  % mV/mV -> mV/V
                    err=[];
                else
                    gain=nan;
                    errorId='EPCMasterSocket:UnableToParseResponseString';
                    errorMessage='Unable to parse response string';
                    err=MException(errorId,errorMessage);
                end            
            else                
                gain=nan;
                errorId='EPCMasterSocket:UnableToParseResponseString';
                errorMessage='Unable to parse response string';
                err=MException(errorId,errorMessage);
            end
        end  % function                        

        %%
        function [value,err]=parseIsCommandEnabledResponse(responseString)
            % The response should end in either 'ON' or 'OFF'.
            responseStringTokens=strsplit(responseString);
            if length(responseStringTokens)>=2 ,
                isCommandEnabledAsString=responseStringTokens{end};
                if strcmp(isCommandEnabledAsString,'ON') ,
                    value=true;
                    err=[];
                elseif strcmp(isCommandEnabledAsString,'OFF') ,
                    value=false;
                    err=[];
                else
                    value=[];
                    errorId='EPCMasterSocket:UnableToParseIsCommandEnabledResponseString';
                    errorMessage='Unable to parse external command response string';
                    err=MException(errorId,errorMessage);
                end
            else
                value=[];
                errorId='EPCMasterSocket:UnableToParseIsCommandEnabledResponseString';
                errorMessage='Unable to parse external command response string';
                err=MException(errorId,errorMessage);
            end
        end  % function                        

        %%
        function [xDetent,iDetent]=findClosestDetent(x,detents)
            [~,iDetent]=min(abs(x-detents));
            xDetent=detents(iDetent);
        end  % function
    end  % public class methods

    methods (Static=true, Access=protected)  % protected class methods
        %%
        function [responseIndex,err]=getResponseIndex_(responseFileId)
            % If successful, leaves the file pointer at the start of the
            % second line of the response file
            responseIndex=[];
            err='';
            
            fseek(responseFileId,0,'bof');
            firstLine=fgetl(responseFileId);
            if isnumeric(firstLine) ,
                errorId='EPCMasterSocket:UnableToReadResponseFileToGetResponseIndex';
                errorMessage='Unable to read response file to get response index';
                err=MException(errorId,errorMessage);
                return
            end
            responseIndex=str2double(firstLine);
            if ~isreal(responseIndex) || ~isfinite(responseIndex) || responseIndex~=round(responseIndex) ,
                errorId='EPCMasterSocket:InvalidIndexInResponse';
                errorMessage='Response file had an invalid index';
                err=MException(errorId,errorMessage);
                return
            end
        end  % function                    
    end  % protected class methods

end  % classdef
