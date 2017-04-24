classdef Store < handle
    properties (Access = private)
        Content_
    end
    methods
        function self = Store()
            %fprintf('Inside Store() constructor\n') ;
            self.Content_ = cell(1,0) ;
        end
        function result = isEmpty(self)
            result = isempty(self.Content_) ;
        end
        function result = isValid(self)
            result = ~isempty(self.Content_) && isvalid(self.Content_{1}) ;            
        end
        function result = get(self)
            if isempty(self.Content_) ,
                error('Can''t get from an empty Store') ;
            else
                result = self.Content_{1} ;
            end
        end
        function set(self, newValue)
            self.Content_ = {newValue} ;
        end
        function clear(self)
            self.Content_ = cell(1,0) ;            
        end
        function delete(self)
            %fprintf('Store::delete() called\n') ;
        end
    end    
end
