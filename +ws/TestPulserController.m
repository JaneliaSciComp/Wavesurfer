classdef TestPulserController < ws.Controller
    methods            
        function self=TestPulserController(wavesurferController,wavesurferModel)
            testPulser=wavesurferModel.Ephys.TestPulser;
            self = self@ws.Controller(wavesurferController, testPulser, {'testPulserFigureWrapper'});            
        end
        
        function controlActuated(self,controlName,source,event) %#ok<INUSD,INUSL>
            %fprintf('controller.controlActuated!\n');            
            try
                fig=self.Figure;
                if source==fig.StartStopButton ,
                    %profile resume
                    self.startStopButtonPressed();
                    %profile off
                else
                    % If the model is running, stop it (have to disable broadcast so we don't lose the new setting)
                    wasRunningOnEntry=self.Model.IsRunning;
                    if wasRunningOnEntry ,
                        self.Figure.AreUpdatesEnabled=false;
                        % doBroadcast=false;
                        % self.Model.stop(doBroadcast);
                        %fprintf('about to stop...\n');
                        self.Model.stop();
                        %fprintf('done stopping...\n');
                    end                

                    % Act on the control
                    switch source ,
                        case fig.ElectrodePopupMenu ,
                            self.electrodePopupMenuTouched();
                        case fig.SubtractBaselineCheckbox ,
                            self.subtractBaselineCheckboxTouched();
                        case fig.AutoYCheckbox ,
                            self.autoYCheckboxTouched();
                        case fig.AutoYRepeatingCheckbox ,
                            self.autoYRepeatingCheckboxTouched();
                        case fig.AmplitudeEdit ,
                            self.amplitudeEditTouched();
                        case fig.DurationEdit ,
                            self.durationEditTouched();
                        case fig.ZoomInButton ,
                            self.zoomInButtonPressed();
                        case fig.ZoomOutButton ,
                            self.zoomOutButtonPressed();
                        case fig.ScrollUpButton ,
                            self.scrollUpButtonPressed();
                        case fig.ScrollDownButton ,
                            self.scrollDownButtonPressed();
                        case fig.VCToggle ,
                            self.vcTogglePressed();
                        case fig.CCToggle ,
                            self.ccTogglePressed();
                    end  % switch

                    % Start running again, if needed
                    if wasRunningOnEntry,
                        self.Figure.AreUpdatesEnabled=true;
                        self.Figure.updateControlProperties();
                        self.Model.start();
                    end                
                end
            catch me
%                 isInDebugMode=~isempty(dbstatus());
%                 if isInDebugMode ,
%                     rethrow(me);
%                 else
                    errordlg(me.message,'Error','modal');
%                 end
            end
        end  % function
        
        function startStopButtonPressed(self)
            %self.Figure.changeReadiness(-1);
            self.Model.toggleIsRunning();
            %self.Figure.changeReadiness(+1);
        end
        
        function electrodePopupMenuTouched(self)
            electrodeNames=self.Model.ElectrodeNames;
            menuItem=ws.utility.getPopupMenuSelection(self.Figure.ElectrodePopupMenu, ...
                                                         electrodeNames);
            if isempty(menuItem) ,  % indicates invalid selection
                self.Figure.badChangeMade();                
            else
                electrodeName=menuItem;
                self.Model.ElectrodeName=electrodeName;
            end
        end
        
        function subtractBaselineCheckboxTouched(self)
            value=logical(get(self.Figure.SubtractBaselineCheckbox,'Value'));
            self.Model.DoSubtractBaseline=value;
        end
        
        function autoYCheckboxTouched(self)
            value=logical(get(self.Figure.AutoYCheckbox,'Value'));
            self.Model.IsAutoY=value;
        end
        
        function autoYRepeatingCheckboxTouched(self)
            value=logical(get(self.Figure.AutoYRepeatingCheckbox,'Value'));
            self.Model.IsAutoYRepeating=value;
        end
        
        function amplitudeEditTouched(self)
            value=get(self.Figure.AmplitudeEdit,'String');
            self.Model.Amplitude=value;  % Amplitude is a double-string
        end
        
        function durationEditTouched(self)
            value=get(self.Figure.DurationEdit,'String');
            self.Model.PulseDurationInMsAsString=value;
        end
        
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
        
        function vcTogglePressed(self)
            % update the other toggle
            set(self.Figure.CCToggle,'Value',0);  % Want this to be fast
            drawnow('update');

            % Change the setting
            self.Model.ElectrodeMode=ws.ElectrodeMode.VC;
        end  % function
        
        function ccTogglePressed(self)
            % update the other toggle
            set(self.Figure.VCToggle,'Value',0);  % Want this to be fast
            drawnow('update');
            
            % Change the setting           
            self.Model.ElectrodeMode=ws.ElectrodeMode.CC;
        end  % function
    end  % methods
    
    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This method is inhierited from AbstractController, and is
            % called after the user indicates she wants to close the
            % window.  Returns true if the window should _not_ close, false
            % if it should go ahead and close.

            % If acquisition is happening, ignore the close window request
            testPulser=self.Model;
            if ~isempty(testPulser) && isvalid(testPulser) ,
                ephys=testPulser.Parent;            
                if ~isempty(ephys) && isvalid(ephys) ,
                    wavesurferModel=ephys.Parent;
                    if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                        isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
                        if ~isIdle ,
                            shouldStayPut=true;
                            return
                        end
                    end
                end
            end

            shouldStayPut=(self.Model.IsRunning);  % If the Test Pulser is running, ignore the close request
        end  % function
    end % protected methods block
    
    properties (SetAccess=protected)
       propBindings = ws.TestPulserController.initialPropertyBindings(); 
    end
    
    methods (Static=true)
        function s=initialPropertyBindings()
            s = struct();
        end
    end  % class methods
    
end  % classdef
