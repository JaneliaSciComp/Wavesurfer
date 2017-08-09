% zmq.core.recv_async - Receive messages from a socket on a separate
%                       thread, calling the callback function when each is
%                       received.  The callback should take a single
%                       argument, the buffer, and return no results.
%
% Usage: zmq.core.recv_async(socket, callback)
%        zmq.core.recv_async(socket, callback, bufferLength)
%
% Input: socket - Instantiated ZMQ socket handle (see zmq.core.socket).
%        callback - the callback, a matlab function handle taking a single
%                   argument, the buffer
%        bufferLength - Size in bytes of buffer pre-allocated to receive message.
%                       This parameter is optional with default value of 255.
%
%
%
%
% NOTICE
%  - The messages received should be uint8 row vectors. Please consider using
%    `char`, `cast` and `typecast` functions before using it. Make sure to know
%    what is the transmitter encoding when receiveing strings, so you can use
%    conversions if they're neeeded, for example:
%      `unicode2native(str, 'UTF-8')` or
%      `feature('DefaultCharacterSet', 'UTF-8')`.
%  - If the pre-allocated buffer is shorter than the message received, the returned
%    vector will be truncated and a `zmq:core:recv:bufferTooSmall` warning will be thrown.
%
% EXAMPLE
%     feature('DefaultCharacterSet', 'UTF-8');
%     try
%       message1 = zmq.core.recv(socket, 100, 'ZMQ_DONTWAIT');
%       % maximum size of message1: 100 bytes
%       fprintf('Received message1: %s\n', char(message1));
%       message2 = zmq.core.recv(socket, 'ZMQ_DONTWAIT');
%       % maximum size of message2: 255 bytes
%       fprintf('Received message2: %s\n', char(message2));
%     catch e
%       if strcmp(e.identifier, 'zmq:core:recv:EAGAIN')
%         fprintf('No message available.\n');
%       else
%         rethrow(e);
%       end
%     end
%     message3 = zmq.core.recv(socket); % this will block MATLAB until receive a message
%     % maximum size of message3: 255 bytes
%     fprintf('Received message3: %s\n', char(message3));
%
% Please refer to http://api.zeromq.org/4-0:zmq-recv for further information.
%
