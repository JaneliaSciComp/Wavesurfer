classdef UserCodeManagerController < ws.MCOSFigureWithSelfControl
    properties
        ClassNameText
        ClassNameEdit        
        %InstantiateButton
        ReinstantiateButton
    end  % properties
        
    methods
        function self = UserCodeManagerController(model)
            self = self@ws.MCOSFigureWithSelfControl(model);

            % Create the figure
            set(self.FigureGH_, ...
                'Tag','UserCodeManagerFigure', ...
                'Units','Pixels', ...
                'Resize','off', ...
                'Name','User Code', ...
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
           
           % Subscribe to events
           model.subscribeMeToUserCodeManagerEvent(self,'Update','','update');
           model.subscribeMe(self,'DidMaybeSetUserClassName','','update');            
           model.subscribeMe(self,'DidSetState','','updateControlEnablement');
           
           % Make figure visible
           set(self.FigureGH_, 'Visible', 'on') ;           
        end  % constructor
    end
    
%     methods (Access=protected)
%         function didSetModel_(self)
%             self.updateSubscriptionsToModelEvents_();
%             didSetModel_@ws.MCOSFigure(self);
%         end
%     end
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            self.ClassNameText = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','text', ...
                          'String','Class Name:');
            self.ClassNameEdit = ...
                ws.uiedit('Parent',self.FigureGH_, ...
                          'HorizontalAlignment','left');
                      
%             self.InstantiateButton = ...
%                 ws.uicontrol('Parent',self.FigureGH_, ...
%                              'Style','pushbutton', ...
%                              'String','Instantiate');
                      
            self.ReinstantiateButton = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                             'Style','pushbutton', ...
                             'String','Reinstantiate');
                      
%             self.ChooseButton = ...
%                 ws.uicontrol('Parent',self.FigureGH_, ...
%                           'Style','pushbutton', ...
%                           'String','Choose...');
                      
