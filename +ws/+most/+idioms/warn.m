function warn(varargin)
    warnst = warning('off','backtrace');
    warning(varargin{:});
    warning(warnst);
end

