classdef ScopeModel < ws.Model     % & ws.EventBroadcaster 
%     properties (Constant=true)
%         BackgroundColor = [0 0 0];
%         ForegroundColor = [.15 .9 .15];
%         FontSize = 10;
%         FontWeight = 'normal';
%         LineStyle = '-';
%         Marker = 'none';
%         %GridOn = true
%     end

    properties (Dependent=true, SetAccess=protected)
        Parent  % the parent Display object
          % this is SetAccess=protected for historical reasons
          % would be nice to change it to immutable at some point
    end
    
    properties (Dependent=true, SetAccess=immutable)
        Tag        % This should be a unique tag that identifies this ScopeModel.
                   % This is used as the Tag for any ScopeFigure that uses
                   % this ScopeModel as its model, and should be usable as
                   % a field name in a structure, for saving/loading
                   % purposes.
        ChannelNames   % row vector, the channel names shown in this scope
        ChannelColorIndex  
        NChannels
        XData
        YData
    end
    
    properties (Dependent=true)  %(SetObservable = true)
        Title        % This is the window title used by any ScopeFigures that use this
                     % ScopeModel as their Model.
        XUnits
        YUnits
        YScale   % implicitly in units of V/YUnits (need this to keep the YLim fixed in terms of volts at the ADC when the channel units/scale changes
        AreYLimitsLockedTightToData
        XOffset  % the x coord shown at the leftmost edge of the plot
        XSpan  % the difference between the xcoord shown at the rightmost edge of the plot and XOffset
        XLim
        YLim
        IsGridOn
        AreColorsNormal        
        DoShowButtons
    end

    properties (Dependent=true, Transient=true)  % not sure this needs to be transient, since it's dependent...
        IsVisibleWhenDisplayEnabled
          % Indicates whether scope is visible when the Display subsystem
          % is enabled.  If display subsystem is disabled, the scopes are
          % all made invisible, but this stores who will be made
          % immediately visible if the display system is reenabled.  Note
          % that this is not persisted in the protocol (.cfg) file --- 
          % persistence of window visibility
          % is all stored in the .usr file, and all other WavesurferModel properties
          % (of which ScopeModels are a part) are all persisted in the .cfg
          % file.  We want it to be clear to user where different kinds of
          % things are stored, not confuse them by having some aspects of
          % window visibilty stored in .usr, and some in .cfg.
    end
    
    properties (Access = protected, Transient=true)
        Parent_
        XData_  % a double array, holding x data for each channel
        YData_ = cell(1,0)  % a 1 x self.NChannels cell array, holding y data for each channel
          % Invariant: For all i,j length(YData{i})==length(YData{j})        
        BufferFactor_ = 1
        RunningMin_ = zeros(1,0)  % length == self.NChannels
        RunningMax_ = zeros(1,0)
        RunningMean_ = zeros(1,0)
        IsVisibleWhenDisplayEnabled_  
          % You'd think IsVisibleWhenDisplayEnabled_ would be non-transient, but it isn't because this information gets persisted in the 
          % "layout" part of the .cfg file.  Long-term, would be cleaner to
          % store it here, it seems to me.
    end
    
    properties (Access = protected)
        Tag_ = ''  % This should be a unique tag that identifies this ScopeModel.
                   % This is used as the Tag for any ScopeFigure that uses
                   % this ScopeModel as its model, and should be usable as
                   % a field name in a structure, for saving/loading
                   % purposes.
        Title_ = ''  % This is the window title used by any ScopeFigures that use this
                     % ScopeModel as their Model.        
        XUnits_ = ws.utility.SIUnit('s')
        YUnits_ = ws.utility.SIUnit()  % pure, which is correct for digital lines
        YScale_ = 1   % implicitly in units of V/YUnits (need this to keep the YLim fixed in terms of volts at the ADC when the channel units/scale changes
        AreYLimitsLockedTightToData_ = false
        XOffset_ = 0
        XSpan_ = 1
        YLim_ = [-10 +10]
        ChannelNames_ = cell(1,0)  % row vector
        ChannelColorIndex_ = zeros(1,0)
        IsGridOn_ = true
        AreColorsNormal_ = true  % if false, colors are inverted, approximately
        DoShowButtons_ = true % if false, don't show buttons in the figure
    end
    
    events
        ChannelAdded
        DataAdded
        DataCleared
        DidSetChannelUnits
        WindowVisibilityNeedsToBeUpdated
        UpdateYAxisLimits
        UpdateAreYLimitsLockedTightToData
    end  % events
    
    methods
        function self = ScopeModel(varargin)
            % Creates a ScopeModel object.  The 'Tag' property is
            % required.  In almost all cases, the 'WavesurferModel' property
            % should also be specified, although occasionally it is useful
            % to leave it out while debugging or testing.
            
            self.IsVisibleWhenDisplayEnabled_=true;
            %
            % Parse and set PV args
            %
            
            % Filter out not-publically-settable props
            validPropNames=[ws.most.util.findPropertiesSuchThat(self,'SetAccess','public') {'Tag' 'Title' 'Parent'}];
            %mandatoryPropNames={'Tag'};
            mandatoryPropNames=cell(1,0);
            pvArgs = ws.most.util.filterPVArgs(varargin,validPropNames,mandatoryPropNames);

            % Make sure there's the same number of props as vals
            propNamesRaw = pvArgs(1:2:end);
            propValsRaw = pvArgs(2:2:end);
            nRawPVs=length(propValsRaw);  % Use the number of vals in case length(varargin) is odd
            propNames=propNamesRaw(1:nRawPVs);
            propVals=propValsRaw(1:nRawPVs);            
            
            % We need to have a unique tag, so make one, even though it
            % will possibly get overwritten by a PV pair
            randomTag=sprintf('scopeModel%015d',randi(10^15)-1);  % very unlikely to be a duplicate
            %randomTag='scopeModel';
            self.Tag=randomTag;
            
            % Set the properties
            for idx = 1:length(propVals)
                self.(propNames{idx}) = propVals{idx};
            end
        end  % constructor
        
%         function delete(self)
%             %self.Parent=[];  % get rid of ref to WavesurferModel
%         end
    end  % methods
    
    methods
        function set.Parent(self, newValue)
            self.Parent_ = newValue;
        end
        
        function result = get.Parent(self)
            result = self.Parent_ ;
        end
        
        function set.Title(self, newValue)            
            self.Title_ = newValue ;
        end
        
        function result = get.Title(self)
            result = self.Title_ ;
        end

        function result = get.Tag(self)
            result = self.Tag_ ;
        end

        function result = get.ChannelNames(self)
            result = self.ChannelNames_ ;
        end

        function result = get.ChannelColorIndex(self)
            result = self.ChannelColorIndex_ ;
        end

        function result = get.XData(self)
            result = self.XData_ ;
        end
        
        function result = get.YData(self)
            result = self.YData_ ;
        end
        
        function result = get.AreYLimitsLockedTightToData(self)
            result = self.AreYLimitsLockedTightToData_ ;
        end
        
        function set.AreYLimitsLockedTightToData(self,newValue)
            if islogical(newValue) && isscalar(newValue) ,
                self.AreYLimitsLockedTightToData_ = newValue ;
            end
            self.broadcast('UpdateAreYLimitsLockedTightToData');  % Want a special update for this, since it will happen while data is ebing acquired
            self.setYAxisLimitsTightToDataIfAreYLimitsLockedTightToData_();
        end
        
%         function set.XAutoScroll(self,newValue)
%             if islogical(newValue) && isscalar(newValue) ,
%                 self.XAutoScroll=newValue;
%             end
%             %self.updateXLim();
%             self.broadcast('XAutoScrollWasSet');
%         end
        
%         function val = get.MaxXData(self)
%             val=0;  % want this to be returned if NChannels==0
%             for i=1:self.NChannels
%                 thisXData=self.XData{i};
%                 if ~isempty(thisXData) ,
%                     val=max(val,thisXData(end));
%                 end
%             end
%         end
                
%         function set.XLim(self,newValue)
%             if isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
%                 self.XLim=newValue;
%                 %set(self.Axes,'XLim',newValue);
%                 self.broadcast('AxisLimitSet');
%             end
%         end

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
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.IsGridOn_ = logical(newValue) ;
                else
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
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.AreColorsNormal_ = logical(newValue) ;
                else
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
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.DoShowButtons_ = logical(newValue) ;
                else
                    error('most:Model:invalidPropVal', ...
                          'DoShowButtons must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');
        end
        
        function result = get.DoShowButtons(self)
            result = self.DoShowButtons_ ;
        end
            
        function set.XOffset(self,newValue)
            if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                self.XOffset_ = newValue;
                %self.XLim=ws.most.util.Nonvalue.The;
            end
            self.broadcast('Update');
        end

        function value=get.XOffset(self)
            value = self.XOffset_ ;
        end
        
        function set.XSpan(self,newValue)
            if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
                self.XSpan_ = newValue ;
                %self.XLim=ws.most.util.Nonvalue.The;
            end
            self.broadcast('Update');
        end
        
        function value=get.XSpan(self)
            value = self.XSpan_ ;
            %self.broadcast('Update');
        end
        
        function value=get.XLim(self)
            value = self.XOffset+[0 self.XSpan];
        end
        
        function set.XLim(self, newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
                self.XOffset=newValue(1);
                self.XSpan=newValue(2)-newValue(1);
            end
            % XOffset and XSpan setters take care of broadcasting an update
        end
        
        function set.YLim(self,newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
                self.YLim_ = newValue;
            end
            self.broadcast('UpdateYAxisLimits');
        end
        
        function value=get.YLim(self)
            value=self.YLim_;
        end
        
        function zoomIn(self)
            yLimits=self.YLim;
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+0.5*yRadius*[-1 +1];
            self.YLim=newYLimits;
        end  % function
        
        function zoomOut(self)
            yLimits=self.YLim;
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+2*yRadius*[-1 +1];
            self.YLim=newYLimits;
        end  % function
        
        function scrollUp(self)
            yLimits=self.YLim;
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle+0.1*ySpan)+yRadius*[-1 +1];
            self.YLim=newYLimits;
        end  % function
        
        function scrollDown(self)
            yLimits=self.YLim;
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle-0.1*ySpan)+yRadius*[-1 +1];
            self.YLim=newYLimits;
        end  % function
        
        function value=get.NChannels(self)
            value=length(self.ChannelNames);
        end
        
        function result=get.IsVisibleWhenDisplayEnabled(self)
            result=self.IsVisibleWhenDisplayEnabled_;
        end
        
        function set.IsVisibleWhenDisplayEnabled(self,newValue)
            if islogical(newValue) && isscalar(newValue) ,
                self.IsVisibleWhenDisplayEnabled_=newValue;
            end
            self.broadcast('WindowVisibilityNeedsToBeUpdated');
            %self.broadcast('WavesurferScopeMenuNeedsToBeUpdated');
            if ~isempty(self.Parent) ,
                self.Parent.didSetScopeIsVisibleWhenDisplayEnabled();
            end
        end
        
        function set.Tag(self,newValue)
            % Make sure it's a valid field name before setting the Tag to
            % it
            if ischar(newValue)
                isValidFieldName=true;
                try
                    s=struct();
                    s.(newValue)=0; %#ok<STRNU>
                catch excp
                    if isequal(excp.identifier,'MATLAB:AddField:InvalidFieldName')
                        isValidFieldName=false;
                    else
                        rethrow(excp);
                    end
                end
                if isValidFieldName ,
                    self.Tag_ = newValue;
                end
            end
        end
        
        function set.XUnits(self,newValue)
            if isa(newValue,'ws.utility.SIUnit') && isscalar(newValue) ,
                self.XUnits_ = newValue;
            end
            self.broadcast('Update');
        end
        
        function set.YUnits(self,newValue)
            if isa(newValue,'ws.utility.SIUnit') && isscalar(newValue) ,
                self.YUnits_ = newValue;
            end
            self.broadcast('Update');
        end
        
        function set.YScale(self,newValue)
            if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                self.YScale_ = newValue;
            end
            self.broadcast('Update');
        end
        
        function result=get.XUnits(self)
            result = self.XUnits_ ;
        end
        
        function result=get.YUnits(self)
            result = self.YUnits_ ;
        end

        function result=get.YScale(self)
            result = self.YScale_ ;
        end

    end  % methods
    
    methods
        function addChannel(self, newChannelName)
            assert(ischar(newChannelName) && ~isempty(newChannelName), ...
                   'A new, valid channel name must be supplied to addChannel()');
            
            % If channel already on scope, just return   
            if any(strcmp(newChannelName,self.ChannelNames)) ,
                return
            end
               
            nChannelsOriginally=self.NChannels;
            iNewChannel=nChannelsOriginally+1;   
            self.ChannelNames_{iNewChannel} = newChannelName;
            %self.yUnits(end+1) = units;
            
            colorOrderIndex = iNewChannel;
            self.ChannelColorIndex_(iNewChannel)=colorOrderIndex;  % store value to colors don't change
            
            %colorOrder = get(self.Axes ,'ColorOrder');
            %color = colorOrder(colorOrderIndex, :);
            
            %self.ChannelNames(end + 1).ChannelName = newChannelID;
            %self.XDataLims(:,iNewChannel) = [0 0]';
            %self.XData{iNewChannel}=zeros(0,1);  % col vector
            self.YData_{iNewChannel}=zeros(0,1);  % col vector            
%             self.Lines(iNewChannel) = ...
%                 line('Parent', self.Axes,...
%                      'XData', [],...
%                      'YData', [],...
%                      'ZData', [],...
%                      'Color', color,...
%                      'Marker', self.Marker,...
%                      'LineStyle', self.LineStyle,...
%                      'LineWidth', 2,...
%                      'Tag', sprintf('%s::%s', self.Name, newChannelName));
            
            self.RunningMin_(iNewChannel) = 0;
            self.RunningMax_(iNewChannel) = 0;
            self.RunningMean_(iNewChannel) = 0;
            
            % If this is the first channel added, pretend the channel units
            % were just set from 1 V/V to something else, to trigger an
            % appropriate change in YLim
            if (nChannelsOriginally==0)
                %self.YLimAtADCBeforeChange=self.YLim;
                self.didSetAnalogChannelUnitsOrScales();
            end
            
            %self.updateYAxisLabel()
            self.broadcast('ChannelAdded');
        end
        
        function addData(self, dataChannelNames, newData, sampleRate, newXOffset)
            %T=zeros(1,5);
            %ticId=tic();
            %T(1)=toc(ticId);
            assert(isnumeric(newData), 'Invalid data format supplied.');
            
            if ~iscell(dataChannelNames) ,
                dataChannelNames = {dataChannelNames};
            end
            
            nNewScans = size(newData, 1);
            %nChannels=size(data,2);
            dt=1/sampleRate;  % s
            newXData = linspace(0, dt*(nNewScans-1), nNewScans)';
            %T(2)=toc(ticId);
            %channelsWithLines = {self.chanLines.ChannelName};
            
            % deal with XData
            currXData = self.XData;
            if isempty(currXData) ,
                xData = newXData;
            else
                xData = [currXData; currXData(end) + dt + newXData];
            end
            % If number of samples is too large to display, trim off
            % the old ones 
            nDisplayableSamples = ceil(self.XSpan * sampleRate * self.BufferFactor_);
            if length(xData) > nDisplayableSamples
                xData=xData(end-nDisplayableSamples+1:end);
            end
            % Commit the data
            self.XData_=xData;
            %T(3)=toc(ticId);
            
            % Deal with YData
            for jInData = 1:numel(dataChannelNames)
                % Figure out the channel index for this channel
                dataChannelName=dataChannelNames{jInData};
                iChannel = find(strcmp(dataChannelName,self.ChannelNames), 1);                
                if isempty(iChannel)
                    continue
                end

                % Add the new data onto the existing data in a local
                % variable
                currYData = self.YData{iChannel};
                yData = [currYData; newData(:, jInData)];
                
                % If number of samples is too large to display, trim off
                % the old ones 
                if length(yData) > nDisplayableSamples
                    yData=yData(end-nDisplayableSamples+1:end);
                end
                
                % Commit the data
                self.YData_{iChannel}=yData;
            end
            
            if newXOffset~=self.XOffset , 
                self.XOffset=newXOffset;
            end
            %T(4)=toc(ticId);
            self.setYAxisLimitsTightToDataIfAreYLimitsLockedTightToData_();
            %T(5)=toc(ticId);
            
            % Update the plot limits to accomodate the new data, if
            % needed
            %self.updateScaling();
            %fprintf('ScopeModel.addData(): About to broadcast(''DataAdded'')...\n');
            self.broadcast('DataAdded');            
            %fprintf('ScopeModel.addData(): Just after broadcast(''DataAdded'')...\n');
            %T(6)=toc(ticId);
            %dT=diff(T);
            %fprintf('ScopeModel.addData(): %7.3f %7.3f %7.3f %7.3f %7.3f\n',dT);
        end
        
        function clearData(self)
            for idx = 1:numel(self.ChannelNames)
                self.XData_=zeros(0,1);
                self.YData_{idx}=zeros(0,1);
                
                %set(self.Lines(idx), {'XData' 'YData'}, {[] []});
                %self.XDataLims(:,idx) = [0; 0];
                
                self.RunningMin_(idx) = 0;
                self.RunningMax_(idx) = 0;
                self.RunningMean_(idx) = 0;
            end
            
            %delete(self.HeldLines);
            %self.HeldLines = [];
            
            %self.updateScaling();
            self.broadcast('DataCleared');
        end
        
%         function eventHappened(self,publisher,eventName,propertyName,source,event)  %#ok
%             if isequal(eventName,'DidSetAnalogChannelUnitsOrScales')
%                 self.didSetAnalogChannelUnitsOrScales();
%             end
%         end
        
        function didSetAnalogChannelUnitsOrScales(self,varargin)
            %fprintf('ScopeModel.didSetAnalogChannelUnitsOrScales():\n');
            display=self.Parent;
            wavesurferModel=display.Parent;
            acquisition=wavesurferModel.Acquisition;            
            firstChannelName=self.ChannelNames{1};
            iFirstChannel=acquisition.iAnalogChannelFromName(firstChannelName);
            if isfinite(iFirstChannel) ,
                newChannelUnits=acquisition.AnalogChannelUnits(iFirstChannel);  
                newScale=acquisition.AnalogChannelScales(iFirstChannel);  % V/newChannelUnits
                %yLimitsAtADCBeforeChange=(self.YScale)*self.YLim;  % V
                %newYLimits=(1/newScale)*yLimitsAtADCBeforeChange;
                %self.YLim=newYLimits;  % Decided we don't want to do this
                                        % anymore---just leave the y limits in the scope alone
                self.YUnits=newChannelUnits;  % convert from a scale factor to the native units
                self.YScale=newScale;
            end
            self.broadcast('DidSetChannelUnits');
        end
        
%         function xMinAndMax=dataXMinAndMax(self)
%             xMin=+inf;
%             xMax=-inf;
%             for iChannel = 1:self.NChannels
%                 xMin=min(xMin,min(self.XData{iChannel}));
%                 xMax=max(xMax,max(self.XData{iChannel}));
%             end
%             xMinAndMax=[xMin xMax];            
%         end
        
        function yMinAndMax=dataYMinAndMax(self)
            % Min and max of the data, across all plotted channels.
            % Returns a 1x2 array.
            % If all channels are empty, returns [+inf -inf].
            import ws.utility.*
            yMin=+inf;
            yMax=-inf;
            for iChannel = 1:self.NChannels
                thisMin=min(self.YData{iChannel});
                yMin=fif(isempty(thisMin),yMin,min(yMin,thisMin));
                thisMax=max(self.YData{iChannel});
                yMax=fif(isempty(thisMax),yMax,max(yMax,thisMax));
            end
            yMinAndMax=double([yMin yMax]);
        end

%         function xMax=dataXMax(self)
%             % Max of the data x coord, across all plotted channels.
%             % Returns a scalar
%             % If all channels are empty, returns -inf.
%             xMax=-inf;
%             for iChannel = 1:self.NChannels
%                 thisMax=self.XData{iChannel}(end);
%                 xMax=fif(isempty(thisMax),xMax,max(xMax,thisMax));
%             end
%         end
        
        function setYAxisLimitsTightToData(self)
            yMinAndMax=self.dataYMinAndMax();
            if any(~isfinite(yMinAndMax)) ,
                return
            end
            yCenter=mean(yMinAndMax);
            yRadius=0.5*diff(yMinAndMax);
            if yRadius==0 ,
                yRadius=0.001;
            end
            self.YLim=yCenter+1.05*yRadius*[-1 +1];
        end  % function
    end  % methods
    
    methods (Access = protected)        
%         function defineDefaultPropertyTags(self)
%             defineDefaultPropertyTags@ws.system.Subsystem(self);            
%             self.setPropertyTags('XOffset', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('XSpan', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('YLim', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('Tag', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('Title', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('ChannelNames', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('ChannelColorIndex', 'IncludeInFileTypes', {'cfg'});
%         end
    end  % methods (Access = protected)
    
    methods (Access = protected)
        function setYAxisLimitsTightToDataIfAreYLimitsLockedTightToData_(self)
            if self.AreYLimitsLockedTightToData,
                self.setYAxisLimitsTightToData();
            end
        end  % function

%         function updateXLim(self)
%             if self.XAutoScroll,
%                 xMax=self.dataXMax();
%                 if ~isfinite(xMax) ,
%                     return
%                 end
%                 xMaxNudged=ceil(100*(xMax/self.XSpan))/100;  % Helps keep the axes aligned to tidy numbers
%                 if xMaxNudged>self.XLim(2) ,
%                     self.XOffset=xMaxNudged-self.XSpan;                    
%                 end
%             end
%         end  % function
    end  % protected methods
    
    methods
        function toggleAreYLimitsLockedTightToData(self)
            self.AreYLimitsLockedTightToData = ~self.AreYLimitsLockedTightToData;
        end
    end

    methods (Access=protected)        
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods (Access=protected)        
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.Model(self);
            self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('CanEnable', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('Enabled', 'IncludeInFileTypes', {'cfg'}, 'ExcludeFromFileTypes', {'usr'});            
%             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'*'});            
        end
    end    
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.ScopeModel.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();
            s.Parent = struct('Classes', 'ws.system.Display', 'AllowEmpty', true);
        end  % function
    end  % class methods block

end
