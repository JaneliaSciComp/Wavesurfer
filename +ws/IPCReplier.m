classdef IPCReplier < ws.ZMQBinder
    
    properties
        Delegate
    end
    
    methods
        function self = IPCReplier(portNumber, delegate)
            %self@ws.ZMQConnecter('ZMQ_SUB');
            self@ws.ZMQBinder(portNumber,'ZMQ_REP');
            self.Delegate = delegate ;
        end  % function

        function delete(self)            
            self.Delegate = [] ;
        end  % function
        
%         function setDelegate(self, newValue)
%             self.Delegate = newValue ;
%         end
        
        function processMessagesIfAvailable(self)
            wasMessageAvailable=true;
            while wasMessageAvailable ,
                wasMessageAvailable=self.processMessageIfAvailable();  % discard method results, if any
            end
        end
        
        function isMessageAvailable = processMessageIfAvailable(self)
            try
                %fprintf('Just before recv\n');
                %fprintf('IPCSubscriber::processMessageIfAvailable(): About to call zmq.core.recv()\n') ;
                serializedMessage = self.Socket.recv(262144, 'ZMQ_DONTWAIT') ;                
                %serializedMessage = zmq.core.recv(self.Socket) ;  % this should block
                %fprintf('Just after recv\n');
            catch me
                if isequal(me.identifier,'zmq:core:recv:EAGAIN') ,
                    % this means that no message is available, which is
                    % not truly exceptional
                    %fprintf('No message available.\n');
                    isMessageAvailable = false;
                    %methodName = '' ;
                    %methodError = [] ;
                    %methodResult = [] ;
                    return
                elseif isequal(me.identifier,'zmq:core:recv:bufferTooSmall') ,
                    % serializedMessage will be truncated, and thus not
                    % unserializable, and thus useless
                    warning('Got a message too long for the buffer in IPCSubscriber');
                    isMessageAvailable = true ;
                    %methodName = '' ;
                    %methodError = [] ;
                    %methodResult = [] ;
                    self.send_([], me) ;  % Have to send a response or else the rep-seq sockets get unhappy
                    return
                else
                    %fprintf('There was an interesting error calling zmq.core.recv.  self.Socket: %d\n',self.Socket);
                    rethrow(me);
                end
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
            %messageAsInt8 = typecast(serializedThing, 'int8') ;
            %fprintf('IPCPublisher::send(): About to call zmq.core.send with %s message\n', methodName);
            %fprintf('IPCReplier::send(): About to call .send() with a result message\n');
            socket = self.Socket ;
            %zmq.core.send(socket, serializedMessage);
            socket.send(serializedMessage) ;
            %fprintf('IPCPublisher::send(): About to exit\n', methodName);            
        end  % function
        
%         function [err, methodResult] = waitForMessage(self, expectedMessageName, timeout)
%             % timeout is in sec
%             ticId = tic() ;
%             timeAtStart = toc(ticId) ;
%             timeSpentWaitingSoFar = 0 ;
%             didGetMessage = false ;
%             while ~didGetMessage && timeSpentWaitingSoFar<timeout ,
%                 timeSpentWaitingSoFar = toc(ticId) - timeAtStart ;
%                 [didGetMessage,messageName,methodError,methodResult] = self.processMessageIfAvailable() ;
%                 pause(0.010) ;
%             end
%             if didGetMessage ,
%                 if isequal(messageName,expectedMessageName) ,
%                     if isempty(methodError) ,
%                         err = [] ;
%                     else
%                         err = methodError ;
%                     end
%                 else
%                     err = MException('ws:unexpectedMessageName', ...
%                                      'Expected message name %s, got message name %s', ...
%                                      expectedMessageName, ...
%                                      messageName) ;
%                 end
%             else
%                 err = MException('ws:timeout', ...
%                                  'No message received within the timeout period of %g seconds', ...
%                                  timeout) ;
%             end
%         end
        
%         function connect(self,portNumber)
%             self.connect@ws.ZMQConnecter(portNumber);
%             %fprintf('IPCSubscriber::connect(): About to call zmq.core.setsockopt()\n') ;
%             %zmq.core.setsockopt(self.Socket, 'ZMQ_SUBSCRIBE', '');  % accept all messages
%             self.Socket.set('ZMQ_SUBSCRIBE', '');  % accept all messages
%         end  % function

    end  % methods
    
end
