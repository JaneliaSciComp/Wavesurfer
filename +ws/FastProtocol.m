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
        function self=FastProtocol(parent,protocolFileName,autoStartType)
            self@ws.Model(parent) ;
            if exist('protocolFileName','var') ,
                self.ProtocolFileName=protocolFileName;
            end
            if exist('autoStartType','var') ,
                self.AutoStartType=autoStartType;
            end            
        end
        
        function set.ProtocolFileName(self, value)
            if ws.isASettableValue(value) ,
                if ws.isString(value) ,
                    self.ProtocolFileName_ = value;
                else
                    self.Parent.updateFastProtocol();
                    error('ws:invalidPropertyValue', ...
                          'ProtocolFileName must be a string');
                end                    
            end
            self.Parent.updateFastProtocol();
        end
        
        function value=get.ProtocolFileName(self)
            value=self.ProtocolFileName_;
        end
        
        function set.AutoStartType(self, value)
            if ws.isASettableValue(value) ,
                if ws.isAStartType(value) ,
                    self.AutoStartType_ = value;
                else
                    self.Parent.updateFastProtocol();
                    error('ws:invalidPropertyValue', ...
                          'AutoStartType must be ''do_nothing'', ''play'', or ''record''.');
                end
            end
            self.Parent.updateFastProtocol();
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
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
%             s.ProtocolFileName = struct('Classes', 'char', 'Attributes', {{'vector', 'row'}}, 'AllowEmpty', true);
%             %s.AutoStartType = struct('Classes','ws.fastprotocol.StartType', 'Attributes', {{'scalar'}});
%         end  % function
%     end  % class methods block
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
end
