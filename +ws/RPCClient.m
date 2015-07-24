classdef RPCClient < ws.ZMQConnecter
    
    methods
        function self = RPCClient(portNumber)
            self@ws.ZMQConnecter(portNumber,'ZMQ_REQ');
        end  % function

        function value = call(self,methodName,varargin)
            % Clear out any old responses from the buffer
            %didClear = self.clearIncomingStream() ;
            %if didClear ,
            
            % If get here, we were able to clear the incoming stream of old
            % messages

            % Send the message            
            message=struct('methodName',{methodName},'arguments',{varargin});  % scalar struct
            serializedMessage = getByteStreamFromArray(message) ;  % uint8 array
            %messageAsInt8 = typecast(serializedThing, 'int8') ;
            zmq.core.send(self.Socket, serializedMessage);

            % Read a response (this will block)
            serializedResponse=zmq.core.recv(self.Socket) ;
            value = getArrayFromByteStream(serializedResponse) ;                        
        end  % function

%         function didClearPipe = clearIncomingStream(self)
%             % Clear out any old responses from the incoming stream
%             timeout = 1 ;  % s
%             didClearPipe = false ;
%             didTimeout = false ;
%             ticId = tic() ;
%             while ~didClearPipe && ~didTimeout ,
%                 %pause(0.001) ;
%                 [~,isThingAvailable] = self.SerializingSocket.read() ;
%                 if isThingAvailable ,
%                     didTimeout = (toc(ticId)>timeout) ;
%                 else                    
%                     % nothing to get, so pipe is clear
%                     didClearPipe = true ;
%                 end
%             end
%         end  % function                
    end
    
end

