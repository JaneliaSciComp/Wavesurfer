classdef IPCPublisher < ws.ZMQBinder    
    methods
        function self = IPCPublisher(portNumber)
            self@ws.ZMQBinder(portNumber,'ZMQ_PUB');
        end  % function

        function send(self, methodName, varargin)
            % Send the message
            message=struct('methodName',{methodName},'arguments',{varargin});  % scalar struct
            serializedMessage = getByteStreamFromArray(message) ;  % uint8 array
            %messageAsInt8 = typecast(serializedThing, 'int8') ;
            %fprintf('IPCPublisher::send(): About to call .send() with %s message\n', methodName);
            socket = self.Socket ;
            %zmq.core.send(socket, serializedMessage);
            socket.send(serializedMessage) ;
            %fprintf('IPCPublisher::send(): About to exit\n', methodName);            
        end  % function
    end  % methods
end  % classdef
