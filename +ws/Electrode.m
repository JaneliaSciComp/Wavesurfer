classdef Electrode < ws.Model % & ws.Mimic 
    
    properties (Constant=true)
        Types = {'Manual' 'Axon Multiclamp' 'Heka EPC' };  % first one is the default amplifier type
    end

    properties (Dependent=true)
        Name
        VoltageMonitorChannelName
        CurrentMonitorChannelName
        VoltageCommandChannelName
        CurrentCommandChannelName
        Mode  % 'vc' or 'cc'
        TestPulseAmplitudeInVC
        TestPulseAmplitudeInCC
        VoltageCommandScaling  % scalar, typically in mV/V
        CurrentMonitorScaling  % scalar, typically in V/pA
        CurrentCommandScaling  % scalar, tpyically in pA/V
        VoltageMonitorScaling  % scalar, typically in V/mV
        VoltageUnits
        CurrentUnits
        Type
        IndexWithinType
        IsCommandEnabled       
        
        TestPulseAmplitude  % for whichever is the current mode
        CommandChannelName
        MonitorChannelName
        CommandScaling
        MonitorScaling
        AllowedModes
        IsInACCMode
        IsInAVCMode
    end
    
    properties (Dependent=true, SetAccess=immutable)  % Hidden so not calc'ed on call to disp()
        CommandUnits
        MonitorUnits
    end
    
    properties (Access=protected)
        Name_
        VoltageMonitorChannelName_
        CurrentMonitorChannelName_
        VoltageCommandChannelName_
        CurrentCommandChannelName_
        Mode_  % 'vc' or 'cc'
        TestPulseAmplitudeInVC_
        TestPulseAmplitudeInCC_
        VoltageCommandScaling_
        CurrentMonitorScaling_
        CurrentCommandScaling_
        VoltageMonitorScaling_
        VoltageUnits_  % constant for now, may change in future
        CurrentUnits_  % constant for now, may change in future
        TypeIndex_  % the index of the type within Types
        IndexWithinType_
        IsCommandEnabled_
    end
    
    methods        
        function self=Electrode()
            % Set the defaults
            self@ws.Model();
            self.Name_ = '' ;
            self.VoltageMonitorChannelName_ = '';
            self.CurrentMonitorChannelName_ = '';
            self.VoltageCommandChannelName_ = '';
            self.CurrentCommandChannelName_ = '';
            self.Mode_ = 'vc';  % 'vc' or 'cc'
            self.TestPulseAmplitudeInVC_ = 10 ;
            self.TestPulseAmplitudeInCC_ = 10 ;
            self.VoltageCommandScaling_ = 10;  % mV/V
            self.CurrentMonitorScaling_ = 0.01;  % V/pA
            self.CurrentCommandScaling_ = 100;  % pA/V
            self.VoltageMonitorScaling_ = 0.01;  % V/mV
            self.VoltageUnits_ = 'mV' ;  % constant for now, may change in future
            self.CurrentUnits_ = 'pA' ;  % constant for now, may change in future
            self.TypeIndex_ = 1;  % default amplifier type
            self.IndexWithinType_=[];  % e.g. 2 means this is the second electrode of the current type
            self.setIsCommandEnabled_(true) ;
            
%             % Process args
%             validPropNames=ws.findPropertiesSuchThat(self,'SetAccess','public');
%             mandatoryPropNames=cell(1,0);
%             pvArgs = ws.filterPVArgs(varargin,validPropNames,mandatoryPropNames);
%             propNamesRaw = pvArgs(1:2:end);
%             propValsRaw = pvArgs(2:2:end);
%             nPVs=length(propValsRaw);  % Use the number of vals in case length(varargin) is odd
%             propNames=propNamesRaw(1:nPVs);
%             propVals=propValsRaw(1:nPVs);            
            
%             % Set the properties
%             for idx = 1:nPVs
%                 self.(propNames{idx}) = propVals{idx};
%             end
            
            % % Notify other parts of the model
            % self.mayHaveChanged();
        end  % function
        
