classdef MulticlampCommanderSocket < ws.Mimic
    % Represents a "socket" for talking to one or more Axon Multiclamp
    % Commander instances.
    
    %%
    properties (SetAccess=protected, Hidden=true)
        %ModeDetents={ws.ElectrodeMode.VC ws.ElectrodeMode.CC ws.ElectrodeMode.IEqualsZero}';
%         CurrentMonitorNominalGainDetents= 1e-3*[ ...
%             0.005 ...
%             0.010 ...
%             0.020 ...
%             0.050 ...
%             0.100 ...
%             0.200 ...
%             0.5 ...
%             1.0 ...
%             2.0 ...
%             5.0 ...
%             10 ...
%             20 ...
%             50 ...
%             100 ...
%             200 ...
%             500 ...
%             1000 ...
%             2000 ]';  % V/pA
%         VoltageMonitorGainDetents= [ ...
%             0.010 0.100]';  % V/mV
%         CurrentCommandGainDetents= [ ...
%             100 1000 10e3 100e3]';  % pA/V
%         VoltageCommandGainDetents= [ ...
%             0 10 20]';  % mV/V (the hardware allows for a (largely) arbitrary setting, but these are convenient values for testing)
    end
    
    %%
    properties  (Access=protected)
        ElectrodeIDs_ = zeros(0,1)
    end

    properties (Dependent=true, SetAccess=immutable)
        IsOpen  % true iff a connection to the Multiclamp Commander program(s) have been established, and hasn't failed yet       
    end
    
    %%
    properties (Dependent=true, SetAccess=immutable)
        %IsOpen  % true iff a connection to the EpcMaster program has been established, and hasn't failed yet        
        NElectrodes
    end
    
    methods
        %%
        function self=MulticlampCommanderSocket()
            %self.IsOpen_=false;
        end  % function
        
        %%
        function delete(self)
            self.close();
        end
        
        %%
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
        
        %%
        function self=close(self)
            ws.dabs.axon.MulticlampTelegraph('stop');
            self.ElectrodeIDs_ = zeros(0,1) ;
        end  % function
        
        %%
        function self=reopen(self)
            % Close the connection, then open it.
            self.close();
            self.open();
        end
        
        %%
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
        
%         %%
%         function self=setElectrodeParameter(self,electrodeIndex,parameterName,newValue)
%             methodName=sprintf('set%s',parameterName);
%             self.(methodName)(electrodeIndex,newValue);
%         end

        %%
        function [electrodeState,err]=getElectrodeState(self,electrodeIndex)
            err=self.checkIfOpenAndValidElectrodeIndex_(electrodeIndex);                        
            if isempty(err) ,
                electrodeID=self.ElectrodeIDs_(electrodeIndex);
                %electrodeState=ws.dabs.axon.MulticlampTelegraph('getElectrode',electrodeID);
                %ws.dabs.axon.MulticlampTelegraph('requestElectrodeState',electrodeID)
                %ws.utility.sleep(0.05);  % Wait a bit for response (how short can we make this?)
                %electrodeState=ws.dabs.axon.MulticlampTelegraph('collectElectrodeState',electrodeID);
                electrodeState=ws.dabs.axon.MulticlampTelegraph('getElectrodeState',electrodeID);
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

        %%
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

%         %%
%         function self=setMode(self,electrodeIndex,newMode)
%             import ws.utility.*
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if ~(isequal(newMode,ws.ElectrodeMode.VC) || isequal(newMode,ws.ElectrodeMode.CC)) ,
%                 return
%             end
%             if ~self.IsOpen ,
%                 errorId='MulticlampCommanderSocket:SocketNotOpen';
%                 errorMessage='Couldn''t set mode because MulticlampCommanderSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
%             responseString1=self.issueCommandAndGetResponse(commandString1);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
% 
%             newModeIndex=fif(isequal(newMode,ws.ElectrodeMode.CC),4,3);
%               % 4 == Current clamp
%               % 3 == Whole cell
%             commandString2=sprintf('Set E Mode %d',newModeIndex);
%             responseString2=self.issueCommandAndGetResponse(commandString2); %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
%             %sleep(0.1);  % wait a bit for that to go through (50 ms is too short for it to work reliably)
%             
%             % Check that that worked
%             newModeCheck=self.getMode(electrodeIndex);
%             if ~isequal(newMode,newModeCheck) ,
%                 errorId='MulticlampCommanderSocket:SettingModeDidntStick';
%                 errorMessage='Setting amplifier mode didn''t stick, for unknown reason';
%                 error(errorId,errorMessage);
%             end
%         end  % function            

        %%
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

        %%
        function [value,err]=getCurrentMonitorRealizedGain(self,electrodeIndex)            
            % Returns the realized current monitor gain, in V/pA
            [value,err]=self.getCurrentMonitorNominalGain(electrodeIndex);  % no distinction between nominal and real current monitor gain in Axon
        end  % function            

