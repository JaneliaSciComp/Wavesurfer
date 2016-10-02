classdef ChannelsController < ws.Controller
    methods
        function self=ChannelsController(wavesurferController,wavesurferModel)
            % Call superclass constructor
            self = self@ws.Controller(wavesurferController,wavesurferModel) ;  

            % Create the figure, store a pointer to it
            fig = ws.ChannelsFigure(wavesurferModel,self) ;
            self.Figure_ = fig ;
        end
        
        function DeviceNamePopupActuated(self, source, event)  %#ok<INUSD>
            allDeviceNames = self.Model.AllDeviceNames ;
            deviceName = ws.getPopupMenuSelection(source, allDeviceNames) ;
            if isempty(deviceName) ,
                self.Figure.update() ;
            else
                %self.Model.DeviceName = deviceName ;
                self.Model.do('set', 'DeviceName', deviceName) ;
            end
        end
        
        function AIChannelNameEditsActuated(self,source,event) %#ok<INUSD>
            isTheChannel = (source==self.Figure.AIChannelNameEdits) ;
            i = find(isTheChannel) ;
            newString = get(self.Figure.AIChannelNameEdits(i),'String') ;
            %self.Model.Acquisition.setSingleAnalogChannelName(i, newString) ;
            self.Model.Acquisition.do('setSingleAnalogChannelName', i, newString) ;
        end
        
        function AITerminalNamePopupsActuated(self,source,event) %#ok<INUSD>
            % Get the list of valid choices, if we can
            wavesurferModel = self.Model ;
            validChoices = wavesurferModel.getAllAITerminalNames() ;
            % Do the rest
            choice=ws.getPopupMenuSelection(source,validChoices);
            terminalIDAsString = choice(3:end) ;
            terminalID = str2double(terminalIDAsString) ;            
            isTheChannel = (source==self.Figure.AITerminalNamePopups) ;
            iChannel = find(isTheChannel) ;
            %self.Model.Acquisition.setSingleAnalogTerminalID(iChannel, terminalID) ;  %#ok<FNDSB>
            self.Model.Acquisition.do('setSingleAnalogTerminalID', iChannel, terminalID) ;  %#ok<FNDSB>
        end
        
        function AIScaleEditsActuated(self,source,event)  %#ok<INUSD>
            isTheChannel=(source==self.Figure.AIScaleEdits);
            i=find(isTheChannel);
            newString=get(self.Figure.AIScaleEdits(i),'String');
            newValue=str2double(newString);
            %self.Model.Acquisition.setSingleAnalogChannelScale(i,newValue);
            self.Model.Acquisition.do('setSingleAnalogChannelScale', i, newValue) ;
        end
        
        function AIUnitsEditsActuated(self,source,event) %#ok<INUSD>
            isTheChannel=(source==self.Figure.AIUnitsEdits);
            i=find(isTheChannel);
            newString=get(self.Figure.AIUnitsEdits(i),'String');
            %self.Model.Acquisition.setSingleAnalogChannelUnits(i,newString);
            self.Model.Acquisition.do('setSingleAnalogChannelUnits', i, newString) ;
        end
        
        function AIIsActiveCheckboxesActuated(self,source,event) %#ok<INUSD>
            isTheChannel=find(source==self.Figure.AIIsActiveCheckboxes);
            isAnalogChannelActive=self.Model.Acquisition.IsAnalogChannelActive;
            isAnalogChannelActive(isTheChannel)=get(source,'Value');  %#ok<FNDSB>
            %self.Model.Acquisition.IsAnalogChannelActive=isAnalogChannelActive;             
            self.Model.Acquisition.do('set', 'IsAnalogChannelActive', isAnalogChannelActive) ;             
        end

        function AIIsMarkedForDeletionCheckboxesActuated(self,source,event)  %#ok<INUSD>
            indexOfTheChannel = find(source==self.Figure.AIIsMarkedForDeletionCheckboxes) ;
            isAnalogChannelMarkedForDeletion = self.Model.Acquisition.IsAnalogChannelMarkedForDeletion ;
            isAnalogChannelMarkedForDeletion(indexOfTheChannel) = get(source,'Value') ;  %#ok<FNDSB>
            %self.Model.Acquisition.IsAnalogChannelMarkedForDeletion = isAnalogChannelMarkedForDeletion ;             
            self.Model.Acquisition.do('set', 'IsAnalogChannelMarkedForDeletion', isAnalogChannelMarkedForDeletion) ;
        end

        function AddAIChannelButtonActuated(self,source,event)  %#ok<INUSD>
            %self.Model.Acquisition.addAnalogChannel() ;
            self.Model.do('addAIChannel') ;
        end
        
        function DeleteAIChannelsButtonActuated(self,source,event)  %#ok<INUSD>
            %self.Model.Acquisition.deleteMarkedAnalogChannels() ;
            self.Model.do('deleteMarkedAIChannels') ;
        end
        
        function AOChannelNameEditsActuated(self,source,event) %#ok<INUSD>
            isTheChannel = (source==self.Figure.AOChannelNameEdits) ;
            i = find(isTheChannel) ;
            newString = get(self.Figure.AOChannelNameEdits(i),'String') ;
            %self.Model.Stimulation.setSingleAnalogChannelName(i, newString) ;
            self.Model.Stimulation.do('setSingleAnalogChannelName', i, newString) ;
        end
        
        function AOTerminalNamePopupsActuated(self,source,event) %#ok<INUSD>
            % Get the list of valid choices, if we can
            wavesurferModel = self.Model ;
            validChoices = wavesurferModel.getAllAOTerminalNames() ;
            % Do the rest
            choice=ws.getPopupMenuSelection(source,validChoices);
            terminalIDAsString = choice(3:end) ;
            terminalID = str2double(terminalIDAsString) ;            
            isTheChannel = (source==self.Figure.AOTerminalNamePopups) ;
            iChannel = find(isTheChannel) ;
            %self.Model.Stimulation.setSingleAnalogTerminalID(iChannel, terminalID) ;  %#ok<FNDSB>
            self.Model.Stimulation.do('setSingleAnalogTerminalID', iChannel, terminalID) ;  %#ok<FNDSB>
        end
        
        function AOScaleEditsActuated(self,source,event)  %#ok<INUSD>
            isTheChannel=(source==self.Figure.AOScaleEdits);
            i=find(isTheChannel);
            newString=get(self.Figure.AOScaleEdits(i),'String');
            newValue=str2double(newString);
            %self.Model.Stimulation.setSingleAnalogChannelScale(i,newValue);
            self.Model.Stimulation.do('setSingleAnalogChannelScale', i, newValue);            
        end
        
        function AOUnitsEditsActuated(self,source,event)  %#ok<INUSD>
            isTheChannel=(source==self.Figure.AOUnitsEdits);
            i=find(isTheChannel);            
            newString=get(self.Figure.AOUnitsEdits(i),'String');
            newValue=strtrim(newString);
            %self.Model.Stimulation.setSingleAnalogChannelUnits(i,newValue);
            self.Model.Stimulation.do('setSingleAnalogChannelUnits', i, newValue) ;
        end
        
        function AOIsMarkedForDeletionCheckboxesActuated(self,source,event)  %#ok<INUSD>
            indexOfTheChannel = find(source==self.Figure.AOIsMarkedForDeletionCheckboxes) ;
            isAnalogChannelMarkedForDeletion = self.Model.Stimulation.IsAnalogChannelMarkedForDeletion ;
            isAnalogChannelMarkedForDeletion(indexOfTheChannel) = get(source,'Value') ;  %#ok<FNDSB>
            %self.Model.Stimulation.IsAnalogChannelMarkedForDeletion = isAnalogChannelMarkedForDeletion ;             
            self.Model.Stimulation.do('set', 'IsAnalogChannelMarkedForDeletion', isAnalogChannelMarkedForDeletion) ;
        end

        function AddAOChannelButtonActuated(self,source,event)  %#ok<INUSD>
            %self.Model.Stimulation.addAnalogChannel() ;
            self.Model.do('addAOChannel') ;            
        end
        
        function DeleteAOChannelsButtonActuated(self,source,event)  %#ok<INUSD>
            %self.Model.deleteMarkedAOChannels() ;
            self.Model.do('deleteMarkedAOChannels') ;
        end
        
        function DIChannelNameEditsActuated(self,source,event) %#ok<INUSD>
            isTheChannel = (source==self.Figure.DIChannelNameEdits) ;
            i = find(isTheChannel) ;
            newString = get(self.Figure.DIChannelNameEdits(i),'String') ;
            %self.Model.Acquisition.setSingleDigitalChannelName(i, newString) ;
            self.Model.Acquisition.do('setSingleDigitalChannelName', i, newString) ;
        end
        
        function DITerminalNamePopupsActuated(self,source,event) %#ok<INUSD>
            % Get the list of valid choices, if we can
            wavesurferModel = self.Model ;
            validChoices = wavesurferModel.getAllDigitalTerminalNames() ;
            % Do the rest
            choice=ws.getPopupMenuSelection(source,validChoices);
            terminalIDAsString = choice(4:end) ;
            terminalID = str2double(terminalIDAsString) ;            
            isTheChannel = (source==self.Figure.DITerminalNamePopups) ;
            iChannel = find(isTheChannel) ;
            %self.Model.setSingleDIChannelTerminalID(iChannel, terminalID) ;  %#ok<FNDSB>
            self.Model.do('setSingleDIChannelTerminalID', iChannel, terminalID) ;  %#ok<FNDSB>
        end
        
        function DIIsActiveCheckboxesActuated(self,source,event)  %#ok<INUSD>
            isTheChannel=find(source==self.Figure.DIIsActiveCheckboxes);
            isDigitalChannelActive=self.Model.Acquisition.IsDigitalChannelActive;
            isDigitalChannelActive(isTheChannel)=get(source,'Value');  %#ok<FNDSB>
            %self.Model.Acquisition.IsDigitalChannelActive=isDigitalChannelActive;        
            self.Model.Acquisition.do('set', 'IsDigitalChannelActive', isDigitalChannelActive);
        end

        function DIIsMarkedForDeletionCheckboxesActuated(self,source,event)  %#ok<INUSD>
            indexOfTheChannel = find(source==self.Figure.DIIsMarkedForDeletionCheckboxes) ;
            isChannelMarkedForDeletion = self.Model.Acquisition.IsDigitalChannelMarkedForDeletion ;
            isChannelMarkedForDeletion(indexOfTheChannel) = get(source,'Value') ;  %#ok<FNDSB>
            %self.Model.Acquisition.IsDigitalChannelMarkedForDeletion = isChannelMarkedForDeletion ;             
            self.Model.Acquisition.do('set', 'IsDigitalChannelMarkedForDeletion', isChannelMarkedForDeletion) ;
        end

        function AddDIChannelButtonActuated(self,source,event)  %#ok<INUSD>
            %self.Model.addDIChannel() ;
            self.Model.do('addDIChannel') ;
        end
        
        function DeleteDIChannelsButtonActuated(self,source,event)  %#ok<INUSD>
            %self.Model.deleteMarkedDIChannels() ;
            self.Model.do('deleteMarkedDIChannels') ;
        end
        
        function DOChannelNameEditsActuated(self,source,event) %#ok<INUSD>
            isTheChannel = (source==self.Figure.DOChannelNameEdits) ;
            i = find(isTheChannel) ;
            newString = get(self.Figure.DOChannelNameEdits(i),'String') ;
            %self.Model.Stimulation.setSingleDigitalChannelName(i, newString) ;
            self.Model.Stimulation.do('setSingleDigitalChannelName', i, newString) ;
        end
        
        function DOTerminalNamePopupsActuated(self,source,event) %#ok<INUSD>
            % Get the list of valid choices, if we can
            wavesurferModel = self.Model ;
            validChoices = wavesurferModel.getAllDigitalTerminalNames() ;
            % Do the rest
            choice=ws.getPopupMenuSelection(source,validChoices);
            terminalIDAsString = choice(4:end) ;
            terminalID = str2double(terminalIDAsString) ;            
            isTheChannel = (source==self.Figure.DOTerminalNamePopups) ;
            iChannel = find(isTheChannel) ;
            %self.Model.setSingleDOChannelTerminalID(iChannel, terminalID) ;  %#ok<FNDSB>
            self.Model.do('setSingleDOChannelTerminalID', iChannel, terminalID) ;  %#ok<FNDSB>
        end
        
        function DOIsTimedCheckboxesActuated(self, source, event)  %#ok<INUSD>
            isTheChannel = (source==self.Figure.DOIsTimedCheckboxes) ;
            i = find(isTheChannel) ;            
            newState = get(self.Figure.DOIsTimedCheckboxes(i),'value') ;
            %self.Model.Stimulation.IsDigitalChannelTimed(i)=newState;
            newArray = ws.replace(self.Model.Stimulation.IsDigitalChannelTimed, i, newState) ;
            self.Model.Stimulation.do('set','IsDigitalChannelTimed', newArray) ;
            %self.Figure.update();  % Surely this is not necessary anymore,
                                    % right?  -- ALT, 2016-09-12
        end
        
        function DOIsOnRadiobuttonsActuated(self,source,event)  %#ok<INUSD>
            isTheChannel = (source==self.Figure.DOIsOnRadiobuttons) ;
            i = find(isTheChannel) ;
            newState = get(self.Figure.DOIsOnRadiobuttons(i),'value') ;
            value = self.Model.Stimulation.DigitalOutputStateIfUntimed ;
            newValue = ws.replace(value, i, newState) ;
            % self.Model.Stimulation.DigitalOutputStateIfUntimed = newValue ;
            self.Model.Stimulation.do('set', 'DigitalOutputStateIfUntimed', newValue) ;            
        end
        
        function DOIsMarkedForDeletionCheckboxesActuated(self, source, event)  %#ok<INUSD>
            indexOfTheChannel = find(source==self.Figure.DOIsMarkedForDeletionCheckboxes) ;
            %isChannelMarkedForDeletion = self.Model.Stimulation.IsDigitalChannelMarkedForDeletion ;
            %isChannelMarkedForDeletion(indexOfTheChannel) = get(source,'Value') ;  %#ok<FNDSB>
            originalArray = self.Model.Stimulation.IsDigitalChannelMarkedForDeletion ;
            newValue = get(source,'Value') ;
            newArray = ws.replace(originalArray, indexOfTheChannel, newValue) ;  %#ok<FNDSB>
            %self.Model.Stimulation.IsDigitalChannelMarkedForDeletion = isChannelMarkedForDeletion ;             
            self.Model.Stimulation.do('set', 'IsDigitalChannelMarkedForDeletion', newArray) ;             
        end

        function AddDOChannelButtonActuated(self,source,event)  %#ok<INUSD>
            %self.Model.addDOChannel() ;
            self.Model.do('addDOChannel') ;
        end
        
        function DeleteDOChannelsButtonActuated(self,source,event)  %#ok<INUSD>
            %self.Model.deleteMarkedDOChannels() ;
            self.Model.do('deleteMarkedDOChannels') ;
        end
        
    end  % methods

    methods (Access=protected)
%         function shouldStayPut = shouldWindowStayPutQ(self, varargin)
%             % This method is inherited from AbstractController, and is
%             % called after the user indicates she wants to close the
%             % window.  Returns true if the window should _not_ close, false
%             % if it should go ahead and close.
%             shouldStayPut=false;
%             
%             % If acquisition is happening, ignore the close window request
%             wavesurferModel=self.Model;
%             if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
%                 isIdle=isequal(wavesurferModel.State,'idle')||isequal(wavesurferModel.State,'no_device');
%                 if ~isIdle ,
%                     shouldStayPut=true;
%                     return
%                 end
%             end
%         end  % function
    end % protected methods block

%     properties (SetAccess=protected)
%        propBindings = ws.ChannelsController.initialPropertyBindings(); 
%     end
%     
%     methods (Static=true)
%         function s=initialPropertyBindings()
%             s = struct();
%         end
%     end  % class methods
    
end
