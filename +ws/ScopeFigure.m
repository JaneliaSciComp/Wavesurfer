classdef ScopeFigure < ws.MCOSFigure & ws.EventSubscriber & ws.EventBroadcaster
    % This is an EventBroadcaster only so that changes to it via the
    % default Matlab figure controls can be communicated to the model (via
    % the controller)
    
    properties (Dependent=true)
        XLim
        YLim
    end

    properties (Access = protected)
        AxesGH;  % HG handle to axes
        LineGHs = zeros(1,0);  % row vector, the line graphics handles for each channel
        %HeldLineGHs;        
%         HorizontalCenterLineGH;  % HG handle to line
%         VerticalCenterLineGH;  % HG handle to line
%         GroundLineGH;  % HG handle to line
        YForPlotting  
            % nScans x nChannels
            % Y data downsampled to approximately two points per pixel,
            % with the first point the min for that pixel, second point the
            % max for that pixel.
        XForPlotting  
            % nScans x 1
            % X data for the points in YForPlotting.  As such, this consist
            % of a sequence of pairs, with each member of a pair being
            % equal.
        XLim_
        YLim_
    end
    
    properties (SetAccess=protected)
        SetYLimTightToDataButtonGH
        ScopeMenuGH
        YLimitsMenuItemGH
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
            import ws.utility.*
            
            self = self@ws.MCOSFigure(model,controller);
            
            % create the downsampled data
            nChannels=length(model.ChannelNames);
            self.XForPlotting=zeros(0,1);
            self.YForPlotting=zeros(0,nChannels);
            
            %
            % Create all the widgets, set them up
            %
            set(self.FigureGH, ...
                'Tag',model.Tag,...
                'Name', model.Title, ...
                'Color', model.BackgroundColor,...
                'NumberTitle', 'off',...
                'Units', 'pixels',...
                'HandleVisibility', 'on',...
                'Renderer','OpenGL', ...
                'CloseRequestFcn', @(source,event)self.closeRequested(source,event));
%                 'Toolbar','none', ...
%                 'MenuBar','none', ...
            
            xl=model.XLim;
            yl=model.YLim;
            self.AxesGH = ...
                axes('Parent', self.FigureGH, ...
                     'Position', [0.11 0.11 0.87 0.83], ...
                     'FontSize', model.FontSize, ...
                     'FontWeight', model.FontWeight, ...
                     'Color', model.BackgroundColor, ...
                     'XColor', model.ForegroundColor, ...
                     'YColor', model.ForegroundColor, ...
                     'ZColor', model.ForegroundColor, ...
                     'XGrid', onIff(model.GridOn), ...
                     'YGrid', onIff(model.GridOn), ...
                     'XLim',xl, ...
                     'YLim',yl ...
                     );
            self.XLim_=xl;
            self.YLim_=yl;
            
            colorOrder = get(self.AxesGH, 'ColorOrder');
            colorOrder = [1 1 1; 1 0.25 0.25; colorOrder];
            set(self.AxesGH, 'ColorOrder', colorOrder);
            
