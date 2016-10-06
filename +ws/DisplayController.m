classdef DisplayController < ws.Controller
    
    properties
        MyYLimDialogFigure=[]
    end

    properties (Access=protected)
        PlotArrangementDialogFigure_ = []
    end
    
    methods
        function self=DisplayController(wavesurferController, wavesurferModel)
            % Call the superclass constructor
            displayModel = wavesurferModel.Display ;
            self = self@ws.Controller(wavesurferController, displayModel);

            % Create the figure, store a pointer to it
            fig = ws.DisplayFigure(displayModel,self) ;
            self.Figure_ = fig ;
        end
        
        function delete(self)
             self.MyYLimDialogFigure=[];
        end
        
        function ShowGridMenuItemGHActuated(self, varargin)
            %self.Model.toggleIsGridOn();
            self.Model.do('toggleIsGridOn') ;
        end  % method        

        function DoShowButtonsMenuItemGHActuated(self, varargin)
            %self.Model.toggleDoShowButtons();
            self.Model.do('toggleDoShowButtons') ;
        end  % method        

        function doColorTracesMenuItemActuated(self, varargin)
            %self.Model.toggleDoColorTraces() ;
            self.Model.do('toggleDoColorTraces') ;
        end  % method        
        
        function InvertColorsMenuItemGHActuated(self, varargin)
            %self.Model.toggleAreColorsNormal();
            self.Model.do('toggleAreColorsNormal');
        end  % method        

        function arrangementMenuItemActuated(self, varargin)
            self.PlotArrangementDialogFigure_ = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            plotArrangementDialogModel = [] ;
            parentFigurePosition = get(self.Figure,'Position') ;
            channelNames = self.Model.Parent.Acquisition.ChannelNames ;
            isDisplayed = horzcat(self.Model.IsAnalogChannelDisplayed, self.Model.IsDigitalChannelDisplayed) ;
            plotHeights = horzcat(self.Model.PlotHeightFromAnalogChannelIndex, self.Model.PlotHeightFromDigitalChannelIndex) ;
            rowIndexFromChannelIndex = horzcat(self.Model.RowIndexFromAnalogChannelIndex, self.Model.RowIndexFromDigitalChannelIndex) ;
            %callbackFunction = ...
            %    @(isDisplayed,plotHeights,rowIndexFromChannelIndex)(self.Model.setPlotHeightsAndOrder(isDisplayed,plotHeights,rowIndexFromChannelIndex)) ;
            callbackFunction = ...
                @(isDisplayed,plotHeights,rowIndexFromChannelIndex)(self.Model.do('setPlotHeightsAndOrder',isDisplayed,plotHeights,rowIndexFromChannelIndex)) ;
            self.PlotArrangementDialogFigure_ = ...
                ws.PlotArrangementDialogFigure(plotArrangementDialogModel, ...
                                               parentFigurePosition, ...
                                               channelNames, isDisplayed, plotHeights, rowIndexFromChannelIndex, ...
                                               callbackFunction) ;
        end  % method        

        function AnalogChannelMenuItemsActuated(self, source, event, aiChannelIndex)  %#ok<INUSL>
            %self.Model.toggleIsAnalogChannelDisplayed(aiChannelIndex) ;
            self.Model.do('toggleIsAnalogChannelDisplayed', aiChannelIndex) ;
        end  % method        

        function DigitalChannelMenuItemsActuated(self, source, event, diChannelIndex)  %#ok<INUSL>
            %self.Model.toggleIsDigitalChannelDisplayed(diChannelIndex) ;
            self.Model.do('toggleIsDigitalChannelDisplayed', diChannelIndex) ;
        end  % method        
                                
        function YScrollUpButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            %self.Model.scrollUp(plotIndex);
            self.Model.do('scrollUp', plotIndex) ;
        end
                
        function YScrollDownButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            %self.Model.scrollDown(plotIndex);
            self.Model.do('scrollDown', plotIndex) ;
        end
                
        function YZoomInButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            %self.Model.zoomIn(plotIndex);
            self.Model.do('zoomIn', plotIndex) ;
        end
                
        function YZoomOutButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            %self.Model.zoomOut(plotIndex);
            self.Model.do('zoomOut', plotIndex) ;
        end
                
        function SetYLimTightToDataButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            self.Figure.setYAxisLimitsTightToData(plotIndex) ;
        end  % method       
        
        function SetYLimTightToDataLockedButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            self.Figure.toggleAreYLimitsLockedTightToData(plotIndex) ;
        end  % method       

        function SetYLimButtonGHActuated(self, source, event, plotIndex)  %#ok<INUSL>
            self.MyYLimDialogFigure=[] ;  % if not first call, this should cause the old controller to be garbage collectable
            myYLimDialogModel = [] ;
            parentFigurePosition = get(self.Figure,'Position') ;
            aiChannelIndex = self.Model.ChannelIndexWithinTypeFromPlotIndex(plotIndex) ;
            yLimits = self.Model.YLimitsPerAnalogChannel(:,aiChannelIndex)' ;
            yUnits = self.Model.Parent.Acquisition.AnalogChannelUnits{aiChannelIndex} ;
            %callbackFunction = @(newYLimits)(self.Model.setYLimitsForSingleAnalogChannel(aiChannelIndex, newYLimits)) ;
            callbackFunction = @(newYLimits)(self.Model.do('setYLimitsForSingleAnalogChannel', aiChannelIndex, newYLimits)) ;
            self.MyYLimDialogFigure = ...
                ws.YLimDialogFigure(myYLimDialogModel, parentFigurePosition, yLimits, yUnits, callbackFunction) ;
        end  % method        
        
    end  % public methods block

    methods
        function castOffAllAttachments(self)
            self.unsubscribeFromAll() ;
            self.Figure.castOffAllAttachments() ;
        end                
    end            
    
end  % classdef
