function dataFileAsStruct = loadDataFile(filename)
    % Loads Wavesurfer data file.  The returned data is a structure array
    % with one element per trial in the data file.

    % Check that file exists
    if ~exist(filename, 'file') , 
        error('The file %s does not exist.', filename)
    end
    
    % Check that file has proper extension
    [~, ~, ext] = fileparts(filename);
    if ~isequal(ext, '.h5') ,
        error('File must be a Wavesurfer-generated HDF5 (.H5) file.');
    end

    % Extract dataset at each group level, recursively.    
    dataFileAsStruct = crawl_h5_tree('/', filename);
end  % function



% ------------------------------------------------------------------------------
% crawl_h5_tree
% ------------------------------------------------------------------------------
function s = crawl_h5_tree(pathToGroup, filename)
    % Get the dataset and subgroup names in the current group
    [datasetNames,subGroupNames] = get_group_info(pathToGroup, filename);
        
    % Create an empty scalar struct
    s=struct();

    % Add a field for each of the subgroups
    for idx = 1:length(subGroupNames)
        subGroupName=subGroupNames{idx};
        fieldName = field_name_from_hdf_name(subGroupName);
        pathToSubgroup = sprintf('%s%s/',pathToGroup,subGroupName);
        s.(fieldName) = crawl_h5_tree(pathToSubgroup, filename);
    end
    
    % Add a field for each of the datasets
    for idx = 1:length(datasetNames) ,
        datasetName = datasetNames{idx} ;
        pathToDataset = sprintf('%s%s',pathToGroup,datasetName);
        dataset = h5read(filename, pathToDataset);
        % Unbox scalar cellstr's
        if iscellstr(dataset) && isscalar(dataset) ,
            dataset=dataset{1};
        end
        fieldName = field_name_from_hdf_name(datasetName) ;        
        s.(fieldName) = dataset;
    end
end  % function



% ------------------------------------------------------------------------------
% get_group_info
% ------------------------------------------------------------------------------
function [datasetNames, subGroupNames] = get_group_info(pathToGroup, filename)
    info = h5info(filename, pathToGroup);

    if isempty(info.Groups) ,
        subGroupNames = cell(1,0);
    else
        subGroupAbsoluteNames = {info.Groups.Name};
        subGroupNames = ...
            cellfun(@local_hdf_name_from_path,subGroupAbsoluteNames,'UniformOutput',false);
    end

    if isempty(info.Datasets) ,
        datasetNames = cell(1,0);
    else
        datasetNames = {info.Datasets.Name};
    end
end  % function



% % ------------------------------------------------------------------------------
% % add_group_data
% % ------------------------------------------------------------------------------
% function s = add_group_data(pathToGroup, datasetNames, filename, sSoFar)
%     elementsOfPathToGroupRawSingleton = textscan(pathToGroup, '%s', 'Delimiter', '/');
%     elementsOfPathToGroupRaw = elementsOfPathToGroupRawSingleton{1} ;
%     elementsOfPathToGroup = elementsOfPathToGroupRaw(2:end);  % first one is generally empty string
%     elementsOfPathToField = ...
%         cellfun(@field_name_from_hdf_name, elementsOfPathToGroup, 'UniformOutput', false);
% 
%     % Create structure to be "appended" to sSoFar
%     sToAppend = struct();
%     for idx = 1:length(datasetNames) ,
%         datasetName = datasetNames{idx};
%         sToAppend.(datasetName) = h5read(filename, [pathToGroup '/' datasetName]);
%     end
% 
%     % "Append" fields to main struct, in the right sub-field
%     if isempty(elementsOfPathToField) ,
%         s = sSoFar;
%     else
%         s = setfield(sSoFar, {1}, elementsOfPathToField{:}, {1}, sToAppend);
%     end
% end



% ------------------------------------------------------------------------------
% force_valid_fieldname
% ------------------------------------------------------------------------------
function fieldName = field_name_from_hdf_name(hdfName)
    numVal = str2double(hdfName);

    if isnan(numVal)
        % This is actually a good thing, b/c it means the groupName is not
        % simply a number, which would be an illegal field name
        fieldName = hdfName;
    else
        try
            validateattributes(numVal, {'numeric'}, {'integer' 'scalar'});
        catch me
            error('Unable to convert group name %s to a valid field name.', hdfName);
        end

        fieldName = ['n' hdfName];
    end
end  % function


function localName = local_hdf_name_from_path(rawPath)
    if isempty(rawPath) ,
        localName = '';
    else
        if rawPath(end)=='/' ,
            path=rawPath(1:end-1);
        else
            path=rawPath;
        end
        indicesOfSlashes=find(path=='/');
        if isempty(indicesOfSlashes) ,
            localName = path;
        else
            indexOfLastSlash=indicesOfSlashes(end);
            if indexOfLastSlash<length(path) ,
                localName = path(indexOfLastSlash+1:end);
            else
                localName = '';
            end
        end
    end
end  % function


% ------------------------------------------------------------------------------
% force_valid_fieldname
% ------------------------------------------------------------------------------

