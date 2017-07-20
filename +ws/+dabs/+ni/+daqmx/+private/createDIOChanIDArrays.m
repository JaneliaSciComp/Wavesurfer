function [physChanNameArray,chanNameArray] = createDIOChanIDArrays(numChans, deviceName, physChanIDs, chanNames)            
    if numChans == 1 && ~iscell(physChanIDs) ,
        physChanIDs = {physChanIDs};
    end

    physChanNameArray = cell(1, numChans) ;
    chanNameArray = cell(1, numChans) ;
    for iChan = 1:numChans ,
        thisPhysChanID = physChanIDs{iChan} ;
        portOrLineID = regexpi(thisPhysChanID, '\s*/?(.*)','tokens','once') ;  % Removes leading slash, if any  
        thisPhysChanName = [deviceName '/' portOrLineID{1}] ;
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
