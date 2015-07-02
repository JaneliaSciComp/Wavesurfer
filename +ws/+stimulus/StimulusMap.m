classdef StimulusMap < ws.Model & ws.mixin.ValueComparable
    %STIMMAP Map Stimulus objects to analog or digital output channels.
    %
    %   S = STIMMAP() creates an empty stimulus map object.  Bindings for output
    %   channels can be added with the addBinding() method.
    %
    %   S = STIMMAP(NAMES) creates a stimulus map with channel names, NAMES.
    %   Bindings can be assigned with the assignBinding() method.  prvMapChannelsChangedListener may also
    %   be added or removed with the addBinding() or removeChannel() methods.
    %
    %   See also ws.stimulus.Stimulus.
    
    % Note that StimulusMaps should only ever
    % exist as an item in a StimulusLibrary!

%     properties (SetAccess = protected, Hidden = true)
%         UUID  % a unique id so that things can be re-linked after loading from disk
%     end
    
    properties
        Parent  % the parent StimulusLibrary.  Invariant: Must be a scalar ws.stimulus.StimulusLibrary.  (E.g. cannot be empty)
    end
    
    properties (Dependent=true)
        Name
    end
    
    properties (Access=protected)
        Name_ = ''
    end
    
    properties (Dependent=true)
        Duration  % s
    end
       
    properties (Dependent=true, SetAccess=immutable)
        IsDurationFree
    end

    properties (Dependent=true, SetAccess=immutable)
        IsLive
        NBindings
    end
    
    properties (Dependent = true, Transient=true)  % Why transient?
        ChannelNames  % a cell array of strings
        Stimuli  % a cell array, with [] for missing stimuli
        Multipliers  % a double array
        IsMarkedForDeletion  % a logical array
    end
    
    properties (Access = protected)
        ChannelNames_ = {}
        %StimulusUUIDs_ = {}
        Multipliers_ = []
        Stimuli_ = {}
        Duration_ = 1  % s, internal duration, can be overridden in some circumstances
        IsMarkedForDeletion_ = logical([])
    end
    
    methods
        function self = StimulusMap(varargin)
            pvArgs = ws.most.util.filterPVArgs(varargin, {'Parent', 'Name', 'Duration'}, {});
            
            prop = pvArgs(1:2:end);
            vals = pvArgs(2:2:end);
            
            for idx = 1:length(prop)
                self.(prop{idx}) = vals{idx};
            end
            
            %if isempty(self.Parent) ,
            %    error('wavesurfer:stimulusMapMustHaveParent','A stimulus map has to have a parent StimulusLibrary');
            %end
            
            %self.UUID = rand();
        end
        
        function delete(self)
            self.Parent=[];
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
        
        function set.Parent(self, newParent)
            if isa(newParent,'ws.most.util.Nonvalue'), return, end            
            %self.validatePropArg('Parent', newParent);
            if (isa(newParent,'double') && isempty(newParent)) || (isa(newParent,'ws.stimulus.StimulusLibrary') && isscalar(newParent)) ,
                if isempty(newParent) ,
                    self.Parent=[];
                else
                    self.Parent=newParent;
                end
            end            
        end  % function
        
        function set.Name(self,newValue)
            if ischar(newValue) && isrow(newValue) && ~isempty(newValue) ,
                allItems=self.Parent.Maps;
                isNotMe=cellfun(@(item)(item~=self),allItems);
                allItemsButMe=allItems(isNotMe);
                allOtherItemNames=cellfun(@(item)(item.Name),allItemsButMe,'UniformOutput',false);
                if ismember(newValue,allOtherItemNames) ,
                    % do nothing
                else
                    self.Name_=newValue;
                end
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end

        function out = get.NBindings(self) 
            out = length(self.ChannelNames);
        end
        
        function out = get.Name(self)
            out = self.Name_;
        end   % function

