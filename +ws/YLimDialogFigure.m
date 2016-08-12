classdef YLimDialogFigure < ws.MCOSFigureWithSelfControl
    properties (Access=protected)
        % The various HG objects in the figure
        YMaxText_
        YMaxEdit_
        YMaxUnitsText_
        YMinText_
        YMinEdit_
        YMinUnitsText_
        OKButton_
        CancelButton_
        % Other things
        YLimits_
        YUnits_
        CallbackFunction_
    end
    
    methods
        function self=YLimDialogFigure(model, parentFigurePosition, yLimits, yUnits, callbackFunction)
            % Call the super-class consructor
            self = self@ws.MCOSFigureWithSelfControl(model) ;
            
            % Initialize some properties
            self.YLimits_ = yLimits ;
            self.YUnits_ = yUnits ;
            self.CallbackFunction_ = callbackFunction ;
            
            % Set the relevant properties of the figure itself
            set(self.FigureGH_, 'Tag', 'YLimDialogFigure', ...
                                'Units', 'pixels', ...
                                'Resize', 'off', ...
                                'Name', 'Y Limits...', ...
                                'Menubar', 'none', ...
                                'Toolbar', 'none', ...
                                'NumberTitle', 'off', ...
                                'WindowStyle', 'modal', ...
                                'Visible', 'off', ...
                                'CloseRequestFcn', @(source,event)(self.closeRequested_(source,event)) ) ;
                          
            % Create all the "static" controls, set them up, but don't position them
            self.createFixedControls_() ;
            
            % sync up self to 'model', which is basically self.YLimits_ and
            % self.YUnits_
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
            % throughout the life of the window, but doesn't position them
            
            self.YMaxText_=...
                ws.uicontrol('Parent',self.FigureGH_, ...
                             'Style','text', ...
                             'HorizontalAlignment','right', ...
                             'String','Y Max:', ...
                             'Tag','YMaxText_', ...
                             'Callback',@(source,event)(self.controlActuated('yMaxText',source,event)));
            self.YMaxEdit_=...
                ws.uiedit('Parent',self.FigureGH_, ...
                          'HorizontalAlignment','right', ...
                          'Tag','YMaxEdit_', ...
                          'Callback',@(source,event)(self.controlActuated('yMaxEdit',source,event)));
            self.YMaxUnitsText_=...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','V', ...
                          'Tag','YMaxUnitsText_', ...
                          'Callback',@(source,event)(self.controlActuated('yMaxUnitsText',source,event)));
            self.YMinText_=...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','text', ...
                          'HorizontalAlignment','right', ...
                          'String','Y Min:', ...
                          'Tag','YMinText_', ...
                          'Callback',@(source,event)(self.controlActuated('yMinText',source,event)));
            self.YMinEdit_=...
                ws.uiedit('Parent',self.FigureGH_, ...
                          'HorizontalAlignment','right', ...
                          'Tag','YMinEdit_', ...
                          'Callback',@(source,event)(self.controlActuated('yMinEdit',source,event)));
            self.YMinUnitsText_=...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'String','V', ...
                          'Tag','YMinUnitsText_', ...
                          'Callback',@(source,event)(self.controlActuated('yMinUnitsText',source,event)));
            
            self.OKButton_= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'String','OK', ...
                          'Tag','OKButton_', ...
                          'Callback',@(source,event)(self.controlActuated('okButton',source,event)), ...
                          'KeypressFcn',@(source,event)(self.keyPressedOnButton('okButton',source,event)));
            self.CancelButton_= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'String','Cancel', ...
                          'Tag','CancelButton_', ...
                          'Callback',@(source,event)(self.controlActuated('cancelButton',source,event)), ...
                          'KeypressFcn',@(source,event)(self.keyPressedOnButton('cancelButton',source,event)));
        end  % function

        function layout_(self)
            % Layout the figure elements
            nRows=2;
            rowHeight=16;
            interRowHeight=8;
            topSpaceHeight=10;
            leftSpaceWidth=10;
            widthBetweenLabelAndEdit=5;
            labelWidth=50;
            labelHeight=rowHeight;
            editXOffset=leftSpaceWidth+labelWidth+widthBetweenLabelAndEdit;
            editWidth=60;
            editHeight=20;            
            editTweakHeight= 0;
            widthBetweenEditAndUnits=3;
            unitsXOffset=editXOffset+editWidth+widthBetweenEditAndUnits;
            unitsWidth=30;
            unitsHeight=rowHeight;
            rightSpaceWidth=10;           
            
            nBottomButtons=2;
            heightBetweenEditRowsAndBottomButtonRow=20;
            bottomButtonWidth=50;
            bottomButtonHeight=20;
            interBottomButtonSpaceWidth=6;
            bottomSpaceHeight=10;
            
            figureWidth=leftSpaceWidth+labelWidth+widthBetweenEditAndUnits+editWidth+widthBetweenEditAndUnits+unitsWidth+rightSpaceWidth;
            figureHeight=topSpaceHeight+nRows*rowHeight+(nRows-1)*interRowHeight+heightBetweenEditRowsAndBottomButtonRow+bottomButtonHeight+bottomSpaceHeight;
            
            % Position the figure, keeping upper left corner fixed
            currentPosition=get(self.FigureGH_,'Position');
            currentOffset=currentPosition(1:2);
            currentSize=currentPosition(3:4);
            currentUpperY=currentOffset(2)+currentSize(2);
            figurePosition=[currentOffset(1) currentUpperY-figureHeight figureWidth figureHeight];
            set(self.FigureGH_,'Position',figurePosition);

            % Layout the edit rows
            yOffsetOfTopRow=bottomSpaceHeight+bottomButtonHeight+heightBetweenEditRowsAndBottomButtonRow+(nRows-1)*(rowHeight+interRowHeight);                        
            yOffsetOfThisRow=yOffsetOfTopRow;
            set(self.YMaxText_     ,'Position',[leftSpaceWidth yOffsetOfThisRow labelWidth labelHeight]);
            set(self.YMaxEdit_     ,'Position',[editXOffset yOffsetOfThisRow+editTweakHeight editWidth editHeight]);
            set(self.YMaxUnitsText_,'Position',[unitsXOffset yOffsetOfThisRow unitsWidth unitsHeight]);
            
            yOffsetOfThisRow=yOffsetOfThisRow-(rowHeight+interRowHeight);            
            set(self.YMinText_     ,'Position',[leftSpaceWidth yOffsetOfThisRow labelWidth labelHeight]);
            set(self.YMinEdit_     ,'Position',[editXOffset yOffsetOfThisRow+editTweakHeight editWidth editHeight]);
            set(self.YMinUnitsText_,'Position',[unitsXOffset yOffsetOfThisRow unitsWidth unitsHeight]);

            % Layout the bottom buttons
            widthOfAllBottomButtons=nBottomButtons*bottomButtonWidth+(nBottomButtons-1)*interBottomButtonSpaceWidth;
            %xOffsetOfLeftButton=(figureWidth-widthOfAllBottomButtons)/2;
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
            if isequal(source, self.YMaxEdit_) || isequal(source, self.YMinEdit_) ,
                self.syncOKButtonEnablementFromEditContents_() ;
            else
                controlActuated@ws.MCOSFigureWithSelfControl(self, methodNameStem, source, event, varargin{:}) ;
            end
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
            yMaxAsString=get(self.YMaxEdit_,'String');
            yMinAsString=get(self.YMinEdit_,'String');
            yMax=str2double(yMaxAsString);
            yMin=str2double(yMinAsString);
            if isfinite(yMax) && isfinite(yMin) ,
                if yMin>yMax ,
                    temp=yMax;
                    yMax=yMin;
                    yMin=temp;
                end
                if yMin~=yMax ,
                    callbackFunction = self.CallbackFunction_ ;
                    feval(callbackFunction,[yMin yMax]) ;
                    %self.Model.(callbackFunction) = [yMin yMax] ;
                end
            end
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
            % Update the relevant controls
            yl = self.YLimits_ ;
            unitsString = self.YUnits_ ;
            set(self.YMaxEdit_     ,'String',sprintf('%0.3g',yl(2)));
            set(self.YMaxUnitsText_,'String',unitsString);
            set(self.YMinEdit_     ,'String',sprintf('%0.3g',yl(1)));
            set(self.YMinUnitsText_,'String',unitsString);            
        end
    end
end  % classdef
