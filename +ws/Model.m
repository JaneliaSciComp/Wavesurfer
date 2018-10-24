classdef (Abstract) Model < ws.Coding & ws.EventBroadcaster
%     events
%         Update  % Means that any dependent views need to update themselves
%     end
    
    methods
        function self = Model()
        end  % function
        
        function delete(self)  %#ok<INUSD>
        end
        
        function mimic(self,other)
            % mimic function that disables, then re-enables broadcasts for
            % speed
            
            % Disable broadcasts for speed
            self.disableBroadcasts();
            self.mimic@ws.Coding(other);
            
            % Re-enable broadcasts
            self.enableBroadcastsMaybe();
            
            % Broadcast update
            %self.broadcast('Update');
        end

        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Coding(self) ;            
            propNames=setdiff(propNamesRaw, ...
                              {'IsReady'}) ;
        end  % function         
        
        function debug(self) %#ok<MANU>
            keyboard
        end  % function        
        
        function result = get(self, propertyName) 
            result = self.(propertyName) ;
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end           
    end  % public methods block    
    
end  % classdef