%         function durationPrecursorMayHaveChanged(self,varargin)
%             self.Duration=ws.most.util.Nonvalue.The;  % a code to do no setting, but cause the post-set event to fire
%             self.IsDurationFree=ws.most.util.Nonvalue.The;  % cause the post-set event to fire
%         end
        
        function set.ChannelNames(self,newValue)
            % newValue must be a row cell array, with each element a string
            % and each string either empty or a valid output channel name
            stimulation=ws.utility.getSubproperty(self,'Parent','Parent');
            if isempty(stimulation) ,
                doCheckChannelNames=false;
            else
                doCheckChannelNames=true;
                allChannelNames=stimulation.ChannelNames;
            end
            
            if iscell(newValue) && all(size(newValue)==size(self.ChannelNames_)) ,  % can't change number of bindings
                nElements=length(newValue);
                isGoodSoFar=true;
                for i=1:nElements ,
                    putativeChannelName=newValue{i};
                    if ischar(putativeChannelName) && (isrow(putativeChannelName) || isempty(putativeChannelName)) ,
                        if isempty(putativeChannelName) ,
                            % this is ok
                        else
                            if doCheckChannelNames ,
                                if ismember(putativeChannelName,allChannelNames) ,
                                    % this is ok
                                else
                                    isGoodSoFar=false;
                                    break
                                end
                            else
                                % this is ok
                            end                            
                        end
                    else
                        isGoodSoFar=false;
                        break
                    end
                end
                % if isGoodSoFar==true here, is good
                if isGoodSoFar ,
                    self.ChannelNames_=newValue;
                end   
            end            
            % notify the stim library so that views can be updated    
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end                        
        end  % function

        function val = get.ChannelNames(self)
            val = self.ChannelNames_ ;
        end

        function set.Stimuli(self,newValue)
            function value = isStimulusValid(stimulus)
                value = (isempty(stimulus) && isa(stimulus,'double')) || (isa(stimulus,'ws.stimulus.Stimulus') && isscalar(stimulus));
            end
            
