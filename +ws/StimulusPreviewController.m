classdef StimulusPreviewController < ws.Controller
    properties  % these are protected by gentleman's agreement
        AxesHandles
    end  % properties
        
    methods
        function self = StimulusPreviewController(model)
            self = self@ws.Controller(model) ;            
            
            set(self.FigureGH_, ...
                'Name', 'Stimulus Preview', ...
                'Color','w', ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle', 'off', ...
                'Visible', 'off') ;
           
           % Create the fixed controls
           %self.createFixedControls_();

           % Layout the figure and set the size
           self.layout_();
           
           % Sync up with the model
           self.update() ;
           
           % Subscribe to model event(s)
           model.subscribeMe(self, 'Update', '', 'update');
           model.subscribeMe(self, 'UpdateStimulusPreview', '', 'update');
           model.subscribeMe(self, 'DidSetSingleFigureVisibility', '', 'updateVisibility') ;
        end  % constructor
    end
    
    methods (Access = protected)
        function createFixedControls_(self)  %#ok<MANU>
        end  % function
        
        function figureSize = layoutFixedControls_(self)
            position = self.FigureGH_.Position ;
            figureSize = position(3:4) ;
        end  % function        
    end  % methods block

    methods (Access=protected)
        function updateControlsInExistance_(self)
            % Delete the existing ones
            ws.deleteIfValidHGHandle(self.AxesHandles);
            
            % Create new controls, three for each additional parameter (the
            % label text, the edit, and the units text)
            model=self.Model_;
            if ~isempty(model) && isvalid(model) ,
                selectedItemClassName = model.selectedStimulusLibraryItemClassName() ;
                if isequal(selectedItemClassName, 'ws.Stimulus') || isequal(selectedItemClassName, 'ws.StimulusMap') ,
                    self.AxesHandles = axes('Parent', self.FigureGH_) ;
                elseif isequal(selectedItemClassName, 'ws.StimulusSequence')
                    nBindings = model.selectedStimulusLibraryItemProperty('NBindings') ;
                    plotHeight = 1/nBindings ;
                    self.AxesHandles = gobjects([1 nBindings]) ;
                    for bindingIndex = 1:nBindings ,
                        % subplot doesn't allow for direct specification of the
                        % target figure
                        self.AxesHandles(bindingIndex) = ...
                            axes('Parent', self.FigureGH_, ...
                                 'OuterPosition', [0 1-bindingIndex*plotHeight 1 plotHeight]) ;
                    end                    
                end
            end
        end
    end
    
    methods (Access=protected)
        function updateControlPropertiesImplementation_(self)
            %fprintf('StimulusLibraryFigure::updateControlPropertiesImplementation_\n');
            model = self.Model_ ;  % this is the WSM
            if isempty(model) || ~isvalid(model) ,
                return
            end
            
            selectedItemClassName = model.selectedStimulusLibraryItemClassName() ;
            if isequal(selectedItemClassName, 'ws.Stimulus') ,
                self.plotStimulus_() ;
            elseif isequal(selectedItemClassName, 'ws.StimulusMap') ,
                self.plotStimulusMap_() ;
            elseif isequal(selectedItemClassName, 'ws.StimulusSequence') ,
                self.plotStimulusSequence_() ;
            else
                % do nothing
            end
        end  % function
    end  % protected methods block

    methods (Access=protected)
        function closeRequested_(self, source, event)  %#ok<INUSD>
            wsModel = self.Model_ ;
            
            if isempty(wsModel) || ~isvalid(wsModel) ,
                shouldStayPut = false ;
            else
                shouldStayPut = ~wsModel.isIdleSensuLato() ;
            end
           
            if shouldStayPut ,
                % Do nothing
            else
                %self.hide() ;
                wsModel.IsStimulusPreviewFigureVisible = false ;                
            end
        end        
    end  % protected methods block

    methods (Access=protected)
        function updateControlEnablementImplementation_(self)  %#ok<MANU>
        end  % function
        
        function plotStimulus_(self)
            stimulusIndex = self.Model_.selectedStimulusLibraryItemIndexWithinClass() ;
            [y, t] = self.Model_.previewStimulus(stimulusIndex) ;
            lineGH = line('Parent', self.AxesHandles, ...
                          'XData', t, ...
                          'YData', y) ;
            ws.setYAxisLimitsToAccomodateLinesBang(self.AxesHandles, lineGH) ;
            n = length(t) ;
            dt = (t(end)-t(1)) / (n-1) ;
            set(self.AxesHandles, 'XLim', [0 n*dt]) ;
            xlabel(self.AxesHandles, 'Time (s)', 'FontSize', 10, 'Interpreter', 'none') ;
            stimulusName = self.Model_.selectedStimulusLibraryItemProperty('Name') ;
            ylabel(self.AxesHandles, stimulusName, 'FontSize', 10, 'Interpreter', 'none') ;                            
        end
        
        function plotStimulusMap_(self)
            mapIndex = self.Model_.selectedStimulusLibraryItemIndexWithinClass() ;
            channelNames = [self.Model_.AOChannelNames self.Model_.DOChannelNames] ;
            mapName = self.Model_.selectedStimulusLibraryItemProperty('Name') ;
            [data, time] = self.Model_.previewStimulusMap(mapIndex) ;
            ws.plotStimulusMapBang(self.AxesHandles, data, time, mapName, channelNames) ;
        end  % function
        
        function plotStimulusSequence_(self)
            sequenceIndex = self.Model_.selectedStimulusLibraryItemIndexWithinClass() ;
            channelNames = [self.Model_.AOChannelNames self.Model_.DOChannelNames] ;
            nBindings = self.Model_.stimulusLibraryItemProperty('ws.StimulusSequence', sequenceIndex, 'NBindings') ;
            mapIndexFromBindingIndex = self.Model_.stimulusLibraryItemProperty('ws.StimulusSequence', sequenceIndex, 'IndexOfEachMapInLibrary') ;
            for bindingIndex = 1:nBindings ,
                ax = self.AxesHandles(bindingIndex) ;
                mapIndex = mapIndexFromBindingIndex{bindingIndex} ;
%                 if isempty(mapIndex) ,
%                     mapName = '' ;
%                 else
%                     mapName = self.Model_.stimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name') ;
%                 end
                [data, time] = self.Model_.previewStimulusMap(mapIndex) ;
                yLabelString = sprintf('Map %d', bindingIndex) ;
                ws.plotStimulusMapBang(ax, data, time, yLabelString, channelNames) ;
                %ylabel(ax, sprintf('Map %d', bindingIndex), 'FontSize', 10, 'Interpreter', 'none') ;
            end
        end  % function
    end  % protected methods block            
    
    methods        
        function delete(self)
            delete@ws.Controller(self) ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
    end  % public methods block    
end  % classdef

