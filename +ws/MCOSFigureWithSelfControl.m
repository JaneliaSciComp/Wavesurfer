classdef (Abstract) MCOSFigureWithSelfControl < ws.EventSubscriber
    % This is a base class that wraps a handle graphics figure in a proper
    % MCOS object, but does not have a separate controller.  All methods
    % fired by UI actions are methods of the MCOSFigureWithSelfControl
    % subclass.
    
    properties (Access=protected, Transient=true)
        DegreeOfEnablement_ = 1
            % We want to be able to disable updates, and do it in such a way
            % that it can be called in nested loops, functions, etc and
            % behave in a reasonable way.  So this this an integer that can
            % take on negative values when it has been disabled multiple
            % times without being enabled.  But it is always <= 1.
        NCallsToUpdateWhileDisabled_ = []    
        NCallsToUpdateControlPropertiesWhileDisabled_ = []    
        NCallsToUpdateControlEnablementWhileDisabled_ = []    
        %DegreeOfReadiness_ = 1
    end
    
    properties (Dependent=true, Transient=true)
        AreUpdatesEnabled   % logical scalar; if false, changes in the model should not be reflected in the UI
        %IsReady  % true <=> figure is showing the normal (as opposed to waiting) cursor
    end
    
%     properties (Dependent=true, SetAccess=immutable)
%         FigureGH  % the figure graphics handle
%         Model  % the model        
%     end  % properties

    properties (Access=protected)
        FigureGH_  % the figure graphics handle
        Model_  % the model        
    end  % properties    
    
    methods
        function self = MCOSFigureWithSelfControl(model)
            backgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            self.FigureGH_=figure('Units','Pixels', ...
                                  'Color',backgroundColor, ...
                                  'Visible','off', ...
                                  'HandleVisibility','off', ...
                                  'DockControls','off', ...
                                  'CloseRequestFcn',@(source,event)(self.closeRequested(source,event)));
            if exist('model','var') ,
                self.Model_ = model ;
                if ~isempty(model) && isvalid(model) ,
                    model.subscribeMe(self,'UpdateReadiness','','updateReadiness');
                end
            else
                self.Model_ = [] ;  % need this to can create an empty array of MCOSFigures
            end
        end
        
        function delete(self)
            self.deleteFigureGH_();
            %self.Controller_=[];
            %self.setModel_([]);
            self.Model_ = [] ;
            %fprintf('here i am doing something\n');
        end
        
        function set.AreUpdatesEnabled(self,newValue)
            import ws.*

            %fprintf('MCOSFigure::set.AreUpdatesEnabled()\n');
            %fprintf('  class of self: %s\n',class(self));
            %newValue
            
            if ~( islogical(newValue) && isscalar(newValue) ) ,
                return
            end
        
%             if isa(self,'ws.TestPulserFigure') ,
%                 fprintf('MCOSFigure:set.AreUpdatesEnabled(): At start, self.DegreeOfEnablement_ = %d\n' , ...
%                         self.DegreeOfEnablement_);
%                 fprintf('MCOSFigure:set.AreUpdatesEnabled(): newValue = %d\n' , ...
%                         newValue);
%             end
            
            netValueBefore=self.AreUpdatesEnabled;
            
            newValueAsSign=2*double(newValue)-1;  % [0,1] -> [-1,+1]
            newDegreeOfEnablementRaw=self.DegreeOfEnablement_+newValueAsSign;
            self.DegreeOfEnablement_ = ...
                    fif(newDegreeOfEnablementRaw<=1, ...
                        newDegreeOfEnablementRaw, ...
                        1);
                        
%             if isa(self,'ws.TestPulserFigure') ,
%                 fprintf('MCOSFigure:set.AreUpdatesEnabled(): After update, self.DegreeOfEnablement_ = %d\n' , ...
%                         self.DegreeOfEnablement_);
%             end
            
            netValueAfter=self.AreUpdatesEnabled;
            
