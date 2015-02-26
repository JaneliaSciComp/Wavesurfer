classdef YLimDialogController < ws.Controller
    methods
        function self=YLimDialogController(scopeController,scopeModel,scopeFigurePosition)
            self = self@ws.Controller(scopeController, scopeModel, {}, {'yLimDialogFigureWrapper'});  % want the figure to start out invisible
            self.IsSuiGeneris=false;  % Multiple instances of this controller can coexist in the same Wavesurfer session            
            self.HideFigureOnClose = false;                        
            self.Figure.centerOnParentPosition(scopeFigurePosition);
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
                    errordlg(me.message,'Error','modal');
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
                    self.Model.YLim=[yMin yMax];
                end
            end
            self.windowCloseRequested(self.Figure.FigureGH,event);
        end  % function
        
        function cancelButtonPressed(self,source,event) %#ok<INUSL>
            self.windowCloseRequested(self.Figure.FigureGH,event);
        end
    end  % methods
    
    methods (Access=protected)
        function shouldStayPut = shouldWindowStayPutQ(self, varargin) %#ok<INUSD>
            % This method is inhierited from AbstractController, and is
            % called after the user indicates she wants to close the
            % window.  Returns true if the window should _not_ close, false
            % if it should go ahead and close.
            shouldStayPut=false;
        end  % function
    end % protected methods block
    
    properties (SetAccess=protected)
       propBindings = struct();
    end
    
end  % classdef