%             function uuid=uuidFromItem(item)
%                 if isempty(item)
%                     uuid=[];
%                 else
%                     uuid=item.UUID;
%                 end
%             end
            
            if iscell(newValue) && all(size(newValue)==size(self.ChannelNames_)) ,  % can't change number of bindings
                isValid=cellfun(@isStimulusValid,newValue);
                if all(isValid) ,
                    self.Stimuli_ = newValue;
                    %self.StimulusUUIDs_ = cellfun(@uuidFromItem,newValue,'UniformOutput',false);
                end
            end
            
            % notify the powers that be
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end
        
        function output = get.Stimuli(self)
            output = self.Stimuli_ ;
        end
        
        function set.Multipliers(self,newValue)
            if isnumeric(newValue) && all(size(newValue)==size(self.ChannelNames_)) ,  % can't change number of bindings                
                self.Multipliers_ = double(newValue);
            end
            % notify the powers that be
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end
        
        function output = get.Multipliers(self)
            output = self.Multipliers_ ;
        end
                
        function set.IsMarkedForDeletion(self,newValue)
            if islogical(newValue) && isequal(size(newValue),size(self.ChannelNames_)) ,  % can't change number of bindings                
                self.IsMarkedForDeletion_ = newValue;
            end
            % notify the powers that be
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end
        
        function output = get.IsMarkedForDeletion(self)
            output = self.IsMarkedForDeletion_ ;
        end
                
        function value = get.Duration(self)  % always returns a double
            try
                % See if we can collect all the information we need to make
                % an informed decision about whether to use the acquisition
                % duration or our own internal duration
                [isTrialBased,doesStimulusUseAcquisitionTriggerScheme,acquisitionDuration]=self.collectExternalInformationAboutDuration();
            catch 
                % If we can't collect enough information to make an
                % informed decision, just fall back to the internal
                % duration.
                value=self.Duration_;
                return
            end
            
            % Return the acquisiton duration or the internal duration,
            % depending
            if isTrialBased && doesStimulusUseAcquisitionTriggerScheme ,
                value=acquisitionDuration;
            else
                value=self.Duration_;
            end
        end   % function
        
        function set.Duration(self, newValue)
            if isa(newValue,'ws.most.util.Nonvalue'), return, end            
            self.validatePropArg('Duration', newValue);
            try
                % See if we can collect all the information we need to make
                % an informed decision about whether to use the acquisition
                % duration or our own internal duration
                % (This is essentially a way to test whether the
                % parent-child relationships that enable us to determine
                % the duration from external object are set up.  If this
                % throws, we know that they're _not_ set up, and so we are
                % free to set the internal duration to the given value.)
                [isTrialBased,doesStimulusUseAcquisitionTriggerScheme]=self.collectExternalInformationAboutDuration();
            catch 
                self.Duration_ = newValue;
                if ~isempty(self.Parent) ,
                    self.Parent.childMayHaveChanged(self);
                end                
                return
            end
            
            % Return the acquisition duration or the internal duration,
            % depending
            if isTrialBased && doesStimulusUseAcquisitionTriggerScheme ,
               % internal duration is overridden, so don't set it.
               % Note that even though we 'do nothing', the PostSet event
               % will still occur.
            else
                self.Duration_ = newValue;
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end   % function
        
        function value = get.IsDurationFree(self)
            try
                % See if we can collect all the information we need to make
                % an informed decision about whether to use the acquisition
                % duration or our own internal duration
                [isTrialBased,doesStimulusUseAcquisitionTriggerScheme]=self.collectExternalInformationAboutDuration();
            catch me %#ok<NASGU>
                % If we can't collect enough information to make an
                % informed decision, then we are free!  Ignorance is
                % freedom!
                value=true;
                return
            end
            
            % Return the acquisiton duration or the internal duration,
            % depending
            value=~(isTrialBased && doesStimulusUseAcquisitionTriggerScheme);
        end   % function
        
        function set.IsDurationFree(self, newValue) %#ok<INUSD>
            % This does nothing, and is only present so we can cause the
            % PostSet event on the property to fire when the precursors
            % change.
        end   % function

        function [isTrialBased,doesStimulusUseAcquisitionTriggerScheme,acquisitionDuration]=collectExternalInformationAboutDuration(self)
            % Collect information that determines whether we use the
            % internal duration or the acquisition duration.  This will
            % throw if the parent/child relationships are not set up.
            
            % See if we can collect all the information we need to make
            % an informed decision about whether to use the acquisition
            % duration or our own internal duration
            stimulusLibrary=self.Parent;
            stimulationSubsystem=stimulusLibrary.Parent;
            wavesurferModel=stimulationSubsystem.Parent;
            triggeringSubsystem=wavesurferModel.Triggering;
            acquisitionSubsystem=wavesurferModel.Acquisition;            
            isTrialBased=wavesurferModel.IsTrialBased;
            doesStimulusUseAcquisitionTriggerScheme=triggeringSubsystem.StimulationUsesAcquisitionTriggerScheme;
            acquisitionDuration=acquisitionSubsystem.Duration;
        end   % function
        
        function out = containsStimulus(self, stimuliOrStimulus)
            stimuli=ws.most.idioms.cellifyIfNeeded(stimuliOrStimulus);
            out = false(size(stimuli));
            
            for index = 1:numel(stimuli)
                validateattributes(stimuli{index}, {'ws.stimulus.Stimulus'}, {'vector'});
            end
            
            if isempty(stimuli)
                return
            end
                        
            %currentStimuli = [self.Bindings_.Stimulus];
            %boundStimuli = cellfun(@(binding)(binding.Stimulus),self.Bindings_,'UniformOutput',false);
            boundStimuli = self.Stimuli;
            
            for index = 1:numel(stimuli) ,
                thisStimulus=stimuli{index};
                isMatch=cellfun(@(boundStimulus)(boundStimulus==thisStimulus),boundStimuli);
                if any(isMatch) ,
                    out(index) = true;
                end
            end
        end   % function

        function addBinding(self, channelName, stimulus, multiplier)
            % Deal with missing args
            if ~exist('channelName','var') || isempty(channelName) ,
                channelName = '';
            end
            if ~exist('stimulus','var') || isempty(stimulus) ,
                stimulus=[];
            end
            if ~exist('multiplier','var') || isempty(multiplier) ,
                multiplier=1;
            end
            
            % Check the args
            isChannelNameOK = ischar(channelName) && (isempty(channelName) || isrow(channelName));
            isStimulusOK = (isa(stimulus,'double') && isempty(stimulus)) || ...
                           (isa(stimulus,'ws.stimulus.Stimulus') && isscalar(stimulus));
            isMultiplierOK = isnumeric(multiplier) && isscalar(multiplier);           
            
            % Create the binding
            if isChannelNameOK && isStimulusOK && isMultiplierOK ,
                self.ChannelNames_{end+1}=channelName;
                self.Stimuli_{end+1}=stimulus;            
