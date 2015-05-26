classdef TriggersFigure < ws.MCOSFigure & ws.EventSubscriber
    properties
        TrialBasedAcquisitionPanel
        UseASAPTriggeringCheckbox
        TrialBasedAcquisitionSchemeText
        TrialBasedAcquisitionSchemePopupmenu
        
        TrialBasedStimulationPanel
        UseAcquisitionTriggerCheckbox
        TrialBasedStimulationSchemeText
        TrialBasedStimulationSchemePopupmenu
        
%         ContinuousPanel
%         ContinuousSchemeText
%         ContinuousSchemePopupmenu
        
        TriggerSourcesPanel
        TriggerSourcesTable
        
        TriggerDestinationsPanel
        TriggerDestinationsTable
    end  % properties
    
    methods
        function self=TriggersFigure(model,controller)
            self = self@ws.MCOSFigure(model,controller);            
            set(self.FigureGH, ...
                'Tag','triggersFigureWrapper', ...
                'Units','Pixels', ...
                'Color',get(0,'defaultUIControlBackgroundColor'), ...
                'Resize','off', ...
                'Name','Triggers', ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off', ...
                'CloseRequestFcn',@(source,event)(self.closeRequested(source,event)));
               % CloseRequestFcn will get overwritten by the ws.most.Controller constructor, but
               % we re-set it in the ws.TriggersController
               % constructor.
           
           % Create the fixed controls (which for this figure is all of them)
           self.createFixedControls_();          

           % Set up the tags of the HG objects to match the property names
           self.setNonidiomaticProperties_();
           
           % Layout the figure and set the position
           self.layout_();
           ws.utility.positionFigureOnRootRelativeToUpperLeftBang(self.FigureGH,[30 30+40]);
           
           % Initialize the guidata
           self.updateGuidata_();
           
           % Sync to the model
           self.update();
           
%            % Make the figure visible
%            set(self.FigureGH,'Visible','on');
        end  % constructor
    end
    
    methods (Access=protected)
        function didSetModel_(self)
            self.updateSubscriptionsToModelEvents_();
            didSetModel_@ws.MCOSFigure(self);
        end
    end
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            % Trial-based Acquisition Panel
            self.TrialBasedAcquisitionPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Acquisition');
            self.UseASAPTriggeringCheckbox = ...
                uicontrol('Parent',self.TrialBasedAcquisitionPanel, ...
                          'Style','checkbox', ...
                          'String','Use ASAP triggering');
            self.TrialBasedAcquisitionSchemeText = ...
                uicontrol('Parent',self.TrialBasedAcquisitionPanel, ...
                          'Style','text', ...
                          'String','Scheme:');
            self.TrialBasedAcquisitionSchemePopupmenu = ...
                uicontrol('Parent',self.TrialBasedAcquisitionPanel, ...
                          'Style','popupmenu', ...
                          'String',{'Thing 1';'Thing 2'});
                          
            % Trial-based Stimulation Panel
            self.TrialBasedStimulationPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Stimulation');
            self.UseAcquisitionTriggerCheckbox = ...
                uicontrol('Parent',self.TrialBasedStimulationPanel, ...
                          'Style','checkbox', ...
                          'String','Use acquisition scheme');
            self.TrialBasedStimulationSchemeText = ...
                uicontrol('Parent',self.TrialBasedStimulationPanel, ...
                          'Style','text', ...
                          'String','Scheme:');
            self.TrialBasedStimulationSchemePopupmenu = ...
                uicontrol('Parent',self.TrialBasedStimulationPanel, ...
                          'Style','popupmenu', ...
                          'String',{'Thing 1';'Thing 2'});

