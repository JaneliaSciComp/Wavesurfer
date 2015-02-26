classdef ScopeModel < ws.Model % & ws.EventBroadcaster 
    properties (Constant=true)
        BackgroundColor = [0 0 0];
        ForegroundColor = [.15 .9 .15];
        FontSize = 10;
        FontWeight = 'normal';
        LineStyle = '-';
        Marker = 'none';
        GridOn = true;
    end
    
    properties (SetAccess=protected, Transient=true)
        Parent  % the parent Display object
    end
    
    properties (Dependent=true)  %(SetObservable = true)
        XUnits
        YUnits
        YScale   % implicitly in units of V/YUnits (need this to keep the YLim fixed in terms of volts at the ADC when the channel units/scale changes
        %YAutoScale
    end

    properties (Access = protected)
        XUnits_ = ws.utility.SIUnit('s')
        YUnits_ = ws.utility.SIUnit('V')
        YScale_ = 1   % implicitly in units of V/YUnits (need this to keep the YLim fixed in terms of volts at the ADC when the channel units/scale changes
        %YAutoScale_ = false
    end
    
    properties (SetAccess = protected)  % SetObservable = true)
        Tag = '';  % This should be a unique tag that identifies this ScopeModel.
                   % This is used as the Tag for any ScopeFigure that uses
                   % this ScopeModel as its model, and should be usable as
                   % a field name in a structure, for saving/loading
                   % purposes.
        Title = '';  % This is the window title used by any ScopeFigures that use this
                     % ScopeModel as their Model.
    end
    
    properties (Dependent=true) %, AbortSet=true, SetObservable=true)
        XOffset  % the x coord shown at the leftmost edge of the plot
        XSpan  % the difference between the xcoord shown at the rightmost edge of the plot and XOffset
        XLim
        YLim
    end

%     properties %(AbortSet=true, SetObservable=true)
%         YLim = [-10 +10]
%     end
    
    properties (Access=protected)
        XOffset_ = 0
        XSpan_ = 1
        YLim_ = [-10 +10]
    end
    
    properties (SetAccess = protected)
        ChannelNames = cell(1,0);  % row vector, the AI indices shown in this Scope
        ChannelColorIndex=zeros(1,0);
        %Lines = zeros(1,0);  % row vector, the line graphics handles for each channel
        
        %displayOptions;
        %HeldLines;
        
        %Figure;  % HG handle to figure
        %Axes;  % HG handle to axes
        %chanLines = struct('ChannelName', {}, 'LineHandle', {}, 'XDataLim', {}); % Structure of line handle objects.
        
        %HorizontalCenterLine;  % HG handle to line
        %VerticalCenterLine;  % HG handle to line
        %GroundLine;  % HG handle to line
    end
    
    properties (Transient=true, Dependent=true)
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
        BufferFactor = 1;
        RunningMin = zeros(1,0);  % length == self.NChannels
        RunningMax = zeros(1,0);
        RunningMean = zeros(1,0);
        %XDataLims = zeros(2,0);  % each col the min and max x value for that line
        %  % Invariant: size(XDataLims,2)==self.NChannels
        %  % The x limits for channel i are in XDataLims(:,i)
        %YLimAtADCBeforeChange;  
          % this is a cache, used to keep the y range constant in volts at
          % the ADC when the scale changes.
        IsVisibleWhenDisplayEnabled_
    end
    
    properties (SetAccess = protected, Transient=true)
        XData  % a double array, holding x data for each channel
        YData=cell(1,0)  % a 1 x self.NChannels cell array, holding y data for each channel
          % Invariant: For all i,j length(YData{i})==length(YData{j})
    end
    
    properties (SetAccess=immutable, Dependent=true)
        NChannels
    end
    
    events
        %AxisLimitSet
        %YAutoScaleWasSet
        %XAutoScrollWasSet
        ChannelAdded
        DataAdded
        DataCleared
        DidSetChannelUnits
        WindowVisibilityNeedsToBeUpdated
        %WavesurferScopeMenuNeedsToBeUpdated
        %Update
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
%             if ~isempty(self.WavesurferModel) && isvalid(self.WavesurferModel) ,
%                 self.WavesurferModel.Acquisition.unsubscribeMe(self,'DidSetChannelUnitsOrScales','','didSetChannelUnitsOrScales');
%             end
            self.Parent=newValue;
            % Sometimes we want to set WavesurferModel to []
%             if ~isempty(newValue)
%                 self.WavesurferModel.Acquisition.subscribeMe(self,'DidSetChannelUnitsOrScales','','didSetChannelUnitsOrScales');
%             end
        end
        