%             self.HorizontalCenterLineGH = ...
%                 line('Parent', self.AxesGH,...
%                      'XData',[],...
%                      'YData',[],...
%                      'Color',[0 0 0],...
%                      'LineStyle','-.',...
%                      'Marker','d',...
%                      'Tag','scope_horizontalCenterLine');
%             
%             self.VerticalCenterLineGH = ...
%                 line('Parent',self.AxesGH,...
%                      'XData',[],...
%                      'YData',[],...
%                      'Color',[0 0 0],...
%                      'LineStyle','-.',...
%                      'Marker','d',...
%                      'Tag','scope_verticalCenterLine');
%             
%             self.GroundLineGH = ...
%                 line('Parent',self.AxesGH,...
%                      'XData',[],...
%                      'YData',[],...
%                      'Color',[0 .5 0],...
%                      'LineStyle','-.',...
%                      'LineWidth',2,...
%                      'Marker','none',...
%                      'Tag','scope_groundLine',...
%                      'Visible','off');

            xlabel(self.AxesGH,sprintf('Time (%s)',string(model.XUnits)));

            % Set up listeners to monitor the axes XLim, YLim, and to set
            % the XLim and YLim properties when they change.  This is
            % mainly so that the XLim and YLim properties can be observed,
            % and used to change them in the model to maintain
            % synchronization.
            % Can't do this using EventBroadcaster/EventSubscriber
            % mechanism b/c can't make the axes HG object an
            % EventBroadcaster.
            addlistener(self.AxesGH,'XLim','PostSet',@self.didSetXLimInAxesGH);
            addlistener(self.AxesGH,'YLim','PostSet',@self.didSetYLimInAxesGH);
            
            % Add a line for each channel in the model
            for i=1:self.Model.NChannels
                self.addChannelLine();
            end
            
            % Add a toolbar button
            wavesurferDirName=fileparts(which('wavesurfer'));
            [cdata, map] = imread(fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'y_tight_to_data.png'));
            map(map(:,1)+map(:,2)+map(:,3)==0) = NaN;
            cdata = ind2rgb(cdata, map);
            toolbarGH = findall(self.FigureGH, 'tag', 'FigureToolBar');
            self.SetYLimTightToDataButtonGH= ...
                uipushtool(toolbarGH, ...
                           'CData', cdata, ...
                           'TooltipString', 'Set y-axis limits tight to data', ....
                           'ClickedCallback', @(source,event)self.controlActuated('SetYLimTightToDataButtonGH',source,event));
                         
            % Add a menu, and a single menu item
            self.ScopeMenuGH = ...
                uimenu('Parent',self.FigureGH, ...
                       'Label','Scope');
            self.YLimitsMenuItemGH = ...
                uimenu('Parent',self.ScopeMenuGH, ...
                       'Label','Y Limits...', ...
                       'Callback',@(source,event)self.controlActuated('YLimitsMenuItemGH',source,event));
            
            % Subscribe to some model events
            model.subscribeMe(self,'Update','','update');
            
%             propertyNames = ws.most.util.findPropertiesSuchThat(model,'SetObservable',true);
%             for i=1:length(propertyNames) ,
%                 propertyName=propertyNames{i};
%                 model.subscribeMe(self,'PostSet',propertyName,'modelPropertyWasSet');
%             end
            
            %model.subscribeMe(self,'YAutoScaleWasSet','','modelYAutoScaleWasSet');
            model.subscribeMe(self,'ChannelAdded','','modelChannelAdded');
            model.subscribeMe(self,'DataAdded','','modelDataAdded');
            model.subscribeMe(self,'DataCleared','','modelDataCleared');
            model.subscribeMe(self,'DidSetChannelUnits','','modelChannelUnitsSet');           

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
            
            % Do stuff to make ws.most.Controller happy
            self.setHGTagsToPropertyNames_();
            self.updateGuidata_();
            
            % sync up self to model
            self.update();            
        end  % constructor
        
        function delete(self)
            % if ~isempty(self.Model) && isvalid(self.Model) ,
            %     self.Model.unsubscribeMeFromAll(self);
            % end
            ws.utility.deleteIfValidHGHandle(self.LineGHs);
            %deleteIfValidHGHandle(self.GroundLineGH);
            %deleteIfValidHGHandle(self.VerticalCenterLineGH);
            %deleteIfValidHGHandle(self.HorizontalCenterLineGH);
            ws.utility.deleteIfValidHGHandle(self.AxesGH);            
        end
        
