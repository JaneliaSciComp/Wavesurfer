function h5savescalarstruct(file, pathName, value, useCreate)

if nargin < 4
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


fieldNames = fieldnames(value);

groupId = H5G.create(fileID, pathName, 0);    
H5G.close(groupId);

for j = 1:numel(fieldNames)
    fieldName=fieldNames{j};
    subPathName = sprintf('%s/%s',pathName,fieldName);
    ws.h5save(fileID, subPathName, value.(fieldName));
end
