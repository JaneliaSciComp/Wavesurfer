classdef FastProtocolsFigure < ws.MCOSFigure & ws.EventSubscriber
    properties
        Table        
        ClearRowButton
        SelectFileButton
    end  % properties
    
    methods
        function self=FastProtocolsFigure(model,controller)
            self = self@ws.MCOSFigure(model,controller);
            set(self.FigureGH, ...
                'Tag','fastProtocolsFigureWrapper', ...
                'Units','Pixels', ...
                'Color',get(0,'defaultUIControlBackgroundColor'), ...
                'Resize','off', ...
                'Name','Fast Protocols', ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off', ...
                'CloseRequestFcn',@(source,event)(self.closeRequested(source,event)));
               % CloseRequestFcn will get overwritten by the ws.most.Controller constructor, but
               % we re-set it in the ws.FastProtocolsController
               % constructor.
           
           % Create the fixed controls (which for this figure is all of them)
           self.createFixedControls_();          

           % Set up the tags of the HG objects to match the property names
           self.setNonidiomaticProperties_();
           
           % Layout the figure and set the size
           self.layout_();
           ws.utility.positionFigureOnRootRelativeToUpperLeftBang(self.FigureGH,[30 30+40]);
           
           % Initialize the guidata
           self.updateGuidata_();
           
           % Sync to the model
           self.update();
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
            
            self.Table = ...
                uitable('Parent',self.FigureGH, ...
                        'ColumnName',{'Protocol File' 'Action'}, ...
                        'ColumnFormat',{'char' {'Do Nothing' 'Play' 'Record'}}, ...
                        'ColumnEditable',[true true]);
            
            self.ClearRowButton = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'TooltipString','Clear the current row', ...
                          'String','Clear Row');

            self.SelectFileButton = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'TooltipString','Choose the protocol file for the current row', ...
                          'String','Select File...');
        end  % function
    end  % protected methods block
    
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
                        set(propertyThing,'CellSelectionCallback',@(source,event)(self.controlActuated(propertyName,source,event)));                        
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
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function figureSize=layoutFixedControls_(self)
            % We return the figure size so that the figure can be properly
            % resized after the initial layout, and we can keep all the
            % layout info in one place.
            
            topPadHeight=10;
            leftPadWidth=10;
            rightPadWidth=10;
            tableWidth=400;
            tableHeight=132;
            heightFromButtonRowToTable=6;
            buttonHeight=26;
            buttonWidth=80;
            widthBetweenButtons=10;
            bottomPadHeight=10;

            figureWidth=leftPadWidth+tableWidth+rightPadWidth;
            figureHeight=bottomPadHeight+buttonHeight+heightFromButtonRowToTable+tableHeight+topPadHeight;

            % The Table.
            % The table cols have fixed width except Name, which takes up
            % the slack.
            actionColumnWidth=80;
            protocolFileNameWidth=tableWidth-(actionColumnWidth+34);  % 30 for the row titles col            
            set(self.Table, ...
                'Position', [leftPadWidth bottomPadHeight+buttonHeight+heightFromButtonRowToTable tableWidth tableHeight], ...
                'ColumnWidth', {protocolFileNameWidth actionColumnWidth});

            % The button bar
            buttonBarYOffset=bottomPadHeight;
            buttonBarWidth=buttonWidth+widthBetweenButtons+buttonWidth;            
            buttonBarXOffset=leftPadWidth+tableWidth-buttonBarWidth;
            
            % The 'Clear Row' button
            set(self.ClearRowButton, ...
                'Position', [buttonBarXOffset buttonBarYOffset buttonWidth buttonHeight]);
            
            % The 'Select File...' button
            selectFileButtonXOffset=buttonBarXOffset+buttonWidth+widthBetweenButtons;
            set(self.SelectFileButton, ...
                'Position', [selectFileButtonXOffset buttonBarYOffset buttonWidth buttonHeight]);
                        
            % We return the figure size
            figureSize=[figureWidth figureHeight];
        end  % function
    end
    
    methods (Access=protected)
        function updateControlPropertiesImplementation_(self)
            model=self.Model;
            if isempty(model) ,
                return
            end
            self.updateTable_();
            %self.updateControlEnablementImplementation_();
        end  % function       
    end  % methods
        
    methods (Access=protected)
        function updateTable_(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            nRows=length(model.FastProtocols);
            nColumns=2;
            data=cell(nRows,nColumns);
            for i=1:nRows ,
                fastProtocol=model.FastProtocols(i);
                data{i,1}=fastProtocol.ProtocolFileName;
                data{i,2}=char(fastProtocol.AutoStartType);
            end
            set(self.Table,'Data',data);
        end  % function
    end  % methods
    
    methods (Access=protected)
        function updateControlEnablementImplementation_(self)
            wavesurferModel=self.Model;
            if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                return
            end            
            import ws.utility.onIff
            isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
            selectedIndex = wavesurferModel.IndexOfSelectedFastProtocol;
            isARowSelected= ~isempty(selectedIndex);

            set(self.ClearRowButton,'Enable',onIff(isIdle&&isARowSelected));
            set(self.SelectFileButton,'Enable',onIff(isIdle&&isARowSelected));
            set(self.Table,'Enable',onIff(isIdle))
        end  % function        
    end
    
    methods (Access=protected)
        function updateSubscriptionsToModelEvents_(self)
            % Unsubscribe from all events, then subsribe to all the
            % approprate events of model.  model should be a Triggering subsystem
            self.unsubscribeFromAll();
            
            model=self.Model;
            if isempty(model) ,
                return
            end

            fastProtocols = model.FastProtocols;            
            for i = 1:numel(fastProtocols) ,
                thisFastProtocol=fastProtocols(i);
                %thisFastProtocol.subscribeMe(self,'PostSet','ProtocolFileName','update');
                %thisFastProtocol.subscribeMe(self,'PostSet','AutoStartType','update');
                thisFastProtocol.subscribeMe(self,'Update','','update');
            end
                        
            model.subscribeMe(self,'DidSetState','','updateControlEnablement');
        end  % function                
    end
    
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

end  % classdef
