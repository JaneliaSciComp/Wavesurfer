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
        IsDisplayed_  % indexed by the *channel* index
        PlotHeights_  % indexed by the *channel* index
        RowIndexFromChannelIndex_  % indexed by the *channel* index, of course
        ChannelIndexFromRowIndex_  % indexed by the row index, of course.  Must be kept in sync with RowIndexFromChannelIndex_
        CallbackFunction_
    end
    
    methods
        function self = PlotArrangementDialogFigure(model, parentFigurePosition, channelNames, isDisplayed, plotHeights, rowIndexFromChannelIndex, ...
                                                    callbackFunction)
            % Call the super-class consructor
            self = self@ws.MCOSFigureWithSelfControl(model) ;
            
            % Initialize some properties
            self.ChannelNames_ = channelNames ;
            self.IsDisplayed_ = isDisplayed ;
            self.PlotHeights_ = plotHeights ;
            self.RowIndexFromChannelIndex_ = rowIndexFromChannelIndex ;
            self.ChannelIndexFromRowIndex_ = ws.invertPermutation(rowIndexFromChannelIndex) ;
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
                                'WindowStyle', 'modal', ...
                                'CloseRequestFcn', @(source,event)(self.closeRequested_(source,event)) ) ;
            
            % Create all the "static" controls, set them up, but don't position them
            self.createFixedControls_() ;
            
            % sync up self to 'model', which is basically
            % self.ChannelNames_, self.PlotHeights_, and self.RowIndexFromChannelIndex_
            %self.updateControlProperties_() ;
            %self.layout_() ;
            self.update_() ;
            
            % Do stuff specific to dialog boxes
            self.centerOnParentPosition_(parentFigurePosition) ;
            self.show() ;
        end  % constructor
    end
    
    methods (Access=protected)
        function createFixedControls_(self)                          
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window, but doesn't position them.

            % Load the icons from disk
            wavesurferDirName=fileparts(which('wavesurfer'));
            upIconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'up_arrow.png');
            upIcon = ws.readPNGWithTransparencyForUIControlImage(upIconFileName) ;            
            downIconFileName = fullfile(wavesurferDirName, '+ws', 'private', 'icons', 'down_arrow.png');
            downIcon = ws.readPNGWithTransparencyForUIControlImage(downIconFileName) ;            
            
            self.IsDisplayedRowTitle_ = ...
                ws.uicontrol('Parent', self.FigureGH_, ...
                             'Style', 'text', ...
                             'HorizontalAlignment', 'center', ...
                             'String', 'Disp?', ...
                             'Tag', 'IsDisplayedRowTitle_') ;
            self.SizeRowTitle_ = ...
                ws.uicontrol('Parent', self.FigureGH_, ...
                             'Style', 'text', ...
                             'HorizontalAlignment', 'center', ...
                             'String', 'Size', ...
                             'Tag', 'SizeRowTitle_') ;
            
            % Preallocate arrays of graphics objects
            channelNames = self.ChannelNames_ ;
            nChannels = length(channelNames) ;
            nRows = nChannels ;
            self.ChannelNameTexts_ = gobjects(1,nRows) ;
            self.IsDisplayedCheckboxes_ = gobjects(1,nRows) ;
            self.PlotHeightEdits_ = gobjects(1,nRows) ;
            self.MoveUpButtons_ = gobjects(1,nRows) ;
            self.MoveDownButtons_ = gobjects(1,nRows) ;
            
            % Create all the one-per-channel widgets
            channelIndexFromRowIndex = self.ChannelIndexFromRowIndex_ ;
            for iRow = 1:nRows ,  % i the channel index
                iChannel = channelIndexFromRowIndex(iRow) ;
                self.ChannelNameTexts_(iRow) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','text', ...
                                 'String',sprintf('%s:',channelNames{iChannel}), ...
                                 'HorizontalAlignment','right', ...
                                 'Tag',sprintf('ChannelNameTexts_(%d)',iRow) ) ;
                self.IsDisplayedCheckboxes_(iRow) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','checkbox', ...
                                 'Tag',sprintf('IsDisplayedCheckboxes_(%d)',iRow), ...
                                 'Callback',@(source,event)(self.controlActuated('isDisplayedCheckbox',source,event,iRow)) ) ;
                self.PlotHeightEdits_(iRow) = ...
                    ws.uiedit('Parent',self.FigureGH_, ...
                              'Tag',sprintf('PlotHeightEdits_(%d)',iRow), ...
                              'HorizontalAlignment','right', ...
                              'Callback',@(source,event)(self.controlActuated('plotHeightEdit',source,event,iRow)) ) ;
                self.MoveUpButtons_(iRow) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','pushbutton', ...
                                 'Tag',sprintf('MoveUpButtons_(%d)',iRow), ...
                                 'CData',upIcon, ...
                                 'Callback',@(source,event)(self.controlActuated('moveUpButton',source,event,iRow)) ) ;
                self.MoveDownButtons_(iRow) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','pushbutton', ...
                                 'Tag',sprintf('MoveDownButtons_(%d)',iRow), ...
                                 'CData',downIcon, ...
                                 'Callback',@(source,event)(self.controlActuated('moveDownButton',source,event,iRow)) ) ;
            end

            % Disable two of the buttons, which will stay disabled for
            % their whole life.  (Sniff.)
            if nRows>0 ,
                set(self.MoveUpButtons_(1)    , 'Enable', 'off') ;
                set(self.MoveDownButtons_(end), 'Enable', 'off') ;
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
            %rowIndexFromChannelIndex = self.RowIndexFromChannelIndex_ ;
            %channelIndexFromRowIndex = ws.invertPermutation(rowIndexFromChannelIndex) ;
            nChannels = length(self.ChannelNames_) ;
            nRows = nChannels ;
            titleRowHeight=18;
            heightBetweenTitleRowAndWidgetRows = 4 ;
            rowHeight=20;
            interRowHeight=8;
            topMarginHeight=2;
            leftMarginWidth=10;
            widthBetweenChannelColAndIsDisplayedCol=5;
            maxChannelTextExtent = ws.maximalExtent(self.ChannelNameTexts_) ;
            channelColWidth = maxChannelTextExtent(1)+4 ;  % the +4 is a shim
            isDisplayedColWidth = 36 ;
            widthBetweenIsDisplayedColAndPlotSizeCol = 2 ;
            plotSizeEditWidth=30;
            plotSizeEditHeight=20;            
            %editTweakHeight= 0;
            widthBetweenPlotSizeColAndUpDownButtons=6;
            upDownButtonSize = 20 ;  % the buttons are square
            interUpDownButtonWidth = 2 ; 
            rightMarginWidth=10;           
            
            nBottomButtons=2;
            heightBetweenWidgetRowsAndBottomButtonRow=20;
            bottomButtonWidth=50;
            bottomButtonHeight=20;
            interBottomButtonSpaceWidth=6;
            bottomSpaceHeight=10;
            
            figureWidth = ...
                leftMarginWidth + ...
                channelColWidth + ...
                widthBetweenChannelColAndIsDisplayedCol + ...
                isDisplayedColWidth + ...
                widthBetweenPlotSizeColAndUpDownButtons + ...
                plotSizeEditWidth + ...
                widthBetweenPlotSizeColAndUpDownButtons + ...
                upDownButtonSize + ...
                interUpDownButtonWidth + ...
                upDownButtonSize + ...
                rightMarginWidth ;
            figureHeight = ...
                topMarginHeight + ...
                titleRowHeight + ...
                heightBetweenTitleRowAndWidgetRows + ...
                nRows*rowHeight + ...
                (nRows-1)*interRowHeight + ...
                heightBetweenWidgetRowsAndBottomButtonRow + ...
                bottomButtonHeight + ...
                bottomSpaceHeight ;
            
            % Size the figure, keeping upper left corner fixed
            currentPosition=get(self.FigureGH_,'Position');
            currentOffset=currentPosition(1:2);
            currentSize=currentPosition(3:4);
            currentUpperY=currentOffset(2)+currentSize(2);
            figurePosition=[currentOffset(1) currentUpperY-figureHeight figureWidth figureHeight];
            set(self.FigureGH_,'Position',figurePosition);
            
            % Layout the title row            
            channelColXOffset = leftMarginWidth ;
            checkboxColXOffset = leftMarginWidth + channelColWidth + widthBetweenChannelColAndIsDisplayedCol ;
            editXOffset = checkboxColXOffset + isDisplayedColWidth + widthBetweenIsDisplayedColAndPlotSizeCol;
            upDownButtonsXOffset = editXOffset + plotSizeEditWidth + widthBetweenPlotSizeColAndUpDownButtons;
            upButtonXOffset = upDownButtonsXOffset ;
            downButtonXOffset  = upButtonXOffset + upDownButtonSize + interUpDownButtonWidth ;
            yOffsetOfTitleRow = figureHeight - topMarginHeight - titleRowHeight ;
            ws.centerTextWithinRectangleBang(self.IsDisplayedRowTitle_, [checkboxColXOffset yOffsetOfTitleRow isDisplayedColWidth titleRowHeight]) ;
            ws.centerTextWithinRectangleBang(self.SizeRowTitle_, [editXOffset yOffsetOfTitleRow plotSizeEditWidth titleRowHeight]) ;
            
            % Layout the rows
            yOffsetOfTopRow = yOffsetOfTitleRow - heightBetweenTitleRowAndWidgetRows - rowHeight ;
            for iRow = 1:nRows ,
                if iRow==1 ,
                    yOffsetOfThisRow = yOffsetOfTopRow ;
                else
                    yOffsetOfThisRow = yOffsetOfThisRow - (interRowHeight+rowHeight) ;
                end
                ws.centerTextVerticallyWithinRectangleBang( ...
                    self.ChannelNameTexts_(iRow)     ,             [channelColXOffset  yOffsetOfThisRow channelColWidth     rowHeight] ) ;
                ws.centerCheckboxWithinRectangleBang( ...
                    self.IsDisplayedCheckboxes_(iRow),             [checkboxColXOffset yOffsetOfThisRow isDisplayedColWidth rowHeight] ) ;
                set(self.PlotHeightEdits_(iRow)      , 'Position', [editXOffset        yOffsetOfThisRow plotSizeEditWidth   plotSizeEditHeight] ) ;
                set(self.MoveUpButtons_(iRow)        , 'Position', [upButtonXOffset    yOffsetOfThisRow upDownButtonSize    upDownButtonSize] ) ;
                set(self.MoveDownButtons_(iRow)      , 'Position', [downButtonXOffset  yOffsetOfThisRow upDownButtonSize    upDownButtonSize] ) ;
            end

            % Layout the bottom buttons
            widthOfAllBottomButtons=nBottomButtons*bottomButtonWidth+(nBottomButtons-1)*interBottomButtonSpaceWidth;
            xOffsetOfLeftButton=figureWidth-rightMarginWidth-widthOfAllBottomButtons;
            
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
%         function controlActuated(self, methodNameStem, source, event, varargin)
%             controlActuated@ws.MCOSFigureWithSelfControl(self, methodNameStem, source, event, varargin{:}) ;
% %             if isequal(source, self.YMaxEdit_) || isequal(source, self.YMinEdit_) ,
% %                 self.syncOKButtonEnablementFromEditContents_() ;
% %             else
% %                 controlActuated@ws.MCOSFigureWithSelfControl(self, methodNameStem, source, event, varargin{:}) ;
% %             end
%         end  % function
       
        function keyPressedOnButton(self, methodNameStem, source, event)
            % This makes it so the user can press "Enter" when a button has keyboard focus to "press" the button.
            if isequal(event.Key,'return') ,
                self.controlActuated(methodNameStem, source, event);
            end
        end  % function
    end  % public methods block
    
