classdef StimulusMap < ws.Model & ws.ValueComparable
    
    properties (Dependent=true)
        Name
        Duration  % s
        ChannelName  % a cell array of strings
        IndexOfEachStimulusInLibrary
        %Stimuli  % a cell array, with [] for missing stimuli
        Multiplier  % a double array
    end
    
    properties (Dependent = true, Transient=true)
        IsMarkedForDeletion  % a logical array
    end

    properties (Dependent = true, SetAccess=immutable, Transient=true)
        %IsDurationFree
        NBindings
    end
    
    properties (Access = protected)
        Name_ = ''
        Duration_ = 1  % s, internal duration, can be overridden in some circumstances
        % Things below are all vectors with the same length, equal to the
        % number of elements in the map
        ChannelName_ = {}
        IndexOfEachStimulusInLibrary_ = {}  % for each binding, the index of the stimulus (in the library) for that binding, or empty if unspecified
        Multiplier_ = []
        IsMarkedForDeletion_ = logical([])
    end
    
    methods
        function self = StimulusMap(parent)  %#ok<INUSD>
            self@ws.Model([]);
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
        
        function set.Name(self, newValue)
            if ws.isString(newValue) && ~isempty(newValue) ,                
                self.Name_ = newValue ;
            else
                error('ws:invalidPropertyValue', ...
                      'Stimulus name must be a nonempty string');                  
            end
        end

        function out = get.NBindings(self) 
            out = length(self.ChannelName);
        end
        
        function out = get.Name(self)
            out = self.Name_;
        end   % function

        function out = get.IndexOfEachStimulusInLibrary(self)
            out = self.IndexOfEachStimulusInLibrary_ ;
        end   % function

        function set.IndexOfEachStimulusInLibrary(self, newValue)            
            self.IndexOfEachStimulusInLibrary_ = newValue ;
        end   % function

        function setSingleChannelName(self, bindingIndex, newValue)
            if ws.isIndex(bindingIndex) && 1<=bindingIndex && bindingIndex<=self.NBindings ,
                if ws.isString(newValue) ,
                    self.ChannelName_{bindingIndex} = newValue ;
                else
                    error('ws:stimulusLibrary:badChannelName', ...
                          'Channel name must be a string');
                end
            else
                error('ws:stimulusLibrary:badBindingIndex', ...
                      'Illegal binding index');
            end
        end  % function
        
        function set.ChannelName(self, newValue)
            % newValue must be a row cell array, with each element a string
            % and each string either empty or a valid output channel name
            if iscell(newValue) && all(size(newValue)==size(self.ChannelName_)) ,  % can't change number of bindings
                nBindings=length(newValue);
                isGoodSoFar=true;
                for i=1:nBindings ,
                    putativeChannelName=newValue{i};
                    if ~ws.isString(putativeChannelName) ,
                        isGoodSoFar=false;
                        break
                    end
                end
                % if isGoodSoFar==true here, is good
                if isGoodSoFar ,
                    self.ChannelName_ = newValue ;
                else
                    error('ws:stimulusLibrary:badChannelName', ...
                          'All elements of ChannelName must be strings');                    
                end   
            else
                error('ws:stimulusLibrary:badChannelName', ...
                      'ChannelName must be a cell row array of strings, of the correct length');
            end            
        end  % function

        function val = get.ChannelName(self)
            val = self.ChannelName_ ;
        end

