function bind(obj, endpoint)
    status = zmq.core.bind(obj.socketPointer, endpoint);
    if (status == 0)
        % Add endpoint to the tracked bindings
        % this is important to the cleanup process
        realized_endpoint = zmq.core.getsockopt(obj.socketPointer, 'ZMQ_LAST_ENDPOINT');
        obj.bindings{end+1} = realized_endpoint;
    end
end
