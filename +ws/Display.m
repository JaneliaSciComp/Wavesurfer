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
        XData
        YData
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
        XSpanInPixels_
        XData_
        YData_  % analog and digital together, all as doubles, but only for the *active* channels
    end
    
    events
        DidSetUpdateRate
        UpdateXSpan
        UpdateXOffset
        UpdateYAxisLimits
        UpdateData
        %DataAdded
        %DataCleared
        ItWouldBeNiceToKnowXSpanInPixels
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
            self.XSpanInPixels_ = 400 ;  % for when we're running headless, this is a reasonable fallback value
        end
        
        function delete(self)  %#ok<INUSD>
        end
        
        function result = get.NScopes(self)
            result = length(self.IsAnalogChannelDisplayed_) + length(self.IsDigitalChannelDisplayed_) ;
        end
        
        function result = get.XData(self)
            result = self.XData_ ;
        end
        
        function result = get.YData(self)
            result = self.YData_ ;
        end
        
        function result = get.AreYLimitsLockedTightToDataForAnalogChannel(self)
            result = self.AreYLimitsLockedTightToDataForAnalogChannel_ ;
        end
        
        function hereIsXSpanInPixels(self, xSpanInPixels)
            self.XSpanInPixels_ = xSpanInPixels ;
        end        
        
        function result = get.IsAnalogChannelDisplayed(self)
            result = self.IsAnalogChannelDisplayed_ ;
        end
        
        function toggleIsAnalogChannelDisplayed(self, aiChannelIndex) 
            if isnumeric(aiChannelIndex) && isscalar(aiChannelIndex) && isreal(aiChannelIndex) && (aiChannelIndex==round(aiChannelIndex))
                nAIChannels = self.Parent.Acquisition.NAnalogChannels ;
                if 1<=aiChannelIndex && aiChannelIndex<=nAIChannels ,
                    currentValue = self.IsAnalogChannelDisplayed_(aiChannelIndex) ;
                    self.IsAnalogChannelDisplayed_(aiChannelIndex) = ~currentValue ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('Update');
            if ~isValid ,
                error('most:Model:invalidPropVal', ...
                      'Argument to toggleIsAnalogChannelDisplayed must be a valid AI channel index') ;
            end                
        end
        
        function toggleIsDigitalChannelDisplayed(self, diChannelIndex) 
            if isnumeric(diChannelIndex) && isscalar(diChannelIndex) && isreal(diChannelIndex) && (diChannelIndex==round(diChannelIndex))
                nDIChannels = self.Parent.Acquisition.NDigitalChannels ;
                if 1<=diChannelIndex && diChannelIndex<=nDIChannels ,
                    currentValue = self.IsDigitalChannelDisplayed_(diChannelIndex) ;
                    self.IsDigitalChannelDisplayed_(diChannelIndex) = ~currentValue ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('Update');
            if ~isValid ,
                error('most:Model:invalidPropVal', ...
                      'Argument to toggleIsDigitalChannelDisplayed must be a valid DI channel index') ;
            end                
        end
        
        function result = get.IsDigitalChannelDisplayed(self)
            result = self.IsDigitalChannelDisplayed_ ;
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
        
        function value = get.YLimitsPerAnalogChannel(self)
            value = self.YLimitsPerAnalogChannel_ ;
        end

        function setYLimitsForSingleAnalogChannel(self, i, newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && newValue(1)<=newValue(2) ,
                self.YLimitsPerAnalogChannel_(:,i) = double(newValue') ;
                wasSet = true ;
            else
                wasSet = false ;
            end
            self.broadcast('Update') ;
            if ~wasSet ,
                error('most:Model:invalidPropVal', ...
                      'YLimitsPerAnalogChannel column must be 2 element numeric row vector, with the first element less than or equal to the second') ;
            end
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
        
        function didSetAnalogChannelUnitsOrScales(self)
            self.clearData_() ;
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
            self.clearData_() ;
            self.broadcast('Update') ;
        end
        
        function didAddDigitalInputChannel(self)
            self.IsDigitalChannelDisplayed_(1,end+1) = true ;
            self.clearData_() ;
            self.broadcast('Update') ;            
        end

        function didDeleteAnalogInputChannels(self, wasDeleted)
            wasKept = ~wasDeleted ;
            self.IsAnalogChannelDisplayed_ = self.IsAnalogChannelDisplayed_(wasKept) ;
            self.AreYLimitsLockedTightToDataForAnalogChannel_ = self.AreYLimitsLockedTightToDataForAnalogChannel_(wasKept) ;
            self.YLimitsPerAnalogChannel_ = self.YLimitsPerAnalogChannel_(:,wasKept) ;
            self.clearData_() ;
            self.broadcast('Update') ;            
        end
        
        function didDeleteDigitalInputChannels(self, wasDeleted)            
            wasKept = ~wasDeleted ;
            self.IsDigitalChannelDisplayed_ = self.IsDigitalChannelDisplayed_(wasKept) ;
            self.clearData_() ;
            self.broadcast('Update') ;            
        end
        
        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
            self.clearData_() ;
            self.broadcast('Update') ;            
        end
        
        function didSetDigitalInputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
            self.clearData_() ;
            self.broadcast('Update') ;            
        end
        
        function didSetIsInputChannelActive(self) 
            self.clearData_() ;
            self.broadcast('Update') ;            
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
        
        function scrollUp(self, aiChannelIndex)  % works on analog channels only
            if isnumeric(aiChannelIndex) && isscalar(aiChannelIndex) && isreal(aiChannelIndex) && (aiChannelIndex==round(aiChannelIndex)) ,
                nAIChannels = self.Parent.Acquisition.NAnalogChannels ;
                if 1<=aiChannelIndex && aiChannelIndex<=nAIChannels ,
                    yLimits = self.YLimitsPerAnalogChannel_(:,aiChannelIndex) ;  % NB: a 2-el col vector
                    yMiddle=mean(yLimits);
                    ySpan=diff(yLimits);
                    yRadius=0.5*ySpan;
                    newYLimits=(yMiddle+0.1*ySpan)+yRadius*[-1 +1]' ;
                    self.YLimitsPerAnalogChannel_(:,aiChannelIndex) = newYLimits ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', aiChannelIndex);
            if ~isValid ,
                error('most:Model:invalidPropVal', ...
                      'Argument to scrollUp() must be a valid AI channel index') ;
            end                
        end  % function
        
        function scrollDown(self, aiChannelIndex)  % works on analog channels only
            if isnumeric(aiChannelIndex) && isscalar(aiChannelIndex) && isreal(aiChannelIndex) && (aiChannelIndex==round(aiChannelIndex)) ,
                nAIChannels = self.Parent.Acquisition.NAnalogChannels ;
                if 1<=aiChannelIndex && aiChannelIndex<=nAIChannels ,
                    yLimits = self.YLimitsPerAnalogChannel_(:,aiChannelIndex) ;  % NB: a 2-el col vector
                    yMiddle=mean(yLimits);
                    ySpan=diff(yLimits);
                    yRadius=0.5*ySpan;
                    newYLimits=(yMiddle-0.1*ySpan)+yRadius*[-1 +1]' ;
                    self.YLimitsPerAnalogChannel_(:,aiChannelIndex) = newYLimits ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', aiChannelIndex);
            if ~isValid ,
                error('most:Model:invalidPropVal', ...
                      'Argument to scrollDown() must be a valid AI channel index') ;
            end                
        end  % function
                
        function zoomIn(self, aiChannelIndex)  % works on analog channels only
            if isnumeric(aiChannelIndex) && isscalar(aiChannelIndex) && isreal(aiChannelIndex) && (aiChannelIndex==round(aiChannelIndex)) ,
                nAIChannels = self.Parent.Acquisition.NAnalogChannels ;
                if 1<=aiChannelIndex && aiChannelIndex<=nAIChannels ,
                    yLimits = self.YLimitsPerAnalogChannel_(:,aiChannelIndex) ;  % NB: a 2-el col vector
                    yMiddle=mean(yLimits);
                    yRadius=0.5*diff(yLimits);
                    newYLimits=yMiddle+0.5*yRadius*[-1 +1]' ;
                    self.YLimitsPerAnalogChannel_(:,aiChannelIndex) = newYLimits ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', aiChannelIndex);
            if ~isValid ,
                error('most:Model:invalidPropVal', ...
                      'Argument to zoomIn() must be a valid AI channel index') ;
            end                
        end  % function
                
        function zoomOut(self, aiChannelIndex)  % works on analog channels only
            if isnumeric(aiChannelIndex) && isscalar(aiChannelIndex) && isreal(aiChannelIndex) && (aiChannelIndex==round(aiChannelIndex)) ,
                nAIChannels = self.Parent.Acquisition.NAnalogChannels ;
                if 1<=aiChannelIndex && aiChannelIndex<=nAIChannels ,
                    yLimits = self.YLimitsPerAnalogChannel_(:,aiChannelIndex) ;  % NB: a 2-el col vector
                    yMiddle=mean(yLimits);
                    yRadius=0.5*diff(yLimits);
                    newYLimits=yMiddle+2*yRadius*[-1 +1]' ;
                    self.YLimitsPerAnalogChannel_(:,aiChannelIndex) = newYLimits ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', aiChannelIndex);
            if ~isValid ,
                error('most:Model:invalidPropVal', ...
                      'Argument to zoomIn() must be a valid AI channel index') ;
            end                
        end  % function
                
        function setYAxisLimitsTightToData(self, aiChannelIndex)            
            if isnumeric(aiChannelIndex) && isscalar(aiChannelIndex) && isreal(aiChannelIndex) && (aiChannelIndex==round(aiChannelIndex)) ,
                nAIChannels = self.Parent.Acquisition.NAnalogChannels ;
                if 1<=aiChannelIndex && aiChannelIndex<=nAIChannels ,
                    self.setYAxisLimitsTightToData_(aiChannelIndex) ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', aiChannelIndex);
            if ~isValid ,
                error('most:Model:invalidPropVal', ...
                      'Argument to setYAxisLimitsTightToData() must be a valid AI channel index') ;
            end                
        end  % function

        function toggleAreYLimitsLockedTightToData(self, aiChannelIndex)
            currentValue = self.AreYLimitsLockedTightToDataForAnalogChannel_(aiChannelIndex) ;
            self.AreYLimitsLockedTightToDataForAnalogChannel_(aiChannelIndex) = ~currentValue ;
            self.setYAxisLimitsTightToData_(aiChannelIndex) ;  % this doesn't call .broadcast()
            self.broadcast('Update') ;  % Would be nice to be more surgical about this...
        end        
        
        function didSetAnalogInputTerminalID_(self)
            % This should only be called by the parent, hence the
            % underscore.
            self.clearData_() ;
            self.broadcast('UpdateData') ;
        end        
        
        function didSetDigitalInputTerminalID_(self)
            % This should only be called by the parent, hence the
            % underscore.
            self.clearData_() ;
            self.broadcast('UpdateData') ;
        end        
    end  % public methods block
    
    methods (Access=protected)        
        function setYAxisLimitsTightToData_(self, aiChannelIndex)            
            % this core function does no arg checking and doesn't call
            % .broadcast.  It just mutates the state.
            yMinAndMax=self.dataYMinAndMax_(aiChannelIndex);
            if any(~isfinite(yMinAndMax)) ,
                return
            end
            yCenter=mean(yMinAndMax);
            yRadius=0.5*diff(yMinAndMax);
            if yRadius==0 ,
                yRadius=0.001;
            end
            newYLimits = yCenter + 1.05*yRadius*[-1 +1]' ;
            self.YLimitsPerAnalogChannel_(:,aiChannelIndex) = newYLimits ;            
        end
        
        function yMinAndMax=dataYMinAndMax_(self, aiChannelIndex)
            % Min and max of the data, across all plotted channels.
            % Returns a 1x2 array.
            % If all channels are empty, returns [+inf -inf].
            indexWithinData = self.Parent.Acquisition.indexOfAnalogChannelWithinActiveAnalogChannels(aiChannelIndex) ;
            y = self.YData(:,indexWithinData) ;
            yMinRaw=min(y);
            yMin=ws.fif(isempty(yMinRaw),+inf,yMinRaw);
            yMaxRaw=max(y);
            yMax=ws.fif(isempty(yMaxRaw),-inf,yMaxRaw);            
            yMinAndMax=double([yMin yMax]);
        end
        
        function completingOrStoppingOrAbortingRun_(self)
            if ~isempty(self.CachedDisplayXSpan_)
                self.XSpan = self.CachedDisplayXSpan_;
            end
            self.CachedDisplayXSpan_ = [];
        end        
        
        function indicesOfAIChannelsNeedingYLimitUpdate = setYAxisLimitsTightToDataIfAreYLimitsLockedTightToData_(self)
            areYLimitsLockedTightToData = self.AreYLimitsLockedTightToDataForAnalogChannel_ ;
            nAIChannels = self.Parent.Acquisition.NAnalogChannels ;
            doesAIChannelNeedYLimitUpdate = false(1,nAIChannels) ;
            for i = 1:nAIChannels ,                
                if areYLimitsLockedTightToData(i) ,
                    doesAIChannelNeedYLimitUpdate(i) = true ;
                    self.setYAxisLimitsTightToData_(i) ;
                end
            end
            indicesOfAIChannelsNeedingYLimitUpdate = find(doesAIChannelNeedYLimitUpdate) ;
        end  % function
        
        function clearData_(self)
            self.XData_ = zeros(0,1) ;
            acquisition = self.Parent.Acquisition ;
            nActiveChannels = acquisition.NActiveAnalogChannels + acquisition.NActiveDigitalChannels ;
            self.YData_ = zeros(0,nActiveChannels) ;
        end
        
        function indicesOfAIChannelsNeedingYLimitUpdate = addData_(self, t, recentScaledAnalogData, recentRawDigitalData, sampleRate, xOffset)
            % t is a scalar, the time stamp of the scan *just after* the
            % most recent scan.  (I.e. it is one dt==1/fs into the future.
            % Queue Doctor Who music.)

            % Get the uint8/uint16/uint32 data out of recentRawDigitalData
            % into a matrix of logical data, then convert it to doubles and
            % concat it with the recentScaledAnalogData, storing the result
            % in yRecent.
            nActiveDigitalChannels = self.Parent.Acquisition.NActiveDigitalChannels ;
            if nActiveDigitalChannels==0 ,
                yRecent = recentScaledAnalogData ;
            else
                % Might need to write a mex function to quickly translate
                % recentRawDigitalData to recentDigitalData.
                nScans = size(recentRawDigitalData,1) ;                
                recentDigitalData = zeros(nScans,nActiveDigitalChannels) ;
                for j = 1:nActiveDigitalChannels ,
                    recentDigitalData(:,j) = bitget(recentRawDigitalData,j) ;
                end
                % End of code that might need to mex-ify
                yRecent = horzcat(recentScaledAnalogData, recentDigitalData) ;
            end
            
            % Compute a timeline for the new data            
            nNewScans = size(yRecent, 1) ;
            dt = 1/sampleRate ;  % s
            t0 = t - dt*nNewScans ;  % timestamp of first scan in newData
            xRecent = t0 + dt*(0:(nNewScans-1))' ;
            
            % Figure out the downsampling ratio
            self.broadcast('ItWouldBeNiceToKnowXSpanInPixels') ;
              % At this point, self.XSpanPixels_ should be set to the
              % correct value, or the fallback value if there's no view
            %xSpanInPixels=ws.ScopeFigure.getWidthInPixels(self.AxesGH_);
            xSpanInPixels = self.XSpanInPixels_ ;
            xSpan = self.XSpan ;
            r = ws.ratioSubsampling(dt, xSpan, xSpanInPixels) ;
            
            % Downsample the new data
            [xForPlottingNew, yForPlottingNew] = ws.minMaxDownsampleMex(xRecent, yRecent, r) ;            
            
            % deal with XData
            xAllOriginal = self.XData ;  % these are already downsampled
            yAllOriginal = self.YData ;            
            
            % Concatenate the old data that we're keeping with the new data
            xAllProto = vertcat(xAllOriginal, xForPlottingNew) ;
            yAllProto = vertcat(yAllOriginal, yForPlottingNew) ;
            
            % Trim off scans that would be off the screen anyway
            doKeepScan = (self.XOffset_<=xAllProto) ;
            xNew = xAllProto(doKeepScan) ;
            yNew = yAllProto(doKeepScan,:) ;

            % Commit the data to self
            self.XData_ = xNew ;
            self.YData_ = yNew ;
            
            % Update the x offset in the scope to match that in the Display
            % subsystem
            if xOffset ~= self.XOffset , 
                self.XOffset = xOffset ;
            end
            
            % Change the y limits to match the data, if appropriate
            indicesOfAIChannelsNeedingYLimitUpdate = self.setYAxisLimitsTightToDataIfAreYLimitsLockedTightToData_() ;
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
            
            if self.IsEnabled , 
                if self.ClearOnNextData_ ,
                    self.clearData_() ;
                    self.broadcast('UpdateData') ;
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
                indicesOfAIChannelsNeedingYLimitUpdate = self.addData_(t, scaledAnalogData, rawDigitalData, self.Parent.Acquisition.SampleRate, self.XOffset_) ;
                self.broadcast('UpdateData');       
                self.broadcast('UpdateYAxisLimits', indicesOfAIChannelsNeedingYLimitUpdate) ;
            else
                % if not active, do nothing
            end
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