%             if isa(self,'ws.TestPulserFigure') ,
%                 fprintf('MCOSFigure.update(): self.DegreeOfEnablement_= %d\n',self.DegreeOfEnablement_);
%             end

            
            if netValueAfter && ~netValueBefore ,
                % Updates have just been enabled
                if self.NCallsToUpdateWhileDisabled_>0
                    self.updateImplementation_();
                elseif self.NCallsToUpdateControlPropertiesWhileDisabled_>0
                    self.updateControlPropertiesImplementation_();
                elseif self.NCallsToUpdateControlEnablementWhileDisabled_>0
                    self.updateControlEnablementImplementation_();
                end
                self.NCallsToUpdateWhileDisabled_=[];
                self.NCallsToUpdateControlPropertiesWhileDisabled_=[];
                self.NCallsToUpdateControlEnablementWhileDisabled_=[];
            elseif ~netValueAfter && netValueBefore ,
                % Updates have just been disabled
                self.NCallsToUpdateWhileDisabled_=0;
                self.NCallsToUpdateControlPropertiesWhileDisabled_=0;
                self.NCallsToUpdateControlEnablementWhileDisabled_=0;
            end            
        end  % function

        function value=get.AreUpdatesEnabled(self)
            %fprintf('MCOSFigure:get.AreUpdatesEnabled(): self.DegreeOfEnablement_ = %d\n' , ...
            %        self.DegreeOfEnablement_);
            value=(self.DegreeOfEnablement_>0);
        end
    end  % public methods block
    
    methods (Access=protected)
%         function set(self,propName,value)
%             if strcmpi(propName,'Visible') && islogical(value) && isscalar(value) ,
%                 % special case to deal with Visible, which seems to
%                 % sometimes be a boolean
%                 if value,
%                     set(self.FigureGH_,'Visible','on');
%                 else
%                     set(self.FigureGH_,'Visible','off');
%                 end
%             else
%                 set(self.FigureGH_,propName,value);
%             end
%         end
%         
%         function value=get(self,propName)
%             value=get(self.FigureGH_,propName);
%         end
        
        function update_(self,varargin)
            % Called when the caller wants the figure to fully re-sync with the
            % model, from scratch.  This may cause the figure to be
            % resized, but this is always done in such a way that the
            % upper-righthand corner stays in the same place.
            if self.AreUpdatesEnabled ,
                self.updateImplementation_();
            else
                self.NCallsToUpdateWhileDisabled_=self.NCallsToUpdateWhileDisabled_+1;
            end
        end
        
        function updateControlProperties_(self,varargin)
            % Called when caller wants the control properties (Properties besides enablement, that is.) to re-sync
            % with the model, but doesn't need to update the controls that are in existance, or change the positions of the controls.
            if self.AreUpdatesEnabled ,
                self.updateControlPropertiesImplementation_();
            else
                self.NCallsToUpdateControlPropertiesWhileDisabled_=self.NCallsToUpdateControlPropertiesWhileDisabled_+1;
            end
        end
        
        function updateControlEnablement_(self,varargin)
            % Called when caller only needs to update the
            % enablement/disablment of the controls, given the model state.
            if self.AreUpdatesEnabled ,
                self.updateControlEnablementImplementation_();
            else
                self.NCallsToUpdateControlEnablementWhileDisabled_=self.NCallsToUpdateControlEnablementWhileDisabled_+1;
            end            
        end
        