%         %%
%         function self=setCurrentMonitorNominalGain(self,electrodeIndex,newWantedValue)
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if newWantedValue<=0 ,
%                 return
%             end
%             if ~self.IsOpen ,
%                 errorId='MulticlampCommanderSocket:SocketNotOpen';
%                 errorMessage='Couldn''t set mode because MulticlampCommanderSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
%             responseString1=self.issueCommandAndGetResponse(commandString1);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
% 
%             [newValueDetent,iDetent]= ...
%                 ws.MulticlampCommanderSocket.findClosestDetent(newWantedValue,self.CurrentMonitorNominalGainDetentsWithSpaceHolders); %#ok<ASGLU>
%             commandString2=sprintf('Set E Gain %d',iDetent-1);  % needs to be zero-based
%             responseString2=self.issueCommandAndGetResponse(commandString2);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
%             
% %             % Check that that worked
% %             newValueDetentCheck=self.getCurrentMonitorNominalGain(electrodeIndex);
% %             if abs(newValueDetentCheck./newValueDetent-1)>0.001 ,
% %                 errorId='MulticlampCommanderSocket:SettingModeDidntStick';
% %                 errorMessage='Setting amplifier current monitor gain didn''t stick, for unknown reason';
% %                 error(errorId,errorMessage);
% %             end
%         end  % function            

        %%
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

%         %%
%         function self=setVoltageMonitorGain(self,electrodeIndex,newWantedValue)
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if newWantedValue<=0 ,
%                 return
%             end
%             if ~self.IsOpen ,
%                 errorId='MulticlampCommanderSocket:SocketNotOpen';
%                 errorMessage='Couldn''t set mode because MulticlampCommanderSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
%             responseString1=self.issueCommandAndGetResponse(commandString1);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
% 
%             [newValueDetent,iDetent]=ws.MulticlampCommanderSocket.findClosestDetent(newWantedValue,self.VoltageMonitorGainDetents); %#ok<ASGLU>
%             commandString2=sprintf('Set E VmonX100 %d',iDetent-1);  % needs to be zero-based
%             responseString2=self.issueCommandAndGetResponse(commandString2);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
%             
% %             % Check that that worked
% %             newValueDetentCheck=self.getVoltageMonitorGain(electrodeIndex);
% %             if abs(newValueDetentCheck./newValueDetent-1)>0.001 ,
% %                 errorId='MulticlampCommanderSocket:SettingModeDidntStick';
% %                 errorMessage='Setting amplifier voltage monitor gain didn''t stick, for unknown reason';
% %                 error(errorId,errorMessage);
% %             end
%         end  % function            

        %%
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

%         %%
%         function self=setIsCommandEnabled(self,electrodeIndex,newWantedValue)
%             import ws.utility.*
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if ~isscalar(newWantedValue) ,
%                 return
%             end
%             if isnumeric(newWantedValue) ,
%                 newWantedValue=logical(newWantedValue>0);
%             end
%             if ~islogical(newWantedValue) ,
%                 return
%             end
%             if ~self.IsOpen ,
%                 errorId='MulticlampCommanderSocket:SocketNotOpen';
%                 errorMessage='Couldn''t set mode because MulticlampCommanderSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
%             responseString1=self.issueCommandAndGetResponse(commandString1);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
% 
%             % For some models, have to explicitly turn on/off the external
%             % command
%             if self.HasCommandOnOffSwitch_ ,
%                 selectionIndex=fif(newWantedValue==0,0,2);
%                 commandString2=sprintf('Set E TestDacToStim%d %d',electrodeIndex,selectionIndex);
%                 responseString2=self.issueCommandAndGetResponse(commandString2); %#ok<NASGU>
%             end              
%         end  % function            

        %%
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

