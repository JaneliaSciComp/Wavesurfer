classdef Display < ws.Subsystem   %& ws.EventSubscriber
    %Display Manages the display and update of one or more Scope objects.
    
    properties (Dependent = true)
        IsGridOn
        AreColorsNormal        
        DoShowButtons        
        UpdateRate  % the rate at which the scopes are updated, in Hz
        XOffset  % the x coord at the left edge of the scope windows
        XSpan  % the trace duration shown in the scope windows
        IsXSpanSlavedToAcquistionDuration
          % if true, the x span for all the scopes is set to the acquisiton
          % sweep duration
        IsXSpanSlavedToAcquistionDurationSettable
          % true iff IsXSpanSlavedToAcquistionDuration is currently
          % settable
        IsAnalogChannelDisplayed  % 1 x nAIChannels
        IsDigitalChannelDisplayed  % 1 x nDIChannels
        AreYLimitsLockedTightToDataForAnalogChannel  % 1 x nAIChannels
        YLimitsPerAnalogChannel  % 2 x nAIChannels, 1st row is the lower limit, 2nd is the upper limit
        NScopes
    end

    properties (Access = protected)
        IsGridOn_ = true
        AreColorsNormal_ = true  % if false, colors are inverted, approximately
        DoShowButtons_ = true % if false, don't show buttons in the figure
        XSpan_ 
        UpdateRate_
        XAutoScroll_   % if true, x limits of all scopes will change to accomodate the data as it is acquired
        IsXSpanSlavedToAcquistionDuration_
          % if true, the x span for all the scopes is set to the acquisiton
          % sweep duration
        IsAnalogChannelDisplayed_  % 1 x nAIChannels
        IsDigitalChannelDisplayed_  % 1 x nDIChannels
        AreYLimitsLockedTightToDataForAnalogChannel_  % 1 x nAIChannels
        YLimitsPerAnalogChannel_  % 2 x nAIChannels, 1st row is the lower limit, 2nd is the upper limit
    end
    
    properties (Access = protected, Transient=true)
        XOffset_
        ClearOnNextData_
        CachedDisplayXSpan_
    end
    
    events
        %NScopesMayHaveChanged
        DidSetScopeIsVisibleWhenDisplayEnabled
        %DidSetIsXSpanSlavedToAcquistionDuration        
        DidSetUpdateRate
        UpdateXSpan
        UpdateXOffset
        DataAdded
        DataCleared
    end

    methods
        function self = Display(parent)
            self@ws.Subsystem(parent) ;
            self.XOffset_ = 0;  % s
            self.XSpan_ = 1;  % s
            self.UpdateRate_ = 10;  % Hz
            self.XAutoScroll_ = false ;
            self.IsXSpanSlavedToAcquistionDuration_ = true ;
            self.IsAnalogChannelDisplayed_ = true(1,0) ; % 1 x nAIChannels
            self.IsDigitalChannelDisplayed_  = true(1,0) ; % 1 x nDIChannels
            self.AreYLimitsLockedTightToDataForAnalogChannel_ = false(1,0) ; % 1 x nAIChannels
            self.YLimitsPerAnalogChannel_ = zeros(2,0) ; % 2 x nAIChannels, 1st row is the lower limit, 2nd is the upper limit            
        end
        
        function delete(self)  %#ok<INUSD>
        end
        
        function result = get.NScopes(self)
            result = length(self.IsAnalogChannelDisplayed_) + length(self.IsDigitalChannelDisplayed_) ;
        end
        
        function value = get.UpdateRate(self)
            value = self.UpdateRate_;
        end
        
        function set.UpdateRate(self, newValue)
            if ws.isASettableValue(newValue) ,
                if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                    newValue = max(0.1,min(newValue,10)) ;
                    self.UpdateRate_ = newValue;
                else
                    self.broadcast('DidSetUpdateRate');
                    error('most:Model:invalidPropVal', ...
                          'UpdateRate must be a scalar finite positive number') ;
                end
            end
            self.broadcast('DidSetUpdateRate');
        end
        
        function value = get.XSpan(self)
            import ws.*
            if self.IsXSpanSlavedToAcquistionDuration ,
                value=1;  % s, fallback value
                wavesurferModel=self.Parent;
                if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                    return
                end
                duration=wavesurferModel.SweepDuration;
                value=fif(isfinite(duration),duration,1);
            else
                value = self.XSpan_;
            end
        end
        
        function set.XSpan(self, newValue)            
            if ws.isASettableValue(newValue) ,
                if self.IsXSpanSlavedToAcquistionDuration ,
                    % don't set anything
                else
                    if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                        self.XSpan_ = double(newValue);
                        % for idx = 1:numel(self.Scopes) ,
                        %     self.Scopes_{idx}.XSpan = self.XSpan;  % N.B.: _not_ = self.XSpan_ !!
                        % end
                    else
                        self.broadcast('UpdateXSpan');
                        error('most:Model:invalidPropVal', ...
                              'XSpan must be a scalar finite positive number') ;
                    end
                end
            end
            self.broadcast('UpdateXSpan');            
        end  % function
                
        function value = get.XOffset(self)
            value = self.XOffset_;
        end
                
        function set.XOffset(self, newValue)
            if ws.isASettableValue(newValue) ,
                if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                    self.XOffset_ = double(newValue);
                    % for idx = 1:numel(self.Scopes)
                    %     self.Scopes_{idx}.XOffset = newValue;
                    % end
                else
                    self.broadcast('UpdateXOffset');
                    error('most:Model:invalidPropVal', ...
                          'XOffset must be a scalar finite number') ;
                end
            end
            self.broadcast('UpdateXOffset');
        end
        
        function value = get.IsXSpanSlavedToAcquistionDuration(self)
            if self.Parent.AreSweepsContinuous ,
                value = false ;
            else
                value = self.IsXSpanSlavedToAcquistionDuration_;
            end
        end  % function
        
        function set.IsXSpanSlavedToAcquistionDuration(self,newValue)
            if self.IsXSpanSlavedToAcquistionDurationSettable ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && isfinite(newValue))) ,
                    self.IsXSpanSlavedToAcquistionDuration_ = logical(newValue) ;
                    % for idx = 1:numel(self.Scopes) ,
                    %     self.Scopes_{idx}.XSpan = self.XSpan;  % N.B.: _not_ = self.XSpan_ !!
                    % end
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'IsXSpanSlavedToAcquistionDuration must be a logical scalar, or convertible to one') ;
                end
            end
            self.broadcast('Update');            
        end
        
        function value = get.IsXSpanSlavedToAcquistionDurationSettable(self)
            value = self.Parent.AreSweepsFiniteDuration ;
        end  % function       
        
        function self=didSetAnalogChannelUnitsOrScales(self)
            self.broadcast('Update') ;
        end       
        
        function startingRun(self)
            self.XOffset = 0;
            self.XSpan = self.XSpan;  % in case user has zoomed in on one or more scopes, want to reset now
            self.XAutoScroll_ = (self.Parent.AreSweepsContinuous) ;
        end  % function
        
        function completingRun(self)
            self.completingOrStoppingOrAbortingRun_();
        end
        
        function stoppingRun(self)
            self.completingOrStoppingOrAbortingRun_();
        end
        
        function abortingRun(self)
            self.completingOrStoppingOrAbortingRun_();
        end
        
        function didAddAnalogInputChannel(self)
            self.IsAnalogChannelDisplayed_ = horzcat(self.IsAnalogChannelDisplayed_, true) ;
            self.AreYLimitsLockedTightToDataForAnalogChannel_ = horzcat(self.AreYLimitsLockedTightToDataForAnalogChannel_, false) ;
            self.YLimitsPerAnalogChannel_ = horzcat(self.YLimitsPerAnalogChannel_, [-10 +10]') ;
            self.broadcast('Update') ;
        end
        
        function didAddDigitalInputChannel(self)
            self.IsDigitalChannelDisplayed_(1,end+1) = true ;
            self.broadcast('Update') ;            
        end

        function didDeleteAnalogInputChannels(self, wasDeleted)
            wasKept = ~wasDeleted ;
            self.IsAnalogChannelDisplayed_ = self.IsAnalogChannelDisplayed_(wasKept) ;
            self.AreYLimitsLockedTightToDataForAnalogChannel_ = self.AreYLimitsLockedTightToDataForAnalogChannel_(wasKept) ;
            self.YLimitsPerAnalogChannel_ = self.YLimitsPerAnalogChannel_(:,wasKept) ;
            self.broadcast('Update') ;            
        end
        
        function didDeleteDigitalInputChannels(self, wasDeleted)            
            wasKept = ~wasDeleted ;
            self.IsDigitalChannelDisplayed_ = self.IsDigitalChannelDisplayed_(wasKept) ;
            self.broadcast('Update') ;            
        end
        
        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue)
            self.broadcast('UpdateControlProperties') ;            
        end
        
        function didSetDigitalInputChannelName(self, didSucceed, oldValue, newValue)
            self.broadcast('UpdateControlProperties') ;            
        end
        
        function toggleIsGridOn(self)
            self.IsGridOn = ~(self.IsGridOn) ;
        end

        function toggleAreColorsNormal(self)
            self.AreColorsNormal = ~(self.AreColorsNormal) ;
        end

        function toggleDoShowButtons(self)
            self.DoShowButtons = ~(self.DoShowButtons) ;
        end
        
        function set.IsGridOn(self,newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.IsGridOn_ = logical(newValue) ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'IsGridOn must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.IsGridOn(self)
            result = self.IsGridOn_ ;
        end
            
        function set.AreColorsNormal(self,newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.AreColorsNormal_ = logical(newValue) ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'AreColorsNormal must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.AreColorsNormal(self)
            result = self.AreColorsNormal_ ;
        end
            
        function set.DoShowButtons(self,newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.DoShowButtons_ = logical(newValue) ;
                else
                    self.broadcast('Update');
                    error('most:Model:invalidPropVal', ...
                          'DoShowButtons must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.DoShowButtons(self)
            result = self.DoShowButtons_ ;
        end                    
    end  % public methods block
    
    methods (Access=protected)
        function completingOrStoppingOrAbortingRun_(self)
            if ~isempty(self.CachedDisplayXSpan_)
                self.XSpan = self.CachedDisplayXSpan_;
            end
            self.CachedDisplayXSpan_ = [];
        end        
        
        function clearData_(self)
            self.broadcast('DataCleared') ;
        end
        
        function addData_(self, t, scaledAnalogData, rawDigitalData, sampleRate, xOffset)
            self.broadcast('DataAdded') ;
        end        
    end
        
    methods    
        function startingSweep(self)
            self.ClearOnNextData_ = true;
        end
         
        function dataAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)  %#ok<INUSL,INUSD>
            % t is a scalar, the time stamp of the scan *just after* the
            % most recent scan.  (I.e. it is one dt==1/fs into the future.
            % Queue Doctor Who music.)
            
            if self.ClearOnNextData_ ,
                self.clearData_() ;
            end            
            self.ClearOnNextData_ = false;
            
            % update the x offset
            if self.XAutoScroll_ ,                
                scale=min(1,self.XSpan);
                tNudged=scale*ceil(100*t/scale)/100;  % Helps keep the axes aligned to tidy numbers
                xOffsetNudged=tNudged-self.XSpan;
                if xOffsetNudged>self.XOffset ,
                    self.XOffset_=xOffsetNudged;
                end
            end

            % Add the data
            self.addData_(t, scaledAnalogData, rawDigitalData, self.Parent.Acquisition.SampleRate, self.XOffset_) ;
            
%             % Feed the data to the scopes
%             activeInputChannelNames=self.Parent.Acquisition.ActiveChannelNames;
%             isActiveChannelAnalog =  self.Parent.Acquisition.IsChannelAnalog(self.Parent.Acquisition.IsChannelActive);
%             for sdx = 1:numel(self.Scopes)
%                 % Figure out which channels go in this scope, and the
%                 % corresponding channel names
%                 % Although this looks like it might be slow, in practice it
%                 % takes negligible time compared to the call to
%                 % ScopeModel.addChannel() below.
%                 thisScope = self.Scopes{sdx} ;
%                 jInAnalogData = [];                
%                 jInDigitalData = [];                
%                 NActiveAnalogChannels = sum(self.Parent.Acquisition.IsAnalogChannelActive);
%                 for cdx = 1:length(activeInputChannelNames)
%                     channelName=activeInputChannelNames{cdx};
%                     if isequal(channelName, thisScope.ChannelName) ,
%                         if isActiveChannelAnalog(cdx)
%                             jInAnalogData(end + 1) = cdx; %#ok<AGROW>
%                         else
%                             jInDigitalData(end + 1) = cdx - NActiveAnalogChannels; %#ok<AGROW>
%                         end
%                     end
%                 end
%                 
%                 % Add the data for the appropriate channels to this scope
%                 if ~isempty(jInAnalogData) ,
%                     dataForThisScope = scaledAnalogData(:, jInAnalogData) ;
%                     thisScope.addData(t, dataForThisScope, self.Parent.Acquisition.SampleRate, self.XOffset_);
%                 end
%                 if ~isempty(jInDigitalData) ,
%                     dataForThisScope = double(bitget(rawDigitalData, jInDigitalData)) ;  % has to be double for ws.minMaxResampleMex()
%                     thisScope.addData(t, dataForThisScope, self.Parent.Acquisition.SampleRate, self.XOffset_);
%                 end
%             end
        end
        
        function didSetAreSweepsFiniteDuration(self)
            % Called by the parent to notify of a change to the acquisition
            % duration
            
            % Want any listeners on XSpan set to get called
            %if self.IsXSpanSlavedToAcquistionDuration ,
%             for idx = 1:numel(self.Scopes) ,
%                 self.Scopes_{idx}.XSpan = self.XSpan;  % N.B.: _not_ = self.XSpan_ !!
%             end
            self.broadcast('UpdateXSpan');
            %end    
            %self.XSpan = nan;
        end
        
        function didSetSweepDurationIfFinite(self)
            % Called by the parent to notify of a change to the acquisition
            % duration
            
            % Want any listeners on XSpan set to get called
            %if self.IsXSpanSlavedToAcquistionDuration ,
%             for idx = 1:numel(self.Scopes) ,
%                 self.Scopes_{idx}.XSpan = self.XSpan;  % N.B.: _not_ = self.XSpan_ !!
%             end
            self.broadcast('UpdateXSpan');
            %end    
            %self.XSpan = nan;
        end
        
%         function out = get.NScopes(self)
%             out = length(self.Scopes);
%         end
                
%         % Need to override the decodeProperties() method supplied by
%         % ws.Coding() to get correct behavior when the number of
%         % scopes changes.
%         function decodeProperties(self, propSet)
%             % Sets the properties in self to the values encoded in propSet.
%             % Returns the _old_ property values from self in
%             % originalValues.
%             
%             assert(isstruct(propSet));
%             
%             % Need to clear the existing scopes first
%             self.removeScopes();
%             
%             % Now call the superclass method
%             %originalValues=self.decodeProperties@ws.Coding(propSet);  % not _really_ the originalValues, but I don't think it matters...
%             self.decodeProperties@ws.Coding(propSet);  % not _really_ the originalValues, but I don't think it matters...
% 
%             % Update the view
%             self.broadcast('NScopesMayHaveChanged');
%         end  % function
        
%         function didSetScopeIsVisibleWhenDisplayEnabled(self)
%             self.broadcast('DidSetScopeIsVisibleWhenDisplayEnabled');
%         end
    end  % pulic methods block
    
%     methods (Access = protected)        
%         % Need to override the decodeUnwrappedEncodingCore_() method supplied
%         % by ws.Coding() to get correct behavior when the number of
%         % scopes changes.
%         function decodeUnwrappedEncodingCore_(self, encoding)            
%             % Need to clear the existing scopes first
%             self.removeScopes_();
%             
%             % Now call the superclass method
%             self.decodeUnwrappedEncodingCore_@ws.Coding(encoding);
% 
%             % Update the view
%             %self.broadcast('NScopesMayHaveChanged');  % do I need this?
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
        end  % function        
    end  % protected methods
    
%     methods (Static=true)
%         function tag=tagFromString(str)
%             % Transform an arbitrary ASCII string into a tag, which must be
%             % a valid Matlab identifier            
%             if isempty(str) ,
%                 tag=str;  % maybe should throw error, but they'll find out soon enough...
%                 return
%             end
%             
%             % Replace illegal chars with underscores
%             isAlphanumeric=isstrprop(str,'alphanum');
%             isUnderscore=(str=='_');
%             isIllegal= ~isAlphanumeric & ~isUnderscore;
%             temp=str;
%             temp(isIllegal)='_';
%             
%             % If first char is not alphabetic, replace with 'a'
%             isFirstCharAlphabetic=isstrprop(temp(1),'alpha');
%             if ~isFirstCharAlphabetic, 
%                 temp(1)='a';
%             end
%             
%             % Return the tag
%             tag=temp;
%         end  % function
%     end
    
%     methods
%         function mimic(self, other)
%             % Cause self to resemble other.
% 
%             % Disable broadcasts for speed
%             self.disableBroadcasts();
%             
%             % Get the list of property names for this file type
%             propertyNames = self.listPropertiesForPersistence();
%             
%             % Set each property to the corresponding one
%             for i = 1:length(propertyNames) ,
%                 thisPropertyName=propertyNames{i};
% %                 if any(strcmp(thisPropertyName,{'Scopes_'})) ,
% %                     source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination
% %                     target = ws.Coding.copyCellArrayOfHandlesGivenParent(source,self) ;
% %                     self.(thisPropertyName) = target ;
% %                 else
%                 if isprop(other,thisPropertyName) ,
%                     source = other.getPropertyValue_(thisPropertyName) ;
%                     self.setPropertyValue_(thisPropertyName, source) ;
%                 end
% %                 end
%             end
%             
%             % Re-enable broadcasts
%             self.enableBroadcastsMaybe();
% 
%             % Broadcast update
%             self.broadcast('Update');
%         end  % function
%     end  % public methods block
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct() ;
%         mdlHeaderExcludeProps = {};
%     end
        
end
