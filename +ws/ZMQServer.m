classdef ZMQServer < handle
    
    properties
        PortNumber
        TypeString
        Context
        Socket
        IsBound
    end
    
    methods
        function self = ZMQServer(portNumber,typeString)
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
                context = zmq.Context() ;  
                self.Context = context ;
            end
            if ~self.hasSocket() ,
                socket  = self.Context.socket(self.TypeString) ;
                self.Socket = socket ;
            end
            if ~self.isBound() ,
                endpoint = sprintf('tcp://127.0.0.1:%d', self.PortNumber) ;
                self.Socket.bind(endpoint);
                self.IsBound = true ;
            end
        end  % function
        
        function delete(self)
            % I think this should be sufficient.  Once nothing refers to
            % the context, it will be deleted(), and its sockets will
            % automatically be unbound and closed.
            self.Socket = [] ;
            self.Context = [] ;            
        end  % function                                
    end  % methods
    
end

