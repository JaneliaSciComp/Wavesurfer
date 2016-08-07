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
            self.Model.toggleIsGridOn();
        end  % method        

        function DoShowButtonsMenuItemGHActuated(self, varargin)
            self.Model.toggleDoShowButtons();
        end  % method        

        function InvertColorsMenuItemGHActuated(self, varargin)
            self.Model.toggleAreColorsNormal();
        end  % method        

        function arrangementMenuItemActuated(self, varargin)
            self.PlotArrangementDialogFigure_ = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            plotArrangementDialogModel = [] ;
            parentFigurePosition = get(self.Figure,'Position') ;
            channelNames = self.Model.Parent.Acquisition.ChannelNames ;
            isDisplayed = horzcat(self.Model.IsAnalogChannelDisplayed, self.Model.IsDigitalChannelDisplayed) ;
            plotHeights = horzcat(self.Model.AnalogChannelHeights, self.Model.DigitalChannelHeights) ;
            rowIndexFromChannelIndex = horzcat(self.Model.RowIndexFromAnalogChannelIndex, self.Model.RowIndexFromDigitalChannelIndex) ;
            %nChannels = length(channelNames) ;
            %plotHeights = ones(1,nChannels) ;
            %plotOrdinality = 1:nChannels ;
            callbackFunction = ...
                @(isDisplayed,plotHeights,rowIndexFromChannelIndex)(self.Model.setPlotHeightsAndOrder_(isDisplayed,plotHeights,rowIndexFromChannelIndex)) ;
            self.PlotArrangementDialogFigure_ = ...
                ws.PlotArrangementDialogFigure(plotArrangementDialogModel, ...
                                               parentFigurePosition, ...
                                               channelNames, isDisplayed, plotHeights, rowIndexFromChannelIndex, ...
                                               callbackFunction) ;
        end  % method        

        function AnalogChannelMenuItemsActuated(self, source, event, aiChannelIndex)  %#ok<INUSL>
            self.Model.toggleIsAnalogChannelDisplayed(aiChannelIndex) ;
        end  % method        

        function DigitalChannelMenuItemsActuated(self, source, event, diChannelIndex)  %#ok<INUSL>
            self.Model.toggleIsDigitalChannelDisplayed(diChannelIndex) ;
        end  % method        
                                
        function YScrollUpButtonGHActuated(self, source, event, channelIndex) %#ok<INUSL>
            self.Model.scrollUp(channelIndex);
        end
                
        function YScrollDownButtonGHActuated(self, source, event, channelIndex) %#ok<INUSL>
            self.Model.scrollDown(channelIndex);
        end
                
        function YZoomInButtonGHActuated(self, source, event, channelIndex) %#ok<INUSL>
            self.Model.zoomIn(channelIndex);
        end
                
        function YZoomOutButtonGHActuated(self, source, event, channelIndex) %#ok<INUSL>
            self.Model.zoomOut(channelIndex);
        end
                
        function SetYLimTightToDataButtonGHActuated(self, source, event, channelIndex) %#ok<INUSL>
            self.Model.setYAxisLimitsTightToData(channelIndex);
        end  % method       
        
        function SetYLimTightToDataLockedButtonGHActuated(self, source, event, channelIndex) %#ok<INUSL>
            self.Model.toggleAreYLimitsLockedTightToData(channelIndex);
        end  % method       

        function SetYLimButtonGHActuated(self, source, event, aiChannelIndex)  %#ok<INUSL>
            self.MyYLimDialogFigure=[];  % if not first call, this should cause the old controller to be garbage collectable
            myYLimDialogModel = [] ;
            parentFigurePosition = get(self.Figure,'Position') ;
            yLimits = self.Model.YLimitsPerAnalogChannel(:,aiChannelIndex)' ;
            yUnits = self.Model.Parent.Acquisition.AnalogChannelUnits{aiChannelIndex} ;
            callbackFunction = @(newYLimits)(self.Model.setYLimitsForSingleAnalogChannel(aiChannelIndex, newYLimits)) ;
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
    
    methods (Access=protected)
%         function shouldStayPut = shouldWindowStayPutQ(self, varargin)
%             % This method is inhierited from AbstractController, and is
%             % called after the user indicates she wants to close the
%             % window.  Returns true if the window should _not_ close, false
%             % if it should go ahead and close.
%             
%             % If acquisition is happening, ignore the close window request
%             wavesurferModel = ws.getSubproperty(self,'Model','Parent','Parent') ;
%             if ~isempty(wavesurferModel) && isvalid(wavesurferModel) ,                
%                 isIdle=isequal(wavesurferModel.State,'idle')||isequal(wavesurferModel.State,'no_device');
%                 if isIdle ,
%                     shouldStayPut=false;
%                 else                 
%                     shouldStayPut=true;
%                 end
%             else
%                 shouldStayPut=false;                
%             end
%         end  % function
    end % protected methods block
    
%     methods (Access=protected)
%         function layoutOfWindowsInClassButOnlyForThisWindow = encodeWindowLayout_(self)
%             window = self.Figure;
%             layoutOfWindowsInClassButOnlyForThisWindow = struct();
%             tag = get(window, 'Tag');
%             layoutOfWindowsInClassButOnlyForThisWindow.(tag).Position = get(window, 'Position');
%             isVisible=self.Model.IsVisibleWhenDisplayEnabled;
%             layoutOfWindowsInClassButOnlyForThisWindow.(tag).IsVisibleWhenDisplayEnabled = isVisible;
% %             if ws.most.gui.AdvancedPanelToggler.isFigToggleable(window)
% %                 layoutOfWindowsInClassButOnlyForThisWindow.(tag).Toggle = ws.most.gui.AdvancedPanelToggler.saveToggleState(window);
% %             else
% %                 layoutOfWindowsInClassButOnlyForThisWindow.(tag).Toggle = [];
% %             end
%         end
%         
%         function decodeWindowLayout(self, layoutOfWindowsInClass, monitorPositions)
%             window = self.Figure ;
%             tag = get(window, 'Tag');
%             if isfield(layoutOfWindowsInClass, tag) ,
%                 thisWindowLayout = layoutOfWindowsInClass.(tag);
%                 set(window, 'Position', thisWindowLayout.Position);
%                 window.constrainPositionToMonitors(monitorPositions) ;
%                 if isfield(thisWindowLayout,'IsVisibleWhenDisplayEnabled') ,
%                     %set(window, 'Visible', layoutInfo.Visible);
%                     % Have to do this at the controller level, so that the
%                     % WavesurferModel gets updated.
%                     model=self.Model;
%                     if ~isempty(model) ,
%                         model.IsVisibleWhenDisplayEnabled=thisWindowLayout.IsVisibleWhenDisplayEnabled;
%                     end
%                 end
%             end
%         end  % function
% 
%     end  % protected methods block
    
%     properties (SetAccess=protected)
%        propBindings = struct();
%     end
    
end  % classdef
