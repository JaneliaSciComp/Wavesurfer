classdef ZMQClient < handle
        
    properties
        TypeString
        Context
        Socket
    end
    
    methods
        function self = ZMQClient(typeString)
            self.TypeString = typeString ;  % e.g. 'ZMQ_SUB'
        end  % function

        function result = hasContext(self)
            result = ~isempty(self.Context) ;
        end  % function
        
        function result = hasSocket(self)
            result = ~isempty(self.Socket) ;
        end  % function

        function connect(self, portNumber)
            if ~self.hasContext() ,
                %fprintf('ZMQClient::connect(): About to call zmq.core.ctx_new()\n');
                context = zmq.Context() ;
                self.Context = context ;
            end
            if ~self.hasSocket() ,
                %fprintf('ZMQClient::connect(): About to call zmq.core.socket()\n');
                self.Socket = self.Context.socket(self.TypeString) ;
            end
            %fprintf('ZMQClient::connect(): About to call zmq.core.connect()\n');
            endpoint = sprintf('tcp://localhost:%d', portNumber) ;
            self.Socket.connect(endpoint) ;
        end  % function
        
        function delete(self)  
            % This should be sufficient
            self.Socket = [] ;
            self.Context = [] ;
        end  % function        
    end  % methods
    
end
