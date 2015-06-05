classdef ElectrodeManager < ws.Model & ws.Mimic  % & ws.EventBroadcaster (was before Mimic)
    properties (Access = protected, Transient=true)
        Parent_  % the parent Ephys object
    end    
    
    properties (Access = protected)
        Electrodes_ = cell(1,0);  % row vector of electrodes
        IsElectrodeMarkedForTestPulse_ = true(1,0)  % boolean row vector, same length as Electrodes_
        IsElectrodeMarkedForRemoval_ = false(1,0)  % boolean row vector, same length as Electrodes_
        LargestElectrodeIndexUsed_ = -inf
        %IdleHeartbeatTimer_  
           % A timer that runs at ~1 Hz when WS is idle, does stuff that
           % needs doing regularly.
        EPCMasterSocket_  % A 'socket' for communicating with the EPCMaster application
        MulticlampCommanderSocket_  % A 'socket' for communicating with the Multiclamp Commander application
        AreSoftpanelsEnabled_
        DidLastElectrodeUpdateWork_ = false(1,0)  % false iff an electrode is smart, and the last attempted update of its gains, etc. threw an error
    end
    
    % TODO: Consider getting rid of public Electrodes, TestPulseElectrodes
    % properties.  These return handle arrays, so they allow for direct
    % manipulation of Electrodes.  Might be a better design to require all
    % electrode changes to go through the ElectrodeManager, because in some
    % cases the ElectrodeManager has to make sure electrode changes get
    % propagated through the whole WavesurferModel, and get propagated to the
    % EPCMasterSocket in some cases.  This would be a good deal of work,
    % though.
    
    properties (Dependent=true, SetAccess=immutable)
        NElectrodes
        TestPulseElectrodes  % the electrodes that are marked for test pulsing.
        TestPulseElectrodeNames  % the names of the electrodes that are marked for test pulsing.
        Electrodes
        DidLastElectrodeUpdateWork
    end
    
    properties (Dependent=true)
        Parent  % public access to parent property
        IsElectrodeMarkedForTestPulse  % provides public access to IsElectrodeMarkedForTestPulse_; settable as long as you don't change its shape
        IsElectrodeMarkedForRemoval  % provides public access to IsElectrodeMarkedForRemoval_; settable as long as you don't change its shape
        AreSoftpanelsEnabled
        IsInControlOfSoftpanelModeAndGains
    end
    
%     events
%         MayHaveChanged
%     end

    methods
        function self = ElectrodeManager(varargin)
            % General initialization
            self.EPCMasterSocket_=ws.EPCMasterSocket();
            self.MulticlampCommanderSocket_=ws.MulticlampCommanderSocket();
            self.AreSoftpanelsEnabled_=true;

            % Create the heartbeat timer
%             self.IdleHeartbeatTimer_=timer('Name','EphysIdleHeartbeatTimer', ...
%                                            'ExecutionMode','fixedSpacing', ...
%                                            'Period',1, ...
%                                            'TimerFcn',@(object,event,varargin)(self.heartbeat(object,event)), ...
%                                            'ErrorFcn',@(object,event,varargin)(self.heartbeatError(object,event)));            
            
            % Process args
            validPropNames=ws.most.util.findPropertiesSuchThat(self,'SetAccess','public');
            mandatoryPropNames=cell(1,0);
            pvArgs = ws.most.util.filterPVArgs(varargin,validPropNames,mandatoryPropNames);
            propNamesRaw = pvArgs(1:2:end);
            propValsRaw = pvArgs(2:2:end);
            nPVs=length(propValsRaw);  % Use the number of vals in case length(varargin) is odd
            propNames=propNamesRaw(1:nPVs);
            propVals=propValsRaw(1:nPVs);            
            
            % Set the properties
            for idx = 1:nPVs
                self.(propNames{idx}) = propVals{idx};
            end
        end
        
        function delete(self)
            %self.IsInControlOfSoftpanelModeAndGains=false;
            %self.AreSoftpanelsEnabled_ = true ;
            %self.Parent = [];
            self.Parent_ = [];  % eliminate reference to parent object (do I need this?)
        end
        
        function out = get.NElectrodes(self)
            out=length(self.Electrodes_);
        end
        
        function out = get.Electrodes(self)
            out=self.Electrodes_;
        end
        
        function out = get.TestPulseElectrodes(self)
            electrodes=self.Electrodes_;
            out=electrodes(self.IsElectrodeMarkedForTestPulse_);
        end
        
        function out = get.TestPulseElectrodeNames(self)
            out=cellfun(@(electrode)(electrode.Name), ...
                        self.TestPulseElectrodes, ...
                        'UniformOutput',false);
        end
        
        function out = get.DidLastElectrodeUpdateWork(self)
            out=self.DidLastElectrodeUpdateWork_;
        end
        
        function out=get.IsElectrodeMarkedForRemoval(self)
            out=self.IsElectrodeMarkedForRemoval_;
        end

        function set.IsElectrodeMarkedForRemoval(self,newValue)
            % newValue must be same shape as old
            if all(size(newValue)==size(self.IsElectrodeMarkedForRemoval_)) ,
                self.IsElectrodeMarkedForRemoval_=newValue;
            end
            self.broadcast('Update');
        end
        
        function out=get.IsElectrodeMarkedForTestPulse(self)
            out=self.IsElectrodeMarkedForTestPulse_;
        end

        function set.IsElectrodeMarkedForTestPulse(self,newValue)
            % newValue must be same shape as old
            if all(size(newValue)==size(self.IsElectrodeMarkedForTestPulse_)) ,
                self.IsElectrodeMarkedForTestPulse_=newValue;
            end
            if ~isempty(self.Parent_) ,
                self.Parent_.isElectrodeMarkedForTestPulseMayHaveChanged();  % notify the parent, so can update ElectrodeManager
            end
            self.broadcast('Update');
        end
        
        function out=get.Parent(self)
            out=self.Parent_;
        end
        
        function set.Parent(self,newValue)
            if isempty(newValue) || isa(newValue,'ws.system.Ephys') ,
                self.Parent_=newValue;
            end
        end
        
        function out=get.AreSoftpanelsEnabled(self)
            out=self.AreSoftpanelsEnabled_;
        end

        function set.AreSoftpanelsEnabled(self,newValue)
            if islogical(newValue) && isscalar(newValue) ,
                self.AreSoftpanelsEnabled_=newValue;
            end
            self.broadcast('Update');            
        end
        
        function out=get.IsInControlOfSoftpanelModeAndGains(self)
            out=~self.AreSoftpanelsEnabled_;
        end

        function set.IsInControlOfSoftpanelModeAndGains(self,newValue)
            if islogical(newValue) && isscalar(newValue) ,
                self.AreSoftpanelsEnabled_=(~newValue);
            end
            self.broadcast('Update');            
        end
        
        function addNewElectrode(self)
            % Figure out an electrode name that is not already an electrode
            % name
            %currentElectrodeNames={self.Electrodes_.Name};
            %electrode=[];  % fallback return value
            currentElectrodeNames=cellfun(@(electrode)(electrode.Name),self.Electrodes_,'UniformOutput',false);
            isPutativeNameUnique=false;
            iInitial=max(self.LargestElectrodeIndexUsed_,0)+1;
            for i=iInitial:iInitial+100 ,
                putativeName=sprintf('Electrode %d',i);
                if any(strcmp(putativeName,currentElectrodeNames)) ,                    
                    continue
                else
                    isPutativeNameUnique=true;
                    break
                end
            end
            if isPutativeNameUnique ,
                self.LargestElectrodeIndexUsed_=max(i,self.LargestElectrodeIndexUsed_);
                name=putativeName;
            else
                % Theoretically, should throw exception, I suppose
                return
            end
            
            % At this point, name is a valid electrode name
            
            % Make an electrode
            electrode= ...
                ws.Electrode('Parent',self, ...
                                'Name',name);
            
            % We now leave the channel names blank until the user selects them.                      
