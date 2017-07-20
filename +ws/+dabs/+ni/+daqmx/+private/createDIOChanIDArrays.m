function [physChanNameArray,chanNameArray] = createDIOChanIDArrays(numChans, deviceName, physChanIDs, chanNames)            
    if numChans == 1 && ~iscell(physChanIDs) ,
        physChanIDs = {physChanIDs};
    end

    % define local function to capture deviceName
    function result = appendDeviceName(str) 
        result = horzcat(deviceName, '/', str) ;
    end
    
    physChanNameArray = cell(1, numChans) ;
    chanNameArray = cell(1, numChans) ;
    for iChan = 1:numChans ,
        thisPhysChanID = physChanIDs{iChan} ;  % e.g. 'port0/line0', or 'port0/line0, port0/line1', or 'line0', or 'line0, line4'
        thisPhysChanIDAsCellString = strtrim(strsplit(thisPhysChanID, ',')) ;
        portOrLineIDsAsCellString = cellfun(@removeLeadingSlash, thisPhysChanIDAsCellString, 'UniformOutput', false) ;
        thisPhysChanNameAsCellString = cellfun(@appendDeviceName, portOrLineIDsAsCellString, 'UniformOutput', false) ;
        thisPhysChanName = stringFromCellString(thisPhysChanNameAsCellString) ;        
        %portOrLineID = regexpi(thisPhysChanID, '\s*/?(.*)','tokens','once') ;  % Removes leading slash, if any  
        %thisPhysChanName = [deviceName '/' portOrLineID{1}] ;
        if isempty(chanNames)
            thisChanName = ''; 
              % Would prefer to give it the physical chan name, but DAQmx won't take any
              % special characters in the given channel name (even as it proceeds to use
              % them in supplying the default itself)
        elseif ischar(chanNames)
            if numChans > 1
                thisChanName = [chanNames num2str(iChan)];
            else
                thisChanName = chanNames;
            end
        elseif iscellstr(chanNames) && length(chanNames)==numChans
            thisChanName = chanNames{iChan};
        else
            error(['Argument ''' inputname(5) ''' must be a string or cell array of strings of length equal to the number of channels.']);
        end
        
        % Put the outputs for this channel in the output arrays
        physChanNameArray{iChan} = thisPhysChanName ;
        chanNameArray{iChan} = thisChanName ;
    end
end

function result = removeLeadingSlash(str)
    % Removes a leading slash from string str, if present.  Otherwise returns str.
    if isempty(str) ,
        result = str ;
    else
        if isequal(str(1), '/') ,
            result = str(2:end) ;
        else
            result = str ;
        end
    end
end


function result = stringFromCellString(cellstring)
    % Converts a cell string to a string, separating values with commas.
    % E.g. {'foo', 'bar', 'baz'} -> 'foo, bar, baz'
    if isempty(cellstring) ,
        result = '' ;
    else
        nElements = length(cellstring) ;
        result = cellstring{1} ;
        for i = 2:nElements ,
            result = horzcat(result, ', ', cellstring{i}) ; %#ok<AGROW>
        end   
    end
end