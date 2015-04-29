function [varargout] = jtcp(actionStr,varargin)
%
% jtcp.m--Uses Matlab's Java interface to handle Transmission Control
% Protocol (TCP) communications with another application, either on the
% same computer or a remote one. This version of jtcp is not restricted to
% transmitting and receiving variables of type int8; it can also use Java's
% serialization mechanisms to handle strings, matrices, cell arrays and
% primitives (that is, just about any Matlab variable type other than
% structures).
%
% Note that the conventional "client/server" terminology used for TCP is
% somewhat misleading; a "client" requests a connection and a "server"
% accepts (or rejects) it, but once the connection is established, both the
% client or server can either write or read data over it.
%
% JTCPOBJ = JTCP('REQUEST',HOST,PORT) represents a request from a client to
% the specified server to establish a TCP/IP connection on the specified
% port. HOST can be either a hostname (e.g., 'www.example.com' or
% 'localhost') or a string representation of an IP address (e.g.,
% '192.0.34.166'); use the loopback address ('127.0.0.1') to enable
% communications between two applications on the same host. Port is an
% integer port number between 1025 and 65535. The specified port must be
% open in the receiving machine's firewall.
%
% JTCPOBJ = JTCP('ACCEPT',PORT) accepts a request for a connection from a
% client.
%
% The REQUEST and ACCEPT modes of jtcp.m accept a timeout argument,
% specified as a parameter/value pair. For example,
%   JTCP('REQUEST',HOST,PORT,'TIMEOUT',2000)
% attempts to make a TCP connection, but gives up after 2000 milliseconds.
% Default timeout is 1 second. 
%
% The REQUEST and ACCEPT modes of jtcp.m also accept a 'serialize'
% argument. If 'serialize' is true (the default), then jtcp.m will use
% Java's serialization mechanism to send/receive data. This allows jtcp.m
% to handle strings, matrices, etc. Set 'serialize' to false if
% communicating with a program or piece of hardware that is not set up to
% handle serialized objects:
%   JTCP('REQUEST',HOST,PORT,'SERIALIZE',FALSE)
%   JTCP('ACCEPT',PORT,'SERIALIZE',FALSE)
% In this case, write and read operations will be restricted to variables
% of type int8.
%
% JTCP('WRITE',JTCPOBJ,MSSG) writes the specified message to the TCP/IP
% connection.
%
% MSSG = JTCP('READ',JTCPOBJ) reads a message from the TCP/IP connection.
%
% With serialization off, 'read' mode accepts a number of input arguments,
% specified as parameter/value pairs. These have no effect when
% serialization is on:
%
% MSSG = JTCP('READ',JTCPOBJ,'MAXNUMBYTES',MAXNUMBYTES) limits the number
% of bytes read in to a maximum of MAXNUMBYTES.
%
% MSSG = JTCP('READ',JTCPOBJ,'NUMBYTES',NUMBYTES) specifies the number of
% bytes to be read in. Returns an empty string if the exact number of
% bytes is not read in.
%
% MSSG = JTCP('READ',JTCPOBJ,'HELPERCLASSPATH',HELPERCLASSPATH), uses a
% Java helper class to do the reading, rather than using a separate
% function call for each byte it reads, making the process much more
% efficient. To use this option, download and compile Rodney Thomson's
% DataReader java class.
%
% JTCPOBJ = JTCP('CLOSE',JTCPOBJ) closes the TCP/IP connection. This should
% be done on both client and server.
%
% With serialize set to true, Matlab converts data into a suitable type for
% passing to the Java layer for transmission and back to a Matlab type on
% receipt of data. This two-way conversion may result in a loss of
% information, depending on the variable types. Upcasting to double before
% transmission requires more overhead but eliminates this problem. See
% http://www.mathworks.com/help/techdoc/matlab_external/f6425.html
% (Conversion of MATLAB Types to Java Types) and
% http://www.mathworks.com/help/techdoc/matlab_external/f6671.html
% (Conversion of Java Types to MATLAB Types) for more details.
%
% The Java Socket setSoTimeout method affects only read operations; write
% operations do not time out. If the data payload is large enough to fill
% the available buffers, then, subsequent write operations will block
% (hang) until the corresponding read operation is carried out. Future
% versions of jtcp.m may be able to use the Java class "SocketChannel"
% (non-blocking sockets) to avoid this.
%
% Inspired by Rodney Thomson's example code on the MathWorks' File
% Exchange.  
%
% e.g., Send/receive strings:
%    server: jTcpObj = jtcp('accept',21566,'timeout',2000);
%    client: jTcpObj = jtcp('request','127.0.0.1',21566,'timeout',2000);
%    client: jtcp('write',jTcpObj,'Hello, server');
%    server: mssg = jtcp('read',jTcpObj); disp(mssg)
%    server: jtcp('write',jTcpObj,'Hello, client');
%    client: mssg = jtcp('read',jTcpObj); disp(mssg)
%    server: jtcp('close',jTcpObj);
%    client: jtcp('close',jTcpObj);
%
% e.g., Send/receive matrix:
%    server: jTcpObj = jtcp('accept',21566,'timeout',2000);
%    client: jTcpObj = jtcp('request','127.0.0.1',21566,'timeout',2000);
%    client: data = eye(5); jtcp('write',jTcpObj,data);
%    server: mssg = jtcp('read',jTcpObj); disp(mssg)
%    server: jtcp('close',jTcpObj);
%    client: jtcp('close',jTcpObj);
%
% e.g., Send/receive cell array. Cell arrays are converted to class
%       java.lang.Object for transmission; convert back to Matlab cell 
%       array with cell():
%    server: jTcpObj = jtcp('accept',21566,'timeout',2000);
%    client: jTcpObj = jtcp('request','127.0.0.1',21566,'timeout',2000);
%    server: data = {'Hello', [1 2 3], pi}; jtcp('write',jTcpObj,data);
%    client: mssg = jtcp('read',jTcpObj); disp(cell(mssg))
%    server: jtcp('close',jTcpObj);
%    client: jtcp('close',jTcpObj);
%
% e.g., Send/receive uint8 array. uint8 arrays are converted to bytes for
%       transmission and back to int8 when read back into Matlab, so 
%       information is lost. Avoid this by upcasting to double and back 
%       down to uint8 on the other end.
%    server: jTcpObj = jtcp('accept',21566,'timeout',2000);
%    client: jTcpObj = jtcp('request','127.0.0.1',21566,'timeout',2000);
%    server: data = double(imread('ngc6543a.jpg')); jtcp('write',jTcpObj,data);
%    client: mssg = jtcp('read',jTcpObj); image(uint8(mssg))
%    server: jtcp('close',jTcpObj);
%    client: jtcp('close',jTcpObj);
%
% e.g., Send/receive int8 bytes one by one with serialization off. 
%    server: jTcpObj = jtcp('accept',21566,'timeout',2000,'serialize',false);
%    client: jTcpObj = jtcp('request','127.0.0.1',21566,'timeout',2000,'serialize',false);
%    server: jtcp('write',jTcpObj,int8('Hello client'));
%    client: mssg = jtcp('read',jTcpObj); char(mssg)
%    server: jtcp('write',jTcpObj,int8('Hello client, read this with helper class'));
%    client: mssg = jtcp('read',jTcpObj,'helperClassPath','/home/bartlett/matlab/mfiles/network/'); char(mssg)
%    server: jtcp('close',jTcpObj);
%    client: jtcp('close',jTcpObj);

