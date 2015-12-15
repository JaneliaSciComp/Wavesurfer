classdef ChannelsController < ws.Controller
    methods
        function self=ChannelsController(wavesurferController,wavesurferModel)
%             self = self@ws.Controller(wavesurferController,wavesurferModel, {'channelsFigureWrapper'});
%             figureObject=self.Figure;
%             figureGH=figureObject.FigureGH;
%             set(figureGH,'CloseRequestFcn',@(source,event)(figureObject.closeRequested(source,event)));
%             self.initialize();

            % Call superclass constructor
            self = self@ws.Controller(wavesurferController,wavesurferModel) ;  

            % Create the figure, store a pointer to it
            fig = ws.ChannelsFigure(wavesurferModel,self) ;
            self.Figure_ = fig ;
        end
        
        function AIChannelNameEditsActuated(self,source,event) %#ok<INUSD>
            isTheChannel = (source==self.Figure.AIChannelNameEdits) ;
            i = find(isTheChannel) ;
            newString = get(self.Figure.AIUnitsEdits(i),'String') ;
            self.Model.Acquisition.setSingleAnalogChannelName(i, newString) ;
        end
        
        function AITerminalNamePopupsActuated(self,source,event) %#ok<INUSD>
            % Get the list of valid choices, if we can
            wavesurferModel = self.Model ;
            validChoices = wavesurferModel.getAllAnalogTerminalNames() ;
            % Do the rest
            choice=ws.utility.getPopupMenuSelection(source,validChoices);
            channelIDAsString = choice(3:end) ;
            channelID = str2double(channelIDAsString) ;            
            isTheChannel = (source==self.Figure.AITerminalNamePopups) ;
            iChannel = find(isTheChannel) ;
            self.Model.Acquisition.setSingleAnalogChannelId(iChannel, channelID) ;  %#ok<FNDSB>
        end
        
        function AIScaleEditsActuated(self,source,event)  %#ok<INUSD>
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
        
        function AIUnitsEditsActuated(self,source,event) %#ok<INUSD>
            isTheChannel=(source==self.Figure.AIUnitsEdits);
            i=find(isTheChannel);
            newString=get(self.Figure.AIUnitsEdits(i),'String');
            self.Model.Acquisition.setSingleAnalogChannelUnits(i,newString);
        end
        
        function AIIsActiveCheckboxesActuated(self,source,event) %#ok<INUSD>
            isTheChannel=find(source==self.Figure.AIIsActiveCheckboxes);
            isAnalogChannelActive=self.Model.Acquisition.IsAnalogChannelActive;
            isAnalogChannelActive(isTheChannel)=get(source,'Value');  %#ok<FNDSB>
            self.Model.Acquisition.IsAnalogChannelActive=isAnalogChannelActive;             
        end

        function AIIsMarkedForDeletionCheckboxesActuated(self,source,event)  %#ok<INUSD>
            indexOfTheChannel = find(source==self.Figure.AIIsMarkedForDeletionCheckboxes) ;
            isAnalogChannelMarkedForDeletion = self.Model.Acquisition.IsAnalogChannelMarkedForDeletion ;
            isAnalogChannelMarkedForDeletion(indexOfTheChannel) = get(source,'Value') ;  %#ok<FNDSB>
            self.Model.Acquisition.IsAnalogChannelMarkedForDeletion = isAnalogChannelMarkedForDeletion ;             
        end

        function AddAIChannelButtonActuated(self,source,event)  %#ok<INUSD>
            self.Model.Acquisition.addAnalogChannel() ;
        end
        
        function DeleteAIChannelsButtonActuated(self,source,event)  %#ok<INUSD>
            self.Model.Acquisition.deleteMarkedAnalogChannels() ;
        end
        
        function DIIsActiveCheckboxesActuated(self,source,event)  %#ok<INUSD>
            isTheChannel=find(source==self.Figure.DIIsActiveCheckboxes);
            isDigitalChannelActive=self.Model.Acquisition.IsDigitalChannelActive;
            isDigitalChannelActive(isTheChannel)=get(source,'Value');  %#ok<FNDSB>
            self.Model.Acquisition.IsDigitalChannelActive=isDigitalChannelActive;        
        end
        
        function AOScaleEditsActuated(self,source,event)  %#ok<INUSD>
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
        
        function AOUnitsEditsActuated(self,source,event)  %#ok<INUSD>
            isTheChannel=(source==self.Figure.AOUnitsEdits);
            i=find(isTheChannel);            
            newString=get(self.Figure.AOUnitsEdits(i),'String');
            newValue=strtrim(newString);
            self.Model.Stimulation.setSingleAnalogChannelUnits(i,newValue);
        end
        
        function DOIsTimedCheckboxesActuated(self,source,event)  %#ok<INUSD>
            isTheChannel=(source==self.Figure.DOIsTimedCheckboxes);
            i=find(isTheChannel);            
            newState = get(self.Figure.DOIsTimedCheckboxes(i),'value');
            self.Model.Stimulation.IsDigitalChannelTimed(i)=newState;
            self.Figure.update();
        end
        
        function DOIsOnRadiobuttonsActuated(self,source,event)  %#ok<INUSD>
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
        
%         function controlActuated(self,controlName,source,event)
%             figureObject=self.Figure;
%             try
%                 if any(source==figureObject.AIScaleEdits)
%                     self.AIScaleEditsActuated(source);
%                 elseif any(source==figureObject.AIUnitsEdits)
%                     self.aiUnitsEditActuated(source);
%                 elseif any(source==figureObject.AIIsActiveCheckboxes)
%                     self.aiIsActiveCheckboxActuated(source);
%                 elseif any(source==figureObject.DIIsActiveCheckboxes)
%                     self.diIsActiveCheckboxActuated(source);
%                 elseif any(source==figureObject.AOScaleEdits)
%                     self.aoScaleEditActuated(source);
%                 elseif any(source==figureObject.AOUnitsEdits)
%                     self.aoUnitsEditActuated(source);
%                 elseif any(source==figureObject.DOIsTimedCheckboxes)
%                     self.doTimedCheckboxActuated(source);
%                 elseif any(source==figureObject.DOIsOnRadiobuttons)
%                     self.doOnRadiobuttonActuated(source);
%                 elseif isequal(controlName,'AddAIChannelButton') ,
%                     self.addAIChannel() ;
%                 elseif isequal(controlName,'DeleteAIChannelsButton') ,
%                     self.deleteAIChannels() ;
%                 elseif isequal(controlName,'AIIsMarkedForDeletionCheckboxes') ,
%                     self.AIIsMarkedForDeletionCheckboxesActuated(source,event);
%                 end
%             catch me
%                     errordlg(me.message,'Error','modal');
%             end            
%         end  % function
        
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
                isIdle=isequal(wavesurferModel.State,'idle');
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
