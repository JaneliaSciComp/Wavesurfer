classdef TestPulserController < ws.Controller
    properties
        MyYLimDialogFigure=[]
    end
    
    methods            
        function self=TestPulserController(wavesurferController,wavesurferModel)
            % Call the superclass constructor
            %testPulser=wavesurferModel.Ephys.TestPulser;
            self = self@ws.Controller(wavesurferController,wavesurferModel);  

            % Create the figure, store a pointer to it
            fig = ws.TestPulserFigure(wavesurferModel,self) ;
            self.Figure_ = fig ;            
        end
        
        function exceptionMaybe = controlActuated(self, controlName, source, event, varargin)
            try
                wsModel = self.Model ;
                %testPulser = wsModel.Ephys.TestPulser;
                if strcmp(controlName, 'StartStopButton') ,
                    self.StartStopButtonActuated() ;
                    exceptionMaybe = {} ;
                else
                    % If the model is running, stop it (have to disable broadcast so we don't lose the new setting)
                    wasRunningOnEntry = wsModel.isTestPulsing() ;
                    if wasRunningOnEntry ,
                        self.Figure.AreUpdatesEnabled = false ;
                        wsModel.stopTestPulsing() ;
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
                            wsModel.startTestPulsing() ;
                        end
                    end
                end
            catch exception
                ws.raiseDialogOnException(exception) ;
                exceptionMaybe = { exception } ;
            end
        end  % function
        
        function StartStopButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('toggleIsTestPulsing');
        end
        
        function ElectrodePopupMenuActuated(self, source, event, varargin)  %#ok<INUSD>
            wsModel = self.Model ;
            electrodeNames = wsModel.getAllElectrodeNames() ;
            menuItem = ws.getPopupMenuSelection(self.Figure.ElectrodePopupMenu, ...
                                                electrodeNames);
            if isempty(menuItem) ,  % indicates invalid selection
                self.Figure.update();                
            else
                electrodeName=menuItem;
                wsModel.do('setTestPulseElectrodeByName', electrodeName) ;
            end
        end
        
        function SubtractBaselineCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            newValue = logical(get(self.Figure.SubtractBaselineCheckbox,'Value')) ;
            self.Model.do('set', 'DoSubtractBaselineInTestPulseView', newValue) ;
        end
        
        function AutoYCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            newValue = logical(get(self.Figure.AutoYCheckbox,'Value')) ;
            self.Model.do('set', 'IsAutoYInTestPulseView', newValue) ;
        end
        
        function AutoYRepeatingCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            newValue = logical(get(self.Figure.AutoYRepeatingCheckbox,'Value')) ;
            self.Model.do('set', 'IsAutoYRepeatingInTestPulseView', newValue) ;
        end
        
        function AmplitudeEditActuated(self, source, event, varargin)  %#ok<INUSD>
            value = get(self.Figure.AmplitudeEdit,'String') ;
            %ephys = self.Model.Ephys ;
            self.Model.do('setTestPulseElectrodeProperty', 'TestPulseAmplitude', value) ;
        end
        
        function DurationEditActuated(self, source, event, varargin)  %#ok<INUSD>
            newValueInMsAsString = get(self.Figure.DurationEdit,'String') ;
            newValue = 1e-3 * str2double(newValueInMsAsString) ;
            self.Model.do('set', 'TestPulseDuration', newValue) ;
        end
        
        function ZoomInButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('zoomInTestPulseView') ;
        end
        
        function ZoomOutButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('zoomOutTestPulseView') ;
        end
        
        function YLimitsButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.MyYLimDialogFigure = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            
            wsModel = self.Model ;
            
            setModelYLimitsCallback = @(newYLimits)(wsModel.do('set', 'TestPulseYLimits', newYLimits)) ;
%             function setModelYLimits(newYLimits)
%                 wsModel.do('set', 'TestPulseYLimits', newYLimits) ;
%             end
            
            self.MyYLimDialogFigure = ...
                ws.YLimDialogFigure([], ...
                                    get(self.Figure,'Position'), ...
                                    wsModel.TestPulseYLimits, ...
                                    wsModel.getTestPulseElectrodeMonitorUnits(), ...
                                    setModelYLimitsCallback) ;
        end
        
        function ScrollUpButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('scrollUpTestPulseView') ;
        end
        
        function ScrollDownButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model.do('scrollDownTestPulseView') ;
        end
        
        function VCToggleActuated(self, source, event, varargin)  %#ok<INUSD>
            % update the other toggle
            set(self.Figure.CCToggle, 'Value', 0) ;  % Want this to be fast
            drawnow('update');

            % Change the setting
            %ephys = self.Model.Ephys ;
            self.Model.do('setTestPulseElectrodeProperty', 'Mode', 'vc') ;
        end  % function
        
        function CCToggleActuated(self, source, event, varargin)  %#ok<INUSD>
            % update the other toggle
            set(self.Figure.VCToggle, 'Value', 0) ;  % Want this to be fast
            drawnow('update');
            
            % Change the setting    
            %ephys = self.Model.Ephys ;
            self.Model.do('setTestPulseElectrodeProperty', 'Mode', 'cc') ;
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
                shouldStayPut = ~model.isIdleSensuLato() || model.isTestPulsing() ;
            end
        end
    end % protected methods block    
    
end  % classdef