%         %%
%         function self=setCurrentCommandGain(self,electrodeIndex,newWantedValue)
%             import ws.utility.*
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             if newWantedValue<=0 ,
%                 return
%             end
%             if ~self.IsOpen ,
%                 errorId='MulticlampCommanderSocket:SocketNotOpen';
%                 errorMessage='Couldn''t set mode because MulticlampCommanderSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
%             responseString1=self.issueCommandAndGetResponse(commandString1);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
% 
% %             % For some models, have to explicitly turn on/off the external
% %             % command
% %             if self.HasCommandOnOffSwitch_ ,
% %                 selectionIndex=fif(newWantedValue==0,0,2);
% %                 commandString2=sprintf('Set E TestDacToStim%d %d',electrodeIndex,selectionIndex);
% %                 responseString2=self.issueCommandAndGetResponse(commandString2); %#ok<NASGU>
% %             end
%               
%             % Set the value
%             [newValueDetent,iDetent]=ws.MulticlampCommanderSocket.findClosestDetent(newWantedValue,self.CurrentCommandGainDetents); %#ok<ASGLU>
%             commandString2=sprintf('Set E CCGain %d',iDetent-1);  % needs to be zero-based
%             responseString2=self.issueCommandAndGetResponse(commandString2);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
%             
% %             % Check that that worked
% %             newValueDetentCheck=self.getCurrentCommandGain(electrodeIndex);
% %             if abs(newValueDetentCheck./newValueDetent-1)>0.001 ,
% %                 errorId='MulticlampCommanderSocket:SettingModeDidntStick';
% %                 errorMessage='Setting amplifier current monitor gain didn''t stick, for unknown reason';
% %                 error(errorId,errorMessage);
% %             end
%         end  % function            

        %%
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

%         %%
%         function self=setVoltageCommandGain(self,electrodeIndex,newValue)
%             import ws.utility.*
%             % newValue should be in mV/V
%             if ~exist('electrodeIndex','var') || isempty(electrodeIndex) ,
%                 electrodeIndex=1;
%             end
%             % Unlike the others, can set this to zero, meaning "turn off
%             % external voltage command"
%             % can also make it negative
% %             if ~isscalar(newValue) ,
% %                 return
% %             end
%             if ~self.IsOpen ,
%                 errorId='MulticlampCommanderSocket:SocketNotOpen';
%                 errorMessage='Couldn''t set mode because MulticlampCommanderSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             commandString1=sprintf('Set E Ampl%d TRUE',electrodeIndex);
%             responseString1=self.issueCommandAndGetResponse(commandString1);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
% 
%             % For some models, have to explicitly turn on/off the external
%             % command
%             if self.HasCommandOnOffSwitch_ ,
%                 selectionIndex=fif(newValue==0,0,2);
%                 commandString2=sprintf('Set E TestDacToStim%d %d',electrodeIndex,selectionIndex);
%                 responseString2=self.issueCommandAndGetResponse(commandString2); %#ok<NASGU>
%             end
%             
%             newValueNativeUnits=1e-3*newValue;  % mV/V => mV/mV
%             commandString3=sprintf('Set E ExtScale %g',newValueNativeUnits);
%             responseString3=self.issueCommandAndGetResponse(commandString3);   %#ok<NASGU>
%               % Don't really need the response, but this ensures that we at
%               % least wait long enough for it to emerge before giving
%               % another command
%             
% %             % Check that that worked
% %             newValueCheck=self.getVoltageCommandGain(electrodeIndex);
% %             if ((newValue==0) && (newValueCheck~=0)) || abs(newValue./newValueCheck-1)>0.001 ,
% %                 errorId='MulticlampCommanderSocket:SettingModeDidntStick';
% %                 errorMessage='Setting amplifier current monitor gain didn''t stick, for unknown reason';
% %                 error(errorId,errorMessage);
% %             end
%         end  % function            

%         %%
%         function setUIEnablement(self,newValueRaw)
%             % Set whether the EPCMaster UI is enabled.  true==enabled.
%             import ws.utility.*
%             newValue=logical(newValueRaw);
%             if ~isscalar(newValue) ,
%                 return
%             end
%             if ~self.IsOpen ,
%                 errorId='MulticlampCommanderSocket:SocketNotOpen';
%                 errorMessage='Couldn''t get mode because MulticlampCommanderSocket not open.';
%                 error(errorId,errorMessage);
%             end
%             %commandIndex=self.issueCommand('GetEpcParams-1 RealGain');
%             commandString=fif(newValue,'EnableUserActions','DisableUserActions');
%             commandIndex=self.issueCommand(commandString);
%             responseString=self.getResponseString(commandIndex); %#ok<NASGU>
%               % this last is mainly just to throw an exception if it
%               % definitely failed.
%         end  % function            

%         %%
%         function responseString=issueCommandAndGetResponse(self,commandString)
%             commandIndex=self.issueCommand(commandString);
%             responseString=self.getResponseString(commandIndex);
%         end
            
