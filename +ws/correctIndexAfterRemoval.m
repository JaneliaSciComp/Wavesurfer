function result = correctIndexAfterRemoval(oldIndex, wasRemoved)
    % Idea is that oldIndex was an index into some array, but that array just
    % had some of its elements removed, the elements represented by the logical array wasRemoved.  
    % So we want to find the index that maps to the same element pointed to by
    % oldIndex in the new array.
    
    wasKept = ~wasRemoved ;
    newIndexFromOldIndex = cumsum(wasKept) ;
    newIndex = newIndexFromOldIndex(oldIndex) ;    
    if newIndex==0, 
        result = [] ;
    else
        result = newIndex ;
    end
end
