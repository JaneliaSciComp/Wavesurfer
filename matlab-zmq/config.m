% Please edit this file with the correct paths for ZMQ instalation.
%
% Examples can be found in files `config_unix.m`, `config_win.m`.
% This file itself shows how to build `matlab-zmq` using a Homebrew
% installation of ZMQ 4.0.4 for OS-X.

% Old ones:
% % ZMQ library filename
% ZMQ_COMPILED_LIB = 'libzmq-v90-mt-4_0_4.lib';
% 
% % ZMQ library path
% ZMQ_LIB_PATH = 'C:/Program Files/ZeroMQ 4.0.4/lib';
% 
% % ZMQ headers path
% ZMQ_INCLUDE_PATH = 'C:/Program Files/ZeroMQ 4.0.4/include';




% New ones for self-compiled zmq lib:
absolutePathToThisFile = mfilename('fullpath') ;
absolutePathToWavesurferRepo = fileparts(fileparts(absolutePathToThisFile)) ;

% ZMQ library filename
ZMQ_COMPILED_LIB = 'libzmq.lib' ;

% ZMQ library path
ZMQ_LIB_PATH = fullfile(absolutePathToWavesurferRepo, 'zeromq-4.1.3', 'lib') ;

% ZMQ headers path
ZMQ_INCLUDE_PATH = fullfile(absolutePathToWavesurferRepo, 'zeromq-4.1.3', 'include') ;