%     methods (Access=protected)
%         function syncOKButtonEnablementFromEditContents_(self)
%             yMaxAsString=get(self.YMaxEdit_,'String');
%             yMinAsString=get(self.YMinEdit_,'String');
%             yMax=str2double(yMaxAsString);
%             yMin=str2double(yMinAsString);
%             isEnabled= isfinite(yMax) && isfinite(yMin) && (yMin~=yMax);
%             set(self.OKButton_,'Enable',ws.onIff(isEnabled));
%         end
%     end 
        
    methods
        function isDisplayedCheckboxActuated(self, source, event, rowIndex)  %#ok<INUSL>            
            channelIndex = self.ChannelIndexFromRowIndex_(rowIndex) ;
            self.IsDisplayed_(channelIndex) = get(source, 'Value') ;
            self.updateControlProperties_() ;
        end  % function
        
        function plotHeightEditActuated(self, source, event, rowIndex)  %#ok<INUSL>
            channelIndex = self.ChannelIndexFromRowIndex_(rowIndex) ;
            newValueAsString = get(source, 'String') ;
            newValueAsDouble = str2double(newValueAsString) ;            
            if isnan(newValueAsDouble) ,
                % do nothing
            else
                if isreal(newValueAsDouble) && newValueAsDouble>=0.09 ,
                    newValueRounded = round(10*newValueAsDouble)/10 ;  % want 10* the value to be an integer
                    self.PlotHeights_(channelIndex) = newValueRounded ;
                else
                    % Value is complex, or negative, or zero, or too small
                    % to bother with, so ignore.
                end
            end
            self.updateControlProperties_() ;
        end  % function

        function moveUpButtonActuated(self, source, event, rowIndex)  %#ok<INUSL>
            % Swap the row corresponding to channelIndex with the row just
            % above it visually.  I.e. if channelIndex corresponds to
            % rowIndex, want to swap rowIndex with rowIndex-1.  This is
            % slightly tricky b/c we need to determine the channel index
            % corresponding to rowIndex-1.
            self.swapRows_(rowIndex, -1) ;
        end  % function

        function moveDownButtonActuated(self, source, event, rowIndex)  %#ok<INUSL>
            % Swap the row corresponding to channelIndex with the row just
            % above it visually.  I.e. if channelIndex corresponds to
            % rowIndex, want to swap rowIndex with rowIndex+1.  This is
            % slightly tricky b/c we need to determine the channel index
            % corresponding to rowIndex-1.
            self.swapRows_(rowIndex, +1) ;
        end  % function
        
        function okButtonActuated(self,source,event) 
            feval(self.CallbackFunction_, self.IsDisplayed_, self.PlotHeights_, self.RowIndexFromChannelIndex_) ;
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
%         function self=updateImplementation_(self,varargin)
%             % Syncs self with model, making no prior assumptions about what
%             % might have changed or not changed in the model.
%             self.updateControlPropertiesImplementation_();
%             %self.layout();
%         end
        
        function updateControlPropertiesImplementation_(self, varargin)
            % Get props out of self
            channelNames = self.ChannelNames_ ;
            isDisplayed = self.IsDisplayed_ ;
            plotHeights = self.PlotHeights_ ;
            %rowIndexFromChannelIndex = self.RowIndexFromChannelIndex_ ;
            channelIndexFromRowIndex = self.ChannelIndexFromRowIndex_ ;
            
            % Set the content of each widget
            nRows = length(channelIndexFromRowIndex) ;
            for iRow = 1:nRows ,
                iChannel = channelIndexFromRowIndex(iRow) ;
                set(self.ChannelNameTexts_(iRow), 'String', channelNames{iChannel}) ;
                set(self.IsDisplayedCheckboxes_(iRow), 'Value', isDisplayed(iChannel) ) ;
                set(self.PlotHeightEdits_(iRow), 'String', sprintf('%g', plotHeights(iChannel) ) ) ;
            end
        end
        
        function updateControlEnablementImplementation_(self, varargin) %#ok<INUSD>