%             % Continuous Acqusition+Stimulation Panel
%             self.ContinuousPanel = ...
%                 uipanel('Parent',self.FigureGH, ...
%                         'Units','pixels', ...
%                         'BorderType','none', ...
%                         'FontWeight','bold', ...
%                         'Title','Continuous Acquisition+Stimulation');
%             self.ContinuousSchemeText = ...
%                 uicontrol('Parent',self.ContinuousPanel, ...
%                           'Style','text', ...
%                           'String','Scheme:');
%             self.ContinuousSchemePopupmenu = ...
%                 uicontrol('Parent',self.ContinuousPanel, ...
%                           'Style','popupmenu', ...
%                           'String',{'Thing 1';'Thing 2'});

            % Trigger Sources Panel
            self.TriggerSourcesPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Internal Trigger Schemes');
            self.TriggerSourcesTable = ...
                uitable('Parent',self.TriggerSourcesPanel, ...
                        'ColumnName',{'Name' 'Device' 'CTR' 'Repeats' 'Interval (s)' 'PFI' 'Edge'}, ...
                        'ColumnFormat',{'char' 'char' 'numeric' 'numeric' 'numeric' 'numeric' {'Rising' 'Falling'}}, ...
                        'ColumnEditable',[false false false true true false false]);
            
            % Trigger Destinations Panel
            self.TriggerDestinationsPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','External Trigger Schemes');
            self.TriggerDestinationsTable = ...
                uitable('Parent',self.TriggerDestinationsPanel, ...
                        'ColumnName',{'Name' 'Device' 'PFI' 'Edge'}, ...
                        'ColumnFormat',{'char' 'char' 'numeric' {'Rising' 'Falling'}}, ...
                        'ColumnEditable',[false false false false]);
        end  % function
    end  % singleton methods block
    
    methods (Access = protected)
        function setNonidiomaticProperties_(self)
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
                    
                    % Set Callback
                    if isequal(get(propertyThing,'Type'),'uimenu') ,
                        if get(propertyThing,'Parent')==self.FigureGH ,
                            % do nothing for top-level menus
                        else
                            set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                        end
                    elseif ( isequal(get(propertyThing,'Type'),'uicontrol') && ~isequal(get(propertyThing,'Style'),'text') ) ,
                        set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                    elseif isequal(get(propertyThing,'Type'),'uitable') 
                        set(propertyThing,'CellEditCallback',@(source,event)(self.controlActuated(propertyName,source,event)));                        
                    end
                    
                    % Set Font
                    if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') ,
                        set(propertyThing,'FontName','Tahoma');
                        set(propertyThing,'FontSize',8);
                    end
                    
                    % Set Units
                    if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') ,
                        set(propertyThing,'Units','pixels');
                    end
                    
