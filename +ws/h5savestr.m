function h5savestr(file, dataset, value, useCreate)
%H5SAVESTR Create an H5 string dataset and write the value.
%
%   Must be a vector string.

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

if isempty(value)
    dims = 1;
    fileType = H5T.copy ('H5T_FORTRAN_S1');
    H5T.set_size (fileType, 'H5T_VARIABLE');
    memType = H5T.copy ('H5T_C_S1');
    H5T.set_size (memType, 'H5T_VARIABLE');
else
    dims = size(value, 1);
    SDIM = size(value, 2) + 1;
    
    fileType = H5T.copy('H5T_FORTRAN_S1');
    H5T.set_size (fileType, SDIM - 1);
    memType = H5T.copy('H5T_C_S1');
    H5T.set_size (memType, SDIM - 1);
end

dataspace = H5S.create_simple (1, fliplr(dims), []);

if size(value, 2) > 1
    value = value';
end

ws.h5savevalue(fileID, dataset, fileType, value, dataspace, memType);

H5T.close(fileType);
