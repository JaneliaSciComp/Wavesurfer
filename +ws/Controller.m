classdef Controller < handle

    properties (Dependent=true, SetAccess=immutable)
        Parent
        Model
        Figure  % the associated figure object (i.e. a handle handle, not a hande graphics handle)
    end
    
    properties (Access=protected)
        Parent_
        Model_
        Figure_
        HideFigureOnClose_ = true  % By default do not destroy the window when closed, just hide
%         IsSuiGeneris_ = true  
%             % Whether or not multiple instances of the controller class can
%             % exist at a time. If true, only one instance of the controller
%             % class can exist at a time.  If false, multiple instances of
%             % the controller class can exist at a time. Currently, Most of
%             % our controllers are sui generis, so true is a good default.
%             % (Making this abstract creates headaches.  Ditto making
%             % SetAccess=immutable, or Constant=true, all of which would
%             % arguably make sense.)  You should only set this in the
%             % constructor, and not change it for the lifetime of the
%             % object.  Also, it should have the same value for all
%             % instances of the class.
    end
        
    methods
        function self = Controller(parent,model)        
            %self = self@ws.most.Controller(model,varargin{:});
            self.Parent_ = parent ;
            self.Model_ = model ;
            %self.Figure_ = figureObject ;
            %figureObject=self.Figure;
            %figureGH=figureObject.FigureGH;
            %set(figureGH,'CloseRequestFcn',@(source,event)(figureObject.closeRequested(source,event)));            
            %self.initialize();            
        end  % function
        
%         function initialize(self)  %#ok<MANU>
%         end
        
        function delete(self)
            %fprintf('ws.Controller::delete()\n');
            if ~isempty(self.Figure) && isvalid(self.Figure) ,
                self.Figure.deleteFigureGH() ;
            end
            %self.deleteFigure_();
            self.Model_ = [] ;
            self.Parent_=[];            
        end
        
        function output=get.Figure(self)
            output = self.Figure_ ;
%             figureGH=self.hGUIsArray;  % should be a scalar
%             if isscalar(figureGH) && ishghandle(figureGH) ,
%                 handles=guidata(figureGH);
%                 if ~isempty(handles) && isfield(handles,'FigureObject') ,
%                     output=handles.FigureObject;
%                 else
%                     output=[];                    
%                 end
%             else
%                 output=[];
%             end
        end  % function        

        function output=get.Parent(self)
            output=self.Parent_;
        end
        
        function output=get.Model(self)
%             output=self.hModel;
            output = self.Model_ ;
        end
        
        function self=setAreUpdatesEnabledForFigure(self,newValue)
            self.Figure.AreUpdatesEnabled = newValue ;
        end        
    end
    
    methods
        function updateFigure(self)             
            self.Figure.update();
        end
        
        function showFigure(self)             
            % This exists so that it can optionally be overridden for some
            % controller classes, like ws.ScopeController
            self.Figure.show();
        end
        
        function hideFigure(self)
            % This exists so that it can optionally be overridden for some
            % controller classes, like ws.ScopeController
            self.Figure.hide();
        end
        
        function quittingWavesurfer(self)   
            self.deleteFigureGH();
        end  % function
        
        function deleteFigureGH(self)   
            self.tellFigureToDeleteFigureGH_();
        end  % function
        
        function raiseFigure(self)
            self.Figure.raise();
        end            
    end  % methods
            
    methods (Access = protected)
%         function deleteFigure_(self)
%             % Destroy the window rather than just hide it.
%             figure=self.Figure;
%             if ~isempty(figure) && isvalid(figure) ,
%                 figure.delete();
%             end
%         end
        
        function tellFigureToDeleteFigureGH_(self)
            figure=self.Figure;
            if ~isempty(figure) && isvalid(figure) ,
                figure.deleteFigureGH();
            end
        end            
    end  % methods
    
    methods (Access = protected, Sealed = true)
        function layoutForAllWindows = addThisWindowLayoutToLayout(self, layoutForAllWindows)
            % Add layout info for this window (just this one window) to
            % a struct representing the layout of all windows in the app
            % session.
           
            % Framework specific transformation.
            thisWindowLayout = self.encodeWindowLayout_();
            
            layoutVarNameForClass = ws.Controller.layoutVariableNameFromControllerClassName(class(self));
            layoutForAllWindows.(layoutVarNameForClass)=thisWindowLayout;
        end
    end

