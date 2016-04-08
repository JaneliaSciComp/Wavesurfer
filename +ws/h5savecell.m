function h5savecell(file, pathName, value, useCreate)

if nargin < 4 ,
    useCreate = false;
end

if ischar(file)
    if useCreate
        fileID = H5F.create(file, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
    else
        fileID = H5F.open(file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
    end
    c = onCleanup(@()H5F.close(fileID));
else
    fileID = file;
end

% Create a group (a.k.a. directory) corresponding to the path to us
groupName = pathName;
groupId = H5G.create(fileID, groupName, 0);
H5G.close(groupId);

for i = 1:numel(value) ,
    subPathName = sprintf('%s/element%d',pathName,i);
    ws.h5save(fileID, subPathName, value{i});
end    
