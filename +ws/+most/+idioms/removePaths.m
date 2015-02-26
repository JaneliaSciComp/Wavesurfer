function removedPaths = removePaths(paths)
removedPaths = {};
for i = 1:length(paths)
    pathi = paths{i};
    pathi = fullfile(pathi,''); % ensure correct formatting
    if ws.most.idioms.isOnPath(pathi);
        rmpath(pathi);
        removedPaths{end+1} = {pathi}; %#ok<AGROW>
    end
end
end