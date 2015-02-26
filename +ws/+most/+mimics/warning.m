function warning(varargin)
%WARNING Mimic of built-in function 'warning', with stack tracing turned off. 

s = warning('off', 'backtrace');
warning(varargin{:});
warning(s);
