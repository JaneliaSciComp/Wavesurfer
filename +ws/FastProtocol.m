classdef FastProtocol < ws.Model
    % Each instance of this class represents a single fast protocol
    
    properties (Dependent=true)
        ProtocolFileName
        AutoStartType
    end
    
    properties (Dependent=true, SetAccess=immutable)
        IsNonempty  % true iff ProtocolFileName is nonempty
    end
    
    properties (Access=protected)
        ProtocolFileName_ = ''
        AutoStartType_ = 'do_nothing'
    end
    
    methods
        function self=FastProtocol()
            self@ws.Model() ;
        end
        
        function set.ProtocolFileName(self, newValue)
            if ws.isString(newValue) && ~isempty(newValue) && ws.isFileNameAbsolute(newValue) && exist(newValue,'file') ,
                self.ProtocolFileName_ = newValue ;
            else
                error('ws:invalidPropertyValue', ...
                      'Fast protocol file name must be an absolute path to an existing file');
            end
        end
        
        function value = get.ProtocolFileName(self)
            value = self.ProtocolFileName_ ;
        end
        
        function set.AutoStartType(self, newValue)
            if ws.isAStartType(newValue) ,
                self.AutoStartType_ = newValue ;
            else
                self.updateFastProtocol() ;
                error('ws:invalidPropertyValue', ...
                      'Fast protocol auto start type must be one of ''do_nothing'', ''play'', or ''record''');
            end
        end

        function value=get.AutoStartType(self)
            value=self.AutoStartType_;
        end

        function value=get.IsNonempty(self)
            value=~isempty(self.ProtocolFileName);
        end
    end  % public methods
        
    methods (Access=protected)
        function result = getPropertyValue_(self, propertyName)
            result = self.(propertyName) ;
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end  % function
    end
    
end
