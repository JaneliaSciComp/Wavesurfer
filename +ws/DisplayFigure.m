classdef DisplayFigure < ws.MCOSFigure
    
%     properties (Dependent=true)
%         % Typically, MCOSFigures don't have public properties like this.  These exist for ScopeFigure
%         % to enable us to keep the ScopeModel state in sync with the HG figure XLim and YLim if the 
%         % user changes them using the default Matlab HG figure tools.  Basically, the ScopeFigure defines 
%         % events DidSetXLim and DidSetYLim, which it fires if the HG figure XLim or YLim are changes.  The
%         % ScopeController subscribes to these events, and when they occur it sets the corresponding properties in the
%         % model.  Care has to be taken to avoid infinite loops, as you might imagine.
%         XLim
%         YLim
%     end

%     properties (Dependent=true)
%         YScrollUpIcon
%         YScrollDownIcon 
%         YTightToDataIcon 
%         YTightToDataLockedIcon 
%         ControlForegroundColor
%         ControlBackgroundColor
%         AxesForegroundColor
%         AxesBackgroundColor
%         TraceLineColor
%     end

    properties (Access = protected)
        AnalogScopePlots_ = ws.ScopePlot.empty(1,0)  % an array of type ws.ScopePlot
        DigitalScopePlots_ = ws.ScopePlot.empty(1,0)  % an array of type ws.ScopePlot
                
        ViewMenu_
        InvertColorsMenuItem_
        ShowGridMenuItem_
        DoShowButtonsMenuItem_

        ChannelsMenu_
        AnalogChannelMenuItems_
        DigitalChannelMenuItems_
        
        NormalYScrollUpIcon_ 
        NormalYScrollDownIcon_ 
        NormalYTightToDataIcon_ 
        NormalYTightToDataLockedIcon_ 
        NormalYCaretIcon_ 
        
%         YScrollUpIcon_ 
%         YScrollDownIcon_ 
%         YTightToDataIcon_ 
%         YTightToDataLockedIcon_ 
%         ControlForegroundColor_
%         ControlBackgroundColor_
%         AxesForegroundColor_
%         AxesBackgroundColor_
%         TraceLineColor_
    end    
    
%     properties (Dependent=true, SetAccess=immutable, Hidden=true)  % hidden so not show in disp() output
%         IsVisibleWhenDisplayEnabled
%     end
    
%     events
%         DidSetXLim
%         DidSetYLim
%     end

    methods
        function self=DisplayFigure(model, controller)
            % Call the superclass constructor
            self = self@ws.MCOSFigure(model,controller) ;
            
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
                'ResizeFcn', @(source,event)(self.layout_()) );
            
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
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_manual_set.png');
            self.NormalYCaretIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;

            % Create the widgets that will persist through the life of the
            % figure
            self.createFixedControls_();
            
            % Set the initial figure position
            self.setInitialFigureSize_();
            
            % Subscribe to some model events
            %self.didSetModel_();
            
%             % reset the downsampled data
%             nChannels=length(model.ChannelNames);
%             self.XForPlotting_=zeros(0,1);
%             self.YForPlotting_=zeros(0,nChannels);
%             
%             % Subscribe to some model events
%             model.subscribeMe(self,'Update','','update');
%             model.subscribeMe(self,'UpdateYAxisLimits','','updateYAxisLimits');
%             model.subscribeMe(self,'UpdateAreYLimitsLockedTightToData','','updateAreYLimitsLockedTightToData');
%             model.subscribeMe(self,'ChannelAdded','','modelChannelAdded');
%             model.subscribeMe(self,'DataAdded','','modelDataAdded');
%             model.subscribeMe(self,'DataCleared','','modelDataCleared');
%             model.subscribeMe(self,'DidSetChannelUnits','','modelChannelUnitsSet');           
% 
%             % Subscribe to events in the master model
%             if ~isempty(model) ,
%                 display=model.Parent;
%                 if ~isempty(display) ,
%                     wavesurferModel=display.Parent;
%                     if ~isempty(wavesurferModel) ,
%                         wavesurferModel.subscribeMe(self,'DidSetState','','update');
%                     end
%                 end
%             end            
            
