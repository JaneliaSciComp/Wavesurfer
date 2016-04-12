classdef ZMQConnecter < handle
        
    properties
        TypeString
        Context
        Socket
        %IsConnected
        %Connections = []
    end
    
    methods
        function self = ZMQConnecter(typeString)
            self.TypeString = typeString ;  % e.g. 'ZMQ_SUB'
            %self.IsConnected = false ;
        end  % function

        function result = hasContext(self)
            result = ~isempty(self.Context) ;
        end  % function
        
        function result = hasSocket(self)
            result = ~isempty(self.Socket) ;
        end  % function

%         function result = isConnected(self)
%             result = self.IsConnected ;
%         end  % function

        function connect(self, portNumber)
            if ~self.hasContext() ,
                %fprintf('ZMQConnecter::connect(): About to call zmq.core.ctx_new()\n');
                %context = zmq.core.ctx_new() ;
                context = zmq.Context() ;
                self.Context = context ;
            end
            if ~self.hasSocket() ,
                %fprintf('ZMQConnecter::connect(): About to call zmq.core.socket()\n');
                %self.Socket = zmq.core.socket(self.Context, self.TypeString);
                self.Socket = self.Context.socket(self.TypeString) ;
            end
            %fprintf('ZMQConnecter::connect(): About to call zmq.core.connect()\n');
            %zmq.core.connect(self.Socket, sprintf('tcp://localhost:%d', portNumber));
            endpoint = sprintf('tcp://localhost:%d', portNumber) ;
            self.Socket.connect(endpoint) ;
            %self.Connections = [self.Connections portNumber];
            %self.IsConnected = true ;
        end  % function
        
        function delete(self)  
            % This should be sufficient
            self.Socket = [] ;
            self.Context = [] ;
            
%             try
% %                 % disconnect all the connections
% %                 nConnections = length(self.Connections) ;
% %                 nConnectionsLeft = nConnections ;
% %                 for i = 1:nConnections ,
% %                     % At this point, nConnectionsLeft is the number of
% %                     % connections that have not yet been disconnected
% %                     portNumber = self.Connections(nConnectionsLeft) ;  % peel off the last one
% %                     %fprintf('ZMQConnecter::delete(): About to call zmq.core.disconnect()\n');
% %                     zmq.core.disconnect(self.Socket, sprintf('tcp://localhost:%d', portNumber)) ;                    
% %                     self.Connections = self.Connections(1:(nConnectionsLeft-1)) ;
% %                     nConnectionsLeft = nConnectionsLeft - 1 ;
% %                 end
% %                 self.Connections = [] ;
%                 % close the socket
%                 if self.hasSocket() ,
%                     %fprintf('ZMQConnecter::delete(): About to call zmq.core.setsockopt()\n');
%                     %zmq.core.setsockopt(self.Socket, 'ZMQ_LINGER', 0);  % don't wait to send pending messages
%                       % the smq.Socket delete() method seems to do this
%                       % already...
%                     %fprintf('ZMQConnecter::delete(): About to call zmq.core.close()\n');
%                     %zmq.core.close(self.Socket);
%                     self.Socket =[] ;
%                 end
%                 % destroy the context
%                 if self.hasContext() ,
%                     %fprintf('ZMQConnecter::delete(): About to call zmq.core.ctx_shutdown()\n');
%                     %zmq.core.ctx_shutdown(self.Context) ;
%                     %fprintf('ZMQConnecter::delete(): Just called zmq.core.ctx_shutdown()\n');                    
%                     %fprintf('ZMQConnecter::delete(): About to call zmq.core.ctx_term()\n');                    
%                     %zmq.core.term(self.Context);
%                     %fprintf('ZMQConnecter::delete(): Just called zmq.core.ctx_term()\n');
%                     self.Context = [] ;  % the delete() method should do the trick...
%                 end
%             catch me %#ok<NASGU>
%                 % Can't throw exceptions from the delete method, so...
%             end
        end  % function        
    end  % methods
    
end

