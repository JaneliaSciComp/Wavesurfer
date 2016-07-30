classdef UserCodeManagerFigure < ws.MCOSFigure
    properties
        ClassNameText
        ClassNameEdit        
        %ChooseButton
        InstantiateButton
        %AbortCallsCompleteCheckbox
    end  % properties
    
    methods
        function self=UserCodeManagerFigure(model,controller)
            self = self@ws.MCOSFigure(model,controller);
            set(self.FigureGH, ...
                'Tag','userFunctionsFigureWrapper', ...
                'Units','Pixels', ...
                'Resize','off', ...
                'Name','User Code', ...
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
           %set(self.FigureGH,'Position',[0 0 figureSize]);
           ws.positionFigureOnRootRelativeToUpperLeftBang(self.FigureGH,[30 30+40]);
           
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
            self.ClassNameText = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'String','Class Name:');
            self.ClassNameEdit = ...
                ws.uiedit('Parent',self.FigureGH, ...
                          'HorizontalAlignment','left');
                      
            self.InstantiateButton = ...
                ws.uicontrol('Parent',self.FigureGH, ...
                          'Style','pushbutton', ...
                          'String','Instantiate');
                      
%             self.ChooseButton = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','pushbutton', ...
%                           'String','Choose...');
                      
%             self.AbortCallsCompleteCheckbox = ...
%                 ws.uicontrol('Parent',self.FigureGH, ...
%                           'Style','checkbox', ...
%                           'String','Abort Calls Complete');
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
                    
%                     if ( isequal(get(propertyThing,'Type'),'uicontrol') && isequal(get(propertyThing,'Style'),'edit') ) ,                    
%                         set(propertyThing,'HorizontalAlignment','left');
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
            
            leftPadWidth=10;
            rightPadWidth=10;
            bottomPadHeight=10;
            topPadHeight=10;
            labelWidth=75;
            editWidth=300;
            %typicalHeightBetweenEdits=4;
            %heightBetweenEditBlocks=16;
            
            %widthFromEditToChooseButton=5;
            %chooseButtonWidth = 80 ;

            heightFromInstantiateButtonToBottomEdit=6;
            instantiateButtonHeight = 24 ;
            instantiateButtonWidth = 80 ;
            
            % Just want to use the default edit height
            sampleEditPosition=get(self.ClassNameEdit,'Position');
            editHeight=sampleEditPosition(4);  
            %chooseButtonHeight = editHeight ;

%             % Just want to use the default checkbox height
%             checkboxPosition=get(self.AbortCallsCompleteCheckbox,'Position');
%             checkboxHeight=checkboxPosition(4);
            
            % Compute the figure dimensions
            figureWidth=leftPadWidth + labelWidth + editWidth + rightPadWidth;
            %figureWidth=leftPadWidth+labelWidth+editWidth+ widthFromEditToChooseButton +chooseButtonWidth+rightPadWidth;
            figureHeight= bottomPadHeight + ...
                          editHeight + ...
                          instantiateButtonHeight + ...
                          heightFromInstantiateButtonToBottomEdit + ...
                          topPadHeight;
            
            % The edit and its label
            editXOffset=leftPadWidth+labelWidth;
            
            editYOffset=figureHeight-topPadHeight-editHeight;
            ws.positionEditLabelAndUnitsBang(self.ClassNameText,self.ClassNameEdit,[], ....
                                             editXOffset,editYOffset,editWidth)

%             % "Choose..." button                          
%             chooseButtonXOffset = editXOffset + editWidth + widthFromEditToChooseButton ;
%             chooseButtonYOffset = editYOffset ;
%             set(self.ChooseButton, ...
%                 'Position',[chooseButtonXOffset chooseButtonYOffset chooseButtonWidth chooseButtonHeight]);
                                      
            % Button
            instantiateButtonXOffset = editXOffset + editWidth - instantiateButtonWidth ;
            instantiateButtonYOffset = editYOffset - heightFromInstantiateButtonToBottomEdit - instantiateButtonHeight ;
            set(self.InstantiateButton, ...
                'Position',[instantiateButtonXOffset instantiateButtonYOffset instantiateButtonWidth instantiateButtonHeight]);
                                      