%         function set.YAutoScale(self,newValue)
%             if islogical(newValue) && isscalar(newValue) ,
%                 self.YAutoScale=newValue;
%             end
%             self.updateYLim();
%             self.broadcast('YAutoScaleWasSet');
%         end
        
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
            self.broadcast('Update');
        end
        
        function value=get.XLim(self)
            value = self.XOffset+[0 self.XSpan];
        end
        
        function set.XLim(self, newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
                self.XOffset=newValue(1);
                self.XSpan=newValue(2)-newValue(1);
            end
        end
        
        function set.YLim(self,newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2) ,
                self.YLim_ = newValue;
            end
            self.broadcast('Update');
        end
        
        function value=get.YLim(self)
            value=self.YLim_;
        end
        
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
                    self.Tag=newValue;
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
            self.ChannelNames{iNewChannel} = newChannelName;
            %self.yUnits(end+1) = units;
            
            colorOrderIndex = iNewChannel;
            self.ChannelColorIndex(iNewChannel)=colorOrderIndex;  % store value to colors don't change
            
            %colorOrder = get(self.Axes ,'ColorOrder');
            %color = colorOrder(colorOrderIndex, :);
            
            %self.ChannelNames(end + 1).ChannelName = newChannelID;
            %self.XDataLims(:,iNewChannel) = [0 0]';
            %self.XData{iNewChannel}=zeros(0,1);  % col vector
            self.YData{iNewChannel}=zeros(0,1);  % col vector            
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
            
            self.RunningMin(iNewChannel) = 0;
            self.RunningMax(iNewChannel) = 0;
            self.RunningMean(iNewChannel) = 0;
            
            % If this is the first channel added, pretend the channel units
            % were just set from 1 V/V to something else, to trigger an
            % appropriate change in YLim
            if (nChannelsOriginally==0)
                %self.YLimAtADCBeforeChange=self.YLim;
                self.didSetChannelUnitsOrScales();
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
            nDisplayableSamples = ceil(self.XSpan * sampleRate * self.BufferFactor);
            if length(xData) > nDisplayableSamples
                xData=xData(end-nDisplayableSamples+1:end);
            end
            % Commit the data
            self.XData=xData;
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
                self.YData{iChannel}=yData;
            end
            
            self.XOffset=newXOffset;
            %T(4)=toc(ticId);
            %self.updateYLim();
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
                self.XData=zeros(0,1);
                self.YData{idx}=zeros(0,1);
                
                %set(self.Lines(idx), {'XData' 'YData'}, {[] []});
                %self.XDataLims(:,idx) = [0; 0];
                
                self.RunningMin(idx) = 0;
                self.RunningMax(idx) = 0;
                self.RunningMean(idx) = 0;
            end
            
            %delete(self.HeldLines);
            %self.HeldLines = [];
            
            %self.updateScaling();
            self.broadcast('DataCleared');
        end
        
%         function eventHappened(self,publisher,eventName,propertyName,source,event)  %#ok
%             if isequal(eventName,'DidSetChannelUnitsOrScales')
%                 self.didSetChannelUnitsOrScales();
%             end
%         end
        
        function didSetChannelUnitsOrScales(self,varargin)
            %fprintf('ScopeModel.didSetChannelUnitsOrScales():\n');
            display=self.Parent;
            wavesurferModel=display.Parent;
            acquisition=wavesurferModel.Acquisition;            
            firstChannelName=self.ChannelNames{1};
            iFirstChannel=acquisition.iChannelFromName(firstChannelName);
            newChannelUnits=acquisition.ChannelUnits(iFirstChannel);  
            newScale=acquisition.ChannelScales(iFirstChannel);  % V/newChannelUnits
            yLimitsAtADCBeforeChange=(self.YScale)*self.YLim;  % V
            newYLimits=(1/newScale)*yLimitsAtADCBeforeChange;
            self.YLim=newYLimits;
            self.YUnits=newChannelUnits;  % convert from a scale factor to the native units
            self.YScale=newScale;
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
            yMinAndMax=[yMin yMax];
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
        
        function setYLimTightToData(self)
            yMinAndMax=self.dataYMinAndMax();
            if any(~isfinite(yMinAndMax)) ,
                return
            end
            yCenter=mean(yMinAndMax);
            yRadius=0.5*diff(yMinAndMax);
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
%         function updateYLim(self)
%             if self.YAutoScale,
%                 yMinAndMax=self.dataYMinAndMax();
%                 if any(~isfinite(yMinAndMax)) ,
%                     return
%                 end
%                 yCenter=mean(yMinAndMax);
%                 yRadius=0.5*diff(yMinAndMax);
%                 self.YLim=yCenter+1.05*yRadius*[-1 +1];
%             end
%         end  % function

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
        
    
%     methods (Access = protected)
%         function toggleYAutoScale(self, varargin)
%             self.YAutoScale = ~self.YAutoScale;
%             self.YAutoScale
%         end  % methods (Access = protected)
%     end

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
