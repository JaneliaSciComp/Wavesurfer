classdef IPCRequester < ws.ZMQClient
    
    methods
        function self = IPCRequester()
            self@ws.ZMQClient('ZMQ_REQ');
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
        end  % function
        
        function [err, response] = waitForResponse(self, timeout, message)
            ticId = tic() ;
            timeAtStart = toc(ticId) ;
            timeSpentWaitingSoFar = 0 ;
            didGetMessage = false ;
            while ~didGetMessage && timeSpentWaitingSoFar<timeout ,
                timeSpentWaitingSoFar = toc(ticId) - timeAtStart ;
                [didGetMessage, response, replierError] = self.receiveResponseIfAvailable_() ;
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
        end  % function        
    end  % methods
    
    methods (Access=protected)
        function [isMessageAvailable, result, err] = receiveResponseIfAvailable_(self)
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
                    result = [] ;
                    err = [] ;
                    return
                elseif isequal(me.identifier,'zmq:core:recv:bufferTooSmall') ,
                    % serializedMessage will be truncated, and thus not
                    % unserializable, and thus useless
                    warning('Got a message too long for the buffer in IPCRequester');
                    isMessageAvailable = false;
                    result = [] ;
                    err = [] ;
                    return
                else
                    %fprintf('There was an interesting error calling zmq.Socket.recv.  self.Socket: %d\n',self.Socket);
                    rethrow(me);
                end
            end
            % We modified the Matlab ZMQ binding to not throw if you give the option
            % ZMQ_DONTWAIT and no message is available.  Instead, it returns an empty
            % message.
            if isempty(serializedMessage) ,
                isMessageAvailable = false ;
                result = [] ;
                err = [] ;
                return
            end                

            isMessageAvailable = true ;
            message = getArrayFromByteStream(serializedMessage) ;
            result = message.result ;
            err = message.error ;
        end  % function
    end  % protected methods block
end
