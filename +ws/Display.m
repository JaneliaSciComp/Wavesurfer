classdef Display < ws.Subsystem   %& ws.EventSubscriber
    %Display Manages the display
    
    properties (Dependent = true)
        UpdateRate  % the rate at which the scopes are updated, in Hz
        XOffset  % the x coord at the left edge of the scope windows
        XSpan  % the trace duration shown in the scope windows
        XSpanIfFree
        IsXSpanSlavedToSweepDuration
          % if true, the x span for all the scopes is set to the acquisiton
          % sweep duration
        IsXSpanSlavedToSweepDurationSettable
          % true iff IsXSpanSlavedToSweepDuration is currently
          % settable
        IsXSpanSlavedToSweepDurationIfFinite
        PlotModels  % a cell array of ws.ScopeModel objects
        NPlots
        IsGridOn
        AreColorsNormal        
        DoShowButtons        
    end

    properties (Access = protected)
        IsAnalogChannelShownWhenActive_
        IsDigitalChannelShownWhenActive_
        YLimitsPerAnalogChannel_
        %PlotModels_  % a cell array of ws.ScopeModel objects
        XSpanIfFree_ 
        UpdateRate_
        IsXSpanSlavedToSweepDurationIfFinite_
          % if true, the x span for all the scopes is set to the acquisiton
          % sweep duration
        IsGridOn_ = true
        AreColorsNormal_ = true  % if false, colors are inverted, approximately
        DoShowButtons_ = true % if false, don't show buttons in the figure  
    end
    
    properties (Access = protected, Transient=true)
        XAutoScroll_   % if true, x limits of all scopes will change to accomodate the data as it is acquired
        XOffset_
        ClearOnNextData_
        CachedDisplayXSpan_
        BufferFactor_ = 1        
    end
    
    events
        Update
        %DidSetScopeIsVisibleWhenDisplayEnabled
        %DidSetIsXSpanSlavedToSweepDuration        
        DidSetUpdateRate
        UpdateXSpan
        %ChannelAdded
        DataAdded
        DataCleared
        DidSetXUnits
        %WindowVisibilityNeedsToBeUpdated
        UpdateXAxisLimits
        UpdateYLimits
        %UpdateAreYLimitsLockedTightToData        
    end  % events

    
    methods
        function self = Display(parent)
            self@ws.Subsystem(parent) ;
            self.PlotModels_ = cell(1,0) ;
            self.XOffset_ = 0;  % s
            self.XSpanIfFree_ = 1;  % s
            self.UpdateRate_ = 10;  % Hz
            self.XAutoScroll_ = false ;
            self.IsXSpanSlavedToSweepDurationIfFinite_ = true ;
        end
        
        function delete(self)
            %self.removeScopes_();
            self.PlotModels_ = cell(1,0) ;
        end
        
        function value = get.UpdateRate(self)
            value = self.UpdateRate_;
        end
        
        function value = get.PlotModels(self)
            value = self.PlotModels_ ;
        end
        
        function set.UpdateRate(self, newValue)
            if ws.isASettableValue(newValue) ,
                if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                    newValue = max(0.1,min(newValue,10)) ;
                    self.UpdateRate_ = newValue;
                else
                    self.broadcast('DidSetUpdateRate');
                    error('ws:Model:invalidPropertyValue', ...
                          'UpdateRate must be a scalar finite positive number') ;
                end
            end
            self.broadcast('DidSetUpdateRate');
        end
        
        function value = get.XSpan(self)
            if self.IsXSpanSlavedToSweepDuration ,
                value = self.Parent.SweepDuration ;
            else
                value = self.XSpanIfFree ;  % piggy-back on this getter
            end
        end
        
        function set.XSpan(self, newValue)            
            if self.IsXSpanSlavedToSweepDuration ,
                % don't set anything
                self.broadcast('UpdateXSpan');
            else
                self.XSpanIfFree = newValue ;  % piggy-back on this setter
            end
        end  % function
        
        function value = get.XSpanIfFree(self)
            value = self.XSpanIfFree_;
        end
        
        function set.XSpanIfFree(self, newValue)            
            if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                isNewValueValid = true ;
                self.XSpanIfFree_ = double(newValue);
            else
                isNewValueValid = false ;
            end
            self.broadcast('UpdateXSpan');
            if ~isNewValueValid ,
                error('ws:Model:invalidPropertyValue', ...
                      'XSpanIfFree must be a scalar finite positive number') ;
            end
        end  % function
        
        function value = get.XOffset(self)
            value = self.XOffset_;
        end
                
        function set.XOffset(self, newValue)
            if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                isNewValueValid = true ;
                self.XOffset_ = double(newValue);
            else
                isNewValueValid = false ;
            end
            self.broadcast('Update');
            if ~isNewValueValid ,
                error('ws:Model:invalidPropertyValue', ...
                      'XOffset must be a scalar finite number') ;
            end
        end
        
        function value = get.IsXSpanSlavedToSweepDurationIfFinite(self)
            value = self.IsXSpanSlavedToSweepDurationIfFinite_ ;
        end
        
        function set.IsXSpanSlavedToSweepDurationIfFinite(self, newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && isfinite(newValue))) ,
                isNewValueValid = true ;
                self.IsXSpanSlavedToSweepDurationIfFinite_ = logical(newValue) ;
            else
                isNewValueValid = false ;
            end
            self.broadcast('Update');
            if ~isNewValueValid,
                error('ws:Model:invalidPropertyValue', ...
                      'IsXSpanSlavedToSweepDuration must be a logical scalar, or convertible to one') ;
            end
        end
        
        function value = get.IsXSpanSlavedToSweepDuration(self)
            if self.Parent.AreSweepsContinuous ,
                value = false ;
            else
                value = self.IsXSpanSlavedToSweepDurationIfFinite ;  % piggy-back on this getter
            end
        end  % function
        
        function set.IsXSpanSlavedToSweepDuration(self,newValue)
            if self.IsXSpanSlavedToSweepDurationSettable ,
                self.IsXSpanSlavedToSweepDuration = newValue ;  % piggy-back on this setter
            else
                self.broadcast('Update');
            end
        end
        
        function value = get.IsXSpanSlavedToSweepDurationSettable(self)
            value = self.Parent.AreSweepsFiniteDuration ;
        end  % function       
        
        function self=didSetAnalogChannelUnitsOrScales(self)
            self.clearData_() ;
        end
    end  % public methods block

    methods (Access=protected)
        function clearData_(self)
            nActiveChannels = self.NActiveChannels ;
            self.XData_ = zeros(0,1) ;
            self.YData_ = zeros(0,nActiveChannels) ;
            self.broadcast('DataCleared');
        end
    end
    
    methods
        function didSetDeviceName(self)  %#ok<MANU>
            % No need to do anything
        end
        
        function toggleIsAnalogChannelShownWhenActive(self, aiChannelIndex)
            originalValue = self.IsAnalogChannelShownWhenActive_(aiChannelIndex) ;
            self.IsAnalogChannelShownWhenActive_(aiChannelIndex) = ~originalValue ;
            broadcast('Update') ;            
        end
        
        function toggleIsDigitalChannelShownWhenActive(self, diChannelIndex)
            originalValue = self.IsDigitalChannelShownWhenActive_(diChannelIndex) ;
            self.IsDigitalChannelShownWhenActive_(diChannelIndex) = ~originalValue ;
            broadcast('Update') ;            
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
            self.IsAnalogChannelShownWhenActive_ = [self.IsAnalogChannelShownWhenActive_ true] ;
            self.YLimsPerAnalogChannel_ = [self.YLimsPerAnalogChannel_ ; ...
                                           -10 +10] ;
            self.broadcast('Update');            
        end
        
        function didAddDigitalInputChannel(self)
            self.IsDigitalChannelShownWhenActive_ = [self.IsDigitalChannelShownWhenActive_ true] ;
            self.broadcast('Update');            
        end

        function didDeleteAnalogInputChannels(self, isToBeDeleted)            
            self.IsAnalogChannelShownWhenActive_ = self.IsAnalogChannelShownWhenActive_(isToBeDeleted) ;
            self.YLimsPerAnalogChannel_ = self.YLimsPerAnalogChannel_(isToBeDeleted,:) ; ...
            self.broadcast('Update');                        
        end
        
        function didDeleteDigitalInputChannels(self, isToBeDeleted)            
            self.IsDigitalChannelShownWhenActive_ = self.IsDigitalChannelShownWhenActive_(isToBeDeleted) ;
            self.broadcast('Update');                        
        end
        
        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
            if didSucceed , 
                self.broadcast('UpdateChannelNames') ;
            end
        end
        
        function didSetDigitalInputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
            if didSucceed , 
                self.broadcast('UpdateChannelNames') ;
            end
        end
        
        function set.IsGridOn(self,newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                isNewValueValid = true ;
                self.IsGridOn_ = logical(newValue) ;
            else
                isNewValueValid = false ;
            end
            self.broadcast('Update');
            if ~isNewValueValid ,
                error('ws:Model:invalidPropertyValue', ...
                      'IsGridOn must be a scalar, and must be logical, 0, or 1');
            end
        end
        
        function result = get.IsGridOn(self)
            result = self.IsGridOn_ ;
        end
            
        function set.AreColorsNormal(self,newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.AreColorsNormal_ = logical(newValue) ;
                self.broadcast('Update');
            else
                self.broadcast('Update');
                error('ws:Model:invalidPropertyValue', ...
                      'AreColorsNormal must be a scalar, and must be logical, 0, or 1');
            end
        end
        
        function result = get.AreColorsNormal(self)
            result = self.AreColorsNormal_ ;
        end
            
        function set.DoShowButtons(self,newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.DoShowButtons_ = logical(newValue) ;
                self.broadcast('Update');
            else
                self.broadcast('Update');
                error('ws:Model:invalidPropertyValue', ...
                      'DoShowButtons must be a scalar, and must be logical, 0, or 1');
            end
        end
        
        function result = get.DoShowButtons(self)
            result = self.DoShowButtons_ ;
        end
        
        function zoomIn(self, indexOfAIChannel)
            yLimits=self.YLimitsPerAnalogChannel_(indexOfAIChannel,:);
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+0.5*yRadius*[-1 +1];
            self.YLimitsPerAnalogChannel_(indexOfAIChannel,:)=newYLimits;
            broadcast('UpdateYLimits', indexOfAIChannel) ;
        end  % function
        
        function zoomOut(self, indexOfAIChannel)
            yLimits=self.YLimitsPerAnalogChannel_(indexOfAIChannel,:);
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+2*yRadius*[-1 +1];
            self.YLimitsPerAnalogChannel_(indexOfAIChannel,:)=newYLimits;
            broadcast('UpdateYLimits', indexOfAIChannel) ;
        end  % function
        
        function scrollUp(self, indexOfAIChannel)
            yLimits=self.YLimitsPerAnalogChannel_(indexOfAIChannel,:);
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle+0.1*ySpan)+yRadius*[-1 +1];
            self.YLimitsPerAnalogChannel_(indexOfAIChannel,:)=newYLimits;
            broadcast('UpdateYLimits', indexOfAIChannel) ;
        end  % function
        
        function scrollDown(self, indexOfAIChannel)
            yLimits=self.YLimitsPerAnalogChannel_(indexOfAIChannel,:);
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle-0.1*ySpan)+yRadius*[-1 +1];
            self.YLimitsPerAnalogChannel_(indexOfAIChannel,:)=newYLimits;
            broadcast('UpdateYLimits', indexOfAIChannel) ;
        end  % function
        
    end  % public methods block
    
    methods (Access=protected)        
        function completingOrStoppingOrAbortingRun_(self)
            if ~isempty(self.CachedDisplayXSpan_)
                self.XSpan = self.CachedDisplayXSpan_;
            end
            self.CachedDisplayXSpan_ = [];
        end        
    end
        
    methods
        function startingSweep(self)
            self.ClearOnNextData_ = true;
        end
        
        function dataAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSL,INUSD>
            % Called by the WSM to notify us that new data is available.            
            % t is the timestamp of the sample just past the latest sample
            % in rawAnalogData, rawDigitalData.
            
            % Clear the existing data, if e.g. this is first data of a
            % new sweep
            if self.ClearOnNextData_ ,
                self.clearData_() ;
            end            
            self.ClearOnNextData_ = false;
            
            % Update the x offset
            xSpan = self.XSpan ;
            xOffset = self.XOffset ;
            if self.XAutoScroll_ ,
                spansAhead = floor((t-xOffset)/xSpan) ;
                if spansAhead>0 ,
                    self.XOffset_ = xOffset + spansAhead*xSpan ;
                end
            end

            % 
            
            % Feed the data to the scopes
            activeInputChannelNames=self.Parent.Acquisition.ActiveChannelNames;
            isActiveChannelAnalog =  self.Parent.Acquisition.IsChannelAnalog(self.Parent.Acquisition.IsChannelActive);
            for sdx = 1:numel(self.PlotModels)
                % Figure out which channels go in this scope, and the
                % corresponding channel names
                % Although this looks like it might be slow, in practice it
                % takes negligible time compared to the call to
                % ScopeModel.addChannel() below.
                %TInner=zeros(1,2);
                %ticId2=tic();
                channelNamesForThisScope = cell(1,0);
                jInAnalogData = [];                
                jInDigitalData = [];                
                NActiveAnalogChannels = sum(self.Parent.Acquisition.IsAnalogChannelActive);
                for cdx = 1:length(activeInputChannelNames)
                    %channelName = sprintf('Acq_%d', inputTerminalIDs(cdx));
                    channelName=activeInputChannelNames{cdx};
                    if any(strcmp(channelName, self.PlotModels{sdx}.ChannelNames)) ,
                        channelNamesForThisScope{end + 1} = channelName; %#ok<AGROW>
                        if isActiveChannelAnalog(cdx)
                            jInAnalogData(end + 1) = cdx; %#ok<AGROW>
                        else
                            jInDigitalData(end + 1) = cdx - NActiveAnalogChannels; %#ok<AGROW>
                        end
                    end
                end
                
                % Add the data for the appropriate channels to this scope
                if ~isempty(jInAnalogData) ,
                    dataForThisScope=scaledAnalogData(:, jInAnalogData);
                    self.PlotModels{sdx}.addData(channelNamesForThisScope, dataForThisScope, self.Parent.Acquisition.SampleRate, self.XOffset_);
                end
                if ~isempty(jInDigitalData) ,
                    dataForThisScope=bitget(rawDigitalData, jInDigitalData);
                    self.PlotModels{sdx}.addData(channelNamesForThisScope, dataForThisScope, self.Parent.Acquisition.SampleRate, self.XOffset_);
                end
            end
        end
        
        function didSetAreSweepsFiniteDuration(self)
            % Called by the parent to notify of a change to the acquisition
            % duration
            self.broadcast('UpdateXSpan');
        end
        
        function didSetSweepDurationIfFinite(self)
            % Called by the parent to notify of a change to the acquisition
            % duration
            self.broadcast('UpdateXSpan');
        end
    end  % pulic methods block
        
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
        
end