%         function set.Stimuli(self,newValue)
%             % newValue a cell array of length equal to the number of
%             % bindings.  Each element either [], or a stimulus
%             % in the library
%             
%             if iscell(newValue) && all(size(newValue)==size(self.ChannelName_)) ,  % can't change number of bindings
%                 areAllElementsOfNewValueOK = true ;
%                 indexOfEachStimulusInLibrary = cell(size(self.ChannelName_)) ;
%                 for i=1:numel(newValue) ,
%                     stimulus = newValue{i} ;
%                     if (isempty(stimulus) && isa(stimulus,'double')) ,
%                         indexOfEachStimulusInLibrary{i} = [] ;
%                     elseif isa(stimulus,'ws.Stimulus') && isscalar(stimulus) ,
%                         indexOfThisStimulusInLibrary = self.Parent.getStimulusIndex(stimulus) ;
%                         if isempty(indexOfThisStimulusInLibrary)
%                             % This stim is not in library
%                             areAllElementsOfNewValueOK = false ;
%                             break
%                         else
%                             indexOfEachStimulusInLibrary{i} = indexOfThisStimulusInLibrary ;
%                         end
%                     else
%                         areAllElementsOfNewValueOK = false ;
%                         break
%                     end                        
%                 end  % for
%                 
%                 if areAllElementsOfNewValueOK ,                    
%                     self.IndexOfEachStimulusInLibrary_ = indexOfEachStimulusInLibrary ;
%                 end
%             end            
%         end
        
