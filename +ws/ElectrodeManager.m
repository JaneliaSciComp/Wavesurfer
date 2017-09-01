classdef ElectrodeManager < ws.Model % & ws.Mimic  % & ws.EventBroadcaster (was before Mimic)
    
    properties (Dependent=true)
        %IsElectrodeMarkedForTestPulse  % provides public access to IsElectrodeMarkedForTestPulse_; settable as long as you don't change its shape
        %IsElectrodeMarkedForRemoval  % provides public access to IsElectrodeMarkedForRemoval_; settable as long as you don't change its shape
        AreSoftpanelsEnabled
        %IsInControlOfSoftpanelModeAndGains
        %DoTrodeUpdateBeforeRun
    end

    properties (Dependent=true, SetAccess=immutable)
        %TestPulseElectrodes  % the electrodes that are marked for test pulsing.
        %TestPulseElectrodeNames  % the names of the electrodes that are marked for test pulsing.
        %TestPulseElectrodesCount
        %Electrodes
        DidLastElectrodeUpdateWork
        IsDoTrodeUpdateBeforeRunSensible
    end

    % TODO: Consider getting rid of public Electrodes, TestPulseElectrodes
    % properties.  These return handle arrays, so they allow for direct
    % manipulation of Electrodes.  Might be a better design to require all
    % electrode changes to go through the ElectrodeManager, because in some
    % cases the ElectrodeManager has to make sure electrode changes get
    % propagated through the whole WavesurferModel, and get propagated to the
    % EPCMasterSocket in some cases.  This would be a good deal of work,
    % though.
    
    properties (Access = protected)
        Electrodes_ = cell(1,0);  % row vector of electrodes
        %IsElectrodeMarkedForTestPulse_ = true(1,0)  % boolean row vector, same length as Electrodes_
        IsElectrodeMarkedForRemoval_ = false(1,0)  % boolean row vector, same length as Electrodes_
        LargestElectrodeIndexUsed_ = -inf
        AreSoftpanelsEnabled_
        DidLastElectrodeUpdateWork_ = false(1,0)  % false iff an electrode is smart, and the last attempted update of its gains, etc. threw an error
        MulticlampCommanderSocket_  % A 'socket' for communicating with the Multiclamp Commander application (non-transient b/c electrode IDs are persisted)
        DoTrodeUpdateBeforeRunWhenSensible_
    end

    properties (Access = protected, Transient = true)
        EPCMasterSocket_  % A 'socket' for communicating with the EPCMaster application
    end

    events
        DidSetIsInputChannelActive
        DidSetIsDigitalOutputTimed
        DidChangeNumberOfInputChannels
        DidChangeNumberOfOutputChannels
    end
    
    methods
        function self = ElectrodeManager()
            % General initialization
            self@ws.Model();
            self.EPCMasterSocket_=ws.EPCMasterSocket();
            self.MulticlampCommanderSocket_=ws.MulticlampCommanderSocket();
            self.AreSoftpanelsEnabled_=true;

            % Create the heartbeat timer
%             self.IdleHeartbeatTimer_=timer('Name','EphysIdleHeartbeatTimer', ...
%                                            'ExecutionMode','fixedSpacing', ...
%                                            'Period',1, ...
%                                            'TimerFcn',@(object,event,varargin)(self.heartbeat(object,event)), ...
%                                            'ErrorFcn',@(object,event,varargin)(self.heartbeatError(object,event)));            
            
%             % Process args
%             validPropNames=ws.findPropertiesSuchThat(self,'SetAccess','public');
%             mandatoryPropNames=cell(1,0);
%             pvArgs = ws.filterPVArgs(varargin,validPropNames,mandatoryPropNames);
%             propNamesRaw = pvArgs(1:2:end);
%             propValsRaw = pvArgs(2:2:end);
%             nPVs=length(propValsRaw);  % Use the number of vals in case length(varargin) is odd
%             propNames=propNamesRaw(1:nPVs);
%             propVals=propValsRaw(1:nPVs);            
            
            self.DoTrodeUpdateBeforeRunWhenSensible_ = true;
            
%             % Set the properties
%             for idx = 1:nPVs
%                 self.(propNames{idx}) = propVals{idx};
%             end
        end
        
        function delete(self)  %#ok<INUSD>
            %self.IsInControlOfSoftpanelModeAndGains=false;
            %self.AreSoftpanelsEnabled_ = true ;
            %self.Parent = [];
            %self.Parent_ = [];  % eliminate reference to parent object (do I need this?)
        end
        
%         function do(self, methodName, varargin)
%             % This is intended to be the usual way of calling model
%             % methods.  For instance, a call to a ws.Controller
%             % controlActuated() method should generally result in a single
%             % call to .do() on it's model object, and zero direct calls to
%             % model methods.  This gives us a
%             % good way to implement functionality that is common to all
%             % model method calls, when they are called as the main "thing"
%             % the user wanted to accomplish.  For instance, we start
%             % warning logging near the beginning of the .do() method, and turn
%             % it off near the end.  That way we don't have to do it for
%             % each model method, and we only do it once per user command.            
%             root = self.Parent.Parent ;
%             root.startLoggingWarnings() ;
%             try
%                 self.(methodName)(varargin{:}) ;
%             catch exception
%                 % If there's a real exception, the warnings no longer
%                 % matter.  But we want to restore the model to the
%                 % non-logging state.
%                 root.stopLoggingWarnings() ;  % discard the result, which might contain warnings
%                 rethrow(exception) ;
%             end
%             warningExceptionMaybe = root.stopLoggingWarnings() ;
%             if ~isempty(warningExceptionMaybe) ,
%                 warningException = warningExceptionMaybe{1} ;
%                 throw(warningException) ;
%             end
%         end
        
        function result = getElectrodeCount(self)
            result = length(self.Electrodes_) ;
        end
        