%         function result = get.Parent(self)
%             result=self.Parent_;
%         end  % function
        
        function result = get.Name(self)
            result=self.Name_;
        end  % function
        
        function result = get.VoltageMonitorChannelName(self)
            result=self.VoltageMonitorChannelName_;
        end  % function
        
        function result = get.CurrentMonitorChannelName(self)
            result=self.CurrentMonitorChannelName_;
        end  % function
        
        function result = get.VoltageCommandChannelName(self)
            result=self.VoltageCommandChannelName_;
        end  % function
        
        function result = get.CurrentCommandChannelName(self)
            result=self.CurrentCommandChannelName_;
        end  % function
        
        function result = get.Mode(self)
            result=self.Mode_;
        end  % function

        function setName_(self, newValue)
            if ws.isString(newValue) ,
                self.Name_ = newValue ;
            end
            %self.mayHaveChanged('Name');
        end  % function
        
        function setVoltageMonitorChannelName_(self, newValue)
            if ~ws.isString(newValue)
                return
            end
            self.VoltageMonitorChannelName_=newValue;
            %self.mayHaveChanged('VoltageMonitorChannelName');
        end  % function
        
        function setVoltageCommandChannelName_(self,newValue)
            if ws.isString(newValue)
                self.VoltageCommandChannelName_=newValue;
            end
            %self.mayHaveChanged('VoltageCommandChannelName');
        end  % function

        function setCurrentMonitorChannelName_(self,newValue)
            if ws.isString(newValue)
                self.CurrentMonitorChannelName_=newValue;
            end
            %self.mayHaveChanged('CurrentMonitorChannelName');
        end  % function
        
        function setCurrentCommandChannelName_(self,newValue)
            if ws.isString(newValue)
                self.CurrentCommandChannelName_=newValue;
            end
            %self.mayHaveChanged('CurrentCommandChannelName');
        end  % function
        
        function didSetAnalogInputChannelName(self, oldValue, newValue)
            if isequal(self.VoltageMonitorChannelName, oldValue) ,
                self.VoltageMonitorChannelName_ = newValue ;
            end
            % Can't do elseif b/c might be equal to both
            if isequal(self.CurrentMonitorChannelName, oldValue) ,
                self.CurrentMonitorChannelName_ =  newValue ;
            end
        end        
        
        function didSetAnalogOutputChannelName(self, oldValue, newValue)
            if isequal(self.VoltageCommandChannelName, oldValue) ,
                self.VoltageCommandChannelName_ = newValue ;
            end
            % Can't do elseif b/c might be equal to both
            if isequal(self.CurrentCommandChannelName, oldValue) ,
                self.CurrentCommandChannelName_ =  newValue ;
            end
        end        
                
        function result = get.CommandChannelName(self)
            if isequal(self.Mode,'vc') ,
                result = self.VoltageCommandChannelName;
            else
                result = self.CurrentCommandChannelName;
            end
        end  % function
        
        function setCommandChannelName_(self,newValue)
            if isequal(self.Mode,'vc') ,
                self.setVoltageCommandChannelName_(newValue) ;
            else
                self.setCurrentCommandChannelName_(newValue) ;
            end
            %self.mayHaveChanged();
        end  % function
        
        function result = get.MonitorChannelName(self)
            if isequal(self.Mode,'vc') ,
                result = self.CurrentMonitorChannelName;
            else
                result = self.VoltageMonitorChannelName;
            end
        end  % function
        
        function setMonitorChannelName_(self,newValue)
            if isequal(self.Mode,'vc') ,
                self.setCurrentMonitorChannelName_(newValue) ;
            else
                self.setVoltageMonitorChannelName_(newValue) ;
            end
            %self.mayHaveChanged();
        end  % function
        
        function result = get.VoltageUnits(self)
            result = self.VoltageUnits_;
        end  % function

        function result = get.CurrentUnits(self)
            result = self.CurrentUnits_;
        end  % function

        function result = get.CommandUnits(self) 
            if isequal(self.Mode,'vc') ,
                result = self.VoltageUnits;
            else
                result = self.CurrentUnits;
            end
        end  % function
        
        function result = get.MonitorUnits(self)
            if isequal(self.Mode,'vc') ,
                result = self.CurrentUnits;
            else
                result = self.VoltageUnits;
            end
        end
        
        function result = get.CommandScaling(self)
            if isequal(self.Mode,'vc') ,
                result = self.VoltageCommandScaling;
            else
                result = self.CurrentCommandScaling;
            end
        end
        
        function setCommandScaling_(self, newValue)
            if isequal(self.Mode,'vc') ,
                self.setVoltageCommandScaling_(newValue) ;
            else
                self.setCurrentCommandScaling_(newValue) ;
            end
        end
        
        function result = get.MonitorScaling(self)
            if isequal(self.Mode,'vc') ,
                result = self.CurrentMonitorScaling;
            else
                result = self.VoltageMonitorScaling;
            end
        end
        
        function setMonitorScaling_(self, newValue)
            if isequal(self.Mode,'vc') ,
                self.setCurrentMonitorScaling_(newValue) ;
            else
                self.setVoltageMonitorScaling_(newValue) ;
            end
        end

