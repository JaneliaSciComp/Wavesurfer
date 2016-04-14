classdef Socket < handle

    properties (Access = private)
        socketPointer;
    end

    properties (Access = public)
        bindings;
        connections;
        defaultBufferLength;
    end

    methods
        function obj = Socket(contextPointer, socketType)
            socketType = obj.normalize_const_name(socketType);
            % Core API
            obj.socketPointer = zmq.core.socket(contextPointer, socketType);
            % Init properties
            obj.bindings = {};
            obj.connections = {};
            obj.defaultBufferLength = 255;
        end

        function delete(obj)
            if (obj.socketPointer ~= 0)
                % Disconnect/Unbind all the endpoints
                cellfun(@(b) obj.unbind(b), obj.bindings, 'UniformOutput', false);
%                 for i = 1:length(obj.bindings) ,
%                     b = obj.bindings{i} ;
%                     obj.unbind(b) ;
%                 end
                obj.bindings = {} ;
                cellfun(@(c) obj.disconnect(c), obj.connections, 'UniformOutput', false);
%                 for i = 1:length(obj.connections) ,
%                     c = obj.connections{i} ;
%                     obj.disconnect(c) ;
%                 end
                obj.connections = {} ;
                % Avoid linger time
                obj.set('linger', 0);
                % close
                %obj.close;
                %status = zmq.core.close(obj.socketPointer);
                zmq.core.close(obj.socketPointer);
                %if (status == 0)
                obj.socketPointer = 0; % ensure NULL pointer
                %end                
            end
        end
    end

    methods (Access = protected)
        normalized = normalize_const_name(obj, name);
        varargout = normalize_msg_options(obj, varargin);
    end

end