%     methods (Access = protected)
%         function out = encodeWindowLayout_(self) %#ok<MANU>
%             % Subclasses can encode size, position, visibility, and other features.  Current
%             % implementations use a struct, but the variable returned from this function can
%             % be anything, as long as it can be saved and loaded from a MAT file. Subclasses
%             % will get the variable back in the exact same state in the decode method.
%             % These methods do not have to be overriden in framework specific subclasses if
%             % saving state is not desired or applicable.
%             out = struct();
%         end
%     end
        
    methods (Access = protected)
        function layout = encodeWindowLayout_(self)
            fig = self.Figure ;
            position = get(fig, 'Position') ;
            visible = get(fig, 'Visible') ;
            if ischar(visible) ,
                isVisible = strcmpi(visible,'on') ;
            else
                isVisible = visible ;
            end
            layout = struct('Position', {position}, 'IsVisible', {isVisible}) ;
        end
    end
    
    methods (Access = protected)
        function decodeWindowLayout(self, layoutOfWindowsInClass, monitorPositions)
            figureObject = self.Figure ;
            fieldNames = fieldnames(layoutOfWindowsInClass) ;
            if isscalar(fieldNames) ,
                % This means it's an older protocol file, with the layout
                % stored in a single field with a sometimes-weird name.
                % But the name doesn't really matter.
                fieldName = fieldNames{1} ;
                layoutOfThisWindow = layoutOfWindowsInClass.(fieldName) ;
                isVisibleFieldName = 'Visible' ;
            else
                % This means it's a newer protocol file, with (hopefully)
                % two fields, Position and IsVisible.
                layoutOfThisWindow = layoutOfWindowsInClass ;
                isVisibleFieldName = 'IsVisible' ;
            end
            if isfield(layoutOfThisWindow, 'Position') ,
                rawPosition = layoutOfThisWindow.Position ;
                set(figureObject, 'Position', rawPosition);
                figureObject.constrainPositionToMonitors(monitorPositions) ;
            end
            if isfield(layoutOfThisWindow, isVisibleFieldName) ,
                set(figureObject, 'Visible', layoutOfThisWindow.(isVisibleFieldName)) ;
            end
        end
    end
    
    methods
        function windowCloseRequested(self, source, event)
            % Frameworks that windows with close boxes or similar decorations should set the
            % callback to this method when they take control of the window.  For example,
            % the CloseRequestFcn for HG windows, or the Closing event in WPF.
            %
            % It is also likely the right choice for callbacks/actions associated with close
            % or quit menu items, etc.
            
            % This method uses three methods that should be overriden by framework specific
            % subclasses to perform either the hide or a true close.  A fourth method
            % (shouldWindowStayPutQ) is a hook for application specific controllers to
            % intercept the close (or hide) attempt and cancel it.  By default it simply
            % returns false to continue.
            
            shouldStayPut = self.shouldWindowStayPutQ(source, event);
            
            if shouldStayPut ,
                % Do nothing
            else
                if self.HideFigureOnClose_ ,
                    % This is not simply a call to hide() because some frameworks will require
                    % modification to the evt object, other actions to actually cancel an
                    % in-progress close event.
                    self.hideFigure();
                else
                    % Actually release the window.  This may actual result in
                    % active deletion of the controller so care should be taken in adding any code
                    % to this method after this call.
                    self.deleteFigureGH();
                end
            end
        end
    end

    % This method is expected to be overriden by actual application controller implementations.
    methods (Access = protected)
%         function out = shouldWindowStayPutQ(self, source, event) %#ok<INUSD>
%             % This method is a hook for application specific controllers to intercept the
%             % close (or hide) attempt and cancel it.  Controllers should return false to
%             % continue the close/hide or true to cancel.
%             out = false;
%         end
        
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This is called after the user indicates she wants to close
            % the window.  Returns true if the window should _not_ close,
            % false if it should go ahead and close.
            model = self.Model ;
            if isempty(model) || ~isvalid(model) ,
                shouldStayPut = false ;
            else
                shouldStayPut = ~model.isRootIdleSensuLato() ;
            end
        end  % function
        
    end
    
    methods (Access = protected)
        % These protected methods will generally only be overriden by implementations
        % for specific frameworks, such as an HG Controller base class.  It is not
        % expected that application controllers that further subclass for a specific
        % window in an application will ever need to modify these methods, and they
        % should generally me marked as (Sealed = true) in the framework specific
        % controllers such as the HG controller.
        
%         function createWindows(self, guiNames, guiNamesInvisible, model) %#ok<INUSD>
%             % Framework specific implementations should load a fig file or create a WPF
%             % window or whatever is appropriate.  A controller base class that does not use
%             % windows (e.g., one specifically for WPF user controls rather than windows -
%             % though it does not exist currently) may do nothing here.
%         end
        
%         function out = get_main_window(self) %#ok<MANU>
%             % Framework specific subclasses can implement this method to return a "primary"
%             % window. This may simply be the first window or the only window.  The reason it
%             % is left to the framework specific subclasses is that they may store references
%             % to their list of windows differently, such as array vs. cell array, depending
%             % on their requirements.
%             out = [];
%         end
        