%         function setCurrentMonitorScaling_(self, newValue)
%             % Want subclasses to be able to override, so we indirect
%             self.setCurrentMonitorScaling_(newValue);
%         end
%         
%         function set.VoltageMonitorScaling(self, newValue)
%             % Want subclasses to be able to override, so we indirect
%             self.setVoltageMonitorScaling_(newValue);
%         end
%         
%         function set.CurrentCommandScaling(self, newValue)
%             % Want subclasses to be able to override, so we indirect
%             self.setCurrentCommandScaling_(newValue);
%         end
%         
%         function set.VoltageCommandScaling(self, newValue)
%             % Want subclasses to be able to override, so we indirect
%             self.setVoltageCommandScaling_(newValue);
%         end
        
%         function set.IsCommandEnabled(self, newValue)
%             % Want subclasses to be able to override, so we indirect
%             self.setIsCommandEnabled_(newValue);
%         end
        
        function result = get.VoltageCommandScaling(self)
%             electrodeManager=self.Parent_;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             result=wavesurferModel.Stimulus.channelScaleFromName(channelName);
            result=self.VoltageCommandScaling_;
        end
        
        function result = get.CurrentCommandScaling(self)
%             channelName=self.CurrentCommandChannelName;
%             electrodeManager=self.Parent_;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             result=wavesurferModel.Stimulus.channelScaleFromName(channelName);
            result=self.CurrentCommandScaling_;
        end
        
        function result = get.VoltageMonitorScaling(self)
%             channelName=self.VoltageMonitorChannelName;
%             electrodeManager=self.Parent_;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             result=wavesurferModel.Acquisition.channelScaleFromName(channelName);
            result=self.VoltageMonitorScaling_;
        end
        
        function result = get.CurrentMonitorScaling(self)
