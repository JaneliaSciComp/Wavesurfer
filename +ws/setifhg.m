function setifhg(hgHandles,varargin)
    % Like set(), but only does the set on valid HG handles in hgHandles.
    % Does nothing at all if hgHandles is empty.
    if ~isempty(hgHandles) ,
        isHG=ishghandle(hgHandles);
        hgHandlesValid=hgHandles(isHG);
        set(hgHandlesValid,varargin{:});
    end
end
