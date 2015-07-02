classdef ScopeFigure < ws.MCOSFigure & ws.EventSubscriber & ws.EventBroadcaster
    % This is an EventBroadcaster only so that changes to it via the
    % default Matlab figure controls can be communicated to the model (via
    % the controller)
    
    properties (Dependent=true)
        % Typically, MCOSFigures don't have public properties like this.  These exist for ScopeFigure
        % to enable us to keep the ScopeModel state in sync with the HG figure XLim and YLim if the 
        % user changes them using the default Matlab HG figure tools.  Basically, the ScopeFigure defines 
        % events DidSetXLim and DidSetYLim, which it fires if the HG figure XLim or YLim are changes.  The
        % ScopeController subscribes to these events, and when they occur it sets the corresponding properties in the
        % model.  Care has to be taken to avoid infinite loops, as you might imagine.
        XLim
        YLim
    end

    properties (Access = protected)
        AxesGH_  % HG handle to axes
        LineGHs_ = zeros(1,0)  % row vector, the line graphics handles for each channel
        %HeldLineGHs;        
%         HorizontalCenterLineGH;  % HG handle to line
%         VerticalCenterLineGH;  % HG handle to line
%         GroundLineGH;  % HG handle to line
        YForPlotting_  
            % nScans x nChannels
            % Y data downsampled to approximately two points per pixel,
            % with the first point the min for that pixel, second point the
            % max for that pixel.
        XForPlotting_  
            % nScans x 1
            % X data for the points in YForPlotting_.  As such, this consist
            % of a sequence of pairs, with each member of a pair being
            % equal.
        XLim_
        YLim_
        SetYLimTightToDataButtonGH_
        SetYLimTightToDataLockedButtonGH_
        
        ScopeMenuGH_
        YZoomInMenuItemGH_
        YZoomOutMenuItemGH_
        YScrollUpMenuItemGH_
        YScrollDownMenuItemGH_
        YLimitsMenuItemGH_
        InvertColorsMenuItemGH_
        ShowGridMenuItemGH_
        DoShowButtonsMenuItemGH_
        
        YZoomInButtonGH_
        YZoomOutButtonGH_
        YScrollUpButtonGH_
        YScrollDownButtonGH_
    end
    
%     properties (Dependent=true, SetAccess=immutable, Hidden=true)  % hidden so not show in disp() output
%         IsVisibleWhenDisplayEnabled
%     end
    
    events
        DidSetXLim
        DidSetYLim
    end

    methods
        function self=ScopeFigure(model,controller)
            % Call the superclass constructor
            self = self@ws.MCOSFigure(model,controller);
            
            % Set properties of the figure
            set(self.FigureGH, ...
                'Tag',model.Tag,...
                'Name', model.Title, ...
                'Color',get(0,'defaultUIControlBackgroundColor'), ...
                'NumberTitle', 'off',...
                'Units', 'pixels',...
                'HandleVisibility', 'on',...
                'Toolbar','figure', ...
                'CloseRequestFcn', @(source,event)(self.closeRequested(source,event)), ...
                'ResizeFcn',@(sourse,event)(self.layout_()));
