classdef IPCPublisher < ws.ZMQBinder    
    methods
        function self = IPCPublisher(portNumber)
            self@ZMQBinder(portNumber,'ZMQ_PUB');
        end  % function

        function send(self,methodName,varargin)
            % Send the message
            message=struct('methodName',{methodName},'arguments',{varargin});  % scalar struct
            serializedMessage = getByteStreamFromArray(message) ;  % uint8 array
            %messageAsInt8 = typecast(serializedThing, 'int8') ;
            zmq.core.send(self.Socket, serializedMessage);
        end  % function
    end  % methods
    
end

