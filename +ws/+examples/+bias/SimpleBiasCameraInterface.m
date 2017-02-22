% HHMI - Janelia Farms Research Campus 2014 
% Author: Arunesh Mittal mittala@janelia.org (Adapted from code written by 
% Jinyang Liu)

classdef SimpleBiasCameraInterface < handle
    
    properties (SetAccess=protected)
        address_ = ''
        port_ = []
    end
    
    methods
        function self = SimpleBiasCameraInterface(address, port)
            self.address_ = address;
            self.port_ = port;
        end
        
        function delete(self)  %#ok<INUSD>
            %self.disconnect() ;
        end

        function rsp = connect(self)
            cmd = sprintf('%s/?connect',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = disconnect(self)
            cmd = sprintf('%s/?disconnect',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = startCapture(self)
            cmd = sprintf('%s/?start-capture',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = stopCapture(self)
            cmd = sprintf('%s/?stop-capture',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = getConfiguration(self)
            cmd = sprintf('%s/?get-configuration', self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = setConfiguration(self,config)
            configJson = structToJson(config);
            cmd = sprintf('%s/?set-configuration=%s',self.baseUrl_(), configJson);
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = enableLogging(self)
            cmd = sprintf('%s/?enable-logging',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = disableLogging(self)
            cmd = sprintf('%s/?disable-logging', self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = loadConfiguration(self,fileName)
            cmd = sprintf('%s/?load-configuration=%s',self.baseUrl_(),fileName);
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = saveConfiguration(self,fileName)
            cmd = sprintf('%s/?save-configuration=%s',self.baseUrl_(),fileName);
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = getFrameCount(self)
            cmd = sprintf('%s/?get-frame-count',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = getCameraGuid(self)
            cmd = sprintf('%s/?get-camera-guid',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = getStatus(self)
            cmd = sprintf('%s/?get-status', self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = setVideoFile(self,fileName)
            cmd = sprintf('%s/?set-video-file=%s',self.baseUrl_(),fileName);
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = getVideoFile(self)
            cmd = sprintf('%s/?get-video-file',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = getTimeStamp(self)
            cmd = sprintf('%s/?get-time-stamp', self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = getFramesPerSec(self)
            cmd = sprintf('%s/?get-frames-per-sec', self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = setCameraName(self,name)
            cmd = sprintf('%s/?set-camera-name=%s',self.baseUrl_(),name);
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = setWindowGeometry(self, geom)
            geomJson = structToJson(geom);
            cmd = sprintf('%s/?set-window-geometry=%s',self.baseUrl_(),geomJson);
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = getWindowGeometry(self)
            cmd = sprintf('%s/?get-window-geometry',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
        
        function rsp = closeWindow(self)
            cmd = sprintf('%s/?close',self.baseUrl_());
            rsp = self.sendCommand_(cmd);
        end
                
        function rsp = connectAndGetConfiguration(self)
            %connect to the server
            self.connect();
            
            % Get current configuration
            rsp = self.getConfiguration();
        end  % method
    end  % public methods block
    
    methods (Access=protected)        
        function result = baseUrl_(self)
            result = sprintf('http://%s:%d',self.address_,self.port_);
        end
        
        function response = sendCommand_(self, commandString)  %#ok<INUSL>
            try
                responseString = urlread(commandString);
            catch me
                if isequal(me.identifier, 'MATLAB:urlread:ConnectionFailed') ,
                    error('SimpleBiasCameraInterface:unableToConnectToBIASServer', ...
                          'Unable to connect to BIAS server') ;
                else
                    me.rethrow() ;
                end
            end
            % JSONlab 1.5 seems to wrap the responses in a cell, so we
            % unwrap.
            responseAsSingletonCellArray = loadjson(responseString) ;
            response = responseAsSingletonCellArray{1} ;
        end
    end
end

function valJson = structToJson(val)
    valJson = savejson('',val);
    valJson = strrep(valJson,sprintf('\n'), '');
    valJson = strrep(valJson,sprintf('\t'), '');
end