%                 if isempty(stimulus) ,
%                     self.StimulusUUIDs_{end+1} = [];
%                 else
%                     self.StimulusUUIDs_{end+1} = stimulus.UUID;
%                 end
                self.Multipliers_(end+1)=multiplier;
                self.IsMarkedForDeletion_(end+1)=false;
            end            
            
            % notify the powers that be
            self.Parent.childMayHaveChanged(self);
        end   % function
        
        function deleteBinding(self, index)
            nBindingsOriginally=length(self.ChannelNames);
            if (1<=index) && (index<=nBindingsOriginally) ,
                self.ChannelNames_(index)=[];
                self.Stimuli_(index)=[];
                self.Multipliers_(index)=[];                
                self.IsMarkedForDeletion_(index)=[];                
            end
            self.Parent.childMayHaveChanged(self);            
        end   % function

        function deleteMarkedBindings(self)            
            isMarkedForDeletion = self.IsMarkedForDeletion ;
            self.ChannelNames_(isMarkedForDeletion)=[];
            self.Stimuli_(isMarkedForDeletion)=[];
            self.Multipliers_(isMarkedForDeletion)=[];
            self.IsMarkedForDeletion_(isMarkedForDeletion)=[];
            self.Parent.childMayHaveChanged(self);            
        end   % function        
        
%         function replaceStimulus(self, oldStimulus, newStimulus)
%             for idx = 1:numel(self.Bindings) ,
%                 if self.Bindings{idx}.Stimulus == oldStimulus ,
%                     self.Bindings{idx}.Stimulus = newStimulus;
%                 end
%             end
%         end  % function
        
        function nullStimulus(self, stimulus)
            % Set all occurances of stimulus in the self to []
            for i = 1:length(self.Stimuli) ,
                if self.Stimuli{i} == stimulus ,
                    self.Stimuli{i} = [];
                end
            end
        end  % function
        
        function [data, nChannelsWithStimulus] = calculateSignals(self, sampleRate, channelNames, isChannelAnalog, trialIndexWithinSet)
            % nBoundChannels is the number of channels *in channelNames* for which
            % a non-empty binding was found.
            if ~exist('trialIndexWithinSet','var') || isempty(trialIndexWithinSet) ,
                trialIndexWithinSet=1;
            end
            
            % Create a timeline
            sampleCount = round(self.Duration * sampleRate);
            dt=1/sampleRate;
            t0=0;  % initial sample time
            t=(t0+dt/2)+dt*(0:(sampleCount-1))';            
              % + dt/2 is somewhat controversial, but in the common case
              % that pulse durations are integer multiples of dt, it
              % ensures that each pulse is exactly (pulseDuration/dt)
              % samples long, and avoids other unpleasant pseudorandomness
              % when stimulus discontinuities occur right at sample times
            
            % Create the data array  
            nChannels=length(channelNames);
            data = zeros(sampleCount, nChannels);
            
            % For each named channel, overwrite a col of data
            boundChannelNames=self.ChannelNames;
            nChannelsWithStimulus = 0 ;
            for iChannel = 1:nChannels ,
                thisChannelName=channelNames{iChannel};
                stimIndex = find(strcmp(thisChannelName, boundChannelNames), 1);
                if isempty(stimIndex) ,
                    % do nothing
                else
                    %thisBinding=self.Bindings_{stimIndex};
                    thisStimulus=self.Stimuli{stimIndex}; 
                    if isempty(thisStimulus) ,
                        % do nothing
                    else        
                        % Calc the signal, scale it, overwrite the appropriate col of
                        % data
                        nChannelsWithStimulus = nChannelsWithStimulus + 1 ;
                        rawSignal = thisStimulus.calculateSignal(t, trialIndexWithinSet);
                        multiplier=self.Multipliers(stimIndex);
                        if isChannelAnalog(iChannel) ,
                            data(:, iChannel) = multiplier*rawSignal ;
                        else
                            data(:, iChannel) = (multiplier*rawSignal>=0.5) ;  % also eliminates nan, sets to false                     
                        end
                    end
                end
            end
        end  % function
        
%         function revive(self,stimuli)
%             for i=1:numel(self) ,
%                 self(i).reviveElement(stimuli);
%             end
%         end  % function

        function value=get.IsLive(self)   %#ok<MANU>
            value=true;
