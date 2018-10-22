classdef FastProtocolsController < ws.Controller
    properties
        Table        
        ClearRowButton
        SelectFileButton
    end  % properties
    
    methods
        function self = FastProtocolsController(model)
            self = self@ws.Controller(model) ;
            
            set(self.FigureGH_, ...
                'Tag','FastProtocolsFigure', ...
                'Units','Pixels', ...
                'Resize','off', ...
                'Name','Fast Protocols', ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off');
           
           % Create the fixed controls (which for this figure is all of them)
           self.createFixedControls_();          

           % Set up the tags of the HG objects to match the property names
           self.setNonidiomaticProperties_();
           
           % Layout the figure and set the size
           self.layout_();
           ws.positionFigureOnRootRelativeToUpperLeftBang(self.FigureGH_,[30 30+40]);
           
           % Sync to the model
           self.update();
           
           % Subscribe to thangs
           if ~isempty(model) ,
               model.subscribeMe(self,'UpdateFastProtocols','','update');                        
               model.subscribeMe(self,'DidSetState','','updateControlEnablement');
               model.subscribeMe(self, 'DidSetSingleFigureVisibility', '', 'updateVisibility') ;
           end
           
           % Make visible
           %set(self.FigureGH_, 'Visible', 'on') ;
        end  % constructor
    end
        
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            self.Table = ...
                ws.uitable('Parent',self.FigureGH_, ...
                        'ColumnName',{'Protocol File' 'Action'}, ...
                        'ColumnFormat',{'char' {'Do Nothing' 'Play' 'Record'}}, ...
                        'ColumnEditable',[true true]);
            
            self.ClearRowButton = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'TooltipString','Clear the current row', ...
                          'String','Clear Row');

            self.SelectFileButton = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
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
                        if get(propertyThing,'Parent')==self.FigureGH_ ,
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
                    
%                     % Set Font
%                     if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') ,
%                         set(propertyThing,'FontName','Tahoma');
%                         set(propertyThing,'FontSize',8);
%                     end
%                     
%                     % Set Units
%                     if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') ,
%                         set(propertyThing,'Units','pixels');
%                     end                    
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function figureSize = layoutFixedControls_(self)
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
            model=self.Model_;
            if isempty(model) ,
                return
            end
            self.updateTable_();
            %self.updateControlEnablementImplementation_();
        end  % function       
    end  % methods
        
    methods (Access=protected)
        function updateTable_(self,varargin)
            wsModel=self.Model_;
            if isempty(wsModel) ,
                return
            end
            nRows = wsModel.NFastProtocols ;
            nColumns=2;
            data=cell(nRows,nColumns);
            for i=1:nRows ,
                protocolFileName = wsModel.getFastProtocolProperty(i, 'ProtocolFileName') ;
                autoStartType = wsModel.getFastProtocolProperty(i, 'AutoStartType') ;
                data{i,1}=protocolFileName;
                data{i,2}=ws.titleStringFromStartType(autoStartType);
            end
            set(self.Table,'Data',data);
        end  % function
    end  % methods
    
    methods (Access=protected)
        function updateControlEnablementImplementation_(self)
            wavesurferModel=self.Model_;
            if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                return
            end            
            isIdle=isequal(wavesurferModel.State,'idle');
            selectedIndex = wavesurferModel.IndexOfSelectedFastProtocol;
            isARowSelected= ~isempty(selectedIndex);

            set(self.ClearRowButton,'Enable',ws.onIff(isIdle&&isARowSelected));
            set(self.SelectFileButton,'Enable',ws.onIff(isIdle&&isARowSelected));
            set(self.Table,'Enable',ws.onIff(isIdle))
        end  % function        
        
        function closeRequested_(self, source, event)  %#ok<INUSD>
            wsModel = self.Model_ ;
            
            if isempty(wsModel) || ~isvalid(wsModel) ,
                shouldStayPut = false ;
            else
                shouldStayPut = ~wsModel.isIdleSensuLato() ;
            end
           
            if shouldStayPut ,
                % Do nothing
            else
                %self.hide() ;
                wsModel.IsFastProtocolsFigureVisible = false ;
            end
        end        
    end  % protected methods block
    
    methods
        function ClearRowButtonActuated(self, varargin)
            %self.Model_.clearSelectedFastProtocol() ;
            self.Model_.do('clearSelectedFastProtocol') ;
        end  % function
        
        function SelectFileButtonActuated(self, varargin)
            % Allow the user to choose a file to be the protocol file for
            % the currently selected fast protocol.
                        
            % Figure out what directory the file picker dialog will start
            % in.  By default start in the location of the current file.
            % If it is empty it will attempt to start in
            % LastProtocolFilePath, loaded from the shared preferences. If
            % that does not exist, then it will start in the current
            % directory.
            filePickerInitialFolderFromPreferences = ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath') ;
            originalFastProtocolFileName = self.Model_.getSelectedFastProtocolProperty('ProtocolFileName') ;
            if isempty(originalFastProtocolFileName) ,
                if ~exist('startLocationFromPreferences','var') ,
                    filePickerInitialFolder = '' ;
                else
                    filePickerInitialFolder =  filePickerInitialFolderFromPreferences ;
                end
            else
                filePickerInitialFolder = originalFastProtocolFileName ;
            end
            [filename, dirName] = uigetfile({'*.wsp', 'WaveSurfer Protocol Files' ; ...
                                             '*.*',  'All Files (*.*)'} , ...
                                            'Select a Protocol File' , ...
                                            filePickerInitialFolder) ;

            % If the user cancels, just exit.
            if filename == 0 ,
                return
            end
            
            % Set the fast protocol to the selected file
            newProtocolFileName = fullfile(dirName, filename) ;
            self.Model_.do('setSelectedFastProtocolProperty', 'ProtocolFileName', newProtocolFileName) ;

