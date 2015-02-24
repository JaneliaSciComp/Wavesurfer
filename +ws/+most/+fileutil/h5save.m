function h5save(file, dataset, value, useCreate)

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

if isstruct(value)
    ws.most.fileutil.h5savestruct(fileID, dataset, value);
elseif isnumeric(value)
    if  ws.most.idioms.isenum(value)
        value = double(value);
    end
    ws.most.fileutil.h5savedouble(fileID, dataset, value);
elseif islogical(value)
    ws.most.fileutil.h5savedouble(fileID, dataset, double(value));
elseif ischar(value)
    ws.most.fileutil.h5savestr(fileID, dataset, value);
elseif iscellstr(value)
    ws.most.fileutil.h5savestr(fileID, dataset, char(value));
elseif isobject(value) && ismethod(value,'h5save') ,
    % If it's an object that knows how to save itself to HDF5, use the
    % method
    value.h5save(fileID, dataset);    
else
    %With stack traces turned off, finding this was non-trivial, so make sure to identify the code throwing the warning. - TO022114A
    ws.most.mimics.warning('most:h5:unsuporteddatatype', 'h5save - Unsupported data type: %s', class(value));
end

end  % function
