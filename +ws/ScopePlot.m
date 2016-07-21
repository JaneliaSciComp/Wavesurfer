classdef ScopePlot < handle
    
    properties
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
                     'XData', [],...
                     'YData', [],...
                     'ZData', []);            
                 
            % Y axis control buttons
            self.YZoomInButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'String','+', ...
                             'Callback',@(source,event)(parent.controlActuated('YZoomInButtonGH',source,event,isAnalog, channelIndex)));
            self.YZoomOutButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'String','-', ...
                             'Callback',@(source,event)(parent.controlActuated('YZoomOutButtonGH',source,event,isAnalog, channelIndex)));
            self.YScrollUpButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'Callback',@(source,event)(parent.controlActuated('YScrollUpButtonGH',source,event,isAnalog, channelIndex)));
            self.YScrollDownButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'Callback',@(source,event)(parent.controlActuated('YScrollDownButtonGH',source,event,isAnalog, channelIndex)));
            self.SetYLimTightToDataButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'TooltipString', 'Set y-axis limits tight to data', ....
                             'Callback',@(source,event)(parent.controlActuated('SetYLimTightToDataButtonGH',source,event,isAnalog, channelIndex)));
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
                             'Callback',@(source,event)(parent.controlActuated('SetYLimTightToDataLockedButtonGH',source,event,isAnalog, channelIndex)));                      
            self.SetYLimButtonGH_ = ...
                ws.uicontrol('Parent',parent.FigureGH, ...
                             'Style','pushbutton', ...
                             'TooltipString', 'Set y-axis limits', ....
                             'Callback',@(source,event)(parent.controlActuated('SetYLimButtonGH',source,event,isAnalog, channelIndex)));                      
        end  % constructor
        
        function delete(self)
            % Do I even need to do this stuff?  Those GHs will become
            % invalid when the figure HG object is deleted...
            %fprintf('ScopeFigure::delete()\n');
            ws.deleteIfValidHGHandle(self.LineGH_);
            ws.deleteIfValidHGHandle(self.AxesGH_);            
        end  % function        
        
        function update(self,varargin)
            % Called when the caller wants the figure to fully re-sync with the
            % model, from scratch.  This may cause the figure to be
            % resized, but this is always done in such a way that the
            % upper-righthand corner stays in the same place.
            self.updateImplementation_(varargin{:});
        end        
    end  % public methods block
    
    methods (Access=protected)        
        function updateImplementation_(self, isAnalog, channelIndex)
            % This method should make sure the figure is fully synched with the
            % model state after it is called.  This includes existance,
            % placement, sizing, enablement, and properties of each control, and
            % of the figure itself.

            % This implementation should work in most cases, but can be overridden by
            % subclasses if needed.
            self.updateControlsInExistance_();
            self.updateControlPropertiesImplementation_(isAnalog, channelIndex);
            self.updateControlEnablementImplementation_(isAnalog, channelIndex);
            self.layout_();
        end                
    end  % protected methods block    
    
    methods
%         function set.Visible(self,newValue)
%             setifhg(self.FigureGH,'Visible',onIff(newValue));
%         end
%         
%         function isVisible=get.Visible(self)
%             if ishghandle(self.FigureGH), 
%                 isVisible=strcmp(get(self.FigureGH,'Visible'),'on');
%             else
%                 isVisible=false;
%             end
%         end
        
%         function set.XLim(self,newValue)
%             if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
%                 self.XLim_=newValue;
%                 set(self.AxesGH_,'XLim',newValue);
%             end
%             %self.broadcast('DidSetXLim');
%         end  % function
%         
%         function value=get.XLim(self)
%             value=self.XLim_;
%         end  % function
%         
%         function set.YLim(self,newValue)
%             %fprintf('ScopeFigure::set.YLim()\n');
%             if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
%                 self.YLim_=newValue;
%                 set(self.AxesGH_,'YLim',newValue);
%             end
%             %self.broadcast('DidSetYLim');
%         end  % function
%             
%         function value=get.YLim(self)
%             value=self.YLim_;
%         end  % function
                
%         function didSetXLimInAxesGH(self,varargin)
%             self.XLim=get(self.AxesGH_,'XLim');
%         end  % function
        
