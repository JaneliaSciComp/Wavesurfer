classdef DisplayFigure < ws.MCOSFigure
    
    properties (Access = protected)
        ScopePlots_ = ws.ScopePlot.empty(1,0)  % an array of type ws.ScopePlot
        
        ViewMenu_
        InvertColorsMenuItem_
        ShowGridMenuItem_
        DoShowButtonsMenuItem_
        DoColorTracesMenuItem_
        PlotArrangementMenuItem_

        % The (downsampled for display) data currently being shown.
        XData_
        YData_
        
        % Stuff below are cached resources that we use in all the
        NormalYScrollUpIcon_ 
        NormalYScrollDownIcon_ 
        NormalYTightToDataIcon_ 
        NormalYTightToDataLockedIcon_ 
        NormalYTightToDataUnlockedIcon_ 
        NormalYCaretIcon_         
        TraceColorSequence_
    end    
    
    methods
        function self=DisplayFigure(model, controller)
            % Call the superclass constructor
            self = self@ws.MCOSFigure(model,controller) ;
            
            % Set up XData_ and YData_
            self.clearXDataAndYData_() ;
            
            % Set properties of the figure
            set(self.FigureGH, ...
                'Name', 'Display', ...
                'Tag', 'DisplayFigure', ...
                'NumberTitle', 'off', ...
                'Units', 'pixels', ...
                'HandleVisibility', 'off', ...
                'Menubar','none', ...
                'Toolbar','none', ...
                'CloseRequestFcn', @(source,event)(self.closeRequested(source,event)), ...
                'ResizeFcn', @(source,event)(self.resize()) );
            
            % Load in the needed icons from disk
            wavesurferDirName=fileparts(which('wavesurfer'));
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'up_arrow.png');
            self.NormalYScrollUpIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;            
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'down_arrow.png');
            self.NormalYScrollDownIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data.png');
            self.NormalYTightToDataIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;            
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data_locked.png');
            self.NormalYTightToDataLockedIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data_unlocked.png');
            self.NormalYTightToDataUnlockedIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_manual_set.png');
            self.NormalYCaretIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;

            % Create the trace color sequence
            self.TraceColorSequence_ = ws.makeColorSequence() ;
            
            % Create the widgets that will persist through the life of the
            % figure
            self.createFixedControls_() ;
            
            % Set the initial figure position
            self.setInitialFigureSize_() ;
                        
            % sync up self to model
            self.update() ;
            
            % position next to main window
            mainFigure = controller.Parent.Figure ;
            self.positionUpperLeftRelativeToOtherUpperRight(mainFigure, [40 0]) ;

            % Subscribe to events
            if ~isempty(model) ,
               model.subscribeMe(self,'Update','','update') ;
               %model.subscribeMe(self,'NScopesMayHaveChanged','','update');
               model.subscribeMe(self,'DidSetIsEnabled','','update') ;
               model.subscribeMe(self,'DidSetUpdateRate','','updateControlProperties') ;
               %model.subscribeMe(self,'DidSetScopeIsVisibleWhenDisplayEnabled','','update');
               %model.subscribeMe(self,'UpdateXSpan','','updateControlProperties');
               model.subscribeMe(self,'UpdateXOffset','','updateXAxisLimits') ;
               model.subscribeMe(self,'UpdateXSpan','','updateXAxisLimits') ;
               model.subscribeMe(self,'UpdateYAxisLimits','','updateYAxisLimits') ;
               %model.subscribeMe(self,'UpdateData','','updateData') ;
               model.subscribeMe(self,'ClearData','','clearData') ;
               %model.subscribeMe(self,'DataAdded','','modelDataAdded');
               %model.subscribeMe(self,'DataCleared','','modelDataCleared');
               model.subscribeMe(self, 'AddData', '', 'addData') ;
               %model.subscribeMe(self,'ItWouldBeNiceToKnowXSpanInPixels','','tellModelXSpanInPixels') ;
               wavesurferModel=model.Parent;
               if ~isempty(wavesurferModel) ,
                   wavesurferModel.subscribeMe(self,'DidSetState','','update') ;
               end
            end
            
        end  % constructor
        
        function delete(self)
            self.ScopePlots_ = [] ;  % not really necessary
        end  % function
        
        function resize(self)
            self.clearXDataAndYData_() ;
            self.clearTraceData_() ;
            self.layout_() ;            
        end        