%             % Do stuff to make ws.most.Controller happy
%             self.setHGTagsToPropertyNames_();
%             self.updateGuidata_();
            
            % sync up self to model
            self.update();
            
            % position next to main window
            mainFigure = controller.Parent.Figure ;
            self.positionUpperLeftRelativeToOtherUpperRight(mainFigure, [40 0]) ;

            % Subscribe to events
            if ~isempty(model) ,
               model.subscribeMe(self,'Update','','update');
               %model.subscribeMe(self,'NScopesMayHaveChanged','','update');
               model.subscribeMe(self,'DidSetIsEnabled','','update');
               model.subscribeMe(self,'DidSetUpdateRate','','updateControlProperties');
               %model.subscribeMe(self,'DidSetScopeIsVisibleWhenDisplayEnabled','','update');
               %model.subscribeMe(self,'UpdateXSpan','','updateControlProperties');
               model.subscribeMe(self,'UpdateXOffset','','updateXAxisLimits');
               model.subscribeMe(self,'UpdateXSpan','','updateXAxisLimits');
               model.subscribeMe(self,'UpdateYAxisLimits','','updateYAxisLimits');
               model.subscribeMe(self,'DataAdded','','modelDataAdded');
               model.subscribeMe(self,'DataCleared','','modelDataCleared');
               wavesurferModel=model.Parent;
               if ~isempty(wavesurferModel) ,
                   wavesurferModel.subscribeMe(self,'DidSetState','','update');
               end
            end
            
        end  % constructor
        
        function delete(self)
            self.AnalogScopePlots_ = [] ;  % not really necessary
            self.DigitalScopePlots_ = [] ;  % not really necessary
        end  % function
        
        function tellModelXSpanInPixels(self, broadcaster, eventName, propertyName, source, event)  %#ok<INUSD>
            if isempty(self.ScopePlots) ,
                xSpanInPixels = 400 ;  % this is a reasonable value, and presumably it won't much matter
            else
                xSpanInPixels=self.ScopePlots(1).getAxesWidthInPixels() ;
            end
            self.Model.hereIsXSpanInPixels(xSpanInPixels) ;
        end
        
%         function set(self,propName,value)
%             % Override MCOSFigure set to catch XLim, YLim
%             if strcmpi(propName,'XLim') ,
%                 self.XLim=value;XLim
%             elseif strcmpi(propName,'YLim') ,
%                 self.YLim=value;
%             else
%                 set@ws.MCOSFigure(self,propName,value);
%             end
%         end  % function

%         function result = get.YScrollUpIcon(self)
%             result = self.YScrollUpIcon_ ;
%         end
%         
%         function result = get.YScrollDownIcon(self)
%             result = self.YScrollDownIcon_ ;
%         end
%         
%         function result = get.YTightToDataIcon(self)
%             result = self.YTightToDataIcon_ ;
%         end
%         
%         function result = get.YTightToDataLockedIcon(self)
%             result = self.YTightToDataLockedIcon_ ;
%         end
% 
%         function result = get.TraceColorLine(self)
%             result = self.TraceColorLine_ ;
%         end
%         
%         function result = get.ControlForegroundColor(self)
%             result = self.ControlForegroundColor_ ;
%         end
%         
%         function result = get.ControlBackgroundColor(self)
%             result = self.ControlBackgroundColor_ ;
%         end
%         
%         function result = get.AxesForegroundColor(self)
%             result = self.AxesForegroundColor_ ;
%         end
%         
%         function result = get.AxesBackgroundColor(self)
%             result = self.AxesBackgroundColor_ ;
%         end
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
            nScopes = self.Model.NScopes ;
            initialHeight = min(250 * max(1,nScopes), maxInitialHeight) ;
            initialSize=[700 initialHeight];
            figurePosition=[offset initialSize];
            set(self.FigureGH,'Position',figurePosition);
        end  % function
        
%         function willSetModel_(self)            
%             % % clear the downsampled data
%             % self.XForPlotting_=zeros(0,1);
%             % self.YForPlotting_=zeros(0,0);
% 
%             % Call the superclass method
%             willSetModel_@ws.MCOSFigure(self);
% 
%             % Get the Model
%             model = self.Model ;            
% 
%             % If model is nonempty, do some unsubscribing
%             if ~isempty(model) ,
%                 % Unsubscribe from events in the model
%                 %model.unsubscribeMeFromAll(self) ;
% 
%                 % Unsubsribe from events in the master model
%                 display=model.Parent;
%                 if ~isempty(display) && isvalid(display) ,
%                     wavesurferModel=display.Parent;
%                     if ~isempty(wavesurferModel) && isvalid(display) ,
%                         wavesurferModel.unsubscribeMeFromAll(self);
%                     end
%                 end
%             end
%         end  % function
        
