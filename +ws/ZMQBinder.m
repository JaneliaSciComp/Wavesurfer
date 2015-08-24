classdef ZMQBinder < handle
    
    properties
        PortNumber
        TypeString
        Context
        Socket
        IsBound
    end
    
    methods
        function self = ZMQBinder(portNumber,typeString)
            self.PortNumber = portNumber ; 
            self.TypeString = typeString ;
            self.IsBound = false ;
        end  % function

        function result = hasContext(self)
            result = ~isempty(self.Context) ;
        end  % function
        
        function result = hasSocket(self)
            result = ~isempty(self.Socket) ;
        end  % function

        function result = isBound(self)
            result = self.IsBound ;
        end  % function
        
        function bind(self)
            if ~self.hasContext() ,
                fprintf('ZMQBinder::bind(): About to call zmq.core.ctx_new()\n');
                context = zmq.core.ctx_new()
                self.Context = context ;
            end
            if ~self.hasSocket() ,
                fprintf('ZMQBinder::bind(): About to call zmq.core.socket()\n');
                socket  = zmq.core.socket(self.Context, self.TypeString)
                self.Socket = socket ;
            end
            if ~self.isBound() ,
                fprintf('ZMQBinder::bind(): About to call zmq.core.bind()\n');
                zmq.core.bind(self.Socket, sprintf('tcp://*:%d', self.PortNumber));
                self.IsBound = true ;
            end
        end  % function
        
        function delete(self)            
            try
                if self.isBound() ,
                    %zmq.core.disconnect(self.Socket, sprintf('tcp://localhost:%d', self.PortNumber));
                    fprintf('ZMQBinder::delete(): About to call zmq.core.unbind()\n');
                    zmq.core.unbind(self.Socket, sprintf('tcp://*:%d', self.PortNumber)) ;
                    self.IsBound = false;
                end
                if self.hasSocket() ,
                    socket = self.Socket ;
                    zmq.core.setsockopt(socket, 'ZMQ_LINGER', 0);  % don't wait to send pending messages
                    fprintf('ZMQBinder::delete(): About to call zmq.core.close()\n');
                    socket
                    zmq.core.close(socket);
                    fprintf('ZMQBinder::delete(): Just called zmq.core.close()\n');
                    self.Socket = [] ;
                end
                if self.hasContext() ,
                    context = self.Context ;
                    fprintf('ZMQBinder::delete(): About to call zmq.core.ctx_shutdown()\n');
                    context
                    zmq.core.ctx_shutdown(context) ;
                    fprintf('ZMQBinder::delete(): Just called zmq.core.ctx_shutdown()\n');
                    fprintf('ZMQBinder::delete(): About to call zmq.core.ctx_term()\n');
                    context
                    zmq.core.ctx_term(context) ;
                    fprintf('ZMQBinder::delete(): Just called zmq.core.ctx_term()\n');
                    self.Context = [] ;
                end
            catch me %#ok<NASGU>
                % Can't throw exceptions from the delete method, so...
            end
        end  % function                                
    end  % methods
    
end