%         function result=get.IsVisibleWhenDisplayEnabled(self)
%             model=self.Model;
%             if isempty(model) ,
%                 result=[];
%             else
%                 result=model.IsVisibleWhenDisplayEnabled;
%             end
%         end  % function

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

    end  % methods
    
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
                set(self.AxesGH,'XLim',newValue);
            end
            self.broadcast('DidSetXLim');
        end
        
        function value=get.XLim(self)
            value=self.XLim_;
        end
        
        function set.YLim(self,newValue)
            %fprintf('ScopeFigure::set.YLim()\n');
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
                self.YLim_=newValue;
                set(self.AxesGH,'YLim',newValue);
            end
            self.broadcast('DidSetYLim');
        end
            
        function value=get.YLim(self)
            value=self.YLim_;
        end
                
        function didSetXLimInAxesGH(self,varargin)
            self.XLim=get(self.AxesGH,'XLim');
        end
        
        function didSetYLimInAxesGH(self,varargin)
            %fprintf('ScopeFigure::didSetYLimInAxesGH()\n');
            %ylOld=self.YLim
            ylNew=get(self.AxesGH,'YLim');
            self.YLim=ylNew;
        end
        
        function modelPropertyWasSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD,INUSL>
            if isequal(propertyName,'YLim') ,
                self.modelYAxisLimitSet();
            elseif isequal(propertyName,'XOffset') ||  isequal(propertyName,'XSpan') ,
                self.modelXAxisLimitSet();                
            else
                self.modelGenericVisualPropertyWasSet();
            end
        end
        
