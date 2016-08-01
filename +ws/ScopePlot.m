classdef ScopePlot < handle
    
    properties (Dependent=true)
        IsVisible
        IsGridOn
    end
    
    properties (Access = protected)
        AxesGH_  % HG handle to axes
        LineGH_ % HG handle to trace line in the axes
        SetYLimTightToDataButtonGH_
        SetYLimTightToDataLockedButtonGH_
        SetYLimButtonGH_
        YZoomInButtonGH_
        YZoomOutButtonGH_
        YScrollUpButtonGH_
        YScrollDownButtonGH_
        XAxisLabelGH_
        YAxisLabelGH_
    end
    
    methods
        function self=ScopePlot(parent, isAnalog, channelIndex)
            self.AxesGH_ = ...
                axes('Parent', parent.FigureGH, ...
                     'Units','pixels', ...
                     'HandleVisibility','off', ...
                     'Box','on' );
            
            % Add the trace line, with no data for now                 
            self.LineGH_ = ...
                line('Parent', self.AxesGH_,...
                     'Color', 'k', ...
                     'XData', [],...
                     'YData', [],...
                     'ZData', []);            
                 
            % Y axis control buttons
            self.YZoomInButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'String','+', ...
                             'Callback',@(source,event)(parent.controlActuated('YZoomInButtonGH',source,event,channelIndex)));
            self.YZoomOutButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'String','-', ...
                             'Callback',@(source,event)(parent.controlActuated('YZoomOutButtonGH',source,event,channelIndex)));
            self.YScrollUpButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'Callback',@(source,event)(parent.controlActuated('YScrollUpButtonGH',source,event,channelIndex)));
            self.YScrollDownButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'Callback',@(source,event)(parent.controlActuated('YScrollDownButtonGH',source,event,channelIndex)));
            self.SetYLimTightToDataButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'TooltipString', 'Set y-axis limits tight to data', ....
                             'Callback',@(source,event)(parent.controlActuated('SetYLimTightToDataButtonGH',source,event,channelIndex)));
            % This next button used to be a togglebutton, but Matlab doesn't let you change the foreground/background colors of togglebuttons, which
            % we want to do with this button when we change to
            % green-on-black mode.  Also, there's a checked menu item that
            % shows when this toggle is engaged or disengaged, so hopefully
            % it won't be too jarring to the user when this button doesn't
            % look toggled after she presses it.  I think it should be OK
            % --- sometimes it's hard to tell even when a togglebutton is
            % toggled.
            self.SetYLimTightToDataLockedButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'TooltipString', 'Set y-axis limits tight to data, and keep that way', ....
                             'Callback',@(source,event)(parent.controlActuated('SetYLimTightToDataLockedButtonGH',source,event,channelIndex)));                      
            self.SetYLimButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'TooltipString', 'Set y-axis limits', ....
                             'Callback',@(source,event)(parent.controlActuated('SetYLimButtonGH',source,event,channelIndex)));                      
        end  % constructor
        
        function delete(self)
            % Do I even need to do this stuff?  Those GHs will become
            % invalid when the figure HG object is deleted...
            %fprintf('ScopePlot::delete()\n');
            self.deleteChildMatlabUIObjects() ;
        end  % function        
        
        function deleteChildMatlabUIObjects(self)
            ws.deleteIfValidHGHandle(self.LineGH_) ;
            ws.deleteIfValidHGHandle(self.AxesGH_) ;            
            ws.deleteIfValidHGHandle(self.SetYLimTightToDataButtonGH_) ;
            ws.deleteIfValidHGHandle(self.SetYLimTightToDataLockedButtonGH_) ;
            ws.deleteIfValidHGHandle(self.SetYLimButtonGH_) ;
            ws.deleteIfValidHGHandle(self.YZoomInButtonGH_) ;
            ws.deleteIfValidHGHandle(self.YZoomOutButtonGH_) ;
            ws.deleteIfValidHGHandle(self.YScrollUpButtonGH_) ;
            ws.deleteIfValidHGHandle(self.YScrollDownButtonGH_) ;
            ws.deleteIfValidHGHandle(self.XAxisLabelGH_) ;
            ws.deleteIfValidHGHandle(self.YAxisLabelGH_) ;
        end
        
        function tellModelXSpanInPixels(self, broadcaster, eventName, propertyName, source, event)  %#ok<INUSD>
            xSpanInPixels=ws.ScopeAxes.getWidthInPixels(self.AxesGH_) ;
            self.Model.hereIsXSpanInPixels_(xSpanInPixels) ;
        end
        
        function result = getAxesWidthInPixels(self)
            result = ws.ScopePlot.getWidthInPixels(self.AxesGH_) ;
        end
        
        function setColorsAndIcons(self, controlForegroundColor, controlBackgroundColor, ...
                                         axesForegroundColor, axesBackgroundColor, ...
                                         traceLineColor, ...
                                         yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedOrUnlockedIcon, yCaretIcon)            
            % Update the colors
            set(self.AxesGH_,'Color',axesBackgroundColor);
            set(self.AxesGH_,'XColor',axesForegroundColor);
            set(self.AxesGH_,'YColor',axesForegroundColor);
            set(self.AxesGH_,'ZColor',axesForegroundColor);

            % Set the line color
            set(self.LineGH_,'Color',traceLineColor);

            % Set the button colors
            set(self.YZoomInButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);
            set(self.YZoomOutButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);
            set(self.YScrollUpButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);
            set(self.YScrollDownButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);            
            set(self.SetYLimTightToDataButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);            
            set(self.SetYLimTightToDataLockedButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);            
            set(self.SetYLimButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);            
            
            % Set the button scroll up/down button images
            set(self.YScrollUpButtonGH_,'CData',yScrollUpIcon);
            set(self.YScrollDownButtonGH_,'CData',yScrollDownIcon);
            set(self.SetYLimTightToDataButtonGH_,'CData',yTightToDataIcon);
            set(self.SetYLimTightToDataLockedButtonGH_,'CData',yTightToDataLockedOrUnlockedIcon);            
            set(self.SetYLimButtonGH_,'CData',yCaretIcon);            
        end  % function

        function set.IsGridOn(self, newValue)
            set(self.AxesGH_, ...
                'XGrid', ws.onIff(newValue), ...
                'YGrid', ws.onIff(newValue) );
        end
           
        function result = get.IsGridOn(self)
            onOrOff = get(self.AxesGH_, 'XGrid') ;
            result = isequal(onOrOff, 'on') ;
        end
        
        function set.IsVisible(self, newValue)
            set(self.AxesGH_, 'Visible', ws.onIff(newValue));
            set(self.SetYLimTightToDataButtonGH_, 'Visible', ws.onIff(newValue));
            set(self.SetYLimTightToDataLockedButtonGH_, 'Visible', ws.onIff(newValue));
            set(self.SetYLimButtonGH_, 'Visible', ws.onIff(newValue));
            set(self.YZoomInButtonGH_, 'Visible', ws.onIff(newValue));
            set(self.YZoomOutButtonGH_, 'Visible', ws.onIff(newValue));
            set(self.YScrollUpButtonGH_, 'Visible', ws.onIff(newValue));
            set(self.YScrollDownButtonGH_, 'Visible', ws.onIff(newValue));
            set(self.YAxisLabelGH_, 'Visible', ws.onIff(newValue));
        end
           
        function result = get.IsVisible(self)
            onOrOff = get(self.AxesGH_, 'Visible') ;
            result = isequal(onOrOff, 'on') ;
        end
        
        function setPositionAndLayout(self, figureSize, xAxisLabelAreaHeight, nScopesVisible, indexOfThisScopeAmongVisibleScopes, doesUserWantToSeeButtons)
            % This method should make sure all the controls are sized and placed
            % appropriately given the current model state.  
            
            % Layout parameters
            minLeftMargin = 52 ;
            maxLeftMargin = 52 ;
            
            minRightMarginIfButtons = 8 ;            
            maxRightMarginIfButtons = 8 ;            

            minRightMarginIfNoButtons = 8 ;            
            maxRightMarginIfNoButtons = 8 ;            
            
            %minBottomMargin = 38 ;  % works ok with HG1
            minBottomMargin = 6 ;  % works ok with HG2 and HG1
            maxBottomMargin = 6 ;
            
            minTopMargin = 6 ;
            maxTopMargin = 6 ;            
            
            minAxesAndButtonsAreaWidth = 20 ;
            minAxesAndButtonsAreaHeight = 20 ;
            
            fromAxesToYRangeButtonsWidth = 6 ;
            yRangeButtonSize = 20 ;  % those buttons are square
            spaceBetweenButtonsInSameBank=5;
            %spaceBetweenButtonsInSameBank=spaceBetweenButtonsInSameBank;
            %spaceBetweenButtonsInSameBank=spaceBetweenButtonsInSameBank;
            %spaceBetweenButtonsInSameBank=spaceBetweenButtonsInSameBank;
            minHeightBetweenButtonBanks = 10 ;
            
            % Show buttons only if user wants them
            %doesUserWantToSeeButtons = self.Model.DoShowButtons ;            

            if doesUserWantToSeeButtons ,
                minRightMargin = minRightMarginIfButtons ;
                maxRightMargin = maxRightMarginIfButtons ;
            else
                minRightMargin = minRightMarginIfNoButtons ;
                maxRightMargin = maxRightMarginIfNoButtons ;
            end
            
            % Get the current figure width, height
            %figureSize = figurePosition(3:4);
            figureWidth = figureSize(1) ;
            figureHeight = figureSize(2) ;
            
            % There's a rectangle within the figure where this scope axes
            % will go.  We'll call this the "panel".  Calculate the
            % position of the panel within the figure rectangle.
            panelWidth = figureWidth ;
            %nScopesVisible = self.Model.Parent.IsScopeVisibleWhenDisplayEnabled ;
            panelHeight = (figureHeight-xAxisLabelAreaHeight)/nScopesVisible ;
            panelXOffset = 0 ;
            panelYOffset = figureHeight - panelHeight*indexOfThisScopeAmongVisibleScopes ;            
            
            % Calculate the first-pass dimensions
            leftMargin = max(minLeftMargin,min(0.13*panelWidth,maxLeftMargin)) ;
            rightMargin = max(minRightMargin,min(0.095*panelWidth,maxRightMargin)) ;
            bottomMargin = max(minBottomMargin,min(0.11*panelHeight,maxBottomMargin)) ;
            topMargin = max(minTopMargin,min(0.075*panelHeight,maxTopMargin)) ;            
            axesAndButtonsAreaWidth = panelWidth - leftMargin - rightMargin ;
            axesAndButtonsAreaHeight = panelHeight - bottomMargin - topMargin ;

            % If not enough vertical space for the buttons, hide them
            if axesAndButtonsAreaHeight < 7*yRangeButtonSize + 4*spaceBetweenButtonsInSameBank + 2*minHeightBetweenButtonBanks ,
                isEnoughHeightForButtons = false ;
                % Recalculate some things that are affected by this change
                minRightMargin = minRightMarginIfNoButtons ;
                maxRightMargin = maxRightMarginIfNoButtons ;
                rightMargin = max(minRightMargin,min(0.095*panelWidth,maxRightMargin)) ;
                axesAndButtonsAreaWidth = panelWidth - leftMargin - rightMargin ;                
            else
                isEnoughHeightForButtons = true ;
            end
            doShowButtons = doesUserWantToSeeButtons && isEnoughHeightForButtons ;
            
            % If the axes-and-buttons-area is too small, make it larger,
            % and change the right margin and/or bottom margin to accomodate
            if axesAndButtonsAreaWidth<minAxesAndButtonsAreaWidth ,                
                axesAndButtonsAreaWidth = minAxesAndButtonsAreaWidth ;
                %rightMargin = figureWidth - axesAndButtonsAreaWidth - leftMargin ;  % can be less than minRightMargin, and that's ok
            end
            if axesAndButtonsAreaHeight<minAxesAndButtonsAreaHeight ,                
                axesAndButtonsAreaHeight = minAxesAndButtonsAreaHeight ;
                bottomMargin = panelHeight - axesAndButtonsAreaHeight - topMargin ;  % can be less than minBottomMargin, and that's ok
            end

            % Set the axes width, depends on whether we're showing the
            % buttons or not
            if doShowButtons ,
                axesWidth = axesAndButtonsAreaWidth - fromAxesToYRangeButtonsWidth - yRangeButtonSize ;                
            else
                axesWidth = axesAndButtonsAreaWidth ;
            end
            axesHeight = axesAndButtonsAreaHeight ;            
            
            % Update the axes position
            axesXOffset = leftMargin ;
            axesYOffset = bottomMargin ;
            set(self.AxesGH_,'Position',[panelXOffset+axesXOffset panelYOffset+axesYOffset axesWidth axesHeight]);            
            
            % the zoom buttons
            yRangeButtonsX=axesXOffset+axesWidth+fromAxesToYRangeButtonsWidth;
            zoomOutButtonX=yRangeButtonsX;
            zoomOutButtonY=axesYOffset;  % want bottom-aligned with axes
            set(self.YZoomOutButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+zoomOutButtonX panelYOffset+zoomOutButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            zoomInButtonX=yRangeButtonsX;
            zoomInButtonY=zoomOutButtonY+yRangeButtonSize+spaceBetweenButtonsInSameBank;  % want just above other zoom button
            set(self.YZoomInButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+zoomInButtonX panelYOffset+zoomInButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            
            % the scroll buttons
            scrollUpButtonX=yRangeButtonsX;
            scrollUpButtonY=axesYOffset+axesHeight-yRangeButtonSize;  % want top-aligned with axes
            set(self.YScrollUpButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+scrollUpButtonX panelYOffset+scrollUpButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            scrollDownButtonX=yRangeButtonsX;
            scrollDownButtonY=scrollUpButtonY-yRangeButtonSize-spaceBetweenButtonsInSameBank;  % want under scroll up button
            set(self.YScrollDownButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+scrollDownButtonX panelYOffset+scrollDownButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
                        
            % the zoom-to-data buttons
            zoomToDataButtonsHeight = 3* yRangeButtonSize + 2*spaceBetweenButtonsInSameBank ;
            zoomToDataButtonsY = axesYOffset+axesHeight/2-zoomToDataButtonsHeight/2 ;            
            setYLimTightToDataButtonY = zoomToDataButtonsY + 2*(yRangeButtonSize + spaceBetweenButtonsInSameBank) ;
            set(self.SetYLimTightToDataButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+yRangeButtonsX panelYOffset+setYLimTightToDataButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            setYLimTightToDataLockedButtonY = zoomToDataButtonsY + (yRangeButtonSize + spaceBetweenButtonsInSameBank) ;
            set(self.SetYLimTightToDataLockedButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+yRangeButtonsX panelYOffset+setYLimTightToDataLockedButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            setYLimButtonY = zoomToDataButtonsY ;
            set(self.SetYLimButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+yRangeButtonsX panelYOffset+setYLimButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            
        end  % function        
        
        function setLineXDataAndYData(self, xData, yData)
            ws.setifhg(self.LineGH_, 'XData', xData, 'YData', yData) ;
        end  % function
        
        function setXAxisLimits(self, xl)
            set(self.AxesGH_, 'XLim', xl) ;
        end  % function                
        
        function setYAxisLimits(self, yl)
            set(self.AxesGH_, 'YLim', yl) ;
        end  % function                
        
        function setYAxisLabel(self, channelName, doShowUnits, units, color)
            self.clearYAxisLabel() ;
            % set the new value
            if doShowUnits ,
                if isempty(units) ,
                    unitsString = 'pure' ;
                else
                    unitsString = units ;
                end
                label = sprintf('%s (%s)',channelName,unitsString) ;
            else
                label = sprintf('%s',channelName) ;
            end
            self.YAxisLabelGH_ = ylabel(self.AxesGH_, ...
                                        label, ...
                                        'Color', color, ...
                                        'FontSize', 10, ...
                                        'Interpreter','none');
        end  % function                
        
        function clearYAxisLabel(self)
            if isempty(self.YAxisLabelGH_) ,
                % nothing to do
            else
                ws.deleteIfValidHGHandle(self.YAxisLabelGH_) ;
                self.YAxisLabelGH_ = [] ;
            end
        end  % function                
        
        function setXAxisLabel(self, color)
            % Set the x-axis tick labels to auto
            set(self.AxesGH_, 'XTickLabelMode', 'auto') ;
            % Clear any prexisting x-axis label
            if isempty(self.XAxisLabelGH_) ,
                % nothing to do
            else
                ws.deleteIfValidHGHandle(self.XAxisLabelGH_) ;
                self.XAxisLabelGH_ = [] ;
            end
            % Now set the label like we want
            label = 'Time (s)' ;
            self.XAxisLabelGH_ = xlabel(self.AxesGH_, ...
                                        label, ...
                                        'Color', color, ...
                                        'FontSize', 10, ...
                                        'Interpreter','none');
        end  % function                
        
        function clearXAxisLabel(self)
            set(self.AxesGH_, 'XTickLabel', '') ;
            if isempty(self.XAxisLabelGH_) ,
                % nothing to do
            else
                ws.deleteIfValidHGHandle(self.XAxisLabelGH_) ;
                self.XAxisLabelGH_ = [] ;
            end
        end  % function                
        
        function setControlEnablement(self, isAnalog, areYLimitsLockedTightToData)
            set(self.SetYLimTightToDataButtonGH_,'Enable',ws.onIff(isAnalog&&~areYLimitsLockedTightToData));
            set(self.SetYLimTightToDataLockedButtonGH_,'Enable',ws.onIff(isAnalog));
            set(self.SetYLimButtonGH_,'Enable',ws.onIff(isAnalog&&~areYLimitsLockedTightToData));
            set(self.YZoomInButtonGH_,'Enable',ws.onIff(isAnalog&&~areYLimitsLockedTightToData));
            set(self.YZoomOutButtonGH_,'Enable',ws.onIff(isAnalog&&~areYLimitsLockedTightToData));
            set(self.YScrollUpButtonGH_,'Enable',ws.onIff(isAnalog&&~areYLimitsLockedTightToData));
            set(self.YScrollDownButtonGH_,'Enable',ws.onIff(isAnalog&&~areYLimitsLockedTightToData));
        end  % function        
    end  % public methods block
    
    methods (Static=true)
        function result=getWidthInPixels(ax)
            % Gets the x span of the given axes, in pixels.
            savedUnits=get(ax,'Units');
            set(ax,'Units','pixels');
            pos=get(ax,'Position');
            result=pos(3);
            set(ax,'Units',savedUnits);            
        end  % function        
    end  % static methods block    
end  % classdef
