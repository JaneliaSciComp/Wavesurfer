classdef Display < ws.Subsystem   %& ws.EventSubscriber
    % Display manages the display and update of one or more Scope objects.
    
    properties (Dependent = true)
        IsGridOn
        AreColorsNormal        
        DoShowButtons        
        DoColorTraces
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
        NPlots
        %XData
        %YData
        PlotHeightFromAnalogChannelIndex  % 1 x nAIChannels
        PlotHeightFromDigitalChannelIndex  % 1 x nDIChannels
        PlotHeightFromChannelIndex  % 1 x nChannels
        RowIndexFromAnalogChannelIndex  % 1 x nAIChannels
        RowIndexFromDigitalChannelIndex  % 1 x nDIChannels
        ChannelIndexWithinTypeFromPlotIndex  % 1 x NPlots
        IsAnalogFromPlotIndex  % 1 x NPlots
        ChannelIndexFromPlotIndex  % 1 x NPlots       
        PlotIndexFromChannelIndex  % 1 x nChannels
        PlotHeightFromPlotIndex  % 1 x NPlots
    end

    properties (Access = protected)
        IsGridOn_ = true
        AreColorsNormal_ = true  % if false, colors are inverted, approximately
        DoShowButtons_ = true % if false, don't show buttons in the figure
        DoColorTraces_ = true % if false, traces are black/white
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
        PlotHeightFromAnalogChannelIndex_  % 1 x nAIChannels
        PlotHeightFromDigitalChannelIndex_  % 1 x nDIChannels
        RowIndexFromAnalogChannelIndex_  % 1 x nAIChannels
        RowIndexFromDigitalChannelIndex_  % 1 x nDIChannels
    end
    
    properties (Access = protected, Transient=true)
        XOffset_
        ClearOnNextData_
        CachedDisplayXSpan_
        XSpanInPixels_
        %XData_
        %YData_  % analog and digital together, all as doubles, but only for the *active* channels
        ChannelIndexWithinTypeFromPlotIndex_  % 1 x NPlots
        IsAnalogFromPlotIndex_  % 1 x NPlots
        ChannelIndexFromPlotIndex_  % 1 x NPlots (the channel index is in the list of all analog, then all digital, channels)
        PlotIndexFromChannelIndex_ % 1 x nChannels (this has nan's for channels that are not displayed)
    end
    
    events
        DidSetUpdateRate
        UpdateXSpan
        UpdateXOffset
        UpdateYAxisLimits
        %UpdateData
        ClearData
        %ItWouldBeNiceToKnowXSpanInPixels
        AddData
    end

    methods
        function self = Display(parent)
            self@ws.Subsystem(parent) ;
            self.XOffset_ = 0 ;  % s
            self.XSpan_ = 1 ;  % s
            self.UpdateRate_ = 10 ;  % Hz
            self.XAutoScroll_ = false ;
            self.IsXSpanSlavedToAcquistionDuration_ = true ;
            self.IsAnalogChannelDisplayed_ = true(1,0) ; % 1 x nAIChannels
            self.IsDigitalChannelDisplayed_  = true(1,0) ; % 1 x nDIChannels
            self.AreYLimitsLockedTightToDataForAnalogChannel_ = false(1,0) ; % 1 x nAIChannels
            self.YLimitsPerAnalogChannel_ = zeros(2,0) ; % 2 x nAIChannels, 1st row is the lower limit, 2nd is the upper limit            
            self.XSpanInPixels_ = 400 ;  % for when we're running headless, this is a reasonable fallback value
            self.PlotHeightFromAnalogChannelIndex_ = zeros(1,0) ;
            self.PlotHeightFromDigitalChannelIndex_ = zeros(1,0) ;
            self.RowIndexFromAnalogChannelIndex_ = zeros(1,0) ;  % 1 x nAIChannels
            self.RowIndexFromDigitalChannelIndex_ = zeros(1,0) ;  % 1 x nDIChannels     
            self.updateMappingsFromPlotIndices_() ;
        end
        
        function delete(self)  %#ok<INUSD>
        end
        
        function result = get.NPlots(self)
            result = length(self.IsAnalogChannelDisplayed_) + length(self.IsDigitalChannelDisplayed_) ;
        end
        
%         function result = get.XData(self)
%             result = self.XData_ ;
%         end
%         
%         function result = get.YData(self)
%             result = self.YData_ ;
%         end
        
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
                    self.updateMappingsFromPlotIndices_() ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('Update');
            if ~isValid ,
                error('ws:invalidPropertyValue', ...
                      'Argument to toggleIsAnalogChannelDisplayed must be a valid AI channel index') ;
            end                
        end
        
        function toggleIsDigitalChannelDisplayed(self, diChannelIndex) 
            if isnumeric(diChannelIndex) && isscalar(diChannelIndex) && isreal(diChannelIndex) && (diChannelIndex==round(diChannelIndex))
                nDIChannels = self.Parent.Acquisition.NDigitalChannels ;
                if 1<=diChannelIndex && diChannelIndex<=nDIChannels ,
                    currentValue = self.IsDigitalChannelDisplayed_(diChannelIndex) ;
                    self.IsDigitalChannelDisplayed_(diChannelIndex) = ~currentValue ;
                    self.updateMappingsFromPlotIndices_() ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('Update');
            if ~isValid ,
                error('ws:invalidPropertyValue', ...
                      'Argument to toggleIsDigitalChannelDisplayed must be a valid DI channel index') ;
            end                
        end
        
        function result = get.IsDigitalChannelDisplayed(self)
            result = self.IsDigitalChannelDisplayed_ ;
        end

        function result = get.PlotHeightFromAnalogChannelIndex(self)
            result = self.PlotHeightFromAnalogChannelIndex_ ;
        end
        
        function result = get.PlotHeightFromDigitalChannelIndex(self)
            result = self.PlotHeightFromDigitalChannelIndex_ ;
        end
        
        function result = get.PlotHeightFromChannelIndex(self)
            result = horzcat(self.PlotHeightFromAnalogChannelIndex_, self.PlotHeightFromDigitalChannelIndex_) ;
        end

        function result = get.PlotHeightFromPlotIndex(self)
            plotHeightFromChannelIndex = self.PlotHeightFromChannelIndex ;
            result = plotHeightFromChannelIndex(self.ChannelIndexFromPlotIndex) ;
        end
        
        function result = get.RowIndexFromAnalogChannelIndex(self)
            result = self.RowIndexFromAnalogChannelIndex_ ;
        end
        
        function result = get.RowIndexFromDigitalChannelIndex(self)
            result = self.RowIndexFromDigitalChannelIndex_ ;
        end
        
        function result = get.ChannelIndexWithinTypeFromPlotIndex(self)
            result = self.ChannelIndexWithinTypeFromPlotIndex_ ;
        end

        function result = get.ChannelIndexFromPlotIndex(self)
            result = self.ChannelIndexFromPlotIndex_ ;
        end

        function result = get.PlotIndexFromChannelIndex(self)
            result = self.PlotIndexFromChannelIndex_ ;
        end
        
        function result = get.IsAnalogFromPlotIndex(self)
            result = self.IsAnalogFromPlotIndex_ ;
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
                    error('ws:invalidPropertyValue', ...
                          'UpdateRate must be a scalar finite positive number') ;
                end
            end
            self.broadcast('DidSetUpdateRate');
        end
        
        function value = get.XSpan(self)
            if self.IsXSpanSlavedToAcquistionDuration ,
                wavesurferModel = self.Parent ;
                if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                    value = 1 ;  % s, fallback value
                else
                    sweepDuration = wavesurferModel.SweepDuration ;
                    value = ws.fif(isfinite(sweepDuration), sweepDuration, 1) ;
                end
            else
                value = self.XSpan_ ;
            end
        end
        
        function set.XSpan(self, newValue)            
            if self.IsXSpanSlavedToAcquistionDuration ,
                % don't set anything
                didSucceed = true ;  % this is by convention
            else
                if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                    self.XSpan_ = double(newValue);
                    %self.clearData_() ;
                    self.broadcast('ClearData') ;
                    didSucceed = true ;
                else
                    didSucceed = false ;
                end
            end
            self.broadcast('UpdateXSpan');
            if ~didSucceed ,
                error('ws:invalidPropertyValue', ...
                      'XSpan must be a scalar finite positive number') ;
            end                
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
                    error('ws:invalidPropertyValue', ...
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
                error('ws:invalidPropertyValue', ...
                      'YLimitsPerAnalogChannel column must be 2 element numeric row vector, with the first element less than or equal to the second') ;
            end
        end
        
        function setYLimitsForSingleAnalogChannel_(self, i, newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && newValue(1)<=newValue(2) ,
                self.YLimitsPerAnalogChannel_(:,i) = double(newValue') ;
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
                    isNewValueAllowed = true ;
                    self.IsXSpanSlavedToAcquistionDuration_ = logical(newValue) ;
                    %self.clearData_() ; 
                    self.broadcast('ClearData');
                else
                    isNewValueAllowed = false ;
                end
            else
                isNewValueAllowed = true ;  % sort of in a trivial sense...
            end
            self.broadcast('Update');            
            if ~isNewValueAllowed ,
                error('ws:invalidPropertyValue', ...
                      'IsXSpanSlavedToAcquistionDuration must be a logical scalar, or convertible to one') ;
            end                
        end
        
        function value = get.IsXSpanSlavedToAcquistionDurationSettable(self)
            value = self.Parent.AreSweepsFiniteDuration ;
        end  % function       
        
        function didSetAnalogChannelUnitsOrScales(self)
            %self.clearData_() ;
            self.broadcast('ClearData') ;
            self.broadcast('Update') ;
        end       
        
        function startingRun(self)
            self.XOffset = 0;
            %self.XSpan = self.XSpan;  % in case user has zoomed in on one or more scopes, want to reset now
            %self.XAutoScroll_ = (self.Parent.AreSweepsContinuous) ;
            self.XAutoScroll_ = (self.XSpan<self.Parent.Acquisition.Duration) ;
            self.broadcast('ClearData') ;
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
            self.PlotHeightFromAnalogChannelIndex_ = horzcat(self.PlotHeightFromAnalogChannelIndex_, 1) ;
            nRowsBefore = length(self.RowIndexFromAnalogChannelIndex_) + length(self.RowIndexFromDigitalChannelIndex_) ;
            self.RowIndexFromAnalogChannelIndex_ = horzcat(self.RowIndexFromAnalogChannelIndex_, nRowsBefore+1) ;
            self.updateMappingsFromPlotIndices_() ;
            self.broadcast('ClearData') ;
            self.broadcast('Update') ;
        end
         
        function didAddDigitalInputChannel(self)
            self.IsDigitalChannelDisplayed_(1,end+1) = true ;
            self.PlotHeightFromDigitalChannelIndex_ = horzcat(self.PlotHeightFromDigitalChannelIndex_, 1) ;
            nRowsBefore = length(self.RowIndexFromAnalogChannelIndex_) + length(self.RowIndexFromDigitalChannelIndex_) ;
            self.RowIndexFromDigitalChannelIndex_ = horzcat(self.RowIndexFromDigitalChannelIndex_, nRowsBefore+1) ;
            self.updateMappingsFromPlotIndices_() ;
            %self.clearData_() ;
            self.broadcast('ClearData') ;
            self.broadcast('Update') ;            
        end

        function didDeleteAnalogInputChannels(self, wasDeleted)
            wasKept = ~wasDeleted ;
            self.IsAnalogChannelDisplayed_ = self.IsAnalogChannelDisplayed_(wasKept) ;
            self.AreYLimitsLockedTightToDataForAnalogChannel_ = self.AreYLimitsLockedTightToDataForAnalogChannel_(wasKept) ;
            self.YLimitsPerAnalogChannel_ = self.YLimitsPerAnalogChannel_(:,wasKept) ;
            self.PlotHeightFromAnalogChannelIndex_ = self.PlotHeightFromAnalogChannelIndex_(wasKept) ;
            self.RowIndexFromAnalogChannelIndex_ = self.RowIndexFromAnalogChannelIndex_(wasKept) ;
            [self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_] = ...
                ws.Display.renormalizeRowIndices(self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_) ;            
            self.updateMappingsFromPlotIndices_() ;
            %self.clearData_() ;
            self.broadcast('ClearData') ;
            self.broadcast('Update') ;            
        end
        
        function didDeleteDigitalInputChannels(self, wasDeleted)            
            wasKept = ~wasDeleted ;
            self.IsDigitalChannelDisplayed_ = self.IsDigitalChannelDisplayed_(wasKept) ;
            self.PlotHeightFromDigitalChannelIndex_ = self.PlotHeightFromDigitalChannelIndex_(wasKept) ;
            self.RowIndexFromDigitalChannelIndex_ = self.RowIndexFromDigitalChannelIndex_(wasKept) ;
            [self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_] = ...
                ws.Display.renormalizeRowIndices(self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_) ;            
            self.updateMappingsFromPlotIndices_() ;
            %self.clearData_() ;
            self.broadcast('ClearData') ;
            self.broadcast('Update') ;            
        end
        
        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
            %self.clearData_() ;
            self.broadcast('ClearData') ;
            self.broadcast('Update') ;            
        end
        
        function didSetDigitalInputChannelName(self, didSucceed, oldValue, newValue) %#ok<INUSD>
            %self.clearData_() ;
            self.broadcast('ClearData') ;
            self.broadcast('Update') ;            
        end
        
        function didSetIsInputChannelActive(self) 
            %self.clearData_() ;
            self.broadcast('ClearData') ;
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
        
        function toggleDoColorTraces(self)
            self.DoColorTraces = ~(self.DoColorTraces) ;
        end
        
        function set.IsGridOn(self,newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.IsGridOn_ = logical(newValue) ;
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
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
                    error('ws:invalidPropertyValue', ...
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
                    error('ws:invalidPropertyValue', ...
                          'DoShowButtons must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.DoShowButtons(self)
            result = self.DoShowButtons_ ;
        end                    
        
        function set.DoColorTraces(self,newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.DoColorTraces_ = logical(newValue) ;
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
                          'DoColorTraces must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.DoColorTraces(self)
            result = self.DoColorTraces_ ;
        end                    
        
        function scrollUp(self, plotIndex)  % works on analog channels only
            if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,
                isAnalogFromPlotIndex = self.IsAnalogFromPlotIndex_ ;
                nPlots = length(isAnalogFromPlotIndex) ;
                if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
                    channelIndex = self.ChannelIndexWithinTypeFromPlotIndex_(plotIndex) ;
                    yLimits = self.YLimitsPerAnalogChannel_(:,channelIndex) ;  % NB: a 2-el col vector
                    yMiddle=mean(yLimits);
                    ySpan=diff(yLimits);
                    yRadius=0.5*ySpan;
                    newYLimits=(yMiddle+0.1*ySpan)+yRadius*[-1 +1]' ;
                    self.YLimitsPerAnalogChannel_(:,channelIndex) = newYLimits ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', plotIndex, channelIndex);
            if ~isValid ,
                error('ws:invalidPropertyValue', ...
                      'Argument to scrollUp() must be a valid AI channel index') ;
            end                
        end  % function
        
        function scrollDown(self, plotIndex)  % works on analog channels only
            if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,
                isAnalogFromPlotIndex = self.IsAnalogFromPlotIndex_ ;
                nPlots = length(isAnalogFromPlotIndex) ;
                if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
                    channelIndex = self.ChannelIndexWithinTypeFromPlotIndex_(plotIndex) ;
                    yLimits = self.YLimitsPerAnalogChannel_(:,channelIndex) ;  % NB: a 2-el col vector
                    yMiddle=mean(yLimits);
                    ySpan=diff(yLimits);
                    yRadius=0.5*ySpan;
                    newYLimits=(yMiddle-0.1*ySpan)+yRadius*[-1 +1]' ;
                    self.YLimitsPerAnalogChannel_(:,channelIndex) = newYLimits ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', plotIndex, channelIndex);
            if ~isValid ,
                error('ws:invalidPropertyValue', ...
                      'Argument to scrollDown() must be a valid AI channel index') ;
            end                
        end  % function
                
        function zoomIn(self, plotIndex)  % works on analog channels only
            if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,
                isAnalogFromPlotIndex = self.IsAnalogFromPlotIndex_ ;
                nPlots = length(isAnalogFromPlotIndex) ;
                if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
                    channelIndex = self.ChannelIndexWithinTypeFromPlotIndex_(plotIndex) ;
                    yLimits = self.YLimitsPerAnalogChannel_(:,channelIndex) ;  % NB: a 2-el col vector
                    yMiddle=mean(yLimits);
                    yRadius=0.5*diff(yLimits);
                    newYLimits=yMiddle+0.5*yRadius*[-1 +1]' ;
                    self.YLimitsPerAnalogChannel_(:,channelIndex) = newYLimits ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', plotIndex, channelIndex);
            if ~isValid ,
                error('ws:invalidPropertyValue', ...
                      'Argument to zoomIn() must be a valid AI channel index') ;
            end                
        end  % function
                
        function zoomOut(self, plotIndex)  % works on analog channels only
            if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,
                isAnalogFromPlotIndex = self.IsAnalogFromPlotIndex_ ;
                nPlots = length(isAnalogFromPlotIndex) ;
                if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
                    channelIndex = self.ChannelIndexWithinTypeFromPlotIndex_(plotIndex) ;
                    yLimits = self.YLimitsPerAnalogChannel_(:,channelIndex) ;  % NB: a 2-el col vector
                    yMiddle=mean(yLimits);
                    yRadius=0.5*diff(yLimits);
                    newYLimits=yMiddle+2*yRadius*[-1 +1]' ;
                    self.YLimitsPerAnalogChannel_(:,channelIndex) = newYLimits ;
                    isValid = true ;
                else
                    isValid = false ;
                end
            else
                isValid = false ;
            end
            self.broadcast('UpdateYAxisLimits', plotIndex, channelIndex);
            if ~isValid ,
                error('ws:invalidPropertyValue', ...
                      'Argument to zoomIn() must be a valid AI channel index') ;
            end                
        end  % function
                
%         function setYAxisLimitsTightToData(self, plotIndex)            
%             if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,
%                 isAnalogFromPlotIndex = self.IsAnalogFromPlotIndex_ ;
%                 nPlots = length(isAnalogFromPlotIndex) ;
%                 if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
%                     channelIndex = self.ChannelIndexWithinTypeFromPlotIndex_(plotIndex) ;
%                     self.setYAxisLimitsTightToData_(channelIndex) ;
%                     isValid = true ;
%                 else
%                     isValid = false ;
%                 end
%             else
%                 isValid = false ;
%             end
%             self.broadcast('UpdateYAxisLimits', plotIndex, channelIndex);
%             if ~isValid ,
%                 error('ws:invalidPropertyValue', ...
%                       'Argument to setYAxisLimitsTightToData() must be a valid AI channel index') ;
%             end                
%         end  % function

        function setAreAreYLimitsLockedTightToDataForSingleChannel_(self, channelIndex, newValue)            
            self.AreYLimitsLockedTightToDataForAnalogChannel_(channelIndex) = newValue ;
        end        
        
        function didSetAnalogInputTerminalID_(self)
            % This should only be called by the parent, hence the
            % underscore.
            %self.clearData_() ;
            self.broadcast('ClearData') ;
        end        
        
        function didSetDigitalInputTerminalID_(self)
            % This should only be called by the parent, hence the
            % underscore.
            %self.clearData_() ;
            self.broadcast('ClearData') ;
        end
        
        function setPlotHeightsAndOrder(self, isDisplayed, plotHeights, rowIndexFromChannelIndex)
            % Typically called by ws.PlotArrangementDialogFigure after OK
            % button is pressed.  Does no argument checking.
            nAIChannels = length(self.IsAnalogChannelDisplayed_) ;
            % Set properties
            
            % We'll need to decide whether to clear the displayed traces or
            % not.  We do this only if the height of one or more plots is
            % changing.  To determine whether this is the case, we need to
            % cache the original values of some things, and compare them to
            % the new values.
            oldIsAnalogChannelDisplayed = self.IsAnalogChannelDisplayed_ ;
            oldIsDigitalChannelDisplayed = self.IsDigitalChannelDisplayed_ ;
            oldPlotHeightFromAnalogChannelIndex = self.PlotHeightFromAnalogChannelIndex_ ;
            oldPlotHeightFromDigitalChannelIndex = self.PlotHeightFromDigitalChannelIndex_ ;
            newIsAnalogChannelDisplayed = isDisplayed(1:nAIChannels) ;
            newIsDigitalChannelDisplayed = isDisplayed(nAIChannels+1:end) ;
            newPlotHeightFromAnalogChannelIndex = plotHeights(1:nAIChannels) ;
            newPlotHeightFromDigitalChannelIndex = plotHeights(nAIChannels+1:end) ;
            doNeedToClearData = ~isequal(newIsAnalogChannelDisplayed, oldIsAnalogChannelDisplayed) || ...
                                ~isequal(newIsDigitalChannelDisplayed, oldIsDigitalChannelDisplayed) || ...
                                ~isequal(newPlotHeightFromAnalogChannelIndex, oldPlotHeightFromAnalogChannelIndex) || ...
                                ~isequal(newPlotHeightFromDigitalChannelIndex, oldPlotHeightFromDigitalChannelIndex) ;
                            
            % OK, now we can actually set instance variables                
            self.IsAnalogChannelDisplayed_ = newIsAnalogChannelDisplayed ;
            self.IsDigitalChannelDisplayed_ = newIsDigitalChannelDisplayed ;
            self.PlotHeightFromAnalogChannelIndex_ = newPlotHeightFromAnalogChannelIndex ;
            self.PlotHeightFromDigitalChannelIndex_ = newPlotHeightFromDigitalChannelIndex ;
            self.RowIndexFromAnalogChannelIndex_ = rowIndexFromChannelIndex(1:nAIChannels) ;
            self.RowIndexFromDigitalChannelIndex_ = rowIndexFromChannelIndex(nAIChannels+1:end) ;
            self.updateMappingsFromPlotIndices_() ;
            if doNeedToClearData ,
                self.broadcast('ClearData') ;
            end
            self.broadcast('Update') ;            
        end
    end  % public methods block
    
    methods (Access=protected)        
%         function setYAxisLimitsTightToData_(self, aiChannelIndex)            
%             % this core function does no arg checking and doesn't call
%             % .broadcast.  It just mutates the state.
%             yMinAndMax=self.dataYMinAndMax_(aiChannelIndex);
%             if any(~isfinite(yMinAndMax)) ,
%                 return
%             end
%             yCenter=mean(yMinAndMax);
%             yRadius=0.5*diff(yMinAndMax);
%             if yRadius==0 ,
%                 yRadius=0.001;
%             end
%             newYLimits = yCenter + 1.05*yRadius*[-1 +1]' ;
%             self.YLimitsPerAnalogChannel_(:,aiChannelIndex) = newYLimits ;            
%         end
%         
%         function yMinAndMax=dataYMinAndMax_(self, aiChannelIndex)
%             % Min and max of the data, across all plotted channels.
%             % Returns a 1x2 array.
%             % If all channels are empty, returns [+inf -inf].
%             activeChannelIndexFromChannelIndex = self.Parent.Acquisition.ActiveChannelIndexFromChannelIndex ;
%             indexWithinData = activeChannelIndexFromChannelIndex(aiChannelIndex) ;
%             y = self.YData(:,indexWithinData) ;
%             yMinRaw=min(y);
%             yMin=ws.fif(isempty(yMinRaw),+inf,yMinRaw);
%             yMaxRaw=max(y);
%             yMax=ws.fif(isempty(yMaxRaw),-inf,yMaxRaw);            
%             yMinAndMax=double([yMin yMax]);
%         end
        
        function completingOrStoppingOrAbortingRun_(self)
            if ~isempty(self.CachedDisplayXSpan_)
                self.XSpan = self.CachedDisplayXSpan_;
            end
            self.CachedDisplayXSpan_ = [];
        end        
                
%         function clearData_(self)
%             self.XData_ = zeros(0,1) ;
%             acquisition = self.Parent.Acquisition ;
%             nActiveChannels = acquisition.NActiveAnalogChannels + acquisition.NActiveDigitalChannels ;
%             self.YData_ = zeros(0,nActiveChannels) ;
%         end
%         
%         function indicesOfAIChannelsNeedingYLimitUpdate = addData_(self, t, recentScaledAnalogData, recentRawDigitalData, sampleRate)
%             % t is a scalar, the time stamp of the scan *just after* the
%             % most recent scan.  (I.e. it is one dt==1/fs into the future.
%             % Queue Doctor Who music.)
% 
%             % Get the uint8/uint16/uint32 data out of recentRawDigitalData
%             % into a matrix of logical data, then convert it to doubles and
%             % concat it with the recentScaledAnalogData, storing the result
%             % in yRecent.
%             nActiveDigitalChannels = self.Parent.Acquisition.NActiveDigitalChannels ;
%             if nActiveDigitalChannels==0 ,
%                 yRecent = recentScaledAnalogData ;
%             else
%                 % Might need to write a mex function to quickly translate
%                 % recentRawDigitalData to recentDigitalData.
%                 nScans = size(recentRawDigitalData,1) ;                
%                 recentDigitalData = zeros(nScans,nActiveDigitalChannels) ;
%                 for j = 1:nActiveDigitalChannels ,
%                     recentDigitalData(:,j) = bitget(recentRawDigitalData,j) ;
%                 end
%                 % End of code that might need to mex-ify
%                 yRecent = horzcat(recentScaledAnalogData, recentDigitalData) ;
%             end
%             
%             % Compute a timeline for the new data            
%             nNewScans = size(yRecent, 1) ;
%             dt = 1/sampleRate ;  % s
%             t0 = t - dt*nNewScans ;  % timestamp of first scan in newData
%             xRecent = t0 + dt*(0:(nNewScans-1))' ;
%             
%             % Figure out the downsampling ratio
%             self.broadcast('ItWouldBeNiceToKnowXSpanInPixels') ;
%               % At this point, self.XSpanPixels_ should be set to the
%               % correct value, or the fallback value if there's no view
%             %xSpanInPixels=ws.ScopeFigure.getWidthInPixels(self.AxesGH_);
%             xSpanInPixels = self.XSpanInPixels_ ;
%             xSpan = self.XSpan ;
%             r = ws.ratioSubsampling(dt, xSpan, xSpanInPixels) ;
%             
%             % Downsample the new data
%             [xForPlottingNew, yForPlottingNew] = ws.minMaxDownsampleMex(xRecent, yRecent, r) ;            
%             
%             % deal with XData
%             xAllOriginal = self.XData ;  % these are already downsampled
%             yAllOriginal = self.YData ;            
%             
%             % Concatenate the old data that we're keeping with the new data
%             xAllProto = vertcat(xAllOriginal, xForPlottingNew) ;
%             yAllProto = vertcat(yAllOriginal, yForPlottingNew) ;
%             
%             % Trim off scans that would be off the screen anyway
%             doKeepScan = (self.XOffset_<=xAllProto) ;
%             xNew = xAllProto(doKeepScan) ;
%             yNew = yAllProto(doKeepScan,:) ;
% 
%             % Commit the data to self
%             self.XData_ = xNew ;
%             self.YData_ = yNew ;
%             
% %             % Update the x offset in the scope to match that in the Display
% %             % subsystem
% %             fprintf('xOffset: %20g     self.XOffset: %20g\n', xOffset, self.XOffset) ;
% %             if xOffset ~= self.XOffset , 
% %                 fprintf('About to change x offset\n') ;
% %                 self.XOffset = xOffset ;
% %             end
%             
%             % Change the y limits to match the data, if appropriate
%             indicesOfAIChannelsNeedingYLimitUpdate = self.setYAxisLimitsTightToDataIfAreYLimitsLockedTightToData_() ;
%         end        
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
                    %self.clearData_() ;
                    self.broadcast('ClearData') ;
                end            
                self.ClearOnNextData_ = false;

                % update the x offset
                if self.XAutoScroll_ ,                
                    scale=min(1,self.XSpan);
                    tNudged=scale*ceil(100*t/scale)/100;  % Helps keep the axes aligned to tidy numbers
                    xOffsetNudged=tNudged-self.XSpan;
                    if xOffsetNudged>self.XOffset ,
                        self.XOffset_=xOffsetNudged;
                        self.broadcast('UpdateXOffset') ;
                    end
                end

                % Add the data
                fs = self.Parent.Acquisition.SampleRate ;
                self.broadcast('AddData', t, scaledAnalogData, rawDigitalData, fs) ;
%                 indicesOfAIChannelsNeedingYLimitUpdate = self.addData_(t, scaledAnalogData, rawDigitalData, fs) ;
%                 plotIndicesNeedingYLimitUpdate = self.PlotIndexFromChannelIndex_(indicesOfAIChannelsNeedingYLimitUpdate) ;
%                 self.broadcast('UpdateData');       
%                 self.broadcast('UpdateYAxisLimits', plotIndicesNeedingYLimitUpdate, indicesOfAIChannelsNeedingYLimitUpdate) ;
            else
                % if not active, do nothing
            end
        end
        
%         function result = getPlotIndexFromChannelIndex(self)
%             % The "channel index" here is is equal to the AI channel index
%             % for AI channels, and is equal to the DI channel index
%             % plus the number of AI channels for DI channels.  The plot
%             % index is set to nan for undisplayed channels.
%             isChannelDisplayed = horzcat(self.IsAnalogChannelDisplayed_, self.IsDigitalChannelDisplayed_) ;
%             rowIndexFromChannelIndex = horzcat(self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_) ;
%             rowIndexFromChannelIndexAmongDisplayed = rowIndexFromChannelIndex(isChannelDisplayed) ;
%             plotIndexFromChannelIndexAmongDisplayed = ws.sortedOrder(rowIndexFromChannelIndexAmongDisplayed) ;
%             nChannels = length(isChannelDisplayed) ;
%             result = nan(1,nChannels) ;
%             result(isChannelDisplayed) = plotIndexFromChannelIndexAmongDisplayed ;            
%         end        
        
%         function [channelIndexWithinTypeFromPlotIndex, isAnalogFromPlotIndex] = getChannelIndexFromPlotIndexMapping(self)
%             isAnalogChannelDisplayed = self.IsAnalogChannelDisplayed_ ;
%             isDigitalChannelDisplayed = self.IsDigitalChannelDisplayed_ ;
%             nAnalogChannels = length(isAnalogChannelDisplayed) ;
%             nDigitalChannels = length(isDigitalChannelDisplayed) ;
%             %nChannels = nAnalogChannels + nDigitalChannels ;
%             isAnalogFromChannelIndex = horzcat( true(1,nAnalogChannels), false(1,nDigitalChannels) ) ;
%             isDisplayedFromChannelIndex = horzcat(isAnalogChannelDisplayed, isDigitalChannelDisplayed) ;
%             rowIndexFromChannelIndex = horzcat(self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_) ;
%             channelIndexFromPlotIndex = ws.Display.computeChannelIndexFromPlotIndexMapping(rowIndexFromChannelIndex, isDisplayedFromChannelIndex) ;
%             isAnalogFromPlotIndex = isAnalogFromChannelIndex(channelIndexFromPlotIndex) ;
%             channelIndexWithinTypeFromPlotIndex = ...
%                 arrayfun(@(channelIndex)(ws.fif(channelIndex>nAnalogChannels,channelIndex-nAnalogChannels,el)), channelIndexFromPlotIndex) ;
%         end
        
        function didSetAreSweepsFiniteDuration(self)
            % Called by the parent to notify of a change to the acquisition
            % duration            
            self.broadcast('ClearData') ;
            self.broadcast('UpdateXSpan') ;
        end
        
        function didSetSweepDurationIfFinite(self)
            % Called by the parent to notify of a change to the acquisition
            % duration.            
            if self.IsXSpanSlavedToAcquistionDuration ,
                self.broadcast('ClearData') ;
            end                
            self.broadcast('UpdateXSpan') ;
        end
        
%         function out = get.NPlots(self)
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
%             self.broadcast('NPlotsMayHaveChanged');
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
%             %self.broadcast('NPlotsMayHaveChanged');  % do I need this?
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
    
    methods (Access=protected)
        function sanitizePersistedState_(self)
            % This method should perform any sanity-checking that might be
            % advisable after loading the persistent state from disk.
            % This is often useful to provide backwards compatibility
            
            nAIChannels = self.Parent.Acquisition.NAnalogChannels ;
            self.IsAnalogChannelDisplayed_ = ws.sanitizeRowVectorLength(self.IsAnalogChannelDisplayed_, nAIChannels, true) ;
            self.AreYLimitsLockedTightToDataForAnalogChannel_ = ...
                ws.sanitizeRowVectorLength(self.AreYLimitsLockedTightToDataForAnalogChannel_, nAIChannels, false) ;
            self.YLimitsPerAnalogChannel_ = ...
                ws.Display.sanitizeYLimitsArrayLength(self.YLimitsPerAnalogChannel_, nAIChannels, [-10 +10]') ;
            self.PlotHeightFromAnalogChannelIndex_  = ...
                ws.sanitizeRowVectorLength(self.PlotHeightFromAnalogChannelIndex_, nAIChannels, 1) ;
            
            nDIChannels = self.Parent.Acquisition.NDigitalChannels ;
            self.IsDigitalChannelDisplayed_ = ws.sanitizeRowVectorLength(self.IsDigitalChannelDisplayed_, nDIChannels, true) ;            
            self.PlotHeightFromDigitalChannelIndex_  = ...
                ws.sanitizeRowVectorLength(self.PlotHeightFromDigitalChannelIndex_, nDIChannels, 1) ;

            % The analog row indices have to be fixed using
            % knowledge of the digital row indices, and vice-versa
            [self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_] = ...
                ws.Display.sanitizeRowIndices(self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_, nAIChannels, nDIChannels) ;
        end
        
        function synchronizeTransientStateToPersistedState_(self)
            self.updateMappingsFromPlotIndices_() ;            
            %self.clearData_() ;  % This will ensure that the size of YData is appropriate
            %self.broadcast('ClearData') ;
        end        
        
    end  % protected methods block
    
    methods (Access=protected)    
        function disableAllBroadcastsDammit_(self)
            self.disableBroadcasts() ;
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.enableBroadcastsMaybe() ;
        end
    end  % protected methods block
    
    methods (Access=protected)    
        function setIsEnabledImplementation_(self, newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.IsEnabled_ = logical(newValue) ;
                if ~self.IsEnabled_ ,
                    %self.clearData_() ;  % if we just disabled Display, clear the data
                    self.broadcast('ClearData') ;
                end
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.broadcast('DidSetIsEnabled') ;
            if ~didSucceed ,
                error('ws:invalidPropertyValue', ...
                      'IsEnabled must be a scalar, and must be logical, 0, or 1') ;
            end
        end
        
        function updateMappingsFromPlotIndices_(self)
            isAnalogChannelDisplayed = self.IsAnalogChannelDisplayed_ ;
            isDigitalChannelDisplayed = self.IsDigitalChannelDisplayed_ ;
            nAnalogChannels = length(isAnalogChannelDisplayed) ;
            nDigitalChannels = length(isDigitalChannelDisplayed) ;
            isAnalogFromChannelIndex = horzcat( true(1,nAnalogChannels), false(1,nDigitalChannels) ) ;
            isDisplayedFromChannelIndex = horzcat(isAnalogChannelDisplayed, isDigitalChannelDisplayed) ;
            rowIndexFromChannelIndex = horzcat(self.RowIndexFromAnalogChannelIndex_, self.RowIndexFromDigitalChannelIndex_) ;
            channelIndexFromPlotIndex = ws.Display.computeChannelIndexFromPlotIndexMapping(rowIndexFromChannelIndex, isDisplayedFromChannelIndex) ;
            isAnalogFromPlotIndex = isAnalogFromChannelIndex(channelIndexFromPlotIndex) ;
            channelIndexWithinTypeFromPlotIndex = ...
                arrayfun(@(channelIndex)(ws.fif(channelIndex>nAnalogChannels,channelIndex-nAnalogChannels,channelIndex)), channelIndexFromPlotIndex) ;
            % Determine the channel index -> plot index mapping
            plotIndexFromChannelIndex = ws.sortedOrderLeavingNansInPlace(rowIndexFromChannelIndex) ;
            % Finally, set the state variables that we need to set
            self.IsAnalogFromPlotIndex_ = isAnalogFromPlotIndex ;
            self.ChannelIndexWithinTypeFromPlotIndex_ = channelIndexWithinTypeFromPlotIndex ;            
            self.ChannelIndexFromPlotIndex_ = channelIndexFromPlotIndex ;
            self.PlotIndexFromChannelIndex_ = plotIndexFromChannelIndex ;
        end  % function
        
    end  % protected methods block    
    
    methods (Static=true)
        function y = sanitizeYLimitsArrayLength(x, targetLength, defaultValue)
            % If x is 2xtargetLength, with all(x(1,:)<x(2,:)), return x.
            % Otherwise, massage x in various ways to make the result
            % 2xtargetLength, with all(y(1,:)<y(2,:)).
            [nRowsOriginal,nColsOriginal] = size(x) ;
            
            % As a first step, fix the shape, so that yProto is 2xn, with
            % all(yProto(1,:)<yProto(2,:)).
            if nRowsOriginal==2 && nColsOriginal==2 ,
                if all(x(1,:)<x(2,:)) ,
                    % Everything looks good.
                    yProto = x ;
                elseif all(x(:,1)<x(:,2)),
                    % if each row has the first el less than
                    % the second, can fix things by transposing.
                    yProto = x' ;                    
                else
                    % WTF?  Force elements to be in right order
                    yProto = ws.prewashYLimitsArray(x) ;
                end                    
            elseif nRowsOriginal==2 ,
                if all(x(1,:)<x(2,:)) ,
                    % Everything looks good.
                    % This should be the common case, want it to be fast, and hopefully
                    % involve no copying...                    
                    yProto = x ;
                else
                    yProto = ws.prewashYLimitsArray(x) ;
                end
            elseif nColsOriginal==2 ,
                yProto = ws.prewashYLimitsArray(x') ;
            else
                % Just use the default value, repeated
                yProto = repmat(defaultValue,[1 targetLength]) ;
            end
            
            % At this point yProto is 2xn, for some n, with 
            % all( yProto(1,:)<yProto(2,:) ).
            nCols = size(yProto,2) ;
            if nCols>targetLength ,
                y = yProto(:,targetLength) ;
            elseif nCols<targetLength ,
                nNewCols = targetLength-nCols ;
                y = horzcat(yProto, repmat(defaultValue,[1 nNewCols])) ;
            else
                % yProto has the right number of cols
                y = yProto ;
            end               
        end        
        
        function y = prewashYLimitsArray(x)
            % x must be 2xn.  Makes sure each col has the first element
            % strictly less than the second.
            n = size(x,2) ;
            y = zeros(2,n) ;
            for i = 1:n ,
                if x(1,i)<x(2,i) ,
                    y(:,i) = x(:,i) ;
                elseif x(1,i)>x(2,i) ;
                    y(:,i) = flipud(x(:,i)) ;
                else
                    % both els equal, so just add/subtract one to make a range
                    y(:,i) = x(1,i) + [-1 +1]' ;
                end
            end
        end
    
        function [newRowIndexFromAnalogChannelIndex, newRowIndexFromDigitalChannelIndex] = ...
                renormalizeRowIndices(rowIndexFromAnalogChannelIndex, rowIndexFromDigitalChannelIndex)
            % Used, e.g. after channel deletion, to maintain the ordering
            % of the row indices, but eliminate any gaps, so that they go
            % from 1 to the number of channels.
            nAIChannels = length(rowIndexFromAnalogChannelIndex) ;
            %nDIChannels = length(rowIndexFromDigitalChannelIndex) ;
            %nChannels = nAIChannels + nDIChannels ;
            rowIndexFromChannelIndex = horzcat(rowIndexFromAnalogChannelIndex, rowIndexFromDigitalChannelIndex) ;  % this may have gaps in the ordering
            newRowIndexFromChannelIndex = ws.sortedOrder(rowIndexFromChannelIndex) ;
            %[~,channelIndexFromRowIndex] = sort(rowIndexFromChannelIndex) ;
            %newRowIndexFromChannelIndex(channelIndexFromRowIndex) = 1:nChannels ;
            newRowIndexFromAnalogChannelIndex = newRowIndexFromChannelIndex(1:nAIChannels) ;
            newRowIndexFromDigitalChannelIndex = newRowIndexFromChannelIndex(nAIChannels+1:end) ;
        end
        
        function [newRowIndexFromAnalogChannelIndex, newRowIndexFromDigitalChannelIndex] = ...
                sanitizeRowIndices(rowIndexFromAnalogChannelIndex, rowIndexFromDigitalChannelIndex, nAIChannels, nDIChannels)
            protoNewRowIndexFromAnalogChannelIndex = ws.sanitizeRowVectorLength(rowIndexFromAnalogChannelIndex, nAIChannels, +inf) ;
            protoNewRowIndexFromDigitalChannelIndex = ws.sanitizeRowVectorLength(rowIndexFromDigitalChannelIndex, nDIChannels, +inf) ;
            [newRowIndexFromAnalogChannelIndex, newRowIndexFromDigitalChannelIndex] = ...
                ws.Display.renormalizeRowIndices(protoNewRowIndexFromAnalogChannelIndex, protoNewRowIndexFromDigitalChannelIndex) ;
        end

        function result = computeChannelIndexFromPlotIndexMapping(rowIndexFromChannelIndex, isDisplayedFromChannelIndex)
            % Computes the mapping from plot index to channel index, given
            % the relevant inputs.  "rows" here refers to rows in the
            % dialog box that the user uses to order the channels for
            % display.  If isDisplayedFromChannelIndex is all true, then
            % the result is simply the inverse permutation of
            % rowIndexFromChannelIndex.
            channelIndexFromRowIndex = ws.invertPermutation(rowIndexFromChannelIndex) ;
            isDisplayedFromRowIndex(rowIndexFromChannelIndex) = isDisplayedFromChannelIndex ;
            result = channelIndexFromRowIndex(isDisplayedFromRowIndex) ;
        end  % function
    end  % static methods block

    
    
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
