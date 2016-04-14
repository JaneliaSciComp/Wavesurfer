function mdfStructure=readMachineDataFile(fileName)
    % Read the whole file into one big string
    fid=fopen(fileName,'rt');
    try
        fileContentsAsString=fread(fid,inf,'char=>char')';
    catch me
        fclose(fid);
        rethrow(me);
    end
    fclose(fid);
    
    % Convert the file contents into a structure with fixed field names
    mdfStructure=mdfStructureFromFileContents(fileContentsAsString);
    
    % Do verfication of fields.  verifyProperty() throws an
    % wavesurfer:InvalidMDFVariableValue exception if it finds something it
    % dislikes
    verifyProperty(mdfStructure, [], 'physicalInputChannelNames', {'Classes', {'cell'}});
    %verifyProperty(mdfStructure, [], 'inputTerminalIDs', {'Classes', {'numeric'}, 'Attributes', {'vector', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true});
    verifyProperty(mdfStructure, [], 'inputChannelNames', {'Classes', {'cell'}});
    
    verifyProperty(mdfStructure, [], 'physicalOutputChannelNames', {'Classes', {'cell'}});
%     verifyProperty(mdfStructure, [], 'outputDeviceNames', {'Classes', {'cell'}});
%     verifyProperty(mdfStructure, [], 'outputAnalogTerminalIDs', ...
%                    {'Classes', {'numeric'}, 'Attributes', {'vector', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true});
    verifyProperty(mdfStructure, [], 'outputChannelNames', {'Classes', {'cell'}});
    
%     verifyProperty(mdfStructure, [], 'outputDigitalTerminalIDs', ...
%                    {'Classes', {'numeric'}, 'Attributes', {'vector', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true});
%     verifyProperty(mdfStructure, [], 'outputDigitalChannelNames', {'Classes', {'cell'}});
    
    for index = 1:length(mdfStructure.triggerSource) ,
        verifyProperty(mdfStructure.triggerSource, index, 'Name', {'Classes', {'char'}});
        verifyProperty(mdfStructure.triggerSource, index, 'DeviceName', {'Classes', {'char'}});
        verifyProperty(mdfStructure.triggerSource, index, 'CounterID', ...
                       {'Classes', {'numeric'}, 'Attributes', {'scalar', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true});
    end    

    for index = 1:length(mdfStructure.triggerDestination) ,
        verifyProperty(mdfStructure.triggerDestination, index, 'Name', {'Classes', {'char'}});
        verifyProperty(mdfStructure.triggerDestination, index, 'DeviceName', {'Classes', {'char'}});
        verifyProperty(mdfStructure.triggerDestination, index, 'PFIID', ...
                       {'Classes', {'numeric'}, 'Attributes', {'scalar', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true});
        verifyProperty(mdfStructure.triggerDestination, index, 'Edge', {'Classes', {'char'}});
    end        
end



function  mdfStructure=mdfStructureFromFileContents(fileContentsAsString)
    eval(fileContentsAsString);  % this will introduce variables into the current scope
    
    % Stuff all the values into the structure to be returned
    requiredFieldNames={'physicalInputChannelNames' 'inputChannelNames' ...
                        'physicalOutputChannelNames' 'outputChannelNames' };
    for i=1:length(requiredFieldNames) ,
        fieldName=requiredFieldNames{i};
        try
            value=eval(fieldName);
        catch me
            error('wavesurfer:MissingMDFVariableValue', 'Machine data file is missing required field ''%s''.', fieldName);
        end
        mdfStructure.(fieldName) = value ;
    end
    optionalFieldNames={'triggerSource' 'triggerDestination'};
    for i=1:length(optionalFieldNames) ,
        fieldName=optionalFieldNames{i};
        try
            value=eval(fieldName);
        catch me %#ok<NASGU>
            value=struct([]);
        end
        mdfStructure.(fieldName) = value ;
    end        
end



function verifyProperty(structure, index, fieldName, validAttributes)
    if isempty(index)
        % structure is already a scalar
        value = structure.(fieldName);
    else
        scalarStructure=structure(index);
        value=scalarStructure.(fieldName);
    end
    try
        if ~isempty(validAttributes)
            ws.validateAttributes(value, validAttributes{:});
        end
    catch me
        error('wavesurfer:InvalidMDFVariableValue', 'Invalid value for machine data file variable ''%s''.', fieldName);
    end
end