%         function out = get.Electrodes(self)
%             out=self.Electrodes_;
%         end
        
%         function out = get.TestPulseElectrodes(self)
%             electrodes = self.Electrodes_ ;
%             out=electrodes(self.IsElectrodeMarkedForTestPulse_);
%         end
        
%         function result = get.TestPulseElectrodeNames(self)
%             result = cellfun(@(electrode)(electrode.Name), ...
%                              self.TestPulseElectrodes, ...
%                              'UniformOutput',false) ;
%         end
        
        function result = get.DidLastElectrodeUpdateWork(self)
            result = self.DidLastElectrodeUpdateWork_ ;
        end
        
        function out=getIsElectrodeMarkedForRemoval_(self)
            out=self.IsElectrodeMarkedForRemoval_;
        end

        function setIsElectrodeMarkedForRemoval_(self, newValue)
            % newValue must be same shape as old
            if all(size(newValue)==size(self.IsElectrodeMarkedForRemoval_)) ,
                self.IsElectrodeMarkedForRemoval_=newValue;
            end
            %self.broadcast('Update');
        end
        
%         function result = getIsElectrodeMarkedForTestPulse(self)
%             result = self.IsElectrodeMarkedForTestPulse_;
%         end
        
        function result = getIsElectrodeEligibleForTestPulse(self)
            result = true(size(self.Electrodes_)) ;
        end
        
%         function setIsElectrodeMarkedForTestPulse(self, newValue)
%             % newValue must be same shape as old
%             if all(size(newValue)==size(self.IsElectrodeMarkedForTestPulse_)) ,
%                 self.IsElectrodeMarkedForTestPulse_=newValue;
%             end
% %             if ~isempty(self.Parent_) ,
% %                 self.Parent_.isElectrodeMarkedForTestPulseMayHaveChanged();  % notify the parent, so can update ElectrodeManager
% %             end
%             self.broadcast('Update');
%         end
        
        function result = getDoTrodeUpdateBeforeRun_(self)
            if self.IsDoTrodeUpdateBeforeRunSensible
                result = self.DoTrodeUpdateBeforeRunWhenSensible_;
            else
                result = false;
            end
        end 
        
        function setDoTrodeUpdateBeforeRun_(self, newValue)
            if self.IsDoTrodeUpdateBeforeRunSensible ,
               self.DoTrodeUpdateBeforeRunWhenSensible_ = newValue; 
            else
                % Do nothing
            end
            self.broadcast('Update');
        end        
        
        function result = get.IsDoTrodeUpdateBeforeRunSensible(self)
           result = self.areAnyElectrodesAxon || ...
                    (self.areAnyElectrodesCommandable && ~self.getIsInControlOfSoftpanelModeAndGains_()) ;
        end
        
%         function out=get.Parent(self)
%             out=self.Parent_;
%         end
%         
%         function set.Parent(self,newValue)
%             if isempty(newValue) || isa(newValue,'ws.Ephys') ,
%                 self.Parent_=newValue;
%             end
%         end
        
        function result = get.AreSoftpanelsEnabled(self)
            result = self.AreSoftpanelsEnabled_ ;
        end

        function set.AreSoftpanelsEnabled(self, newValue)
            if islogical(newValue) && isscalar(newValue) ,
                self.AreSoftpanelsEnabled_=newValue;
            end
            self.broadcast('Update');            
        end
        
        function result = getIsInControlOfSoftpanelModeAndGains_(self)
            result = ~self.AreSoftpanelsEnabled_ ;
        end

        function result = getAllElectrodeNames(self)
            result = cellfun(@(electrode)(electrode.Name), self.Electrodes_, 'UniformOutput', false) ;
        end
        
        function electrodeIndex = addNewElectrode(self)
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
                %return
                self.broadcast('Update');
                error('ws:unableToAddElectrode', ...
                      'Unable to add a new electrode') ;
            end
            
            % At this point, name is a valid electrode name
            
            % Make an electrode
            electrode = ws.Electrode() ;
            electrode.setName_(name) ;
            
            % Add the electrode
            electrodeIndex = length(self.Electrodes_)+1 ;
            self.Electrodes_{electrodeIndex}=electrode;  
            %self.IsElectrodeMarkedForTestPulse_(electrodeIndex)=false;
            self.IsElectrodeMarkedForRemoval_(electrodeIndex)=false;
            self.DidLastElectrodeUpdateWork_(electrodeIndex)=true;  % true by convention
            