%             channelName=self.CurrentMonitorChannelName;
%             electrodeManager=self.Parent_;
%             ephys=electrodeManager.Parent;
%             wavesurferModel=ephys.Parent;
%             result=wavesurferModel.Acquisition.channelScaleFromName(channelName);
            result=self.CurrentMonitorScaling_;
        end
        
        function result = get.IsCommandEnabled(self)
            if isequal(self.Type,'Manual') ,
                result=true;
            else
                result = self.IsCommandEnabled_;
            end
        end
        
        function result = get.TestPulseAmplitudeInVC(self)
            result=self.TestPulseAmplitudeInVC_;
        end
        
        function result = get.TestPulseAmplitudeInCC(self)
            result=self.TestPulseAmplitudeInCC_;
        end
        
        function setTestPulseAmplitudeInVC_(self, newValue)
            if ws.isString(newValue) ,
                newValueAsDouble = str2double(newValue) ;
            elseif isnumeric(newValue) && isscalar(newValue) ,
                newValueAsDouble = double(newValue) ;
            else
                newValueAsDouble = nan ;  % isfinite(nan) is false
            end            
            self.TestPulseAmplitudeInVC_= newValueAsDouble;
            %self.mayHaveChanged('TestPulseAmplitudeInVC');
        end
        
        function setTestPulseAmplitudeInCC_(self, newValue)
            if ws.isString(newValue) ,
                newValueAsDouble = str2double(newValue) ;
            elseif isnumeric(newValue) && isscalar(newValue) ,
                newValueAsDouble = double(newValue) ;
            else
                newValueAsDouble = nan ;  % isfinite(nan) is false
            end            
            self.TestPulseAmplitudeInCC_= double(newValueAsDouble);
            %self.mayHaveChanged('TestPulseAmplitudeInCC');
        end  % function
        
        function result = get.TestPulseAmplitude(self)
            if isequal(self.Mode,'cc')
                result=self.TestPulseAmplitudeInCC;
            else
                result=self.TestPulseAmplitudeInVC;
            end
        end  % function
        
        function setTestPulseAmplitude_(self,newValue)
            if isequal(self.Mode,'cc')
                self.setTestPulseAmplitudeInCC_(newValue) ;
            else
                self.setTestPulseAmplitudeInVC_(newValue) ;
            end
        end  % function
        
        function result = areChannelsValid(self, aiChannelNames, aoChannelNames)
            % In order for this method to return true, the command and monitor
            % channel names for the current mode have to refer to valid
            % active channels.
            
            % If either the command or monitor channel is unspecified,
            % return false
            commandChannelName=self.CommandChannelName;
            if isempty(commandChannelName) ,
                result = false ;            
            else
                monitorChannelName=self.MonitorChannelName;
                if isempty(monitorChannelName) ,
                    result = false ;            
                else
                    % The typical case
                    result = any(strcmp(commandChannelName, aoChannelNames)) && ...
                             any(strcmp(monitorChannelName, aiChannelNames));
                       % this will be false if either aiChannelNames or
                       % aoChannelNames is empty
                end
            end
        end  % function
        
        function mimic(self, other)
            self.Name_=other.Name;
            self.IndexWithinType_=other.IndexWithinType;
            self.Mode_=other.Mode;
            self.VoltageCommandChannelName_=other.VoltageCommandChannelName;
            self.CurrentMonitorChannelName_=other.CurrentMonitorChannelName;
            self.CurrentCommandChannelName_=other.CurrentCommandChannelName;
            self.VoltageMonitorChannelName_=other.VoltageMonitorChannelName;
            self.TestPulseAmplitudeInVC_=other.TestPulseAmplitudeInVC;
            self.TestPulseAmplitudeInCC_=other.TestPulseAmplitudeInCC;
            self.VoltageCommandScaling_=other.VoltageCommandScaling;
            self.CurrentMonitorScaling_=other.CurrentMonitorScaling;
            self.CurrentCommandScaling_=other.CurrentCommandScaling;
            self.VoltageMonitorScaling_=other.VoltageMonitorScaling;
            self.IsCommandEnabled_=other.IsCommandEnabled;
            self.setType_(other.Type);
            %self.mayHaveChanged();  % Want to call it once, argument doesn't matter
        end  % function