%             nBindings=length(self.ChannelNames);
%             value=true;
%             for i=1:nBindings ,
%                 % A binding is broken when there's a stimulus UUID but no
%                 % stimulus handle.  It's sound iff it's not broken.
%                 thisStimulus=self.Stimuli_{i};
%                 thisStimulusUUID=self.StimulusUUIDs_{i};
%                 isThisOneLive= ~(isempty(thisStimulus) && ~isempty(thisStimulusUUID)) ;                
%                 if ~isThisOneLive ,
%                     value=false;
%                     break
%                 end
%             end
        end
        
        function lines = plot(self, fig, ax, sampleRate)
            if ~exist('ax','var') || isempty(ax)
                ax = axes('Parent',fig);
            end            
            if ~exist('sampleRate','var') || isempty(sampleRate)
                sampleRate = 20000;  % Hz
            end
            
            % Get the channel names
            channelNames=self.ChannelNames;
            
            % Try to determine whether channels are analog or digital.  Fallback to analog, if needed.
            nChannels = length(channelNames) ;
            isChannelAnalog = true(1,nChannels) ;
            stimulusLibrary = self.Parent ;
            if ~isempty(stimulusLibrary) ,
                stimulation = stimulusLibrary.Parent ;
                if ~isempty(stimulation) ,                                    
                    for i = 1:nChannels ,
                        channelName = channelNames{i} ;
                        isChannelAnalog(i) = stimulation.isAnalogChannelName(channelName) ;
                    end
                end
            end
            
            % calculate the signals
            data = self.calculateSignals(sampleRate,channelNames,isChannelAnalog);
            
            %[data, channelNames] = self.calculateSignals(sampleRate, varargin{:});
            n=size(data,1);
            nSignals=size(data,2);
            
            lines = zeros(1, size(data,2));
            
            dt=1/sampleRate;  % s
            time = dt*(0:(n-1))';
            
            clist = 'bgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmk';
            
            %set(ax, 'NextPlot', 'Add');
            
            for idx = 1:nSignals ,
                lines(idx) = line('Parent',ax, ...
                                  'XData',time, ...
                                  'YData',data(:,idx), ...
                                  'Color',clist(idx));
            end
            
            ws.utility.setYAxisLimitsToAccomodateLinesBang(ax,lines);
            legend(ax, channelNames, 'Interpreter', 'None');
            %title(ax,sprintf('Stimulus Map: %s', self.Name));
            xlabel(ax,'Time (s)','FontSize',10);
            ylabel(ax,self.Name,'FontSize',10);
            
            %set(ax, 'NextPlot', 'Replace');
        end        
        
        function value=isLiveAndSelfConsistent(self)
            value=false(size(self));
            for i=1:numel(self) ,
                value(i)=self(i).isLiveAndSelfConsistentElement();
            end
        end
        
        function value=isLiveAndSelfConsistentElement(self) %#ok<MANU>
            value=true;
%             nBindings=length(self.ChannelNames);
%             value=true;
%             for i=1:nBindings ,
%                 % A binding is broken when there's a stimulus UUID but no
%                 % stimulus handle.  It's sound iff it's not broken.
%                 % It's self-consistent if the locally-stored UUID aggrees
%                 % with the one in the stimulus object itself.
%                 thisStimulus=self.Stimuli_{i};
%                 thisStimulusUUID=self.StimulusUUIDs_{i};
%                 isThisOneLive= ~(isempty(thisStimulus) && ~isempty(thisStimulusUUID)) ;                
%                 if isThisOneLive ,
%                     isThisOneSelfConsistent=(thisStimulus.UUID==thisStimulusUUID);
%                     if ~isThisOneSelfConsistent ,
%                         value=false;
%                         break
%                     end                    
%                 else 
%                     value=false;
%                     break
%                 end
%             end
        end  % function        

        function result=areAllStimuliInDictionary(self,stimulusDictionary)
            nStimuli=self.NBindings;
            for i=1:nStimuli ,
                thisStimulus=self.Stimuli{i};
                isMatch=cellfun(@(stimulus)(thisStimulus==stimulus),stimulusDictionary);
                if ~any(isMatch) ,
                    result=false;
                    return
                end
            end
            result=true;
        end
    end  % public methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyTags(self)