%         function output = get.Stimuli(self)
%             nBindings = numel(self.IndexOfEachStimulusInLibrary_) ;            
%             output = cell(size(self.IndexOfEachStimulusInLibrary_)) ;
%             for i = 1:nBindings ,
%                 indexOfThisStimulusInLibrary = self.IndexOfEachStimulusInLibrary_{i} ;
%                 if isempty(indexOfThisStimulusInLibrary) ,
%                     output{i} = [] ;
%                 else                    
%                     output{i} = self.Parent.Stimuli{indexOfThisStimulusInLibrary} ;
%                 end
%             end
%         end
        
        function set.Multiplier(self,newValue)
            if isnumeric(newValue) && all(size(newValue)==size(self.ChannelName_)) ,  % can't change number of bindings                
                self.Multiplier_ = double(newValue) ;
            end
        end
        
        function output = get.Multiplier(self)
            output = self.Multiplier_ ;
        end
                
        function set.IsMarkedForDeletion(self,newValue)
            if islogical(newValue) && isequal(size(newValue),size(self.ChannelName_)) ,  % can't change number of bindings                
                self.IsMarkedForDeletion_ = newValue ;
            end
        end
        
        function output = get.IsMarkedForDeletion(self)
            output = self.IsMarkedForDeletion_ ;
        end
                
        function value = get.Duration(self)
            value = self.Duration_ ;
        end   % function
        
        function set.Duration(self, newValue)
            if isnumeric(newValue) && isreal(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>=0 ,
                newValue = double(newValue) ;
                self.Duration_ = newValue;
            else
                error('ws:invalidPropertyValue', ...
                      'Duration must be numeric, real, scalar, nonnegative, and finite.');
            end
        end   % function
                
        function result = containsStimulus(self, queryStimulusIndex)
            result = cellfun(@(element)(any(element==queryStimulusIndex)), self.IndexOfEachStimulusInLibrary_) ;
        end   % function

        function bindingIndex = addBinding(self)
            % Add a "binding" to the list of bindings
            bindingIndex = self.NBindings + 1 ;
            self.ChannelName_{bindingIndex} = '' ;
            self.IndexOfEachStimulusInLibrary_{bindingIndex} = [] ;
            self.Multiplier_(bindingIndex) = 1 ;
            self.IsMarkedForDeletion_(bindingIndex) = false ;
        end   % function
        
        function deleteBinding(self, index)
            nBindingsOriginally=length(self.ChannelName);
            if (1<=index) && (index<=nBindingsOriginally) ,
                self.ChannelName_(index)=[];
                self.IndexOfEachStimulusInLibrary_(index)=[];
                self.Multiplier_(index)=[];                
                self.IsMarkedForDeletion_(index)=[];                
            end
        end   % function

        function deleteMarkedBindings(self)            
            isMarkedForDeletion = self.IsMarkedForDeletion ;
            self.ChannelName_(isMarkedForDeletion)=[];
            self.IndexOfEachStimulusInLibrary_(isMarkedForDeletion)=[];
            self.Multiplier_(isMarkedForDeletion)=[];
            self.IsMarkedForDeletion_(isMarkedForDeletion)=[];
        end   % function        
        
%         function [data, nChannelsWithStimulus] = calculateSignals(self, sampleRate, channelNames, isChannelAnalog, sweepIndexWithinSet)
%             % nBoundChannels is the number of channels *in channelNames* for which
%             % a non-empty binding was found.
%             if ~exist('sweepIndexWithinSet','var') || isempty(sweepIndexWithinSet) ,
%                 sweepIndexWithinSet=1;
%             end
%             
%             % Create a timeline
%             duration = self.Duration ;
%             sampleCount = round(duration * sampleRate);
%             dt=1/sampleRate;
%             t0=0;  % initial sample time
%             t=(t0+dt/2)+dt*(0:(sampleCount-1))';            
%               % + dt/2 is somewhat controversial, but in the common case
%               % that pulse durations are integer multiples of dt, it
%               % ensures that each pulse is exactly (pulseDuration/dt)
%               % samples long, and avoids other unpleasant pseudorandomness
%               % when stimulus discontinuities occur right at sample times
%             
%             % Create the data array  
%             nChannels=length(channelNames);
%             data = zeros(sampleCount, nChannels);
%             
%             % For each named channel, overwrite a col of data
%             boundChannelNames=self.ChannelName;
%             nChannelsWithStimulus = 0 ;
%             for iChannel = 1:nChannels ,
%                 thisChannelName=channelNames{iChannel};
%                 stimIndex = find(strcmp(thisChannelName, boundChannelNames), 1);
%                 if isempty(stimIndex) ,
%                     % do nothing
%                 else
%                     %thisBinding=self.Bindings_{stimIndex};
%                     thisStimulus=self.Stimuli{stimIndex}; 
%                     if isempty(thisStimulus) ,
%                         % do nothing
%                     else        
%                         % Calc the signal, scale it, overwrite the appropriate col of
%                         % data
%                         nChannelsWithStimulus = nChannelsWithStimulus + 1 ;
%                         rawSignal = thisStimulus.calculateSignal(t, sweepIndexWithinSet);
%                         multiplier=self.Multiplier(stimIndex);
%                         if isChannelAnalog(iChannel) ,
%                             data(:, iChannel) = multiplier*rawSignal ;
%                         else
%                             data(:, iChannel) = (multiplier*rawSignal>=0.5) ;  % also eliminates nan, sets to false                     
%                         end
%                     end
%                 end
%             end
%         end  % function
        
        function setBindingTargetByIndex(self, bindingIndex, indexOfNewTargetWithinClass)
            % A "binding target", in this case, is a map.
            nBindings = self.NBindings ;
            if ws.isIndex(bindingIndex) && 1<=bindingIndex && bindingIndex<=nBindings ,
                if isempty(indexOfNewTargetWithinClass) ,
                    self.IndexOfEachStimulusInLibrary_{bindingIndex} = [] ;
                else
                    self.IndexOfEachStimulusInLibrary_{bindingIndex} = indexOfNewTargetWithinClass ;
                end
            end
        end   % function

%         function setBindingTargetByIndex(self, bindingIndex, stimulusIndexInLibrary)
%             if bindingIndex==round(bindingIndex) && 1<=bindingIndex && bindingIndex<=self.NBindings ,
%                 %library = self.Parent ;
%                 %stimulusIndexInLibrary = library.indexOfStimulusWithName(stimulusName) ;
%                 if isempty(stimulusIndexInLibrary) ,
%                     self.IndexOfEachStimulusInLibrary_{bindingIndex} = [] ;  % "null" the stimulus
%                 else
%                     self.IndexOfEachStimulusInLibrary_{bindingIndex} = stimulusIndexInLibrary ;
%                 end
%             end
%         end
        
        function result=areAllStimulusIndicesValid(self, nStimuliInLibrary)
            %library = self.Parent ;
            %nStimuliInLibrary = length(library.Stimuli) ;
            nStimuli = self.NBindings ;
            for i=1:nStimuli ,
                thisStimulusIndex = self.IndexOfEachStimulusInLibrary_{i} ;
                if isempty(thisStimulusIndex) || ...
                   ( thisStimulusIndex==round(thisStimulusIndex) && 1<=thisStimulusIndex && thisStimulusIndex<=nStimuliInLibrary ) ,
                    % this is all to the good
                else
                    result=false;
                    return
                end
            end
            result=true;
        end
        
        function renameChannel(self, oldValue, newValue)
            channelNames = self.ChannelName ;
            nChannels = length(channelNames) ;
            for i = 1:nChannels ,
                thisChannelName = channelNames{i} ;
                if isequal(thisChannelName, oldValue) ,
                    self.ChannelName_{i} = newValue ;
                end
            end
        end
        
        function adjustStimulusIndicesWhenDeletingAStimulus_(self, indexOfStimulusBeingDeleted)
            % The indexOfStimuluspBeingDeleted is the index of the stimulus
            % in the library, not its index in the map.
            for i=1:length(self.IndexOfEachStimulusInLibrary_) ,
                indexOfThisStimulus = self.IndexOfEachStimulusInLibrary_{i} ;
                if isempty(indexOfThisStimulus) ,
                    % nothing to do here, but want to catch before we start
                    % doing comparisons, etc.
                elseif indexOfStimulusBeingDeleted==indexOfThisStimulus ,
                    self.IndexOfEachStimulusInLibrary_{i} = [] ;
                elseif indexOfStimulusBeingDeleted<indexOfThisStimulus ,
                    self.IndexOfEachStimulusInLibrary_{i} = indexOfThisStimulus - 1 ;
                end
            end
        end        
        
        function nullGivenTargetInAllBindings(self, targetStimulusIndex)
            % Set all occurances of targetStimulusIndex in the bindings to []
            for i = 1:self.NBindings ,
                thisStimulusIndex = self.IndexOfEachStimulusInLibrary_{i} ;
                if thisStimulusIndex==targetStimulusIndex ,
                    self.IndexOfEachStimulusInLibrary_{i} = [] ;
                end
            end
        end  % function
    end  % public methods block
    
    methods
        function value=isequal(self,other)
            value=isequalHelper(self,other,'ws.StimulusMap');
        end  % function    
    end  % methods
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            % Test for "value equality" of two scalar StimulusMap's
            propertyNamesToCompare={'Name' 'Duration' 'ChannelName' 'IndexOfEachStimulusInLibrary' 'Multiplier'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end  % function
    end  % methods
    
    methods
        function other=copyGivenParent(self,parent)
            % Makes a "copy" of self, but where other.Stimuli_ point to
            % elements of otherStimulusDictionary.  StimulusMaps are not
            % meant to be free-standing objects, and so are not subclassed
            % from matlab.mixin.Copyable.
            
            % Do the easy part
            other=ws.StimulusMap(parent);
            other.Name_ = self.Name_ ;
            other.ChannelName_ = self.ChannelName_ ;
            other.IndexOfEachStimulusInLibrary_ = self.IndexOfEachStimulusInLibrary_ ;
            other.Multiplier_ = self.Multiplier_ ;
            other.IsMarkedForDeletion_ = self.IsMarkedForDeletion_ ;
            other.Duration_ = self.Duration_ ;
        end  % function
    end  % methods
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods (Access=protected)
        function sanitizePersistedState_(self)
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
            
            nBindings = length(self.ChannelName_) ;
            
            % length of things should equal nBindings
            self.IndexOfEachStimulusInLibrary_ = ws.sanitizeRowVectorLength(self.IndexOfEachStimulusInLibrary_, nBindings, {[]}) ;
            self.Multiplier_ = ws.sanitizeRowVectorLength(self.Multiplier_, nBindings, 1) ;
            self.IsMarkedForDeletion_ = ws.sanitizeRowVectorLength(self.IsMarkedForDeletion_, nBindings, false) ;
        end
    end  % protected methods block    
end