%         function set.Type(self,newValue)
%             isMatch=strcmp(newValue,self.Types);
%             newTypeIndex=find(isMatch,1);
%             if ~isempty(newTypeIndex) ,
%                 % Some trode types can't do 'i_equals_zero' mode, so check for that
%                 % and change to 'cc' if needed
%                 newType=self.Types{newTypeIndex};
%                 mode=self.Mode;
%                 if ~ws.Electrode.isModeAllowedForType(mode,newType) ,
%                     newMode = ws.Electrode.findClosestAllowedModeForType(mode,newType) ;
%                     self.Mode = newMode;
%                 end                
%                 % Actually change the type index
%                 self.TypeIndex_=newTypeIndex;
%                 % Set IndexWithinType_ as needed
%                 if isequal(newValue,'Manual') ,
%                     self.IndexWithinType_=[];
%                 else
%                     if isempty(self.IndexWithinType_) ,
%                         self.IndexWithinType_=1;
%                     end
%                 end
%             end                       
%             self.mayHaveChanged('Type');
%         end  % function
        
        function value=get.Type(self)
            value=self.Types{self.TypeIndex_};
        end  % function
        
        function setIndexWithinType_(self,newValue)
            if isnumeric(newValue) && isscalar(newValue) && round(newValue)==newValue && newValue>0 && ~isequal(self.Type,'Manual') ,
                self.IndexWithinType_=newValue;
            end            
            %self.mayHaveChanged('IndexWithinType');
        end  % function
        
        function value=get.IndexWithinType(self)
            value=self.IndexWithinType_;
        end  % function
        
        function setModeAndScalings_(self,...
                                     newMode, ...
                                     newCurrentMonitorScaling, ...
                                     newVoltageMonitorScaling, ...
                                     newCurrentCommandScaling, ...
                                     newVoltageCommandScaling,...
                                     newIsCommandEnabled)
            self.setMode_(newMode);
            self.setCurrentMonitorScaling_(newCurrentMonitorScaling);
            self.setVoltageMonitorScaling_(newVoltageMonitorScaling);
            self.setCurrentCommandScaling_(newCurrentCommandScaling);
            self.setIsCommandEnabled_(newIsCommandEnabled);
            self.setVoltageCommandScaling_(newVoltageCommandScaling);            
        end  % function
        
        function result=whichCommandOrMonitor(self, commandOrMonitor)
            % commandOrMonitor should be either 'Command' or 'Monitor'.
            % If commandOrMonitor is 'Monitor', and the current electrode
            % is 'vc', then the result is 'CurrentMonitor', for example.
            mode=self.Mode;
            if isequal(mode,'cc') ,
                if isequal(commandOrMonitor,'Command') ,                                    
                    result='CurrentCommand';
                else
                    result='VoltageMonitor';
                end                                    
            else
                if isequal(commandOrMonitor,'Command') ,                                    
                    result='VoltageCommand';
                else
                    result='CurrentMonitorRealized';
                end                                    
            end            
        end  % function
        
        function result = isNamedMonitorChannelManaged(self,channelName)
            if isempty(channelName)
                result=false;
            else
                managedChannelNames=[{self.CurrentMonitorChannelName_} ...
                                     {self.VoltageMonitorChannelName_}];
                result=any(strcmp(channelName,managedChannelNames));
            end
        end
        
        function result = isNamedCommandChannelManaged(self,channelName)
            if isempty(channelName)
                result=false;
            else
                managedChannelNames=[{self.CurrentCommandChannelName_} ...
                                     {self.VoltageCommandChannelName_}];
                result=any(strcmp(channelName,managedChannelNames)); 
            end
        end
        
        function result=getMonitorScalingByName(self,channelName)
            % Get the scaling for the named monitor channel dictated by
            % this electrode.  If the named channel is both the current and
            % voltage monitor name, use the mode to break the tie.
            managedChannelNames=[{self.CurrentMonitorChannelName_} ...
                                 {self.VoltageMonitorChannelName_}];
            isMatch=strcmp(channelName,managedChannelNames);
            scales=[self.CurrentMonitorScaling_ ...
                    self.VoltageMonitorScaling_];
            matchingScales=scales(isMatch);
            if length(matchingScales)>1 ,
                if isequal(self.Mode_,'vc') ,
                    result=matchingScales(1);
                else
                    result=matchingScales(2);
                end
            else
                result=matchingScales;
            end
        end
        
        function result=getCommandScalingByName(self,channelName)
            % Get the scaling for the named command channel dictated by
            % this electrode.  If the named channel is both the current and
            % voltage command name, use the mode to break the tie.
            managedChannelNames=[{self.CurrentCommandChannelName_} ...
                                 {self.VoltageCommandChannelName_}];
            isMatch=strcmp(channelName,managedChannelNames);
            scales=[self.CurrentCommandScaling_ ...
                    self.VoltageCommandScaling_];
            matchingScales=scales(isMatch);
            if length(matchingScales)>1 ,
                if isequal(self.Mode_,'vc') ,
                    result=matchingScales(2);
                else
                    result=matchingScales(1);
                end
            else
                result=matchingScales;
            end
        end
        
        function result=getMonitorUnitsByName(self,channelName)
            % Get the scaling for the named monitor channel dictated by
            % this electrode.  If the named channel is both the current and
            % voltage monitor name, use the mode to break the tie.
            managedChannelNames=[{self.CurrentMonitorChannelName_} ...
                                 {self.VoltageMonitorChannelName_}];
            isMatch=strcmp(channelName,managedChannelNames);
            units={self.CurrentUnits_ ...
                   self.VoltageUnits_};
            matchingUnits=units(isMatch);
            if length(matchingUnits)>1 ,
                if isequal(self.Mode_,'vc') ,
                    result=matchingUnits{1};
                else
                    result=matchingUnits{2};
                end
            else
                result=matchingUnits{1};
            end
        end
        
        function result = getCommandUnitByName(self,channelName)
            % Get the scaling for the named command channel dictated by
            % this electrode.  If the named channel is both the current and
            % voltage command name, use the mode to break the tie.
            managedChannelNames=[{self.CurrentCommandChannelName_} ...
                                 {self.VoltageCommandChannelName_}];
            isMatch=strcmp(channelName,managedChannelNames);
            units={self.CurrentUnits_ ...
                   self.VoltageUnits_};
            matchingUnits=units(isMatch);
            if length(matchingUnits)>1 ,
                if isequal(self.Mode_,'vc') ,
                    result=matchingUnits{2};
                else
                    result=matchingUnits{1};
                end
            else
                result=matchingUnits{1};
            end
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
        
        function modes = get.AllowedModes(self)
            modes = ws.Electrode.allowedModesForType(self.Type) ;
        end
        
        function result = get.IsInACCMode(self)
            result = isequal(self.Mode_,'cc') || isequal(self.Mode_,'i_equals_zero') ;
        end

        function result = get.IsInAVCMode(self)
            result = isequal(self.Mode_,'vc') ;
        end
        
        function setMode_(self, newValue)
            if ~isempty(newValue) ,  % empty sometimes used to signal that mode is unknown
                allowedModes = self.AllowedModes ;
                isMatch=cellfun(@(mode)(isequal(mode,newValue)),allowedModes);            
                if any(isMatch) ,
                    self.Mode_ = newValue;
                end
            end