%             % Get props out of self
%             channelNames = self.ChannelNames_ ;
%             %isDisplayed = self.IsDisplayed_ ;
%             %plotHeights = self.PlotHeights_ ;
%             rowIndexFromChannelIndex = self.RowIndexFromChannelIndex_ ;
% 
%             % Invert the channel->row mapping
%             channelIndexFromRowIndex = ws.invertPermutation(rowIndexFromChannelIndex) ;   
%             
%             % Turn off the top move up button, the bottom move down button
%             nChannels = length(channelNames) ;
%             set(self.MoveUpButtons_(  channelIndexFromRowIndex(1        )), 'Enable', 'off') ;
%             set(self.MoveUpButtons_(  channelIndexFromRowIndex(2:end    )), 'Enable', 'on' ) ;
%             set(self.MoveDownButtons_(channelIndexFromRowIndex(1:end-1  )), 'Enable', 'on' ) ;
%             set(self.MoveDownButtons_(channelIndexFromRowIndex(nChannels)), 'Enable', 'off') ;
        end
        
        function swapRows_(self, rowIndex, delta)
            % Swap the row indicated by rowIndex with the row above (when delta==-1) or
            % below (when delta==+1) it.  Delta must be -1 or +1.
            channelIndexFromRowIndex = self.ChannelIndexFromRowIndex_ ;
            %rowIndexFromChannelIndex = self.RowIndexFromChannelIndex_ ;
            %rowIndex = rowIndexFromChannelIndex(channelIndex) ;
            otherRowIndex = rowIndex + delta ;
            nRows = length(channelIndexFromRowIndex) ;  % number of channels, also number of rows
            if 1<=otherRowIndex && otherRowIndex<=nRows ,
                newChannelIndexFromRowIndex = ws.swapElementsInPermutation(channelIndexFromRowIndex, rowIndex, otherRowIndex) ;
                newRowIndexFromChannelIndex = ws.invertPermutation(newChannelIndexFromRowIndex) ;
                self.RowIndexFromChannelIndex_ = newRowIndexFromChannelIndex ;
                self.ChannelIndexFromRowIndex_ = newChannelIndexFromRowIndex ;
            end
            self.updateControlProperties_() ;            
        end
    end
end  % classdef
