classdef PlotArrangementDialogFigure < ws.MCOSFigureWithSelfControl
    properties (Access=protected)
        % The various HG objects in the figure
        IsDisplayedRowTitle_
        SizeRowTitle_
        ChannelNameTexts_
        IsDisplayedCheckboxes_
        PlotHeightEdits_
        MoveUpButtons_
        MoveDownButtons_
        OKButton_
        CancelButton_
        
        % Other things
        ChannelNames_  % the names of the channels
        IsDisplayed_
        PlotHeights_
        PlotOrdinality_  
          % the order the plots are displayed in.
          % self.ChannelNames_{self.PlotOrdinality(1)} is at the top,
          % self.ChannelNames_{self.PlotOrdinality(2)} next, etc.
        CallbackFunction_
    end
    
    methods
        function self = PlotArrangementDialogFigure(model, parentFigurePosition, channelNames, isDisplayed, plotHeights, plotOrdinality, callbackFunction)
            % Call the super-class consructor
            self = self@ws.MCOSFigureWithSelfControl(model) ;
            
            % Initialize some properties
            self.ChannelNames_ = channelNames ;
            self.IsDisplayed_ = isDisplayed ;
            self.PlotHeights_ = plotHeights ;
            self.PlotOrdinality_ = plotOrdinality ;
            self.CallbackFunction_ = callbackFunction ;
            
            % Set the relevant properties of the figure itself
            set(self.FigureGH_, 'Tag', 'PlotArrangementDialogFigure', ...
                                'Units', 'pixels', ...
                                'Resize', 'off', ...
                                'Name', 'Plot Arrangement...', ...
                                'Menubar', 'none', ...
                                'Toolbar', 'none', ...
                                'NumberTitle', 'off', ...
                                'Visible', 'off', ...
                                'CloseRequestFcn', @(source,event)(self.closeRequested_(source,event)) ) ;
