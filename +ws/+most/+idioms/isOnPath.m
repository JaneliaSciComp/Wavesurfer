function tf = isOnPath(path_)
path_ = fullfile(path_,''); % ensure right formatting
currentpath = strsplit(path(),';');
tf = any(strcmpi(path_,currentpath)); % case insensitive
end