%         function changeReadiness(self,delta)
%             import ws.*
% 
%             if ~( isnumeric(delta) && isscalar(delta) && (delta==-1 || delta==0 || delta==+1 || (isinf(delta) && delta>0) ) ),
%                 return
%             end
%                     
%             isReadyBefore=self.IsReady;
%             
%             newDegreeOfReadinessRaw=self.DegreeOfReadiness_+delta;
%             self.DegreeOfReadiness_ = ...
%                     fif(newDegreeOfReadinessRaw<=1, ...
%                         newDegreeOfReadinessRaw, ...
%                         1);
%                         
%             isReadyAfter=self.IsReady;
%             
%             if isReadyAfter && ~isReadyBefore ,
%                 % Change cursor to normal
%                 set(self.FigureGH_,'pointer','arrow');
%                 drawnow('update');
%             elseif ~isReadyAfter && isReadyBefore ,
%                 % Change cursor to hourglass
%                 set(self.FigureGH_,'pointer','watch');
%                 drawnow('update');
%             end            
%         end  % function        
%         
%         function value=get.IsReady(self)
%             value=(self.DegreeOfReadiness_>0);
%         end       
        
        function updateReadiness_(self,varargin)
            self.updateReadinessImplementation_();
        end

        function positionUpperLeftRelativeToOtherUpperRight_(self, other, offset)
            % Positions the upper left corner of the figure relative to the upper
            % *right* corner of the other figure.  offset is 2x1, with the 1st
            % element the number of pixels from the right side of the other figure,
            % the 2nd the number of pixels from the top of the other figure.

            ws.positionFigureUpperLeftRelativeToFigureUpperRightBang(self.FigureGH_, other.FigureGH_, offset) ;
        end
        
        createFixedControls_(self)
            % In subclass, this should create all the controls that persist
            % throughout the lifetime of the figure.
        
        function updateControlsInExistance_(self)  %#ok<MANU>
            % In subclass, this should make sure the non-fixed controls in
            % existance are synced with the model state, deleting
            % inappropriate ones and creating appropriate ones as needed.
            
            % This default implementation does nothing, and is appropriate
            % only if all the controls are fixed.
        end
        
        updateControlPropertiesImplementation_(self) 
            % In subclass, this should make sure the properties of the
            % controls (besides Position and Enable) are in-sync with the
            % model.  It can assume that all the controls that should
            % exist, do exist.
        
        updateControlEnablementImplementation_(self) 
            % In subclass, this should make sure the Enable property of
            % each control is in-sync with the model.  It can assume that
            % all the controls that should exist, do exist.
        
        figureSize=layoutFixedControls_(self) 
            % In subclass, this should make sure all the positions of the
            % fixed controls are appropriate given the current model state.
        
        function figureSizeModified=layoutNonfixedControls_(self,figureSize)  %#ok<INUSL>
            % In subclass, this should make sure all the positions of the
            % non-fixed controls are appropriate given the current model state.
            % It can safely assume that all the non-fixed controls already
            % exist
            figureSizeModified=figureSize;  % this is appropriate if there are no nonfixed controls
        end
        
        function layout_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely given the current model state.
            
            % This implementation should work in most cases, but can be overridden by
            % subclasses if needed.
            figureSize=self.layoutFixedControls_();
            figureSizeModified=self.layoutNonfixedControls_(figureSize);
            ws.resizeLeavingUpperLeftFixedBang(self.FigureGH_,figureSizeModified);            
        end
        
        function updateImplementation_(self)
            % This method should make sure the figure is fully synched with the
            % model state after it is called.  This includes existance,
            % placement, sizing, enablement, and properties of each control, and
            % of the figure itself.

            % This implementation should work in most cases, but can be overridden by
            % subclasses if needed.
            self.updateControlsInExistance_();
            self.updateControlPropertiesImplementation_();
            self.updateControlEnablementImplementation_();
            self.layout_();
        end
        
        function updateReadinessImplementation_(self)
            if isempty(self.Model_) 
                pointerValue = 'arrow';
            else
                if isvalid(self.Model_) ,
                    if self.Model_.IsReady ,
                        pointerValue = 'arrow';
                    else
                        pointerValue = 'watch';
                    end
                else
                    pointerValue = 'arrow';
                end
            end
            set(self.FigureGH_,'pointer',pointerValue);
            %fprintf('drawnow(''update'')\n');
            drawnow('update');
        end
    end
    
    methods (Access=protected)
        function setIsVisible_(self, newValue)
            if ~isempty(self.FigureGH_) && ishghandle(self.FigureGH_) ,
                set(self.FigureGH_, 'Visible', ws.onIff(newValue));
            end
        end  % function
    end  % methods
    
    methods
        function show(self)
            self.setIsVisible_(true);
        end  % function       
    end  % methods    

    methods
        function hide(self)
            self.setIsVisible_(false);
        end  % function       
    end  % methods    
    
    methods
        function raise(self)
            self.hide() ;
            self.show() ;  
        end  % function       
    end  % public methods block
    
    methods (Access=protected)
        function closeRequested_(self, source, event)  %#ok<INUSD>
            % Subclasses can override this if it's not to their liking
            self.deleteFigureGH_();
        end  % function       
    end  % methods    
            
    methods (Access=protected)
        function deleteFigureGH_(self)   
            % This causes the figure HG object to be deleted, with no ifs
            % ands or buts
            if ~isempty(self.FigureGH_) && ishghandle(self.FigureGH_) ,
                delete(self.FigureGH_);
            end
            self.FigureGH_ = [] ;
        end  % function       
    end  % methods    
        
    methods
        function exceptionMaybe = controlActuated(self, methodNameStem, source, event, varargin)  % public so that control actuation can be easily faked          
            % E.g. self.CancelButton_ would typically have the method name stem 'cancelButton'.
            % The advantage of passing in the methodNameStem, rather than,
            % say always storing it in the tag of the graphics object, and
            % then reading it out of the source arg, is that doing it this
            % way makes it easier to fake control actuations by calling
            % this function with the desired methodNameStem and an empty
            % source and event.
            try
                if isempty(source) ,
                    % this means the control actuated was a 'faux' control
                    methodName=[methodNameStem 'Actuated'] ;
                    if ismethod(self,methodName) ,
                        self.(methodName)(source, event, varargin{:});
                    end
                else
                    type=get(source,'Type');
                    if isequal(type,'uitable') ,
                        if isfield(event,'EditData') || isprop(event,'EditData') ,  % in older Matlabs, event is a struct, in later, an object
                            methodName=[methodNameStem 'CellEdited'];
                        else
                            methodName=[methodNameStem 'CellSelected'];
                        end
                        if ismethod(self,methodName) ,
                            self.(methodName)(source, event, varargin{:});
                        end
                    elseif isequal(type,'uicontrol') || isequal(type,'uimenu') ,
                        methodName=[methodNameStem 'Actuated'] ;
                        if ismethod(self,methodName) ,
                            self.(methodName)(source, event, varargin{:});
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
    end  % public methods block
    
    methods (Access=protected)
        function raiseDialogOnException_(self, exception)
            model = self.Model ;
            if ~isempty(model) ,
                model.resetReadiness() ;  % don't want the spinning cursor after we show the error dialog
            end
            if isempty(exception.cause)
                ws.errordlg(exception.message, 'Error', 'modal') ;
            else
                primaryCause = exception.cause{1} ;
                if isempty(primaryCause.cause) ,
                    errorString = sprintf('%s:\n%s',exception.message,primaryCause.message) ;
                    ws.errordlg(errorString, 'Error', 'modal') ;
                else
                    secondaryCause = primaryCause.cause{1} ;
                    errorString = sprintf('%s:\n%s\n%s', exception.message, primaryCause.message, secondaryCause.message) ;
                    ws.errordlg(errorString, 'Error', 'modal') ;
                end
            end            
        end  % method
    end  % protected methods block
    
    methods
        function constrainPositionToMonitors(self, monitorPositions)
            % For each monitor, calculate the translation needed to get the
            % figure onto it.

            % get the figure's OuterPosition
            %dbstack
            figureOuterPosition = get(self.FigureGH_, 'OuterPosition') ;
            figurePosition = get(self.FigureGH_, 'Position') ;
            %monitorPositions
            
            % define some local functions we'll need
            function translation = translationToFit2D(offset, sz, screenOffset, screenSize)
                xTranslation = translationToFit1D(offset(1), sz(1), screenOffset(1), screenSize(1)) ;
                yTranslation = translationToFit1D(offset(2), sz(2), screenOffset(2), screenSize(2)) ;
                translation = [xTranslation yTranslation] ;
            end

            function translation = translationToFit1D(offset, sz, screenOffset, screenSize)
                % Calculate a translation that will get a thing of size size at offset
                % offset onto a screen at offset screenOffset, of size screenSize.  All
                % args are *scalars*, as is the returned value
                topOffset = offset + sz ;  % or right offset, really
                screenTop = screenOffset+screenSize ;
                if offset < screenOffset ,
                    newOffset = screenOffset ;
                    translation =  newOffset - offset ;
                elseif topOffset > screenTop ,
                    newOffset = screenTop - sz ;
                    translation =  newOffset - offset ;
                else
                    translation = 0 ;
                end
            end
            
            % Get the offset, size of the figure
            figureOuterOffset = figureOuterPosition(1:2) ;
            figureOuterSize = figureOuterPosition(3:4) ;
            figureOffset = figurePosition(1:2) ;
            figureSize = figurePosition(3:4) ;
            
            % Compute the translation needed to get the figure onto each of
            % the monitors
            nMonitors = size(monitorPositions, 1) ;
            figureTranslationForEachMonitor = zeros(nMonitors,2) ;
            for i = 1:nMonitors ,
                monitorPosition = monitorPositions(i,:) ;
                monitorOffset = monitorPosition(1:2) ;
                monitorSize = monitorPosition(3:4) ;
                figureTranslationForThisMonitor = translationToFit2D(figureOuterOffset, figureOuterSize, monitorOffset, monitorSize) ;
                figureTranslationForEachMonitor(i,:) = figureTranslationForThisMonitor ;
            end

            % Calculate the magnitude of the translation for each monitor
            sizeOfFigureTranslationForEachMonitor = hypot(figureTranslationForEachMonitor(:,1), figureTranslationForEachMonitor(:,2)) ;
            
            % Pick the smallest translation that gets the figure onto
            % *some* monitor
            [~,indexOfSmallestFigureTranslation] = min(sizeOfFigureTranslationForEachMonitor) ;
            if isempty(indexOfSmallestFigureTranslation) ,
                figureTranslation = [0 0] ;
            else
                figureTranslation = figureTranslationForEachMonitor(indexOfSmallestFigureTranslation,:) ;
            end        

            % Compute the new position
            newFigurePosition = [figureOffset+figureTranslation figureSize] ;  
              % Apply the translation to the Position, not the
              % OuterPosition, as this seems to be more reliable.  Setting
              % the OuterPosition causes the layouts to get messed up
              % sometimes.  (Maybe setting the 'OuterSize' is the problem?)
            
            % Set it
            set(self.FigureGH_, 'Position', newFigurePosition) ;
        end  % function        
    end  % public methods block
    