%         function modifyEventIfNeededToCancelClose(self, src, evt) %#ok<INUSD>
%             % Perform any action required to cancel a window close event.  May be a no-op
%             % (e.g., for an HG controller) or require modification of the event object (see
%             % the WPF controller for an example).
%         end
        
%         function modifyEventIfNeededAndHideWindow(self, src, evt) %#ok<INUSD>
%             % Perform any action required to hide a window rather than close it.
%         end
        
%         function deleteWindows(self) %#ok<MANU>
%             % Should actually release/delete any handles or objects that define the window
%             % object.  This is essentially for the framework specific delete() method code
%             % for windows and associated resources.
%         end
    end  % protected methods that are designed to be optionally overridden
    
    methods
        function exceptionMaybe = controlActuated(self, controlName, source, event, varargin)            
            % The gateway for all UI-initiated commands.  exceptionMaybe is
            % an empty cell array if all goes well.  If something goes
            % awry, we raise a dialog, and then return the exception in a
            % length-one cell array.  But note that upon return, the user
            % has already been notified that an exception occurred.  Still,
            % subclasses may want to call this method, and may want to know
            % if anything went wrong during execution.
            try
                if isempty(source) ,
                    % This enables us to easily do fake actuations
                    methodName=[controlName 'Actuated'] ;
                    if ismethod(self,methodName) ,
                        self.(methodName)(source,event,varargin{:}) ;
                    end
                else                    
                    type=get(source,'Type') ;
                    if isequal(type,'uitable') ,
                        if isfield(event,'EditData') || isprop(event,'EditData') ,  % in older Matlabs, event is a struct, in later, an object
                            methodName=[controlName 'CellEdited'] ;
                        else
                            methodName=[controlName 'CellSelected'] ;
                        end
                        if ismethod(self,methodName) ,
                            self.(methodName)(source,event,varargin{:}) ;
                        end                    
                    elseif isequal(type,'uicontrol') || isequal(type,'uimenu') ,
                        methodName=[controlName 'Actuated'] ;
                        if ismethod(self,methodName) ,
                            self.(methodName)(source,event,varargin{:}) ;
                        end
                    else
                        % odd --- just ignore
                    end
                end
                exceptionMaybe = {} ;
            catch exception
                if isequal(exception.identifier,'ws:invalidPropertyValue') ,
                    % ignore completely, don't even pass on to output
                    exceptionMaybe = {} ;
                else
                    self.raiseDialogOnException_(exception) ;
                    exceptionMaybe = { exception } ;
                end
            end
        end  % function
        
        function fakeControlActuatedInTest(self, controlName, varargin)            
            % This is like controlActuated(), but used when you want to
            % fake the actuation of a control, often in a testing script.
            % So, for instance, if only ws:warnings occur, if prints them,
            % rather than showing a dialog box.  Also, this lets
            % non-warning errors (including ws:invalidPropertyValue)
            % percolate upward, unlike controlActuated().  Also, this
            % always calls [controlName 'Actuated'], rather than using
            % source.Type to determine the method name.  That's becuase
            % there's generally no real source for fake actuations.
            try
                methodName=[controlName 'Actuated'] ;
                if ismethod(self,methodName) ,
                    source = [] ;
                    event = [] ;
                    self.(methodName)(source,event,varargin{:}) ;
                end
            catch exception
                indicesOfWarningPhrase = strfind(exception.identifier,'ws:warningsOccurred') ;
                isWarning = (~isempty(indicesOfWarningPhrase) && indicesOfWarningPhrase(1)==1) ;
                if isWarning ,
                    fprintf('A warning-level exception was thrown.  Here is the report for it:\n') ;
                    disp(exception.getReport()) ;
                    fprintf('(End of report for warning-level exception.)\n\n') ;
                else
                    rethrow(exception) ;
                end
            end
        end  % function
    end  % public methods block
    
    methods (Access=protected)        
        function raiseDialogOnException_(self, exception)
            model = self.Model ;
            if ~isempty(model) ,
                model.resetReadiness() ;  % don't want the spinning cursor after we show the error dialog
            end
            indicesOfWarningPhrase = strfind(exception.identifier,'ws:warningsOccurred') ;
            isWarning = (~isempty(indicesOfWarningPhrase) && indicesOfWarningPhrase(1)==1) ;
            if isWarning ,
                dialogContentString = exception.message ;
                dialogTitleString = ws.fif(length(exception.cause)<=1, 'Warning', 'Warnings') ;
            else
                if isempty(exception.cause)
                    dialogContentString = exception.message ;
                    dialogTitleString = 'Error' ;
                else
                    primaryCause = exception.cause{1} ;
                    if isempty(primaryCause.cause) ,
                        dialogContentString = sprintf('%s:\n%s',exception.message,primaryCause.message) ;
                        dialogTitleString = 'Error' ;
                    else
                        secondaryCause = primaryCause.cause{1} ;
                        dialogContentString = sprintf('%s:\n%s\n%s', exception.message, primaryCause.message, secondaryCause.message) ;
                        dialogTitleString = 'Error' ;
                    end
                end            
            end
            ws.errordlg(dialogContentString, dialogTitleString, 'modal') ;                
        end  % method
    end  % protected methods block
    
    methods (Static=true)
        function setWithBenefits(object,propertyName,newValue)
            % Do object.(propertyName)=newValue, but catch any
            % ws:invalidPropertyValue exception generated.  If that
            % exception is generated, just ignore it.  The model is
            % responsible for broadcasting an Update event in the case of a
            % attempt to set an invalid value, which should cause the
            % invalid value to be cleared from the view, and replaced with
            % the preexisting value.
            try 
                object.(propertyName)=newValue;
            catch exception
                if isequal(exception.identifier,'ws:invalidPropertyValue') ,
                    % Ignore it
                else
                    rethrow(exception);
                end
            end
        end  % function
        
        function monitorPositions = getMonitorPositions(doForceForOldMatlabs)
            % Get the monitor positions for the current monitor
            % configuration, dealing with brokenness in olf Matlab versions
            % as best we can.
            
            % Deal with args
            if ~exist('doForceForOldMatlabs', 'var') || isempty(doForceForOldMatlabs) ,
                doForceForOldMatlabs = false ;
            end
            
            if verLessThan('matlab','8.4') ,
                % MonitorPositions is broken in this version, so just get
                % primary screen positions.
                
                if doForceForOldMatlabs ,
                    % Get the (primary) screen size in pels
                    originalScreenUnits = get(0,'Units') ;    
                    set(0,'Units','pixels') ;    
                    monitorPositions = get(0,'ScreenSize') ;
                    set(0,'Units',originalScreenUnits) ;
                else
                    monitorPositions = [-1e12 -1e12 2e12 2e12] ;  
                      % a huge screen, than any window will presumably be within, thus the window will not be moved
                      % don't want to use infs b/c topOffset = offset +
                      % size, which for infs would be topOffset == -inf +
                      % inf == nan.
                end                    
            else
                % This version has a working MonitorPositions, so use that.

                % Get the monitor positions in pels
                originalScreenUnits = get(0,'Units') ;    
                set(0,'Units','pixels') ;    
                monitorPositions = get(0,'MonitorPositions') ;  % 
                set(0,'Units',originalScreenUnits) ;
                %monitorPositions = bsxfun(@plus, monitorPositionsAlaMatlab, [-1 -1 0 0]) ;  % not-insane style
            end
        end  % function        
    end  % static methods block
    
    methods (Access=protected, Sealed = true)
        function extractAndDecodeLayoutFromMultipleWindowLayout_(self, multiWindowLayout, monitorPositions)
            % Find a layout that applies to whatever subclass of controller
            % self happens to be (if any), and use it to position self's
            % figure's window.            
            if isscalar(multiWindowLayout) && isstruct(multiWindowLayout) ,
                layoutMaybe = ws.Controller.singleWindowLayoutMaybeFromMultiWindowLayout(multiWindowLayout, class(self)) ;
                if ~isempty(layoutMaybe) ,
                    layoutForThisClass = layoutMaybe{1} ;
                    self.decodeWindowLayout(layoutForThisClass, monitorPositions);
                end
            end
        end  % function        
    end
    
    methods (Static=true)
        function result = layoutVariableNameFromControllerClassName(controllerClassName)
            controllerClassNameWithoutPrefix = strrep(controllerClassName, 'ws.', '') ;
            figureClassName = strrep(controllerClassNameWithoutPrefix, 'Controller', 'Figure') ;
            % Make sure we don't go beyond matlab var name length limit
            if length(figureClassName)>63 ,
                result = figureClassName(1:63) ;
            else
                result = figureClassName ;
            end
        end  % method
        
        function layoutMaybe = singleWindowLayoutMaybeFromMultiWindowLayout(multiWindowLayout, controllerClassName) 
            coreName = strrep(strrep(controllerClassName, 'ws.', ''), 'Controller', '') ;
            if isempty(multiWindowLayout) ,
                layoutMaybe = {} ;
            else
                multiWindowLayoutFieldNames = fieldnames(multiWindowLayout) ;
                layoutMaybe = {} ;
                for i = 1:length(multiWindowLayoutFieldNames) ,
                    fieldName = multiWindowLayoutFieldNames{i} ;
                    doesFieldNameContainCoreName = ~isempty(strfind(fieldName, coreName)) ;
                    if doesFieldNameContainCoreName ,
                        layoutMaybe = {multiWindowLayout.(fieldName)} ;
                        break
                    end
                end
            end
        end  % function
        
    end  % static methods block
    
end  % classdef