end  % public methods block
    
    methods (Access=protected)        
        function setInitialFigureSize_(self)
            % Set the initial figure size

            % Get the offset, which will stay the same
            position = get(self.FigureGH,'Position') ;
            offset = position(1:2) ;            
            
            % Don't want the fig to be larger than the screen
            originalScreenUnits=get(0,'Units');
            set(0,'Units','pixels');
            screenPosition=get(0,'ScreenSize');
            set(0,'Units',originalScreenUnits);            
            screenSize=screenPosition(3:4);
            screenHeight = screenSize(2) ;
            maxInitialHeight = screenHeight - 50 ;  % pels
            
            % Position the figure in the middle of the screen
            nPlots = self.Model.NPlots ;
            initialHeight = min(250 * max(1,nPlots), maxInitialHeight) ;
            initialSize=[700 initialHeight];
            figurePosition=[offset initialSize];
            set(self.FigureGH,'Position',figurePosition);
        end  % function        
    end  % protected methods block    
    
    methods
        function updateXAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateXAxisLimits_();
        end  % function
        
        function updateYAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSL>
            args = event.Args ;
            plotIndex = args{1} ;
            aiChannelIndex = args{2} ;
            self.updateYAxisLimits_(plotIndex, aiChannelIndex) ;
        end  % function
        
        function updateAreYLimitsLockedTightToData(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            %self.updateAreYLimitsLockedTightToData_();
            %self.updateControlEnablement_();
            self.update() ;
        end  % function
        
        function updateData(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.syncLineXDataAndYData_();
        end  % function
    end  % methods
    
    methods (Access=protected)        
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            % Add a menu, and a single menu item
            self.ViewMenu_ = ...
                uimenu('Parent',self.FigureGH, ...
                       'Label','View');
            self.InvertColorsMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Green On Black', ...
                       'Callback',@(source,event)self.controlActuated('InvertColorsMenuItemGH',source,event));            
            self.ShowGridMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Show Grid', ...
                       'Callback',@(source,event)self.controlActuated('ShowGridMenuItemGH',source,event));            
            self.DoShowButtonsMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Show Buttons', ...
                       'Callback',@(source,event)self.controlActuated('DoShowButtonsMenuItemGH',source,event));            
            self.DoColorTracesMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Color Traces', ...
                       'Callback',@(source,event)self.controlActuated('doColorTracesMenuItem',source,event));            
            self.PlotArrangementMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Separator', 'on', ...
                       'Label','Plot Arrangement...', ...
                       'Callback',@(source,event)self.controlActuated('arrangementMenuItem',source,event));                                                  
        end  % function            

        function updateControlsInExistance_(self)
            % Make it so we have the same number of scopes as displayed channels,
            % adding/deleting them as needed.
            isChannelDisplayed = horzcat(self.Model.IsAnalogChannelDisplayed, self.Model.IsDigitalChannelDisplayed) ;
            nChannelsDisplayed = sum(isChannelDisplayed) ;
            nScopePlots = length(self.ScopePlots_) ;
            if nChannelsDisplayed>nScopePlots ,
                for i = nScopePlots+1:nChannelsDisplayed ,
                    newScopePlot = ws.ScopePlot(self, i) ;
                    self.ScopePlots_ = horzcat(self.ScopePlots_, newScopePlot);
                end
            elseif nChannelsDisplayed<nScopePlots ,
                for i = nChannelsDisplayed+1:nScopePlots ,
                    self.ScopePlots_(i).delete() ;  % Have to delete to eliminate UI objects
                end
                self.ScopePlots_ = self.ScopePlots_(1:nChannelsDisplayed) ;
            else
                % do nothing --- we already have the right number of
                % ScopePlots
            end
        end  % function
        
        function updateControlPropertiesImplementation_(self)
            % If there are issues with the model, just return
            model=self.Model;
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
            % Update the Show Grid togglemenu
            isGridOn = self.Model.IsGridOn ;
            set(self.ShowGridMenuItem_,'Checked',ws.onIff(isGridOn));

            % Update the Invert Colors togglemenu
            areColorsNormal = self.Model.AreColorsNormal ;
            set(self.InvertColorsMenuItem_,'Checked',ws.onIff(~areColorsNormal));

            % Update the Do Show Buttons togglemenu
            doShowButtons = self.Model.DoShowButtons ;
            set(self.DoShowButtonsMenuItem_,'Checked',ws.onIff(doShowButtons));

            % Update the Do Color Traces togglemenu
            doColorTraces = self.Model.DoColorTraces ;
            set(self.DoColorTracesMenuItem_,'Checked',ws.onIff(doColorTraces));

            % Compute the colors
            defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            controlBackgroundColor  = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            controlForegroundColor = ws.fif(areColorsNormal,'k','w') ;
            figureBackground = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            set(self.FigureGH,'Color',figureBackground);
            axesBackgroundColor = ws.fif(areColorsNormal,'w','k') ;
            axesForegroundColor = ws.fif(areColorsNormal,'k','g') ;
            %traceLineColor = ws.fif(areColorsNormal,'k','w') ;

            % Compute the icons
            if areColorsNormal ,
                yScrollUpIcon   = self.NormalYScrollUpIcon_   ;
                yScrollDownIcon = self.NormalYScrollDownIcon_ ;
                yTightToDataIcon = self.NormalYTightToDataIcon_ ;
                yTightToDataLockedIcon = self.NormalYTightToDataLockedIcon_ ;
                yTightToDataUnlockedIcon = self.NormalYTightToDataUnlockedIcon_ ;
                yCaretIcon = self.NormalYCaretIcon_ ;
            else
                yScrollUpIcon   = 1-self.NormalYScrollUpIcon_   ;  % RGB images, so this inverts them, leaving nan's alone
                yScrollDownIcon = 1-self.NormalYScrollDownIcon_ ;                
                yTightToDataIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataIcon_) ;  
                yTightToDataLockedIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataLockedIcon_) ;
                yTightToDataUnlockedIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataUnlockedIcon_) ;
                yCaretIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYCaretIcon_) ;
            end                

            % Determine the common x-axis limits
            xl = self.Model.XOffset + [0 self.Model.XSpan] ;

            % Get the y-axis limits for all analog channels
            yLimitsPerAnalogChannel = self.Model.YLimitsPerAnalogChannel ;

            % Get the channel names and units for all channels
            acq = model.Parent.Acquisition ;
            aiChannelNames = acq.AnalogChannelNames ;            
            diChannelNames = acq.DigitalChannelNames ;
            aiChannelUnits = acq.AnalogChannelUnits ;            
            
            % Update the individual plot colors and icons
            areYLimitsLockedTightToDataFromAIChannelIndex = self.Model.AreYLimitsLockedTightToDataForAnalogChannel ;
            channelIndexWithinTypeFromPlotIndex = self.Model.ChannelIndexWithinTypeFromPlotIndex ;
            isAnalogFromPlotIndex = self.Model.IsAnalogFromPlotIndex ;
            channelIndexFromPlotIndex = self.Model.ChannelIndexFromPlotIndex ;
            %[channelIndexWithinTypeFromPlotIndex, isAnalogFromPlotIndex] = self.getChannelIndexFromPlotIndexMapping() ;
            nPlots = length(self.ScopePlots_) ;
            for plotIndex=1:length(self.ScopePlots_) ,
                thisPlot = self.ScopePlots_(plotIndex) ;
                isThisChannelAnalog = isAnalogFromPlotIndex(plotIndex) ;
                indexOfThisChannelWithinType =  channelIndexWithinTypeFromPlotIndex(plotIndex) ;  % where "type" means analog or digital
                indexOfThisChannel = channelIndexFromPlotIndex(plotIndex) ;

                % Determine trace color for this plot
                if doColorTraces ,
                    normalTraceLineColor = self.TraceColorSequence_(indexOfThisChannel,:) ;
                else
                    normalTraceLineColor = [0 0 0] ;  % black
                end
                if areColorsNormal ,
                    traceLineColor = normalTraceLineColor ;
                else
                    traceLineColor = 1 - normalTraceLineColor ;
                end
                    
                if isThisChannelAnalog ,
                    areYLimitsLockedTightToDataForThisChannel = areYLimitsLockedTightToDataFromAIChannelIndex(indexOfThisChannelWithinType) ;
                    thisPlot.setColorsAndIcons(controlForegroundColor, controlBackgroundColor, ...
                                               axesForegroundColor, axesBackgroundColor, ...
                                               traceLineColor, ...
                                               yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon, yTightToDataUnlockedIcon, yCaretIcon, ...
                                               areYLimitsLockedTightToDataForThisChannel) ;
                    thisPlot.IsGridOn = isGridOn ;                       
                    thisPlot.setXAxisLimits(xl) ;
                    thisPlot.setYAxisLimits(yLimitsPerAnalogChannel(:,indexOfThisChannelWithinType)') ;
                    thisPlot.setYAxisLabel(aiChannelNames{indexOfThisChannelWithinType}, ...
                                           true, ...
                                           aiChannelUnits{indexOfThisChannelWithinType}, ...
                                           axesForegroundColor) ;
                    if plotIndex==nPlots ,
                        thisPlot.setXAxisLabel(axesForegroundColor) ;
                    else
                        thisPlot.clearXAxisLabel() ;
                    end
                else
                    % this channel is digital
                    thisPlot.setColorsAndIcons(controlForegroundColor, controlBackgroundColor, ...
                                               axesForegroundColor, axesBackgroundColor, ...
                                               traceLineColor, ...
                                               yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon, yTightToDataUnlockedIcon, yCaretIcon, ...
                                               true) ;
                    thisPlot.IsGridOn = isGridOn ;                       
                    thisPlot.setXAxisLimits(xl) ;
                    thisPlot.setYAxisLimits([-0.05 1.05]) ;
                    thisPlot.setYAxisLabel(diChannelNames{indexOfThisChannelWithinType}, false, [], axesForegroundColor) ;
                    if plotIndex==nPlots ,
                        thisPlot.setXAxisLabel(axesForegroundColor) ;
                    else
                        thisPlot.clearXAxisLabel() ;
                    end
                end
            end

            % Do this separately, although we could do it at same time if
            % speed is an issue...
            self.syncLineXDataAndYData_();
        end  % function
        
        function updateControlEnablementImplementation_(self)
            % Update the enablement of buttons in the panels
            areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToDataForAnalogChannel ;
            channelIndexWithinTypeFromPlotIndex = self.Model.ChannelIndexWithinTypeFromPlotIndex ;
            isAnalogFromPlotIndex = self.Model.IsAnalogFromPlotIndex ;
            for iPlot=1:length(self.ScopePlots_) ,
                isThisPlotAnalog = isAnalogFromPlotIndex(iPlot) ;
                thisChannelIndex = channelIndexWithinTypeFromPlotIndex(iPlot) ;
                if isThisPlotAnalog ,
                    self.ScopePlots_(iPlot).setControlEnablement(true, areYLimitsLockedTightToData(thisChannelIndex)) ;
                else
                    % this channel/plot is digital
                    self.ScopePlots_(iPlot).setControlEnablement(false) ;  % digital channels are always locked tight to data
                end
            end
        end  % function
        
        function layout_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely given the current model state.
            
            figurePosition = get(self.FigureGH, 'Position') ;
            figureSize = figurePosition(3:4) ;
        
            xAxisLabelAreaHeight = 44 ;
            
            plotHeightFromPlotIndex = self.Model.PlotHeightFromPlotIndex ;
            normalizedPlotHeightFromPlotIndex = plotHeightFromPlotIndex/sum(plotHeightFromPlotIndex) ;
            totalNormalizedHeightOfPreviousPlotsFromPlotIndex = cumsum(normalizedPlotHeightFromPlotIndex) ;
            
            doesUserWantToSeeButtons = self.Model.DoShowButtons ;
            isAnalogFromPlotIndex = self.Model.IsAnalogFromPlotIndex ;
            nPlots = length(self.ScopePlots_) ;
            for iPlot=1:nPlots ,
                isThisPlotAnalog = isAnalogFromPlotIndex(iPlot) ;
                self.ScopePlots_(iPlot).setPositionAndLayout(figureSize, ...
                                                             xAxisLabelAreaHeight, ...
                                                             normalizedPlotHeightFromPlotIndex(iPlot) , ...
                                                             totalNormalizedHeightOfPreviousPlotsFromPlotIndex(iPlot) , ...                                                             
                                                             doesUserWantToSeeButtons, ...
                                                             isThisPlotAnalog) ;
            end
        end  % function
    end  % protected methods block
    
    methods
        function addData(self, broadcaster, eventName, propertyName, source, event) %#ok<INUSL>
            args = event.Args ;
            t = args{1} ;
            recentScaledAnalogData = args{2} ;
            recentRawDigitalData = args{3} ;
            sampleRate = args{4} ;
            self.addData_(t, recentScaledAnalogData, recentRawDigitalData, sampleRate) ;
        end
        
        function clearData(self, broadcaster, eventName, propertyName, source, event)  %#ok<INUSD>
            self.clearXDataAndYData_() ;
            self.clearTraceData_() ;
        end        
    end
    
    methods (Access=protected)
        function addData_(self, t, recentScaledAnalogData, recentRawDigitalData, sampleRate)
            % t is a scalar, the time stamp of the scan *just after* the
            % most recent scan.  (I.e. it is one dt==1/fs into the future.
            % Queue Doctor Who music.)

            % Get the uint8/uint16/uint32 data out of recentRawDigitalData
            % into a matrix of logical data, then convert it to doubles and
            % concat it with the recentScaledAnalogData, storing the result
            % in yRecent.
            model = self.Model ;
            nActiveDigitalChannels = model.Parent.Acquisition.NActiveDigitalChannels ;
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
            if isempty(self.ScopePlots_) ,
                xSpanInPixels = 400 ;  % this is a reasonable value, and presumably it won't much matter
            else
                xSpanInPixels=self.ScopePlots_(1).getAxesWidthInPixels() ;
            end            
            xSpan = model.XSpan ;
            r = ws.ratioSubsampling(dt, xSpan, xSpanInPixels) ;
            
            % Downsample the new data
            [xForPlottingNew, yForPlottingNew] = ws.minMaxDownsampleMex(xRecent, yRecent, r) ;            
            
            % deal with XData
            xAllOriginal = self.XData_ ;  % these are already downsampled
            yAllOriginal = self.YData_ ;            
            
            % Concatenate the old data that we're keeping with the new data
            xAllProto = vertcat(xAllOriginal, xForPlottingNew) ;
            yAllProto = vertcat(yAllOriginal, yForPlottingNew) ;
            
            % Trim off scans that would be off the screen anyway
            doKeepScan = (model.XOffset<=xAllProto) ;
            xNew = xAllProto(doKeepScan) ;
            yNew = yAllProto(doKeepScan,:) ;

            % Commit the data to self
            self.XData_ = xNew ;
            self.YData_ = yNew ;
            
            % Update the line graphics objects to reflect XData_, YData_
            self.syncLineXDataAndYData_();
            
            % Change the y limits to match the data, if appropriate
            indicesOfAIChannelsNeedingYLimitUpdate = self.setYAxisLimitsInModelTightToDataIfAreYLimitsLockedTightToData_() ;            
            plotIndicesNeedingYLimitUpdate = self.Model.PlotIndexFromChannelIndex(indicesOfAIChannelsNeedingYLimitUpdate) ;
            self.updateYAxisLimits_(plotIndicesNeedingYLimitUpdate, indicesOfAIChannelsNeedingYLimitUpdate) ;
        end        
        
        function indicesOfAIChannelsNeedingYLimitUpdate = setYAxisLimitsInModelTightToDataIfAreYLimitsLockedTightToData_(self)
            model = self.Model ;
            areYLimitsLockedTightToData = model.AreYLimitsLockedTightToDataForAnalogChannel ;
            nAIChannels = model.Parent.Acquisition.NAnalogChannels ;
            doesAIChannelNeedYLimitUpdate = false(1,nAIChannels) ;
            for i = 1:nAIChannels ,                
                if areYLimitsLockedTightToData(i) ,
                    doesAIChannelNeedYLimitUpdate(i) = true ;
                    self.setYAxisLimitsInModelTightToData_(i) ;
                end
            end
            indicesOfAIChannelsNeedingYLimitUpdate = find(doesAIChannelNeedYLimitUpdate) ;
        end  % function
    end

    methods (Access = protected)
        function clearXDataAndYData_(self)
            self.XData_ = zeros(0,1) ;
            acquisition = self.Model.Parent.Acquisition ;
            nActiveChannels = acquisition.NActiveAnalogChannels + acquisition.NActiveDigitalChannels ;
            self.YData_ = zeros(0,nActiveChannels) ;
        end
        
        function clearTraceData_(self)
            % Also clear the lines in the plots
            nPlots = length(self.ScopePlots_) ;
            for iPlot = 1:nPlots ,
                thisPlot = self.ScopePlots_(iPlot) ;
                thisPlot.setLineXDataAndYData([],[]) ;
            end            
        end

        function [channelIndexFromPlotIndex, activeChannelIndexFromChannelIndex] = syncLineXDataAndYData_(self)
            if isempty(self.YData_) ,
                % Make sure it's the right kind of empty
                self.clearXDataAndYData_() ;
            end
            xData = self.XData_ ;
            yData = self.YData_ ;
            acq = self.Model.Parent.Acquisition ;
            activeChannelIndexFromChannelIndex = acq.ActiveChannelIndexFromChannelIndex ;            
            channelIndexFromPlotIndex = self.Model.ChannelIndexFromPlotIndex ;
            nPlots = length(self.ScopePlots_) ;
            for iPlot = 1:nPlots ,
                thisPlot = self.ScopePlots_(iPlot) ;
                channelIndex = channelIndexFromPlotIndex(iPlot) ;
                activeChannelIndex = activeChannelIndexFromChannelIndex(channelIndex) ;
                if isnan(activeChannelIndex) ,
                    % channel is not active
                    thisPlot.setLineXDataAndYData([],[]) ;
                else
                    % channel is active
                    yDataForThisChannel = yData(:,activeChannelIndex) ;
                    thisPlot.setLineXDataAndYData(xData, yDataForThisChannel) ;
                end
            end
        end  % function

        function updateAxisLabels_(self,axisForegroundColor)
            for i = 1:length(self.ScopePlots_) ,
                self.ScopePlots_(i).updateAxisLabels_(axisForegroundColor) ;
            end            
        end  % function
        
        function updateYAxisLabel_(self, color)
            % Updates the y axis label handle graphics to match the model state
            % and that of the Acquisition subsystem.
            %set(self.Axes_,'YLim',self.YOffset+[0 self.YRange]);
            if self.Model.NChannels==0 ,
                ylabel(self.Axes_,'Signal','Color',color,'FontSize',10,'Interpreter','none');
            else
                firstChannelName=self.Model.ChannelNames{1};
                units=self.Model.YUnits;
                if isempty(units) ,
                    unitsString = 'pure' ;
                else
                    unitsString = units ;
                end
                ylabel(self.Axes_,sprintf('%s (%s)',firstChannelName,unitsString),'Color',color,'FontSize',10,'Interpreter','none');
            end
        end  % function
        
        function updateXAxisLimits_(self)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            xl = self.Model.XOffset + [0 self.Model.XSpan] ;
            for i = 1:length(self.ScopePlots_) ,
                self.ScopePlots_(i).setXAxisLimits(xl) ;
            end
        end  % function        

        function updateYAxisLimits_(self, plotIndices, aiChannelIndices)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            yLimitsFromAIChannelIndex = self.Model.YLimitsPerAnalogChannel ;
            for i = 1:length(plotIndices) ,
                plotIndex = plotIndices(i) ;
                aiChannelIndex = aiChannelIndices(i) ;
                yl = yLimitsFromAIChannelIndex(:,aiChannelIndex)' ;
                self.ScopePlots_(plotIndex).setYAxisLimits(yl) ;
            end
        end  % function        
    end  % methods (Access = protected)

    methods
        function castOffAllAttachments(self)
            self.unsubscribeFromAll() ;
            self.deleteFigureGH() ;
        end
    end

    methods (Access = protected)
        % Have to override with identical function text b/c of
        % protected/protected horseshit
        function setHGTagsToPropertyNames_(self)
            % For each object property, if it's an HG object, set the tag
            % based on the property name, and set other HG object properties that can be
            % set systematically.
            mc=metaclass(self);
            propertyNames={mc.PropertyList.Name};
            for i=1:length(propertyNames) ,
                propertyName=propertyNames{i};
                propertyThing=self.(propertyName);
                if ~isempty(propertyThing) && all(ishghandle(propertyThing)) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
                    % Set Tag
                    set(propertyThing,'Tag',propertyName);                    
                end
            end
        end  % function        
    end  % protected methods block
    
    methods
        function setYAxisLimitsTightToData(self, plotIndex)            
            if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,
                isAnalogFromPlotIndex = self.Model.IsAnalogFromPlotIndex ;
                nPlots = length(isAnalogFromPlotIndex) ;
                if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
                    channelIndex = self.Model.ChannelIndexWithinTypeFromPlotIndex(plotIndex) ;
                    self.setYAxisLimitsInModelTightToData_(channelIndex) ;
                end
            end
            self.updateYAxisLimits_(plotIndex, channelIndex) ;
        end  % function        
        
        function toggleAreYLimitsLockedTightToData(self, plotIndex)
            if isnumeric(plotIndex) && isscalar(plotIndex) && isreal(plotIndex) && (plotIndex==round(plotIndex)) && 1<=plotIndex,
                isAnalogFromPlotIndex = self.Model.IsAnalogFromPlotIndex ;
                nPlots = length(isAnalogFromPlotIndex) ;
                if plotIndex <= nPlots && isAnalogFromPlotIndex(plotIndex),
                    channelIndex = self.Model.ChannelIndexWithinTypeFromPlotIndex(plotIndex) ;
                    currentValue = self.Model.AreYLimitsLockedTightToDataForAnalogChannel(channelIndex) ;
                    newValue = ~currentValue ;
                    self.Model.setAreAreYLimitsLockedTightToDataForSingleChannel_(channelIndex, newValue) ;
                    if newValue ,
                        self.setYAxisLimitsInModelTightToData_(channelIndex) ;
                    end
                end
            end
            self.update() ;  % update the button
        end                
    end  % public methods block
    
    methods (Access=protected)
        function setYAxisLimitsInModelTightToData_(self, aiChannelIndex)            
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
            newYLimits = yCenter + 1.05*yRadius*[-1 +1] ;
            self.Model.setYLimitsForSingleAnalogChannel_(aiChannelIndex, newYLimits)
        end
        
        function yMinAndMax=dataYMinAndMax_(self, aiChannelIndex)
            % Min and max of the data, across all plotted channels.
            % Returns a 1x2 array.
            % If all channels are empty, returns [+inf -inf].
            activeChannelIndexFromChannelIndex = self.Model.Parent.Acquisition.ActiveChannelIndexFromChannelIndex ;
            indexWithinData = activeChannelIndexFromChannelIndex(aiChannelIndex) ;
            y = self.YData_(:,indexWithinData) ;
            yMinRaw=min(y);
            yMin=ws.fif(isempty(yMinRaw),+inf,yMinRaw);
            yMaxRaw=max(y);
            yMax=ws.fif(isempty(yMaxRaw),-inf,yMaxRaw);            
            yMinAndMax=double([yMin yMax]);
        end        
    end  % protected methods block    
end