%         function didSetModel_(self)
%             model = self.Model ;
% 
%             % % reset the downsampled data
%             % if ~isempty(model) ,
%             %     nChannels=length(model.ChannelNames);
%             %     self.XForPlotting_=zeros(0,1);
%             %     self.YForPlotting_=zeros(0,nChannels);
%             % end
% 
%             % Call the superclass method
%             didSetModel_@ws.MCOSFigure(self);
% 
%             % Subscribe to some model events
%             if ~isempty(model) ,
%                 model.subscribeMe(self,'Update','','update');
%                 model.subscribeMe(self,'UpdateXOffset','','updateXAxisLimits');
%                 model.subscribeMe(self,'UpdateXSpan','','updateXAxisLimits');
%                 %model.subscribeMe(self,'UpdateYAxisLimits','','updateYAxisLimits');
%                 %model.subscribeMe(self,'UpdateAreYLimitsLockedTightToData','','updateAreYLimitsLockedTightToData');
%                 %model.subscribeMe(self,'ChannelAdded','','modelChannelAdded');
%                 model.subscribeMe(self,'DataAdded','','modelDataAdded');
%                 model.subscribeMe(self,'DataCleared','','modelDataCleared');
%                 %model.subscribeMe(self,'DidSetChannelUnits','','modelChannelUnitsSet');
%                 %model.subscribeMe(self,'ItWouldBeNiceToKnowXSpanInPixels','','tellModelXSpanInPixels') ;
%             end
% 
%             % Subscribe to events in the master model
%             if ~isempty(model) ,
%                 display=model.Parent;
%                 if ~isempty(display) ,
%                     wavesurferModel=display.Parent;
%                     if ~isempty(wavesurferModel) ,
%                         wavesurferModel.subscribeMe(self,'DidSetState','','update');
%                     end
%                 end
%             end
%         end  % function
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
        
        function updateXAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateXAxisLimits_();
        end  % function
        
        function updateYAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSL>
            args = event.Args ;
            aiChannelIndex = args{1} ;
            self.updateYAxisLimits_(aiChannelIndex);
        end  % function
        
        function updateAreYLimitsLockedTightToData(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            %self.updateAreYLimitsLockedTightToData_();
            %self.updateControlEnablement_();
            self.update() ;
        end  % function
        
%         function modelChannelAdded(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
% %             % Redimension downsampled data, clearing the existing data in
% %             % the process
% %             nChannels=self.Model.NChannels;
% %             self.XForPlotting_=zeros(0,1);
% %             self.YForPlotting_=zeros(0,nChannels);
%             
%             % Do other stuff
%             self.addChannelLineToAxes_();
%             self.update();
%         end  % function
        
%         function tellModelXSpanInPixels(self, broadcaster, eventName, propertyName, source, event)  %#ok<INUSD>
%             xSpanInPixels=ws.ScopeFigure.getWidthInPixels(self.AxesGH_) ;
%             self.Model.hereIsXSpanInPixels_(xSpanInPixels) ;
%         end
        
%         function modelDataAdded(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
% %             % Need to pack up all the y data into a single array for
% %             % downsampling (should change things more globally to make this
% %             % unnecessary)
% %             x = self.Model.XData ;
% %             y = self.Model.YData ;
% %             %nScans = length(x) ;
% %             
% %             % This shouldn't ever happen, but just in case...
% %             if isempty(x) ,
% %                 return
% %             end
% %             
% %             % Figure out the downsampling ratio
% %             xSpanInPixels=ws.ScopeFigure.getWidthInPixels(self.AxesGH_);
% %             r=ws.ScopeFigure.ratioSubsampling(x,self.Model.XSpan,xSpanInPixels);
% %             
% %             % get the current downsampled data
% %             xForPlottingOriginal=self.XForPlotting_;
% %             yForPlottingOriginal=self.YForPlotting_;
% %             
% %             % Trim off any that is beyond the left edge of the plotted data
% %             x0=x(1);  % this is the time of the first sample in the model's XData
% %             keep=(x0<=xForPlottingOriginal);
% %             xForPlottingOriginalTrimmed=xForPlottingOriginal(keep);
% %             yForPlottingOriginalTrimmed=yForPlottingOriginal(keep,:);
% %             
% %             % Get just the new data
% %             if isempty(xForPlottingOriginal)
% %                 xNew=x;
% %                 yNew=y;
% %             else                
% %                 isNew=(xForPlottingOriginal(end)<x);
% %                 xNew=x(isNew);
% %                 yNew=y(isNew);
% %             end
% %             
% %             % Downsample the new data
% %             [xForPlottingNew,yForPlottingNew]=ws.minMaxDownsampleMex(xNew,yNew,r);            
% %             
% %             % Concatenate old and new downsampled data, commit to self
% %             self.XForPlotting_=[xForPlottingOriginalTrimmed; ...
% %                                xForPlottingNew];
% %             self.YForPlotting_=[yForPlottingOriginalTrimmed; ...
% %                                yForPlottingNew];
% 
%             % Update the lines
%             self.updateLineXDataAndYData_();
%         end  % function
        
        function modelDataCleared(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateLineXDataAndYData_();                      
        end  % function
        
%         function modelChannelUnitsSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             self.update();
%         end  % function

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

        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
%             %model = self.Model ;
%             self.AxesGH_ = ...
%                 axes('Parent', self.FigureGH, ...
%                      'Units','pixels', ...
%                      'HandleVisibility','off', ...
%                      'Box','on' );
% %                      'XGrid', ws.onIff(model.IsGridOn), ...
% %                      'YGrid', ws.onIff(model.IsGridOn) );
%             %         'Position', [0.11 0.11 0.87 0.83], ...
% %                      'XColor', model.ForegroundColor, ...
% %                      'YColor', model.ForegroundColor, ...
% %                      'ZColor', model.ForegroundColor, ...
% %                      'FontSize', model.FontSize, ...
% %                      'FontWeight', model.FontWeight, ...
% %                     'Color', model.BackgroundColor, ...
%             
%             colorOrder = get(self.AxesGH_, 'ColorOrder');
%             %colorOrder = [1 1 1; 1 0.25 0.25; colorOrder];
%             colorOrder = [0 0 0; colorOrder];
%             set(self.AxesGH_, 'ColorOrder', colorOrder);

            % Create the x-axis label
            %xlabel(self.AxesGH_,sprintf('Time (%s)',string(model.XUnits)),'FontSize',10);

            % Set up listeners to monitor the axes XLim, YLim, and to set
            % the XLim and YLim properties when they change.  This is
            % mainly so that the XLim and YLim properties can be observed,
            % and used to change them in the model to maintain
            % synchronization.
            % Can't do this using EventBroadcaster/EventSubscriber
            % mechanism b/c can't make the axes HG object an
            % EventBroadcaster.
            %addlistener(self.AxesGH_,'XLim','PostSet',@self.didSetXLimInAxesGH);
            %addlistener(self.AxesGH_,'YLim','PostSet',@self.didSetYLimInAxesGH);
            
%             % Add a line for each channel in the model
%             for i=1:self.Model.NChannels
%                 self.addChannelLineToAxes_();
%             end

%             % Load some icons
%             wavesurferDirName=fileparts(which('wavesurfer'));
%             
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data.png');
%             cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
% %            toolbarGH = findall(self.FigureGH, 'tag', 'FigureToolBar');
% %             self.SetYLimTightToDataButtonGH_ = ...
% %                 uipushtool(toolbarGH, ...
% %                            'CData', cdata, ...
% %                            'TooltipString', 'Set y-axis limits tight to data', ....
% %                            'ClickedCallback', @(source,event)self.controlActuated('SetYLimTightToDataButtonGH',source,event));
%             self.SetYLimTightToDataButtonGH_ = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','pushbutton', ...
%                           'Units','pixels', ...
%                           'FontSize',9, ...
%                           'TooltipString', 'Set y-axis limits tight to data', ....
%                           'CData', cdata, ...
%                           'Callback',@(source,event)(self.controlActuated('SetYLimTightToDataButtonGH',source,event)));
%                        
%             % Add a second toolbar button           
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data_locked.png');
%             cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
% %             self.SetYLimTightToDataLockedButtonGH_ = ...
% %                 uitoggletool(toolbarGH, ...
% %                              'CData', cdata, ...
% %                              'TooltipString', 'Set y-axis limits tight to data, and keep that way', ....
% %                              'ClickedCallback', @(source,event)self.controlActuated('SetYLimTightToDataLockedButtonGH',source,event));
%             self.SetYLimTightToDataLockedButtonGH_ = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','togglebutton', ...
%                           'Units','pixels', ...
%                           'FontSize',9, ...
%                           'TooltipString', 'Set y-axis limits tight to data, and keep that way', ....
%                           'CData', cdata, ...
%                           'Callback',@(source,event)(self.controlActuated('SetYLimTightToDataLockedButtonGH',source,event)));

            % Add the channels menu
            self.ChannelsMenu_ = ...
                uimenu('Parent',self.FigureGH, ...
                       'Label','Channels');

            % Add a menu, and a single menu item
            self.ViewMenu_ = ...
                uimenu('Parent',self.FigureGH, ...
                       'Label','View');
%             self.YScrollUpMenuItem_ = ...
%                 uimenu('Parent',self.ViewMenu_, ...
%                        'Label','Scroll Up Y-Axis', ...
%                        'Callback',@(source,event)self.controlActuated('YScrollUpMenuItemGH',source,event));            
%             self.YScrollDownMenuItem_ = ...
%                 uimenu('Parent',self.ViewMenu_, ...
%                        'Label','Scroll Down Y-Axis', ...
%                        'Callback',@(source,event)self.controlActuated('YScrollDownMenuItemGH',source,event));                               
% 
%             self.SetYLimTightToDataMenuItem_ = ...
%                 uimenu('Parent',self.ViewMenu_, ...
%                        'Label','Y Limits Tight to Data', ...
%                        'Callback',@(source,event)self.controlActuated('SetYLimTightToDataMenuItemGH',source,event));            
%             self.SetYLimTightToDataLockedMenuItem_ = ...
%                 uimenu('Parent',self.ViewMenu_, ...
%                        'Label','Lock Y Limits Tight to Data', ...
%                        'Callback',@(source,event)self.controlActuated('SetYLimTightToDataLockedMenuItemGH',source,event));            
%                    
%             self.YZoomInMenuItem_ = ...
%                 uimenu('Parent',self.ViewMenu_, ...
%                        'Label','Zoom In Y-Axis', ...
%                        'Callback',@(source,event)self.controlActuated('YZoomInMenuItemGH',source,event));            
%             self.YZoomOutMenuItem_ = ...
%                 uimenu('Parent',self.ViewMenu_, ...
%                        'Label','Zoom Out Y-Axis', ...
%                        'Callback',@(source,event)self.controlActuated('YZoomOutMenuItemGH',source,event));            
%             self.YLimitsMenuItem_ = ...
%                 uimenu('Parent',self.ViewMenu_, ...
%                        'Label','Y Limits...', ...
%                        'Callback',@(source,event)self.controlActuated('YLimitsMenuItemGH',source,event));            
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
                                      
%             % Y axis control buttons
%             self.YZoomInButton_ = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','pushbutton', ...
%                           'String','+', ...
%                           'Callback',@(source,event)(self.controlActuated('YZoomInButtonGH',source,event)));
%             self.YZoomOutButton_ = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','pushbutton', ...
%                           'String','-', ...
%                           'Callback',@(source,event)(self.controlActuated('YZoomOutButtonGH',source,event)));
%             self.YScrollUpButton_ = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','pushbutton', ...
%                           'Callback',@(source,event)(self.controlActuated('YScrollUpButtonGH',source,event)));
%             self.YScrollDownButton_ = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','pushbutton', ...
%                           'Callback',@(source,event)(self.controlActuated('YScrollDownButtonGH',source,event)));
%             self.SetYLimTightToDataButton_ = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','pushbutton', ...
%                           'TooltipString', 'Set y-axis limits tight to data', ....
%                           'Callback',@(source,event)(self.controlActuated('SetYLimTightToDataButtonGH',source,event)));
%             % This next button used to be a togglebutton, but Matlab doesn't let you change the foreground/background colors of togglebuttons, which
%             % we want to do with this button when we change to
%             % green-on-black mode.  Also, there's a checked menu item that
%             % shows when this toggle is engaged or diengaged, so hopefully
%             % it won't be too jarring to the user when this button doesn't
%             % look toggled after she presses it.  I think it should be OK
%             % --- sometimes it's hard to tell even when a togglebutton is
%             % toggled.
%             self.SetYLimTightToDataLockedButton_ = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','pushbutton', ...
%                           'TooltipString', 'Set y-axis limits tight to data, and keep that way', ....
%                           'Callback',@(source,event)(self.controlActuated('SetYLimTightToDataLockedButtonGH',source,event)));                      
                      
        end  % function            

        function updateControlsInExistance_(self)
            % Make it so we have the same number of scopes as analog channels,
            % adding/deleting them as needed
            nAnalogScopePlots = length(self.AnalogScopePlots_) ;
            nAnalogChannels = self.Model.Parent.Acquisition.NAnalogChannels ;
            if nAnalogChannels>nAnalogScopePlots ,
                for i = nAnalogScopePlots+1:nAnalogChannels ,
                    newScopePlot = ws.ScopePlot(self, true, i) ;
                    self.AnalogScopePlots_ = horzcat(self.AnalogScopePlots_, newScopePlot);
                end
            elseif nAnalogChannels<nAnalogScopePlots ,
                self.AnalogScopePlots_ = self.AnalogScopePlots_(1:nAnalogChannels) ;
            else
                % do nothing --- we already have the right number of
                % analog ScopePlots
            end

            % Make it so we have the same number of scopes as digital channels,
            % adding/deleting them as needed
            nDigitalScopePlots = length(self.DigitalScopePlots_) ;
            nDigitalChannels = self.Model.Parent.Acquisition.NDigitalChannels ;
            if nDigitalChannels>nDigitalScopePlots ,
                for i = nDigitalScopePlots+1:nDigitalChannels ,
                    newScopePlot = ws.ScopePlot(self, false, i) ;
                    self.DigitalScopePlots_ = horzcat(self.DigitalScopePlots_, newScopePlot);
                end
            elseif nDigitalChannels<nDigitalScopePlots ,
                self.DigitalScopePlots_ = self.DigitalScopePlots_(1:nDigitalChannels) ;
            else
                % do nothing --- we already have the right number of
                % digital ScopePlots
            end
            
            % Update the Channels menu
            self.updateChannelsMenu_() ;
        end  % function

        function updateChannelsMenu_(self)
            % Update the scope menu match the model state
            
            % Delete all the menu items in the Channels menu
            ws.deleteIfValidHGHandle(self.AnalogChannelMenuItems_);
            ws.deleteIfValidHGHandle(self.DigitalChannelMenuItems_);
            self.AnalogChannelMenuItems_ = [] ;
            self.DigitalChannelMenuItems_ = [] ;
                        
            % 
            % At this point, the Channels menu has been reduced to a blank
            % slate
            %
            
            % If no model, can't really do much, so return
            model=self.Model;
            if isempty(model) ,
                return
            end
            
            % Get the HG object representing the "Scopes" item in the
            % "Tools" menu.  Also the "Remove" item in the Scopes submenu.
            channelsMenu = self.ChannelsMenu_ ;
            
            % Set the Visibility of the Remove item in the Scope submenu
            %set(removeItem,'Visible',onIff(model.Display.NScopes>0));
            
            % Add a menu item for each AI channel
            aiChannelNames = self.Model.Parent.Acquisition.AnalogChannelNames ;
            for i = 1:length(aiChannelNames) ,
                menuItem = uimenu('Parent', channelsMenu, ...
                                  'Label', aiChannelNames{i}, ...
                                  'Tag', sprintf('AnalogChannelMenuItem %d',i), ...
                                  'Checked', ws.onIff(model.IsAnalogChannelDisplayed(i)), ...
                                  'Callback', @(source,event)(self.controlActuated('AnalogChannelMenuItems',source,event,i)));
                self.AnalogChannelMenuItems_ = horzcat(self.AnalogChannelMenuItems_, menuItem) ;
            end
            
            % Add a menu item for each DI channel
            diChannelNames = self.Model.Parent.Acquisition.DigitalChannelNames ;
            for i = 1:length(diChannelNames) ,
                menuItem = uimenu('Parent', channelsMenu, ...
                                  'Label', diChannelNames{i}, ...
                                  'Tag', sprintf('DigitalChannelMenuItem %d',i), ...
                                  'Checked', ws.onIff(model.IsDigitalChannelDisplayed(i)), ...
                                  'Callback', @(source,event)(self.controlActuated('DigitalChannelMenuItems',source,event,i)));
                if i==1 ,
                    set(menuItem, 'Separator', 'on') ;
                end
                self.DigitalChannelMenuItems_ = horzcat(self.DigitalChannelMenuItems_, menuItem) ;
            end
        end  % function
        
        function updateControlPropertiesImplementation_(self)
            % If there are issues with the model, just return
            model=self.Model;
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
%             % Update the togglebutton
%             areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToData ;           
%             set(self.SetYLimTightToDataLockedMenuItem_,'Checked',ws.onIff(areYLimitsLockedTightToData));            

            % Update the Show Grid togglemenu
            isGridOn = self.Model.IsGridOn ;
            set(self.ShowGridMenuItem_,'Checked',ws.onIff(isGridOn));

            % Update the Invert Colors togglemenu
            areColorsNormal = self.Model.AreColorsNormal ;
            set(self.InvertColorsMenuItem_,'Checked',ws.onIff(~areColorsNormal));

            % Update the Do Show Buttons togglemenu
            doShowButtons = self.Model.DoShowButtons ;
            set(self.DoShowButtonsMenuItem_,'Checked',ws.onIff(doShowButtons));

            % Compute the colors
            areColorsNormal = self.Model.AreColorsNormal ;
            defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            controlBackgroundColor  = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            controlForegroundColor = ws.fif(areColorsNormal,'k','w') ;
            figureBackground = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            set(self.FigureGH,'Color',figureBackground);
            axesBackgroundColor = ws.fif(areColorsNormal,'w','k') ;
            axesForegroundColor = ws.fif(areColorsNormal,'k','g') ;
            traceLineColor = ws.fif(areColorsNormal,'b','w') ;

            % Compute the icons
            if areColorsNormal ,
                yScrollUpIcon   = self.NormalYScrollUpIcon_   ;
                yScrollDownIcon = self.NormalYScrollDownIcon_ ;
                yTightToDataIcon = self.NormalYTightToDataIcon_ ;
                yTightToDataLockedIcon = self.NormalYTightToDataLockedIcon_ ;
                yCaretIcon = self.NormalYCaretIcon_ ;
            else
                yScrollUpIcon   = 1-self.NormalYScrollUpIcon_   ;  % RGB images, so this inverts them, leaving nan's alone
                yScrollDownIcon = 1-self.NormalYScrollDownIcon_ ;                
                yTightToDataIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataIcon_) ;  
                yTightToDataLockedIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataLockedIcon_) ;
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
            for i=1:length(self.AnalogScopePlots_) ,
                thisPlot = self.AnalogScopePlots_(i) ;
                thisPlot.setColorsAndIcons(controlForegroundColor, controlBackgroundColor, ...
                                           axesForegroundColor, axesBackgroundColor, ...
                                           traceLineColor, ...
                                           yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon, yCaretIcon) ;
                thisPlot.IsGridOn = isGridOn ;                       
                thisPlot.setXAxisLimits(xl) ;
                thisPlot.setYAxisLimits(yLimitsPerAnalogChannel(:,i)') ;
                thisPlot.setYAxisLabel(aiChannelNames{i}, true, aiChannelUnits{i}, axesForegroundColor) ;
            end
            for i=1:length(self.DigitalScopePlots_) ,
                thisPlot = self.DigitalScopePlots_(i) ;
                thisPlot.setColorsAndIcons(controlForegroundColor, controlBackgroundColor, ...
                                           axesForegroundColor, axesBackgroundColor, ...
                                           traceLineColor, ...
                                           yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon, yCaretIcon) ;
                thisPlot.IsGridOn = isGridOn ;                       
                thisPlot.setXAxisLimits(xl) ;
                thisPlot.setYAxisLimits([-0.05 1.05]) ;
                thisPlot.setYAxisLabel(diChannelNames{i}, false, [], axesForegroundColor) ;
            end

            % Do this separately, although we could do it at same time if
            % speed is an issue...
            self.updateLineXDataAndYData_();
        end  % function
        
        function updateControlEnablementImplementation_(self)
%             % Set the menu enablement
%             wavesurferModel = self.Model.Parent ;
%             isIdle=isequal(wavesurferModel.State,'idle');
%             set(self.InvertColorsMenuItem_,  'Enable',onIff(isIdle));            
%             set(self.ShowGridMenuItem_,      'Enable',onIff(isIdle));            
%             set(self.DoShowButtonsMenuItem_, 'Enable',onIff(isIdle));            
            
            % Update the enablement of buttons in the panels
            isAnalogChannelDisplayed = self.Model.IsAnalogChannelDisplayed ;
            isDigitalChannelDisplayed = self.Model.IsDigitalChannelDisplayed ;            
            areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToDataForAnalogChannel ;
            for i=1:length(self.AnalogScopePlots_) ,
                self.AnalogScopePlots_(i).IsVisible = isAnalogChannelDisplayed(i) ;
                self.AnalogScopePlots_(i).setControlEnablement(areYLimitsLockedTightToData(i)) ;
            end
            for i=1:length(self.DigitalScopePlots_) ,
                self.DigitalScopePlots_(i).IsVisible = isDigitalChannelDisplayed(i) ;
                self.DigitalScopePlots_(i).setControlEnablement(true) ;  % digital channels are always locked tight to data
            end
        end  % function
        
        function layout_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely given the current model state.
            
            %figureSize=self.layoutFixedControls_();
            figurePosition = get(self.FigureGH, 'Position') ;
            figureSize = figurePosition(3:4) ;
            
            doesUserWantToSeeButtons = self.Model.DoShowButtons ;
            isAnalogChannelDisplayed = self.Model.IsAnalogChannelDisplayed ;
            isDigitalChannelDisplayed = self.Model.IsDigitalChannelDisplayed ;
            nScopesVisible = sum(isAnalogChannelDisplayed) + sum(isDigitalChannelDisplayed) ;
            indexOfThisScopeAmongVisibleScopes = 0 ;
            for i=1:length(self.AnalogScopePlots_)
                if isAnalogChannelDisplayed(i) ,
                    indexOfThisScopeAmongVisibleScopes = indexOfThisScopeAmongVisibleScopes + 1 ;
                    self.AnalogScopePlots_(i).setPositionAndLayout(figureSize, nScopesVisible, indexOfThisScopeAmongVisibleScopes, doesUserWantToSeeButtons) ;
                end
            end
            for i=1:length(self.DigitalScopePlots_)
                if isDigitalChannelDisplayed(i) ,
                    indexOfThisScopeAmongVisibleScopes = indexOfThisScopeAmongVisibleScopes + 1 ;
                    self.DigitalScopePlots_(i).setPositionAndLayout(figureSize, nScopesVisible, indexOfThisScopeAmongVisibleScopes, doesUserWantToSeeButtons) ;
                end
            end
        end
    end  % protected methods block
    
    methods (Access = protected)
%         function addChannelLineToAxes_(self)
%             % Creates a new channel line, adding it to the end of self.LineGHs_.
%             iChannel=length(self.LineGHs_)+1;
%             newChannelName=self.Model.ChannelNames{iChannel};
%             
%             colorOrder = get(self.Axes_ ,'ColorOrder');
%             color = colorOrder(self.Model.ChannelColorIndex(iChannel), :);
%             
%             self.LineGHs_(iChannel) = ...
%                 line('Parent', self.Axes_,...
%                      'XData', [],...
%                      'YData', [],...
%                      'ZData', [],...
%                      'Color', color,...
%                      'Tag', sprintf('%s::%s', self.Model.Tag, newChannelName));
% %                                      'LineWidth', 2,...
% %                      'Marker', self.Model.Marker,...
% %                      'LineStyle', self.Model.LineStyle,...
%         end  % function
        
%         function modelAxisLimitWasSet(self)
%             self.updateReferenceLines();
%         end
        
        function modelGenericVisualPropertyWasSet_(self)
            self.update();
        end  % function 
        
        function updateLineXDataAndYData_(self)
            xData = self.Model.XData ;
            yData = self.Model.YData ;            
            acq = self.Model.Parent.Acquisition ;
            isAIChannelActive = acq.IsAnalogChannelActive ;
            activeChannelIndex = 0 ;
            for aiChannelIndex = 1:length(self.AnalogScopePlots_) ,
                if isAIChannelActive(aiChannelIndex) ,
                    activeChannelIndex = activeChannelIndex + 1 ;
                    yDataForThisChannel = yData(:,activeChannelIndex) ;
                    self.AnalogScopePlots_(aiChannelIndex).setLineXDataAndYData(xData, yDataForThisChannel) ;
                else
                    self.AnalogScopePlots_(aiChannelIndex).setLineXDataAndYData([],[]) ;
                end
            end
            isDIChannelActive = acq.IsDigitalChannelActive ;
            for diChannelIndex = 1:length(self.DigitalScopePlots_) ,
                if isDIChannelActive(diChannelIndex) ,
                    activeChannelIndex = activeChannelIndex + 1 ;
                    yDataForThisChannel = yData(:,activeChannelIndex) ;
                    self.DigitalScopePlots_(diChannelIndex).setLineXDataAndYData(xData, yDataForThisChannel) ;
                else
                    self.DigitalScopePlots_(diChannelIndex).setLineXDataAndYData([],[]) ;
                end
            end
        end  % function

        function updateAxisLabels_(self,axisForegroundColor)
            for i = 1:length(self.ScopePlots_) ,
                self.ScopePlots_(i).updateAxisLabels_(axisForegroundColor) ;
            end            
%             if self.Model.NChannels==0 ,
%                 ylabel(self.Axes_,'Signal','Color',axisForegroundColor,'FontSize',10,'Interpreter','none');
%             else
%                 firstChannelName=self.Model.ChannelNames{1};
%                 %iFirstChannel=self.Model.WavesurferModel.Acquisition.iChannelFromName(firstChannelName);
%                 %units=self.Model.WavesurferModel.Acquisition.ChannelUnits(iFirstChannel);
%                 units=self.Model.YUnits;
%                 if isempty(units) ,
%                     unitsString = 'pure' ;
%                 else
%                     unitsString = units ;
%                 end
%                 ylabel(self.Axes_,sprintf('%s (%s)',firstChannelName,unitsString),'Color',axisForegroundColor,'FontSize',10,'Interpreter','none');
%             end
        end  % function
        
        function updateYAxisLabel_(self,color)
            % Updates the y axis label handle graphics to match the model state
            % and that of the Acquisition subsystem.
            %set(self.Axes_,'YLim',self.YOffset+[0 self.YRange]);
            if self.Model.NChannels==0 ,
                ylabel(self.Axes_,'Signal','Color',color,'FontSize',10,'Interpreter','none');
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
                ylabel(self.Axes_,sprintf('%s (%s)',firstChannelName,unitsString),'Color',color,'FontSize',10,'Interpreter','none');
            end
        end  % function
        
        function updateXAxisLimits_(self)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            xl = self.Model.XOffset + [0 self.Model.XSpan] ;
            for i = 1:length(self.AnalogScopePlots_) ,
                self.AnalogScopePlots_(i).setXAxisLimits(xl) ;
            end
            for i = 1:length(self.DigitalScopePlots_) ,
                self.DigitalScopePlots_(i).setXAxisLimits(xl) ;
            end
        end  % function        

        function updateYAxisLimits_(self, aiChannelIndex)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            yLimitsPerAnalogChannel = self.Model.YLimitsPerAnalogChannel ;
            yl = yLimitsPerAnalogChannel(:,aiChannelIndex)' ;
            self.AnalogScopePlots_(aiChannelIndex).setYAxisLimits(yl) ;
        end  % function        

%         function updateAreYLimitsLockedTightToData_(self)
%             % Update the axes limits to match those in the model
%             if isempty(self.Model) || ~isvalid(self.Model) ,
%                 return
%             end
%             areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToData ;
%             set(self.SetYLimTightToDataLockedButton_,'State',ws.onIff(areYLimitsLockedTightToData));            
%         end  % function        
        
        
%         function updateAxisLimits(self)
%             % Update the axes limits to match those in the model
%             if isempty(self.Model) || ~isvalid(self.Model) ,
%                 return
%             end
%             xl=self.Model.XLim;
%             yl=self.Model.YLim;
%             setifhg(self.Axes_, 'XLim', xl, 'YLim', yl);
%         end

%         function updateScaling(self)
% %             % Update the axes x-limits to accomodate the lines in it.
% %             xMax=self.Model.MaxXData;            
% %             xLim = [max([0, xMax - self.Model.XRange]), max(xMax, self.Model.XRange)];
% %             setifhg(self.Axes_, 'XLim', xLim);
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
    
    methods
        function castOffAllAttachments(self)
            self.unsubscribeFromAll() ;
            self.deleteFigureGH() ;
        end
    end

    methods (Static=true)
%         function result=getWidthInPixels(ax)
%             % Gets the x span of the given axes, in pixels.
%             savedUnits=get(ax,'Units');
%             set(ax,'Units','pixels');
%             pos=get(ax,'Position');
%             result=pos(3);
%             set(ax,'Units',savedUnits);            
%         end  % function
        
%         function r=ratioSubsampling(t,T_view,n_pels_view)
%             % Computes r, a good ratio to use for subsampling data on time base t
%             % for plotting in Spoke_main_plot plot, given that the x axis of
%             % Spoke_main_plot spans T_view seconds.  Returns the empty matrix if no
%             % subsampling is called for.
%             n_t=length(t);
%             if n_t==0
%                 r=[];
%             else
%                 dt=(t(end)-t(1))/(n_t-1);
%                 n_t_view=T_view/dt;
%                 samples_per_pel=n_t_view/n_pels_view;
%                 %if samples_per_pel>10  % original value
%                 if samples_per_pel>2
%                     %if samples_per_pel>1.2
%                     % figure out how much we're going to subsample
%                     samples_per_pel_want=2;  % original value
%                     %samples_per_pel_want=1;
%                     n_t_view_want=n_pels_view*samples_per_pel_want;
%                     r=floor(n_t_view/n_t_view_want);
%                 else
%                     r=[];  % no need for resampling
%                 end
%             end
%         end  % function
        
    end  % static methods block
    
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
    
end