%             % self.setPropertyTags('Name', 'IncludeInFileTypes', {'*'});
%             % self.setPropertyTags('Bindings', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('Duration_', 'IncludeInFileTypes', {'*'});            
%         end  % function
        
%         function reviveElement(self,stimuli)
%             nBindings=self.NBindings;
%             for i=1:nBindings ,
%                 self.reviveElementBinding(i,stimuli);
%             end
%         end  % function
        
%         function reviveElementBinding(self,i,stimuli) %#ok<INUSD>
%             % Allows one to re-link a binding to its stimulus, e.g. after
%             % loading from a file.  Tries to find a stimulus in stimuli
%             % with a UUID matching the binding's stored stimulus UUID.            
%             stimulusUUID=self.StimulusUUIDs_{i};
%             uuids=ws.most.idioms.cellArrayPropertyAsArray(stimuli,'UUID');
%             isMatch=(uuids==stimulusUUID);
%             iMatch=find(isMatch,1);
%             if isempty(iMatch) ,
%                 self.Stimuli_{i}=[];  % this will at least make it so Stimuli_ has the right number of elements
%             else                
%                 self.Stimuli_{i}=stimuli{iMatch};
%             end                
%         end  % function
    end
    
    methods
        function value=isequal(self,other)
            value=isequalHelper(self,other,'ws.stimulus.StimulusMap');
        end  % function    
    end  % methods
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            % Test for "value equality" of two scalar StimulusMap's
            propertyNamesToCompare={'Name' 'Duration' 'ChannelNames' 'Stimuli' 'Multipliers'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end  % function
    end  % methods
    
    methods
        function other=copyGivenStimuli(self,otherStimulusDictionary,selfStimulusDictionary)
            % Makes a "copy" of self, but where other.Stimuli_ point to
            % elements of otherStimulusDictionary.  StimulusMaps are not
            % meant to be free-standing objects, and so are not subclassed
            % from matlab.mixin.Copyable.
            
            % Do the easy part
            other=ws.stimulus.StimulusMap();
            other.Name_ = self.Name_ ;
            other.ChannelNames_ = self.ChannelNames_ ;
            other.Multipliers_ = self.Multipliers_ ;
            other.IsMarkedForDeletion_ = self.IsMarkedForDeletion_ ;
            other.Duration_ = self.Duration_ ;

            % re-do the bindings so that they point to corresponding
            % elements of otherStimuli
            nStimuli=length(self.ChannelNames);
            other.Stimuli_ = cell(1,nStimuli);
            %uuids=ws.most.idioms.cellArrayPropertyAsArray(selfStimuli,'UUID');
            for j=1:nStimuli ,
                %uuidOfThisStimulusInSelf=self.StimulusUUIDs_{j};
                thisStimulusInSelf=self.Stimuli_{j};
                %indexOfThisStimulusInLibrary=find(uuidOfThisStimulusInSelf==uuids);
                if isempty(thisStimulusInSelf) ,
                    isMatch = false(size(selfStimulusDictionary));
                else
                    isMatch = cellfun(@(stimulus)(stimulus==thisStimulusInSelf),selfStimulusDictionary);
                end
                indexOfThisStimulusInDictionary=find(isMatch,1);
                if isempty(indexOfThisStimulusInDictionary) ,
                    other.Stimuli_{j}=[];
                else
                    other.Stimuli_{j}=otherStimulusDictionary{indexOfThisStimulusInDictionary};
                end
            end
        end  % function
    end  % methods
    
%     methods (Access = protected)
%         function other = copyElement(self)
%             % Perform the standard copy.
%             other = copyElement@matlab.mixin.Copyable(self);
%             
%             % Change the uuid.
%             %other.UUID = rand();
% 
%             other.Parent=[];  % Don't want this to point to self's Parent
%         end
%     end
    
    methods (Access=protected)
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.Model(self);
            self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
        end
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.stimulus.StimulusMap.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();
            
            s.Name = struct('Classes', 'char');
            s.Duration = struct('Classes', 'numeric', ...
                                'Attributes', {{'scalar', 'nonnegative', 'real', 'finite'}});
            s.ChannelNames = struct('Classes', 'string');
            s.Multipliers = struct('Classes', 'numeric', 'Attributes', {{'row', 'real', 'finite'}});
            s.Stimuli = struct('Classes', 'ws.stimulus.StimulusMap');                            
        end  % function
        
%         function self = loadobj(self)
%             self.IsMarkedForDeletion_ = false(size(self.ChannelNames_));
%               % Is MarkedForDeletion_ is transient
%         end
    end  % class methods block
    
end