%             % Notify the parent Ephys object that an electrode has been added
%             ephys=self.Parent_;
%             if ~isempty(ephys) ,
%                 ephys.electrodeWasAdded(electrode);
%             end
            
            % Notify subscribers
            self.broadcast('Update');
        end
        
        function wasRemoved = removeMarkedElectrodes_(self)
            isToBeRemoved= self.IsElectrodeMarkedForRemoval_;
            % The constructions below (=[]) are better than the alternative
            % (where you define isToBeKept and do x=x(isToBeKept) b/c it
            % keeps row vectors row vectors, even when they are reduced to
            % zero length.
            self.Electrodes_(isToBeRemoved) = [] ;
            %self.IsElectrodeMarkedForTestPulse_(isToBeRemoved) = [] ;
            self.IsElectrodeMarkedForRemoval_(isToBeRemoved) = [] ;  % should be all false afterwards
            self.DidLastElectrodeUpdateWork_(isToBeRemoved) = [] ;
            
            % If the number of electrodes is down to zero, reset the
            % default electrode numbering
            if isempty(self.Electrodes_) ,
                self.LargestElectrodeIndexUsed_ = -inf;
            end
            
%             % Notify the parent Ephys object that an electrode has been
%             % removed
%             if ~isempty(self.Parent_)
%                 self.Parent_.electrodesRemoved();
%             end

            % Notify subscribers
            self.broadcast('Update');
            
            wasRemoved = isToBeRemoved ;
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
        
        function doNeedToUpdateGainsAndModes = setElectrodeType_(self, electrodeIndex, newValue)
            % Can only change the electrode type if softpanels are
            % enabled.  I.e. only when WS is *not* in command of the
            % gain settings.
            doNeedToUpdateGainsAndModes = false ;  % fallback return value
            %self.changeReadiness(-1);  % may have to establish contact with the softpanel, which can take a little while
            if self.AreSoftpanelsEnabled_ ,
                electrode=self.Electrodes_{electrodeIndex};
                originalType=electrode.Type;
                if ~isequal(newValue,originalType) ,
                    electrode.setProperty_('Type', newValue) ;
                    newType = electrode.Type ;  % if newValue was invalid, newType will be same as originalType
                    if ~isequal(newType,originalType) ,
                        isManualElectrode=isequal(newType,'Manual');
                        if isManualElectrode ,
                            self.DidLastElectrodeUpdateWork_(electrodeIndex)=true;
                        else
                            % need to do an update if smart electrode
                            %self.updateSmartElectrodeGainsAndModes();
                            doNeedToUpdateGainsAndModes = true ;
                        end
                    end                    
                end
            end
            %self.changeReadiness(+1);
            self.broadcast('Update');
        end  % function
        
        function doUpdateSmartElectrodeGainsAndModes = setElectrodeIndexWithinType_(self, electrodeIndex, newValue)
            % Can only change the electrode type if softpanels are
            % enabled.  I.e. only when WS is _not_ in command of the
            % gain settings
            doUpdateSmartElectrodeGainsAndModes = false ;  % default return
            if self.AreSoftpanelsEnabled_ ,
                electrode=self.Electrodes_{electrodeIndex};
                originalValue=electrode.IndexWithinType;
                if ~isequal(newValue,originalValue) ,
                    electrode.setProperty_('IndexWithinType', newValue) ;
                    checkValue = electrode.IndexWithinType ;  % if newValue was invalid, checkValue will be same as originalType
                    if ~isequal(checkValue,originalValue) ,
                        type=electrode.Type;
                        isManualElectrode=isequal(type,'Manual');
                        isSmartElectrode=~isManualElectrode;
                        if isSmartElectrode ,
                            doUpdateSmartElectrodeGainsAndModes = true ;
                        end
                    end                    
                end
            end
            self.broadcast('Update');
        end  % function

%         function setTestPulseElectrodeModeOrScaling(self,testPulseElectrodeIndex,propertyName,newValue)
%             % Like setElectrodeModeOrScaling(), but the given electrode
%             % index refers to the index within the test pulse electrodes
%             % only.
%             electrodeIndices=(1:self.NElectrodes);
%             testPulseElectrodeIndices=electrodeIndices(self.IsElectrodeMarkedForTestPulse_);
%             electrodeIndex=testPulseElectrodeIndices(testPulseElectrodeIndex);
%             self.setElectrodeModeOrScaling(electrodeIndex,propertyName,newValue);
%         end  % function

%         function result = electrodeIndexFromIndexWithinTestPulseElectrodes(self, indexWithinTestPulseElectrodes)
%             electrodeIndices = (1:self.getElectrodeCount()) ;
%             testPulseElectrodeIndices = electrodeIndices(self.IsElectrodeMarkedForTestPulse_) ;
%             result = testPulseElectrodeIndices(indexWithinTestPulseElectrodes) ;
%         end  % function
        
%         function result = indexWithinTestPulseElectrodesFromElectrodeIndex(self, electrodeIndex)
%             electrodeIndices = (1:self.getElectrodeCount()) ;
%             testPulseElectrodeIndices = electrodeIndices(self.IsElectrodeMarkedForTestPulse_) ;
%             result = find(testPulseElectrodeIndices==electrodeIndex, 1) ;
%         end  % function

%         function setElectrodeMonitorScaling(self, electrodeIndex, newValue)
%             electrode = self.Electrodes_{electrodeIndex} ;
%             if electrode.getIsInAVCMode() ,
%                 propertyName = 'CurrentMonitorScaling' ;
%             else
%                 propertyName = 'VoltageMonitorScaling' ;
%             end                
%             self.setElectrodeModeOrScaling_(electrodeIndex, propertyName, newValue) ;
%         end  % function
%         
%         function setElectrodeCommandScaling(self, electrodeIndex, newValue)
%             electrode = self.Electrodes_{electrodeIndex} ;
%             if electrode.getIsInAVCMode() ,
%                 propertyName = 'VoltageCommandScaling' ;
%             else
%                 propertyName = 'CurrentCommandScaling' ;
%             end                
%             self.setElectrodeModeOrScaling_(electrodeIndex, propertyName, newValue) ;
%         end  % function
        
        function setElectrodeModeOrScaling_(self, electrodeIndex, propertyName, newValue)
            electrode=self.Electrodes_{electrodeIndex};
            type=electrode.Type;
            isManualElectrode=isequal(type,'Manual');
            if isManualElectrode ,
                % just set it
                electrode.setProperty_(propertyName, newValue) ;
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
                        self.EPCMasterSocket_.setElectrodeParameter(indexWithinType,parameterNameForSetting,newValue);
                        % if we get here, no exception happened within
                        % EPCMasterSocket
                        newValueCheck=self.EPCMasterSocket_.getElectrodeParameter(indexWithinType,parameterNameForGetting);
                        electrode.setProperty_(propertyName, newValueCheck) ;  % set the value in the electrode proper
                        % For a Heka amp, setting the voltage command
                        % scaling can affect the external command
                        % enablement and vice-versa.  So update the
                        % other one in these cases.
                        if self.EPCMasterSocket_.IsOpen && self.EPCMasterSocket_.HasCommandOnOffSwitch ,
                            if isequal(parameterNameForSetting,'VoltageCommandGain') ,
                                otherPropertyName='IsCommandEnabled';
                                otherParameterNameForGetting=self.parameterNameForGettingFromPropertyName(electrodeIndex,otherPropertyName);
                                otherValue=self.EPCMasterSocket_.getElectrodeParameter(indexWithinType,otherParameterNameForGetting);
                                electrode.setProperty_(otherPropertyName, otherValue) ;  % set the value in the electrode proper
                            elseif isequal(parameterNameForSetting,'IsCommandEnabled') || isequal(parameterNameForSetting,'Mode') ,
                                otherPropertyName='VoltageCommandScaling';
                                otherParameterNameForGetting=self.parameterNameForGettingFromPropertyName(electrodeIndex,otherPropertyName);
                                otherValue=self.EPCMasterSocket_.getElectrodeParameter(indexWithinType,otherParameterNameForGetting);
                                electrode.setProperty_(otherPropertyName, otherValue) ;  % set the value in the electrode proper
                            end
                        end
                    else
                        % no other softpanel types are implemented                        
                    end
                end
            end                
        end  % function
        
%         function setElectrodeCommandChannelName(self, electrodeIndex, newValue)
%             electrode = self.Electrodes_{electrodeIndex} ;
%             electrode.CommandChannelName = newValue ;
%         end
%         
%         function setElectrodeMonitorChannelName(self, electrodeIndex, newValue)
%             electrode = self.Electrodes_{electrodeIndex} ;
%             electrode.MonitorChannelName = newValue ;
%         end
        
        function electrodeMayHaveChanged(self, electrode, propertyName)  %#ok<INUSD>
            % Called by the child electrodes when they may have changed.
            % Currently, broadcasts that self has changed, and notifies the
            % parent Ephys object.
            
%             % propagate the notifications up the chain of command
%             self.Parent_.electrodeMayHaveChanged(electrode,propertyName);
            
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

        function result = getElectrodeIndexByName(self, electrodeName)
            electrodeNames=cellfun(@(electrode)(electrode.Name),self.Electrodes_,'UniformOutput',false);
            isElectrode=strcmp(electrodeName,electrodeNames);
            result = find(isElectrode, 1) ;
        end  % function

%         function result = getElectrodePropertyByName(self, electrodeName, propertyName)
%             electrode = self.getElectrodeByName(electrodeName) ;
%             if isempty(electrode) ,
%                 error('ws:noSuchElectrode' , ...
%                       'No electrode by that name') ;
%             else
%                 result = electrode.(propertyName) ;
%             end
%         end  % function

        function result = getElectrodeProperty(self, electrodeIndex, propertyName)
            electrode = self.Electrodes_{electrodeIndex} ;
            result = electrode.(propertyName) ;
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
%             queryChannelUnits=repmat(ws.SIUnit(),[1 nQueryChannels]);
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
            nElectrodes=self.getElectrodeCount();
            nQueryChannels=length(queryChannelNames);
            isMatchBig=false(nElectrodes,nQueryChannels);
            for i=1:nElectrodes ,
                for j=1:nQueryChannels,
                    isMatchBig(i,j)=self.Electrodes_{i}.isNamedCommandChannelManaged(queryChannelNames{j});
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
        
        function [queryChannelUnits,isQueryChannelScaleManaged] = getCommandUnitsByName(self,queryChannelNames)
%             if ischar(queryChannelNamesRaw) ,
%                 queryChannelNames={queryChannelNamesRaw};
%             else
%                 queryChannelNames=queryChannelNamesRaw;
%             end
            isMatchBig = self.getMatrixOfMatchesToCommandChannelNames(queryChannelNames);  % nElectrodes x nQueryChannels
            isQueryChannelScaleManaged=(sum(isMatchBig,1)>=1);            
            nQueryChannels=length(queryChannelNames);
            queryChannelUnits=repmat({''},[1 nQueryChannels]);
            for i=1:nQueryChannels ,
                if isQueryChannelScaleManaged(i),
                    isRelevantElectrode=isMatchBig(:,i);
                    iRelevantElectrodes=find(isRelevantElectrode,1);
                    if isscalar(iRelevantElectrodes) ,
                        iElectrode=iRelevantElectrodes(1); 
                        electrode=self.Electrodes_{iElectrode};
                        queryChannelUnits{i}=electrode.getCommandUnitByName(queryChannelNames{i});
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
            isQueryChannelScaleManaged=(sum(isMatchBig,1)>=1);            
            nQueryChannels=length(queryChannelNames);
            queryChannelScales=ones(1,nQueryChannels);
            for i=1:nQueryChannels ,
                if isQueryChannelScaleManaged(i),
                    isRelevantElectrode=isMatchBig(:,i);
                    iRelevantElectrodes=find(isRelevantElectrode,1);
                    if isscalar(iRelevantElectrodes) ,
                        iElectrode=iRelevantElectrodes(1);  
                        electrode=self.Electrodes_{iElectrode};
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
            nElectrodes=self.getElectrodeCount();
            nQueryChannels=length(queryChannelNames);
            isMatchBig=false(nElectrodes,nQueryChannels);
            for i=1:nElectrodes ,
                electrode=self.Electrodes_{i};
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
            isQueryChannelScaleManaged=(sum(isMatchBig,1)>=1);            
            nQueryChannels=length(queryChannelNames);
            queryChannelUnits=repmat({''},[1 nQueryChannels]);
            for i=1:nQueryChannels ,
                if isQueryChannelScaleManaged(i),
                    isRelevantElectrode=isMatchBig(:,i);
                    iRelevantElectrodes=find(isRelevantElectrode,1);
                    if isscalar(iRelevantElectrodes) ,
                        iElectrode=iRelevantElectrodes(1);  
                        electrode=self.Electrodes_{iElectrode};
                        queryChannelUnits{i}=electrode.getMonitorUnitsByName(queryChannelNames{i});
                    else
                        % do nothing, thus falling back to empty string
                        % (which means dimensionless)
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
            isQueryChannelScaleManaged=(sum(isMatchBig,1)>=1);            
            nQueryChannels=length(queryChannelNames);
            queryChannelScales=ones(1,nQueryChannels);
            for i=1:nQueryChannels ,
                if isQueryChannelScaleManaged(i),
                    isRelevantElectrode=isMatchBig(:,i);
                    iRelevantElectrodes=find(isRelevantElectrode,1);
                    if isscalar(iRelevantElectrodes) ,
                        iElectrode=iRelevantElectrodes(1);  
                        electrode=self.Electrodes_{iElectrode};
                        queryChannelScales(i)=electrode.getMonitorScalingByName(queryChannelNames{i});
                    end                    
                end                    
            end
        end  % function        
        
%         function result = areAllCommandChannelNamesDistinct(self, testPulseElectrodeIndex)
%             allChannelNames=cellfun(@(electrode)(electrode.CommandChannelName), ...
%                                  self.Electrodes_ , ...
%                                  'UniformOutput',false);
%             channelNames=allChannelNames(testPulseElectrodeIndex);
%             uniqueChannelNames=unique(channelNames);
%             result=(length(channelNames)==length(uniqueChannelNames));
%         end  % function
        
%         function result = areAllMonitorChannelNamesDistinct(self, testPulseElectrodeIndex)
%             allChannelNames=cellfun(@(electrode)(electrode.MonitorChannelName), ...
%                                  self.Electrodes_ , ...
%                                  'UniformOutput',false);
%             channelNames=allChannelNames(testPulseElectrodeIndex);                             
%             uniqueChannelNames=unique(channelNames);
%             result=(length(channelNames)==length(uniqueChannelNames));
%         end  % function
        
%         function result = areAllMonitorAndCommandChannelNamesDistinct(self, testPulseElectrodeIndex)
%             result=self.areAllCommandChannelNamesDistinct(testPulseElectrodeIndex) && ...
%                    self.areAllMonitorChannelNamesDistinct(testPulseElectrodeIndex) ;
%         end  % function
        
        function result = areTestPulseElectrodeChannelsValid(self, aiChannelNames, aoChannelNames, testPulseElectrodeIndex)
            if isempty(testPulseElectrodeIndex) ,
                result = false ;
            else
                electrode =self.Electrodes_{testPulseElectrodeIndex} ;
                result = electrode.areChannelsValid(aiChannelNames, aoChannelNames) ;
            end
        end  % function
        
        function result = areAnyElectrodesSmart(self)
            isElectrodeManual=self.isElectrodeOfType('Manual');
            isElectrodeSmart=~isElectrodeManual;
            result=any(isElectrodeSmart);
        end  % function
        
        function result = areAnyElectrodesCommandable(self)
            isElectrodeCommandable=self.isElectrodeOfType('Heka EPC');
            result=any(isElectrodeCommandable);
        end  % function
        
        function result = areAnyElectrodesAxon(self)
            isElectrodeAxon=self.isElectrodeOfType('Axon Multiclamp');
            result=any(isElectrodeAxon);
        end
        
        function result = isElectrodeOfType(self, queryType)
            typePerElectrode=cellfun(@(electrode)(electrode.Type), ...
                                     self.Electrodes_, ...
                                     'UniformOutput',false);
            result=strcmp(queryType,typePerElectrode);
        end  % function
        
        function result = doesElectrodeHaveCommandOnOffSwitch(self)
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
        
        function doUpdateSmartElectrodeGainsAndModes = setIsInControlOfSoftpanelModeAndGains_(self, desiredNewValueOfIsInControlOfSoftpanelModeAndGains)
            if islogical(desiredNewValueOfIsInControlOfSoftpanelModeAndGains) && isscalar(desiredNewValueOfIsInControlOfSoftpanelModeAndGains) ,
                desiredNewValueOfAreSoftPanelsEnabled = ~desiredNewValueOfIsInControlOfSoftpanelModeAndGains ;
                %originalValue = self.AreSoftpanelsEnabled_ ;
                %desiredNewValue = ~originalValue ;
                try
                    self.EPCMasterSocket_.setUIEnablement(desiredNewValueOfAreSoftPanelsEnabled) ;
                catch me
                    % If the exception is an EPCMasterSocket-specific one, then
                    % we failed to set the mode
                    indicesThatMatch=strfind(me.identifier,'EPCMasterSocket:');                
                    if ~isempty(indicesThatMatch) && indicesThatMatch(1)==1 ,
                        desiredNewValueOfAreSoftPanelsEnabled = self.AreSoftpanelsEnabled_ ;
                    else
                        self.broadcast('Update') ;
                        rethrow(me) ;
                    end
                end
                newValueOfAreSoftPanelsEnabled = desiredNewValueOfAreSoftPanelsEnabled ;
                self.AreSoftpanelsEnabled_ = newValueOfAreSoftPanelsEnabled ;
                % If softpanels were just disabled, make sure that the
                % gains and modes are up-to-date
                doUpdateSmartElectrodeGainsAndModes = ~newValueOfAreSoftPanelsEnabled ;
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
        
%         function updateSmartElectrodeGainsAndModes(self)
%             self.changeReadiness(-1);
%             % Get the current mode and scaling from any smart electrodes
%             smartElectrodeTypes=setdiff(ws.Electrode.Types,{'Manual'});
%             for k=1:length(smartElectrodeTypes), 
%                 smartElectrodeType=smartElectrodeTypes{k};
%                 isThisType=self.isElectrodeOfType(smartElectrodeType);
%                 if any(isThisType) ,
%                     indicesOfThisTypeOfElectrodes=find(isThisType);
%                     thisTypeOfElectrodes=self.Electrodes_(indicesOfThisTypeOfElectrodes);
%                     indexWithinTypeOfTheseElectrodes=cellfun(@(electrode)(electrode.IndexWithinType) , ...
%                                                            thisTypeOfElectrodes);
%                     socketPropertyName=ws.ElectrodeManager.socketPropertyNameFromElectrodeType_(smartElectrodeType);                                         
%                     %self.(socketPropertyName).open();
%                     [overallError,perElectrodeErrors,modes,currentMonitorScalings,voltageMonitorScalings,currentCommandScalings,voltageCommandScalings, ...
%                      isCommandEnabled]= ...
%                         self.(socketPropertyName).getModeAndGainsAndIsCommandEnabled(indexWithinTypeOfTheseElectrodes);
%                     if isempty(overallError) ,
%                         nElectrodesOfThisType=length(indicesOfThisTypeOfElectrodes);
%                         for j=1:nElectrodesOfThisType ,
%                             i=indicesOfThisTypeOfElectrodes(j);
%                             electrode=self.Electrodes_{i};
%                             % Even if there's was an error on the electrode
%                             % and no new info could be gathered, those ones
%                             % should just be nan's or empty's, which
%                             % setModeAndScalings() knows to ignore.
%                             electrode.setModeAndScalings(modes{j}, ...
%                                                          currentMonitorScalings(j), ...
%                                                          voltageMonitorScalings(j), ...
%                                                          currentCommandScalings(j), ...
%                                                          voltageCommandScalings(j), ...
%                                                          isCommandEnabled{j});
%                             self.DidLastElectrodeUpdateWork_(i) = isempty(perElectrodeErrors{j});
%                         end
%                     else
%                         self.DidLastElectrodeUpdateWork_(indicesOfThisTypeOfElectrodes) = false;
%                     end
%                 end
%             end
%             self.changeReadiness(+1);
%             self.broadcast('Update');            
%         end  % function
        
        function reconnectWithSmartElectrodes_(self)
            % Close and repoen the connection to any smart electrodes
            %self.changeReadiness(-1);
            smartElectrodeTypes=setdiff(ws.Electrode.Types,{'Manual'});
            for k=1:length(smartElectrodeTypes), 
                smartElectrodeType=smartElectrodeTypes{k};
                isThisType=self.isElectrodeOfType(smartElectrodeType);
                if any(isThisType) ,
                    socketPropertyName=ws.ElectrodeManager.socketPropertyNameFromElectrodeType_(smartElectrodeType);
                    self.(socketPropertyName).reopen();
                end
            end
            %self.updateSmartElectrodeGainsAndModes() ;
            %self.changeReadiness(+1);
            %self.broadcast('Update');
        end  % function
        
        function result = isElectrodeConnectionOpen(self)
            result=true(1,self.getElectrodeCount());  % dumb electrodes always have an open connection, by convention            
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

        function result = isElectrodeIndexWithinTypeValid(self)
            % Heka doesn't provide an easy way to determine the number of
            % electrodes, so we just always say that a Heka index is valid.
            % Similarly for dumb electrodes.
            
            % populate array of number of electrodes of each type
            nElectrodesOfType=inf(1,self.getElectrodeCount());            
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
            indexOfElectrodeWithinType=ones(1,self.getElectrodeCount());
            for i=1:self.getElectrodeCount() ,                
                electrode=self.Electrodes_{i};
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

        function didSetIsInputChannelActive(self) 
            self.broadcast('DidSetIsInputChannelActive');
        end

        function didSetIsDigitalOutputTimed(self)
            self.broadcast('DidSetIsDigitalOutputTimed');
        end
        
        function didChangeNumberOfInputChannels(self)
            self.broadcast('DidChangeNumberOfInputChannels');
        end
        
        function didChangeNumberOfOutputChannels(self)
            self.broadcast('DidChangeNumberOfOutputChannels');
        end
        
        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue)
            if didSucceed ,
                for i=1:self.getElectrodeCount() ,                
                    electrode=self.Electrodes_{i};
                    electrode.didSetAnalogInputChannelName(oldValue, newValue) ;
                end            
            end
            self.broadcast('Update');
        end        
        
        function didSetAnalogOutputChannelName(self, didSucceed, oldValue, newValue)
            if didSucceed ,
                for i=1:self.getElectrodeCount() ,                
                    electrode=self.Electrodes_{i};
                    electrode.didSetAnalogOutputChannelName(oldValue, newValue) ;
                end            
            end
            self.broadcast('Update');
        end        
        
        function debug(self) %#ok<MANU>
            keyboard
        end
    end  % methods block
    
