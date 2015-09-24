classdef IPCSubscriber < ws.ZMQConnecter
    
    properties
        Delegate
    end
    
    methods
        function self = IPCSubscriber()
            self@ws.ZMQConnecter('ZMQ_SUB');
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
        
        function [isMessageAvailable,methodName] = processMessageIfAvailable(self)
            try
                %fprintf('Just before recv\n');
                %fprintf('IPCSubscriber::processMessageIfAvailable(): About to call zmq.core.recv()\n') ;
                serializedMessage = zmq.core.recv(self.Socket, 262144, 'ZMQ_DONTWAIT') ;
                %serializedMessage = zmq.core.recv(self.Socket) ;  % this should block
                %fprintf('Just after recv\n');
            catch me
                if isequal(me.identifier,'zmq:core:recv:EAGAIN') ,
                    % this means that no message is available, which is
                    % not truly exceptional
                    %fprintf('No message available.\n');
                    isMessageAvailable = false;
                    methodName = '' ;
                    return
                elseif isequal(me.identifier,'zmq:core:recv:bufferTooSmall') ,
                    % serializedMessage will be truncated, and thus not
                    % unserializable, and thus useless
                    warning('Got a message too long for the buffer in IPCSubscriber');
                    isMessageAvailable = false;
                    methodName = '' ;
                    return                    
                else
                    fprintf('There was an interesting error calling zmq.core.recv.  self.Socket: %d\n',self.Socket);
                    rethrow(me);
                end
            end            
            isMessageAvailable = true;
            message = getArrayFromByteStream(serializedMessage) ;
            methodName = message.methodName ;
            arguments = message.arguments ;
            %fprintf('IPCSubscriber::processMessageIfAvailable(): Got message %s\n',methodName);
            if isempty(self.Delegate) ,
                error('IPCSubscriber:noDelegate', ...
                      'Couldn''t call the method because Delegate is empty or invalid');
            else
                feval(methodName,self.Delegate,arguments{:});
            end
        end  % function        
        
        function [didGetMessage,err] = waitForMessage(self, expectedMessageName, timeout)
            % timeout is in sec
            ticId = tic() ;
            timeAtStart = toc(ticId) ;
            timeSpentWaitingSoFar = 0 ;
            didGetMessage = false ;
            while ~didGetMessage && timeSpentWaitingSoFar<timeout ,
                timeSpentWaitingSoFar = toc(ticId) - timeAtStart ;
                [didGetMessage,messageName] = self.processMessageIfAvailable() ;
                pause(0.010) ;
            end
            if didGetMessage ,
                if isequal(messageName,expectedMessageName) ,
                    err = [] ;
                else
                    err = MException('ws:unexpectedMessageName', ...
                                     'Expected message name %s, got message name %s', ...
                                     expectedMessageName, ...
                                     messageName) ;
                end
            else
                err = MException('ws:timeout', ...
                                 'No message received within the timeout period of %g seconds', ...
                                 timeout) ;
            end
        end
        
        function connect(self,portNumber)
            self.connect@ws.ZMQConnecter(portNumber);
            fprintf('IPCSubscriber::connect(): About to call zmq.core.setsockopt()\n') ;
            zmq.core.setsockopt(self.Socket, 'ZMQ_SUBSCRIBE', '');  % accept all messages
        end  % function

    end  % methods
    
end