%                'Renderer','OpenGL', ...            
%                'Color', model.BackgroundColor,...
            
            % Create the widgets that will persist through the life of the
            % figure
            self.createFixedControls_();
            
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
            
            % Do stuff to make ws.most.Controller happy
            self.setHGTagsToPropertyNames_();
            self.updateGuidata_();
            
            % sync up self to model
            self.update();            
        end  % constructor
        
        function delete(self)
            % Do I even need to do this stuff?  Those GHs will become
            % invalid when the figure HG object is deleted...
            ws.utility.deleteIfValidHGHandle(self.LineGHs_);
            ws.utility.deleteIfValidHGHandle(self.AxesGH_);            
        end  % function
        
        function set(self,propName,value)
            % Override MCOSFigure set to catch XLim, YLim
            if strcmpi(propName,'XLim') ,
                self.XLim=value;
            elseif strcmpi(propName,'YLim') ,
                self.YLim=value;
            else
                set@ws.MCOSFigure(self,propName,value);
            end
        end  % function
    end  % public methods block
    
    methods (Access=protected)        
        function willSetModel_(self)            
            % clear the downsampled data
            self.XForPlotting_=zeros(0,1);
            self.YForPlotting_=zeros(0,0);

            % Call the superclass method
            willSetModel_@ws.MCOSFigure(self);

            % Get the Model
            model = self.Model ;            

            % If model is nonempty, do some unsubscribing
            if ~isempty(model) ,
                % Unsubscribe from events in the model
                %model.unsubscribeMeFromAll(self) ;

                % Unsubsribe from events in the master model
                display=model.Parent;
                if ~isempty(display) ,
                    wavesurferModel=display.Parent;
                    if ~isempty(wavesurferModel) ,
                        wavesurferModel.unsubscribeMeFromAll(self);
                    end
                end
            end
        end  % function
        
        function didSetModel_(self)
            model = self.Model ;

            % reset the downsampled data
            if ~isempty(model) ,
                nChannels=length(model.ChannelNames);
                self.XForPlotting_=zeros(0,1);
                self.YForPlotting_=zeros(0,nChannels);
            end

            % Call the superclass method
            didSetModel_@ws.MCOSFigure(self);

            % Subscribe to some model events
            if ~isempty(model) ,
                model.subscribeMe(self,'Update','','update');
                model.subscribeMe(self,'UpdateYAxisLimits','','updateYAxisLimits');
                model.subscribeMe(self,'UpdateAreYLimitsLockedTightToData','','updateAreYLimitsLockedTightToData');
                model.subscribeMe(self,'ChannelAdded','','modelChannelAdded');
                model.subscribeMe(self,'DataAdded','','modelDataAdded');
                model.subscribeMe(self,'DataCleared','','modelDataCleared');
                model.subscribeMe(self,'DidSetChannelUnits','','modelChannelUnitsSet');
            end

            % Subscribe to events in the master model
            if ~isempty(model) ,
                display=model.Parent;
                if ~isempty(display) ,
                    wavesurferModel=display.Parent;
                    if ~isempty(wavesurferModel) ,
                        wavesurferModel.subscribeMe(self,'DidSetState','','update');
                    end
                end
            end
        end  % function
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
        
        function set.XLim(self,newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
                self.XLim_=newValue;
                set(self.AxesGH_,'XLim',newValue);
            end
            self.broadcast('DidSetXLim');
        end  % function
        
        function value=get.XLim(self)
            value=self.XLim_;
        end  % function
        
        function set.YLim(self,newValue)
            %fprintf('ScopeFigure::set.YLim()\n');
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
                self.YLim_=newValue;
                set(self.AxesGH_,'YLim',newValue);
            end
            self.broadcast('DidSetYLim');
        end  % function
            
        function value=get.YLim(self)
            value=self.YLim_;
        end  % function
                
        function didSetXLimInAxesGH(self,varargin)
            self.XLim=get(self.AxesGH_,'XLim');
        end  % function
        
        function didSetYLimInAxesGH(self,varargin)
            %fprintf('ScopeFigure::didSetYLimInAxesGH()\n');
            %ylOld=self.YLim
            ylNew=get(self.AxesGH_,'YLim');
            self.YLim=ylNew;
        end  % function
        
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
        
        function modelXAxisLimitSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateXAxisLimits_();
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
            % Redimension downsampled data, clearing the existing data in
            % the process
            nChannels=self.Model.NChannels;
            self.XForPlotting_=zeros(0,1);
            self.YForPlotting_=zeros(0,nChannels);
            
            % Do other stuff
            self.addChannelLineToAxes_();
            self.update();
        end  % function
        
        function modelDataAdded(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            % Need to pack up all the y data into a single array for
            % downsampling (should change things more globally to make this
            % unnecessary)
            nScans=length(self.Model.XData);
            nChannels=length(self.Model.YData);
            y=zeros(nScans,nChannels);
            for i=1:nChannels ,
                y(:,i)=self.Model.YData{i};
            end
            x=self.Model.XData;
            
            % This shouldn't ever happen, but just in case...
            if isempty(x) ,
                return
            end
            
            % Figure out the downsampling ratio
            xSpanInPixels=ws.ScopeFigure.getWidthInPixels(self.AxesGH_);
            r=ws.ScopeFigure.ratioSubsampling(x,self.Model.XSpan,xSpanInPixels);
            
            % get the current downsampled data
            xForPlottingOriginal=self.XForPlotting_;
            yForPlottingOriginal=self.YForPlotting_;
            
            % Trim off any that is beyond the left edge of the data
            x0=x(1);
            keep=(x0<=xForPlottingOriginal);
            xForPlottingOriginalTrimmed=xForPlottingOriginal(keep);
            yForPlottingOriginalTrimmed=yForPlottingOriginal(keep,:);
            
            % Get just the new data
            if isempty(xForPlottingOriginal)
                xNew=x;
                yNew=y;
            else                
                isNew=(xForPlottingOriginal(end)<x);
                xNew=x(isNew);
                yNew=y(isNew);
            end
            
            % Downsample the new data
            [xForPlottingNew,yForPlottingNew]=ws.ScopeFigure.minMaxDownsample(xNew,yNew,r);            
            
            % Concatenate old and new downsampled data, commit to self
            self.XForPlotting_=[xForPlottingOriginalTrimmed; ...
                               xForPlottingNew];
            self.YForPlotting_=[yForPlottingOriginalTrimmed; ...
                               yForPlottingNew];

            % Update the lines
            self.updateLineXDataAndYData_();
        end  % function
        
        function modelDataCleared(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            %fprintf('ScopeFigure::modelDataCleared()\n');
            nChannels=self.Model.NChannels;
            self.XForPlotting_=zeros(0,1);
            self.YForPlotting_=zeros(0,nChannels);                        
            self.updateLineXDataAndYData_();                      
        end  % function
        
        function modelChannelUnitsSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.update();
        end  % function

        function syncTitleAndTagsToModel(self)
            import ws.utility.onIff
            
            model=self.Model;
            set(self.FigureGH, ...
                'Tag',model.Tag,...
                'Name', model.Title);
%             , ...
%                 'Color', model.BackgroundColor);
%             set(self.AxesGH_, ...
%                 'FontSize', model.FontSize, ...
%                 'FontWeight', model.FontWeight, ...
%                 'Color', model.BackgroundColor, ...
%                 'XColor', model.ForegroundColor, ...
%                 'YColor', model.ForegroundColor, ...
%                 'ZColor', model.ForegroundColor, ...
%                 'XGrid', onIff(model.GridOn), ...
%                 'YGrid', onIff(model.GridOn) ...
%                 );
%             set(self.AxesGH_, ...
%                 'XGrid', onIff(model.IsGridOn), ...
%                 'YGrid', onIff(model.IsGridOn) ...
%                 );
        end  % function
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
%             %import ws.utility.onIff
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
%             cdata = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;
%             self.SetYLimTightToDataIcon_ = cdata ;
%                                      
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data_locked.png');
%             cdata = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;
%             self.SetYLimTightToDataLockedIcon_ = cdata ;
% 
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'up_arrow.png');
%             cdata = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;                      
%             self.YScrollUpIcon_ = cdata ;
%             
%             iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'down_arrow.png');
%             cdata = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;                      
%             self.YScrollDownIcon_ = cdata ;
%         end

        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            %model = self.Model ;
            self.AxesGH_ = ...
                axes('Parent', self.FigureGH, ...
                     'Units','pixels', ...
                     'Box','on' );
