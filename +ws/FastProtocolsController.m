classdef FastProtocolsController < ws.Controller
    
    methods
        function self = FastProtocolsController(wavesurferController,wavesurferModel)
            % Call the superclass constructor
            self = self@ws.Controller(wavesurferController,wavesurferModel); 

            % Create the figure, store a pointer to it
            fig = ws.FastProtocolsFigure(wavesurferModel,self) ;
            self.Figure_ = fig ;
        end  % function        
    end  % public methods block

    methods
        function ClearRowButtonActuated(self, varargin)
            %self.Model.clearSelectedFastProtocol() ;
            self.Model.do('clearSelectedFastProtocol') ;
        end  % function
        
        function SelectFileButtonActuated(self, varargin)
            % Allow the user to choose a file to be the protocol file for
            % the currently selected fast protocol.
                        
            % Figure out what directory the file picker dialog will start
            % in.  By default start in the location of the current file.
            % If it is empty it will attempt to start in
            % LastProtocolFilePath, loaded from the shared preferences. If
            % that does not exist, then it will start in the current
            % directory.
            filePickerInitialFolderFromPreferences = ws.Preferences.sharedPreferences().loadPref('LastProtocolFilePath') ;
            originalFastProtocolFileName = self.Model.getSelectedFastProtocolProperty('ProtocolFileName') ;
            if isempty(originalFastProtocolFileName) ,
                if ~exist('startLocationFromPreferences','var') ,
                    filePickerInitialFolder = '' ;
                else
                    filePickerInitialFolder =  filePickerInitialFolderFromPreferences ;
                end
            else
                filePickerInitialFolder = originalFastProtocolFileName ;
            end
            [filename, dirName] = uigetfile({'*.wsp', 'WaveSurfer Protocol Files' ; ...
                                             '*.*',  'All Files (*.*)'} , ...
                                            'Select a Protocol File' , ...
                                            filePickerInitialFolder) ;

            % If the user cancels, just exit.
            if filename == 0 ,
                return
            end
            
            % Set the fast protocol to the selected file
            newProtocolFileName = fullfile(dirName, filename) ;
            self.Model.do('setSelectedFastProtocolProperty', 'ProtocolFileName', newProtocolFileName) ;

%             % If newProtocolFileName and filePickerInitialFolderFromPreferences differ, then
%             % save newProtocolFileName as the new LastProtocolFilePath.
%             if ~isequal( ws.canonicalizePath(filePickerInitialFolderFromPreferences) , ws.canonicalizePath(newProtocolFileName) ) ,
%                 ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', newProtocolFileName);
%             end
        end  % function
        
        function TableCellSelected(self, source, event)  %#ok<INUSL>
            indices = event.Indices ;
            if ~isempty(indices) ,
                rowIndex = indices(1) ;
                %self.Model.IndexOfSelectedFastProtocol = rowIndex ;
                self.Model.do('set', 'IndexOfSelectedFastProtocol', rowIndex) ;                
            end
        end  % function
    
        function TableCellEdited(self,source,event) %#ok<INUSL>
            indices=event.Indices;
            newString=event.EditData;
            rowIndex=indices(1);
            columnIndex=indices(2);
            fastProtocolIndex=rowIndex;
            if (columnIndex==1) ,
                % this is the Protocol File column
%                 if isempty(newString) || exist(newString,'file') ,
%                     theFastProtocol=self.Model.FastProtocols{fastProtocolIndex};
%                     ws.Controller.setWithBenefits(theFastProtocol,'ProtocolFileName',newString);
%                 end
                self.Model.do('setFastProtocolProperty', fastProtocolIndex, 'ProtocolFileName', newString) ;
            elseif (columnIndex==2) ,
                % this is the Action column
                newValue = ws.startTypeFromTitleString(newString) ;  
%                 theFastProtocol=self.Model.FastProtocols{fastProtocolIndex};
%                 ws.Controller.setWithBenefits(theFastProtocol,'AutoStartType',newValue);
                self.Model.do('setFastProtocolProperty', fastProtocolIndex, 'AutoStartType', newValue) ;
            end            
        end  % function        
    end  % public methods block
    
end  % classdef
