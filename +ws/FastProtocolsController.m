classdef FastProtocolsController < ws.Controller
    
    methods
        function self = FastProtocolsController(wavesurferController,wavesurferModel)
            self = self@ws.Controller(wavesurferController, wavesurferModel, {'fastProtocolsFigureWrapper'});
        end  % function        
    end  % public methods block

    methods
        function ClearRowButtonActuated(self, varargin)
            selectedIndex = self.Model.IndexOfSelectedFastProtocol;
            if isempty(selectedIndex) ,
                return
            end
            self.Model.FastProtocols(selectedIndex).ProtocolFileName = '';
            self.Model.FastProtocols(selectedIndex).AutoStartType = ws.fastprotocol.StartType.DoNothing;
        end  % function
        
        function SelectFileButtonActuated(self, varargin)
            selectedIndex = self.Model.IndexOfSelectedFastProtocol;
            if isempty(selectedIndex) ,
                return
            end
            
            % By default start in the location of the current file.  If it is empty it will
            % just start in the current directory.
            originalFileName = self.Model.FastProtocols(selectedIndex).ProtocolFileName;
            [filename, dirName] = uigetfile({'*.cfg'}, 'Select a Protocol File', originalFileName);
            
            % If the user cancels, just exit.
            if filename == 0 ,
                return
            end
            
            newFileName=fullfile(dirName, filename);
            theFastProtocol=self.Model.FastProtocols(selectedIndex);
            ws.Controller.setWithBenefits(theFastProtocol,'ProtocolFileName',newFileName);
        end  % function
        
        function TableCellSelected(self,source,event) %#ok<INUSL>
            indices=event.Indices;
            if isempty(indices), return, end
            rowIndex=indices(1);
            %columnIndex=indices(2);
            self.Model.IndexOfSelectedFastProtocol=rowIndex;
        end
    
        function TableCellEdited(self,source,event) %#ok<INUSL>
            indices=event.Indices;
            newString=event.EditData;
            rowIndex=indices(1);
            columnIndex=indices(2);
            fastProtocolIndex=rowIndex;
            if (columnIndex==1) ,
                % this is the Protocol File column
                if isempty(newString) || exist(newString,'file') ,
                    theFastProtocol=self.Model.FastProtocols(fastProtocolIndex);
                    ws.Controller.setWithBenefits(theFastProtocol,'ProtocolFileName',newString);
                end
            elseif (columnIndex==2) ,
                % this is the Action column
                newValue=ws.fastprotocol.StartType.str2num(newString);
                theFastProtocol=self.Model.FastProtocols(fastProtocolIndex);
                ws.Controller.setWithBenefits(theFastProtocol,'AutoStartType',newValue);
            end            
        end  % function        
    end  %methods block
    
    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This method is inhierited from AbstractController, and is
            % called after the user indicates she wants to close the
            % window.  Returns true if the window should _not_ close, false
            % if it should go ahead and close.
            shouldStayPut=false;
            
            % If acquisition is happening, ignore the close window request
            wavesurferModel=self.Model;
            if isempty(wavesurferModel) || ~isvalid(wavesurferModel) ,
                return
            end            
            isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
            if ~isIdle ,
                shouldStayPut=true;
            end
        end  % function
    end % protected methods block    
    
    properties (SetAccess=protected)
       propBindings = struct(); 
    end
    
%     methods
%         function controlActuated(self,controlName,source,event)            
%             %figureObject=self.Figure;
% 
%             try
%                 type=get(source,'Type');
%                 if isequal(type,'uitable') ,
%                     %event
%                     if isfield(event,'EditData') ,
%                         methodName=[controlName 'CellEdited'];
%                     else
%                         methodName=[controlName 'CellSelected'];
%                     end
%                     if ismethod(self,methodName) ,
%                         self.(methodName)(source,event);
%                     end                    
%                 elseif isequal(type,'uicontrol') ,
%                     methodName=[controlName 'Actuated'];
%                     if ismethod(self,methodName) ,
%                         self.(methodName)(source,event);
%                     end
%                 end
%             catch me
%                 isInDebugMode=~isempty(dbstatus());
%                 if isInDebugMode ,
%                     rethrow(me);
%                 else
%                     errordlg(me.message,'Error','modal');
%                 end
%             end
%         end  % function       
%     end    
end