%         %%
%         function commandIndex=issueCommand(self,commandString)
%             % Open the command file, and clear the current contents (if
%             % any)
%             commandFileId=fopen(self.CommandFileName_,'w+');  % open for writing.  Create if doesn't exist, discard contents if already exists.
%             if commandFileId<0 ,
%                 % Couldn't open command file
%                 errorId='MulticlampCommanderSocket:CouldNotOpenCommandFile';
%                 errorMessage='Could not open command file';
%                 error(errorId,errorMessage);
%             end            
%             commandIndex=self.NextCommandIndex_;
%             self.NextCommandIndex_=self.NextCommandIndex_+1;
%             %fprintf('About to issue command "%s" with command index %d\n',commandString,commandIndex);
%             fprintf(commandFileId,'-%08d\n',commandIndex);
%             fprintf(commandFileId,'%s\n\n',commandString);
%             % Overwrite the initial - with a +
%             fseek(commandFileId,0,'bof');
%             fprintf(commandFileId,'+');              
%             fclose(commandFileId);
%         end
%     
%         %%
%         function commandIndex=issueCommands(self,commandStrings)
%             % Open the command file, and clear the current contents (if
%             % any)
%             commandFileId=fopen(self.CommandFileName_,'w+');  % open for writing.  Create if doesn't exist, discard contents if already exists.
%             if commandFileId<0 ,
%                 % Couldn't open command file
%                 errorId='MulticlampCommanderSocket:CouldNotOpenCommandFile';
%                 errorMessage='Could not open command file';
%                 error(errorId,errorMessage);
%             end            
%             commandIndex=self.NextCommandIndex_;
%             self.NextCommandIndex_=self.NextCommandIndex_+1;
%             fprintf(commandFileId,'-%08d\n',commandIndex);
%             for i=1:length(commandStrings)
%                 fprintf(commandFileId,'%s\n',commandStrings{i});
%             end
%             fprintf(commandFileId,'\n');            
%             % Overwrite the initial - with a +
%             fseek(commandFileId,0,'bof');
%             fprintf(commandFileId,'+');              
%             fclose(commandFileId);
%         end
%     
%         %%
%         function responseString=getResponseString(self,commandIndex)
%             import ws.utility.*
%             responseFileId=fopen(self.ResponseFileName_,'r');
%             if responseFileId<0 ,
%                 % Couldn't open response file
%                 errorId='MulticlampCommanderSocket:CouldNotOpenResponseFile';
%                 errorMessage='Couldn''t get response because couldn''t open reponse file';
%                 error(errorId,errorMessage);
%             end
%             
%             maximumWaitTime=1;  % s
%             dt=0.005;
%             nIterations=round(maximumWaitTime/dt);
%             wasResponseGenerated=false;
%             for i=1:nIterations ,
%                 try
%                     responseIndex=ws.MulticlampCommanderSocket.getResponseIndex_(responseFileId);
%                     success=true;
%                 catch me
%                     id=me.identifier;
%                     if isequal(id,'MulticlampCommanderSocket:UnableToReadResponseFileToGetResponseIndex') || ...
%                        isequal(id,'MulticlampCommanderSocket:InvalidIndexInResponse') ,
%                         % this was a failure, but one that will perhaps
%                         % resolve itself later
%                         success=false;
%                     else
%                         % this seems like a "real" error
%                         rethrow(me);
%                     end
%                 end
%                 if success ,
%                     % We used to do a special check for
%                     % responseIndex>commandIndex and throw if that
%                     % happened, but that turned out to be
%                     % counterproductive.  Sometimes you read an old
%                     % response file from a previous MulticlampCommanderSocket
%                     % session, just because EPCMaster hasn't yet written
%                     % the response to your latest command.  With the old
%                     % code, that would throw.  With the new code, we just
%                     % wait longer to see if the response file appears.
%                     if responseIndex==commandIndex ,
%                         wasResponseGenerated=true;
%                         break
%                     else
%                         % wait longer
%                         sleep(dt);
% %                     else
% %                         % the response index is somehow greater than the
% %                         % command index we're looking for
% %                         fclose(responseFileId);
% %                         errorId='MulticlampCommanderSocket:ResponseIndexTooHigh';
% %                         errorMessage='The response index is greater than the command index already';
% %                         error(errorId,errorMessage);
%                     end
%                 else
%                     sleep(dt);
%                 end
%             end
%             
%             if ~wasResponseGenerated ,
%                 fclose(responseFileId);
%                 errorId='MulticlampCommanderSocket:NoReponse';
%                 errorMessage='EPCMaster did not respond to a command within the timeout interval';
%                 error(errorId,errorMessage);
%             end
%             
%             responseString=fgetl(responseFileId);
%             fclose(responseFileId);
%             if isnumeric(responseString) ,
%                 responseString='';  % Some commands don't have a response beyond just generating a reponse file with the line containging the response index
%                 % errorId='MulticlampCommanderSocket:UnableToReadResponseFileToGetResponseString';
%                 % errorMessage='Unable to read EPCMaster response file to get response string';
%                 % error(errorId,errorMessage);
%             end
%         end  % function
% 
%         %%
%         function responseStrings=getResponseStrings(self,commandIndex)
%             import ws.utility.*
%             %fprintf('Just entered getResponseStrings()\n');
%             %commandIndex
%             responseFileId=fopen(self.ResponseFileName_,'r');
%             if responseFileId<0 ,
%                 % Couldn't open response file
%                 errorId='MulticlampCommanderSocket:CouldNotOpenResponseFile';
%                 errorMessage='Couldn''t get response because couldn''t open reponse file';
%                 error(errorId,errorMessage);
%             end
%             
%             %tStart=tic();
%             maximumWaitTime=1;  % s
%             dt=0.005;
%             nIterations=round(maximumWaitTime/dt);
%             wasResponseGenerated=false;
%             for i=1:nIterations ,
%                 try
%                     responseIndex=ws.MulticlampCommanderSocket.getResponseIndex_(responseFileId);
%                     success=true;
%                 catch me
%                     id=me.identifier;
%                     if isequal(id,'MulticlampCommanderSocket:UnableToReadResponseFileToGetResponseIndex') || ...
%                        isequal(id,'MulticlampCommanderSocket:InvalidIndexInResponse') ,
%                         % this was a failure, but one that will perhaps
%                         % resolve itself later
%                         success=false;
%                     else
%                         % this seems like a "real" error
%                         rethrow(me);
%                     end
%                 end
%                 % success
%                 if success ,
%                     if responseIndex==commandIndex ,
%                         wasResponseGenerated=true;
%                         break
%                     else
%                         % wait longer
%                         sleep(dt);
%                     end
% %                     elseif responseIndex==commandIndex ,
% %                     else
% %                         % the response index is somehow greater than the
% %                         % command index we're looking for
% %                         fclose(responseFileId);
% %                         errorId='MulticlampCommanderSocket:ResponseIndexTooHigh';
% %                         errorMessage='The response index is greater than the command index already';
% %                         error(errorId,errorMessage);
% %                     end
%                 else
%                     sleep(dt);
%                 end
%             end
%             % toc(tStart)
%             
%             if ~wasResponseGenerated ,
%                 fclose(responseFileId);
%                 errorId='MulticlampCommanderSocket:NoReponse';
%                 errorMessage='EPCMaster did not respond to a command within the timeout interval';
%                 error(errorId,errorMessage);
%             end
%             
%             %tStart=tic();
%             responseStrings=cell(1,0);
%             i=1;
%             atEndOfFile=false;
%             while ~atEndOfFile ,
%                 thisLine=fgetl(responseFileId);
%                 if isnumeric(thisLine)
%                     atEndOfFile=true;
%                 else
%                     responseStrings{1,i}=thisLine;
%                     i=i+1;
%                 end
%             end                
%             %toc(tStart)
%             %tStart=tic();
%             fclose(responseFileId);
%             %toc(tStart)
%             %fprintf('About to exit getResponseStrings()\n');
%         end  % function

        %%
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
                        isCommandEnabled{i} = ~isequal(thisMode,ws.ElectrodeMode.IEqualsZero) ; 
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
        %%
        function updateElectrodeList_(self)
            % Update the list of electrode IDs that we know about
            electrodeIDs=ws.dabs.axon.MulticlampTelegraph('getAllElectrodeIDs');
            sortedElectrodeIDs=ws.MulticlampCommanderSocket.sortElectrodeIDs(electrodeIDs);
            self.ElectrodeIDs_ = sortedElectrodeIDs;  % want them ordered reliably
        end  % function
        
    end  % protected methods
    
    methods (Static=true)  % public class methods