%                                'WindowStyle', 'modal', ...
            
            % Create all the "static" controls, set them up, but don't position them
            self.createFixedControls_() ;
            
            % sync up self to 'model', which is basically
            % self.ChannelNames_, self.PlotHeights_, and self.PlotOrdinality_
            self.updateControlProperties_() ;
            self.layout_() ;
            
            % Do stuff specific to dialog boxes
            self.centerOnParentPosition_(parentFigurePosition) ;
            self.show() ;
        end  % constructor
    end
    
    methods (Access=protected)
        function createFixedControls_(self)                          
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window, but doesn't position them.
                
            self.IsDisplayedRowTitle_ = ...
                ws.uicontrol('Parent', self.FigureGH_, ...
                             'Style', 'text', ...
                             'HorizontalAlignment', 'center', ...
                             'String', 'Displayed?', ...
                             'Tag', 'IsDisplayedRowTitle_') ;
            self.SizeRowTitle_ = ...
                ws.uicontrol('Parent', self.FigureGH_, ...
                             'Style', 'text', ...
                             'HorizontalAlignment', 'center', ...
                             'String', 'Size', ...
                             'Tag', 'SizeRowTitle_') ;
            
            % Preallocate arrays of graphics objects
            channelNames = self.ChannelNames_ ;
            nPlots = length(channelNames) ;
            self.ChannelNameTexts_ = gobjects(1,nPlots) ;
            self.IsDisplayedCheckboxes_ = gobjects(1,nPlots) ;
            self.PlotHeightEdits_ = gobjects(1,nPlots) ;
            self.MoveUpButtons_ = gobjects(1,nPlots) ;
            self.MoveDownButtons_ = gobjects(1,nPlots) ;
            
            % Create all the one-per-channel widgets
            for i = 1:nPlots ,  % i the channel index
                self.ChannelNameTexts_(i) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','text', ...
                                 'String',sprintf('%s:',channelNames{i}), ...
                                 'HorizontalAlignment','right', ...
                                 'Tag',sprintf('ChannelNameTexts_(%d)',i) ) ;
                self.IsDisplayedCheckboxes_(i) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','checkbox', ...
                                 'Tag',sprintf('IsDisplayedCheckboxes_(%d)',i), ...
                                 'Callback',@(source,event)(self.controlActuated('isDisplayedCheckbox',source,event,i)) ) ;
                self.PlotHeightEdits_(i) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','edit', ...
                                 'Tag',sprintf('PlotHeightEdits_(%d)',i), ...
                                 'Callback',@(source,event)(self.controlActuated('plotHeightEdit',source,event,i)) ) ;
                self.MoveUpButtons_(i) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','pushbutton', ...
                                 'Tag',sprintf('MoveUpButtons_(%d)',i), ...
                                 'String','^', ...
                                 'Callback',@(source,event)(self.controlActuated('moveUpButton',source,event,i)) ) ;
                self.MoveDownButtons_(i) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','pushbutton', ...
                                 'Tag',sprintf('MoveDownButtons_(%d)',i), ...
                                 'String','v', ...
                                 'Callback',@(source,event)(self.controlActuated('moveDownButton',source,event,i)) ) ;
            end

            % Create the OK and Cancel buttons
            self.OKButton_ = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                             'Style','pushbutton', ...
                             'String','OK', ...
                             'Tag','OKButton_', ...
                             'Callback',@(source,event)(self.controlActuated('okButton',source,event)), ...
                             'KeypressFcn',@(source,event)(self.keyPressedOnButton('okButton',source,event)) ) ;
            self.CancelButton_ = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                             'Style','pushbutton', ...
                             'String','Cancel', ...
                             'Tag','CancelButton_', ...
                             'Callback',@(source,event)(self.controlActuated('cancelButton',source,event)), ...
                             'KeypressFcn',@(source,event)(self.keyPressedOnButton('cancelButton',source,event)) ) ;
        end  % function

        function layout_(self)
            % Layout the figure elements
            nPlots = length(self.ChannelNames_) ;
            nRows = nPlots ;
            titleRowHeight=18;
            rowHeight=16;
            interRowHeight=8;
            topSpaceHeight=10;
            leftSpaceWidth=10;
            widthBetweenLabelAndCheckbox=5;
            labelWidth=50;
            labelHeight=rowHeight;
            checkboxColWidth = 60 ;
            widthBetweenCheckboxAndEdit = 2 ;
            editWidth=30;
            editHeight=20;            
            %editTweakHeight= 0;
            widthBetweenEditAndUpDownButtons=3;
            upDownButtonSize = 16 ;  % the buttons are square
            interUpDownButtonWidth = 2 ; 
            rightSpaceWidth=10;           
            
            nBottomButtons=2;
            heightBetweenWidgetRowsAndBottomButtonRow=20;
            bottomButtonWidth=50;
            bottomButtonHeight=20;
            interBottomButtonSpaceWidth=6;
            bottomSpaceHeight=10;
            
            figureWidth = ...
                leftSpaceWidth+labelWidth+widthBetweenLabelAndCheckbox+checkboxColWidth + ...
                widthBetweenEditAndUpDownButtons+editWidth+widthBetweenEditAndUpDownButtons+upDownButtonSize+interUpDownButtonWidth+upDownButtonSize+rightSpaceWidth ;
            figureHeight = ...
                topSpaceHeight+titleRowHeight+nRows*rowHeight+(nRows-1)*interRowHeight+heightBetweenWidgetRowsAndBottomButtonRow+bottomButtonHeight + ...
                bottomSpaceHeight ;
            
            % Size the figure, keeping upper left corner fixed
            currentPosition=get(self.FigureGH_,'Position');
            currentOffset=currentPosition(1:2);
            currentSize=currentPosition(3:4);
            currentUpperY=currentOffset(2)+currentSize(2);
            figurePosition=[currentOffset(1) currentUpperY-figureHeight figureWidth figureHeight];
            set(self.FigureGH_,'Position',figurePosition);
            
            % Layout the title row            
            checkboxColXOffset = leftSpaceWidth + labelWidth + widthBetweenLabelAndCheckbox ;
            editXOffset = checkboxColXOffset + checkboxColWidth + widthBetweenCheckboxAndEdit;
            upDownButtonsXOffset = editXOffset + editWidth + widthBetweenEditAndUpDownButtons;
            upButtonXOffset = upDownButtonsXOffset ;
            downButtonXOffset  = upButtonXOffset + upDownButtonSize + interUpDownButtonWidth ;
            yOffsetOfTitleRow = figureHeight - titleRowHeight ;
            ws.centerTextWithinRectangleBang(self.IsDisplayedRowTitle_, [checkboxColXOffset yOffsetOfTitleRow labelWidth labelHeight]) ;
            set(self.SizeRowTitle_, 
            
            % Layout the rows
            yOffsetOfTopRow = bottomSpaceHeight + bottomButtonHeight + heightBetweenWidgetRowsAndBottomButtonRow + (nRows-1)*(rowHeight+interRowHeight) ;                        
            for i = 1:nPlots ,
                if i==1 ,
                    yOffsetOfThisRow = yOffsetOfTopRow ;
                else
                    yOffsetOfThisRow = yOffsetOfThisRow - (rowHeight+interRowHeight) ;
                end
                set(self.ChannelNameTexts_(i)     , 'Position', [leftSpaceWidth yOffsetOfThisRow labelWidth labelHeight] ) ;
                ws.centerCheckboxBang( ...
                    self.IsDisplayedCheckboxes_(i),             [checkboxColXOffset+checkboxColWidth/2 yOffsetOfThisRow+rowHeight/2] ) ;
                set(self.PlotHeightEdits_(i)      , 'Position', [editXOffset yOffsetOfThisRow editWidth editHeight] ) ;
                set(self.MoveUpButtons_(i)        , 'Position', [upButtonXOffset yOffsetOfThisRow upDownButtonSize upDownButtonSize] ) ;
                set(self.MoveDownButtons_(i)      , 'Position', [downButtonXOffset yOffsetOfThisRow upDownButtonSize upDownButtonSize] ) ;
            end

            % Layout the bottom buttons
            widthOfAllBottomButtons=nBottomButtons*bottomButtonWidth+(nBottomButtons-1)*interBottomButtonSpaceWidth;
            xOffsetOfLeftButton=figureWidth-rightSpaceWidth-widthOfAllBottomButtons;
            
            xOffsetOfThisButton=xOffsetOfLeftButton;
            set(self.OKButton_,'Position',[xOffsetOfThisButton bottomSpaceHeight bottomButtonWidth bottomButtonHeight]);
            xOffsetOfThisButton=xOffsetOfThisButton+(bottomButtonWidth+interBottomButtonSpaceWidth);
            set(self.CancelButton_,'Position',[xOffsetOfThisButton bottomSpaceHeight bottomButtonWidth bottomButtonHeight]);
        end  % function
        
        function centerOnParentPosition_(self,parentPosition)
            originalPosition=get(self.FigureGH_,'Position');
            %originalOffset=originalPosition(1:2);
            size=originalPosition(3:4);
            parentOffset=parentPosition(1:2);
            parentSize=parentPosition(3:4);
            newOffset=parentOffset+(parentSize-size)/2;
            newPosition=[newOffset size];
            set(self.FigureGH_,'Position',newPosition);
        end
    end % protected methods block
    
    methods        
        function controlActuated(self, methodNameStem, source, event, varargin)
            controlActuated@ws.MCOSFigureWithSelfControl(self, methodNameStem, source, event, varargin{:}) ;
%             if isequal(source, self.YMaxEdit_) || isequal(source, self.YMinEdit_) ,
%                 self.syncOKButtonEnablementFromEditContents_() ;
%             else
%                 controlActuated@ws.MCOSFigureWithSelfControl(self, methodNameStem, source, event, varargin{:}) ;
%             end
        end  % function
       
        function keyPressedOnButton(self, methodNameStem, source, event)
            % This makes it so the user can press "Enter" when a button has keyboard focus to "press" the button.
            if isequal(event.Key,'return') ,
                self.controlActuated(methodNameStem, source, event);
            end
        end  % function
    end  % public methods block
    
    methods (Access=protected)
        function syncOKButtonEnablementFromEditContents_(self)
            yMaxAsString=get(self.YMaxEdit_,'String');
            yMinAsString=get(self.YMinEdit_,'String');
            yMax=str2double(yMaxAsString);
            yMin=str2double(yMinAsString);
            isEnabled= isfinite(yMax) && isfinite(yMin) && (yMin~=yMax);
            set(self.OKButton_,'Enable',ws.onIff(isEnabled));
        end
    end 
        
    methods
        function okButtonActuated(self,source,event) 
%             yMaxAsString=get(self.YMaxEdit_,'String');
%             yMinAsString=get(self.YMinEdit_,'String');
%             yMax=str2double(yMaxAsString);
%             yMin=str2double(yMinAsString);
%             if isfinite(yMax) && isfinite(yMin) ,
%                 if yMin>yMax ,
%                     temp=yMax;
%                     yMax=yMin;
%                     yMin=temp;
%                 end
%                 if yMin~=yMax ,
%                     callbackFunction = self.CallbackFunction_ ;
%                     feval(callbackFunction,[yMin yMax]) ;
%                     %self.Model.(callbackFunction) = [yMin yMax] ;
%                 end
%             end
            self.closeRequested_(source, event) ;
        end  % function
        
        function cancelButtonActuated(self,source,event)
            self.closeRequested_(source, event) ;
        end        
    end  % methods

    methods (Access=protected)
        function self=updateImplementation_(self,varargin)
            % Syncs self with model, making no prior assumptions about what
            % might have changed or not changed in the model.
            self.updateControlPropertiesImplementation_();
            %self.layout();
        end
        
        function self=updateControlPropertiesImplementation_(self, varargin)
%             % Update the relevant controls
%             yl = self.YLimits_ ;
%             unitsString = self.YUnits_ ;
%             set(self.YMaxEdit_     ,'String',sprintf('%0.3g',yl(2)));
%             set(self.YMaxUnitsText_,'String',unitsString);
%             set(self.YMinEdit_     ,'String',sprintf('%0.3g',yl(1)));
%             set(self.YMinUnitsText_,'String',unitsString);            
        end
    end
end  % classdef