%                     % Set border type
%                     if isequal(get(propertyThing,'Type'),'uipanel') ,
%                         set(propertyThing,'BorderType','none', ...
%                                           'FontWeight','bold');
%                     end
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function figureSize=layoutFixedControls_(self)
            % We return the figure size so that the figure can be properly
            % resized after the initial layout, and we can keep all the
            % layout info in one place.
            
            import ws.utility.positionEditLabelAndUnitsBang
            
            topPadHeight=10;
            schemesAreaWidth=280;
            tablePanelsAreaWidth=500;
            tablePanelAreaHeight=210;
            heightBetweenTableAreas=6;

            figureWidth=schemesAreaWidth+tablePanelsAreaWidth;
            figureHeight=tablePanelAreaHeight+heightBetweenTableAreas+tablePanelAreaHeight+topPadHeight;

            trialBasedAcquisitionPanelAreaHeight=78;
            trialBasedStimulationPanelAreaHeight=78;
            continuousPanelAreaHeight=56;
            spaceBetweenPanelsHeight=30;
            
            
            %
            % The schemes area containing the trial-based acq, trial-based
            % stim, and continuous panels, arranged in a column
            %
            panelInset=3;  % panel dimensions are defined by the panel area, then inset by this amount on all sides
            
            % The Trial-based Acquisition panel
            trialBasedAcquisitionPanelXOffset=panelInset;
            trialBasedAcquisitionPanelWidth=schemesAreaWidth-panelInset-panelInset;
            trialBasedAcquisitionPanelAreaYOffset=figureHeight-topPadHeight-trialBasedAcquisitionPanelAreaHeight;
            trialBasedAcquisitionPanelYOffset=trialBasedAcquisitionPanelAreaYOffset+panelInset;            
            trialBasedAcquisitionPanelHeight=trialBasedAcquisitionPanelAreaHeight-panelInset-panelInset;
            set(self.TrialBasedAcquisitionPanel, ...
                'Position',[trialBasedAcquisitionPanelXOffset trialBasedAcquisitionPanelYOffset ...
                            trialBasedAcquisitionPanelWidth trialBasedAcquisitionPanelHeight]);

            % The Trial-based Stimulation panel
            trialBasedStimulationPanelXOffset=panelInset;
            trialBasedStimulationPanelWidth=schemesAreaWidth-panelInset-panelInset;
            trialBasedStimulationPanelAreaYOffset=trialBasedAcquisitionPanelAreaYOffset-trialBasedStimulationPanelAreaHeight-spaceBetweenPanelsHeight;
            trialBasedStimulationPanelYOffset=trialBasedStimulationPanelAreaYOffset+panelInset;            
            trialBasedStimulationPanelHeight=trialBasedStimulationPanelAreaHeight-panelInset-panelInset;
            set(self.TrialBasedStimulationPanel, ...
                'Position',[trialBasedStimulationPanelXOffset trialBasedStimulationPanelYOffset ...
                            trialBasedStimulationPanelWidth trialBasedStimulationPanelHeight]);

            % The Continuous Acquisition+Stimulation panel
            continuousPanelXOffset=panelInset;
            continuousPanelWidth=schemesAreaWidth-panelInset-panelInset;
            continuousPanelAreaYOffset=trialBasedStimulationPanelAreaYOffset-continuousPanelAreaHeight-spaceBetweenPanelsHeight;
            continuousPanelYOffset=continuousPanelAreaYOffset+panelInset;            
            continuousPanelHeight=continuousPanelAreaHeight-panelInset-panelInset;
