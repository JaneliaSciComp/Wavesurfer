classdef MicroManagerInterface < handle
    
    properties (Access=private)
        address_
        port_
    end
    
    methods
        function self = MicroManagerInterface(address, port)
            if ~exist('address', 'var') || isempty(address)
                address = '127.0.0.1' ;
            end            
            if ~exist('port', 'var') || isempty(port)
                port = 8000 ;
            end
            self.address_ = address;
            self.port_ = port;
        end
        
        function delete(self)  %#ok<INUSD>
            %self.disconnect() ;
        end

        function result = isBusy(self)
            command = sprintf('%s/get/busy/', self.baseUrl_()) ;
            response = self.sendCommand_(command) ;
            result = strcmpi(response.status,'true') ;
        end
        
        function result = isCameraBusy(self)
            command = sprintf('%s/get/busy/?device=Camera', self.baseUrl_()) ;
            response = self.sendCommand_(command) ;
            result = strcmpi(response.status,'true') ;
        end
        
        function result = isAcquiring(self)
            command = sprintf('%s/get/acquisition/', self.baseUrl_()) ;
            response = self.sendCommand_(command) ;
            result = strcmpi(response.status,'true') ;
        end
        
        function runWithoutBlocking(self)
            command = sprintf('%s/run/acquisition/?run&blocking=false', self.baseUrl_()) ;
            %command = sprintf('%s/?run&blocking=false', self.baseUrl_()) ;
            response = self.sendCommand_(command);
            if ~isscalar(response) || ~isstruct(response) || ~isfield(response, 'status') || ~strcmpi(response.status,'OK') ,
                error('MicroManagerInterface:reponseNotOK', ...
                      'Micro-Manager server returned a non-OK reponse') ;
            end
        end
    end  % public methods block
    
    methods (Access=protected)        
        function result = baseUrl_(self)
            result = sprintf('http://%s:%d',self.address_,self.port_);
        end
        
        function response = sendCommand_(self, commandString)  %#ok<INUSL>
            try
                responseString = urlread(commandString) ;
            catch me
                if isequal(me.identifier, 'MATLAB:urlread:ConnectionFailed') ,
                    error('MicroManagerInterface:unableToConnectToServer', ...
                          'Unable to connect to Micro-Manager server') ;
                else
                    me.rethrow() ;
                end
            end
%             if length(responseString)<80 ,
%                 trimmedResponseString = responseString ;
%             else
%                 trimmedResponseString = responseString(1:80) ;
%             end
%             trimmedResponseString
            try 
                response = loadjson(responseString) ;
            catch me
                % If the server doesn't understand the request, it returns an HTML "help"
                % page
                if isequal(me.message, 'input file does not exist') ,
                    error('MicroManagerInterface:badRequest', ...
                          'Micro-Manager server did not understand request %s', commandString) ;
                else
                    rethrow(me) ;
                end
            end
        end  % function
    end  % protected methods block
end  % classdef

% function result = jsonFromStruct(s)
%     result = savejson('',s);
%     result = strrep(result,sprintf('\n'), '');  %#ok<SPRINTFN>
%     result = strrep(result,sprintf('\t'), '');
% end
