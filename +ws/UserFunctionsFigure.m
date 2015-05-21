classdef UserFunctionsFigure < ws.MCOSFigure & ws.EventSubscriber
    properties
        ClassNameText
        ClassNameEdit        
        
        AbortCallsCompleteCheckbox
    end  % properties
    
    methods
        function self=UserFunctionsFigure(model,controller)
            self = self@ws.MCOSFigure(model,controller);
            set(self.FigureGH, ...
                'Tag','userFunctionsFigureWrapper', ...
                'Units','Pixels', ...
                'Color',get(0,'defaultUIControlBackgroundColor'), ...
                'Resize','off', ...
                'Name','User Functions', ...
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
            self.ClassNameText = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','text', ...
                          'String','Class Name:');
            self.ClassNameEdit = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','edit');
                      
            self.AbortCallsCompleteCheckbox = ...
                uicontrol('Parent',self.FigureGH, ...
                          'Style','checkbox', ...
                          'String','Abort Calls Complete');
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
                    
                    if ( isequal(get(propertyThing,'Type'),'uicontrol') && isequal(get(propertyThing,'Style'),'edit') ) ,                    
                        set(propertyThing,'HorizontalAlignment','left');
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
            
            import ws.utility.positionEditLabelAndUnitsBang
            
            leftPadWidth=10;
            rightPadWidth=10;
            bottomPadHeight=10;
            topPadHeight=10;
            labelWidth=75;
            editWidth=300;
            typicalHeightBetweenEdits=4;
            heightBetweenEditBlocks=16;
            heightFromCheckboxToBottomEdit=4;
            
            % Just want to use the default edit height
            sampleEditPosition=get(self.ClassNameEdit,'Position');
            editHeight=sampleEditPosition(4);  

            % Just want to use the default checkbox height
            checkboxPosition=get(self.AbortCallsCompleteCheckbox,'Position');
            checkboxHeight=checkboxPosition(4);
            
            % Compute the figure dimensions
            figureWidth=leftPadWidth+labelWidth+editWidth+rightPadWidth;
            figureHeight= bottomPadHeight + ...
                          checkboxHeight + ...
                          heightFromCheckboxToBottomEdit + ...
                          editHeight + ...
                          topPadHeight;
            
            % The edits and their labels
            editXOffset=leftPadWidth+labelWidth;
            
            rowYOffset=figureHeight-topPadHeight-editHeight;
            positionEditLabelAndUnitsBang(self.ClassNameText,self.ClassNameEdit,[], ....
                                          editXOffset,rowYOffset,editWidth)

            % Checkbox
            checkboxFullExtent=get(self.AbortCallsCompleteCheckbox,'Extent');
            checkboxExtent=checkboxFullExtent(3:4);
            checkboxXOffset=editXOffset;
            checkboxWidth=checkboxExtent(1)+16;  % size of the checkbox itself
            checkboxYOffset=bottomPadHeight;            
            set(self.AbortCallsCompleteCheckbox, ...
                'Position',[checkboxXOffset checkboxYOffset checkboxWidth checkboxHeight]);
                        
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
%             set(self.TrialStartEdit,'String',model.TrialWillStart);
%             set(self.TrialCompleteEdit,'String',model.TrialDidComplete);
%             set(self.TrialAbortEdit,'String',model.TrialDidAbort);            
%             set(self.TrialSetStartEdit,'String',model.ExperimentWillStart);
%             set(self.TrialSetCompleteEdit,'String',model.ExperimentDidComplete);
%             set(self.TrialSetAbortEdit,'String',model.ExperimentDidAbort);            
%             set(self.AbortCallsCompleteCheckbox,'Value',model.AbortCallsComplete);
%             
%             updateControlEnablementImplementation_();
%         end  % function       
%     end  % methods

    methods (Access=protected)
        function updateControlPropertiesImplementation_(self)
            %fprintf('UserFunctionsFigure::updateControlPropertiesImplementation_\n');
            model=self.Model;
            if isempty(model) ,
                return
            end

            set(self.ClassNameEdit,'String',model.ClassName);            
            set(self.AbortCallsCompleteCheckbox,'Value',model.AbortCallsComplete);
        end
    end
    
    methods (Access=protected)
        function updateControlEnablementImplementation_(self,varargin)
            model=self.Model;  % this is the UserFunctions object
            if isempty(model) || ~isvalid(model) ,
                return
            end
            wavesurferModel=model.Parent;
            if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                return
            end
            import ws.utility.onIff
            isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
            set(self.ClassNameEdit,'Enable',onIff(isIdle));            
            set(self.AbortCallsCompleteCheckbox,'Enable',onIff(isIdle));
        end
    end
    
    methods (Access=protected)
        function updateSubscriptionsToModelEvents_(self)
            % Unsubscribe from all events, then subsribe to all the
            % approprate events of model.  model should be a UserFunctions subsystem
            %fprintf('UserFunctionsFigure::updateSubscriptionsToModelEvents_()\n');
            %self.unsubscribeFromAll();
            
            model=self.Model;
            if isempty(model) ,
                return
            end
            wavesurferModel=model.Parent;
            if isempty(wavesurferModel) ,
                return
            end
            
%             model.subscribeMe(self,'PostSet','TrialWillStart','update');
%             model.subscribeMe(self,'PostSet','TrialDidComplete','update');
%             model.subscribeMe(self,'PostSet','TrialDidAbort','update');   
%             model.subscribeMe(self,'PostSet','ExperimentWillStart','update');
%             model.subscribeMe(self,'PostSet','ExperimentDidComplete','update');
%             model.subscribeMe(self,'PostSet','ExperimentDidAbort','update');           
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