%     methods (Access = protected)
%         function updateSmartElectrodeGainsAndModes_(self)
%             self.changeReadiness(-1);
%             % Get the current mode and scaling from any smart electrodes
%             smartElectrodeTypes=setdiff(ws.Electrode.Types,{'Manual'});
%             for k=1:length(smartElectrodeTypes), 
%                 smartElectrodeType=smartElectrodeTypes{k};
%                 isThisType=self.isElectrodeOfType(smartElectrodeType);
%                 if any(isThisType) ,
%                     indicesOfThisTypeOfElectrodes=find(isThisType);
%                     thisTypeOfElectrodes=self.Electrodes_(indicesOfThisTypeOfElectrodes);
%                     indexWithinTypeOfTheseElectrodes=cellfun(@(electrode)(electrode.IndexWithinType) , ...
%                                                            thisTypeOfElectrodes);
%                     socketPropertyName=ws.ElectrodeManager.socketPropertyNameFromElectrodeType_(smartElectrodeType);                                         
%                     %self.(socketPropertyName).open();
%                     [overallError,perElectrodeErrors,modes,currentMonitorScalings,voltageMonitorScalings,currentCommandScalings,voltageCommandScalings,isCommandEnabled]= ...
%                         self.(socketPropertyName).getModeAndGainsAndIsCommandEnabled(indexWithinTypeOfTheseElectrodes);
%                     if isempty(overallError) ,
%                         nElectrodesOfThisType=length(indicesOfThisTypeOfElectrodes);
%                         for j=1:nElectrodesOfThisType ,
%                             i=indicesOfThisTypeOfElectrodes(j);
%                             electrode=self.Electrodes_{i};
%                             % Even if there's was an error on the electrode
%                             % and no new info could be gathered, those ones
%                             % should just be nan's or empty's, which
%                             % setModeAndScalings() knows to ignore.
%                             electrode.setModeAndScalings(modes{j}, ...
%                                                          currentMonitorScalings(j), ...
%                                                          voltageMonitorScalings(j), ...
%                                                          currentCommandScalings(j), ...
%                                                          voltageCommandScalings(j), ...
%                                                          isCommandEnabled{j});
%                             self.DidLastElectrodeUpdateWork_(i) = isempty(perElectrodeErrors{j});
%                         end
%                     else
%                         self.DidLastElectrodeUpdateWork_(indicesOfThisTypeOfElectrodes) = false;
%                     end
%                 end
%             end
%             self.changeReadiness(+1);
%             self.broadcast('Update');            
%         end  % function
%     end  % protected methods block
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end
        
        function setElectrodeName_(self, electrodeIndex, newValue)
            if ws.isString(newValue) && ~isempty(newValue) ,  
                electrodeNames = cellfun(@(electrode)(electrode.Name), ...
                                         self.Electrodes_, ...
                                         'UniformOutput',false) ;
                if ~ismember(newValue, electrodeNames) ,  % prevent name collisions
                    electrode = self.Electrodes_{electrodeIndex} ;
                    electrode.setProperty_('Name', newValue) ;
                end
            end
            %self.broadcast('Update') ;
        end                
    end  % protected methods block
        
    methods (Access=public)        
        function mimic(self, other)
            % Note that this uses the high-level setters, so it will cause
            % any subscribers to get (several) MayHaveChanged events.
            
            % Disable broadcasts for speed
            self.disableBroadcasts() ;

            % Mimic the trodes
            nNewElectrodes=length(other.Electrodes_) ;
            self.Electrodes_ = cell(1, nNewElectrodes) ;
            for i=1:nNewElectrodes ,
                self.Electrodes_{i} = ws.Electrode() ;
                self.Electrodes_{i}.mimic(other.Electrodes_{i}) ;
            end
            
            % Copy some fields
            %self.IsElectrodeMarkedForTestPulse_ = other.IsElectrodeMarkedForTestPulse_ ;
            self.IsElectrodeMarkedForRemoval_ = other.IsElectrodeMarkedForRemoval_ ;
            self.AreSoftpanelsEnabled_ = other.AreSoftpanelsEnabled_ ;
            self.DidLastElectrodeUpdateWork_ = other.DidLastElectrodeUpdateWork_ ;
            
            % mimic the softpanel sockets
            self.MulticlampCommanderSocket_.mimic(other.MulticlampCommanderSocket_) ;