%             set(self.ContinuousPanel, ...
%                 'Position',[continuousPanelXOffset continuousPanelYOffset ...
%                             continuousPanelWidth continuousPanelHeight]);

            % The Trigger Sources panel
            tablesAreaXOffset=schemesAreaWidth;
            triggerSourcesPanelXOffset=tablesAreaXOffset+panelInset;
            triggerSourcesPanelWidth=tablePanelsAreaWidth-panelInset-panelInset;
            triggerSourcesPanelAreaYOffset=tablePanelAreaHeight+heightBetweenTableAreas;
            triggerSourcesPanelYOffset=triggerSourcesPanelAreaYOffset+panelInset;            
            triggerSourcesPanelHeight=tablePanelAreaHeight-panelInset-panelInset;
            set(self.TriggerSourcesPanel, ...
                'Position',[triggerSourcesPanelXOffset triggerSourcesPanelYOffset ...
                            triggerSourcesPanelWidth triggerSourcesPanelHeight]);
            
            % The Trigger Destinations panel
            triggerDestinationsPanelXOffset=tablesAreaXOffset+panelInset;
            triggerDestinationsPanelWidth=tablePanelsAreaWidth-panelInset-panelInset;
            triggerDestinationsPanelAreaYOffset=0;
            triggerDestinationsPanelYOffset=triggerDestinationsPanelAreaYOffset+panelInset;            
            triggerDestinationsPanelHeight=tablePanelAreaHeight-panelInset-panelInset;
            set(self.TriggerDestinationsPanel, ...
                'Position',[triggerDestinationsPanelXOffset triggerDestinationsPanelYOffset ...
                            triggerDestinationsPanelWidth triggerDestinationsPanelHeight]);

            % Contents of panels
            self.layoutTrialBasedAcquisitionPanel_(trialBasedAcquisitionPanelWidth,trialBasedAcquisitionPanelHeight);
            self.layoutTrialBasedStimulationPanel_(trialBasedStimulationPanelWidth,trialBasedStimulationPanelHeight);
            %self.layoutContinuousPanel_(continuousPanelWidth,continuousPanelHeight);
            self.layoutTriggerSourcesPanel_(triggerSourcesPanelWidth,triggerSourcesPanelHeight);
            self.layoutTriggerDestinationsPanel_(triggerDestinationsPanelWidth,triggerDestinationsPanelHeight);
                        
            % We return the figure size
            figureSize=[figureWidth figureHeight];
        end  % function
    end
    
    methods (Access = protected)
        function layoutTrialBasedAcquisitionPanel_(self,panelWidth,panelHeight)  %#ok<INUSL>
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang

            % Dimensions
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToPopupmenu=6;
            heightFromPopupmenuToRest=4;
            rulerXOffset=60;
            popupmenuWidth=200;
            
            % Source popupmenu
            position=get(self.TrialBasedAcquisitionSchemePopupmenu,'Position');
            height=position(4);
            popupmenuYOffset=panelHeight-heightOfPanelTitle-heightFromTopToPopupmenu-height;  %checkboxYOffset-heightFromPopupmenuToRest-height;
            positionPopupmenuAndLabelBang(self.TrialBasedAcquisitionSchemeText,self.TrialBasedAcquisitionSchemePopupmenu, ...
                                          rulerXOffset,popupmenuYOffset,popupmenuWidth)            

            % Checkbox
            checkboxFullExtent=get(self.UseASAPTriggeringCheckbox,'Extent');
            checkboxExtent=checkboxFullExtent(3:4);
            checkboxPosition=get(self.UseASAPTriggeringCheckbox,'Position');
            checkboxXOffset=rulerXOffset;
            checkboxWidth=checkboxExtent(1)+16;  % size of the checkbox itself
            checkboxHeight=checkboxPosition(4);
            checkboxYOffset=popupmenuYOffset-heightFromPopupmenuToRest-checkboxHeight;  % panelHeight-heightOfPanelTitle-heightFromTopToPopupmenu-checkboxHeight;            
            set(self.UseASAPTriggeringCheckbox, ...
                'Position',[checkboxXOffset checkboxYOffset ...
                            checkboxWidth checkboxHeight]);            
        end  % function
    end

    methods (Access = protected)
        function layoutTrialBasedStimulationPanel_(self,panelWidth,panelHeight)  %#ok<INUSL>
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang

            % Dimensions
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToCheckbox=2;
            heightFromCheckboxToRest=4;
            rulerXOffset=60;
            popupmenuWidth=200;
            
            % Checkbox
            checkboxFullExtent=get(self.UseAcquisitionTriggerCheckbox,'Extent');
            checkboxExtent=checkboxFullExtent(3:4);
            checkboxPosition=get(self.UseAcquisitionTriggerCheckbox,'Position');
            checkboxXOffset=rulerXOffset;
            checkboxWidth=checkboxExtent(1)+16;  % size of the checkbox itself
            checkboxHeight=checkboxPosition(4);
            checkboxYOffset=panelHeight-heightOfPanelTitle-heightFromTopToCheckbox-checkboxHeight;            
            set(self.UseAcquisitionTriggerCheckbox, ...
                'Position',[checkboxXOffset checkboxYOffset ...
                            checkboxWidth checkboxHeight]);
            
            % Source popupmenu
            position=get(self.TrialBasedStimulationSchemePopupmenu,'Position');
            height=position(4);
            popupmenuYOffset=checkboxYOffset-heightFromCheckboxToRest-height;
            positionPopupmenuAndLabelBang(self.TrialBasedStimulationSchemeText,self.TrialBasedStimulationSchemePopupmenu, ...
                                          rulerXOffset,popupmenuYOffset,popupmenuWidth)            
        end  % function
    end

    methods (Access = protected)