%     methods (Static)
%         function result = methodNameStemFromControlName(controlName)
%             % We want to translate typical control names like
%             % 'CancelButton_' to method name stems like 'cancelButton'.
%             % Also, want e.g. 'OKButton_' to go to 'okButton'.
%             if isempty(controlName) ,
%                 result = '' ;
%             elseif isscalar(controlName) ,
%                 result = lower(controlName) ;
%             else
%                 % control is at least 2 chars long
%                 isUpperCaseLetter = arrayfun(controlName, @(c)(('A'<=c)&&(c<='Z'))) ;                
%                 indexOfFirstNonUpperCaseLetter = find(~isUpperCaseLetter,1) ;
%                 if isempty(indexOfFirstNonUpperCaseLetter) ,
%                     % controlName is all uppercase letters
%                     lowerCamelCaseControlName = lower(controlName) ;
%                 else
%                     if indexOfFirstNonUpperCaseLetter==1 ,
%                         lowerCamelCaseControlName = controlName ;
%                     elseif indexOfFirstNonUpperCaseLetter==2 ,
%                         % This is probably the most common case, e.g.
%                         % 'CancelButton_', for which the case-corrected
%                         % contol name is 'cancelButton_'                        
%                         lowerCamelCaseControlName = horzcat(lower(controlName(1)), controlName(2:end)) ;
%                     else
%                         % E.g. 'OKButton_', for which the case-corrected
%                         % contol name is 'okButton_'                        
%                         indexOfLastUpperCaseLetter = indexOfFirstNonUpperCaseLetter - 1 ;
%                         indexOfLastCharacterInFirstWord = indexOfLastUpperCaseLetter - 1 ;  % where the first "word" might be something like "OK"
%                         lowerCamelCaseControlName = horzcat(lower(controlName(1:indexOfLastCharacterInFirstWord)), controlName(indexOfLastCharacterInFirstWord+1:end)) ;                        
%                     end
%                 end
%                 % Now delete any trailing underscore                
%                 if isequal(lowerCamelCaseControlName(end),'_') ,
%                     result = lowerCamelCaseControlName(1:end-1) ;
%                 else
%                     result = lowerCamelCaseControlName ;
%                 end                    
%             end
%         end
%     end
    
end  % classdef