%         %%
%         function mode=parseModeResponse(responseString)
%             % The response should look like 'V-Clamp', 'I-Clamp', or 
%             % 'I = 0'
%             % Returns either ws.ElectrodeMode.VC,ws.ElectrodeMode.CC, or ws.ElectrodeMode.IEqualsZero
%             switch responseString ,
%                 case 'V-Clamp' ,
%                     mode=ws.ElectrodeMode.VC;
%                 case 'I-Clamp' ,
%                     mode=ws.ElectrodeMode.CC;
%                 case 'I = 0' ,
%                     mode=ws.ElectrodeMode.IEqualsZero;
%                 otherwise
%                     mode=ws.ElectrodeMode.VC;  % fallback
% %                     errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
% %                     errorMessage='Unable to parse mode response string';
% %                     error(errorId,errorMessage);
%             end
%         end  % function                
% 
%         %%
%         function gain=parseCurrentMonitorRealizedGainResponse(responseString)
%             % The response should look like 'GetEpcParams-1 1.00000E+10',
%             % with that gain in V/A.  We convert to V/pA.
%             % TODO_ALT: Deal with possibility that user wants to use nA, or
%             % whatever.
%             responseStringTokens=strsplit(responseString);
%             if length(responseStringTokens)<2 ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end
%             gainAsString=responseStringTokens{2};
%             gainInOhms=str2double(gainAsString);  % V/A
%             if ~isfinite(gainInOhms) ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end            
%             gain=1e-12*gainInOhms;  % V/A -> V/pA            
%         end  % function                
% 
%         %%
%         function gain=parseCurrentMonitorNominalGainResponse(responseString)
%             % The response should look like 'GetEpcParams-1 0.020mV/pA',
%             % with that gain in mV/pA (obviously).  We convert to V/pA.
%             % TODO_ALT: Deal with possibility that user wants to use nA, or
%             % whatever.
%             responseStringTokens=strsplit(responseString);
%             if length(responseStringTokens)<2 ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end
%             gainWithUnitsAsString=responseStringTokens{2};
%             gainAsString=gainWithUnitsAsString(1:end-5);            
%             gainInNativeUnits=str2double(gainAsString);  % mV/pA
%             if ~isfinite(gainInNativeUnits) ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end            
%             gain=1e-3*gainInNativeUnits;  % mV/pA -> V/pA            
%         end  % function                
% 
%         %%
%         function gain=parseVoltageMonitorGainResponse(responseString)
%             % The response should look like 'GetEpcParams-1 VmonX10' or 'GetEpcParams-1 VmonX100',
%             % with that gain in mV/mV.  We convert to V/mV.
%             responseStringTokens=strsplit(responseString);
%             if length(responseStringTokens)<2 ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end
%             gainAsVmonXString=responseStringTokens{2};
%             gainAsString=gainAsVmonXString(6:end);
%             gainPure=str2double(gainAsString);  % mV/mV
%             if ~isfinite(gainPure) ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end            
%             gain=1e-3*gainPure;  % mV/mV -> V/mV 
%         end  % function
% 
%         %%
%         function gain=parseCurrentCommandGainResponse(responseString)
%             % The response should look like 'GetEpcParams-1 CC0.1pA' [sic], 
%             % with that gain in pA/mV.  We convert to pA/V.
%             % TODO_ALT: Deal with possibility that user wants to use nA, or
%             % whatever.
%             responseStringTokens=strsplit(responseString);
%             if length(responseStringTokens)<2 ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end
%             gainAsCCString=responseStringTokens{2};
%             gainAsString=gainAsCCString(3:end-2);
%             gainRaw=str2double(gainAsString);  % pA/mV
%             if ~isfinite(gainRaw) ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end            
%             gain=1e3*gainRaw;  % pA/mV -> pA/V
%         end  % function                
%         
%         %%
%         function gain=parseVoltageCommandGainResponse(responseString)
%             % The response should look like 'GetEpcParams-1 0.100',
%             % with that gain in mV/mV.  We convert to mV/V.
%             responseStringTokens=strsplit(responseString);
%             if length(responseStringTokens)<2 ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end
%             gainPureAsString=responseStringTokens{2};
%             gainPure=str2double(gainPureAsString);  % mV/mV
%             if ~isfinite(gainPure) ,
%                 errorId='MulticlampCommanderSocket:UnableToParseModeResponseString';
%                 errorMessage='Unable to parse mode response string';
%                 error(errorId,errorMessage);
%             end            
%             gain=1e3*gainPure;  % mV/mV -> mV/V
%         end  % function                        
% 
%         %%
%         function value=parseIsCommandEnabledResponse(responseString)
%             % The response should end in either 'ON' or 'OFF'.
%             responseStringTokens=strsplit(responseString);
%             if length(responseStringTokens)<2 ,
%                 errorId='MulticlampCommanderSocket:UnableToParseIsCommandEnabledResponseString';
%                 errorMessage='Unable to parse external command response string';
%                 error(errorId,errorMessage);
%             end
%             isCommandEnabledAsString=responseStringTokens{end};
%             if strcmp(isCommandEnabledAsString,'ON') ,
%                 value=true;
%             elseif strcmp(isCommandEnabledAsString,'OFF') ,
%                 value=false;
%             else
%                 errorId='MulticlampCommanderSocket:UnableToParseIsCommandEnabledResponseString';
%                 errorMessage='Unable to parse external command response string';
%                 error(errorId,errorMessage);
%             end
%         end  % function                        

