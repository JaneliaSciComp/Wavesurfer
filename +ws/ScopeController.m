classdef ScopeController < ws.Controller & ws.EventSubscriber
    
    properties
        MyYLimDialogController=[]
    end

    methods
        function self=ScopeController(wavesurferController,scopeModel)
            %self = self@ws.Controller(wavesurferController,scopeModel,{},figureClassNames);  % as third arg, should start out hidden
            self = self@ws.Controller(wavesurferController, scopeModel, {'scopeFigureWrapper'});

            %scopeModel.Parent.subscribeMe(self,'PostSet','Enabled','displayEnablementMayHaveChanged');
            %  We want the scopes to be made visible in a well-defined
            %  order, so this is now handled by the main figure controller
            scopeModel.subscribeMe(self,'WindowVisibilityNeedsToBeUpdated','','updateWindowVisibility');            
            % Next four lines allow user to zoom with the default figure
            % controls, and ensure that the ScopeModel stays synchronized
            %model.subscribeMe(self,'XLim','PostSet','didSetXLimInModel');
            %self.Figure.subscribeMe(self,'XLim','PostSet','didSetXLimInView');
            display=scopeModel.Parent;
            if ~isempty(display) ,
                display.subscribeMe(self,'DidSetEnabled','','displayEnablementMayHaveChanged');
            end
            scopeFigure=self.Figure;
%             scopeFigure.subscribeMe(self,'PostSet','XLim','didSetXLimInView');           
%             scopeFigure.subscribeMe(self,'PostSet','YLim','didSetYLimInView');           
            scopeFigure.subscribeMe(self,'DidSetXLim','','didSetXLimInView');           
            scopeFigure.subscribeMe(self,'DidSetYLim','','didSetYLimInView');           
            self.IsSuiGeneris=false;  % Multiple instances of this controller can coexist in the same Wavesurfer session
            scopeFigure.syncTitleAndTagsToModel();  % Shouldn't this happen somewhere else?
            self.updateWindowVisibility();
              % Need to update the window visibility to match Display
              % subsystem enablement and the per-scope visibility setting.
        end
        
        function delete(self)
             self.MyYLimDialogController=[];
        end
        
        function showFigure(self)
            % We override this method and interpret it as a request to show
            % the window, but the actual showing of the window is left to
            % the showFigureForReals() method.  Here we update the model,
            % and that indirectly causes showFigureForReals to get called.
            %
            % There's only one ScopeFigure per ScopeController, so windows
            % is ignored
            if isempty(self) || ~isvalid(self) ,
                return
            end
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            if isempty(self.Model.Parent) || ~isvalid(self.Model.Parent) ,
                return
            end
            
            display=self.Model.Parent;
            display.Scopes(display.Scopes==self.Model).IsVisibleWhenDisplayEnabled=true;
%             self.showFigureForReals();
%             self.broadcast('ScopeVisibilitySetDirectlyByScopeController');
        end
        
        function hideFigure(self)
            % We override this method and interpret it as a request to hide
            % the window, but the actual hiding of the window is left to
            % the hideFigureForReals() method.  Here we update the model,
            % and that indirectly causes hideFigureForReals to get called.

            % There's only one ScopeFigure per ScopeController, so windows
            % is ignored
            if isempty(self) || ~isvalid(self) ,
                return
            end       
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            if isempty(self.Model.Parent) || ~isvalid(self.Model.Parent) ,
                return
            end
            
            display=self.Model.Parent;
            display.Scopes(display.Scopes==self.Model).IsVisibleWhenDisplayEnabled=false;
%             self.hideFigureForReals();
%             self.broadcast('ScopeVisibilitySetDirectlyByScopeController');
        end
        
        function showFigureForReals_(self)
            % Low-level method that actually makes the window visible            
%             isValid=isvalid(self.Figure);
%             validFigure=self.Figure(isValid);
%             arrayfun(@(w)set(w, 'Visible', 'on'), validFigure);
            
            self.Figure.show();
        end  % method
        
        function hideFigureForReals_(self)
            % Low-level method that actually makes the window invisible