%         function layoutContinuousPanel_(self,panelWidth,panelHeight) %#ok<INUSL>
%             import ws.utility.positionEditLabelAndUnitsBang
%             import ws.utility.positionPopupmenuAndLabelBang
% 
%             % Dimensions
%             heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
%             heightFromTopToRest=6;
%             rulerXOffset=60;
%             popupmenuWidth=200;
%             
%             % Source popupmenu
%             position=get(self.ContinuousSchemePopupmenu,'Position');
%             height=position(4);
%             popupmenuYOffset=panelHeight-heightOfPanelTitle-heightFromTopToRest-height;
%             positionPopupmenuAndLabelBang(self.ContinuousSchemeText,self.ContinuousSchemePopupmenu, ...
%                                           rulerXOffset,popupmenuYOffset,popupmenuWidth)            
%         end
    end
    
    methods (Access = protected)
        function layoutTriggerSourcesPanel_(self,panelWidth,panelHeight)
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title

            leftPad=10;
            rightPad=10;
            bottomPad=10;
            topPad=2;
            
            tableWidth=panelWidth-leftPad-rightPad;
            tableHeight=panelHeight-heightOfPanelTitle-bottomPad-topPad;
            
            % The table cols have fixed width except Name, which takes up
            % the slack.
            deviceWidth=50;
            ctrWidth=40;            
            repeatsWidth=60;
            intervalWidth=66;
            pfiWidth=40;
            edgeWidth=50;
            nameWidth=tableWidth-(deviceWidth+ctrWidth+repeatsWidth+intervalWidth+pfiWidth+edgeWidth+34);  % 30 for the row titles col
            
            % 'Name' 'CTR' 'Repeats' 'Interval (s)' 'PFI' 'Edge'
            set(self.TriggerSourcesTable, ...
                'Position', [leftPad bottomPad tableWidth tableHeight], ...
                'ColumnWidth', {nameWidth deviceWidth ctrWidth repeatsWidth intervalWidth pfiWidth edgeWidth});
        end
    end
    
    methods (Access = protected)
        function layoutTriggerDestinationsPanel_(self,panelWidth,panelHeight)
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title

            leftPad=10;
            rightPad=10;
            bottomPad=10;
            topPad=2;
            
            tableWidth=panelWidth-leftPad-rightPad;
            tableHeight=panelHeight-heightOfPanelTitle-bottomPad-topPad;
            
            % The table cols have fixed width except Name, which takes up
            % the slack.
            deviceWidth=50;
            pfiWidth=40;
            edgeWidth=50;
            nameWidth=tableWidth-(deviceWidth+pfiWidth+edgeWidth+34);  % 34 for the row titles col
                        
            % 'Name' 'PFI' 'Edge'
            set(self.TriggerDestinationsTable, ...
                'Position', [leftPad bottomPad tableWidth tableHeight], ...
                'ColumnWidth', {nameWidth deviceWidth pfiWidth edgeWidth});
        end
    end
    
    methods
        function delete(self) %#ok<INUSD>
%             if ishghandle(self.FigureGH) ,
%                 delete(self.FigureGH);
%             end
        end  % function       
    end  % methods    

