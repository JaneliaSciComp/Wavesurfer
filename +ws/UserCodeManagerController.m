classdef UserCodeManagerController < ws.Controller     %& ws.EventSubscriber
    
    methods
        function self = UserCodeManagerController(wavesurferController,wavesurferModel)
%             userFunctionsModel=wavesurferModel.UserCodeManager;
%             self = self@ws.Controller(wavesurferController, userFunctionsModel, {'userFunctionsFigureWrapper'});
            
            % Call the superclass constructor
            userFunctionsModel=wavesurferModel.UserCodeManager;
            self = self@ws.Controller(wavesurferController,userFunctionsModel);

            % Create the figure, store a pointer to it
            fig = ws.UserCodeManagerFigure(userFunctionsModel,self) ;
            self.Figure_ = fig ;                        
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
                    ws.errordlg(me.message,'Error','modal');
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
                    isIdle=isequal(wavesurferModel.State,'idle');
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

        function ReinstantiateButtonActuated(self,source,event) %#ok<INUSD>
            self.Model.reinstantiateUserObject();
        end
        
        function ChooseButtonActuated(self,source,event) %#ok<INUSD>
            mAbsoluteFileName = uigetdir(self.Model.Logging.FileLocation, 'Choose User Class M-file...');
            if ~isempty(mAbsoluteFileName) ,
                self.Model.Logging.FileLocation = mAbsoluteFileName;
            end
        end
    end
    
end