%             % Checkbox
%             checkboxFullExtent=get(self.AbortCallsCompleteCheckbox,'Extent');
%             checkboxExtent=checkboxFullExtent(3:4);
%             checkboxXOffset=editXOffset;
%             checkboxWidth=checkboxExtent(1)+16;  % size of the checkbox itself
%             checkboxYOffset=bottomPadHeight;            
%             set(self.AbortCallsCompleteCheckbox, ...
%                 'Position',[checkboxXOffset checkboxYOffset checkboxWidth checkboxHeight]);
                        
            % We return the figure size
            figureSize=[figureWidth figureHeight];
        end  % function
    end
    
%     methods (Access=protected)
%         function updateImplementation_(self,varargin)
%             model=self.Model;
%             if isempty(model) ,
%                 return
%             end
% 
%             set(self.SweepStartEdit,'String',model.SweepWillStart);
%             set(self.SweepCompleteEdit,'String',model.SweepDidComplete);
%             set(self.SweepAbortEdit,'String',model.SweepDidAbort);            
%             set(self.RunStartEdit,'String',model.RunWillStart);
%             set(self.RunCompleteEdit,'String',model.RunDidComplete);
%             set(self.RunAbortEdit,'String',model.RunDidAbort);            
%             set(self.AbortCallsCompleteCheckbox,'Value',model.AbortCallsComplete);
%             
%             updateControlEnablementImplementation_();
%         end  % function       
%     end  % methods

    methods (Access=protected)
        function updateControlPropertiesImplementation_(self)
            %fprintf('UserCodeManagerFigure::updateControlPropertiesImplementation_\n');
            model=self.Model;
            if isempty(model) ,
                return
            end

            normalBackgroundColor = ws.WavesurferMainFigure.NormalBackgroundColor ;
            warningBackgroundColor = ws.WavesurferMainFigure.WarningBackgroundColor ;
            isClassNameValid = model.IsClassNameValid ;
            backgroundColor = ws.fif(isClassNameValid,normalBackgroundColor,warningBackgroundColor) ;
            set(self.ClassNameEdit, ...
                'String', model.ClassName, ...
                'BackgroundColor', backgroundColor );
            %set(self.AbortCallsCompleteCheckbox,'Value',model.AbortCallsComplete);
            set(self.InstantiateButton, 'String', ws.fif(isempty(model.TheObject), ...
                                                         'Instantiate', ...
                                                         'Reinstantiate') ) ;
        end
    end
    
    methods (Access=protected)
        function updateControlEnablementImplementation_(self,varargin)
            model=self.Model;  % this is the UserCodeManager object
            if isempty(model) || ~isvalid(model) ,
                return
            end
            wavesurferModel=model.Parent;
            if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                return
            end
            isIdle = isequal(wavesurferModel.State,'idle') ;
            set(self.ClassNameEdit, 'Enable', ws.onIff(isIdle) );
            %set(self.ChooseButton, 'Enable', ws.onIff(isIdle) );
            %set(self.InstantiateButton, 'Enable', ws.onIff(isIdle&&~isempty(model.ClassName)) );
            set(self.InstantiateButton, 'Enable', ws.onIff(isIdle) ) ;
        end
    end
    
    methods (Access=protected)
        function updateSubscriptionsToModelEvents_(self)
            % Unsubscribe from all events, then subsribe to all the
            % approprate events of model.  model should be a UserCodeManager subsystem
            %fprintf('UserCodeManagerFigure::updateSubscriptionsToModelEvents_()\n');
            %self.unsubscribeFromAll();
            
            model=self.Model;
            if isempty(model) ,
                return
            end
            wavesurferModel=model.Parent;
            if isempty(wavesurferModel) ,
                return
            end
            
%             model.subscribeMe(self,'PostSet','SweepWillStart','update');
%             model.subscribeMe(self,'PostSet','SweepDidComplete','update');
%             model.subscribeMe(self,'PostSet','SweepDidAbort','update');   
%             model.subscribeMe(self,'PostSet','RunWillStart','update');
%             model.subscribeMe(self,'PostSet','RunDidComplete','update');
%             model.subscribeMe(self,'PostSet','RunDidAbort','update');           
%             model.subscribeMe(self,'PostSet','AbortCallsComplete','update');
            model.subscribeMe(self,'Update','','update');
            
            wavesurferModel.subscribeMe(self,'DidSetState','','updateControlEnablement');
        end  % function                
    end
    
%     methods
%         function controlActuated(self,controlName,source,event)
%             if isempty(self.Controller) ,
%                 % do nothing
%             else
%                 self.Controller.controlActuated(controlName,source,event);
%             end
%         end  % function       
%     end  % methods

end  % classdef