%         function modelYAutoScaleWasSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             isToggleOn=isequal(get(self.SetYLimTightToDataButtonGH,'State'),'on');
%             if isToggleOn ~= self.Model.YAutoScale ,
%                 set(self.SetYLimTightToDataButtonGH,'State',onIff(self.Model.YAutoScale));  % sync to the model
%             end
%         end
        
        function modelXAxisLimitSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateXAxisLimits();
        end
        
        function modelYAxisLimitSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateYAxisLimits();
        end
        
        function modelChannelAdded(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            % Redimension downsampled data, clearing the existing data in
            % the process
            nChannels=self.Model.NChannels;
            self.XForPlotting=zeros(0,1);
            self.YForPlotting=zeros(0,nChannels);            
            
            % Do other stuff
            self.addChannelLine();
            self.update();
        end
        
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
            xSpanInPixels=ws.ScopeFigure.getWidthInPixels(self.AxesGH);
            r=ws.ScopeFigure.ratioSubsampling(x,self.Model.XSpan,xSpanInPixels);
            
            % get the current downsampled data
            xForPlottingOriginal=self.XForPlotting;
            yForPlottingOriginal=self.YForPlotting;
            
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
            self.XForPlotting=[xForPlottingOriginalTrimmed; ...
                               xForPlottingNew];
            self.YForPlotting=[yForPlottingOriginalTrimmed; ...
                               yForPlottingNew];

            % Update the lines
            self.updateLineXDataAndYData();
        end
        
        function modelDataCleared(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            nChannels=self.Model.NChannels;
            self.XForPlotting=zeros(0,1);
            self.YForPlotting=zeros(0,nChannels);                        
            self.updateLineXDataAndYData();                      
        end
        
        function modelChannelUnitsSet(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.update();
        end

        function updateColorsFontsTitleGridAndTags(self)
            import ws.utility.onIff
            
            model=self.Model;
            set(self.FigureGH, ...
                'Tag',model.Tag,...
                'Name', model.Title, ...
                'Color', model.BackgroundColor);
            set(self.AxesGH, ...
                'FontSize', model.FontSize, ...
                'FontWeight', model.FontWeight, ...
                'Color', model.BackgroundColor, ...
                'XColor', model.ForegroundColor, ...
                'YColor', model.ForegroundColor, ...
                'ZColor', model.ForegroundColor, ...
                'XGrid', onIff(model.GridOn), ...
                'YGrid', onIff(model.GridOn) ...
                );
        end
    end  % methods
    
    methods (Access=protected)
        function updateImplementation_(self,varargin)
            % Syncs self with the model.
            
            % If there are issues with the model, just return
            model=self.Model;
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
            % Need to figure out the wavesurferModel State            
            display=[];
            if ~isempty(model) && isvalid(model),
                display=model.Parent;
            end
            wavesurferModel=[];
            if ~isempty(display) && isvalid(display),
                wavesurferModel=display.Parent;
            end
            isWavesurferIdle=[];
            if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                isWavesurferIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
            end
            if isempty(isWavesurferIdle)
                isWavesurferIdle=true;  % things are probably fucked anyway...
            end            

            % Update the axis limits
            self.updateXAxisLimits();
            self.updateYAxisLimits();
            
            % Update the graphics objects to match the model
            self.updateYAxisLabel();
            self.updateLineXDataAndYData();
            
            % Update the enablement of controls
            import ws.utility.onIff
            set(self.SetYLimTightToDataButtonGH,'Enable',onIff(isWavesurferIdle));
            set(self.YLimitsMenuItemGH,'Enable',onIff(isWavesurferIdle));            
        end                
    end
    
    methods (Access = protected)
        function addChannelLine(self)
            % Creates a new channel line, adding it to the end of self.LineGHs.
            iChannel=length(self.LineGHs)+1;
            newChannelName=self.Model.ChannelNames{iChannel};
            
            colorOrder = get(self.AxesGH ,'ColorOrder');
            color = colorOrder(self.Model.ChannelColorIndex(iChannel), :);
            
            self.LineGHs(iChannel) = ...
                line('Parent', self.AxesGH,...
                     'XData', [],...
                     'YData', [],...
                     'ZData', [],...
                     'Color', color,...
                     'Marker', self.Model.Marker,...
                     'LineStyle', self.Model.LineStyle,...
                     'Tag', sprintf('%s::%s', self.Model.Tag, newChannelName));
%                                      'LineWidth', 2,...
        end
        
%         function modelAxisLimitWasSet(self)
%             self.updateReferenceLines();
%         end
        
        function modelGenericVisualPropertyWasSet(self)
            self.update();
        end 
        
        function updateLineXDataAndYData(self)
            for iChannel = 1:self.Model.NChannels ,                
                thisLineGH = self.LineGHs(iChannel);
                ws.utility.setifhg(thisLineGH, 'XData', self.XForPlotting, 'YData', self.YForPlotting(:,iChannel));
            end                     
        end
        
        function updateYAxisLabel(self)
            % Updates the y axis label handle graphics to match the model state
            % and that of the Acquisition subsystem.
            %set(self.AxesGH,'YLim',self.YOffset+[0 self.YRange]);
            if self.Model.NChannels==0 ,
                ylabel(self.AxesGH,'Signal');
            else
                %firstChannelName=self.Model.ChannelNames{1};
                %iFirstChannel=self.Model.WavesurferModel.Acquisition.iChannelFromName(firstChannelName);
                %units=self.Model.WavesurferModel.Acquisition.ChannelUnits(iFirstChannel);
                units=self.Model.YUnits;
                ylabel(self.AxesGH,sprintf('Signal (%s)',string(units)));
            end
        end
        
        function updateXAxisLimits(self)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            xlimInModel=self.Model.XLim;
            %ws.utility.setifhg(self.AxesGH, 'XLim', xl);
            if any(xlimInModel~=self.XLim) ,                
                self.XLim=xlimInModel;
            end
        end        

        function updateYAxisLimits(self)
            % Update the axes limits to match those in the model
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            ylimInModel=self.Model.YLim;
            %ws.utility.setifhg(self.AxesGH, 'YLim', yl);
            if any(ylimInModel~=self.YLim) ,                
                self.YLim=ylimInModel;
            end
        end        
        
%         function updateAxisLimits(self)
%             % Update the axes limits to match those in the model
%             if isempty(self.Model) || ~isvalid(self.Model) ,
%                 return
%             end
%             xl=self.Model.XLim;
%             yl=self.Model.YLim;
%             setifhg(self.AxesGH, 'XLim', xl, 'YLim', yl);
%         end

%         function updateScaling(self)
% %             % Update the axes x-limits to accomodate the lines in it.
% %             xMax=self.Model.MaxXData;            
% %             xLim = [max([0, xMax - self.Model.XRange]), max(xMax, self.Model.XRange)];
% %             setifhg(self.AxesGH, 'XLim', xLim);
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
        end
        
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
