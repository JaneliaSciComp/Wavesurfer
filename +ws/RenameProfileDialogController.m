classdef RenameProfileDialogController < ws.Controller
    properties (Access=protected)
        % The various HG objects in the figure
        NewNameText_
        NewNameEdit_
        OKButton_
        CancelButton_
        % Other things
        NewName_
        %AreYLimitsAcceptable_
        %YUnits_
        CallbackFunction_
    end
    
    methods
        function self = RenameProfileDialogController(model, parentFigurePosition, oldProfileName, callbackFunction)
            % Call the super-class consructor
            self = self@ws.Controller(model) ;
            
            % Initialize some properties
            self.NewName_ = oldProfileName ;
            self.CallbackFunction_ = callbackFunction ;
            
            % Set the relevant properties of the figure itself
            set(self.FigureGH_, 'Tag', 'RenameProfileDialogController', ...
                                'Units', 'pixels', ...
                                'Resize', 'off', ...
                                'Name', 'Rename Profile...', ...
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
            self.update_() ;
            self.layout_() ;
            
            % Do stuff specific to dialog boxes
            self.centerOnParentPosition_(parentFigurePosition) ;
            self.show() ;
            
            % Give the top edit keyboard focus
            uicontrol(self.NewNameEdit_) ;
        end  % constructor
    end
    
    methods (Access=protected)
        function createFixedControls_(self)                          
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window, but doesn't position them
            
            self.NewNameText_=...
                ws.uicontrol('Parent',self.FigureGH_, ...
                             'Style','text', ...
                             'HorizontalAlignment','right', ...
                             'String','New Name:', ...
                             'Tag','NewNameText_');
            self.NewNameEdit_=...
                ws.uiedit('Parent',self.FigureGH_, ...
                          'HorizontalAlignment','left', ...
                          'Tag','NewNameEdit_', ...
                          'KeypressFcn',@(source,event)(self.keyPressedOnEdit('newNameEdit',source,event)), ...
                          'Callback',@(source,event)(self.controlActuated('newNameEdit',source,event)));
            
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
            nRows=1;
            rowHeight=16;
            interRowHeight=8;
            topSpaceHeight=20;
            leftSpaceWidth=60;
            widthBetweenLabelAndEdit=5;
            labelWidth=58;
            labelHeight=rowHeight;
            editXOffset=leftSpaceWidth+labelWidth+widthBetweenLabelAndEdit;
            editWidth=120;
            editHeight=20;            
            editTweakHeight= 0;
            widthBetweenEditAndUnits=3;
            %unitsXOffset=editXOffset+editWidth+widthBetweenEditAndUnits;
            %unitsWidth=30;
            %unitsHeight=rowHeight;
            rightSpaceWidth=60;           
            rightButtonSpaceWidth = 10 ;
            
            nBottomButtons=2;
            heightBetweenEditRowsAndBottomButtonRow=20;
            bottomButtonWidth=50;
            bottomButtonHeight=20;
            interBottomButtonSpaceWidth=6;
            bottomSpaceHeight=10;
            
            figureWidth=leftSpaceWidth+labelWidth+widthBetweenEditAndUnits+editWidth+rightSpaceWidth;
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
            set(self.NewNameText_     ,'Position',[leftSpaceWidth yOffsetOfThisRow labelWidth labelHeight]);
            set(self.NewNameEdit_     ,'Position',[editXOffset yOffsetOfThisRow+editTweakHeight editWidth editHeight]);

            % Layout the bottom buttons
            widthOfAllBottomButtons=nBottomButtons*bottomButtonWidth+(nBottomButtons-1)*interBottomButtonSpaceWidth;
            %xOffsetOfLeftButton=(figureWidth-widthOfAllBottomButtons)/2;
            xOffsetOfLeftButton=figureWidth-rightButtonSpaceWidth-widthOfAllBottomButtons;
            
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
%             controlActuated@ws.Controller(self, methodNameStem, source, event, varargin{:}) ;
%         end  % function
       
        function keyPressedOnEdit(self, methodNameStem, source, event) %#ok<INUSL>
            %self.setYLimitsGivenEditContents_() ;
            %self.syncAreYLimitsAcceptableGivenYLimits_() ;
            %self.updateControlEnablement_() ;
            if isequal(event.Key,'return') ,
                uicontrol(source) ;  % Have to do this so the edit's String property reflects the value the user is currently seeing
                self.controlActuated('okButton', source, event);
            end            
        end

        function keyPressedOnButton(self, methodNameStem, source, event)
            % This makes it so the user can press "Enter" when a control
            % has keyboard focus to press the OK button.  Unless the
            % control is the Cancel Button, in which case it's like pressig
            % the Cancel button.
            %fprintf('keyPressedOnControl()\n') ;
            %key = event.Key
            if isequal(event.Key,'return') ,
                self.controlActuated(methodNameStem, source, event);
            end
        end  % function
    end  % public methods block
    
%     methods (Static)
%         function result = areYLimitsAcceptable(yLimits)
%             yMin = yLimits(1) ;
%             yMax = yLimits(2) ;
%             result = isfinite(yMax) && isfinite(yMin) && (yMin~=yMax) ;
%         end
%     end 

    methods (Access=protected)
%         function syncAreYLimitsAcceptableGivenYLimits_(self)
%             self.AreYLimitsAcceptable_ = ws.YLimDialogController.areYLimitsAcceptable(self.YLimits_) ;
%         end
        
%         function setYLimitsGivenEditContents_(self)
%             yMaxAsString=get(self.YMaxEdit_,'String') ;
%             yMinAsString=get(self.YMinEdit_,'String') ;
%             yMax=str2double(yMaxAsString);
%             yMin=str2double(yMinAsString);
%             self.YLimits_ = [yMin yMax] ;
%         end
        
%         function syncOKButtonEnablementFromEditContents_(self)
%             self.setYLimitsGivenEditContents_() ;
%             self.syncAreYLimitsAcceptableGivenYLimits_() ;
%             self.updateControlEnablement_() ;
%         end
    end 
        
    methods
        function okButtonActuated(self, source, event) 
            newName = self.NewName_ ;
            callbackFunction = self.CallbackFunction_ ;
            feval(callbackFunction, newName) ;
            self.closeRequested_(source, event) ;
        end  % function
        
        function cancelButtonActuated(self,source,event)
            self.closeRequested_(source, event) ;
        end
        
        function newNameEditActuated(self, source, event)  %#ok<INUSD>
            newName = strtrim(get(self.NewNameEdit_,'String')) ;
            self.NewName_ = newName ;
        end
    end  % methods

    methods (Access=protected)
        function self = updateImplementation_(self,varargin)
            % Syncs self with model, making no prior assumptions about what
            % might have changed or not changed in the model.
            self.updateControlPropertiesImplementation_();
            self.updateControlEnablementImplementation_();
            %self.layout();
        end
        
        function self=updateControlPropertiesImplementation_(self, varargin)
            % Update the relevant controls
            newName = self.NewName_ ;
            set(self.NewNameEdit_, 'String', newName) ;
        end
        
        function self = updateControlEnablementImplementation_(self, varargin)
            % Update the relevant controls
            %set(self.OKButton_,'Enable',ws.onIff(self.AreYLimitsAcceptable_));
        end        
    end
end  % classdef