%             % If newProtocolFileName and filePickerInitialFolderFromPreferences differ, then
%             % save newProtocolFileName as the new LastProtocolFilePath.
%             if ~isequal( ws.canonicalizePath(filePickerInitialFolderFromPreferences) , ws.canonicalizePath(newProtocolFileName) ) ,
%                 ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', newProtocolFileName);
%             end
        end  % function
        
        function TableCellSelected(self, source, event)  %#ok<INUSL>
            indices = event.Indices ;
            if ~isempty(indices) ,
                rowIndex = indices(1) ;
                %self.Model_.IndexOfSelectedFastProtocol = rowIndex ;
                self.Model_.do('set', 'IndexOfSelectedFastProtocol', rowIndex) ;                
            end
        end  % function
    
        function TableCellEdited(self,source,event) %#ok<INUSL>
            indices=event.Indices;
            newString=event.EditData;
            rowIndex=indices(1);
            columnIndex=indices(2);
            fastProtocolIndex=rowIndex;
            if (columnIndex==1) ,
                % this is the Protocol File column
%                 if isempty(newString) || exist(newString,'file') ,
%                     theFastProtocol=self.Model_.FastProtocols{fastProtocolIndex};
%                     ws.Controller.setWithBenefits(theFastProtocol,'ProtocolFileName',newString);
%                 end
                self.Model_.do('setFastProtocolProperty', fastProtocolIndex, 'ProtocolFileName', newString) ;
            elseif (columnIndex==2) ,
                % this is the Action column
                newValue = ws.startTypeFromTitleString(newString) ;  
%                 theFastProtocol=self.Model_.FastProtocols{fastProtocolIndex};
%                 ws.Controller.setWithBenefits(theFastProtocol,'AutoStartType',newValue);
                self.Model_.do('setFastProtocolProperty', fastProtocolIndex, 'AutoStartType', newValue) ;
            end            
        end  % function        
    end  % public methods block
    
%     methods (Access=protected)
%         function updateVisibility_(self, ~, ~, ~, ~, event)
%             figureName = event.Args{1} ;
%             oldValue = event.Args{2} ;            
%             if isequal(figureName, 'FastProtocols') ,
%                 newValue = self.Model_.IsFastProtocolsFigureVisible ;
%                 if oldValue && newValue , 
%                     % Do this to raise the figure
%                     set(self.FigureGH_, 'Visible', 'off') ;
%                     set(self.FigureGH_, 'Visible', 'on') ;
%                 else
%                     set(self.FigureGH_, 'Visible', ws.onIff(newValue)) ;
%                 end                    
%             end
%         end                
%     end
    
end  % classdef
