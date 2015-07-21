classdef IPCSubscriber < ZMQConnecter
    
    properties
        Delegate
    end
    
    methods
        function self = IPCSubscriber(portNumber)
            self@ZMQConnecter(portNumber,'ZMQ_SUB');
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
                %fprintf('Just before recv\n');
                serializedMessage = zmq.core.recv(self.Socket, 262144, 'ZMQ_DONTWAIT') ;
                %serializedMessage = zmq.core.recv(self.Socket) ;  % this should block
                %fprintf('Just after recv\n');
            catch me
                if isequal(me.identifier,'zmq:core:recv:EAGAIN') ,
                    % this means that no message is available, which is
                    % not truly exceptional
                    %fprintf('No message available.\n');
                    isMessageAvailable = false;
                    return
                elseif isequal(me.identifier,'zmq:core:recv:bufferTooSmall') ,
                    % serializedMessage will be truncated, and thus not
                    % unserializable, and thus useless
                    warning('Got a message too long for the buffer in IPCSubscriber');
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
                error('IPCSubscriber:noDelegate', ...
                      'Couldn''t call the method because Delegate is empty or invalid');
            else
                feval(methodName,self.Delegate,arguments{:});
            end
        end  % function        
        
        function connect(self)
            self.connect@ZMQConnecter();
            zmq.core.setsockopt(self.Socket, 'ZMQ_SUBSCRIBE', '');  % accept all messages
        end  % function

    end  % methods
    
end

