classdef ZMQConnecter < handle
    
    properties
        PortNumber
        TypeString
        Context
        Socket
        IsConnected
    end
    
    methods
        function self = ZMQConnecter(portNumber,typeString)
            self.PortNumber = portNumber ; 
            self.TypeString = typeString ;  % e.g. 'ZMQ_SUB'
            self.IsConnected = false ;
        end  % function

        function result = hasContext(self)
            result = ~isempty(self.Context) ;
        end  % function
        
        function result = hasSocket(self)
            result = ~isempty(self.Socket) ;
        end  % function

        function result = isConnected(self)
            result = self.IsConnected ;
        end  % function

        function connect(self)
            if ~self.hasContext() ,
                self.Context = zmq.core.ctx_new();
            end
            if ~self.hasSocket() ,
                self.Socket = zmq.core.socket(self.Context, self.TypeString);
            end
            if ~self.isConnected() ,
                zmq.core.connect(self.Socket, sprintf('tcp://localhost:%d', self.PortNumber));
                self.IsConnected = true ;
            end
        end  % function
        
        function delete(self)            
            try
                if self.isConnected() ,
                    zmq.core.disconnect(self.Socket, sprintf('tcp://localhost:%d', self.PortNumber));
                    self.IsConnected = false ;
                end
                if self.hasSocket() ,
                    zmq.core.close(self.Socket);
                    self.Socket =[] ;
                end
                if self.hasContext() ,
                    zmq.core.ctx_term(self.Context);
                    self.Context = [] ;
                end
            catch me %#ok<NASGU>
                % Can't throw exceptions from the delete method, so...
            end
        end  % function        
    end  % methods
    
end