%             % Get initial values for the channel names, set them in the
%             % trode
%             ephys=self.Parent_;
%             if isempty(ephys) ,
%                 wavesurferModel=[];
%             else
%                 wavesurferModel=ephys.Parent;
%             end
%             if isempty(wavesurferModel) ,
%                 channelNames=cell(1,0);
%             else
%                 channelNames=wavesurferModel.Stimulation.ChannelNames;
%             end
%             if ~isempty(channelNames) ,
%                 electrode.VoltageCommandChannelName=channelNames{1};
%                 electrode.CurrentCommandChannelName=channelNames{1};
%             end
%             if isempty(wavesurferModel) ,
%                 channelNames=cell(1,0);
%             else
%                 channelNames=wavesurferModel.Acquisition.ChannelNames;
%             end
%             if ~isempty(channelNames) ,
%                 electrode.VoltageMonitorChannelName=channelNames{1};
%                 electrode.CurrentMonitorChannelName=channelNames{1};
%             end
            
            % Add the electrode        
            self.Electrodes_{end+1}=electrode;  
            self.IsElectrodeMarkedForTestPulse_(end+1)=true;
            self.IsElectrodeMarkedForRemoval_(end+1)=false;
            self.DidLastElectrodeUpdateWork_(end+1)=true;  % true by convention
            
            % Notify the parent Ephys object that an electrode has been added
            ephys=self.Parent_;
            if ~isempty(ephys) ,
                ephys.electrodeWasAdded(electrode);
            end
            
            % Notify subscribers
            self.broadcast('Update');
        end
        
        function removeMarkedElectrodes(self)
            isToBeRemoved= self.IsElectrodeMarkedForRemoval_;
            % The constructions below (=[]) are better than the alternative
            % (where you define isToBeKept and do x=x(isToBeKept) b/c it
            % keeps row vectors row vectors, even when they are reduced to
            % zero length.
            self.Electrodes_(isToBeRemoved)=[];
            self.IsElectrodeMarkedForTestPulse_(isToBeRemoved)=[];
            self.IsElectrodeMarkedForRemoval_(isToBeRemoved)=[];  % should be all false afterwards
            self.DidLastElectrodeUpdateWork_(isToBeRemoved)=[];
            
            % If the number of electrodes is down to zero, reset the
            % default electrode numbering
            if isempty(self.Electrodes_) ,
                self.LargestElectrodeIndexUsed_ = -inf;
            end
            
            % Notify the parent Ephys object that an electrode has been
            % removed
            if ~isempty(self.Parent_)
                self.Parent_.electrodesRemoved();
            end

            % Notify subscribers
            self.broadcast('Update');            
        end

%         function updateSmartElectrodeGainsAndModes(self)
%             if ~isempty(self.Parent_) ,
%                 self.Parent_.updateSmartElectrodeGainsAndModes();
%             end
%         end
%         
%         function toggleSoftpanelEnablement(self)
%             if ~isempty(self.Parent_) ,
%                 self.Parent_.toggleSoftpanelEnablement();
%             end            
%         end        
        
        function setElectrodeType(self,electrodeIndex,newValue)
            % can only change the electrode type if softpanels are
            % enabled.  I.e. only when WS is _not_ in command of the
            % gain settings
            self.changeReadiness(-1);  % may have to establish contact with the softpanel, which can take a little while
            if self.AreSoftpanelsEnabled_ ,
                electrode=self.Electrodes_{electrodeIndex};
                originalType=electrode.Type;
                if ~isequal(newValue,originalType) ,
                    electrode.Type=newValue;
                    newType=electrode.Type;  % if newValue was invalid, newType will be same as originalType
                    if ~isequal(newType,originalType) ,
                        isManualElectrode=isequal(newType,'Manual');
                        if isManualElectrode ,
                            self.DidLastElectrodeUpdateWork_(electrodeIndex)=true;
                        else
                            % need to do an update if smart electrode
                            self.updateSmartElectrodeGainsAndModes();
                        end
                    end                    
                end
            end
            self.changeReadiness(+1);
        end  % function
        
        function setElectrodeIndexWithinType(self,electrodeIndex,newValue)
            % can only change the electrode type if softpanels are
            % enabled.  I.e. only when WS is _not_ in command of the
            % gain settings
            if self.AreSoftpanelsEnabled_ ,
                electrode=self.Electrodes_{electrodeIndex};
                originalValue=electrode.IndexWithinType;
                if ~isequal(newValue,originalValue) ,
                    electrode.IndexWithinType=newValue;
                    checkValue=electrode.IndexWithinType;  % if newValue was invalid, checkValue will be same as originalType
                    if ~isequal(checkValue,originalValue) ,
                        type=electrode.Type;
                        isManualElectrode=isequal(type,'Manual');
                        isSmartElectrode=~isManualElectrode;
                        if isSmartElectrode ,
                            self.updateSmartElectrodeGainsAndModes();
                        end
                    end                    
                end
            end
        end  % function

        function setTestPulseElectrodeModeOrScaling(self,testPulseElectrodeIndex,propertyName,newValue)
            % Like setElectrodeModeOrScaling(), but the given electrode
            % index refers to the index within the test pulse electrodes
            % only.
            electrodeIndices=(1:self.NElectrodes);
            testPulseElectrodeIndices=electrodeIndices(self.IsElectrodeMarkedForTestPulse_);
            electrodeIndex=testPulseElectrodeIndices(testPulseElectrodeIndex);
            self.setElectrodeModeOrScaling(electrodeIndex,propertyName,newValue);
        end  % function

        function setElectrodeMonitorScaling(self, electrodeIndex, newValue)
            electrode = self.Electrodes_{electrodeIndex} ;
            if electrode.getIsInAVCMode() ,
                propertyName = 'CurrentMonitorScaling' ;
            else
                propertyName = 'VoltageMonitorScaling' ;
            end                
            self.setElectrodeModeOrScaling(electrodeIndex, propertyName, newValue) ;
        end  % function
        
        function setElectrodeCommandScaling(self, electrodeIndex, newValue)
            electrode = self.Electrodes_{electrodeIndex} ;
            if electrode.getIsInAVCMode() ,
                propertyName = 'VoltageCommandScaling' ;
            else
                propertyName = 'CurrentCommandScaling' ;
            end                
            self.setElectrodeModeOrScaling(electrodeIndex, propertyName, newValue) ;
        end  % function
        
        function setElectrodeModeOrScaling(self,electrodeIndex,propertyName,newValue)
            electrode=self.Electrodes_{electrodeIndex};
            type=electrode.Type;
            isManualElectrode=isequal(type,'Manual');
            if isManualElectrode ,
                % just set it
                electrode.(propertyName)=newValue;
            else
                % is smart electrode
                if self.AreSoftpanelsEnabled_ ,
                    % this shouldn't ever happen
                else
                    % if softpanel UIs are enabled, we need to command the
                    % softpanel
                    
                    % Need to translate the property name (used by Electrode) to a parameter                    
                    % name (used by EPCMasterSocket/MulticlampCommanderSocket)
                    parameterNameForSetting=self.parameterNameForSettingFromPropertyName(electrodeIndex,propertyName);
                    parameterNameForGetting=self.parameterNameForGettingFromPropertyName(electrodeIndex,propertyName);
                    
                    if isequal(type,'Heka EPC') ,
                        indexWithinType=electrode.IndexWithinType;
                        try
                            self.EPCMasterSocket_.setElectrodeParameter(indexWithinType,parameterNameForSetting,newValue);
                            % if we get here, no exception happened within
                            % EPCMasterSocket
                            newValueCheck=self.EPCMasterSocket_.getElectrodeParameter(indexWithinType,parameterNameForGetting);
                            electrode.(propertyName)=newValueCheck;  % set the value in the electrode proper
                            % For a Heka amp, setting the voltage command
                            % scaling can affect the external command
                            % enablement and vice-versa.  So update the
                            % other one in these cases.
                            if self.EPCMasterSocket_.IsOpen && self.EPCMasterSocket_.HasCommandOnOffSwitch ,
                                if isequal(parameterNameForSetting,'VoltageCommandGain') ,
                                    otherPropertyName='IsCommandEnabled';
                                    otherParameterNameForGetting=self.parameterNameForGettingFromPropertyName(electrodeIndex,otherPropertyName);
                                    otherValue=self.EPCMasterSocket_.getElectrodeParameter(indexWithinType,otherParameterNameForGetting);
                                    electrode.(otherPropertyName)=otherValue;  % set the value in the electrode proper
                                elseif isequal(parameterNameForSetting,'IsCommandEnabled') || isequal(parameterNameForSetting,'Mode') ,
                                    otherPropertyName='VoltageCommandScaling';
                                    otherParameterNameForGetting=self.parameterNameForGettingFromPropertyName(electrodeIndex,otherPropertyName);
                                    otherValue=self.EPCMasterSocket_.getElectrodeParameter(indexWithinType,otherParameterNameForGetting);
                                    electrode.(otherPropertyName)=otherValue;  % set the value in the electrode proper
                                end
                            end
                        catch me
                            % deal with EPCMasterSocket exceptions,
                            % otherwise rethrow
                            indicesThatMatch=strfind(me.identifier,'EPCMasterSocket:');                
                            if ~isempty(indicesThatMatch) && indicesThatMatch(1)==1 ,
                                % The error was an EPCMasterSocket error,
                                % so we just neglect to set the mode in the
                                % electrode, and make sure the view gets
                                % resynced
                                self.electrodeMayHaveChanged(electrode,propertyName);
                            else
                                % There was some other kind of problem
                                rethrow(me);
                            end
                        end                        
                    else
                        % no other softpanel types are implemented                        
                    end
                end
            end                
        end  % function
        
        function electrodeMayHaveChanged(self,electrode,propertyName)
            % Called by the child electrodes when they may have changed.
            % Currently, broadcasts that self has changed, and notifies the
            % parent Ephys object.
            
            % propagate the notifications up the chain of command
            if ~isempty(self.Parent_) ,
                self.Parent_.electrodeMayHaveChanged(electrode,propertyName);
            end
            
            % notify the view(s)
            self.broadcast('Update');
        end  % function
        
%         function set.Electrodes(self,newElectrodes)
%             % Way to set all the electrodes.  This uses only property
%             % getters and setters to to its thing, so in that sense it's a
%             % high-level method.
%             nOldElectrodes=self.NElectrodes;
%             self.IsElectrodeMarkedForRemoval=true(1,nOldElectrodes);
%             self.removeMarkedElectrodes();
%             nNewElectrodes=length(newElectrodes);
%             for i=1:nNewElectrodes ,
%                 self.addNewElectrode();
%                 self.Electrodes(i).Name=newElectrodes(i).Name;
%                 self.Electrodes(i).Mode=newElectrodes(i).Mode;
%                 self.Electrodes(i).VoltageCommandChannelName=newElectrodes(i).VoltageCommandChannelName;
%                 self.Electrodes(i).CurrentMonitorChannelName=newElectrodes(i).CurrentMonitorChannelName;
%                 self.Electrodes(i).CurrentCommandChannelName=newElectrodes(i).CurrentCommandChannelName;
%                 self.Electrodes(i).VoltageMonitorChannelName=newElectrodes(i).VoltageMonitorChannelName;
%                 self.Electrodes(i).TestPulseAmplitudeInVC=newElectrodes(i).TestPulseAmplitudeInVC;
%                 self.Electrodes(i).TestPulseAmplitudeInCC=newElectrodes(i).TestPulseAmplitudeInCC;
%             end
%         end
        
        function electrode=getElectrodeByName(self,electrodeName)
            electrodeNames=cellfun(@(electrode)(electrode.Name),self.Electrodes_,'UniformOutput',false);
            isElectrode=strcmp(electrodeName,electrodeNames);
            nMatches=sum(isElectrode);
            if nMatches==0 ,
                electrode=[];
            else
                electrodes=self.Electrodes_(isElectrode);
                electrode=electrodes{1};
            end
        end  % function
        
%         function result=getIsCommandChannelManagedByName(self,channelName)
%             if isempty(channelName) ,
%                 result=false;
%                 return
%             end
%             electrodes=self.Electrodes;
%             for i=1:self.NElectrodes ,
%                 if isequal(channelName,electrodes{i}.CommandChannelName);
%                     result=true;
%                     return
%                 end
%             end
%             result=false;
%         end  % function
%         
%         function result=getIsMonitorChannelManagedByName(self,channelName)
%             if isempty(channelName) ,
%                 result=false;
%                 return
%             end
%             electrodes=self.Electrodes;
%             for i=1:self.NElectrodes ,
%                 if isequal(channelName,electrodes{i}.MonitorChannelName);
%                     result=true;
%                     return
%                 end
%             end
%             result=false;
%         end  % function
        
%         function [isQueryChannelScaleManaged, ...
%                   queryChannelUnits, ...
%                   queryChannelScales] = getCommandUnitsAndScalesByName(self,queryChannelNames)
%             commandChannelNames=cellfun(@(electrode)(electrode.CommandChannelName), ...
%                                         self.Electrodes_, ...
%                                         'UniformOutput',false);
%             nQueryChannels=length(queryChannelNames);
%             nElectrodes=self.NElectrodes;
%             commandChannelNamesBig=repmat(commandChannelNames',[1 nQueryChannels]);
%             queryChannelNamesBig=repmat(queryChannelNames,[nElectrodes 1]);            
%             isMatchBig=cellfun(@(string1,string2)(isequal(string1,string2)), ...
%                                commandChannelNamesBig, ...
%                                queryChannelNamesBig);
%                 % nElectrodes x nQueryChannels, indicates where the channel
%                 % names match
%             isQueryChannelScaleManaged=any(isMatchBig,1);
%             commandUnits=cellfun(@(electrode)(electrode.CommandUnits), ...
%                                  self.Electrodes_, ...
%                                  'UniformOutput',false);
%             commandScales=cellfun(@(electrode)(electrode.CommandScaling), ...
%                                   self.Electrodes_ , ...
%                                   'UniformOutput',false);
%             queryChannelUnits=repmat(ws.utility.SIUnit(),[1 nQueryChannels]);
%             queryChannelScales=ones([1 nQueryChannels]);
%             for i=1:nQueryChannels ,
%                 if isQueryChannelScaleManaged(i), 
%                     isMatchForThisQueryChannel=isMatchBig(:,i)';
%                     queryChannelUnits(i)=commandUnits{isMatchForThisQueryChannel};
%                     queryChannelScales(i)=commandScales{isMatchForThisQueryChannel};
%                 end                    
%             end
%         end  % function
        
        function isMatchBig = getMatrixOfMatchesToCommandChannelNames(self,queryChannelNamesRaw)
            % nElectrodes x nQueryChannels, indicates where the command channel
            % names match the queryChannelNames.
            if ischar(queryChannelNamesRaw) ,
                queryChannelNames={queryChannelNamesRaw};
            else
                queryChannelNames=queryChannelNamesRaw;
            end
            nElectrodes=self.NElectrodes;
            nQueryChannels=length(queryChannelNames);
            isMatchBig=false(nElectrodes,nQueryChannels);
            for i=1:nElectrodes ,
                for j=1:nQueryChannels,
                    isMatchBig(i,j)=self.Electrodes{i}.isNamedCommandChannelManaged(queryChannelNames{j});
                end
            end
        end  % function
        
%         function value = getIsCommandChannelManagedByName(self,queryChannelNames)
%             % Returns a boolean array of same size as queryChannelNames
%             value=(self.getNumberOfElectrodesClaimingCommandChannel(queryChannelNames)==1);
%         end  % function
        
        function value = getNumberOfElectrodesClaimingCommandChannel(self,queryChannelNames)
            % Returns a boolean array of same size as queryChannelNames
            isMatchBig = self.getMatrixOfMatchesToCommandChannelNames(queryChannelNames);% nElectrodes x nQueryChannels
            value=sum(isMatchBig,1);
        end  % function
        
        function [queryChannelUnits,isQueryChannelScaleManaged] = getCommandUnitsByName(self,queryChannelNamesRaw)
            if ischar(queryChannelNamesRaw) ,
                queryChannelNames={queryChannelNamesRaw};
            else
                queryChannelNames=queryChannelNamesRaw;
            end
            isMatchBig = self.getMatrixOfMatchesToCommandChannelNames(queryChannelNames);  % nElectrodes x nQueryChannels
            isQueryChannelScaleManaged=(sum(isMatchBig,1)==1);            
            nQueryChannels=length(queryChannelNames);
            queryChannelUnits=repmat(ws.utility.SIUnit(),[1 nQueryChannels]);
            for i=1:nQueryChannels ,
                if isQueryChannelScaleManaged(i),
                    isRelevantElectrode=isMatchBig(:,i);
                    iRelevantElectrodes=find(isRelevantElectrode);
                    if isscalar(iRelevantElectrodes) ,
                        iElectrode=iRelevantElectrodes(1); 
                        electrode=self.Electrodes{iElectrode};
                        queryChannelUnits(i)=electrode.getCommandUnitsByName(queryChannelNames{i});
                    end                    
                end                    
            end
        end  % function
        
        
        function [queryChannelScales,isQueryChannelScaleManaged] = getCommandScalingsByName(self,queryChannelNamesRaw)
            if ischar(queryChannelNamesRaw) ,
                queryChannelNames={queryChannelNamesRaw};
            else
                queryChannelNames=queryChannelNamesRaw;                
            end
            isMatchBig = self.getMatrixOfMatchesToCommandChannelNames(queryChannelNames);  % nElectrodes x nQueryChannels
            isQueryChannelScaleManaged=(sum(isMatchBig,1)==1);            
            nQueryChannels=length(queryChannelNames);
            queryChannelScales=ones(1,nQueryChannels);
            for i=1:nQueryChannels ,
                if isQueryChannelScaleManaged(i),
                    isRelevantElectrode=isMatchBig(:,i);
                    iRelevantElectrodes=find(isRelevantElectrode);
                    if isscalar(iRelevantElectrodes) ,
                        iElectrode=iRelevantElectrodes(1);  
                        electrode=self.Electrodes{iElectrode};
                        queryChannelScales(i)=electrode.getCommandScalingByName(queryChannelNames{i});
                    end                    
                end                    
            end
        end  % function
        
        
        function isMatchBig = getMatrixOfMatchesToMonitorChannelNames(self,queryChannelNamesRaw)
            % nElectrodes x nQueryChannels, indicates where the monitor channel
            % names match the queryChannelNames.
            if ischar(queryChannelNamesRaw) ,
                queryChannelNames={queryChannelNamesRaw};
            else
                queryChannelNames=queryChannelNamesRaw;                
            end
            nElectrodes=self.NElectrodes;
            nQueryChannels=length(queryChannelNames);
            isMatchBig=false(nElectrodes,nQueryChannels);
            for i=1:nElectrodes ,
                electrode=self.Electrodes{i};
                for j=1:nQueryChannels, 
                    isMatchBig(i,j)=electrode.isNamedMonitorChannelManaged(queryChannelNames{j});
                end
            end
        end  % function
        
%         
%         function value = getIsMonitorChannelManagedByName(self,queryChannelNames)
%             % Returns a boolean array of same size as queryChannelNames
%             value=(self.getNumberOfElectrodesClaimingMonitorChannel(queryChannelNames)==1);
%         end  % function
        
        
        function value = getNumberOfElectrodesClaimingMonitorChannel(self,queryChannelNames)
            % Returns a boolean array of same size as queryChannelNames
            isMatchBig = self.getMatrixOfMatchesToMonitorChannelNames(queryChannelNames);% nElectrodes x nQueryChannels
            value=sum(isMatchBig,1);
        end  % function
        
        
        function [queryChannelUnits,isQueryChannelScaleManaged] = getMonitorUnitsByName(self,queryChannelNamesRaw)
            if ischar(queryChannelNamesRaw) ,
                queryChannelNames={queryChannelNamesRaw};
            else
                queryChannelNames=queryChannelNamesRaw;                
            end
            isMatchBig = self.getMatrixOfMatchesToMonitorChannelNames(queryChannelNames);  % nElectrodes x nQueryChannels
            isQueryChannelScaleManaged=(sum(isMatchBig,1)==1);            
            nQueryChannels=length(queryChannelNames);
            queryChannelUnits=repmat(ws.utility.SIUnit(),[1 nQueryChannels]);
            for i=1:nQueryChannels ,
                if isQueryChannelScaleManaged(i),
                    isRelevantElectrode=isMatchBig(:,i);
                    iRelevantElectrodes=find(isRelevantElectrode);
                    if isscalar(iRelevantElectrodes) ,
                        iElectrode=iRelevantElectrodes(1);  
                        electrode=self.Electrodes{iElectrode};
                        queryChannelUnits(i)=electrode.getMonitorUnitsByName(queryChannelNames{i});
                    else
                        % do nothing, thus falling back to dimensionless
                    end                    
                end                    
            end
        end  % function
        
        
        function [queryChannelScales,isQueryChannelScaleManaged] = getMonitorScalingsByName(self,queryChannelNamesRaw)
            if ischar(queryChannelNamesRaw) ,
                queryChannelNames={queryChannelNamesRaw};
            else
                queryChannelNames=queryChannelNamesRaw;                
            end
            isMatchBig = self.getMatrixOfMatchesToMonitorChannelNames(queryChannelNames);  % nElectrodes x nQueryChannels
            isQueryChannelScaleManaged=(sum(isMatchBig,1)==1);            
            nQueryChannels=length(queryChannelNames);
            queryChannelScales=ones(1,nQueryChannels);
            for i=1:nQueryChannels ,
                if isQueryChannelScaleManaged(i),
                    isRelevantElectrode=isMatchBig(:,i);
                    iRelevantElectrodes=find(isRelevantElectrode);
                    if isscalar(iRelevantElectrodes) ,
                        iElectrode=iRelevantElectrodes(1);  
                        electrode=self.Electrodes{iElectrode};
                        queryChannelScales(i)=electrode.getMonitorScalingByName(queryChannelNames{i});
                    end                    
                end                    
            end
        end  % function
        
        
        function result=areAllCommandChannelNamesDistinct(self)
            channelNames=cellfun(@(electrode)(electrode.CommandChannelName), ...
                                 self.Electrodes_ , ...
                                 'UniformOutput',false);
            channelNames=channelNames(self.IsElectrodeMarkedForTestPulse_);                             
            uniqueChannelNames=unique(channelNames);
            result=(length(channelNames)==length(uniqueChannelNames));
        end  % function
        
        function result=areAllMonitorChannelNamesDistinct(self)
            channelNames=cellfun(@(electrode)(electrode.MonitorChannelName), ...
                                 self.Electrodes_ , ...
                                 'UniformOutput',false);
            channelNames=channelNames(self.IsElectrodeMarkedForTestPulse_);                             
            uniqueChannelNames=unique(channelNames);
            result=(length(channelNames)==length(uniqueChannelNames));
        end  % function
        
        function result=areAllMonitorAndCommandChannelNamesDistinct(self)
            result=self.areAllCommandChannelNamesDistinct() && ...
                   self.areAllMonitorChannelNamesDistinct() ;
        end  % function
        
        function result=areAllElectrodesTestPulsable(self)
            nElectrodes=self.NElectrodes;
            for i=1:nElectrodes
                if ~self.IsElectrodeMarkedForTestPulse_(i) ,
                    continue
                end
                electrode=self.Electrodes_{i};
                if ~electrode.isTestPulsable() ,
                    result=false;
                    return
                end
            end
            result=true;
        end  % function
        
        function result=areAnyElectrodesSmart(self)
            isElectrodeManual=self.isElectrodeOfType('Manual');
            isElectrodeSmart=~isElectrodeManual;
            result=any(isElectrodeSmart);
        end  % function
        
        function result=areAnyElectrodesCommandable(self)
            isElectrodeCommandable=self.isElectrodeOfType('Heka EPC');
            result=any(isElectrodeCommandable);
        end  % function
        
        function result=isElectrodeOfType(self,queryType)
            typePerElectrode=cellfun(@(electrode)(electrode.Type), ...
                                     self.Electrodes, ...
                                     'UniformOutput',false);
            result=strcmp(queryType,typePerElectrode);
        end  % function
        
        function result=doesElectrodeHaveCommandOnOffSwitch(self)
            isElectrodeHeka=self.isElectrodeOfType('Heka EPC');
            if any(isElectrodeHeka) ,            
                if self.EPCMasterSocket_.HasCommandOnOffSwitch ,
                    result=isElectrodeHeka;
                else
                    result=false(size(isElectrodeHeka));
                end
            else
                result=isElectrodeHeka;
            end            
        end
        
        function toggleSoftpanelEnablement(self)
            originalValue=self.AreSoftpanelsEnabled_;
            putativeNewValue=~originalValue;
            try
                self.EPCMasterSocket_.setUIEnablement(putativeNewValue);
            catch me
                % If the exception is an EPCMasterSocket-specific one, then
                % we failed to set the mode
                indicesThatMatch=strfind(me.identifier,'EPCMasterSocket:');                
                if ~isempty(indicesThatMatch) && indicesThatMatch(1)==1 ,
                    putativeNewValue=originalValue;
                else
                    rethrow(me)
                end
            end
            newValue=putativeNewValue;
            self.AreSoftpanelsEnabled_=newValue;
            if ~newValue ,
                % If softpanels were just disabled, make sure that the
                % gains and modes are up-to-date
                self.updateSmartElectrodeGainsAndModes();                
            end
            self.broadcast('Update');
        end  % function
        
%         function startIdleHeartbeatTimer(self)
%             start(self.IdleHeartbeatTimer_);            
%         end
%         
%         function stopIdleHeartbeatTimer(self)
%             stop(self.IdleHeartbeatTimer_);            
%         end
        
        function updateSmartElectrodeGainsAndModes(self)
            self.changeReadiness(-1);
            % Get the current mode and scaling from any smart electrodes
            smartElectrodeTypes=setdiff(ws.Electrode.Types,{'Manual'});
            for k=1:length(smartElectrodeTypes), 
                smartElectrodeType=smartElectrodeTypes{k};
                isThisType=self.isElectrodeOfType(smartElectrodeType);
                if any(isThisType) ,
                    indicesOfThisTypeOfElectrodes=find(isThisType);
                    thisTypeOfElectrodes=self.Electrodes(indicesOfThisTypeOfElectrodes);
                    indexWithinTypeOfTheseElectrodes=cellfun(@(electrode)(electrode.IndexWithinType) , ...
                                                           thisTypeOfElectrodes);
                    socketPropertyName=ws.ElectrodeManager.socketPropertyNameFromElectrodeType_(smartElectrodeType);                                         
                    %self.(socketPropertyName).open();
                    [overallError,perElectrodeErrors,modes,currentMonitorScalings,voltageMonitorScalings,currentCommandScalings,voltageCommandScalings,isCommandEnabled]= ...
                        self.(socketPropertyName).getModeAndGainsAndIsCommandEnabled(indexWithinTypeOfTheseElectrodes);
                    if isempty(overallError) ,
                        nElectrodesOfThisType=length(indicesOfThisTypeOfElectrodes);
                        for j=1:nElectrodesOfThisType ,
                            i=indicesOfThisTypeOfElectrodes(j);
                            electrode=self.Electrodes{i};
                            % Even if there's was an error on the electrode
                            % and no new info could be gathered, those ones
                            % should just be nan's or empty's, which
                            % setModeAndScalings() knows to ignore.
                            electrode.setModeAndScalings(modes{j}, ...
                                                         currentMonitorScalings(j), ...
                                                         voltageMonitorScalings(j), ...
                                                         currentCommandScalings(j), ...
                                                         voltageCommandScalings(j), ...
                                                         isCommandEnabled{j});
                            self.DidLastElectrodeUpdateWork_(i) = isempty(perElectrodeErrors{j});
                        end
                    else
                        self.DidLastElectrodeUpdateWork_(indicesOfThisTypeOfElectrodes) = false;
                    end
                end
            end
            self.changeReadiness(+1);
            self.broadcast('Update');            
        end  % function
        
        function reconnectWithSmartElectrodes(self)
            % Close and repoen the connection to any smart electrodes
            self.changeReadiness(-1);
            smartElectrodeTypes=setdiff(ws.Electrode.Types,{'Manual'});
            for k=1:length(smartElectrodeTypes), 
                smartElectrodeType=smartElectrodeTypes{k};
                isThisType=self.isElectrodeOfType(smartElectrodeType);
                if any(isThisType) ,
                    socketPropertyName=ws.ElectrodeManager.socketPropertyNameFromElectrodeType_(smartElectrodeType);
                    self.(socketPropertyName).reopen();
                end
            end
            self.changeReadiness(+1);
            self.broadcast('Update');
        end  % function
        
        function result=isElectrodeConnectionOpen(self)
            result=true(1,self.NElectrodes);  % dumb electrodes always have an open connection, by convention            
            smartElectrodeTypes=setdiff(ws.Electrode.Types,{'Manual'});
            for k=1:length(smartElectrodeTypes), 
                smartElectrodeType=smartElectrodeTypes{k};
                isThisType=self.isElectrodeOfType(smartElectrodeType);
                if any(isThisType) ,
                    socketPropertyName=ws.ElectrodeManager.socketPropertyNameFromElectrodeType_(smartElectrodeType);
                    result(isThisType)=self.(socketPropertyName).IsOpen();
                end
            end
        end  % function

        function result=isElectrodeIndexWithinTypeValid(self)
            % Heka doesn't provide an easy way to determine the number of
            % electrodes, so we just always say that a Heka index is valid.
            % Similarly for dumb electrodes.
            
            % populate array of number of electrodes of each type
            nElectrodesOfType=inf(1,self.NElectrodes);            
            electrodeTypesThatReportNumber=setdiff(ws.Electrode.Types,{'Manual' 'Heka EPC'});
            for k=1:length(electrodeTypesThatReportNumber), 
                electrodeType=electrodeTypesThatReportNumber{k};
                isThisType=self.isElectrodeOfType(electrodeType);
                if any(isThisType) ,
                    socketPropertyName=ws.ElectrodeManager.socketPropertyNameFromElectrodeType_(electrodeType);
                    nElectrodesOfThisType=self.(socketPropertyName).NElectrodes;
                    nElectrodesOfType(isThisType)=nElectrodesOfThisType;
                end
            end

            % Check that index of each is within range
            indexOfElectrodeWithinType=ones(1,self.NElectrodes);
            for i=1:self.NElectrodes ,                
                electrode=self.Electrodes{i};
                indexOfThisElectrodeWithinType=electrode.IndexWithinType;
                if ~isempty(indexOfThisElectrodeWithinType) ,
                    indexOfElectrodeWithinType(i)=indexOfThisElectrodeWithinType;
                end
            end
            result= (1<=indexOfElectrodeWithinType) & (indexOfElectrodeWithinType<=nElectrodesOfType) ;
        end  % function
        
%         function heartbeat(self,object,event)  %#ok<INUSD>
%             %fprintf('Beat!\n');
%             %state=self.State_
%             %object
%             %event
%             
%             % Get the current mode and scaling from any smart electrodes
%             self.updateSmartElectrodeGainsAndModes();
%         end  % function
%         
%         function heartbeatError(self,object,event)  %#ok<INUSD>
%             fprintf('A heartbeat error occurred!\n');
%             %self.State_
%         end  % function

        function debug(self) %#ok<MANU>
            keyboard
        end
    end  % methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyAttributes(self) %#ok<MANU>
%         end  % function
        
%         function defineDefaultPropertyTags(self)
% %             self.setPropertyTags('Electrodes', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('Electrodes_', 'IncludeInFileTypes', {'cfg'});
% %             self.setPropertyTags('Electrodes_', 'ExcludeFromFileTypes', {'usr','header'});            
% %             
% %             self.setPropertyTags('IsElectrodeMarkedForTestPulse', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('IsElectrodeMarkedForTestPulse_', 'IncludeInFileTypes', {'cfg'});
% %             self.setPropertyTags('IsElectrodeMarkedForTestPulse_', 'ExcludeFromFileTypes', {'usr','header'});            
% % 
% %             self.setPropertyTags('IsElectrodeMarkedForRemoval', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('IsElectrodeMarkedForRemoval_', 'IncludeInFileTypes', {'cfg'});
% %             self.setPropertyTags('IsElectrodeMarkedForRemoval_', 'ExcludeFromFileTypes', {'usr','header'});            
% %             
% %             self.setPropertyTags('LargestElectrodeIndexUsed_', 'IncludeInFileTypes', {'cfg'});
% %             self.setPropertyTags('LargestElectrodeIndexUsed_', 'ExcludeFromFileTypes', {'usr','header'});            
% % 
% %             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'*'});
% %             self.setPropertyTags('Parent_', 'ExcludeFromFileTypes', {'*'});
%             
%             % First: Exclude everything from all file types.
%             propertyNames=ws.most.util.findPropertiesSuchThat(self);
%             for i=1:length(propertyNames)
%                 propertyName=propertyNames{i};
%                 self.setPropertyTags(propertyName, 'ExcludeFromFileTypes', {'*'});
%             end
% 
%             % Put a few back, because we need them
%             propertyNamesForCfgFile= ...
%                 {'Electrodes' ...
%                  'IsElectrodeMarkedForTestPulse' ...
%                  'IsElectrodeMarkedForRemoval'};
%             for i=1:length(propertyNamesForCfgFile)
%                 propertyName=propertyNamesForCfgFile{i};
%                 self.setPropertyTags(propertyName, 'IncludeInFileTypes', {'cfg'});
%                 self.setPropertyTags(propertyName, 'ExcludeFromFileTypes', {'usr' 'header'});
%             end            
%             
%         end
%         
%         % Allows access to protected and protected variables from ws.mixin.Coding.
%         function out = getPropertyValue(self, name)
%             out = self.(name);
%         end
%         
%         % Allows access to protected and protected variables from ws.mixin.Coding.
%         function setPropertyValue(self, name, value)
%             if nargin < 3
%                 value = [];
%             end
%             self.(name) = value;
%             self.broadcast('Update');
%         end
    end  % protected methods block
        
    methods (Access=public)        
%         function doppelganger=clone(self)
%             % Make a clone of the ElectrodeManager.  This is another
%             % ElectrodeManager with the same settings.
%             import ws.*
%             s=self.encodeSettings();
%             doppelganger=ElectrodeManager();
%             doppelganger.restoreSettings(s);
%         end

%         function s=encodeSettings(self)
%             % Return a structure representing the current object settings.
%             s=struct();
%             nElectrodes=self.NElectrodes;
%             s.Electrodes=cell(1,nElectrodes);
%             for i=1:nElectrodes ,
%                 s.Electrodes{i}=self.Electrodes{i}.encodeSettings();
%             end
%             s.IsElectrodeMarkedForTestPulse=self.IsElectrodeMarkedForTestPulse;
%             s.IsElectrodeMarkedForRemoval=self.IsElectrodeMarkedForRemoval;            
%         end
%         
%         function restoreSettings(self, s)
%             % Note that this uses the high-level setters, so it will cause
%             % any subscribers to get (several) MayHaveChanged events.
%             nOldElectrodes=self.NElectrodes;
%             self.IsElectrodeMarkedForRemoval=true(1,nOldElectrodes);
%             self.removeMarkedElectrodes();            
%             nNewElectrodes=length(s.Electrodes);
%             for i=1:nNewElectrodes ,
%                 self.addNewElectrode();
%                 self.Electrodes{i}.restoreSettings(s.Electrodes{i});
%             end
%             self.IsElectrodeMarkedForTestPulse=s.IsElectrodeMarkedForTestPulse;
%             self.IsElectrodeMarkedForRemoval=s.IsElectrodeMarkedForRemoval;            
%         end
%         
%         function original=restoreSettingsAndReturnCopyOfOriginal(self, s)
%             original=self.clone();
%             self.restoreSettings(s);
%         end  % function
        
        function mimic(self, other)
            % Note that this uses the high-level setters, so it will cause
            % any subscribers to get (several) MayHaveChanged events.
            nOldElectrodes=self.NElectrodes;
            self.IsElectrodeMarkedForRemoval=true(1,nOldElectrodes);
            self.removeMarkedElectrodes();            
            nNewElectrodes=length(other.Electrodes);
            for i=1:nNewElectrodes ,
                self.addNewElectrode();
                self.Electrodes{i}.mimic(other.Electrodes{i});
            end
            self.IsElectrodeMarkedForTestPulse=other.IsElectrodeMarkedForTestPulse;
            self.IsElectrodeMarkedForRemoval=other.IsElectrodeMarkedForRemoval;            
            self.AreSoftpanelsEnabled = other.AreSoftpanelsEnabled;
            self.DidLastElectrodeUpdateWork_ = other.DidLastElectrodeUpdateWork ;

            % mimic the softpanel sockets
            self.EPCMasterSocket_.mimic(other.EPCMasterSocket_);
            self.MulticlampCommanderSocket_.mimic(other.MulticlampCommanderSocket_);
        end  % function
        
    end % methods
    
    methods
        function parameterName=parameterNameForSettingFromPropertyName(self,electrodeIndex,propertyName)
            % The "parameter" names used by the EPCMasterSocket are
            % slightly different from the property names of Electrode
            % properties.  This translates for the purposes of setting.
            
            import ws.utility.*

            electrode=self.Electrodes_{electrodeIndex};
            
            if isempty(strfind(propertyName,'Scaling')) ,
                parameterName=propertyName;
            else
                % "Scaling" should be the last thing
                head=propertyName(1:end-7);
                % The head can be "Command" or "Monitor",
                % optionally preceded by "Voltage" or "Current"
                if isempty(strfind(head,'Voltage')) && isempty(strfind(head,'Current')) ,
                    % If here, head is either 'Command' or 'Monitor'
                    fullHeadPrototype=electrode.whichCommandOrMonitor(head);
                else
                    fullHeadPrototype=head;
                end
                fullHead=fif(isequal(fullHeadPrototype,'CurrentMonitor'),'CurrentMonitorNominal',fullHeadPrototype);
                parameterName=[fullHead 'Gain'];                        
            end
        end  % function

        function parameterName=parameterNameForGettingFromPropertyName(self,electrodeIndex,propertyName)
            % The "parameter" names used by the EPCMasterSocket are
            % slightly different from the property names of Electrode
            % properties.  This translates for the purposes of getting.
            
            import ws.utility.*

            electrode=self.Electrodes_{electrodeIndex};
            
            if isempty(strfind(propertyName,'Scaling')) ,
                parameterName=propertyName;
            else
                % "Scaling" should be the last thing
                head=propertyName(1:end-7);
                % The head can be "Command" or "Monitor",
                % optionally preceded by "Voltage" or "Current"
                if isempty(strfind(head,'Voltage')) && isempty(strfind(head,'Current')) ,
                    % If here, head is either 'Command' or 'Monitor'
                    fullHeadPrototype=electrode.whichCommandOrMonitor(head);
                else
                    fullHeadPrototype=head;
                end
                fullHead=fif(isequal(fullHeadPrototype,'CurrentMonitor'),'CurrentMonitorRealized',fullHeadPrototype);
                parameterName=[fullHead 'Gain'];                        
            end
        end  % function
    end
    
    methods (Access=protected)        
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.Model(self);
            self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
        end
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.ElectrodeManager.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();
            
            s.Parent = struct('Classes', 'ws.system.Ephys', 'AllowEmpty', true);
            s.Electrodes = struct('Classes', 'cell', 'Attributes', {{'vector', 'row'}}, 'AllowEmpty', true);
            s.IsElectrodeMarkedForTestPulse = struct('Classes', 'logical', 'Attributes', {{'vector', 'row'}}, 'AllowEmpty', true);
            s.IsElectrodeMarkedForRemoval = struct('Classes', 'logical', 'Attributes', {{'vector', 'row'}}, 'AllowEmpty', true);
            s.AreSoftpanelsEnabled = struct('Classes', 'logical', 'Attributes', {{'scalar'}});
            s.IsInControlOfSoftpanelModeAndGains = struct('Classes', 'logical', 'Attributes', {{'scalar'}});
        end  % function
    end

    methods (Static, Access=protected)
        function socketPropertyName=socketPropertyNameFromElectrodeType_(electrodeType)
            if isequal(electrodeType,'Heka EPC') ,
                socketPropertyName='EPCMasterSocket_';
            elseif isequal(electrodeType,'Axon Multiclamp') ,
                socketPropertyName='MulticlampCommanderSocket_';
            elseif isequal(electrodeType,'Manual') ,
                error('wavesurfer:ElectrodeManager:manualElectrodeHasNoSocket', ...
                      'A manual electrode does not have a socket.');                
            else
                error('wavesurfer:ElectrodeManager:invalidElectrodeType', ...
                      'Invalid electrode type.');
            end
        end  % function        
    end  % class methods block
      
end  % classdef