%             isValid=isvalid(self.Figure);
%             validFigure=self.Figure(isValid);
%             arrayfun(@(w)set(w, 'Visible', 'off'), validFigure);

            self.Figure.hide();
        end  % method
        
        function setYLimTightToDataButtonActuated(self)
            self.Model.setYAxisLimitsTightToData();
            % View update happens automatically
        end  % method       
        
        function setYLimTightToDataLockedButtonActuated(self)
            self.Model.toggleAreYLimitsLockedTightToData();
            % View update happens automatically
        end  % method       
        
        function displayEnablementMayHaveChanged(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            % Called to advise the controller that it may need to show/hide
            % the window.
            % Currently, calls self.updateWindowVisibility(), which queries the WavesurferModel.Display to see whether
            % the window should be visible, and adjusts accordingly.
            self.updateWindowVisibility();
        end  % method
        
        function updateWindowVisibility(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            % Queries the WavesurferModel.Display and the scope model to see whether
            % the window should be visible, and adjusts accordingly.
            if isempty(self) || ~isvalid(self) ,
                return
            end
            if isempty(self.Model) || ~isvalid(self.Model) ,
                return
            end
            if isempty(self.Model.Parent) || ~isvalid(self.Model.Parent) ,
                return
            end
            display=self.Model.Parent;
            iScope=find(display.Scopes==self.Model);
            if isscalar(iScope) ,
                shouldBeVisible=(display.Enabled && display.Scopes(iScope).IsVisibleWhenDisplayEnabled);
                if shouldBeVisible ,
                    self.showFigureForReals_();
                else
                    self.hideFigureForReals_();
                end
            end            
        end  % method
        
        function didSetXLimInView(self,varargin)
            %fprintf('ScopeController::didSetXLimInView()\n');
            xlimInFigure=self.Figure.XLim;
            xLowInFigure=xlimInFigure(1);
            xHighInFigure=xlimInFigure(2);
            xlimInModel=self.Model.XLim;
            xLowInModel=xlimInModel(1);
            xHighInModel=xlimInModel(2);
            % Check if this is a real change to avoid infinite loops
            if xLowInFigure~=xLowInModel || xHighInFigure~=xHighInModel ,
                self.Model.XLim=xlimInFigure;
            end
        end  % method
        
        function didSetYLimInView(self,varargin)
            %fprintf('ScopeController::didSetYLimInView()\n');
            ylimInFigure=self.Figure.YLim;
            yLowInFigure=ylimInFigure(1);
            yHighInFigure=ylimInFigure(2);
            ylimInModel=self.Model.YLim;
            yLowInModel=ylimInModel(1);
            yHighInModel=ylimInModel(2);
            % Check if this is a real change to avoid infinite loops
            if yLowInFigure~=yLowInModel || yHighInFigure~=yHighInModel ,
                self.Model.YLim=ylimInFigure;
            end
        end  % method
        
        function controlActuated(self,controlName,source,event)  %#ok<INUSD>
            %figureObject=self.Figure;
            try
                switch controlName ,
                    case 'SetYLimTightToDataButtonGH' ,
                        self.setYLimTightToDataButtonActuated();
                    case 'SetYLimTightToDataLockedButtonGH' ,
                        self.setYLimTightToDataLockedButtonActuated();
                    case 'YLimitsMenuItemGH' ,
                        self.yLimitsMenuItemActuated();
                    case 'InvertColorsMenuItemGH' ,
                        self.invertColorsMenuItemActuated();
                    case 'DoShowButtonsMenuItemGH' ,
                        self.doShowButtonsMenuItemActuated();
                    case 'ShowGridMenuItemGH' ,
                        self.showGridMenuItemActuated();
                    case {'YZoomInButtonGH','YZoomInMenuItemGH'} ,
                        self.zoomInButtonPressed();
                    case {'YZoomOutButtonGH','YZoomOutMenuItemGH'} ,
                        self.zoomOutButtonPressed();
                    case {'YScrollUpButtonGH','YScrollUpMenuItemGH'} ,
                        self.scrollUpButtonPressed();
                    case {'YScrollDownButtonGH','YScrollDownMenuItemGH'} ,
                        self.scrollDownButtonPressed();
                end  % switch
            catch me
%                 isInDebugMode=~isempty(dbstatus());
%                 if isInDebugMode ,
%                     rethrow(me);
%                 else
                    errordlg(me.message,'Error','modal');
%                 end
            end
        end  % method
        
        function yLimitsMenuItemActuated(self)
            self.MyYLimDialogController=[];  % if not first call, this should cause the old controller to be garbage collectable
            self.MyYLimDialogController=...
                ws.YLimDialogController(self,self.Model,get(self.Figure,'Position'));
        end  % method        
        
        function showGridMenuItemActuated(self)
            self.Model.toggleIsGridOn();
        end  % method        

        function doShowButtonsMenuItemActuated(self)
            self.Model.toggleDoShowButtons();
        end  % method        

        function invertColorsMenuItemActuated(self)
            self.Model.toggleAreColorsNormal();
        end  % method        

        function zoomInButtonPressed(self)
            self.Model.zoomIn();
        end
        
        function zoomOutButtonPressed(self)
            self.Model.zoomOut();
        end
        
        function scrollUpButtonPressed(self)
            self.Model.scrollUp();
        end
        
        function scrollDownButtonPressed(self)
            self.Model.scrollDown();
        end
        
    end  % public methods block

    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This method is inhierited from AbstractController, and is
            % called after the user indicates she wants to close the
            % window.  Returns true if the window should _not_ close, false
            % if it should go ahead and close.
            
            % If acquisition is happening, ignore the close window request
            wavesurferModel = ws.utility.getSubproperty(self,'Model','Parent','Parent') ;
            if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,                
                isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
                if isIdle ,
                    shouldStayPut=false;
                else                 
                    shouldStayPut=true;
                end
            else
                shouldStayPut=false;                
            end
        end  % function
    end % protected methods block
    
    methods (Access=protected)
        function layoutOfWindowsInClassButOnlyForThisWindow = encode_window_layout(self)
            window = self.Figure;
            layoutOfWindowsInClassButOnlyForThisWindow = struct();
            tag = get(window, 'Tag');
            layoutOfWindowsInClassButOnlyForThisWindow.(tag).Position = get(window, 'Position');
            isVisible=self.Model.IsVisibleWhenDisplayEnabled;
            layoutOfWindowsInClassButOnlyForThisWindow.(tag).IsVisibleWhenDisplayEnabled = isVisible;
            if ws.most.gui.AdvancedPanelToggler.isFigToggleable(window)
                layoutOfWindowsInClassButOnlyForThisWindow.(tag).Toggle = ws.most.gui.AdvancedPanelToggler.saveToggleState(window);
            else
                layoutOfWindowsInClassButOnlyForThisWindow.(tag).Toggle = [];
            end
        end
        
        function decode_window_layout(self, layoutOfWindowsInClass)
            window = self.Figure;
            tag = get(window, 'Tag');
            if isfield(layoutOfWindowsInClass, tag)
                thisWindowLayout = layoutOfWindowsInClass.(tag);

                if isfield(thisWindowLayout, 'Toggle')
                    toggleState = thisWindowLayout.Toggle;
                else
                    % This branch is only to support legacy .usr files that
                    % don't have up-to-date layout info.
                    toggleState = [];
                end

                if ~isempty(toggleState)
                    assert(ws.most.gui.AdvancedPanelToggler.isFigToggleable(window));

                    ws.most.gui.AdvancedPanelToggler.loadToggleState(window,toggleState);

                    % gui is toggleable; for position, only set x- and
                    % y-pos, not width and height, as those are controlled
                    % by toggle-state.
                    pos = get(window,'Position');
                    pos(1:2) = thisWindowLayout.Position(1:2);
                    set(window,'Position',pos);
                else
                    % Not a toggleable GUI.
                    set(window, 'Position', thisWindowLayout.Position);
                end

                if isfield(thisWindowLayout,'IsVisibleWhenDisplayEnabled') ,
                    %set(window, 'Visible', layoutInfo.Visible);
                    % Have to do this at the controller level, so that the
                    % WavesurferModel gets updated.
                    model=self.Model;
                    if ~isempty(model) ,
                        model.IsVisibleWhenDisplayEnabled=thisWindowLayout.IsVisibleWhenDisplayEnabled;
                    end
                end
            end
        end  % function

    end  % protected methods block
    
    properties (SetAccess=protected)
       propBindings = struct();
    end
    
end  % classdef
