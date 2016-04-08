function h5savedouble(file, dataset, value, useCreate)
%H5SAVEDOUBLE Create an H5 double dataset and write the value.

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

datatypeID = H5T.copy('H5T_NATIVE_DOUBLE');

ws.h5savevalue(fileID, dataset, datatypeID, value);

H5T.close(datatypeID);
