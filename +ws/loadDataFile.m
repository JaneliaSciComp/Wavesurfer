function data = loadDataFile(filename)
    % Loads Wavesurfer data file.  The returned data is a structure array
    % with one element per trial in the data file.

    % Determine source file
    assert(exist(filename, 'file') > 0, sprintf('The specified file, %s, does not exist.', filename));
    [~, ~, e] = fileparts(filename);
    assert(isequal(e, '.h5'), 'File must be a Wavesurfer-generated HDF5 (.H5) file.');

    % Extract dataset at each group level, recursively.
    data = struct();
    data = local_crawl_h5_tree('/', filename, data);
end



% ------------------------------------------------------------------------------
% local_crawl_h5_tree
% ------------------------------------------------------------------------------
function s = local_crawl_h5_tree(parentGroup, filename, s)
    [datasets,childGroups] = local_get_group_info(parentGroup, filename);

    s = local_add_group_data(parentGroup, datasets, filename, s);

    if isempty(childGroups)
        return;
    else
        for idx = 1:length(childGroups)
            s = local_crawl_h5_tree(childGroups{idx}, filename, s);
        end
    end
end



% ------------------------------------------------------------------------------
% local_get_group_info
% ------------------------------------------------------------------------------
function [datasets, childGroups] = local_get_group_info(parentGroup, filename)
    info = h5info(filename, parentGroup);

    if isempty(info.Groups)
        childGroups = {};
    else
        childGroups = {info.Groups.Name};
    end

    if isempty(info.Datasets)
        datasets = {};
    else
        datasets = {info.Datasets.Name};
    end
end



% ------------------------------------------------------------------------------
% local_add_group_data
% ------------------------------------------------------------------------------
function s = local_add_group_data(parentGroup, datasets, filename, s)
    C = textscan(parentGroup, '%s', 'Delimiter', '/');
    C = C{1}(2:end);
    C = cellfun(@(c)local_force_valid_fieldname(c), C, 'UniformOutput', false);

    % Create sub-struct.
    sub = struct();
    for idx = 1:length(datasets)
        sub.(datasets{idx}) = h5read(filename, [parentGroup '/' datasets{idx}]);
    end

    % Append to main struct.
    if ~isempty(C)
        s = setfield(s, {1}, C{:}, {1}, sub);
    end
end



% ------------------------------------------------------------------------------
% local_force_valid_fieldname
% ------------------------------------------------------------------------------
function fieldname = local_force_valid_fieldname(fieldname)
    numVal = str2double(fieldname);

    if ~isnan(numVal)
        try
            validateattributes(numVal, {'numeric'}, {'integer' 'scalar'});
        catch me
            error('Unsupported group name detected: %s', fieldname);
        end

        fieldname = ['n' fieldname];
    end
end