%                      'XGrid', ws.utility.onIff(model.IsGridOn), ...
%                      'YGrid', ws.utility.onIff(model.IsGridOn) );
            %         'Position', [0.11 0.11 0.87 0.83], ...
%                      'XColor', model.ForegroundColor, ...
%                      'YColor', model.ForegroundColor, ...
%                      'ZColor', model.ForegroundColor, ...
%                      'FontSize', model.FontSize, ...
%                      'FontWeight', model.FontWeight, ...
%                     'Color', model.BackgroundColor, ...
            
            colorOrder = get(self.AxesGH_, 'ColorOrder');
            %colorOrder = [1 1 1; 1 0.25 0.25; colorOrder];
            colorOrder = [0 0 0; colorOrder];
            set(self.AxesGH_, 'ColorOrder', colorOrder);

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
            addlistener(self.AxesGH_,'XLim','PostSet',@self.didSetXLimInAxesGH);
            addlistener(self.AxesGH_,'YLim','PostSet',@self.didSetYLimInAxesGH);
            
%             % Add a line for each channel in the model
%             for i=1:self.Model.NChannels
%                 self.addChannelLineToAxes_();
%             end

            % Load some icons
            wavesurferDirName=fileparts(which('wavesurfer'));
            
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data.png');
            setYLimTightToDataIcon = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;
                                     
            iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data_locked.png');
            setYLimTightToDataLockedIcon = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;

            % Add a toolbar button
            toolbarGH = findall(self.FigureGH, 'tag', 'FigureToolBar');
            self.SetYLimTightToDataButtonGH_ = ...
                uipushtool(toolbarGH, ...
                           'CData', setYLimTightToDataIcon , ...
                           'TooltipString', 'Set y-axis limits tight to data', ....
                           'ClickedCallback', @(source,event)self.controlActuated('SetYLimTightToDataButtonGH',source,event));
                         
            % Add a second toolbar button           
            self.SetYLimTightToDataLockedButtonGH_ = ...
                uitoggletool(toolbarGH, ...
                             'CData', setYLimTightToDataLockedIcon , ...
                             'TooltipString', 'Set y-axis limits tight to data, and keep that way', ....
                             'ClickedCallback', @(source,event)self.controlActuated('SetYLimTightToDataLockedButtonGH',source,event));
                       
            % Add a menu, and a single menu item
            self.ScopeMenuGH_ = ...
                uimenu('Parent',self.FigureGH, ...
                       'Label','Scope');
            self.YScrollUpMenuItemGH_ = ...
                uimenu('Parent',self.ScopeMenuGH_, ...
                       'Label','Scroll Up Y-Axis', ...
                       'Callback',@(source,event)self.controlActuated('YScrollUpMenuItemGH',source,event));            
            self.YScrollDownMenuItemGH_ = ...
                uimenu('Parent',self.ScopeMenuGH_, ...
                       'Label','Scroll Down Y-Axis', ...
                       'Callback',@(source,event)self.controlActuated('YScrollDownMenuItemGH',source,event));                               
            self.YZoomInMenuItemGH_ = ...
                uimenu('Parent',self.ScopeMenuGH_, ...
                       'Label','Zoom In Y-Axis', ...
                       'Callback',@(source,event)self.controlActuated('YZoomInMenuItemGH',source,event));            
            self.YZoomOutMenuItemGH_ = ...
                uimenu('Parent',self.ScopeMenuGH_, ...
                       'Label','Zoom Out Y-Axis', ...
                       'Callback',@(source,event)self.controlActuated('YZoomOutMenuItemGH',source,event));            
            self.YLimitsMenuItemGH_ = ...
                uimenu('Parent',self.ScopeMenuGH_, ...
                       'Label','Y Limits...', ...
                       'Callback',@(source,event)self.controlActuated('YLimitsMenuItemGH',source,event));            
            self.InvertColorsMenuItemGH_ = ...
                uimenu('Parent',self.ScopeMenuGH_, ...
                       'Separator','on', ...
                       'Label','Green On Black', ...
                       'Callback',@(source,event)self.controlActuated('InvertColorsMenuItemGH',source,event));            
            self.ShowGridMenuItemGH_ = ...
                uimenu('Parent',self.ScopeMenuGH_, ...
                       'Label','Show Grid', ...
                       'Callback',@(source,event)self.controlActuated('ShowGridMenuItemGH',source,event));            
            self.DoShowButtonsMenuItemGH_ = ...
                uimenu('Parent',self.ScopeMenuGH_, ...
                       'Label','Show Buttons', ...
                       'Callback',@(source,event)self.controlActuated('DoShowButtonsMenuItemGH',source,event));            
                                      
            % Y axis control buttons
            self.YZoomInButtonGH_ = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'String','+', ...
                          'Callback',@(source,event)(self.controlActuated('YZoomInButtonGH',source,event)));
            self.YZoomOutButtonGH_ = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'String','-', ...
                          'Callback',@(source,event)(self.controlActuated('YZoomOutButtonGH',source,event)));
            self.YScrollUpButtonGH_ = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'Callback',@(source,event)(self.controlActuated('YScrollUpButtonGH',source,event)));
            self.YScrollDownButtonGH_ = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontSize',9, ...
                          'Callback',@(source,event)(self.controlActuated('YScrollDownButtonGH',source,event)));
        end  % function            

        function updateControlsInExistance_(self)            
            % Make it so we have the same number of lines as channels,
            % adding/deleting them as needed
            nChannels = self.Model.NChannels ;            
            currentLineGHs = self.LineGHs_ ;            
            nLines= length(currentLineGHs);
            if nLines>nChannels ,
                delete(self.LineGHs_(nChannels+1:nLines));
                self.LineGHs_(nChannels+1:nLines)=[];
            elseif nLines<nChannels
                for i=nLines+1:nChannels ,
                    self.addChannelLineToAxes_();
                end                
            end
        end  % function
        
        function updateControlPropertiesImplementation_(self)
            % If there are issues with the model, just return
            model=self.Model;
            if isempty(model) || ~isvalid(model) ,
                return
            end

            persistent persistentYScrollUpIcon
            if isempty(persistentYScrollUpIcon) ,
                wavesurferDirName=fileparts(which('wavesurfer'));
                iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'up_arrow.png');
                persistentYScrollUpIcon = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            end

            persistent persistentYScrollDownIcon
            if isempty(persistentYScrollDownIcon) ,
                wavesurferDirName=fileparts(which('wavesurfer'));
                iconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'up_arrow.png');
                persistentYScrollDownIcon = ws.utility.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            end
            
            % Update the togglebutton
            areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToData ;
            set(self.SetYLimTightToDataLockedButtonGH_,'State',ws.utility.onIff(areYLimitsLockedTightToData));            

            % Update the Show Grid togglemenu
            isGridOn = self.Model.IsGridOn ;
            set(self.ShowGridMenuItemGH_,'Checked',ws.utility.onIff(isGridOn));

            % Update the Invert Colors togglemenu
            areColorsNormal = self.Model.AreColorsNormal ;
            set(self.InvertColorsMenuItemGH_,'Checked',ws.utility.onIff(~areColorsNormal));

            % Update the Do Show Buttons togglemenu
            doShowButtons = self.Model.DoShowButtons ;
            set(self.DoShowButtonsMenuItemGH_,'Checked',ws.utility.onIff(doShowButtons));

            % Update the colors
            areColorsNormal = self.Model.AreColorsNormal ;
            defaultUIControlBackgroundColor = get(0,'defaultUIControlBackgroundColor') ;
            controlBackground  = ws.utility.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            controlForeground = ws.utility.fif(areColorsNormal,'k','w') ;
            figureBackground = ws.utility.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            set(self.FigureGH,'Color',figureBackground);
            axesBackground = ws.utility.fif(areColorsNormal,'w','k') ;
            set(self.AxesGH_,'Color',axesBackground);
            axesForeground = ws.utility.fif(areColorsNormal,'k','g') ;
            set(self.AxesGH_,'XColor',axesForeground);
            set(self.AxesGH_,'YColor',axesForeground);
            set(self.AxesGH_,'ZColor',axesForeground);
            if areColorsNormal ,
                colorOrder = ...
                    [      0                         0                         0  ; ...
                           0                         0                         1  ; ...
                           0                       0.5                         0  ; ...
                           1                         0                         0  ; ...
                           0                      0.75                      0.75  ; ...
                        0.75                         0                      0.75  ; ...
                        0.75                      0.75                         0  ; ...
                        0.25                      0.25                      0.25  ] ;
            else
                colorOrder = ...
                    [      1                         1                         1  ; ...
                           0                       0.5                         1  ; ...
                           0                         1                         0  ; ...
                           1                         0                         1  ; ...
                           0                         1                         1  ; ...
                        0.75                         0                      0.75  ; ...
                           1                         1                         0  ; ...
                        0.75                      0.75                      0.75  ] ;
                
            end
            set(self.AxesGH_,'ColorOrder',colorOrder);

            % Set the line colors
            for iChannel = 1:length(self.LineGHs_)
                lineGH = self.LineGHs_(iChannel) ;
                color = colorOrder(self.Model.ChannelColorIndex(iChannel), :);
                set(lineGH,'Color',color);
            end

            % Set the button colors
            set(self.YZoomInButtonGH_,'ForegroundColor',controlForeground,'BackgroundColor',controlBackground);
            set(self.YZoomOutButtonGH_,'ForegroundColor',controlForeground,'BackgroundColor',controlBackground);
            set(self.YScrollUpButtonGH_,'ForegroundColor',controlForeground,'BackgroundColor',controlBackground);
            set(self.YScrollDownButtonGH_,'ForegroundColor',controlForeground,'BackgroundColor',controlBackground);            
            
            % Set the button scroll up/down button images
            if areColorsNormal ,
                yScrollUpIcon   = persistentYScrollUpIcon   ;
                yScrollDownIcon = persistentYScrollDownIcon ;
            else
                yScrollUpIcon   = 1-persistentYScrollUpIcon   ;  % RGB images, so this inverts them, leaving nan's alone
                yScrollDownIcon = 1-persistentYScrollDownIcon ;                
            end                
            set(self.YScrollUpButtonGH_,'CData',yScrollUpIcon);
            set(self.YScrollDownButtonGH_,'CData',yScrollDownIcon);
            
            % Update the axes grid on/off
            set(self.AxesGH_, ...
                'XGrid', ws.utility.onIff(isGridOn), ...
                'YGrid', ws.utility.onIff(isGridOn) ...
                );
            
            % Update the axis limits
            self.updateXAxisLimits_();
            self.updateYAxisLimits_();
            
            % Update the graphics objects to match the model
            xlabel(self.AxesGH_,'Time (s)','Color',axesForeground,'FontSize',10);
            self.updateYAxisLabel_(axesForeground);
            self.updateLineXDataAndYData_();
        end  % function
        
        function updateControlEnablementImplementation_(self)
            % Update the enablement of controls
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToData ;
            
            %import ws.utility.onIff
            onIffNotAreYLimitsLockedTightToData = ws.utility.onIff(~areYLimitsLockedTightToData) ;
            set(self.YLimitsMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);            
            set(self.SetYLimTightToDataButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YZoomInButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YZoomOutButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YScrollUpButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YScrollDownButtonGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YZoomInMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YZoomOutMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YScrollUpMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
            set(self.YScrollDownMenuItemGH_,'Enable',onIffNotAreYLimitsLockedTightToData);
        end  % function
        
        function layout_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely given the current model state.  

            % We can use a simplified version of this, since all the
            % controls are fixed (i.e. they exist for the lifetime of the
            % figure)
            self.layoutFixedControls_() ;
            
            % This implementation should work in most cases, but can be overridden by
            % subclasses if needed.
            %figureSize=self.layoutFixedControls_();
            %figureSizeModified=self.layoutNonfixedControls_(figureSize);
            %ws.utility.resizeLeavingUpperLeftFixedBang(self.FigureGH,figureSizeModified);            
        end  % function
        
        function layoutFixedControls_(self)
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
            figurePosition = get(self.FigureGH, 'Position') ;
            figureSize = figurePosition(3:4);
            figureWidth = figureSize(1) ;
            figureHeight = figureSize(2) ;
            
            % Calculate the first-pass dimensions
            leftMargin = max(minLeftMargin,min(0.13*figureWidth,maxLeftMargin)) ;
            rightMargin = max(minRightMargin,min(0.095*figureWidth,maxRightMargin)) ;
            bottomMargin = max(minBottomMargin,min(0.11*figureHeight,maxBottomMargin)) ;
            topMargin = max(minTopMargin,min(0.075*figureHeight,maxTopMargin)) ;            
            axesAndButtonsAreaWidth = figureWidth - leftMargin - rightMargin ;
            axesAndButtonsAreaHeight = figureHeight - bottomMargin - topMargin ;

            % If not enough vertical space for the buttons, hide them
            if axesAndButtonsAreaHeight < 4*yRangeButtonSize + spaceBetweenScrollButtons + spaceBetweenZoomButtons + minHeightBetweenButtonBanks ,
                isEnoughHeightForButtons = false ;
                % Recalculate some things that are affected by this change
                minRightMargin = minRightMarginIfNoButtons ;
                maxRightMargin = maxRightMarginIfNoButtons ;
                rightMargin = max(minRightMargin,min(0.095*figureWidth,maxRightMargin)) ;
                axesAndButtonsAreaWidth = figureWidth - leftMargin - rightMargin ;                
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
                bottomMargin = figureHeight - axesAndButtonsAreaHeight - topMargin ;  % can be less than minBottomMargin, and that's ok
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
            set(self.AxesGH_,'Position',[axesXOffset axesYOffset axesWidth axesHeight]);            
            
            % the zoom buttons
            yRangeButtonsX=axesXOffset+axesWidth+fromAxesToYRangeButtonsWidth;
            zoomOutButtonX=yRangeButtonsX;
            zoomOutButtonY=axesYOffset;  % want bottom-aligned with axes
            set(self.YZoomOutButtonGH_, ...
                'Visible',ws.utility.onIff(doShowButtons) , ...
                'Position',[zoomOutButtonX zoomOutButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            zoomInButtonX=yRangeButtonsX;
            zoomInButtonY=zoomOutButtonY+yRangeButtonSize+spaceBetweenZoomButtons;  % want just above other zoom button
            set(self.YZoomInButtonGH_, ...
                'Visible',ws.utility.onIff(doShowButtons) , ...
                'Position',[zoomInButtonX zoomInButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            
            % the scroll buttons
            scrollUpButtonX=yRangeButtonsX;
            scrollUpButtonY=axesYOffset+axesHeight-yRangeButtonSize;  % want top-aligned with axes
            set(self.YScrollUpButtonGH_, ...
                'Visible',ws.utility.onIff(doShowButtons) , ...
                'Position',[scrollUpButtonX scrollUpButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            scrollDownButtonX=yRangeButtonsX;
            scrollDownButtonY=scrollUpButtonY-yRangeButtonSize-spaceBetweenScrollButtons;  % want under scroll up button
            set(self.YScrollDownButtonGH_, ...
                'Visible',ws.utility.onIff(doShowButtons) , ...
                'Position',[scrollDownButtonX scrollDownButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
        end  % function
        
    end
    
    methods (Access = protected)
        function addChannelLineToAxes_(self)
            % Creates a new channel line, adding it to the end of self.LineGHs_.
            iChannel=length(self.LineGHs_)+1;
            newChannelName=self.Model.ChannelNames{iChannel};
            
            colorOrder = get(self.AxesGH_ ,'ColorOrder');
            color = colorOrder(self.Model.ChannelColorIndex(iChannel), :);
            
            self.LineGHs_(iChannel) = ...
                line('Parent', self.AxesGH_,...
                     'XData', [],...
                     'YData', [],...
                     'ZData', [],...
                     'Color', color,...
                     'Tag', sprintf('%s::%s', self.Model.Tag, newChannelName));
%                                      'LineWidth', 2,...
%                      'Marker', self.Model.Marker,...
%                      'LineStyle', self.Model.LineStyle,...
        end  % function
        
%         function modelAxisLimitWasSet(self)
%             self.updateReferenceLines();
%         end
        
        function modelGenericVisualPropertyWasSet_(self)
            self.update();
        end  % function 
        
        function updateLineXDataAndYData_(self)
            for iChannel = 1:self.Model.NChannels ,                
                thisLineGH = self.LineGHs_(iChannel);
                ws.utility.setifhg(thisLineGH, 'XData', self.XForPlotting_, 'YData', self.YForPlotting_(:,iChannel));
            end                     
        end  % function
        
        function updateYAxisLabel_(self,color)
            % Updates the y axis label handle graphics to match the model state
            % and that of the Acquisition subsystem.
            %set(self.AxesGH_,'YLim',self.YOffset+[0 self.YRange]);
            if self.Model.NChannels==0 ,
                ylabel(self.AxesGH_,'Signal','Color',color,'FontSize',10);
            else
                %firstChannelName=self.Model.ChannelNames{1};
                %iFirstChannel=self.Model.WavesurferModel.Acquisition.iChannelFromName(firstChannelName);
                %units=self.Model.WavesurferModel.Acquisition.ChannelUnits(iFirstChannel);
                units=self.Model.YUnits;
                if units.isPure() ,
                    unitsString = 'pure' ;
                else
                    unitsString = string(units) ;
                end
                ylabel(self.AxesGH_,sprintf('Signal (%s)',unitsString),'Color',color,'FontSize',10);
            end
        end  % function
        
        function updateXAxisLimits_(self)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            xlimInModel=self.Model.XLim;
            %ws.utility.setifhg(self.AxesGH_, 'XLim', xl);
            if ~isequal(xlimInModel,self.XLim) ,                
                % Set this directly, instead of calling the XLim setter
                % This means that we don't fire the DidSetXLim method.
                % This should be OK, since updateXAxisLimits_ is only called in 
                % response to the model firing an event
                self.XLim_=xlimInModel;
                set(self.AxesGH_,'XLim',xlimInModel);
            end
        end  % function        

        function updateYAxisLimits_(self)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            ylimInModel=self.Model.YLim;
            %ws.utility.setifhg(self.AxesGH_, 'YLim', yl);
            if ~isequal(ylimInModel,self.YLim) ,   
                % Set this directly, instead of calling the YLim setter
                % This means that we don't fire the DidSetYLim method.
                % This should be OK, since updateYAxisLimits_ is only called in 
                % response to the model firing an event
                self.YLim_=ylimInModel;
                set(self.AxesGH_,'YLim',ylimInModel);
            end
        end  % function        

%         function updateAreYLimitsLockedTightToData_(self)
%             % Update the axes limits to match those in the model
%             if isempty(self.Model) || ~isvalid(self.Model) ,
%                 return
%             end
%             areYLimitsLockedTightToData = self.Model.AreYLimitsLockedTightToData ;
%             set(self.SetYLimTightToDataLockedButtonGH_,'State',ws.utility.onIff(areYLimitsLockedTightToData));            
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
    
    methods (Static=true)
        function result=getWidthInPixels(ax)
            % Gets the x span of the given axes, in pixels.
            savedUnits=get(ax,'Units');
            set(ax,'Units','pixels');
            pos=get(ax,'Position');
            result=pos(3);
            set(ax,'Units',savedUnits);            
        end  % function
        
        function r=ratioSubsampling(t,T_view,n_pels_view)
            % Computes r, a good ratio to use for subsampling data on time base t
            % for plotting in Spoke_main_plot plot, given that the x axis of
            % Spoke_main_plot spans T_view seconds.  Returns the empty matrix if no
            % subsampling is called for.
            n_t=length(t);
            if n_t==0
                r=[];
            else
                dt=(t(end)-t(1))/(n_t-1);
                n_t_view=T_view/dt;
                samples_per_pel=n_t_view/n_pels_view;
                %if samples_per_pel>10  % original value
                if samples_per_pel>2
                    %if samples_per_pel>1.2
                    % figure out how much we're going to subsample
                    samples_per_pel_want=2;  % original value
                    %samples_per_pel_want=1;
                    n_t_view_want=n_pels_view*samples_per_pel_want;
                    r=floor(n_t_view/n_t_view_want);
                else
                    r=[];  % no need for resampling
                end
            end
        end  % function
        
        function [t_sub_dub,data_sub_dub]=minMaxDownsample(t,data,r)
            % Static method to downsample data, but in a way that is well-suited
            % to on-screen display.  For every r data points, we calculate the min
            % and the max of them, and these are returned in data_sub_min and
            % data_sub_max.
            
            % if r is empty, means no downsampling called for
            if isempty(r)
                % don't subsample
                t_sub_dub=t;
                data_sub_dub=data;
            else
                % get data dims
                [n_t,n_signals,n_sweeps]=size(data);
                
                % downsample the timeline
                t_sub=t(1:r:end);
                n_t_sub=length(t_sub);
                
                % turns out that it's best to write this as a loop that can be
                % JIT-compiled my Matlab.  This is faster than blkproc(), it turns
                % out.
                data_sub_max=zeros(n_t_sub,n_signals,n_sweeps);
                data_sub_min=zeros(n_t_sub,n_signals,n_sweeps);
                for k=1:n_sweeps
                    for j=1:n_signals
                        i=1;
                        for i_sub=1:(n_t_sub-1)
                            mx=-inf;
                            mn=+inf;
                            for i_offset=1:r
                                d=data(i,j,k);
                                if d>mx
                                    mx=d;
                                end
                                if d<mn
                                    mn=d;
                                end
                                i=i+1;
                            end
                            data_sub_max(i_sub,j,k)=mx;
                            data_sub_min(i_sub,j,k)=mn;
                        end
                        % the last block may have less than r elements
                        mx=-inf;
                        mn=+inf;
                        n_t_left=n_t-r*(n_t_sub-1);
                        for i_offset=1:n_t_left
                            d=data(i,j,k);
                            if d>mx
                                mx=d;
                            end
                            if d<mn
                                mn=d;
                            end
                            i=i+1;
                        end
                        data_sub_max(n_t_sub,j,k)=mx;
                        data_sub_min(n_t_sub,j,k)=mn;
                    end  % for j=1:n_signals
                end  % for k=1:n_sweeps
                
                % now "double-up" time, and put max's in the odd times, and min's in
                % the even times
                t_sub_dub=nan(2*n_t_sub,1);
                t_sub_dub(1:2:end)=t_sub;
                t_sub_dub(2:2:end)=t_sub;
                data_sub_dub=nan(2*n_t_sub,n_signals,n_sweeps);
                data_sub_dub(1:2:end,:,:)=data_sub_max;
                data_sub_dub(2:2:end,:,:)=data_sub_min;
            end
        end  % function
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