%         %%
%         function [xDetent,iDetent]=findClosestDetent(x,detents)
%             [~,iDetent]=min(abs(x-detents));
%             xDetent=detents(iDetent);
%         end  % function
        
        %%
        function units=unitsFromUnitsString(unitsAsString)
            % Convert a units string of the kind produced by
            % ws.dabs.axon.MulticlampTelegraph().
            topAndBottomUnits=strsplit(unitsAsString,'/');
            if isempty(topAndBottomUnits) ,
                units=ws.utility.SIUnit();  % pure (why not?)
            elseif length(topAndBottomUnits)==1 ,
                units=ws.utility.SIUnit(topAndBottomUnits{1});
            else
                units=ws.utility.SIUnit(topAndBottomUnits{1})/ws.utility.SIUnit(topAndBottomUnits{2}) ;
            end                
        end  % function

        %%
        function [targetNumber,err]=numberForTargetUnits(targetUnits,sourceNumber,sourceUnits)
            % Convert a dimensional quantity equal to
            % sourceNumber*sourceUnits to the targetUnits.  sourceUnits
            % and targetUnits must be commensurable.            
            if areSummable(targetUnits,sourceUnits) ,
                targetNumber=sourceNumber.*multiplier(sourceUnits/targetUnits);
                err=[];
            else
                targetNumber=NaN;
                errorId='MulticlampCommanderSocket:unableToConvertToTargetUnits';
                errorMessage='Unable to convert source quantity to target units.';
                err=MException(errorId,errorMessage);
            end
        end  % function
    
        %%
        function [value,err]=modeFromElectrodeState(electrodeState)
            % Returns the current mode as a string
            operatingModeString=electrodeState.OperatingMode;
            switch operatingModeString ,
                case 'V-Clamp' ,
                    value=ws.ElectrodeMode.VC;
                    err=[];
                case 'I-Clamp' ,
                    value=ws.ElectrodeMode.CC;
                    err=[];
                case 'I = 0' ,
                    value=ws.ElectrodeMode.IEqualsZero;
                    err=[];
                otherwise
                    %value=ws.ElectrodeMode.VC;  % fallback
                    value=[];
                    errorId='MulticlampCommanderSocket:electrodeInUnknownMode';
                    errorMessage='Electrode is in an unknown mode.';
                    err=error(errorId,errorMessage);
            end
        end  % function
        
        %%
        function [value,err]=currentMonitorGainFromElectrodeState(electrodeState)
            % Returns the current monitor gain, in V/pA
            if isequal(electrodeState.OperatingMode,'V-Clamp') ,
                if isequal(electrodeState.ScaledOutSignal,'Im') ,
                    rawScaleFactor=electrodeState.ScaleFactor*electrodeState.Alpha;
                    rawUnitsAsString=electrodeState.ScaleFactorUnits;
                    rawUnits=ws.MulticlampCommanderSocket.unitsFromUnitsString(rawUnitsAsString);
                    targetUnits=ws.utility.SIUnit('V')/ws.utility.SIUnit('pA');
                    [value,err]=ws.MulticlampCommanderSocket.numberForTargetUnits(targetUnits,rawScaleFactor,rawUnits);
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
        
        %%
        function [value,err]=voltageMonitorGainFromElectrodeState(electrodeState)
            % Returns the current monitor gain, in V/mV
            if isequal(electrodeState.OperatingMode,'I-Clamp') || isequal(electrodeState.OperatingMode,'I = 0') ,
                if isequal(electrodeState.ScaledOutSignal,'Vm') ,
                    rawScaleFactor = electrodeState.ScaleFactor * electrodeState.Alpha ;
                    rawUnitsAsString=electrodeState.ScaleFactorUnits;
                    rawUnits=ws.MulticlampCommanderSocket.unitsFromUnitsString(rawUnitsAsString);
                    targetUnits=ws.utility.SIUnit('V')/ws.utility.SIUnit('mV');
                    [value,err]=ws.MulticlampCommanderSocket.numberForTargetUnits(targetUnits,rawScaleFactor,rawUnits);
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
        
        %%
        function [value,err]=currentCommandGainFromElectrodeState(electrodeState)
            % Returns the current command gain, in pA/V
            % This one doesn't really need an error output, but we'll leave
            % it for consistentcy.
            if isequal(electrodeState.OperatingMode,'I-Clamp') || isequal(electrodeState.OperatingMode,'I = 0') ,
                rawScaleFactor=electrodeState.ExtCmdSens;
                rawUnits=ws.utility.SIUnit('A')/ws.utility.SIUnit('V');
                targetUnits=ws.utility.SIUnit('pA')/ws.utility.SIUnit('V');
                [value,err]=ws.MulticlampCommanderSocket.numberForTargetUnits(targetUnits,rawScaleFactor,rawUnits);
            else
                value=nan;
                err=[];  % this is not an error, it's part of normal operation
            end
        end  % function
        
        %%
        function [value,err]=voltageCommandGainFromElectrodeState(electrodeState)
            % Returns the voltage command gain, in mV/V
            % This one doesn't really need an error output, but we'll leave
            % it for consistentcy.
            if isequal(electrodeState.OperatingMode,'V-Clamp') ,
                rawScaleFactor=electrodeState.ExtCmdSens;
                rawUnits=ws.utility.SIUnit('V')/ws.utility.SIUnit('V');
                targetUnits=ws.utility.SIUnit('mV')/ws.utility.SIUnit('V');
                [value,err]=ws.MulticlampCommanderSocket.numberForTargetUnits(targetUnits,rawScaleFactor,rawUnits);
            else
                value=nan;
                err=[];  % this is not an error, it's part of normal operation
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
                                     'channelID',temp);
            for i=1:numel(electrodeID) ,
                id=uint32(electrodeID(i));                
                aOrB=ws.MulticlampCommanderSocket.multiclampAOrBFromElectrodeID(id);
                if isequal(aOrB,'A') ,
                    % 700A
                    channelID=uint16(bitshift(id,-16));
                    axoBusID=uint8(bitand(bitshift(id,-8),255));
                    comPortID=uint8(bitand(id,255));
                    serialNumber=[];
                else
                    % 700B
                    serialNumber=uint32(bitand(id,268435455));  % 268435455==2^28-1
                    channelID=uint8(bitshift(id,-28));
                    axoBusID=[];
                    comPortID=[];
                end
                electrodeIDStruct(i)=struct('aOrB',aOrB, ...
                                            'comPortID',comPortID, ...
                                            'axoBusID',axoBusID, ...
                                            'serialNumber',serialNumber, ...
                                            'channelID',channelID);
            end
        end  % function

        function electrodeID=electrodeIDFromElectrodeIDStruct(electrodeIDStruct)
            electrodeID=zeros(size(electrodeIDStruct),'uint32');
            for i=1:numel(electrodeIDStruct) ,
                s=electrodeIDStruct(i);
                if isequal(s.aOrB,'A') ,
                    % 700A
                    electrodeID(i)=bitor(bitshift(uint32(s.channelID),16), ...
                                         bitshift(uint32(s.axoBusID),8), ...
                                         uint32(s.comPortID));
                else
                    % 700B
                    electrodeID(i)=bitor(s.serialNumber, ...
                                         bitshift(uint32(s.channelID),28));
                end
            end
        end  % function
        
        function sorted = sortElectrodeIDStructs(s)
            % Sort electrodeIDStructs as we want them to be sorted.
            % This relies on sort() doing a stable sort.
            sorted=s;  
            
            % Sort by channelID
            channelID=uint16([sorted.channelID]);
            [~,i]=sort(channelID);
            sorted=sorted(i);

            % Sort by serialNumber
            serialNumber={sorted.serialNumber};
            serialNumber=cellfun(@(c)(ws.utility.fif(isempty(c),-inf,c)),serialNumber);  % 700As have serialNumber == -inf, so they are left on left end
            [~,i]=sort(serialNumber);
            sorted=sorted(i);
            
            % Sort by axoBusID
            axoBusID={sorted.axoBusID};
            axoBusID=cellfun(@(c)(ws.utility.fif(isempty(c),+inf,c)),axoBusID);  % 700Bs have axoBusID == inf, so they are left on right end
            [~,i]=sort(axoBusID);
            sorted=sorted(i);
            
            % Sort by com port
            comPortID={sorted.comPortID};
            comPortID=cellfun(@(c)(ws.utility.fif(isempty(c),+inf,c)),comPortID);  % 700Bs have comPortID == inf, so they are left on right end
            [~,i]=sort(comPortID);
            sorted=sorted(i);
            
            % Think this should already be good
%             % Sort by A-or-B
%             is700B=double(strcmp({sorted.aOrB},'B'));            
%             [~,i]=sort(is700B);
%             sorted=sorted(i);
            
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
    
    methods (Static=true, Access=protected)  % protected class methods
        %%
        function responseIndex=getResponseIndex_(responseFileId)
            % If successful, leaves the file pointer at the start of the
            % second line of the response file
            fseek(responseFileId,0,'bof');
            firstLine=fgetl(responseFileId);
            if isnumeric(firstLine) ,
                errorId='MulticlampCommanderSocket:UnableToReadResponseFileToGetResponseIndex';
                errorMessage='Unable to read response file to get response index';
                error(errorId,errorMessage);
            end
            responseIndex=str2double(firstLine);
            if ~isreal(responseIndex) || ~isfinite(responseIndex) || responseIndex~=round(responseIndex) ,
                errorId='MulticlampCommanderSocket:InvalidIndexInResponse';
                errorMessage='Response file had an invalid index';
                error(errorId,errorMessage);
            end
        end  % function                    
    end  % protected class methods

end  % classdef