%             if doNotify,
%                  self.mayHaveChanged('Mode');
%             end
        end  % function        
        
        function setVoltageMonitorScaling_(self,newValue)
            if isscalar(newValue) && isfinite(newValue) ,  % need isfinite() check b/c smart amps use this as "unknown" value
                self.VoltageMonitorScaling_=newValue;
            end
%             if doNotify,
%                 self.mayHaveChanged('VoltageMonitorScaling');
%             end
        end
        
        function setCurrentCommandScaling_(self, newValue)
            if isscalar(newValue) && isfinite(newValue) ,  % need isfinite() check b/c smart amps use this as "unknown" value
                self.CurrentCommandScaling_=newValue;
            end
%             if doNotify,
%                 self.mayHaveChanged('CurrentCommandScaling');
%             end
        end
        
        function setVoltageCommandScaling_(self, newValue)
            if isscalar(newValue) && isfinite(newValue) ,  % need isfinite() check b/c smart amps use this as "unknown" value
                self.VoltageCommandScaling_=newValue;
            end
%             if doNotify,
%                 self.mayHaveChanged('VoltageCommandScaling');
%             end
        end
        
        function setCurrentMonitorScaling_(self, newValue)
            if isscalar(newValue) && isfinite(newValue) ,  % need isfinite() check b/c smart amps use this as "unknown" value
                self.CurrentMonitorScaling_=newValue;
            end
