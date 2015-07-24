classdef RPCServer < ws.ZMQBinder
    
    properties
        Delegate                
    end
    
    methods
        function self = RPCServer(portNumber)
            self@ws.ZMQBinder(portNumber,'ZMQ_REP');
        end  % function

        function delete(self)            
            self.Delegate = [] ;
        end  % function
        
        function setDelegate(self, newValue)
            self.Delegate = newValue ;
        end
                        
        function processMessagesIfAvailable(self)
            wasMessageAvailable=true;
            while wasMessageAvailable ,
                wasMessageAvailable=self.processMessageIfAvailable();
            end
        end
        
        function isMessageAvailable=processMessageIfAvailable(self)
            try
                serializedMessage = zmq.core.recv(self.Socket, 'ZMQ_DONTWAIT') ;
            catch me
                if isequal(me.identifier,'zmq:core:recv:EAGAIN') ,
                    % this means that no message is available, which is
                    % not truly exceptional
                    isMessageAvailable = false;
                    return
                else
                    rethrow(me);
                end
            end            
            isMessageAvailable = true;
            message = getArrayFromByteStream(serializedMessage) ;
            methodName = message.methodName ;
            arguments = message.arguments ;
            if isempty(self.Delegate) ,
                value = MException('RPCServer:noDelegate', ...
                                   'Couldn''t call the method because Delegate is empty or invalid');
            else
                value = feval(methodName,self.Delegate,arguments{:});
            end
            % Now send the reply
            serializedValue = getByteStreamFromArray(value) ;  % uint8 array
            zmq.core.send(self.Socket, serializedValue);            
        end  % function        
    end  % methods
    
end