%             self.EPCMasterSocket_.mimic(other.EPCMasterSocket_) ;  
%               % Doesn't actually do anything, and self.EPCMasterSocket_ is
%               % transient
            self.DoTrodeUpdateBeforeRunWhenSensible_ = other.DoTrodeUpdateBeforeRunWhenSensible_ ;

            % Re-enable broadcasts
            self.enableBroadcastsMaybe() ;
            
            % Broadcast update
            self.broadcast('Update') ;
        end  % function        
    end % methods
    
    methods
        function parameterName=parameterNameForSettingFromPropertyName(self,electrodeIndex,propertyName)
            % The "parameter" names used by the EPCMasterSocket are
            % slightly different from the property names of Electrode
            % properties.  This translates for the purposes of setting.
            
            %import ws.*

            electrode=self.Electrodes_{electrodeIndex};
            
            if ~ws.contains(propertyName,'Scaling') ,
                parameterName=propertyName;
            else
                % "Scaling" should be the last thing
                head=propertyName(1:end-7);
                % The head can be "Command" or "Monitor",
                % optionally preceded by "Voltage" or "Current"
                if ~ws.contains(head,'Voltage') && ~ws.contains(head,'Current') ,
                    % If here, head is either 'Command' or 'Monitor'
                    fullHeadPrototype=electrode.whichCommandOrMonitor(head);
                else
                    fullHeadPrototype=head;
                end
                fullHead=ws.fif(isequal(fullHeadPrototype,'CurrentMonitor'),'CurrentMonitorNominal',fullHeadPrototype);
                parameterName=[fullHead 'Gain'];                        
            end
        end  % function

        function parameterName=parameterNameForGettingFromPropertyName(self,electrodeIndex,propertyName)
            % The "parameter" names used by the EPCMasterSocket are
            % slightly different from the property names of Electrode
            % properties.  This translates for the purposes of getting.
            
            %import ws.*

            electrode=self.Electrodes_{electrodeIndex};
            
            if ~ws.contains(propertyName,'Scaling') ,
                parameterName=propertyName;
            else
                % "Scaling" should be the last thing
                head=propertyName(1:end-7);
                % The head can be "Command" or "Monitor",
                % optionally preceded by "Voltage" or "Current"
                if ~ws.contains(head,'Voltage') && ~ws.contains(head,'Current') ,
                    % If here, head is either 'Command' or 'Monitor'
                    fullHeadPrototype=electrode.whichCommandOrMonitor(head);
                else
                    fullHeadPrototype=head;
                end
                fullHead=ws.fif(isequal(fullHeadPrototype,'CurrentMonitor'),'CurrentMonitorRealized',fullHeadPrototype);
                parameterName=[fullHead 'Gain'];                        
            end
        end  % function
    end
    
