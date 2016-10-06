classdef TestPulserController < ws.Controller
    properties
        MyYLimDialogFigure=[]
    end
    
    methods            
        function self=TestPulserController(wavesurferController,wavesurferModel)
            % Call the superclass constructor
            testPulser=wavesurferModel.Ephys.TestPulser;
            self = self@ws.Controller(wavesurferController,testPulser);  

            % Create the figure, store a pointer to it
            fig = ws.TestPulserFigure(testPulser,self) ;
            self.Figure_ = fig ;            
        end
        
        function exceptionMaybe = controlActuated(self, controlName, source, event, varargin)
            try
                if strcmp(controlName, 'StartStopButton') ,
                    self.StartStopButtonActuated() ;
                    exceptionMaybe = {} ;
                else
                    % If the model is running, stop it (have to disable broadcast so we don't lose the new setting)
                    wasRunningOnEntry = self.Model.IsRunning ;
                    if wasRunningOnEntry ,
                        self.Figure.AreUpdatesEnabled = false ;
                        self.Model.stop() ;
                    end
                    
                    % Act on the control
                    exceptionMaybe = controlActuated@ws.Controller(self, controlName, source, event, varargin{:}) ;
                    % if exceptionMaybe is nonempty, a dialog has already
                    % been shown to the user.

                    % Start running again, if needed, and if there was no
                    % exception.
                    if wasRunningOnEntry ,
                        self.Figure.AreUpdatesEnabled = true ;
                        self.Figure.updateControlProperties() ;
                        if isempty(exceptionMaybe) ,
                            self.Model.start() ;
                        end
                    end
                end
            catch exception
                self.raiseDialogOnException_(exception) ;
                exceptionMaybe = { exception } ;
            end
        end  % function
        
        function StartStopButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('toggleIsRunning');
        end
        
        function ElectrodePopupMenuActuated(self, source, event, varargin)  %#ok<INUSD>
            electrodeNames = self.Model.ElectrodeNames ;
            menuItem = ws.getPopupMenuSelection(self.Figure.ElectrodePopupMenu, ...
                                                electrodeNames);
            if isempty(menuItem) ,  % indicates invalid selection
                self.Figure.update();                
            else
                electrodeName=menuItem;
                self.Model.do('set','ElectrodeName',electrodeName) ;
            end
        end
        
        function SubtractBaselineCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            value = logical(get(self.Figure.SubtractBaselineCheckbox,'Value')) ;
            self.Model.do('set', 'DoSubtractBaseline', value) ;
        end
        
        function AutoYCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            value = logical(get(self.Figure.AutoYCheckbox,'Value')) ;
            self.Model.do('set', 'IsAutoY', value) ;
        end
        
        function AutoYRepeatingCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            value = logical(get(self.Figure.AutoYRepeatingCheckbox,'Value')) ;
            self.Model.do('set', 'IsAutoYRepeating', value) ;
        end
        
        function AmplitudeEditActuated(self, source, event, varargin)  %#ok<INUSD>
            value = get(self.Figure.AmplitudeEdit,'String') ;
            self.Model.do('set', 'Amplitude', value) ;
        end
        
        function DurationEditActuated(self, source, event, varargin)  %#ok<INUSD>
            value = get(self.Figure.DurationEdit,'String') ;
            self.Model.do('set', 'PulseDurationInMsAsString', value) ;
        end
        
        function ZoomInButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('zoomIn') ;
        end
        
        function ZoomOutButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('zoomOut') ;
        end
        
        function YLimitsButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.MyYLimDialogFigure = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            
            function setModelYLimits(newYLimits)
                self.Model.do('set', 'YLimits', newYLimits) ;
            end
            
            self.MyYLimDialogFigure = ...
                ws.YLimDialogFigure([], ...
                                    get(self.Figure,'Position'), ...
                                    self.Model.YLimits, ...
                                    self.Model.YUnits, ...
                                    @setModelYLimits) ;
        end
        
        function ScrollUpButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('scrollUp') ;
        end
        
        function ScrollDownButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('scrollDown') ;
        end
        
        function VCToggleActuated(self, source, event, varargin)  %#ok<INUSD>
            % update the other toggle
            set(self.Figure.CCToggle, 'Value', 0) ;  % Want this to be fast
            drawnow('update');

            % Change the setting
            self.Model.do('set', 'ElectrodeMode', 'vc') ;
        end  % function
        
        function CCToggleActuated(self, source, event, varargin)  %#ok<INUSD>
            % update the other toggle
            set(self.Figure.VCToggle, 'Value', 0) ;  % Want this to be fast
            drawnow('update');
            
            % Change the setting           
            self.Model.do('set', 'ElectrodeMode', 'cc') ;
        end  % function
    end  % methods
    
    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This is called after the user indicates she wants to close
            % the window.  Returns true if the window should _not_ close,
            % false if it should go ahead and close.
            model = self.Model ;
            if isempty(model) || ~isvalid(model) ,
                shouldStayPut = false ;
            else
                shouldStayPut = ~model.isRootIdleSensuLato() || model.IsRunning;
            end
        end
    end % protected methods block    
    
end  % classdef
