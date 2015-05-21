classdef UserFunctionsController < ws.Controller & ws.EventSubscriber
    
    methods
        function self = UserFunctionsController(wavesurferController,wavesurferModel)
            userFunctionsModel=wavesurferModel.UserFunctions;
            self = self@ws.Controller(wavesurferController, userFunctionsModel, {'userFunctionsFigureWrapper'});
        end  % constructor
    end  % methods block
    
    methods
        function controlActuated(self,controlName,source,event)            
            try
                type=get(source,'Type');
                if isequal(type,'uicontrol') ,
                    methodName=[controlName 'Actuated'];
                    if ismethod(self,methodName) ,
                        self.(methodName)(source,event);
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
    end

    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin)
            % This method is inhierited from AbstractController, and is
            % called after the user indicates she wants to close the
            % window.  Returns true if the window should _not_ close, false
            % if it should go ahead and close.
            shouldStayPut=false;
            
            % If acquisition is happening, ignore the close window request
            model=self.Model;
            if ~isempty(model) && isvalid(model) ,            
                wavesurferModel=model.Parent;
                if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,
                    isIdle=(wavesurferModel.State==ws.ApplicationState.Idle);
                    if ~isIdle ,
                        shouldStayPut=true;
                        return
                    end
                end
            end
        end  % function
    end % protected methods block    

    properties (SetAccess=protected)
       propBindings = struct(); 
    end
    
    methods
        function ClassNameEditActuated(self,source,event) %#ok<INUSD>
            newString=get(source,'String');
            ws.Controller.setWithBenefits(self.Model,'ClassName',newString);
        end

        function AbortCallsCompleteCheckboxActuated(self,source,event) %#ok<INUSD>
            newValue=get(source,'Value');
            ws.Controller.setWithBenefits(self.Model,'AbortCallsComplete',newValue);
        end
    end
    
end