%         function didSetYLimInAxesGH(self,varargin)
%             %fprintf('ScopeFigure::didSetYLimInAxesGH()\n');
%             %ylOld=self.YLim
%             ylNew=get(self.AxesGH_,'YLim');
%             self.YLim=ylNew;
%         end  % function
        
%         function modelPropertyWasSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD,INUSL>
%             if isequal(propertyName,'YLim') ,
%                 self.updateYAxisLimits();
%             elseif isequal(propertyName,'XOffset') ||  isequal(propertyName,'XSpan') ,
%                 self.modelXAxisLimitSet();                
%             else
%                 self.modelGenericVisualPropertyWasSet_();
%             end
%         end
        
%         function modelYAutoScaleWasSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             isToggleOn=isequal(get(self.SetYLimTightToDataButtonGH_,'State'),'on');
%             if isToggleOn ~= self.Model.YAutoScale ,
%                 set(self.SetYLimTightToDataButtonGH_,'State',onIff(self.Model.YAutoScale));  % sync to the model
%             end
%         end
        
        function updateXAxisLimits(self,xl)
            self.updateXAxisLimits_(xl);
        end  % function
        
        function updateYAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateYAxisLimits_();
        end  % function
        
        function updateAreYLimitsLockedTightToData(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            %self.updateAreYLimitsLockedTightToData_();
            %self.updateControlEnablement_();
            self.update() ;
        end  % function
        
        function modelChannelAdded(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             % Redimension downsampled data, clearing the existing data in
%             % the process
%             nChannels=self.Model.NChannels;
%             self.XForPlotting_=zeros(0,1);
%             self.YForPlotting_=zeros(0,nChannels);
            
            % Do other stuff
            self.addChannelLineToAxes_();
            self.update();
        end  % function
        
        function tellModelXSpanInPixels(self, broadcaster, eventName, propertyName, source, event)  %#ok<INUSD>
            xSpanInPixels=ws.ScopeAxes.getWidthInPixels(self.AxesGH_) ;
            self.Model.hereIsXSpanInPixels_(xSpanInPixels) ;
        end
        
        function modelDataAdded(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             % Need to pack up all the y data into a single array for
%             % downsampling (should change things more globally to make this
%             % unnecessary)
%             x = self.Model.XData ;
%             y = self.Model.YData ;
%             %nScans = length(x) ;
%             
%             % This shouldn't ever happen, but just in case...
%             if isempty(x) ,
%                 return
%             end
%             
%             % Figure out the downsampling ratio
%             xSpanInPixels=ws.ScopeFigure.getWidthInPixels(self.AxesGH_);
%             r=ws.ScopeFigure.ratioSubsampling(x,self.Model.XSpan,xSpanInPixels);
%             
%             % get the current downsampled data
%             xForPlottingOriginal=self.XForPlotting_;
%             yForPlottingOriginal=self.YForPlotting_;
%             
%             % Trim off any that is beyond the left edge of the plotted data
%             x0=x(1);  % this is the time of the first sample in the model's XData
%             keep=(x0<=xForPlottingOriginal);
%             xForPlottingOriginalTrimmed=xForPlottingOriginal(keep);
%             yForPlottingOriginalTrimmed=yForPlottingOriginal(keep,:);
%             
%             % Get just the new data
%             if isempty(xForPlottingOriginal)
%                 xNew=x;
%                 yNew=y;
%             else                
%                 isNew=(xForPlottingOriginal(end)<x);
%                 xNew=x(isNew);
%                 yNew=y(isNew);
%             end
%             
%             % Downsample the new data
%             [xForPlottingNew,yForPlottingNew]=ws.minMaxDownsampleMex(xNew,yNew,r);            
%             
%             % Concatenate old and new downsampled data, commit to self
%             self.XForPlotting_=[xForPlottingOriginalTrimmed; ...
%                                xForPlottingNew];
%             self.YForPlotting_=[yForPlottingOriginalTrimmed; ...
%                                yForPlottingNew];

            % Update the lines
            self.updateLineXDataAndYData_();
        end  % function
        
        function modelDataCleared(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            %fprintf('ScopeFigure::modelDataCleared()\n');
            %nChannels=self.Model.NChannels;
            %self.XForPlotting_=zeros(0,1);
            %self.YForPlotting_=zeros(0,nChannels);                        
            self.updateLineXDataAndYData_();                      
        end  % function
        
        function modelChannelUnitsSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.update();
        end  % function

        function setColorsAndIcons(self, controlForegroundColor, controlBackgroundColor, ...
                                         axesForegroundColor, axesBackgroundColor, ...
                                         traceLineColor, ...
                                         yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon)
            % If there are issues with the model, just return
            %displayFigure = self.Parent_ ;
            
            % Update the colors
            %controlBackgroundColor  = displayFigure.ControlBackgroundColor ;
            %controlForegroundColor = displayFigure.ControlForegroundColor ;
            %axesBackgroundColor = displayFigure.AxesBackgroundColor ;
            %axesForegroundColor = displayFigure.AxesForegroundColor ;
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
            
            % Set the button scroll up/down button images
%             yScrollUpIcon   = displayFigure.YScrollUpIcon   ;
%             yScrollDownIcon = displayFigure.YScrollDownIcon ;
%             yTightToDataIcon = displayFigure.YTightToDataIcon ;
%             yTightToDataLockedIcon = displayFigure.YTightToDataLockedIcon ;
            set(self.YScrollUpButtonGH_,'CData',yScrollUpIcon);
            set(self.YScrollDownButtonGH_,'CData',yScrollDownIcon);
            set(self.SetYLimTightToDataButtonGH_,'CData',yTightToDataIcon);
            set(self.SetYLimTightToDataLockedButtonGH_,'CData',yTightToDataLockedIcon);            
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
        
%         function syncTitleAndTagsToModel(self)
%             import ws.onIff
%             
%             model=self.Model;
%             set(self.FigureGH, ...
%                 'Tag',model.Tag,...
%                 'Name', model.Title);
% %             , ...
% %                 'Color', model.BackgroundColor);
% %             set(self.AxesGH_, ...
% %                 'FontSize', model.FontSize, ...
% %                 'FontWeight', model.FontWeight, ...
% %                 'Color', model.BackgroundColor, ...
% %                 'XColor', model.ForegroundColor, ...
% %                 'YColor', model.ForegroundColor, ...
% %                 'ZColor', model.ForegroundColor, ...
% %                 'XGrid', onIff(model.GridOn), ...
% %                 'YGrid', onIff(model.GridOn) ...
% %                 );
% %             set(self.AxesGH_, ...
% %                 'XGrid', onIff(model.IsGridOn), ...
% %                 'YGrid', onIff(model.IsGridOn) ...
% %                 );
%         end  % function
    end  % methods
    
    methods (Access=protected)        
%         function updateImplementation_(self,varargin)
%             % Syncs self with the model.
%             
%             % If there are issues with the model, just return
%             model=self.Model;
%             if isempty(model) || ~isvalid(model) ,
%                 return
%             end
% 
%             % Update the togglebutton
%             self.updateAreYLimitsLockedTightToData_();
% 
%             % Update the axis limits
%             self.updateXAxisLimits_();
%             self.updateYAxisLimits_();
%             
%             % Update the graphics objects to match the model
%             self.updateYAxisLabel_();
%             self.updateLineXDataAndYData_();
%             
%             % Update the enablement of controls
%             %import ws.onIff
%             %set(self.SetYLimTightToDataButtonGH_,'Enable',onIff(isWavesurferIdle));
%             %set(self.YLimitsMenuItemGH_,'Enable',onIff(isWavesurferIdle));            
%             %set(self.SetYLimTightToDataButtonGH_,'Enable',onIff(true));
%             %set(self.YLimitsMenuItemGH_,'Enable',onIff(true));            
%         end                

%         function loadIcons_(self)
%             % Load icons from disk, store them in instance vars
%             
%             wavesurferDirName=fileparts(which('wavesurfer'));
% 
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data.png');
%             cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
%             self.SetYLimTightToDataIcon_ = cdata ;
%                                      
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data_locked.png');
%             cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
%             self.SetYLimTightToDataLockedIcon_ = cdata ;
% 
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'up_arrow.png');
%             cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;                      
%             self.YScrollUpIcon_ = cdata ;
%             
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'down_arrow.png');
%             cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;                      
%             self.YScrollDownIcon_ = cdata ;
%         end

        function updateControlsInExistance_(self)  %#ok<MANU>
            % All controls are fixed, so nothing to do here.
        end  % function
        
        function updateControlPropertiesImplementation_(self, isAnalog, channelIndex)
            % If there are issues with the model, just return
            displayFigure = self.Parent_ ;
            displayModel = displayFigure.Model ;            
            
            % Update the colors
            controlBackgroundColor  = displayFigure.ControlBackgroundColor ;
            controlForegroundColor = displayFigure.ControlForegroundColor ;
            axesBackgroundColor = displayFigure.AxesBackgroundColor ;
            axesForegroundColor = displayFigure.AxesForegroundColor ;
            set(self.AxesGH_,'Color',axesBackgroundColor);
            set(self.AxesGH_,'XColor',axesForegroundColor);
            set(self.AxesGH_,'YColor',axesForegroundColor);
            set(self.AxesGH_,'ZColor',axesForegroundColor);
            set(self.AxesGH_,'ColorOrder',displayFigure.ColorOrder);

            % Set the line color
            set(self.LineGH_,'Color',displayFigure.TraceLineColor);

            % Set the button colors
            set(self.YZoomInButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);
            set(self.YZoomOutButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);
            set(self.YScrollUpButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);
            set(self.YScrollDownButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);            
            set(self.SetYLimTightToDataButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);            
            set(self.SetYLimTightToDataLockedButtonGH_,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);            
            
            % Set the button scroll up/down button images
            yScrollUpIcon   = self.Parent_.YScrollUpIcon   ;
            yScrollDownIcon = self.Parent_.YScrollDownIcon ;
            yTightToDataIcon = self.Parent_.YTightToDataIcon ;
            yTightToDataLockedIcon = self.Parent_.YTightToDataLockedIcon ;
            set(self.YScrollUpButtonGH_,'CData',yScrollUpIcon);
            set(self.YScrollDownButtonGH_,'CData',yScrollDownIcon);
            set(self.SetYLimTightToDataButtonGH_,'CData',yTightToDataIcon);
            set(self.SetYLimTightToDataLockedButtonGH_,'CData',yTightToDataLockedIcon);
            
            % Update the axes grid on/off
            isGridOn = displayModel.IsGridOn ;
            set(self.AxesGH_, ...
                'XGrid', ws.onIff(isGridOn), ...
                'YGrid', ws.onIff(isGridOn) ...
                );
            
            % Update the axis limits
            self.updateXAxisLimits_();
            self.updateYAxisLimits_(isAnalog, channelIndex);
            
            % Update the graphics objects to match the model
            xlabel(self.AxesGH_,'Time (s)','Color',axesForegroundColor,'FontSize',10,'Interpreter','none');
            self.updateYAxisLabel_(isAnalog, channelIndex, axesForegroundColor);
            self.updateLineXDataAndYData_();
        end  % function
        
        function updateControlEnablementImplementation_(self)
            % Update the enablement of controls
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToData ;
            
            onIffNotAreYLimitsLockedTightToData = ws.onIff(~areYLimitsLockedTightToData) ;
            %set(self.YLimitsMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);            
            set(self.SetYLimTightToDataButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.SetYLimTightToDataMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YZoomInButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YZoomOutButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YScrollUpButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YScrollDownButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            %set(self.YZoomInMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            %set(self.YZoomOutMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            %set(self.YScrollUpMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            %set(self.YScrollDownMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
        end  % function
    end
    
    methods
        function layout(self, nScopesVisible, indexOfThisScopeAmongVisibleScopes)
            % This method should make sure all the controls are sized and placed
            % appropriately given the current model state.  

            % Layout parameters
            minLeftMargin = 46 ;
            maxLeftMargin = 62 ;
            
            minRightMarginIfButtons = 8 ;            
            maxRightMarginIfButtons = 8 ;            

            minRightMarginIfNoButtons = 8 ;            
            maxRightMarginIfNoButtons = 16 ;            
            
            %minBottomMargin = 38 ;  % works ok with HG1
            minBottomMargin = 44 ;  % works ok with HG2 and HG1
            maxBottomMargin = 52 ;
            
            minTopMargin = 10 ;
            maxTopMargin = 26 ;            
            
            minAxesAndButtonsAreaWidth = 20 ;
            minAxesAndButtonsAreaHeight = 20 ;
            
            fromAxesToYRangeButtonsWidth = 6 ;
            yRangeButtonSize = 20 ;  % those buttons are square
            spaceBetweenScrollButtons=5;
            spaceBetweenZoomButtons=5;
            spaceBetweenZoomToDataButtons=5;
            minHeightBetweenButtonBanks = 5 ;
            
            % Show buttons only if user wants them
            doesUserWantToSeeButtons = self.Model.DoShowButtons ;            

            if doesUserWantToSeeButtons ,
                minRightMargin = minRightMarginIfButtons ;
                maxRightMargin = maxRightMarginIfButtons ;
            else
                minRightMargin = minRightMarginIfNoButtons ;
                maxRightMargin = maxRightMarginIfNoButtons ;
            end
            
            % Get the current figure width, height
            figurePosition = get(self.Parent_.FigureGH, 'Position') ;
            figureSize = figurePosition(3:4);
            figureWidth = figureSize(1) ;
            figureHeight = figureSize(2) ;
            
            % There's a rectangle within the figure where this scope axes
            % will go.  We'll call this the "panel".  Calculate the
            % position of the panel within the figure rectangle.
            panelWidth = figureWidth ;
            %nScopesVisible = self.Model.Parent.IsScopeVisibleWhenDisplayEnabled ;
            panelHeight = figureHeight/nScopesVisible ;
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
            if axesAndButtonsAreaHeight < 4*yRangeButtonSize + spaceBetweenScrollButtons + spaceBetweenZoomButtons + minHeightBetweenButtonBanks ,
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
            set(self.AxesGH_,'Position',[panelXOffset+axesXOffset axesYOffset axesWidth axesHeight]);            
            
            % the zoom buttons
            yRangeButtonsX=axesXOffset+axesWidth+fromAxesToYRangeButtonsWidth;
            zoomOutButtonX=yRangeButtonsX;
            zoomOutButtonY=axesYOffset;  % want bottom-aligned with axes
            set(self.YZoomOutButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+zoomOutButtonX panelYOffset+zoomOutButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            zoomInButtonX=yRangeButtonsX;
            zoomInButtonY=zoomOutButtonY+yRangeButtonSize+spaceBetweenZoomButtons;  % want just above other zoom button
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
            scrollDownButtonY=scrollUpButtonY-yRangeButtonSize-spaceBetweenScrollButtons;  % want under scroll up button
            set(self.YScrollDownButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+scrollDownButtonX panelYOffset+scrollDownButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
                        
            % the zoom-to-data buttons
            zoomToDataButtonsHeight = yRangeButtonSize + spaceBetweenZoomToDataButtons + yRangeButtonSize ;
            zoomToDataButtonsY = axesYOffset+axesHeight/2-zoomToDataButtonsHeight/2 ;            
            setYLimTightToDataButtonY = zoomToDataButtonsY + yRangeButtonSize + spaceBetweenZoomToDataButtons ;
            set(self.SetYLimTightToDataButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+yRangeButtonsX panelYOffset+setYLimTightToDataButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            setYLimTightToDataLockedButtonY = zoomToDataButtonsY ;
            set(self.SetYLimTightToDataLockedButtonGH_, ...
                'Visible',ws.onIff(doShowButtons) , ...
                'Position',[panelXOffset+yRangeButtonsX panelYOffset+setYLimTightToDataLockedButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            
        end  % function        
        
        function setLineXDataAndYData(self, xData, yData)
            ws.setifhg(self.LineGH_, 'XData', xData, 'YData', yData) ;
        end  % function
        
        function setXAxisLimits(self, xl)
            set(self.AxesGH_, 'XLim', xl) ;
        end  % function                
    end  % public methods block
    
    methods (Access = protected)
        function modelGenericVisualPropertyWasSet_(self)
            self.update();
        end  % function 
        
        function updateYAxisLabel_(self,color)
            % Updates the y axis label handle graphics to match the model state
            % and that of the Acquisition subsystem.
            %set(self.AxesGH_,'YLim',self.YOffset+[0 self.YRange]);
            if self.Model.NChannels==0 ,
                ylabel(self.AxesGH_,'Signal','Color',color,'FontSize',10,'Interpreter','none');
            else
                firstChannelName=self.Model.ChannelNames{1};
                %iFirstChannel=self.Model.WavesurferModel.Acquisition.iChannelFromName(firstChannelName);
                %units=self.Model.WavesurferModel.Acquisition.ChannelUnits(iFirstChannel);
                units=self.Model.YUnits;
                if isempty(units) ,
                    unitsString = 'pure' ;
                else
                    unitsString = units ;
                end
                ylabel(self.AxesGH_,sprintf('%s (%s)',firstChannelName,unitsString),'Color',color,'FontSize',10,'Interpreter','none');
            end
        end  % function        

        function updateYAxisLimits_(self)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            ylimInModel=self.Model.YLim;
            set(self.AxesGH_, 'YLim', ylimInModel);
        end  % function        

%         function updateAreYLimitsLockedTightToData_(self)
%             % Update the axes limits to match those in the model
%             if isempty(self.Model) || ~isvalid(self.Model) ,
%                 return
%             end
%             areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToData ;
%             set(self.SetYLimTightToDataLockedButtonGH_,'State',ws.onIff(areYLimitsLockedTightToData));            
%         end  % function        
        
        
%         function updateAxisLimits(self)
%             % Update the axes limits to match those in the model
%             if isempty(self.Model) || ~isvalid(self.Model) ,
%                 return
%             end
%             xl=self.Model.XLim;
%             yl=self.Model.YLim;
%             setifhg(self.AxesGH_, 'XLim', xl, 'YLim', yl);
%         end

%         function updateScaling(self)
% %             % Update the axes x-limits to accomodate the lines in it.
% %             xMax=self.Model.MaxXData;            
% %             xLim = [max([0, xMax - self.Model.XRange]), max(xMax, self.Model.XRange)];
% %             setifhg(self.AxesGH_, 'XLim', xLim);
%         end
        
%         function updateReferenceLines(self)
%             % Update the horizontal and vertical center lines, and the
%             % ground lines to accomodate the current internal axis limits.
%             % Then update the x-axis scaling to accomodate the lines.
%             xl = self.Model.XLim;
%             yl = self.Model.YLim;
%             
%             setifhg(self.HorizontalCenterLineGH,'XData',[xl(1) xl(1)+.5*(xl(2)-xl(1)) xl(2)]);
%             setifhg(self.HorizontalCenterLineGH,'YData',ones(3, 1) * (yl(1) + 0.5* diff(yl)));
%             
%             setifhg(self.VerticalCenterLineGH,'XData',ones(3, 1) * (xl(1) + 0.5* diff(xl)));
%             setifhg(self.VerticalCenterLineGH,'YData',[yl(1) yl(1)+.5*(yl(2)-yl(1)) yl(2)]);
%             
%             setifhg(self.GroundLineGH,'XData',xl,'YData',[0 0]);
%         end
        
%         function updateAxesYLimMode(self)
%             isYAxisAutomaticallyScaled=self.Model.YAutoScale;
%             if isYAxisAutomaticallyScaled ,
%                 set(self.Axes, 'YLimMode', 'auto');
%             else
%                 set(self.Axes, 'YLimMode', 'manual');
%             end
%         end
        
%         function controlActuated(self,source,event) %#ok<INUSD>
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 return
%             end
%             self.Controller.controlActuated(source);
%         end  % function
    end  % methods (Access = protected)

%     methods
%         function closeRequested(self,source,event)
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 delete(self);
%             else
%                 self.Controller.windowCloseRequested(source,event);
%             end
%         end  % function
%     end
    
%     methods
%         function castOffAllAttachments(self)
%             self.unsubscribeFromAll() ;
%             %self.deleteFigureGH() ;
%         end
%     end

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
    
%     methods (Access = protected)
%         % Have to override with identical function text b/c of
%         % protected/protected horseshit
%         function setHGTagsToPropertyNames_(self)
%             % For each object property, if it's an HG object, set the tag
%             % based on the property name, and set other HG object properties that can be
%             % set systematically.
%             mc=metaclass(self);
%             propertyNames={mc.PropertyList.Name};
%             for i=1:length(propertyNames) ,
%                 propertyName=propertyNames{i};
%                 propertyThing=self.(propertyName);
%                 if ~isempty(propertyThing) && all(ishghandle(propertyThing)) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
%                     % Set Tag
%                     set(propertyThing,'Tag',propertyName);                    
%                 end
%             end
%         end  % function        
%     end  % protected methods block
    
end