%     methods (Access=protected)        
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.Model(self);
%             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
%         end
%     end
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = ws.ElectrodeManager.propertyAttributes();        
%         mdlHeaderExcludeProps = {};
%     end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
%             
%             s.Parent = struct('Classes', 'ws.Ephys', 'AllowEmpty', true);
%             s.Electrodes = struct('Classes', 'cell', 'Attributes', {{'vector', 'row'}}, 'AllowEmpty', true);
%             s.IsElectrodeMarkedForTestPulse = struct('Classes', 'logical', 'Attributes', {{'vector', 'row'}}, 'AllowEmpty', true);
%             s.IsElectrodeMarkedForRemoval = struct('Classes', 'logical', 'Attributes', {{'vector', 'row'}}, 'AllowEmpty', true);
%             s.AreSoftpanelsEnabled = struct('Classes', 'logical', 'Attributes', {{'scalar'}});
%             s.IsInControlOfSoftpanelModeAndGains = struct('Classes', 'logical', 'Attributes', {{'scalar'}});
%         end  % function
%     end

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
      
    methods
%         function result=get.TestPulseElectrodesCount(self)
%             result=sum(self.IsElectrodeMarkedForTestPulse_) ;
%         end
        
%         function electrode = getElectrodeByIndex_(self, electrodeIndex)
%             electrode = self.Electrodes_{electrodeIndex} ;
%         end    
        
