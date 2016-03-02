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
            self.Figure.AreUpdatesEnabled=newValue;
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
        
        function deleteFigureGH(self)   
            self.tellFigureToDeleteFigureGH_();
        end  % function       
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
        function layoutForAllWindows=addThisWindowLayoutToLayout(self, layoutForAllWindows)
            % Add layout info for this window (just this one window) to
            % a struct representing the layout of all windows in the app
            % session.
           
            % Framework specific transformation.
            thisWindowLayout = self.encodeWindowLayout_();
            
            layoutVarNameForClass = self.getLayoutVariableNameForClass();
            if isfield(layoutForAllWindows,layoutVarNameForClass)
                % If the class field is already present, add the single tag
                tag=get(self.Figure,'Tag');
                layoutForAllWindows.(layoutVarNameForClass).(tag)=thisWindowLayout.(tag);
            else
                % If the class field is not present, thisWindowLayout
                % becomes the whole field
                layoutForAllWindows.(layoutVarNameForClass)=thisWindowLayout;
            end
        end
    end

    methods (Access = protected, Sealed = true)
        function varName = getLayoutVariableNameForClass(self, varargin)
            if nargin == 1
                str = class(self);
            else
                str = varargin{1};
            end
            
            varName = sprintf('%s_layout', str);
            varName = regexprep(varName, '\.','__');
            % Make sure we don't go beyonf matlab var name length limit
            if length(varName)>63 ,
                varName=varName(end-62:end);
            end
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
        function layoutOfWindowsInClassButOnlyForThisWindow = encodeWindowLayout_(self)
            window = self.Figure;
            layoutOfWindowsInClassButOnlyForThisWindow = struct();
            tag = get(window, 'Tag');
            layoutOfWindowsInClassButOnlyForThisWindow.(tag).Position = get(window, 'Position');
            visible=get(window, 'Visible');
            if ischar(visible) ,
                isVisible=strcmpi(visible,'on');
            else
                isVisible=visible;
            end
            layoutOfWindowsInClassButOnlyForThisWindow.(tag).Visible = isVisible;
%             if ws.most.gui.AdvancedPanelToggler.isFigToggleable(window)
%                 layoutOfWindowsInClassButOnlyForThisWindow.(tag).Toggle = ws.most.gui.AdvancedPanelToggler.saveToggleState(window);
%             else
%                 layoutOfWindowsInClassButOnlyForThisWindow.(tag).Toggle = [];
%             end
        end
    end
    
    methods (Access = protected)
        function decodeWindowLayout(self, layoutOfWindowsInClass)
            figureObject = self.Figure;
            %figureGH=figureObject.FigureGH;
            tag = get(figureObject, 'Tag');
            if isfield(layoutOfWindowsInClass, tag)
                layoutOfThisWindow = layoutOfWindowsInClass.(tag);

%                 if isfield(layoutOfThisWindow, 'Toggle')
%                     toggleState = layoutOfThisWindow.Toggle;
%                 else
%                     % This branch is only to support legacy .usr files that
%                     % don't have up-to-date layout info.
%                     toggleState = [];
%                 end

%                 if ~isempty(toggleState)
%                 if false ,
%                     assert(ws.most.gui.AdvancedPanelToggler.isFigToggleable(figureObject));
% 
%                     ws.most.gui.AdvancedPanelToggler.loadToggleState(figureObject,toggleState);
% 
%                     % gui is toggleable; for position, only set x- and
%                     % y-pos, not width and height, as those are controlled
%                     % by toggle-state.
%                     pos = get(figureObject,'Position');
%                     pos(1:2) = layoutOfThisWindow.Position(1:2);
%                     set(figureObject,'Position',pos);
%                 else
                    % Not a toggleable GUI.
                set(figureObject, 'Position', layoutOfThisWindow.Position);
%                 end

                if isfield(layoutOfThisWindow,'Visible') ,
                    set(figureObject, 'Visible', layoutOfThisWindow.Visible);
                end
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
        function out = shouldWindowStayPutQ(self, source, event) %#ok<INUSD>
            % This method is a hook for application specific controllers to intercept the
            % close (or hide) attempt and cancel it.  Controllers should return false to
            % continue the close/hide or true to cancel.
            out = false;
        end
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
        function controlActuated(self,controlName,source,event)            
            try
                %controlName
                type=get(source,'Type');
                if isequal(type,'uitable') ,
                    if isfield(event,'EditData') || isprop(event,'EditData') ,  % in older Matlabs, event is a struct, in later, an object
                        methodName=[controlName 'CellEdited'];
                    else
                        methodName=[controlName 'CellSelected'];
                    end
                    if ismethod(self,methodName) ,
                        self.(methodName)(source,event);
                    end                    
                elseif isequal(type,'uicontrol') || isequal(type,'uimenu') ,
                    methodName=[controlName 'Actuated'];
                    if ismethod(self,methodName) ,
                        self.(methodName)(source,event);
                    end
                end
            catch me
                self.Model.resetReadiness() ;  % don't want the spinning cursor after we show the error dialog
                
%                 isInDebugMode=~isempty(dbstatus());
%                 if isInDebugMode ,
%                     rethrow(me);
%                 else

%                     fprintf('ws.Controller::controlActuated: An error occured:\n');
%                     id = me.identifier
%                     msg = me.message
%                     report = me.getReport()

                 if isempty(me.cause) 
                     errordlg(me.message,'Error','modal');
                 else
                     firstCause = me.cause{1} ;
                     errorString = sprintf('%s:\n%s',me.message,firstCause.message) ;
                     errordlg(errorString, ...
                              'Error','modal');
                 end                     
%                end
            end
        end  % function       
    end
    
    methods (Static=true)
        function setWithBenefits(object,propertyName,newValue)
            % Do object.(propertyName)=newValue, but catch any
            % most:Model:invalidPropVal exception generated.  If that
            % exception is generated, just ignore it.  The model is
            % responsible for broadcasting an Update event in the case of a
            % attempt to set an invalid value, which should cause the
            % invalid value to be cleared from the view, and replaced with
            % the preexisting value.
            try 
                object.(propertyName)=newValue;
            catch exception
                if isequal(exception.identifier,'most:Model:invalidPropVal') ,
                    % Ignore it
                else
                    rethrow(exception);
                end
            end
        end
    end
    
    methods (Access=protected, Sealed = true)
        function extractAndDecodeLayoutFromMultipleWindowLayout_(self, multiWindowLayout)
            % Load a mulitiple window layout from an already loaded struct.
            
            if isempty(multiWindowLayout)
                return
            end
            
            layoutVarNameForThisClass = self.getLayoutVariableNameForClass();
            
            if isfield(multiWindowLayout, layoutVarNameForThisClass) ,
                layoutForThisClass=multiWindowLayout.(layoutVarNameForThisClass);
                self.decodeWindowLayout(layoutForThisClass);
%                 if self.IsSuiGeneris ,
%                     windowLayout = layoutForThisClass;
%                     self.decodeWindowLayout(windowLayout);
%                 else
%                     tag=get(self.Window,'Tag');
%                     if isfield(layoutForAllWindows.(layoutVarNameForThisClass),tag)
%                         windowLayout=layoutForAllWindows.(layoutVarNameForThisClass).(tag);
%                         self.decodeWindowLayout(windowLayout);
%                     end
%                 end
            end
        end  % function        
    end
    
    
end  % classdef