%             if doNotify,
%                 self.mayHaveChanged('CurrentMonitorScaling');
%             end
        end        
        
        function setIsCommandEnabled_(self, newValue)
            if islogical(newValue) && isscalar(newValue) ,
                % This property is always true for manual trodes
                if ~isequal(self.Type,'Manual') ,
                    self.IsCommandEnabled_=newValue;
                end
            end
%             if doNotify,
%                 self.mayHaveChanged('IsCommandEnabled');
%             end
        end
        
        function setType_(self,newValue)
            isMatch=strcmp(newValue,self.Types);
            newTypeIndex=find(isMatch,1);
            if ~isempty(newTypeIndex) ,
                % Some trode types can't do 'i_equals_zero' mode, so check for that
                % and change to 'cc' if needed
                newType=self.Types{newTypeIndex};
                mode=self.Mode;
                if ~ws.Electrode.isModeAllowedForType(mode,newType) ,
                    newMode = ws.Electrode.findClosestAllowedModeForType(mode,newType) ;
                    self.Mode_ = newMode;
                end                
                % Actually change the type index
                self.TypeIndex_=newTypeIndex;
                % Set IndexWithinType_ as needed
                if isequal(newValue,'Manual') ,
                    self.IndexWithinType_=[];
                else
                    if isempty(self.IndexWithinType_) ,
                        self.IndexWithinType_=1;
                    end
                end
            end                       
        end  % function
    end  % public methods block
    
%     methods (Access=protected)
%         function mayHaveChanged(self,propertyName)
%             electrodeManager=self.Parent_;
%             if isempty(electrodeManager) || ~isvalid(electrodeManager) ,
%                 return
%             end
%             if ~exist('propertyName','var') ,
%                 propertyName='';
%             end
%             electrodeManager.electrodeMayHaveChanged(self,propertyName);
%         end
%     end
    
    methods (Access = protected)
        function result = getPropertyValue_(self, name)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to encode private/protected variables, or do
            % some other kind of transformation on encoding, this method can be overridden.
            result = self.(name);
        end
        
        function setPropertyValue_(self, name, value)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to decode private/protected variables, or do
            % some other kind of transformation on decoding, this method can be overridden.
            self.(name) = value;
        end
    end  % protected methods
    
    methods (Static)
        function modes=allowedModesForType(type)
            switch type ,
                case 'Axon Multiclamp' ,
                    modes={'vc' 'cc' 'i_equals_zero'};
                otherwise
                    modes={'vc' 'cc'};
            end
        end
        
        function result=isModeAllowedForType(mode,type)
            allowedModes=ws.Electrode.allowedModesForType(type);
            result=any(strcmp(mode,allowedModes));
        end
        
        function mode=findClosestAllowedModeForType(desiredMode,type)
            switch type ,
                case 'Axon Multiclamp' ,
                    mode=desiredMode;
                otherwise
                    if isequal(desiredMode,'i_equals_zero') ,
                        mode='cc';
                    else
                        mode=desiredMode;
                    end
            end
        end        
    end  % static methods

%     methods (Access=protected)        
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.Model(self);
%             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
%         end
%     end
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
    methods
        function setProperty_(self, propertyName, newValue)            
            % This one is deisigned to be used for most setting needs.
            % setPropertyValue_() is mostly just for use by ws.Coding.
            methodName = horzcat('set', propertyName, '_') ;
            feval(methodName, self, newValue) ;
        end
    end

end  % classdef
