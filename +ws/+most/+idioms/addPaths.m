function addedPaths = addPaths(paths)
assert(iscell(paths),'Input needs to be a cell array of strings');

addedPaths = {};
for i = 1:length(paths)
    pathi = paths{i};
    pathi = fullfile(pathi,''); % ensure correct formatting
    if ~ws.most.idioms.isOnPath(pathi)
        addpath(pathi);
        addedPaths{end+1} = pathi; %#ok<AGROW>
    end
end

end