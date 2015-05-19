classdef ChannelsController < ws.Controller
    methods
        function self=ChannelsController(wavesurferController,wavesurferModel)
            %self = self@ws.Controller(parent,model,figureClassNames,[],[],[]);            
            self = self@ws.Controller(wavesurferController,wavesurferModel, {'channelsFigureWrapper'});
            figureObject=self.Figure;
            figureGH=figureObject.FigureGH;
            set(figureGH,'CloseRequestFcn',@(source,event)(figureObject.closeRequested(source,event)));
            self.initialize();
        end
        
        function aiScaleEditActuated(self,source)
            isTheChannel=(source==self.Figure.AIScaleEdits);
            i=find(isTheChannel);
            newString=get(self.Figure.AIScaleEdits(i),'String');
            newValue=str2double(newString);
            if isfinite(newValue) && newValue>0 ,
                % good value
                self.Model.Acquisition.setSingleAnalogChannelScale(i,newValue);
                % changing model should auto-update the view
            else
                % discard change by re-syncing view to model
                self.Figure.update();
            end
        end
        
        function aiUnitsEditActuated(self,source)
            isTheChannel=(source==self.Figure.AIUnitsEdits);
            i=find(isTheChannel);
            newString=get(self.Figure.AIUnitsEdits(i),'String');
            try
                newValue=ws.utility.SIUnit(newString);
                self.Model.Acquisition.setSingleAnalogChannelUnits(i,newValue);
            catch excp, 
                if isequal(excp.identifier,'SIUnits:badConstructorArgs') ,
                    self.Figure.update();
                else
                    rethrow(excp);
                end
            end
        end
        
        function aiIsActiveCheckboxActuated(self,source)
            isTheChannel=find(source==self.Figure.AIIsActiveCheckboxes);
            isAnalogChannelActive=self.Model.Acquisition.IsAnalogChannelActive;
            isAnalogChannelActive(isTheChannel)=get(source,'Value');  %#ok<FNDSB>
            self.Model.Acquisition.IsAnalogChannelActive=isAnalogChannelActive;             
        end
        
        function diIsActiveCheckboxActuated(self,source)
            isTheChannel=find(source==self.Figure.DIIsActiveCheckboxes);
            isDigitalChannelActive=self.Model.Acquisition.IsDigitalChannelActive;
            isDigitalChannelActive(isTheChannel)=get(source,'Value');  %#ok<FNDSB>
            self.Model.Acquisition.IsDigitalChannelActive=isDigitalChannelActive;        
        end
        
        function aoScaleEditActuated(self,source)
            isTheChannel=(source==self.Figure.AOScaleEdits);
            i=find(isTheChannel);
            newString=get(self.Figure.AOScaleEdits(i),'String');
            newValue=str2double(newString);
            if isfinite(newValue) && newValue>0 ,
                % good value
                %self.Model.Stimulation.ChannelScales(i)=newValue;
                self.Model.Stimulation.setSingleAnalogChannelScale(i,newValue);
                % changing model should auto-update the view
            else
                % discard change by re-syncing view to model
                self.Figure.update();
            end
        end
        
        function aoUnitsEditActuated(self,source)
            isTheChannel=(source==self.Figure.AOUnitsEdits);
            i=find(isTheChannel);            
            newString=get(self.Figure.AOUnitsEdits(i),'String');
            try
                newValue=ws.utility.SIUnit(newString);
                self.Model.Stimulation.setSingleAnalogChannelUnits(i,newValue);
            catch excp, 
                if isequal(excp.identifier,'SIUnits:badConstructorArgs') ,
                    self.Figure.update();
                else
                    rethrow(excp);
                end
            end
        end
        
        function doTimedCheckboxActuated(self,source)
            isTheChannel=(source==self.Figure.DOIsTimedCheckboxes);
            i=find(isTheChannel);            
            newState = get(self.Figure.DOIsTimedCheckboxes(i),'value');
            self.Model.Stimulation.IsDigitalChannelTimed(i)=newState;
            self.Figure.update();
        end
        
        function doOnRadiobuttonActuated(self,source)
            isTheChannel=(source==self.Figure.DOIsOnRadiobuttons);
            i=find(isTheChannel);            
            newState = get(self.Figure.DOIsOnRadiobuttons(i),'value');
            self.Model.Stimulation.DigitalOutputStateIfUntimed(i)=newState;
        end
        
%         function aoMultiplierEditActuated(self,source)
%             isTheChannel=(source==self.Figure.AOMultiplierEdits);
%             i=find(isTheChannel);
%             newString=get(self.Figure.AOMultiplierEdits(i),'String');
%             newValue=str2double(newString);
%             if isfinite(newValue) && newValue>0 ,
%                 % good value
%                 %self.Model.Stimulation.ChannelScales(i)=newValue;
%                 self.Model.Stimulation.setSingleChannelMultiplier(i,newValue);
%                 % changing model should auto-update the view
%             else
%                 % discard change by re-syncing view to model
%                 self.Figure.update();
%             end
%         end    
        
        function controlActuated(self,controlName,source,event) %#ok<INUSD,INUSL>
            figureObject=self.Figure;
            try
                if any(source==figureObject.AIScaleEdits)
                    self.aiScaleEditActuated(source);
                elseif any(source==figureObject.AIUnitsEdits)
                    self.aiUnitsEditActuated(source);
                elseif any(source==figureObject.AIIsActiveCheckboxes)
                    self.aiIsActiveCheckboxActuated(source);
                elseif any(source==figureObject.DIIsActiveCheckboxes)
                    self.diIsActiveCheckboxActuated(source);
                elseif any(source==figureObject.AOScaleEdits)
                    self.aoScaleEditActuated(source);
                elseif any(source==figureObject.AOUnitsEdits)
                    self.aoUnitsEditActuated(source);
                elseif any(source==figureObject.DOIsTimedCheckboxes)
                    self.doTimedCheckboxActuated(source);
                elseif any(source==figureObject.DOIsOnRadiobuttons)
                    self.doOnRadiobuttonActuated(source);
%                 elseif any(source==figureObject.AOMultiplierEdits)
%                     self.aoMultiplierEditActuated(source);
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
        
    end  % methods

    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This method is inherited from AbstractController, and is
            % called after the user indicates she wants to close the
            % window.  Returns true if the window should _not_ close, false
            % if it should go ahead and close.
            shouldStayPut=false;
            
            % If acquisition is happening, ignore the close window request
            wavesurferModel=self.Model;
            if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
                if ~isIdle ,
                    shouldStayPut=true;
                    return
                end
            end
        end  % function
    end % protected methods block

    properties (SetAccess=protected)
       propBindings = ws.ChannelsController.initialPropertyBindings(); 
    end
    
    methods (Static=true)
        function s=initialPropertyBindings()
            s = struct();
        end
    end  % class methods
    
end
