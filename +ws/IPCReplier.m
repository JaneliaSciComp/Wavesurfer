classdef IPCReplier < ws.ZMQServer
    
    properties
        Delegate
    end
    
    methods
        function self = IPCReplier(portNumber, delegate)
            self@ws.ZMQServer(portNumber,'ZMQ_REP');
            self.Delegate = delegate ;
        end  % function

        function delete(self)            
            self.Delegate = [] ;
        end  % function
        
        function processMessagesIfAvailable(self)
            wasMessageAvailable=true;
            while wasMessageAvailable ,
                wasMessageAvailable=self.processMessageIfAvailable();  % discard method results, if any
            end
        end
        
        function isMessageAvailable = processMessageIfAvailable(self)
            try
                %fprintf('Just before recv\n');
                serializedMessage = self.Socket.recv(262144, 'ZMQ_DONTWAIT') ;                
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
                    warning('Got a message too long for the buffer in IPCReplier');
                    isMessageAvailable = true ;
                    self.send_([], me) ;  % Have to send a response or else the rep-seq sockets get unhappy
                    return
                else
                    %fprintf('There was an interesting error calling zmq.core.recv.  self.Socket: %d\n',self.Socket);
                    rethrow(me);
                end
            end
            % We modified the Matlab ZMQ binding to not throw if you give the option
            % ZMQ_DONTWAIT and no message is available.  Instead, it returns an empty
            % message.
            if isempty(serializedMessage) ,
                isMessageAvailable = false;
                return
            end                
            isMessageAvailable = true ;
            message = getArrayFromByteStream(serializedMessage) ;
            methodName = message.methodName ;
            arguments = message.arguments ;
            %fprintf('IPCReplier::processMessageIfAvailable(): Got message %s\n',methodName);
            if isempty(self.Delegate) ,
                error('IPCReplier:noDelegate', ...
                      'Couldn''t call the method because Delegate is empty or invalid');
            else
                % This function is typically called in a message-processing
                % loop.  Even if there's an uncaught error during method
                % execution, we don't want that to *ever* disrupt the
                % message-processing loop, so we wrap it in try-catch.
                try                    
                    methodResult = feval(methodName,self.Delegate,arguments{:}) ;
                    methodError = [] ;
                catch methodError
                    % Barf up a message to the console, as much as that
                    % pains me.
                    warning('IPCSubscriber:uncaughtErrorInMessageMethod', 'Error in message-handling method %s', methodName);
                    fprintf('Stack trace for method error:\n');
                    display(methodError.getReport());
                    methodResult = [] ;
                end
            end
            % Send the result back as the response
            self.send_(methodResult, methodError) ;
        end  % function
    end
    
    methods (Access=protected)
        function send_(self, result, err)
            % Send the message
            message=struct('result',{result},'error',{err});  % scalar struct
            serializedMessage = getByteStreamFromArray(message) ;  % uint8 array
            %fprintf('IPCReplier::send(): About to call .send() with a result message\n');
            socket = self.Socket ;
            socket.send(serializedMessage) ;
        end  % function        
    end  % methods    
end  % classdef
