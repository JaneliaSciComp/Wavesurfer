function data = loadDataFile(filename)
    % Loads Wavesurfer data file.  The returned data is a structure array
    % with one element per trial in the data file.

    % Determine source file
    assert(exist(filename, 'file') > 0, sprintf('The specified file, %s, does not exist.', filename));
    [~, ~, e] = fileparts(filename);
    assert(isequal(e, '.h5'), 'File must be a Wavesurfer-generated HDF5 (.H5) file.');

    % Extract dataset at each group level, recursively.
    data = struct();
    data = crawl_h5_tree('/', filename, data);
end



% ------------------------------------------------------------------------------
% crawl_h5_tree
% ------------------------------------------------------------------------------
function s = crawl_h5_tree(pathToGroup, filename, s)
    [datasetNames,subGroupNames] = get_group_info(pathToGroup, filename);

    s = add_group_data(pathToGroup, datasetNames, filename, s);

    if isempty(subGroupNames)
        return
    else
        for idx = 1:length(subGroupNames)
            s = crawl_h5_tree(subGroupNames{idx}, filename, s);
        end
    end
end



% ------------------------------------------------------------------------------
% get_group_info
% ------------------------------------------------------------------------------
function [datasetNames, childGroupNames] = get_group_info(pathToGroup, filename)
    info = h5info(filename, pathToGroup);

    if isempty(info.Groups)
        childGroupNames = {};
    else
        childGroupNames = {info.Groups.Name};
    end

    if isempty(info.Datasets)
        datasetNames = {};
    else
        datasetNames = {info.Datasets.Name};
    end
end



% ------------------------------------------------------------------------------
% add_group_data
% ------------------------------------------------------------------------------
function s = add_group_data(pathToGroup, datasetNames, filename, sSoFar)
    elementsOfPathToGroupRawSingleton = textscan(pathToGroup, '%s', 'Delimiter', '/');
    elementsOfPathToGroupRaw = elementsOfPathToGroupRawSingleton{1} ;
    elementsOfPathToGroup = elementsOfPathToGroupRaw(2:end);  % first one is generally empty string
    elementsOfPathToField = ...
        cellfun(@field_name_from_group_name, elementsOfPathToGroup, 'UniformOutput', false);

    % Create structure to be "appended" to sSoFar
    sToAppend = struct();
    for idx = 1:length(datasetNames) ,
        datasetName = datasetNames{idx};
        sToAppend.(datasetName) = h5read(filename, [pathToGroup '/' datasetName]);
    end

    % "Append" fields to main struct, in the right sub-field
    if isempty(elementsOfPathToField) ,
        s = sSoFar;
    else
        s = setfield(sSoFar, {1}, elementsOfPathToField{:}, {1}, sToAppend);
    end
end



% ------------------------------------------------------------------------------
% force_valid_fieldname
% ------------------------------------------------------------------------------
function fieldName = field_name_from_group_name(groupName)
    numVal = str2double(groupName);

    if isnan(numVal)
        % This is actually a good thing, b/c it means the groupName is not
        % simply a number, which would be an illegal field name
        fieldName = groupName;
    else
        try
            validateattributes(numVal, {'numeric'}, {'integer' 'scalar'});
        catch me
            error('Unable to convert group name %s to a valid field name.', groupName);
        end

        fieldName = ['n' groupName];
    end
end
