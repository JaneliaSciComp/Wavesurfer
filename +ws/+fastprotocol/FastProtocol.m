classdef FastProtocol < ws.Model % & ws.EventBroadcaster
    % Each instance of this class represents a single fast protocol
    
    properties (Dependent=true)
        ProtocolFileName
        AutoStartType
    end
    
    properties (SetAccess=immutable, Dependent=true)
        IsNonempty  % true iff ProtocolFileName is nonempty
    end
    
    properties (Access=protected)
        ProtocolFileName_ = ''
        AutoStartType_ = ws.fastprotocol.StartType.DoNothing
    end
    
    methods
        function self=FastProtocol(protocolFileName,autoStartType)
            if exist('protocolFileName','var') ,
                self.ProtocolFileName=protocolFileName;
            end
            if exist('autoStartType','var') ,
                self.AutoStartType=autoStartType;
            end            
        end
        
        function set.ProtocolFileName(self, value)
            if ws.utility.isASettableValue(value) ,
                self.validatePropArg('ProtocolFileName', value);
                self.ProtocolFileName_ = value;
            end
            self.broadcast('Update');            
        end
        
        function value=get.ProtocolFileName(self)
            value=self.ProtocolFileName_;
        end
        
        function set.AutoStartType(self, value)
            if ws.utility.isASettableValue(value) ,
                self.validatePropArg('AutoStartType', value);
                self.AutoStartType_ = value;
            end
            self.broadcast('Update');
        end

        function value=get.AutoStartType(self)
            value=self.AutoStartType_;
        end

        function value=get.IsNonempty(self)
            value=~isempty(self.ProtocolFileName);
        end
        
%         function disp(self)
%             if numel(self) == 1 && isvalid(self)
%                 % Customize so that the AutoStartType displays as the enumeration name, rather
%                 % than as [1x1 ws.fastprotocol.StartType].
%                 fprintf('  ws.fastprotocol.FastProtocol with properties:\n\n');
%                 fprintf('     ProtocolFileName: ''%s''\n', self.ProtocolFileName);
%                 fprintf('        AutoStartType: %s\n', char(self.AutoStartType));
%                 fprintf('\n');
%             else
%                 disp@handle(self);
%             end
%         end
    end
        
%     methods (Static = true)
%         function thing=loadobj(pickledThing)
%             thing=pickledThing;
%             % Fix the IsNonempty field
%             for i=1:numel(thing) ,
%                 thing(i).IsNonempty=~isempty(thing(i).ProtocolFileName);
%             end
%         end
%     end    
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.fastprotocol.FastProtocol.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();
            s.ProtocolFileName = struct('Classes', 'char', 'Attributes', {{'vector', 'row'}}, 'AllowEmpty', true);
            s.AutoStartType = struct('Classes','ws.fastprotocol.StartType', 'Attributes', {{'scalar'}});
        end  % function
    end  % class methods block
    
    methods (Access=protected)
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
            self.broadcast('Update');  % Even if it's a non-public property, want to generate an Update event
        end  % function
    end
    
end
