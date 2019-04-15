function result = insertColumn(A, index, newColumn)
    % index is the index of the newColumn after insertion
    result = horzcat(A(:,1:index-1), newColumn, A(:,index:end)) ;
end