%     methods
%         function controlActuated(self,controlName,source,event)
%             if isempty(self.Controller) ,
%                 % do nothing
%             else
%                 self.Controller.controlActuated(controlName,source,event);
%                 %self.Controller.updateModel(source,event,guidata(self.FigureGH));
%             end
%         end  % function       
%     end  % methods

    methods (Access=protected)
        function updateControlPropertiesImplementation_(self,varargin)
            if isempty(self.Model) ,
                return
            end            
            self.updateTrialBasedAcquisitionControls();
            self.updateTrialBasedStimulationControls();
            %self.updateContinuousModeControls();
            self.updateTriggerSourcesTable();
            self.updateTriggerDestinationsTable();                   
        end  % function
    end  % methods
    
    methods (Access=protected)
        function updateControlEnablementImplementation_(self)
            triggeringModel=self.Model;
            if isempty(triggeringModel) || ~isvalid(triggeringModel) ,
                return
            end            
            wsModel=triggeringModel.Parent;  % this is the WavesurferModel
            isIdle=(wsModel.State==ws.ApplicationState.Idle);
            isTrialBased = wsModel.IsTrialBased;
            
            import ws.utility.onIff
            
            set(self.TrialBasedAcquisitionSchemePopupmenu,'Enable',onIff(isIdle));
            
            acquisitionUsesASAPTriggering=triggeringModel.AcquisitionUsesASAPTriggering;
            isStimulusUsingAcquisitionTriggerScheme=triggeringModel.StimulationUsesAcquisitionTriggerScheme;
            isAcquisitionSchemeInternal=triggeringModel.AcquisitionTriggerScheme.IsInternal;
            set(self.UseASAPTriggeringCheckbox,'Enable',onIff(isIdle&&isTrialBased&&isAcquisitionSchemeInternal));
            set(self.UseAcquisitionTriggerCheckbox,'Enable',onIff(isIdle&&~acquisitionUsesASAPTriggering));
            set(self.TrialBasedStimulationSchemePopupmenu,'Enable',onIff(isIdle&&~isStimulusUsingAcquisitionTriggerScheme));
            
            %set(self.ContinuousSchemePopupmenu,'Enable',onIff(isIdle));
            
            set(self.TriggerSourcesTable,'Enable',onIff(isIdle));
            set(self.TriggerDestinationsTable,'Enable',onIff(isIdle));
        end  % function
    end
    
    methods
        function updateTrialBasedAcquisitionControls(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            import ws.utility.setPopupMenuItemsAndSelectionBang
            import ws.utility.onIff
            set(self.UseASAPTriggeringCheckbox,'Value',model.AcquisitionUsesASAPTriggering);
            rawMenuItems={model.Sources.Name model.Destinations.Name};
            rawCurrentItem=model.AcquisitionTriggerScheme.Target.Name;
            setPopupMenuItemsAndSelectionBang(self.TrialBasedAcquisitionSchemePopupmenu, ...
                                              rawMenuItems, ...
                                              rawCurrentItem);
        end  % function       
    end  % methods
    
    methods
        function updateTrialBasedStimulationControls(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            import ws.utility.setPopupMenuItemsAndSelectionBang
            import ws.utility.onIff
            set(self.UseAcquisitionTriggerCheckbox,'Value',model.StimulationUsesAcquisitionTriggerScheme);
            rawMenuItems={model.Sources.Name model.Destinations.Name};
            rawCurrentItem=model.StimulationTriggerScheme.Target.Name;
            setPopupMenuItemsAndSelectionBang(self.TrialBasedStimulationSchemePopupmenu, ...
                                              rawMenuItems, ...
                                              rawCurrentItem);
        end  % function       
    end  % methods
    
    methods
%         function updateContinuousModeControls(self,varargin)
%             model=self.Model;
%             if isempty(model) ,
%                 return
%             end
%             import ws.utility.setPopupMenuItemsAndSelectionBang
%             import ws.utility.onIff
%             rawMenuItems={model.Sources.Name};
%             rawCurrentItem=model.ContinuousModeTriggerScheme.Target.Name;
%             setPopupMenuItemsAndSelectionBang(self.ContinuousSchemePopupmenu, ...
%                                               rawMenuItems, ...
%                                               rawCurrentItem);
%         end  % function       
    end  % methods

    methods
        function updateTriggerSourcesTable(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            nRows=length(model.Sources);
            nColumns=7;
            data=cell(nRows,nColumns);
            for i=1:nRows ,
                source=model.Sources(i);
                data{i,1}=source.Name;
                data{i,2}=source.DeviceName;
                data{i,3}=source.CounterID;
                data{i,4}=source.RepeatCount;
                data{i,5}=source.Interval;
                data{i,6}=source.PFIID;
                data{i,7}=char(source.Edge);
            end
            set(self.TriggerSourcesTable,'Data',data);
        end  % function
    end  % methods
    
    methods
        function updateTriggerDestinationsTable(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            nRows=length(model.Destinations);
            nColumns=4;
            data=cell(nRows,nColumns);
            for i=1:nRows ,
                destination=model.Destinations(i);
                data{i,1}=destination.Name;
                data{i,2}=destination.DeviceName;
                data{i,3}=destination.PFIID;
                data{i,4}=char(destination.Edge);
            end
            set(self.TriggerDestinationsTable,'Data',data);
        end  % function
    end  % methods
    
    methods (Access=protected)
        function updateSubscriptionsToModelEvents_(self)
            % Unsubscribe from all events, then subsribe to all the
            % approprate events of model.  model should be a Triggering subsystem
            %self.unsubscribeFromAll();
            model=self.Model;
            if ~isempty(model) && isvalid(model) ,
                % Sources and Destinations setters did nothing, and those
                % are set in the MDF file, so don't think these are needed
%                 model.subscribeMe(self, 'PostSet', 'Sources', 'updateTriggerSourcesTable');
%                 model.subscribeMe(self, 'PostSet', 'Sources', 'updateSupscriptionsToSourceProperties_');
%                 model.subscribeMe(self, 'PostSet', 'Destinations', 'updateTriggerDestinationsTable');
                

%                 model.AcquisitionTriggerScheme.subscribeMe(self,'PostSet','Target','updateTrialBasedAcquisitionControls');  
%                 model.StimulationTriggerScheme.subscribeMe(self,'PostSet','Target','updateTrialBasedStimulationControls');  
%                 model.ContinuousModeTriggerScheme.subscribeMe(self,'PostSet','Target','updateContinuousModeControls');  
                model.AcquisitionTriggerScheme.subscribeMe(self,'DidSetTarget','','updateTrialBasedAcquisitionControls');
                model.StimulationTriggerScheme.subscribeMe(self,'DidSetTarget','','updateTrialBasedStimulationControls');  
                %model.ContinuousModeTriggerScheme.subscribeMe(self,'DidSetTarget','','updateContinuousModeControls');  

                % Add subscriptions for updating control enablement
                model.Parent.subscribeMe(self,'DidSetState','','updateControlEnablement');
                model.Parent.subscribeMe(self,'DidSetIsTrialBasedContinuous','','update');
%                 model.subscribeMe(self,'PostSet','AcquisitionUsesASAPTriggering','update');
%                 model.subscribeMe(self,'PostSet','StimulationUsesAcquisitionTriggerScheme','update');
                model.subscribeMe(self,'Update','','update');
                model.AcquisitionTriggerScheme.subscribeMe(self,'DidSetIsInternal','','updateControlEnablement');  
                model.StimulationTriggerScheme.subscribeMe(self,'DidSetIsInternal','','updateControlEnablement');  

                % Add subscriptions for the changeable fields of each element
                % of model.Sources
                self.updateSubscriptionsToSourceProperties_();
            end
        end
        
        function updateSubscriptionsToSourceProperties_(self,varargin)
            % Add subscriptions for the changeable fields of each source
            model=self.Model;
            sources = model.Sources;            
            for i = 1:length(sources) ,
                source=sources(i);
                source.unsubscribeMeFromAll(self);
                %source.subscribeMe(self, 'PostSet', 'Interval', 'updateTriggerSourcesTable');
                %source.subscribeMe(self, 'PostSet', 'RepeatCount', 'updateTriggerSourcesTable');
                source.subscribeMe(self, 'Update', '', 'updateTriggerSourcesTable');
            end
        end
    end
    
end  % classdef
