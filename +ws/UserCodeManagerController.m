classdef UserCodeManagerController < ws.Controller     %& ws.EventSubscriber
    
    methods
        function self = UserCodeManagerController(wavesurferController, wavesurferModel)
            % Call the superclass constructor
            %userFunctionsModel=wavesurferModel.UserCodeManager;
            self = self@ws.Controller(wavesurferController,wavesurferModel);

            % Create the figure, store a pointer to it
            fig = ws.UserCodeManagerFigure(wavesurferModel,self) ;
            self.Figure_ = fig ;                        
        end  % constructor
    end  % methods block
    
    methods
        function ClassNameEditActuated(self,source,event) %#ok<INUSD>
            newString = get(source,'String') ;
            %ws.Controller.setWithBenefits(self.Model,'ClassName',newString);
            self.Model.do('set', 'UserClassName', newString) ;
        end

%         function InstantiateButtonActuated(self,source,event) %#ok<INUSD>
%             % This doesn't actually do anything.  It's there just to give
%             % the user something obvious to do after they edit the
%             % ClassName editbox.  The edit box losing keyboard focus
%             % triggers the ClassNameEditActuated callback, which
%             % instantiates a model object.
%             
%             %self.Model.do('instantiateUserObject') ;            
%         end
        
        function ReinstantiateButtonActuated(self,source,event) %#ok<INUSD>
            self.Model.do('reinstantiateUserObject') ;            
        end
        
%         function ChooseButtonActuated(self,source,event) %#ok<INUSD>
%             mAbsoluteFileName = uigetdir(self.Model.DataFileLocation, 'Choose User Class M-file...');
%             if ~isempty(mAbsoluteFileName) ,
%                 self.Model.DataFileLocation = mAbsoluteFileName;
%             end            
%         end
    end
    
end
