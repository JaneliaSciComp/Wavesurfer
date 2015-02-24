function h5savestruct(file, dataset, value, useCreate)

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

groupId = H5G.create(fileID, dataset, 0);

H5G.close(groupId);

fieldNames = fieldnames(value);

for idx = 1:numel(fieldNames)
    fieldName=fieldNames{idx};
    ws.most.fileutil.h5save(fileID, [dataset '/', fieldName], value.(fieldName));
end
