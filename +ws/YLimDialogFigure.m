classdef YLimDialogFigure < ws.MCOSFigure & ws.EventSubscriber
    properties
        % The various HG objects in the figure
        YMaxText
        YMaxEdit
        YMaxUnitsText
        YMinText
        YMinEdit
        YMinUnitsText
        OKButton
        CancelButton
    end  % properties
    
    methods
        function self=YLimDialogFigure(model,controller)
            % Call the super-class consructor
            self = self@ws.MCOSFigure(model,controller);
            
            % Set the relevant properties of the figure itself
            set(self.FigureGH,'Tag','YLimDialogFigure', ...
                              'Units','pixels', ...
                              'Color',get(0,'defaultUIControlBackgroundColor'), ...
                              'Resize','off', ...
                              'Name','Y Limits...', ...
                              'Menubar','none', ...
                              'Toolbar','none', ...
                              'NumberTitle','off', ...
                              'WindowStyle','modal', ...
                              'Visible','off', ...
                              'CloseRequestFcn', @(source,event)self.closeRequested(source,event) );
                          
            % Create all the "static" controls, set them up, but don't position them
            self.createFixedControls();
            
            % Do stuff to make ws.most.Controller happy
            self.setHGTagsToPropertyNames_();
            self.updateGuidata_();
            
            % sync up self to model
            self.updateControlProperties();
            self.layout();
            
            % make the figure visible
            %set(self.FigureGH,'Visible','on');            
        end  % constructor
        
        function createFixedControls(self)                          
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window, but doesn't position them
            
            self.YMaxText=...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'Units','pixels', ...
                          'FontName','Tahoma', ...
                          'FontSize',8, ...
                          'HorizontalAlignment','right', ...
                          'String','Y Max:', ...
                          'Callback',@(source,event)(self.controlActuated(source,event)));
            self.YMaxEdit=...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','edit', ...
                          'Units','pixels', ...
                          'FontName','Tahoma', ...
                          'FontSize',8, ...
                          'BackgroundColor','w', ...
                          'HorizontalAlignment','right', ...
                          'Callback',@(source,event)(self.controlActuated(source,event)));
            self.YMaxUnitsText=...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'Units','pixels', ...
                          'FontName','Tahoma', ...
                          'FontSize',8, ...
                          'HorizontalAlignment','left', ...
                          'String','V', ...
                          'Callback',@(source,event)(self.controlActuated(source,event)));

            self.YMinText=...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'Units','pixels', ...
                          'FontName','Tahoma', ...
                          'FontSize',8, ...
                          'HorizontalAlignment','right', ...
                          'String','Y Min:', ...
                          'Callback',@(source,event)(self.controlActuated(source,event)));
            self.YMinEdit=...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','edit', ...
                          'Units','pixels', ...
                          'FontName','Tahoma', ...
                          'FontSize',8, ...
                          'BackgroundColor','w', ...
                          'HorizontalAlignment','right', ...
                          'Callback',@(source,event)(self.controlActuated(source,event)));
            self.YMinUnitsText=...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'Units','pixels', ...
                          'FontName','Tahoma', ...
                          'FontSize',8, ...
                          'HorizontalAlignment','left', ...
                          'String','V', ...
                          'Callback',@(source,event)(self.controlActuated(source,event)));
            
            self.OKButton= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontName','Tahoma', ...
                          'FontSize',8, ...
                          'String','OK', ...
                          'Callback',@(source,event)(self.controlActuated(source,event)), ...
                          'KeypressFcn',@(source,event)(self.keyPressedOnButton(source,event)));
            self.CancelButton= ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'Units','pixels', ...
                          'FontName','Tahoma', ...
                          'FontSize',8, ...
                          'String','Cancel', ...
                          'Callback',@(source,event)(self.controlActuated(source,event)), ...
                          'KeypressFcn',@(source,event)(self.keyPressedOnButton(source,event)));
        end  % function

        function layout(self)
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
            currentPosition=get(self.FigureGH,'Position');
            currentOffset=currentPosition(1:2);
            currentSize=currentPosition(3:4);
            currentUpperY=currentOffset(2)+currentSize(2);
            figurePosition=[currentOffset(1) currentUpperY-figureHeight figureWidth figureHeight];
            set(self.FigureGH,'Position',figurePosition);

            % Layout the edit rows
            yOffsetOfTopRow=bottomSpaceHeight+bottomButtonHeight+heightBetweenEditRowsAndBottomButtonRow+(nRows-1)*(rowHeight+interRowHeight);                        
            yOffsetOfThisRow=yOffsetOfTopRow;
            set(self.YMaxText     ,'Position',[leftSpaceWidth yOffsetOfThisRow labelWidth labelHeight]);
            set(self.YMaxEdit     ,'Position',[editXOffset yOffsetOfThisRow+editTweakHeight editWidth editHeight]);
            set(self.YMaxUnitsText,'Position',[unitsXOffset yOffsetOfThisRow unitsWidth unitsHeight]);
            
            yOffsetOfThisRow=yOffsetOfThisRow-(rowHeight+interRowHeight);            
            set(self.YMinText     ,'Position',[leftSpaceWidth yOffsetOfThisRow labelWidth labelHeight]);
            set(self.YMinEdit     ,'Position',[editXOffset yOffsetOfThisRow+editTweakHeight editWidth editHeight]);
            set(self.YMinUnitsText,'Position',[unitsXOffset yOffsetOfThisRow unitsWidth unitsHeight]);

            % Layout the bottom buttons
            widthOfAllBottomButtons=nBottomButtons*bottomButtonWidth+(nBottomButtons-1)*interBottomButtonSpaceWidth;
            %xOffsetOfLeftButton=(figureWidth-widthOfAllBottomButtons)/2;
            xOffsetOfLeftButton=figureWidth-rightSpaceWidth-widthOfAllBottomButtons;
            
            xOffsetOfThisButton=xOffsetOfLeftButton;
            set(self.OKButton,'Position',[xOffsetOfThisButton bottomSpaceHeight bottomButtonWidth bottomButtonHeight]);
            xOffsetOfThisButton=xOffsetOfThisButton+(bottomButtonWidth+interBottomButtonSpaceWidth);
            set(self.CancelButton,'Position',[xOffsetOfThisButton bottomSpaceHeight bottomButtonWidth bottomButtonHeight]);
        end  % function
        
        function centerOnParentPosition(self,parentPosition)
            originalPosition=get(self.FigureGH,'Position');
            %originalOffset=originalPosition(1:2);
            size=originalPosition(3:4);
            parentOffset=parentPosition(1:2);
            parentSize=parentPosition(3:4);
            newOffset=parentOffset+(parentSize-size)/2;
            newPosition=[newOffset size];
            set(self.FigureGH,'Position',newPosition);
        end
        
        function controlActuated(self,source,event)
            % This makes it so that we don't have all these implicit
            % references to the controller in the closures attached to HG
            % object callbacks.  It also means we can just do nothing if
            % the Controller is invalid, instead of erroring.
            if isequal(source,self.YMaxEdit) || isequal(source,self.YMinEdit) ,
                self.syncOKButtonEnablementFromEditContents();
                return
            end            
            if isempty(self.Controller) || ~isvalid(self.Controller) ,
                return
            end
            self.Controller.controlActuated(source,event);
        end  % function
       
        function keyPressedOnButton(self,source,event)
            % This makes it so the user can press "Enter" when a button has keyboard focus to "press" the button.
            if isequal(event.Key,'return') ,
                self.controlActuated(source,event);
            end
        end  % function
        
        function syncOKButtonEnablementFromEditContents(self)
            import ws.utility.onIff
            yMaxAsString=get(self.YMaxEdit,'String');
            yMinAsString=get(self.YMinEdit,'String');
            yMax=str2double(yMaxAsString);
            yMin=str2double(yMinAsString);
            isEnabled= isfinite(yMax) && isfinite(yMin) && (yMin~=yMax);
            set(self.OKButton,'Enable',onIff(isEnabled));
        end
        
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
    end  % methods

    methods (Access=protected)
        function self=updateImplementation_(self,varargin)
            % Syncs self with model, making no prior assumptions about what
            % might have changed or not changed in the model.
            self.updateControlPropertiesImplementation_();
            %self.layout();
        end
        
        function self=updateControlPropertiesImplementation_(self,varargin)
            import ws.utility.*
            
            % If the model is empty or broken, just return at this point
            model=self.Model;
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
            % Update the relevant controls
            yl=self.Model.YLim;
            unitsString=string(self.Model.YUnits);
            set(self.YMaxEdit     ,'String',sprintf('%0.3g',yl(2)));
            set(self.YMaxUnitsText,'String',unitsString);
            set(self.YMinEdit     ,'String',sprintf('%0.3g',yl(1)));
            set(self.YMinUnitsText,'String',unitsString);            
        end
    end
end  % classdef