%             self.AbortCallsCompleteCheckbox = ...
%                 ws.uicontrol('Parent',self.FigureGH_, ...
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

            heightFromButtonRowToBottomEdit=6;            
            reinstantiateButtonHeight = 24 ;
            reinstantiateButtonWidth = 80 ;
            %widthBetweenButtons = 8 ;
            
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
                          reinstantiateButtonHeight + ...
                          heightFromButtonRowToBottomEdit + ...
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
                                      
%             % Button
%             instantiateButtonXOffset = editXOffset + editWidth - reinstantiateButtonWidth ;
%             instantiateButtonYOffset = editYOffset - heightFromInstantiateButtonToBottomEdit - reinstantiateButtonHeight ;
%             set(self.InstantiateButton, ...
%                 'Position',[instantiateButtonXOffset instantiateButtonYOffset reinstantiateButtonWidth reinstantiateButtonHeight]);

            % Other button
%             reinstantiateButtonWidth = reinstantiateButtonWidth ;
%             reinstantiateButtonHeight = reinstantiateButtonHeight ;
            reinstantiateButtonXOffset = editXOffset + editWidth - reinstantiateButtonWidth ;
            reinstantiateButtonYOffset = editYOffset - heightFromButtonRowToBottomEdit - reinstantiateButtonHeight ;
            set(self.ReinstantiateButton, ...
                'Position',[reinstantiateButtonXOffset reinstantiateButtonYOffset reinstantiateButtonWidth reinstantiateButtonHeight]);
                                      
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
%             model=self.Model_;
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
            wsModel = self.Model_ ;
            if isempty(wsModel) ,
                return
            end

            normalBackgroundColor = ws.normalBackgroundColor() ;
            warningBackgroundColor = ws.warningBackgroundColor() ;
            isClassNameValid = wsModel.IsUserClassNameValid ;
            backgroundColor = ws.fif(isClassNameValid,normalBackgroundColor,warningBackgroundColor) ;
            set(self.ClassNameEdit, ...
                'String', wsModel.UserClassName, ...
                'BackgroundColor', backgroundColor );
%             set(self.InstantiateButton, 'String', ws.fif(isempty(model.TheObject), ...
%                                                          'Instantiate', ...
%                                                          'Reinstantiate') ) ;
%             set(self.InstantiateButton, 'Visible', ws.fif(isempty(model.TheObject), ...
%                                                          'on', ...
%                                                          'off') ) ;
%             set(self.ReinstantiateButton, 'Visible', ws.fif(~isempty(model.TheObject), ...
%                                                             'on', ...
%                                                             'off') ) ;
        end
    end
    
    methods (Access=protected)
        function updateControlEnablementImplementation_(self,varargin)
%             model=self.Model_;  % this is the UserCodeManager object
%             if isempty(model) || ~isvalid(model) ,
%                 return
%             end
            wavesurferModel = self.Model_ ;
            if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                return
            end
            isIdle = isequal(wavesurferModel.State,'idle') ;
            set(self.ClassNameEdit, 'Enable', ws.onIff(isIdle) );
            %set(self.ChooseButton, 'Enable', ws.onIff(isIdle) );
            %set(self.InstantiateButton, 'Enable', ws.onIff(isIdle&&~isempty(model.ClassName)) );
            %set(self.InstantiateButton, 'Enable', ws.onIff(isIdle) ) ;
            set(self.ReinstantiateButton, 'Enable', ws.onIff(isIdle&&wavesurferModel.DoesTheUserObjectMatchTheUserClassName) ) ;
        end
    end
    
%     methods (Access=protected)
%         function updateSubscriptionsToModelEvents_(self)
%             % Unsubscribe from all events, then subsribe to all the
%             % approprate events of model.  model should be a UserCodeManager subsystem
%             %fprintf('UserCodeManagerFigure::updateSubscriptionsToModelEvents_()\n');
%             %self.unsubscribeFromAll();
%             
%             wsModel = self.Model_ ;
%             if isempty(wsModel) ,
%                 return
%             end
%             %userCodeManager = wavesurferModel.UserCodeManager ;
%             
% %             model.subscribeMe(self,'PostSet','SweepWillStart','update');
% %             model.subscribeMe(self,'PostSet','SweepDidComplete','update');
% %             model.subscribeMe(self,'PostSet','SweepDidAbort','update');   
% %             model.subscribeMe(self,'PostSet','RunWillStart','update');
% %             model.subscribeMe(self,'PostSet','RunDidComplete','update');
% %             model.subscribeMe(self,'PostSet','RunDidAbort','update');           
% %             model.subscribeMe(self,'PostSet','AbortCallsComplete','update');
%             wsModel.subscribeMeToUserCodeManagerEvent(self,'Update','','update');
%             wsModel.subscribeMe(self,'DidMaybeSetUserClassName','','update');            
%             wsModel.subscribeMe(self,'DidSetState','','updateControlEnablement');
%         end  % function                
%     end
    
%     methods
%         function controlActuated(self,controlName,source,event)
%             if isempty(self.Controller) ,
%                 % do nothing
%             else
%                 self.Controller.controlActuated(controlName,source,event);
%             end
%         end  % function       
%     end  % methods

%     methods
%         function self = UserCodeManagerController(wavesurferController, wavesurferModel)
%             % Call the superclass constructor
%             %userFunctionsModel=wavesurferModel.UserCodeManager;
%             self = self@ws.Controller(wavesurferController,wavesurferModel);
% 
%             % Create the figure, store a pointer to it
%             fig = ws.UserCodeManagerFigure(wavesurferModel,self) ;
%             self.Figure_ = fig ;                        
%         end  % constructor
%     end  % methods block
    
    methods
        function ClassNameEditActuated(self,source,event) %#ok<INUSD>
            newString = get(source,'String') ;
            %ws.Controller.setWithBenefits(self.Model_,'ClassName',newString);
            self.Model_.do('set', 'UserClassName', newString) ;
        end

%         function InstantiateButtonActuated(self,source,event) %#ok<INUSD>
%             % This doesn't actually do anything.  It's there just to give
%             % the user something obvious to do after they edit the
%             % ClassName editbox.  The edit box losing keyboard focus
%             % triggers the ClassNameEditActuated callback, which
%             % instantiates a model object.
%             
%             %self.Model_.do('instantiateUserObject') ;            
%         end
        
        function ReinstantiateButtonActuated(self,source,event) %#ok<INUSD>
            self.Model_.do('reinstantiateUserObject') ;            
        end
        
%         function ChooseButtonActuated(self,source,event) %#ok<INUSD>
%             mAbsoluteFileName = uigetdir(self.Model_.DataFileLocation, 'Choose User Class M-file...');
%             if ~isempty(mAbsoluteFileName) ,
%                 self.Model_.DataFileLocation = mAbsoluteFileName;
%             end            
%         end
    end
    
    methods (Access=protected)
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
                self.hide() ;
            end
        end        
    end  % protected methods block
    
end
