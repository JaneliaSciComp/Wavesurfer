function target = copyCellArrayOfHandles(source)
    % Utility function for copying a cell array of encodable
    % entities, given a parent.
    nElements = length(source) ;
    target = cell(size(source)) ;  % want to preserve row vectors vs col vectors
    for j=1:nElements ,
        target{j} = ws.copy(source{j});
    end
end  % function
