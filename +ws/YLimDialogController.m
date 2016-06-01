classdef YLimDialogController < ws.Controller
    properties (Dependent=true)
        ModelPropertyName
    end
    
    properties (Access=protected)
        ModelPropertyName_
    end
    
    methods
        function self=YLimDialogController(parentController,parentModel,parentFigurePosition,modelPropertyName)
%             self = self@ws.Controller(parentController, parentModel, {}, {'yLimDialogFigureWrapper'});  % want the figure to start out invisible
%             %self.IsSuiGeneris_ = false;  % Multiple instances of this controller can coexist in the same Wavesurfer session            
%             self.HideFigureOnClose_ = false;                        
%             self.Figure.centerOnParentPosition(parentFigurePosition);
%             self.showFigure();
            
            % Call the superclass constructor
            self = self@ws.Controller(parentController,parentModel);

            % Store the model property name
            self.ModelPropertyName_ = modelPropertyName ;
            
            % Create the figure, store a pointer to it
            fig = ws.YLimDialogFigure(parentModel,self) ;
            self.Figure_ = fig ;                                    
            
            % Do stuff specific to dialog boxes
            self.HideFigureOnClose_ = false;
            self.Figure.centerOnParentPosition(parentFigurePosition);
            self.showFigure();
        end
        
        function delete(self)
            self.Parent_=[];
        end
                
        function controlActuated(self,source,event)
            figureObject=self.Figure;
            try
                if source==figureObject.OKButton ,
                    self.okButtonPressed(source,event);
                elseif source==figureObject.CancelButton ,
                    self.cancelButtonPressed(source,event);
                end  % switch
            catch me
%                 isInDebugMode=~isempty(dbstatus());
%                 if isInDebugMode ,
%                     rethrow(me);
%                 else
                    ws.errordlg(me.message,'Error','modal');
%                 end
            end
        end  % method
        
        function okButtonPressed(self,source,event) %#ok<INUSL>
            yMaxAsString=get(self.Figure.YMaxEdit,'String');
            yMinAsString=get(self.Figure.YMinEdit,'String');
            yMax=str2double(yMaxAsString);
            yMin=str2double(yMinAsString);
            if isfinite(yMax) && isfinite(yMin) ,
                if yMin>yMax ,
                    temp=yMax;
                    yMax=yMin;
                    yMin=temp;
                end
                if yMin~=yMax ,
                    propertyName = self.ModelPropertyName_ ;
                    self.Model.(propertyName) = [yMin yMax] ;
                end
            end
            self.windowCloseRequested(self.Figure.FigureGH,event);
        end  % function
        
        function cancelButtonPressed(self,source,event) %#ok<INUSL>
            self.windowCloseRequested(self.Figure.FigureGH,event);
        end
        
        function result = get.ModelPropertyName(self) 
            result = self.ModelPropertyName_ ;
        end
    end  % methods
    
    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin) %#ok<INUSD>
            shouldStayPut=false;
        end  % function
    end % protected methods block
    
    properties (SetAccess=protected)
       propBindings = struct();
    end
    
end  % classdef
