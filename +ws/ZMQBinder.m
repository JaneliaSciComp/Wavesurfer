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
                self.Context = zmq.core.ctx_new();
            end
            if ~self.hasSocket() ,
                self.Socket = zmq.core.socket(self.Context, self.TypeString);
            end
            if ~self.isBound() ,
                zmq.core.bind(self.Socket, sprintf('tcp://*:%d', self.PortNumber));
            end
        end  % function
        
        function delete(self)            
            try
                % Don't need to unbind, I guess
                if self.isBound() ,
                    %zmq.core.disconnect(self.Socket, sprintf('tcp://localhost:%d', self.PortNumber));
                    self.IsBound = false;
                end
                if self.hasSocket() ,
                    zmq.core.close(self.Socket);
                    self.Socket =[] ;
                end
                if self.hasContext() ,
                    fprintf('ZMQBinder::delete(): About to call zmq.core.ctx_term()\n');
                    zmq.core.ctx_term(self.Context);
                    fprintf('ZMQBinder::delete(): Just called zmq.core.ctx_term()\n');
                    self.Context = [] ;
                end
            catch me %#ok<NASGU>
                % Can't throw exceptions from the delete method, so...
            end
        end  % function                                
    end  % methods
    
end

