% HHMI - Janelia Farms Research Campus 2014 
% Author: Arunesh Mittal mittala@janelia.org (Adapted from code written by 
% Jinyang Liu)

classdef BiasCameraInterface < handle
    
    properties
        address = ''
        port = []
        %biasExeDirName = 'bias_fc2_win64-v0.53-plugin-dev-07';
        biasExeDirName = 'C:/Users/labadmin/Desktop/bias_fc2_win64-v0.54-plugin-dev-08'
        %biasExeFileName = 'bias_gui_v0p53.exe';%'bias_gui_v049.exe';
        biasExeFileName = 'bias_gui_v0p54.exe'
    end
    
    properties (Dependent)
        baseUrl
    end
    
    methods
        function self = BiasCameraInterface(address, port)
            self.address = address;
            self.port = port;
            [~,cmdout] = system(sprintf('tasklist /fo LIST /fi "Imagename eq %s"',self.biasExeFileName));
            nInstancesOfBIAS = length(strfind(cmdout,self.biasExeFileName));
            if nInstancesOfBIAS == 0
                % If BIAS is not running, launch it
                fprintf('Launching BIAS...');
                %biasExeAbsoluteFileName = which(self.biasExeFileName);
                biasExeAbsoluteFileName = fullfile(biasExeDirName, biasExeFileName) ;
                if ~isempty(biasExeAbsoluteFileName) ,
                    system(['start "Matlab driven BIAS" ' biasExeAbsoluteFileName]);
                    fprintf('done.\n');
                else
                    fprintf('Executable "%s" not found.\n', biasExeAbsoluteFileName);
                end
            elseif nInstancesOfBIAS == 1 ,
                % No need to do anything here
            else
                % i.e. nInstancesOfBIAS > 1 
                fprintf(['More than one instance of ' self.biasExeFileName 'found running!\n']);
                fprintf('Quitting all instances and restarting BIAS.\n');
                system(['taskkill /F /IM ' self.biasExeFileName]);
                biasExeAbsoluteFileName = fullfile(biasExeDirName, biasExeFileName) ;
                system(['start "Matlab driven BIAS" ' biasExeAbsoluteFileName]);
            end
        end
        
        function kill(self)
            fprintf(['One instance of ' self.biasExeFileName ' found running!\n']);
            system(['taskkill /F /IM ' self.biasExeFileName]);
        end
        
        function rsp = connect(self)
            cmd = sprintf('%s/?connect',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = disconnect(self)
            cmd = sprintf('%s/?disconnect',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = startCapture(self)
            cmd = sprintf('%s/?start-capture',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = stopCapture(self)
            cmd = sprintf('%s/?stop-capture',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = getConfiguration(self)
            cmd = sprintf('%s/?get-configuration', self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = setConfiguration(self,config)
            configJson = structToJson(config);
            cmd = sprintf('%s/?set-configuration=%s',self.baseUrl, configJson);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = enableLogging(self)
            cmd = sprintf('%s/?enable-logging',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = disableLogging(self)
            cmd = sprintf('%s/?disable-logging', self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = loadConfiguration(self,fileName)
            cmd = sprintf('%s/?load-configuration=%s',self.baseUrl,fileName);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = saveConfiguration(self,fileName)
            cmd = sprintf('%s/?save-configuration=%s',self.baseUrl,fileName);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = getFrameCount(self)
            cmd = sprintf('%s/?get-frame-count',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = getCameraGuid(self)
            cmd = sprintf('%s/?get-camera-guid',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = getStatus(self)
            cmd = sprintf('%s/?get-status', self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = setVideoFile(self,fileName)
            cmd = sprintf('%s/?set-video-file=%s',self.baseUrl,fileName);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = getVideoFile(self)
            cmd = sprintf('%s/?get-video-file',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = getTimeStamp(self)
            cmd = sprintf('%s/?get-time-stamp', self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = getFramesPerSec(self)
            cmd = sprintf('%s/?get-frames-per-sec', self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = setCameraName(self,name)
            cmd = sprintf('%s/?set-camera-name=%s',self.baseUrl,name);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = setWindowGeometry(self, geom)
            geomJson = structToJson(geom);
            cmd = sprintf('%s/?set-window-geometry=%s',self.baseUrl,geomJson);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = getWindowGeometry(self)
            cmd = sprintf('%s/?get-window-geometry',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function rsp = closeWindow(self)
            cmd = sprintf('%s/?close',self.baseUrl);
            rsp = self.sendCmd(cmd);
        end
        
        function baseUrl = get.baseUrl(self)
            baseUrl = sprintf('http://%s:%d',self.address,self.port);
        end
        
        function rsp = initializeCamera(self,varargin)
            %property list: frameRate, movieFormat, ROI, triggerMode
            nVarargs = length(varargin);
            
           switch nVarargs
                case 0
                    frameRate = 50;
                    movieFormat = 'ufmf';
                    ROI = [0,0,1280,960];
                    triggerMode = 'Internal';
                case 1
                    frameRate = varargin{1};
                    movieFormat = 'ufmf';
                    ROI = [0,0,1280,960];
                    triggerMode = 'Internal';
                case 2
                    frameRate = varargin{1};
                    movieFormat = varargin{2};
                    ROI = [0,0,1280,960];
                    triggerMode = 'Internal';
                case 3
                    frameRate = varargin{1};
                    movieFormat = varargin{2};
                    ROI = varargin{3};
                    triggerMode = 'Internal';
               case 4
                    frameRate = varargin{1};
                    movieFormat = varargin{2};
                    ROI = varargin{3};
                    triggerMode = varargin{4};
               case 5
                   frameRate = varargin{1};
                    movieFormat = varargin{2};
                    ROI = varargin{3};
                    triggerMode = varargin{4};
                    shutterValue = varargin{5};
            end
            
            %connect to the server
            self.connect();
            
            % Get current configuration
            rsp = self.getConfiguration();
            config = rsp(1).value;
            
            % Set frame rate if configuration structure - note to use absolute value
            % asbolute control must be enabled (set to true).
            config.camera.properties.frameRate.absoluteControl = 1;
            config.camera.properties.frameRate.autoActive = 0;
            config.camera.properties.frameRate.absoluteValue = frameRate;
            config.camera.properties.shutter.value = shutterValue;
            
            %set movie format
            if strcmp(movieFormat, 'avi')
                config.logging.format = 'avi';
                config.logging.settings.avi.frameSkip = 1;
            elseif strcmp(movieFormat, 'ufmf')
            end
            
            % Set ROI in configuration
            config.camera.format7Settings.roi.offsetX = ROI(1)-rem(ROI(1),8);  %step 8
            config.camera.format7Settings.roi.offsetY = ROI(2)-rem(ROI(2),2);  %step 2
            config.camera.format7Settings.roi.width = ROI(3)-rem(ROI(3),16);   %step 16
            config.camera.format7Settings.roi.height = ROI(4)-rem(ROI(4),2);   %step 2
            
            %trigger mode is either internal or external
            if strncmpi(triggerMode, 'ex', 2)
                config.camera.triggerType = 'External';
            else
                config.camera.triggerType = 'Internal';
            end
            
            % Set new configuration
            rsp = self.setConfiguration(config);
            if rsp(1).success
                fprintf('ROI set successfully\n');
            else
                fprintf('Error setting ROI %s\n',rsp.message);
            end
        end  % method
        
        function rsp = justConnectToCamera(self)
            %property list: frameRate, movieFormat, ROI, triggerMode
            %nVarargs = length(varargin);
            
%            switch nVarargs
%                 case 0
%                     frameRate = 50;
%                     movieFormat = 'ufmf';
%                     ROI = [0,0,1280,960];
%                     triggerMode = 'Internal';
%                 case 1
%                     frameRate = varargin{1};
%                     movieFormat = 'ufmf';
%                     ROI = [0,0,1280,960];
%                     triggerMode = 'Internal';
%                 case 2
%                     frameRate = varargin{1};
%                     movieFormat = varargin{2};
%                     ROI = [0,0,1280,960];
%                     triggerMode = 'Internal';
%                 case 3
%                     frameRate = varargin{1};
%                     movieFormat = varargin{2};
%                     ROI = varargin{3};
%                     triggerMode = 'Internal';
%                case 4
%                     frameRate = varargin{1};
%                     movieFormat = varargin{2};
%                     ROI = varargin{3};
%                     triggerMode = varargin{4};
%                case 5
%                    frameRate = varargin{1};
%                     movieFormat = varargin{2};
%                     ROI = varargin{3};
%                     triggerMode = varargin{4};
%                     shutterValue = varargin{5};
%             end
            
            %connect to the server
            self.connect();
            
            % Get current configuration
            rsp = self.getConfiguration();
%             config = rsp(1).value;
%             
%             % Set frame rate if configuration structure - note to use absolute value
%             % asbolute control must be enabled (set to true).
%             config.camera.properties.frameRate.absoluteControl = 1;
%             config.camera.properties.frameRate.autoActive = 0;
%             config.camera.properties.frameRate.absoluteValue = frameRate;
%             config.camera.properties.shutter.value = shutterValue;
%             
%             %set movie format
%             if strcmp(movieFormat, 'avi')
%                 config.logging.format = 'avi';
%                 config.logging.settings.avi.frameSkip = 1;
%             elseif strcmp(movieFormat, 'ufmf')
%             end
%             
%             % Set ROI in configuration
%             config.camera.format7Settings.roi.offsetX = ROI(1)-rem(ROI(1),8);  %step 8
%             config.camera.format7Settings.roi.offsetY = ROI(2)-rem(ROI(2),2);  %step 2
%             config.camera.format7Settings.roi.width = ROI(3)-rem(ROI(3),16);   %step 16
%             config.camera.format7Settings.roi.height = ROI(4)-rem(ROI(4),2);   %step 2
%             
%             %trigger mode is either internal or external
%             if strncmpi(triggerMode, 'ex', 2)
%                 config.camera.triggerType = 'External';
%             else
%                 config.camera.triggerType = 'Internal';
%             end
%             
%             % Set new configuration
%             rsp = self.setConfiguration(config);
%             if rsp(1).success
%                 fprintf('ROI set successfully\n');
%             else
%                 fprintf('Error setting ROI %s\n',rsp.message);
%             end
        end  % method
    end  % public methods block
    
    methods (Access=protected)        
        function rsp = sendCmd(self, cmd)  %#ok<INUSL>
            rspString = urlread(cmd);
            rsp = loadjson(rspString);
        end
    end
    
    methods (Access=private)
    end
end

function valJson = structToJson(val)
    valJson = savejson('',val);
    valJson = strrep(valJson,sprintf('\n'), '');
    valJson = strrep(valJson,sprintf('\t'), '');
end