%         function result = getTestPulseElectrodes_(self)
%             % Moving forwards, it would be better if (trusted) consumers called this to
%             % get the test pulse electrodes
%             result = self.TestPulseElectrodes ;
%         end    
        
        function setElectrodeProperty_(self, electrodeIndex, propertyName, newValue)            
            switch propertyName ,
                case 'Name' ,
                    self.setElectrodeName_(electrodeIndex, newValue) ,
                case 'MonitorScaling' ,
                    electrode = self.Electrodes_{electrodeIndex} ;
                    if electrode.IsInAVCMode ,
                        propertyName = 'CurrentMonitorScaling' ;
                    else
                        propertyName = 'VoltageMonitorScaling' ;
                    end                
                    self.setElectrodeModeOrScaling_(electrodeIndex, propertyName, newValue) ;                
                case 'CommandScaling' ,
                    electrode = self.Electrodes_{electrodeIndex} ;
                    if electrode.IsInAVCMode ,
                        propertyName = 'VoltageCommandScaling' ;
                    else
                        propertyName = 'CurrentCommandScaling' ;
                    end                
                    self.setElectrodeModeOrScaling_(electrodeIndex, propertyName, newValue) ;
                case {'Mode' 'IsCommandEnabled' 'CurrentMonitorScaling' 'VoltageMonitorScaling' 'VoltageCommandScaling' 'CurrentCommandScaling'} ,
                    self.setElectrodeModeOrScaling_(electrodeIndex, propertyName, newValue) ;                    
                otherwise ,
                    electrode = self.Electrodes_{electrodeIndex} ;
                    electrode.setProperty_(propertyName, newValue) ;
            end
            self.broadcast('Update');
        end        
        
        function setElectrodeModeAndScalings_(self,...
                                              electrodeIndex, ...
                                              newMode, ...
                                              newCurrentMonitorScaling, ...
                                              newVoltageMonitorScaling, ...
                                              newCurrentCommandScaling, ...
                                              newVoltageCommandScaling,...
                                              newIsCommandEnabled)
            electrode = self.Electrodes_{electrodeIndex} ;
            electrode.setModeAndScalings_(newMode, ...
                                          newCurrentMonitorScaling, ...
                                          newVoltageMonitorScaling, ...
                                          newCurrentCommandScaling, ...
                                          newVoltageCommandScaling,...
                                          newIsCommandEnabled) ;
            self.broadcast('Update');
        end  % function

        function [areAnyOfThisType, ...
                  indicesOfThisTypeOfElectrodes, ...
                  overallError, ...
                  modes, ...
                  currentMonitorScalings, voltageMonitorScalings, currentCommandScalings, voltageCommandScalings, ...
                  isCommandEnabled] = ...
                 probeHardwareForSmartElectrodeModesAndScalings_(self, smartElectrodeType)
            isThisType = self.isElectrodeOfType(smartElectrodeType) ;
            areAnyOfThisType = any(isThisType) ;
            if areAnyOfThisType ,
                indicesOfThisTypeOfElectrodes = find(isThisType) ;
                thisTypeOfElectrodes = self.Electrodes_(isThisType) ;
                indexWithinTypeOfTheseElectrodes = cellfun(@(electrode)(electrode.IndexWithinType) , ...
                                                           thisTypeOfElectrodes) ;
                socketPropertyName = ws.ElectrodeManager.socketPropertyNameFromElectrodeType_(smartElectrodeType) ; 
                [overallError,perElectrodeErrors,modes,currentMonitorScalings,voltageMonitorScalings,currentCommandScalings,voltageCommandScalings,...
                 isCommandEnabled] = ...
                    self.(socketPropertyName).getModeAndGainsAndIsCommandEnabled(indexWithinTypeOfTheseElectrodes) ;

                % Update self.DidLastElectrodeUpdateWork_
                if isempty(overallError) ,
                    nElectrodesOfThisType = length(indicesOfThisTypeOfElectrodes) ;
                    for j = 1:nElectrodesOfThisType ,
                        electrodeIndex = indicesOfThisTypeOfElectrodes(j) ;
                        self.DidLastElectrodeUpdateWork_(electrodeIndex) = isempty(perElectrodeErrors{j}) ;
                    end
                else
                    self.DidLastElectrodeUpdateWork_(indicesOfThisTypeOfElectrodes) = false ;
                end
            else
                % These are not relevant if areAnyOfThisType is false
                indicesOfThisTypeOfElectrodes = [] ;
                overallError = [] ;
                %perElectrodeErrors = [] ;
                modes = [] ;
                currentMonitorScalings = [] ;
                voltageMonitorScalings = [] ;
                currentCommandScalings = [] ;                
                voltageCommandScalings = [] ;                
                isCommandEnabled = [] ;                
            end
        end  % function
        
    end        
end  % classdef
