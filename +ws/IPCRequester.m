classdef IPCRequester < ws.ZMQConnecter
    
%     properties
%         Delegate
%     end
    
    methods
        function self = IPCRequester()
            self@ws.ZMQConnecter('ZMQ_REQ');
        end  % function

%         function delete(self)            
%             %self.Delegate = [] ;
%         end  % function
        
%         function setDelegate(self, newValue)
%             self.Delegate = newValue ;
%         end
        
%         function processMessagesIfAvailable(self)
%             wasMessageAvailable=true;
%             while wasMessageAvailable ,
%                 wasMessageAvailable=self.processMessageIfAvailable();  % discard method results, if any
%             end
%         end
        
        function [isMessageAvailable, result, err] = receiveResponseIfAvailable(self)
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
                    result = [] ;
                    err = [] ;
                    return
                elseif isequal(me.identifier,'zmq:core:recv:bufferTooSmall') ,
                    % serializedMessage will be truncated, and thus not
                    % unserializable, and thus useless
                    warning('Got a message too long for the buffer in IPCRequester');
                    isMessageAvailable = false;
                    %methodName = '' ;
                    %methodError = [] ;
                    result = [] ;
                    err = [] ;
                    return
                else
                    %fprintf('There was an interesting error calling zmq.core.recv.  self.Socket: %d\n',self.Socket);
                    rethrow(me);
                end
            end
            isMessageAvailable = true ;
            message = getArrayFromByteStream(serializedMessage) ;
            result = message.result ;
            err = message.error ;
%             results = message.results ;
%             methodName = message.methodName ;
%             arguments = message.arguments ;
%             %fprintf('IPCSubscriber::processMessageIfAvailable(): Got message %s\n',methodName);
%             if isempty(self.Delegate) ,
%                 error('IPCSubscriber:noDelegate', ...
%                       'Couldn''t call the method because Delegate is empty or invalid');
%             else
%                 % This function is typically called in a message-processing
%                 % loop.  Even if there's an uncaught error during method
%                 % execution, we don't want that to *ever* disrupt the
%                 % message-processing loop, so we wrap it in try-catch.
%                 try                    
%                     methodResult = feval(methodName,self.Delegate,arguments{:}) ;
%                     methodError = [] ;
%                 catch methodError
%                     % Barf up a message to the console, as much as that
%                     % pains me.
%                     warning('IPCSubscriber:uncaughtErrorInMessageMethod', 'Error in message-handling method %s', methodName);
%                     fprintf('Stack trace for method error:\n');
%                     display(methodError.getReport());
%                     methodResult = [] ;
%                 end
%             end
        end  % function
        
        function send(self, methodName, varargin)
            % Send the message
            message=struct('methodName',{methodName},'arguments',{varargin});  % scalar struct
            serializedMessage = getByteStreamFromArray(message) ;  % uint8 array
            %messageAsInt8 = typecast(serializedThing, 'int8') ;
            %fprintf('IPCRequester::send(): About to call .send() with %s message\n', methodName);
            socket = self.Socket ;
            %zmq.core.send(socket, serializedMessage);
            socket.send(serializedMessage) ;
            %fprintf('IPCPublisher::send(): About to exit\n', methodName);            
        end  % function
        
        function [err, response] = waitForResponse(self, timeout, message)
            ticId = tic() ;
            timeAtStart = toc(ticId) ;
            timeSpentWaitingSoFar = 0 ;
            didGetMessage = false ;
            while ~didGetMessage && timeSpentWaitingSoFar<timeout ,
                timeSpentWaitingSoFar = toc(ticId) - timeAtStart ;
                % [didGetMessage,messageName,methodError,methodResult] = self.processMessageIfAvailable() ;
                [didGetMessage, response, replierError] = self.receiveResponseIfAvailable() ;
                pause(0.010) ;
            end
            if didGetMessage ,
                if isempty(replierError) ,
                    err = [] ;
                else
                    err = replierError ;
                end
            else
                err = MException('ws:timeout', ...
                                 'No message received in response to message %s within the timeout period of %g seconds', ...
                                 message, ...
                                 timeout) ;
            end
        end
        
%         function connect(self,portNumber)
%             self.connect@ws.ZMQConnecter(portNumber);
%             %fprintf('IPCSubscriber::connect(): About to call zmq.core.setsockopt()\n') ;
%             %zmq.core.setsockopt(self.Socket, 'ZMQ_SUBSCRIBE', '');  % accept all messages
%             %self.Socket.set('ZMQ_SUBSCRIBE', '');  % accept all messages
%         end  % function

    end  % methods
    
end