% Developed in Matlab 7.8.0.347 (R2009a) on GLNX86.
% Kevin Bartlett (kpb@uvic.ca), 2009-06-17 13:03
%-------------------------------------------------------------------------

% Handle input arguments.
REQUEST = 1;
ACCEPT = 2;
WRITE = 3;
READ = 4;
CLOSE = 5;

if strcmpi(actionStr,'request')
    action = REQUEST;    
elseif strcmpi(actionStr,'accept')
    action = ACCEPT;
elseif strcmpi(actionStr,'write')
    action = WRITE;
elseif strcmpi(actionStr,'read')
    action = READ;
elseif strcmpi(actionStr,'close')
    action = CLOSE;    
else
    error([mfilename '.m--Unrecognised actionStr ''' actionStr ''.']);
end % if

% Parse remaining arguments.
if action==REQUEST
    assert(nargin>=3,[mfilename '.m--REQUEST mode requires at least 3 input arguments.']);
    p = inputParser;
    p.FunctionName = mfilename;
    p.addRequired('host',@ischar);
    p.addRequired('port',@isnumeric);
    p.addOptional('serialize',true, @(x) ismember(x,[0 1]) || islogical(x));
    p.addOptional('timeout',1000, @isnumeric);
    p.parse(varargin{:});
    host = p.Results.host;
    port = p.Results.port;
    serialize = p.Results.serialize;
    timeout = p.Results.timeout;
elseif action==ACCEPT
    assert(nargin>=2,[mfilename '.m--ACCEPT mode requires at least 2 input arguments.']);
    p = inputParser;
    p.FunctionName = mfilename;
    p.addRequired('port',@isnumeric);
    p.addOptional('serialize',true, @(x) ismember(x,[0 1]) || islogical(x));
    p.addOptional('timeout',1000, @isnumeric);
    p.parse(varargin{:});
    port = p.Results.port;
    serialize = p.Results.serialize;
    timeout = p.Results.timeout;
elseif action==WRITE
    assert(nargin==3,[mfilename '.m--WRITE mode requires exactly 3 input arguments.']);
    jTcpObj = varargin{1};
    mssg = varargin{2};
elseif action==READ
    assert(nargin>=2,[mfilename '.m--READ mode requires at least 2 input arguments.']);
    p = inputParser;
    p.FunctionName = mfilename;
    p.addRequired('jTcpObj',@isstruct);
    p.addOptional('maxNumBytes',Inf, @isnumeric);
    p.addOptional('numBytes', NaN, @isnumeric);
    p.addOptional('helperClassPath', '', @ischar);
    p.parse(varargin{:});
    jTcpObj = p.Results.jTcpObj;
    maxNumBytes = p.Results.maxNumBytes;
    numBytes = p.Results.numBytes;
    helperClassPath = p.Results.helperClassPath;
elseif action==CLOSE
    assert(nargin==2,[mfilename '.m--CLOSE mode requires exactly 2 input arguments.']);
    jTcpObj = varargin{1};
end

% ...Check for validity of input arguments.
if exist('timeout','var')
    assert(timeout>0,[mfilename '.m--Input argument ''timeout'' must be greater than zero.']);
end

if exist('port','var')
    if rem(port,1)~=0 || port < 1025 || port > 65535
       error([mfilename '.m--Port number must be an integer between 1025 and 65535.']);
    end % if
end % if

if exist('jTcpObj','var')    
    if ~isfield(jTcpObj,'socket')
        error([mfilename '.m--Input argument ''jTcpObj'' not of recognised format.']);        
    end % if
end % if

% Perform specified action.
if action == REQUEST
    jTcpObj = jtcp_request_connection(host,port,timeout,serialize);
elseif action == ACCEPT
    jTcpObj = jtcp_accept_connection(port,timeout,serialize);
elseif action == WRITE
    jtcp_write(jTcpObj,mssg);
elseif action == READ
    mssg = jtcp_read(jTcpObj,maxNumBytes,numBytes,helperClassPath);
elseif action == CLOSE
    jTcpObj = jtcp_close(jTcpObj);
end % if

if nargout > 0
    if ismember(action,[REQUEST ACCEPT CLOSE])
        varargout{1} = jTcpObj;
    elseif action == WRITE
        varargout{1} = [];
    elseif action == READ
        varargout{1} = mssg;
    elseif action == CLOSE
        varargout{1} = [];
    end % if
end % if

%-------------------------------------------------------------------------
function jTcpObj = jtcp_request_connection(host,port,timeout,serialize)
%
% jtcp_request_connection.m--Request a TCP connection from server.
%
% Syntax: jTcpObj = jtcp_request_connection(host,port,timeout,serialize)
%
% e.g., jTcpObj = jtcp_request_connection('208.77.188.166',21566,1000,true)

% Developed in Matlab 7.8.0.347 (R2009a) on GLNX86.
% Kevin Bartlett (kpb@uvic.ca), 2009-06-17 13:03
%-------------------------------------------------------------------------

% Assemble socket address.
socketAddress = java.net.InetSocketAddress(host,port); 

% 2009-10-05--Suggestion from Derek Eggiman to clean up code. Instead of a
% while loop for the timeout, create an unconnected socket, then connect it
% to the host/port address while specifying a timeout.

% Establish unconnected socket. 
socket = java.net.Socket();
socket.setSoTimeout(timeout);

% Connect socket to address.
try 
    socket.connect(socketAddress,timeout); 
catch ME
    %errorStr = sprintf('%s.m--Failed to make TCP connection.\nJava error message follows:\n%s',mfilename,lasterr);
    error('jtcp:connectionRequestFailed','%s.m--Failed to make TCP connection.\nJava error message follows:\n%s',mfilename,ME.message);
end % try

% On the server, getInputStream() blocks in jtcp_accept_connection() until
% the client executes getOutputStream(), so the order of creation of
% outputStream and inputStream here must be done in the reverse
% order from that used in jtcp_accept_connection().
if serialize
    socketOutputStream = socket.getOutputStream();
    outputStream = java.io.ObjectOutputStream(socketOutputStream);
    socketInputStream = socket.getInputStream();
    inputStream = java.io.ObjectInputStream(socketInputStream);
else
    socketOutputStream = socket.getOutputStream();
    outputStream = java.io.DataOutputStream(socketOutputStream);
    socketInputStream = socket.getInputStream();
    inputStream = java.io.DataInputStream(socketInputStream);    
end

jTcpObj.socket = socket;
jTcpObj.remoteHost = host;
jTcpObj.port = port;
jTcpObj.socketInputStream = socketInputStream;
jTcpObj.inputStream = inputStream;
jTcpObj.socketOutputStream = socketOutputStream;
jTcpObj.outputStream = outputStream;
jTcpObj.serialize = serialize;

%-------------------------------------------------------------------------
function jTcpObj = jtcp_accept_connection(port,timeout,serialize)
%
% jtcp_accept_connection.m--Accept a TCP connection from client.
%
% Syntax: jTcpObj = jtcp_accept_connection(port,timeout,serialize)
%
% e.g., jTcpObj = jtcp_accept_connection(21566,1000,true)

% Developed in Matlab 7.8.0.347 (R2009a) on GLNX86.
% Kevin Bartlett (kpb@uvic.ca), 2009-06-17 13:03
%-------------------------------------------------------------------------

serverSocket = java.net.ServerSocket(port);
serverSocket.setSoTimeout(timeout);

try
    socket = serverSocket.accept;
    socket.setSoTimeout(timeout);
    
    if serialize
        socketInputStream = socket.getInputStream();
        inputStream = java.io.ObjectInputStream(socketInputStream);
        socketOutputStream = socket.getOutputStream();
        outputStream = java.io.ObjectOutputStream(socketOutputStream);
    else
        socketInputStream = socket.getInputStream();
        inputStream = java.io.DataInputStream(socketInputStream);
        socketOutputStream = socket.getOutputStream();
        outputStream = java.io.DataOutputStream(socketOutputStream);        
    end
    
    jTcpObj.socket = socket;
    inetAddress = socket.getInetAddress;
    host = char(inetAddress.getHostAddress);        
    jTcpObj.remoteHost = host;
    jTcpObj.port = port;
    jTcpObj.socketInputStream = socketInputStream;
    jTcpObj.inputStream = inputStream;
    jTcpObj.socketOutputStream = socketOutputStream;
    jTcpObj.outputStream = outputStream;
    jTcpObj.serialize = serialize;
catch ME
    serverSocket.close;
    rethrow(ME);
end % try

serverSocket.close;

%-------------------------------------------------------------------------
function [] = jtcp_write(jTcpObj,mssg)
%
% jtcp_write.m--Writes the specified message to the TCP/IP connection.
%
% Syntax: jtcp_write(jTcpObj,mssg)
%
% e.g.,   jtcp_write(jTcpObj,'howdy')

% Developed in Matlab 7.8.0.347 (R2009a) on GLNX86.
% Kevin Bartlett (kpb@uvic.ca), 2009-06-17 13:03
%-------------------------------------------------------------------------

if jTcpObj.serialize
    jTcpObj.outputStream.writeObject(mssg);
else
    if ~isa(mssg,'int8')
        error([mfilename '.m--With ''serialize'' parameter set to false, data to be sent must be of the type ''int8''.']);
    end
    jTcpObj.outputStream.write(mssg,0,length(mssg));
end

jTcpObj.outputStream.flush;

%-------------------------------------------------------------------------
function [mssg] = jtcp_read(jTcpObj,maxNumBytes,numBytes,helperClassPath)
%
% jtcp_read.m--Reads the specified message from the TCP/IP connection.
%
% Variables maxNumBytes,numBytes,helperClassPath have no effect if
% serialize is true.
%
% If not serializing a Java helper class will be used if the
% helperClassPath input string is not empty. If the helper class is not
% found, jtcp_read will revert to reading byte-by-byte, which is slow.
%
% Syntax: mssg = jtcp_read(jTcpObj,maxNumBytes,numBytes,helperClassPath);

% Developed in Matlab 7.8.0.347 (R2009a) on GLNX86.
% Kevin Bartlett (kpb@uvic.ca), 2009-06-17 13:03
%-------------------------------------------------------------------------

numBytesAvailable = jTcpObj.socketInputStream.available;

if jTcpObj.serialize
    if numBytesAvailable > 0
        mssg = jTcpObj.inputStream.readObject();
    else
        mssg = [];
    end % if
else
    % Default behaviour is to read in all available bytes.
    numBytesToRead = numBytesAvailable;
    
    doUseHelperClass = ~isempty(helperClassPath);
    
    % If a maximum number of bytes to read has been specified, and if that
    % maximum number is less than the number of available bytes, then
    % limit the number of bytes read in.
    if maxNumBytes <= numBytesAvailable
        numBytesToRead = maxNumBytes;
    end % if
    
    % If an exact number of bytes to read in has been specified, then it
    % trumps any value of maxNumBytes.
    if ~isnan(numBytes)
        numBytesToRead = numBytes;
    end % if
    
    % If the number of bytes to read exceeds the number available, then do
    % not attempt to read; return an empty string.
    if numBytesToRead > numBytesAvailable
        mssg = '';
    else
        if doUseHelperClass
            % Use of the helper class has been specified, but the class has
            % to be on the java class path to be useable.
            dynamicJavaClassPath = javaclasspath('-dynamic');
            
            % Add the helper class path if it isn't already there.
            if ~ismember(helperClassPath,dynamicJavaClassPath)
                javaaddpath(helperClassPath);
                
                % javaaddpath issues a warning rather than an error if it
                % fails, so can't use try/catch here. Test again to see if
                % helper path added.
                dynamicJavaClassPath = javaclasspath('-dynamic');
                
                if ~ismember(helperClassPath,dynamicJavaClassPath)
                    warning('jtcp:helperClassNotFound',[mfilename '.m--Unable to add Java helper class; reverting to byte-by-byte (slow) algorithm.']);
                    doUseHelperClass = false;
                end % if
                
            end % if
            
        end % if
        
        % Read the message.
        if doUseHelperClass
            % Read incoming message using efficient single function call.
            data_reader = DataReader(jTcpObj.inputStream);
            mssg = data_reader.readBuffer(numBytesToRead);
            mssg = mssg(:)';
        else
            % Read incoming message byte-by-byte with separate function
            % call for each byte.
            mssg = zeros(1, numBytesToRead, 'int8');
            
            for i = 1:numBytesToRead,
                mssg(i) = jTcpObj.inputStream.readByte;
            end % for
            
        end % if
        
    end % if
    
end

%-------------------------------------------------------------------------
function [jTcpObj] = jtcp_close(jTcpObj)
%
% jtcp_close.m--Closes the specified TCP/IP connection.
%
% Syntax: jTcpObj = jtcp_close(jTcpObj);
%
% e.g.,   jTcpObj = jtcp_close(jTcpObj);

% Developed in Matlab 7.8.0.347 (R2009a) on GLNX86.
% Kevin Bartlett (kpb@uvic.ca), 2009-06-17 13:03
%-------------------------------------------------------------------------

jTcpObj.socket.close;

